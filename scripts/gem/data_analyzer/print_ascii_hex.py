#!/usr/bin/env python

from utils import *
import signal
import sys
import os
import fnmatch
import struct
import zlib
import math
import analyze_events
from enum import Enum

def main():

    rawFilename = ""

    if len(sys.argv) < 2:
        print('Usage: print_ascii_hex.py <gem_raw_file>')
        print('This program simply prints a given binary file in a nicely formatted hex ascii with 64bit word size and correct endian-ness for easy reading')
        return
    else:
        rawFilename = sys.argv[1]

    print("Opening file: %s" % rawFilename)
    f = open(rawFilename, 'rb')
    fileSize = os.fstat(f.fileno()).st_size
    print("file size: %d" % fileSize)

    fedData = f.read(fileSize)
    printHexBlock64BigEndian(fedData, fileSize)

    print("DONE")
    f.close()

def printHexBlock64BigEndian(str, length):
    fedBytes = struct.unpack("%dB" % length, str)
    # print "length: %d, str length: %d, num of 8 byte words: %d" % (len(fedBytes), len(str), int(math.ceil(length / 8.0)))
    for i in range(0, int(math.ceil(length / 8.0))):
        idx = i * 8
        sys.stdout.write("{0:#0{1}x}: ".format(idx, 4 + 2))
        # sys.stdout.write("%d: " % idx)
        for j in range(0, 8):
            if (i+1) * 8 - (j + 1) >= length:
                sys.stdout.write("-- ")
            else:
                sys.stdout.write("%s " % (format(fedBytes[(i+1) * 8 - (j + 1)], '02x')))
        sys.stdout.write('\n')
    sys.stdout.flush()

if __name__ == '__main__':
    main()
