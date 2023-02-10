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
    parser = argparse.ArgumentParser(description='Initialize/Terminate RPI GPIOs for QUESO')
    parser.add_argument("-o", "--off", action="store_true", dest="off", help="off = turn off")
    args = parser.parse_args()

    # Set up RPi
    global gbt_rpi_chc
    gbt_rpi_chc = rpi_chc.rpi_chc()

    # Initialize GPIOs
    if not args.off:
        gpio_output_list = []
        gpio_input_list = []

        # Set GPIO controlling regulators to OUT 
        gpio_output_list.append(6)
        gpio_output_list.append(5)

        # Set GPIO for FPGA reset to OUT
        gpio_output_list.append(18)
        gpio_output_list.append(27)
        gpio_output_list.append(22)

        # Set GPIO for FPGA Chip Enable to OUT
        gpio_output_list.append(20)
        gpio_output_list.append(16)
        gpio_output_list.append(12)

        # Set GPIO for FPGA DONE read to IN
        gpio_input_list.append(23)
        gpio_input_list.append(24)
        gpio_input_list.append(25)

        for gpio in gpio_output_list:
            init_success = gbt_rpi_chc.init_gpio(gpio, "out")
            if init_success:
                print (Colors.GREEN + "GPIO %d initialized to state OUT"%gpio + Colors.ENDC)
            else:
                print (Colors.RED + "ERROR: GPIO %d could not be initialized"%gpio + Colors.ENDC)
                terminate()

        for gpio in gpio_input_list:
            init_success = gbt_rpi_chc.init_gpio(gpio, "in")
            if init_success:
                print (Colors.GREEN + "GPIO %d initialized to state IN"%gpio + Colors.ENDC)
            else:
                print (Colors.RED + "ERROR: GPIO %d could not be initialized"%gpio + Colors.ENDC)
                terminate()

    # Terminate GPIOs
    if args.off:
       gbt_rpi_chc.gpio_terminate()

    # Terminate RPi
    terminate()

