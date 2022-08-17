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

def terminate():
    # Terminating RPi
    terminate_success = gbt_rpi_chc.terminate()
    if not terminate_success:
        print(Colors.RED + "ERROR: Problem in RPi_CHC termination" + Colors.ENDC)
        sys.exit()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Reset the selected FPGA')
    parser.add_argument("-f", "--fpga", action="store", nargs="+", dest="fpga", help="fpga = list of fpga to reset (1, 2, 3)")
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
    reset_gpio = {}
    reset_gpio["1"] = 18
    reset_gpio["2"] = 27
    reset_gpio["3"] = 22

    # Reset FPGA
    for f in args.fpga:
        try:
            my_rpi_chc.gpio_action("write", reset_gpio[f], 1)
        except:
            print("unable to write GPIO %d to high (fpga %s)"%(reset_gpio[f], f))
        time.sleep(1)
        try:
            my_rpi_chc.gpio_action("write", reset_gpio[f], 0)
        except:
            print("unable to write GPIO %d to low (fpga %s)"%(reset_gpio[f], f))
        time.sleep(1)

    # Terminate RPi
    terminate()




