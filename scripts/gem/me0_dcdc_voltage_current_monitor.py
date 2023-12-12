from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep, time
import sys
import argparse
import csv
import matplotlib.pyplot as plt
import os, glob
import datetime
import numpy as np
from common.utils import get_befe_scripts_dir
from gem.me0_lpgbt_adc import *

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
    dataDir = me0Dir + "/lpgbt_dcdc_voltage_current_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/ME0_OH%d_GBT%d_dcdc_voltage_current_data_"%(oh_select, gbt_select) + now + ".txt"

    open(filename, "w+").close()
    if gbt == 0:
        minutes, vin, v_1v2d, i_1v2d, i_diff_1v2d = [], [], [], [], []
    elif gbt == 2:
        minutes, v_1v2a, i_1v2a, i_diff_1v2a = [], [], [], []

    run_time_min = float(run_time_min)

    fig1, ax1 = plt.subplots()
    ax1.set_xlabel("minutes")
    ax1.set_ylabel("PG Current (A)")
    fig2, ax2 = plt.subplots()
    ax2.set_xlabel("minutes")
    ax2.set_ylabel("PG Voltage (V)")
    #ax.set_xticks(range(0,run_time_min+1))
    #ax.set_xlim([0,run_time_min])
    start_time = int(time())
    end_time = int(time()) + (60 * run_time_min)

    file_out = open(filename, "w")
    if gbt == 0:
        file_out.write("Time (min) \t V_IN Voltage (V) \t 1.2VD Voltage (V) \t 1.2VD Current (A) \t 1.2VD Current (Differential Measurement) (A)\n")
    elif gbt == 2:
        file_out.write("Time (min) \t 1.2VA Voltage (V) \t 1.2VA Current (A) \t 1.2VA Current (Differential Measurement) (A)\n")
    t0 = time()
    nrun = 0
    first_reading = 1
    while ((run_time_min != 0 and int(time()) <= end_time) or (nrun < niter)):
        read_adc_iter = 1
        if (run_time_min != 0 and not first_reading and (time()-t0)<=60):
            read_adc_iter = 0

        if read_adc_iter:
            adc_value_vin = -9999
            adc_value_1v2d_p = -9999
            adc_value_1v2d_n = -9999
            adc_value_1v2d_pn = -9999
            adc_value_1v2a_p = -9999
            adc_value_1v2a_n = -9999
            adc_value_1v2a_pn = -9999
            if gbt == 0:
                if oh_ver == 1:
                    adc_value_vin = read_adc(4, gain, system)
                    adc_value_1v2d_p = read_adc(3, gain, system)
                    adc_value_1v2d_n = read_adc(1, gain, system)
                    adc_value_1v2d_pn = read_adc(3, gain, system, 1)
                elif oh_ver == 2:
                    adc_value_vin = read_adc(6, gain, system)
                    adc_value_1v2d_p = read_adc(3, gain, system)
                    adc_value_1v2d_n = read_adc(0, gain, system)
                    adc_value_1v2d_pn = read_adc(3, gain, system, 0)
            elif gbt == 2:
                if oh_ver == 1:
                    adc_value_1v2a_p = read_adc(3, gain, system)
                    adc_value_1v2a_n = read_adc(1, gain, system)
                    adc_value_1v2a_pn = read_adc(3, gain, system, 1)
                elif oh_ver == 2:
                    adc_value_1v2a_p = read_adc(3, gain, system)
                    adc_value_1v2a_n = read_adc(0, gain, system)
                    adc_value_1v2a_pn = read_adc(3, gain, system, 0)

            vin_converted = -9999
            v_1v2d_converted = -9999
            i_1v2d_converted = -9999
            i_diff_1v2d_converted = -9999
            v_1v2a_converted = -9999
            i_1v2a_converted = -9999
            i_diff_1v2a_converted = -9999
            if gbt == 0:
                adc_value_vin_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_vin, gain)
                adc_value_1v2d_p_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_1v2d_p, gain)
                adc_value_1v2d_n_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_1v2d_n, gain)
                adc_value_1v2d_pn_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_1v2d_pn, gain)
                vin_converted = adc_value_vin_Vin * ((750 + 10000)/750)
                v_1v2d_p_converted = adc_value_1v2d_p_Vin * 2
                v_1v2d_n_converted = adc_value_1v2d_n_Vin * 2
                v_1v2d_pn_converted = adc_value_1v2d_pn_Vin * 2
                v_1v2d_converted = (v_1v2d_p_converted + v_1v2d_n_converted)/2.0
                i_1v2d_converted = (v_1v2d_p_converted - v_1v2d_n_converted)/0.01
                i_diff_1v2d_converted = v_1v2d_pn_converted/0.01
                vin.append(vin_converted)
                v_1v2d.append(v_1v2d_converted)
                i_1v2d.append(i_1v2d_converted)
                i_diff_1v2d.append(i_diff_1v2d_converted)
            elif gbt == 2:
                adc_value_1v2a_p_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_1v2a_p, gain)
                adc_value_1v2a_n_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_1v2a_n, gain)
                adc_value_1v2a_pn_Vin = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value_1v2a_pn, gain)
                v_1v2a_p_converted = adc_value_1v2a_p_Vin * 2
                v_1v2a_n_converted = adc_value_1v2a_n_Vin * 2
                v_1v2a_pn_converted = adc_value_1v2a_pn_Vin * 2
                v_1v2a_converted = (v_1v2a_p_converted + v_1v2a_n_converted)/2.0
                i_1v2a_converted = (v_1v2a_p_converted - v_1v2a_n_converted)/0.01
                i_diff_1v2a_converted = v_1v2a_pn_converted/0.01
                v_1v2a.append(v_1v2a_converted)
                i_1v2a.append(i_1v2a_converted)
                i_diff_1v2a.append(i_diff_1v2a_converted)
            second = time() - start_time
            minutes.append(second/60.0)
            
            if plot:
                if gbt == 0:
                    live_plot_current(ax1, minutes, vin, v_1v2d, run_time_min, gbt)
                    live_plot_voltage(ax2, minutes, i_1v2d, i_diff_1v2d, run_time_min, gbt)
                elif gbt == 2:
                    live_plot_current(ax1, minutes, v_1v2a, None, run_time_min, gbt)
                    live_plot_voltage(ax2, minutes, i_1v2a, i_diff_1v2a, run_time_min, gbt)

            if gbt == 0:
                file_out.write(str(second/60.0) + "\t" + str(vin_converted) + "\t" + str(v_1v2d_converted) + "\t" + str(i_1v2d_converted) + "\t" + str(i_diff_1v2d_converted) + "\n" )
                print("Time: " + "{:.2f}".format(second/60.0) + " min \t V_IN Voltage: " + "{:.3f}".format(vin_converted) + " V \t 1.2VD Voltage: " + "{:.3f}".format(v_1v2d_converted) + " V \t 1.2VD Current: " + "{:.3f}".format(i_1v2d_converted) + " A \t 1.2VD Current (Differential Measurement): " + "{:.3f}".format(i_diff_1v2d_converted) + " A \n" )
            elif gbt == 2:
                file_out.write(str(second/60.0) + "\t" + str(v_1v2a_converted) + "\t" + str(v_1v2d_converted) + "\t" + str(i_1v2a_converted) + "\t" + str(i_diff_1v2a_converted) + "\n" )
                print("Time: " + "{:.2f}".format(second/60.0) + " min \t 1.2VA Voltage: " + "{:.3f}".format(v_1v2a_converted) + " V \t 1.2VA Current: " + "{:.3f}".format(i_1v2a_converted) + " A \t 1.2VA Current (Differential Measurement): " + "{:.3f}".format(i_diff_1v2a_converted) + " A \n" )
            t0 = time()
            if first_reading:
                first_reading = 0

        if run_time_min == 0:
            nrun += 1
            sleep(0.1)

    file_out.close()

    if gbt == 0:
        figure_name3 = dataDir + "/ME0_OH%d_GBT%d_Vin_voltage_"%(oh_select, gbt_select) + now + "_plot.pdf"
        figure_name4 = dataDir + "/ME0_OH%d_GBT%d_1V2D_voltage_"%(oh_select, gbt_select) + now + "_plot.pdf"
        figure_name5 = dataDir + "/ME0_OH%d_GBT%d_1V2D_current_"%(oh_select, gbt_select) + now + "_plot.pdf"
        fig3, ax3 = plt.subplots()
        fig4, ax4 = plt.subplots()
        fig5, ax5 = plt.subplots()
        ax3.set_xlabel("minutes")
        ax3.set_ylabel("Vin Voltage (V)")
        ax4.set_xlabel("minutes")
        ax4.set_ylabel("1.2VD Voltage (V)")
        ax5.set_xlabel("minutes")
        ax5.set_ylabel("1.2VD Current (V)")
        ax3.plot(minutes, vin, color="red")
        ax4.plot(minutes, v_1v2d, color="red")
        ax5.plot(minutes, i_1v2d, color="red", label="1.2VD Current")
        ax5.plot(minutes, i_diff_1v2d, color="blue", label="1.2VD Current Differential")
        ax5.legend(loc="center right")
        fig3.savefig(figure_name3, bbox_inches="tight")
        fig4.savefig(figure_name4, bbox_inches="tight")
        fig5.savefig(figure_name5, bbox_inches="tight")
    elif gbt == 2:
        figure_name3 = dataDir + "/ME0_OH%d_GBT%d_1V2A_voltage_"%(oh_select, gbt_select) + now + "_plot.pdf"
        figure_name4 = dataDir + "/ME0_OH%d_GBT%d_1V2A_current_"%(oh_select, gbt_select) + now + "_plot.pdf"
        fig3, ax3 = plt.subplots()
        fig4, ax4 = plt.subplots()
        ax3.set_xlabel("minutes")
        ax3.set_ylabel("1.2VA Voltage (V)")
        ax4.set_xlabel("minutes")
        ax4.set_ylabel("1.2VA Current (V)")
        ax3.plot(minutes, v_1v2a, color="red")
        ax4.plot(minutes, i_1v2a, color="red", label="1.2VA Current")
        ax4.plot(minutes, i_diff_1v2a, color="blue", label="1.2VA Current Differential")
        ax4.legend(loc="center right")
        fig3.savefig(figure_name3, bbox_inches="tight")
        fig4.savefig(figure_name4, bbox_inches="tight")

    powerdown_adc(oh_ver)

def live_plot_current(ax1, x, i1, i2, run_time_min, gbt):
    line1, = ax1.plot(x, i1, "red")
    line2, = ax1.plot(x, i2, "black")
    if gbt == 0:
        ax1.legend((line1, line2), ("1.2VD current", "1.2VD current differential"), loc="center right")
    elif gbt == 2:
        ax1.legend((line1, line2), ("1.2VA current", "1.2VA current differential"), loc="center right")
    plt.draw()
    plt.pause(0.01)

def live_plot_voltage(ax2, x, v1, v2, run_time_min, gbt):
    line1, = ax2.plot(x, v1, "red")
    if v2 is not None:
        line2, = ax2.plot(x, v2, "black")
    if gbt == 0:
        ax2.legend((line1, line2), ("V_in voltage", "1.2VD voltage"), loc="center right")
    elif gbt == 2:
        ax2.legend((line1), ("1.2VA voltage"), loc="center right")
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
    parser = argparse.ArgumentParser(description="DC-DC voltage and current monitoring for ME0 Optohybrid")
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
        print("Using Rpi CHeeseCake for dc-dc voltage and current monitoring")
    elif args.system == "queso":
        print("Using QUESO for dc-dc voltage and current  monitoring")
    elif args.system == "backend":
        print ("Using Backend for dc-dc voltage and current  monitoring")
    elif args.system == "dryrun":
        print("Dry Run - not actually running dc-dc voltage and current  monitoring")
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
