from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse
import math
import json
from common.utils import get_befe_scripts_dir
from gem.me0_lpgbt.queso_testing.queso_initialization import queso_oh_map
import gem.me0_lpgbt.rw_reg_lpgbt as rw_reg_lpgbt

def lpgbt_fec_error_counter(oh_ver):
    error_counter = 0
    if oh_ver == 1:
        error_counter_h = rw_reg_lpgbt.mpeek(0x1B6)
        error_counter_l = rw_reg_lpgbt.mpeek(0x1B7)
        error_counter = (error_counter_h << 8) | error_counter_l
    elif oh_ver == 2:
        error_counter_0 = rw_reg_lpgbt.mpeek(0x1C6)
        error_counter_1 = rw_reg_lpgbt.mpeek(0x1C7)
        error_counter_2 = rw_reg_lpgbt.mpeek(0x1C8)
        error_counter_3 = rw_reg_lpgbt.mpeek(0x1C9)
        error_counter = (error_counter_0 << 24) | (error_counter_1 << 16) | (error_counter_2 << 8) | error_counter_3
    return error_counter   

def init_lpgbt_fec_error_counter(oh_ver):
    if oh_ver == 1:
        rw_reg_lpgbt.mpoke(0x1B6, 0x0)
        rw_reg_lpgbt.mpoke(0x1B7, 0x0)
    elif oh_ver == 2:
        rw_reg_lpgbt.mpoke(0x1C6, 0x0)
        rw_reg_lpgbt.mpoke(0x1C7, 0x0)
        rw_reg_lpgbt.mpoke(0x1C8, 0x0)
        rw_reg_lpgbt.mpoke(0x1C9, 0x0)

def queso_bert(system, queso_dict, oh_gbt_vfat_map, runtime, ber_limit, cl, loopback, batch = None):
    scripts_gem_dir = get_befe_scripts_dir() + '/gem'
    resultDir = scripts_gem_dir + "/me0_lpgbt/queso_testing/results"
    if batch is None:
        dataDir = resultDir + "/bert_results"
    else:
        dataDir = resultDir + "/%s_tests"%batch
    try:
        os.makedirs(dataDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    oh_ser_nr_list = []
    for queso in queso_dict:
        oh_ser_nr_list.append(queso_dict[queso])
    OHDir = dataDir+"/OH_SNs_"+"_".join(oh_ser_nr_list)
    try:
        os.makedirs(OHDir) # create directory for OHs under test
    except FileExistsError: # skip if directory already exists
        pass  
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    log_fn = OHDir+"/queso_elink_bert_log.txt"
    logfile = open(log_fn, "w")
    results_fn = OHDir+"/queso_elink_bert_results.json"

    print (Colors.BLUE + "\nTests started for Batch: %s\n"%batch + Colors.ENDC)
    print ("")
    logfile.write("\nTests started for Batch: %s\n\n"%batch)

    print ("Checking BER for elinks for OH Serial Numbers: " + "  ".join(oh_ser_nr_list)  + "\n")
    logfile.write("Checking BER for elinks for OH Serial Numbers: " + "  ".join(oh_ser_nr_list)  + "\n\n")
    
    # Check if GBT is READY
    for oh_select in oh_gbt_vfat_map:
        for gbt in oh_gbt_vfat_map[oh_select]["GBT"]:
            link_ready = read_backend_reg(get_backend_node("BEFE.GEM.OH_LINKS.OH%s.GBT%s_READY" % (oh_select, gbt)))
            if (link_ready!=1):
                print (Colors.RED + "ERROR: OH %d lpGBT %d links are not READY, check fiber connections"%(oh_select,gbt) + Colors.ENDC)
                logfile.close()
                rw_terminate()

    data_rate = 320 * 1e6 # 320 Mb/s
    optical_uplink_data_rate = 10.24 * 1e9 # 10.24 Gb/s
    optical_downlink_data_rate = 2.56 * 1e9 # 2.56 Gb/s
    if runtime is None:
        ber_limit = float(ber_limit)
        runtime = (-math.log(1-cl))/(data_rate * ber_limit * 60)
    elif ber_limit is None:
        runtime = float(runtime)

    queso_reset_node = get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_RESET")
    queso_prbs_nodes = {}
    prbs_errors = {}
    for oh_select in oh_gbt_vfat_map:
        queso_prbs_nodes[oh_select] = {}
        prbs_errors[oh_select] = {}
        vfat_list = oh_gbt_vfat_map[oh_select]["VFAT"]
        for vfat in vfat_list:
            queso_prbs_nodes[oh_select][vfat] = {}
            prbs_errors[oh_select][vfat] = {}
            for elink in range(0, 9):
                queso_prbs_nodes[oh_select][vfat][elink] = get_backend_node("BEFE.GEM.GEM_TESTS.QUESO_TEST.OH%d.VFAT%d.ELINK%d.PRBS_ERR_COUNT"%(oh_select, vfat, elink))
                prbs_errors[oh_select][vfat][elink] = {}
                prbs_errors[oh_select][vfat][elink]["lpgbt"] = -9999
                prbs_errors[oh_select][vfat][elink]["lpgbt_elink"] = -9999
                prbs_errors[oh_select][vfat][elink]["n_errors"] = 0
                prbs_errors[oh_select][vfat][elink]["ber_ul"] = -9999
    fec_uplink_error_nodes = {}
    fec_uplink_errors = {}
    fec_downlink_errors = {}
    oh_ver = {}
    for oh_select in oh_gbt_vfat_map:
        fec_uplink_error_nodes[oh_select] = {}
        fec_uplink_errors[oh_select] = {}
        fec_downlink_errors[oh_select] = {}
        oh_ver[oh_select] = {}
        for gbt in oh_gbt_vfat_map[oh_select]["GBT"]:
            oh_ver[oh_select][gbt] = rw_reg_lpgbt.get_oh_ver(oh_select, gbt)
            fec_uplink_errors[oh_select][gbt] = 0
            fec_uplink_error_nodes[oh_select][gbt] = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.GBT%d_FEC_ERR_CNT" % (oh_select, gbt))
            if gbt%2==0:
                fec_downlink_errors[oh_select][gbt] = 0

    print ("Start Error Counting for time = %.2f minutes" % (runtime))
    logfile.write("Start Error Counting for time = %.2f minutes\n" % (runtime))
    print ("")
    logfile.write("\n")

    # Configure lpGBT in loopback mode if loopback test
    if loopback:
        for oh_select in oh_gbt_vfat_map:
            for gbt in oh_gbt_vfat_map[oh_select]["GBT"]:
                rw_reg_lpgbt.select_ic_link(oh_select, gbt)
                if oh_ver[oh_select][gbt] == 1:
                    rw_reg_lpgbt.mpoke(0x119, 0x36)
                    rw_reg_lpgbt.mpoke(0x11a, 0x36)
                    rw_reg_lpgbt.mpoke(0x11b, 0x36)
                    rw_reg_lpgbt.mpoke(0x11c, 0x06)
                elif oh_ver[oh_select][gbt] == 1:
                    rw_reg_lpgbt.mpoke(0x129, 0x36)
                    rw_reg_lpgbt.mpoke(0x12a, 0x36)
                    rw_reg_lpgbt.mpoke(0x12b, 0x36)
                    rw_reg_lpgbt.mpoke(0x12c, 0x06)

    # Enable QUESO BERT
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_EN"), 1)

    # Reset QUESO BERT registers
    gem_link_reset()
    sleep(0.1)
    write_backend_reg(queso_reset_node, 1)
    sleep(0.1)

    t0 = time()
    time_prev = t0

    # Start the downlink FEC counters on the lpGBT
    for oh_select in oh_gbt_vfat_map:
        for gbt in oh_gbt_vfat_map[oh_select]["GBT"]:
            if gbt%2==0:
                rw_reg_lpgbt.select_ic_link(oh_select, gbt)
                init_lpgbt_fec_error_counter(oh_ver[oh_select][gbt])
                if oh_ver[oh_select][gbt] == 1:
                    rw_reg_lpgbt.mpoke(0x117, 0x10)
                elif oh_ver[oh_select][gbt] == 2:
                    rw_reg_lpgbt.mpoke(0x142, 0x10)

    # Initial errors
    n_elink_errors = 0
    print ("Starting PRBS and FEC errors: \n")
    logfile.write("Starting PRBS and FEC errors: \n\n")

    err_str = Colors.RED + "  PRBS errors on: "
    for oh_select in oh_gbt_vfat_map:
        vfat_list = oh_gbt_vfat_map[oh_select]["VFAT"]
        for vfat in vfat_list:
            for elink in range(0, 9):
                prbs_errors[oh_select][vfat][elink]["n_errors"] = read_backend_reg(queso_prbs_nodes[oh_select][vfat][elink])
                if prbs_errors[oh_select][vfat][elink]["n_errors"] != 0:
                    err_str += "OH %d VFAT %d ELINK %d: %d errors\n"%(oh_select,vfat, elink, prbs_errors[oh_select][vfat][elink]["n_errors"])
                    n_elink_errors += 1
    err_str += "\n" + Colors.ENDC
    if n_elink_errors == 0:
        print (Colors.GREEN + "  No PRBS errors on any ELINK on any VFAT\n" + Colors.ENDC)
        logfile.write(Colors.GREEN + "  No PRBS errors on any ELINK on any VFAT\n\n" + Colors.ENDC)
    else:
        print (err_str)
        logfile.write(err_str + "\n")

    n_link_fec_errors = 0
    err_str = Colors.RED + "  FEC errors on: "
    for oh_select in oh_gbt_vfat_map:
        for gbt in oh_gbt_vfat_map[oh_select]["GBT"]:
            fec_uplink_errors[oh_select][gbt] = read_backend_reg(fec_uplink_error_nodes[oh_select][gbt])
            if fec_uplink_errors[oh_select][gbt] != 0:
                err_str += "OH %d VFAT %d GBT %d: %d uplink errors\n"%(oh_select,vfat, gbt, fec_uplink_errors[oh_select][gbt])
                n_link_fec_errors += 1
            if gbt%2==0:
                rw_reg_lpgbt.select_ic_link(oh_select, gbt)
                fec_downlink_errors[oh_select][gbt] = lpgbt_fec_error_counter(oh_ver[oh_select][gbt])
                if fec_downlink_errors[oh_select][gbt] != 0:
                    err_str += "OH %d VFAT %d GBT %d: %d downlink errors\n"%(oh_select,vfat, gbt, fec_uplink_errors[oh_select][gbt])
                    n_link_fec_errors += 1
    err_str += "\n" + Colors.ENDC
    if n_link_fec_errors == 0:
        print (Colors.GREEN + "  No FEC errors on any optical link on any GBT\n" + Colors.ENDC)
        logfile.write(Colors.GREEN + "  No FEC errors on any optical link on any GBT\n\n" + Colors.ENDC)
    else:
        print (err_str)
        logfile.write(err_str + "\n")

    # Running QUESO BERT
    while ((time()-t0)/60.0) < runtime:
        time_passed = (time()-time_prev)/60.0
        if time_passed >= 1:
            print ("Time passed: %.2f minutes: " % ((time()-t0)/60.0))
            logfile.write("Time passed: %.2f minutes\n" % ((time()-t0)/60.0))

            # Checking errors
            n_elink_errors = 0
            print ("Checking PRBS and FEC errors: \n")
            logfile.write("Checking PRBS and FEC errors: \n\n")
            err_str = Colors.RED + "  PRBS errors on: "
            for oh_select in oh_gbt_vfat_map:
                vfat_list = oh_gbt_vfat_map[oh_select]["VFAT"]
                for vfat in vfat_list:
                    for elink in range(9):
                        prbs_errors[oh_select][vfat][elink]["n_errors"] = read_backend_reg(queso_prbs_nodes[oh_select][vfat][elink])
                        if prbs_errors[oh_select][vfat][elink]["n_errors"] != 0:
                            err_str += "OH %d VFAT %d ELINK %d: %d errors\n"%(oh_select,vfat, elink, prbs_errors[oh_select][vfat][elink]["n_errors"])
                            n_elink_errors += 1
            err_str += "\n" + Colors.ENDC
            if n_elink_errors == 0:
                print (Colors.GREEN + "  No PRBS errors on any ELINK on any VFAT\n" + Colors.ENDC)
                logfile.write(Colors.GREEN + "  No PRBS errors on any ELINK on any VFAT\n\n" + Colors.ENDC)
            else:
                print (err_str)
                logfile.write(err_str + "\n")

            n_link_fec_errors = 0
            err_str = Colors.RED + "  FEC errors on: "
            for oh_select in oh_gbt_vfat_map:
                for gbt in oh_gbt_vfat_map[oh_select]["GBT"]:
                    fec_uplink_errors[oh_select][gbt] = read_backend_reg(fec_uplink_error_nodes[oh_select][gbt])
                    if fec_uplink_errors[oh_select][gbt] != 0:
                        err_str += "OH %d VFAT %d GBT %d: %d uplink errors\n"%(oh_select,vfat, gbt, fec_uplink_errors[oh_select][gbt])
                        n_link_fec_errors += 1
                    if gbt%2==0:
                        rw_reg_lpgbt.select_ic_link(oh_select, gbt)
                        fec_downlink_errors[oh_select][gbt] = lpgbt_fec_error_counter(oh_ver[oh_select][gbt])
                        if fec_downlink_errors[oh_select][gbt] != 0:
                            err_str += "OH %d VFAT %d GBT %d: %d downlink errors\n"%(oh_select,vfat, gbt, fec_uplink_errors[oh_select][gbt])
                            n_link_fec_errors += 1
            err_str += "\n" + Colors.ENDC
            if n_link_fec_errors == 0:
                print (Colors.GREEN + "  No FEC errors on any optical link on any GBT\n" + Colors.ENDC)
                logfile.write(Colors.GREEN + "  No FEC errors on any optical link on any GBT\n\n" + Colors.ENDC)
            else:
                print (err_str)
                logfile.write(err_str + "\n")

            time_prev = time()

    print ("\nEnd Error Counting:")
    logfile.write("\nEnd Error Counting: \n")

    # Final errors
    for oh_select in oh_gbt_vfat_map:
        vfat_list = oh_gbt_vfat_map[oh_select]["VFAT"]
        for vfat in vfat_list:
            for elink in range(9):
                prbs_errors[oh_select][vfat][elink]["n_errors"] = read_backend_reg(queso_prbs_nodes[oh_select][vfat][elink])
    for oh_select in oh_gbt_vfat_map:
        for gbt in oh_gbt_vfat_map[oh_select]["GBT"]:
            fec_uplink_errors[oh_select][gbt] = read_backend_reg(fec_uplink_error_nodes[oh_select][gbt])
            if gbt%2==0:
                rw_reg_lpgbt.select_ic_link(oh_select, gbt)
                fec_downlink_errors[oh_select][gbt] = lpgbt_fec_error_counter(oh_ver[oh_select][gbt])
                
    # Disable QUESO BERT 
    sleep(0.1)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_EN"), 0)

    # Disable the downlink FEC counters on the lpGBT
    for oh_select in oh_gbt_vfat_map:
        for gbt in oh_gbt_vfat_map[oh_select]["GBT"]:
            if gbt%2==0:
                rw_reg_lpgbt.select_ic_link(oh_select, gbt)
                if oh_ver[oh_select][gbt] == 1:
                    rw_reg_lpgbt.mpoke(0x117, 0x00)
                elif oh_ver[oh_select][gbt] == 2:
                    rw_reg_lpgbt.mpoke(0x142, 0x00)

    # Disable lpGBT in loopback mode if loopback test
    if loopback:
        for oh_select in oh_gbt_vfat_map:
            for gbt in oh_gbt_vfat_map[oh_select]["GBT"]:
                oh_ver = oh_ver[oh_select][gbt]
                rw_reg_lpgbt.select_ic_link(oh_select, gbt)
                if oh_ver == 1:
                    rw_reg_lpgbt.mpoke(0x119, 0x00)
                    rw_reg_lpgbt.mpoke(0x11a, 0x00)
                    rw_reg_lpgbt.mpoke(0x11b, 0x00)
                    rw_reg_lpgbt.mpoke(0x11c, 0x00)
                elif oh_ver == 1:
                    rw_reg_lpgbt.mpoke(0x129, 0x00)
                    rw_reg_lpgbt.mpoke(0x12a, 0x00)
                    rw_reg_lpgbt.mpoke(0x12b, 0x00)
                    rw_reg_lpgbt.mpoke(0x12c, 0x00)

    # Reset QUESO BERT registers
    write_backend_reg(queso_reset_node, 1)
    gem_link_reset()
    sleep(0.1)

    # Printing results
    ber_ul = (-math.log(1-cl))/ (data_rate * runtime * 60)
    optical_uplink_ber_ul = (-math.log(1-cl))/ (optical_uplink_data_rate * runtime * 60)
    optical_downlink_ber_ul = (-math.log(1-cl))/ (optical_downlink_data_rate * runtime * 60)

    print("PRBS BERT Results for OH SNs: " + " ".join(oh_ser_nr_list) +":\n")
    logfile.write("PRBS BERT Results for OH SNs: " + " ".join(oh_ser_nr_list) +":\n\n")
    for oh_select in oh_gbt_vfat_map:
        vfat_list = oh_gbt_vfat_map[oh_select]["VFAT"]
        for vfat in vfat_list:
            print ("  OH %d VFAT %d:"%(oh_select,vfat))
            logfile.write("  OH %d VFAT %d:\n"%(oh_select,vfat))
            for elink in prbs_errors[oh_select][vfat]:
                err_str = ""
                if prbs_errors[oh_select][vfat][elink]["n_errors"] == 0:
                    err_str += Colors.GREEN
                else:
                    err_str += Colors.RED
                lpgbt = ME0_VFAT_TO_GBT_ELINK_GPIO[vfat][1]
                if elink == 0:
                    elink_nr = ME0_VFAT_TO_GBT_ELINK_GPIO[vfat][2]
                else:
                    elink_nr = ME0_VFAT_TO_SBIT_ELINK[vfat][elink-1]
                prbs_errors[oh_select][vfat][elink]["lpgbt"] = lpgbt
                prbs_errors[oh_select][vfat][elink]["lpgbt_elink"] = elink_nr
                err_str += "    ELINK %d (GBT: %d, Elink nr: %d): Nr. of PRBS errors = %d"%(elink, lpgbt, elink_nr, prbs_errors[oh_select][vfat][elink]["n_errors"])
                if prbs_errors[oh_select][vfat][elink]["n_errors"] == 0:
                    err_str += ", BER < {:.4e}".format(ber_ul) 
                    prbs_errors[oh_select][vfat][elink]["ber_ul"] = ber_ul
                err_str += Colors.ENDC
                print (err_str)
                logfile.write(err_str + "\n")
    print ("")
    logfile.write("\n")

    print("FEC Error Results for OH SNs: " + " ".join(oh_ser_nr_list) +":\n")
    logfile.write("FEC Error Results for OH SNs: " + " ".join(oh_ser_nr_list) +":\n\n")
    for oh_select in oh_gbt_vfat_map:
        for gbt in oh_gbt_vfat_map[oh_select]["GBT"]:
            print ("  OH %d GBT %d:"%(oh_select,gbt))
            logfile.write("  OH %d GBT %d:\n"%(oh_select,gbt))
            err_str = ""
            if fec_uplink_errors[oh_select][gbt] == 0:
                err_str += Colors.GREEN
            else:
                err_str += Colors.RED
            err_str += "    Uplink FEC Errors = %d"%fec_uplink_errors[oh_select][gbt]
            err_str += Colors.ENDC
            print (err_str)
            logfile.write(err_str + "\n")
            if gbt%2==0:
                err_str = ""
                if fec_downlink_errors[oh_select][gbt] == 0:
                    err_str += Colors.GREEN
                else:
                    err_str += Colors.RED
                err_str += "    Downlink FEC Errors = %d"%fec_uplink_errors[oh_select][gbt]
                err_str += Colors.ENDC
                print (err_str)
                logfile.write(err_str + "\n")
    print ("")
    logfile.write("\n")

    print ("")
    logfile.write("\n")
    prbs_errors_oh_sn = {}
    for queso,oh_sn in queso_dict.items():
        print ("OH SN: %s"%oh_sn)
        logfile.write("OH SN: %s\n"%oh_sn)
        oh_select = queso_oh_map[queso]["OH"]
        gbt_list = queso_oh_map[queso]["GBT"]
        vfat_list = queso_oh_map[queso]["VFAT"]
        prbs_errors_oh_sn[oh_sn] = {}
        for gbt in gbt_list:
            if gbt%2 == 0:
                gbt_type = "LPGBT_M"
            else:
                gbt_type = "LPGBT_S"        
            prbs_errors_oh_sn[oh_sn][gbt_type + "_QUESO_UP_ELINK_PRBS_ERROR_COUNT"] = [-9999 for _ in range(28)]
            prbs_errors_oh_sn[oh_sn][gbt_type + "_QUESO_UP_ELINK_PRBS_BER_UPPER_LIMIT"] = [-9999 for _ in range(28)]
            prbs_errors_oh_sn[oh_sn][gbt_type + "_QUESO_UP_OPTICAL_LINK_FEC_ERROR_COUNT"] = fec_uplink_errors[oh_select][gbt]
            prbs_errors_oh_sn[oh_sn][gbt_type + "_QUESO_UP_OPTICAL_LINK_PRBS_ERROR_COUNT"] = -9999
            prbs_errors_oh_sn[oh_sn][gbt_type + "_QUESO_UP_OPTICAL_LINK_PRBS_BER_UPPER_LIMIT"] = -9999
            if gbt%2 == 0:   
                prbs_errors_oh_sn[oh_sn][gbt_type + "_QUESO_DOWN_ELINK_PRBS_ERROR_COUNT"] = [-9999 for _ in range(6)]
                prbs_errors_oh_sn[oh_sn][gbt_type + "_QUESO_DOWN_ELINK_PRBS_BER_UPPER_LIMIT"] = [-9999 for _ in range(6)]
                prbs_errors_oh_sn[oh_sn][gbt_type + "_QUESO_DOWN_OPTICAL_LINK_FEC_ERROR_COUNT"] = fec_downlink_errors[oh_select][gbt]
                prbs_errors_oh_sn[oh_sn][gbt_type + "_QUESO_DOWN_OPTICAL_LINK_PRBS_ERROR_COUNT"] = -9999
                prbs_errors_oh_sn[oh_sn][gbt_type + "_QUESO_DOWN_OPTICAL_LINK_PRBS_BER_UPPER_LIMIT"] = -9999
        n_boss_total_elink_errors = 0
        n_sub_total_elink_errors = 0
        for v_n, vfat in enumerate(vfat_list):
            n_total_elink_errors = 0
            for elink in range(0, 9):
                lpgbt = prbs_errors[oh_select][vfat][elink]["lpgbt"]
                elink_nr = prbs_errors[oh_select][vfat][elink]["lpgbt_elink"]
                error_count = prbs_errors[oh_select][vfat][elink]["n_errors"]
                ber_ul = prbs_errors[oh_select][vfat][elink]["ber_ul"]
                gbt_type = ""
                if lpgbt%2 == 0:
                    gbt_type = "LPGBT_M"
                    n_boss_total_elink_errors += error_count
                else:
                    gbt_type = "LPGBT_S"
                    n_sub_total_elink_errors += error_count
                prbs_errors_oh_sn[oh_sn][gbt_type + "_QUESO_UP_ELINK_PRBS_ERROR_COUNT"][elink_nr] = error_count
                prbs_errors_oh_sn[oh_sn][gbt_type + "_QUESO_UP_ELINK_PRBS_BER_UPPER_LIMIT"][elink_nr] = ber_ul
                n_total_elink_errors += error_count
            prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_DOWN_ELINK_PRBS_ERROR_COUNT"][v_n] = n_total_elink_errors
            if n_total_elink_errors == 0:
                prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_DOWN_ELINK_PRBS_BER_UPPER_LIMIT"][v_n] = ber_ul
        prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_UP_OPTICAL_LINK_PRBS_ERROR_COUNT"] = n_boss_total_elink_errors
        prbs_errors_oh_sn[oh_sn]["LPGBT_S_QUESO_UP_OPTICAL_LINK_PRBS_ERROR_COUNT"] = n_sub_total_elink_errors
        prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_DOWN_OPTICAL_LINK_PRBS_ERROR_COUNT"] = n_boss_total_elink_errors + n_sub_total_elink_errors
        if n_boss_total_elink_errors == 0 and prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_UP_OPTICAL_LINK_FEC_ERROR_COUNT"] == 0:
            prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_UP_OPTICAL_LINK_PRBS_BER_UPPER_LIMIT"] = "{:.4e}".format(optical_uplink_ber_ul) 
            print (Colors.GREEN + "  Total number of PRBS errors on boss lpGBT = %d"%n_boss_total_elink_errors + Colors.ENDC)
            print (Colors.GREEN + "  Total number of uplink FEC errors on boss lpGBT = %d"%prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_UP_OPTICAL_LINK_FEC_ERROR_COUNT"] + Colors.ENDC)
            print (Colors.GREEN + "  For each uplink elink on boss lpGBT: " + "BER < {:.4e}".format(ber_ul) + Colors.ENDC)
            print (Colors.GREEN + "  For optical uplink on boss lpGBT: " + prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_UP_OPTICAL_LINK_PRBS_BER_UPPER_LIMIT"] + Colors.ENDC)
            logfile.write("  Total number of PRBS errors on boss lpGBT = %d\n"%n_boss_total_elink_errors)
            logfile.write("  Total number of uplink FEC errors on boss lpGBT = %d"%prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_UP_OPTICAL_LINK_FEC_ERROR_COUNT"])
            logfile.write("  For each uplink elink on boss lpGBT: " + "BER < {:.4e}".format(ber_ul) + "\n")
            logfile.write("  For optical uplink on boss lpGBT: " + prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_UP_OPTICAL_LINK_PRBS_BER_UPPER_LIMIT"] + "\n")
        else:
            print (Colors.RED + "  Total number of PRBS errors on boss lpGBT = %d"%n_boss_total_elink_errors + Colors.ENDC)
            print (Colors.RED + "  Total number of uplink FEC errors on boss lpGBT = %d"%prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_UP_OPTICAL_LINK_FEC_ERROR_COUNT"] + Colors.ENDC)
            logfile.write("  Total number of PRBS errors on boss lpGBT = %d\n"%n_boss_total_elink_errors)
            logfile.write("  Total number of uplink FEC errors on boss lpGBT = %d"%prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_UP_OPTICAL_LINK_FEC_ERROR_COUNT"])
        if n_sub_total_elink_errors == 0 and prbs_errors_oh_sn[oh_sn]["LPGBT_S_QUESO_UP_OPTICAL_LINK_FEC_ERROR_COUNT"] == 0:
            prbs_errors_oh_sn[oh_sn]["LPGBT_S_QUESO_UP_OPTICAL_LINK_PRBS_BER_UPPER_LIMIT"] = "{:.4e}".format(optical_uplink_ber_ul) 
            print (Colors.GREEN + "  Total number of PRBS errors on sub lpGBT = %d"%n_sub_total_elink_errors + Colors.ENDC)
            print (Colors.GREEN + "  Total number of uplink FEC errors on sub lpGBT = %d"%prbs_errors_oh_sn[oh_sn]["LPGBT_S_QUESO_UP_OPTICAL_LINK_FEC_ERROR_COUNT"] + Colors.ENDC)
            print (Colors.GREEN + "  For each uplink elink on sub lpGBT: " + "BER < {:.4e}".format(ber_ul) + Colors.ENDC)
            print (Colors.GREEN + "  For optical uplink on sub lpGBT: " + prbs_errors_oh_sn[oh_sn]["LPGBT_S_QUESO_UP_OPTICAL_LINK_PRBS_BER_UPPER_LIMIT"] + Colors.ENDC)
            logfile.write("  Total number of PRBS errors on sub lpGBT = %d\n"%n_sub_total_elink_errors)
            logfile.write("  Total number of uplink FEC errors on sub lpGBT = %d"%prbs_errors_oh_sn[oh_sn]["LPGBT_S_QUESO_UP_OPTICAL_LINK_FEC_ERROR_COUNT"])
            logfile.write("  For each uplink elink on sub lpGBT: " + "BER < {:.4e}".format(ber_ul) + "\n")
            logfile.write("  For optical uplink on sub lpGBT: " + prbs_errors_oh_sn[oh_sn]["LPGBT_S_QUESO_UP_OPTICAL_LINK_PRBS_BER_UPPER_LIMIT"] + "\n")
        else:
            print (Colors.RED + "  Total number of PRBS errors on sub lpGBT = %d"%n_sub_total_elink_errors + Colors.ENDC)
            print (Colors.RED + "  Total number of uplink FEC errors on boss lpGBT = %d"%prbs_errors_oh_sn[oh_sn]["LPGBT_S_QUESO_UP_OPTICAL_LINK_FEC_ERROR_COUNT"])
            logfile.write("  Total number of PRBS errors on sub lpGBT = %d\n"%n_sub_total_elink_errors)
            logfile.write("  Total number of uplink FEC errors on sub lpGBT = %d"%prbs_errors_oh_sn[oh_sn]["LPGBT_S_QUESO_UP_OPTICAL_LINK_FEC_ERROR_COUNT"] + Colors.ENDC)
        if (n_boss_total_elink_errors + n_sub_total_elink_errors) == 0 and prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_DOWN_OPTICAL_LINK_FEC_ERROR_COUNT"] == 0:
            prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_DOWN_OPTICAL_LINK_PRBS_BER_UPPER_LIMIT"] = "{:.4e}".format(optical_downlink_ber_ul) 
            print (Colors.GREEN + "  Total number of PRBS errors on boss and sub lpGBT = %d"%(n_boss_total_elink_errors + n_sub_total_elink_errors) + Colors.ENDC)
            print (Colors.GREEN + "  Total number of downlink FEC errors on boss lpGBT = %d"%prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_DOWN_OPTICAL_LINK_FEC_ERROR_COUNT"] + Colors.ENDC)
            print (Colors.GREEN + "  For each downlink elink on boss lpGBT: " + "BER < {:.4e}".format(ber_ul) + Colors.ENDC)
            print (Colors.GREEN + "  For optical downlink on boss lpGBT: " + prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_DOWN_OPTICAL_LINK_PRBS_BER_UPPER_LIMIT"] + Colors.ENDC)
            logfile.write("  Total number of PRBS errors on boss and sub lpGBT = %d\n"%(n_boss_total_elink_errors + n_sub_total_elink_errors))
            logfile.write("  Total number of downlink FEC errors on boss lpGBT = %d"%prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_DOWN_OPTICAL_LINK_FEC_ERROR_COUNT"])
            logfile.write("  For each downlink elink on boss lpGBT: " + "BER < {:.4e}".format(ber_ul))
            logfile.write("  For optical downlink on boss lpGBT: " + prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_DOWN_OPTICAL_LINK_PRBS_BER_UPPER_LIMIT"])
        else:
            print (Colors.RED + "  Total number of PRBS errors on boss and sub lpGBT = %d"%(n_boss_total_elink_errors + n_sub_total_elink_errors) + Colors.ENDC)
            print (Colors.RED + "  Total number of downlink FEC errors on boss lpGBT = %d"%prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_DOWN_OPTICAL_LINK_FEC_ERROR_COUNT"] + Colors.ENDC)
            logfile.write("  Total number of PRBS errors on boss ans sub lpGBT = %d\n"%(n_boss_total_elink_errors + n_sub_total_elink_errors))
            logfile.write("  Total number of downlink FEC errors on boss lpGBT = %d"%prbs_errors_oh_sn[oh_sn]["LPGBT_M_QUESO_DOWN_OPTICAL_LINK_FEC_ERROR_COUNT"])
        print ("")
        logfile.write("\n")
    print ("")
    logfile.write("\n")
    
    for oh_sn in prbs_errors_oh_sn:
        prbs_errors_oh_sn[oh_sn]['LPGBT_M_QUESO_UP_ELINK_PRBS_ERROR_COUNT'] = ["{:.4e}".format(p_err) for p_err in prbs_errors_oh_sn[oh_sn]['LPGBT_M_QUESO_UP_ELINK_PRBS_ERROR_COUNT']]
        prbs_errors_oh_sn[oh_sn]['LPGBT_M_QUESO_UP_ELINK_PRBS_BER_UPPER_LIMIT'] = ["{:.4e}".format(p_err) for p_err in prbs_errors_oh_sn[oh_sn]['LPGBT_M_QUESO_UP_ELINK_PRBS_BER_UPPER_LIMIT']]
        prbs_errors_oh_sn[oh_sn]['LPGBT_M_QUESO_DOWN_ELINK_PRBS_ERROR_COUNT'] = ["{:.4e}".format(p_err) for p_err in prbs_errors_oh_sn[oh_sn]['LPGBT_M_QUESO_DOWN_ELINK_PRBS_ERROR_COUNT']]
        prbs_errors_oh_sn[oh_sn]['LPGBT_M_QUESO_DOWN_ELINK_PRBS_BER_UPPER_LIMIT'] = ["{:.4e}".format(p_err) for p_err in prbs_errors_oh_sn[oh_sn]['LPGBT_M_QUESO_DOWN_ELINK_PRBS_BER_UPPER_LIMIT']]
        prbs_errors_oh_sn[oh_sn]['LPGBT_S_QUESO_UP_ELINK_PRBS_ERROR_COUNT'] = ["{:.4e}".format(p_err) for p_err in prbs_errors_oh_sn[oh_sn]['LPGBT_S_QUESO_UP_ELINK_PRBS_ERROR_COUNT']]
        prbs_errors_oh_sn[oh_sn]['LPGBT_S_QUESO_UP_ELINK_PRBS_BER_UPPER_LIMIT'] = ["{:.4e}".format(p_err) for p_err in prbs_errors_oh_sn[oh_sn]['LPGBT_S_QUESO_UP_ELINK_PRBS_BER_UPPER_LIMIT']]
    
    prbs_errors_oh_sn = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in prbs_errors_oh_sn.items()]
    with open(results_fn, "w") as resultsfile:
        json.dump(prbs_errors_oh_sn,resultsfile,indent=2)

    print ("Finished BER for elinks for OH Serial Numbers: " + "  ".join(oh_ser_nr_list)  + "\n")
    logfile.write("Finished BER for elinks for OH Serial Numbers: " + "  ".join(oh_ser_nr_list)  + "\n\n")

    logfile.close()
    resultsfile.close()

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="QUESO BERT")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    #parser.add_argument("-o", "--ohs", action="store", nargs="+", dest="ohs", help="ohs = list of OH numbers (0-1)")
    #parser.add_argument("-n", "--oh_ser_nrs", action="store", nargs="+", dest="oh_ser_nrs", help="oh_ser_nrs = list of OH serial numbers")
    #parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-i", "--input_file", action="store", dest="input_file", help="INPUT_FILE = input file containing OH serial numbers for QUESOs")
    parser.add_argument("-t", "--time", action="store", dest="time", help="TIME = measurement time in minutes")
    parser.add_argument("-b", "--ber", action="store", dest="ber", help="BER = measurement till this BER. eg. 1e-12")
    parser.add_argument("-c", "--cl", action="store", dest="cl", default="0.95", help="CL = confidence level desired for BER measurement, default = 0.95")
    parser.add_argument("-l", "--loopback", action="store_true", dest="loopback", help="whether to run in loopback mode (mainly needed for testing on the GEB)")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for queso bert")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running queso bert")
    else:
        print (Colors.YELLOW + "Only valid options: backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem != "ME0":
        print(Colors.YELLOW + "Valid gem station: ME0" + Colors.ENDC)
        sys.exit()

    if args.input_file is None:
        print(Colors.YELLOW + "Need Input File" + Colors.ENDC)
        sys.exit()
    oh_gbt_vfat_map = {}
    queso_dict = {}
    input_file = open(args.input_file)
    for line in input_file.readlines():
        if "#" in line:
            if "TEST_TYPE" in line:
                batch = line.split()[2]
                if batch not in ["prototype", "pre_production", "pre_series", "production", "long_production"]:
                    print(Colors.YELLOW + 'Valid test batch codes are "prototype", "pre_production", "pre_series", "production" or "long_production"' + Colors.ENDC)
                    sys.exit()
            continue
        queso_nr = line.split()[0]
        oh_sn = line.split()[1]
        if oh_sn != "-9999":
            if batch == "pre_production" and int(oh_sn) not in range(1, 1001):
                print(Colors.YELLOW + "Valid OH serial number between 1 and 1000" + Colors.ENDC)
                sys.exit()
            elif batch in ["pre_series", "production"] and int(oh_sn) not in range(1001, 2019):
                print(Colors.YELLOW + "Valid OH serial number between 1001 and 2018" + Colors.ENDC)
                sys.exit()
            queso_dict[queso_nr] = oh_sn
    input_file.close()
    if len(queso_dict) == 0:
        print(Colors.YELLOW + "At least 1 QUESO need to have valid OH serial number" + Colors.ENDC)
        sys.exit()

    for queso in queso_dict:
        oh = queso_oh_map[queso]["OH"]
        if oh not in oh_gbt_vfat_map:
            oh_gbt_vfat_map[oh] = {}
            oh_gbt_vfat_map[oh]["GBT"] = []
            oh_gbt_vfat_map[oh]["VFAT"] = []
        oh_gbt_vfat_map[oh]["GBT"] += queso_oh_map[queso]["GBT"]
        oh_gbt_vfat_map[oh]["VFAT"] += queso_oh_map[queso]["VFAT"]
        oh_gbt_vfat_map[oh]["GBT"].sort()
        oh_gbt_vfat_map[oh]["VFAT"].sort()

    if args.time is None and args.ber is None:
        print (Colors.YELLOW + "BERT measurement time or BER limit required" + Colors.ENDC)
        sys.exit()
    if args.time is not None and args.ber is not None:
        print (Colors.YELLOW + "Only either BERT measurement time or BER limit should be given" + Colors.ENDC)
        sys.exit()

    # Initialization 
    rw_reg_lpgbt.rw_initialize(args.gem, args.system)
    print("Initialization Done\n")

    # Scanning/setting bitslips
    try:
        queso_bert(args.system, queso_dict, oh_gbt_vfat_map, args.time, args.ber, float(args.cl), args.loopback, batch=batch)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()
