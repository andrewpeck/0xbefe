from time import time, sleep
import os, sys, glob
import paramiko
import argparse

queso_id_ip_map = {
    1 : "169.254.119.34",
    2 : "169.254.52.40",
    3 : "169.254.118.3",
    4 : "169.254.66.95",
    5 : "169.254.122.125",
    6 : "169.254.200.178",
    7 : "169.254.8.226",
    8 : "169.254.57.247",
}

if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 Power Cycle Tests")
    parser.add_argument("-q", "--queso_id", action="store", nargs="+", dest="queso_id", help="queso_id = list of QUESO that needs to be tested")
    parser.add_argument("-c", "--configure_test", action="store_true", dest="configure_test", help="configure_test = do configuration from RPI test")
    parser.add_argument("-i", "--init_frontend_test", action="store_true", dest="init_frontend_test", help="init_frontend_test = do init_frontend")
    parser.add_argument("-t", "--i2c_test", action="store_true", dest="i2c_test", help="i2c_test = check i2c connection")
    parser.add_argument("-n", "--niter", action="store", dest="niter", default="50", help="niter = Number of iterations (default=50)")
    args = parser.parse_args()

    for i in range(args.niter):
        print("iteration", i)
        # 1. only power on and do nothing
        os.system("python3 me0_lpgbt/queso_testing/queso_initialization.py -i me0_lpgbt/queso_testing/resources/input_queso.txt -p")
        sleep(5)

        # 2. do the test
        if args.init_frontend_test:
            os.system("python3 init_frontend.py")

        else:
            router_username = "pi"
            router_password = "queso"
            for queso in args.queso_id:
                router_ip = queso_id_ip_map[queso]
                ssh = paramiko.SSHClient()
                ssh.load_system_host_keys()
                ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                # Connect to router using username/password authentication
                ssh.connect(router_ip, 
                            username=router_username, 
                            password=router_password,
                            look_for_keys=False)
                check_boss = "cd Documents/0xbefe/scripts/gem; python3 me0_lpgbt_rw_register.py -s queso -q ME0 -o 0 -g 0 -r 0x00 -d 0x01"   
                check_sub = "cd Documents/0xbefe/scripts/gem; python3 me0_lpgbt_rw_register.py -s queso -q ME0 -o 0 -g 1 -r 0x00 -d 0x01"
                config_boss = "cd Documents/0xbefe/scripts/gem; python3 me0_lpgbt_config.py -s queso -q ME0 -o 0 -g 0 -i ../resources/me0_boss_config_ohv2.txt"
                config_sub = "cd Documents/0xbefe/scripts/gem; python3 me0_lpgbt_config.py -s queso -q ME0 -o 0 -g 1 -i ../resources/me0_sub_config_ohv2.txt"
                if args.configure_test:
                    ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(config_boss)
                    print("Config Boss for QUESO", queso)
                    print(ssh_stdout)
                    if "error" in ssh_stdout.lower():
                        sys.exit()
                    sleep(2)
                
                    ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(config_sub)
                    print("Config Sub for QUESO", queso)
                    print(ssh_stdout)
                    if "error" in ssh_stdout.lower():
                        sys.exit()
                    sleep(2)
                elif args.i2c_test:
                    ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(check_boss)
                    print("Check i2c for Boss for QUESO", queso)
                    print(ssh_stdout)
                    if "error" in ssh_stdout.lower():
                        sys.exit()
                    sleep(2)
                
                    ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(check_sub)
                    print("Check i2c for Sub for QUESO", queso)
                    print(ssh_stdout)
                    if "error" in ssh_stdout.lower():
                        sys.exit()
                    sleep(2)
                
        # 3. power off
        os.system("python3 me0_lpgbt/queso_testing/queso_initialization.py -i me0_lpgbt/queso_testing/resources/input_queso.txt -o")
        sleep(5)
        
    print("50 iterations passed")