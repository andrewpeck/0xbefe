from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse
import random
import glob
import json
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel

def vfat_daq(gem, system, oh_select, vfat_list, channel_list, step, runtime, l1a_bxgap, parallel, all, verbose):

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
    dataDir = "results/vfat_data/vfat_daq_noise_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/%s_OH%d_vfat_daq_noise_"%(gem,oh_select) + now + ".txt"
    file_out = open(filename,"w+")
    file_out.write("vfat    channel    threshold    fired    time\n")

    gem_link_reset()
    #global_reset()
    sleep(0.1)

    daq_data = {}
    # Check ready and get nodes
    for vfat in vfat_list:
        gbt, gbt_select, elink, gpio = me0_vfat_to_gbt_elink_gpio(vfat)
        check_gbt_link_ready(oh_select, gbt_select)

        print("Configuring VFAT %d" % (vfat))
        configureVfat(1, vfat, oh_select, 0)
        for channel in range(0,128):
            enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask all channels and disable calpulsing

        write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_LATENCY"% (oh_select, vfat)), 18)
        link_good_node = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat))
        sync_error_node = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat))
        link_good = read_backend_reg(link_good_node)
        sync_err = read_backend_reg(sync_error_node)
        if system!="dryrun" and (link_good == 0 or sync_err > 0):
            print (Colors.RED + "Link is bad for VFAT# %02d"%(vfat) + Colors.ENDC)
            terminate()

        daq_data[vfat] = {}
        for channel in channel_list:
            daq_data[vfat][channel] = {}
            for thr in range(0,256,step):
                daq_data[vfat][channel][thr] = {}
                daq_data[vfat][channel][thr]["time"] = -9999
                daq_data[vfat][channel][thr]["fired"] = -9999

    sleep(1)

    # Configure TTC generator
    #write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.SINGLE_HARD_RESET"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_GAP"), l1a_bxgap)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_COUNT"), 0)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 25)

    # Setup the DAQ monitor
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.ENABLE"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.VFAT_CHANNEL_GLOBAL_OR"), 0)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.OH_SELECT"), oh_select)
    daq_monitor_reset_node = get_backend_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.RESET")
    daq_monitor_enable_node = get_backend_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.ENABLE")
    daq_monitor_select_node = get_backend_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.VFAT_CHANNEL_SELECT")

    dac_node = {}
    daq_monitor_event_count_node = {}
    daq_monitor_fire_count_node = {}
    dac = "CFG_THR_ARM_DAC"
    for vfat in vfat_list:
        dac_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%d.%s"%(oh_select, vfat, dac))
        daq_monitor_event_count_node[vfat] = get_backend_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.VFAT%d.GOOD_EVENTS_COUNT"%(vfat))
        daq_monitor_fire_count_node[vfat] = get_backend_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.VFAT%d.CHANNEL_FIRE_COUNT"%(vfat))

    ttc_reset_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET")
    ttc_cyclic_start_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START")
    cyclic_running_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_RUNNING")

    print ("\nRunning DAQ Noise Scans for VFATs:")
    print (vfat_list)
    print ("")

    initial_thr = {}
    for vfat in vfat_list:
        initial_thr[vfat] = read_backend_reg(dac_node[vfat])
        if parallel:
            print ("Unmasking all channels in all VFATs")
            # Unmask channels for this vfat
            for channel in range(0,128):
                enableVfatchannel(vfat, oh_select, channel, 0, 0) # unmask channels

    # Looping over channels
    for channel in channel_list:
        if all:
            for vfat in vfat_list:
                for thr in range(0,256,step):
                    daq_data[vfat][channel][thr]["fired"] = 0
                    daq_data[vfat][channel][thr]["time"] = runtime
            continue

        if channel == "all":
            continue
        print ("Channel: %d"%channel)
        for vfat in vfat_list:
            enableVfatchannel(vfat, oh_select, channel, 0, 0) # unmask channel
        write_backend_reg(daq_monitor_select_node, channel)

        # Looping over threshold
        for thr in range(0,256,step):
            if verbose:
                print ("    Threshold: %d"%thr)
            for vfat in vfat_list:
                write_backend_reg(dac_node[vfat], thr)
            sleep(1e-3)

            write_backend_reg(daq_monitor_reset_node, 1)
            write_backend_reg(daq_monitor_enable_node, 1)

            # Start the cyclic generator
            sleep(0.001)
            write_backend_reg(ttc_cyclic_start_node, 1)
            sleep(runtime)
            # Stop the cyclic generator
            write_backend_reg(ttc_reset_node, 1)
            sleep(0.001)
            write_backend_reg(daq_monitor_enable_node, 0)

            # Looping over VFATs
            for vfat in vfat_list:
                #daq_data[vfat][channel][thr]["events"] = read_backend_reg(daq_monitor_event_count_node[vfat])
                daq_data[vfat][channel][thr]["fired"] = read_backend_reg(daq_monitor_fire_count_node[vfat])
                daq_data[vfat][channel][thr]["time"] = runtime
            # End of VFAT loop

        # Mask again channels
        if not parallel:
            for vfat in vfat_list:
                enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask channel

        for vfat in vfat_list:
            write_backend_reg(dac_node[vfat], initial_thr[vfat])
        sleep(1e-3)
        #print ("")

    # End of channel loop
    print ("")

    # Rate counters for entire VFATs
    print ("All VFATs, Channels: All")
    write_backend_reg(daq_monitor_select_node, 0)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.VFAT_CHANNEL_GLOBAL_OR"), 1)
    for vfat in vfat_list:
        # Unmask channels for this vfat
        for channel in range(0,128):
            enableVfatchannel(vfat, oh_select, channel, 0, 0) # unmask channels
    for thr in range(0,256,step):
        print ("  Threshold: %d"%thr)
        for vfat in vfat_list:
            write_backend_reg(dac_node[vfat], thr)
            sleep(1e-3)

        write_backend_reg(daq_monitor_reset_node, 1)
        write_backend_reg(daq_monitor_enable_node, 1)
        # Start the cyclic generator
        write_backend_reg(ttc_cyclic_start_node, 1)
        sleep(1.1)
        # Stop the cyclic generator
        write_backend_reg(ttc_reset_node, 1)
        write_backend_reg(daq_monitor_enable_node, 0)

        # Looping over VFATs
        for vfat in vfat_list:
            #daq_data[vfat]["all"][thr]["events"] = read_backend_reg(daq_monitor_event_count_node[vfat])
            daq_data[vfat]["all"][thr]["fired"] = read_backend_reg(daq_monitor_fire_count_node[vfat]) * runtime
            daq_data[vfat]["all"][thr]["time"] = runtime
        # End of VFAT loop

    write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.VFAT_CHANNEL_GLOBAL_OR"), 0)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 0)

    # Disable channels on VFATs
    for vfat in vfat_list:
        write_backend_reg(dac_node[vfat], initial_thr[vfat])
        print("Unconfiguring VFAT %d" % (vfat))
        for channel in range(0,128):
            enableVfatchannel(vfat, oh_select, channel, 0, 0) # unmask all channels
        configureVfat(0, vfat, oh_select, 0)

    # Writing Results
    for vfat in vfat_list:
        for channel in channel_list:
            for thr in range(0,256,1):
                if thr not in daq_data[vfat][channel]:
                    continue
                if channel != "all":
                    file_out.write("%d    %d    %d    %f    %f\n"%(vfat, channel, thr, daq_data[vfat][channel][thr]["fired"], daq_data[vfat][channel][thr]["time"]))
                else:
                    file_out.write("%d    all    %d    %f    %f\n"%(vfat, thr, daq_data[vfat][channel][thr]["fired"], daq_data[vfat][channel][thr]["time"]))

    print ("")
    file_out.close()


if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 VFAT S-Bit Noise Rate")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--vfats", action="store", dest="vfats", nargs="+", help="vfats = VFAT number (0-23)")
    parser.add_argument("-a", "--all", action="store_true", dest="all", default=False, help="Set to only perform sbit rate measurement of OR of all channels in a VFAT")
    parser.add_argument("-p", "--parallel", action="store_true", dest="parallel", default=False, help="Set to unmask all channels in all VFATs simultaneosuly for rate measurements")
    parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
    parser.add_argument("-t", "--step", action="store", dest="step", default="1", help="step = Step size for threshold scan (default = 1)")
    parser.add_argument("-m", "--time", action="store", dest="time", default="0.001", help="time = time for each elink in sec (default = 0.001 s or 1 ms)")
    parser.add_argument("-b", "--bxgap", action="store", dest="bxgap", default="500", help="bxgap = Nr. of BX between two L1As (default = 500 i.e. 12.5 us)")
    parser.add_argument("-z", "--verbose", action="store_true", dest="verbose", default=False, help="Set for more verbosity")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for S-bit Noise Rate")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running vfat noise rate")
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

    channel_list = [i for i in range(0, 128)]
    channel_list.append("all")

    step = int(args.step)
    if step not in range(1,257):
        print (Colors.YELLOW + "Step size can only be between 1 and 256" + Colors.ENDC)
        sys.exit()

    if args.use_channel_trimming is not None:
        if args.use_channel_trimming not in ["daq", "sbit"]:
            print (Colors.YELLOW + "Only allowed options for use_channel_trimming: daq or sbit" + Colors.ENDC)
            sys.exit()

    l1a_bxgap = int(args.bxgap)
    l1a_timegap = l1a_bxgap * 25 * 0.001 # in microseconds
    if l1a_bxgap<25:
        print (Colors.YELLOW + "Gap between L1As should be at least 25 BX to read out enitre DAQ data packets" + Colors.ENDC)
        sys.exit()
    else:
        print ("Gap between consecutive L1A = %d BX = %.2f us" %(l1a_bxgap, l1a_timegap))

    if args.all and args.parallel:
        print (Colors.YELLOW + "All and Parallel cannot be given together" + Colors.ENDC)
        sys.exit()

    # Initialization 
    initialize(args.gem, args.system)
    initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")

    # Running Sbit Noise Rate
    try:
        vfat_daq(args.gem, args.system, int(args.ohid), vfat_list, channel_list, step, float(args.time), l1a_bxgap, args.parallel, args.all, args.verbose)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




