import paramiko
from time import time, sleep
import argparse
import os, sys
from common.rw_reg import *

class Colors:
    WHITE   = "\033[97m"
    CYAN    = "\033[96m"
    MAGENTA = "\033[95m"
    BLUE    = "\033[94m"
    YELLOW  = "\033[93m"
    GREEN   = "\033[92m"
    RED     = "\033[91m"
    ENDC    = "\033[0m"

if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="Queso initialization procedure")
    parser.add_argument("-q", "--queso_list", dest="queso_list", help="queso_list = list of QUESOs to initialize or turn off")
    parser.add_argument("-r", "--reset", action="store_true", dest="reset", help="reset = reset all fpga")
    parser.add_argument("-o", "--turn_off", action="store_true", dest="turn_off", help="turn_off = turn regulator off")
    args = parser.parse_args()

    if not args.turn_off:
        print(Colors.BLUE + "Initializting QUESOs: " + Colors.ENDC)
    else:
        print(Colors.BLUE + "Turning OFF QUESOs: " + Colors.ENDC)
    for queso in args.queso_list:
        queso = int(queso)
        if queso not in range(0,8):
            print (Colors.YELLOW + "Invalid QUESO serial number, only allowed (0-7)" + Colors.ENDC)
            sys.exit()
        print("  QUESO: %s"%queso)
    print("")

    # List of QUESO Pi's
    pi_list = {}
    pi_list["0"] =  "169.254.119.34"
    pi_list["1"] =  "169.254.181.119"
    username = "pi"
    password = "queso"
    ssh = paramiko.SSHClient()

    # QUESO to OH mapping
    queso_oh_map = {}
    queso_oh_map["0"] = 0
    queso_oh_map["1"] = 0

    # OH, GBT, VFAT list overall
    oh_gbt_vfat_map = {}
    oh_gbt_vfat_map[0] = {}
    oh_gbt_vfat_map[0]["GBT"] = [0, 1]
    oh_gbt_vfat_map[0]["VFAT"] = [0, 1, 8, 9, 16, 17]
    oh_gbt_vfat_map[1] = {}
    oh_gbt_vfat_map[1]["GBT"] = [2, 3]
    oh_gbt_vfat_map[1]["VFAT"] = [2, 3, 10, 11, 18, 19]

    # Load SSH host keys
    ssh.load_system_host_keys()
    # Add SSH host key automatically if needed
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    base_ssh_command = "cd Documents/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 me0_lpgbt/queso_testing/"

    print ("\n#####################################################################################################################################\n")

    for queso in args.queso_list:
        print(Colors.BLUE + "Starting QUESO %s\n"%queso + Colors.ENDC)
        # Connect to each RPi using username/password authentication
        if queso in pi_list:
            pi_ip = pi_list[queso]
        else:
            print (Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
            continue
        ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)
        print ("\n######################################################\n")

        # Initialize RPI GPIOs
        if not args.turn_off:
            print(Colors.BLUE + "Initialize RPI GPIOs\n" + Colors.ENDC)
            cur_ssh_command = base_ssh_command + "queso_init_gpio.py"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            print(output)
            print(Colors.GREEN + "\nRPI GPIO Initialization Done" + Colors.ENDC)
            print ("\n######################################################\n")
            sleep(5)

        # Reset all FPGA if needed
        if args.reset:
            print(Colors.BLUE + "Reset FPGAs\n" + Colors.ENDC)
            cur_ssh_command = base_ssh_command + "queso_reset_fpga.py -f 1 2 3"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            print(output)
            print(Colors.GREEN + "\nReset Done" + Colors.ENDC)
            print ("\n######################################################\n")
            sleep(5)

        # Check FPGA done
        if not args.turn_off:
            print(Colors.BLUE + "Checking if FPGA programming done\n" + Colors.ENDC)
            cur_ssh_command = base_ssh_command + "queso_check_fpga_done.py -f 1 2 3"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            print(output)
            print(Colors.GREEN + "\nCheck FPGA Done" + Colors.ENDC)
            print ("\n######################################################\n")
            sleep(1)

        # Write FPGA ID
        if not args.turn_off:
            print(Colors.BLUE + "Writing FPGA ID\n" + Colors.ENDC)
            cur_ssh_command = base_ssh_command + "queso_write_fpga_id.py -f 1 2 3 -i 0x00 0x01 0x02"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            print(output)
            print(Colors.GREEN + "\nWriting FPGA ID Done" + Colors.ENDC)
            print ("\n######################################################\n")
            sleep(1)

        # Read currents before OH powered on
        if not args.turn_off:
            print (Colors.BLUE + "Reading Currents before OH powered on" + Colors.ENDC)
            cur_ssh_command = base_ssh_command + "queso_current_monitor.py -t 2"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            print(output)
            print (Colors.GREEN + "\nReading Currents done" + Colors.ENDC)
            print ("\n######################################################\n")
            sleep(2)

        # Enabling/Disabling regulators
        if not args.turn_off:
            print(Colors.BLUE + "Enabling regulators\n" + Colors.ENDC)
            cur_ssh_command = base_ssh_command + "queso_enable_regulator.py -r 1v2 2v5"
        else:
            print(Colors.BLUE + "Disabling regulators\n" + Colors.ENDC)
            cur_ssh_command = base_ssh_command + "queso_enable_regulator.py -r 1v2 2v5 -o"
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
        output = ssh_stdout.readlines()
        print(output)
        if not args.turn_off:
            print(Colors.GREEN + "\nRegulators Enabled" + Colors.ENDC)
        else:
            print(Colors.GREEN + "\nRegulators Disabled" + Colors.ENDC)
        print ("\n######################################################\n")
        sleep(10)

        # Terminate RPI GPIOs
        if args.turn_off:
            print(Colors.BLUE + "Terminate RPI GPIOs\n" + Colors.ENDC)
            cur_ssh_command = base_ssh_command + "queso_init_gpio.py -o"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            print(output)
            print(Colors.GREEN + "\RPI GPIO Terminate Done" + Colors.ENDC)
            print ("\n######################################################\n")
            sleep(5)

        print(Colors.BLUE + "QUESO %s Done\n"%queso + Colors.ENDC)
        print ("\n#####################################################################################################################################\n")
        ssh.close()
    
    print ("")
    if args.turn_off:
        sys.exit()

    # Initialize frontend
    print(Colors.BLUE + "Initialization\n" + Colors.ENDC)
    os.system("python3 init_frontend.py")
    print(Colors.GREEN + "\nInitialization Done" + Colors.ENDC)
    print ("\n######################################################\n")
    sleep(2)

    # Invert Elinks in OH
    print(Colors.BLUE + "Invert Elinks in OH\n" + Colors.ENDC)
    for ohid in oh_gbt_vfat_map:
        gbtid_list = oh_gbt_vfat_map[ohid]["GBT"]
        for gbtid in gbtid_list:
            os.system("python3 me0_lpgbt/queso_testing/queso_oh_link_invert.py -s backend -q ME0 -o %d -g %d"%(ohid, gbtid))
    print(Colors.GREEN + "\nInvert Elinks Done" + Colors.ENDC)
    print ("\n######################################################\n")
    sleep(2)

    # Set elink phases for QUESO
    print(Colors.BLUE + "Set Elink Phases and Bitslips\n" + Colors.ENDC)
    for ohid in oh_gbt_vfat_map:
        vfat_list = oh_gbt_vfat_map[ohid]["VFAT"]
        vfat_list_str = ' '.join(str(v) for v in vfat_list)
        os.system("python3 me0_lpgbt/queso_testing/queso_elink_phase_bitslip_scan.py -s backend -q ME0 -o %d -v %s"%(ohid, vfat_list_str))
    sleep(2)
    print(Colors.GREEN + "\nSetting Elink Phases and Bitslips Done" + Colors.ENDC)
    print ("\n######################################################\n")
    sleep(2)

    print ("")
    for queso in args.queso_list:
        print(Colors.BLUE + "Connecting again to QUESO %s\n"%queso + Colors.ENDC)
        # Connect to each RPi using username/password authentication
        if queso in pi_list:
            pi_ip = pi_list[queso]
        else:
            print (Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
            continue
        ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)
        print ("\n######################################################\n")

        # Read currents after OH initialization
        if not args.turn_off:
            print (Colors.BLUE + "Reading Currents after OH Initialization" + Colors.ENDC)
            cur_ssh_command = base_ssh_command + "queso_current_monitor.py -t 2"
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
            output = ssh_stdout.readlines()
            print(output)
            print (Colors.GREEN + "\nReading Currents done" + Colors.ENDC)
            print ("\n######################################################\n")
            sleep(2)

        print(Colors.BLUE + "QUESO %s Done\n"%queso + Colors.ENDC)
        print ("\n#####################################################################################################################################\n")
        ssh.close()
