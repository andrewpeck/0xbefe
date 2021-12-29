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
    if numVfats == 1:
        fig1, ax1 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        fig3, ax3 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        fig5, ax5 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        cf5 = 0
        cbar5 = 0
    elif numVfats <= 3:
        fig1, ax1 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        fig3, ax3 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        fig5, ax5 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        cf5 = {}
        cbar5 = {}
    elif numVfats <= 6:
        fig1, ax1 = plt.subplots(2, 3, figsize=(30,20))
        fig3, ax3 = plt.subplots(2, 3, figsize=(30,20))
        fig5, ax5 = plt.subplots(2, 3, figsize=(30,20))
        cf5 = {}
        cbar5 = {}
    elif numVfats <= 12:
        fig1, ax1 = plt.subplots(2, 6, figsize=(60,20))
        fig3, ax3 = plt.subplots(2, 6, figsize=(60,20))
        fig5, ax5 = plt.subplots(2, 6, figsize=(60,20))
        cf5 = {}
        cbar5 = {}
    elif numVfats <= 18:
        fig1, ax1 = plt.subplots(3, 6, figsize=(60,30))
        fig3, ax3 = plt.subplots(3, 6, figsize=(60,30))
        fig5, ax5 = plt.subplots(3, 6, figsize=(60,30))
        cf5 = {}
        cbar5 = {}
    elif numVfats <= 24:
        fig1, ax1 = plt.subplots(4, 6, figsize=(60,40))
        fig3, ax3 = plt.subplots(4, 6, figsize=(60,40))
        fig5, ax5 = plt.subplots(4, 6, figsize=(60,40))
        cf5 = {}
        cbar5 = {}

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
            n_sbits += 1
            for i in range(0,len(threshold)):
                thr = threshold[i]
                noise_rate_avg[i] += noise_result[vfat][sbit][thr]/time
        noise_rate_avg = [noise/n_sbits for noise in noise_rate_avg]

        map_plot_data = []
        map_plot_data_x = []
        map_plot_data_y = threshold
        z_max = 1
        for sbit in range(0,64):
            map_plot_data_x.append(sbit)
        for thr in range(0,len(threshold)):
            data = []
            for sbit in noise_result[vfat]:
                if sbit=="all":
                    continue
                data.append(noise_result[vfat][sbit][thr]/time)
                if (noise_result[vfat][sbit][thr]/time) > z_max:
                    z_max = noise_result[vfat][sbit][thr]/time
            map_plot_data.append(data)

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
            ax3.set_title("Mean S-Bit rate for VFAT%02d"%vfat)
            ax3.grid()
            ax3.plot(threshold, noise_rate_avg, "o", markersize=12)
            ax3.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax3.transAxes)
            ax3.text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax3.transAxes)
            ax5.set_xlabel("S-Bit", loc='right')
            ax5.set_ylabel("Threshold (DAC)")
            ax5.set_title("VFAT%02d"%vfat)
            cf5 = ax5.pcolormesh(map_plot_data_x, map_plot_data_y, map_plot_data, cmap=cm.ocean_r, shading="nearest", norm=mcolors.LogNorm(vmin=1, vmax=z_max))
            cbar5 = fig5.colorbar(cf5, ax=ax5, pad=0.01)
            cbar5.set_label("S-Bit rate (Hz)", loc='top')
            ax5.set_xticks(np.arange(0, 64, 20))
            ax5.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=20, transform=ax5.transAxes)
            ax5.text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=18, transform=ax5.transAxes)
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
            ax3[vfatCnt0].set_title("Mean S-Bit rate for VFAT%02d"%vfat)
            ax3[vfatCnt0].grid()
            ax3[vfatCnt0].plot(threshold, noise_rate_avg, "o", markersize=12)
            ax3[vfatCnt0].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=24, transform=ax3[vfatCnt0].transAxes)
            ax3[vfatCnt0].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=22, transform=ax3[vfatCnt0].transAxes)
            ax5[vfatCnt0].set_xlabel("S-Bit", loc='right')
            ax5[vfatCnt0].set_ylabel("Threshold (DAC)")
            ax5[vfatCnt0].set_title("VFAT%02d"%vfat)
            cf5[vfatCnt0] = ax5[vfatCnt0].pcolormesh(map_plot_data_x, map_plot_data_y, map_plot_data, cmap=cm.ocean_r, shading="nearest", norm=mcolors.LogNorm(vmin=1, vmax=z_max))
            cbar5[vfatCnt0] = fig5.colorbar(cf5[vfatCnt0], ax=ax5[vfatCnt0], pad=0.01)
            cbar5[vfatCnt0].set_label("S-Bit rate (Hz)", loc='top')
            ax5[vfatCnt0].set_xticks(np.arange(0, 64, 20))
            ax5[vfatCnt0].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=20, transform=ax5[vfatCnt0].transAxes)
            ax5[vfatCnt0].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=18, transform=ax5[vfatCnt0].transAxes)
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
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_title("Mean S-Bit rate for VFAT%02d"%vfat)
            ax3[int(vfatCnt0/3), vfatCnt0%3].grid()
            ax3[int(vfatCnt0/3), vfatCnt0%3].plot(threshold, noise_rate_avg, "o", markersize=12)
            ax3[int(vfatCnt0/3), vfatCnt0%3].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax3[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax3[int(vfatCnt0/3), vfatCnt0%3].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax3[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax5[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("S-Bit", loc='right')
            ax5[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("Threshold (DAC)")
            ax5[int(vfatCnt0/3), vfatCnt0%3].set_title("VFAT%02d"%vfat)
            cf5[int(vfatCnt0/3), vfatCnt0%3] = ax5[int(vfatCnt0/3), vfatCnt0%3].pcolormesh(map_plot_data_x, map_plot_data_y, map_plot_data, cmap=cm.ocean_r, shading="nearest", norm=mcolors.LogNorm(vmin=1, vmax=z_max))
            cbar5[int(vfatCnt0/3), vfatCnt0%3] = fig5.colorbar(cf5[int(vfatCnt0/3), vfatCnt0%3], ax=ax5[int(vfatCnt0/3), vfatCnt0%3], pad=0.01)
            cbar5[int(vfatCnt0/3), vfatCnt0%3].set_label("S-Bit rate (Hz)", loc='top')
            ax5[int(vfatCnt0/3), vfatCnt0%3].set_xticks(np.arange(0, 64, 20))
            ax5[int(vfatCnt0/3), vfatCnt0%3].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=20, transform=ax5[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax5[int(vfatCnt0/3), vfatCnt0%3].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=18, transform=ax5[int(vfatCnt0/3), vfatCnt0%3].transAxes)
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
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_title("Mean S-Bit rate for VFAT%02d"%vfat)
            ax3[int(vfatCnt0/6), vfatCnt0%6].grid()
            ax3[int(vfatCnt0/6), vfatCnt0%6].plot(threshold, noise_rate_avg, "o", markersize=12)
            ax3[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=25, transform=ax3[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax3[int(vfatCnt0/6), vfatCnt0%6].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=23, transform=ax3[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax5[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("S-Bit", loc='right')
            ax5[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("Threshold (DAC)")
            ax5[int(vfatCnt0/6), vfatCnt0%6].set_title("VFAT%02d"%vfat)
            cf5[int(vfatCnt0/6), vfatCnt0%6] = ax5[int(vfatCnt0/6), vfatCnt0%6].pcolormesh(map_plot_data_x, map_plot_data_y, map_plot_data, cmap=cm.ocean_r, shading="nearest", norm=mcolors.LogNorm(vmin=1, vmax=z_max))
            cbar5[int(vfatCnt0/6), vfatCnt0%6] = fig5.colorbar(cf5[int(vfatCnt0/6), vfatCnt0%6], ax=ax5[int(vfatCnt0/6), vfatCnt0%6], pad=0.01)
            cbar5[int(vfatCnt0/6), vfatCnt0%6].set_label("S-Bit rate (Hz)", loc='top')
            ax5[int(vfatCnt0/6), vfatCnt0%6].set_xticks(np.arange(0, 64, 20))
            ax5[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=20, transform=ax5[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax5[int(vfatCnt0/6), vfatCnt0%6].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=18, transform=ax5[int(vfatCnt0/6), vfatCnt0%6].transAxes)

        fig2, ax2 = plt.subplots(8, 8, figsize=(80,80))
        for sbit in noise_result[vfat]:
            if sbit == "all":
                continue
            noise_rate_sbit = []
            for thr in range(0,len(threshold)):
                noise_rate_sbit.append(noise_result[vfat][sbit][thr]/time)
            ax2[int(sbit/8), sbit%8].set_xlabel("Threshold (DAC)", loc='right')
            ax2[int(sbit/8), sbit%8].set_ylabel("S-Bit rate (Hz)", loc='top')
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
            ax2[int(sbit/8), sbit%8].set_title("VFAT%02d, S-Bit %02d"%(vfat, sbit))
            ax2[int(sbit/8), sbit%8].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax2[int(sbit/8), sbit%8].transAxes)
            ax2[int(sbit/8), sbit%8].text(-0.01, 1.01, 'Muon R&D',fontstyle='italic', fontsize=24, transform=ax2[int(sbit/8), sbit%8].transAxes)
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
    fig5.savefig((directoryName+"/2d_sbit_threshold_noise_rate_"+oh+".pdf"))
    plt.close(fig5)
    print(Colors.GREEN + 'Plots stored at %s' % directoryName + Colors.ENDC)







