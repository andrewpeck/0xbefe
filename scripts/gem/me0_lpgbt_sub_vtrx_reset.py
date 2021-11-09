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

def lpgbt_sub_reset(system, oh_ver, boss, oh_select, gbt_select, reset):
    print("Sub lpGBT or VTRx+ RESET\n")

    gpio_dirH_node = getNode("LPGBT.RWF.PIO.PIODIRH")
    gpio_outH_node = getNode("LPGBT.RWF.PIO.PIOOUTH")
    gpio_dirL_node = getNode("LPGBT.RWF.PIO.PIODIRL")
    gpio_outL_node = getNode("LPGBT.RWF.PIO.PIOOUTL")
    gpio_dirH_addr = gpio_dirH_node.address
    gpio_outH_addr = gpio_outH_node.address
    gpio_dirL_addr = gpio_dirL_node.address
    gpio_outL_addr = gpio_outL_node.address

    # Set GPIO as output
    gpio_dirH_output = 0
    gpio_dirL_output = 0
    if oh_ver == 1:
        if (boss):
            gpio_dirH_output = 0x80 | 0x01
            gpio_dirL_output = 0x01 | 0x04 # set as outputs
        else:
            gpio_dirH_output = 0x02 | 0x04 | 0x08 # set as outputs
            gpio_dirL_output = 0x00 # set as outputs
    elif oh_ver == 2:
        if (boss):
            gpio_dirH_output = 0x01 | 0x02 | 0x20 # set as outputs (8, 9, 13)
            gpio_dirL_output = 0x01 | 0x04 | 0x20 # set as outputs (0, 2, 5)
        else:
            gpio_dirH_output = 0x01 | 0x02 | 0x04 | 0x08 | 0x20 # set as outputs
            gpio_dirL_output = 0x01 | 0x02 | 0x08 # set as outputs
    
    if backend:
        mpoke(gpio_dirH_addr, gpio_dirH_output)
        mpoke(gpio_dirL_addr, gpio_dirL_output)
    else:
        writeReg(gpio_dirH_node, gpio_dirH_output, 0)
        writeReg(gpio_dirL_node, gpio_dirL_output, 0)

    print("Set GPIO as output (including GPIO 15/5 for boss lpGBT for OH-v1/v2), register: 0x%03X, value: 0x%02X" % (gpio_dirH_addr, gpio_dirH_output))
    print("Set GPIO as output, register: 0x%03X, value: 0x%02X" % (gpio_dirL_addr, gpio_dirL_output))
    sleep(0.000001)
        
    gpio = 0
    if reset == "sub":
        print ("Reset sub lpGBT\n")
        gpio = 9
    elif reset == "vtrx": 
        print ("Reset VTRx+\n")  
        gpio = 13
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

    if args.reset not in ["sub", "vtrx"]:
        print (Colors.YELLOW + "Only sub or vtrx allowed" + Colors.ENDC)
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
        lpgbt_sub_vtrx_reset(args.system, oh_ver, boss, int(args.ohid), int(args.gbtid), args.reset)
    except KeyboardInterrupt:
        print(Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print(Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
