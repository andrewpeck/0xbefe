#!/bin/env python3

import sys
import csv

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

link = 3

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

def printWithColor(string, color):
    print(color + string + Colors.ENDC)

def hex_padded(number, numBytes):
    if number is None:
        return 'None'
    else:
        return "{0:#0{1}x}".format(number, int(numBytes * 2) + 2)

def main():

    if len(sys.argv) < 1:
        print('Usage: emtf_parse_new.py <ila_csv_dump_filename>')
        return

    f = open(sys.argv[1])

    csv_reader = csv.reader(f, delimiter=',')

    header = next(csv_reader)
    next(csv_reader) # Skip the type line

    for row in csv_reader:
        bx = int(row[header.index("Sample in Window")])
        for chamber in range(3):
            eta = int(row[header.index("dbg_ps/ge11_sel[%d][prt][2:0]" % chamber)], 16)
            phi = int(row[header.index("dbg_ps/ge11_sel[%d][str][7:0]" % chamber)], 16)
            size = int(row[header.index("dbg_ps/ge11_sel[%d][csz][2:0]" % chamber)], 16)
            if phi != 0xff:
                print("BX %d: chamber %d, eta %d, phi %d, size %d" % (bx, chamber, eta, phi, size))

    f.close()

def decode_cluster(data):
    ret = {}
    ret["size"] = (data >> 11) & 0x7
    address = data & 0x7ff
    ret["vfat"] = address // 64
    ret["pad"] = address % 64
    ret["phi"] = address % 192
    ret["eta"] = ret["vfat"] // 3
    if (address > 1536):
        return None
    else:
        return ret
        # return "VFAT = {}, pad = {}, size = {}".format(vfat, pad, size + 1)

if __name__ == '__main__':
    main()
