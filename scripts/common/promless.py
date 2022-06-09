from common.rw_reg import *
from os import path
import struct
from common.utils import *

MAX_FW_SIZE = 16000000

def bytesToWord(bytes, idx):
    return (bytes[idx + 3] << 24) | (bytes[idx + 2] << 16) | (bytes[idx + 1] << 8) | (bytes[idx])
    # return (bytes[idx + 0] << 24) | (bytes[idx + 1] << 16) | (bytes[idx + 2] << 8) | (bytes[idx + 3])

def promless_load(bitfile_name, verify=True):

    fname = bitfile_name
    if not path.exists(fname):
        printRed("Could not find %s" % fname)
        return

    write_reg(get_node("BEFE.PROMLESS.RESET_ADDR"), 1)

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
    wDataAddr = get_node("BEFE.PROMLESS.WRITE_DATA").address
    for i in range(numWords):
        bidx = i * 4
        word = bytesToWord(bytes, bidx)
        wReg(wDataAddr, word)

    write_reg(get_node("BEFE.PROMLESS.FIRMWARE_SIZE"), len(bytes))
    fw_flavor = read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
    if fw_flavor.to_string() == "GEM":
        write_reg(get_node("BEFE.GEM.GEM_SYSTEM.PROMLESS.FIRMWARE_SIZE"), len(bytes))
    elif fw_flavor.to_string() == "CSC_FED":
        write_reg(get_node("BEFE.CSC_FED.CSC_SYSTEM.PROMLESS.FIRMWARE_SIZE"), len(bytes))
    else:
        printRed("Unknown firmware flavor (%s), firmware size is not set in the promless loader (normally BEFE.GEM.GEM_SYSTEM.PROMLESS.FIRMWARE_SIZE or BEFE.CSC_FED.CSC_SYSTEM.PROMLESS.FIRMWARE_SIZE)" % fw_flavor.to_string(False))

    if verify:
        print("Verifying PROMless firmware...")
        rDataAddr = get_node("BEFE.PROMLESS.READ_DATA").address
        for i in range(numWords):
            wordReadback = rReg(rDataAddr)
            bidx = i * 4
            wordExpect = bytesToWord(bytes, bidx)
            if wordReadback != wordExpect:
                print_red("ERROR: word %d is corrupted, readback value = %s, expected value = %s" % (i, hex(wordReadback), hex(wordExpect)))
                return

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: promless_load.py <frontend_bitfile>")
        exit()

    parse_xml()
    promless_load(sys.argv[1])
