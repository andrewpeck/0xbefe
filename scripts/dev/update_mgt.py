import sys
import re
import tableformatter as tf
from colorama import Back
from common.utils import *

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

CONVERT_ALL_HEX_TO_BINARY = True # if false, hex values are represented as x"1234" in VHDL, if true then all hex values are converted to VHDL binary format

def main():

    if len(sys.argv) < 7:
        print('This utility uses output files from describe_mgt.tcl to update a given VHDL file which instantiates an MGT channel with the correct parameters and port constants')
        print('Usage: update_mgt.py <mgt_channel_vhd_file> <port_file> <property_file> <output_file> <mgt_of_qpll_type> <tx_sync_type> [rx_slide_mode]')
        print('    * mgt_or_qpll_type: gty / gth / qpll / qpll0 / qpll1 (if qpll0 or qpll1 is passed, only ports and properties for that QPLL are updated, and error/warning is thrown if any of the common properties are different)')
        print('    * tx_sync_type: can be "no" (TX buffer bypass is not used), "multilane_auto" (use for GTY), "multilane_manual" (use for GTH)')
        print('    * rx_slide_mode: can be "PCS" or "PMA" (use PMA for GBT links)')
        return

    vhdlFName = sys.argv[1]
    portFName = sys.argv[2]
    propFName = sys.argv[3]
    outFName = sys.argv[4]
    mgtType = sys.argv[5]
    txSyncType = sys.argv[6]
    if len(sys.argv) > 7:
        rxSlideMode = sys.argv[7]
    else:
        rxSlideMode = None

    is_qpll = False
    is_qpll0 = False
    is_qpll1 = False

    if mgtType not in ["gty", "gth", "qpll", "qpll0", "qpll1"]:
        print('ERROR: unsupported MGT type "%s", supported types are: gty, gth' % mgtType)
        return

    if "qpll" in mgtType:
        is_qpll = True
        if mgtType == "qpll0":
            is_qpll0 = True
        elif mgtType == "qpll1":
            is_qpll1 = True

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

        if type.lower() == "string":
            valVhdl = '"%s"' % val
        elif type.lower() == "int" or type.lower() == "double":
            valVhdl = val
        elif type.lower() == "binary":
            if val[:val.index("'b")] == "1":
                valVhdl = "'%s'" % val[val.index("'b") + 2:]
            else:
                valVhdl = '"%s"' % val[val.index("'b") + 2:]
        elif type.lower() == "hex":
            numBits = int(val[:val.index("'h")])
            # if the number of bits is a multiple of 4 then use the x"123" notation, otherwise just convert to binary
            if numBits % 4 != 0 or CONVERT_ALL_HEX_TO_BINARY:
                valHex = int(val[val.index("'h") + 2:], base=16)
                binStr = bin(valHex)[2:].zfill(numBits)
                valVhdl = '"%s"' % binStr
            else:
                valVhdl = 'x"%s"' % val[val.index("'h") + 2:]
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

    print("======================== special properties ========================")

    if mgtType == "gty":
        if txSyncType == "no":
            props["TXSYNC_MULTILANE"] = "'0'"
            props["TXSYNC_OVRD"] = "'0'"
            props["TXSYNC_SKIP_DA"] = "'0'"
        elif txSyncType == "multilane_auto":
            props["TXSYNC_MULTILANE"] = "'1'"
            props["TXSYNC_OVRD"] = "'0'"
            props["TXSYNC_SKIP_DA"] = "'0'"
        else:
            print('ERROR: unsupported tx_sync_type "%s" for MGT type "%s", supported types are: no, multilane_auto' % (txSyncType, mgtType))
            return

    if mgtType == "gth":
        if txSyncType == "no":
            props["TXSYNC_MULTILANE"] = "'0'"
            props["TXSYNC_OVRD"] = "'0'"
            props["TXSYNC_SKIP_DA"] = "'0'"
        elif txSyncType == "multilane_manual":
            props["TXSYNC_MULTILANE"] = "'0'"
            props["TXSYNC_OVRD"] = "'1'"
            props["TXSYNC_SKIP_DA"] = "'0'"
        else:
            print('ERROR: unsupported tx_sync_type "%s" for MGT type "%s", supported types are: no, multilane_auto' % (txSyncType, mgtType))
            return

    if rxSlideMode is not None:
        if rxSlideMode not in ["PCS", "PMA"]:
            print('ERROR: unsupported RX slide mode "%s", supported types are: PCS, PMA' % rxSlideMode)
            return
        props["RXSLIDE_MODE"] = '"%s"' % rxSlideMode

    # always single auto
    props["RXSYNC_MULTILANE"] = "'0'"
    props["RXSYNC_OVRD"] = "'0'"
    props["RXSYNC_SKIP_DA"] = "'0'"

    # always select programmable termination at 800mV trim
    props["RX_CM_SEL"] = "3"
    props["RX_CM_TRIM"] = "10"

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
            if name not in portBits:
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
            for i in range(len(bits) - 1, -1, -1):
                val += "%d" % bits[i]
            val += '"'

        ports[name] = val
        print("%s => %s" % (name, val))

    print("======================== updating VHDL ========================")

    vhdlFile = open(vhdlFName, "r")
    vhdl = ""
    r = re.compile(r'\s+(\S+)\s*=>\s*([^,]*),?.*\n') # used to parse mappings
    rVal = re.compile(r'=>\s*([^,\n]*)') # used to replace the value
    portSection = False

    skipped_keep_props = []
    skipped_qpll_props = []
    skipped_ports = []
    conflicting_qpll_props = []
    conflicting_qpll_ports = []
    updated_props = []
    updated_ports = []

    lineNum = 1
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
            if "--" in line and "keep" in line:
                print("SKIPPING GENERIC %s due to 'keep' comment" % line)
                skipped_keep_props.append([name, val, props[name], lineNum])
                vhdl += line
                continue
            if (is_qpll0 and "QPLL1" in name) or (is_qpll1 and "QPLL0" in name):
                print("SKIPPING GENERIC %s because it does not belong to %s " % (line, mgtType))
                skipped_qpll_props.append([name, val, props[name], lineNum])
                vhdl += line
                continue
            if name not in props:
                print("ERROR: Unknown generic: %s" % name)
                print("Exiting...")
                return

            if (is_qpll0 or is_qpll1) and "QPLL0" not in name and "QPLL1" not in name and val != props[name]:
                print("ERROR: A common QPLL parameter has a different value than the props file, and we are only updating %s" % mgtType)
                print("VHDL file has %s => %s, while props file has value %s" % (name, val, props[name]))
                conflicting_qpll_props.append([name, val, props[name], lineNum])
                vhdl += line
                continue

            if val != props[name]:
                updated_props.append([name, val, props[name], lineNum])
            line = rVal.sub("=> " + props[name], line)
            # line = line.replace(val, props[name])

        # port
        else:
            # skip if the port isn't in the map, or it is not a constant in the original file
            if name not in ports or (("'" not in line and '"' not in line) or "&" in line) or \
               (is_qpll0 and "QPLL1" in name) or (is_qpll1 and "QPLL0" in name):

                newVal = "UNKNOWN" if name not in ports else ports[name]
                if len(newVal) > 40:
                    newVal = newVal[:40] + " TRUNCATED"
                skipped_ports.append([name, val, newVal, lineNum])
                vhdl += line
                continue

            if (is_qpll0 or is_qpll1) and "QPLL0" not in name and "QPLL1" not in name and val != ports[name]:
                print("ERROR: A common QPLL port has a different value than the ports file, and we are only updating %s" % mgtType)
                print("VHDL file has %s => %s, while ports file has value %s" % (name, val, ports[name]))
                conflicting_qpll_ports.append([name, val, ports[name], lineNum])
                vhdl += line
                continue

            if val != ports[name]:
                updated_ports.append([name, val, ports[name], lineNum])
            line = rVal.sub("=> " + ports[name], line)
            # line = line.replace(val, ports[name])

        vhdl += line
        lineNum += 1

    vhdlFile.close()

    if len(conflicting_qpll_ports) > 0:
        print_red("ERROR, there are conflicting common QPLL0/QPLL1 paramters:")
        printSkipped(conflicting_qpll_props)
        print_red("ERROR, there are conflicting common QPLL0/QPLL1 ports:")
        printSkipped(conflicting_qpll_ports)
        print("Would have updated these properties:")
        printSkipped(updated_props)
        print("Would have updated these ports:")
        printSkipped(updated_ports)
        print_red("FILE NOT UPDATED")
        return

    vhdlOutFile = open(outFName, "w")
    vhdlOutFile.write(vhdl)
    vhdlOutFile.close()

    # print(vhdl)

    print("")
    print('============================ UPDATED PORTS ============================')
    printSkipped(updated_ports)
    print('============================ UPDATED PROPERTIES ============================')
    printSkipped(updated_props)
    print('============================ SKIPPED PORTS ============================')
    printSkipped(skipped_ports)
    print('============================ SKIPPED PROPERTIES DUE TO "KEEP" COMMENT ============================')
    printSkipped(skipped_keep_props)
    print('============================ SKIPPED PROPERTIES DUE TO BELONGING TO ANOTHER QPLL ============================')
    printSkipped(skipped_qpll_props)

def printSkipped(skipped):
    cols = ["Name", "Original Value", "Value in port/props file", "VHDL line num"]
    print(tf.generate_table(skipped, cols))

if __name__ == '__main__':
    main()
