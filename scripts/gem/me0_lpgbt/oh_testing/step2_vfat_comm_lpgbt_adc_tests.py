import sys, os, glob
import time
import argparse
from gem.me0_lpgbt.rw_reg_lpgbt import *

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Testing Step 2 - VFAT Communication and lpGBT ADC Measurement Tests")
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
    dataDir = me0Dir+"/step2_vfat_comm_lpgbt_adc_tests"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    filename = dataDir + "/step_2_log.txt"
    logfile = open(filename, "w")
    
    oh_ver_slot1 = get_oh_ver("0", "0")
    oh_ver_slot2 = get_oh_ver("0", "2")
    
    print ("\n#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 1 - Slow Control Error Rate Test
    print (Colors.BLUE + "Step 1: Slow Control Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 1: Slow Control Error Rate Test\n\n")
    
    os.system("python3 vfat_slow_control_test.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -r TEST_REG -t 30")
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
    
    print (Colors.GREEN + "\nStep 1: Slow Control Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 1: Slow Control Error Rate Test Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 2 - DAQ Error Rate Test
    print (Colors.BLUE + "Step 2: DAQ Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 2: DAQ Error Rate Test\n\n")
    
    os.system("python3 vfat_daq_test.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -t 30")
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
    
    print (Colors.GREEN + "\nStep 2: DAQ Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 2: DAQ Error Rate Test Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 3 - S-bit Error Rate Test
    print (Colors.BLUE + "Step 3: S-bit Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 3: S-bit Error Rate Test\n\n")
    
    print (Colors.BLUE + "Running S-bit Error test for VFAT17 Elink7\n" + Colors.ENDC)
    logfile.write("Running S-bit Error test for VFAT17 Elink7\n\n")
    os.system("python3 me0_vfat_sbit_test.py -s backend -q ME0 -o 0 -v 17 -e 7 -t 1 -b 20 -l")
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
    os.system("python3 me0_vfat_sbit_test.py -s backend -q ME0 -o 0 -v 19 -e 7 -t 1 -b 20 -l")
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
    
    print (Colors.GREEN + "\nStep 3: S-bit Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 3: S-bit Error Rate Test Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 4 - DAC Scans
    print (Colors.BLUE + "Step 4: DAC Scans\n" + Colors.ENDC)
    logfile.write("Step 4: DAC Scans\n\n")
    
    print (Colors.BLUE + "\nRunning DAC Scans for all VFATs\n" + Colors.ENDC)
    logfile.write("\nRunning DAC Scans for all VFATs\n\n")
    os.system("python3 vfat_dac_scan.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -f ../resources/DAC_scan_reg_list.txt")
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
    
    print (Colors.GREEN + "\nStep 4: DAC Scans Complete\n" + Colors.ENDC)
    logfile.write("\nStep 4: DAC Scans Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 5 - ADC Measurements
    print (Colors.BLUE + "Step 5: ADC Measurements\n" + Colors.ENDC)
    logfile.write("Step 5: ADC Measurements\n\n")
    
    print (Colors.BLUE + "Configuring all VFATs\n" + Colors.ENDC)
    logfile.write("Configuring all VFATs\n\n")
    logfile.close()
    os.system("python3 vfat_config.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c 1 >> %s"%filename)    
    logfile = open(filename, "a")
    time.sleep(5)
    
    print (Colors.BLUE + "\nRunning ADC Calibration Scan\n" + Colors.ENDC)
    logfile.write("Running ADC Calibration Scan\n\n")
    os.system("python3 me0_lpgbt_adc_calibration_scan.py -s backend -q ME0 -o 0 -g 0")
    os.system("python3 me0_lpgbt_adc_calibration_scan.py -s backend -q ME0 -o 0 -g 1")
    os.system("python3 me0_lpgbt_adc_calibration_scan.py -s backend -q ME0 -o 0 -g 2")
    os.system("python3 me0_lpgbt_adc_calibration_scan.py -s backend -q ME0 -o 0 -g 3")
    list_of_files = glob.glob("results/me0_lpgbt_data/adc_calibration_data/*GBT0*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/adc_calib_slot1_boss.pdf"%(latest_file, dataDir))
    list_of_files = glob.glob("results/me0_lpgbt_data/adc_calibration_data/*GBT1*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/adc_calib_slot1_sub.pdf"%(latest_file, dataDir))
    list_of_files = glob.glob("results/me0_lpgbt_data/adc_calibration_data/*GBT2*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/adc_calib_slot2_boss.pdf"%(latest_file, dataDir))
    list_of_files = glob.glob("results/me0_lpgbt_data/adc_calibration_data/*GBT3*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/adc_calib_slot2_sub.pdf"%(latest_file, dataDir))
    time.sleep(5)
    
    print (Colors.BLUE + "\nRunning RSSI Scan\n" + Colors.ENDC)
    logfile.write("Running RSSI Scan\n\n")
    os.system("python3 me0_rssi_monitor.py -s backend -q ME0 -o 0 -g 1 -v 2.56 -m 5")
    os.system("python3 me0_rssi_monitor.py -s backend -q ME0 -o 0 -g 3 -v 2.56 -m 5")
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_vtrx+_rssi_data/*GBT1*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/rssi_slot1.pdf"%(latest_file, dataDir))
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_vtrx+_rssi_data/*GBT3*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/rssi_slot2.pdf"%(latest_file, dataDir))
    time.sleep(5)
    
    print (Colors.BLUE + "\nRunning GEB Current and Temperature Scan\n" + Colors.ENDC)
    logfile.write("Running GEB Current and Temperature Scan\n\n")
    os.system("python3 me0_asense_monitor.py -s backend -q ME0 -o 0 -g 0 -m 5")
    os.system("python3 me0_asense_monitor.py -s backend -q ME0 -o 0 -g 2 -m 5")
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_asense_data/*GBT0_pg_current*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/pg_current_slot1.pdf"%(latest_file, dataDir))
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_asense_data/*GBT0_rt_voltage*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/rt_voltage_slot1.pdf"%(latest_file, dataDir))
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_asense_data/*GBT2_pg_current*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/pg_current_slot2.pdf"%(latest_file, dataDir))
    list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_asense_data/*GBT2_rt_voltage*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/rt_voltage_slot2.pdf"%(latest_file, dataDir))
    time.sleep(5)
    
    print (Colors.BLUE + "\nRunning OH Temperature Scan\n" + Colors.ENDC)
    logfile.write("Running OH Temperature Scan\n\n")
    os.system("python3 me0_temp_monitor.py -s backend -q ME0 -o 0 -g 1 -t OH -m 5")
    os.system("python3 me0_temp_monitor.py -s backend -q ME0 -o 0 -g 3 -t OH -m 5")
    list_of_files = glob.glob("results/me0_lpgbt_data/temp_monitor_data/*GBT1_temp_OH*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/oh_temp_slot1.pdf"%(latest_file, dataDir))
    list_of_files = glob.glob("results/me0_lpgbt_data/temp_monitor_data/*GBT3_temp_OH*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/oh_temp_slot2.pdf"%(latest_file, dataDir))
    time.sleep(5)
    
    print (Colors.BLUE + "\nRunning VTRx+ Temperature Scan\n" + Colors.ENDC)
    logfile.write("Running VTRx+ Temperature Scan\n\n")
    os.system("python3 me0_temp_monitor.py -s backend -q ME0 -o 0 -g 1 -t VTRX -m 5")
    os.system("python3 me0_temp_monitor.py -s backend -q ME0 -o 0 -g 3 -t VTRX -m 5")
    list_of_files = glob.glob("results/me0_lpgbt_data/temp_monitor_data/*GBT1_temp_VTRX*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/vtrx+_temp_slot1.pdf"%(latest_file, dataDir))
    list_of_files = glob.glob("results/me0_lpgbt_data/temp_monitor_data/*GBT3_temp_VTRX*.pdf")
    if len(list_of_files)>0:
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system("cp %s %s/vtrx+_temp_slot2.pdf"%(latest_file, dataDir))
    time.sleep(5)
    
    print (Colors.BLUE + "\nUnconfiguring all VFATs\n" + Colors.ENDC)
    logfile.write("Unconfiguring all VFATs\n\n")
    logfile.close()
    os.system("python3 vfat_config.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c 0 >> %s"%filename)    
    logfile = open(filename, "a")
    
    print (Colors.GREEN + "\nStep 5: ADC Measurements Complete\n" + Colors.ENDC)
    logfile.write("\nStep 5: ADC Measurements Complete\n\n")
    time.sleep(5)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    logfile.close()
    os.system("rm -rf out.txt")






