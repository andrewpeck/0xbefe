from gem.gem_utils import *
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib import cm
import numpy as np
import os, sys, glob
import argparse

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Plotting VFAT Sbit Cluster Noise Rate")
    parser.add_argument("-f", "--filename", action="store", dest="filename", help="Noise rate result filename")
    args = parser.parse_args()

    directoryName        = args.filename.split(".txt")[0]
    plot_filename_prefix = (directoryName.split("/"))[2]
    oh = plot_filename_prefix.split("_vfat")[0]
    file = open(args.filename)

    plt.rcParams.update({'font.size': 22})

    try:
        os.makedirs(directoryName) # create directory for scurve noise rate results
    except FileExistsError: # skip if directory already exists
        pass
        
    noise_result = {}
    time = 0
    for line in file.readlines():
        if "vfat" in line:
            continue
        vfat = int(line.split()[0])
        sbit = line.split()[1]
        if sbit != "all":
            sbit = int(sbit)
        thr = int(line.split()[2])
        fired = int(line.split()[3])
        time = float(line.split()[4])
        if vfat not in noise_result:
            noise_result[vfat] = {}
        if sbit not in noise_result[vfat]:
            noise_result[vfat][sbit] = {}
        if fired == -9999:
            noise_result[vfat][sbit][thr] = 0
        else:
            noise_result[vfat][sbit][thr] = fired
    file.close()

    numVfats = len(noise_result.keys())
    if numVfats <= 3:
        fig1, ax1 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        fig3, ax3 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
    elif numVfats <= 6:
        fig1, ax1 = plt.subplots(2, 3, figsize=(30,20))
        fig3, ax3 = plt.subplots(2, 3, figsize=(30,20))
    elif numVfats <= 12:
        fig1, ax1 = plt.subplots(2, 6, figsize=(60,20))
        fig3, ax3 = plt.subplots(2, 6, figsize=(60,20))
    elif numVfats <= 18:
        fig1, ax1 = plt.subplots(3, 6, figsize=(60,30))
        fig3, ax3 = plt.subplots(3, 6, figsize=(60,30))
    elif numVfats <= 24:
        fig1, ax1 = plt.subplots(4, 6, figsize=(60,40))
        fig3, ax3 = plt.subplots(4, 6, figsize=(60,40))

    vfatCnt0 = 0
    for vfat in noise_result:
        print ("Creating plots for VFAT %02d"%vfat)
        threshold = []
        noise_rate = []
        noise_rate_avg = []
        n_sbits = 0

        for thr in noise_result[vfat]["all"]:
            threshold.append(thr)
            noise_rate.append(noise_result[vfat]["all"][thr]/time)
            noise_rate_avg.append(0)
        for sbit in noise_result[vfat]:
            if sbit == "all":
                continue
            nsbits += 1
            for i in range(0,len(threshold)):
                thr = threshold[i]
                noise_rate_avg[i] += noise_result[vfat][sbit][thr]/time
        noise_rate_avg = [noise/nsbits for noise in noise_rate_avg]

        if numVfats == 1:
            ax1.set_xlabel("Threshold (DAC)")
            ax1.set_ylabel("SBit Rate (Hz)")
            ax1.set_yscale("log")
            ax1.set_title("Total S-Bit Rate for VFAT# %02d"%vfat)
            ax1.grid()
            ax1.plot(threshold, noise_rate, "o", markersize=12)
            ax3.set_xlabel("Threshold (DAC)")
            ax3.set_ylabel("SBit Rate (Hz)")
            ax3.set_yscale("log")
            ax3.set_title("Average S-Bit Rate for VFAT# %02d"%vfat)
            ax3.grid()
            ax3.plot(threshold, noise_rate_avg, "o", markersize=12)
        elif numVfats <= 3:
            ax1[vfatCnt0].set_xlabel("Threshold (DAC)")
            ax1[vfatCnt0].set_ylabel("SBit Rate (Hz)")
            ax1[vfatCnt0].set_yscale("log")
            ax1[vfatCnt0].set_title("Total S-Bit Rate for VFAT# %02d"%vfat)
            ax1[vfatCnt0].grid()
            ax1[vfatCnt0].plot(threshold, noise_rate, "o", markersize=12)
            ax3[vfatCnt0].set_xlabel("Threshold (DAC)")
            ax3[vfatCnt0].set_ylabel("SBit Rate (Hz)")
            ax3[vfatCnt0].set_yscale("log")
            ax3[vfatCnt0].set_title("Average S-Bit Rate for VFAT# %02d"%vfat)
            ax3[vfatCnt0].grid()
            ax3[vfatCnt0].plot(threshold, noise_rate_avg, "o", markersize=12)
        elif numVfats <= 6:
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Threshold (DAC)")
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("SBit Rate (Hz)")
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_yscale("log")
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_title("Total S-Bit Rate for VFAT# %02d"%vfat)
            ax1[int(vfatCnt0/3), vfatCnt0%3].grid()
            ax1[int(vfatCnt0/3), vfatCnt0%3].plot(threshold, noise_rate, "o", markersize=12)
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Threshold (DAC)")
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("SBit Rate (Hz)")
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_yscale("log")
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_title("Average S-Bit Rate for VFAT# %02d"%vfat)
            ax3[int(vfatCnt0/3), vfatCnt0%3].grid()
            ax3[int(vfatCnt0/3), vfatCnt0%3].plot(threshold, noise_rate_avg, "o", markersize=12)
        else:
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Threshold (DAC)")
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("SBit Rate (Hz)")
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_yscale("log")
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_title("Total S-Bit Rate for VFAT# %02d"%vfat)
            ax1[int(vfatCnt0/6), vfatCnt0%6].grid()
            ax1[int(vfatCnt0/6), vfatCnt0%6].plot(threshold, noise_rate, "o", markersize=12)
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Threshold (DAC)")
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("SBit Rate (Hz)")
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_yscale("log")
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_title("Average S-Bit Rate for VFAT# %02d"%vfat)
            ax3[int(vfatCnt0/6), vfatCnt0%6].grid()
            ax3[int(vfatCnt0/6), vfatCnt0%6].plot(threshold, noise_rate_avg, "o", markersize=12)

        fig2, ax2 = plt.subplots(8, 8, figsize=(80,80))
        for sbit in noise_result[vfat]:
            if sbit == "all":
                continue
            noise_rate_sbit = []
            for thr in range(0,len(threshold)):
                noise_rate_sbit.append(noise_result[vfat][sbit][thr]/time)
            ax2[int(sbit/8), sbit%8].set_xlabel("Threshold (DAC)")
            ax2[int(sbit/8), sbit%8].set_ylabel("SBit Rate (Hz)")
            ax2[int(sbit/8), sbit%8].grid()

            y_not_all_zero = 0
            for y in noise_rate_sbit:
                if y!=0:
                    y_not_all_zero = 1
                    break
            if y_not_all_zero:
                ax2[int(sbit/8), sbit%8].set_yscale("log")
            ax2[int(sbit/8), sbit%8].plot(threshold, noise_rate_sbit, "o", markersize=12)
            #leg = ax.legend(loc="center right", ncol=2)
            ax2[int(sbit/8), sbit%8].set_title("VFAT# %02d, S-Bit# %02d"%(vfat, sbit))
        fig2.tight_layout()
        fig2.savefig((directoryName+"/sbit_noise_rate_channels_"+oh+"_VFAT%02d.pdf")%vfat)
        plt.close(fig2)

        vfatCnt0+=1

    fig1.tight_layout()
    fig1.savefig((directoryName+"/sbit_cluster_noise_rate_total_"+oh+".pdf"))
    plt.close(fig1)
    fig3.tight_layout()
    fig3.savefig((directoryName+"/sbit_cluster_noise_rate_average_"+oh+".pdf"))
    plt.close(fig3)







