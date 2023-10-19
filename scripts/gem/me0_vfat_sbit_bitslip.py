from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse
import random
import json
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel

def vfat_sbit(gem, system, oh_select, vfat_list, nl1a, calpulse_only, l1a_bxgap, set_cal_mode, cal_dac, n_allowed_missing_hits, input_file, bitslip_all):
    print ("%s VFAT S-Bit Bitslipping\n"%gem)

    if bitslip_all is not None:
        for vfat_in in vfat_list:
            for elink_in in range(8):
                bitslip_in = int(bitslip_all)
                print ("Bitslip set for VFAT %d Elink %d: %d"%(vfat_in, elink_in, bitslip_in))
                write_backend_reg(get_backend_node("BEFE.GEM.SBIT_ME0.OH%d_BITSLIP.VFAT%d.ELINK%d_MAP"%(oh_select,vfat_in,elink_in)), bitslip_in)
        print ("\nS-bit Bitslipping done\n")
        return

    if input_file is not None:
        file_in = open(input_file)
        for line in file_in.readlines():
            if "VFAT" in line:
                continue
            vfat_in = int(line.split()[0])
            elink_in = int(line.split()[1])
            bitslip_in = int(line.split()[2])
            print ("Bitslip set for VFAT %d Elink %d: %d"%(vfat_in, elink_in, bitslip_in))
            write_backend_reg(get_backend_node("BEFE.GEM.SBIT_ME0.OH%d_BITSLIP.VFAT%d.ELINK%d_MAP"%(oh_select,vfat_in,elink_in)), bitslip_in)

        file_in.close()
        print ("\nS-bit Bitslipping done\n")
        return

    global_reset()
    #gem_link_reset()
    #sleep(0.1)
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

    write_backend_reg(get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_OH_SBIT_ME0"), oh_select)
    elink_sbit_select_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_ELINK_SBIT_ME0") # Node for selecting Elink to count
    channel_sbit_select_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_SBIT_ME0") # Node for selecting S-bit to count
    elink_sbit_counter_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SBIT0XE_COUNT_ME0") # S-bit counter for elink
    channel_sbit_counter_node = get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SBIT0XS_COUNT_ME0") # S-bit counter for specific channel
    reset_sbit_counter_node = get_backend_node("BEFE.GEM.SBIT_ME0.CTRL.SBIT_TEST_RESET")  # To reset all S-bit counters
    sbit_bistlip_nodes = {}
    for vfat in vfat_list:
        sbit_bistlip_nodes[vfat] = {}
        for elink in range(8):
            sbit_bistlip_nodes[vfat][elink] = get_backend_node("BEFE.GEM.SBIT_ME0.OH%d_BITSLIP.VFAT%d.ELINK%d_MAP"%(oh_select,vfat,elink))

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
            cal_dur = 200
            if l1a_bxgap < 225:
                cal_dur = l1a_bxgap - 25
            if cal_dur < 20:
                cal_dur = 20
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"% (oh_select, vfat)), cal_dur)
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
    sbit_bitslip_values = {}
    for vfat in vfat_list:
        print ("Testing VFAT#: %02d" %(vfat))
        print ("")
        write_backend_reg(get_backend_node("BEFE.GEM.SBIT_ME0.TEST_SEL_VFAT_SBIT_ME0"), vfat) # Select VFAT for reading S-bits

        sbit_bitslip_values[vfat] = {}
        # Looping over all 8 elinks
        for elink in range(0,8):
            print ("Phase scan for S-bits in ELINK# %02d" %(elink))
            write_backend_reg(elink_sbit_select_node, elink) # Select elink for S-bit counter

            sbit_bitslip_values[vfat][elink] = -9999

            channel = elink*16
            correct_sbit = elink*8
            # Enabling the pulsing channel
            enableVfatchannel(vfat, oh_select, channel, 0, 1) # unmask this channel and enable calpulsing

            # Looping over all bitslip values
            for bitslip in range(8):
                
                # Set bitslip
                write_backend_reg(sbit_bistlip_nodes[vfat][elink], bitslip)

                channel_sbit_counter_final = {}
                sbit_channel_match = 0
                sbit_matched = -9999

                # Looping over all s-bits in that elink
                for sbit in range(elink*8,elink*8+8):
                    # Reset L1A, CalPulse and S-bit counters
                    write_backend_reg(ttc_cnt_reset_node, 1)
                    write_backend_reg(reset_sbit_counter_node, 1)

                    write_backend_reg(channel_sbit_select_node, sbit) # Select S-bit for S-bit counter

                    # Start the cyclic generator
                    sleep(0.001)
                    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START"), 1)
                    sleep(0.001)
                    cyclic_running = read_backend_reg(cyclic_running_node)
                    while cyclic_running:
                        cyclic_running = read_backend_reg(cyclic_running_node)

                    # Stop the cyclic generator
                    sleep(0.001)
                    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
                    sleep(0.001)

                    elink_sbit_counter_final = read_backend_reg(elink_sbit_counter_node)
                    l1a_counter = read_backend_reg(l1a_node)
                    calpulse_counter = read_backend_reg(calpulse_node)

                    if calpulse_counter == 0:
                        # Calpulse Counter is 0
                        sbit_matched = -9999
                        break

                    if system!="dryrun" and abs(elink_sbit_counter_final - calpulse_counter) > n_allowed_missing_hits:
                        print (Colors.YELLOW + "WARNING: Elink %02d did not register the correct number of hits on channel %02d"%(elink, channel) + Colors.ENDC)
                        sbit_matched = -9999
                        break
                    channel_sbit_counter_final[sbit] = read_backend_reg(channel_sbit_counter_node)

                    if abs(channel_sbit_counter_final[sbit] - calpulse_counter) <= n_allowed_missing_hits:
                        if sbit_channel_match == 1:
                            print (Colors.YELLOW + "WARNING: Multiple S-bits registered hits for calpulse on channel %02d"%(channel) + Colors.ENDC)
                            sbit_matched = -9999
                            break
                        sbit_matched = sbit
                        sbit_channel_match = 1
                # End of S-bit loop for this channel

                if sbit_matched == correct_sbit:
                    sbit_bitslip_values[vfat][elink] = bitslip
                    break

            # End of bitslip loop

            # Disabling the pulsing channels
            enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask this channel and disable calpulsing
            # Set bitslip back to 0
            write_backend_reg(sbit_bistlip_nodes[vfat][elink], 0)

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
    
    scripts_gem_dir = get_befe_scripts_dir() + '/gem'
    resultDir = scripts_gem_dir + "/results"
    vfatDir = resultDir + "/vfat_data"
    try:
        os.makedirs(vfatDir) # create directory for VFAT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = vfatDir + "/vfat_sbit_bitslip_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/%s_OH%d_vfat_sbit_bitslip_results_"%(gem,oh_select) + now + ".txt"
    filename_data = dataDir + "/%s_OH%d_vfat_sbit_bitslip_data_"%(gem,oh_select) + now + ".txt"
    file_out = open(filename, "w")
    file_out_data = open(filename_data, "w")
    file_out.write("VFAT    Elink    Bitslip\n")

    print ("S-bit Bitslipping Results: \n")
    file_out_data.write("S-bit Bitslipping Results: \n\n")
    bad_elinks_string = Colors.RED + "\n Bad Elinks: \n"
    bad_elink_count = 0
    for vfat in sbit_bitslip_values:
        print ("VFAT %02d: "%(vfat))
        file_out_data.write("VFAT %02d: \n"%(vfat))
        for elink in sbit_bitslip_values[vfat]:
            print ("  ELINK %02d: "%(elink))
            file_out_data.write("  ELINK %02d: \n"%(elink))
            file_out.write("%d    %d    %d\n"%(vfat, elink, sbit_bitslip_values[vfat][elink]))
            if sbit_bitslip_values[vfat][elink] == -9999:
                print (Colors.RED + "    Bit slip not set, value %02d"%(sbit_bitslip_values[vfat][elink]) + Colors.ENDC)
                file_out_data.write(Colors.RED + "    Bit slip not set, value %02d\n"%(sbit_bitslip_values[vfat][elink]) + Colors.ENDC)
                bad_elinks_string += "  VFAT %02d, Elink %02d\n"%(vfat, elink)
                bad_elink_count += 1
            else:
                print (Colors.GREEN + "    Bit slip set to value %02d"%(sbit_bitslip_values[vfat][elink]) + Colors.ENDC)
                file_out_data.write(Colors.GREEN + "    Bit slip set to value %02d\n"%(sbit_bitslip_values[vfat][elink]) + Colors.ENDC)
                # Set bitslip
                write_backend_reg(sbit_bistlip_nodes[vfat][elink], sbit_bitslip_values[vfat][elink])

        print ("")
        file_out_data.write("\n")
    bad_elinks_string += "\n" + Colors.ENDC
    if bad_elink_count != 0:
        print (bad_elinks_string)
        file_out_data.write(bad_elinks_string)
    else:
        print (Colors.GREEN + "No Bad Elinks in Bitslipping\n" + Colors.ENDC)
        file_out_data.write(Colors.GREEN + "No Bad Elinks in Bitslipping\n\n" + Colors.ENDC)

    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)
    print ("\nS-bit Bistlipping done\n")
    file_out.close()
    file_out_data.close()

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 VFAT S-Bit Bitslipping")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-n", "--nl1a", action="store", dest="nl1a", default = "1000", help="nl1a = fixed number of L1A cycles")
    parser.add_argument("-l", "--calpulse_only", action="store_true", dest="calpulse_only", help="calpulse_only = to use only calpulsing without L1A's")
    parser.add_argument("-b", "--bxgap", action="store", dest="bxgap", default="20", help="bxgap = Nr. of BX between two L1As (default = 20 i.e. 0.5 us)")
    parser.add_argument("-x", "--n_miss", action="store", dest="n_miss", default = "5", help="n_miss = Max nr. of missing hits allowed")
    parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
    parser.add_argument("-t", "--bitslip", action="store", dest="bitslip", help="bitslip = write this bitslip to all elinks of vfats")
    parser.add_argument("-f", "--input_file", action="store", dest="input_file", help="input_file = write bitslip from this input file")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for S-bit Bitslipping")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running sbit bitslipping")
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

    if args.input_file is not None and args.bitslip is not None:
        print (Colors.YELLOW + "Can't give input file and bitslip value at the same time" + Colors.ENDC)
        sys.exit()

    if args.bitslip is not None:
        bitslip_all = int(args.bitslip)
        if bitslip_all not in range(8):
            print (Colors.YELLOW + "Only allowed bitslip values 0-7" + Colors.ENDC)
            sys.exit()

    set_cal_mode = "current"
    cal_dac = 150 # should be 50 for voltage pulse mode
        
    # Initialization 
    initialize(args.gem, args.system)
    initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")

    # Running Phase Scan
    try:
        vfat_sbit(args.gem, args.system, int(args.ohid), vfat_list, int(args.nl1a), args.calpulse_only, int(args.bxgap), set_cal_mode, cal_dac, int(args.n_miss), args.input_file, args.bitslip)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




