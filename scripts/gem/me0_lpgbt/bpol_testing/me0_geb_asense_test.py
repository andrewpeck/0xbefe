import sys, os, glob
import time
import argparse
from gem.me0_lpgbt.rw_reg_lpgbt import *

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="GEB Temp and Current Monitoring")
    parser.add_argument("-t", "--time", action="store", dest="time", help="time in minutes")
    args = parser.parse_args()

    runtime = int(args.time)

    # Power on
    os.system("python3 me0_lpgbt/powercycle_test_ucla/set_relay.py -r 7 -s on")
    time.sleep(10)

    # Initialization
    os.system("python3 init_frontend.py")
    time.sleep(2)

    # Phase Scan
    os.system("python3 me0_phase_scan.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c -b 40")
    time.sleep(2)

    # Configure VFAT
    os.system("python3 vfat_config.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c 1")
    sleep(5)

    # ASense Scan GBT 0
    os.system("python3 me0_asense_monitor.py -s backend -q ME0 -o 0 -g 0 -m %d"%runtime)
    sleep(2)

    # ASense Scan GBT 2
    os.system("python3 me0_asense_monitor.py -s backend -q ME0 -o 0 -g 2 -m %d"%runtime)
    sleep(2)

    # Unconfigure VFAT
    os.system("python3 vfat_config.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -c 0")
    sleep(5)

    # Power off
    os.system("python3 me0_lpgbt/powercycle_test_ucla/set_relay.py -r 7 -s off")
    time.sleep(10)

    print ("\n")















