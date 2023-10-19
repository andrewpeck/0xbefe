import sys, os, glob
import time
import argparse
from gem.me0_lpgbt.rw_reg_lpgbt import *
from common.utils import get_befe_scripts_dir

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="ME0 bPOL Testing")
    parser.add_argument("-v", "--voltage", action="store", dest="voltage", help="power supply voltage")
    args = parser.parse_args()

    if args.voltage is "None":
        print (Colors.YELLOW + "Enter power supply voltage" + Colors.ENDC) 
        sys.exit()
    voltage = float(args.voltage)

    scripts_gem_dir = get_befe_scripts_dir + '/gem'
    resultDir = scripts_gem_dir + "/results" # gem results dir
    me0Dir = resultDir + '/me0_lpgbt_data'
    try:
        os.makedirs(me0Dir) # create directory for OH under test
    except FileExistsError: # skip if directory already exists
        pass
    vfatDir = resultDir + '/vfat_data'
    try:
        os.makedirs(vfatDir) # create directory for OH under test
    except FileExistsError: # skip if directory already exists
        pass

    bpolResultDir = scripts_gem_dir + '/me0_lpgbt/bpol_testing/results'
    dataDir = bpolResultDir + "/voltage_%.1f"%(voltage)
    try:
        os.makedirs(dataDir) # create directory for OH under test
    except FileExistsError: # skip if directory already exists
        pass
    
    filename = dataDir + "/log.txt"
    logfile = open(filename, "w")
    
    oh_ver_slot1 = get_oh_ver("0", "0")
    oh_ver_slot2 = get_oh_ver("0", "2")
    
    print ("\n#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Power on   
    os.system("python3 me0_lpgbt/powercycle_test_ucla/set_relay.py -r 7 -s on")
    time.sleep(10)

    # Step 1 - Run init_frontend
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
    
    # Step 2 - Downlink Optical BERT     
    print (Colors.BLUE + "Step 2: Downlink Optical BERT\n" + Colors.ENDC)
    logfile.write("Step 2: Downlink Optical BERT\n\n")
    
    print (Colors.BLUE + "Running Downlink Optical BERT for Slot 1 Boss lpGBT\n" + Colors.ENDC)
    logfile.write("Running Downlink Optical BERT for Slot 1 Boss lpGBT\n\n")
    os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o 0 -g 0 -p downlink -r run -b 1e-12 -z")
    list_of_files = glob.glob(me0Dir + "/lpgbt_optical_link_bert_fec_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, filename))
    
    logfile = open(filename, "a")
    print (Colors.BLUE + "Running Downlink Optical BERT for Slot 2 Boss lpGBT\n" + Colors.ENDC)
    logfile.write("Running Downlink Optical BERT for Slot 2 Boss lpGBT\n\n")
    os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o 0 -g 2 -p downlink -r run -b 1e-12 -z")
    list_of_files = glob.glob(me0Dir + "/lpgbt_optical_link_bert_fec_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, filename))
    
    logfile = open(filename, "a")
    print (Colors.GREEN + "\nStep 2: Downlink Optical BERT Complete\n" + Colors.ENDC)
    logfile.write("\nStep 2: Downlink Optical BERT Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 3 - Uplink Optical BERT
    print (Colors.BLUE + "Step 3: Uplink Optical BERT\n" + Colors.ENDC)
    logfile.write("Step 3: Uplink Optical BERT\n\n")
    
    print (Colors.BLUE + "Running Uplink Optical BERT for Slot 1 and Slot 2, Boss and Sub lpGBTs\n" + Colors.ENDC)
    logfile.write("Running Uplink Optical BERT for Slot 1 and Slot 2, Boss and Sub lpGBTs\n\n")
    os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o 0 -g 0 1 2 3 -p uplink -r run -b 1e-12 -z")
    list_of_files = glob.glob(me0Dir + "/lpgbt_optical_link_bert_fec_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, filename))
    
    logfile = open(filename, "a")
    print (Colors.GREEN + "\nStep 3: Uplink Optical BERT Complete\n" + Colors.ENDC)
    logfile.write("\nStep 3: Uplink Optical BERT Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 4 - DAQ Phase Scan
    print (Colors.BLUE + "Step 4: DAQ Phase Scan\n" + Colors.ENDC)
    logfile.write("Step 4: DAQ Phase Scan\n\n")

    print (Colors.BLUE + "Running DAQ Phase Scan on all VFATs\n" + Colors.ENDC)
    logfile.write("Running DAQ Phase Scan on all VFATs\n\n")
    os.system("python3 me0_phase_scan.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c")
    list_of_files = glob.glob(vfatDir + "/vfat_phase_scan_results/*_data_*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, filename))

    logfile = open(filename, "a")
    print (Colors.GREEN + "\nStep 4: DAQ Phase Scan Complete\n" + Colors.ENDC)
    logfile.write("\nStep 4: DAQ Phase Scan Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 5 - S-bit Phase Scan, Mapping, Cluster Mapping
    print (Colors.BLUE + "Step 5: S-bit Phase Scan, Mapping, Cluster Mapping\n" + Colors.ENDC)
    logfile.write("Step 5: S-bit Phase Scan, Mapping, Cluster Mapping\n\n")

    print (Colors.BLUE + "Running S-bit Phase Scan on all VFATs\n" + Colors.ENDC)
    logfile.write("Running S-bit Phase Scan on all VFATs\n\n")
    os.system("python3 me0_vfat_sbit_phase_scan.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -l -a")
    list_of_files = glob.glob(vfatDir + "/vfat_sbit_phase_scan_results/*_data_*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    logfile.close()
    os.system("cat %s >> %s"%(latest_file, filename))
    logfile = open(filename, "a")
    time.sleep(5)

    print (Colors.BLUE + "\n\nRunning S-bit Mapping on all VFATs\n" + Colors.ENDC)
    logfile.write("\n\nRunning S-bit Mapping on all VFATs\n\n")
    os.system("python3 me0_vfat_sbit_mapping.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -l")
    list_of_files = glob.glob(vfatDir + "/vfat_sbit_mapping_results/*_data_*.txt")
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
    list_of_files = glob.glob(vfatDir + "/vfat_sbit_monitor_cluster_mapping_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/vfat_clustermap.txt"%(latest_file, dataDir))

    logfile = open(filename, "a")
    print (Colors.GREEN + "\nStep 5: S-bit Phase Scan, Mapping, Cluster Mapping Complete\n" + Colors.ENDC)
    logfile.write("\nStep 5: S-bit Phase Scan, Mapping, Cluster Mapping Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 6 - Slow Control Error Rate Test
    print (Colors.BLUE + "Step 6: Slow Control Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 6: Slow Control Error Rate Test\n\n")
    
    os.system("python3 vfat_slow_control_test.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -r TEST_REG -t 30")
    list_of_files = glob.glob(vfatDir + "/vfat_slow_control_test_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    slow_control_results_file = open(latest_file)
    write_flag = 0
    for line in slow_control_results_file.readlines():
        if "Error test results" in line:
            write_flag = 1
        if write_flag:
            logfile.write(line)
    slow_control_results_file.close()
    
    print (Colors.GREEN + "\nStep 6: Slow Control Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 6: Slow Control Error Rate Test Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 7 - DAQ Error Rate Test
    print (Colors.BLUE + "Step 7: DAQ Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 7: DAQ Error Rate Test\n\n")
    
    os.system("python3 vfat_daq_test.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -b 40 -t 30")
    list_of_files = glob.glob(vfatDir + "/vfat_daq_test_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    daq_results_file = open(latest_file)
    write_flag = 0
    for line in daq_results_file.readlines():
        if "Error test results" in line:
            write_flag = 1
        if write_flag:
            logfile.write(line)
    daq_results_file.close()
    
    print (Colors.GREEN + "\nStep 7: DAQ Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 7: DAQ Error Rate Test Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 8 - DAQ SCurve 
    print (Colors.BLUE + "Step 8: DAQ SCurve\n" + Colors.ENDC)
    logfile.write("Step 8: DAQ SCurve\n\n")
    
    print (Colors.BLUE + "Running DAQ SCurves for all VFATs\n" + Colors.ENDC)
    logfile.write("Running DAQ SCurves for all VFATs\n\n")
    os.system("python3 vfat_daq_scurve.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -n 1000")
    list_of_files = glob.glob(vfatDir + "/vfat_daq_scurve_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    
    print (Colors.BLUE + "Plotting DAQ SCurves for all VFATs\n" + Colors.ENDC)
    logfile.write("Plotting DAQ SCurves for all VFATs\n\n")
    os.system("python3 plotting_scripts/vfat_analysis_scurve.py -c 0 -m voltage -f %s"%latest_file)
    latest_dir = latest_file.split(".txt")[0]
    if os.path.isdir(latest_dir):
        os.system("cp %s/scurve2Dhist_ME0_OH0.png %s/daq_scurve_2D_hist.png"%(latest_dir, dataDir))
        os.system("cp %s/scurveENCdistribution_ME0_OH0.pdf %s/daq_scurve_ENC.pdf"%(latest_dir, dataDir))
        os.system("cp %s/scurveThreshdistribution_ME0_OH0.pdf %s/daq_scurve_Threshold.pdf"%(latest_dir, dataDir))
    else:
        print (Colors.RED + "DAQ Scurve result directory not found" + Colors.ENDC)
        logfile.write("DAQ SCurve result directory not found\n")    
    
    print (Colors.GREEN + "\nStep 8: DAQ SCurve Complete\n" + Colors.ENDC)
    logfile.write("\nStep 8: DAQ SCurve Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 9 - S-bit SCurve
    print (Colors.BLUE + "Step 9: S-bit SCurve\n" + Colors.ENDC)
    logfile.write("Step 9: S-bit SCurve\n\n")
    
    print (Colors.BLUE + "Running S-bit SCurves for all VFATs\n" + Colors.ENDC)
    logfile.write("Running S-bit SCurves for all VFATs\n\n")
    os.system("python3 me0_vfat_sbit_scurve.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -n 1000 -b 20 -l")
    list_of_files = glob.glob(vfatDir + "/vfat_sbit_scurve_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    
    print (Colors.BLUE + "Plotting S-bit SCurves for all VFATs\n" + Colors.ENDC)
    logfile.write("Plotting S-bit SCurves for all VFATs\n\n")
    os.system("python3 plotting_scripts/vfat_analysis_scurve.py -c 0 -m current -f %s"%latest_file)
    latest_dir = latest_file.split(".txt")[0]
    if os.path.isdir(latest_dir):
        os.system("cp %s/scurve2Dhist_ME0_OH0.png %s/sbit_scurve_2D_hist.png"%(latest_dir, dataDir))
        os.system("cp %s/scurveENCdistribution_ME0_OH0.pdf %s/sbit_scurve_ENC.pdf"%(latest_dir, dataDir))
        os.system("cp %s/scurveThreshdistribution_ME0_OH0.pdf %s/sbit_scurve_Threshold.pdf"%(latest_dir, dataDir))
    else:
        print (Colors.RED + "S-bit Scurve result directory not found" + Colors.ENDC)
        logfile.write("S-bit SCurve result directory not found\n")    
    
    print (Colors.GREEN + "\nStep 9: S-bit SCurve Complete\n" + Colors.ENDC)
    logfile.write("\nStep 9: S-bit SCurve Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Power off
    os.system("python3 me0_lpgbt/powercycle_test_ucla/set_relay.py -r 7 -s off")
    time.sleep(10)

    logfile.close()
    os.system("rm -rf out.txt")






