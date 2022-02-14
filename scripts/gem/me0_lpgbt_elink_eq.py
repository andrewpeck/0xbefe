from gem.me0_lpgbt.rw_reg_lpgbt import *
import gem.gem_utils as gem_utils
from time import sleep
import sys
import argparse

def get_elink_group_channel(elink):
    group = -9999
    channel = -9999
    group = int(elink/4)
    channel = elink%4
    return group, channel

def set_eq_setting(elink, eq0, eq1):
    group, channel = get_elink_group_channel(elink)
    writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX%d%dEQ0"%(group, channel)), eq0, 0)
    writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX%dEQ1"%elink), eq1, 0)

def main(system, oh_select, vfat_list, sbit_elink_list, daq, eq):

    eq_setting0 = 0
    eq_setting1 = 0
    if eq == 1:
        eq_setting0 = 1
    elif eq == 2:
        eq_setting1 = 1
    elif eq == 3:
        eq_setting0 = 1
        eq_setting1 = 1

    print ("Setting Equalization Settings for: \n")
    for vfat in vfat_list:
        print ("  VFAT %02d: ")
        gbt, gbt_select, elink, gpio = gem_utils.me0_vfat_to_gbt_elink_gpio(vfat)
        sbit_elinks = gem_utils.me0_vfat_to_sbit_elink(vfat)
        oh_ver = get_oh_ver(oh_select, gbt_select)
        select_ic_link(oh_select, gbt_select)
        gem_utils.check_gbt_link_ready(oh_select, gbt_select)

        if daq:
            set_eq_setting(elink, eq_setting0, eq_setting1)
            print ("    For DAQ Elink: %d"%eq)
        for sbit_elink in sbit_elink_list:
            set_eq_setting(sbit_elinks[sbit_elink], eq_setting0, eq_setting1)
            print ("    For Sbit Elink %d: %d"%(sbit_elink,eq))
        print ("")

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Setting Elink Equalization settings of lpGBT for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-e", "--sbit", action="store", nargs="+", dest="sbit", help="sbit = list of SBIT elinks to set (0-7)")
    parser.add_argument("-d", "--daq", action="store_true", dest="daq", help="whether to set for the DAQ elink")
    parser.add_argument("-q", "--eq", action="store", dest="eq", help="eq = equalization setting (0, 1, 2, 3)")
    args = parser.parse_args()

    if args.system == "chc":
        print ("Using Rpi CHeeseCake for status check")
    elif args.system == "backend":
        print ("Using Backend for status check")
    elif args.system == "dryrun":
        print ("Dry Run - not actually checking status of lpGBT")
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
    #    print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
    #    sys.exit()
    
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

    sbit_elink_list = []
    for s in args.sbit:
        s_int = int(args.sbit)
        if s_int not in range(0,8):
            print (Colors.YELLOW + "Invalid SBIT ELINK number, only allowed 0-7" + Colors.ENDC)
            sys.exit()
        sbit_elink_list.append(s_int)

    if args.sbit is None and not daq:
        print (Colors.YELLOW + "Enter at least Sbit elink or DAQ elink" + Colors.ENDC)
        sys.exit()

    if int(args.eq) not in range(0,3):
        print (Colors.YELLOW + "Invalid equalization setting, only allowed 0-3" + Colors.ENDC)
        sys.exit()

    # Initialization 
    rw_initialize(args.gem, args.system)
    print("Initialization Done\n")
        
    try:
        main(args.system, int(args.ohid), vfat_list, sbit_elink_list, args.daq, int(args.eq))
    except KeyboardInterrupt:
        print (Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()



