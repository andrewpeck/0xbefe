from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep, time
import sys
import argparse
        
def convert_gpio_reg(gpio):
    reg_data = 0
    if gpio<=7:
        bit = gpio
    else:
        bit = gpio - 8
    reg_data |= (0x01 << bit)
    return reg_data
        
def vfat_reset(system, oh_select, vfat_list):
    print ("VFAT RESET\n")
    
    gpio_dirH_addr = 0x052
    gpio_dirL_addr = 0x053
    gpio_outH_addr = 0x054
    gpio_outL_addr = 0x055
    gpio_dirH_node = getNode("LPGBT.RWF.PIO.PIODIRH")
    gpio_dirL_node = getNode("LPGBT.RWF.PIO.PIODIRL")
    gpio_outH_node = getNode("LPGBT.RWF.PIO.PIOOUTH")
    gpio_outL_node = getNode("LPGBT.RWF.PIO.PIOOUTL")

    for vfat in vfat_list:
        gbt, gbt_select, elink, gpio = vfat_to_gbt_elink_gpio(vfat)
        print ("VFAT#: %02d, lpGBT: %s, OH: %d, GBT: %d, GPIO: %d" %(vfat, gbt, oh_select, gbt_select, gpio))
        
        boss=0
        if gbt=="boss":
            boss=1
        
        if system=="backend":
            select_ic_link(oh_select, gbt_select)
        elif system=="chc":
            config_initialize_chc(boss)
        check_lpgbt_ready()
                     
        if system!="dryrun" and system!="backend":
            check_rom_readback()

        # Set GPIO as output
        gpio_dirH_output = 0
        gpio_dirL_output = 0
        if boss:
            gpio_dirH_output = 0x80 | 0x01
            gpio_dirL_output = 0x01 | 0x04
        else:
            gpio_dirH_output = 0x02 | 0x04 | 0x08
            gpio_dirL_output = 0x00
        if system=="backend":
            mpoke(gpio_dirH_addr, gpio_dirH_output)
            mpoke(gpio_dirL_addr, gpio_dirL_output)
        else:
            writeReg(gpio_dirH_node, gpio_dirH_output, 0)
            writeReg(gpio_dirL_node, gpio_dirL_output, 0)

        print ("Set GPIO as output (including GPIO 15 for boss lpGBT), register: 0x%03X, value: 0x%02X" %(gpio_dirH_addr, gpio_dirH_output))
        print ("Set GPIO as output, register: 0x%03X, value: 0x%02X" %(gpio_dirL_addr, gpio_dirL_output))
        sleep(0.000001)

        data_enable = convert_gpio_reg(gpio)
        data_disable = 0x00
        gpio_out_addr = 0
        gpio_out_node = ""
        if gpio<=7:
            gpio_out_addr = gpio_outL_addr
            gpio_out_node = gpio_outL_node
        else:
            gpio_out_addr = gpio_outH_addr
            gpio_out_node = gpio_outH_node
            if boss:
                data_enable |= 0x80 # To keep GPIO LED on ASIAGO ON
                data_disable |= 0x80 # To keep GPIO LED on ASIAGO ON

        # Reset - 1
        if system=="backend":
            mpoke(gpio_out_addr, data_enable)
        else:
            writeReg(gpio_out_node, data_enable, 0)
        print ("Enable GPIO to reset (including GPIO 15 for boss lpGBT), register: 0x%03X, value: 0x%02X" %(gpio_out_addr, data_enable))
        sleep(0.000001) 
            
        # Reset - 0
        if system=="backend":
            mpoke(gpio_out_addr, data_disable)
        else:
            writeReg(gpio_out_node, data_disable, 0)
        print ("Disable GPIO (except GPIO 15 for boss lpGBT), register: 0x%03X, value: 0x%02X" %(gpio_out_addr, data_disable))
        sleep(0.000001) 
        
        print ("")
        
    # Link reset after VFAT reset
    gem_utils.gem_link_reset()
    sleep(0.1)
    
if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="VFAT RESET")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc, backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    #parser.add_argument("-l", "--lpgbt", action="store", dest="lpgbt", help="lpgbt = boss or sub")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number (only needed for backend)")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number (only needed for backend)")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    args = parser.parse_args()

    if args.system == "chc":
        print ("Using Rpi CHeeseCake for VFAT reset")
    elif args.system == "backend":
        print ("Using Backend for VFAT reset")
   elif args.system == "dryrun":
        print ("Dry Run - not actually doing vfat reset")
    else:
        print (Colors.YELLOW + "Only valid options: chc, backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem != "ME0":
        print(Colors.YELLOW + "Valid gem station: ME0" + Colors.ENDC)
        sys.exit()

    if args.ohid is None:
        print(Colors.YELLOW + "Need OHID" + Colors.ENDC)
        sys.exit()
    #if int(args.ohid) > 1:
    #   print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
    #   sys.exit()

    if args.vfats is None:
        print (Colors.YELLOW + "Enter VFAT numbers" + Colors.ENDC)
        sys.exit()
    vfat_list = []
    for v in args.vfats:
        v_int = int(v)
        if v_int not in range(0,24):
            print (Colors.YELLOW + "Invalid VFAT number, only allowed 0-23" + Colors.ENDC)
            sys.exit()
        vfat_list.append(v_int)
    
    if args.system == "backend" or args.system == "dryrun":
        import gem.gem_utils as gem_utils
        global gem_utils
    
    # Initialization 
    rw_initialize(args.gem, args.system, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")

    # Running Phase Scan
    try:
        vfat_reset(args.system, int(args.ohid), vfat_list)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




