import gem.me0_lpgbt.rpi_chc as rpi_chc
import argparse
import time

class Colors:
    WHITE   = "\033[97m"
    CYAN    = "\033[96m"
    MAGENTA = "\033[95m"
    BLUE    = "\033[94m"
    YELLOW  = "\033[93m"
    GREEN   = "\033[92m"
    RED     = "\033[91m"
    ENDC    = "\033[0m"

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
    global my_rpi_chc
    my_rpi_chc = rpi_chc.rpi_chc()

    # GPIOs 
    read_gpio = {}
    read_gpio["1"] = 23
    read_gpio["2"] = 24
    read_gpio["3"] = 25

    # Read FPGA DONE
    for f in args.fpga:
        try:
            fpga_done = my_rpi_chc.gpio_action("read", read_gpio[f])
            print("FPGA %s done status:",%(f, fpga_done))
        except:
            print("Unable to read from GPIO %d to low (fpga %s)"%(read_gpio[f], f))
        time.sleep(1)

    # Terminate RPi
    terminate()