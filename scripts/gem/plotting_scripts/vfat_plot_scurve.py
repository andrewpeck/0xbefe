from gem.gem_utils import *
from common.utils import get_befe_scripts_dir
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib import cm
import numpy as np
import os, sys, glob
import argparse
import warnings
import copy

plt.rcParams.update({"font.size": 22}) # Increase font size

def getCalData(calib_path):
    slope_adc = {}
    intercept_adc = {}

    if os.path.isfile(calib_path):
        calib_file = open(calib_path)
        for line in calib_file.readlines():
            if "vfat" in line:
                continue
            vfat = int(line.split(";")[0])
            slope_adc[vfat] = float(line.split(";")[2])
            intercept_adc[vfat] = float(line.split(";")[3])
        calib_file.close()

    return slope_adc, intercept_adc

def DACToCharge(dac, slope_adc, intercept_adc, current_pulse_sf, vfat, mode):
    """
    Slope and intercept for all VFATs from the CAL_DAC cal file.
    If cal file not present, use default values here are a rough average of cal data.
    """

    slope = -9999
    intercept = -9999

    if vfat in slope_adc:
        if slope_adc[vfat]!=-9999 and intercept_adc[vfat]!=-9999:
            if mode=="voltage":
                slope = slope_adc[vfat]
                intercept = intercept_adc[vfat]
            elif mode=="current":
                slope = abs(slope_adc[vfat])
                intercept = 0
    if slope==-9999 or intercept==-9999: # use average values
        print (Colors.YELLOW + "ADC Cal data not present for VFAT%d, using average values"%vfat + Colors.ENDC)
        if mode=="voltage":
            slope = -0.22 # fC/DAC
            intercept = 56.1 # fC
        elif mode=="current":
            slope = 0.22 # fC/DAC
            intercept = 0
    charge = (dac * slope) + intercept
    if mode == "current":
        charge = charge * current_pulse_sf
    return charge

if __name__ == "__main__":
    warnings.filterwarnings("ignore") # temporarily disable warnings; infinite covariance matrix is returned when calling scipy.optimize.curve_fit(), but fit is fine

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Plotting VFAT SCurve")
    parser.add_argument("-f", "--filename", action="store", dest="filename", help="SCurve result filename")
    #parser.add_argument("-t", "--type", action="store", dest="type", help="type = daq or sbit")
    parser.add_argument("-m", "--mode", action="store", dest="mode", help="mode = voltage or current")
    parser.add_argument("-c", "--channels", action="store", nargs="+", dest="channels", help="Channels to plot for each VFAT")
    parser.add_argument("-fs", "--cal_fs", action="store", dest="cal_fs", help="cal_fs = value of CAL_FS used (0-3), default = taken from VFAT config text file")
    args = parser.parse_args()

    if args.channels is None:
        print(Colors.YELLOW + "Enter channel list to plot SCurves" + Colors.ENDC)
        sys.exit()

    if args.mode not in ["voltage", "current"]:
        print(Colors.YELLOW + "Mode can only be voltage or current" + Colors.ENDC)
        sys.exit()

    #if args.type not in ["daq", "sbit"]:
    #    print(Colors.YELLOW + "Type can only be daq or sbit" + Colors.ENDC)
    #    sys.exit()

    directoryName        = args.filename.removesuffix(".txt")
    plot_filename_prefix = (directoryName.split("/"))[-1]
    oh = plot_filename_prefix.split("_vfat")[0]
    file = open(args.filename)

    try:
        os.makedirs(directoryName) # create directory for scurve analysis results
    except FileExistsError: # skip if directory already exists
        pass

    cal_fs = -9999
    if args.cal_fs is None:
        vfat_config_path = "../resources/vfatConfig.txt"
        if not os.path.isfile(vfat_config_path):
            print(Colors.YELLOW + "VFAT config file not present, provide CAL_FS used" + Colors.ENDC)
            sys.exit()
        file_config = open(vfat_config_path)
        for line in file_config.readlines():
            if "CFG_CAL_FS" in line:
                cal_fs = int(line.split()[1])
                break
        file_config.close()
    else:
        cal_fs = int(args.cal_fs)
        if cal_fs > 3:
            print(Colors.YELLOW + "CAL_FS can be only 0-3" + Colors.ENDC)
            sys.exit()
    current_pulse_sf = -9999
    if cal_fs == 0:
        current_pulse_sf = 0.25
    elif cal_fs == 1:
        current_pulse_sf = 0.50
    elif cal_fs == 2:
        current_pulse_sf = 0.75
    elif cal_fs == 3:
        current_pulse_sf = 1.00
    if current_pulse_sf == -9999:
        print(Colors.YELLOW + "invalid Current Pulse SF" + Colors.ENDC)
        sys.exit()

    scripts_gem_dir = get_befe_scripts_dir() + '/gem'
    calib_path = scripts_gem_dir + "/results/vfat_data/vfat_calib_data/"+oh+"_vfat_calib_info_calDac.txt"
    slope_adc, intercept_adc = getCalData(calib_path)

    scurve_result = {}
    for line in file.readlines():
        if "vfat" in line:
            continue

        vfat    = int(line.split()[0])
        channel = int(line.split()[1])
        charge  = int(line.split()[2])
        fired   = int(line.split()[3])
        events  = int(line.split()[4])

        #if args.mode == "voltage":
        #    charge = 255 - charge
        charge = DACToCharge(charge, slope_adc, intercept_adc, current_pulse_sf, vfat, args.mode) # convert to fC

        if vfat not in scurve_result:
            scurve_result[vfat] = {}
        if channel not in scurve_result[vfat]:
            scurve_result[vfat][channel] = {}
        if fired == -9999 or events == -9999 or events == 0:
            scurve_result[vfat][channel][charge] = 0
        else:
            scurve_result[vfat][channel][charge] = float(fired)/float(events)
    file.close()

    channelNum = np.arange(0, 128, 1)
    chargeVals = np.arange(0, 256, 1)

    numVfats = len(scurve_result.keys())
    if numVfats == 1:
        fig1, ax1 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        cf1 = 0
        cbar1 = 0
    elif numVfats <= 3:
        fig1, ax1 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        cf1 = {}
        cbar1 = {}
    elif numVfats <= 6:
        fig1, ax1 = plt.subplots(2, 3, figsize=(30,20))
        cf1 = {}
        cbar1 = {}
    elif numVfats <= 12:
        fig1, ax1 = plt.subplots(2, 6, figsize=(60,20))
        cf1 = {}
        cbar1 = {}
    elif numVfats <= 18:
        fig1, ax1 = plt.subplots(3, 6, figsize=(60,30))
        cf1 = {}
        cbar1 = {}
    elif numVfats <= 24:
        fig1, ax1 = plt.subplots(4, 6, figsize=(60,40))
        cf1 = {}
        cbar1 = {}

    vfatCnt0 = 0
    for vfat in scurve_result:
        fig, axs = plt.subplots(figsize=(10,10))
        axs.set_xlabel("Channel number", loc = 'right')
        axs.set_ylabel("Injected charge (fC)", loc = 'top')
        #axs.xlim(0,128)
        #axs.ylim(0,256)

        plot_data = []
        plot_data_x = []
        plot_data_y = []
        for dac in range(0,256):
            charge = DACToCharge(dac, slope_adc, intercept_adc, current_pulse_sf, vfat, args.mode)
            #plot_data_y.append(charge)
            #data = []
            #data_x = []
            #data_y = []
            for channel in range(0,128):
                plot_data_x.append(channel)
                plot_data_y.append(charge)
                if channel not in scurve_result[vfat]:
                    plot_data.append(0)
                    #data.append(0)
                elif charge not in scurve_result[vfat][channel]:
                    plot_data.append(0)
                    #data.append(0)
                else:
                    plot_data.append(scurve_result[vfat][channel][charge])
                    #data.append(scurve_result[vfat][channel][charge])
            #plot_data.append(data)
        #for channel in range(0,128):
        #    plot_data_x.append(channel)

        cmap_new = copy.copy(cm.get_cmap("viridis"))
        cmap_new.set_under('w')
        my_norm = mcolors.Normalize(vmin=0.00025, vmax=1, clip=False)
        cf = axs.scatter(x=plot_data_x,y=plot_data_y,c=plot_data,cmap=cmap_new, norm=my_norm, s=2)

        #cf = plt.pcolormesh(plot_data_x, plot_data_y, plot_data, cmap=cm.ocean_r, shading="nearest")
        #chargeVals_mod = chargeVals
        #for i in range(0,len(chargeVals_mod)):
        #    chargeVals_mod[i] = DACToCharge(chargeVals_mod[i], slope_adc, intercept_adc, current_pulse_sf, vfat, args.mode)
        #plot = axs.imshow(plot_data, extent=[min(channelNum), max(channelNum), min(chargeVals_mod), max(chargeVals_mod)], origin="lower",  cmap=cm.ocean_r,interpolation="nearest", aspect="auto")
        cbar = fig.colorbar(cf, ax=axs, pad=0.01)
        #cbar = plt.colorbar()
        cbar.ax.set_ylabel("Fired Events / Total Events", rotation=270, fontsize=18, labelpad=16)
        #cbar.ax.set_label("Fired Events / Total Events", loc='top', fontsize=14)
        cbar.ax.tick_params(labelsize=14)
        axs.set_title("VFAT%02d"%vfat)
        axs.set_xticks(np.arange(min(channelNum), max(channelNum)+1, 20))
        axs.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=axs.transAxes)
        axs.text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=axs.transAxes)
        fig.tight_layout()
        fig.savefig((directoryName+"/scurve2Dhist_"+oh+"_VFAT%02d.pdf")%vfat)
        plt.close(fig)

        if numVfats == 1:
            ax1.set_xlabel("Channel number", loc='right', fontsize=18)
            ax1.set_ylabel("Injected charge (fC)", loc='top', fontsize=18)
            ax1.set_title("VFAT%02d"%vfat)
            cf1 = ax1.scatter(x=plot_data_x,y=plot_data_y,c=plot_data,cmap=cmap_new, norm=my_norm, s=2)
            cbar1 = fig1.colorbar(cf1, ax=ax1, pad=0.01)
            cbar1.ax.set_ylabel("Fired Events / Total Events", rotation=270, fontsize=18, labelpad=16)
            #cf1 = ax1.pcolormesh(plot_data_x, plot_data_y, plot_data, cmap=cm.ocean_r, shading="nearest")
            #cbar1 = fig1.colorbar(cf1, ax=ax1, pad=0.01)
            #cbar1.set_label("Fired events / total events", loc='top')
            ax1.set_xticks(np.arange(min(channelNum), max(channelNum)+1, 20))
            ax1.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=20, transform=ax1.transAxes)
            ax1.text(-0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=18, transform=ax1.transAxes)
        elif numVfats <= 3:
            ax1[vfatCnt0].set_xlabel("Channel number", loc='right', fontsize=18)
            ax1[vfatCnt0].set_ylabel("Injected charge (fC)", loc='top', fontsize=18)
            ax1[vfatCnt0].set_title("VFAT%02d"%vfat)
            cf1[vfatCnt0] = ax1[vfatCnt0].scatter(x=plot_data_x,y=plot_data_y,c=plot_data,cmap=cmap_new, norm=my_norm, s=2)
            cbar1[vfatCnt0] = fig1.colorbar(cf1[vfatCnt0], ax=ax1[vfatCnt0], pad=0.01)
            cbar1[vfatCnt0].ax.set_ylabel("Fired Events / Total Events", rotation=270, fontsize=18, labelpad=16)
            #cf1[vfatCnt0] = ax1[vfatCnt0].pcolormesh(plot_data_x, plot_data_y, plot_data, cmap=cm.ocean_r, shading="nearest")
            #cbar1[vfatCnt0] = fig1.colorbar(cf1[vfatCnt0], ax=ax1[vfatCnt0], pad=0.01)
            #cbar1[vfatCnt0].set_label("Fired events / total events", loc='top')
            ax1[vfatCnt0].set_xticks(np.arange(min(channelNum), max(channelNum)+1, 20))
            ax1[vfatCnt0].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=20, transform=ax1[vfatCnt0].transAxes)
            ax1[vfatCnt0].text(-0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=18, transform=ax1[vfatCnt0].transAxes)
        elif numVfats <= 6:
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Channel number", loc='right', fontsize=18)
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("Injected charge (fC)", loc='top', fontsize=18)
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_title("VFAT%02d"%vfat)
            cf1[int(vfatCnt0/3), vfatCnt0%3] = ax1[int(vfatCnt0/3), vfatCnt0%3].scatter(x=plot_data_x,y=plot_data_y,c=plot_data,cmap=cmap_new, norm=my_norm, s=2)
            cbar1[int(vfatCnt0/3), vfatCnt0%3] = fig1.colorbar(cf1[int(vfatCnt0/3), vfatCnt0%3], ax=ax1[int(vfatCnt0/3), vfatCnt0%3], pad=0.01)
            cbar1[int(vfatCnt0/3), vfatCnt0%3].ax.set_ylabel("Fired Events / Total Events", rotation=270, fontsize=18, labelpad=16)
            #cf1[int(vfatCnt0/3), vfatCnt0%3] = ax1[int(vfatCnt0/3), vfatCnt0%3].pcolormesh(plot_data_x, plot_data_y, plot_data, cmap=cm.ocean_r, shading="nearest")
            #cbar1[int(vfatCnt0/3), vfatCnt0%3] = fig1.colorbar(cf1[int(vfatCnt0/3), vfatCnt0%3], ax=ax1[int(vfatCnt0/3), vfatCnt0%3], pad=0.01)
            #cbar1[int(vfatCnt0/3), vfatCnt0%3].set_label("Fired events / total events", loc='top')
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_xticks(np.arange(min(channelNum), max(channelNum)+1, 20))
            ax1[int(vfatCnt0/3), vfatCnt0%3].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax1[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax1[int(vfatCnt0/3), vfatCnt0%3].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax1[int(vfatCnt0/3), vfatCnt0%3].transAxes)
        else:
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Channel number", loc='right', fontsize=18)
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("Injected charge (fC)", loc='top', fontsize=18)
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_title("VFAT%02d"%vfat)
            cf1[int(vfatCnt0/6), vfatCnt0%6] = ax1[int(vfatCnt0/6), vfatCnt0%6].scatter(x=plot_data_x,y=plot_data_y,c=plot_data,cmap=cmap_new, norm=my_norm, s=2)
            cbar1[int(vfatCnt0/6), vfatCnt0%6] = fig1.colorbar(cf1[int(vfatCnt0/6), vfatCnt0%6], ax=ax1[int(vfatCnt0/6), vfatCnt0%6], pad=0.01)
            cbar1[int(vfatCnt0/6), vfatCnt0%6].ax.set_ylabel("Fired Events / Total Events", rotation=270, fontsize=18, labelpad=16)
            #cf1[int(vfatCnt0/6), vfatCnt0%6] = ax1[int(vfatCnt0/6), vfatCnt0%6].pcolormesh(plot_data_x, plot_data_y, plot_data, cmap=cm.ocean_r, shading="nearest")
            #cbar1[int(vfatCnt0/6), vfatCnt0%6] = fig1.colorbar(cf1[int(vfatCnt0/6), vfatCnt0%6], ax=ax1[int(vfatCnt0/6), vfatCnt0%6], pad=0.01)
            #cbar1[int(vfatCnt0/6), vfatCnt0%6].set_label("Fired events / total events", loc='top')
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_xticks(np.arange(min(channelNum), max(channelNum)+1, 20))
            ax1[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=20, transform=ax1[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax1[int(vfatCnt0/6), vfatCnt0%6].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=18, transform=ax1[int(vfatCnt0/6), vfatCnt0%6].transAxes)

        vfatCnt0+=1

    fig1.tight_layout()
    fig1.savefig((directoryName+"/scurve2Dhist_"+oh+".pdf"))
    fig1.savefig((directoryName+"/scurve2Dhist_"+oh+".png"))
    plt.close(fig1)


    if numVfats <= 3:
        fig2, ax2 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        leg2 = 0
    elif numVfats <= 6:
        fig2, ax2 = plt.subplots(2, 3, figsize=(30,20))
        leg2 ={}
    elif numVfats <= 12:
        fig2, ax2 = plt.subplots(2, 6, figsize=(60,20))
        leg2 ={}
    elif numVfats <= 18:
        fig2, ax2 = plt.subplots(3, 6, figsize=(60,30))
        leg2 ={}
    elif numVfats <= 24:
        fig2, ax2 = plt.subplots(4, 6, figsize=(60,40))
        leg2 ={}

    vfatCnt0 = 0
    for vfat in scurve_result:
        fig, ax = plt.subplots(figsize=(12,10))
        ax.set_xlabel("Injected charge (fC)", loc = 'right')
        ax.set_ylabel("Fired events / total events", loc = 'top')
        #if args.type == "daq":
        #    plt.ylim(-0.1,1.1)
        #else:
        #    plt.ylim(-0.1,2.1)

        for channel in args.channels:
            channel = int(channel)
            if channel not in scurve_result[vfat]:
                print (Colors.YELLOW + "Channel %d not in SCurve scan"%channel + Colors.ENDC)
                continue
            dac = range(0,256)
            charge_plot = []
            frac = []
            for d in dac:
                c = DACToCharge(d, slope_adc, intercept_adc, current_pulse_sf, vfat, args.mode)
                if c in scurve_result[vfat][channel]:
                    charge_plot.append(c)
                    frac.append(scurve_result[vfat][channel][c])
            ax.grid()
            ax.plot(charge_plot, frac, "o",markersize = 6, label="Channel %d"%channel)
            ax.text(-0.1, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax.transAxes)
            ax.text(0.01, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax.transAxes)
            if numVfats == 1:
                ax2.grid()
                ax2.plot(charge_plot, frac, "o", markersize = 6, label="Channel %d"%channel)
            elif numVfats <= 3:
                ax2[vfatCnt0].grid()
                ax2[vfatCnt0].plot(charge_plot, frac, "o", markersize = 6, label="Channel %d"%channel)
            elif numVfats <= 6:
                ax2[int(vfatCnt0/3), vfatCnt0%3].grid()
                ax2[int(vfatCnt0/3), vfatCnt0%3].plot(charge_plot, frac, "o", markersize = 6, label="Channel %d"%channel)
            else:
                ax2[int(vfatCnt0/6), vfatCnt0%6].grid()
                ax2[int(vfatCnt0/6), vfatCnt0%6].plot(charge_plot, frac, "o", markersize = 6, label="Channel %d"%channel)
        leg = ax.legend(loc="center right", ncol=2)
        ax.set_title("VFAT%02d"%vfat)
        fig.savefig((directoryName+"/scurve_"+oh+"_VFAT%02d.pdf")%vfat)
        plt.close(fig)

        if numVfats == 1:
            ax2.set_xlabel("Injected charge (fC)", loc = 'right')
            ax2.set_ylabel("Fired events / total events", loc = 'top')
            ax2.set_title("VFAT%02d"%vfat)
            leg2 = ax2.legend(loc="center right", ncol=2)
            ax2.text(-0.09, 1.01, 'CMS', fontweight='bold', fontsize=26, transform=ax2.transAxes)
            ax2.text(0.01, 1.01, 'Preliminary',fontstyle='italic', fontsize=24, transform=ax2.transAxes)
        elif numVfats <= 3:
            ax2[vfatCnt0].set_xlabel("Injected charge (fC)", loc = 'right')
            ax2[vfatCnt0].set_ylabel("Fired events / total events", loc = 'top')
            ax2[vfatCnt0].set_title("VFAT%02d"%vfat)
            leg2[vfatCnt0] = ax2[vfatCnt0].legend(loc="center right", ncol=2)
            ax2[vfatCnt0].text(-0.09, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax2[vfatCnt0].transAxes)
            ax2[vfatCnt0].text(0.01, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax2[vfatCnt0].transAxes)
        elif numVfats <= 6:
            ax2[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Injected charge (fC)", loc = 'right')
            ax2[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("Fired Events / Total Events", loc = 'top')
            ax2[int(vfatCnt0/3), vfatCnt0%3].set_title("VFAT%02d"%vfat)
            leg2[int(vfatCnt0/3), vfatCnt0%3] = ax2[int(vfatCnt0/3), vfatCnt0%3].legend(loc="center right", ncol=2)
            ax2[int(vfatCnt0/3), vfatCnt0%3].text(-0.11, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax2[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax2[int(vfatCnt0/3), vfatCnt0%3].text(0.02, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax2[int(vfatCnt0/3), vfatCnt0%3].transAxes)
        else:
            ax2[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Injected charge (fC)", loc = 'right')
            ax2[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("Fired Events / Total Events", loc = 'top')
            ax2[int(vfatCnt0/6), vfatCnt0%6].set_title("VFAT%02d"%vfat)
            leg2[int(vfatCnt0/6), vfatCnt0%6] = ax2[int(vfatCnt0/6), vfatCnt0%6].legend(loc="center right", ncol=2)
            ax2[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax2[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax2[int(vfatCnt0/6), vfatCnt0%6].text(0.01, 1.01, 'Preliminary',fontstyle='italic', fontsize=26, transform=ax2[int(vfatCnt0/6), vfatCnt0%6].transAxes)
        vfatCnt0+=1

    fig2.tight_layout()
    fig2.savefig((directoryName+"/scurve_"+oh+".pdf"))
    plt.close(fig2)
    print(Colors.GREEN + 'Plots saved at %s' % directoryName + Colors.ENDC)





