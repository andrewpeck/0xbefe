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

def box(df, xCol, yCol, xMin, xMax, xBinStep, title, showfliers=False):
    bins = np.arange(xMin, xMax, xBinStep)
    labels = []
    for i in range(bins.size-1):
        labels.append("%.2f" % ((bins[i] + bins[i+1]) / 2))
    df["bins"] = pd.cut(df[xCol], bins=bins, labels=labels)
    df.boxplot(column=yCol, by="bins", rot=90, showmeans=True, showfliers=showfliers)
    plt.title(title)

def main():

    if len(sys.argv) < 1:
        print('Usage: plot_result.py <parsed_csv_file>')
        return

    df = pd.read_csv(sys.argv[1])

    # add gem local coords
    # df["gem_eta"] = df["gem_vfat"].floordiv(3)
    # df["gem_eta"] = df["gem_vfat"].mod(8)

    # select layer
    # df = df[df.gem_layer == 1]

    # plot
    df.hist(column="gem_bx", bins=range(16))
    df.plot(x="csc_wg", y="gem_vfat", style=".", title="csc wiregroup vs vfat")
    df.plot(x="csc_wg", y="gem_eta", style=".", title="csc wiregroup vs gem_eta")
    df.plot(x="csc_hs", y="gem_phi", style=".", title="gem local phi vs ME1/1-B halfstrip", xlim=(0, 127))
    df.plot(x="csc_hs", y="gem_phi", style=".", title="gem local phi vs ME1/1-A halfstrip", xlim=(128, 223))
    box(df, "csc_wg", "gem_eta", 0, 46, 5, "gem_eta vs csc wiregroup")
    box(df, "csc_hs", "gem_phi", 0, 127, 10, "gem_phi vs ME1/1-B halfstrip")
    box(df, "csc_hs", "gem_phi", 128, 223, 10, "gem_phi vs ME1/1-A halfstrip")

    df.hist(column="gem_size")

    plt.show()

if __name__ == '__main__':
    main()
