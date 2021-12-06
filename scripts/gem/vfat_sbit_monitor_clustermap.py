from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse
import random
import json
import glob
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel

def vfat_sbit(gem, system, oh_select, vfat_list, nl1a, l1a_bxgap, set_cal_mode, cal_dac, s_bit_channel_mapping):
    print ("LPGBT VFAT S-Bit Cluster Mapping\n")

    gem_link_reset()
    global_reset()
    sleep(0.1)
    write_backend_reg(get_backend_node("BEFE.GEM_AMC.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)

    # Configure TTC generator
    write_backend_reg(get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.RESET"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_L1A_GAP"), l1a_bxgap)
    write_backend_reg(get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_L1A_COUNT"), nl1a)
    if l1a_bxgap >= 40:
        write_backend_reg(get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 25)
    else:
        write_backend_reg(get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 2)

    # Reading S-bit monitor
    cyclic_running_node = get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_RUNNING")
    l1a_node = get_backend_node("BEFE.GEM_AMC.TTC.CMD_COUNTERS.L1A")
    calpulse_node = get_backend_node("BEFE.GEM_AMC.TTC.CMD_COUNTERS.CALPULSE")

    write_backend_reg(get_backend_node("BEFE.GEM_AMC.TRIGGER.SBIT_MONITOR.OH_SELECT"), oh_select)
    reset_sbit_monitor_node = get_backend_node("BEFE.GEM_AMC.TRIGGER.SBIT_MONITOR.RESET")  # To reset S-bit Monitor
    sbit_monitor_nodes = []
    cluster_count_nodes = []
    for i in range(0,8):
        sbit_monitor_nodes.append(get_backend_node("BEFE.GEM_AMC.TRIGGER.SBIT_MONITOR.CLUSTER%d"%i))
        cluster_count_nodes.append(get_backend_node("BEFE.GEM_AMC.TRIGGER.OH0.CLUSTER_COUNT_%d_CNT"%i))

    s_bit_cluster_mapping = {}

    for vfat in vfat_list:
        print ("Testing VFAT#: %02d" %(vfat))
        print ("")
        gbt, gbt_select, elink_daq, gpio = me0_vfat_to_gbt_elink_gpio(vfat)
        check_gbt_link_ready(oh_select, gbt_select)

        link_good = read_backend_reg(get_backend_node("BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat)))
        sync_err = read_backend_reg(get_backend_node("BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat)))
        if system!="dryrun" and (link_good == 0 or sync_err > 0):
            print (Colors.RED + "Link is bad for VFAT# %02d"%(vfat) + Colors.ENDC)
            terminate()

        # Configure the pulsing VFAT
        print("Configuring VFAT %02d" % (vfat))
        configureVfat(1, vfat, oh_select, 0)
        if set_cal_mode == "voltage":
            write_backend_reg(get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"% (oh_select, vfat)), 1)
            write_backend_reg(get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"% (oh_select, vfat)), 200)
        elif set_cal_mode == "current":
            write_backend_reg(get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"% (oh_select, vfat)), 2)
            write_backend_reg(get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"% (oh_select, vfat)), 0)
        else:
            write_backend_reg(get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"% (oh_select, vfat)), 0)
            write_backend_reg(get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"% (oh_select, vfat)), 0)
        write_backend_reg(get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DAC"% (oh_select, vfat)), cal_dac)
        for i in range(128):
            enableVfatchannel(vfat, oh_select, i, 1, 0) # mask all channels and disable calpulsing
        print ("")

        s_bit_cluster_mapping[vfat] = {}

        # Looping over all channels
        for channel in range(0,128):
            elink = int(channel/16)
            sbit = 0
            if gem == "ME0":
                sbit = s_bit_channel_mapping[str(vfat)][str(elink)][str(channel)]
            s_bit_cluster_mapping[vfat][channel] = {}
            s_bit_cluster_mapping[vfat][channel]["sbit"] = sbit
            s_bit_cluster_mapping[vfat][channel]["cluster_count"] = []
            s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_size"] = []
            s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_address"] = []

            # Enabling the pulsing channel
            enableVfatchannel(vfat, oh_select, channel, 0, 1) # unmask this channel and enable calpulsing

            # Reset L1A, CalPulse and S-bit monitor
            global_reset()
            write_backend_reg(reset_sbit_monitor_node, 1)

            # Start the cyclic generator
            write_backend_reg(get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_START"), 1)
            cyclic_running = read_backend_reg(cyclic_running_node)
            while cyclic_running:
                cyclic_running = read_backend_reg(cyclic_running_node)

            # Stop the cyclic generator
            write_backend_reg(get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.RESET"), 1)

            l1a_counter = read_backend_reg(l1a_node)
            calpulse_counter = read_backend_reg(calpulse_node)

            if system!="dryrun" and l1a_counter != nl1a:
                print (Colors.RED + "ERROR: Number of L1As incorrect" + Colors.ENDC)
                rw_terminate()

            for i in range(0,8):
                s_bit_cluster_mapping[vfat][channel]["cluster_count"].append(read_backend_reg(cluster_count_nodes[i])/calpulse_counter)
                sbit_monitor_value = read_backend_reg(sbit_monitor_nodes[i])
                sbit_cluster_address = sbit_monitor_value & 0x7ff
                sbit_cluster_size = ((sbit_monitor_value >> 11) & 0x7) + 1
                s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_size"].append(sbit_cluster_size)
                s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_address"].append(sbit_cluster_address)

            # Disabling the pulsing channels
            enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask this channel and disable calpulsing

        # Unconfigure the pulsing VFAT
        print("Unconfiguring VFAT %02d" % (vfat))
        configureVfat(0, vfat, oh_select, 0)
        print ("")
        # End of VFAT loop
    write_backend_reg(get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE"), 0)

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

    for vfat in s_bit_cluster_mapping:
        for channel in s_bit_cluster_mapping[vfat]:
            result_str = "%02d  %03d  %03d  "%(vfat, channel, s_bit_cluster_mapping[vfat][channel]["sbit"])
            for i in range(1,8):
                result_str += "%d,"%s_bit_cluster_mapping[vfat][channel]["cluster_count"][i]
            result_str += "  "
            for i in range(0,8):
                if (s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_address"][i] == 0x7ff and s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_size"][i] == 0x7):
                    continue
                result_str += "%d,%03d  "%(s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_size"][i], s_bit_cluster_mapping[vfat][channel]["sbit_monitor_cluster_address"][i])
            result_str += "\n"
            file_out.write(result_str)
    file_out.close()
    print ("S-bit Monitor Cluster Mapping Results written in file: %s \n"%filename)

    write_backend_reg(get_backend_node("BEFE.GEM_AMC.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)
    print ("\nS-bit cluster mapping done\n")

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="VFAT S-Bit Monitor Cluster Mapping")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 or GE21 or GE11")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
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

    nl1a = 1 # Nr. of L1As
    l1a_bxgap = 100 # Gap between 2 L1As in nr. of BXs
    set_cal_mode = "current"
    cal_dac = 150 # should be 50 for voltage pulse mode
        
    # Initialization 
    initialize(args.gem, args.system)
    initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")

    # Running Phase Scan
    try:
        vfat_sbit(args.gem, args.system, int(args.ohid), vfat_list, nl1a, l1a_bxgap, set_cal_mode, cal_dac, s_bit_channel_mapping)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




