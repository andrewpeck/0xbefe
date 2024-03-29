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

    parser = argparse.ArgumentParser(description='Enable to correspoding regulators')
    parser.add_argument("-r", "--regulators", action="store", nargs="+", dest="regulators", help="volt = 2v5 or 1v2")
    parser.add_argument("-o", "--turn_off", action="store_true", dest="turn_off", help="turn_off = turn regulator off")
    args = parser.parse_args()

    if args.regulators is None:
        print(Colors.YELLOW + "Please give at least one regulator to enable" + Colors.ENDC)
        sys.exit()
    for r in args.regulators:
        if r not in ["1v2", "2v5"]:
            print(Colors.YELLOW + "Please give valid regulator (1v2, 2v5) to reset" + Colors.ENDC)
            sys.exit()

    # Set up RPi
    global gbt_rpi_chc
    gbt_rpi_chc = rpi_chc.rpi_chc()

    regulators = {}
    regulators["1v2"] = 6
    regulators["2v5"] = 5

    for r in args.regulators:
        if not args.turn_off:
            try:
                read = gbt_rpi_chc.gpio_action("write", regulators[r], 1)
                if read != -9999:
                    print(Colors.GREEN + "GPIO %d set to high for regulator %s"%(regulators[r], r) + Colors.ENDC)
                    
                    # Turn ON Red LED of FPGAs
                    spi_success, spi_data = gbt_rpi_chc.spi_rw("1", 0x06, [0x04])
                    if not spi_success:
                        terminate() # err already printed out in function call
                    time.sleep(0.1)
                    spi_success, spi_data = gbt_rpi_chc.spi_rw("2", 0x06, [0x04])
                    if not spi_success:
                        terminate() # err already printed out in function call
                    time.sleep(0.1)
                    spi_success, spi_data = gbt_rpi_chc.spi_rw("3", 0x06, [0x04])
                    if not spi_success:
                        terminate() # err already printed out in function call
                    time.sleep(0.1)
                    print(Colors.GREEN + "RED LEDs turned ON for all 3 FPAGs" + Colors.ENDC)

                    print(Colors.GREEN + "Regulator %s ON"%r + Colors.ENDC)

                else:
                    print(Colors.RED + "ERROR: Unable to write GPIO %d to high (regulator %s)"%(regulators[r], r) + Colors.ENDC)
            except:
                print(Colors.RED + "ERROR: Unable to write GPIO %d to high (regulator %s)"%(regulators[r], r) + Colors.ENDC)
            time.sleep(0.5)
        else:
            try:
                read = gbt_rpi_chc.gpio_action("write", regulators[r], 0)
                if read != -9999:
                    print(Colors.GREEN + "GPIO %d set to low for regulator %s"%(regulators[r], r) + Colors.ENDC)

                    # Turn OFF Red LED of FPGAs
                    spi_success, spi_data = gbt_rpi_chc.spi_rw("1", 0x06, [0x00])
                    if not spi_success:
                        terminate() # err already printed out in function call
                    time.sleep(0.1)
                    spi_success, spi_data = gbt_rpi_chc.spi_rw("2", 0x06, [0x00])
                    if not spi_success:
                        terminate() # err already printed out in function call
                    time.sleep(0.1)
                    spi_success, spi_data = gbt_rpi_chc.spi_rw("3", 0x06, [0x00])
                    if not spi_success:
                        terminate() # err already printed out in function call
                    time.sleep(0.1)
                    print(Colors.GREEN + "RED LEDs turned ON for all 3 FPAGs" + Colors.ENDC)

                    print(Colors.GREEN + "Regulator %s OFF"%r + Colors.ENDC)
                else:
                    print(Colors.RED + "ERROR: Unable to write GPIO %d to low (regulator %s)"%(regulators[r], r) + Colors.ENDC)
            except:
                print(Colors.RED + "ERROR: Unable to write GPIO %d to low (regulator %s)"%(regulators[r], r) + Colors.ENDC)
            time.sleep(0.5)

    # Terminate RPi
    terminate()