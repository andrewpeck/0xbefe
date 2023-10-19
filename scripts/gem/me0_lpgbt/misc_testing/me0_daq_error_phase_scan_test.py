import sys, os, glob
import time
import argparse
from gem.me0_lpgbt.rw_reg_lpgbt import *
from common.utils import get_befe_scripts_dir

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Testing DAQ CRC Tests with Powercycles")
    parser.add_argument("-n", "--niter", action="store", dest="n", help="n = number of iterations")
    args = parser.parse_args()

    scripts_gem_dir = get_befe_scripts_dir() + '/gem'

    n = int(args.n)
    n_nonzero_errors = {}
    vfat_list = [0, 1, 2, 3, 8, 9, 10, 11, 16, 17, 18, 19]
    for vfat in vfat_list:
        n_nonzero_errors[vfat] = 0

    for i in range(0,n):
        print (Colors.BLUE + "Iteration #%d\n"%i)
	
        # Power on
        os.system("python3 me0_lpgbt/powercycle_test_ucla/set_relay.py -r 7 -s on")
        time.sleep(10)

        # Initialization
        os.system("python3 init_frontend.py")
        time.sleep(2)

        # Phase Scan
        os.system("python3 me0_phase_scan.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c")
        time.sleep(2)

        # DAQ CRC Error Test	
        os.system("python3 vfat_daq_test.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -n 100000")
        time.sleep(2)
        list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_daq_test_results/*.txt")
        latest_file = max(list_of_files, key=os.path.getctime)
        result_file = open(latest_file)
        for line in result_file.readlines():
            if "Errors =" not in line:
                continue
            vfat = int(line.split()[1].split(",")[0])
            nerr = int(line.split()[4].split(",")[0])
            if nerr != 0:
                n_nonzero_errors[vfat] += 1
        result_file.close()

        # Power off
        os.system("python3 me0_lpgbt/powercycle_test_ucla/set_relay.py -r 7 -s off")
        time.sleep(10)

    print ("\n")

    for vfat in vfat_list:
        if n_nonzero_errors[vfat] == 0:
            print (Colors.GREEN + "VFAT %02d, Number of runs with CRC errors = %d"%(vfat, n_nonzero_errors[vfat])  + Colors.ENDC)
        else:
            print (Colors.RED + "VFAT %02d, Number of runs with CRC errors = %d"%(vfat, n_nonzero_errors[vfat])  + Colors.ENDC)
    print ("")














