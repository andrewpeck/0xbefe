from gem.gem_utils import *
from time import sleep, time
import sys
import argparse
import csv
import matplotlib.pyplot as plt
import os, glob
import datetime
import math
import numpy as np
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel

REGISTER_DAC_MONITOR_MAP = {
    "V Tsens Int": 37,
    "V Tsens Ext": 38
}

def convert_to_temp(V):
    temp = (V-340.0)/3.83
    return temp

def main(system, oh_ver, oh_select, vfat_list, run_time_min, ref, vref_list, niter, calData):

    init_adc(oh_ver)
    print("Temperature Readings:")

    resultDir = "results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    me0Dir = "results/vfat_data"
    try:
        os.makedirs(me0Dir) # create directory for ME0 lpGBT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = "results/vfat_data/vfat_temp_monitor"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    foldername = dataDir + "/"
    filename_text = {}
    file_text = {}
    for vfat in vfat_list:
        filename_text[vfat] = foldername + "ME0_OH%d_vfat%02d_temp_"%(oh_select, vfat) + device + "_data_" + now + ".txt"
        file_text[vfat] = open(filename_text[vfat], "w")
        file_text[vfat].write("Time (min) \t Voltage (V) \t Temperature (C)\n")
    minutes, T = {}, {}
    run_time_min = float(run_time_min)

    gem_link_reset()
    sleep(0.1)

    link_good_node = {}
    sync_error_node = {}
    vfat_cfg_run_node = {}
    adc_monitor_select_node = {}
    adc0_cached_node = {}
    adc0_update_node = {}
    adc1_cached_node = {}
    adc1_update_node = {}

    # Check ready and get nodes
    for vfat in vfat_list:
        gbt, gbt_select, elink, gpio = me0_vfat_to_gbt_elink_gpio(vfat)
        check_gbt_link_ready(oh_select, gbt_select)

        print("Configuring VFAT %d" % (vfat))
        configureVfat(1, vfat, oh_select, 0)

        link_good_node[vfat] = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat))
        sync_error_node[vfat] = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat))
        link_good = read_backend_reg(link_good_node[vfat])
        sync_err = read_backend_reg(sync_error_node[vfat])
        if system!="dryrun" and (link_good == 0 or sync_err > 0):
            print (Colors.RED + "Link is bad for VFAT# %02d"%(vfat) + Colors.ENDC)
            terminate()

        vfat_cfg_run_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN" % (oh_select, vfat))
        adc_monitor_select_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_MONITOR_SELECT" % (oh_select, vfat))
        adc0_cached_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.ADC0_CACHED" % (oh_select, vfat))
        adc0_update_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.ADC0_UPDATE" % (oh_select, vfat))
        adc1_cached_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.ADC1_CACHED" % (oh_select, vfat))
        adc1_update_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.ADC1_UPDATE" % (oh_select, vfat))

        write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%d.CFG_VREF_ADC" % (oh_select, vfat)) , vref_list[vfat])
        # Setup DAC Monitor
        write_backend_reg(adc_monitor_select_node[vfat], REGISTER_DAC_MONITOR_MAP["V Tsens Int"])
        for ii in range(0, niter):
            if adc_ref == "internal": # use ADC0
                adc_update_read = read_backend_reg(adc0_update_node[vfat]) # read/write to this register triggers a cache update
                sleep(20e-6) # sleep for 20 us

        minutes[vfat] = []
        T[vfat] = []
    
    sleep(1)
    print ("")

    start_time = int(time())
    end_time = int(time()) + (60 * run_time_min)

    t0 = time()
    while int(time()) <= end_time:
        if (time()-t0)>60:
            for vfat in vfat_list:
                
                # Read the ADC
                adc_value = []
                # Taking average
                for i in range(0,niter):
                    if adc_ref == "internal": # use ADC0
                        adc_update_read = read_backend_reg(adc0_update_node[vfat]) # read/write to this register triggers a cache update
                        sleep(20e-6) # sleep for 20 us
                        adc_value.append(read_backend_reg(adc0_cached_node[vfat]))
                    elif adc_ref == "external": # use ADC1
                        adc_update_read = read_backend_reg(adc1_update_node[vfat]) # read/write to this register triggers a cache update
                        sleep(20e-6) # sleep for 20 us
                        adc_value.append(read_backend_reg(adc1_cached_node[vfat]))
                avg_adc_value = sum(adc_value) / len(adc_value)
                slopeTemp = calData[vfat]["slope"] # get slope for VFAT
                interTemp = calData[vfat]["intercept"] # get intercept for VFAT
                Vin = avg_adc_value * slopeTemp + interTemp # convert adc to mV
                temp = convert_to_temp(Vin)
            
                second = time() - start_time
                T[vfat].append(temp)
                minutes[vfat].append(second/60.0)
            
                file_text[vfat].write(str(second/60.0) + "\t" + str(Vin) + "\t" + str(temp) + "\n")
                print("VFAT %02d: time = %.2f min, %.2fV = %.2f deg C" % (vfat, second/60.0, Vin, temp))
            t0 = time()
            print ("")
    
    for vfat in vfat_list:
        # Reset DAC Monitor
        write_backend_reg(adc_monitor_select_node[vfat], 0)
        print("Unconfiguring VFAT %d" % (vfat))
        configureVfat(0, vfat, oh_select, 0)
        file_text[vfat].close()

    filename_text = {}
    file_text = {}
    for vfat in vfat_list:
        filename_text[vfat] = foldername + "ME0_OH%d_vfat%02d_temp_"%(oh_select, vfat) + device + "_data_" + now + ".txt"
        file_text[vfat] = open(filename_text[vfat], "w")
        file_text[vfat].write("Time (min) \t Voltage (V) \t Temperature (C)\n")

    figure_name = {}
    for vfat in vfat_list:
        figure_name[vfat] = foldername + "ME0_OH%d_vfat%02d_temp_"%(oh_select, vfat) + device + "_plot_" + now + ".pdf"
        fig1, ax1 = plt.subplots()
        ax1.set_xlabel("minutes")
        ax1.set_ylabel("T (C)")
        ax1.set_title("VFAT %02d"%vfat)
        ax1.plot(minutes, T, color="turquoise")
        fig1.savefig(figure_name[vfat], bbox_inches="tight")

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Temperature Monitoring for VFATs")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-m", "--minutes", action="store", dest="minutes", help="minutes = int. # of minutes you want to run")
    parser.add_argument("-n", "--niter", action="store", dest="niter", default="100", help="niter = Number of times to read ADC for averaging (default=100)")
    parser.add_argument("-e", "--ref", action="store", dest="ref", default = "internal", help="ref = ADC reference: internal or external (default=internal)")
    parser.add_argument("-vr", "--vref", action="store", dest="vref", help="vref = CFG_VREF_ADC (0-3) (default = taken from calib file or 3)")
    parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
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
    
    if args.vfats is None:
        print (Colors.YELLOW + "Enter VFAT numbers" + Colors.ENDC)
        sys.exit()
    vfat_list = []
    for v in args.vfats:
        v_int = int(v)
        if v_int not in range(0,24):
            print (Colors.YELLOW + "Invalid VFAT number, only allowed 0-23" + Colors.ENDC)
            sys.exit()
        vfat_list.append(v_int)

    if args.ref not in ["internal", "external"]:
        print (Colors.YELLOW + "ADC reference can only be internal or external" + Colors.ENDC)
        sys.exit()

    vref_list = {}
    if args.vref is not None:
        vref = int(args.vref)
        if vref>3:
            print (Colors.YELLOW + "Allowed VREF: 0-3" + Colors.ENDC)
            sys.exit()
        for vfat in vfat_list:
            vref_list[vfat] = vref
    else:
        calib_path = "results/vfat_data/vfat_calib_data/%s_OH%s_vfat_calib_info_vref.txt"%(args.gem, args.ohid)
        vref_calib = {}
        if os.path.isfile(calib_path):
            calib_file = open(calib_path)
            for line in calib_file.readlines():
                if "vfat" in line:
                    continue
                vfat = int(line.split(";")[0])
                vref_calib[vfat] = int(line.split(";")[2])
            calib_file.close()
        for vfat in vfat_list:
            if vfat in vref_calib:
                vref_list[vfat] = vref_calib[vfat]
            else:
                vref_list[vfat] = 3

    if args.use_channel_trimming is not None:
        if args.use_channel_trimming not in ["daq", "sbit"]:
            print (Colors.YELLOW + "Only allowed options for use_channel_trimming: daq or sbit" + Colors.ENDC)
            sys.exit()

    calFile = "results/vfat_data/vfat_calib_data/ME0_OH"+args.ohid+"_vfat_calib_info_adc0.txt"
    if not os.path.isfile(calFile):
        print(Colors.YELLOW + "Calib file for ADC0 must be present in the correct directory" + Colors.ENDC)
        sys.exit()
    calData_file = open(calFile)
    calData = {}
    for line in calData_file.readlines():
        if "vfat" in line: 
            continue
        vfat = line.split(";")[0]
        slope = line.split(";")[2]
        intercept = line.split(";")[3]
        if int(vfat) not in calData:
            calData[int(vfat)] = {}
        calData[int(vfat)]["slope"] = slope
        calData[int(vfat)]["intercept"] = intercept
    calData_file.close()

    # Initialization
    initialize(args.gem, args.system)
    initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")

    try:
        main(args.system, oh_ver, int(args.ohid), vfat_list, args.minutes, args.ref, vref_list, niter, calData)
    except KeyboardInterrupt:
        print(Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
