from common.rw_reg import *
from os import path
import struct
from common.utils import *

MAX_FW_SIZE = 16000000

def bytesToWord(bytes, idx):
    return (bytes[idx + 3] << 24) | (bytes[idx + 2] << 16) | (bytes[idx + 1] << 8) | (bytes[idx])
    # return (bytes[idx + 0] << 24) | (bytes[idx + 1] << 16) | (bytes[idx + 2] << 8) | (bytes[idx + 3])

# if promless_type is supplied, it will be appended to the PROMLESS node name in the address table (it's only used in CSC) e.g. if promless_type=ALCT, the function will use BEFE.PROMLESS_ALCT....
def promless_load(bitfile_name, verify=True, promless_type=None):

    node_suffix = ""
    if promless_type is not None and len(promless_type > 0):
        node_suffix = "_" + promless_type

    fname = bitfile_name
    if not path.exists(fname):
        printRed("Could not find %s" % fname)
        return

    write_reg(get_node("BEFE.PROMLESS%s.RESET_ADDR" % node_suffix), 1)

    print("Opening firmware bitstream file %s" % fname)
    f = open(fname, "rb")

    dataStr = f.read(MAX_FW_SIZE)
    bytes = struct.unpack("%dB" % len(dataStr), dataStr)

    f.close()

    if len(bytes) == MAX_FW_SIZE:
        print("ERROR: The file seems too big, check if you gave the correct filename, or change MAX_FW_SIZE const in the script..")
        return

    if len(bytes) % 4 != 0:
        print("Appending %d zero bytes at the end to make it divisible by 32bit words" % (len(bytes) % 4))
        for i in range(len(bytes) % 4):
            bytes = bytes + (0,)

    numWords = int(len(bytes) / 4)

    print("Firmware bitstream size: %d bytes (%d words):" % (len(bytes), numWords))

    print("Writing PROMless firmware...")
    wDataAddr = get_node("BEFE.PROMLESS%s.WRITE_DATA" % node_suffix).address
    for i in range(numWords):
        bidx = i * 4
        word = bytesToWord(bytes, bidx)
        wReg(wDataAddr, word)

    write_reg(get_node("BEFE.PROMLESS%s.FIRMWARE_SIZE" % node_suffix), len(bytes))
    fw_flavor = read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
    if fw_flavor.to_string() == "GEM":
        write_reg(get_node("BEFE.GEM.GEM_SYSTEM.PROMLESS%s.FIRMWARE_SIZE" % node_suffix), len(bytes))
    elif fw_flavor.to_string() == "CSC_FED":
        write_reg(get_node("BEFE.CSC_FED.CSC_SYSTEM.PROMLESS%s.FIRMWARE_SIZE" % node_suffix), len(bytes))
    else:
        printRed("Unknown firmware flavor (%s), firmware size is not set in the promless loader (normally BEFE.GEM.GEM_SYSTEM.PROMLESS.FIRMWARE_SIZE or BEFE.CSC_FED.CSC_SYSTEM.PROMLESS.FIRMWARE_SIZE)" % fw_flavor.to_string(False))

    if verify:
        print("Verifying PROMless firmware...")
        rDataAddr = get_node("BEFE.PROMLESS%s.READ_DATA" % node_suffix).address
        for i in range(numWords):
            wordReadback = rReg(rDataAddr)
            bidx = i * 4
            wordExpect = bytesToWord(bytes, bidx)
            if wordReadback != wordExpect:
                print_red("ERROR: word %d is corrupted, readback value = %s, expected value = %s" % (i, hex(wordReadback), hex(wordExpect)))
                return

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: promless_load.py <frontend_bitfile> [promless_type]")
        print("    promless_type: in csc it's used to select either cfeb or alct promless block")
        exit()

    fname = sys.argv[1]

    promless_type = None
    if len(sys.argv) > 2:
        promless_type = sys.argv[2]

    parse_xml()
    promless_load(fname, promless_type=promless_type)
