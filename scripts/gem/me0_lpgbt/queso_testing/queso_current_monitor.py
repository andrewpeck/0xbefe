import time
import sys
import argparse
import multiprocessing
import csv
import datetime
import os
import gem.me0_lpgbt.rpi_chc as rpi_chc

class Colors:
    WHITE   = "\033[97m"
    CYAN    = "\033[96m"
    MAGENTA = "\033[95m"
    BLUE    = "\033[94m"
    YELLOW  = "\033[93m"
    GREEN   = "\033[92m"
    RED     = "\033[91m"
    ENDC    = "\033[0m"

def buildReadCommand(channel):
    startBit = 0x01
    singleEnded = 0x08
    return [startBit, (singleEnded|channel)<<4, 0]
    
def processAdcValue(result):
    '''Take in result as array of three bytes. 
       Return the two lowest bits of the 2nd byte and
       all of the third byte'''
    byte2 = (result[1] & 0x03)
    out_code = (byte2 << 8) | result[2]
    volt = (out_code * 1.024) / 1024 
    amp = volt / (0.008 * 300)
    return amp
    
def readAdc(channel):
    # only care about channel 0 - 3
    if ((channel > 3) or (channel < 0)):
        print (Colors.RED + "ERROR: Invalid channel, only allowed: 0, 1, 2 and 3" + Colors.ENDC)
        terminate()
    success, data = gbt_rpi_chc.spi_rw(buildReadCommand(channel))
    if not success:
        print (Colors.RED + "ERROR: Invalid data read from SPI transaction" + Colors.ENDC)
        terminate()
    return processAdcValue(data)

def terminate():
    # Terminating RPi
    terminate_success = gbt_rpi_chc.terminate()
    if not terminate_success:
        print(Colors.RED + "ERROR: Problem in RPi_CHC termination" + Colors.ENDC)
    sys.exit()

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='Monitor the currents of OH and FPGA')
    parser.add_argument("-c", "--config", action="store_true", dest="config", help="if you only want to configure, not run the monitor")
    parser.add_argument("-t", "--runtime", action="store", dest="runtime", help="runtime = time given in minutes")
    args = parser.parse_args()

    # Set up RPi
    global gbt_rpi_chc
    gbt_rpi_chc = rpi_chc.rpi_chc()
    
    initialize_success = 1
    if initialize_success:
        initialize_success *= gbt_rpi_chc.en_i2c_switch() 
    if not initialize_success:
        print(Colors.RED + "ERROR: Problem in initialization" + Colors.ENDC)
        terminate()

    # Configure the OH current monitors
    channel_sel_success = 0
    channel_sel_success = gbt_rpi_chc.i2c_channel_sel(None, "oh")
    time.sleep (0.1)
    if not channel_sel_success:
        print(Colors.RED + "ERROR: Problem in selecting channel of switch" + Colors.ENDC)
        terminate()
    success = gbt_rpi_chc.current_monitor_write("oh_1v2", 0x58)
    if not success:
        print(Colors.RED + "ERROR: Problem in writing to OH 1.2V current monitor" + Colors.ENDC)
        terminate()
    success = gbt_rpi_chc.current_monitor_write("oh_2v5", 0x58)
    if not success:
        print(Colors.RED + "ERROR: Problem in writing to OH 2.5V current monitor" + Colors.ENDC)
        terminate()

    # Configure the FPGA current monitors
    channel_sel_success = 0
    channel_sel_success = gbt_rpi_chc.i2c_channel_sel(None, "fpga")
    time.sleep (0.1)
    if not channel_sel_success:
        print(Colors.RED + "ERROR: Problem in selecting channel of switch" + Colors.ENDC)
        terminate()
    success = gbt_rpi_chc.current_monitor_write("fpga_1v35", 0x58)
    if not success:
        print(Colors.RED + "ERROR: Problem in writing to FPGA 1.35V current monitor" + Colors.ENDC)
        terminate()
    success = gbt_rpi_chc.current_monitor_write("fpga_2v5", 0x58)
    if not success:
        print(Colors.RED + "ERROR: Problem in writing to FPGA 2.5V current monitor" + Colors.ENDC)
        terminate()

    if args.config:
        terminate()

    # Run monitors

    # channel 0 and 1 for OH
    # channel 2 and 3 for FPGA

    resultDir = "me0_lpgbt/queso_testing/results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    current_monitor_dir = resultDir + "/current_monitor_results"
    try:
        os.makedirs(current_monitor_dir) # create directory for current monitor data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = current_monitor_dir + "/ME0_QUESO_current_monitor_data_" + now + ".csv"

    with open(filename, "w") as f:
        writer = csv.writer(f)
        writer.writerow(["oh_1v2", "oh_2v5", "fpga_1v35", "fpga_2v5"])

    print ("")
    start_time = time.time()
    time_passed = 0
    while (time_passed < (int(args.runtime) * 60)):
        oh_1v2 = readAdc(0)
        oh_2v5 = readAdc(1)
        fpga_1v35 = readAdc(2)
        fpga_2v5 = readAdc(3)
        with open(filename, "a") as f:
            writer = csv.writer(f)
            writer.writerow([oh_1v2, oh_2v5, fpga_1v35, fpga_2v5])
        print("gbt_1v2 current: %.4f A, gbt_2v5 current: %.4f A, fpga_1v35 current: %.4f A, fpga_2v5 current: %.4f A"%(oh_1v2, oh_2v5, fpga_1v35, fpga_2v5))
        time.sleep(30)
        time_passed = time.time() - start_time

    # Terminate RPi
    terminate()
