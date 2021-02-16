from rw_reg import *
from os import path
import struct
from utils import *

MAX_FW_SIZE = 16000000

def bytesToWord(bytes, idx):
    return (bytes[idx + 3] << 24) | (bytes[idx + 2] << 16) | (bytes[idx + 1] << 8) | (bytes[idx])
    # return (bytes[idx + 0] << 24) | (bytes[idx + 1] << 16) | (bytes[idx + 2] << 8) | (bytes[idx + 3])

def main():

    if len(sys.argv) < 2:
        print("Usage: promless_load.py <frontend_bitfile>")
        return

    parseXML()

    fname = sys.argv[1]
    if not path.exists(fname):
        print("Could not find %s" % fname)
        return

    writeReg(getNode("GEM_AMC.PROMLESS.RESET_ADDR"), 1)

    print("Opening file %s" % fname)
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

    print("Got %d bytes (%d words):" % (len(bytes), numWords))

    print("Writing...")
    wDataAddr = getNode("GEM_AMC.PROMLESS.WRITE_DATA").real_address
    for i in xrange(numWords):
        bidx = i * 4
        word = bytesToWord(bytes, bidx)
        wReg(wDataAddr, word)

    writeReg(getNode("GEM_AMC.PROMLESS.FIRMWARE_SIZE"), len(bytes))
    writeReg(getNode("GEM_AMC.GEM_SYSTEM.GEM_LOADER.FIRMWARE_SIZE"), len(bytes))

    print("Verifying...")
    rDataAddr = getNode("GEM_AMC.PROMLESS.READ_DATA").real_address
    for i in xrange(numWords):
        wordReadback = rReg(rDataAddr)
        bidx = i * 4
        wordExpect = bytesToWord(bytes, bidx)
        if wordReadback != wordExpect:
            printRed("ERROR: word %d is corrupted, readback value = %s, expected value = %s" % (i, hex(wordReadback), hex(wordExpect)))
            return

if __name__ == '__main__':
    main()
