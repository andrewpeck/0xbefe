import gem.me0_lpgbt.rpi_chc as rpi_chc
import argparse
import time
import sys

class Colors:
    WHITE   = "\033[97m"
    CYAN    = "\033[96m"
    MAGENTA = "\033[95m"
    BLUE    = "\033[94m"
    YELLOW  = "\033[93m"
    GREEN   = "\033[92m"
    RED     = "\033[91m"
    ENDC    = "\033[0m"

def terminate():
    # Terminating RPi
    terminate_success = gbt_rpi_chc.terminate()
    if not terminate_success:
        print(Colors.RED + "ERROR: Problem in RPi_CHC termination" + Colors.ENDC)
    sys.exit()

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='Check the FPGA done status')
    parser.add_argument("-f", "--fpga", action="store", nargs="+", dest="fpga", help="fpga = list of fpga to read done status (1, 2, 3)")
    args = parser.parse_args()

    if args.fpga is None:
        print(Colors.YELLOW + "Please give at least one fpga to reset" + Colors.ENDC)
        terminate()
    for f in args.fpga:
        if f not in ["1", "2", "3"]:
            print(Colors.YELLOW + "Please give valid fpga (1, 2, 3) to reset" + Colors.ENDC)
            terminate()

    # Set up RPi
    global gbt_rpi_chc
    gbt_rpi_chc = rpi_chc.rpi_chc()

    # GPIOs 
    read_gpio = {}
    read_gpio["1"] = 23
    read_gpio["2"] = 24
    read_gpio["3"] = 25

    # Read FPGA DONE
    for f in args.fpga:
        try:
            fpga_done = gbt_rpi_chc.gpio_action("read", read_gpio[f])
            if fpga_done != -9999:
                if fpga_done == 1:
                    print(Colors.GREEN + "FPGA %s done status: %d"%(f, fpga_done) + Colors.ENDC)
                else:
                    print(Colors.YELLOW + "FPGA %s done status: %d"%(f, fpga_done) + Colors.ENDC)
            else:
                print(Colors.RED + "ERROR: Status invalid FPGA %s)"%(f) + Colors.ENDC)
        except:
            print(Colors.RED + "ERROR: Unable to read from GPIO %d (fpga %s)"%(read_gpio[f], f) + Colors.ENDC)
        time.sleep(1)

    # Terminate RPi
    terminate()