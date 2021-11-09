from gem.gem_utils import *
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib import cm
import numpy as np
import os, sys, glob
import argparse
import pandas as pd

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Plotting VFAT Sbit Noise Rate")
    parser.add_argument("-f", "--filename", action="store", dest="filename", help="Noise rate result filename")
    args = parser.parse_args()

    directoryName        = args.filename.split(".txt")[0]
    plot_filename_prefix = (directoryName.split("/"))[3]
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
        if sbit!="all":
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
        fig4, ax4 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
    elif numVfats <= 6:
        fig1, ax1 = plt.subplots(2, 3, figsize=(30,20))
        fig3, ax3 = plt.subplots(2, 3, figsize=(30,20))
        fig4, ax4 = plt.subplots(2, 3, figsize=(30,20))
    elif numVfats <= 12:
        fig1, ax1 = plt.subplots(2, 6, figsize=(60,20))
        fig3, ax3 = plt.subplots(2, 6, figsize=(60,20))
        fig4, ax4 = plt.subplots(2, 6, figsize=(60,20))
    elif numVfats <= 18:
        fig1, ax1 = plt.subplots(3, 6, figsize=(60,30))
        fig3, ax3 = plt.subplots(3, 6, figsize=(60,30))
        fig4, ax4 = plt.subplots(3, 6, figsize=(60,30))
    elif numVfats <= 24:
        fig1, ax1 = plt.subplots(4, 6, figsize=(60,40))
        fig3, ax3 = plt.subplots(4, 6, figsize=(60,40))
        fig4, ax4 = plt.subplots(4, 6, figsize=(60,40))

    vfatCnt0 = 0
    for vfat in noise_result:
        print ("Creating plots for VFAT %02d"%vfat)

        threshold = []
        noise_rate = []
        noise_rate_vfat = []
        n_sbits = 0

        for sbit in noise_result[vfat]:
            for thr in noise_result[vfat][sbit]:
                threshold.append(thr)
                noise_rate.append(0)
                noise_rate_vfat.append(0)
            break
        for sbit in noise_result[vfat]:
            if sbit == "all":
                continue
            n_sbits += 1
            for i in range(0,len(threshold)):
                thr = threshold[i]
                noise_rate[i] += noise_result[vfat][sbit][thr]/time
        noise_rate_avg = [noise/n_sbits for noise in noise_rate]
        for i in range(0,len(threshold)):
            thr = threshold[i]
            noise_rate_vfat[i] += noise_result[vfat]["all"][thr]/time

        if numVfats == 1:
            ax1.set_xlabel("Threshold (DAC)", loc='right')
            ax1.set_ylabel("S-Bit rate (Hz)", loc='top')
            ax1.set_yscale("log")
            ax1.set_title("Total S-Bit rate for VFAT%02d" % vfat)
            ax1.grid()
            ax1.plot(threshold, noise_rate, "o", markersize=12)
            ax1.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax1.transAxes)
            ax1.text(-0.01, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax1.transAxes)
            ax3.set_xlabel("Threshold (DAC)", loc='right')
            ax3.set_ylabel("S-Bit rate (Hz)", loc='top')
            ax3.set_yscale("log")
            ax3.set_title("Avergae S-Bit rate for VFAT%02d"%vfat)
            ax3.grid()
            ax3.plot(threshold, noise_rate_avg, "o", markersize=12)
            ax3.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax3.transAxes)
            ax3.text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax3.transAxes)
            ax4.set_xlabel("Threshold (DAC)", loc='right')
            ax4.set_ylabel("S-Bit rate (Hz)", loc='top')
            ax4.set_yscale("log")
            ax4.set_title("OR S-Bit rate for VFAT%02d"%vfat)
            ax4.grid()
            ax4.plot(threshold, noise_rate_vfat, "o", markersize=12)
            ax4.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax4.transAxes)
            ax4.text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax4.transAxes)
        elif numVfats <= 3:
            ax1[vfatCnt0].set_xlabel("Threshold (DAC)", loc='right')
            ax1[vfatCnt0].set_ylabel("S-Bit rate (Hz)", loc='top')
            ax1[vfatCnt0].set_yscale("log")
            ax1[vfatCnt0].set_title("Total S-Bit rate for VFAT%02d" % vfat)
            ax1[vfatCnt0].grid()
            ax1[vfatCnt0].plot(threshold, noise_rate, "o", markersize=12)
            ax1[vfatCnt0].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax1[vfatCnt0].transAxes)
            ax1[vfatCnt0].text(-0.01, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax1[vfatCnt0].transAxes)
            ax3[vfatCnt0].set_xlabel("Threshold (DAC)", loc='right')
            ax3[vfatCnt0].set_ylabel("S-Bit Rate (Hz)", loc='top')
            ax3[vfatCnt0].set_yscale("log")
            ax3[vfatCnt0].set_title("Average S-Bit rate for VFAT%02d"%vfat)
            ax3[vfatCnt0].grid()
            ax3[vfatCnt0].plot(threshold, noise_rate_avg, "o", markersize=12)
            ax3[vfatCnt0].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=24, transform=ax3[vfatCnt0].transAxes)
            ax3[vfatCnt0].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=22, transform=ax3[vfatCnt0].transAxes)
            ax4[vfatCnt0].set_xlabel("Threshold (DAC)", loc='right')
            ax4[vfatCnt0].set_ylabel("S-Bit Rate (Hz)", loc='top')
            ax4[vfatCnt0].set_yscale("log")
            ax4[vfatCnt0].set_title("OR S-Bit rate for VFAT%02d"%vfat)
            ax4[vfatCnt0].grid()
            ax4[vfatCnt0].plot(threshold, noise_rate_vfat, "o", markersize=12)
            ax4[vfatCnt0].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=24, transform=ax4[vfatCnt0].transAxes)
            ax4[vfatCnt0].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=22, transform=ax4[vfatCnt0].transAxes)
        elif numVfats <= 6:
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Threshold (DAC)", loc='right')
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("S-Bit rate (Hz)", loc='top')
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_yscale("log")
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_title("Total S-Bit rate for VFAT%02d"%vfat)
            ax1[int(vfatCnt0/3), vfatCnt0%3].grid()
            ax1[int(vfatCnt0/3), vfatCnt0%3].plot(threshold, noise_rate, "o", markersize=12)
            ax1[int(vfatCnt0/3), vfatCnt0%3].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax1[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax1[int(vfatCnt0/3), vfatCnt0%3].text(-0.01, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax1[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Threshold (DAC)", loc='right')
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("S-Bit rate (Hz)", loc='top')
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_yscale("log")
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_title("Average S-Bit rate for VFAT%02d"%vfat)
            ax3[int(vfatCnt0/3), vfatCnt0%3].grid()
            ax3[int(vfatCnt0/3), vfatCnt0%3].plot(threshold, noise_rate_avg, "o", markersize=12)
            ax3[int(vfatCnt0/3), vfatCnt0%3].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax3[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax3[int(vfatCnt0/3), vfatCnt0%3].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax3[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax4[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Threshold (DAC)", loc='right')
            ax4[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("S-Bit rate (Hz)", loc='top')
            ax4[int(vfatCnt0/3), vfatCnt0%3].set_yscale("log")
            ax4[int(vfatCnt0/3), vfatCnt0%3].set_title("OR S-Bit rate for VFAT%02d"%vfat)
            ax4[int(vfatCnt0/3), vfatCnt0%3].grid()
            ax4[int(vfatCnt0/3), vfatCnt0%3].plot(threshold, noise_rate_vfat, "o", markersize=12)
            ax4[int(vfatCnt0/3), vfatCnt0%3].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax4[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax4[int(vfatCnt0/3), vfatCnt0%3].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax4[int(vfatCnt0/3), vfatCnt0%3].transAxes)
        else:
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Threshold (DAC)", loc='right')
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("S-Bit rate (Hz)", loc='top')
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_yscale("log")
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_title("Total S-Bit rate for VFAT%02d"%vfat)
            ax1[int(vfatCnt0/6), vfatCnt0%6].grid()
            ax1[int(vfatCnt0/6), vfatCnt0%6].plot(threshold, noise_rate, "o", markersize=12)
            ax1[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax1[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax1[int(vfatCnt0/6), vfatCnt0%6].text(-0.01, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax1[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Threshold (DAC)", loc='right')
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("S-Bit rate (Hz)", loc='top')
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_yscale("log")
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_title("Average S-Bit rate for VFAT%02d"%vfat)
            ax3[int(vfatCnt0/6), vfatCnt0%6].grid()
            ax3[int(vfatCnt0/6), vfatCnt0%6].plot(threshold, noise_rate_avg, "o", markersize=12)
            ax3[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=25, transform=ax3[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax3[int(vfatCnt0/6), vfatCnt0%6].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=23, transform=ax3[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax4[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Threshold (DAC)", loc='right')
            ax4[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("S-Bit rate (Hz)", loc='top')
            ax4[int(vfatCnt0/6), vfatCnt0%6].set_yscale("log")
            ax4[int(vfatCnt0/6), vfatCnt0%6].set_title("OR S-Bit rate for VFAT%02d"%vfat)
            ax4[int(vfatCnt0/6), vfatCnt0%6].grid()
            ax4[int(vfatCnt0/6), vfatCnt0%6].plot(threshold, noise_rate_vfat, "o", markersize=12)
            ax4[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=25, transform=ax4[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax4[int(vfatCnt0/6), vfatCnt0%6].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=23, transform=ax4[int(vfatCnt0/6), vfatCnt0%6].transAxes)

        fig2, ax2 = plt.subplots(8, 8, figsize=(80,80))
        for sbit in noise_result[vfat]:
            if sbit=="all":
                continue
            noise_rate_sbit = []
            for thr in range(0,len(threshold)):
                noise_rate_sbit.append(noise_result[vfat][sbit][thr]/time)
            ax2[int(sbit/8), sbit%8].set_xlabel("Threshold (DAC)", loc='right')
            ax2[int(sbit/8), sbit%8].set_ylabel("S-Bit rate (Hz)", loc='top')
            ax2[int(sbit/8), sbit%8].set_yscale("log")
            ax2[int(sbit/8), sbit%8].grid()
            ax2[int(sbit/8), sbit%8].plot(threshold, noise_rate_sbit, "o", markersize=12)
            #leg = ax.legend(loc="center right", ncol=2)
            ax2[int(sbit/8), sbit%8].set_title("VFAT%02d, S-Bit %02d"%(vfat, sbit))
            ax2[int(sbit/8), sbit%8].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax2[int(sbit/8), sbit%8].transAxes)
            ax2[int(sbit/8), sbit%8].text(-0.01, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax2[int(sbit/8), sbit%8].transAxes)
            
        #ax2.text(-0.14, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax2.transAxes)
        #ax2.text(0.03, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax2.transAxes)
        fig2.tight_layout()
        fig2.savefig((directoryName+"/sbit_noise_rate_channels_"+oh+"_VFAT%02d.pdf")%vfat)
        plt.close(fig2)

        vfatCnt0+=1

    fig1.tight_layout()
    fig1.savefig((directoryName+"/sbit_noise_rate_total_"+oh+".pdf"))
    plt.close(fig1)
    fig3.tight_layout()
    fig3.savefig((directoryName+"/sbit_noise_rate_average_"+oh+".pdf"))
    plt.close(fig3)
    fig4.tight_layout()
    fig4.savefig((directoryName+"/sbit_noise_rate_or_"+oh+".pdf"))
    plt.close(fig4)
    print(Colors.GREEN + 'Plots stored at %s' % directoryName + Colors.ENDC)






