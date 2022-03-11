from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse
import random
import glob
import json
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel

s_bit_channel_mapping = {}
print ("")
if not os.path.isdir("results/vfat_data/vfat_sbit_mapping_results"):
    print (Colors.YELLOW + "Run the S-bit mapping first" + Colors.ENDC)
    sys.exit()
list_of_files = glob.glob("results/vfat_data/vfat_sbit_mapping_results/*.py")
if len(list_of_files)==0:
    print (Colors.YELLOW + "Run the S-bit mapping first" + Colors.ENDC)
    sys.exit()
elif len(list_of_files)>1:
    print ("Mutliple S-bit mapping results found, using latest file")
latest_file = max(list_of_files, key=os.path.getctime)
print ("Using S-bit mapping file: %s\n"%(latest_file.split("results/vfat_data/vfat_sbit_mapping_results/")[1]))
with open(latest_file) as input_file:
    s_bit_channel_mapping = json.load(input_file)


def vfat_sbit(gem, system, oh_select, vfat_list, set_cal_mode, cal_dac, nl1a, calpulse_only, l1a_bxgap):

    resultDir = "results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    vfatDir = "results/vfat_data"
    try:
        os.makedirs(vfatDir) # create directory for VFAT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = "results/vfat_data/vfat_sbit_crosstalk_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/%s_OH%d_vfat_sbit_crosstalk_"%(gem,oh_select) + now + "_data.txt"
    file_out = open(filename,"w+")
    file_out.write("vfat    channel_inj    channel_read    fired    events\n")

    gem_link_reset()
    global_reset()
    sleep(0.1)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)

    sbit_data = {}
    cal_mode = {}
    channel_list = range(0,128)
    # Check ready and get nodes
    for vfat in vfat_list:
        gbt, gbt_select, elink, gpio = me0_vfat_to_gbt_elink_gpio(vfat)
        check_gbt_link_ready(oh_select, gbt_select)

        print("Configuring VFAT %d" % (vfat))
        configureVfat(1, vfat, oh_select, 0)
        if set_cal_mode == "voltage":
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"% (oh_select, vfat)), 1)
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"% (oh_select, vfat)), 200)
        elif set_cal_mode == "current":
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"% (oh_select, vfat)), 2)
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"% (oh_select, vfat)), 0)
        else:
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"% (oh_select, vfat)), 0)
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"% (oh_select, vfat)), 0)
            
        for channel in channel_list:
            enableVfatchannel(vfat, oh_select, channel, 0, 0) # unmask all channels and disable calpulsing
        cal_mode[vfat] = read_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"% (oh_select, vfat)))

        link_good_node = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat))
        sync_error_node = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat))
        link_good = read_backend_reg(link_good_node)
        sync_err = read_backend_reg(sync_error_node)
        if system!="dryrun" and (link_good == 0 or sync_err > 0):
            print (Colors.RED + "Link is bad for VFAT# %02d"%(vfat) + Colors.ENDC)
            terminate()

        sbit_data[vfat] = {}
        for channel_inj in channel_list:
            sbit_data[vfat][channel_inj] = {}
            for channel_read in channel_list:
                sbit_data[vfat][channel_inj][channel_read] = {}
                sbit_data[vfat][channel_inj][channel_read]["events"] = -9999
                sbit_data[vfat][channel_inj][channel_read]["fired"] = -9999

    sleep(1)

    # Configure TTC generator
    #write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.SINGLE_HARD_RESET"), 1)
    ttc_cnt_reset_node = get_backend_node("BEFE.GEM.TTC.CTRL.MODULE_RESET")
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
    if calpulse_only:
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 0)
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE_CALPULSE_ONLY"), 1)
    else:
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 1)
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE_CALPULSE_ONLY"), 0)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_GAP"), l1a_bxgap)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_COUNT"), nl1a)
    if l1a_bxgap >= 40:
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 25)
    else:
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 2)

    ttc_reset_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET")
    ttc_cyclic_start_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START")
    cyclic_running_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_RUNNING")
    calpulse_node = get_backend_node("BEFE.GEM.TTC.CMD_COUNTERS.CALPULSE")
    
    # Nodes for Sbit counters
    vfat_sbit_select_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_VFAT_SBIT_ME0") # VFAT for reading S-bits
    elink_sbit_select_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_ELINK_SBIT_ME0") # Node for selecting Elink to count
    channel_sbit_select_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_SBIT_ME0") # Node for selecting S-bit to count
    elink_sbit_counter_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SBIT0XE_COUNT_ME0") # S-bit counter for elink
    channel_sbit_counter_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SBIT0XS_COUNT_ME0") # S-bit counter for specific channel
    reset_sbit_counter_node = get_backend_node("BEFE.GEM.SBIT_ME0.CTRL.SBIT_TEST_RESET")  # To reset all S-bit counters

    dac = "CFG_CAL_DAC"
    for vfat in vfat_list:
        write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%d.%s"%(oh_select, vfat, dac)), cal_dac)

    print ("\nRunning Sbit Crosstalk Scans for %.2e L1A cycles for VFATs:" % (nl1a))
    print (vfat_list)
    print ("")

    # Looping over VFATs
    for vfat in vfat_list:
        # Looping over channels to be injected
        for channel_inj in channel_list:
            print ("VFAT: %02d, Channel Injected: %d"%(vfat, channel_inj))
            enableVfatchannel(vfat, oh_select, channel_inj, 0, 1) # enable calpulsing
            write_backend_reg(vfat_sbit_select_node, vfat)

            # Looping over channels to be read
            for channel_read in channel_list:
                elink = int(channel_read/16)
                if str(vfat) not in s_bit_channel_mapping:
                    print (Colors.YELLOW + "    Mapping not present for VFAT %02d"%(vfat) + Colors.ENDC)
                    continue
                if s_bit_channel_mapping[str(vfat)][str(elink)][str(channel_read)] == -9999:
                    print (Colors.YELLOW + "    Bad channel (from S-bit mapping) %02d on VFAT %02d"%(channel_read,vfat) + Colors.ENDC)
                    continue
                write_backend_reg(channel_sbit_select_node, s_bit_channel_mapping[str(vfat)][str(elink)][str(channel_read)])

                # Start the cyclic generator
                write_backend_reg(ttc_cnt_reset_node, 1)
                write_backend_reg(reset_sbit_counter_node, 1)
                write_backend_reg(ttc_cyclic_start_node, 1)
                cyclic_running = 1
                while (cyclic_running):
                    cyclic_running = read_backend_reg(cyclic_running_node)
                # Stop the cyclic generator
                write_backend_reg(ttc_reset_node, 1)
                calpulse_counter = read_backend_reg(calpulse_node)

                sbit_data[vfat][channel_inj][channel_read]["events"] = calpulse_counter
                sbit_data[vfat][channel_inj][channel_read]["fired"] = read_backend_reg(channel_sbit_counter_node)
            # End of charge loop
            enableVfatchannel(vfat, oh_select, channel_inj, 0, 0) # disable calpulsing
        # End of channel loop
        print ("")
    # End of VFAT loop
    if calpulse_only:
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE_CALPULSE_ONLY"), 0)
    else:
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 0)
    print ("")

    # Disable channels on VFATs
    for vfat in vfat_list:
        print("Unconfiguring VFAT %d" % (vfat))
        for channel in range(0,128):
            enableVfatchannel(vfat, oh_select, channel, 0, 0) # disable calpulsing on all channels for this VFAT
        configureVfat(0, vfat, oh_select, 0)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)

    # Writing Results
    cross_talk_obs = 0
    filename_result = dataDir + "/%s_OH%d_vfat_crosstalk_caldac%d_"%(gem,oh_select,cal_dac) + now + "_result.txt"
    file_result_out = open(filename_result,"w+")
    print ("\nCross Talk Results:\n")
    file_result_out.write("Cross Talk Results:\n")
    for vfat in vfat_list:
        for channel_inj in channel_list:
            elink_inj = int(channel_inj/16)
            crosstalk_channel_list = ""
            for channel_read in channel_list:
                elink_read = int(channel_read/16)
                if s_bit_channel_mapping[str(vfat)][str(elink_read)][str(channel_read)] != s_bit_channel_mapping[str(vfat)][str(elink_inj)][str(channel_inj)]:
                    if sbit_data[vfat][channel_inj][channel_read]["fired"] > 0:
                        crosstalk_channel_list += " %d,"%channel_read
                file_out.write("%d    %d    %d    %d    %d\n"%(vfat, channel_inj, channel_read, sbit_data[vfat][channel_inj][channel_read]["fired"], sbit_data[vfat][channel_inj][channel_read]["events"]))
            if crosstalk_channel_list != "":
                print ("  VFAT %d, Cross Talk for Channel %d in channels: %s"%(vfat, channel_inj, crosstalk_channel_list))
                file_result_out.write("  VFAT %d, Cross Talk for Channel %d in channels: %s\n"%(vfat, channel_inj, crosstalk_channel_list))
                cross_talk_obs += 1
    if cross_talk_obs == 0:
        print (Colors.GREEN + "No Cross Talk observed between channels" + Colors.ENDC)
        file_result_out.write("No Cross Talk observed between channels\n")

    print ("")
    file_out.close()
    file_result_out.close()

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 VFAT S-Bit Cross Talk")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--vfats", action="store", dest="vfats", nargs="+", help="vfats = VFAT number (0-23)")
    parser.add_argument("-m", "--cal_mode", action="store", dest="cal_mode", default = "current", help="cal_mode = voltage or current (default = current)")
    parser.add_argument("-d", "--cal_dac", action="store", dest="cal_dac", help="cal_dac = Value of CAL_DAC register (default = 50 for voltage pulse mode and 150 for current pulse mode)")
    parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
    parser.add_argument("-n", "--nl1a", action="store", dest="nl1a", help="nl1a = fixed number of L1A cycles")
    parser.add_argument("-l", "--calpulse_only", action="store_true", dest="calpulse_only", help="calpulse_only = to use only calpulsing without L1A's")
    parser.add_argument("-b", "--bxgap", action="store", dest="bxgap", default="500", help="bxgap = Nr. of BX between two L1As (default = 500 i.e. 12.5 us)")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for S-bit Cross Talk")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running sbit cross talk")
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

    cal_mode = args.cal_mode
    if cal_mode not in ["voltage", "current"]:
        print (Colors.YELLOW + "CAL_MODE must be either voltage or current" + Colors.ENDC)
        sys.exit()

    cal_dac = -9999
    if args.cal_dac is None:
        if cal_mode == "voltage":
            cal_dac = 50
        elif cal_mode == "current":
            cal_dac = 150
    else:
        cal_dac = int(args.cal_dac)
        if cal_dac > 255 or cal_dac < 0:
            print (Colors.YELLOW + "CAL_DAC must be between 0 and 255" + Colors.ENDC)
            sys.exit()

    nl1a = 0
    if args.nl1a is not None:
        nl1a = int(args.nl1a)
        if nl1a > (2**32 - 1):
            print (Colors.YELLOW + "Number of L1A cycles can be maximum 4.29e9" + Colors.ENDC)
            sys.exit()
    if nl1a==0:
        print (Colors.YELLOW + "Enter number of L1A cycles" + Colors.ENDC)
        sys.exit()

    l1a_bxgap = int(args.bxgap)
    l1a_timegap = l1a_bxgap * 25 * 0.001 # in microseconds
    print ("Gap between consecutive L1A or CalPulses = %d BX = %.2f us" %(l1a_bxgap, l1a_timegap))

    if args.use_channel_trimming is not None:
        if args.use_channel_trimming not in ["daq", "sbit"]:
            print (Colors.YELLOW + "Only allowed options for use_channel_trimming: daq or sbit" + Colors.ENDC)
            sys.exit()

    # Initialization 
    initialize(args.gem, args.system)
    initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")

    # Running Sbit SCurve
    try:
        vfat_sbit(args.gem, args.system, int(args.ohid), vfat_list, cal_mode, cal_dac , nl1a, args.calpulse_only, l1a_bxgap)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




