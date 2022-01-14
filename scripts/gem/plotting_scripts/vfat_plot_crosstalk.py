from gem.gem_utils import *
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import numpy as np
import os, sys, glob
import argparse

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Plotting VFAT Cross Talk")
    parser.add_argument("-f", "--filename", action="store", dest="filename", help="Cross talk result filename")
    args = parser.parse_args()

    directoryName        = args.filename.split(".txt")[0]
    plot_filename_prefix = (directoryName.split("/"))[3]
    oh = plot_filename_prefix.split("_vfat")[0]
    file = open(args.filename)

    try:
        os.makedirs(directoryName) # create directory for scurve analysis results
    except FileExistsError: # skip if directory already exists
        pass
        
    hitmap_result = {}
    for line in file.readlines():
        if "vfat" in line:
            continue
        vfat = int(line.split()[0])
        channel_inj = int(line.split()[1])
        channel_read = int(line.split()[2])
        fired = int(line.split()[3])
        events = int(line.split()[4])
        if vfat not in hitmap_result:
            hitmap_result[vfat] = {}
        if channel_inj not in hitmap_result[vfat]:
            hitmap_result[vfat][channel_inj] = {}
        hitmap_result[vfat][channel_inj][channel_read] = {}
        if fired == -9999 or events == -9999 or events == 0:
            hitmap_result[vfat][channel_inj][channel_read] = 0
        else:
            hitmap_result[vfat][channel_inj][channel_read] = float(fired)/float(events)
    file.close()

    numVfats = len(hitmap_result.keys())
    if numVfats == 1:
        fig1, ax1 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        plot1 = 0
    elif numVfats <= 3:
        fig1, ax1 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        plot1 = {}
    elif numVfats <= 6:
        fig1, ax1 = plt.subplots(2, 3, figsize=(30,20))
        plot1 = {}
    elif numVfats <= 12:
        fig1, ax1 = plt.subplots(2, 6, figsize=(60,20))
        plot1 = {}
    elif numVfats <= 18:
        fig1, ax1 = plt.subplots(3, 6, figsize=(60,30))
        plot1 = {}
    elif numVfats <= 24:
        fig1, ax1 = plt.subplots(4, 6, figsize=(60,40))
        plot1 = {}

    vfatCnt0 = 0
    for vfat in hitmap_result:
        plot_data = []
        for x in range(0,128):
            data = []
            for y in range(0,128):
                data.append(hitmap_result[vfat][y][x])
            plot_data.append(data)

        fig, axs = plt.subplots()
        axs.set_xlabel("Channel Injected")
        axs.set_ylabel("Channel Read")
        axs.set_xlim(0,128)
        axs.set_ylim(0,128)
        plot = axs.imshow(plot_data, cmap="jet")
        fig.colorbar(plot, ax=axs)
        axs.set_title("VFAT# %02d"%vfat)
        fig.savefig((directoryName+"/crosstalk_"+oh+"_VFAT%02d.pdf")%vfat)
        plt.close(fig)

        if numVfats == 1:
            ax1.set_xlabel("Channel Injected")
            ax1.set_ylabel("Channel Read")
            ax1.set_title("VFAT# %02d"%vfat)
            ax1.set_xlim(0,128)
            ax1.set_ylim(0,128)
            plot1 = ax1.imshow(plot_data, cmap="jet")
            fig1.colorbar(plot1, ax=ax1)
        elif numVfats <= 3:
            ax1[vfatCnt0].set_xlabel("Channel Injected")
            ax1[vfatCnt0].set_ylabel("Channel Read")
            ax1[vfatCnt0].set_title("VFAT# %02d"%vfat)
            ax1[vfatCnt0].set_xlim(0,128)
            ax1[vfatCnt0].set_ylim(0,128)
            plot1[vfatCnt0] = ax1[vfatCnt0].imshow(plot_data, cmap="jet")
            fig1.colorbar(plot1[vfatCnt0], ax=ax1[vfatCnt0])
        elif numVfats <= 6:
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Channel Injected")
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("Channel Read")
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_title("VFAT# %02d"%vfat)
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_xlim(0,128)
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_ylim(0,128)
            plot1[int(vfatCnt0/3), vfatCnt0%3] = ax1[int(vfatCnt0/3), vfatCnt0%3].imshow(plot_data, cmap="jet")
            fig1.colorbar(plot1[int(vfatCnt0/3), vfatCnt0%3], ax=ax1[int(vfatCnt0/3), vfatCnt0%3])
        else:
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Channel Injected")
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("Channel Read")
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_title("VFAT# %02d"%vfat)
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_xlim(0,128)
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_ylim(0,128)
            plot1[int(vfatCnt0/6), vfatCnt0%6] = ax1[int(vfatCnt0/6), vfatCnt0%6].imshow(plot_data, cmap="jet")
            fig1.colorbar(plot1[int(vfatCnt0/6), vfatCnt0%6], ax=ax1[int(vfatCnt0/6), vfatCnt0%6])

        vfatCnt0+=1

    fig1.tight_layout()
    fig1.savefig((directoryName+"/crosstalk_"+oh+".pdf"))
    plt.close(fig1)
