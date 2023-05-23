from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse
import math
import json
import paramiko
from gem.me0_lpgbt.queso_testing.queso_initialization import queso_oh_map, pi_list

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="QUESO EFuse")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = queso or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-i", "--input_file", action="store", dest="input_file", help="INPUT_FILE = input file containing OH serial numers for QUESOs")
    parser.add_argument("-u", "--userid_file", action="store", dest="userid_file", help="USERID_FILE = file containing list of USER_ID for OH Serial Numbers")
    args = parser.parse_args()

    if args.system == "queso":
        print ("Using QUESO for fusing")
    elif args.system == "dryrun":
        print ("Dry Run - not actually fusing")
    else:
        print (Colors.YELLOW + "Only valid options: queso, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem != "ME0":
        print(Colors.YELLOW + "Valid gem station: ME0" + Colors.ENDC)
        sys.exit()

    if args.input_file is None:
        print(Colors.YELLOW + "Need Input File" + Colors.ENDC)
        sys.exit()
    if args.userid_file is None:
        print(Colors.YELLOW + "Need User ID File" + Colors.ENDC)
        sys.exit()

    queso_list = {}
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
            queso_list[queso_nr] = oh_serial_nr
    input_file.close()
    if len(queso_list) == 0:
        print(Colors.YELLOW + "At least 1 QUESO need to have valid OH serial number" + Colors.ENDC)
        sys.exit() 

    oh_user_id = {}
    userid_file = open(args.userid_file)
    for line in userid_file.readlines():
        if "#" in line:
            continue
        oh_serial_nr = line.split()[0]
        main_user_id = line.split()[1]
        secondary_user_id = line.split()[2]
        oh_user_id[oh_serial_nr]["main"] = main_user_id
        oh_user_id[oh_serial_nr]["secondary"] = secondary_user_id
    userid_file.close()
    
    username = "pi"
    password = "queso"
    ssh = paramiko.SSHClient()

    # Load SSH host keys
    ssh.load_system_host_keys()
    # Add SSH host key automatically if needed
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    base_ssh_command = "cd Documents/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 "

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

        # Run EFuse script
        oh_serial_nr = queso_list[queso]
        main_user_id = oh_user_id[oh_serial_nr]["main"]
        secondary_user_id = oh_user_id[oh_serial_nr]["secondary"]
        oh_id = queso_oh_map[queso]["OH"]
        gbt_main_id = queso_oh_map[queso]["GBT"][0]
        gbt_secondary_id = queso_oh_map[queso]["GBT"][1]

        print(Colors.BLUE + "Fusing Main lpGBT for OH Serial Number: %s\n"%(oh_serial_nr) + Colors.ENDC)
        cur_ssh_command = base_ssh_command + "me0_lpgbt_efuse.py -s %s -q %s -o %d -g %d -f user_id -u %s"%(args.system, args.gem, oh_id, gbt_main_id, main_user_id)
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
        output = ssh_stdout.readlines()
        for line in output:
            print (line)
        print(Colors.GREEN + "\nFusing Main lpGBT for OH Serial Number: %s Done\n"%(oh_serial_nr) + Colors.ENDC)
        print ("\n######################################################\n")
        sleep(5)

        print(Colors.BLUE + "Fusing Secondary lpGBT for OH Serial Number: %s\n"%(oh_serial_nr) + Colors.ENDC)
        cur_ssh_command = base_ssh_command + "me0_lpgbt_efuse.py -s %s -q %s -o %d -g %d -f user_id -u %s"%(args.system, args.gem, oh_id, gbt_secondary_id, secondary_user_id)
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
        output = ssh_stdout.readlines()
        for line in output:
            print (line)
        print(Colors.GREEN + "\nFusing Secondary lpGBT for OH Serial Number: %s Done\n"%(oh_serial_nr) + Colors.ENDC)
        print ("\n######################################################\n")
        sleep(5)

        print(Colors.BLUE + "QUESO %s Done\n"%queso + Colors.ENDC)
        print ("\n#####################################################################################################################################\n")
        ssh.close()
