import sys, os, glob
import time
import argparse
from gem.me0_lpgbt.rw_reg_lpgbt import *

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Testing Step 1 - Initialize, Configure and Optical Tests")
    parser.add_argument("-s1", "--slot1", action="store", dest="slot1", help="slot1 = OH serial number on slot 1")
    parser.add_argument("-s2", "--slot2", action="store", dest="slot2", help="slot2 = OH serial number on slot 2")
    args = parser.parse_args()

    if args.slot1 is "None" or args.slot2 is None:
        print (Colors.YELLOW + "Enter OH serial numbers for both slot 1 and 2" + Colors.ENDC) 
        sys.exit()

    resultDir = "results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    me0Dir = "me0_lpgbt/oh_testing/results/OH_slot1_%s_slot2_%s"%(args.slot1, args.slot2)
    try:
        os.makedirs(me0Dir) # create directory for OH under test
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = me0Dir+"/step1_initialize_optical_tests"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    filename = dataDir + "/step_1_log.txt"
    logfile = open(filename, "w")
    
    oh_ver_slot1 = get_oh_ver("0", "0")
    oh_ver_slot2 = get_oh_ver("0", "2")
    
    print ("\n#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 1 - run init_frontend
    print (Colors.BLUE + "Step 1: Initializing\n" + Colors.ENDC)
    logfile.write("Step 1: Initializing\n\n")
    logfile.close()

    os.system("python3 init_frontend.py")
    os.system("python3 init_frontend.py >> %s"%filename)
    logfile = open(filename, "a")

    print (Colors.GREEN + "\nStep 1: Initialization Complete\n" + Colors.ENDC)
    logfile.write("\nStep 1: Initialization Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 2 - check lpGBT status
    print (Colors.BLUE + "Step 2: Checking lpGBT Status\n" + Colors.ENDC)
    logfile.write("Step 2: Checking lpGBT Status\n\n")
    
    os.system("python3 me0_lpgbt_status.py -s backend -q ME0 -o 0 -g 0 > out.txt")
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_status_data/status_boss*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/status_boss_slot1.txt"%(latest_file, dataDir))
    os.system("python3 me0_lpgbt_status.py -s backend -q ME0 -o 0 -g 1 > out.txt")
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_status_data/status_sub*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/status_sub_slot1.txt"%(latest_file, dataDir))
    
    os.system("python3 me0_lpgbt_status.py -s backend -q ME0 -o 0 -g 2 > out.txt")
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_status_data/status_boss*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/status_boss_slot2.txt"%(latest_file, dataDir))
    os.system("python3 me0_lpgbt_status.py -s backend -q ME0 -o 0 -g 3 > out.txt")
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_status_data/status_sub*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/status_sub_slot2.txt"%(latest_file, dataDir))
      
    config_boss_slot1_file = open("../resources/me0_boss_config_ohv%d.txt"%oh_ver_slot1) 
    config_sub_slot1_file = open("../resources/me0_sub_config_ohv%d.txt"%oh_ver_slot1)
    config_boss_slot2_file = open("../resources/me0_boss_config_ohv%d.txt"%oh_ver_slot2) 
    config_sub_slot2_file = open("../resources/me0_sub_config_ohv%d.txt"%oh_ver_slot2) 
    status_boss_slot1_file = open("%s/status_boss_slot1.txt"%dataDir) 
    status_sub_slot1_file = open("%s/status_sub_slot1.txt"%dataDir) 
    status_boss_slot2_file = open("%s/status_boss_slot2.txt"%dataDir) 
    status_sub_slot2_file = open("%s/status_sub_slot2.txt"%dataDir) 
    
    status_boss_slot1_registers = {}
    status_sub_slot1_registers = {}
    status_boss_slot2_registers = {}
    status_sub_slot2_registers = {}
    for line in status_boss_slot1_file.readlines():
        status_boss_slot1_registers[int(line.split()[0],16)] = int(line.split()[1],16)
    for line in status_sub_slot1_file.readlines():
        status_sub_slot1_registers[int(line.split()[0],16)] = int(line.split()[1],16)
    for line in status_boss_slot2_file.readlines():
        status_boss_slot2_registers[int(line.split()[0],16)] = int(line.split()[1],16)
    for line in status_sub_slot2_file.readlines():
        status_sub_slot2_registers[int(line.split()[0],16)] = int(line.split()[1],16)
       
    print ("Checking Slot 1 OH Boss lpGBT:") 
    logfile.write("Checking Slot 1 OH Boss lpGBT:\n")
    n_error = 0
    for line in config_boss_slot1_file.readlines():
        if int(line.split()[0],16) in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
            continue
        if status_boss_slot1_registers[int(line.split()[0],16)] != int(line.split()[1],16):
            n_error += 1
            print (Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(int(line.split()[0],16), int(line.split()[1],16), status_boss_slot1_registers[int(line.split()[0],16)]) + Colors.ENDC)
            logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(int(line.split()[0],16), int(line.split()[1],16), status_boss_slot1_registers[int(line.split()[0],16)]))
    if n_error == 0:
        print (Colors.GREEN + "  No register mismatches" + Colors.ENDC)
        logfile.write("  No register mismatches")

    print ("Checking Slot 1 OH Sub lpGBT:")
    logfile.write("Checking Slot 1 OH Sub lpGBT:\n")
    n_error = 0
    for line in config_sub_slot1_file.readlines():
        if int(line.split()[0],16) in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
            continue
        if status_sub_slot1_registers[int(line.split()[0],16)] != int(line.split()[1],16):
            n_error += 1
            print (Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(int(line.split()[0],16), int(line.split()[1],16), status_sub_slot1_registers[int(line.split()[0],16)]) + Colors.ENDC)
            logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(int(line.split()[0],16), int(line.split()[1],16), status_sub_slot1_registers[int(line.split()[0],16)]))
    if n_error == 0:
        print (Colors.GREEN + "  No register mismatches" + Colors.ENDC)
        logfile.write("  No register mismatches")

    print ("Checking Slot 2 OH Boss lpGBT:")
    logfile.write("Checking Slot 2 OH Boss lpGBT:\n")
    n_error = 0
    for line in config_boss_slot2_file.readlines():
        if int(line.split()[0],16) in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
            continue
        if status_boss_slot2_registers[int(line.split()[0],16)] != int(line.split()[1],16):
            n_error += 1
            print (Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(int(line.split()[0],16), int(line.split()[1],16), status_boss_slot2_registers[int(line.split()[0],16)]) + Colors.ENDC)
            logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(int(line.split()[0],16), int(line.split()[1],16), status_boss_slot2_registers[int(line.split()[0],16)]))
    if n_error == 0:
        print (Colors.GREEN + "  No register mismatches" + Colors.ENDC)
        logfile.write("  No register mismatches")

    print ("Checking Slot 2 OH Sub lpGBT:") 
    logfile.write("Checking Slot 2 OH Sub lpGBT:\n")
    n_error = 0
    for line in config_sub_slot2_file.readlines():
        if int(line.split()[0],16) in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
            continue
        if status_sub_slot2_registers[int(line.split()[0],16)] != int(line.split()[1],16):
            n_error += 1
            print (Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(int(line.split()[0],16), int(line.split()[1],16), status_sub_slot2_registers[int(line.split()[0],16)]) + Colors.ENDC)
            logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(int(line.split()[0],16), int(line.split()[1],16), status_sub_slot2_registers[int(line.split()[0],16)]))
    if n_error == 0:
        print (Colors.GREEN + "  No register mismatches" + Colors.ENDC)
        logfile.write("  No register mismatches")

    config_boss_slot1_file.close()
    config_sub_slot1_file.close()
    config_boss_slot2_file.close()
    config_sub_slot2_file.close()
    status_boss_slot1_file.close()
    status_sub_slot1_file.close()
    status_boss_slot2_file.close()
    status_sub_slot2_file.close()
    
    print (Colors.GREEN + "\nStep 2: Checking lpGBT Status Complete\n" + Colors.ENDC)
    logfile.write("\nStep 2: Checking lpGBT Status Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
   
    # Step 3 - Downlink eye diagrams
    print (Colors.BLUE + "Step 3: Downlink Eye Diagram\n" + Colors.ENDC)
    logfile.write("Step 3: Downlink Eye Diagram\n\n")
    
    print (Colors.BLUE + "Running Eye diagram for Slot 1, Boss lpGBT" + Colors.ENDC)
    logfile.write("Running Eye diagram for Slot 1, Boss lpGBT")
    os.system("python3 me0_eye_scan.py -s backend -q ME0 -o 0 -g 0 > out.txt")
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("python3 plotting_scripts/me0_eye_scan_plot.py -f %s -s > out.txt"%latest_file)
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*.pdf")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/downlink_optical_eye_boss_slot1.pdf"%(latest_file, dataDir))
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*out.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    eye_result_slot1_boss_file = open(latest_file)
    result = eye_result_slot1_boss_file.readlines()[0]
    eye_result_slot1_boss_file.close()
    print (result)
    logfile.write(result)
    
    print (Colors.BLUE + "Running Eye diagram for Slot 2, Boss lpGBT" + Colors.ENDC)
    logfile.write("Running Eye diagram for Slot 2, Boss lpGBT")
    os.system("python3 me0_eye_scan.py -s backend -q ME0 -o 0 -g 2 > out.txt")
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("python3 plotting_scripts/me0_eye_scan_plot.py -f %s -s > out.txt"%latest_file)
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*.pdf")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/downlink_optical_eye_boss_slot2.pdf"%(latest_file, dataDir))
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*out.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    eye_result_slot2_boss_file = open(latest_file)
    result = eye_result_slot2_boss_file.readlines()[0]
    eye_result_slot2_boss_file.close()
    print (result)
    logfile.write(result)
    
    print (Colors.GREEN + "Step 3: Downlink Eye Diagram Complete\n" + Colors.ENDC)
    logfile.write("Step 3: Downlink Eye Diagram Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 4 - Downlink Optical BERT
    print (Colors.BLUE + "Step 4: Downlink Optical BERT\n" + Colors.ENDC)
    logfile.write("Step 4: Downlink Optical BERT\n\n")
    
    print (Colors.BLUE + "Running Downlink Optical BERT for Slot 1 Boss lpGBT\n" + Colors.ENDC)
    logfile.write("Running Downlink Optical BERT for Slot 1 Boss lpGBT\n\n")
    os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o 0 -g 0 -p downlink -r run -b 1e-12 -z")
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_optical_link_bert_fec_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, filename))
    
    logfile = open(filename, "a")
    print (Colors.BLUE + "Running Downlink Optical BERT for Slot 2 Boss lpGBT\n" + Colors.ENDC)
    logfile.write("Running Downlink Optical BERT for Slot 2 Boss lpGBT\n\n")
    os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o 0 -g 2 -p downlink -r run -b 1e-12 -z")
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_optical_link_bert_fec_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, filename))
    
    logfile = open(filename, "a")
    print (Colors.GREEN + "\nStep 4: Downlink Optical BERT Complete\n" + Colors.ENDC)
    logfile.write("\nStep 4: Downlink Optical BERT Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 5 - Uplink Optical BERT
    print (Colors.BLUE + "Step 5: Uplink Optical BERT\n" + Colors.ENDC)
    logfile.write("Step 5: Uplink Optical BERT\n\n")
    
    print (Colors.BLUE + "Running Uplink Optical BERT for Slot 1 and Slot 2, Boss and Sub lpGBTs\n" + Colors.ENDC)
    logfile.write("Running Uplink Optical BERT for Slot 1 and Slot 2, Boss and Sub lpGBTs\n\n")
    os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o 0 -g 0 1 2 3 -p uplink -r run -b 1e-12 -z")
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_optical_link_bert_fec_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, filename))
    
    logfile = open(filename, "a")
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
    os.system("python3 me0_phase_scan.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c")
    list_of_files = glob.glob("results/vfat_data/vfat_phase_scan_results/*_data_*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, filename))

    logfile = open(filename, "a")
    print (Colors.GREEN + "\nStep 6: DAQ Phase Scan Complete\n" + Colors.ENDC)
    logfile.write("\nStep 6: DAQ Phase Scan Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 7 - S-bit Phase Scan, Mapping, Cluster Mapping
    print (Colors.BLUE + "Step 7: S-bit Phase Scan, Mapping, Cluster Mapping\n" + Colors.ENDC)
    logfile.write("Step 7: S-bit Phase Scan, Mapping, Cluster Mapping\n\n")

    print (Colors.BLUE + "Running S-bit Phase Scan on all VFATs\n" + Colors.ENDC)
    logfile.write("Running S-bit Phase Scan on all VFATs\n\n")
    os.system("python3 me0_vfat_sbit_phase_scan.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -l -a")
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_phase_scan_results/*_data_*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, filename))
    logfile = open(filename, "a")
    time.sleep(5)

    print (Colors.BLUE + "\n\nRunning S-bit Mapping on all VFATs\n" + Colors.ENDC)
    logfile.write("\n\nRunning S-bit Mapping on all VFATs\n\n")
    os.system("python3 me0_vfat_sbit_mapping.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -l")
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_mapping_results/*_data_*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, filename))
    logfile = open(filename, "a")
    time.sleep(5)

    print (Colors.BLUE + "Running S-bit Cluster Mapping on all VFATs\n" + Colors.ENDC)
    logfile.write("Running S-bit Cluster Mapping on all VFATs\n\n")
    logfile.close()
    os.system("python3 vfat_sbit_monitor_clustermap.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -l >> %s"%filename)
    logfile = open(filename, "a")
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_monitor_cluster_mapping_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/vfat_clustermap.txt"%(latest_file, dataDir))

    logfile = open(filename, "a")
    print (Colors.GREEN + "\nStep 7: S-bit Phase Scan, Mapping, Cluster Mapping Complete\n" + Colors.ENDC)
    logfile.write("\nStep 7: S-bit Phase Scan, Mapping, Cluster Mapping Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 8 - VFAT Reset
    print (Colors.BLUE + "Step 8: VFAT Reset\n" + Colors.ENDC)
    logfile.write("Step 8: VFAT Reset\n\n")

    print (Colors.BLUE + "Configuring all VFATs\n" + Colors.ENDC)
    logfile.write("Configuring all VFATs\n\n")
    logfile.close()
    os.system("python3 vfat_config.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c 1 >> %s"%filename)
    logfile = open(filename, "a")
    time.sleep(5)

    print (Colors.BLUE + "Resetting all VFATs\n" + Colors.ENDC)
    logfile.write("Resetting all VFATs\n\n")
    logfile.close()
    os.system("python3 me0_vfat_reset.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 >> %s"%filename)
    logfile = open(filename, "a")
    time.sleep(5)

    print (Colors.BLUE + "Unconfiguring all VFATs\n" + Colors.ENDC)
    logfile.write("Unconfiguring all VFATs\n\n")
    logfile.close()
    os.system("python3 vfat_config.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c 0 >> %s"%filename)
    logfile = open(filename, "a")

    print (Colors.GREEN + "\nStep 8: VFAT Reset Complete\n" + Colors.ENDC)
    logfile.write("\nStep 8: VFAT Reset Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    logfile.close()
    os.system("rm -rf out.txt")






