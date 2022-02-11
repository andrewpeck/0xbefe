import sys, os, glob
import time
import argparse
from gem.me0_lpgbt.rw_reg_lpgbt import *

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Testing Step 2 - VFAT Communication Tests")
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
    dataDir = me0Dir+"/step2_vfat_communication_tests"
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

    # Step 1 - DAQ Phase Scan
    print (Colors.YELLOW + "Step 1: DAQ Phase Scan\n" + Colors.ENDC)
    logfile.write("Step 1: DAQ Phase Scan\n\n")
    logfile.close()
    
    os.system("python3 me0_phase_scan.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c >> %s"%filename)
    
    logfile = open(filename, "a")
    print (Colors.GREEN + "Step 1: DAQ Phase Scan Complete\n" + Colors.ENDC)
    logfile.write("Step 1: DAQ Phase Scan Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 2 - S-bit Phase Scan, Mapping, Cluster Mapping
    print (Colors.YELLOW + "Step 2: S-bit Phase Scan, Mapping, Cluster Mapping\n" + Colors.ENDC)
    logfile.write("Step 2: S-bit Phase Scan, Mapping, Cluster Mapping\n\n")
    

    print (Colors.GREEN + "\nStep 2: S-bit Phase Scan, Mapping, Cluster Mapping Complete\n" + Colors.ENDC)
    logfile.write("\nStep 2: S-bit Phase Scan, Mapping, Cluster Mapping Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
   
    # Step 3 - VFAT Reset
    print (Colors.YELLOW + "Step 3: VFAT Reset\n" + Colors.ENDC)
    logfile.write("Step 3: VFAT Reset\n\n")
    

    
    print (Colors.GREEN + "\nStep 3: VFAT Reset Complete\n" + Colors.ENDC)
    logfile.write("\nStep 3: VFAT Reset Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 4 - Slow Control Error Rate Test
    print (Colors.YELLOW + "Step 4: Slow Control Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 4: Slow Control Error Rate Test\n\n")
    
    
    
    print (Colors.GREEN + "\nStep 4: Slow Control Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 4: Slow Control Error Rate Test Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 5 - DAQ Error Rate Test
    print (Colors.YELLOW + "Step 5: DAQ Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 5: DAQ Error Rate Test\n\n")
    
    
    
    print (Colors.GREEN + "\nStep 5: DAQ Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 5: DAQ Error Rate Test Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 6 - S-bit Error Rate Test
    print (Colors.YELLOW + "Step 6: S-bit Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 6: S-bit Error Rate Test\n\n")
    
    
    
    print (Colors.GREEN + "\nStep 6: S-bit Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 6: S-bit Error Rate Test Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 7 - DAC Scans
    print (Colors.YELLOW + "Step 7: DAC Scans\n" + Colors.ENDC)
    logfile.write("Step 7: DAC Scans\n\n")
    
    
    
    print (Colors.GREEN + "\nStep 7: DAC Scans Complete\n" + Colors.ENDC)
    logfile.write("\nStep 7: DAC Scans Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    logfile.close()
    os.system("rm -rf out.txt")






