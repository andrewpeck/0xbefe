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

    gbt = gbt_select%4
    print("ADC Readings:")

    chip_id = read_chip_id(system, oh_ver)
    adc_calib = read_central_adc_calib_file()
    junc_temp, junc_temp_unc = read_junc_temp(system, chip_id, adc_calib)
    vref_tune, vref_tune_unc = read_vref_tune(chip_id, adc_calib, junc_temp, junc_temp_unc)
    init_adc(oh_ver, vref_tune)
    
    scripts_gem_dir = get_befe_scripts_dir() + '/gem'
    resultDir = scripts_gem_dir + "/results"
    me0Dir = resultDir + "/me0_lpgbt_data"
    try:
        os.makedirs(me0Dir) # create directory for ME0 lpGBT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = me0Dir + "/lpgbt_asense_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/ME0_OH%d_GBT%d_asense_data_"%(oh_select, gbt_select) + now + ".txt"

    open(filename, "w+").close()
    minutes, asense0, asense1, asense2, asense3 = [], [], [], [], []

    run_time_min = float(run_time_min)

    fig1, ax1 = plt.subplots()
    ax1.set_xlabel("minutes")
    ax1.set_ylabel("PG Current (A)")
    fig2, ax2 = plt.subplots()
    ax2.set_xlabel("minutes")
    ax2.set_ylabel("Rt Voltage (V)")
    #ax.set_xticks(range(0,run_time_min+1))
    #ax.set_xlim([0,run_time_min])
    start_time = int(time())
    end_time = int(time()) + (60 * run_time_min)

    file_out = open(filename, "w")
    if gbt == 0:
        file_out.write("Time (min) \t Asense0 (PG2.5V current) (A) \t Asense1 (Rt2 voltage) (V) \t Asense2 (PG1.2V current) (A) \t Asense3 (Rt1 voltage) (V)\n")
    elif gbt == 2:
        file_out.write("Time (min) \t Asense0 (PG1.2VD current) (A) \t Asense1 (Rt3 voltage) (V) \t Asense2 (PG1.2VA current) (A) \t Asense3 (Rt4 voltage) (V)\n")
    t0 = time()
    nrun = 0
    first_reading = 1
    while ((run_time_min != 0 and int(time()) <= end_time) or (nrun < niter)):
        read_adc_iter = 1
        if (run_time_min != 0 and not first_reading and (time()-t0)<=60):
            read_adc_iter = 0

        if read_adc_iter:
            if oh_ver == 1:
                adc_value0 = read_adc(4, gain, system)
                adc_value1 = read_adc(2, gain, system)
                adc_value2 = read_adc(1, gain, system)
                adc_value3 = read_adc(3, gain, system)
            if oh_ver == 2:
                adc_value0 = read_adc(6, gain, system)
                adc_value1 = read_adc(1, gain, system)
                adc_value2 = read_adc(0, gain, system)
                adc_value3 = read_adc(3, gain, system)

            asense0_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value0, gain)
            asense1_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value1, gain)
            asense2_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value2, gain)
            asense3_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value3, gain)

            asense0_converted = asense_current_conversion(asense0_Vin)
            asense1_converted = asense1_Vin
            asense2_converted = asense_current_conversion(asense2_Vin)
            asense3_converted = asense3_Vin
            second = time() - start_time
            asense0.append(asense0_converted)
            asense1.append(asense1_converted)
            asense2.append(asense2_converted)
            asense3.append(asense3_converted)
            minutes.append(second/60.0)
            
            if plot:
                live_plot_current(ax1, minutes, asense0, asense2, run_time_min, gbt)
                live_plot_temp(ax2, minutes, asense1, asense3, run_time_min, gbt)

            file_out.write(str(second/60.0) + "\t" + str(asense0_converted) + "\t" + str(asense1_converted) + "\t" + str(asense2_converted) + "\t" + str(asense3_converted) + "\n" )
            if gbt == 0:
                print("Time: " + "{:.2f}".format(second/60.0) + " min \t Asense0 (PG2.5V current): " + "{:.3f}".format(asense0_converted) + " A \t Asense1 (Rt2 voltage): " + "{:.3f}".format(asense1_converted) + " V \t Asense2 (PG1.2V current): " + "{:.3f}".format(asense2_converted) + " A \t Asense3 (Rt1 voltage): " + "{:.3f}".format(asense3_converted) + " V \n" )
            elif gbt == 2:
                print("Time: " + "{:.2f}".format(second/60.0) + " min \t Asense0 (PG1.2VD current): " + "{:.3f}".format(asense0_converted) + " A \t Asense1 (Rt3 voltage): " + "{:.3f}".format(asense1_converted) + " V \t Asense2 (PG1.2VA current): " + "{:.3f}".format(asense2_converted) + " A \t Asense3 (Rt4 voltage): " + "{:.3f}".format(asense3_converted) + " V \n" )

            t0 = time()
            if first_reading:
                first_reading = 0

        if run_time_min == 0:
            nrun += 1
            sleep(0.1)

    file_out.close()

    asense0_label = ""
    asense1_label = ""
    asense2_label = ""
    asense3_label = ""
    if gbt==0:
        asense0_label = "PG2.5V current"
        asense1_label = "Rt2 voltage"
        asense2_label = "PG1.2V current"
        asense3_label = "Rt1 voltage"
    if gbt==2:
        asense0_label = "PG1.2VD current"
        asense1_label = "Rt3 voltage"
        asense2_label = "PG1.2VA current"
        asense3_label = "Rt4 voltage"

    figure_name1 = dataDir + "/ME0_OH%d_GBT%d_pg_current_"%(oh_select, gbt_select) + now + "_plot.pdf"
    figure_name2 = dataDir + "/ME0_OH%d_GBT%d_rt_voltage_"%(oh_select, gbt_select) + now + "_plot.pdf"
    fig3, ax3 = plt.subplots()
    fig4, ax4 = plt.subplots()
    ax3.set_xlabel("minutes")
    ax3.set_ylabel("PG Current (A)")
    ax4.set_xlabel("minutes")
    ax4.set_ylabel("Rt Voltage (V)")
    ax3.plot(minutes, asense0, color="red", label=asense0_label)
    ax3.plot(minutes, asense2, color="blue", label=asense2_label)
    ax3.legend(loc="center right")
    ax4.plot(minutes, asense1, color="red", label=asense1_label)
    ax4.plot(minutes, asense3, color="blue", label=asense3_label)
    ax4.legend(loc="center right")
    fig3.savefig(figure_name1, bbox_inches="tight")
    fig4.savefig(figure_name2, bbox_inches="tight")

    powerdown_adc(oh_ver)

def live_plot_current(ax1, x, y0, y2, run_time_min, gbt):
    line0, = ax1.plot(x, y0, "red")
    line2, = ax1.plot(x, y2, "black")
    if gbt in [0,1]:
        ax1.legend((line0, line2), ("PG2.5V current", "PG1.2V current"), loc="center right")
    else:
        ax1.legend((line0, line2), ("PG1.2VD current", "PG1.2VA current"), loc="center right")
    plt.draw()
    plt.pause(0.01)

def live_plot_temp(ax2, x, y1, y3, run_time_min, gbt):
    line1, = ax2.plot(x, y1, "red")
    line3, = ax2.plot(x, y3, "black")
    if gbt in [0,1]:
        ax2.legend((line1, line3), ("Rt2 voltage", "Rt1 voltage"), loc="center right")
    else:
        ax2.legend((line1, line3), ("Rt3 voltage", "Rt4 voltage"), loc="center right")
    plt.draw()
    plt.pause(0.01)

def asense_current_conversion(Vin):
    # Resistor values
    R = 0.01 # 0.01 Ohm

    asense_voltage = Vin
    asense_voltage /= 20 # Gain in current sense circuit
    asense_current = asense_voltage/R # asense current
    return asense_current


if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Asense monitoring for ME0 Optohybrid")
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
        print("Using Rpi CHeeseCake for asense monitoring")
    elif args.system == "queso":
        print("Using QUESO for asense monitoring")
    elif args.system == "backend":
        print ("Using Backend for asense monitoring")
    elif args.system == "dryrun":
        print("Dry Run - not actually running asense monitoring")
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
    if not boss:
        print (Colors.YELLOW + "Only boss lpGBT allowed" + Colors.ENDC)
        sys.exit()
        
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
