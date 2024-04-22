from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep, time
import sys
import argparse
import csv
import matplotlib
import matplotlib.pyplot as plt
import os, glob
import datetime
import numpy as np
from common.utils import get_befe_scripts_dir
from gem.me0_lpgbt_adc import *

matplotlib.use('Agg')

def main(system, oh_ver, oh_select, gbt_select, boss, run_time_min, niter, gain, plot):

    chip_id = read_chip_id(system, oh_ver)
    adc_calib = read_central_adc_calib_file()
    adc_calib = check_chip_id_adc_calib(oh_ver, chip_id, adc_calib)
    junc_temp, junc_temp_unc = read_junc_temp(system, chip_id, adc_calib)
    vref_tune, vref_tune_unc = read_vref_tune(chip_id, adc_calib, junc_temp, junc_temp_unc)
    init_adc(oh_ver, vref_tune)
    print("ADC Readings:")

    scripts_gem_dir = get_befe_scripts_dir() + '/gem'
    resultDir = scripts_gem_dir + "/results"
    me0Dir = resultDir + "/me0_lpgbt_data"
    try:
        os.makedirs(me0Dir) # create directory for ME0 lpGBT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = me0Dir + "/lpgbt_voltage_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/ME0_OH%d_GBT%d_voltage_data_"%(oh_select, gbt_select) + now + ".txt"

    open(filename, "w+").close()
    minutes, v2v5, vssa, vddtx, vddrx, vdd, vdda, vref = [], [], [], [], [], [], [], []

    run_time_min = float(run_time_min)

    fig1, ax1 = plt.subplots()
    ax1.set_xlabel("minutes")
    ax1.set_ylabel("PG Current (A)")
    #ax1.set_xticks(range(0,run_time_min+1))
    #ax1.set_xlim([0,run_time_min])
    start_time = int(time())
    end_time = int(time()) + (60 * run_time_min)

    file_out = open(filename, "w")
    if oh_ver == 1:
        file_out.write("Time (min) \t V2V5 (V) \t VDDIO (internal signal) (V) \t VDDTX (internal signal) (V) \t VDDRX (internal signal) (V) \t VDD (internal signal) (V) \t VDDA (internal signal) (V) \t VREF (internal signal) (V)\n")
    elif oh_ver == 2:
        file_out.write("Time (min) \t V2V5 (V) \t VSSA (internal signal) (V) \t VDDTX (internal signal) (V) \t VDDRX (internal signal) (V) \t VDD (internal signal) (V) \t VDDA (internal signal) (V) \t VREF (internal signal) (V)\n")
    t0 = time()
    nrun = 0
    first_reading = 1
    while ((run_time_min != 0 and int(time()) <= end_time) or (nrun < niter)):
        read_adc_iter = 1
        if (run_time_min != 0 and not first_reading and (time()-t0)<=60):
            read_adc_iter = 0

        if read_adc_iter:
            if oh_ver == 1:
                adc_value_v2v5 = read_adc(6, gain, system)
            elif oh_ver == 2:
                adc_value_v2v5 = read_adc(1, gain, system)
            adc_value_vssa = read_adc(9, gain, system)
            adc_value_vddtx = read_adc(10, gain, system)
            adc_value_vddrx = read_adc(11, gain, system)
            adc_value_vdd = read_adc(12, gain, system)
            adc_value_vdda = read_adc(13, gain, system)
            adc_value_vref = read_adc(15, gain, system)

            v2v5_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_v2v5, gain)
            vssa_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_vssa, gain)
            vddtx_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_vddtx, gain)
            vddrx_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_vddrx, gain)
            vdd_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_vdd, gain)
            vdda_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_vdda, gain)
            vref_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_vref, gain)

            if oh_ver == 1:
                if gbt_select%2 == 0:
                    v2v5_converted = v2v5_Vin*3.0
                else:
                    v2v5_converted = -9999
                vssa_converted = vssa_Vin/0.428
            elif oh_ver == 2:
                if gbt_select%2 == 0:
                    v2v5_converted = -9999
                else:
                    v2v5_converted = v2v5_Vin*3.0
                vssa_converted = vssa_Vin
            vddtx_converted = get_vmon(chip_id, adc_calib, junc_temp, vddtx_Vin)
            vddrx_converted = get_vmon(chip_id, adc_calib, junc_temp, vddrx_Vin)
            vdd_converted = get_vmon(chip_id, adc_calib, junc_temp, vdd_Vin)
            vdda_converted = get_vmon(chip_id, adc_calib, junc_temp, vdda_Vin)
            vref_converted = vref_Vin/0.5

            second = time() - start_time
            v2v5.append(v2v5_converted)
            vssa.append(vssa_converted)
            vddtx.append(vddtx_converted)
            vddrx.append(vddrx_converted)
            vdd.append(vdd_converted)
            vdda.append(vdda_converted)
            vref.append(vref_converted)
            minutes.append(second/60.0)
            
            if plot:
                live_plot_voltage(ax1, minutes, v2v5, vssa, vddtx, vddrx, vdd, vdda, vref, run_time_min)

            file_out.write(str(second/60.0) + "\t" + str(v2v5_converted) + "\t" + str(vssa_converted) + "\t" + str(vddtx_converted) + "\t" + str(vddrx_converted) + "\t" + str(vdd_converted) + "\t" + str(vdda_converted) + "\t" + str(vref_converted) + "\n" )
            print("Time: " + "{:.2f}".format(second/60.0) + " min \t V2V5: " + "{:.3f}".format(v2v5_converted) + " V \t VSSA (Internal Signal): " + "{:.3f}".format(vssa_converted) + " V \t VDDTX (Internal Signal): " + "{:.3f}".format(vddtx_converted) + " V \t VDDRX (Internal Signal): " + "{:.3f}".format(vddrx_converted) + " V \t VDD (Internal Signal): " + "{:.3f}".format(vdd_converted) + " V \t VDDA (Internal Signal): " + "{:.3f}".format(vdda_converted) + " V \t VREF (Internal Signal): " + "{:.3f}".format(vref_converted) + "\n")
            
            t0 = time()
            if first_reading:
                first_reading = 0

        if run_time_min == 0:
            nrun += 1
            sleep(0.1)

    file_out.close()

    figure_name1 = dataDir + "/ME0_OH%d_GBT%d_voltage_"%(oh_select, gbt_select) + now + "_plot.pdf"
    fig3, ax3 = plt.subplots()
    ax3.set_xlabel("minutes")
    ax3.set_ylabel("Voltage (V)")
    ax3.plot(minutes, vssa, color="red", label="V2V5")
    ax3.plot(minutes, vssa, color="blue", label="VSSA")
    ax3.plot(minutes, vddtx, color="black", label="VDDTX")
    ax3.plot(minutes, vddrx, color="green", label="VDDRX")
    ax3.plot(minutes, vdd, color="yellow", label="VDD")
    ax3.plot(minutes, vdda, color="cyan", label="VDDA")
    ax3.plot(minutes, vref, color="magenta", label="VREF")
    ax3.legend(loc="center right")
    fig3.savefig(figure_name1, bbox_inches="tight")

    powerdown_adc(oh_ver)

def live_plot_voltage(ax1, x, y0, y1, y2, y3, y4, y5, y6, run_time_min):
    line0 = ax1.plot(x, y0, "red")
    line1 = ax1.plot(x, y1, "blue")
    line2 = ax1.plot(x, y2, "black")
    line3 = ax1.plot(x, y3, "green")
    line4 = ax1.plot(x, y4, "yellow")
    line5 = ax1.plot(x, y5, "cyan")
    line6 = ax1.plot(x, y6, "magenta")
    ax1.legend((line0, line1, line2, line3, line4, line5, line6), ("V2V5", "VSSA", "VDDTX", "VDDRX", "VDD", "VDDA", "VREF"), loc="center right")
    plt.draw()
    plt.pause(0.01)

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Voltage monitoring for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or queso or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-m", "--minutes", action="store", default = "0", dest="minutes", help="minutes = # of minutes you want to run")
    parser.add_argument("-n", "--niter", action="store", default = "0", dest="niter", help="niter = # of measurements")
    parser.add_argument("-p", "--plot", action="store_true", dest="plot", help="plot = enable live plot")
    parser.add_argument("-a", "--gain", action="store", dest="gain", default = "2", help="gain = Gain for ADC: 2, 8, 16, 32")
    args = parser.parse_args()

    if args.system == "chc":
        print("Using Rpi CHeeseCake for voltage monitoring")
    elif args.system == "queso":
        print("Using QUESO for voltage monitoring")
    elif args.system == "backend":
        print ("Using Backend for voltage monitoring")
    elif args.system == "dryrun":
        print("Dry Run - not actually running voltage monitoring")
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
    if args.system == "backend":
        check_lpgbt_ready(args.ohid, args.gbtid)

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun":
        check_rom_readback(args.ohid, args.gbtid)
        check_lpgbt_mode(boss, args.ohid, args.gbtid)
        
    try:
        main(args.system, oh_ver, int(args.ohid), int(args.gbtid), boss, args.minutes, int(args.niter), gain, args.plot)
    except KeyboardInterrupt:
        print(Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
