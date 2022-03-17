from gem.gem_utils import *
from time import sleep, time
import sys
import argparse
import random
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel
import datetime

def vfat_bert(gem, system, oh_select, vfat_list, set_cal_mode, cal_dac, nl1a, runtime, l1a_bxgap, calpulse):
    
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
    file_out = open(dataDir+"/%s_OH%d_vfat_daq_test_output_"%(gem,oh_select) + now + ".txt", "w+")

    if nl1a!=0:
        print ("VFAT Bit Error Ratio Test with %.2e L1As\n" % (nl1a))
        file_out.write("VFAT Bit Error Ratio Test with %.2e L1As\n\n" % (nl1a))
    elif runtime!=0:
        print ("VFAT Bit Error Ratio Test for %.2f minutes\n" % (runtime))
        file_out.write("VFAT Bit Error Ratio Test for %.2f minutes\n\n" % (runtime))
    errors = {}
    error_rates = {}

    gem_link_reset()
    global_reset()
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)
    sleep(0.1)

    link_good_node = {}
    sync_error_node = {}
    daq_event_count_node = {}
    daq_crc_error_node = {}
    daq_event_count_final = 24*[0]
    daq_crc_error_count_final = 24*[0]
    daq_event_count_diff = 24*[0]
    daq_crc_error_count_diff = 24*[0]

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
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"% (oh_select, vfat)), 200)
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

    if nl1a != 0:
        print ("\nRunning for %.2e L1A cycles for VFATs:" % (nl1a))
        file_out.write("\nRunning for %.2e L1A cycles for VFATs:\n" % (nl1a))
    else:
        print ("\nRunning for %f minutes for VFATs:" %(runtime))
        file_out.write("\nRunning for %f minutes for VFATs:\n" %(runtime))
    print (vfat_list)
    for vfat in vfat_list:
        file_out.write(str(vfat) + "  ")
    file_out.write("\n")
    print ("")
    file_out.write("\n")
    cyclic_running_node = get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_RUNNING")
    l1a_node = get_backend_node("BEFE.GEM.TTC.CMD_COUNTERS.L1A")
    calpulse_node = get_backend_node("BEFE.GEM.TTC.CMD_COUNTERS.CALPULSE")

    # Start the cyclic generator
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START"), 1)

    cyclic_running = read_backend_reg(cyclic_running_node)
    nl1a_reg_cycles = 0
    l1a_counter = 0
    t0 = time()
    time_prev = t0
    if nl1a != 0:
        while cyclic_running:
            cyclic_running = read_backend_reg(cyclic_running_node)
            time_passed = (time()-time_prev)/60.0
            if time_passed >= 1:
                expected_l1a = int(l1a_rate * (time()-t0) * efficiency)
                if (read_backend_reg(l1a_node) < l1a_counter):
                    #nl1a_reg_cycles = int(expected_l1a/(2**32))
                    nl1a_reg_cycles += 1
                l1a_counter = read_backend_reg(l1a_node)
                calpulse_counter = read_backend_reg(calpulse_node)
                real_l1a_counter = nl1a_reg_cycles*(2**32) + l1a_counter
                if calpulse:
                    real_calpulse_counter = nl1a_reg_cycles*(2**32) + calpulse_counter
                else:
                    real_calpulse_counter = calpulse_counter
                #daq_event_count_temp = read_backend_reg(daq_event_count_node[vfat])
                daq_event_count_temp = real_l1a_counter # since DAQ_EVENT_CNT is a 16-bit rolling counter
                print ("Time passed: %.2f minutes, L1A counter = %.2e,  Calpulse counter = %.2e, DAQ Events = %.2e" % ((time()-t0)/60.0, real_l1a_counter, real_calpulse_counter, daq_event_count_temp))
                file_out.write("Time passed: %.2f minutes, L1A counter = %.2e,  Calpulse counter = %.2e, DAQ Events = %.2e" % ((time()-t0)/60.0, real_l1a_counter, real_calpulse_counter, daq_event_count_temp))
                vfat_results_string = ""
                for vfat in vfat_list:
                    daq_error_count_temp = read_backend_reg(daq_crc_error_node[vfat])
                    vfat_results_string += "VFAT %02d DAQ Errors: %d, "%(vfat, daq_error_count_temp)
                print (vfat_results_string + "\n")
                file_out.write(vfat_results_string + "\n\n")
                time_prev = time()
    else:
        while ((time()-t0)/60.0) < runtime:
            time_passed = (time()-time_prev)/60.0
            if time_passed >= 1:
                expected_l1a = int(l1a_rate * (time()-t0) * efficiency)
                if (read_backend_reg(l1a_node) < l1a_counter):
                    #nl1a_reg_cycles = int(expected_l1a/(2**32))
                    nl1a_reg_cycles += 1
                l1a_counter = read_backend_reg(l1a_node)
                calpulse_counter = read_backend_reg(calpulse_node)
                real_l1a_counter = nl1a_reg_cycles*(2**32) + l1a_counter
                if calpulse:
                    real_calpulse_counter = nl1a_reg_cycles*(2**32) + calpulse_counter
                else:
                    real_calpulse_counter = calpulse_counter
                #daq_event_count_temp = read_backend_reg(daq_event_count_node[vfat])
                daq_event_count_temp = real_l1a_counter # since DAQ_EVENT_CNT is a 16-bit rolling counter
                print ("Time passed: %.2f minutes, L1A counter = %.2e,  Calpulse counter = %.2e, DAQ Events = %.2e" % ((time()-t0)/60.0, real_l1a_counter, real_calpulse_counter, daq_event_count_temp))
                file_out.write("Time passed: %.2f minutes, L1A counter = %.2e,  Calpulse counter = %.2e, DAQ Events = %.2e\n" % ((time()-t0)/60.0, real_l1a_counter, real_calpulse_counter, daq_event_count_temp))
                vfat_results_string = ""
                for vfat in vfat_list:
                    daq_error_count_temp = read_backend_reg(daq_crc_error_node[vfat])
                    vfat_results_string += "VFAT %02d DAQ Errors: %d, "%(vfat, daq_error_count_temp)
                print (vfat_results_string + "\n")
                file_out.write(vfat_results_string + "\n\n")
                time_prev = time()

    # Stop the cyclic generator
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 0)

    print ("")
    file_out.write("\n")
    total_time = time() - t0
    print ("L1A and Calpulsing cycle completed in %.2f seconds (%.2f minutes) \n"%(total_time, total_time/60.0))
    file_out.write("L1A and Calpulsing cycle completed in %.2f seconds (%.2f minutes) \n\n"%(total_time, total_time/60.0))
    l1a_counter = read_backend_reg(l1a_node)
    calpulse_counter = read_backend_reg(calpulse_node)

    print ("Error test results for DAQ elinks\n")
    file_out.write("Error test results for DAQ elinks\n\n")
    for vfat in vfat_list:
        link_good = read_backend_reg(link_good_node[vfat])
        sync_err = read_backend_reg(sync_error_node[vfat])
        if link_good == 1:
            print (Colors.GREEN + "VFAT#: %02d, link is GOOD"%(vfat) + Colors.ENDC)
            file_out.write("VFAT#: %02d, link is GOOD\n"%(vfat))
        else:
            print (Colors.RED + "VFAT#: %02d, link is BAD"%(vfat) + Colors.ENDC)
            file_out.write("VFAT#: %02d, link is BAD\n"%(vfat))
        if sync_err==0:
            print (Colors.GREEN + "VFAT#: %02d, nr. of sync errors: %d"%(vfat, sync_err) + Colors.ENDC)
            file_out.write("VFAT#: %02d, nr. of sync errors: %d\n"%(vfat, sync_err))
        else:
            print (Colors.RED + "VFAT#: %02d, nr. of sync errors: %d"%(vfat, sync_err) + Colors.ENDC)
            file_out.write("VFAT#: %02d, nr. of sync errors: %d\n"%(vfat, sync_err))

        daq_event_count_final[vfat] = read_backend_reg(daq_event_count_node[vfat])
        daq_crc_error_count_final[vfat] = read_backend_reg(daq_crc_error_node[vfat])
        daq_event_count_diff[vfat] = daq_event_count_final[vfat]
        daq_crc_error_count_diff[vfat] = daq_crc_error_count_final[vfat]

        expected_l1a = 0
        if nl1a != 0:
            expected_l1a = nl1a
        else:
            expected_l1a = int(l1a_rate * runtime * 60 * efficiency)
        real_l1a_counter = 0
        real_calpulse_counter = 0

        if system != "dryrun":
            nl1a_reg_cycles = int(expected_l1a/(2**32))
            real_l1a_counter = nl1a_reg_cycles*(2**32) + l1a_counter
            if calpulse:
                real_calpulse_counter = nl1a_reg_cycles*(2**32) + calpulse_counter
            else:
                real_calpulse_counter = calpulse_counter
            if daq_event_count_diff[vfat] != real_l1a_counter%(2**16):
                print (Colors.YELLOW + "Mismatch between DAQ_EVENT_CNT and L1A counter: %d"%(real_l1a_counter%(2**16) - daq_event_count_diff[vfat]) + Colors.ENDC)
                file_out.write("Mismatch between DAQ_EVENT_CNT and L1A counter: %d\n"%(real_l1a_counter%(2**16) - daq_event_count_diff[vfat]))
            daq_event_count_diff[vfat] = real_l1a_counter # since DAQ_EVENT_CNT is a 16-bit rolling counter
        else:
            if nl1a != 0:
                daq_event_count_diff[vfat] = nl1a
                l1a_counter = nl1a
                real_l1a_counter = nl1a
                if calpulse:
                    calpulse_counter = nl1a
                    real_calpulse_counter = nl1a
                else:
                    calpulse_counter = 0
            else:
                daq_event_count_diff[vfat] = expected_l1a
                l1a_counter = expected_l1a
                real_l1a_counter = expected_l1a
                if calpulse:
                    calpulse_counter = expected_l1a
                    real_calpulse_counter = expected_l1a
                else:
                    calpulse_counter = 0
        print ("VFAT#: %02d, Time: %.2f minutes,  L1A rate: %.2f kHz, Expected L1As (effi=%.3f): %.2e, Nr. of L1As: %.2e,  Nr. of Calpulses: %.2e  \nDAQ Events: %.2e,  DAQ CRC Errors: %d" %(vfat, total_time/60.0, l1a_rate/1000.0, efficiency, expected_l1a, real_l1a_counter, real_calpulse_counter, daq_event_count_diff[vfat], daq_crc_error_count_diff[vfat]))
        file_out.write("VFAT#: %02d, Time: %.2f minutes,  L1A rate: %.2f kHz, Expected L1As (effi=%.3f): %.2e, Nr. of L1As: %.2e,  Nr. of Calpulses: %.2e  \nDAQ Events: %.2e,  DAQ CRC Errors: %d\n" %(vfat, total_time/60.0, l1a_rate/1000.0, efficiency, expected_l1a, real_l1a_counter, real_calpulse_counter, daq_event_count_diff[vfat], daq_crc_error_count_diff[vfat]))

        daq_data_packet_size = 176 # 176 bits
        if daq_event_count_diff[vfat]==0:
            ber = 0
            ineffi = 0
        else:
            ber = float(daq_crc_error_count_diff[vfat])/(daq_event_count_diff[vfat] * daq_data_packet_size)
            ineffi = float(daq_crc_error_count_diff[vfat])/(daq_event_count_diff[vfat])
        ber_ul = 1.0/(daq_event_count_diff[vfat] * daq_data_packet_size)
        ineffi_ul = 1.0/(daq_event_count_diff[vfat])
        if ber==0:
            print (Colors.GREEN + "VFAT#: %02d, Errors = %d,  Bit Error Ratio (BER) < "%(vfat, daq_crc_error_count_diff[vfat]) + "{:.2e}".format(ber_ul) + ", Inefficiency < " + "{:.2e}".format(ineffi_ul) + Colors.ENDC)
            file_out.write("VFAT#: %02d, Errors = %d,  Bit Error Ratio (BER) < "%(vfat, daq_crc_error_count_diff[vfat]) + "{:.2e}\n".format(ber_ul) + ", Inefficiency < " + "{:.2e}".format(ineffi_ul))
        else:
            print (Colors.YELLOW + "VFAT#: %02d, Errors = %d,  Bit Error Ratio (BER) = "%(vfat, daq_crc_error_count_diff[vfat]) + "{:.2e}".format(ber) + ", Inefficiency = " + "{:.2e}".format(ineffi) + Colors.ENDC)
            file_out.write("VFAT#: %02d, Errors = %d,  Bit Error Ratio (BER) = "%(vfat, daq_crc_error_count_diff[vfat]) + "{:.2e}\n".format(ber) + ", Inefficiency = " + "{:.2e}".format(ineffi))

            print ("")
            file_out.write("\n")
        print ("")
        file_out.write("\n\n")

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
    parser.add_argument("-n", "--nl1a", action="store", dest="nl1a", help="nl1a = fixed number of L1A cycles")
    parser.add_argument("-t", "--time", action="store", dest="time", help="time = time (in minutes) to perform the DAQ test")
    parser.add_argument("-b", "--bxgap", action="store", dest="bxgap", default="500", help="bxgap = Nr. of BX between two L1As (default = 500 i.e. 12.5 us)")
    parser.add_argument("-c", "--calpulse", action="store_true", dest="calpulse", help="if calpulsing for all channels should be enabled")
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
    if args.nl1a is not None:
        nl1a = int(args.nl1a)
        if args.time is not None:
            print (Colors.YELLOW + "Cannot give both time and number of L1A cycles" + Colors.ENDC)
            sys.exit()
        if nl1a > (2**32 - 1):
            print (Colors.YELLOW + "Number of L1A cycles can be maximum 4.29e9. Using time option for longer tests" + Colors.ENDC)
            sys.exit()
    runtime = 0
    if args.time is not None:
        runtime = float(args.time)
        if args.nl1a is not None:
            if args.time is not None:
                print (Colors.YELLOW + "Cannot give both time and number of L1A cycles" + Colors.ENDC)
                sys.exit()
    if nl1a==0 and runtime==0:
        print (Colors.YELLOW + "Enter either runtime or number of L1A cycles" + Colors.ENDC)
        sys.exit()

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
        vfat_bert(args.gem, args.system, int(args.ohid), vfat_list, cal_mode, cal_dac, nl1a, runtime, l1a_bxgap, args.calpulse)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




