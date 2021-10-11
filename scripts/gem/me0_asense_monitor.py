from gem.me0_lpgbt.rw_reg_lpgbt import *
import gem.gem_utils as gem_utils
from time import sleep, time
import sys
import argparse
import csv
import matplotlib.pyplot as plt
import os
import datetime

def main(system, boss, gbt, run_time_min, gain):

    init_adc()
    print("ADC Readings:")

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
    dataDir = "results/me0_lpgbt_data/lpgbt_asense_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    foldername = dataDir+"/"
    filename = foldername + "asense_data_" + now + ".txt"

    print(filename)
    open(filename, "w+").close()
    minutes, seconds, asense0, asense1, asense2, asense3 = [], [], [], [], [], []

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

    while int(time()) <= end_time:
        with open(filename, "a") as file:
            asense0_value = read_adc(4, gain, system)
            asense1_value = read_adc(2, gain, system)
            asense2_value = read_adc(1, gain, system)
            asense3_value = read_adc(3, gain, system)
            asense0_converted = asense_current_conversion(asense0_value)
            asense1_converted = asense_temp_voltage_conversion(asense1_value)
            asense2_converted = asense_current_conversion(asense2_value)
            asense3_converted = asense_temp_voltage_conversion(asense3_value)
            second = time() - start_time
            seconds.append(second)
            asense0.append(asense0_converted)
            asense1.append(asense1_converted)
            asense2.append(asense2_converted)
            asense3.append(asense3_converted)
            minutes.append(second/60)
            live_plot_current(ax1, minutes, asense0, asense2, run_time_min, gbt)
            live_plot_temp(ax2, minutes, asense1, asense3, run_time_min, gbt)

            file.write(str(second) + "\t" + str(asense0_converted) + "\t" + str(asense1_converted) + "\t" + str(asense2_converted) + "\t" + str(asense3_converted) + "\n" )
            if gbt in [0,1]:
                print("Time: " + "{:.2f}".format(second) + " s \t Asense0 (PG2.5V current): " + "{:.3f}".format(asense0_converted) + " A \t Asense1 (Rt2 voltage): " + "{:.3f}".format(asense1_converted) + " V \t Asense2 (PG1.2V current): " + "{:.3f}".format(asense2_converted) + " A \t Asense3 (Rt1 voltage): " + "{:.3f}".format(asense3_converted) + " V \n" )
            else:
                print("Time: " + "{:.2f}".format(second) + " s \t Asense0 (PG1.2VD current): " + "{:.3f}".format(asense0_converted) + " A \t Asense1 (Rt3 voltage): " + "{:.3f}".format(asense1_converted) + " V \t Asense2 (PG1.2VA current): " + "{:.3f}".format(asense2_converted) + " A \t Asense3 (Rt4 voltage): " + "{:.3f}".format(asense3_converted) + " V \n" )

            sleep(1)

    figure_name1 = foldername + now + "_pg_current_plot.pdf"
    fig1.savefig(figure_name1, bbox_inches="tight")
    figure_name2 = foldername + now + "_rt_voltage_plot.pdf"
    fig2.savefig(figure_name2, bbox_inches="tight")

    powerdown_adc()

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


def init_adc():
    writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x1, 0)  # enable ADC
    writeReg(getNode("LPGBT.RW.ADC.TEMPSENSRESET"), 0x1, 0)  # resets temp sensor
    writeReg(getNode("LPGBT.RW.ADC.VDDMONENA"), 0x1, 0)  # enable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDTXMONENA"), 0x1, 0)  # enable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDRXMONENA"), 0x1, 0)  # enable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDPSTMONENA"), 0x1, 0)  # enable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDANMONENA"), 0x1, 0)  # enable dividers
    writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFENABLE"), 0x1, 0)  # vref enable
    writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFTUNE"), 0x63, 0) # vref tune
    sleep(0.01)


def powerdown_adc():
    writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x0, 0)  # disable ADC
    writeReg(getNode("LPGBT.RW.ADC.TEMPSENSRESET"), 0x0, 0)  # disable temp sensor
    writeReg(getNode("LPGBT.RW.ADC.VDDMONENA"), 0x0, 0)  # disable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDTXMONENA"), 0x0, 0)  # disable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDRXMONENA"), 0x0, 0)  # disable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDPSTMONENA"), 0x0, 0)  # disable dividers
    writeReg(getNode("LPGBT.RW.ADC.VDDANMONENA"), 0x0, 0)  # disable dividers
    writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFENABLE"), 0x0, 0)  # vref disable
    writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFTUNE"), 0x0, 0) # vref tune


def read_adc(channel, gain, system):
    # ADCInPSelect[3:0]	|  Input
    # ------------------|----------------------------------------
    # 4"d0	        |  ADC0 (external pin)
    # 4"d1	        |  ADC1 (external pin)
    # 4"d2	        |  ADC2 (external pin)
    # 4"d3	        |  ADC3 (external pin)
    # 4"d4	        |  ADC4 (external pin)
    # 4"d5	        |  ADC5 (external pin)
    # 4"d6	        |  ADC6 (external pin)
    # 4"d7	        |  ADC7 (external pin)
    # 4"d8	        |  EOM DAC (internal signal)
    # 4"d9	        |  VDDIO * 0.42 (internal signal)
    # 4"d10	        |  VDDTX * 0.42 (internal signal)
    # 4"d11	        |  VDDRX * 0.42 (internal signal)
    # 4"d12	        |  VDD * 0.42 (internal signal)
    # 4"d13	        |  VDDA * 0.42 (internal signal)
    # 4"d14	        |  Temperature sensor (internal signal)
    # 4"d15	        |  VREF/2 (internal signal)

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

def asense_current_conversion(asense_adc):
    # Resistor values
    R = 0.01 # 0.01 Ohm

    asense_voltage = 1.0 * (asense_adc/1024.0) # 10-bit ADC, range 0-1 V
    asense_voltage /= 20 # Gain in current sense circuit
    asense_current = asense_voltage/R # asense current
    return asense_current

def asense_temp_voltage_conversion(asense_adc):
    # Resistor values
    R = 0.01 # 0.01 Ohm

    asense_voltage = 1.0 * (asense_adc/1024.0) # 10-bit ADC, range 0-1 V
    return asense_voltage


if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Asense monitoring for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-l", "--lpgbt", action="store", dest="lpgbt", help="lpgbt = only boss")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number (only needed for backend)")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = 0-7")
    parser.add_argument("-m", "--minutes", action="store", dest="minutes", help="minutes = # of minutes you want to run")
    parser.add_argument("-a", "--gain", action="store", dest="gain", default = "2", help="gain = Gain for Asense ADCs: 2, 8, 16, 32")
    args = parser.parse_args()

    if args.system == "chc":
        print("Using Rpi CHeeseCake for asense monitoring")
    elif args.system == "backend":
        # print ("Using Backend for asense monitoring")
        print(Colors.YELLOW + "Only chc (Rpi Cheesecake) or dryrun supported at the moment" + Colors.ENDC)
        sys.exit()
    elif args.system == "dryrun":
        print("Dry Run - not actually running asense monitoring")
    else:
        print(Colors.YELLOW + "Only valid options: chc, backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem != "ME0":
        print(Colors.YELLOW + "Valid gem station: ME0" + Colors.ENDC)
        sys.exit()

    boss = None
    if args.lpgbt is None:
        print(Colors.YELLOW + "Please select boss or sub" + Colors.ENDC)
        sys.exit()
    elif (args.lpgbt == "boss"):
        print("Using boss LPGBT")
        boss = 1
    elif (args.lpgbt == "sub"):
        #print("Using sub LPGBT")
        print (Colors.YELLOW + "Only boss allowed" + Colors.ENDC)
        boss = 0
    else:
        print(Colors.YELLOW + "Please select boss" + Colors.ENDC)
        sys.exit()
    if boss is None:
        sys.exit()

    if args.gbtid is None:
        print(Colors.YELLOW + "Need GBTID" + Colors.ENDC)
        sys.exit()
    if int(args.gbtid) > 7:
        print(Colors.YELLOW + "Only GBTID 0-7 allowed" + Colors.ENDC)
        sys.exit()
    gbt = int(args.gbtid)%4

    if args.system == "backend":
        if args.ohid is None:
            print(Colors.YELLOW + "Need OHID" + Colors.ENDC)
            sys.exit()
        #if int(args.ohid) > 1:
        #    print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
        #    sys.exit()
    else:
        if args.ohid is not None:
            print(Colors.YELLOW + "OHID only needed for backend" + Colors.ENDC)
            sys.exit()

    if args.gain not in ["2", "8", "16", "32"]:
        print(Colors.YELLOW + "Allowed values of gain = 2, 8, 16, 32" + Colors.ENDC)
        sys.exit()
    gain = int(args.gain)

    # Initialization 
    rw_initialize(args.gem, args.system, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun" and args.system != "backend":
        check_rom_readback()

    # Check if GBT is READY
    if args.system=="chc":
        check_lpgbt_ready()
    else:
        gem_utils.check_gbt_link_ready(args.ohid, args.gbtid)
        
    try:
        main(args.system, boss, gbt, args.minutes, gain)
    except KeyboardInterrupt:
        print(Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
