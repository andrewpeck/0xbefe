import xml.etree.ElementTree as xml
import sys, os, subprocess
from collections import OrderedDict

DEBUG = True
ADDRESS_TABLE_TOP = "me0_lpgbt/lpgbt_registers.xml"
system = ""
nodes = OrderedDict()
reg_list_dryrun = {}
for i in range(462):
    reg_list_dryrun[i] = 0x00
n_rw_reg = (0x13C+1) # number of registers in LPGBT rwf + rw block

TOP_NODE_NAME = "LPGBT"

NODE_IC_GBTX_LINK_SELECT = None
NODE_IC_GBTX_I2C_ADDRESS = None
NODE_IC_READ_WRITE_LENGTH = None
NODE_IC_ADDR = None
NODE_IC_WRITE_DATA = None
NODE_IC_EXEC_WRITE = None
NODE_IC_EXEC_READ = None
#NODE_IC_READ_DATA = None

class Node:
    name = ""
    vhdlname = ""
    address = 0x0
    real_address = 0x0
    permission = ""
    mask = 0x0
    lsb_pos = 0x0
    isModule = False
    parent = None
    level = 0
    mode = None

    def __init__(self):
        self.children = []

    def addChild(self, child):
        self.children.append(child)

    def getVhdlName(self):
        return self.name.replace(TOP_NODE_NAME + ".", "").replace(".", "_")

    def output(self):
        print ("Name:",self.name)
        print ("Address:","{0:#010x}".format(self.address))
        print ("Permission:",self.permission)
        print ("Mask:",self.mask)
        print ("LSB:",self.lsb_pos)
        print ("Module:",self.isModule)
        print ("Parent:",self.parent.name)

class Colors:
    WHITE   = "\033[97m"
    CYAN    = "\033[96m"
    MAGENTA = "\033[95m"
    BLUE    = "\033[94m"
    YELLOW  = "\033[93m"
    GREEN   = "\033[92m"
    RED     = "\033[91m"
    ENDC    = "\033[0m"

def main():
    parseXML()
    
    print ("Example1:")
    print (getNode("LPGBT.RWF.CHIPID.CHIPID0").output())
    
    print ("\nExample2:")
    for node in getNodesContaining("CHIPID"):
        print (node.output())
        
    print ("\nExample3:")
    print (getNodeFromAddress(0x00).output())
    
    print ("\nExample4:")
    for node in getRegsContaining("CHIPID"):
        print (node.output())
        
    print ("\nExample5:")
    print (completeReg("LPGBT.RWF.CHIPID.CHIPID"))
    

# Functions related to parsing lpgbt_registers.xml
def parseXML(filename = None, num_of_oh = None):
    if filename == None:
        filename = ADDRESS_TABLE_TOP
    print ("Parsing",filename,"...")
    tree = xml.parse(filename)
    root = tree.getroot()[0]
    vars = {}
    makeTree(root,"",0x0,nodes,None,vars,False,num_of_oh)

def makeTree(node,baseName,baseAddress,nodes,parentNode,vars,isGenerated,num_of_oh=None):
    if (isGenerated == None or isGenerated == False) and node.get("generate") is not None and node.get("generate") == "true":
        if (node.get("generate_idx_var") == "OH_IDX" and num_of_oh is not None):
            generateSize = num_of_oh
        else:
            generateSize = parseInt(node.get("generate_size"))
        # generateSize = parseInt(node.get("generate_size"))
        generateAddressStep = parseInt(node.get("generate_address_step"))
        generateIdxVar = node.get("generate_idx_var")
        for i in range(0, generateSize):
            vars[generateIdxVar] = i
            #print("generate base_addr = " + hex(baseAddress + generateAddressStep * i) + " for node " + node.get("id"))
            makeTree(node, baseName, baseAddress + generateAddressStep * i, nodes, parentNode, vars, True)
        return
    newNode = Node()
    name = baseName
    if baseName != "": name += "."
    name += node.get("id")
    name = substituteVars(name, vars)
    newNode.name = name
    address = baseAddress
    if node.get("address") is not None:
        address = baseAddress + parseInt(eval(node.get("address")))
    newNode.address = address
    newNode.real_address = address
    newNode.permission = node.get("permission")
    newNode.mask = parseInt(node.get("mask"))
    newNode.lsb_pos = mask_to_lsb(newNode.mask)
    newNode.isModule = node.get("fw_is_module") is not None and node.get("fw_is_module") == "true"
    if node.get("mode") is not None:
        newNode.mode = node.get("mode")
    nodes[newNode.name] = newNode
    if parentNode is not None:
        parentNode.addChild(newNode)
        newNode.parent = parentNode
        newNode.level = parentNode.level+1
    for child in node:
        makeTree(child,name,address,nodes,newNode,vars,False,num_of_oh)

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
    return next((nodes[nodename] for nodename in nodes if nodes[nodename].real_address == nodeAddress),None)

def getNodesContaining(nodeString):
    nodelist = [nodes[nodename] for nodename in nodes if nodeString in nodename]
    if len(nodelist): return nodelist
    else: return None

def getRegsContaining(nodeString):
    nodelist = [nodes[nodename] for nodename in nodes if nodeString in nodename and nodes[nodename].permission is not None and "r" in nodes[nodename].permission]
    if len(nodelist): return nodelist
    else: return None

def readAddress(address):
    try:
        output = subprocess.check_output("mpeek (" + str(address) + ")" + stderr==subprocess.STDOUT , shell=True)
        value = "".join(s for s in output if s.isalnum())
    except subprocess.CalledProcessError as e: value = parseError(int(str(e)[-1:]))
    return "{0:#010x}".format(parseInt(str(value)))

def readRawAddress(raw_address):
    try:
        address = (parseInt(raw_address) << 2)+0x64000000
        return readAddress(address)
    except:
        return "Error reading address. (rw_reg)"


# Functions regarding reading/writing registers
def rw_initialize(station, system_val, boss=None, ohIdx=None, gbtIdx=None):
    print("Parsing lpGBT xml file...")
    parseXML()
    print("Parsing complete...")

    global system
    system = system_val
    if system=="chc":
        import gem.me0_lpgbt.rpi_chc as rpi_chc
        global gbt_rpi_chc
        gbt_rpi_chc = rpi_chc.rpi_chc()
        if boss is not None:
            config_initialize_chc(boss)    
    elif system=="backend" or system=="dryrun":
        import gem.gem_utils as gem_utils
        global gem_utils
        print("Parsing backend xml file...")
        gem_utils.initialize(station, system_val)
        print("Parsing complete...")

        global NODE_IC_GBTX_LINK_SELECT
        global NODE_IC_GBTX_I2C_ADDRESS
        global NODE_IC_READ_WRITE_LENGTH
        global NODE_IC_ADDR
        global NODE_IC_WRITE_DATA
        global NODE_IC_EXEC_WRITE
        global NODE_IC_EXEC_READ
        global NODE_IC_READ_DATA
        NODE_IC_GBTX_LINK_SELECT = gem_utils.get_backend_node("BEFE.GEM_AMC.SLOW_CONTROL.IC.GBTX_LINK_SELECT")
        NODE_IC_GBTX_I2C_ADDRESS = gem_utils.get_backend_node("BEFE.GEM_AMC.SLOW_CONTROL.IC.GBTX_I2C_ADDR")
        NODE_IC_READ_WRITE_LENGTH = gem_utils.get_backend_node("BEFE.GEM_AMC.SLOW_CONTROL.IC.READ_WRITE_LENGTH")
        NODE_IC_ADDR = gem_utils.get_backend_node("BEFE.GEM_AMC.SLOW_CONTROL.IC.ADDRESS")
        NODE_IC_WRITE_DATA = gem_utils.get_backend_node("BEFE.GEM_AMC.SLOW_CONTROL.IC.WRITE_DATA")
        NODE_IC_EXEC_WRITE = gem_utils.get_backend_node("BEFE.GEM_AMC.SLOW_CONTROL.IC.EXECUTE_WRITE")
        NODE_IC_EXEC_READ = gem_utils.get_backend_node("BEFE.GEM_AMC.SLOW_CONTROL.IC.EXECUTE_READ")
        #NODE_IC_READ_DATA = gem_utils.get_backend_node("BEFE.GEM_AMC.SLOW_CONTROL.IC.READ_DATA")

        if ohIdx is not None and gbtIdx is not None:
            select_ic_link(ohIdx, gbtIdx)

def config_initialize_chc(boss):
    initialize_success = 1
    initialize_success *= gbt_rpi_chc.config_select(boss)
    if initialize_success:
        initialize_success *= gbt_rpi_chc.en_i2c_switch()
    if initialize_success:
        initialize_success *= gbt_rpi_chc.i2c_channel_sel(boss)
    if not initialize_success:
        print(Colors.RED + "ERROR: Problem in initialization" + Colors.ENDC)
        rw_terminate()
            
def select_ic_link(ohIdx, gbtIdx):
    if system=="backend":
        ohIdx = int(ohIdx)
        gbtIdx = int(gbtIdx)
        if ohIdx not in range(0,2) or gbtIdx not in range(0,8):
            print (Colors.RED + "ERROR: Invalid ohIdx or gbtIdx" + Colors.ENDC)
            rw_terminate()
        linkIdx = ohIdx * 8 + gbtIdx
        gem_utils.write_backend_reg(NODE_IC_GBTX_LINK_SELECT, linkIdx)
        gem_utils.write_backend_reg(NODE_IC_GBTX_I2C_ADDRESS, 0x70)
        gem_utils.write_backend_reg(NODE_IC_READ_WRITE_LENGTH, 1)

def mpeek(address):
    if system=="chc":
        success, data = gbt_rpi_chc.lpgbt_read_register(address)
        if success:
            return data
        else:
            print(Colors.RED + "ERROR: Problem in reading register: " + str(hex(address)) + Colors.ENDC)
            rw_terminate()
    elif system=="backend":
        #write_backend_reg(NODE_IC_ADDR, address)
        #write_backend_reg(NODE_IC_EXEC_READ, 1)
        #data = read_backend_reg(NODE_IC_READ_DATA)
        #return data
        return reg_list_dryrun[address]
    elif system=="dryrun":
        return reg_list_dryrun[address]
    else:
        print(Colors.RED + "ERROR: Incorrect system" + Colors.ENDC)
        rw_terminate()

def mpoke(address, value):
    global reg_list_dryrun
    if system=="chc":
        success = gbt_rpi_chc.lpgbt_write_register(address, value)
        if not success:
            print(Colors.RED + "ERROR: Problem in writing register: " + str(hex(address)) + Colors.ENDC)
            rw_terminate()
    elif system=="backend":
        gem_utils.write_backend_reg(NODE_IC_ADDR, address)
        gem_utils.write_backend_reg(NODE_IC_WRITE_DATA, value)
        gem_utils.write_backend_reg(NODE_IC_EXEC_WRITE, 1)
        reg_list_dryrun[address] = value
    elif system=="dryrun":
        reg_list_dryrun[address] = value
    else:
        print(Colors.RED + "ERROR: Incorrect system" + Colors.ENDC)
        rw_terminate()

def readRegStr(reg):
    return "0x%02X"%(readReg(reg))
    #return "{0:#010x}".format(readReg(reg))

def readReg(reg):
    try:
        address = reg.real_address
    except:
        print ("Reg",reg,"not a Node")
        return
    if "r" not in reg.permission:
        return "No read permission!"

    # read
    value = mpeek(address)

    # Apply Mask
    if (reg.mask != 0):
        value = (reg.mask & value) >> reg.lsb_pos

    return value

def displayReg(reg, option=None):
    address = reg.real_address
    if "r" not in reg.permission:
        return "No read permission!"
    # mpeek
    value = mpeek(address)
    # Apply Mask
    if reg.mask is not None:
        shift_amount=0
        for bit in reversed("{0:b}".format(reg.mask)):
            if bit=="0": shift_amount+=1
            else: break
        final_value = (parseInt(str(reg.mask))&parseInt(value)) >> shift_amount
    else: final_value = value
    final_int =  parseInt(str(final_value))

    if option=="hexbin": return hex(address).rstrip("L")+" "+reg.permission+"\t"+tabPad(reg.name,7)+"{0:#010x}".format(final_int)+" = "+"{0:032b}".format(final_int)
    else: return hex(address).rstrip("L")+" "+reg.permission+"\t"+tabPad(reg.name,7)+"{0:#010x}".format(final_int)

def writeReg(reg, value, readback):
    try:
        address = reg.real_address
    except:
        print ("Reg",reg,"not a Node")
        return
    if "w" not in reg.permission:
        return "No write permission!"

    if (readback):
        if (value!=readReg(reg)):
            print (Colors.RED + "ERROR: Failed to read back register %s. Expect=0x%x Read=0x%x" % (reg.name, value, readReg(reg)) + Colors.ENDC)
    else:
        # Apply Mask if applicable
        if (reg.mask != 0):
            value = value << reg.lsb_pos
            value = value & reg.mask
            if "r" in reg.permission:
                value = (value) | (mpeek(address) & ~reg.mask)
        # mpoke
        mpoke(address, value)

def writeandcheckReg(reg, value):
    try:
        address = reg.real_address
    except:
        print ("Reg",reg,"not a Node")
        return
    if "w" not in reg.permission:
        return "No write permission!"

    # Apply Mask if applicable
    if (reg.mask != 0):
        value = value << reg.lsb_pos
        value = value & reg.mask
        if "r" in reg.permission:
            value = (value) | (mpeek(address) & ~reg.mask)
    # mpoke
    mpoke(address, value)

    # Check register value
    if "r" not in reg.permission:
        return "No read permission!, cant check"
    value_check = mpeek(address)
    if (reg.mask != 0):
        value_check = (reg.mask & value_check) >> reg.lsb_pos

    check=0
    if value == value_check:
        check=1
    return check

def isValid(address):
    #try: subprocess.check_output("mpeek "+str(address), stderr=subprocess.STDOUT , shell=True)
    #except subprocess.CalledProcessError as e: return False
    return True

def completeReg(string):
    possibleNodes = []
    completions = []
    currentLevel = len([c for c in string if c=="."])

    possibleNodes = [nodes[nodename] for nodename in nodes if nodename.startswith(string) and nodes[nodename].level == currentLevel]
    if len(possibleNodes)==1:
        if possibleNodes[0].children == []: return [possibleNodes[0].name]
        for n in possibleNodes[0].children:
            completions.append(n.name)
    else:
        for n in possibleNodes:
            completions.append(n.name)
    return completions

def check_lpgbt_ready(ohIdx=None, gbtIdx=None):
    if system!="dryrun":
        pusmstate = readReg(getNode("LPGBT.RO.PUSM.PUSMSTATE"))
        if (pusmstate==18):
            print ("lpGBT status is READY")
        else:
            print (Colors.RED + "ERROR: lpGBT is not READY, configure lpGBT first" + Colors.ENDC)
            rw_terminate()

def lpgbt_efuse(boss, enable):
    fuse_success = 1
    if boss:
        lpgbt_type = "Boss"
    else:
        lpgbt_type = "Sub"
    if system=="chc":
        fuse_success = gbt_rpi_chc.fuse_arm_disarm(boss, enable)
        if not fuse_success:
            print(Colors.RED + "ERROR: Problem in fusing for: " + lpgbt_type + Colors.ENDC)
            fuse_off = gbt_rpi_chc.fuse_arm_disarm(boss, 0)
            if not fuse_off:
                print (Colors.RED + "ERROR: EFUSE Power cannot be turned OFF for: " + lpgbt_type + Colors.ENDC)
                print (Colors.YELLOW + "Turn OFF 2.5V fusing Power Supply or Switch Immediately for: " + lpgbt_type + Colors.ENDC)
            rw_terminate()

def chc_terminate():
    # Check EFUSE status and disarm EFUSE if necessary
    efuse_success_boss, efuse_status_boss = gbt_rpi_chc.fuse_status(1) # boss
    efuse_success_sub, efuse_status_sub = gbt_rpi_chc.fuse_status(0) # sub
    if efuse_success_boss and efuse_success_sub:
        if (efuse_status_boss):
            print (Colors.YELLOW + "EFUSE for Boss was ARMED for Boss" + Colors.ENDC)
            fuse_off = gbt_rpi_chc.fuse_arm_disarm(1, 0) # boss
            if not fuse_off:
                print (Colors.RED + "ERROR: EFUSE Power cannot be turned OFF for Boss" + Colors.ENDC)
                print (Colors.YELLOW + "Turn OFF 2.5V fusing Power Supply or Switch Immediately for Boss" + Colors.ENDC)
        if (efuse_status_sub):
            print (Colors.YELLOW + "EFUSE for Sub was ARMED for Sub" + Colors.ENDC)
            fuse_off = gbt_rpi_chc.fuse_arm_disarm(0, 0) # sub
            if not fuse_off:
                print (Colors.RED + "ERROR: EFUSE Power cannot be turned OFF for Sub" + Colors.ENDC)
                print (Colors.YELLOW + "Turn OFF 2.5V fusing Power Supply or Switch Immediately for Sub" + Colors.ENDC)
    else:
        print (Colors.RED + "ERROR: Problem in reading EFUSE status" + Colors.ENDC)
        print (Colors.YELLOW + "Turn OFF 2.5V fusing Power Supply or Switch Immediately (if they were ON) for both Boss and Sub" + Colors.ENDC)

    # Terminating RPi
    terminate_success = gbt_rpi_chc.terminate()
    if not terminate_success:
        print(Colors.RED + "ERROR: Problem in RPi_CHC termination" + Colors.ENDC)
        sys.exit()

def rw_terminate():
    if system=="backend":
        gem_utils.terminate()
    if system=="chc":
        chc_terminate()
    sys.exit()

def check_rom_readback():
    romreg=readReg(getNode("LPGBT.RO.ROMREG"))
    if (romreg != 0xA5):
        print (Colors.RED + "ERROR: no communication with LPGBT. ROMREG=0x%x, EXPECT=0x%x" % (romreg, 0xA5) + Colors.ENDC)
        rw_terminate()
    else:
        print ("Successfully read from ROM. I2C communication OK")

def parseError(e):
    if e==1:
        return "Failed to parse address"
    if e==2:
        return "Bus error"
    else:
        return "Unknown error: "+str(e)

def parseInt(s):
    if s is None:
        return None
    string = str(s)
    if string.startswith("0x"):
        return int(string, 16)
    elif string.startswith("0b"):
        return int(string, 2)
    else:
        return int(string)

def substituteVars(string, vars):
    if string is None:
        return string
    ret = string
    for varKey in vars.keys():
        ret = ret.replace("${" + varKey + "}", str(vars[varKey]))
    return ret

def tabPad(s,maxlen):
    return s+"\t"*((8*maxlen-len(s)-1)/8+1)

def mask_to_lsb(mask):
    if mask is None:
        return 0
    if (mask&0x1):
        return 0
    else:
        idx=1
        while (True):
            mask=mask>>1
            if (mask&0x1):
                return idx
            idx = idx+1

def lpgbt_write_config_file(config_file = "config.txt"):
    f = open(config_file,"w+")
    for i in range (n_rw_reg):
        val =  mpeek(i)
        if i in range(0x0f0, 0x105): # I2C Masters
            val = 0x00
        write_string = "0x%03X  0x%02X\n" % (i, val)
        f.write(write_string)
    f.close()

def lpgbt_dump_config(config_file = "Loopback_test.txt"):
        #dump configuration to lpGBT - accepts .txt of .xml input
        # Read configuration file
        if(config_file[-4:] == ".xml"):
            tree = ET.parse(config_file)
            root = tree.getroot()
            reg_config = []
            for i in range(0,366):
                reg_config.append([0,0]) # Value / Mask

            for child in root:
                name_signal = child.attrib["name"]
                triplicated = child.attrib["triplicated"]
                reg_value   = int(child[0].text)
                if(triplicated in ["true", "True", "TRUE"]) : n=3
                else                                        : n=1
                for i in range(1,n+1):
                    #print(name_signal)
                    #print(triplicated)
                    #print(reg_value)
                    reg_addr = int(child[i].attrib["startAddress"])
                    startbit = int(child[i].attrib["startBitIndex"])
                    endbit   = int(child[i].attrib["lastBitIndex"])
                    mask     = 2**(startbit+1) - 2**(endbit)
                    reg_config[reg_addr][0] = reg_config[reg_addr][0] | (reg_value << startbit)
                    reg_config[reg_addr][1] = reg_config[reg_addr][1] | mask

            for reg_addr in range(0,len(reg_config)):
                value = reg_config[reg_addr][0]
                mask  = reg_config[reg_addr][1]
                if(mask != 0):
                    value = mpeek(reg_addr)
                    value = (value & (~mask)) | value
                    mpoke(reg_addr, value)
        else:
            input_file = open(config_file, "r")
            for line in input_file.readlines():
                reg_addr = int(line.split()[0],16)
                value = int(line.split()[1],16)
                if reg_addr in range(0x0f0, 0x105): # I2C Masters
                    value = 0x00
                mpoke(reg_addr, value)
            input_file.close()
        print("lpGBT Configuration Done")

if __name__ == "__main__":
    main()
