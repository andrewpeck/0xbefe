from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse
import random
import json
import glob
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel

def vfat_sbit(gem, system, oh_select, vfat_list, nl1a, calpulse_only, l1a_bxgap, set_cal_mode, cal_dac, s_bit_channel_mapping):
    print ("LPGBT VFAT S-Bit Cluster Mapping\n")

    gem_link_reset()
    global_reset()
    sleep(0.1)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)

    # Configure TTC generator
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

    # Reading S-bit monitor
    cyclic_running_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_RUNNING")
    l1a_node = get_backend_node("BEFE.GEM.TTC.CMD_COUNTERS.L1A")
    calpulse_node = get_backend_node("BEFE.GEM.TTC.CMD_COUNTERS.CALPULSE")

    write_backend_reg(get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.OH_SELECT"), oh_select)
    reset_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.RESET")  # To reset S-bit Monitor
    reset_sbit_cluster_node = get_backend_node("BEFE.GEM.TRIGGER.CTRL.CNT_RESET")  # To reset Cluster Counter
    sbit_monitor_nodes = []
    cluster_count_nodes = []
    for i in range(0,8):
        sbit_monitor_nodes.append(get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.CLUSTER%d"%i))
        cluster_count_nodes.append(get_backend_node("BEFE.GEM.TRIGGER.OH0.CLUSTER_COUNT_%d_CNT"%i))

    s_bit_cluster_mapping = {}
    for vfat in vfat_list:
        gbt, gbt_select, elink_daq, gpio = me0_vfat_to_gbt_elink_gpio(vfat)
        check_gbt_link_ready(oh_select, gbt_select)

        link_good = read_backend_reg(get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat)))
        sync_err = read_backend_reg(get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat)))
        if system!="dryrun" and (link_good == 0 or sync_err > 0):
            print (Colors.RED + "Link is bad for VFAT# %02d"%(vfat) + Colors.ENDC)
            terminate()

        # Configure the pulsing VFAT
        print("Configuring VFAT %02d" % (vfat))
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
        write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DAC"% (oh_select, vfat)), cal_dac)
        for i in range(128):
            enableVfatchannel(vfat, oh_select, i, 1, 0) # mask all channels and disable calpulsing
        print ("")

        s_bit_cluster_mapping[vfat] = {}

    sleep(1)

    # Looping over VFATs
    for vfat in vfat_list:
        print ("Testing VFAT#: %02d" %(vfat))
        print ("")
        # Looping over all channels
        for channel in range(0,128):
            elink = int(channel/16)
            sbit = 0
            if gem == "ME0":
                if str(vfat) not in s_bit_channel_mapping:
                    print (Colors.YELLOW + "    Mapping not present for VFAT %02d"%(vfat) + Colors.ENDC)
                    sbit = -9999
                sbit = s_bit_channel_mapping[str(vfat)][str(elink)][str(channel)]
            s_bit_cluster_mapping[vfat][channel] = {}
            s_bit_cluster_mapping[vfat][channel]["sbit"] = sbit
            s_bit_cluster_mapping[vfat][channel]["calpulse_counter"] = 0
            s_bit_cluster_mapping[vfat][channel]["cluster_count"] = []
            s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_size"] = []
            s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_address"] = []

            # Enabling the pulsing channel
            enableVfatchannel(vfat, oh_select, channel, 0, 1) # unmask this channel and enable calpulsing

            # Reset L1A, CalPulse and S-bit monitor
            write_backend_reg(ttc_cnt_reset_node, 1)
            write_backend_reg(reset_sbit_monitor_node, 1)
            write_backend_reg(reset_sbit_cluster_node, 1)

            # Start the cyclic generator
            write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START"), 1)
            cyclic_running = read_backend_reg(cyclic_running_node)
            while cyclic_running:
                cyclic_running = read_backend_reg(cyclic_running_node)

            # Stop the cyclic generator
            write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)

            l1a_counter = read_backend_reg(l1a_node)
            calpulse_counter = read_backend_reg(calpulse_node)

            for i in range(0,8):
                s_bit_cluster_mapping[vfat][channel]["calpulse_counter"] = calpulse_counter
                s_bit_cluster_mapping[vfat][channel]["cluster_count"].append(read_backend_reg(cluster_count_nodes[i]))
                sbit_monitor_value = read_backend_reg(sbit_monitor_nodes[i])
                sbit_cluster_address = sbit_monitor_value & 0x7ff
                sbit_cluster_size = ((sbit_monitor_value >> 12) & 0x7) + 1
                s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_size"].append(sbit_cluster_size)
                s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_address"].append(sbit_cluster_address)

            # Disabling the pulsing channels
            enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask this channel and disable calpulsing
        # End of Channel loop
        print ("")
    # End of VFAT loop

    for vfat in vfat_list:
        # Unconfigure the pulsing VFAT
        print("Unconfiguring VFAT %02d" % (vfat))
        configureVfat(0, vfat, oh_select, 0)
        print ("")
    if calpulse_only:
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE_CALPULSE_ONLY"), 0)
    else:
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 0)

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
    dataDir = "results/vfat_data/vfat_sbit_monitor_cluster_mapping_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/%s_OH%d_vfat_sbit_monitor_cluster_mapping_results_"%(gem,oh_select) + now + ".txt"
    file_out = open(filename, "w")
    file_out.write("VFAT    Channel    Sbit    Cluster_Counts (1-7)    Clusters (Size, Address)\n\n")

    bad_mapping_str = Colors.RED + "Bad mapping for channels: \n"
    bad_mapping_count = 0
    for vfat in s_bit_cluster_mapping:
        for channel in s_bit_cluster_mapping[vfat]:
            result_str = "%02d  %03d  %03d  "%(vfat, channel, s_bit_cluster_mapping[vfat][channel]["sbit"])
            multiple_cluster_counts = 0
            for i in range(1,8):
                result_str += "%d,"%s_bit_cluster_mapping[vfat][channel]["cluster_count"][i]
                if i == 1:
                    if s_bit_cluster_mapping[vfat][channel]["cluster_count"][i] != s_bit_cluster_mapping[vfat][channel]["calpulse_counter"]:
                        multiple_cluster_counts = 1
                else:
                    if s_bit_cluster_mapping[vfat][channel]["cluster_count"][i] != 0:
                        multiple_cluster_counts = 1
            result_str += "  "
            n_clusters = 0
            large_cluster = 0
            for i in range(0,8):
                if (s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_address"][i] == 0x7ff or s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_size"][i] == 8):
                    continue
                n_clusters += 1
                if s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_size"][i] > 1:
                    large_cluster = 1
                result_str += "%d,%03d  "%(s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_size"][i], s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_address"][i])
            if n_clusters > 1 or large_cluster == 1 or multiple_cluster_counts == 1:
                bad_mapping_str += "  VFAT %02d, Channel %02d\n"%(vfat, channel)
                bad_mapping_count += 1
            result_str += "\n"
            file_out.write(result_str)
    file_out.close()
    bad_mapping_str += "\n" + Colors.ENDC
    if bad_mapping_count != 0:
        print (bad_mapping_str)
    else:
        print (Colors.GREEN + "No Bad Mapping for Channels\n" + Colors.ENDC)

    print ("S-bit Monitor Cluster Mapping Results written in file: %s \n"%filename)

    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)
    print ("\nS-bit cluster mapping done\n")

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="VFAT S-Bit Monitor Cluster Mapping")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 or GE21 or GE11")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-n", "--nl1a", action="store", dest="nl1a", default = "1000", help="nl1a = fixed number of L1A cycles")
    parser.add_argument("-l", "--calpulse_only", action="store_true", dest="calpulse_only", help="calpulse_only = to use only calpulsing without L1A's")
    parser.add_argument("-b", "--bxgap", action="store", dest="bxgap", default="20", help="bxgap = Nr. of BX between two L1As (default = 20 i.e. 0.5 us)")
    parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for S-bit Monitor Cluster Map")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running cluster map")
    else:
        print (Colors.YELLOW + "Only valid options: backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem not in ["ME0", "GE21", "GE11"]:
        print(Colors.YELLOW + "Valid gem station: ME0 or GE21 or GE11" + Colors.ENDC)
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

    s_bit_channel_mapping = {}
    print ("")
    if args.gem == "ME0":
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

    if args.use_channel_trimming is not None:
        if args.use_channel_trimming not in ["daq", "sbit"]:
            print (Colors.YELLOW + "Only allowed options for use_channel_trimming: daq or sbit" + Colors.ENDC)
            sys.exit()

    set_cal_mode = "current"
    cal_dac = 150 # should be 50 for voltage pulse mode
        
    # Initialization 
    initialize(args.gem, args.system)
    initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")

    # Running Phase Scan
    try:
        vfat_sbit(args.gem, args.system, int(args.ohid), vfat_list, int(args.nl1a), args.calpulse_only, int(args.bxgap), set_cal_mode, cal_dac, s_bit_channel_mapping)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




