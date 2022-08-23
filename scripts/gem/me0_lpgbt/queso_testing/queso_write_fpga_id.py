from os import terminal_size
import gem.me0_lpgbt.rpi_chc as rpi_chc
import time
import argparse

class Colors:
    WHITE   = "\033[97m"
    CYAN    = "\033[96m"
    MAGENTA = "\033[95m"
    BLUE    = "\033[94m"
    YELLOW  = "\033[93m"
    GREEN   = "\033[92m"
    RED     = "\033[91m"
    ENDC    = "\033[0m"

if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="Write FPGA ID to fpga")
    parser.add_argument("-f", "--fpga", action="store", nargs="+", dest="fpga", help="fpga = list of fpga to write to (1, 2, 3)")
    parser.add_argument("-i", "--id", action="store",  nargs="+", dest="id", help="id = list of id write to given fpga (in order of fpga)")
    args = parser.parse_args()

    gpio = {}
    gpio["1"] = 20
    gpio["2"] = 16
    gpio["3"] = 12

    # need to be changed after addr is decided !!!!
    fpga_reg_addr = {}
    fpga_reg_addr["1"] = 0x00
    fpga_reg_addr["2"] = 0x00
    fpga_reg_addr["3"] = 0x00

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

    for i in range(len(args.fpga)):
        # enable corresponding chip select
        spi_success = my_rpi_chc.fpga_spi_cs(gpio[args.fpga[i]], 1)
        if not spi_success:
            terminate() # err already printed out in function call

        # write the corresponding id to fpga
        spi_success = my_rpi_chc.spi_rw([fpga_reg_addr[args.fpga[i]], args.id[i]])
        if not spi_success:
            terminate() # err already printed out in function call

        # disable the chip select after finishing writing
        spi_success = my_rpi_chc.fpga_spi_cs(gpio[args.fpga[i]], 0)
        if not spi_success:
            terminate() # err already printed out in function call
            
    # terminate the RPi
    terminate()

