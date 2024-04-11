from gem.gem_utils import *
from gem.me0_lpgbt.rw_reg_lpgbt import rw_initialize
from common.utils import get_befe_scripts_dir, Colors
from queso_initialization import queso_oh_map, pi_list

import paramiko
from time import time, sleep
import argparse
import os, sys, glob, csv, json
import numpy as np
from operator import itemgetter
import datetime

scripts_gem_dir = get_befe_scripts_dir() + '/gem'
queso_dir = scripts_gem_dir + "/me0_lpgbt/queso_testing"
results_dir = queso_dir + '/results'
input_fn = queso_dir + '/resources/input_queso.txt'

# Map vfat number to 
fpga_vfat_map = {
    # fpga -> vfat_id -> queso : vfat
    '1':{
        0:{'1':8,  '2':10, '3':4,  '4':6,  '5':8,  '6':10, '7':4,  '8':6},  # Boss
        1:{'1':16, '2':18, '3':20, '4':22, '5':16, '6':18, '7':20, '8':22}  # Sub
    },
    '2':{
        0:{'1':1, '2':3,  '3':5,  '4':7,  '5':1, '6':3,  '7':5,  '8':7},    # Boss
        1:{'1':9, '2':11, '3':13, '4':15, '5':9, '6':11, '7':13, '8':15}    # Sub
    },
    '3':{
        0:{'1':0,  '2':2,  '3':12, '4':14, '5':0,  '6':2,  '7':12, '8':14}, # Boss
        1:{'1':17, '2':19, '3':21, '4':23, '5':17, '6':19, '7':21, '8':23}  # Sub
    }
}

MAX_CNT = 255

def ssh_channel_en(fpga,loopback=True,en_all=True,vfat=None,channel=None,verbose=False):
    command = 'queso_channel_en.py'
    # fpga arg
    if type(fpga) is list:
        command += f" -f {' '.join(map(str,fpga))}"
    else:
        command += f" -f {fpga}"
    # loopback arg
    if loopback:
        command += ' -l'
    # vfat arg
    if vfat is not None:
        if type(vfat) is list:
            command += f" -v {' '.join(map(str,vfat))}"
        else:
            command += f" -v {vfat}"
    # channel arg
    if channel is not None:
        command += f" -c {channel}"
    elif en_all:
        command += f" -c all"
    global ssh,base_ssh_command
    cur_ssh_command = base_ssh_command + command
    ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(cur_ssh_command)
    stderr_output = ssh_stderr.readlines()
    if stderr_output:
        for line in stderr_output:
            print(Colors.RED + line + Colors.ENDC)
        ssh.close()
        sys.exit()
    if verbose:
        output = ssh_stdout.readlines()
        for line in output:
            print(line)

def read_backend_counters(queso,backend_counter_nodes):
    counters = {}
    for vfat in queso_oh_map[queso]['VFAT']:
        counters[vfat] = [0 for _ in range(9)]
        for elink in range(9):
            counters[vfat][elink] += read_backend_reg(backend_counter_nodes[queso][vfat][elink])
    return counters

def min_of_max_count(counters):
    return max([(q,v,counters[q][v].index(cnt),cnt) for q in counters for v in counters[q].keys() for cnt in counters[q][v]],key=itemgetter(-1))

if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="Queso crosstalk test procedure")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument('-l','--loopback', action='store_true', dest='loopback', help='loopback = Enable loopback for channels during crosstalk test, instead of sending only 1\'s')
    parser.add_argument('-p','--check_prbs', action='store_true', dest='check_prbs', help='check_prbs = Check PRBS errors in backend if loopback is enabled. Good for checking for dead channels.')
    parser.add_argument('-v','--verbose',action='store_true',dest='verbose',help='verbose = Enable for full crosstalk data and channel enable printouts.')
    # Channel controls/debug
    parser.add_argument('-e','--enable',action='store_true',dest='enable',help='enable = Enable all elinks with loopback ON.')
    parser.add_argument('-d','--disable',action='store_true',dest='disable',help='disable = Disable all elinks with loopback ON.')
    parser.add_argument('-c','--channel',action='store',dest='channel',help='channel = Channel to enable in all quesos. Index = 18*(fpga-1) + 9*vfat_id + elink.')
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for queso crosstalk")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running queso crosstalk")
    else:
        print (Colors.YELLOW + "Only valid options: backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem != "ME0":
        print(Colors.YELLOW + "Valid gem station: ME0" + Colors.ENDC)
        sys.exit()

    # Initialization 
    rw_initialize(args.gem, args.system)


    # automatically find input file
    oh_gbt_vfat_map = {}
    queso_dict = {}

    input_file = open(input_fn)
    for line in input_file.readlines():
        if "#" in line:
            # Don't need to check test type
            # --------------------------------------
            # if "TEST_TYPE" in line:
            #     test_type = line.split()[2]
            #     if test_type not in ["prototype", "pre_production", "pre_series", "production", "long_production"]:
            #         print(Colors.YELLOW + 'Valid test type codes are "prototype", "pre_production", "pre_series", "production" or "long_production"' + Colors.ENDC)
            #         sys.exit()
            continue
        queso_nr = line.split()[0]
        oh_sn = line.split()[1]
        if oh_sn != "-9999":
            # if test_type == "pre_production" and int(oh_sn) not in range(1, 1001):
            #     print(Colors.YELLOW + "Valid OH serial number between 1 and 1000" + Colors.ENDC)
            #     sys.exit()
            # elif test_type == 'pre_series' and int(oh_sn) not in range(1001, 1025):
            #     print(Colors.YELLOW + "Valid pre-series OH serial number between 1001 and 1024" + Colors.ENDC)
            #     sys.exit()
            # elif test_type in ['production', 'acceptance', 'debug'] and int(oh_sn) not in range(1025, 2019):
            #     print(Colors.YELLOW + "Valid OH serial number between 1025 and 2018" + Colors.ENDC)
            #     sys.exit()
            queso_dict[queso_nr] = oh_sn
    input_file.close()
    if not queso_dict:
        print(Colors.YELLOW + "At least 1 QUESO need to have valid OH serial number" + Colors.ENDC)
        sys.exit()
    print()

    # Counters and backend nodes
    if args.loopback or args.check_prbs:
        # Turn on prbs
        write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_EN"),1)
    queso_reset_node = get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_RESET") # reset counters

    queso_crosstalk_nodes = {}
    queso_crosstalk_data = {}
    if args.check_prbs:
        queso_prbs_nodes = {}
        prbs_err_data = {}
    for queso in queso_dict:
        oh_select = queso_oh_map[queso]['OH']
        queso_crosstalk_nodes[queso] = {}
        queso_crosstalk_data[queso] = {}
        if args.check_prbs:
            queso_prbs_nodes[queso] = {}
            prbs_err_data[queso] = {}
        for vfat in queso_oh_map[queso]['VFAT']:
            queso_crosstalk_nodes[queso][vfat] = {}
            queso_crosstalk_data[queso][vfat] = {}
            if args.check_prbs:
                prbs_err_data[queso][vfat] = [0 for _ in range(9)]
                queso_prbs_nodes[queso][vfat] = {}
            for elink in range(9):
                queso_crosstalk_nodes[queso][vfat][elink] = get_backend_node(f"BEFE.GEM.GEM_TESTS.QUESO_TEST.OH{oh_select}.VFAT{vfat}.ELINK{elink}.DATA_COUNT")
                if args.check_prbs:
                    queso_prbs_nodes[queso][vfat][elink] = get_backend_node(f"BEFE.GEM.GEM_TESTS.QUESO_TEST.OH{oh_select}.VFAT{vfat}.ELINK{elink}.PRBS_ERR_COUNT")

    # Set up ssh
    username = "pi"
    password = "queso"
    ssh = paramiko.SSHClient()
    # Load SSH host keys
    ssh.load_system_host_keys()
    # Add SSH host key automatically if needed
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    base_ssh_command = "cd Documents/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 me0_lpgbt/queso_testing/"
    
    if args.enable:
        # Enable all elinks
        print(Colors.BLUE + 'Enabling all elinks in all quesos, then exiting.\n' + Colors.ENDC)
        for queso in queso_dict:
            # Connect to each RPi using username/password authentication
            if queso in pi_list:
                pi_ip = pi_list[queso]
            else:
                print(Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
                continue
            ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)
            ssh_channel_en([1,2,3],vfat=[0,1],en_all=True,loopback=args.loopback,verbose=args.verbose)
            ssh.close()
        sys.exit()
    elif args.disable:
        # Disable all elinks
        print(Colors.BLUE + 'Disabling all elinks in all quesos with loopback ON, then exiting.\n' + Colors.ENDC)
        for queso in queso_dict:
            # Connect to each RPi using username/password authentication
            if queso in pi_list:
                pi_ip = pi_list[queso]
            else:
                print(Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
                continue
            ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)
            ssh_channel_en([1,2,3],en_all=True,loopback=True,verbose=args.verbose)
            ssh.close()
        sys.exit()

    elif args.channel is not None:
        # Enable 1 channel in all quesos
        try:
            channel = int(args.channel)
            if channel > 53 or channel < 0:
                print(Colors.RED + 'Valid input for channel are integers range 0 - 53. Index = 18*(fpga-1) + 9*vfat_id + elink.' + Colors.ENDC)
                sys.exit()
        except TypeError:
            print(Colors.RED + 'Valid input for channel are integers range 0 - 53. Index = 18*(fpga-1) + 9*vfat_id + elink.' + Colors.ENDC)
            sys.exit()
        elink   = channel % 9
        vfat_id = (channel // 9) % 2
        fpga    = (channel // 18) + 1

        print(Colors.BLUE + f'Enabling FPGA {fpga} VFAT_ID {vfat_id:02d} ELINK {elink} in all quesos, then exiting.\n' + Colors.ENDC)
        
        # Disable all elinks
        print(Colors.BLUE + 'Disabling all elinks in all quesos' + Colors.ENDC)
        for queso in queso_dict:
            # Connect to each RPi using username/password authentication
            if queso in pi_list:
                pi_ip = pi_list[queso]
            else:
                print(Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
                continue
            ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)
            ssh_channel_en([1,2,3],loopback=args.loopback,verbose=args.verbose)
            ssh.close()

        # Enable 1 elink in all quesos in parallel
        for queso in queso_dict:
            vfat = fpga_vfat_map[str(fpga)][vfat_id][queso]

            print(Colors.BLUE + f'Enabling VFAT {vfat:02d} ELINK {elink} (in QUESO {queso})' + Colors.ENDC)
            # Connect to RPi
            if queso in pi_list:
                pi_ip = pi_list[queso]
            else:
                print(Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
                continue
            ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)
            # Enable data on 1 elink
            ssh_channel_en(
                fpga,
                loopback=args.loopback,
                en_all=False,
                vfat=vfat_id,
                channel=elink,
                verbose=args.verbose
            )
            ssh.close()

        sys.exit()

    # Disable all elinks
    print(Colors.BLUE + 'Disabling all elinks in all quesos\n' + Colors.ENDC)
    for queso in queso_dict:
        # Connect to each RPi using username/password authentication
        if queso in pi_list:
            pi_ip = pi_list[queso]
        else:
            print(Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
            continue
        ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)
        ssh_channel_en([1,2,3],loopback=args.loopback,verbose=args.verbose)
        ssh.close()
    
    # Reset counters
    write_backend_reg(queso_reset_node, 1)
    sleep(0.1)

    # Enable 1 elink at a time
    for fpga in fpga_vfat_map:
        for vfat_id in fpga_vfat_map[fpga]:
            for elink_inj in range(9):
                # Enable 1 elink in all quesos in parallel
                for queso in queso_dict:
                    vfat = fpga_vfat_map[fpga][vfat_id][queso]

                    print(Colors.BLUE + f'Enabling VFAT {vfat:02d} ELINK {elink_inj} (in QUESO {queso})' + Colors.ENDC)
                    # Connect to RPi
                    if queso in pi_list:
                        pi_ip = pi_list[queso]
                    else:
                        print(Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
                        continue
                    ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)
                    # Enable data on 1 elink
                    ssh_channel_en(
                        fpga,
                        loopback=args.loopback,
                        en_all=False,
                        vfat=vfat_id,
                        channel=elink_inj,
                        verbose=args.verbose
                    )
                    ssh.close()

                # Reset counters
                sleep(0.1)
                write_backend_reg(queso_reset_node, 1)
                sleep(0.1)

                # Check backend counters
                print(Colors.BLUE + 'Reading cross talk counters' + Colors.ENDC)
                elink_data_counters = {}
                if args.check_prbs:
                    print(Colors.BLUE + 'Reading PRBS counters' + Colors.ENDC)
                    prbs_counters = {}
                print()
                for queso in queso_dict:
                    elink_data_counters[queso] = read_backend_counters(queso,queso_crosstalk_nodes)
                    if args.check_prbs:
                        prbs_counters[queso] = read_backend_counters(queso,queso_prbs_nodes)
                # Wait for counter to max out
                min_queso,min_vfat,min_elink,min_max_cnt = min_of_max_count(elink_data_counters)
                while min_max_cnt < MAX_CNT:
                    sleep(0.1)
                    # Check backend counters
                    elink_data_counters[min_queso] = read_backend_counters(min_queso,queso_crosstalk_nodes)
                    min_queso,min_vfat,min_elink,min_max_cnt = min_of_max_count(elink_data_counters)
                    if min_max_cnt == 0:
                        print(Colors.RED + "No data found on any elinks\n" + Colors.ENDC)
                        break
                # Get final cnt values
                for queso in queso_dict:
                    elink_data_counters[queso] = read_backend_counters(queso,queso_crosstalk_nodes)


                if args.verbose:
                    print('Data counters:')
                    for queso in elink_data_counters:
                        print(f'QUESO {queso}:')
                        for vfat in elink_data_counters[queso]:
                            print(f'  VFAT {vfat}:')
                            for elink_read,val in enumerate(elink_data_counters[queso][vfat]):
                                print(f'    ELINK {elink_read}: {val}')
                    print()

                # Save for later analysis
                for queso in queso_dict:
                    vfat = fpga_vfat_map[fpga][vfat_id][queso]
                    # Save data per queso
                    queso_crosstalk_data[queso][vfat][elink_inj] = elink_data_counters[queso]
                    if args.check_prbs:
                        # Only check relevant elink
                        prbs_err_data[queso][vfat][elink_inj] += read_backend_reg(queso_prbs_nodes[queso][vfat][elink_inj])

            # End elink
        # End vfat
        # Disable data in fpga
        for queso in queso_dict:
            # Connect to each RPi using username/password authentication
            if queso in pi_list:
                pi_ip = pi_list[queso]
            else:
                print(Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
                continue
            ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)
            ssh_channel_en(fpga,loopback=args.loopback,verbose=args.verbose)
            ssh.close()
    # End fpga
    
    # Re-enable all elinks to normal operation (loopback on)
    for queso in queso_dict:
        # Connect to each RPi using username/password authentication
        if queso in pi_list:
            pi_ip = pi_list[queso]
        else:
            print(Colors.YELLOW + "Pi IP not present for QUESO %s"%queso + Colors.ENDC)
            continue
        ssh.connect(pi_ip, username=username, password=password, look_for_keys=False)
        ssh_channel_en([1,2,3],loopback=True,en_all=True,vfat=[0,1],verbose=args.verbose)
        ssh.close()
    
    # Sort by vfat # per queso
    for queso in queso_crosstalk_data:
        queso_crosstalk_data[queso] = dict(sorted(queso_crosstalk_data[queso].items()))
    
    # Results file
    dataDir = results_dir + "/crosstalk_results"
    try:
        os.makedirs(dataDir)
    except FileExistsError:
        pass # skip for existing directory

    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = f"{dataDir}/vfat_elink_crosstalk_data_{now}.txt"
    file_out = open(filename,"w")
   
    # -- Validate data --
    crosstalk_results = {}
    crosstalk_elink_list = []
    bad_elink_list = []
    for queso,oh_sn in queso_dict.items():
        crosstalk_results[queso] = {}
        for vfat_inj in queso_crosstalk_data[queso]:
            crosstalk_results[queso][vfat_inj] = {}
            for elink_inj in queso_crosstalk_data[queso][vfat_inj]:
                crosstalk_results[queso][vfat_inj][elink_inj] = {
                    'crosstalk' : {},
                    'prbs_err' : None,
                    'dead' : False
                }
                for vfat_read in queso_crosstalk_data[queso][vfat_inj][elink_inj]:
                    for elink_read in range(9):
                        if (vfat_inj == vfat_read) and (elink_inj == elink_read):
                            # Check for dead channels
                            if queso_crosstalk_data[queso][vfat_inj][elink_inj][vfat_read][elink_read] == 0:
                                crosstalk_results[queso][vfat_inj][elink_inj]['dead'] = True
                                if (queso,vfat_read,elink_read) not in bad_elink_list:
                                    bad_elink_list += [(queso,vfat_read,elink_read)]
                            if args.check_prbs:
                                crosstalk_results[queso][vfat_inj][elink_inj]['prbs_err'] = prbs_err_data[queso][vfat_inj][elink_inj]
                                if prbs_err_data[queso][vfat_inj][elink_inj] > 0:
                                    if (queso,vfat_read,elink_read) not in bad_elink_list:
                                        bad_elink_list += [(queso,vfat_read,elink_read)]
                        else: #NAND
                            # Check for data elsewhere
                            if queso_crosstalk_data[queso][vfat_inj][elink_inj][vfat_read][elink_read] > 0:
                                if vfat_read not in crosstalk_results[queso][vfat_inj][elink_inj]['crosstalk']:
                                    crosstalk_results[queso][vfat_inj][elink_inj]['crosstalk'][vfat_read] = [elink_read]
                                else:
                                    crosstalk_results[queso][vfat_inj][elink_inj]['crosstalk'][vfat_read] += [elink_read]
                                crosstalk_elink_list += [(queso,vfat_read,elink_read)]
                                if (queso,vfat_read,elink_read) not in bad_elink_list:
                                    bad_elink_list += [(queso,vfat_read,elink_read)]
    
    # -- Print results --
    print('\nCross Talk Data:\n')
    file_out.write('Cross Talk Data:\n\n')
    for queso in crosstalk_results:
        print(f'QUESO {queso} - OH {oh_sn}:')
        file_out.write(f'OH {oh_sn} on QUESO {queso}:\n')
        for vfat_inj in crosstalk_results[queso]:
            print(f'  VFAT {vfat_inj:02d}:')
            file_out.write(f'  VFAT {vfat_inj:02d}:\n')
            for elink_inj in crosstalk_results[queso][vfat_inj]:
                if (queso,vfat_inj,elink_inj) in bad_elink_list:
                    print( f"    ELINK {elink_inj}: {Colors.RED}BAD{Colors.ENDC}")
                else:
                    print( f"    ELINK {elink_inj}: {Colors.GREEN}GOOD{Colors.ENDC}")
                
                if (queso,vfat_inj,elink_inj) in crosstalk_elink_list:
                    # Found crosstalk
                    print(Colors.YELLOW + f"    Cross Talk noise observed in this elink" + Colors.ENDC)
                if crosstalk_results[queso][vfat_inj][elink_inj]['dead']:
                    # Found dead elink
                    print(Colors.YELLOW + f"    No data observed in this elink" + Colors.ENDC)
                if args.check_prbs:
                    if crosstalk_results[queso][vfat_inj][elink_inj]['prbs_err']:
                        err_cnt = crosstalk_results[queso][vfat_inj][elink_inj]['prbs_err']
                        print(Colors.YELLOW + f"    {err_cnt} PRBS errors observed in this elink" + Colors.ENDC)
                if crosstalk_results[queso][vfat_inj][elink_inj]['crosstalk']:
                    # Found crosstalk
                    if args.verbose:
                        for vfat_read in crosstalk_results[queso][vfat_inj][elink_inj]['crosstalk']:
                            print(Colors.YELLOW + f"    Cross Talk observed in VFAT {vfat_read:02d} ELINKS {' '.join(map(str,[elink for elink in crosstalk_results[queso][vfat_inj][elink]['crosstalk'][vfat_read]]))}" + Colors.ENDC)

    print('\nCross Talk Results:\n')
    file_out.write('Cross Talk Results:\n\n')
    if bad_elink_list:
        for queso,vfat,elink in bad_elink_list:
            if (queso,vfat,elink) in crosstalk_elink_list:
                print(Colors.RED + f'Crosstalk observed in QUESO {queso} OH {queso_dict[queso]} VFAT {vfat:02d} ELINK {elink}' + Colors.ENDC)
                file_out.write(f'Crosstalk observed in QUESO {queso} OH {queso_dict[queso]} VFAT {vfat:02d} ELINK {elink}\n')
            if crosstalk_results[queso][vfat][elink]['dead']:
                print(Colors.RED + f"Dead elink: No data observed in QUESO {queso} OH {queso_dict[queso]} VFAT {vfat:02d} ELINK {elink}" + Colors.ENDC)
                file_out.write(f"Dead elink: No data observed in QUESO {queso} OH {queso_dict[queso]} VFAT {vfat:02d} ELINK {elink}\n")
            if args.check_prbs:
                if crosstalk_results[queso][vfat][elink]['prbs_err']:
                    err_cnt = crosstalk_results[queso][vfat][elink]['prbs_err']
                    print(Colors.YELLOW + f"{err_cnt} PRBS errors observed in QUESO {queso} OH {queso_dict[queso]} VFAT {vfat:02d} ELINK {elink}" + Colors.ENDC)
            print()
    else:
        print(Colors.GREEN + "No Cross Talk observed between elinks" + Colors.ENDC)
        file_out.write("No Cross Talk observed between elinks\n")
    print()

    file_out.close()
