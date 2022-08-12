from time import time, sleep
import os, sys, glob
import argparse
import random
import datetime
import math
import paramiko
from gem.gem_utils import *
      
if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 QSFP BERT using VOA")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", nargs="+", dest="gbtid", help="gbtid = list of GBT numbers (multiple only possible for uplink)")
    parser.add_argument("-p", "--path", action="store", dest="path", help="path = uplink, downlink")
    args = parser.parse_args()

    # VOA Control Parameters
    attenuation_list_increase = []
    attenuation_list_decrease = []
    lpgbt_status_increase = []
    lpgbt_status_decrease = []
    a = 10.0
    b = 18.0
    while a<=18:
        attenuation_list_increase.append(a)
        attenuation_list_decrease.append(b)
        lpgbt_status_increase.append("")
        lpgbt_status_decrease.append("")
        a += 0.5
        b -=0.5

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
    #ssh_command = "cd devel_scripts_update_0xbefe/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 me0_lpgbt/qsfp_testing/voa_control.py -r -a 0"    
    ssh_command = "python3 Documents/voa_control.py -r -a 0"
    ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(ssh_command)
    output = ssh_stdout.readlines()
    print(output)
    print ("Attenuation set to 0 dB\n")
    sleep(2)

    # Initialize  
    initialize("ME0", "backend")
    os.system("python3 init_frontend.py")
    print ("")

    counter = 0
    print ("Increasing Attenuation: \n")
    for i in attenuation_list_increase:
        print ("Start Test for Attenuation: %0.1f dB\n"%i)

        # Run ssh command for VOA
        #ssh_command = "cd devel_scripts_update_0xbefe/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 me0_lpgbt/qsfp_testing/voa_control.py -a %0.1f"%i  
        ssh_command = "python3 Documents/voa_control.py -a %0.1f"%i
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(ssh_command)
        output = ssh_stdout.readlines()
        print(output)
        print ("Attenuation set to %0.1f dB\n"%i)
        sleep(2)

        # Check lpGBT Status
        ready = read_reg("BEFE.GEM.OH_LINKS.OH%s.GBT%s_READY" % (args.ohid, args.gbtid[0]))
        fec_err_cnt = read_reg("BEFE.GEM.OH_LINKS.OH%s.GBT%s_FEC_ERR_CNT" % (args.ohid, args.gbtid[0]))
        if ready:
            lpgbt_status_increase[count] = "READY, FEC Errors = %d"%fec_err_cnt
        else:
            lpgbt_status_increase[count] = "NOT READY"
        sleep(1)

        print ("End Test for Attenuation: %0.1f dB\n"%i)
        counter += 1

    sleep (5)
    print ("Decreasing Attenuation: \n")
    for i in attenuation_list_decrease:
        print ("Start Test for Attenuation: %0.1f dB\n"%i)

        # Run ssh command for VOA
        #ssh_command = "cd devel_scripts_update_0xbefe/0xbefe/scripts; source env.sh me0 cvp13 0; cd gem; python3 me0_lpgbt/qsfp_testing/voa_control.py -a %0.1f"%i  
        ssh_command = "python3 Documents/voa_control.py -a %0.1f"%i
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(ssh_command)
        output = ssh_stdout.readlines()
        print(output)
        print ("Attenuation set to %0.1f dB\n"%i)
        sleep(2)

        # Check lpGBT Status
        ready = read_backend_reg(get_backend_node("BEFE.GEM.OH_LINKS.OH%s.GBT%s_READY" % (args.ohid, args.gbtid[0])))
        fec_err_cnt = read_backend_reg(get_backend_node("BEFE.GEM.OH_LINKS.OH%s.GBT%s_FEC_ERR_CNT" % (args.ohid, args.gbtid[0])))
        if ready:
            lpgbt_status_decrease[count] = "READY, FEC Errors = %d"%fec_err_cnt
        else:
            lpgbt_status_decrease[count] = "NOT READY"
        sleep(1)

        print ("End Test for Attenuation: %0.1f dB\n"%i)
        counter += 1


    print ("")
    print ("QSFP RX Squelch Results for: ")
    for i in range(0, len(attenuation_list_increase)):
        print ("  Attenuation = %0.1f: Increasing attenuation status: %s,    Decreasing attenuation status: %s"%(lpgbt_status_increase[i], lpgbt_status_decrease[i]))
    print ("")

    # Close connection
    ssh.close()
    

       

    