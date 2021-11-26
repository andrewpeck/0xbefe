from gem.gem_utils import *
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib import cm
import numpy as np
import os, sys, glob
import argparse
from scipy.optimize import curve_fit
from scipy.special import erf
from math import sqrt
from tqdm import tqdm
import warnings

plt.rcParams.update({"font.size": 22}) # Increase font size

def dictToArray(dictionary, vfatNumber, channel):
    """
    Returns (256, 2) ndarray.
    column 0 = injected charge
    column 1 = ratio of fired events / total events
    """
    return np.array(list(dictionary[vfatNumber][channel].items()))

def scurveFunc(injCharge, A, ch_pedestal, mean, sigma):
    """
    Modified error function.
    injCharge = injected charge
    """
    
    pedestal = np.zeros(256)
    if ch_pedestal > 0.0:
        pedestal.fill(ch_pedestal)
        
    maxCharge = np.maximum(pedestal, injCharge)

    return A * erf(np.true_divide((maxCharge - mean), sigma * sqrt(2))) + A

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

def fit_scurve(vfatList, scurve_result, oh, directoryName, verbose , channel_list):
    vfatCounter   = 0 
    scurveParams = np.ndarray((len(vfatList), 128, 2))

    for vfat in vfatList:
        print("Fitting data for VFAT%02d" % vfat)
        fitFileName = directoryName + "/fitResults_" + oh + ("_VFAT%02d" % vfat) + ".txt"
        file_out = open(fitFileName, "w+")
        file_out.write("========= Results for VFAT%2d =========\n" % vfat)
        print("========= Processing data for VFAT%2d =========\n" % vfat)
        file_out.write("Channel    Mean    ENC\n")

        for channel in tqdm(range(128)):
            scurveData      = dictToArray(scurve_result, vfat, channel) # transfer data from dictionary to array
            effi_mid_point = (scurveData[:,1][0] + scurveData[:,1][-1])/2.0
            threshold_initial_guess = 0
            for charge in scurve_result[vfat][channel]:
                if scurve_result[vfat][channel][charge] >= effi_mid_point:
                    threshold_initial_guess = charge
                    break
            params, covMatrix = curve_fit(scurveFunc, scurveData[:,0], scurveData[:,1], p0=[1, 0, threshold_initial_guess, 0.4], maxfev=100000) # fit data; returns optimized parameters and covariance matrix
            if verbose == True:
                print ("Initial guess for threshold for fitting: %.4f (fC)"%vfat_threshold_initial_guess[vfat])

            file_out.write("%d    %.4f    %.4f \n" % (channel, params[2], params[3]))
            scurveParams[vfatCounter, channel, 0] = params[3] # store channel ENC
            scurveParams[vfatCounter, channel, 1] = params[2] # store channel mean
            
            if verbose == True:
                print("Channel %i Average ENC: %.4f " % (channel, scurveParams[vfatCounter, channel, 0]))
                print("Channel %i Average mean: %.4f " % (channel, scurveParams[vfatCounter, channel, 1]))
            else:
                pass

            try:
                os.makedirs(directoryName+"/scurveFit_"+oh+"_VFAT%02d"%(vfat))
            except FileExistsError:
                pass

            if channel in channel_list:
                fig, ax = plt.subplots(figsize = (12,10))
                ax.set_xlabel("Charge (fC)", loc='right')
                ax.set_ylabel("Fired events / total events", loc='top')
                ax.grid()
                ax.plot(scurveData[:,0], scurveData[:,1], "o", markersize= 6, label = "Channel %d" % channel) # plot raw data
                ax.plot(scurveData[:,0], scurveFunc(scurveData[:,0], *params), "r-", label="fit")
                props = dict(boxstyle="round", facecolor="white",edgecolor="lightgrey", alpha=1)
                textstr = "\n".join((
                    r"Threshold: $\mu=%.4f$ (fC)" % (params[2], ),
                    r"ENC: $\sigma=%.4f$ (fC)" % (params[3], ),))
                ax.text(0.57, 0.7, textstr, transform=ax.transAxes, fontsize=22, verticalalignment="top", bbox=props)
                ax.set_title("VFAT0%d" % vfat)
                leg = ax.legend(loc="center right", ncol=2)
                ax.text(-0.09, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax.transAxes)
                ax.text(0.01, 1.01, 'Muon R&D',fontstyle='italic', fontsize=26, transform=ax.transAxes)
                fig.tight_layout()
                plt.savefig(directoryName + "/scurveFit_"+oh+"_VFAT%02d/"%(vfat)+"scurveFit_"+oh+"_VFAT%02d_channel%d.pdf" % (vfat, channel))
                plt.close() # clear the plot
            else:
                pass
        
        # average values for all channels    
        avgENC = np.average(scurveParams[vfatCounter, :, 0])
        avgMean = np.average(scurveParams[vfatCounter, :, 1])


        print("========= Summary =========\n")
        print("Average ENC: %.4f (fC)" % avgENC)
        print("Average mean (threshold): %.4f (fC)" % avgMean)

        file_out.write("========= Summary =========\n")
        file_out.write("Average ENC: %.4f (fC)\n" % avgENC)
        file_out.write("Average mean (threshold): %.4f (fC)\n" % avgMean)

        file_out.close()
        print("Results for VFAT%0d saved in %s\n" % (vfat, fitFileName))
        vfatCounter += 1
        
    return scurveParams

def plotENCdistributions(vfatList, scurveParams, oh, directoryName):
    """
    Plots the ENC distribution of all channels for each VFAT.
    """
    fig, ax = plt.subplots(figsize = (12,10))
    ax.set_title("ENC distributions")
    ax.set_xlabel("VFAT number", loc='right')
    ax.set_ylabel("S-curve ENC (fC)", loc='top')
    ax.grid()

    data = []
    for ii in range(len(vfatList)):
        data.append(scurveParams[ii, :, 0])

    ax.boxplot(data, patch_artist=True)
    
    ax.text(-0.092, 1.01, 'CMS', fontweight='bold', fontsize=30, transform=ax.transAxes)
    ax.text(0.01, 1.01, 'Muon R&D',fontstyle='italic', fontsize=28, transform=ax.transAxes)

    textStr = '\n'.join((
    r'Orange line = median',
    r'Box = interquartile range (IQR) Q1$-$Q3', 
    r'Top whisker = Q3$+1.5$\cdot$IQR', 
    r'Bottom whisker = Q1$-$1.5$\cdot$IQR',
    r'Circles = outliers'))

    props = dict(boxstyle='round', facecolor='white', alpha=0.4)

    ax.text(0.03, 0.76, textStr, transform=ax.transAxes, fontsize=22, bbox=props)
    
    plt.xticks(np.arange(1, len(vfatList) + 1), vfatList) # replace ticks with vfat number
    fig.tight_layout()
    plt.savefig(directoryName + "/scurveENCdistribution_"+oh+".pdf")
    print("\nENC distribution plot saved at %s" % directoryName + "/scurveENCdistribution_"+oh+".pdf")
    plt.close()

def plot2Dhist(vfatList, directoryName, oh, scurve_result, slope_adc, intercept_adc, current_pulse_sf, mode):
    """
    Formats data originally stored in the s-curve dictionary
    and plots the 2D s-curve histogram.
    """
    channelNum = np.arange(0, 128, 1)
    chargeVals = np.arange(0, 256, 1)

    numVfats = len(scurve_result.keys())
    if numVfats == 1:
        fig1, ax1 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        cf1 = 0
        cbar1 = 0
    elif numVfats <= 3:
        fig1, ax1 = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        cf1 ={}
        cbar1 ={}
    elif numVfats <= 6:
        fig1, ax1 = plt.subplots(2, 3, figsize=(30,20))
        cf1 ={}
        cbar1 ={}
    elif numVfats <= 12:
        fig1, ax1 = plt.subplots(2, 6, figsize=(60,20))
        cf1 ={}
        cbar1 ={}
    elif numVfats <= 18:
        fig1, ax1 = plt.subplots(3, 6, figsize=(60,30))
        cf1 ={}
        cbar1 ={}
    elif numVfats <= 24:
        fig1, ax1 = plt.subplots(4, 6, figsize=(60,40))
        cf1 ={}
        cbar1 ={}

    vfatCnt0 = 0
    for vfat in scurve_result:
        fig, axs = plt.subplots()
        axs.set_title("VFAT%02d"%vfat, fontsize=16)
        axs.set_xlabel("Channel number", loc='right', fontsize=14)
        axs.set_ylabel("Injected charge (fC)", loc='top', fontsize=14)
        for label in (axs.get_xticklabels() + axs.get_yticklabels()):
            label.set_fontsize(14)
        #axs.xlim(0,128)
        #axs.ylim(0,256)

        plot_data = []
        plot_data_x = []
        plot_data_y = []
        for dac in range(0,256):
            charge = DACToCharge(dac, slope_adc, intercept_adc, current_pulse_sf, vfat, mode)
            plot_data_y.append(charge)
            data = []
            data_x = []
            data_y = []
            for channel in range(0,128):
                if channel not in scurve_result[vfat]:
                    data.append(0)
                elif charge not in scurve_result[vfat][channel]:
                    data.append(0)
                else:
                    data.append(scurve_result[vfat][channel][charge])
            plot_data.append(data)
        for channel in range(0,128):
            plot_data_x.append(channel)

        cf = axs.pcolormesh(plot_data_x, plot_data_y, plot_data, cmap=cm.ocean_r, shading="nearest")
        #chargeVals_mod = chargeVals
        #for i in range(0,len(chargeVals_mod)):
        #    chargeVals_mod[i] = DACToCharge(chargeVals_mod[i], slope_adc, intercept_adc, current_pulse_sf, vfat, mode)
        #plot = axs.imshow(plot_data, extent=[min(channelNum), max(channelNum), min(chargeVals_mod), max(chargeVals_mod)], origin="lower",  cmap=cm.ocean_r,interpolation="nearest", aspect="auto")
        cbar = fig.colorbar(cf, ax=axs, pad=0.01)
        cbar.set_label("Fired Events / Total Events", loc='top', fontsize=14)
        cbar.ax.tick_params(labelsize=14)
        axs.text(-0.14, 1.01, 'CMS', fontweight='bold', fontsize=20, transform=axs.transAxes)
        axs.text(0.03, 1.01, 'Muon R&D',fontstyle='italic', fontsize=18, transform=axs.transAxes)
        axs.set_xticks(np.arange(min(channelNum), max(channelNum)+1, 20))
        axs.set_yticks(np.arange(min(plot_data_y), max(plot_data_y)+1, 20))
        fig.tight_layout()
        fig.savefig((directoryName+"/scurve2Dhist_"+oh+"_VFAT%02d.pdf")%vfat)
        plt.close(fig)

        if numVfats == 1:
            ax1.set_xlabel("Channel number", loc='right')
            ax1.set_ylabel("Injected charge (fC)")
            ax1.set_title("VFAT%02d"%vfat)
            cf1 = ax1.pcolormesh(plot_data_x, plot_data_y, plot_data, cmap=cm.ocean_r, shading="nearest")
            cbar1 = fig1.colorbar(cf1, ax=ax1, pad=0.01)
            cbar1.set_label("Fired events / total events", loc='top')
            ax1.set_xticks(np.arange(min(channelNum), max(channelNum)+1, 20))
            ax1.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=20, transform=ax1.transAxes)
            ax1.text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=18, transform=ax1.transAxes)
        elif numVfats <= 3:
            ax1[vfatCnt0].set_xlabel("Channel Number", loc='right')
            ax1[vfatCnt0].set_ylabel("Injected Charge (fC)", loc='top')
            ax1[vfatCnt0].set_title("VFAT%02d"%vfat)
            cf1[vfatCnt0] = ax1[vfatCnt0].pcolormesh(plot_data_x, plot_data_y, plot_data, cmap=cm.ocean_r, shading="nearest")
            cbar1[vfatCnt0] = fig1.colorbar(cf1[vfatCnt0], ax=ax1[vfatCnt0], pad=0.01)
            cbar1[vfatCnt0].set_label("Fired events / total events", loc='top')
            ax1[vfatCnt0].set_xticks(np.arange(min(channelNum), max(channelNum)+1, 20))
            ax1[vfatCnt0].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=20, transform=ax1[vfatCnt0].transAxes)
            ax1[vfatCnt0].text(-0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=18, transform=ax1[vfatCnt0].transAxes)
        elif numVfats <= 6:
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_xlabel("Channel number", loc='right')
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("Injected charge (fC)", loc='top')
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_title("VFAT%02d"%vfat)
            cf1[int(vfatCnt0/3), vfatCnt0%3] = ax1[int(vfatCnt0/3), vfatCnt0%3].pcolormesh(plot_data_x, plot_data_y, plot_data, cmap=cm.ocean_r, shading="nearest")
            cbar1[int(vfatCnt0/3), vfatCnt0%3] = fig1.colorbar(cf1[int(vfatCnt0/3), vfatCnt0%3], ax=ax1[int(vfatCnt0/3), vfatCnt0%3], pad=0.01)
            cbar1[int(vfatCnt0/3), vfatCnt0%3].set_label("Fired events / total events", loc='top')
            ax1[int(vfatCnt0/3), vfatCnt0%3].set_xticks(np.arange(min(channelNum), max(channelNum)+1, 20))
            ax1[int(vfatCnt0/3), vfatCnt0%3].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax1[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            ax1[int(vfatCnt0/3), vfatCnt0%3].text(0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=26, transform=ax1[int(vfatCnt0/3), vfatCnt0%3].transAxes)
        else:
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_xlabel("Channel number", loc='right', fontsize=18)
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("Injected charge (fC)", loc='top', fontsize=18)
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_title("VFAT%02d"%vfat)
            cf1[int(vfatCnt0/6), vfatCnt0%6] = ax1[int(vfatCnt0/6), vfatCnt0%6].pcolormesh(plot_data_x, plot_data_y, plot_data, cmap=cm.ocean_r, shading="nearest")
            cbar1[int(vfatCnt0/6), vfatCnt0%6] = fig1.colorbar(cf1[int(vfatCnt0/6), vfatCnt0%6], ax=ax1[int(vfatCnt0/6), vfatCnt0%6], pad=0.01)
            cbar1[int(vfatCnt0/6), vfatCnt0%6].set_label("Fired events / total events", loc='top')
            ax1[int(vfatCnt0/6), vfatCnt0%6].set_xticks(np.arange(min(channelNum), max(channelNum)+1, 20))
            ax1[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=20, transform=ax1[int(vfatCnt0/6), vfatCnt0%6].transAxes)
            ax1[int(vfatCnt0/6), vfatCnt0%6].text(0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=18, transform=ax1[int(vfatCnt0/6), vfatCnt0%6].transAxes)

        vfatCnt0 += 1
        print(("\n2D histogram of scurves for VFAT%d " % vfat )+ ("saved at %s" % directoryName) + "/scurve2Dhist_"+oh+"_VFAT%d.pdf" % vfat)

    #plt.figtext(0.01, 1.0, 'CMS', fontweight='bold', fontsize=28)
    #plt.figtext(0.8, 1.0, 'Muon R&D', fontstyle='italic', fontsize=26)
    fig1.tight_layout()
    fig1.savefig((directoryName+"/scurve2Dhist_"+oh+".pdf"))
    #plt.close(fig1)

if __name__ == "__main__":
    warnings.filterwarnings("ignore") # temporarily disable warnings; infinite covariance matrix is returned when calling scipy.optimize.curve_fit(), but fit is fine

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Plotting VFAT DAQ SCurve")
    parser.add_argument("-f", "--filename", action="store", dest="filename", help="SCurve result filename")
    parser.add_argument("-c", "--channels", action="store", nargs="+", dest="channels", help="Channels to plot for each VFAT, default = all 128 channels")
    parser.add_argument("-m", "--mode", action="store", dest="mode", help="mode = voltage or current")
    parser.add_argument("-fs", "--cal_fs", action="store", dest="cal_fs", help="cal_fs = value of CAL_FS used (0-3), default = taken from VFAT config text file")
    parser.add_argument("-v", "--verbose", action="store_true", dest="verbose", help="Increase verbosity")
    args = parser.parse_args()

    channel_list = []
    if args.channels is None:
        channel_list = range(0,128)
    else:
        for channel in args.channels:
            channel_list.append(int(channel))

    if args.mode not in ["voltage", "current"]:
        print(Colors.YELLOW + "Mode can only be voltage or current" + Colors.ENDC)
        sys.exit()

    directoryName        = args.filename.split(".txt")[0]
    plot_filename_prefix = (directoryName.split("/"))[3]
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

    calib_path = "results/vfat_data/vfat_calib_data/"+oh+"_vfat_calib_info_calDac.txt"
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
    
    vfatList     = list(scurve_result.keys())
    scurveParams = fit_scurve(vfatList, scurve_result, oh, directoryName, args.verbose, channel_list)
    plotENCdistributions(vfatList, scurveParams, oh, directoryName)
    plot2Dhist(vfatList, directoryName, oh, scurve_result, slope_adc, intercept_adc, current_pulse_sf, args.mode)


