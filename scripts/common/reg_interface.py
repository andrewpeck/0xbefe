from cmd import Cmd
import sys, os, subprocess
from rw_reg import *
#from vfat_config import *

MAX_OH_NUM = 3


class Prompt(Cmd):

    def do_outputnode(self, args):
        """Output properies of node matching name. USAGE: outputnode <NAME>"""
        arglist = args.split()
        if len(arglist)==1:
            node = getNode(args)
            if node is not None:
                print node.output()
            else:
                print 'Node not found:',args

        else: print 'Incorrect number of arguments.' 
                


    def do_sbittranslate(self, args):
        """Decode SBit Cluster data. USAGE: sbittranslate <SBIT CLUSTER>"""
        arglist = args.split()
        if len(arglist)==1:
            try: cluster = parseInt(args)
            except: 
                print 'Invalid cluster.'
                return
            print 'VFAT:',cluster_to_vfat(cluster)
            print 'SBit:',cluster_to_vfat2_sbit(cluster)
            print 'Size:',cluster_to_size(cluster)
        else: print 'Incorrect number of arguments.'
                                          
    def do_test(self, args):
        print 'Test here!'
        print 'args:',args

    def do_oh(self, args):
        """ Begin command by selecting OH, followed by command. USAGE oh <number> <command> """
        arglist = args.split()
        if len(arglist)<1: print 'Too few arguments.'
        elif len(arglist)==1:
            if not arglist[0].isdigit():
                print 'Invalid OH number:',arglist[0]
                return
            elif int(arglist[0])<0 or int(arglist[0])>MAX_OH_NUM: print 'Invalid OH number:',arglist[0]
            else:
                if getNodesContaining('GEM_AMC.OH.OH'+str(arglist[0])+'.') is not None:
                    for reg in getNodesContaining('GEM_AMC.OH.OH'+str(arglist[0])+'.'):
                        address = reg.real_address
                        if 'r' in str(reg.permission):
                            print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7),readReg(reg)
                else: print 'Regs not found!'

        elif not arglist[0].isdigit(): print 'Incorrect usage.'
        elif int(arglist[0])<0 or int(arglist[0])>MAX_OH_NUM: print 'Invalid OH number:',arglist[0]
        else:
            new_args=''
            for i in range(2,len(arglist)):
                new_args += arglist[i]+' '
            if arglist[1]=='v2a': self.do_v2a(arglist[0])
            elif arglist[1]=='test': self.do_test(new_args)
            elif arglist[1]=='mask': self.do_mask(arglist[0]+' '+new_args)
            #elif arglist[1]=='unmask': self.do_unmask(arglist[0]+' '+new_args)
            else: print 'No command found:',arglist[1]


    def do_daq(self, args=''):
        """Read all registers in DAQ module. USAGE: daq <optional OH_NUM>"""
        arglist = args.split()
        if len(arglist)==1: 
            if not arglist[0].isdigit(): 
                print 'Incorrect usage.'
                return
            elif int(arglist[0])<0 or int(arglist[0])>MAX_OH_NUM: print 'Invalid OH number:',arglist[0]
            else:                
                if getNodesContaining('GEM_AMC.DAQ.OH'+str(arglist[0])+'.') is not None:
                    for reg in getNodesContaining('GEM_AMC.DAQ.OH'+str(arglist[0])+'.'):
                        address = reg.real_address
                        if 'r' in str(reg.permission):
                            print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7),readReg(reg)
                else: print 'Regs not found!'
        
        elif args=='': 
            if getNodesContaining('GEM_AMC.DAQ') is not None:
                for reg in getNodesContaining('GEM_AMC.DAQ'):
                    address = reg.real_address
                    if 'r' in str(reg.permission):
                        print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7),readReg(reg)
            else: print 'Regs not found!'
        
        else: print 'Incorrect usage.'

    def do_gemsystem(self, args=None):
        """Read all registers in GEM_SYSTEM module. USAGE: gemsystem"""
        if args == '':
            if getNodesContaining('GEM_AMC.GEM_SYSTEM') is not None:
                for reg in getNodesContaining('GEM_AMC.GEM_SYSTEM'):
                    address = reg.real_address
                    if 'r' in str(reg.permission):
                        print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7),readReg(reg)
            else: print 'Regs not found!'

    def do_ttc(self, args=None):
        """Read all registers in TTC module. USAGE: ttc"""
        if getNodesContaining('GEM_AMC.TTC') is not None:
            for reg in getNodesContaining('GEM_AMC.TTC'):
                address = reg.real_address
                if 'r' in str(reg.permission):
                    print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7),readReg(reg)
        else: print 'Regs not found!'

    def do_trigger(self, args=''):
        """Read all registers in TRIGGER module. USAGE: trigger <optional OH_NUM>"""
        arglist = args.split()
        if len(arglist)==1:
            if not arglist[0].isdigit():
                print 'Incorrect usage.'
                return
            elif int(arglist[0])<0 or int(arglist[0])>MAX_OH_NUM: print 'Invalid OH number:',arglist[0]
            else:
                if getNodesContaining('GEM_AMC.TRIGGER.OH'+str(arglist[0])+'.') is not None:
                    for reg in getNodesContaining('GEM_AMC.TRIGGER.OH'+str(arglist[0])+'.'):
                        address = reg.real_address
                        if 'r' in str(reg.permission):
                            print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7),readReg(reg)
                else: print 'Regs not found!'
        elif args=='':
            if getNodesContaining('GEM_AMC.TRIGGER') is not None:
                for reg in getNodesContaining('GEM_AMC.TRIGGER'):
                    address = reg.real_address
                    if 'r' in str(reg.permission):
                        print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7),readReg(reg)
            else: print 'Regs not found!'

        else: print 'Incorrect usage.'




    def do_read(self, args):
        """Reads register. USAGE: read <register name>. OUTPUT <address> <mask> <permission> <name> <value>"""
        reg = getNode(args)
        if reg is not None: 
            address = reg.real_address
            if 'r' in str(reg.permission):
                print displayReg(reg)
            elif reg.isModule: print 'This is a module!'
            else: print hex(address),'\t',reg.name,'\t','No read permission!' 
        else:
            print args,'not found!'

    
    def complete_read(self, text, line, begidx, endidx):
        return completeReg(text)


    def do_write(self, args):
        """Writes register. USAGE: write <register name> <register value>"""
        arglist = args.split()
        if len(arglist)==2:
            reg = getNode(arglist[0])
            if reg is not None:
                try: value = parseInt(arglist[1])
                except: 
                    print 'Write Value must be a number!'
                    return
                if 'w' in str(reg.permission): print writeReg(reg,value)
                else: print 'No write permission!'                
            else: print arglist[0],'not found!'
        else: print "Incorrect number of arguments!"

    def complete_write(self, text, line, begidx, endidx):
        return completeReg(text)


    def do_readGroup(self, args): #INEFFICIENT
        """Read all registers below node in register tree. USAGE: readGroup <register/node name> """
        node = getNode(args)
        if node is not None: 
            print 'NODE:',node.name
            kids = []
            getAllChildren(node, kids)
            print len(kids),'CHILDREN'
            for reg in kids: 
                if 'r' in str(reg.permission): print displayReg(reg)
        else: print args,'not found!'

    def complete_readGroup(self, text, line, begidx, endidx):
        return completeReg(text)


    def do_readFW(self, args=None):
        """Quick read of all FW-related registers"""
        for reg in getNodesContaining('STATUS.FW'):
            if 'r' in str(reg.permission): print hex(reg.real_address),reg.permission,'\t',tabPad(reg.name,4),readReg(reg)

    def do_fw(self, args=None):
        """Quick read of all FW-related registers"""
        for reg in getNodesContaining('STATUS.FW'):
            if 'r' in str(reg.permission): print hex(reg.real_address),reg.permission,'\t',tabPad(reg.name,4),readReg(reg)


    def do_readKW(self, args):
        """Read all registers containing KeyWord. USAGE: readKW <KeyWord>"""
        if getNodesContaining(args) is not None and args!='':
            for reg in getNodesContaining(args):
                address = reg.real_address
                if 'r' in str(reg.permission):
                    print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7),readReg(reg)
                elif reg.isModule: print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7) #,'Module!'
                else: print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7) #,'No read permission!' 
        else: print args,'not found!'


    def do_kw(self, args):
        """Read all registers containing KeyWord. USAGE: readKW <KeyWord>"""
        if getNodesContaining(args) is not None and args!='':
            for reg in getNodesContaining(args):
                address = reg.real_address
                if 'r' in str(reg.permission):
                    print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7),readReg(reg)
                elif reg.isModule: print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7) #,'Module!'
                else: print hex(address).rstrip('L'),reg.permission,'\t',tabPad(reg.name,7) #,'No read permission!' 
        else: print args,'not found!'


    def do_readAll(self, args):
        """Read all registers with read-permission"""
        for reg in getNodesContaining(''):
            if 'r' in str(reg.permission): print displayReg(reg) 
            
    def do_exit(self, args):
        """Exit program"""
        return True

    def do_readAddress(self, args):
        """ Directly read address. USAGE: readAddress <address> """
        try: reg = getNodeFromAddress(parseInt(args))
        except: 
            print 'Error retrieving node.'
            return
        if reg is not None: 
            address = reg.real_address
            print hex(address),'\t',readAddress(address)
        else:
            print args,'not found!' 

    def do_readRawAddress(self, args):
        """Read raw address (from XML file). USAGE: readRawAddress <address> """
        try: print readRawAddress(args)
        except: print 'Error reading address. (reg_interface)'
            

    def do_mpeek(self,args):
        """Basic mpeek command to read register. USAGE: mpeek <address>"""
        print mpeek(args)

    def do_mpoke(self,args):
        """Basic mpoke command to write register. USAGE: mpoke <address> <value>"""
        arglist = args.split()
        if len(arglist)==2:
            print mpoke(arglist[0],arglist[1])
        else: print "Incorrect number of arguments!"

    def do_debug(self,args):
        """Quick read of SBit Clusters. USAGE: debug <OH_NUM>"""
        arglist = args.split()
        if len(arglist)==1:
            for reg in getNodesContaining('OH'+str(args)+'.DEBUG_LAST'):
                try: cluster = parseInt(readReg(reg))
                except: cluster = 0
                if cluster == 2047:
                    if 'r' in str(reg.permission): print hex(reg.real_address),reg.permission,'\t',tabPad(reg.name,4),readReg(reg),'(None)'
                else:
                    if 'r' in str(reg.permission): print hex(reg.real_address),reg.permission,'\t',tabPad(reg.name,4),readReg(reg),'(VFAT:',cluster_to_vfat(cluster),'SBit:',cluster_to_vfat2_sbit(cluster),'Size:',cluster_to_size(cluster),')'

        else: print "Incorrect number of arguments!"


    def do_v2a(self,args):
        """Configure recovered clock for OHv2a. USAGE v2a <OH_NUM>"""
        arglist = args.split()
        if len(arglist)==1:
            if not args.isdigit() or int(args)<0 or int(args)>2: 
                print 'Invalid OH number.'
                return
            reg = getNode('GEM_AMC.OH.OH'+str(args)+'.CONTROL.CLOCK.REF_CLK')
            if reg is not None:
                try: print writeReg(reg,1)
                except:
                    print 'Write error.'
                    return
            else: print 'Error finding clock control register!'
        else: print "Incorrect number of arguments!"


    def do_mask(self, args):
        """Mask single VFAT to data. If no VFAT provided, will mask all VFATs. USAGE mask <OH_NUM> <optional VFAT_SLOT> """
        arglist = args.split()
        if len(arglist)==1 and isValidOH(arglist[0]):
            print writeReg(getNode('GEM_AMC.OH.OH'+str(arglist[0])+'.CONTROL.VFAT.MASK'),0xffffffff)
        elif len(arglist)==2 and isValidOH(arglist[0]) and isValidVFAT(arglist[1]):
            vfat = int(arglist[1])
            oh = int(arglist[0])
            mask = (0x1 << vfat)
            try: current_mask = parseInt(readReg(getNode('GEM_AMC.OH.OH'+str(oh)+'.CONTROL.VFAT.MASK')))
            except: 
                print 'Error reading current mask.'
                return
            new_mask = mask | current_mask
            print writeReg(getNode('GEM_AMC.OH.OH'+str(oh)+'.CONTROL.VFAT.MASK'),new_mask)
        else:
            print 'Incorrect usage.'
            return
                                       
    def do_unmask(self, args):
        """Unmask single VFAT to data. If no VFAT provided, will unmask all VFATs. USAGE unmask <OH_NUM> <optional VFAT_SLOT> """
        arglist = args.split()
        if len(arglist)==1 and isValidOH(arglist[0]):
            print writeReg(getNode('GEM_AMC.OH.OH'+str(arglist[0])+'.CONTROL.VFAT.MASK'),0x00000000)
        elif len(arglist)==2 and isValidOH(arglist[0]) and isValidVFAT(arglist[1]):
            vfat = int(arglist[1])
            oh = int(arglist[0])
            mask = 0xffffffff ^ (0x1 << vfat)
            try: current_mask = parseInt(readReg(getNode('GEM_AMC.OH.OH'+str(oh)+'.CONTROL.VFAT.MASK')))
            except:
                print 'Error reading current mask.'
                return
            new_mask = mask & current_mask
            print writeReg(getNode('GEM_AMC.OH.OH'+str(oh)+'.CONTROL.VFAT.MASK'),new_mask)
        else:
            print 'Incorrect usage.'
            return

    def execute(self, other_function, args):
        other_function = 'do_'+other_function
        call_func = getattr(Prompt,other_function)
        try:
            call_func(self,*args)
        except TypeError:
            print 'Could not recognize command. See usage in tool.'

def isValidOH(oh):
    if not oh.isdigit(): return False
    if int(oh)<0 or int(oh)>MAX_OH_NUM: return False
    return True
    
def isValidVFAT(vfat):
    if not vfat.isdigit(): return False
    if int(vfat)<0 or int(vfat)>23: return False
    return True



if __name__ == '__main__':
    from optparse import OptionParser
    parser = OptionParser()
    parser.add_option("-e", "--execute", type="str", dest="exe",
                      help="Function to execute once", metavar="exe", default=None)
    # parser.add_option("-g", "--gtx", type="int", dest="gtx",
    #                   help="GTX on the GLIB", metavar="gtx", default=0)

    (options, args) = parser.parse_args()
    if options.exe:
        parseXML()
        prompt=Prompt()
        prompt.execute(options.exe,args)
        exit
    else:
        try:
            parseXML()
            prompt = Prompt()
            prompt.prompt = '0xBEFE > '
            prompt.cmdloop('Starting 0xBEFE Register Command Line Interface.\n')
        except TypeError:
            print '[TypeError] Incorrect usage. See help'
        except KeyboardInterrupt:
            print '\n'
