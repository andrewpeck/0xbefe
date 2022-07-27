from time import time, sleep
import os, sys, glob
import argparse
import random
import datetime
import math
import paramiko
      
if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 QSFP BERT using VOA")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", nargs="+", dest="gbtid", help="gbtid = list of GBT numbers (multiple only possible for uplink)")
    parser.add_argument("-p", "--path", action="store", dest="path", help="path = uplink, downlink")
    parser.add_argument("-b", "--ber", action="store", dest="ber", help="BER = measurement till this BER. eg. 1e-12")
    args = parser.parse_args()

    # Initialize
    os.system("python3 init_frontend.py")

    # VOA Control Parameters
    attenuation_list = [8, 9, 10, 11, 11.2, 11.4, 11.6, 11.8, 12, 12.2, 12.4, 12.6, 12.8, 13, 13.2, 13.4, 13.6]
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

    n_fec_errors = [-9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999]
    print ("")

    counter = 0
    for i in attenuation_list:
        print ("Start Test for Attenuation: %0.1f dB\n"%i)

        # Run ssh command for VOA
        if i==8:
            #ssh_command = "cd devel_scripts_update_0xbefe/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 me0_lpgbt/qsfp_testing/voa_control.py -r -a %0.1f"%i 
            ssh_command = "python3 Documents/voa_control.py -r -a %0.1f"%i
        else:
            #ssh_command = "cd devel_scripts_update_0xbefe/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 me0_lpgbt/qsfp_testing/voa_control.py -a %0.1f"%i  
            ssh_command = "python3 Documents/voa_control.py -a %0.1f"%i
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(ssh_command)
        output = ssh_stdout.readlines()
        print(output)
        print ("Attenuation set for %0.1f dB\n"%i)
        sleep(2)

        # Run FEC BERT
        os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %s -g %s -p %s -r run -b %s"%(args.ohid, args.gbtid, args.path, args.ber))
        list_of_files = glob.glob("results/vfat_data/vfat_sbit_mapping_results/*.txt")
        latest_file = max(list_of_files, key=os.path.getctime)
        result_file = open(latest_file)  
        result_read = 0  
        for line in result_file.readlines():
            if "End Error Counting:" in line:
                result_read=1
            if result_read:
                n_fec_errors[counter] = int(line.split("=")[1])
                break

        result_file.close()
        sleep(1)

        print ("End Test for Attenuation: %0.1f dB\n"%i)
        counter += 1

    print ("")
    print ("QSFP Test Results: ")
    for i in range(0, len(attenuation_list)):
        print ("  Attenuation = %0.1f: Nr. of FEC Errors = %d"%(attenuation_list[i], n_fec_errors[i]))
    print ("")

    # Close connection
    ssh.close()
    

       

    