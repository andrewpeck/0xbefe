from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep, time
import sys
import argparse
import csv
import matplotlib.pyplot as plt
import os
import datetime

def main(system, oh_ver, boss, run_time_min, gain, voltage, ver):

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
    dataDir = "results/me0_lpgbt_data/lpgbt_vtrx+_rssi_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/rssi_data_" + now + ".txt"

    print(filename)
    open(filename, "w+").close()
    minutes, seconds, rssi = [], [], []

    run_time_min = float(run_time_min)

    fig, ax = plt.subplots()
    ax.set_xlabel("minutes")
    ax.set_ylabel("RSSI (uA)")
    #ax.set_xticks(range(0,run_time_min+1))
    #ax.set_xlim([0,run_time_min])

    start_time = int(time())
    end_time = int(time()) + (60 * run_time_min)

    while int(time()) <= end_time:
        with open(filename, "a") as file:
            value = read_adc(7, gain, system)
            rssi_current = rssi_current_conversion(value, gain, voltage, ver) * 1e6 # in uA
            second = time() - start_time
            seconds.append(second)
            rssi.append(rssi_current)
            minutes.append(second/60)
            live_plot(ax, minutes, rssi, run_time_min)

            file.write(str(second) + "\t" + str(rssi_current) + "\n" )
            print("\tch %X: 0x%03X = %f (RSSI (uA))" % (7, value, rssi_current))

            sleep(1)

    figure_name = dataDir + "/rssi_data_" + now + "_plot.pdf"
    fig.savefig(figure_name, bbox_inches="tight")

    powerdown_adc()

def live_plot(ax, x, y, run_time_min):
    ax.plot(x, y, "turquoise")
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

def rssi_current_conversion(rssi_adc, gain, input_voltage, ver):

    rssi_current = -9999
    rssi_adc_converted = 1.0 * (rssi_adc/1024.0) # 10-bit ADC, range 0-1 V
    #rssi_voltage = rssi_adc_converted/gain # Gain
    rssi_voltage = rssi_adc_converted

    if ver == 1:
        # Resistor values
        R1 = 4.7 * 1000 # 4.7 kOhm
        v_r = rssi_voltage
        rssi_current = (input_voltage - v_r)/R1 # rssi current
    elif ver == 2:
        # Resistor values
        R1 = 4.7 * 1000 # 4.7 kOhm
        R2 = 1000.0 * 1000 # 1 MOhm
        R3 = 470.0 * 1000 # 470 kOhm
        v_r = rssi_voltage * ((R2+R3)/R3) # voltage divider
        rssi_current = (input_voltage - v_r)/R1 # rssi current

    return rssi_current

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="RSSI Monitor for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--voltage", action="store", dest="voltage", default = "2.5", help="voltage = exact value of the 2.5V input voltage to OH")
    parser.add_argument("-z", "--ver", action="store", dest="ver", help="ver = OH version 1 or 2")
    parser.add_argument("-m", "--minutes", action="store", dest="minutes", help="minutes = int. # of minutes you want to run")
    parser.add_argument("-a", "--gain", action="store", dest="gain", default = "2", help="gain = Gain for RSSI ADC: 2, 8, 16, 32")
    args = parser.parse_args()

    if args.system == "chc":
        print("Using Rpi CHeeseCake for rssi monitoring")
    elif args.system == "backend":
        # print ("Using Backend for rssi monitoring")
        print(Colors.YELLOW + "Only chc (Rpi Cheesecake) or dryrun supported at the moment" + Colors.ENDC)
        sys.exit()
    elif args.system == "dryrun":
        print("Dry Run - not actually running rssi monitoring")
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
    boss = None
    if int(args.gbtid)%2 == 0:
        boss = 1
    else:
        boss = 0
    if not boss:
        print(Colors.YELLOW + "Only boos lpGBT allowed" + Colors.ENDC)
        sys.exit()

    if args.gain not in ["2", "8", "16", "32"]:
        print(Colors.YELLOW + "Allowed values of gain = 2, 8, 16, 32" + Colors.ENDC)
        sys.exit()
    gain = int(args.gain)

    if args.ver not in ["1", "2"]:
        print(Colors.YELLOW + "Allowed versions = 1 or 2" + Colors.ENDC)
        sys.exit()

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
        main(args.system, oh_ver, boss, args.minutes, gain, float(args.voltage), int(args.ver))
    except KeyboardInterrupt:
        print(Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
