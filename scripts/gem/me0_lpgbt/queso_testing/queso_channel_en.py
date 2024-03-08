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
    parser.add_argument("-v","--vfat",action="store",nargs="+",dest="vfat",help="vfat = list of vfats to select (0, 1)")
    parser.add_argument("-l","--loopback",action="store_true", dest="loopback",help="loopback = Set enabled channel data to loopback (True) or 1's (False)")
    parser.add_argument("-c","--channel",action="store", dest="channel", help="channel = elink channel to enable (0 - 8), or \'all\'")
    args = parser.parse_args()

    if not args.fpga:
        print(Colors.YELLOW + 'Must provide an argument for `fpga`. Valid entries: [1,2,3].' + Colors.ENDC)
        sys.exit()
    fpga_list = []
    for fpga in args.fpga:
        try:
            if int(fpga) in range(1,4):
                fpga_list.append(fpga)
            else:
                print(Colors.YELLOW + 'Valid entries for `fpga`: [1,2,3].' + Colors.ENDC)
                sys.exit()
        except TypeError:
            print(Colors.RED + '`vfat` arg only accepts integer values as input.')
            sys.exit     

    if not args.vfat:
        print(Colors.YELLOW + 'Must provide an argument for `vfat`. Valid entries: [0,1].' + Colors.ENDC)
        sys.exit()
    vfat_list = []
    for vfat in args.vfat:
        try:
            if int(vfat) in range(2):
                vfat_list.append(int(vfat))
            else:
                print(Colors.YELLOW + 'Valid entries for `fpga`: [0,1].' + Colors.ENDC)
                sys.exit()
        except TypeError:
            print(Colors.RED + '`vfat` arg only accepts integer values as input.')
            sys.exit()

    if not args.channel:
        # turn all channels off
        channel_sel = 0xF # NULL value
    elif args.channel == 'all':
        channel_sel = 0xF # NULL value
    else:
        try:
            if int(args.channel) in range(9):
                channel_sel = int(args.channel)
            else:
                print(Colors.YELLOW + 'Valid entries for `channel`: [0-8] or \'all\'.' + Colors.ENDC)
                sys.exit()
            channel_sel = int(args.channel)
        except TypeError:
            print(Colors.RED + '`channel` arg only accepts integer values or \'all\' as input.')
            sys.exit()

    # Set up RPi
    gbt_rpi_chc = rpi_chc.rpi_chc()
    print ("")

    channel_en_adr = 0x04

    # Channel enable register
    # Bit 7: Enable all channels VFAT 0
    # Bit 6: Enable all channels VFAT 1
    # Bit 5: VFAT select based on VFAT ID (0,1)
    # Bit 4: loopback on (1) or set to 1's
    # Bit 3-0: Channel/ELINK select (0-8) 

    # check if all channels enabled
    vfat_en_all = 0
    if args.channel == 'all':
        for vfat in vfat_list:
            # Enable all channels
            if vfat==0:
                vfat_en_all |= 1<<1
            elif vfat==1:
                vfat_en_all |= 1

    # Loop through fpga's to enable channels
    for fpga in fpga_list:
        # Loop through vfat list to enable channels
        for vfat in vfat_list:
            if args.channel == 'all':
                print(f"Enabling all channels for { {3:'ALL VFATS',2:'VFAT 0',1:'VFAT 1'}[vfat_en_all] } with loopback { {True:'ON',False:'OFF'}[args.loopback] } in FPGA {fpga}.")
                break
            elif channel_sel == 0xF:
                print(f'Disabling all channels for VFAT {vfat} in FPGA {fpga}.')
            else:
                print(f"Enabling channel {channel_sel} with loopback { {True:'ON',False:'OFF'} } for VFAT {vfat} in FPGA {fpga}.")
            channel_en_reg = vfat_en_all | vfat << 5 | int(args.loopback) << 4 | channel_sel

            spi_success, spi_data = gbt_rpi_chc.spi_rw(fpga,channel_en_adr,channel_en_reg)
            if not spi_success:
                terminate() # err already printed out in function call
            time.sleep(0.1)

                

