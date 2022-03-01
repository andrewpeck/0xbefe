from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep, time
import sys
import argparse
import csv
import matplotlib.pyplot as plt
import os, glob
import datetime
import numpy as np

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

def main(system, oh_ver, oh_select, gbt_select, boss, run_time_min, gain, voltage, plot):

    init_adc(oh_ver)
    print("ADC Readings:")

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
    dataDir = "results/me0_lpgbt_data/lpgbt_vtrx+_rssi_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/ME0_OH%d_GBT%d_rssi_data_"%(oh_select, gbt_select) + now + ".txt"

    open(filename, "w+").close()
    minutes, rssi = [], []

    run_time_min = float(run_time_min)

    fig, ax = plt.subplots()
    ax.set_xlabel("minutes")
    ax.set_ylabel("RSSI (uA)")
    #ax.set_xticks(range(0,run_time_min+1))
    #ax.set_xlim([0,run_time_min])

    start_time = int(time())
    end_time = int(time()) + (60 * run_time_min)

    file_out = open(filename, "w")
    file_out.write("Time (min) \t RSSI (uA)\n")
    t0 = time()
    while int(time()) <= end_time:
        if (time()-t0)>60:
            if oh_ver == 1:
                value = read_adc(7, gain, system)
            if oh_ver == 2:
                value = read_adc(5, gain, system)
            Vout = 1.0 * (value/1024.0) # 10-bit ADC, range 0-1 V
            if len(adc_calib_results)!=0:
                Vin = get_vin(Vout, adc_calib_results_array)
            else:
                Vin = Vout
            rssi_current = rssi_current_conversion(Vin, gain, voltage, oh_ver) * 1e6 # in uA
            second = time() - start_time
            rssi.append(rssi_current)
            minutes.append(second/60.0)
            if plot:
                live_plot(ax, minutes, rssi)

            file_out.write(str(second/60.0) + "\t" + str(rssi_current) + "\n")
            print("time = %.2f min, \tch %X: 0x%03X = %.2fV =  %f uA RSSI" % (second/60.0, 7, value, Vin, rssi_current))
            t0 = time()
            
    file_out.close()
    figure_name = dataDir + "/ME0_OH%d_GBT%d_rssi_data_"%(oh_select, gbt_select) + now + "_plot.pdf"
    fig1, ax1 = plt.subplots()
    ax1.set_xlabel("minutes")
    ax1.set_ylabel("RSSI (uA)")
    ax1.plot(minutes, rssi, color="turquoise")
    fig1.savefig(figure_name, bbox_inches="tight")

    powerdown_adc(oh_ver)
    
def convert_adc_reg(adc):
    reg_data = 0
    bit = adc
    reg_data |= (0x01 << bit)
    return reg_data

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
        writeReg(getNode("LPGBT.RW.ADC.VDDPSTMONENA"), 0x0, 0)  # disable dividers
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

def rssi_current_conversion(Vin, gain, input_voltage, oh_ver):

    rssi_current = -9999
    #rssi_voltage = Vin/gain # Gain
    rssi_voltage = Vin

    if oh_ver == 1:
        # Resistor values
        R1 = 4.7 * 1000 # 4.7 kOhm
        v_r = rssi_voltage
        rssi_current = (input_voltage - v_r)/R1 # rssi current
    elif oh_ver == 2:
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
    parser.add_argument("-m", "--minutes", action="store", dest="minutes", help="minutes = int. # of minutes you want to run")
    parser.add_argument("-p", "--plot", action="store_true", dest="plot", help="plot = enable live plot")
    parser.add_argument("-a", "--gain", action="store", dest="gain", default = "2", help="gain = Gain for ADC: 2, 8, 16, 32")
    args = parser.parse_args()

    if args.system == "chc":
        print("Using Rpi CHeeseCake for rssi monitoring")
    elif args.system == "backend":
        print ("Using Backend for rssi monitoring")
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
    if oh_ver == 1 and not boss:
        print(Colors.YELLOW + "Only boss lpGBT allowed for ME0 OH-v1" + Colors.ENDC)
        sys.exit()
    if oh_ver == 2 and boss:
        print(Colors.YELLOW + "Only sub lpGBT allowed for ME0 OH-v2" + Colors.ENDC)
        sys.exit()

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
        main(args.system, oh_ver, int(args.ohid), int(args.gbtid), boss, args.minutes, gain, float(args.voltage), args.plot)
    except KeyboardInterrupt:
        print(Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
