import paramiko
from time import time, sleep
import argparse
import os, sys, glob, csv, json
import numpy as np
from common.utils import get_befe_scripts_dir, Colors
from queso_initialization import queso_oh_map, pi_list
import datetime

scripts_gem_dir = get_befe_scripts_dir() + '/gem'
queso_dir = scripts_gem_dir + "/me0_lpgbt/queso_testing"
resultDir = queso_dir + '/results'
input_fn = queso_dir + '/resources/input_queso.txt'

# Map vfat number to 
fpga_vfat_map = {
    # vfat (geb) -> {fpga_id,vfat_id(fpga)}
    # OH 1
    0 :  {'fpga_id': 1, 'vfat_id': 0}, # Placeholder values, need to look at schematic
    1 :  {'fpga_id': 1, 'vfat_id': 1},
    8 :  {'fpga_id': 2, 'vfat_id': 0},
    9 :  {'fpga_id': 2, 'vfat_id': 1},
    16 : {'fpga_id': 3, 'vfat_id': 0},
    17 : {'fpga_id': 3, 'vfat_id': 1},
    # OH 2
    2 :  {'fpga_id': 1, 'vfat_id': 0}, # Placeholder values, need to look at schematic
    3 :  {'fpga_id': 1, 'vfat_id': 1},
    10 : {'fpga_id': 2, 'vfat_id': 0},
    11 : {'fpga_id': 2, 'vfat_id': 1},
    18 : {'fpga_id': 3, 'vfat_id': 0},
    19 : {'fpga_id': 3, 'vfat_id': 1},
    # OH 3
    4 :  {'fpga_id': 1, 'vfat_id': 0}, # Placeholder values, need to look at schematic
    5 :  {'fpga_id': 1, 'vfat_id': 1},
    12 : {'fpga_id': 2, 'vfat_id': 0},
    13 : {'fpga_id': 2, 'vfat_id': 1},
    20 : {'fpga_id': 3, 'vfat_id': 0},
    21 : {'fpga_id': 3, 'vfat_id': 1},
    # OH 4
    6 :  {'fpga_id': 1, 'vfat_id': 0}, # Placeholder values, need to look at schematic
    7 :  {'fpga_id': 1, 'vfat_id': 1},
    14 : {'fpga_id': 2, 'vfat_id': 0},
    15 : {'fpga_id': 2, 'vfat_id': 1},
    22 : {'fpga_id': 3, 'vfat_id': 0},
    23 : {'fpga_id': 3, 'vfat_id': 1}
}

def ssh_channel_en(fpga,loopback=True,en_all=True,vfat=None,channel=None):
    command = 'queso_channel_en.py'
    # fpga arg
    if type(fpga) is list:
        command += f" -f {' '.join(fpga)}"
    else:
        command += f" -f {fpga}"
    # loopback arg
    if loopback:
        command += ' -l'
    # vfat arg
    if type(vfat) is list:
        command += f" -v {' '.join(vfat)}"
    else:
        command += f" -v {vfat}"
    # channel arg
    if en_all:
        channel = 'all'
    if channel:
        command += f" -c {channel}"
    
    global ssh,base_ssh_command
    cur_ssh_command = base_ssh_command + command
    ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
    stderr_output = ssh_stderr.readlines()
    if stderr_output:
        for line in stderr_output:
            print(Colors.RED + line + Colors.ENDC)
        ssh.close()
        sys.exit()
    output = ssh_stdout.readlines()
    for line in output:
        print(line)

if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="Queso crosstalk test procedure")
    parser.add_argument('-l','--loopback', action='store_true', dest='loopback', help='loopback = Enable loopback for channels during crosstalk test, instead of sending only 1\'s')
    parser.add_argument('-p','--check_prbs', action='store_true', dest='check_prbs', help='check_prbs = Check PRBS errors in backend if loopback is enabled. Good for checking for dead channels.')
    args = parser.parse_args()

    # automatically find input file
    oh_gbt_vfat_map = {}
    queso_dict = {}

    input_file = open(input_fn)
    for line in input_file.readlines():
        if "#" in line:
            if "TEST_TYPE" in line:
                batch = line.split()[2]
                if batch not in ["prototype", "pre_production", "pre_series", "production", "long_production"]:
                    print(Colors.YELLOW + 'Valid test batch codes are "prototype", "pre_production", "pre_series", "production" or "long_production"' + Colors.ENDC)
                    sys.exit()
            continue
        queso_nr = line.split()[0]
        oh_sn = line.split()[1]
        if oh_sn != "-9999":
            if batch == "pre_production" and int(oh_sn) not in range(1, 1001):
                print(Colors.YELLOW + "Valid OH serial number between 1 and 1000" + Colors.ENDC)
                sys.exit()
            elif batch == 'pre_series' and int(oh_sn) not in range(1001, 1025):
                print(Colors.YELLOW + "Valid pre-series OH serial number between 1001 and 1024" + Colors.ENDC)
                sys.exit()
            elif batch in ['production', 'acceptance', 'debug'] and int(oh_sn) not in range(1025, 2019):
                print(Colors.YELLOW + "Valid OH serial number between 1025 and 2018" + Colors.ENDC)
                sys.exit()
            queso_dict[queso_nr] = oh_sn
    input_file.close()
    if not queso_dict:
        print(Colors.YELLOW + "At least 1 QUESO need to have valid OH serial number" + Colors.ENDC)
        sys.exit()
    print()

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
    
    # Backend counter nodes
    # --------------------------
    # placeholder
    # --------------------------
    
    # Set up ssh
    username = "pi"
    password = "queso"
    ssh = paramiko.SSHClient()
    # Load SSH host keys
    ssh.load_system_host_keys()
    # Add SSH host key automatically if needed
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    base_ssh_command = "cd Documents/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 me0_lpgbt/queso_testing/"

    # Disable all elinks
    for queso,oh_sn in queso_dict.items():
        # Connect to each RPi using username/password authentication
        if queso in pi_list:
            pi_ip = pi_list[queso]
        else:
            print(Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
            continue
        ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)

        ssh_channel_en([1,2,3],loopback=args.loopback)

    # Enable 1 elink at a time
    for queso,oh_sn in queso_dict.items():
        # Connect to each RPi using username/password authentication
        if queso in pi_list:
            pi_ip = pi_list[queso]
        else:
            print(Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
            continue
        ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)

        for vfat in queso_oh_map[queso]['VFAT']:
            fpga = fpga_vfat_map[vfat]['fpga_id']
            vfat_id = fpga_vfat_map[vfat]['vfat_id']
            for elink in range(9):
                ssh_channel_en(
                    fpga,
                    loopback=args.loopback,
                    en_all=False,
                    vfat=vfat_id,
                    channel=elink
                )

                # Check backend counter

        ssh.close()

