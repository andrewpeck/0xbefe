from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep, time
import sys
import argparse
import csv
import matplotlib.pyplot as plt
import os
import datetime
import math
import numpy as np

def main(system, oh_ver, boss, device, run_time_min, gain, plot):

    # PT-100 is an RTD (Resistance Temperature Detector) sensor
    # PT (ie platinum) has linear temperature-resistance relationship
    # RTD sensors made of platinum are called PRT (Platinum Resistance Themometer)

    init_adc(oh_ver)

    cal_channel = 3 # servant_adc_in3
    F = calculate_F(cal_channel, gain, system)

    print("Temperature Readings:")

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
    filename = foldername + "temp_" + device + "_data" + now + ".txt"

    open(filename, "w+").close()
    minutes, T = [], []

    run_time_min = float(run_time_min)

    fig, ax = plt.subplots()
    ax.set_xlabel('minutes')
    ax.set_ylabel('T (C)')

    if device == "OH":
        channel = 6
        DAC = 50
    else:
        channel = 0
        DAC = 20

    LSB = 3.55e-06
    I = DAC * LSB
    find_temp = temp_res_fit()

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
            V_m = F * read_adc(channel, gain, system)
            R_m = V_m/I
            temp = find_temp(np.log10(R_m))

            second = time() - start_time
            T.append(temp)
            minutes.append(second/60.0)
            if plot:
                live_plot(ax, minutes, T)

            file.write(str(second/60.0) + "\t" + str(V_m) + "\t" + str(R_m) + "\t" + str(temp) + "\n")
            print("time = %.2f min, \tch %X: 0x%03X = %f (R (Ohms) = %f (T (C))" % (second/60.0, channel, V_m, R_m, temp))
            t0 = time()
    file.close()

    figure_name = foldername + "temp_" + device + now + "_plot.pdf"
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


def calculate_F(channel, gain, system):

    R = 1e-03
    LSB = 3.55e-06
    DAC = 150

    I = DAC * LSB
    V = I * R

    reg_data = convert_adc_reg(channel)

    writeReg(getNode("LPGBT.RWF.VOLTAGE_DAC.CURDACENABLE"), 0x1, 0)  # Enables current DAC.
    writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACSELECT"), DAC, 0)  #Sets output current for the current DAC.
    writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACCHNENABLE"), reg_data, 0)
    sleep(0.01)

    if system == "dryrun":
        F = 1
    else:
        V_m = read_adc(channel, gain, system)
        F = V/V_m

    writeReg(getNode("LPGBT.RWF.VOLTAGE_DAC.CURDACENABLE"), 0x0, 0)  # Enables current DAC.
    writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACSELECT"), 0x0, 0)  #Sets output current for the current DAC.
    writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACCHNENABLE"), 0x0, 0)
    sleep(0.01)

    return F


def convert_adc_reg(adc):
    reg_data = 0
    bit = adc
    reg_data |= (0x01 << bit)
    return reg_data


def temp_res_fit(power=2):

    B_list = [3900, 3934, 3950, 3971]  # OH: NTCG103UH103JT1, VTRX+: NTCG063UH103HTBX
    T_list = [50, 75, 85, 100]
    R_list = []

    for i in range(len(T_list)):
        T_list[i] = T_list[i] + 272.15

    for B, T in zip(B_list, T_list):
        R = 10e3 * math.exp(-B * ((1/298.15) - (1/T)))
        R_list.append(R)

    T_list = [298.15] + T_list
    R_list = [10000] + R_list

    for i in range(len(T_list)):
        T_list[i] = T_list[i] - 272.15

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
    parser.add_argument("-a", "--gain", action="store", dest="gain", default = "2", help="gain = Gain for RSSI ADC: 2, 8, 16, 32")
    args = parser.parse_args()

    if args.system == "chc":
        print("Using Rpi CHeeseCake for temperature monitoring")
    elif args.system == "backend":
        # print ("Using Backend for temperature monitoring")
        print(Colors.YELLOW + "Only chc (Rpi Cheesecake) or dryrun supported at the moment" + Colors.ENDC)
        sys.exit()
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

    # Initialization 
    rw_initialize(args.gem, args.system, oh_ver, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun" and args.system != "backend":
        check_rom_readback(args.ohid, args.gbtid)
        check_lpgbt_mode(boss, args.ohid, args.gbtid)

    # Check if GBT is READY
    check_lpgbt_ready(args.ohid, args.gbtid)

    try:
        main(args.system, oh_ver, boss, args.temp, args.minutes, gain, args.plot)
    except KeyboardInterrupt:
        print(Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()