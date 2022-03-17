from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse
import random
import json
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel

def vfat_sbit(gem, system, oh_select, vfat_list, nl1a, calpulse_only, l1a_bxgap, set_cal_mode, cal_dac):
    print ("%s VFAT S-Bit Mapping\n"%gem)

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

    # Reading S-bit counter
    cyclic_running_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_RUNNING")
    l1a_node = get_backend_node("BEFE.GEM.TTC.CMD_COUNTERS.L1A")
    calpulse_node = get_backend_node("BEFE.GEM.TTC.CMD_COUNTERS.CALPULSE")

    elink_sbit_select_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_ELINK_SBIT_ME0") # Node for selecting Elink to count
    channel_sbit_select_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_SBIT_ME0") # Node for selecting S-bit to count
    elink_sbit_counter_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SBIT0XE_COUNT_ME0") # S-bit counter for elink
    channel_sbit_counter_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SBIT0XS_COUNT_ME0") # S-bit counter for specific channel
    reset_sbit_counter_node = get_backend_node("BEFE.GEM.SBIT_ME0.CTRL.SBIT_TEST_RESET")  # To reset all S-bit counters

    # Configure all VFATs
    for vfat in vfat_list:
        print("Configuring VFAT %02d" % (vfat))
        gbt, gbt_select, elink_daq, gpio = me0_vfat_to_gbt_elink_gpio(vfat)
        check_gbt_link_ready(oh_select, gbt_select)

        link_good = read_backend_reg(get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat)))
        sync_err = read_backend_reg(get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat)))
        if system!="dryrun" and (link_good == 0 or sync_err > 0):
            print (Colors.RED + "Link is bad for VFAT# %02d"%(vfat) + Colors.ENDC)
            terminate()
            
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
    print ("")

    # Starting VFAT loop
    s_bit_channel_mapping = {}
    for vfat in vfat_list:
        print ("Testing VFAT#: %02d" %(vfat))
        print ("")
        write_backend_reg(get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_VFAT_SBIT_ME0"), vfat) # Select VFAT for reading S-bits

        s_bit_channel_mapping[vfat] = {}
        # Looping over all 8 elinks
        for elink in range(0,8):
            print ("Phase scan for S-bits in ELINK# %02d" %(elink))
            write_backend_reg(elink_sbit_select_node, elink) # Select elink for S-bit counter

            s_bit_channel_mapping[vfat][elink] = {}
            s_bit_matches = {}
            for sbit in range(elink*8,elink*8+8):
                s_bit_matches[sbit] = 0

            # Looping over all channels in that elink
            for channel in range(elink*16,elink*16+16):
                # Enabling the pulsing channel
                enableVfatchannel(vfat, oh_select, channel, 0, 1) # unmask this channel and enable calpulsing

                channel_sbit_counter_final = {}
                sbit_channel_match = 0
                s_bit_channel_mapping[vfat][elink][channel] = -9999

                # Looping over all s-bits in that elink
                for sbit in range(elink*8,elink*8+8):
                    # Reset L1A, CalPulse and S-bit counters
                    write_backend_reg(ttc_cnt_reset_node, 1)
                    write_backend_reg(reset_sbit_counter_node, 1)

                    write_backend_reg(channel_sbit_select_node, sbit) # Select S-bit for S-bit counter

                    # Start the cyclic generator
                    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START"), 1)
                    cyclic_running = read_backend_reg(cyclic_running_node)
                    while cyclic_running:
                        cyclic_running = read_backend_reg(cyclic_running_node)

                    # Stop the cyclic generator
                    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)

                    elink_sbit_counter_final = read_backend_reg(elink_sbit_counter_node)
                    l1a_counter = read_backend_reg(l1a_node)
                    calpulse_counter = read_backend_reg(calpulse_node)

                    if calpulse_counter == 0:
                        # Calpulse Counter is 0
                        s_bit_channel_mapping[vfat][elink][channel] = -9999
                        break

                    if system!="dryrun" and elink_sbit_counter_final != calpulse_counter:
                        print (Colors.YELLOW + "WARNING: Elink %02d did not register any S-bit for calpulse on channel %02d"%(elink, channel) + Colors.ENDC)
                        s_bit_channel_mapping[vfat][elink][channel] = -9999
                        break
                    channel_sbit_counter_final[sbit] = read_backend_reg(channel_sbit_counter_node)

                    if channel_sbit_counter_final[sbit] == calpulse_counter:
                        if sbit_channel_match == 1:
                            print (Colors.YELLOW + "WARNING: Multiple S-bits registered hits for calpulse on channel %02d"%(channel) + Colors.ENDC)
                            s_bit_channel_mapping[vfat][elink][channel] = -9999
                            break
                        if s_bit_matches[sbit] >= 2:
                            print (Colors.YELLOW + "WARNING: S-bit %02d already matched to 2 channels"%(sbit) + Colors.ENDC)
                            s_bit_channel_mapping[vfat][elink][channel] = -9999
                            break
                        if s_bit_matches[sbit] == 1:
                            if s_bit_channel_mapping[vfat][elink][channel-1] != sbit:
                                print (Colors.YELLOW + "WARNING: S-bit %02d matched to a different channel than the previous one"%(sbit) + Colors.ENDC)
                                s_bit_channel_mapping[vfat][elink][channel] = -9999
                                break
                            if channel%2==0:
                                print (Colors.YELLOW + "WARNING: S-bit %02d already matched to an earlier odd numbered channel"%(sbit) + Colors.ENDC)
                                s_bit_channel_mapping[vfat][elink][channel] = -9999
                                break
                        s_bit_channel_mapping[vfat][elink][channel] = sbit
                        sbit_channel_match = 1
                        s_bit_matches[sbit] += 1
                # End of S-bit loop for this channel

                # Disabling the pulsing channels
                enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask this channel and disable calpulsing
            # End of Channel loop

            print ("")
        # End of Elink loop
        print ("")
    # End of VFAT loop

    # Unconfigure all VFATs
    for vfat in vfat_list:
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
    dataDir = "results/vfat_data/vfat_sbit_mapping_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/%s_OH%d_vfat_sbit_mapping_results_"%(gem,oh_select) + now + ".py"
    filename_data = dataDir + "/%s_OH%d_vfat_sbit_mapping_data_"%(gem,oh_select) + now + ".txt"
    with open(filename, "w") as file:
        file.write(json.dumps(s_bit_channel_mapping))
    file_out_data = open(filename_data, "w")

    print ("S-bit Mapping Results: \n")
    file_out_data.write("S-bit Mapping Results: \n\n")
    bad_channels_string = Colors.RED + "\n Bad Channels: \n"
    bad_channel_count = 0
    for vfat in s_bit_channel_mapping:
        print ("VFAT %02d: "%(vfat))
        file_out_data.write("VFAT %02d: \n"%(vfat))
        for elink in s_bit_channel_mapping[vfat]:
            print ("  ELINK %02d: "%(elink))
            file_out_data.write("  ELINK %02d: \n"%(elink))
            for channel in s_bit_channel_mapping[vfat][elink]:
                if s_bit_channel_mapping[vfat][elink][channel] == -9999:
                    print (Colors.RED + "    Channel %02d:  S-bit %02d"%(channel, s_bit_channel_mapping[vfat][elink][channel]) + Colors.ENDC)
                    file_out_data.write(Colors.RED + "    Channel %02d:  S-bit %02d\n"%(channel, s_bit_channel_mapping[vfat][elink][channel]) + Colors.ENDC)
                    bad_channels_string += "  VFAT %02d, Elink %02d, Channel %02d\n"%(vfat, elink, channel)
                    bad_channel_count += 1
                else:
                    print (Colors.GREEN + "    Channel %02d:  S-bit %02d"%(channel, s_bit_channel_mapping[vfat][elink][channel]) + Colors.ENDC)
                    file_out_data.write(Colors.GREEN + "    Channel %02d:  S-bit %02d\n"%(channel, s_bit_channel_mapping[vfat][elink][channel]) + Colors.ENDC)
        print ("")
        file_out_data.write("\n")
    bad_channels_string += "\n" + Colors.ENDC
    if bad_channel_count != 0:
        print (bad_channels_string)
        file_out_data.write(bad_channels_string)
    else:
        print (Colors.GREEN + "No Bad Channels in Mapping\n" + Colors.ENDC)
        file_out_data.write(Colors.GREEN + "No Bad Channels in Mapping\n\n" + Colors.ENDC)

    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)
    print ("\nS-bit mapping done\n")
    file_out_data.close()

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 VFAT S-Bit Mapping")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0")
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
        print ("Using Backend for S-bit Mapping")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running sbit mapping")
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
        vfat_sbit(args.gem, args.system, int(args.ohid), vfat_list, int(args.nl1a), args.calpulse_only, int(args.bxgap), set_cal_mode, cal_dac)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




