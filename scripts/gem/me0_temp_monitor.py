from gem.me0_lpgbt.rw_reg_lpgbt import *
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

def poly5(x, a, b, c, d, e, f):
    return (a * np.power(x,5)) + (b * np.power(x,4)) + (c * np.power(x,3)) + (d * np.power(x,2)) + (e * x) + f

def get_vin(vout, fit_results):
    vin_range = np.linspace(0, 1, 1000)
    vout_range = poly5(vin_range, *fit_results)
    diff = 9999
    vin = 0
    for i in range(0,len(vout_range)):
        if abs(vout - vout_range[i])<=diff:
            diff = abs(vout - vout_range[i])
            vin = vin_range[i]
    return vin

def main(system, oh_ver, oh_select, gbt_select, boss, device, run_time_min, gain, plot, temp_cal):

    # PT-100 is an RTD (Resistance Temperature Detector) sensor
    # PT (ie platinum) has linear temperature-resistance relationship
    # RTD sensors made of platinum are called PRT (Platinum Resistance Themometer)

    init_adc(oh_ver)
    print("Temperature Readings:")

    adc_calib_results = []
    adc_calibration_dir = "results/me0_lpgbt_data/adc_calibration_data/"
    if not os.path.isdir(adc_calibration_dir):
        print (Colors.YELLOW + "ADC calibration not present, using raw ADC values" + Colors.ENDC)
    list_of_files = glob.glob(adc_calibration_dir+"ME0_OH%d_GBT%d_adc_calibration_results_*.txt"%(oh_select, gbt_select))
    if len(list_of_files)==0:
        print (Colors.YELLOW + "ADC calibration not present, using raw ADC values" + Colors.ENDC)
    elif len(list_of_files)>1:
        print ("Mutliple ADC calibration results found, using latest file")
    if len(list_of_files)!=0:
        latest_file = max(list_of_files, key=os.path.getctime)
        adc_calib_file = open(latest_file)
        adc_calib_results = adc_calib_file.readlines()[0].split()
        adc_calib_results_float = [float(a) for a in adc_calib_results]
        adc_calib_results_array = np.array(adc_calib_results_float)
        adc_calib_file.close()

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
    dataDir = "results/me0_lpgbt_data/temp_monitor_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    foldername = dataDir + "/"
    filename = foldername + "ME0_OH%d_GBT%d_temp_"%(oh_select, gbt_select) + device + "_data_" + now + ".txt"

    open(filename, "w+").close()
    minutes, T = [], []

    run_time_min = float(run_time_min)

    fig, ax = plt.subplots()
    ax.set_xlabel('minutes')
    ax.set_ylabel('T (C)')
    
    if device == "OH":
        channel = 6
    elif device == "VTRX":
        channel = 0
    DAC = 0
    if temp_cal == "10k":
        DAC = 20
    elif temp_cal == "1k":
        DAC = 60
    LSB = 3.55e-06
    I = DAC * LSB
    find_temp = temp_res_fit(temp_cal=temp_cal)

    reg_data = convert_adc_reg(channel)
    writeReg(getNode("LPGBT.RWF.VOLTAGE_DAC.CURDACENABLE"), 0x1, 0)  # Enables current DAC.
    writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACCHNENABLE"), reg_data, 0)
    writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACSELECT"), DAC, 0)  # Sets output current for the current DAC.
    sleep(0.01)

    start_time = int(time())
    end_time = int(time()) + (60 * run_time_min)

    file = open(filename, "w")
    file.write("Time (min) \t Voltage (V) \t Resistance (Ohm) \t Temperature (C)\n")
    t0 = time()
    while int(time()) <= end_time:
        if (time()-t0)>60:
            value = read_adc(channel, gain, system)
            Vout = 1.0 * (value/1024.0) # 10-bit ADC, range 0-1 V
            if len(adc_calib_results)!=0:
                Vin = get_vin(Vout, adc_calib_results_array)
            else:
                Vin = Vout
            R_m = Vin/I
            temp = find_temp(np.log10(R_m))

            second = time() - start_time
            T.append(temp)
            minutes.append(second/60.0)
            if plot:
                live_plot(ax, minutes, T)

            file.write(str(second/60.0) + "\t" + str(Vin) + "\t" + str(R_m) + "\t" + str(temp) + "\n")
            print("time = %.2f min, \tch %X: 0x%03X = %.2fV = %.2f kOhm = %.2f deg C" % (second/60.0, channel, value, Vin, R_m/1000.0, temp))
            t0 = time()
    file.close()

    figure_name = foldername + "ME0_OH%d_GBT%d_temp_"%(oh_select, gbt_select) + device + "_plot_" + now + ".pdf"
    fig1, ax1 = plt.subplots()
    ax1.set_xlabel("minutes")
    ax1.set_ylabel("T (C)")
    ax1.plot(minutes, T, color="turquoise")
    fig1.savefig(figure_name, bbox_inches="tight")

    writeReg(getNode("LPGBT.RWF.VOLTAGE_DAC.CURDACENABLE"), 0x0, 0)  # Enables current DAC.
    writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACSELECT"), 0x0, 0)  #Sets output current for the current DAC.
    writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACCHNENABLE"), 0x0, 0)
    sleep(0.01)

    powerdown_adc(oh_ver)

def convert_adc_reg(adc):
    reg_data = 0
    bit = adc
    reg_data |= (0x01 << bit)
    return reg_data

def temp_res_fit(temp_cal="10k", power=2):

    if temp_cal=="10k":
        B_list = [3900, 3934, 3950, 3971]  # OH: NTCG103UH103JT1, VTRX+ 10k: NTCG063UH103HTBX
        T_list = [50, 75, 85, 100]
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
    writeReg(getNode("LPGBT.RW.ADC.VDDRXMONENA"), 0x0, 0)  # disable dividers
    if oh_ver == 1:
        writeReg(getNode("LPGBT.RW.ADC.VDDPSTMONENA"), 0x0, 0)  # enable dividers
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
    parser = argparse.ArgumentParser(description="Temperature Monitoring for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-t", "--temp", action="store", dest="temp", help="temp = OH or VTRX")
    parser.add_argument("-m", "--minutes", action="store", dest="minutes", help="minutes = int. # of minutes you want to run")
    parser.add_argument("-p", "--plot", action="store_true", dest="plot", help="plot = enable live plot")
    parser.add_argument("-a", "--gain", action="store", dest="gain", default = "2", help="gain = Gain for ADC: 2, 8, 16, 32")
    args = parser.parse_args()

    if args.system == "chc":
        print("Using Rpi CHeeseCake for temperature monitoring")
    elif args.system == "backend":
        print ("Using Backend for temperature monitoring")
    elif args.system == "dryrun":
        print("Dry Run - not actually running temperature monitoring")
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
    if boss:
        print (Colors.YELLOW + "Only sub lpGBT allowed" + Colors.ENDC)
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
    elif args.temp == "OH":
        temp_cal = "10k"

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
        main(args.system, oh_ver, int(args.ohid), int(args.gbtid), boss, args.temp, args.minutes, gain, args.plot, temp_cal)
    except KeyboardInterrupt:
        print(Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
