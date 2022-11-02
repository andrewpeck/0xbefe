from os import terminal_size
import gem.me0_lpgbt.rpi_chc as rpi_chc
import time
import argparse
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

if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="Write FPGA ID to fpga")
    parser.add_argument("-f", "--fpga", action="store", nargs="+", dest="fpga", help="fpga = list of fpga to write to (1, 2, 3)")
    parser.add_argument("-i", "--id", action="store",  nargs="+", dest="id", help="id = list of id write to given fpga (in order of fpga)")
    args = parser.parse_args()

    fpga_reg_addr = {}
    fpga_reg_addr["1"] = 0x02
    fpga_reg_addr["2"] = 0x02
    fpga_reg_addr["3"] = 0x02

    if args.fpga is None:
        print(Colors.YELLOW + "Please give at least one fpga to write to" + Colors.ENDC)
        sys.exit()
    for f in args.fpga:
        if f not in ["1", "2", "3"]:
            print(Colors.YELLOW + "Please give valid fpga (1, 2, 3) to write to" + Colors.ENDC)
            sys.exit()

    # Set up RPi
    global gbt_rpi_chc
    gbt_rpi_chc = rpi_chc.rpi_chc()

    for i in range(len(args.fpga)):
        
        # write the corresponding id to fpga
        print ("Writing ID (register 0x%02X) to FPGA %s = 0x%02X"%(fpga_reg_addr[args.fpga[i]]+0x01, args.fpga[i], int(args.id[i], 16)))
        spi_success, spi_data = gbt_rpi_chc.spi_rw(args.fpga[i], fpga_reg_addr[args.fpga[i]], [int(args.id[i], 16)])
        if not spi_success:
            terminate() # err already printed out in function call
        time.sleep(0.1)

        # read fpga id
        spi_success, spi_data = gbt_rpi_chc.spi_rw(args.fpga[i], fpga_reg_addr[args.fpga[i]])
        if not spi_success:
            terminate() # err already printed out in function call
        print ("ID (register 0x%02X) written to FPGA %s = 0x%02X\n"%(fpga_reg_addr[args.fpga[i]], args.fpga[i], spi_data[1]))
        time.sleep (0.1)
            
    # terminate the RPi
    terminate()

