import sys
import re

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

def main():

    if len(sys.argv) < 5:
        print('This utility uses output files from describe_mgt.tcl to update a given VHDL file which instantiates an MGT channel with the correct parameters and port constants')
        print('Usage: update_mgt.py <mgt_channel_vhd_file> <port_file> <property_file> <output_file>')
        return

    vhdlFName = sys.argv[1]
    portFName = sys.argv[2]
    propFName = sys.argv[3]
    outFName = sys.argv[4]

    # make a dictionary for properties
    print("======================== properties ========================")

    props = {}
    propFile = open(propFName, "r")
    propFile.readline()
    for line in propFile:
        split = line.split()
        if len(split) < 4:
            if len(split) == 3 and split[1].lower() == "string":
                print(Colors.RED + ("WARNING: empty string value in line %s" % line.replace("\n", "")) + Colors.ENDC)
                split.append("")
            if split[1].lower() != "enum":
                print(Colors.RED + ("WARNING: invalid line: %s" % line.replace("\n", "")) + Colors.ENDC)
            continue

        name = split[0]
        type = split[1]
        val = split[3]
        valVhdl = ""

        if type.lower() == "enum" or type.lower() == "site" or type.lower() == "cell":
            continue

        if type.lower() ==  "string":
            valVhdl = '"%s"' % val
        elif type.lower() ==  "int" or type.lower() == "double":
            valVhdl = val
        elif type.lower() == "binary":
            if val[:val.index("'b")] == "1":
                valVhdl = "'%s'" % val[val.index("'b")+2:]
            else:
                valVhdl = '"%s"' % val[val.index("'b")+2:]
        elif type.lower() == "hex":
            valVhdl = 'x"%s"' % val[val.index("'h")+2:]
        elif type.lower() == "bool":
            if val == "1":
                valVhdl = "true"
            elif val == "0":
                valVhdl = "false"
            else:
                print("ERROR: unrecognized bool value: " + val)
                print("Exiting..")
                return
        else:
            print("ERROR: unknown type in properties file: %s" % type)
            return

        props[name] = valVhdl
        print("%s => %s" % (name, valVhdl))

    propFile.close()

    print("======================== ports ========================")

    portBits = {}
    portFile = open(portFName, "r")
    for line in portFile:
        split = line.split()
        name = split[0]
        val = split[1]
        if val.lower() == "signal" or "clock" in val.lower():
            continue
        elif val.lower() == "ground":
            val = 0
        elif val.lower() == "power":
            val = 1

        idx = 0
        r = re.compile(r'(.*)\[(.*)\]')
        m = r.match(name)
        if m:
            print("match for %s" % name)
            name = m.group(1)
            idx = int(m.group(2))
            if not name in portBits:
                portBits[name] = [0] * (idx + 1)
        else:
            print("no match for %s" % name)
            portBits[name] = [0]

        portBits[name][idx] = val

    portFile.close()

    ports = {}
    for name in portBits:
        bits = portBits[name]
        val = ""
        if len(bits) == 1:
            val = "'%d'" % bits[0]
        else:
            val = '"'
            for i in range(len(bits)-1, -1, -1):
                val += "%d" % bits[i]
            val += '"'

        ports[name] = val
        print("%s => %s" % (name, val))

    print("======================== updating VHDL ========================")

    vhdlFile = open(vhdlFName, "r")
    vhdl = ""
    r = re.compile(r'\s+(\S+)\s*=>\s*([^,]*),?\n') # used to parse mappings
    rVal = re.compile(r'=>\s*([^,\n]*)') # used to replace the value
    portSection = False

    for line in vhdlFile:
        if "port map" in line:
            portSection = True
        m = r.match(line)
        print(line.replace("\n", ""))
        name = ""
        val = ""
        if m:
            name = m.group(1)
            val = m.group(2)
            # print("match, name = %s, value = %s" % (name, val))
        else:
            vhdl += line
            continue

        # prop
        if not portSection:
            if not name in props:
                print("ERROR: Unknown generic: %s" % name)
                print("Exiting...")
                return

            line = rVal.sub("=> " + props[name], line)
            # line = line.replace(val, props[name])

        # port
        else:
            # skip if the port isn't in the map, or it is not a constant in the original file
            if not name in ports or ("'" not in line and '"' not in line):
                vhdl += line
                continue

            line = rVal.sub("=> " + ports[name], line)
            # line = line.replace(val, ports[name])

        vhdl += line

    vhdlFile.close()

    vhdlOutFile = open(outFName, "w")
    vhdlOutFile.write(vhdl)
    vhdlOutFile.close()

    # print(vhdl)

if __name__ == '__main__':
    main()
