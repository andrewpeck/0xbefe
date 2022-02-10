import sys, os, glob
import time
import argparse
from gem.me0_lpgbt.rw_reg_lpgbt import *

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Testing Step 1 - Initialize, Configure and Optical Tests")
    parser.add_argument("-s1", "--slot1", action="store", dest="slot1", help="slot1 = OH serial number on slot 1")
    parser.add_argument("-s2", "--slot2", action="store", dest="slot2", help="slot2 = OH serial number on slot 2")
    args = parser.parse_args()

    resultDir = "results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    me0Dir = "results/OH_slot1_%s_slot2_%s"%(args.s1, args.s2)
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
    
    # Step 1 - run init_frontend
    print ("Initializing")
    logfile.write("Initializing\n")
    os.system("python ../../init_frontend.py")
    print (Colors.GREEN + "Initialization Complete\n" + Colors.ENDC)
    logfile.write("Initialization Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 2 - check lpGBT status
    print ("Checking lpGBT Status")
    logfile.write("Checking lpGBT Status\n")
    os.system("python3 me0_lpgbt_status.py -s backend -q ME0 -o 0 -g 0 > out.txt")
    list_of_files = glob.glob("../../results/me0_lpgbt_data/lpgbt_status_data/status_boss*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/status_boss_slot1.txt"%(latest_file, dataDir))
    os.system("python3 me0_lpgbt_status.py -s backend -q ME0 -o 0 -g 1 > out.txt")
    list_of_files = glob.glob("../../results/me0_lpgbt_data/lpgbt_status_data/status_sub*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/status_sub_slot1.txt"%(latest_file, dataDir))
    
    os.system("python3 me0_lpgbt_status.py -s backend -q ME0 -o 0 -g 2 > out.txt")
    list_of_files = glob.glob("../../results/me0_lpgbt_data/lpgbt_status_data/status_boss*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/status_boss_slot2.txt"%(latest_file, dataDir))
    os.system("python3 me0_lpgbt_status.py -s backend -q ME0 -o 0 -g 3 > out.txt")
    list_of_files = glob.glob("../../results/me0_lpgbt_data/lpgbt_status_data/status_sub*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cp %s %s/status_sub_slot2.txt"%(latest_file, dataDir))
      
    config_boss_slot1_file = open("../../../resources/me0_boss_config_ohv%d"%oh_ver_slot1) 
    config_sub_slot1_file = open("../../../resources/me0_sub_config_ohv%d"%oh_ver_slot1)
    config_boss_slot2_file = open("../../../resources/me0_boss_config_ohv%d"%oh_ver_slot2) 
    config_sub_slot2_file = open("../../../resources/me0_sub_config_ohv%d"%oh_ver_slot2) 
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
        
    for line in config_boss_slot1_file.readlines():
        print ("Checking Slot 1 OH Boss lpGBT:")
        logfile.write("Checking Slot 1 OH Boss lpGBT:\n")
        if status_boss_slot1_registers[int(line.split()[0],16] != int(line.split()[1],16):
            print (Colors.YELLOW + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(int(line.split()[0],16, int(line.split()[1],16), status_boss_slot1_registers[int(line.split()[0],16]) + Colors.ENDC)
            logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(int(line.split()[0],16, int(line.split()[1],16), status_boss_slot1_registers[int(line.split()[0],16]))
    
    for line in config_sub_slot1_file.readlines():
        print ("Checking Slot 1 OH Sub lpGBT:")
        logfile.write("Checking Slot 1 OH Sub lpGBT:\n")
        if status_sub_slot1_registers[int(line.split()[0],16] != int(line.split()[1],16):
            print (Colors.YELLOW + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(int(line.split()[0],16, int(line.split()[1],16), status_sub_slot1_registers[int(line.split()[0],16]) + Colors.ENDC)
            logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(int(line.split()[0],16, int(line.split()[1],16), status_sub_slot1_registers[int(line.split()[0],16]))
            
    for line in config_boss_slot2_file.readlines():
        print ("Checking Slot 2 OH Boss lpGBT:")
        logfile.write("Checking Slot 2 OH Boss lpGBT:\n")
        if status_boss_slot2_registers[int(line.split()[0],16] != int(line.split()[1],16):
            print (Colors.YELLOW + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(int(line.split()[0],16, int(line.split()[1],16), status_boss_slot2_registers[int(line.split()[0],16]) + Colors.ENDC)
            logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(int(line.split()[0],16, int(line.split()[1],16), status_boss_slot2_registers[int(line.split()[0],16]))
    
    for line in config_sub_slot2_file.readlines():
        print ("Checking Slot 2 OH Sub lpGBT:")
        logfile.write("Checking Slot 2 OH Sub lpGBT:\n")
        if status_sub_slot2_registers[int(line.split()[0],16] != int(line.split()[1],16):
            print (Colors.YELLOW + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(int(line.split()[0],16, int(line.split()[1],16), status_sub_slot2_registers[int(line.split()[0],16]) + Colors.ENDC)
            logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(int(line.split()[0],16, int(line.split()[1],16), status_sub_slot2_registers[int(line.split()[0],16]))
   
    print (Colors.GREEN + "\nChecking lpGBT Status Complete\n" + Colors.ENDC)
    logfile.write("\nChecking lpGBT Status Complete\n\n")
    config_boss_slot1_file.close()
    config_sub_slot1_file.close()
    config_boss_slot2_file.close()
    config_sub_slot2_file.close()
    status_boss_slot1_file.close()
    status_sub_slot1_file.close()
    status_boss_slot2_file.close()
    status_sub_slot2_file.close()
    
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
   
    # Step 3 - Downlink eye diagrams
    
    
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 4 - Downlink Optical BERT
    
    
    
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 5 - Uplink Optical BERT


    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    logfile.close()
    os.system("rm -rf out.txt")






