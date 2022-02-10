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

def main(system, oh_ver, oh_select, gbt_select, boss, run_time_min, gain, plot):

    gbt = gbt_select%4
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
    dataDir = "results/me0_lpgbt_data/lpgbt_asense_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    foldername = dataDir + "/"
    filename = foldername + "ME0_OH%d_GBT%d_asense_data_"%(oh_select, gbt_select) + now + ".txt"

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
    while int(time()) <= end_time:
        if (time()-t0)>60:
            if oh_ver == 1:
                asense0_value = read_adc(4, gain, system)
                asense1_value = read_adc(2, gain, system)
                asense2_value = read_adc(1, gain, system)
                asense3_value = read_adc(3, gain, system)
            if oh_ver == 2:
                asense0_value = read_adc(6, gain, system)
                asense1_value = read_adc(1, gain, system)
                asense2_value = read_adc(0, gain, system)
                asense3_value = read_adc(3, gain, system)

            asense0_Vout = 1.0 * (asense0_value/1024.0) # 10-bit ADC, range 0-1 V
            asense1_Vout = 1.0 * (asense1_value/1024.0) # 10-bit ADC, range 0-1 V
            asense2_Vout = 1.0 * (asense2_value/1024.0) # 10-bit ADC, range 0-1 V
            asense3_Vout = 1.0 * (asense3_value/1024.0) # 10-bit ADC, range 0-1 V
            if len(adc_calib_results)!=0:
                asense0_Vin = get_vin(asense0_Vout, adc_calib_results_array)
                asense1_Vin = get_vin(asense1_Vout, adc_calib_results_array)
                asense2_Vin = get_vin(asense2_Vout, adc_calib_results_array)
                asense3_Vin = get_vin(asense3_Vout, adc_calib_results_array)
            else:
                asense0_Vin = asense0_Vout
                asense1_Vin = asense1_Vout
                asense2_Vin = asense2_Vout
                asense3_Vin = asense3_Vout

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

    figure_name1 = foldername + "ME0_OH%d_GBT%d_pg_current_"%(oh_select, gbt_select) + now + "_plot.pdf"
    figure_name2 = foldername + "ME0_OH%d_GBT%d_rt_voltage_"%(oh_select, gbt_select) + now + "_plot.pdf"
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

def convert_adc_reg(adc):
    reg_data = 0
    bit = adc
    reg_data |= (0x01 << bit)
    return reg_data

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
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-m", "--minutes", action="store", dest="minutes", help="minutes = # of minutes you want to run")
    parser.add_argument("-p", "--plot", action="store_true", dest="plot", help="plot = enable live plot")
    parser.add_argument("-a", "--gain", action="store", dest="gain", default = "2", help="gain = Gain for ADC: 2, 8, 16, 32")
    args = parser.parse_args()

    if args.system == "chc":
        print("Using Rpi CHeeseCake for asense monitoring")
    elif args.system == "backend":
        print ("Using Backend for asense monitoring")
    elif args.system == "dryrun":
        print("Dry Run - not actually running asense monitoring")
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
        print (Colors.YELLOW + "Only boss lpGBT allowed" + Colors.ENDC)
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
        main(args.system, oh_ver, int(args.ohid), int(args.gbtid), boss, args.minutes, gain, args.plot)
    except KeyboardInterrupt:
        print(Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
