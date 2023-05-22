import sys, os, glob
import time
import argparse
import numpy as np
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
    parser = argparse.ArgumentParser(description="OptoHybrid Production Tests")
    parser.add_argument("-i", "--input_file", action="store", dest="input_file", help="INPUT_FILE = input file containing OH serial numbers for slots")
    parser.add_argument("-b", "--batch", action="store", dest="batch", help="batch = which batch of oh tests to perform: pre-series, production or production-long. (pre,prod,prod_long)")
    args = parser.parse_args()

    if args.input_file is None:
        print(Colors.YELLOW + "Need Input File" + Colors.ENDC)
        sys.exit()

    geb_dict = {}
    input_file = open(args.input_file)
    for line in input_file.readlines():
        if "#" in line:
            if "BATCH" in line:
                batch = line.split()[1]
            continue
        slot = line.split()[0]
        oh_sn = line.split()[1]
        if oh_sn != "-9999":
            if int(oh_sn) not in range(1, 1019):
                print(Colors.YELLOW + "Valid OH serial number between 1 and 1018" + Colors.ENDC)
                sys.exit() 
            elif int(slot) > 4:
                print(Colors.YELLOW + "Tests for more than 1 OH layer is not yet supported. Valid slots (1-4)" + Colors.ENDC)
                sys.exit()
            geb_dict[slot] = oh_sn

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
    if args.batch == "pre":
        dataDir = resultDir+"/pre_series_tests"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    OHDir = dataDir+"/OH_SNs_"+"_".join(oh_sn_list)
    try:
        os.makedirs(OHDir) # create directory for ohid under test
    except FileExistsError: # skip if directory already exists
        pass
    log_fn = OHDir + "/oh_tests_log.txt"
    logfile = open(log_fn, "w")
    resultsfile = open(OHDir + "/oh_tests_results.json","w")

    results = {}
    # log results for each asiago by serial #
    # Not sure if booleans should be True/False or 1/0
    for slot,oh_sn in geb_dict:
        results[oh_sn]={}
        # Which test batch
        if args.batch == "pre":
            results[oh_sn]["pre_series"]=True
            results[oh_sn]["production"]=False
            results[oh_sn]["production_long"]=False
        elif args.batch == "prod":
            results[oh_sn]["pre_series"]=False
            results[oh_sn]["production"]=True
            results[oh_sn]["production_long"]=False
        elif args.batch == "prod_long":
            results[oh_sn]["pre_series"]=False
            results[oh_sn]["production"]=False
            results[oh_sn]["production_long"]=True
        else:
            results[oh_sn]["pre_series"]=False
            results[oh_sn]["production"]=False
            results[oh_sn]["production_long"]=False
    

    print ("\n#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 1 - run init_frontend
    print (Colors.BLUE + "Step 1: Initializing\n" + Colors.ENDC)
    logfile.write("Step 1: Initializing\n\n")
    logfile.close()

    os.system("python3 init_frontend.py")
    os.system("python3 init_frontend.py >> %s"%log_fn)

    gbt_list = []
    for oh in oh_gbt_vfat_map:
        gbt_list+=oh_gbt_vfat_map[oh]["GBT"]
    gbt_list = list(set(gbt_list))

    logfile = open(log_fn, "r")
    for line in logfile.readlines():
        if ("0: READY" in line) or ("0: NOT READY" in line):
            oh_select = int(line.split()[0])
        for gbt in gbt_list:
            if "%d: READY" in line:
                for slot in geb_oh_map:
                    if (geb_oh_map[slot]["OH"]==oh_select) and (gbt in geb_oh_map[slot]["GBT"]): 
                        results[geb_dict[slot]][""]
        

    logfile = open(log_fn, "a")

    print (Colors.GREEN + "\nStep 1: Initialization Complete\n" + Colors.ENDC)
    logfile.write("\nStep 1: Initialization Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 2 - check lpGBT status
    print (Colors.BLUE + "Step 2: Checking lpGBT Status\n" + Colors.ENDC)
    logfile.write("Step 2: Checking lpGBT Status\n\n")

    for gbt in range(8):
        os.system("python3 me0_lpgbt_status.py -s backend -q ME0 -o %d -g %d > out.txt"%(oh_select,gbt))
        # even gbt indexes are boss, odd are sub
        slot = get_slot(oh_select,gbt)
        if gbt%2==0:
            # boss lpgbts
            list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_status_data/status_boss*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("cp %s %s/status_boss_slot%d.txt"%(latest_file, OHDir, slot))
        elif (gbt+1)%2==0:
            # sub lpgbts
            list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_status_data/status_sub*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("cp %s %s/status_sub_slot%d.txt"%(latest_file, OHDir, slot))

    config_files = []
    for oh_ver in oh_ver_list:
        config_files.append(open("../resources/me0_boss_config_ohv%d.txt"%oh_ver))
        config_files.append(open("../resources/me0_sub_config_ohv%d.txt"%oh_ver))
    status_files = []
    for gbt in range(8):
        slot = get_slot(oh_select,gbt)            
        if gbt%2==0:
            # boss lpgbts
            status_files.append(open(OHDir+"/status_boss_slot%d.txt"%slot))
        else:
            # sub lpgbts
            status_files.append(open(OHDir+"/status_sub_slot%d.txt"%slot))
    status_registers = {}
    # Read all status registers from files
    for i,(status_file,config_file) in enumerate(zip(status_files,config_files)):
        slot = np.floor_divide(i,2) + 1
        status_registers["SLOT%d"%slot]={}
        if i%2 == 0: # boss lpgbts
            # Get status registers
            status_registers["SLOT%d"%slot]["BOSS"]={}
            for line in status_file.readlines():
                reg,value = int(line.split()[0],16),int(line.split()[1],16)
                status_registers["SLOT%d"%slot]["BOSS"][reg] = value
            
            # Check against config files
            print ("Checking Slot %d OH Boss lpGBT:"%slot) 
            logfile.write("Checking Slot %d OH Boss lpGBT:\n"%slot)
            n_error = 0
            results[oh_sn_list[slot-1]]["lpGBT0_bad_regs"]=[]
            for line in config_file.readlines():
                reg,value = int(line.split()[0],16),int(line.split()[1],16)
                if reg in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
                    continue
                if status_registers["SLOT%d"%slot]["BOSS"][reg] != value:
                    n_error += 1
                    print(Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(reg, value, status_registers["SLOT%d"%slot]["BOSS"][reg]) + Colors.ENDC)
                    logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(reg, value, status_registers["SLOT%d"%slot]["BOSS"][reg]))
                    # log bad registers in results
                    results[oh_sn_list[slot-1]]["lpGBT0_status_good"]=False
                    results[oh_sn_list[slot-1]]["lpGBT0_bad_regs"].append(reg)

            if n_error == 0:
                print (Colors.GREEN + "  No register mismatches" + Colors.ENDC)
                logfile.write("  No register mismatches")

                # log results for boss lpGBT
                results[oh_sn_list[slot-1]]["lpGBT0_status_good"]=True

        else: # sub lpgbts
            # Get status registers
            status_registers["SLOT%d"%slot]["SUB"]={}
            for line in status_file.readlines():
                reg,value = int(line.split()[0],16),int(line.split()[1],16)
                status_registers["SLOT%d"%slot]["SUB"][reg] = value

            # Check against config files
            print ("Checking Slot %d OH Sub lpGBT:"%slot) 
            logfile.write("Checking Slot %d OH Sub lpGBT:\n"%slot)
            n_error = 0

            results[oh_sn_list[slot-1]]["lpGBT1_bad_regs"]=[]
            for line in config_file.readlines():
                reg,value = int(line.split()[0],16),int(line.split()[1],16)
                if reg in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
                    continue
                if status_registers["SLOT%d"%slot]["SUB"][reg] != value:
                    n_error += 1
                    print(Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(reg, value, status_registers["SLOT%d"%slot]["SUB"][reg]) + Colors.ENDC)
                    logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(reg, value, status_registers["SLOT%d"%slot]["SUB"][reg]))
                    results[oh_sn_list[slot-1]]["lpGBT1_status_good"]=False
                    results[oh_sn_list[slot-1]]["lpGBT1_bad_regs"].append(reg)

            if n_error == 0:
                print (Colors.GREEN + "  No register mismatches" + Colors.ENDC)
                logfile.write("  No register mismatches")
                results[oh_sn_list[slot-1]]["lpGBT1_status_good"]=True

        status_file.close()
        config_file.close()
    
    print (Colors.GREEN + "\nStep 2: Checking lpGBT Status Complete\n" + Colors.ENDC)
    logfile.write("\nStep 2: Checking lpGBT Status Complete\n\n")
    time.sleep(5)
    
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
   
    # Step 3 - Downlink eye diagrams
    print (Colors.BLUE + "Step 3: Downlink Eye Diagram\n" + Colors.ENDC)
    logfile.write("Step 3: Downlink Eye Diagram\n\n")

    for gbt in range(0,8,2):
        slot = get_slot(oh_select,gbt)
        print (Colors.BLUE + "Running Eye diagram for Slot %d, Boss lpGBT"%slot + Colors.ENDC)
        logfile.write("Running Eye diagram for Slot %d, Boss lpGBT\n"%slot)
        os.system("python3 me0_eye_scan.py -s backend -q ME0 -o %d -g %d > out.txt"%(oh_select,gbt))
        list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*.txt")
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("python3 plotting_scripts/me0_eye_scan_plot.py -f %s -s > out.txt"%latest_file)
        list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*.pdf")
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/downlink_optical_eye_boss_slot%d.pdf"%(latest_file, dataDir, slot))
        list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*out.txt")
        latest_file = max(list_of_files, key=os.path.getctime)
        eye_result_file=open(latest_file)
        result = eye_result_file.readlines()[0]
        eye_result_file.close()
        print(result)
        logfile.write(result+"\n")

    for oh_sn in oh_sn_list:
        # Save some result
        pass

    print (Colors.GREEN + "Step 3: Downlink Eye Diagram Complete\n" + Colors.ENDC)
    logfile.write("Step 3: Downlink Eye Diagram Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 4 - Downlink Optical BERT
    print (Colors.BLUE + "Step 4: Downlink Optical BERT\n" + Colors.ENDC)
    logfile.write("Step 4: Downlink Optical BERT\n\n")

    for gbt in range(0,8,2):
        slot = get_slot(oh_select,gbt)
        print (Colors.BLUE + "Running Downlink Optical BERT for Slot %d Boss lpGBT\n"%slot + Colors.ENDC)
        logfile.write("Running Downlink Optical BERT for Slot %d Boss lpGBT\n\n"%slot)
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %d -p downlink -r run -b 1e-12 -z"%(oh_select,gbt))
        list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_optical_link_bert_fec_results/*.txt")
        latest_file = max(list_of_files, key=os.path.getctime)
        logfile.close()
        os.system("cat %s >> %s"%(latest_file, log_fn))
        logfile = open(log_fn, "a")
    
    print (Colors.GREEN + "\nStep 4: Downlink Optical BERT Complete\n" + Colors.ENDC)
    logfile.write("\nStep 4: Downlink Optical BERT Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 5 - Uplink Optical BERT
    print (Colors.BLUE + "Step 5: Uplink Optical BERT\n" + Colors.ENDC)
    logfile.write("Step 5: Uplink Optical BERT\n\n")

    ############################## 
    # May need to change uplink to work for multiple oh's 
    ##############################

    print (Colors.BLUE + "Running Uplink Optical BERT for OH %d, Boss and Sub lpGBTs\n" + Colors.ENDC)
    logfile.write("Running Uplink Optical BERT for OH %d, Boss and Sub lpGBTs\n\n")
    os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g 0 1 2 3 4 5 6 7 -p uplink -r run -b 1e-12 -z"%oh_select)
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_optical_link_bert_fec_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, log_fn))
    
    logfile = open(log_fn, "a")
    print (Colors.GREEN + "\nStep 5: Uplink Optical BERT Complete\n" + Colors.ENDC)
    logfile.write("\nStep 5: Uplink Optical BERT Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 6 - DAQ Phase Scan
    print (Colors.BLUE + "Step 6: DAQ Phase Scan\n" + Colors.ENDC)
    logfile.write("Step 6: DAQ Phase Scan\n\n")

    print (Colors.BLUE + "Running DAQ Phase Scan on all VFATs\n" + Colors.ENDC)
    logfile.write("Running DAQ Phase Scan on all VFATs\n\n")
    os.system("python3 me0_phase_scan.py -s backend -q ME0 -o %d -v "%oh_select + " ".join(map(str,range(24)))+ " -c")
    list_of_files = glob.glob("results/vfat_data/vfat_phase_scan_results/*_data_*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, log_fn))

    logfile = open(log_fn, "a")
    print (Colors.GREEN + "\nStep 6: DAQ Phase Scan Complete\n" + Colors.ENDC)
    logfile.write("\nStep 6: DAQ Phase Scan Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 7 - S-bit Phase Scan, Bitslipping, Mapping, Cluster Mapping
    print (Colors.BLUE + "Step 7: S-bit Phase Scan, Bitslipping,  Mapping, Cluster Mapping\n" + Colors.ENDC)
    logfile.write("Step 7: S-bit Phase Scan, Bitslipping, Mapping, Cluster Mapping\n\n")

    print (Colors.BLUE + "Running S-bit Phase Scan on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
    logfile.write("Running S-bit Phase Scan on OH %d all VFATs\n\n"%oh_select)
    os.system("python3 me0_vfat_sbit_phase_scan.py -s backend -q ME0 -o %d -v "%oh_select + " ".join(map(str,range(24)))+ " -l -a")
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_phase_scan_results/*_data_*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, log_fn))
    logfile = open(log_fn, "a")
    time.sleep(5)

    print (Colors.BLUE + "\n\nRunning S-bit Bitslipping on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
    logfile.write("\n\nRunning S-bit Bitslipping on OH %d, all VFATs\n\n"%oh_select)
    os.system("python3 me0_vfat_sbit_bitslip.py -s backend -q ME0 -o %d -v "%oh_select + " ".join(map(str,range(24)))+ " -l")
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_bitslip_results/*_data_*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, log_fn))
    logfile = open(log_fn, "a")
    time.sleep(5)

    print (Colors.BLUE + "\n\nRunning S-bit Mapping on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
    logfile.write("\n\nRunning S-bit Mapping on OH %d, all VFATs\n\n"%oh_select)
    os.system("python3 me0_vfat_sbit_mapping.py -s backend -q ME0 -o %d -v "%oh_select + " ".join(map(str,range(24)))+ " -l")
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_mapping_results/*_data_*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, log_fn))
    logfile = open(log_fn, "a")
    time.sleep(5)

    print (Colors.BLUE + "Running S-bit Cluster Mapping on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
    logfile.write("Running S-bit Cluster Mapping on OH %d, all VFATs\n\n"%oh_select)
    logfile.close()
    os.system("python3 vfat_sbit_monitor_clustermap.py -s backend -q ME0 -o %d -v "%oh_select + " ".join(map(str,range(24)))+ " -l -f >> %s"%log_fn)
    logfile = open(log_fn, "a")
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_monitor_cluster_mapping_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/vfat_clustermap.txt"%(latest_file, dataDir))

    logfile = open(log_fn, "a")
    print (Colors.GREEN + "\nStep 7: S-bit Phase Scan, Bitslipping, Mapping, Cluster Mapping Complete\n" + Colors.ENDC)
    logfile.write("\nStep 7: S-bit Phase Scan, Bitslipping, Mapping, Cluster Mapping Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 8 - VFAT Reset
    print (Colors.BLUE + "Step 8: VFAT Reset\n" + Colors.ENDC)
    logfile.write("Step 8: VFAT Reset\n\n")
    print (Colors.BLUE + "Configuring all VFATs\n" + Colors.ENDC)
    logfile.write("Configuring all VFATs\n\n")
    logfile.close()
    os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v "%oh_select + " ".join(map(str,range(24)))+ " -c 1 >> %s"%log_fn)
    logfile = open(log_fn, "a")
    time.sleep(5)
    
    print (Colors.BLUE + "Resetting all VFATs\n" + Colors.ENDC)
    logfile.write("Resetting all VFATs\n\n")
    logfile.close()
    os.system("python3 me0_vfat_reset.py -s backend -q ME0 -o %d -v "%oh_select + " ".join(map(str,range(24)))+ " >> %s"%log_fn)
    logfile = open(log_fn, "a")
    time.sleep(5)
    
    print (Colors.BLUE + "Unconfiguring all VFATs\n" + Colors.ENDC)
    logfile.write("Unconfiguring all VFATs\n\n")
    logfile.close()
    os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v "%oh_select + " ".join(map(str,range(24)))+ " -c 0 >> %s"%log_fn)
    logfile = open(log_fn, "a")
    
    print (Colors.GREEN + "\nStep 8: VFAT Reset Complete\n" + Colors.ENDC)
    logfile.write("\nStep 8: VFAT Reset Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 9 - Slow Control Error Rate Test
    print (Colors.BLUE + "Step 9: Slow Control Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 9: Slow Control Error Rate Test\n\n")

    os.system("python3 vfat_slow_control_test.py -s backend -q ME0 -o %d -v "%oh_select + " ".join(map(str,range(24))) + " -r TEST_REG -t 2")
    list_of_files = glob.glob("results/vfat_data/vfat_slow_control_test_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    slow_control_results_file = open(latest_file)
    write_flag = 0
    for line in slow_control_results_file.readlines():
        if "Error test results" in line:
            write_flag = 1
        if write_flag:
            logfile.write(line)
    slow_control_results_file.close()

    print (Colors.GREEN + "\nStep 9: Slow Control Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 9: Slow Control Error Rate Test Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 10 - DAQ Error Rate Test
    print (Colors.BLUE + "Step 10: DAQ Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 10: DAQ Error Rate Test\n\n")
    
    os.system("python3 vfat_daq_test.py -s backend -q ME0 -o %d -v "%oh_select + " ".join(map(str,range(24))) + " -t 2")
    list_of_files = glob.glob("results/vfat_data/vfat_daq_test_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    daq_results_file = open(latest_file)
    write_flag = 0
    for line in daq_results_file.readlines():
        if "Error test results" in line:
            write_flag = 1
        if write_flag:
            logfile.write(line)
    daq_results_file.close()
    
    print (Colors.GREEN + "\nStep 10: DAQ Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 10: DAQ Error Rate Test Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 11 - S-bit Error Rate Test
    print (Colors.BLUE + "Step 11: S-bit Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 11: S-bit Error Rate Test\n\n")
    
    print (Colors.BLUE + "Running S-bit Error test for VFAT17 Elink7\n" + Colors.ENDC)
    logfile.write("Running S-bit Error test for VFAT17 Elink7\n\n")
    os.system("python3 me0_vfat_sbit_test.py -s backend -q ME0 -o %d -v 17 -e 7 -t 1 -b 20 -l -f"%oh_select)
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_test_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    sbit_results_file1 = open(latest_file)
    write_flag = 0
    for line in sbit_results_file1.readlines():
        if "Error Test Results" in line:
            write_flag = 1
        if write_flag:
            logfile.write(line)
    sbit_results_file1.close()
    time.sleep(5)
    
    print (Colors.BLUE + "\nRunning S-bit Error test for VFAT19 Elink7\n" + Colors.ENDC)
    logfile.write("\nRunning S-bit Error test for VFAT19 Elink7\n\n")
    os.system("python3 me0_vfat_sbit_test.py -s backend -q ME0 -o %d -v 19 -e 7 -t 1 -b 20 -l -f"%oh_select)
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_test_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    sbit_results_file2 = open(latest_file)
    write_flag = 0
    for line in sbit_results_file2.readlines():
        if "Error Test Results" in line:
            write_flag = 1
        if write_flag:
            logfile.write(line)
    sbit_results_file2.close()
    
    print (Colors.GREEN + "\nStep 11: S-bit Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 11: S-bit Error Rate Test Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 12 - DAC Scans
    print (Colors.BLUE + "Step 12: DAC Scans\n" + Colors.ENDC)
    logfile.write("Step 12: DAC Scans\n\n")
    
    print (Colors.BLUE + "\nRunning DAC Scans for all VFATs\n" + Colors.ENDC)
    logfile.write("\nRunning DAC Scans for all VFATs\n\n")
    os.system("python3 vfat_dac_scan.py -s backend -q ME0 -o %d -v "%oh_select + " ".join(map(str,range(24))) +" -f ../resources/DAC_scan_reg_list.txt")
    list_of_files = glob.glob("results/vfat_data/vfat_dac_scan_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
 
    print (Colors.BLUE + "\nPlotting DAC Scans for all VFATs\n" + Colors.ENDC)
    logfile.write("\nPlotting DAC Scans for all VFATs\n\n")
    os.system("python3 plotting_scripts/vfat_analysis_dac.py -f %s"%latest_file)
    latest_dir = latest_file.split(".txt")[0]
    if os.path.isdir(latest_dir):
        if os.path.isdir(dataDir + "/dac_scan_results"):
            os.system("rm -rf " + dataDir + "/dac_scan_results")
        os.makedirs(dataDir + "/dac_scan_results")
        os.system("cp %s/*.pdf %s/dac_scan_results/"%(latest_dir, dataDir))
    else:
        print (Colors.RED + "DAC scan result directory not found" + Colors.ENDC)
        logfile.write("DAC scan result directory not found\n")
    
    print (Colors.GREEN + "\nStep 12: DAC Scans Complete\n" + Colors.ENDC)
    logfile.write("\nStep 12: DAC Scans Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 13 - ADC Measurements
    print (Colors.BLUE + "Step 13: ADC Measurements\n" + Colors.ENDC)
    logfile.write("Step 13: ADC Measurements\n\n")
    
    print (Colors.BLUE + "Configuring all VFATs\n" + Colors.ENDC)
    logfile.write("Configuring all VFATs\n\n")
    logfile.close()
    os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v "%oh_select + " ".join(map(str,range(24))) + "-c 1 >> %s"%log_fn)    
    logfile = open(log_fn, "a")
    time.sleep(5)

    print (Colors.BLUE + "\nRunning ADC Calibration Scan\n" + Colors.ENDC)
    logfile.write("Running ADC Calibration Scan\n\n")
    for gbt in range(8):
        slot = get_slot(oh_select,gbt)
        os.system("python3 me0_lpgbt_adc_calibration_scan.py -s backend -q ME0 -o %d -g %d"%(oh_select,gbt))

        list_of_files = glob.glob("results/me0_lpgbt_data/adc_calibration_data/*GBT%d*.pdf"%gbt)
        if len(list_of_files)>0:
            latest_file = max(list_of_files, key=os.path.getctime)
            if gbt%2==0:
                os.system("cp %s %s/adc_calib_slot%d_boss.pdf"%(latest_file, dataDir, slot))
            else:
                os.system("cp %s %s/adc_calib_slot%d_sub.pdf"%(latest_file, dataDir, slot))
    time.sleep(5)

    print (Colors.BLUE + "\nRunning lpGBT Voltage Scan\n" + Colors.ENDC)
    logfile.write("Running lpGBT Voltage Scan\n\n")

    for gbt in range(8):
        slot = get_slot(oh_select,gbt)
        os.system("python3 me0_voltage_monitor.py -s backend -q ME0 -o %d -g %d -m 1"%(oh_select,gbt))
        list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_voltage_data/*GBT0*.pdf")
        if len(list_of_files)>0:
            latest_file = max(list_of_files, key=os.path.getctime)
            if gbt%2==0:
                os.system("cp %s %s/voltage_slot%d_boss.pdf"%(latest_file, dataDir, slot))
            else:
                os.system("cp %s %s/voltage_slot%d_sub.pdf"%(latest_file, dataDir, slot))
    time.sleep(5)

    print (Colors.BLUE + "\nRunning RSSI Scan\n" + Colors.ENDC)
    logfile.write("Running RSSI Scan\n\n")
    for gbt in range(1,8,2):
        slot = get_slot(oh_select,gbt)
        os.system("python3 me0_rssi_monitor.py -s backend -q ME0 -o %d -g %d -v 2.56 -m 5"%(oh_select,gbt))
        list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_vtrx+_rssi_data/*GBT%d*.pdf"%gbt)
        if len(list_of_files)>0:
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("cp %s %s/rssi_slot%d.pdf"%(latest_file, dataDir, slot))
    time.sleep(5)







