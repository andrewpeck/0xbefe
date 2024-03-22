from pyHM310T import PowerSupply
from gem.me0_lpgbt.rw_reg_lpgbt import *
import gem.gem_utils as gem_utils
from time import sleep
import sys, os
import argparse
import paramiko

def main(system, oh_select, gbt_list, current, voltages, niter):

    if sys.version_info[0] < 3:
        raise Exception("Python version 3.x required")

    # Configure Power Supply
    power_supply = PowerSupply(port='/dev/ttyUSB0')
    sleep(0.5)
    power_supply.set_current(current)
    sleep(0.5)
    power_supply.set_voltage(voltages)
    sleep(0.5)

    # Get first list of registers to compare
    print ("Turning off power, then on and getting initial list of registers and turning off power")

    # Turn power supply off
    power_supply.disable_output()
    sleep(3)
    # Check if output is disabled
    while (power_supply.is_output_enabled()):
        sleep(0.5)
    print("Output is disabled")

    # cheesecake parameters
    router_ip = "169.254.181.119"
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

    n_error_backend_ready_boss = 0
    n_error_backend_ready_sub  = 0

    print ("Begin powercycle iteration\n")
    # Power cycle interations
    for n in range(0,niter):
        print ("Iteration: %d\n"%(n+1))

        # Turn power supply on
        power_supply.enable_output()
        sleep(3)
        # Check if output is enabled
        while (not power_supply.is_output_enabled()):
            sleep(0.5)
        print("Output is enabled")

        # -----------------need cheesecake connection from here----------------------
        ssh_command = "cd /home/pi/Documents/0xbefe/scripts/; source env.sh me0 cvp13 0; cd gem/;"
        ssh_command += "python3 me0_lpgbt_rw_register.py -s chc -q ME0 -o 1 -g 0 -r 0x00 -d 0x01"    
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(ssh_command)
        output = ssh_stdout.readlines()
        # print (output)
        i2c_success = True
        for line in output:
            if "ERROR" in line:
                i2c_success = False
                n_error_backend_ready_boss += 1
                print(Colors.RED + "I2C connection ERROR reading BOSS GBT!" + Colors.ENDC)
                print(Colors.YELLOW + f'BOSS Link Ready Errors: {n_error_backend_ready_boss}' + Colors.ENDC)
                break # so that it does not count multiple
                # print("Exit the Test")
                # rw_terminate()
        if i2c_success:
            print(Colors.GREEN + 'BOSS I2C read successful!' + Colors.ENDC)
        sleep(2)
       
        ssh_command = "cd /home/pi/Documents/0xbefe/scripts/; source env.sh me0 cvp13 0; cd gem/;" 
        ssh_command += "python3 me0_lpgbt_rw_register.py -s chc -q ME0 -o 1 -g 1 -r 0x00 -d 0x01"    
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(ssh_command)
        output = ssh_stdout.readlines()
        # print (output)
        i2c_success = True
        for line in output:
            if "ERROR" in line:
                i2c_success = False
                n_error_backend_ready_sub += 1
                print(Colors.RED + "I2C connection ERROR reading SUB GBT!" + Colors.ENDC)
                print(Colors.YELLOW + f'SUB Link Ready Errors: {n_error_backend_ready_sub}' + Colors.ENDC)
                break
                # print("Exit the Test")
                # rw_terminate()
        if i2c_success:
            print(Colors.GREEN + 'SUB I2C read successful!' + Colors.ENDC)
        
        # print("I2C connection successful, continue...")
        sleep(2)
        # -----------------no longer need cheesecake connection from here----------------------

        print ("")
        # Turn power supply off
        power_supply.disable_output()
        sleep(3)
        # Check if output is disabled
        while (power_supply.is_output_enabled()):
            sleep(0.5)
        print("Output is disabled")

    print ("\nEnd of powercycle iteration")
    print(Colors.YELLOW + f'BOSS Link Ready Errors: {n_error_backend_ready_boss}' + Colors.ENDC)
    print(Colors.YELLOW + f'SUB Link Ready Errors: {n_error_backend_ready_sub}' + Colors.ENDC)
    print ("Number of iterations: %d\n"%niter)
    ssh.close()

    # Results
    print ("Result For lpGBTs: \n")
    for gbt in gbt_list["boss"]:
        print ("Boss lpGBT %d: "%gbt)
        str_n_error_backend_ready_boss = ""
        str_n_error_uplink_fec_boss = ""
        str_n_error_mode_boss = ""
        str_n_error_pusm_ready_boss = ""
        str_n_error_reg_list_boss = ""
        if n_error_backend_ready_boss[gbt]==0:
            str_n_error_backend_ready_boss += Colors.GREEN
        else:
            str_n_error_backend_ready_boss += Colors.RED
        if n_error_uplink_fec_boss[gbt]==0:
            str_n_error_uplink_fec_boss += Colors.GREEN
        else:
            str_n_error_uplink_fec_boss += Colors.RED
        if n_error_mode_boss[gbt]==0:
            str_n_error_mode_boss += Colors.GREEN
        else:
            str_n_error_mode_boss += Colors.RED
        if n_error_pusm_ready_boss[gbt]==0:
            str_n_error_pusm_ready_boss += Colors.GREEN
        else:
            str_n_error_pusm_ready_boss += Colors.RED
        if n_error_reg_list_boss[gbt]==0:
            str_n_error_reg_list_boss += Colors.GREEN
        else:
            str_n_error_reg_list_boss += Colors.RED
        str_n_error_backend_ready_boss += "  Number of Backend READY Status Errors: %d"%(n_error_backend_ready_boss[gbt])
        str_n_error_uplink_fec_boss += "  Number of Powercycles with Uplink FEC Errors: %d"%n_error_uplink_fec_boss[gbt]
        str_n_error_mode_boss += "  Number of Mode Errors: %d"%n_error_mode_boss[gbt]
        str_n_error_pusm_ready_boss += "  Number of PUSMSTATE Errors: %d"%n_error_pusm_ready_boss[gbt]
        str_n_error_reg_list_boss += "  Number of Register Value Errors: %d"%n_error_reg_list_boss[gbt]
        str_n_error_backend_ready_boss += Colors.ENDC
        str_n_error_uplink_fec_boss += Colors.ENDC
        str_n_error_mode_boss += Colors.ENDC
        str_n_error_pusm_ready_boss += Colors.ENDC
        str_n_error_reg_list_boss += Colors.ENDC
        print (str_n_error_backend_ready_boss)
        print (str_n_error_uplink_fec_boss)
        print (str_n_error_mode_boss)
        print (str_n_error_pusm_ready_boss)
        print (str_n_error_reg_list_boss)

    print ("")
    for gbt in gbt_list["sub"]:
        print ("Sub lpGBT %d: "%gbt)
        str_n_error_backend_ready_sub = ""
        str_n_error_uplink_fec_sub = ""
        str_n_error_mode_sub = ""
        str_n_error_pusm_ready_sub = ""
        str_n_error_reg_list_sub = ""
        if n_error_backend_ready_sub[gbt]==0:
            str_n_error_backend_ready_sub += Colors.GREEN
        else:
            str_n_error_backend_ready_sub += Colors.RED
        if n_error_uplink_fec_sub[gbt]==0:
            str_n_error_uplink_fec_sub += Colors.GREEN
        else:
            str_n_error_uplink_fec_sub += Colors.RED
        if n_error_mode_sub[gbt]==0:
            str_n_error_mode_sub += Colors.GREEN
        else:
            str_n_error_mode_sub += Colors.RED
        if n_error_pusm_ready_sub[gbt]==0:
            str_n_error_pusm_ready_sub += Colors.GREEN
        else:
            str_n_error_pusm_ready_sub += Colors.RED
        if n_error_reg_list_sub[gbt]==0:
            str_n_error_reg_list_sub += Colors.GREEN
        else:
            str_n_error_reg_list_sub += Colors.RED
        str_n_error_backend_ready_sub += "  Number of Backend READY Status Errors: %d"%(n_error_backend_ready_sub[gbt])
        str_n_error_uplink_fec_sub += "  Number of Powercycles with Uplink FEC Errors: %d"%n_error_uplink_fec_sub[gbt]
        str_n_error_mode_sub += "  Number of Mode Errors: %d"%n_error_mode_sub[gbt]
        str_n_error_pusm_ready_sub += "  Number of PUSMSTATE Errors: %d"%n_error_pusm_ready_sub[gbt]
        str_n_error_reg_list_sub += "  Number of Register Value Errors: %d"%n_error_reg_list_sub[gbt]
        str_n_error_backend_ready_sub += Colors.ENDC
        str_n_error_uplink_fec_sub += Colors.ENDC
        str_n_error_mode_sub += Colors.ENDC
        str_n_error_pusm_ready_sub += Colors.ENDC
        str_n_error_reg_list_sub += Colors.ENDC
        print (str_n_error_backend_ready_sub)
        print (str_n_error_uplink_fec_sub)
        print (str_n_error_mode_sub)
        print (str_n_error_pusm_ready_sub)
        print (str_n_error_reg_list_sub)

    print ("")

if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="Powercycle test for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", nargs="+", dest="gbtid", help="gbtid = List of GBT IDs")
    parser.add_argument('-i','--current',action='store',dest='current',help='current = Current limit to set power supply to.')
    parser.add_argument('-v','--voltage',action='store',dest='voltage',help='voltage = Voltage to set power supply to.')
    parser.add_argument("-n", "--niter", action="store", dest="niter", default="1000", help="niter = Number of iterations (default=1000)")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for testing")
    else:
        print (Colors.YELLOW + "Only valid options: backend" + Colors.ENDC)
        sys.exit()

    gbt_list = {}
    gbt_list["boss"] = []
    gbt_list["sub"] = []
    oh_select = -9999
    if args.ohid is None:
        print (Colors.YELLOW + "Need OHID for backend" + Colors.ENDC)
        sys.exit()
    if args.gbtid is None:
        print (Colors.YELLOW + "Need Boss GBTID for backend" + Colors.ENDC)
        sys.exit()
    oh_select = int(args.ohid)
    #if oh_select > 1:
    #    print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
    #    sys.exit()
    for gbt in args.gbtid:
        if int(gbt) > 7:
            print(Colors.YELLOW + "Only GBTID 0-7 allowed" + Colors.ENDC)
            sys.exit()
        if int(gbt)%2 == 0:
            gbt_list["boss"].append(int(gbt))
        else:
            gbt_list["sub"].append(int(gbt))

    if not args.voltage:
        print(Colors.YELLOW + 'Enter voltage' + Colors.ENDC)
        sys.exit()
    else:
        try:
            voltage = float(args.voltage)
        except TypeError:
            print(Colors.YELLOW + 'Must enter floating point values for voltage' + Colors.ENDC)
            sys.exit()

    if args.current:
        try:
            current = float(args.current)
        except TypeError:
            print(Colors.YELLOW + 'Must enter floating point value for current limit' + Colors.ENDC)
            sys.exit()
    else:
        current = None

    # Initialization
    rw_initialize(args.gem, args.system)
    print("Initialization Done\n")

    try:
        main(args.system, oh_select, gbt_list, current, voltage, int(args.niter))
    except KeyboardInterrupt:
        print (Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()



