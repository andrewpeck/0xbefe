from gem.gem_utils import *
from time import sleep, time
import sys
import argparse
import random
import glob
import json
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel
import datetime

def vfat_sbit(gem, system, oh_select, vfat, elink_list, channel_list, trigger, parallel, set_cal_mode, cal_dac, nl1a, calpulse_only, l1a_bxgap, s_bit_cluster_mapping):
    
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
    dataDir = "results/vfat_data/vfat_sbit_cluster_test_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    file_out = open(dataDir + "/%s_OH%d_vfat_sbit_cluster_test_output_"%(gem,oh_select) + now + ".txt", "w")
    print ("%s VFAT S-Bit Cluster Test\n"%gem)
    file_out.write("%s VFAT S-Bit Cluster Test\n\n"%gem)

    gem_link_reset()
    global_reset()
    sleep(0.1)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)

    gbt, gbt_select, elink_daq, gpio = me0_vfat_to_gbt_elink_gpio(vfat)
    print ("Testing VFAT#: %02d\n" %(vfat))
    file_out.write("Testing VFAT#: %02d\n\n")
    
    check_gbt_link_ready(oh_select, gbt_select)
    link_good = read_backend_reg(get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat)))
    sync_err = read_backend_reg(get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat)))
    if system!="dryrun" and (link_good == 0 or sync_err > 0):
        print (Colors.RED + "Link is bad for VFAT# %02d"%(vfat) + Colors.ENDC)
        terminate()

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

    n_bx_fifo = 0
    n_bx_fifo += l1a_bxgap * nl1a
    n_cluster_expected = 0
    if n_bx_fifo <= 512:
        n_cluster_expected = nl1a
        print ("Clusters for all L1A's will be recorded in the FIFO")
        file_out.write("Clusters for all L1A's will be recorded in the FIFO\n")
        #print ("Expecting %d clusters in the FIFO\n"%n_cluster_expected)
        #file_out.write("Expecting %d clusters in the FIFO\n\n"%n_cluster_expected)
    else:
        n_bx_fifo = 512
        n_cluster_expected = (int((n_bx_fifo)/l1a_bxgap))
        print (Colors.YELLOW + "Clusters for all L1A's will not be recorded in the FIFO" + Colors.ENDC)
        file_out.write("Clusters for all L1A's will not be recorded in the FIFO\n")
        #print ("Expecting %d clusters in the FIFO\n"%n_cluster_expected)
        #file_out.write("Expecting %d clusters in the FIFO\n\n"%n_cluster_expected)

    ttc_reset_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET")
    ttc_cyclic_start_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START")
    cyclic_running_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_RUNNING")
    calpulse_node = get_backend_node("BEFE.GEM.TTC.CMD_COUNTERS.CALPULSE")
    l1a_node = get_backend_node("BEFE.GEM.TTC.CMD_COUNTERS.L1A")

    # Nodes for Sbit Monitor
    write_backend_reg(get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.OH_SELECT"), oh_select)
    reset_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.RESET")  # To reset S-bit Monitor
    reset_sbit_cluster_node = get_backend_node("BEFE.GEM.TRIGGER.CTRL.CNT_RESET")  # To reset Cluster Counter
    sbit_monitor_nodes = []
    cluster_count_nodes = []
    for i in range(0,8):
        sbit_monitor_nodes.append(get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.CLUSTER%d"%i))
        cluster_count_nodes.append(get_backend_node("BEFE.GEM.TRIGGER.OH0.CLUSTER_COUNT_%d_CNT"%i))
    fifo_empty_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.FIFO_EMPTY")
    fifo_en_l1a_trigger_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.FIFO_EN_L1A_TRIGGER")
    fifo_en_sbit_trigger_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.FIFO_EN_SBIT_TRIGGER")
    trigger_delay_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.FIFO_TRIGGER_DELAY")
    fifo_data_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.FIFO_DATA")

    l1a_rate = 1e9/(l1a_bxgap * 25) # in Hz
    efficiency = 1
    if l1a_rate > 1e6 * 0.5:
        efficiency = 0.977

    # Configure the pulsing VFAT
    print("Configuring VFAT %02d" % (vfat))
    file_out.write("Configuring VFAT %02d\n" % (vfat))
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

    if parallel == "all":
        print ("Injecting charge in all channels in parallel\n")
        file_out.write("Injecting charge in all channels in parallel\n\n")
        for channel in range(0, 128):
            enableVfatchannel(vfat, oh_select, channel, 0, 1) # unmask channel and enable calpulsing
    elif parallel == "select":
        print ("Injecting charge in selected channels in parallel\n")
        file_out.write("Injecting charge in selected channels in parallel\n\n")
        for elink in elink_list:
            for channel in channel_list[elink]:
                enableVfatchannel(vfat, oh_select, channel, 0, 1) # unmask channel and enable calpulsing
    else:
        for channel in range(0, 128):
            enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask this channel and disable calpulsing

    sleep(1)

    # Looping over Elinks
    for elink in elink_list:
        print ("Channel List in ELINK# %02d:" %(elink))
        file_out.write("Channel List in ELINK# %02d:\n" %(elink))
        print (channel_list[elink])
        for channel in channel_list[elink]:
            file_out.write(str(channel) + "  ")
        file_out.write("\n")
        print ("")
        file_out.write("\n")

        # Looping over channels
        for channel in channel_list[elink]:
            if vfat not in s_bit_cluster_mapping:
                print (Colors.YELLOW + "    Mapping not present for VFAT %02d"%(vfat) + Colors.ENDC)
                continue
            if s_bit_cluster_mapping[vfat][channel]["cluster_address"] == -9999:
                print (Colors.YELLOW + "    Bad channel (from S-bit cluster mapping) %02d on VFAT %02d"%(channel,vfat) + Colors.ENDC)
                continue
            # Enabling the pulsing channel
            if parallel is None:
                print("Enabling pulsing on channel %02d in ELINK# %02d:" % (channel, elink))
                file_out.write("Enabling pulsing on channel %02d in ELINK# %02d:\n" % (channel, elink))
                enableVfatchannel(vfat, oh_select, channel, 0, 1) # unmask this channel and enable calpulsing

            # Reset L1A, CalPulse and S-bit Monitor
            write_backend_reg(ttc_cnt_reset_node, 1)
            write_backend_reg(reset_sbit_monitor_node, 1)
            write_backend_reg(reset_sbit_cluster_node, 1)

            # Setting Trigger Delay
            write_backend_reg(trigger_delay_sbit_monitor_node, 512)

            # Start the cyclic generator
            print ("ELINK# %02d, Channel %02d: Start L1A and Calpulsing cycle"%(elink, channel))
            file_out.write("ELINK# %02d, Channel %02d: Start L1A and Calpulsing cycle\n"%(elink, channel))
            write_backend_reg(ttc_cyclic_start_node, 1)

            # Setting Trigger Enable
            if trigger == "l1a":
                write_backend_reg(fifo_en_l1a_trigger_sbit_monitor_node, 1)
            elif trigger == "sbit":
                write_backend_reg(fifo_en_sbit_trigger_sbit_monitor_node, 1)

            cyclic_running = 1
            t0 = time()
            while (cyclic_running):
                cyclic_running = read_backend_reg(cyclic_running_node)
            # Stop the cyclic generator
            write_backend_reg(ttc_reset_node, 1)

            # Disabling the pulsing channels
            if parallel is None:
                print("Disabling pulsing on channel %02d in ELINK# %02d:" % (channel, elink))
                file_out.write("Disabling pulsing on channel %02d in ELINK# %02d:\n" % (channel, elink))
                enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask this channel and disable calpulsing
            print("")
            file_out.write("\n")

            # Reading the Sbit Monitor FIFO
            l1a_counter = read_backend_reg(l1a_node)
            calpulse_counter = read_backend_reg(calpulse_node)
            fifo_empty = read_backend_reg(fifo_empty_sbit_monitor_node)
            expected_cluster_size = 0
            expected_cluster_pos = 0
            if parallel:
                expected_cluster_size = len(channel_list)
                expected_cluster_pos = s_bit_cluster_mapping[vfat][min(channel_list)]["cluster_address"]
            else:
                expected_cluster_size = 1
                expected_cluster_pos = s_bit_cluster_mapping[vfat][channel]["cluster_address"]
            n_clusters = 0
            #n_clusters_error = 0
            n_cluster_size_error = 0
            n_cluster_pos_error = 0
            n = -1
            nbx = -1
            status_str = ""
            min_cluster = 0

            while (fifo_empty == 0):
                fifo_data = read_backend_reg(fifo_data_sbit_monitor_node)
                cluster1_sbit_monitor_value = fifo_data & 0x0000ffff
                cluster1_sbit_cluster_address = cluster1_sbit_monitor_value & 0x7ff
                cluster1_sbit_cluster_size = ((cluster1_sbit_monitor_value >> 12) & 0x7) + 1
                cluster1_l1a = cluster1_sbit_monitor_value >> 15

                cluster2_sbit_monitor_value = (fifo_data >> 4) & 0x0000ffff
                cluster2_sbit_cluster_address = cluster2_sbit_monitor_value & 0x7ff
                cluster2_sbit_cluster_size = ((cluster2_sbit_monitor_value >> 12) & 0x7) + 1
                cluster2_l1a = cluster2_sbit_monitor_value >> 15

                fifo_empty = read_backend_reg(fifo_empty_sbit_monitor_node)

                n += 1
                if n%4==0:
                    nbx += 1
                    n = 0
                    status_str = "BX %d:  \n"%nbx
                    min_cluster = 0

                if cluster1_sbit_cluster_address != 0x7ff and cluster1_sbit_cluster_size != 8:
                    status_str += "  Cluster: %d (size = %d)"%(cluster1_sbit_cluster_address, cluster1_sbit_cluster_size)
                    n_clusters += 1
                    min_cluster = 1
                    if cluster1_sbit_cluster_size != expected_cluster_size:
                        n_cluster_size_error += 1
                    if cluster1_sbit_cluster_address != expected_cluster_pos:
                        n_cluster_pos_error += 1
                if cluster2_sbit_cluster_address != 0x7ff and cluster2_sbit_cluster_size != 8:
                    status_str += "  Cluster: %d (size = %d)"%(cluster2_sbit_cluster_address, cluster2_sbit_cluster_size)
                    n_clusters += 1
                    min_cluster = 1
                    if cluster2_sbit_cluster_size != expected_cluster_size:
                        n_cluster_size_error += 1
                    if cluster2_sbit_cluster_address != expected_cluster_pos:
                        n_cluster_pos_error += 1
                if n%4==0 and min_cluster:
                    print (status_str)
                    file_out.write(status_str + "\n")
            #n_clusters_error = n_clusters - n_cluster_expected

            if trigger == "l1a":
                write_backend_reg(fifo_en_l1a_trigger_sbit_monitor_node, 0)
            elif trigger == "sbit":
                write_backend_reg(fifo_en_sbit_trigger_sbit_monitor_node, 0)

            print ("Time taken: %.2f minutes, L1A_rate = %.2f kHz, L1A counter = %.2e,  Calpulse counter = %.2e\n" % ((time()-t0)/60.0, l1a_rate/1000.0, l1a_counter, calpulse_counter))
            file_out.write("Time taken: %.2f minutes, L1A_rate = %.2f kHz, L1A counter = %.2e,  Calpulse counter = %.2e\n\n" % ((time()-t0)/60.0, l1a_rate/1000.0, l1a_counter, calpulse_counter))

            #if n_clusters_error == 0:
                #print (Colors.GREEN + "Nr. of cluster expected = %d, Nr. of clusters recorded = %d"%(n_cluster_expected, n_clusters) + Colors.ENDC)
            #else:
                #print (Colors.RED + "Nr. of cluster expected = %d, Nr. of clusters recorded = %d"%(n_cluster_expected, n_clusters) + Colors.ENDC)
            print ("Nr. of clusters recorded = %d"%(n_clusters))
            #file_out.write("Nr. of cluster expected = %d, Nr. of clusters recorded = %d\n"%(n_cluster_expected, n_clusters))
            file_out.write("Nr. of clusters recorded = %d"%(n_clusters))
            if n_cluster_size_error == 0:
                print (Colors.GREEN + "Nr. of cluster size mismatches = %d"%n_cluster_size_error + Colors.ENDC)
            else:
                print (Colors.RED + "Nr. of cluster size mismatches = %d"%n_cluster_size_error + Colors.ENDC)
            file_out.write("Nr. of cluster size mismatches = %d"%n_cluster_size_error)
            if n_cluster_pos_error == 0:
                print (Colors.GREEN + "Nr. of cluster position mismatches = %d"%n_cluster_pos_error + Colors.ENDC)
            else:
                print (Colors.RED + "Nr. of cluster position mismatches = %d"%n_cluster_pos_error + Colors.ENDC)
            file_out.write("Nr. of cluster position mismatches = %d"%n_cluster_pos_error)

            print ("")
            file_out.write("\n")
    if calpulse_only:
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE_CALPULSE_ONLY"), 0)
    else:
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 0)

    # Unconfigure the pulsing VFAT
    print("Disabling pulsing on all channels in VFAT# %02d" % (vfat))
    file_out.write("Disabling pulsing on all channels in VFAT# %02d\n" % (vfat))
    print("")
    file_out.write("\n")
    for elink in elink_list:
        for channel in range(0,128):
            enableVfatchannel(vfat, oh_select, channel, 0, 0) # disable calpulsing on all channels for this VFAT
    print("Unconfiguring VFAT %02d" % (vfat))
    file_out.write("Unconfiguring VFAT %02d\n" % (vfat))
    configureVfat(0, vfat, oh_select, 0)

    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)

    print ("\nS-bit Cluster testing done\n")
    file_out.write("\nS-bit Cluster testing done\n\n")
    file_out.close()

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 VFAT S-Bit Test")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--vfat", action="store", dest="vfat", help="vfat = VFAT number (0-23)")
    parser.add_argument("-e", "--elink", action="store", dest="elink", nargs="+", help="elink = list of ELINKs (0-7) for S-bits")
    parser.add_argument("-c", "--channels", action="store", dest="channels", nargs="+", help="channels = list of channels for chosen VFAT and ELINK (list allowed only for 1 elink, by default all channels used for the elinks)")
    parser.add_argument("-t", "--trigger", action="store", dest="trigger", help="trigger = l1a or sbit")
    parser.add_argument("-m", "--cal_mode", action="store", dest="cal_mode", default = "current", help="cal_mode = voltage or current (default = current)")
    parser.add_argument("-d", "--cal_dac", action="store", dest="cal_dac", help="cal_dac = Value of CAL_DAC register (default = 50 for voltage pulse mode and 150 for current pulse mode)")
    parser.add_argument("-p", "--parallel", action="store", dest="parallel", help="parallel = all (inject calpulse in all channels) or select (inject calpulse in selected channels) simultaneously (only possible in voltage mode, not a preferred option)")
    parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
    parser.add_argument("-n", "--nl1a", action="store", dest="nl1a", help="nl1a = fixed number of L1A cycles")
    parser.add_argument("-l", "--calpulse_only", action="store_true", dest="calpulse_only", help="calpulse_only = to use only calpulsing without L1A's")
    parser.add_argument("-b", "--bxgap", action="store", dest="bxgap", default="500", help="bxgap = Nr. of BX between two L1As (default = 500 i.e. 12.5 us)")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for S-bit test")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running sbit test")
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

    s_bit_cluster_mapping = {}
    print ("")
    if not os.path.isdir("results/vfat_data/vfat_sbit_monitor_cluster_mapping_results"):
        print (Colors.YELLOW + "Run the S-bit cluster mapping first" + Colors.ENDC)
        sys.exit()
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_monitor_cluster_mapping_results/*.txt")
    if len(list_of_files)==0:
        print (Colors.YELLOW + "Run the S-bit cluster mapping first" + Colors.ENDC)
        sys.exit()
    elif len(list_of_files)>1:
        print ("Mutliple S-bit cluster mapping results found, using latest file")
    latest_file = max(list_of_files, key=os.path.getctime)
    print ("Using S-bit cluster mapping file: %s\n"%(latest_file.split("results/vfat_data/vfat_sbit_monitor_cluster_mapping_results/")[1]))
    file_in = open(latest_file)
    for line in file_in.readlines():
        if "VFAT" in line:
            continue
        if len(line.split())==0:
            continue
        vfat = int(line.split()[0])
        channel = int(line.split()[1])
        sbit = int(line.split()[2])
        cluster_count = line.split()[3]
        cluster_address = -9999
        cluster_size = -9999
        if len(line.split())>4:
            cluster_size = int(line.split()[4].split(",")[0])
            cluster_address = int(line.split()[4].split(",")[1])
        if cluster_address == 2047 or cluster_size == 8:
            cluster_address = -9999
            cluster_size = -9999
        if vfat not in s_bit_cluster_mapping:
            s_bit_cluster_mapping[vfat] = {}
        s_bit_cluster_mapping[vfat][channel] = {}
        s_bit_cluster_mapping[vfat][channel]["sbit"] = sbit
        s_bit_cluster_mapping[vfat][channel]["cluster_address"] = cluster_address
    file_in.close()

    if args.vfat is None:
        print (Colors.YELLOW + "Enter VFAT number" + Colors.ENDC)
        sys.exit()
    vfat = int(args.vfat)
    if vfat not in range(0,24):
        print (Colors.YELLOW + "Invalid VFAT number, only allowed 0-23" + Colors.ENDC)
        sys.exit()

    if args.elink is None:
        args.elink = ["0","1","2","3","4","5","6","7"]
    if len(args.elink)>1 and args.channels is not None:
        print (Colors.YELLOW + "Channel list allowed only for 1 elink, by default all channels used for multiple elinks" + Colors.ENDC)
        sys.exit()

    elink_list = []
    channel_list = {}
    for e in args.elink:
        elink = int(e)
        if elink not in range(0,8):
            print (Colors.YELLOW + "Invalid ELINK number, only allowed 0-7" + Colors.ENDC)
            sys.exit()
        elink_list.append(elink)
        channel_list[elink] = []

        if args.channels is None:
            for c in range(0,16):
                channel_list[elink].append(elink*16 + c)
        else:
            for c in args.channels:
                c_int = int(c)
                if c_int not in range(elink*16, elink*16+16):
                    print (Colors.YELLOW + "Invalid Channel number for selected ELINK" + Colors.ENDC)
                    sys.exit()
                channel_list[elink].append(c_int)

    cal_mode = args.cal_mode
    if cal_mode not in ["voltage", "current"]:
        print (Colors.YELLOW + "CAL_MODE must be either voltage or current" + Colors.ENDC)
        sys.exit()

    if args.parallel is not None:
        if args.parallel != "select":
            print (Colors.YELLOW + "Only Parallel mode allowed: select" + Colors.ENDC)
            sys.exit()
        if cal_mode != "voltage":
            print (Colors.YELLOW + "CAL_MODE must be voltage for parallel injection" + Colors.ENDC)
            sys.exit()
        if len(elink_list) != 1:
            print (Colors.YELLOW + "Only 1 elink is allowed for parallel injection" + Colors.ENDC)
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
    else:
        print (Colors.YELLOW + "Enter number of L1A cycles" + Colors.ENDC)
        sys.exit()

    if args.use_channel_trimming is not None:
        if args.use_channel_trimming not in ["daq", "sbit"]:
            print (Colors.YELLOW + "Only allowed options for use_channel_trimming: daq or sbit" + Colors.ENDC)
            sys.exit()

    if args.trigger not in ["l1a", "sbit"]:
        print (Colors.YELLOW + "Trigger on either l1a or sbit" + Colors.ENDC)
        sys.exit()
    if args.trigger == "l1a":
        if args.calpulse_only:
            print (Colors.YELLOW + "Cant trigger in l1a if only calpulses are sent" + Colors.ENDC)
            sys.exit()

    l1a_bxgap = int(args.bxgap)
    l1a_timegap = l1a_bxgap * 25 * 0.001 # in microseconds
    print ("Gap between consecutive L1A or CalPulses = %d BX = %.2f us" %(l1a_bxgap, l1a_timegap))

    # Initialization 
    initialize(args.gem, args.system)
    initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")

    # Running Phase Scan
    try:
        vfat_sbit(args.gem, args.system, int(args.ohid), vfat, elink_list, channel_list, args.trigger, args.parallel, cal_mode, cal_dac, nl1a, args.calpulse_only, l1a_bxgap, s_bit_cluster_mapping)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




