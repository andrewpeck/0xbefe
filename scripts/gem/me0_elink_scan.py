from gem.me0_lpgbt.rw_reg_lpgbt import *
import gem.gem_utils as gem_utils
from time import sleep, time
import sys
import argparse

config_boss_filename = "../resources/me0_boss_config.txt"
config_sub_filename = "../resources/me0_sub_config.txt"
config_boss = {}
config_sub = {}

def getConfig (filename):
    f = open(filename, "r")
    reg_map = {}
    for line in f.readlines():
        reg = int(line.split()[0], 16)
        data = int(line.split()[1], 16)
        reg_map[reg] = data
    f.close()
    return reg_map

def me0_elink_scan(system, oh_select, vfat_list):
    print ("ME0 Elink Scan")

    n_err_vfat_elink = {}
    for vfat in vfat_list: # Loop over all vfats
        n_err_vfat_elink[vfat] = {}
        for elink in range(0,28): # Loop for all 28 RX elinks
            print ("VFAT%02d , ELINK %02d" % (vfat, elink))
            # Disable RX elink under test
            setVfatRxEnable(system, oh_select, vfat, 0, elink)

            # Reset the link, give some time to accumulate any sync errors and then check VFAT comms
            sleep(0.1)
            gem_utils.gem_link_reset()
            sleep(0.001)

            gbt, gbt_select, elink_old, gpio = gem_utils.vfat_to_gbt_elink_gpio(vfat)
            gem_utils.check_gbt_link_ready(oh_select, gbt_select)

            hwid_node = gem_utils.get_backend_node("BEFE.GEM_AMC.OH.OH%d.GEB.VFAT%d.HW_ID" % (oh_select, vfat))
            n_err = 0
            for iread in range(10):
                hwid = gem_utils.simple_read_backend_reg(hwid_node, -9999)
                if hwid==-9999:
                    n_err+=1
            n_err_vfat_elink[vfat][elink] = n_err

            setVfatRxEnable(system, oh_select, vfat, 1, elink)
        print ("")

    sleep(0.1)
    gem_utils.gem_link_reset()

    print ("Elink mapping results: \n")
    for vfat in vfat_list:
        for elink in range(0,28):
            sys.stdout.write("VFAT%02d , ELINK %02d:" % (vfat, elink))
            if n_err_vfat_elink[vfat][elink]==10:
                char=Colors.GREEN + "+\n" + Colors.ENDC
            else:
                char=Colors.RED + "-\n" + Colors.ENDC
            sys.stdout.write("%s" % char)
            sys.stdout.flush()
        print ("")

def setVfatRxEnable(system, oh_select, vfat, enable, elink):
    gbt, gbt_select, elink_old, gpio = gem_utils.vfat_to_gbt_elink_gpio(vfat)

    if lpgbt == "boss":
        config = config_boss
    elif lpgbt == "sub":
        config = config_sub

    # disable/enable channel
    GBT_ELINK_SAMPLE_ENABLE_BASE_REG = 0x0C4
    addr = GBT_ELINK_SAMPLE_ENABLE_BASE_REG + elink/4
    bit = 4 + elink%4
    mask = (1 << bit)
    value = (config[addr] & (~mask)) | (enable << bit)

    gem_utils.check_gbt_link_ready(oh_select, gbt_select)
    select_ic_link(oh_select, gbt_select)
    if system!= "dryrun" and system!= "backend":
        check_rom_readback()
    mpoke(addr, value)
    sleep(0.000001) # writing too fast for CVP13

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 Elink Scan for each VFAT")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    #parser.add_argument("-l", "--lpgbt", action="store", dest="lpgbt", help="lpgbt = boss or sub")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number (only needed for backend)")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number (only needed for backend)")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for Elink Scan")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running elink scan")
    else:
        print (Colors.YELLOW + "Only valid options: backend, dryrun" + Colors.ENDC)
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

    # Initialization 
    rw_initialize(args.gem, args.system)
    print("Initialization Done\n")

    if not os.path.isfile(config_boss_filename):
        print (Colors.YELLOW + "Missing config file for boss: config_boss.txt" + Colors.ENDC)
        sys.exit()
    
    if not os.path.isfile(config_sub_filename):
        print (Colors.YELLOW + "Missing config file for sub: sub_boss.txt" + Colors.ENDC)
        sys.exit()

    config_boss = getConfig(config_boss_filename)
    config_sub  = getConfig(config_sub_filename)
    
    # Running Phase Scan
    try:
        me0_elink_scan(args.system, int(args.ohid), vfat_list)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()




