import sys, os, glob
import time
import argparse
import numpy as np
import json
import re
import math
from gem.me0_lpgbt.rw_reg_lpgbt import *

# slot to OH mapping
geb_oh_map = {}
geb_oh_map["1"] = {}
geb_oh_map["1"]["OH"] = 0
geb_oh_map["1"]["GBT"] = [0, 1]
geb_oh_map["1"]["VFAT"] = [0, 1, 8, 9, 16, 17]
geb_oh_map["2"] = {}
geb_oh_map["2"]["OH"] = 0
geb_oh_map["2"]["GBT"] = [2, 3]
geb_oh_map["2"]["VFAT"] = [2, 3, 10, 11, 18, 19]
geb_oh_map["3"] = {}
geb_oh_map["3"]["OH"] = 0
geb_oh_map["3"]["GBT"] = [4, 5]
geb_oh_map["3"]["VFAT"] = [4, 5, 12, 13, 20, 21]
geb_oh_map["4"] = {}
geb_oh_map["4"]["OH"] = 0
geb_oh_map["4"]["GBT"] = [6, 7]
geb_oh_map["4"]["VFAT"] = [6, 7, 14, 15, 22, 23]
geb_oh_map["5"] = {}
geb_oh_map["5"]["OH"] = 1
geb_oh_map["5"]["GBT"] = [0, 1]
geb_oh_map["5"]["VFAT"] = [0, 1, 8, 9, 16, 17]
geb_oh_map["6"] = {}
geb_oh_map["6"]["OH"] = 1
geb_oh_map["6"]["GBT"] = [2, 3]
geb_oh_map["6"]["VFAT"] = [2, 3, 10, 11, 18, 19]
geb_oh_map["7"] = {}
geb_oh_map["7"]["OH"] = 1
geb_oh_map["7"]["GBT"] = [4, 5]
geb_oh_map["7"]["VFAT"] = [4, 5, 12, 13, 20, 21]
geb_oh_map["8"] = {}
geb_oh_map["8"]["OH"] = 1
geb_oh_map["8"]["GBT"] = [6, 7]
geb_oh_map["8"]["VFAT"] = [6, 7, 14, 15, 22, 23]

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OptoHybrid Production Tests - Long Optical BERT")
    parser.add_argument("-i", "--input_file", action="store", dest="input_file", help="INPUT_FILE = input file containing OH and VTRx+ serial numbers for slots")
    parser.add_argument("-b", "--ber", action="store", dest="ber", help="BER = measurement till this BER. eg. 1e-12")
    parser.add_argument("-t", "--time", action="store", dest="time", help="TIME = measurement time in minutes")
    parser.add_argument("-c", "--cl", action="store", dest="cl", default="0.95", help="CL = confidence level desired for BER measurement, default = 0.95")
    args = parser.parse_args()

    if args.input_file is None:
        print(Colors.YELLOW + "Need Input File" + Colors.ENDC)
        sys.exit()

    geb_dict = {}
    slot_name_dict = {}
    vtrx_dict = {}
    pigtail_dict = {}
    input_file = open(args.input_file)
    for line in input_file.readlines():
        if "#" in line:
            if "BATCH" in line:
                batch = line.split()[2]
                if batch not in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance", "debug"]:
                    print(Colors.YELLOW + 'Valid test batch codes are "prototype", "pre_production", "pre_series", "production", "long_production", "acceptance" or debug' + Colors.ENDC)
                    sys.exit()
            continue
        slot = line.split()[0]
        slot_name = line.split()[1]
        oh_sn = line.split()[2]
        vtrx_sn = line.split()[3]
        pigtail = float(line.split()[4])
        if oh_sn != "-9999":
            if batch in ["prototype", "pre_production"]:
                if int(oh_sn) not in range(1,1001):
                    print(Colors.YELLOW + "Valid %s OH serial number between 1 and 1000"%batch.replace('_','-') + Colors.ENDC)
                    sys.exit()
            elif batch in ["pre_series", "production", "long_production", "acceptance"]:
                if int(oh_sn) not in range(1001, 2019):
                    print(Colors.YELLOW + "Valid %s OH serial number between 1001 and 2018"%batch.replace('_','-') + Colors.ENDC)
                    sys.exit()
            elif batch=="debug":
                if int(oh_sn) not in range(1, 2019):
                    print(Colors.YELLOW + "Valid %s OH serial number between 1001 and 2018"%batch.replace('_','-') + Colors.ENDC)
                    sys.exit()
            if int(slot) > 4:
                print(Colors.YELLOW + "Tests for more than 1 OH layer is not yet supported. Valid slots (1-4)" + Colors.ENDC)
                sys.exit()
            geb_dict[slot] = oh_sn
            slot_name_dict[slot] = slot_name
            vtrx_dict[slot] = vtrx_sn
            pigtail_dict[slot] = pigtail
    input_file.close()

    if len(geb_dict) == 0:
        print(Colors.YELLOW + "At least 1 slot needs to have valid OH serial number" + Colors.ENDC)
        sys.exit()
    print("")

    oh_sn_list = []
    for slot,oh_sn in geb_dict.items():
        oh_sn_list.append(oh_sn)
    
    oh_gbt_vfat_map = {}
    for slot in geb_dict:
        oh = geb_oh_map[slot]["OH"]
        if oh not in oh_gbt_vfat_map:
            oh_gbt_vfat_map[oh] = {}
            oh_gbt_vfat_map[oh]["GBT"] = []
            oh_gbt_vfat_map[oh]["VFAT"] = []
        oh_gbt_vfat_map[oh]["GBT"] += geb_oh_map[slot]["GBT"]
        oh_gbt_vfat_map[oh]["VFAT"] += geb_oh_map[slot]["VFAT"]
        oh_gbt_vfat_map[oh]["GBT"].sort()
        oh_gbt_vfat_map[oh]["VFAT"].sort()
    
    oh_ver_list = []
    for oh in oh_gbt_vfat_map:
        oh_ver_list += [get_oh_ver(oh,gbt) for gbt in oh_gbt_vfat_map[oh]["GBT"]]
    
    resultDir = "me0_lpgbt/oh_testing/results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass

    try:
        dataDir = resultDir + "/%s_tests"%batch
    except NameError:
        print(Colors.YELLOW + 'Must include test batch in input file as "# BATCH: <test_batch>"' + Colors.ENDC)
        sys.exit()

    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    dataDir += "/long_optical_bert"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    dataDir += "/OH_SNs_"+"_".join(oh_sn_list)
    try:
        os.makedirs(dataDir) # create directory for ohid under test
    except FileExistsError: # skip if directory already exists
        pass

    log_fn = dataDir + "/oh_tests_log.txt"
    logfile = open(log_fn, "w")
    results_fn = dataDir + "/oh_tests_results.json"
    
    uplink_datarate = 10.24 * 1e9
    downlink_datarate = 2.56 * 1e9

    if args.time != None and args.ber != None:
        print (Colors.YELLOW + "Enter only either time or BER limit but not both" + Colors.ENDC)
        sys.exit()
    if args.ber != None:
        ber_limit = float(args.ber)
        cl = float(args.cl)
        uplink_runtime = (-math.log(1-cl))/(uplink_datarate * ber_limit * 60)
        downlink_runtime = (-math.log(1-cl))/(downlink_datarate * ber_limit * 60)
        runtime = max(uplink_runtime, downlink_runtime)
    else:
        runtime = float(args.time)

    print ("\n#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    print (Colors.BLUE + "\nTests started for Batch: %s\n"%batch + Colors.ENDC)
    print (Colors.BLUE + "Optohybrid Serial Numbers: %s\n"%(' '.join(oh_sn_list)) + Colors.ENDC)
    print ("")

    logfile.write("\nTests started for Batch: %s\n\n"%batch)
    logfile.write("Optohybrid Serial Numbers: %s\n\n"%(' '.join(oh_sn_list)))

    print ("\n#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Run init_frontend
    print (Colors.BLUE + "Initializing\n" + Colors.ENDC)
    logfile.write("Initializing\n\n")
    time.sleep(1)

    logfile.close()
    os.system("python3 init_frontend.py")
    os.system("python3 status_frontend.py >> %s"%log_fn)
    os.system("python3 clean_log.py -i %s"%log_fn)

    print (Colors.GREEN + "\nInitialization Complete\n" + Colors.ENDC)
    logfile = open(log_fn, "a")
    logfile.write("\nInitialization Complete\n\n")
    time.sleep(1)
    
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Start the Downlink BER counters
    print (Colors.BLUE + "Starting Downlink BER counters\n" + Colors.ENDC)
    logfile.write("Starting Downlink BER counters\n\n")
    time.sleep(1)

    for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
        print (Colors.BLUE + "Starting Downlink BER counters for OH %s BOSS lpGBTs\n"%oh_select + Colors.ENDC)
        logfile.write("Starting Downlink BER counters for OH %s BOSS lpGBTs\n\n"%oh_select)
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p downlink -r start -z > out.txt"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT'][0::2]))))

    print (Colors.GREEN + "\nDownlink BERT Counters Started\n" + Colors.ENDC)
    logfile.write("\nDownlink BERT Counters Started\n\n")

    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Reading Uplink and Downlink BER counters
    print (Colors.BLUE + "Reading Uplink and Downlink BER counters for %.2f minutes\n"%runtime + Colors.ENDC)
    logfile.write("Reading Uplink and Downlink BER counters for %.2f minutes\n\n"%runtime)
    t0 = time.time()
    time_prev = t0

    # First Reading
    for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
        print ("First Reading: \n")
        print ("OH %d: \n"%oh_select)
        print ("Downlink: \n")
        logfile.write("First Reading: \n")
        logfile.write("OH %d: \n"%oh_select)
        logfile.write("Downlink: \n")
        logfile.close()
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p downlink -r read -z"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT'][0::2]))))
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p downlink -r read -z >> %s"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT'][0::2])), log_fn))
        print ("\nUplink: \n")
        logfile = open(log_fn, "a")
        logfile.write("\nUplink: \n")
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p uplink -r read -z"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT']))))
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p uplink -r read -z >> %s"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT'])), log_fn))
        print ("\n")
        logfile = open(log_fn, "a")
        logfile.write("\n")

    # Running and Reading
    while (time.time()-t0)/60.0 < runtime:
        if (time.time() - time_prev)/60.0 >= 1.0:
            print ("Time passed: %.2f minutes, %.2f % Done\n"%((time.time()-t0)/60.0, (((time.time()-t0)/60.0)/runtime)*100))
            for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
                print ("OH %d: \n"%oh_select)
                print ("Downlink: \n")
                os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p downlink -r read -z"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT'][0::2]))))
                print ("\nUplink: \n")
                os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p uplink -r read -z"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT']))))
                print ("\n")
            time_prev = time.time()

    # Last Reading
    for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
        print ("Last Reading: \n")
        print ("OH %d: \n"%oh_select)
        print ("Downlink: \n")
        logfile.write("Last Reading: \n")
        logfile.write("OH %d: \n"%oh_select)
        logfile.write("Downlink: \n")
        logfile.close()
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p downlink -r read -z"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT'][0::2]))))
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p downlink -r read -z >> %s"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT'][0::2])), log_fn))
        print ("\nUplink: \n")
        logfile = open(log_fn, "a")
        logfile.write("\nUplink: \n")
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p uplink -r read -z"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT']))))
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p uplink -r read -z >> %s"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT'])), log_fn))
        print ("\n")
        logfile = open(log_fn, "a")
        logfile.write("\n")

    print (Colors.GREEN + "\nUplink and Downlink BERT Finished\n" + Colors.ENDC)
    logfile.write("\nUplink and Downlink BERT Finished\n\n")

    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Stopping the Downlink BER counters
    print (Colors.BLUE + "Stopping Downlink BER counters\n" + Colors.ENDC)
    logfile.write("Stopping Downlink BER counters\n\n")
    time.sleep(1)

    for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
        print (Colors.BLUE + "Stopping Downlink BER counters for OH %s BOSS lpGBTs\n"%oh_select + Colors.ENDC)
        logfile.write("Stopping Downlink BER counters for OH %s BOSS lpGBTs\n\n"%oh_select)
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p downlink -r stop -z > out.txt"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT'][0::2]))))

    print (Colors.GREEN + "\nDownlink BERT Counters Stopped\n" + Colors.ENDC)
    logfile.write("\nDownlink BERT Counters Stopped\n\n")

    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    print ("Total runtime: %.2f minutes"%runtime)
    logfile.write("Total runtime: %.2f minutes"%runtime)

    logfile.close()
    os.system("rm -rf out.txt")
