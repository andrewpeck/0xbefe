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

    parser = argparse.ArgumentParser(description='Enable to correspoding regulators')
    parser.add_argument("-r", "--regulators", action="store", nargs="+", dest="regulators", help="volt = 2v5 or 1v2")
    parser.add_argument("-o", "--turn_off", action="store_true", dest="turn_off", help="turn_off = turn regulator off")
    args = parser.parse_args()

    if args.regulators is None:
        print(Colors.YELLOW + "Please give at least one regulator to enable" + Colors.ENDC)
        terminate()
    for r in args.regulators:
        if r not in ["1v2", "2v5"]:
            print(Colors.YELLOW + "Please give valid regulator (1v2, 2v5) to reset" + Colors.ENDC)
            terminate()

    # Set up RPi
    global my_rpi_chc
    my_rpi_chc = rpi_chc.rpi_chc()

    regulators = {}
    regulators["1v2"] = 6
    regulators["2v5"] = 5

    for r in args.regulators:
        if not args.turn_off:
            try:
                read = my_rpi_chc.gpio_action("write", regulators[r], 0)
                if read != -9999:
                    print(Colors.GREEN + "GPIO %d set to low for regulator %s"%(regulators[r], r) + Colors.ENDC)
                    print(Colors.GREEN + "Regulator %s ON"%r + Colors.ENDC)
                else:
                    print(Colors.RED + "ERROR: Unable to write GPIO %d to low (regulator %s)"%(regulators[r], r) + Colors.ENDC)
            except:
                print(Colors.RED + "ERROR: Unable to write GPIO %d to low (regulator %s)"%(regulators[r], r) + Colors.ENDC)
            time.sleep(0.5)
        else:
            try:
                read = my_rpi_chc.gpio_action("write", regulators[r], 1)
                if read != -9999:
                    print(Colors.GREEN + "GPIO %d set to high for regulator %s"%(regulators[r], r) + Colors.ENDC)
                    print(Colors.GREEN + "Regulator %s OFF"%r + Colors.ENDC)
                else:
                    print(Colors.RED + "ERROR: Unable to write GPIO %d to high (regulator %s)"%(regulators[r], r) + Colors.ENDC)
            except:
                print(Colors.RED + "ERROR: Unable to write GPIO %d to high (regulator %s)"%(regulators[r], r) + Colors.ENDC)
            time.sleep(0.5)

    # Terminate RPi
    terminate()