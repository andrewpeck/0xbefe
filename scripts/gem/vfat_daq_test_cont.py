from gem.gem_utils import *
from time import sleep, time
import sys
import argparse
import random
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel, dump_vfat_config
import datetime

def vfat_bert(gem, system, oh_select, vfat_list, set_cal_mode, cal_dac, nl1a, l1a_bxgap, calpulse, do_print):
    
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
    dataDir = "results/vfat_data/vfat_daq_test_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    file_out = open(dataDir+"/%s_OH%d_vfat_daq_test_cont_output_"%(gem,oh_select) + now + ".txt", "w+")

    print ("Reset VFAT links\n")
    global_reset()
    #gem_link_reset()
    #sleep(0.1)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)
    sleep(0.1)

    link_good_node = {}
    sync_error_node = {}
    daq_event_count_node = {}
    daq_crc_error_node = {}
   
    l1a_rate = 1e9/(l1a_bxgap * 25) # in Hz
    efficiency = 1
    if l1a_rate > 1e6 * 0.5:
        efficiency = 0.977

    # Check ready and get nodes
    for vfat in vfat_list:
        gbt, gbt_select, elink, gpio = me0_vfat_to_gbt_elink_gpio(vfat)
        check_gbt_link_ready(oh_select, gbt_select)

        print("Configuring VFAT %d" % (vfat))
        file_out.write("Configuring VFAT %d\n" % (vfat))
        if calpulse:
            configureVfat(1, vfat, oh_select, 0)
            for channel in range(128):
                enableVfatchannel(vfat, oh_select, channel, 0, 0) # unmask all channels and disable calpulsing
            enableVfatchannel(vfat, oh_select, 0, 0, 1) # enable calpulsing on channel 0 for this VFAT
        else:
            configureVfat(1, vfat, oh_select, 1) # configure with 0 threshold to get noise
            for channel in range(128):
                enableVfatchannel(vfat, oh_select, channel, 0, 0) # unmask all channels and disable calpulsing
        write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_LATENCY"% (oh_select, vfat)), 18)
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

        link_good_node[vfat] = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat))
        sync_error_node[vfat] = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat))
        link_good = read_backend_reg(link_good_node[vfat])
        sync_err = read_backend_reg(sync_error_node[vfat])
        if system!="dryrun" and (link_good == 0 or sync_err > 0):
            print (Colors.RED + "Link is bad for VFAT# %02d"%(vfat) + Colors.ENDC)
            terminate()
        daq_event_count_node[vfat] = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.DAQ_EVENT_CNT" % (oh_select, vfat))
        daq_crc_error_node[vfat] = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.DAQ_CRC_ERROR_CNT" % (oh_select, vfat))

    sleep(1)

    # Configure TTC generator
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_GAP"), l1a_bxgap)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_COUNT"), nl1a)

    if calpulse:
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 25)
    else:
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 0) # Disable Calpulsing

    print ("\nStarting DAQ test for VFATs:")
    file_out.write("\nStarting L1A's for VFATs:\n")
    print (vfat_list)
    for vfat in vfat_list:
        file_out.write(str(vfat) + "  ")
    file_out.write("\n")
    print ("")
    file_out.write("\n")
    cyclic_running_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_RUNNING")
    ttc_cnt_reset_node = get_backend_node("BEFE.GEM.TTC.CTRL.MODULE_RESET")
    l1a_node = get_backend_node("BEFE.GEM.TTC.CMD_COUNTERS.L1A")
    calpulse_node = get_backend_node("BEFE.GEM.TTC.CMD_COUNTERS.CALPULSE")

    n_reset = 0
    nl1a_reg_cycles = 0
    l1a_counter = 0
    t0 = time()
    time_prev = t0
    
    if do_print:
        vfatDir = dataDir + "%s_OH%d_vfat_daq_test_cont_vfat_data_"%(gem,oh_select) + now
        vfat_out_filename = vfatDir+"/vfat_data_nreset_%d"%(n_reset) + ".txt"
        vfat_out_file = open(vfat_out_filename)
        vfat_out_file.write("VFAT    register    value")
        for vfat in vfat_list:
            dump_vfat_data = dump_vfat_config(oh_select, vfat)
            for reg in dump_vfat_data:
                vfat_out_file.write("%d    %s    %d"%(vfat, reg, dump_vfat_data[reg]))
        vfat_out_file.close()

    # Start the cyclic generator
    sleep(0.001)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START"), 1)
    sleep(0.001)

    cyclic_running = read_backend_reg(cyclic_running_node)

    print ("Starting L1A's, press Ctrl+C to end\n")
    file_out.write("Starting L1A's, press Ctrl+C to end\n")

    while cyclic_running:
        try:  
            time_passed = (time()-time_prev)/60.0
            if time_passed >= 1:
                # Stop L1A's
                sleep(0.001)
                write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
                sleep(0.001)

                # Check counters 
                if (read_backend_reg(l1a_node) < l1a_counter):
                    nl1a_reg_cycles += 1
                l1a_counter = read_backend_reg(l1a_node)
                calpulse_counter = read_backend_reg(calpulse_node)
                real_l1a_counter = nl1a_reg_cycles*(2**32) + l1a_counter
                if calpulse:
                    real_calpulse_counter = nl1a_reg_cycles*(2**32) + calpulse_counter
                else:
                    real_calpulse_counter = calpulse_counter

                print ("Number of resets due to mismatches = %d"%n_reset)
                file_out.write("Number of resets due to mismatches = %d\n"%n_reset)
                print ("Time passed: %.2f minutes, L1A counter = %.2e,  Calpulse counter = %.2e" % ((time()-t0)/60.0, real_l1a_counter, real_calpulse_counter))
                file_out.write("Time passed: %.2f minutes, L1A counter = %.2e,  Calpulse counter = %.2e\n" % ((time()-t0)/60.0, real_l1a_counter, real_calpulse_counter))
                vfat_results_string = ""
                n_mismatch = 0
                vfat_mismatch = []
                for vfat in vfat_list:
                    daq_event_count_temp = read_backend_reg(daq_event_count_node[vfat])
                    daq_error_count_temp = read_backend_reg(daq_crc_error_node[vfat])
                    vfat_results_string += "VFAT %02d: DAQ Event Counter = %d, L1A Counter - DAQ Event Counter = %d, DAQ Errors = %d\n"%(vfat, daq_event_count_temp, real_l1a_counter%(2**16) - daq_event_count_temp, daq_error_count_temp) 
                    if (real_l1a_counter%(2**16) - daq_event_count_temp) != 0:
                        vfat_mismatch.append(vfat)
                        n_mismatch += 1
                print (vfat_results_string)
                file_out.write(vfat_results_string + "\n")
                vfat_mismatch_str = ', '.join(str(x) for x in vfat_mismatch)

                if n_mismatch != 0:
                    print (Colors.YELLOW + "\nEncountered L1A and DAQ Event Counter mismatches in VFATs: %s; sending reset and starting again\n"%vfat_mismatch_str + Colors.ENDC)
                    file_out.write("\nEncountered L1A and DAQ Event Counter mismatches in VFATs: %s; sending reset and starting again\n\n"%vfat_mismatch_str)

                    # Reset links and counters
                    gem_link_reset()
                    write_backend_reg(ttc_cnt_reset_node, 1)
                    n_reset += 1
                    nl1a_reg_cycles = 0
                    l1a_counter = 0
                    t0 = time()

                    if do_print:
                        vfatDir = dataDir + "%s_OH%d_vfat_daq_test_cont_vfat_data_"%(gem,oh_select) + now
                        vfat_out_filename = vfatDir+"/vfat_data_nreset_%d"%(n_reset) + ".txt"
                        vfat_out_file = open(vfat_out_filename)
                        vfat_out_file.write("VFAT    register    value")
                        for vfat in vfat_list:
                            dump_vfat_data = dump_vfat_config(oh_select, vfat)
                            for reg in dump_vfat_data:
                                vfat_out_file.write("%d    %s    %d"%(vfat, reg, dump_vfat_data[reg]))
                        vfat_out_file.close()

                # Start L1A's 
                sleep(0.001)
                write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START"), 1)
                sleep(0.001)
                            
                time_prev = time()
            cyclic_running = read_backend_reg(cyclic_running_node)
        except KeyboardInterrupt:
            cyclic_running = 0

    # Stop the cyclic generator
    sleep(0.001)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 0)
    sleep(0.001)

    print ("\nStopped L1A's\n")
    file_out.write("\nStopped L1A's\n")

    # Disable channels on VFATs
    for vfat in vfat_list:
        enable_channel = 0
        print("Unconfiguring VFAT %d" % (vfat))
        file_out.write("Unconfiguring VFAT %d\n" % (vfat))
        for channel in range(128):
            enableVfatchannel(vfat, oh_select, channel, 0, 0) # unmask all channels and disable calpulsing 
        configureVfat(0, vfat, oh_select, 0)

    file_out.close()
if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="VFAT DAQ Error Ratio Test")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 or GE21 or GE11")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-m", "--cal_mode", action="store", dest="cal_mode", default = "voltage", help="cal_mode = voltage or current (default = voltage), only required when calpulsing")
    parser.add_argument("-d", "--cal_dac", action="store", dest="cal_dac", help="cal_dac = Value of CAL_DAC register (default = 50 for voltage pulse mode and 150 for current pulse mode)")
    parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
    parser.add_argument("-b", "--bxgap", action="store", dest="bxgap", default="500", help="bxgap = Nr. of BX between two L1As (default = 500 i.e. 12.5 us)")
    parser.add_argument("-c", "--calpulse", action="store_true", dest="calpulse", help="if calpulsing for all channels should be enabled")
    parser.add_argument("-p", "--print", action="store_true", dest="print", help="to dump all VFAT config if errors encountered")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for VFAT DAQ BERT")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running vfat daq bert")
    else:
        print (Colors.YELLOW + "Only valid options: backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem not in ["ME0", "GE21" or "GE11"]:
        print(Colors.YELLOW + "Valid gem stations: ME0, GE21, GE11" + Colors.ENDC)
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
    
    l1a_bxgap = int(args.bxgap)
    l1a_timegap = l1a_bxgap * 25 * 0.001 # in microseconds
    if l1a_bxgap<25:
        print (Colors.YELLOW + "Gap between L1As should be at least 25 BX to read out enitre DAQ data packets" + Colors.ENDC)
        sys.exit()
    else:
        print ("Gap between consecutive L1A or CalPulses = %d BX = %.2f us" %(l1a_bxgap, l1a_timegap))

    if args.calpulse:
        print ("Calpulsing enabled for all channels for given VFATs")

    if args.use_channel_trimming is not None:
        if args.use_channel_trimming not in ["daq", "sbit"]:
            print (Colors.YELLOW + "Only allowed options for use_channel_trimming: daq or sbit" + Colors.ENDC)
            sys.exit()

    # Initialization 
    initialize(args.gem, args.system)
    initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")

    # Running Phase Scan 
    try:
        vfat_bert(args.gem, args.system, int(args.ohid), vfat_list, cal_mode, cal_dac, nl1a, l1a_bxgap, args.calpulse args.print)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




