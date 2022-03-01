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

def lpgbt_sub_vtrx_reset(system, oh_ver, boss, oh_select, gbt_select, reset):
    print("Sub lpGBT or VTRx+ RESET\n")

    gpio_dirH_node = getNode("LPGBT.RWF.PIO.PIODIRH")
    gpio_outH_node = getNode("LPGBT.RWF.PIO.PIOOUTH")
    gpio_dirL_node = getNode("LPGBT.RWF.PIO.PIODIRL")
    gpio_outL_node = getNode("LPGBT.RWF.PIO.PIOOUTL")
    gpio_dirH_addr = gpio_dirH_node.address
    gpio_outH_addr = gpio_outH_node.address
    gpio_dirL_addr = gpio_dirL_node.address
    gpio_outL_addr = gpio_outL_node.address

    gpio = 0
    if reset == "vtrx":
        print("VTRx+ RESET\n")
        gpio  = 13
    elif reset == "sub":
        print("SUB RESET\n")
        gpio = 9

    dir_enable = convert_gpio_reg(gpio)
    dir_disable = 0x00
    data_enable = convert_gpio_reg(gpio)
    data_disable = 0x00
    gpio_dir_addr = 0
    gpio_dir_node = ""
    gpio_out_addr = 0
    gpio_out_node = ""

    # These 2 resets are only for OH-v2
    if gpio <= 7:
        gpio_dir_addr = gpio_dirL_addr
        gpio_dir_node = gpio_dirL_node
        gpio_out_addr = gpio_outL_addr
        gpio_out_node = gpio_outL_node
        if boss:
            dir_enable |= 0x20  # To keep GPIO LED on ASIAGO output enabled
            dir_disable |= 0x20  # To keep GPIO LED on ASIAGO output enabled
            #data_enable |= 0x20  # To keep GPIO LED on ASIAGO ON
            data_disable |= 0x20  # To keep GPIO LED on ASIAGO ON
        else:
            dir_enable |= 0x01 | 0x02 | 0x08  # To keep GPIO LED on ASIAGO output enabled
            dir_disable |= 0x01 | 0x02 | 0x08  # To keep GPIO LED on ASIAGO output enabled
            #data_enable |= 0x00
            data_disable |= 0x00
    else:
        gpio_dir_addr = gpio_dirH_addr
        gpio_dir_node = gpio_dirH_node
        gpio_out_addr = gpio_outH_addr
        gpio_out_node = gpio_outH_node
        if not boss:
            dir_enable |= 0x01 | 0x20  # To keep GPIO LED on ASIAGO output enabled
            dir_disable |= 0x01 | 0x20  # To keep GPIO LED on ASIAGO output enabled
            #data_enable |= 0x00
            data_disable |= 0x00

    # Enable GPIO as output
    writeReg(gpio_dir_node, dir_enable, 0)
    print("Enable GPIO %d as output"%gpio)
    sleep(0.000001)

    # Set GPIO to 0 for reset
    writeReg(gpio_out_node, data_disable, 0)
    print("Set GPIO %d to 0 for reset"%gpio)
    sleep(0.1)

    # Disable GPIO as output
    writeReg(gpio_dir_node, dir_disable, 0)
    print("Disable GPIO %d as output"%gpio)
    sleep(0.000001)

    print("")

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Sub lpGBT or VTRx+ RESET")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-r", "--reset", action="store", dest="reset", help="reset = sub or vtrx")
    
    args = parser.parse_args()

    if args.system == "chc":
        print("Using Rpi CHeeseCake for sub lpGBT or VTRx+ reset")
    elif args.system == "backend":
        print ("Using Backend for sub lpGBT or VTRx+ reset")
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

    if args.reset not in ["sub", "vtrx"]:
        print (Colors.YELLOW + "Only sub or vtrx allowed" + Colors.ENDC)
        sys.exit() 

    # Initialization 
    rw_initialize(args.gem, args.system, oh_ver, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun":
        check_rom_readback(args.ohid, args.gbtid)
        check_lpgbt_mode(boss, args.ohid, args.gbtid)

    # Check if GBT is READY
    check_lpgbt_ready(args.ohid, args.gbtid)

    try:
        lpgbt_sub_vtrx_reset(args.system, oh_ver, boss, int(args.ohid), int(args.gbtid), args.reset)
    except KeyboardInterrupt:
        print(Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
