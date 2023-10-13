from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep, time
import sys
import argparse
import csv
import matplotlib.pyplot as plt
import os
import datetime
import numpy as np
from gem.me0_lpgbt_adc import *

def main(system, oh_ver, oh_select, gbt_select, boss, gain):

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

    R_load = 1e3
    DAC_range = range(1, 256, 1)

    chip_id = read_chip_id(system, oh_ver)
    adc_calib = read_central_adc_calib_file()
    junc_temp, junc_temp_unc = read_junc_temp(system, chip_id, adc_calib)
    vref_tune, vref_tune_unc = read_vref_tune(chip_id, adc_calib, junc_temp, junc_temp_unc)
    init_adc(oh_ver, vref_tune)

    for DAC in DAC_range:
        current = get_current_from_dac(chip_id, adc_calib, junc_temp, channel, R_load, DAC)
        Vin = current * R_load

        init_current_dac(channel, DAC)
        sleep(0.01)

        Vout = 0
        if system == "dryrun":
            Vout = Vin
        else:
            adc_value = read_adc(channel, gain, system)
            Vout = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value, gain)

        Vin_range.append(Vin)
        Vout_range.append(Vout)
        print ("  DAC: %d,  Vin: %.4f V,  Vout: %.4f V"%(DAC, Vin, Vout))
        filename_file.write("%d    %.4f    %.4f\n"%(DAC, Vin, Vout))

        powerdown_current_dac()

    filename_file.close()
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

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="ADC Precision Calibration Scan for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or queso or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-a", "--gain", action="store", dest="gain", default = "2", help="gain = Gain for ADC: 2, 8, 16, 32")
    args = parser.parse_args()

    if args.system == "chc":
        print("Using Rpi CHeeseCake for scanning ADC precision calibration resistor")
    elif args.system == "queso":
        print("Using QUESO for scanning ADC precision calibration resistor")
    elif args.system == "backend":
        print ("Using Backend for scanning ADC precision calibration resistor")
    elif args.system == "dryrun":
        print("Dry Run - not actually running adc scan")
    else:
        print(Colors.YELLOW + "Only valid options: chc, queso, backend, dryrun" + Colors.ENDC)
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

    # Check if GBT is READY
    check_lpgbt_ready(args.ohid, args.gbtid)

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun":
        check_rom_readback(args.ohid, args.gbtid)
        check_lpgbt_mode(boss, args.ohid, args.gbtid)

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
