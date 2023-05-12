import sys, os, glob
import time
import argparse
import numpy as np
from gem.me0_lpgbt.rw_reg_lpgbt import *

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OptoHybrid Production Tests")
    parser.add_argument("-o", "--ohs", action="store", nargs="+", dest="ohs", help="ohs = list of OH numbers (0-1)")
    parser.add_argument("-n", "--oh_ser_nrs", action="store", nargs="+", dest="oh_ser_nrs", help="oh_ser_nrs = list of OH serial numbers")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-b", "--batch", action="store", dest="batch", help="batch = which batch of oh tests to perform: pre-series, production or production-long. (pre,prod,prod_long)")
    args = parser.parse_args()

    if args.ohs is None:
        print(Colors.YELLOW + "Enter OHID numbers" + Colors.ENDC)
        sys.exit()
    oh_select_list = []
    for oh in args.ohs:
        if int(oh) not in range(2):
            print (Colors.YELLOW + "Invalid OHID, only allowed 0-1" + Colors.ENDC)
            sys.exit()
        oh_select_list.append(int(oh))

    if args.oh_ser_nrs is None:
        print (Colors.YELLOW + "Enter OH serial numbers" + Colors.ENDC)
    oh_ser_nr_list = []
    for n in args.oh_ser_nrs:
        oh_ser_nr_list.append(n) # Keep as identifier string
    
    if args.vfats is None:
        print (Colors.YELLOW + "Enter VFAT numbers" + Colors.ENDC)
        sys.exit()
    vfat_list = []
    for v in args.vfats:
        if int(v) not in range(24):
            print (Colors.YELLOW + "Invalid VFAT number, only allowed 0-23" + Colors.ENDC)
            sys.exit()
        vfat_list.append(int(v))
    
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
    OHDir = dataDir+"/OH_SNs_"+"_".join(oh_ser_nr_list)
    try:
        os.makedirs(OHDir) # create directory for OHs under test
    except FileExistsError: # skip if directory already exists
        pass
    log_fn = OHDir + "/oh_tests_log.txt"
    logfile = open(log_fn, "w")
    resultsfile = open(OHDir + "/oh_tests_results.txt","w")

    results = {}
    for oh_ser_nr in oh_ser_nr_list:
        results[oh_ser_nr]={}
        if args.batch == "pre":
            results[oh_ser_nr]["pre_series"]=True
        


    oh_ver_list = []
    for oh_select in oh_select_list:
        for gbt_idx in range(0,8,2):
            oh_ver_list.append(get_oh_ver(oh_select,gbt_idx))
    
    print ("\n#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 1 - run init_frontend
    print (Colors.BLUE + "Step 1: Initializing\n" + Colors.ENDC)
    logfile.write("Step 1: Initializing\n\n")
    logfile.close()

    os.system("python3 init_frontend.py")
    os.system("python3 init_frontend.py >> %s"%log_fn)
    logfile = open(log_fn, "a")

    print (Colors.GREEN + "\nStep 1: Initialization Complete\n" + Colors.ENDC)
    logfile.write("\nStep 1: Initialization Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 2 - check lpGBT status
    print (Colors.BLUE + "Step 2: Checking lpGBT Status\n" + Colors.ENDC)
    logfile.write("Step 2: Checking lpGBT Status\n\n")

    for oh_select in oh_select_list:
        for gbt in range(8):
            os.system("python3 me0_lpgbt_status.py -s backend -q ME0 -o %d -g %d > out.txt"%(oh_select,gbt))
            # even gbt indexes are boss, odd are sub
            slot = np.floor_divide(gbt,2)+2*oh_select+1
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
    for oh_select in oh_select_list:
        for gbt in range(8):
            slot = np.floor_divide(gbt,2)+2*oh_select+1            
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
                status_registers["SLOT%d"%slot]["BOSS"][int(line.split()[0],16)] = int(line.split()[1],16)
            
            # Check against config files
            print ("Checking Slot %d OH Boss lpGBT:"%slot) 
            logfile.write("Checking Slot %d OH Boss lpGBT:\n"%slot)
            n_error = 0
            for line in config_file.readlines():
                if int(line.split()[0],16) in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
                    continue
                if status_registers["SLOT%d"%slot]["BOSS"][int(line.split()[0],16)] != int(line.split()[1],16):
                    n_error += 1
                    print (Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(int(line.split()[0],16), int(line.split()[1],16), status_registers["SLOT%d"%slot]["BOSS"][int(line.split()[0],16)]) + Colors.ENDC)
                    logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(int(line.split()[0],16), int(line.split()[1],16), status_registers["SLOT%d"%slot]["BOSS"][int(line.split()[0],16)]))
            if n_error == 0:
                print (Colors.GREEN + "  No register mismatches" + Colors.ENDC)
                logfile.write("  No register mismatches")

        else: # sub lpgbts
            # Get status registers
            status_registers["SLOT%d"%slot]["SUB"]={}
            for line in status_file.readlines():
                status_registers["SLOT%d"%slot]["SUB"][int(line.split()[0],16)] = int(line.split()[1],16)

            # Check against config files
            print ("Checking Slot %d OH Sub lpGBT:"%slot) 
            logfile.write("Checking Slot %d OH Sub lpGBT:\n"%slot)
            n_error = 0
            for line in config_file.readlines():
                if int(line.split()[0],16) in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
                    continue
                if status_registers["SLOT%d"%slot]["SUB"][int(line.split()[0],16)] != int(line.split()[1],16):
                    n_error += 1
                    print (Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(int(line.split()[0],16), int(line.split()[1],16), status_registers["SLOT%d"%slot]["SUB"][int(line.split()[0],16)]) + Colors.ENDC)
                    logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(int(line.split()[0],16), int(line.split()[1],16), status_registers["SLOT%d"%slot]["SUB"][int(line.split()[0],16)]))
            if n_error == 0:
                print (Colors.GREEN + "  No register mismatches" + Colors.ENDC)
                logfile.write("  No register mismatches")
        
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

    eye_result_files = {}
    for oh_select in oh_select_list:
        for gbt in range(0,8,2):
            slot = np.floor_divide(gbt,2)+2*oh_select+1
            eye_result_files["SLOT%d"%slot]={"BOSS":{}}
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
            eye_result_files["SLOT%d"%slot]["BOSS"]["DOWNLINK"] = open(latest_file)
            result = eye_result_files["SLOT%d"%slot]["BOSS"]["DOWNLINK"].readlines()[0]
            eye_result_files["SLOT%d"%slot]["BOSS"]["DOWNLINK"].close()
            print(result)
            logfile.write(result+"\n")

    print (Colors.GREEN + "Step 3: Downlink Eye Diagram Complete\n" + Colors.ENDC)
    logfile.write("Step 3: Downlink Eye Diagram Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 4 - Downlink Optical BERT
    print (Colors.BLUE + "Step 4: Downlink Optical BERT\n" + Colors.ENDC)
    logfile.write("Step 4: Downlink Optical BERT\n\n")





    









