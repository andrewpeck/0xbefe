from time import time, sleep
import os, sys, glob
import argparse
import random
import datetime
import math
import paramiko
from common.utils import get_befe_scripts_dir
      
if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 QSFP BERT using VOA")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", nargs="+", dest="gbtid", help="gbtid = list of GBT numbers (multiple only possible for uplink)")
    parser.add_argument("-p", "--path", action="store", dest="path", help="path = uplink, downlink")
    parser.add_argument("-b", "--ber", action="store", dest="ber", help="BER = measurement till this BER. eg. 1e-12")
    parser.add_argument("-v", "--vfat_lt", action="store_true", dest="vfat_lt", help="vfat_lt = if you want to set the VFATs to low threshold")
    args = parser.parse_args()

    scripts_gem_dir = get_befe_scripts_dir() + '/gem'

    # VOA Control Parameters
    attenuation_list = [8, 9, 10, 11, 12, 13, 13.2, 13.4, 13.6, 13.8, 14, 14.2, 14.4, 14.6, 14.8, 15.0, 15.2, 15.4]
    router_ip = "169.254.119.34"
    router_username = "pi"
    router_password = "queso"
    ssh = paramiko.SSHClient()

    # Load SSH host keys
    ssh.load_system_host_keys()

    # Add SSH host key automatically if needed
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    # Connect to router using username/password authentication
    ssh.connect(router_ip, 
                username=router_username, 
                password=router_password,
                look_for_keys=False)

    # Set Attenuation to 0
    ssh_command = "cd Documents/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 me0_lpgbt/qsfp_testing/voa_control.py -r -a 0"    
    ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(ssh_command)
    output = ssh_stdout.readlines()
    print(output)
    print ("Attenuation set to 0 dB\n")
    sleep(2)

    # Initialize  
    os.system("python3 init_frontend.py")
    sleep (5)

    # Set VFATs to low threshold if needed
    if args.vfat_lt:
        os.system("python3 vfat_config.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c 1 -lt")
    sleep (5)

    n_fec_errors = []
    for i in range(0, len(attenuation_list)):
        n_fec_errors.append(-9999) 
    print ("")

    counter = 0
    for i in attenuation_list:
        print ("Start Test for Attenuation: %0.1f dB\n"%i)

        # Run ssh command for VOA
        ssh_command = "cd Documents/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 me0_lpgbt/qsfp_testing/voa_control.py -a %0.1f"%i  
        print (ssh_command)
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(ssh_command)
        output = ssh_stdout.readlines()
        print(output)
        print ("Attenuation set to %0.1f dB\n"%i)
        sleep(2)

        # Run FEC BERT
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %s -g %s -p %s -r run -b %s"%(args.ohid, args.gbtid[0], args.path, args.ber))
        list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_optical_link_bert_fec_results/*.txt")
        latest_file = max(list_of_files, key=os.path.getctime)
        result_file = open(latest_file)  
        result_read = 0  
        for line in result_file.readlines():
            if result_read:
                n_fec_errors[counter] = int(line.split("=")[1])
                break
            if "End Error Counting:" in line:
                result_read=1
      
        result_file.close()
        sleep(1)

        print ("End Test for Attenuation: %0.1f dB\n"%i)
        counter += 1

    # Unconfigure VFATs
    if args.vfat_lt:
        os.system("python3 vfat_config.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c 0")
    sleep (5)

    # Set Attenuation to 0
    ssh_command = "cd Documents/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 me0_lpgbt/qsfp_testing/voa_control.py -r -a 0"    
    ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(ssh_command)
    output = ssh_stdout.readlines()
    print(output)
    print ("Attenuation set to 0 dB\n")
    sleep(2)

    print ("")
    print ("QSFP Test Results: ")
    for i in range(0, len(attenuation_list)):
        print ("  Attenuation = %0.1f: Nr. of FEC Errors = %d"%(attenuation_list[i], n_fec_errors[i]))
    print ("")

    # Close connection
    ssh.close()
    

       

    
