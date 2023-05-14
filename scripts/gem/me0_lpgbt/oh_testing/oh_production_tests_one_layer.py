import sys, os, glob
import time
import argparse
import numpy as np
from gem.me0_lpgbt.rw_reg_lpgbt import *

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OptoHybrid Production Tests")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = list of OH numbers (0-1)")
    parser.add_argument("-n", "--oh_ser_nrs", action="store", nargs="+", dest="oh_ser_nrs", help="oh_ser_nrs = list of OH serial numbers")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-b", "--batch", action="store", dest="batch", help="batch = which batch of oh tests to perform: pre-series, production or production-long. (pre,prod,prod_long)")
    args = parser.parse_args()

    if args.ohid is None:
        print(Colors.YELLOW + "Enter OHID numbers" + Colors.ENDC)
        sys.exit()
    oh_select = int(args.ohid)
    # oh_select_list = []
    # for oh in args.ohid:
    #     if int(oh) not in range(2):
    #         print (Colors.YELLOW + "Invalid OHID, only allowed 0-1" + Colors.ENDC)
    #         sys.exit()
    #     oh_select_list.append(int(oh))

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
        os.makedirs(OHDir) # create directory for ohid under test
    except FileExistsError: # skip if directory already exists
        pass
    log_fn = OHDir + "/oh_tests_log.txt"
    logfile = open(log_fn, "w")
    resultsfile = open(OHDir + "/oh_tests_results.txt","w")

    results = {}
    # log results for each asiago by serial #
    # Not sure if booleans should be True/False or 1/0
    get_slot = lambda oh,gbt: np.floor_divide(gbt,2)+2*oh+1

    for oh_ser_nr in oh_ser_nr_list:
        results[oh_ser_nr]={}
        # Which test batch
        if args.batch == "pre":
            results[oh_ser_nr]["pre_series"]=True
            results[oh_ser_nr]["production"]=False
            results[oh_ser_nr]["production_long"]=False
        elif args.batch == "prod":
            results[oh_ser_nr]["pre_series"]=False
            results[oh_ser_nr]["production"]=True
            results[oh_ser_nr]["production_long"]=False
        elif args.batch == "prod_long":
            results[oh_ser_nr]["pre_series"]=False
            results[oh_ser_nr]["production"]=False
            results[oh_ser_nr]["production_long"]=True
        else:
            results[oh_ser_nr]["pre_series"]=False
            results[oh_ser_nr]["production"]=False
            results[oh_ser_nr]["production_long"]=False


    oh_ver_list = []
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

    # default result log. Might need to manually check that all is good
    for oh_ser_nr in oh_ser_nr_list:
        results[oh_ser_nr]["initialization"]=True

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
            results[oh_ser_nr_list[slot-1]]["lpGBT0_bad_regs"]=[]
            for line in config_file.readlines():
                reg,value = int(line.split()[0],16),int(line.split()[1],16)
                if reg in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
                    continue
                if status_registers["SLOT%d"%slot]["BOSS"][reg] != value:
                    n_error += 1
                    print(Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(reg, value, status_registers["SLOT%d"%slot]["BOSS"][reg]) + Colors.ENDC)
                    logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(reg, value, status_registers["SLOT%d"%slot]["BOSS"][reg]))
                    # log bad registers in results
                    results[oh_ser_nr_list[slot-1]]["lpGBT0_status_good"]=False
                    results[oh_ser_nr_list[slot-1]]["lpGBT0_bad_regs"].append(reg)

            if n_error == 0:
                print (Colors.GREEN + "  No register mismatches" + Colors.ENDC)
                logfile.write("  No register mismatches")

                # log results for boss lpGBT
                results[oh_ser_nr_list[slot-1]]["lpGBT0_status_good"]=True

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

            results[oh_ser_nr_list[slot-1]]["lpGBT1_bad_regs"]=[]
            for line in config_file.readlines():
                reg,value = int(line.split()[0],16),int(line.split()[1],16)
                if reg in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
                    continue
                if status_registers["SLOT%d"%slot]["SUB"][reg] != value:
                    n_error += 1
                    print(Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(reg, value, status_registers["SLOT%d"%slot]["SUB"][reg]) + Colors.ENDC)
                    logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(reg, value, status_registers["SLOT%d"%slot]["SUB"][reg]))
                    results[oh_ser_nr_list[slot-1]]["lpGBT1_status_good"]=False
                    results[oh_ser_nr_list[slot-1]]["lpGBT1_bad_regs"].append(reg)

            if n_error == 0:
                print (Colors.GREEN + "  No register mismatches" + Colors.ENDC)
                logfile.write("  No register mismatches")
                results[oh_ser_nr_list[slot-1]]["lpGBT1_status_good"]=True

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

    for oh_ser_nr in oh_ser_nr_list:
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
    
    # Step 2 - DAQ Error Rate Test
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



    









