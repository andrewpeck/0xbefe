from gem.me0_lpgbt.rw_reg_lpgbt import *
from common.utils import get_befe_scripts_dir
from time import sleep, time
import sys
import argparse
import csv
import matplotlib.pyplot as plt
import os, glob
import datetime
import math
import numpy as np
from me0_lpgbt_vtrx import i2cmaster_write, i2cmaster_read
from gem.me0_lpgbt_adc import *

def main(system, oh_ver, oh_select, gbt_select, boss, device, run_time_min, niter, gain, plot, temp_cal):

    # PT-100 is an RTD (Resistance Temperature Detector) sensor
    # PT (ie platinum) has linear temperature-resistance relationship
    # RTD sensors made of platinum are called PRT (Platinum Resistance Themometer)

    chip_id = read_chip_id(system, oh_ver)
    adc_calib = read_central_adc_calib_file()
    junc_temp, junc_temp_unc = read_junc_temp(system, chip_id, adc_calib)
    vref_tune, vref_tune_unc = read_vref_tune(chip_id, adc_calib, junc_temp, junc_temp_unc)
    init_adc(oh_ver, vref_tune)
    print("Temperature Readings:")

    adc_calib_results = []
    adc_calib_results_array = []
    if chip_id not in adc_calib:
        adc_calib_results, adc_calib_results_array = get_local_adc_calib_from_file(oh_select, gbt_select)

    scripts_gem_dir = get_befe_scripts_dir() + '/gem'
    resultDir = scripts_gem_dir + "/results"
    me0Dir = resultDir + "/me0_lpgbt_data"
    try:
        os.makedirs(me0Dir) # create directory for ME0 lpGBT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = me0Dir + "/temp_monitor_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/ME0_OH%d_GBT%d_temp_"%(oh_select, gbt_select) + device + "_data_" + now + ".txt"

    open(filename, "w+").close()
    minutes, T = [], []

    run_time_min = float(run_time_min)

    fig, ax = plt.subplots()
    ax.set_xlabel('minutes')
    ax.set_ylabel('T (C)')
    
    channel = -9999
    if device == "OH":
        channel = 6
    elif device == "VTRX":
        channel = 0
    elif device == "lpGBT":
        channel = 14
    elif device == "GEB_1V2D":
        if oh_ver == 1:
            channel = 2
        elif oh_ver == 2:
            channel = 1
    elif device == "GEB_1V2A":
        if oh_ver == 1:
            channel = 2
        elif oh_ver == 2:
            channel = 1
    elif device == "GEB_2V5":
        if oh_ver == 1:
            channel = 4
        elif oh_ver == 2:
            channel = 6

    if temp_cal == "10k":
        current = (0.71/10000) # in A
    elif temp_cal == "1k":
        current = (0.21/1000) # in A

    if device != "lpGBT":
        DAC, R_out = current_dac_conversion_lpgbt(chip_id, adc_calib, junc_temp, channel, current)
        #if temp_cal == "10k":
        #    DAC = 20
        #elif temp_cal == "1k":
        #    DAC = 60
        if chip_id in adc_calib and device == "OH": 
            find_temp = temp_res_fit(temp_cal=temp_cal, type="OH_new")
        else:
            find_temp = temp_res_fit(temp_cal=temp_cal)

        init_current_dac(channel, DAC)
        sleep(0.01)

    start_time = int(time())
    end_time = int(time()) + (60 * run_time_min)

    file = open(filename, "w")
    file.write("Time (min) \t Voltage (V) \t Resistance (Ohm) \t Temperature (C)\n")
    t0 = time()
    nrun = 0
    first_reading = 1
    while ((run_time_min != 0 and int(time()) <= end_time) or (nrun < niter)):
        read_adc_iter = 1
        if (run_time_min != 0 and not first_reading and (time()-t0)<=60):
            read_adc_iter = 0

        if read_adc_iter:
            adc_value = read_adc(channel, gain, system)
            Vout = adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc_value, gain)
            if device != "lpGBT":
                R_m = get_resistance_from_current_dac(chip_id, adc_calib, Vout, current, R_out, adc_calib_results, adc_calib_results_array)
                temp = find_temp(np.log10(R_m))
            else:
                R_m = 0
                temp = get_temp_sensor(chip_id, adc_calib, junc_temp, Vout)

            second = time() - start_time
            T.append(temp)
            minutes.append(second/60.0)
            if plot:
                live_plot(ax, minutes, T)

            file.write(str(second/60.0) + "\t" + str(Vout) + "\t" + str(R_m) + "\t" + str(temp) + "\n")
            print("time = %.2f min, \tch %X: %.2fV = %.2f kOhm = %.2f deg C" % (second/60.0, channel, Vout, R_m/1000.0, temp))
            t0 = time()
            if first_reading:
                first_reading = 0

        if run_time_min == 0:
            nrun += 1
            sleep(0.1)
            
    file.close()

    figure_name = dataDir + "/ME0_OH%d_GBT%d_temp_"%(oh_select, gbt_select) + device + "_plot_" + now + ".pdf"
    fig1, ax1 = plt.subplots()
    ax1.set_xlabel("minutes")
    ax1.set_ylabel("T (C)")
    ax1.plot(minutes, T, color="turquoise")
    fig1.savefig(figure_name, bbox_inches="tight")

    if device != "lpGBT":
        powerdown_current_dac()
        sleep(0.01)

    powerdown_adc(oh_ver)

def temp_res_fit(temp_cal="10k", type="nominal", power=2):

    B_list = []
    T_list = []
    if temp_cal=="10k":
        if type == "OH_new":
            B_list = [3380, 3422, 3435, 3453]  # OH: NTCG103JX103DT1S
            T_list = [50, 75, 85, 100]
        elif type == "OH":
            B_list = [3900, 3934, 3950, 3971]  # OH: NTCG103UH103JT1, VTRX+ 10k: NTCG063UH103HTBX
            T_list = [50, 75, 85, 100]
        elif "GEB" in type:
            B_list = [3380, 3434, 3455]  # GEB: NCP03XH103F05RL
            T_list = [50, 85, 100]
    elif temp_cal=="1k": 
        B_list = [3500, 3539, 3545, 3560]  # VTRX+ 1k: NCP03XM102E05RL
        T_list = [50, 80, 85, 100]
    R_list = []

    for i in range(len(T_list)):
        T_list[i] = T_list[i] + 273.15

    for B, T in zip(B_list, T_list):
        if temp_cal=="10k":
            R = 10e3 * math.exp(-B * ((1/298.15) - (1/T)))
        elif temp_cal=="1k":
            R = 1e3 * math.exp(-B * ((1/298.15) - (1/T)))
        R_list.append(R)

    T_list = [298.15] + T_list
    if temp_cal=="10k":
        R_list = [10000] + R_list
    elif temp_cal=="1k": 
        R_list = [1000] + R_list
        
    for i in range(len(T_list)):
        T_list[i] = T_list[i] - 273.15

    poly_coeffs = np.polyfit(np.log10(R_list), T_list, power)
    fit = np.poly1d(poly_coeffs)

    return fit


def live_plot(ax, x, y):
    ax.plot(x, y, "turquoise")
    plt.draw()
    plt.pause(0.01)

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Temperature Monitoring for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or queso or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-t", "--temp", action="store", dest="temp", help="temp = OH or VTRX or lpGBT or GEB_1V2D or or GEB_1V2A or or GEB_2V5")
    parser.add_argument("-m", "--minutes", action="store", default = "0", dest="minutes", help="minutes = # of minutes you want to run")
    parser.add_argument("-n", "--niter", action="store", default = "0", dest="niter", help="niter = # of measurements")
    parser.add_argument("-p", "--plot", action="store_true", dest="plot", help="plot = enable live plot")
    parser.add_argument("-a", "--gain", action="store", dest="gain", default = "2", help="gain = Gain for ADC: 2, 8, 16, 32")
    args = parser.parse_args()

    if args.system == "chc":
        print("Using Rpi CHeeseCake for temperature monitoring")
    elif args.system == "queso":
        print("Using QUESO for temperature monitoring")
    elif args.system == "backend":
        print ("Using Backend for temperature monitoring")
    elif args.system == "dryrun":
        print("Dry Run - not actually running temperature monitoring")
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
    if args.temp in ["OH", "VTRX", "lpGBT"] and oh_ver == 1:
        print(Colors.YELLOW + "Only OH-v2 is allowed for OH, VTRx+ and lpGBT" + Colors.ENDC)
        sys.exit()
    boss = None
    if int(args.gbtid)%2 == 0:
        boss = 1
    else:
        boss = 0
    if args.temp in ["OH", "VTRX"]:
        if boss:
            print (Colors.YELLOW + "Only sub lpGBT allowed for OH and VTRx+ temperature" + Colors.ENDC)
            sys.exit()
    elif "GEB" in args.temp:
        if not boss:
            print (Colors.YELLOW + "Only boss lpGBT allowed for GEB temperature" + Colors.ENDC)
            sys.exit()
        if args.temp == "GEB_1V2D":
            if int(args.gbtid)%4 != 0:
                print (Colors.YELLOW + "Incorrect boss lpGBT for 1.2VD GEB temperature" + Colors.ENDC)
                sys.exit()
        elif args.temp in ["GEB_1V2A", "GEB_2.5VD"]:
            if int(args.gbtid)%4 == 0:
                print (Colors.YELLOW + "Incorrect boss lpGBT for 1.2VA and 2.5V GEB temperature" + Colors.ENDC)
                sys.exit()
        else:
            print (Colors.YELLOW + "Incorrect GEB temperature" + Colors.ENDC)
            sys.exit()
    else:
        print (Colors.YELLOW + "Incorrect temperature to read" + Colors.ENDC)
        sys.exit()

    if args.gain not in ["2", "8", "16", "32"]:
        print(Colors.YELLOW + "Allowed values of gain = 2, 8, 16, 32" + Colors.ENDC)
        sys.exit()
    gain = int(args.gain)

    # Check VTRx+ version if reading VTRx+ temperature
    temp_cal = ""
    if args.temp == "VTRX":
        gbtid_sub = int(args.gbtid)
        gbtid_boss = str(gbtid_sub-1)
        rw_initialize(args.gem, args.system, oh_ver, boss, args.ohid, gbtid_boss)
        vtrx_id1 = i2cmaster_read(system, oh_ver, 0x16)
        vtrx_id2 = i2cmaster_read(system, oh_ver, 0x17)
        vtrx_id3 = i2cmaster_read(system, oh_ver, 0x18)
        vtrx_id4 = i2cmaster_read(system, oh_ver, 0x19)
        if vtrx_id1 == 0 and vtrx_id2 == 0 and vtrx_id3 == 0 and vtrx_id4 == 0:
            temp_cal = "10k"
        else:
            temp_cal = "1k"
    elif args.temp == "OH" or "GEB" in args.temp:
        temp_cal = "10k"

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
        main(args.system, oh_ver, int(args.ohid), int(args.gbtid), boss, args.temp, args.minutes, int(args.niter), gain, args.plot, temp_cal)
    except KeyboardInterrupt:
        print(Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
