from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep, time
import sys
import argparse

def convert_gpio_reg(gpio):
    reg_data = 0
    if gpio <= 7:
        bit = gpio
    else:
        bit = gpio - 8
    reg_data |= (0x01 << bit)
    return reg_data

def lpgbt_sub_reset(system, oh_ver, oh_select, gbt_select):
    print("Sub lpGBT or VTRx+ RESET\n")

    gpio_dirH_node = getNode("LPGBT.RWF.PIO.PIODIRH")
    gpio_outH_node = getNode("LPGBT.RWF.PIO.PIOOUTH")

    gpio_dirH_addr = gpio_dirH_node.address
    gpio_outH_addr = gpio_outH_node.address

    gpio = 9
    boss = 1

    # Set GPIO as output
    gpio_dirH_output = 0x02

    if system == "backend":
        mpoke(gpio_dirH_addr, gpio_dirH_output)
    else:
        writeReg(gpio_dirH_node, gpio_dirH_output, 0)

    print("Set GPIO as output, register: 0x%03X, value: 0x%02X" % (gpio_dirH_addr, gpio_dirH_output))
    sleep(0.000001)

    data_enable = convert_gpio_reg(gpio)
    data_disable = 0x00

    gpio_out_addr = gpio_outH_addr
    gpio_out_node = gpio_outH_node

    # Reset - 1
    if system == "backend":
        mpoke(gpio_out_addr, data_enable)
    else:
        writeReg(gpio_out_node, data_enable, 0)
    print("Enable GPIO to reset, register: 0x%03X, value: 0x%02X" % (gpio_out_addr, data_enable))
    sleep(0.000001)

    # Reset - 0
    if system == "backend":
        mpoke(gpio_out_addr, data_disable)
    else:
        writeReg(gpio_out_node, data_disable, 0)
    print("Disable GPIO, register: 0x%03X, value: 0x%02X" % (gpio_out_addr, data_disable))
    sleep(0.000001)

    print("")

    vfat_oh_link_reset()
    sleep(0.1)


if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Sub lpGBT or VTRx+ RESET")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    
    args = parser.parse_args()

    if args.system == "chc":
        print("Using Rpi CHeeseCake for sub lpGBT or VTRx+ reset")
    elif args.system == "backend":
        # print ("Using Backend for sub lpGBT or VTRx+ reset")
        print(Colors.YELLOW + "Only chc (Rpi Cheesecake) or dryrun supported at the moment" + Colors.ENDC)
        sys.exit()
    elif args.system == "dryrun":
        print("Dry Run - not actually doing sub lpGBT or VTRx+ reset")
    else:
        print(Colors.YELLOW + "Only valid options: chc, backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem != "ME0":
        print(Colors.YELLOW + "Valid gem station: ME0" + Colors.ENDC)
        sys.exit()

    if args.ohid is None:
        print(Colors.YELLOW + "Need OHID" + Colors.ENDC)
        sys.exit()
    #if int(args.ohid) > 1:
    #    print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
    #    sys.exit()
    
    if args.gbtid is None:
        print(Colors.YELLOW + "Need GBTID" + Colors.ENDC)
        sys.exit()
    if int(args.gbtid) > 7:
        print(Colors.YELLOW + "Only GBTID 0-7 allowed" + Colors.ENDC)
        sys.exit()
    
    oh_ver = get_oh_ver(args.ohid, args.gbtid)
    if oh_ver == 1:
        print(Colors.YELLOW + "Only OH-v2 is allowed" + Colors.ENDC)
    boss = None
    if int(args.gbtid)%2 == 0:
        boss = 1
    else:
        boss = 0
    if not boss:
        print (Colors.YELLOW + "Only boss lpGBT allowed" + Colors.ENDC)
        sys.exit()

    # Initialization 
    rw_initialize(args.gem, args.system, oh_ver, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun" and args.system != "backend":
        check_rom_readback(args.ohid, args.gbtid)
        check_lpgbt_mode(boss, args.ohid, args.gbtid)

    # Check if GBT is READY
    check_lpgbt_ready(args.ohid, args.gbtid)

    try:
        lpgbt_sub_vtrx_reset(args.system, oh_ver, int(args.ohid), int(args.gbtid))
    except KeyboardInterrupt:
        print(Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
