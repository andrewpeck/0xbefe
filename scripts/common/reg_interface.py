from cmd import Cmd
import sys, os, subprocess
from common.rw_reg import *

class Prompt(Cmd):

    def do_doc(self, args):
        """Show properies of the node matching the name. USAGE: doc <NAME>"""
        arglist = args.split()
        if len(arglist)==1:
            node = get_node(args)
            if node is not None:
                print(node.output())
            else:
                print('Node not found: ' + args)

        else: print('Incorrect number of arguments.')

    def do_read(self, args):
        """Reads register. USAGE: read <register name>. OUTPUT <address> <mask> <permission> <name> <value>"""
        reg = get_node(args)
        if reg is not None:
            if 'r' in str(reg.permission):
                print(display_reg(reg))
            elif reg.isModule: print('This is a module!')
            else: print(hex(reg.address) + '\t' + reg.name + '\t' + 'No read permission!')
        else:
            print(args + ' not found!')


    def complete_read(self, text, line, begidx, endidx):
        return complete_reg(text)


    def do_write(self, args):
        """Writes register. USAGE: write <register name> <register value>"""
        arglist = args.split()
        if len(arglist)==2:
            reg = get_node(arglist[0])
            if reg is not None:
                try: value = parse_int(arglist[1])
                except:
                    print('Write Value must be a number!')
                    return
                if 'w' in str(reg.permission): write_reg(reg,value)
                else: print('No write permission!')
            else: print(arglist[0] + ' not found!')
        else: print("Incorrect number of arguments!")

    def complete_write(self, text, line, begidx, endidx):
        return complete_reg(text)


    def do_readGroup(self, args): #INEFFICIENT
        """Read all registers below node in register tree. USAGE: readGroup <register/node name> """
        node = get_node(args)
        if node is not None:
            print('NODE: ' + node.name)
            kids = []
            get_all_children(node, kids)
            print(len(kids) + ' CHILDREN')
            for reg in kids:
                if 'r' in str(reg.permission): print(display_reg(reg))
        else: print(args + ' not found!')

    def complete_readGroup(self, text, line, begidx, endidx):
        return complete_reg(text)


    def do_readKW(self, args):
        """Read all registers containing KeyWord. USAGE: readKW <KeyWord>"""
        if get_nodes_containing(args) is not None and args!='':
            for reg in get_nodes_containing(args):
                if 'r' in str(reg.permission):
                    print(display_reg(reg))
                elif reg.isModule: print(hex(reg.address).rstrip('L') + " " + reg.permission + '\t' + tab_pad(reg.name,7)) #,'Module!'
                else: print(hex(reg.address).rstrip('L') + " " + reg.permission + '\t' + tab_pad(reg.name,7)) #,'No read permission!'
        else: print(args + ' not found!')

    def do_exit(self, args):
        """Exit program"""
        return True

    def do_read_address(self, args):
        """ Directly read address. USAGE: readAddress <address> """
        try: reg = get_node_from_address(parse_int(args))
        except:
            print('Error retrieving node.')
            return
        if reg is not None:
            print(hex(reg.address) + '\t' + "0x%08x" % read_address(reg.address))
        else:
            print(args + ' not found!')

    def execute(self, other_function, args):
        other_function = 'do_'+other_function
        call_func = getattr(Prompt,other_function)
        try:
            call_func(self,*args)
        except TypeError:
            print('Could not recognize command. See usage in tool.')

if __name__ == '__main__':
    from optparse import OptionParser
    parser = OptionParser()
    parser.add_option("-e", "--execute", type="str", dest="exe",
                      help="Function to execute once", metavar="exe", default=None)
    # parser.add_option("-g", "--gtx", type="int", dest="gtx",
    #                   help="GTX on the GLIB", metavar="gtx", default=0)

    (options, args) = parser.parse_args()
    if options.exe:
        parse_xml()
        prompt=Prompt()
        prompt.execute(options.exe,args)
        exit
    else:
        parse_xml()
        prompt = Prompt()
        prompt.prompt = '0xBEFE > '
        prompt.cmdloop('Starting 0xBEFE Register Command Line Interface.\n')

        # try:
        #     parse_xml()
        #     prompt = Prompt()
        #     prompt.prompt = '0xBEFE > '
        #     prompt.cmdloop('Starting 0xBEFE Register Command Line Interface.\n')
        # except TypeError:
        #     print('[TypeError] Incorrect usage. See help')
        # except KeyboardInterrupt:
        #     print('\n')
