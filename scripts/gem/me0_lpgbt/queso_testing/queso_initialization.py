import paramiko
from time import time, sleep
import argparse
import os, sys, glob, csv, json
import numpy as np
from common.rw_reg import *
import datetime

class Colors:
    WHITE   = "\033[97m"
    CYAN    = "\033[96m"
    MAGENTA = "\033[95m"
    BLUE    = "\033[94m"
    YELLOW  = "\033[93m"
    GREEN   = "\033[92m"
    RED     = "\033[91m"
    ENDC    = "\033[0m"

# QUESO to OH mapping
queso_oh_map = {}
queso_oh_map["1"] = {}
queso_oh_map["1"]["OH"] = 0
queso_oh_map["1"]["GBT"] = [0, 1]
queso_oh_map["1"]["VFAT"] = [0, 1, 8, 9, 16, 17]
queso_oh_map["2"] = {}
queso_oh_map["2"]["OH"] = 0
queso_oh_map["2"]["GBT"] = [2, 3]
queso_oh_map["2"]["VFAT"] = [2, 3, 10, 11, 18, 19]
queso_oh_map["3"] = {}
queso_oh_map["3"]["OH"] = 0
queso_oh_map["3"]["GBT"] = [4, 5]
queso_oh_map["3"]["VFAT"] = [4, 5, 12, 13, 20, 21]
queso_oh_map["4"] = {}
queso_oh_map["4"]["OH"] = 0
queso_oh_map["4"]["GBT"] = [6, 7]
queso_oh_map["4"]["VFAT"] = [6, 7, 14, 15, 22, 23]
queso_oh_map["5"] = {}
queso_oh_map["5"]["OH"] = 1
queso_oh_map["5"]["GBT"] = [0, 1]
queso_oh_map["5"]["VFAT"] = [0, 1, 8, 9, 16, 17]
queso_oh_map["6"] = {}
queso_oh_map["6"]["OH"] = 1
queso_oh_map["6"]["GBT"] = [2, 3]
queso_oh_map["6"]["VFAT"] = [2, 3, 10, 11, 18, 19]
queso_oh_map["7"] = {}
queso_oh_map["7"]["OH"] = 1
queso_oh_map["7"]["GBT"] = [4, 5]
queso_oh_map["7"]["VFAT"] = [4, 5, 12, 13, 20, 21]
queso_oh_map["8"] = {}
queso_oh_map["8"]["OH"] = 1
queso_oh_map["8"]["GBT"] = [6, 7]
queso_oh_map["8"]["VFAT"] = [6, 7, 14, 15, 22, 23]

# List of QUESO Pi's
pi_list = {}
pi_list["1"] =  "169.254.119.34"
pi_list["2"] =  "169.254.181.119"
pi_list["3"] =  "169.254.118.3"
pi_list["4"] =  "169.254.66.95"
pi_list["5"] =  "169.254.122.125"
pi_list["6"] =  "169.254.200.178"
pi_list["7"] =  "169.254.8.226"
pi_list["8"] =  "169.254.57.247"

if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="Queso initialization procedure")
    #parser.add_argument("-q", "--queso_list", dest="queso_list", help="queso_list = list of QUESOs to initialize or turn off (1-8)")
    parser.add_argument("-i", "--input_file", action="store", dest="input_file", help="INPUT_FILE = input file containing OH serial numers for QUESOs")
    parser.add_argument("-r", "--reset", action="store_true", dest="reset", help="reset = reset all fpga")
    parser.add_argument("-o", "--turn_off", action="store_true", dest="turn_off", help="turn_off = turn regulator off")
    args = parser.parse_args()

    if args.input_file is None:
        print(Colors.YELLOW + "Need Input File" + Colors.ENDC)
        sys.exit()

    queso_dict = {}
    input_file = open(args.input_file)
    for line in input_file.readlines():
        if "#" in line:
            continue
        queso_nr = line.split()[0]
        oh_serial_nr = line.split()[1]
        if oh_serial_nr != "-9999":
            if int(oh_serial_nr) not in range(1, 1019):
                print(Colors.YELLOW + "Valid OH serial number between 1 and 1018" + Colors.ENDC)
                sys.exit() 
            queso_dict[queso_nr] = oh_serial_nr
    input_file.close()
    if len(queso_dict) == 0:
        print(Colors.YELLOW + "At least 1 QUESO need to have valid OH serial number" + Colors.ENDC)
        sys.exit()
    print("")

    resultDir = "me0_lpgbt/queso_testing/results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = "me0_lpgbt/queso_testing/results/bert_results"
    try:
        os.makedirs(dataDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    currMonDir = resultDir + "/current_monitor_results"

    oh_ser_nr_list = []
    for queso in queso_dict:
        oh_ser_nr_list.append(queso_dict[queso])
    OHDir = dataDir+"/OH_SNs_"+"_".join(oh_ser_nr_list)
    try:
        os.makedirs(OHDir) # create directory for OHs under test
    except FileExistsError: # skip if directory already exists
        pass  
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    log_fn = OHDir+"/queso_initialization_log.txt"
    logfile = open(log_fn, "w")
    results_fn = OHDir+"/queso_initialization_results.json"

    if not args.turn_off:
        print(Colors.BLUE + "Initializting QUESOs: " + Colors.ENDC)
        logfile.write("Initializting QUESOs: \n")
    else:
        print(Colors.BLUE + "Turning OFF QUESOs: " + Colors.ENDC)
        logfile.write("Turning OFF QUESOs: \n")
    for queso in queso_dict:
        print("  QUESO: %s"%queso)
        logfile.write("  QUESO: %s\n"%queso)

    username = "pi"
    password = "queso"
    ssh = paramiko.SSHClient()

    # OH, GBT, VFAT list overall
    oh_gbt_vfat_map = {}
    for queso in queso_dict:
        oh = queso_oh_map[queso]["OH"]
        if oh not in oh_gbt_vfat_map:
            oh_gbt_vfat_map[oh] = {}
            oh_gbt_vfat_map[oh]["GBT"] = []
            oh_gbt_vfat_map[oh]["VFAT"] = []
        oh_gbt_vfat_map[oh]["GBT"] += queso_oh_map[queso]["GBT"]
        oh_gbt_vfat_map[oh]["VFAT"] += queso_oh_map[queso]["VFAT"]
        oh_gbt_vfat_map[oh]["GBT"].sort()
        oh_gbt_vfat_map[oh]["VFAT"].sort()

    # Load SSH host keys
    ssh.load_system_host_keys()
    # Add SSH host key automatically if needed
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    base_ssh_command = "cd Documents/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 me0_lpgbt/queso_testing/"

    print("\n#####################################################################################################################################\n")
    logfile.write("\n#####################################################################################################################################\n\n")

    for queso in queso_dict:
        print(Colors.BLUE + "Starting QUESO %s\n"%queso + Colors.ENDC)
        logfile.write("Starting QUESO %s\n\n"%queso)
        # Connect to each RPi using username/password authentication
        if queso in pi_list:
            pi_ip = pi_list[queso]
        else:
            print(Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
            logfile.write("Pi IP not present for QUESO %s\n"%queso)
            continue
        ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)
        print("\n######################################################\n")
        logfile.write("\n######################################################\n\n")

        # Initialize RPI GPIOs
        if not args.turn_off:
            print(Colors.BLUE + "Initialize RPI GPIOs\n" + Colors.ENDC)
            logfile.write("Initialize RPI GPIOs\n\n")
            cur_ssh_command = base_ssh_command + "queso_init_gpio.py"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            for line in output:
                print(line)
                logfile.write(line+"\n")
            print(Colors.GREEN + "\nRPI GPIO Initialization Done" + Colors.ENDC)
            print("\n######################################################\n")
            logfile.write("\nRPI GPIO Initialization Done\n")
            logfile.write("\n######################################################\n\n")
            sleep(1)

        # Reset all FPGA if needed
        if args.reset:
            print(Colors.BLUE + "Reset FPGAs\n" + Colors.ENDC)
            logfile.write("Reset FPGAs\n\n")
            cur_ssh_command = base_ssh_command + "queso_reset_fpga.py -f 1 2 3"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            for line in output:
                print(line)
                logfile.write(line+"\n")
            print(Colors.GREEN + "\nReset Done" + Colors.ENDC)
            print("\n######################################################\n")
            logfile.write("\nReset Done\n")
            logfile.write("\n######################################################\n\n")
            sleep(1)

        # Check FPGA done
        if not args.turn_off:
            print(Colors.BLUE + "Checking if FPGA programming done\n" + Colors.ENDC)
            logfile.write("Checking if FPGA programming done\n\n")
            cur_ssh_command = base_ssh_command + "queso_check_fpga_done.py -f 1 2 3"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            for line in output:
                print(line)
                logfile.write(line+"\n")
            print(Colors.GREEN + "\nCheck FPGA Done" + Colors.ENDC)
            print("\n######################################################\n")
            logfile.write("\nCheck FPGA Done")
            logfile.write("\n######################################################\n\n")
            sleep(1)

        # Write FPGA ID
        if not args.turn_off:
            print(Colors.BLUE + "Writing FPGA ID\n" + Colors.ENDC)
            logfile.write("Writing FPGA ID\n\n")
            cur_ssh_command = base_ssh_command + "queso_write_fpga_id.py -f 1 2 3 -i 0x00 0x01 0x02"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            for line in output:
                print(line)
                logfile.write(line+"\n")
            print(Colors.GREEN + "\nWriting FPGA ID Done" + Colors.ENDC)
            print("\n######################################################\n")
            logfile.write("\nWriting FPGA ID Done\n")
            logfile.write("\n######################################################\n\n")
            sleep(1)

        # Read currents before OH powered on
        if not args.turn_off:
            print (Colors.BLUE + "Reading Currents before OH powered on" + Colors.ENDC)
            logfile.write("Reading Currents before OH powered on\n")
            cur_ssh_command = base_ssh_command + "queso_current_monitor.py -n 1"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            for line in output:
                print(line)
                logfile.write(line+"\n")
            print(Colors.GREEN + "\nReading Currents done" + Colors.ENDC)
            print("\n######################################################\n")
            logfile.write("\nReading Currents done\n")
            logfile.write("\n######################################################\n\n")
            sleep(1)

        # Enabling/Disabling regulators
        if not args.turn_off:
            print(Colors.BLUE + "Enabling regulators\n" + Colors.ENDC)
            logfile.write("Enabling regulators\n\n")
            cur_ssh_command = base_ssh_command + "queso_enable_regulator.py -r 1v2 2v5"
        else:
            print(Colors.BLUE + "Disabling regulators\n" + Colors.ENDC)
            logfile.write("Disabling regulators\n\n")
            cur_ssh_command = base_ssh_command + "queso_enable_regulator.py -r 1v2 2v5 -o"
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
        output = ssh_stdout.readlines()
        for line in output:
            print(line)
            logfile.write(line+"\n")
        if not args.turn_off:
            print(Colors.GREEN + "\nRegulators Enabled" + Colors.ENDC)
            logfile.write("\nRegulators Enabled\n")
        else:
            print(Colors.GREEN + "\nRegulators Disabled" + Colors.ENDC)
            logfile.write("\nRegulators Disabled\n")
        print("\n######################################################\n")
        logfile.write("\n######################################################\n\n")
        sleep(1)

        # Terminate RPI GPIOs
        if args.turn_off:
            print(Colors.BLUE + "Terminate RPI GPIOs\n" + Colors.ENDC)
            logfile.write("Terminate RPI GPIOs\n\n")
            cur_ssh_command = base_ssh_command + "queso_init_gpio.py -o"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            for line in output:
                print(line)
                logfile.write(line+"\n")
            print(Colors.GREEN + "\nRPI GPIO Terminate Done" + Colors.ENDC)
            print("\n######################################################\n")
            logfile.write("\nRPI GPIO Terminate Done\n")
            logfile.write("\n######################################################\n\n")
            sleep(1)

        print(Colors.BLUE + "QUESO %s Done\n"%queso + Colors.ENDC)
        print("\n#####################################################################################################################################\n")
        logfile.write("QUESO %s Done\n\n"%queso)
        logfile.write("\n#####################################################################################################################################\n\n")
        ssh.close()
    
    print("")
    logfile.write("\n")
    if args.turn_off:
        sys.exit()

    # Initialize frontend
    print(Colors.BLUE + "Initialization\n" + Colors.ENDC)
    logfile.write("Initialization\n\n")
    logfile.close()
    os.system("python3 init_frontend.py")
    os.system("python3 init_frontend.py >> %s"%log_fn)
    logfile = open(log_fn,"a")
    print(Colors.GREEN + "\nInitialization Done" + Colors.ENDC)
    print("\n######################################################\n")
    logfile.write("\nInitialization Done\n")
    logfile.write("\n######################################################\n\n")
    sleep(1)

    # Invert Elinks in OH
    print(Colors.BLUE + "Invert Elinks in OH\n" + Colors.ENDC)
    logfile.write("Invert Elinks in OH\n\n")
    logfile.close()
    for ohid in oh_gbt_vfat_map:
        gbtid_list = oh_gbt_vfat_map[ohid]["GBT"]
        for gbtid in gbtid_list:
            os.system("python3 me0_lpgbt/queso_testing/queso_oh_links_invert.py -s backend -q ME0 -o %d -g %d"%(ohid, gbtid))
            os.system("python3 me0_lpgbt/queso_testing/queso_oh_links_invert.py -s backend -q ME0 -o %d -g %d >> %s"%(ohid, gbtid,log_fn))
    logfile = open(log_fn,"a")
    print(Colors.GREEN + "\nInvert Elinks Done" + Colors.ENDC)
    print("\n######################################################\n")
    logfile.write("\nInvert Elinks Done\n")
    logfile.write("\n######################################################\n\n")
    sleep(2)

    # Set elink phases for QUESO
    print(Colors.BLUE + "Set Elink Phases and Bitslips\n" + Colors.ENDC)
    logfile.write("Set Elink Phases and Bitslips\n\n")
    logfile.close()
    for ohid in oh_gbt_vfat_map:
        vfat_list_str = ' '.join(str(v) for v in oh_gbt_vfat_map[ohid]["VFAT"])
        os.system("python3 me0_lpgbt/queso_testing/queso_elink_phase_bitslip_scan.py -s backend -q ME0 -o %d -v %s"%(ohid, vfat_list_str))
        os.system("python3 me0_lpgbt/queso_testing/queso_elink_phase_bitslip_scan.py -s backend -q ME0 -o %d -v %s >> %s"%(ohid, vfat_list_str,log_fn))
    logfile = open(log_fn,"a")
    print(Colors.GREEN + "\nSetting Elink Phases and Bitslips Done" + Colors.ENDC)
    print("\n######################################################\n")
    logfile.write("\nSetting Elink Phases and Bitslips Done\n")
    logfile.write("\n######################################################\n\n")
    sleep(2)

    print("")
    logfile.write("\n")
    for queso,oh_ser_nr in queso_dict.items():
        print(Colors.BLUE + "Connecting again to QUESO %s\n"%queso + Colors.ENDC)
        logfile.write("Connecting again to QUESO %s\n\n"%queso)
        # Connect to each RPi using username/password authentication
        if queso in pi_list:
            pi_ip = pi_list[queso]
        else:
            print(Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
            logfile.write("Pi IP not present for QUESO %s\n"%queso)
            continue
        ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)
        print("\n######################################################\n")
        logfile.write("\n######################################################\n\n")

        # Read currents after OH initialization
        resultDir + "/current_monitor_results"
        if not args.turn_off:
            print(Colors.BLUE + "Reading Currents after OH Initialization" + Colors.ENDC)
            logfile.write("Reading Currents after OH Initialization\n")
            cur_ssh_command = base_ssh_command + "queso_current_monitor.py -n 10"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            for line in output:
                print(line)
                logfile.write(line+"\n")
            print(Colors.GREEN + "\nReading Currents done" + Colors.ENDC)
            print("\n######################################################\n")
            logfile.write("\nReading Currents done\n")
            logfile.write("\n######################################################\n\n")
            sleep(1)
            # Get current monitor results
            list_of_files = glob.glob(currMonDir+"/ME0_QUESO_current_monitor_data_*.csv")
            latest_file = max(list_of_files, key=os.path.getctime)
            csvfile = csv.reader(latest_file)
            queso_current = {}
            for i,line in enumerate(csvfile):
                if not i:
                    keys = line
                    for key in keys:
                        queso_current[key]=[]
                else:
                    for key,current in zip(keys,line):
                        queso_current[key].append(current)
            queso_current_oh_sn = {}
            queso_current_oh_sn[oh_ser_nr]={}
            for key in keys[:2]:
                queso_current_oh_sn[oh_ser_nr][key]=np.mean(queso_current[key])
        

        print(Colors.BLUE + "QUESO %s Done\n"%queso + Colors.ENDC)
        print("\n#####################################################################################################################################\n")
        logfile.write("QUESO %s Done\n\n"%queso)
        logfile.write("\n#####################################################################################################################################\n\n")
        ssh.close()
    
    with open(results_fn, "w") as resultsfile:
        resultsfile.write(json.dumps(queso_current_oh_sn))
    logfile.close()
