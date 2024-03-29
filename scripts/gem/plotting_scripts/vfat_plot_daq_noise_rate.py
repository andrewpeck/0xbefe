from gem.gem_utils import *
import matplotlib
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib import cm
import numpy as np
import os, sys, glob
import argparse
import pandas as pd
import warnings
import copy

plt.rcParams.update({"font.size": 24}) # Increase font size
matplotlib.use('Agg')

if __name__ == "__main__":
    warnings.filterwarnings("ignore") # temporarily disable warnings; infinite covariance matrix is returned when calling scipy.optimize.curve_fit(), but fit is fine

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Plotting VFAT DAQ Noise Rate")
    parser.add_argument("-f", "--filename", action="store", dest="filename", help="Noise rate result filename")
    args = parser.parse_args()

    directoryName        = args.filename.replace('.txt','')
    plot_filename_prefix = (directoryName.split("/"))[-1]
    oh = plot_filename_prefix.split("_vfat")[0]
    file = open(args.filename)

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
        channel = line.split()[1]
        if channel!="all":
            channel = int(channel)
        thr = int(line.split()[2])
        fired = float(line.split()[3])
        time = float(line.split()[4])
        if vfat not in noise_result:
            noise_result[vfat] = {}
        if channel not in noise_result[vfat]:
            noise_result[vfat][channel] = {}
        if fired == -9999:
            noise_result[vfat][channel][thr] = 0
        else:
            noise_result[vfat][channel][thr] = fired
    file.close()

    numVfats = len(noise_result.keys())
    if numVfats == 1:
        fig1, ax1 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        fig3, ax3 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        fig4, ax4 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        fig5, ax5 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        cf5 = 0
        cbar5 = 0
    elif numVfats <= 3:
        fig1, ax1 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        fig3, ax3 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        fig4, ax4 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        fig5, ax5 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        cf5 = {}
        cbar5 = {}
    elif numVfats <= 6:
        fig1, ax1 = plt.subplots(2, 3, figsize=(30,20))
        fig3, ax3 = plt.subplots(2, 3, figsize=(30,20))
        fig4, ax4 = plt.subplots(2, 3, figsize=(30,20))
        fig5, ax5 = plt.subplots(2, 3, figsize=(30,20))
        cf5 = {}
        cbar5 = {}
    elif numVfats <= 12:
        fig1, ax1 = plt.subplots(2, 6, figsize=(60,20))
        fig3, ax3 = plt.subplots(2, 6, figsize=(60,20))
        fig4, ax4 = plt.subplots(2, 6, figsize=(60,20))
        fig5, ax5 = plt.subplots(2, 6, figsize=(60,20))
        cf5 = {}
        cbar5 = {}
    elif numVfats <= 18:
        fig1, ax1 = plt.subplots(3, 6, figsize=(60,30))
        fig3, ax3 = plt.subplots(3, 6, figsize=(60,30))
        fig4, ax4 = plt.subplots(3, 6, figsize=(60,30))
        fig5, ax5 = plt.subplots(3, 6, figsize=(60,30))
        cf5 = {}
        cbar5 = {}
    elif numVfats <= 24:
        fig1, ax1 = plt.subplots(4, 6, figsize=(60,40))
        fig3, ax3 = plt.subplots(4, 6, figsize=(60,40))
        fig4, ax4 = plt.subplots(4, 6, figsize=(60,40))
        fig5, ax5 = plt.subplots(4, 6, figsize=(60,40))
        cf5 = {}
        cbar5 = {}

    vfatCnt0 = 0
    for vfat in noise_result:
        print ("Creating plots for VFAT %02d"%vfat)

        threshold = []
        noise_rate = []
        noise_rate_vfat = []
        n_channels = 0

        for channel in noise_result[vfat]:
            for thr in noise_result[vfat][channel]:
                threshold.append(thr)
                noise_rate.append(0)
                noise_rate_vfat.append(0)
            break
        for channel in noise_result[vfat]:
            if channel == "all":
                continue
            n_channels += 1
            for i in range(0,len(threshold)):
                thr = threshold[i]
                noise_rate[i] += noise_result[vfat][channel][thr]/time
        noise_rate_avg = [noise/n_channels for noise in noise_rate]
        for i in range(0,len(threshold)):
            thr = threshold[i]
            noise_rate_vfat[i] += noise_result[vfat]["all"][thr]/time

        map_plot_data = []
        map_plot_data_x = []
        #map_plot_data_y = threshold
        map_plot_data_y = []
        z_max = 1
        #for channel in range(0,128):
        #    map_plot_data_x.append(channel)
        for i in range(0,len(threshold)):
            thr = threshold[i]
            #data = []
            for channel in range(0,128):
                map_plot_data_x.append(channel)
                map_plot_data_y.append(thr)
                if channel not in noise_result[vfat]:
                    map_plot_data.append(0)
                else:
                    map_plot_data.append(noise_result[vfat][channel][thr]/time)
                #if channel=="all":
                #    continue
                #data.append(noise_result[vfat][channel][thr]/time)
                if (noise_result[vfat][channel][thr]/time) > z_max:
                    z_max = noise_result[vfat][channel][thr]/time
            #map_plot_data.append(data)

        cmap_new = copy.copy(cm.get_cmap("viridis"))
        cmap_new.set_under('w')
        my_norm = mcolors.LogNorm(vmin=1e-1, vmax=1e8, clip=False)

        if numVfats == 1:
            ax1.set_xlabel("Threshold (DAC)", loc='right')
            ax1.set_ylabel("Channel rate (Hz)", loc='top')
            ax1.set_yscale("log")
            ax1.set_ylim(1e-1, 1e8)
            ax1.set_title("Total Channel rate for VFAT%02d" % vfat)
            ax1.grid()
            ax1.plot(threshold, noise_rate, "o", markersize=12)
            ax1.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax1.transAxes)
            ax1.text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax1.transAxes)
            ax3.set_xlabel("Threshold (DAC)", loc='right')
            ax3.set_ylabel("Channel rate (Hz)", loc='top')
            ax3.set_yscale("log")
            ax3.set_ylim(1e-1, 1e8)
            ax3.set_title("Mean Channel rate for VFAT%02d"%vfat)
            ax3.grid()
            ax3.plot(threshold, noise_rate_avg, "o", markersize=12)
            ax3.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax3.transAxes)
            ax3.text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax3.transAxes)
            ax4.set_xlabel("Threshold (DAC)", loc='right')
            ax4.set_ylabel("Channel rate (Hz)", loc='top')
            ax4.set_yscale("log")
            ax4.set_ylim(1e-1, 1e8)
            ax4.set_title("OR Channel rate for VFAT%02d"%vfat)
            ax4.grid()
            ax4.plot(threshold, noise_rate_vfat, "o", markersize=12)
            ax4.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax4.transAxes)
            ax4.text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax4.transAxes)
            ax5.set_xlabel("Channel", loc='right')
            ax5.set_ylabel("Threshold (DAC)", loc='top')
            ax5.set_title("VFAT%02d"%vfat)
            cf5 = ax5.scatter(x=map_plot_data_x,y=map_plot_data_y,c=map_plot_data,cmap=cmap_new, norm=my_norm, s=2)
            cbar5 = fig5.colorbar(cf5, ax=ax5, pad=0.01)
            #cbar5.ax.set_ylabel("Channel rate (Hz)", rotation=270, labelpad=16)  
            cbar5.ax.text(2.7,0.47,"Channel rate (Hz)",rotation=270)
            #cf5 = ax5.pcolormesh(map_plot_data_x, map_plot_data_y, map_plot_data, cmap=cm.ocean_r, shading="nearest", norm=mcolors.LogNorm(vmin=1e-1, vmax=1e8))
            #cbar5 = fig5.colorbar(cf5, ax=ax5, pad=0.01)
            #cbar5.set_label("Channel rate (Hz)", loc='top')
            ax5.set_xticks(np.arange(0, 128, 20))
            ax5.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax5.transAxes)
            ax5.text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax5.transAxes)
            ax5.set_xlim([-1,128])
        elif numVfats <= 3:
            ax1[vfatCnt0].set_xlabel("Threshold (DAC)", loc='right')
            ax1[vfatCnt0].set_ylabel("Channel rate (Hz)", loc='top')
            ax1[vfatCnt0].set_yscale("log")
            ax1[vfatCnt0].set_ylim(1e-1, 1e8)
            ax1[vfatCnt0].set_title("Total Channel rate for VFAT%02d" % vfat)
            ax1[vfatCnt0].grid()
            ax1[vfatCnt0].plot(threshold, noise_rate, "o", markersize=12)
            ax1[vfatCnt0].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax1[vfatCnt0].transAxes)
            ax1[vfatCnt0].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax1[vfatCnt0].transAxes)
            ax3[vfatCnt0].set_xlabel("Threshold (DAC)", loc='right')
            ax3[vfatCnt0].set_ylabel("Channel Rate (Hz)", loc='top')
            ax3[vfatCnt0].set_yscale("log")
            ax3[vfatCnt0].set_ylim(1e-1, 1e8)
            ax3[vfatCnt0].set_title("Mean Channel rate for VFAT%02d"%vfat)
            ax3[vfatCnt0].grid()
            ax3[vfatCnt0].plot(threshold, noise_rate_avg, "o", markersize=12)
            ax3[vfatCnt0].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax3[vfatCnt0].transAxes)
            ax3[vfatCnt0].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax3[vfatCnt0].transAxes)
            ax4[vfatCnt0].set_xlabel("Threshold (DAC)", loc='right')
            ax4[vfatCnt0].set_ylabel("Channel Rate (Hz)", loc='top')
            ax4[vfatCnt0].set_yscale("log")
            ax4[vfatCnt0].set_ylim(1e-1, 1e8)
            ax4[vfatCnt0].set_title("OR Channel rate for VFAT%02d"%vfat)
            ax4[vfatCnt0].grid()
            ax4[vfatCnt0].plot(threshold, noise_rate_vfat, "o", markersize=12)
            ax4[vfatCnt0].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax4[vfatCnt0].transAxes)
            ax4[vfatCnt0].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax4[vfatCnt0].transAxes)
            ax5[vfatCnt0].set_xlabel("Channel", loc='right')
            ax5[vfatCnt0].set_ylabel("Threshold (DAC)", loc='top')
            ax5[vfatCnt0].set_title("VFAT%02d"%vfat)
            cf5[vfatCnt0] = ax5[vfatCnt0].scatter(x=map_plot_data_x,y=map_plot_data_y,c=map_plot_data,cmap=cmap_new, norm=my_norm, s=2)
            cbar5[vfatCnt0] = fig5.colorbar(cf5[vfatCnt0], ax=ax5[vfatCnt0], pad=0.01)
            #cbar5[vfatCnt0].ax.set_ylabel("Channel rate (Hz)", rotation=270, labelpad=16)
            cbar5[vfatCnt0].ax.text(2.7,0.47,"Channel rate (Hz)",rotation=270)
            #cf5[vfatCnt0] = ax5[vfatCnt0].pcolormesh(map_plot_data_x, map_plot_data_y, map_plot_data, cmap=cm.ocean_r, shading="nearest", norm=mcolors.LogNorm(vmin=1e-1, vmax=1e8))
            #cbar5[vfatCnt0] = fig5.colorbar(cf5[vfatCnt0], ax=ax5[vfatCnt0], pad=0.01)
            #cbar5[vfatCnt0].set_label("Channel rate (Hz)", loc='top')
            ax5[vfatCnt0].set_xticks(np.arange(0, 128, 20))
            ax5[vfatCnt0].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax5[vfatCnt0].transAxes)
            ax5[vfatCnt0].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax5[vfatCnt0].transAxes)
            ax5[vfatCnt0].set_xlim([-1,128])
        elif numVfats <= 6:
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Threshold (DAC)", loc='right')
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("Channel rate (Hz)", loc='top')
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_yscale("log")
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_ylim(1e-1, 1e8)
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_title("Total Channel rate for VFAT%02d"%vfat)
            ax1[int(vfatCnt0/3), vfatCnt0%3].grid()
            ax1[int(vfatCnt0/3), vfatCnt0%3].plot(threshold, noise_rate, "o", markersize=12)
            ax1[int(vfatCnt0/3), vfatCnt0%3].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax1[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax1[int(vfatCnt0/3), vfatCnt0%3].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax1[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Threshold (DAC)", loc='right')
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("Channel rate (Hz)", loc='top')
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_yscale("log")
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_ylim(1e-1, 1e8)
            ax3[int(vfatCnt0/3), vfatCnt0%3].set_title("Mean Channel rate for VFAT%02d"%vfat)
            ax3[int(vfatCnt0/3), vfatCnt0%3].grid()
            ax3[int(vfatCnt0/3), vfatCnt0%3].plot(threshold, noise_rate_avg, "o", markersize=12)
            ax3[int(vfatCnt0/3), vfatCnt0%3].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax3[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax3[int(vfatCnt0/3), vfatCnt0%3].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax3[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax4[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Threshold (DAC)", loc='right')
            ax4[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("Channel rate (Hz)", loc='top')
            ax4[int(vfatCnt0/3), vfatCnt0%3].set_yscale("log")
            ax4[int(vfatCnt0/3), vfatCnt0%3].set_ylim(1e-1, 1e8)
            ax4[int(vfatCnt0/3), vfatCnt0%3].set_title("OR Channel rate for VFAT%02d"%vfat)
            ax4[int(vfatCnt0/3), vfatCnt0%3].grid()
            ax4[int(vfatCnt0/3), vfatCnt0%3].plot(threshold, noise_rate_vfat, "o", markersize=12)
            ax4[int(vfatCnt0/3), vfatCnt0%3].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax4[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax4[int(vfatCnt0/3), vfatCnt0%3].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax4[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax5[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Channel", loc='right')
            ax5[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("Threshold (DAC)", loc='top')
            ax5[int(vfatCnt0/3), vfatCnt0%3].set_title("VFAT%02d"%vfat)
            cf5[int(vfatCnt0/3), vfatCnt0%3] = ax5[int(vfatCnt0/3), vfatCnt0%3].scatter(x=map_plot_data_x,y=map_plot_data_y,c=map_plot_data,cmap=cmap_new, norm=my_norm, s=2)
            cbar5[int(vfatCnt0/3), vfatCnt0%3] = fig5.colorbar(cf5[int(vfatCnt0/3), vfatCnt0%3], ax=ax5[int(vfatCnt0/3), vfatCnt0%3], pad=0.01)
            #cbar5[int(vfatCnt0/3), vfatCnt0%3].ax.set_ylabel("Channel rate (Hz)", rotation=270, labelpad=16)
            cbar5[int(vfatCnt0/3), vfatCnt0%3].ax.text(2.7,0.47,"Channel rate (Hz)",rotation=270)
            #cf5[int(vfatCnt0/3), vfatCnt0%3] = ax5[int(vfatCnt0/3), vfatCnt0%3].pcolormesh(map_plot_data_x, map_plot_data_y, map_plot_data, cmap=cm.ocean_r, shading="nearest", norm=mcolors.LogNorm(vmin=1e-1, vmax=1e8))
            #cbar5[int(vfatCnt0/3), vfatCnt0%3] = fig5.colorbar(cf5[int(vfatCnt0/3), vfatCnt0%3], ax=ax5[int(vfatCnt0/3), vfatCnt0%3], pad=0.01)
            #cbar5[int(vfatCnt0/3), vfatCnt0%3].set_label("Channel rate (Hz)", loc='top')
            ax5[int(vfatCnt0/3), vfatCnt0%3].set_xticks(np.arange(0, 128, 20))
            ax5[int(vfatCnt0/3), vfatCnt0%3].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax5[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax5[int(vfatCnt0/3), vfatCnt0%3].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax5[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax5[int(vfatCnt0/3), vfatCnt0%3].set_xlim([-1,128])
        else:
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Threshold (DAC)", loc='right')
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("Channel rate (Hz)", loc='top')
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_yscale("log")
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_ylim(1e-1, 1e8)
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_title("Total Channel rate for VFAT%02d"%vfat)
            ax1[int(vfatCnt0/6), vfatCnt0%6].grid()
            ax1[int(vfatCnt0/6), vfatCnt0%6].plot(threshold, noise_rate, "o", markersize=12)
            ax1[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax1[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax1[int(vfatCnt0/6), vfatCnt0%6].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax1[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Threshold (DAC)", loc='right')
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("Channel rate (Hz)", loc='top')
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_yscale("log")
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_ylim(1e-1, 1e8)
            ax3[int(vfatCnt0/6), vfatCnt0%6].set_title("Mean Channel rate for VFAT%02d"%vfat)
            ax3[int(vfatCnt0/6), vfatCnt0%6].grid()
            ax3[int(vfatCnt0/6), vfatCnt0%6].plot(threshold, noise_rate_avg, "o", markersize=12)
            ax3[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax3[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax3[int(vfatCnt0/6), vfatCnt0%6].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax3[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax4[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Threshold (DAC)", loc='right')
            ax4[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("Channel rate (Hz)", loc='top')
            ax4[int(vfatCnt0/6), vfatCnt0%6].set_yscale("log")
            ax4[int(vfatCnt0/6), vfatCnt0%6].set_ylim(1e-1, 1e8)
            ax4[int(vfatCnt0/6), vfatCnt0%6].set_title("OR Channel rate for VFAT%02d"%vfat)
            ax4[int(vfatCnt0/6), vfatCnt0%6].grid()
            ax4[int(vfatCnt0/6), vfatCnt0%6].plot(threshold, noise_rate_vfat, "o", markersize=12)
            ax4[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax4[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax4[int(vfatCnt0/6), vfatCnt0%6].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax4[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax5[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Channel", loc='right')
            ax5[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("Threshold (DAC)", loc='top')
            ax5[int(vfatCnt0/6), vfatCnt0%6].set_title("VFAT%02d"%vfat)
            cf5[int(vfatCnt0/6), vfatCnt0%6] = ax5[int(vfatCnt0/6), vfatCnt0%6].scatter(x=map_plot_data_x,y=map_plot_data_y,c=map_plot_data,cmap=cmap_new, norm=my_norm, s=2)
            cbar5[int(vfatCnt0/6), vfatCnt0%6] = fig5.colorbar(cf5[int(vfatCnt0/6), vfatCnt0%6], ax=ax5[int(vfatCnt0/6), vfatCnt0%6], pad=0.01)
            #cbar5[int(vfatCnt0/6), vfatCnt0%6].ax.set_ylabel("Channel rate (Hz)", rotation=270, labelpad=16)
            cbar5[int(vfatCnt0/6), vfatCnt0%6].ax.text(2.7,0.47,"Channel rate (Hz)",rotation=270)
            #cf5[int(vfatCnt0/6), vfatCnt0%6] = ax5[int(vfatCnt0/6), vfatCnt0%6].pcolormesh(map_plot_data_x, map_plot_data_y, map_plot_data, cmap=cm.ocean_r, shading="nearest", norm=mcolors.LogNorm(vmin=1e-1, vmax=1e8))
            #cbar5[int(vfatCnt0/6), vfatCnt0%6] = fig5.colorbar(cf5[int(vfatCnt0/6), vfatCnt0%6], ax=ax5[int(vfatCnt0/6), vfatCnt0%6], pad=0.01)
            #cbar5[int(vfatCnt0/6), vfatCnt0%6].set_label("Channel rate (Hz)", loc='top')
            ax5[int(vfatCnt0/6), vfatCnt0%6].set_xticks(np.arange(0, 128, 20))
            ax5[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax5[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax5[int(vfatCnt0/6), vfatCnt0%6].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax5[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax5[int(vfatCnt0/6), vfatCnt0%6].set_xlim([-1,128])

        fig2, ax2 = plt.subplots(16, 8, figsize=(80,80))
        for channel in noise_result[vfat]:
            if channel=="all":
                continue
            noise_rate_channel = []
            for i in range(0,len(threshold)):
                thr = threshold[i]
                noise_rate_channel.append(noise_result[vfat][channel][thr]/time)
            ax2[int(channel/8), channel%8].set_xlabel("Threshold (DAC)", loc='right')
            ax2[int(channel/8), channel%8].set_ylabel("Channel rate (Hz)", loc='top')
            ax2[int(channel/8), channel%8].set_yscale("log")
            ax2[int(channel/8), channel%8].set_ylim(1e-1, 1e8)
            ax2[int(channel/8), channel%8].grid()
            ax2[int(channel/8), channel%8].plot(threshold, noise_rate_channel, "o", markersize=12)
            #leg = ax.legend(loc="center right", ncol=2)
            ax2[int(channel/8), channel%8].set_title("VFAT%02d, Channel %02d"%(vfat, channel))
            ax2[int(channel/8), channel%8].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax2[int(channel/8), channel%8].transAxes)
            ax2[int(channel/8), channel%8].text(-0.01, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax2[int(channel/8), channel%8].transAxes)
            
        #ax2.text(-0.14, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax2.transAxes)
        #ax2.text(0.03, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax2.transAxes)
        fig2.tight_layout()
        fig2.savefig((directoryName+"/daq_noise_rate_channels_"+oh+"_VFAT%02d.pdf")%vfat)
        plt.close(fig2)

        vfatCnt0+=1

    fig1.tight_layout()
    fig1.savefig((directoryName+"/daq_noise_rate_total_"+oh+".pdf"))
    plt.close(fig1)
    fig3.tight_layout()
    fig3.savefig((directoryName+"/daq_noise_rate_mean_"+oh+".pdf"))
    plt.close(fig3)
    fig4.tight_layout()
    fig4.savefig((directoryName+"/daq_noise_rate_or_"+oh+".pdf"))
    plt.close(fig4)
    fig5.savefig((directoryName+"/2d_daq_threshold_noise_rate_"+oh+".pdf"))
    fig5.savefig((directoryName+"/2d_daq_threshold_noise_rate_"+oh+".png"))
    plt.close(fig5)
    print(Colors.GREEN + 'Plots stored at %s' % directoryName + Colors.ENDC)






