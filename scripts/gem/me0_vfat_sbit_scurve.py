from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse
import random
import glob
import json
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel, setVfatchannelTrim

def vfat_sbit(gem, system, oh_select, vfat_list, channel_list, set_cal_mode, parallel, threshold, step, nl1a, calpulse_only, l1a_bxgap, trim, s_bit_channel_mapping):
    
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
    dataDir = "results/vfat_data/vfat_sbit_scurve_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/%s_OH%d_vfat_sbit_scurve_"%(gem, oh_select) + now + ".txt"
    file_out = open(filename,"w+")
    file_out.write("vfat    channel    charge    fired    events\n")

    gem_link_reset()
    global_reset()
    sleep(0.1)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)

    sbit_data = {}
    cal_mode = {}
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
            
        if threshold != -9999:
            print("Setting threshold = %d (DAC)"%threshold)
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_THR_ARM_DAC"%(oh_select,vfat)), threshold)
        for channel in channel_list:
            enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask all channels and disable calpulsing
        cal_mode[vfat] = read_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"% (oh_select, vfat)))

        if trim == "up":
            print ("Trim settings set to high for all channels")
            for channel in channel_list:
                setVfatchannelTrim(vfat, oh_select, channel, 0, 31)
        elif trim == "down":
            print ("Trim settings set to low for all channels")
            for channel in channel_list:
                setVfatchannelTrim(vfat, oh_select, channel, 1, 31)

        link_good_node = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat))
        sync_error_node = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat))
        link_good = read_backend_reg(link_good_node)
        sync_err = read_backend_reg(sync_error_node)
        if system!="dryrun" and (link_good == 0 or sync_err > 0):
            print (Colors.RED + "Link is bad for VFAT# %02d"%(vfat) + Colors.ENDC)
            terminate()

        sbit_data[vfat] = {}
        for channel in channel_list:
            sbit_data[vfat][channel] = {}
            for c in range(0,256,step):
                #if cal_mode[vfat] == 1:
                #    charge = 255 - c
                #else:
                charge = c
                sbit_data[vfat][channel][charge] = {}
                sbit_data[vfat][channel][charge]["events"] = -9999
                sbit_data[vfat][channel][charge]["fired"] = -9999

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

    dac_node = {}
    dac = "CFG_CAL_DAC"
    for vfat in vfat_list:
        dac_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%d.%s"%(oh_select, vfat, dac))

    print ("\nRunning Sbit SCurves for %.2e L1A cycles for VFATs:" % (nl1a))
    print (vfat_list)
    print ("")

    if parallel == "all":
        print ("Injecting charge in all channels in parallel\n")
        for vfat in vfat_list:
            for channel in range(0, 128):
                enableVfatchannel(vfat, oh_select, channel, 0, 1) # unmask channel and enable calpulsing
    elif parallel == "select":
        print ("Injecting charge in selected channels in parallel\n")
        for vfat in vfat_list:
            for channel in channel_list:
                enableVfatchannel(vfat, oh_select, channel, 0, 1) # unmask channel and enable calpulsing
    else:
        print ("Injecting charge in channels one at a time\n")

    # Looping over VFATs
    for vfat in vfat_list:
        # Looping over channels
        for channel in channel_list:
            print ("VFAT: %02d  Channel: %d"%(vfat, channel))
            elink = int(channel/16)

            if str(vfat) not in s_bit_channel_mapping:
                print (Colors.YELLOW + "    Mapping not present for VFAT %02d"%(vfat) + Colors.ENDC)
                continue
            if s_bit_channel_mapping[str(vfat)][str(elink)][str(channel)] == -9999:
                print (Colors.YELLOW + "    Bad channel (from S-bit mapping) %02d on VFAT %02d"%(channel,vfat) + Colors.ENDC)
                continue
            if parallel is None:
                enableVfatchannel(vfat, oh_select, channel, 0, 1) # unmask channel and enable calpulsing
            write_backend_reg(vfat_sbit_select_node, vfat)
            write_backend_reg(channel_sbit_select_node, s_bit_channel_mapping[str(vfat)][str(elink)][str(channel)])

            # Looping over charge
            for c in range(0,256,step):
                #if cal_mode[vfat] == 1:
                #    charge = 255 - c
                #else:
                charge = c
                #print ("    Injected Charge: %d"%charge)
                write_backend_reg(dac_node[vfat], c)

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

                sbit_data[vfat][channel][charge]["events"] = calpulse_counter
                sbit_data[vfat][channel][charge]["fired"] = read_backend_reg(channel_sbit_counter_node)
            # End of charge loop
            if parallel is None:
                enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask channel and disable calpulsing
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
    for vfat in vfat_list:
        for channel in channel_list:
            for charge in range(0,256,1):
                if charge not in sbit_data[vfat][channel]:
                    continue
                file_out.write("%d    %d    %d    %d    %d\n"%(vfat, channel, charge, sbit_data[vfat][channel][charge]["fired"], sbit_data[vfat][channel][charge]["events"]))

    print ("")
    file_out.close()


if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 VFAT S-Bit SCurve")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--vfats", action="store", dest="vfats", nargs="+", help="vfats = VFAT number (0-23)")
    parser.add_argument("-c", "--channels", action="store", nargs="+", dest="channels", help="channels = list of channels (default: 0-127)")
    parser.add_argument("-m", "--cal_mode", action="store", dest="cal_mode", default = "current", help="cal_mode = voltage or current (default = current)")
    parser.add_argument("-p", "--parallel", action="store", dest="parallel", help="parallel = all (inject calpulse in all channels) or select (inject calpulse in selected channels) simultaneously (only possible in voltage mode, not a preferred option)")
    parser.add_argument("-x", "--threshold", action="store", dest="threshold", help="threshold = the CFG_THR_ARM_DAC value (default=configured value of VFAT)")
    parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
    parser.add_argument("-t", "--step", action="store", dest="step", default="1", help="step = Step size for SCurve scan (default=1)")
    parser.add_argument("-n", "--nl1a", action="store", dest="nl1a", help="nl1a = fixed number of L1A cycles")
    parser.add_argument("-l", "--calpulse_only", action="store_true", dest="calpulse_only", help="calpulse_only = to use only calpulsing without L1A's")
    parser.add_argument("-b", "--bxgap", action="store", dest="bxgap", default="500", help="bxgap = Nr. of BX between two L1As (default = 500 i.e. 12.5 us)")
    parser.add_argument("-z", "--trim", action="store", dest="trim", default="nominal", help="trim = nominal, up, down (default = nominal)")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for S-bit SCurve")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running sbit scurve")
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

    if args.parallel is not None:
        if args.parallel not in ["all", "select"]:
            print (Colors.YELLOW + "Parallel mode can be either all or select" + Colors.ENDC)
            sys.exit()
        if cal_mode != "voltage":
            print (Colors.YELLOW + "CAL_MODE must be voltage for parallel injection" + Colors.ENDC)
            sys.exit()

    threshold = -9999
    if args.threshold is not None:
        threshold = int(args.threshold)
        if threshold not in range(0,256):
            print (Colors.YELLOW + "Threshold has to 8 bits (0-255)" + Colors.ENDC)
            sys.exit()

    step = int(args.step)
    if step not in range(1,257):
        print (Colors.YELLOW + "Step size can only be between 1 and 256" + Colors.ENDC)
        sys.exit()

    channel_list = []
    if args.channels is None:
        channel_list = range(0,128)
    else:
        for c in args.channels:
            c_int = int(c)
            if c_int not in range(0,128):
                print (Colors.YELLOW + "Invalid channel, only allowed 0-127" + Colors.ENDC)
                sys.exit()
            channel_list.append(c_int)

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

    if args.trim not in ["nominal", "up", "down"]:
        print (Colors.YELLOW + "Trim option can only be: nominal, up, down" + Colors.ENDC)
        sys.exit()

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
        vfat_sbit(args.gem, args.system, int(args.ohid), vfat_list, channel_list, cal_mode, args.parallel, threshold, step, nl1a, args.calpulse_only, l1a_bxgap, args.trim, s_bit_channel_mapping)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




