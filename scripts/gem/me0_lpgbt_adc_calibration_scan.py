from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep, time
import sys
import argparse
import csv
import matplotlib.pyplot as plt
import os
import datetime
import numpy as np

def poly5(x, a, b, c, d, e, f):
    return (a * np.power(x,5)) + (b * np.power(x,4)) + (c * np.power(x,3)) + (d * np.power(x,2)) + (e * x) + f

def main(system, oh_ver, oh_select, gbt_select, boss, gain):

    init_adc(oh_ver)

    if boss == 1: 
        channel = 7 # master_adc_in7
    else:
        channel = 3 # servant_adc_in3

    print("ADC Calibration Scan:")

    resultDir = "results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    me0Dir = "results/me0_lpgbt_data"
    try:
        os.makedirs(me0Dir) # create directory for ME0 lpGBT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = "results/me0_lpgbt_data/adc_calibration_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    foldername = dataDir + "/"
    filename = foldername + "ME0_OH%d_GBT%d_adc_calibration_data_"%(oh_select, gbt_select) + now + ".txt"
    filename_results = foldername + "ME0_OH%d_GBT%d_adc_calibration_results_"%(oh_select, gbt_select) + now + ".txt"

    filename_file = open(filename, "w")
    filename_file.write("#DAC    Vin    Vout\n")
    Vin_range = []
    Vout_range = []

    R = 1e3
    LSB = 3.55e-06
    DAC_range = range(0, 256, 1)

    reg_data = convert_adc_reg(channel)
    writeReg(getNode("LPGBT.RWF.VOLTAGE_DAC.CURDACENABLE"), 0x1, 0)  # Enables current DAC.
    writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACCHNENABLE"), reg_data, 0)

    for DAC in DAC_range:
        I = DAC * LSB
        Vin = I * R

        writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACSELECT"), DAC, 0)  # Sets output current for the current DAC.
        sleep(0.01)

        Vout = 0
        if system == "dryrun":
            Vout = Vin
        else:
            Vout = read_adc(channel, gain, system) * (1.0/1024.0)

        Vin_range.append(Vin)
        Vout_range.append(Vout)
        print ("  DAC: %d,  Vin: %.4f V,  Vout: %.4f V"%(DAC, Vin, Vout))
        filename_file.write("%d    %.4f    %.4f\n"%(DAC, Vin, Vout))

    filename_file.close()
    writeReg(getNode("LPGBT.RWF.VOLTAGE_DAC.CURDACENABLE"), 0x0, 0)  # Enables current DAC.
    writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACSELECT"), 0x0, 0)  # Sets output current for the current DAC.
    writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACCHNENABLE"), 0x0, 0)
    sleep(0.01)

    print ("\nFitting\n")
    filename_results_file = open(filename_results, "w")
    fitData = np.polyfit(np.array(Vin_range), np.array(Vout_range), 5) # fit data to 5th degree polynomial
    Vin_range_fit = np.linspace(0,1,1000)
    Vout_range_fit = poly5(Vin_range_fit, *fitData)
    for m in fitData:
        filename_results_file.write("%.4f    "%m)
    filename_results_file.write("\n")
    filename_results_file.close()

    print ("\nPlotting\n")
    fig, ax = plt.subplots()
    ax.set_xlabel("Vin (V)")
    ax.set_ylabel("Vout (V)")
    ax.plot(Vin_range, Vout_range, "turquoise", marker='o')
    ax.plot(Vin_range_fit, Vout_range_fit, "red")
    plt.draw()
    figure_name = foldername + "ME0_OH%d_GBT%d_calibration_data_"%(oh_select, gbt_select) + now + "_plot.pdf"
    fig.savefig(figure_name, bbox_inches="tight")

    powerdown_adc(oh_ver)

def convert_adc_reg(adc):
    reg_data = 0
    bit = adc
    reg_data |= (0x01 << bit)
    return reg_data

def init_adc(oh_ver):
    writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x1, 0)  # enable ADC
    writeReg(getNode("LPGBT.RW.ADC.TEMPSENSRESET"), 0x1, 0)  # resets temp sensor
    writeReg(getNode("LPGBT.RW.ADC.VDDMONENA"), 0x1, 0)  # enable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDTXMONENA"), 0x1, 0)  # enable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDRXMONENA"), 0x1, 0)  # enable dividers
    if oh_ver == 1:
        writeReg(getNode("LPGBT.RW.ADC.VDDPSTMONENA"), 0x1, 0)  # enable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDANMONENA"), 0x1, 0)  # enable dividers
    writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFENABLE"), 0x1, 0)  # vref enable
    writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFTUNE"), 0x63, 0) # vref tune
    sleep(0.01)

def powerdown_adc(oh_ver):
    writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x0, 0)  # disable ADC
    writeReg(getNode("LPGBT.RW.ADC.TEMPSENSRESET"), 0x0, 0)  # disable temp sensor
    writeReg(getNode("LPGBT.RW.ADC.VDDMONENA"), 0x0, 0)  # disable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDTXMONENA"), 0x0, 0)  # disable dividers
    if oh_ver == 1:
        writeReg(getNode("LPGBT.RW.ADC.VDDPSTMONENA"), 0x0, 0)  # enable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDRXMONENA"), 0x0, 0)  # disable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDANMONENA"), 0x0, 0)  # disable dividers
    writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFENABLE"), 0x0, 0)  # vref disable
    writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFTUNE"), 0x0, 0) # vref tune

def read_adc(channel, gain, system):

    writeReg(getNode("LPGBT.RW.ADC.ADCINPSELECT"), channel, 0)
    writeReg(getNode("LPGBT.RW.ADC.ADCINNSELECT"), 0xf, 0)

    gain_settings = {
        2: 0x00,
        8: 0x01,
        16: 0x10,
        32: 0x11
    }
    writeReg(getNode("LPGBT.RW.ADC.ADCGAINSELECT"), gain_settings[gain], 0)
    writeReg(getNode("LPGBT.RW.ADC.ADCCONVERT"), 0x1, 0)

    done = 0
    while (done == 0):
        if system != "dryrun":
            done = readReg(getNode("LPGBT.RO.ADC.ADCDONE"))
        else:
            done = 1

    val = readReg(getNode("LPGBT.RO.ADC.ADCVALUEL"))
    val |= (readReg(getNode("LPGBT.RO.ADC.ADCVALUEH")) << 8)

    writeReg(getNode("LPGBT.RW.ADC.ADCCONVERT"), 0x0, 0)
    writeReg(getNode("LPGBT.RW.ADC.ADCGAINSELECT"), 0x0, 0)
    writeReg(getNode("LPGBT.RW.ADC.ADCINPSELECT"), 0x0, 0)
    writeReg(getNode("LPGBT.RW.ADC.ADCINNSELECT"), 0x0, 0)

    return val

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="ADC Precision Calibration Scan for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-a", "--gain", action="store", dest="gain", default = "2", help="gain = Gain for ADC: 2, 8, 16, 32")
    args = parser.parse_args()

    if args.system == "chc":
        print("Using Rpi CHeeseCake for scanning ADC precision calibration resistor")
    elif args.system == "backend":
        print ("Using Backend for scanning ADC precision calibration resistor")
    elif args.system == "dryrun":
        print("Dry Run - not actually running adc scan")
    else:
        print(Colors.YELLOW + "Only valid options: chc, backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem != "ME0":
        print(Colors.YELLOW + "Valid gem station: ME0" + Colors.ENDC)
        sys.exit()

    if args.ohid is None:
        print(Colors.YELLOW + "Need OHID" + Colors.ENDC)
        sys.exit()
    #if int(args.ohid) > 1:
    #    print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
    #    sys.exit()
    
    if args.gbtid is None:
        print(Colors.YELLOW + "Need GBTID" + Colors.ENDC)
        sys.exit()
    if int(args.gbtid) > 7:
        print(Colors.YELLOW + "Only GBTID 0-7 allowed" + Colors.ENDC)
        sys.exit()

    oh_ver = get_oh_ver(args.ohid, args.gbtid)
    if oh_ver == 1:
        print(Colors.YELLOW + "Only OH-v2 is allowed" + Colors.ENDC)
        sys.exit()
    boss = None
    if int(args.gbtid)%2 == 0:
        boss = 1
    else:
        boss = 0

    if args.gain not in ["2", "8", "16", "32"]:
        print(Colors.YELLOW + "Allowed values of gain = 2, 8, 16, 32" + Colors.ENDC)
        sys.exit()
    gain = int(args.gain)

    # Initialization 
    rw_initialize(args.gem, args.system, oh_ver, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun":
        check_rom_readback(args.ohid, args.gbtid)
        check_lpgbt_mode(boss, args.ohid, args.gbtid)

    # Check if GBT is READY
    check_lpgbt_ready(args.ohid, args.gbtid)

    try:
        main(args.system, oh_ver, int(args.ohid), int(args.gbtid), boss, gain)
    except KeyboardInterrupt:
        print(Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
