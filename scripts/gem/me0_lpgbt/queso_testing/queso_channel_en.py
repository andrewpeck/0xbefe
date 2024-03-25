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
    global gbt_rpi_chc
    terminate_success = gbt_rpi_chc.terminate()
    if not terminate_success:
        print(Colors.RED + "ERROR: Problem in RPi_CHC termination" + Colors.ENDC)
    sys.exit()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Enable selected channel on selected FPGA')
    parser.add_argument("-f", "--fpga", action="store", nargs="+", dest="fpga", help="fpga = list of fpga to select (1, 2, 3)")
    parser.add_argument("-v","--vfat",action="store",nargs="+",dest="vfat",help="vfat = list of vfats to enable (0, 1), disables both vfats if no arg provided.")
    parser.add_argument("-l","--loopback",action="store_true", dest="loopback",help="loopback = Set enabled channel data to loopback (True) or 1's (False)")
    parser.add_argument("-c","--channel",action="store", dest="channel", help="channel = elink channel to enable (0 - 8), or \'all\'")
    args = parser.parse_args()

    if not args.fpga:
        print(Colors.YELLOW + 'Must provide an argument for `fpga`. Valid entries: [1,2,3].' + Colors.ENDC)
        sys.exit()
    fpga_list = []
    for fpga in args.fpga:
        try:
            if int(fpga) in [1,2,3]:
                fpga_list.append(fpga)
            else:
                print(Colors.YELLOW + 'Valid entries for `fpga`: [1,2,3].' + Colors.ENDC)
                sys.exit()
        except ValueError:
            print(Colors.RED + '`vfat` arg only accepts integer values as input.')
            sys.exit

    vfat_list = []
    if args.vfat:
        for vfat in args.vfat:
            try:
                if int(vfat) in [0,1]:
                    vfat_list.append(int(vfat))
                else:
                    print(Colors.YELLOW + 'Valid entries for `vfat`: [0,1].' + Colors.ENDC)
                    sys.exit()
            except ValueError:
                print(Colors.RED + '`vfat` arg only accepts integer values as input.')
                sys.exit()


    # Channel enable register mapping
    # -------------------------------
    # Bit 7: Enable VFAT 1
    # Bit 6: Enable VFAT 0
    vfat_en = 0 # Disable all if no vfats provided
    if vfat_list:
        for vfat in vfat_list:
            if vfat == 1:
                vfat_en |= 1 << 1
            elif vfat == 0:
                vfat_en |= 1

    # Bit 5: loopback on (1) or set to 1's
    loopback_en = int(args.loopback)

    # Bit 4:    Enable all channels [1] or 1 channel at a time (crosstalk) [0]
    # Bits 3-0: Channel/ELINK select [0-8]

    # check if all channels enabled
    if args.channel == 'all':
        en_all = 1
        channel_sel = 0xF # NULL value
    elif args.channel is not None:
        en_all = 0
        # only accept channel values
        try:
            if int(args.channel) in range(9):
                channel_sel = int(args.channel)
            else:
                print(Colors.YELLOW + 'Valid entries for `channel`: [0-8] or \'all\'.' + Colors.ENDC)
                sys.exit()
            channel_sel = int(args.channel)
        except ValueError:
            print(Colors.RED + '`channel` arg only accepts integer values [0-8] or \'all\' as input.')
            sys.exit()
    else:
        print(Colors.YELLOW + 'No argument provided for `channel`. Defaulting to all channels on.' + Colors.ENDC)
        # Default to crosstalk off
        en_all = 1
        channel_sel = 0xF # NULL value
        # sys.exit()
    channel_en_reg = vfat_en << 6 | loopback_en << 5 | en_all << 4 | channel_sel

    # Set up RPi
    gbt_rpi_chc = rpi_chc.rpi_chc()
    channel_en_adr = 0x08

    print()
    # Loop through fpga's to enable channels
    for fpga in fpga_list:
        # Loop through vfat list to enable channels
        if vfat_en == 0:
            print(f"Disabling all channels for ALL VFATS in FPGA {fpga}.")
        elif en_all:
            print(f"Enabling all channels for { {3:'ALL VFATS',2:'VFAT 1',1:'VFAT 0'}[vfat_en] } with loopback {'ON' if args.loopback else 'OFF'} in FPGA {fpga}.")
        else:
            print(f"Enabling channel {channel_sel} for { {3:'ALL VFATS',2:'VFAT 1',1:'VFAT 0'}[vfat_en] } with loopback {'ON' if args.loopback else 'OFF'} in FPGA {fpga}.")
        
        print(f"    Writing to CHANNEL_EN_REG at SPI addr 0x{channel_en_adr:02X} = 0x{channel_en_reg:02X}")
        spi_success, spi_data = gbt_rpi_chc.spi_rw(fpga,channel_en_adr,[channel_en_reg])
        if not spi_success:
            terminate() # err already printed out in function call
        print()
    # terminate the RPi
    terminate()
