from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse
import random
import glob
import json
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel

def vfat_sbit(gem, system, oh_select, vfat_list, sbit_list, step, runtime, s_bit_channel_mapping, parallel, all, verbose):

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
    dataDir = "results/vfat_data/vfat_sbit_noise_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/%s_OH%d_vfat_sbit_noise_"%(gem,oh_select) + now + ".txt"
    file_out = open(filename,"w+")
    file_out.write("vfat    sbit    threshold    fired    time\n")

    gem_link_reset()
    global_reset()
    sleep(0.1)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)

    sbit_data = {}
    # Check ready and get nodes
    for vfat in vfat_list:
        gbt, gbt_select, elink, gpio = me0_vfat_to_gbt_elink_gpio(vfat)
        check_gbt_link_ready(oh_select, gbt_select)

        print("Configuring VFAT %d" % (vfat))
        configureVfat(1, vfat, oh_select, 0)
        for channel in range(0,128):
            enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask all channels and disable calpulsing

        link_good_node = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat))
        sync_error_node = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat))
        link_good = read_backend_reg(link_good_node)
        sync_err = read_backend_reg(sync_error_node)
        if system!="dryrun" and (link_good == 0 or sync_err > 0):
            print (Colors.RED + "Link is bad for VFAT# %02d"%(vfat) + Colors.ENDC)
            terminate()

        sbit_data[vfat] = {}
        for sbit in sbit_list:
            sbit_data[vfat][sbit] = {}
            for thr in range(0,256,step):
                sbit_data[vfat][sbit][thr] = {}
                sbit_data[vfat][sbit][thr]["time"] = -9999
                sbit_data[vfat][sbit][thr]["fired"] = -9999

    sleep(1)

    # Nodes for Sbit counters
    vfat_sbit_select_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_VFAT_SBIT_ME0") # VFAT for reading S-bits
    elink_sbit_select_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_ELINK_SBIT_ME0") # Node for selecting Elink to count
    channel_sbit_select_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_SBIT_ME0") # Node for selecting S-bit to count
    elink_sbit_counter_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SBIT0XE_COUNT_ME0") # S-bit counter for elink
    channel_sbit_counter_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SBIT0XS_COUNT_ME0") # S-bit counter for specific channel
    reset_sbit_counter_node = get_backend_node("BEFE.GEM.SBIT_ME0.CTRL.SBIT_TEST_RESET")  # To reset all S-bit counters
    reset_sbit_vfat_node = get_backend_node("BEFE.GEM.SBIT_ME0.CTRL.MODULE_RESET")  # To reset VFAT S-bit rate registers

    dac_node = {}
    vfat_counter_node = {}
    dac = "CFG_THR_ARM_DAC"
    for vfat in vfat_list:
        dac_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%d.%s"%(oh_select, vfat, dac))
        vfat_counter_node[vfat] = get_backend_node("BEFE.GEM.SBIT_ME0.ME0_VFAT%d_SBIT_RATE"%vfat) # S-bit counter for enitre VFAT

    print ("\nRunning Sbit Noise Scans for VFATs:")
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
            write_backend_reg(dac_node[vfat], 0)

    # Looping over VFATs
    for vfat in vfat_list:
        if all:
            for sbit in sbit_list:
                for thr in range(0,256,step):
                    sbit_data[vfat][sbit][thr]["fired"] = 0
                    sbit_data[vfat][sbit][thr]["time"] = runtime
            continue
        print ("VFAT: %02d"%vfat)

        # Looping over sbits
        for sbit in sbit_list:
            if sbit == "all":
                continue
            if verbose:
                print ("  VFAT: %02d, Sbit: %d"%(vfat, sbit))
            elink = int(sbit/8)
            channel_list = []
            if str(vfat) not in s_bit_channel_mapping:
                print (Colors.YELLOW + "    Mapping not present for VFAT %02d"%(vfat) + Colors.ENDC)
                continue
            for c in s_bit_channel_mapping[str(vfat)][str(elink)]:
                if sbit == s_bit_channel_mapping[str(vfat)][str(elink)][c]:
                    channel_list.append(int(c))
            if len(channel_list)>2:
                print (Colors.YELLOW + "Skipping S-bit %02d, more than 2 channels"%sbit + Colors.ENDC)
                continue
            elif len(channel_list)==1:
                print (Colors.YELLOW + "S-bit %02d has 1 non-working channel"%sbit + Colors.ENDC)
            elif len(channel_list)==0:
                print (Colors.YELLOW + "Skipping S-bit %02d, missing both channels"%sbit + Colors.ENDC)
                continue
            write_backend_reg(vfat_sbit_select_node, vfat)
            write_backend_reg(channel_sbit_select_node, sbit)

            if not parallel:
                # Unmask channels for this sbit
                for channel in channel_list:
                    enableVfatchannel(vfat, oh_select, channel, 0, 0) # unmask channels

            # Looping over threshold
            for thr in range(0,256,step):
                #print ("    Threshold: %d"%thr)
                write_backend_reg(dac_node[vfat], thr)
                sleep(1e-3)

                # Count hits in sbit in given time
                write_backend_reg(reset_sbit_counter_node, 1)
                sleep(runtime)
                sbit_data[vfat][sbit][thr]["fired"] = read_backend_reg(channel_sbit_counter_node)
                sbit_data[vfat][sbit][thr]["time"] = runtime
            # End of threshold loop

            if not parallel:
                # Mask again channels for this sbit
                for channel in channel_list:
                    enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask channels

        # End of sbits loop
        if parallel:
            write_backend_reg(dac_node[vfat], 0)
        else:
            write_backend_reg(dac_node[vfat], initial_thr[vfat])
        sleep(1e-3)
        print ("")
    # End of VFAT loop
    print ("")

    if parallel:
        for vfat in vfat_list:
            write_backend_reg(dac_node[vfat], initial_thr[vfat])

    # Rate counters for entire VFATs
    print ("All VFATs, Sbit: All")
    for vfat in vfat_list:
        # Unmask channels for this vfat
        for channel in range(0,128):
            enableVfatchannel(vfat, oh_select, channel, 0, 0) # unmask channels
    for thr in range(0,256,step):
        print ("  Threshold: %d"%thr)
        for vfat in vfat_list:
            write_backend_reg(dac_node[vfat], thr)
            sleep(1e-3)
        write_backend_reg(reset_sbit_vfat_node, 1)
        sleep(1.1)
        for vfat in vfat_list:
            sbit_data[vfat]["all"][thr]["fired"] = read_backend_reg(vfat_counter_node[vfat]) * runtime
            sbit_data[vfat]["all"][thr]["time"] = runtime

    # Disable channels on VFATs
    for vfat in vfat_list:
        write_backend_reg(dac_node[vfat], initial_thr[vfat])
        print("Unconfiguring VFAT %d" % (vfat))
        for channel in range(0,128):
            enableVfatchannel(vfat, oh_select, channel, 0, 0) # unmask all channels
        configureVfat(0, vfat, oh_select, 0)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)

    # Writing Results
    for vfat in vfat_list:
        for sbit in sbit_list:
            for thr in range(0,256,1):
                if thr not in sbit_data[vfat][sbit]:
                    continue
                if sbit != "all":
                    file_out.write("%d    %d    %d    %d    %f\n"%(vfat, sbit, thr, sbit_data[vfat][sbit][thr]["fired"], sbit_data[vfat][sbit][thr]["time"]))
                else:
                    file_out.write("%d    all    %d    %d    %f\n"%(vfat, thr, sbit_data[vfat][sbit][thr]["fired"], sbit_data[vfat][sbit][thr]["time"]))

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

    step = int(args.step)
    if step not in range(1,257):
        print (Colors.YELLOW + "Step size can only be between 1 and 256" + Colors.ENDC)
        sys.exit()

    if args.all and args.parallel:
        print (Colors.YELLOW + "All and Parallel cannot be given together" + Colors.ENDC)
        sys.exit()

    sbit_list = [i for i in range(0,64)]
    sbit_list.append("all")
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

    if args.use_channel_trimming is not None:
        if args.use_channel_trimming not in ["daq", "sbit"]:
            print (Colors.YELLOW + "Only allowed options for use_channel_trimming: daq or sbit" + Colors.ENDC)
            sys.exit()

    # Initialization 
    initialize(args.gem, args.system)
    initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")

    # Running Sbit Noise Rate
    try:
        vfat_sbit(args.gem, args.system, int(args.ohid), vfat_list, sbit_list, step, float(args.time), s_bit_channel_mapping, args.parallel, args.all, args.verbose)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




