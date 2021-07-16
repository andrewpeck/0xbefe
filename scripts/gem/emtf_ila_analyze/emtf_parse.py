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
        print('Usage: emtf_parse.py <ila_csv_dump_filename>')
        return

    f = open(sys.argv[1])

    csv_reader = csv.reader(f, delimiter=',')

    header = next(csv_reader)
    next(csv_reader) # Skip the type line

    df = pd.DataFrame(columns=["csc_bx", "csc_hs", "csc_wg", "gem_bx", "gem_layer", "gem_vfat", "gem_pad", "gem_size", "gem_eta", "gem_phi"])
    cl_i = 0

    evt_clusters = []
    evt_lct = {}

    for row in csv_reader:
        sample = -1
        clusters = []
        trigger = -1
        halfstrip = -1
        wiregroup = -1

        for i in range(len(header)):
            if "Sample in Window" in header[i]:
                sample = int(row[i])

            if "gem_rx_i/cluster[{}][0]".format(link) in header[i]:
                cluster = decode_cluster(int(row[i], 16))
                if (cluster != None):
                    clusters.append("layer = 0, VFAT = {}, pad = {}, size = {}".format(cluster["vfat"], cluster["pad"], cluster["size"] + 1))
                    cluster["bx"] = sample
                    cluster["layer"] = 0
                    evt_clusters.append(cluster)

            if "gem_rx_i/cluster[{}][1]".format(link) in header[i]:
                cluster = decode_cluster(int(row[i], 16))
                if (cluster != None):
                    clusters.append("layer = 1, VFAT = {}, pad = {}, size = {}".format(cluster["vfat"], cluster["pad"], cluster["size"] + 1))
                    cluster["bx"] = sample
                    cluster["layer"] = 1
                    evt_clusters.append(cluster)

            if "TRIGGER" in header[i]:
                trigger = int(row[i])

            if "dbg_ps/lct_sel[0][0][hs]" in header[i]:
                halfstrip = int(row[i], 16)

            if "dbg_ps/lct_sel[0][0][wg]" in header[i]:
                wiregroup = int(row[i], 16)

        if sample == 0:
            printWithColor("New event!", Colors.RED)

            for cl in evt_clusters:
                df.loc[cl_i] = {"csc_bx": evt_lct["bx"], "csc_hs": evt_lct["hs"], "csc_wg": evt_lct["wg"], "gem_bx": cl["bx"], "gem_layer": cl["layer"], "gem_vfat": cl["vfat"], "gem_pad": cl["pad"], "gem_size": cl["size"], "gem_eta": cl["eta"], "gem_phi": cl["phi"]}
                cl_i += 1

            evt_clusters = []
            evt_lct = {}

        if len(clusters) != 0:
            print("{:02} | {}".format(sample, " | ".join(clusters)))

        if trigger == 1:
            printWithColor("{:02} | ME1/1 LCT wiregroup = {}, halfstrip = {}".format(sample, wiregroup, halfstrip), Colors.GREEN)
            evt_lct["bx"] = sample
            evt_lct["hs"] = halfstrip
            evt_lct["wg"] = wiregroup

    f.close()

    df.to_csv("parsed_%s" % sys.argv[1])

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
