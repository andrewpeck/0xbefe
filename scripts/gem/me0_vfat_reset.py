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
        
def vfat_reset(system, oh_select, vfat_list):
    print ("VFAT RESET\n")
    
    # Check VFAT mode before reset
    gem_utils.gem_link_reset()
    sleep(0.1)
    mode_before_reset = {}
    for vfat in vfat_list:
        mode_before_reset[vfat] = gem_utils.read_backend_reg(gem_utils.get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN" % (oh_select, vfat)))

    for vfat in vfat_list:
        gbt, gbt_select, elink, gpio = gem_utils.me0_vfat_to_gbt_elink_gpio(vfat)
        oh_ver = get_oh_ver(oh_select, gbt_select)
        print ("VFAT#: %02d, lpGBT: %s, OH: %d, GBT: %d, GPIO: %d" %(vfat, gbt, oh_select, gbt_select, gpio))
        
        if oh_ver == 1:
            gpio_dirH_addr = 0x052
            gpio_dirL_addr = 0x053
            gpio_outH_addr = 0x054
            gpio_outL_addr = 0x055
        elif oh_ver == 2:
            gpio_dirH_addr = 0x053
            gpio_dirL_addr = 0x054
            gpio_outH_addr = 0x055
            gpio_outL_addr = 0x056
        
        boss=0
        if gbt=="boss":
            boss=1
        
        if system=="backend":
            select_ic_link(oh_select, gbt_select)
        elif system=="chc":
            config_initialize_chc(oh_ver, boss)
        if system!="dryrun":
            if oh_ver == 1:
                if mpeek(0x1c7)!=18:
                    print (Colors.RED + "ERROR: lpGBT is not READY, configure lpGBT first" + Colors.ENDC)
                    rw_terminate()
                if mpeek(0x1c5)!=0xA5:
                    print (Colors.RED + "ERROR: no communication with LPGBT. ROMREG=0x%x, EXPECT=0x%x" % (romreg, 0xA5) + Colors.ENDC)
                    rw_terminate()
            elif oh_ver == 2:
                if mpeek(0x1d9)!=19:
                    print (Colors.RED + "ERROR: lpGBT is not READY, configure lpGBT first" + Colors.ENDC)
                    rw_terminate()
                if mpeek(0x1d7)!=0xA6:
                    print (Colors.RED + "ERROR: no communication with LPGBT. ROMREG=0x%x, EXPECT=0x%x" % (romreg, 0xA5) + Colors.ENDC)
                    rw_terminate()

        #dir_enable = convert_gpio_reg(gpio)
        #dir_disable = 0x00
        data_enable = convert_gpio_reg(gpio)
        data_disable = 0x00
        #gpio_dir_addr = 0
        gpio_out_addr = 0

        if oh_ver == 1:
            if gpio <= 7:
                #gpio_dir_addr = gpio_dirL_addr
                gpio_out_addr = gpio_outL_addr
            else:
                #gpio_dir_addr = gpio_dirH_addr
                gpio_out_addr = gpio_outH_addr
                if boss:
                    #dir_enable |= 0x80  # To keep GPIO LED on ASIAGO output enabled
                    #dir_disable |= 0x80  # To keep GPIO LED on ASIAGO output enabled
                    data_enable |= 0x80  # To keep GPIO LED on ASIAGO ON
                    data_disable |= 0x80  # To keep GPIO LED on ASIAGO ON
        elif oh_ver == 2:
            if gpio <= 7:
                #gpio_dir_addr = gpio_dirL_addr
                gpio_out_addr = gpio_outL_addr
                if boss:
                    #dir_enable |= 0x20  # To keep GPIO LED on ASIAGO output enabled
                    #dir_disable |= 0x20  # To keep GPIO LED on ASIAGO output enabled
                    data_enable |= 0x20  # To keep GPIO LED on ASIAGO ON
                    data_disable |= 0x20  # To keep GPIO LED on ASIAGO ON
                else:
                    #dir_enable |= (0x01 | 0x02 | 0x08)  # To keep GPIO LED on ASIAGO output enabled
                    #dir_disable |= (0x01 | 0x02 | 0x08)  # To keep GPIO LED on ASIAGO output enabled
                    data_enable |= 0x00
                    data_disable |= 0x00
            else:
                #gpio_dir_addr = gpio_dirH_addr
                gpio_out_addr = gpio_outH_addr
                if boss:
                    data_enable |= (0x02 | 0x20) # Keep the sub lpGBT and VTRx+ to high (no reset state)
                    data_disable |= (0x02 | 0x20) # Keep the sub lpGBT and VTRx+ to high (no reset state)
                else:
                    #dir_enable |= (0x01 | 0x20)  # To keep GPIO LED on ASIAGO output enabled
                    #dir_disable |= (0x01 | 0x20)  # To keep GPIO LED on ASIAGO output enabled
                    data_enable |= 0x00
                    data_disable |= 0x00

        # Enable GPIO as output
        #mpoke(gpio_dir_addr, dir_enable)
        #print("Enable GPIO %d as output"%gpio)
        #sleep(0.000001)

        # Set GPIO to 1 for VFAT reset
        mpoke(gpio_out_addr, data_enable)
        print("Set GPIO %d to 1 for VFAT reset"%gpio)
        sleep(0.1)

        # Set GPIO back to 0
        mpoke(gpio_out_addr, data_disable)
        print("Set GPIO %d back to 0"%gpio)
        sleep(0.1)

        # Disable GPIO as output
        #mpoke(gpio_dir_addr, dir_disable)
        #print("Disable GPIO %d as output"%gpio)
        #sleep(0.000001)
        
        print ("")
        
    # Check VFAT mode before reset
    gem_utils.gem_link_reset()
    sleep(0.1)
    mode_after_reset = {}
    for vfat in vfat_list:
        mode_after_reset[vfat] = gem_utils.read_backend_reg(gem_utils.get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN" % (oh_select, vfat)))

    for vfat in vfat_list:
        print_string = ""
        if mode_after_reset[vfat] != 0:
            print_string += (Colors.RED)
        else:
            print_string += Colors.GREEN
        print_string += "VFAT# %02d: "%(vfat)
        if mode_after_reset[vfat] != 0:
            print_string += "ERROR - VFAT Reset did not work, VFAT still in RUN mode"
        else:
            if mode_before_reset[vfat] == 0:
                print_string += "VFAT was already in SLEEP mode before RESET, in SLEEP mode after RESET"
            else:
                print_string += "VFAT RESET from RUN mode to SLEEP mode"

        print_string += Colors.ENDC 
        print (print_string)
    print ("")

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="VFAT RESET")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc, queso, backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    args = parser.parse_args()

    if args.system == "chc":
        print ("Using Rpi CHeeseCake for VFAT reset")
    elif args.system == "queso":
        print("Using QUESO for VFAT reset")
    elif args.system == "backend":
        print ("Using Backend for VFAT reset")
    elif args.system == "dryrun":
        print ("Dry Run - not actually doing vfat reset")
    else:
        print (Colors.YELLOW + "Only valid options: chc, queso, backend, dryrun" + Colors.ENDC)
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
    rw_initialize(args.gem, args.system)
    print("Initialization Done\n")

    # Running VFAT Reset
    try:
        vfat_reset(args.system, int(args.ohid), vfat_list)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()




