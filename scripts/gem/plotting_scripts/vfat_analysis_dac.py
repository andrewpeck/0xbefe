from gem.gem_utils import *
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import os
from time import time

plt.rcParams.update({"font.size": 22}) # Increase font size

def poly5(x, a, b, c, d, e, f):
    return (a * np.power(x,5)) + (b * np.power(x,4)) + (c * np.power(x,3)) + (d * np.power(x,2)) + (e * x) + f

def linear(x, m, b):
    return x*m + b

def determine_nom(data, nominal_ADC0):
    val1=abs(data["value"]-nominal_ADC0).idxmin()
    return (data.iloc[val1].DAC_point)
 
nominalDacValues = {
        "CFG_CAL_DAC_I":(0,"uA"), # there is no nominal value
        "CFG_BIAS_PRE_I_BIT":(150,"uA"),
        "CFG_BIAS_PRE_I_BLCC":(25.0/1000.0,"uA"), # changed to uA from nA
        "CFG_BIAS_PRE_I_BSF":(26,"uA"),
        "CFG_BIAS_SH_I_BFCAS":(26,"uA"),
        "CFG_BIAS_SH_I_BDIFF":(16,"uA"),
        "CFG_BIAS_SD_I_BDIFF":(28,"uA"),
        "CFG_BIAS_SD_I_BFCAS":(27,"uA"),
        "CFG_BIAS_SD_I_BSF":(30,"uA"),
        "CFG_BIAS_CFD_DAC_1":(20,"uA"),
        "CFG_BIAS_CFD_DAC_2":(20,"uA"),
        "CFG_HYST":(100.0/1000.0,"uA"), # changed to uA from nA
        "CFG_THR_ARM_DAC":(64,"mV"),
        "CFG_THR_ZCC_DAC":(5.5,"mV"),
        "CFG_CAL_DAC_V_HIGH":(0,"mV"), # there is no nominal value
        "CFG_CAL_DAC_V_LOW":(0,"mV"), # there is no nominal value
        "CFG_BIAS_PRE_VREF":(430,"mV"),
        "CFG_VREF_ADC":(1.0,"V")
}

#: From Tables 12 and 13 from the VFAT3 manual
nominalDacScalingFactors = {
        "CFG_CAL_DAC_I":10, # Valid only for currentPulse
        "CFG_BIAS_PRE_I_BIT":0.2,
        "CFG_BIAS_PRE_I_BLCC":100,
        "CFG_BIAS_PRE_I_BSF":0.25,
        "CFG_BIAS_SH_I_BFCAS":1,
        "CFG_BIAS_SH_I_BDIFF":1,
        "CFG_BIAS_SD_I_BDIFF":1,
        "CFG_BIAS_SD_I_BFCAS":1,
        "CFG_BIAS_SD_I_BSF":0.25,
        "CFG_BIAS_CFD_DAC_1":1,
        "CFG_BIAS_CFD_DAC_2":1,
        "CFG_HYST":5,
        "CFG_THR_ARM_DAC":1,
        "CFG_THR_ZCC_DAC":4,
        "CFG_CAL_DAC_V_HIGH":1, #if voltageStep this is 1
        "CFG_CAL_DAC_V_LOW":1, #if voltageStep this is 1
        "CFG_BIAS_PRE_VREF":1,
        "CFG_ADC_VREF": 1,
}

def main(inFile, calFile, directoryName, oh):
    # read in DAC and cal data to dataframe
    dacData = pd.read_csv(inFile, names=["OH", "DAC_reg", "vfat", "DAC_point","value","error"], sep=";", skiprows=[0])
    calData = pd.read_csv(calFile ,names=["vfat", "vfat_serial_num", "slope", "intercept"], sep=";", skiprows=[0])

    numDacs  = dacData["DAC_reg"].nunique() # get number of dacs scanned
    numVfats = dacData["vfat"].nunique() # get number of vfats

    indices = dacData[dacData["DAC_reg"] == "CFG_MON_GAIN"].index
    dacData.drop(indices, inplace=True)

    nominal_iref = 10*0.5 #the nominal reference current is 10 uA and it has a scaling factor of 0.5

    cal_dac_derive = 0
    vfat_list = dacData.vfat.unique()
    vfat_cal_dac = {}
    caldacFileName = directoryName + "/" + oh + "_vfat_calib_info_calDac.txt"
    if "CFG_CAL_DAC_V_HIGH" in dacData.DAC_reg.unique() and "CFG_CAL_DAC_V_LOW" in dacData.DAC_reg.unique():
        print ("Deriving slope and intercept for CAL DAC")
        cal_dac_derive = 1
        caldacfile = open(caldacFileName, "w")
        caldacfile.write("vfat;vfat3_ser_num;cal_dacm;cal_dacb\n")
        caldacfile.close()
        vfatid_filename = "vfat_data/"+oh+"_vfatID.txt"
        vfat_id_list = {}
        if os.path.isfile(vfatid_filename):
            vfatid_file = open(vfatid_filename)
            for line in vfatid_file.readlines():
                vfat_id_list[int(line.split()[0])] = int(line.split()[1])
            vfatid_file.close()
        for vfat in vfat_list:
            vfat_cal_dac[vfat] = {}
            if vfat in vfat_id_list:
                vfat_cal_dac[vfat]["vfat_serial_num"] = vfat_id_list[vfat]
            else:
                vfat_cal_dac[vfat]["vfat_serial_num"] = 0
            vfat_cal_dac[vfat]["slope_high"] = 0
            vfat_cal_dac[vfat]["slope_low"] = 0
            vfat_cal_dac[vfat]["intercept_high"] = 0
            vfat_cal_dac[vfat]["intercept_low"] = 0

    for DAC_reg in dacData.DAC_reg.unique(): # loop over dacs
        startTime = time()
        print(Colors.GREEN + "\nWorking on DAC: %s \n" % DAC_reg + Colors.ENDC)

        if DAC_reg not in ["CFG_CAL_DAC_V_HIGH", "CFG_CAL_DAC_V_LOW"]:
            dacFileName = directoryName + "/nominalValues_" + oh + "_" + DAC_reg + ".txt"
            dac_nominal_file = open(dacFileName, "w")
        sel = dacData.DAC_reg == DAC_reg # select rows for specific DAC
        datareg = dacData[sel] # slice dataframe for specific DAC
        vfatCnt0 = 0 # Initialize vfat counter

        if numVfats <= 3:
            fig, ax = plt.subplots(1, numVfats, figsize=(numVfats*10,10))
        elif numVfats <= 6:
            fig, ax = plt.subplots(2, 3, figsize=(30,20))
        elif numVfats <= 12:
            fig, ax = plt.subplots(2, 6, figsize=(60,20))
        elif numVfats <= 18:
            fig, ax = plt.subplots(3, 6, figsize=(60,30))
        elif numVfats <= 24:
            fig, ax = plt.subplots(4, 6, figsize=(60,40))

        if DAC_reg == "CFG_THR_ARM_DAC":
            thr_filename_out = directoryName + "/converted_values" + oh + "_" + DAC_reg + ".txt"
            thr_pd = pd.DataFrame()

        for vfat in datareg.vfat.unique(): # loop over vfats
            print(Colors.GREEN + "\n  Working on VFAT: %s\n" % vfat+ Colors.ENDC)
            sel2 = datareg.vfat == vfat # select rows for the current vfat
            datavfat = datareg[sel2].reset_index() # reset starting index of sliced dataframe to 0
            slopeTemp = np.array(calData.loc[calData["vfat"] == vfat].slope) # get slope for VFAT
            interTemp = np.array(calData.loc[calData["vfat"] == vfat].intercept) # get intercept for VFAT
            #print("VFAT: {}, slope: {}, intercept: {}".format(vfat, slopeTemp, interTemp))
            #print("vfat data: {}".format(datavfat["value"]))

            datavfat["value"] = (datavfat["value"] * slopeTemp) + interTemp # transform data from DAC to mV
            datavfat["error"] = (datavfat["error"] * slopeTemp)
            if nominalDacValues[DAC_reg][1] == "uA":
                datavfat["value"] /= 20.0 # change current DACs to uA (20kOhm resistor)
                datavfat["error"] /= 20.0
                if DAC_reg!="CFG_IREF":
                    datavfat["value"] -= nominal_iref
            datavfat["value"] /= nominalDacScalingFactors[DAC_reg] # use scale factor
            datavfat["error"] /= nominalDacScalingFactors[DAC_reg]
            #print("vfat data after transformation: {}".format(datavfat["value"]))
            if DAC_reg == "CFG_THR_ARM_DAC":
                thr_pd = thr_pd.append(datavfat)
            datavfat2 = datavfat

            # convert data to np arrays for plotting
            xdata = datavfat["value"].to_numpy()
            xerror = datavfat["error"].to_numpy()
            ydata = datavfat["DAC_point"].to_numpy()

            #if DAC_reg == "CFG_HYST" or DAC_reg == "CFG_BIAS_PRE_I_BLCC":
            #    xdata = xdata / 1000 # convert to uA
            #    datavfat["value"] = datavfat["value"] / 1000

            xlabel_plot = ""
            if nominalDacValues[DAC_reg][1] == "uA":
                xlabel_plot = "ADC0 ($\mu$A)"
            else:
                xlabel_plot = "ADC0 (%s)" % nominalDacValues[DAC_reg][1]

            if numVfats == 1:
                ax.grid()
                ax.errorbar(datavfat.value, datavfat.DAC_point, xerr=datavfat.error, fmt="ko", markersize=7, fillstyle="none") # plot transformed data
                ax.set_xlabel(xlabel_plot, loc = 'right')
                ax.set_ylabel("%s register value (DAC)" % DAC_reg, loc = 'top')
                ax.set_title("VFAT%02d"%vfat)
                ax.text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax.transAxes)
                ax.text(0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=26, transform=ax.transAxes)
            elif numVfats <= 3:
                ax[vfatCnt0].grid()
                ax[vfatCnt0].errorbar(datavfat.value, datavfat.DAC_point, xerr=datavfat.error, fmt="ko", markersize=7, fillstyle="none") # plot transformed data
                ax[vfatCnt0].set_xlabel(xlabel_plot, loc = 'right')
                ax[vfatCnt0].set_ylabel("%s register value (DAC)" % DAC_reg, loc = 'top')
                ax[vfatCnt0].set_title("VFAT%02d" % vfat)
                ax[vfatCnt0].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax[vfatCnt0].transAxes)
                ax[vfatCnt0].text(0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=26, transform=ax[vfatCnt0].transAxes)
            elif numVfats <= 6:
                ax[int(vfatCnt0/3), vfatCnt0%3].grid()
                ax[int(vfatCnt0/3), vfatCnt0%3].errorbar(datavfat.value, datavfat.DAC_point, xerr=datavfat.error, fmt="ko", markersize=7, fillstyle="none") # plot transformed data
                ax[int(vfatCnt0/3), vfatCnt0%3].set_xlabel(xlabel_plot, loc = 'right')
                ax[int(vfatCnt0/3), vfatCnt0%3].set_ylabel("%s register value (DAC)" % DAC_reg, loc = 'top')
                ax[int(vfatCnt0/3), vfatCnt0%3].set_title("VFAT%02d" % vfat)
                ax[int(vfatCnt0/3), vfatCnt0%3].text(-0.1, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax[int(vfatCnt0/3), vfatCnt0%3].transAxes)
                ax[int(vfatCnt0/3), vfatCnt0%3].text(0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=26, transform=ax[int(vfatCnt0/3), vfatCnt0%3].transAxes)
            else:
                ax[int(vfatCnt0/6), vfatCnt0%6].grid()
                ax[int(vfatCnt0/6), vfatCnt0%6].errorbar(datavfat.value, datavfat.DAC_point, xerr=datavfat.error, fmt="ko", markersize=7, fillstyle="none") # plot transformed data
                ax[int(vfatCnt0/6), vfatCnt0%6].set_xlabel(xlabel_plot, loc = 'right')
                ax[int(vfatCnt0/6), vfatCnt0%6].set_ylabel("%s register value (DAC)" % DAC_reg, loc = 'top')
                ax[int(vfatCnt0/6), vfatCnt0%6].set_title("VFAT%02d" % vfat)
                ax[int(vfatCnt0/6), vfatCnt0%6].text(-0.12, 1.01, 'CMS', fontweight='bold', fontsize=28, transform=ax[int(vfatCnt0/6), vfatCnt0%6].transAxes)
                ax[int(vfatCnt0/6), vfatCnt0%6].text(0.02, 1.01, 'Muon R&D',fontstyle='italic', fontsize=26, transform=ax[int(vfatCnt0/6), vfatCnt0%6].transAxes)

            if DAC_reg not in ["CFG_CAL_DAC_V_HIGH", "CFG_CAL_DAC_V_LOW"]:         
                fitData = np.polyfit(xdata, ydata, 5) # fit data to 5th degree polynomial

                datavfat2["DAC_point"] = pd.DataFrame(poly5(xdata, *fitData), columns=["DAC_point"]) # adds fitted data to dataframe
                nml = nominalDacValues[DAC_reg][0] # store nominal DAC value
                nominal_ADC0 = int(determine_nom(datavfat2, nml)) # find nominal value for specific vfat
                if nominal_ADC0 > max(datavfat.DAC_point):
                    nominal_ADC0 = max(datavfat.DAC_point)

            # Only for CAL_DAC
            if cal_dac_derive and (DAC_reg=="CFG_CAL_DAC_V_HIGH" or DAC_reg=="CFG_CAL_DAC_V_LOW"):
                cal_dac_data_x = ydata
                cal_dac_data_y = xdata
                if DAC_reg=="CFG_CAL_DAC_V_HIGH":
                    fitData_cal_dac = np.polyfit(cal_dac_data_x, cal_dac_data_y, 1)
                    vfat_cal_dac[vfat]["slope_high"] = fitData_cal_dac[0]
                    vfat_cal_dac[vfat]["intercept_high"] = fitData_cal_dac[1]
                elif DAC_reg=="CFG_CAL_DAC_V_LOW":
                    vfat_cal_dac[vfat]["slope_low"] = 0
                    vfat_cal_dac[vfat]["intercept_low"] = np.mean(cal_dac_data_y)

            # Plot fit
            if DAC_reg not in ["CFG_CAL_DAC_V_HIGH", "CFG_CAL_DAC_V_LOW"]:
                if numVfats == 1:
                    ax.plot(xdata, poly5(xdata, *fitData), "r-", linewidth=3) # plot fit
                elif numVfats <= 3:
                    ax[vfatCnt0].plot(xdata, poly5(xdata, *fitData), "r-", linewidth=3) # plot fit
                elif numVfats <= 6:
                    ax[int(vfatCnt0/3), vfatCnt0%3].plot(xdata, poly5(xdata, *fitData), "r-", linewidth=3) # plot fit
                else:
                    ax[int(vfatCnt0/6), vfatCnt0%6].plot(xdata, poly5(xdata, *fitData), "r-", linewidth=3) # plot fit
                dac_nominal_file.write("%s;%i;%i\n" % (DAC_reg, vfat, nominal_ADC0))

            vfatCnt0 += 1

        if DAC_reg == "CFG_THR_ARM_DAC":
            thr_pd.to_csv(thr_filename_out)

        #fig.suptitle(DAC_reg, fontsize=32) # place DAC name for main title
        #fig.subplots_adjust(top=0.88) # adjust main title
        fig.tight_layout()
        plt.savefig(directoryName + "/DAC_summaryPlots_%s_%s.pdf"%(oh, DAC_reg))
        if DAC_reg not in ["CFG_CAL_DAC_V_HIGH", "CFG_CAL_DAC_V_LOW"]:
            dac_nominal_file.close()
        #print("Total time to execute: %s s" % str(time() - startTime))
        plt.close()

    if cal_dac_derive:
        caldacfile = open(caldacFileName, "a")
        for vfat in vfat_list:
            slope = vfat_cal_dac[vfat]["slope_high"] * (1e-3 * 100) # in fC/DAC
            intercept = (vfat_cal_dac[vfat]["intercept_high"] - vfat_cal_dac[vfat]["intercept_low"]) * (1e-3 * 100) # in fC
            caldacfile.write("%d;%d;%.4f;%.4f\n"%(vfat, vfat_cal_dac[vfat]["vfat_serial_num"], slope, intercept))
        caldacfile.close()
    print(Colors.GREEN + "\nPlots saved at: %s \n" % directoryName + Colors.ENDC)

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="LpGBT VFAT DAC Scan Results")
    parser.add_argument("-f", "--inFile", action="store", dest="inFile", help="Input file")
    args = parser.parse_args()

    if args.inFile is None:
        print(Colors.YELLOW + "Input file must be input" + Colors.ENDC)
        sys.exit()

    directoryName        = args.inFile.split(".txt")[0]
    plot_filename_prefix = (directoryName.split("/"))[3]
    oh = plot_filename_prefix.split("_vfat")[0]
    print(Colors.GREEN + "\nDAC scan results stored in: %s" % directoryName + Colors.ENDC)

    calFile = "results/vfat_data/vfat_calib_data/"+oh+"_vfat_calib_info_adc0.txt"
    if not os.path.isfile(calFile):
        print(Colors.YELLOW + "Calib file for ADC0 must be present in the correct directory" + Colors.ENDC)
        sys.exit()

    try:
        os.makedirs(directoryName) # create directory for dac scan results
    except FileExistsError: # skip if directory already exists
        pass

    try:
        main(args.inFile, calFile, directoryName, oh)
    except KeyboardInterrupt:
        print(Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)


