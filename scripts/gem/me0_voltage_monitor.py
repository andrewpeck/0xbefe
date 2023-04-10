from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep, time
import sys
import argparse
import csv
import matplotlib.pyplot as plt
import os, glob
import datetime
import numpy as np

def adc_conversion_lpgbt(adc):
    #voltage = adc/1024.0
    voltage = (adc - 38.4)/(1.85 * 512)
    return voltage

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

def main(system, oh_ver, oh_select, gbt_select, boss, run_time_min, niter, gain, plot):

    init_adc(oh_ver)
    print("ADC Readings:")

    '''
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
    '''

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
    dataDir = "results/me0_lpgbt_data/lpgbt_voltage_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    foldername = dataDir + "/"
    filename = foldername + "ME0_OH%d_GBT%d_voltage_data_"%(oh_select, gbt_select) + now + ".txt"

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
                v2v5_Vout = read_adc(6, gain, system)
            elif oh_ver == 2:
                v2v5_Vout = read_adc(1, gain, system)
            vssa_Vout = read_adc(9, gain, system)
            vddtx_Vout = read_adc(10, gain, system)
            vddrx_Vout = read_adc(11, gain, system)
            vdd_Vout = read_adc(12, gain, system)
            vdda_Vout = read_adc(13, gain, system)
            vref_Vout = read_adc(15, gain, system)

            #if len(adc_calib_results)!=0:
            #    v2v5_Vin = get_vin(v2v5_Vout, adc_calib_results_array)
            #    vssa_Vin = get_vin(vssa_Vout, adc_calib_results_array)
            #    vddtx_Vin = get_vin(vddtx_Vout, adc_calib_results_array)
            #    vddrx_Vin = get_vin(vddrx_Vout, adc_calib_results_array)
            #    vdd_Vin = get_vin(vdd_Vout, adc_calib_results_array)
            #    vdda_Vin = get_vin(vdda_Vout, adc_calib_results_array)
            #    vref_Vin = get_vin(vref_Vout, adc_calib_results_array)
            #else:
            v2v5_Vin = v2v5_Vout
            vssa_Vin = vssa_Vout
            vddtx_Vin = vddtx_Vout
            vddrx_Vin = vddrx_Vout
            vdd_Vin = vdd_Vout
            vdda_Vin = vdda_Vout
            vref_Vin = vref_Vout

            if oh_ver == 1:
                if gbt_select%2 == 0:
                    v2v5_converted = v2v5_Vin*3.0
                else:
                    v2v5_converted = -9999
                vssa_converted = vssa_Vin/0.42
            elif oh_ver == 2:
                if gbt_select%2 == 0:
                    v2v5_converted = -9999
                else:
                    v2v5_converted = v2v5_Vin*3.0
                vssa_converted = vssa_Vin
            vddtx_converted = vddtx_Vin/0.42
            vddrx_converted = vddrx_Vin/0.42
            vdd_converted = vdd_Vin/0.42
            vdda_converted = vdda_Vin/0.42
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

    figure_name1 = foldername + "ME0_OH%d_GBT%d_voltage_"%(oh_select, gbt_select) + now + "_plot.pdf"
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

def convert_adc_reg(adc):
    reg_data = 0
    bit = adc
    reg_data |= (0x01 << bit)
    return reg_data

def init_adc(oh_ver):
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x1)  # enable ADC
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.TEMPSENSRESET"), 0x1)  # resets temp sensor
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDMONENA"), 0x1)  # enable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDTXMONENA"), 0x1)  # enable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDRXMONENA"), 0x1)  # enable dividers
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDPSTMONENA"), 0x1)  # enable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDANMONENA"), 0x1)  # enable dividers
    lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFENABLE"), 0x1)  # vref enable
    lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFTUNE"), 0x63) # vref tune
    sleep(0.01)


def powerdown_adc(oh_ver):
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x0)  # disable ADC
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.TEMPSENSRESET"), 0x0)  # disable temp sensor
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDMONENA"), 0x0)  # disable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDTXMONENA"), 0x0)  # disable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDRXMONENA"), 0x0)  # disable dividers
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDPSTMONENA"), 0x0)  # disable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDANMONENA"), 0x0)  # disable dividers
    lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFENABLE"), 0x0)  # vref disable
    lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFTUNE"), 0x0) # vref tune


def read_adc(channel, gain, system):
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINPSELECT"), channel)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINNSELECT"), 0xf)

    gain_settings = {
        2: 0x00,
        8: 0x01,
        16: 0x10,
        32: 0x11
    }
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCGAINSELECT"), gain_settings[gain])
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCCONVERT"), 0x1)

    vals = []
    for i in range(0,100):
        done = 0
        while (done==0):
            if system!="dryrun":
                done = lpgbt_readReg(getNode("LPGBT.RO.ADC.ADCDONE"))
            else:
                done=1
        val = lpgbt_readReg(getNode("LPGBT.RO.ADC.ADCVALUEL"))
        val |= (lpgbt_readReg(getNode("LPGBT.RO.ADC.ADCVALUEH")) << 8)
        val = adc_conversion_lpgbt(val)
        vals.append(val)
    mean_val = sum(vals)/len(vals)

    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCCONVERT"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCGAINSELECT"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINPSELECT"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINNSELECT"), 0x0)

    return mean_val

def asense_current_conversion(Vin):
    # Resistor values
    R = 0.01 # 0.01 Ohm

    asense_voltage = Vin
    asense_voltage /= 20 # Gain in current sense circuit
    asense_current = asense_voltage/R # asense current
    return asense_current


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
