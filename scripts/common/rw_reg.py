import xml.etree.ElementTree as xml
import sys, os, subprocess
from ctypes import *
from config import *
import imp
import sys
import math
from collections import OrderedDict
from utils import *

print('Loading shared library: librwreg.so')
lib = CDLL("librwreg.so")
rReg = lib.getReg
rReg.restype = c_uint
rReg.argtypes=[c_uint]
wReg = lib.putReg
wReg.restype = c_uint
wReg.argtypes=[c_uint,c_uint]
regInitExists = False
try:
    regInit = lib.rwreg_init
    regInit.argtypes=[c_char_p]
    regInitExists = True
except:
    print("WARNING: rwreg_init() function does not exist.. if you're running on CTP7, you can safely ignore this warning.")

DEBUG = True
ADDRESS_TABLE_DEFAULT = './address_table.xml'
nodes = OrderedDict()
val_cache = {}

boardType = os.environ.get('BOARD_TYPE')
boardIdx = int(os.environ.get('BOARD_IDX'))
DEVICE = CONFIG_RWREG[boardType][boardIdx]['DEVICE']
if sys.version_info[0] == 3:
    DEVICE = CONFIG_RWREG[boardType][boardIdx]['DEVICE'].encode()
BASE_ADDR = CONFIG_RWREG[boardType][boardIdx]['BASE_ADDR']

class Node:
    name = ''
    description = ''
    vhdlname = ''
    local_address = 0x0
    address = 0x0
    permission = ''
    mask = 0x0
    mask_start_bit_pos = None
    isModule = False
    parent = None
    level = 0
    sw_enum = None
    sw_val_good = None
    sw_val_bad = None
    sw_val_warn = None
    sw_val_neutral = None

    def __init__(self):
        self.children = []

    def addChild(self, child):
        self.children.append(child)

    def getVhdlName(self):
        return self.name.replace(TOP_NODE_NAME + '.', '').replace('.', '_')

    def output(self):
        print('Name:',self.name)
        print('Description:',self.description)
        print('Local Address:','{0:#010x}'.format(self.local_address))
        print('Address:','{0:#010x}'.format(self.address))
        print('Permission:',self.permission)
        print('Mask:','{0:#010x}'.format(self.mask))
        print('Module:',self.isModule)
        print('Parent:',self.parent.name)

class RegVal(int):
    reg = None

    def __str__(self):
        if self == 0xdeaddead:
            return Colors.RED + "Bus Error" + Colors.ENDC
        val = "0x%08x" % self
        if self.reg.sw_enum is not None:
            enum_val = "UNKNOWN" if self >= len(self.reg.sw_enum) else self.reg.sw_enum[self]
            val += " (%s)" % enum_val

        if self.reg.sw_val_neutral is not None and eval(self.reg.sw_val_neutral):
            val = val
        elif self.reg.sw_val_bad is not None and eval(self.reg.sw_val_bad):
            val = Colors.RED + val + Colors.ENDC
        elif self.reg.sw_val_warn is not None and eval(self.reg.sw_val_warn):
            val = Colors.YELLOW + val + Colors.ENDC
        elif self.reg.sw_val_good is not None and eval(self.reg.sw_val_good):
            val = Colors.GREEN + val + Colors.ENDC
        elif self.reg.sw_val_good is not None:
            val = Colors.RED + val + Colors.ENDC

        return val

def main():
    parseXML()
    print('Example:')
    random_node = nodes["GEM_AMC.GEM_SYSTEM.BOARD_ID"]
    #print str(random_node.__class__.__name__)
    print('Node:',random_node.name)
    print('Parent:',random_node.parent.name)
    kids = []
    getAllChildren(random_node, kids)
    print(len(kids), kids.name)

def parseXML():
    if regInitExists:
        regInit(DEVICE)
    addressTable = os.environ.get('ADDRESS_TABLE')
    if addressTable is None:
        print('Warning: environment variable ADDRESS_TABLE is not set, using a default of %s' % ADDRESS_TABLE_DEFAULT)
        addressTable = ADDRESS_TABLE_DEFAULT
    print('Parsing',addressTable,'...')
    tree = None
    lxmlExists = False
    try:
        imp.find_module('lxml')
        import lxml.etree
        lxmlExists = True
    except:
        print("WARNING: lxml python module was not found, so xinclude won't work")

    if lxmlExists:
        tree = lxml.etree.parse(addressTable)
        try:
            tree.xinclude()
        except Exception as e:
            print(e)
    else:
        tree = xml.parse(addressTable)

    root = tree.getroot()
    vars = {}
    makeTree(root,'',0x0,nodes,None,vars,False)
    print("Parsing done. Total num register nodes: %d" % len(nodes))

# returns the position of the first set bit
def findFirstSetBitPos(n):
    return int(math.log(n&-n, 2))

def makeTree(node,baseName,baseAddress,nodes,parentNode,vars,isGenerated):

    if node.get('id') is None or (node.get('ignore') is not None and eval(node.get('ignore')) == True):
        return

    if (isGenerated == None or isGenerated == False) and node.get('generate') is not None and node.get('generate') == 'true':
        generateSize = parseInt(node.get('generate_size'))
        generateAddressStep = parseInt(node.get('generate_address_step'))
        generateIdxVar = node.get('generate_idx_var')
        for i in range(0, generateSize):
            vars[generateIdxVar] = i
            makeTree(node, baseName, baseAddress + generateAddressStep * i, nodes, parentNode, vars, True)
        return
    newNode = Node()
    name = baseName
    if baseName != '': name += '.'
    name += node.get('id')
    name = substituteVars(name, vars)
    newNode.name = name
    if node.get('description') is not None:
        newNode.description = node.get('description')
    address = baseAddress
    if node.get('address') is not None:
        address = baseAddress + parseInt(node.get('address'))
    newNode.local_address = address
    newNode.address = (address<<2) + BASE_ADDR
    newNode.permission = node.get('permission')
    if newNode.permission is None:
        newNode.permission = ""
    newNode.mask = parseInt(node.get('mask'))
    if newNode.mask is not None:
        newNode.mask_start_bit_pos = findFirstSetBitPos(newNode.mask)
    newNode.isModule = node.get('fw_is_module') is not None and node.get('fw_is_module') == 'true'
    if node.get('sw_enum') is not None:
        newNode.sw_enum = eval(node.get('sw_enum'))
    if node.get('sw_val_good') is not None:
        newNode.sw_val_good = substituteVars(node.get('sw_val_good'), vars)
    if node.get('sw_val_bad') is not None:
        newNode.sw_val_bad = substituteVars(node.get('sw_val_bad'), vars)
    if node.get('sw_val_warn') is not None:
        newNode.sw_val_warn = substituteVars(node.get('sw_val_warn'), vars)
    if node.get('sw_val_neutral') is not None:
        newNode.sw_val_neutral = substituteVars(node.get('sw_val_neutral'), vars)
    nodes[newNode.name] = newNode
    if parentNode is not None:
        parentNode.addChild(newNode)
        newNode.parent = parentNode
        newNode.level = parentNode.level+1
    for child in node:
        makeTree(child,name,address,nodes,newNode,vars,False)


def getAllChildren(node,kids=[]):
    if node.children==[]:
        kids.append(node)
        return kids
    else:
        for child in node.children:
            getAllChildren(child,kids)

def getNode(nodeName):
    thisnode = None
    if nodeName in nodes:
        thisnode = nodes[nodeName]
    if (thisnode == None):
        print (nodeName)
    return thisnode

def getNodeFromAddress(nodeAddress):
    return next((nodes[nodename] for nodename in nodes if nodes[nodename].address == nodeAddress),None)

def getNodesContaining(nodeString):
    nodelist = [nodes[nodename] for nodename in nodes if nodeString in nodename]
    if len(nodelist): return nodelist
    else: return None

#returns *readable* registers
def getRegsContaining(nodeString):
    nodelist = [nodes[nodename] for nodename in nodes if nodeString in nodename and nodes[nodename].permission is not None and 'r' in nodes[nodename].permission]
    if len(nodelist): return nodelist
    else: return None

def readAddress(address):
    return rReg(address)

# returns RegVal, which is a subclass of int, so it can be used as regular int, but also contains a reference to the node, and when converted to string returns a string with a green/red/yellow color if sw_val_good/sw_val_bad/sw_val_warn is defined, and if it's an enum it will also display the enum value
def readReg(reg, verbose=True):
    if isinstance(reg, str):
        reg = getNode(reg)
    if 'r' not in reg.permission:
        print("No read permission for register %s" % reg.name)
        return RegVal(0xdeaddead, reg)
    val = rReg(reg.address)
    if val == 0xdeaddead:
        if verbose:
            print("Bus error while reading %s" % reg.name)
    if reg.mask is not None:
        val = (val & reg.mask) >> reg.mask_start_bit_pos

    val = RegVal(val)
    val.reg = reg

    return val

# this method reads the register if it doesn't exist in cache, but all subsequent calls will return the cached value -- use very cautiously, if in doubt always use the readReg function instead!
# this should only be used on regs that never change, like config regs
# it's mostly intended to speed up sw_val_good/sw_val_bad/sw_val_warn evals that require looking up configuration values
def readRegCache(reg):
    if isinstance(reg, Node):
        reg = reg.name
    if reg not in val_cache:
        val = readReg(reg)
        val_cache[reg] = val
        return val

    return val_cache[reg]


def displayReg(reg,option=None):
    val = readReg(reg, False)
    str_val = str(val)
    return hex32(reg.address).rstrip('L')+' '+reg.permission+'\t'+tabPad(reg.name,7)+str_val

def writeReg(reg, value):
    if isinstance(reg, str):
        reg = getNode(reg)
    if 'w' not in reg.permission:
        print("No write permission for register %s" % reg.name)
        return -1

    # Apply Mask if applicable
    val32 = value
    if reg.mask is not None:
        val_shifted = value << reg.mask_start_bit_pos
        val32 = rReg(reg.address)
        val32 = (val32 & ~reg.mask) | (val_shifted & reg.mask)
    ret = wReg(reg.address, val32)
    if ret < 0:
        print("Bus error while writing to %s" % reg.name)
        return -1
    return 0

def completeReg(string):
    possibleNodes = []
    completions = []
    currentLevel = len([c for c in string if c=='.'])

    possibleNodes = [nodes[nodename] for nodename in nodes if nodename.startswith(string) and nodes[nodename].level == currentLevel]
    if len(possibleNodes)==1:
        if possibleNodes[0].children == []: return [possibleNodes[0].name]
        for n in possibleNodes[0].children:
            completions.append(n.name)
    else:
        for n in possibleNodes:
            completions.append(n.name)
    return completions

def substituteVars(string, vars):
    if string is None:
        return string
    ret = string
    for varKey in vars.keys():
        ret = ret.replace('${' + varKey + '}', str(vars[varKey]))
    return ret

def tabPad(s, maxlen):
    return s+"\t"*int((8*maxlen-len(s)-1)/8+1)

if __name__ == '__main__':
    main()
