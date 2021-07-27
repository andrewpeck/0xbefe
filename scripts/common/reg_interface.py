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
                node.print_info()
            else:
                print('Node not found: ' + args)

        else: print('Incorrect number of arguments.')

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

    def complete_readGroup(self, text, line, begidx, endidx):
        return complete_reg(text)

    def print_tree(self, reg, last_printed_reg=None):
        if reg is None:
            return
        last_parent = None if last_printed_reg is None else last_printed_reg.parent
        if last_parent is None or (reg.parent is not None and reg.parent != last_parent):
            self.print_tree(reg.parent, last_parent)
        # if print_parents and reg.parent is not None:
        #     self.print_tree(reg.parent)

        s = ""
        for i in range(reg.level - 1):
            s += "|  "
        if reg.level > 0:
            s += "├──"
        s += reg.local_name
        if reg.permission is not None and reg.permission != "":
            s += " (%s)" % reg.permission
            s = tab_pad(s, 7)
            if 'r' in reg.permission:
                s += read_reg(reg).to_string(hex=True)
        print(s)

    def do_readTree(self, args):
        """Read all registers containing the RegName supplied. USAGE: read <RegName>"""
        if args is None or args == "":
            return

        nodes = get_nodes_containing(args)
        if nodes is not None:
            last_printed_reg = None
            for reg in nodes:
                if reg.permission is not None and reg.permission != "":
                    self.print_tree(reg, last_printed_reg)
                    last_printed_reg = reg
        else:
            print(args + ' not found!')

    def do_read(self, args):
        """Read all registers containing the RegName supplied. USAGE: read <RegName>"""
        if args is None or args == "":
            return

        nodes = get_nodes_containing(args)
        if nodes is not None:
            for reg in nodes:
                if 'r' in str(reg.permission):
                    print(display_reg(reg))
                elif reg.isModule:
                    print(hex(reg.address).rstrip('L') + " " + reg.permission + '\t' + tab_pad(reg.name, 7)) #,'Module!'
                else:
                    print(hex(reg.address).rstrip('L') + " " + reg.permission + '\t' + tab_pad(reg.name, 7)) #,'No read permission!'
        else:
            print(args + ' not found!')

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
