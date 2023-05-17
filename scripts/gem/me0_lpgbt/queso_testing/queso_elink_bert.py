from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse
import math
import json
from gem.me0_lpgbt.queso_testing.queso_initialization import queso_oh_map

def queso_bert(system, queso_dict, oh_gbt_vfat_map, runtime, ber_limit, cl):

    resultDir = "me0_lpgbt/queso_testing/results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = "me0_lpgbt/queso_testing/results/bert_results"
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

    data_rate = 320 *1e6 # 320 Mb/s
    if runtime is None:
        ber_limit = float(ber_limit)
        runtime = (-math.log(1-cl))/(data_rate * ber_limit * 60)
    elif ber_limit is None:
        runtime = float(runtime)

    queso_reset_node = get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_RESET")
    queso_bitslip_nodes = {}
    queso_prbs_nodes = {}
    prbs_errors = {}
    for oh_select in oh_gbt_vfat_map:
        queso_bitslip_nodes[oh_select] = {}
        queso_prbs_nodes[oh_select] = {}
        prbs_errors[oh_select] = {}
        vfat_list = oh_gbt_vfat_map[oh_select]["VFAT"]
        for vfat in vfat_list:
            queso_bitslip_nodes[oh_select][vfat] = {}
            queso_prbs_nodes[oh_select][vfat] = {}
            prbs_errors[oh_select][vfat] = {}
            for elink in range(0, 9):
                queso_bitslip_nodes[oh_select][vfat][elink] = get_backend_node("BEFE.GEM.GEM_TESTS.QUESO_TEST.OH%d.VFAT%d.ELINK%d.ELINK_BITSLIP"%(oh_select, vfat, elink))
                queso_prbs_nodes[oh_select][vfat][elink] = get_backend_node("BEFE.GEM.GEM_TESTS.QUESO_TEST.OH%d.VFAT%d.ELINK%d.PRBS_ERR_COUNT"%(oh_select, vfat, elink))
                prbs_errors[oh_select][vfat][elink] = 0

    print ("Start Error Counting for time = %.2f minutes" % (runtime))
    logfile.write("Start Error Counting for time = %.2f minutes\n" % (runtime))
    print ("")
    logfile.write("\n")

    # Enable QUESO BERT
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_EN"), 1)

    # Reset QUESO BERT registers
    write_backend_reg(queso_reset_node, 1)
    sleep(0.1)

    t0 = time()
    time_prev = t0

    # Initial errors
    n_elink_errors = 0
    print ("Starting PRBS errors: ")
    logfile.write("Starting PRBS errors: \n")
    err_str = Colors.RED + "  PRBS errors on: "
    for oh_select in oh_gbt_vfat_map:
        vfat_list = oh_gbt_vfat_map[oh_select]["VFAT"]
        for vfat in vfat_list:
            for elink in range(0, 9):
                prbs_errors[oh_select][vfat][elink] = read_backend_reg(queso_prbs_nodes[oh_select][vfat][elink])
                if prbs_errors[oh_select][vfat][elink] != 0:
                    err_str += "OH %d VFAT %d ELINK %d: %d errors, "%(oh_select,vfat, elink, prbs_errors[oh_select][vfat][elink])
                    n_elink_errors += 1
    err_str += "\n" + Colors.ENDC
    if n_elink_errors == 0:
        print (Colors.GREEN + "  No PRBS errors on any ELINK on any VFAT\n" + Colors.ENDC)
        logfile.write(Colors.GREEN + "  No PRBS errors on any ELINK on any VFAT\n\n" + Colors.ENDC)
    else:
        print (err_str)
        logfile.write(err_str + "\n")

    while ((time()-t0)/60.0) < runtime:
        time_passed = (time()-time_prev)/60.0
        if time_passed >= 1:
            print ("Time passed: %.2f minutes: " % ((time()-t0)/60.0))
            logfile.write("Time passed: %.2f minutes\n" % ((time()-t0)/60.0))

            # Checking errors
            n_elink_errors = 0
            print ("Checking PRBS errors: ")
            logfile.write("Checking PRBS errors: \n")
            err_str = Colors.RED + "  PRBS errors on: "
            for oh_select in oh_gbt_vfat_map:
                vfat_list = oh_gbt_vfat_map[oh_select]["VFAT"]
                for vfat in vfat_list:
                    for elink in range(9):
                        prbs_errors[oh_select][vfat][elink] = read_backend_reg(queso_prbs_nodes[oh_select][vfat][elink])
                        if prbs_errors[oh_select][vfat][elink] != 0:
                            err_str += "OH %d VFAT %d ELINK %d: %d errors, "%(oh_select,vfat, elink, prbs_errors[oh_select][vfat][elink])
                            n_elink_errors += 1
            err_str += "\n" + Colors.ENDC
            if n_elink_errors == 0:
                print (Colors.GREEN + "  No PRBS errors on any ELINK on any VFAT\n" + Colors.ENDC)
                logfile.write(Colors.GREEN + "  No PRBS errors on any ELINK on any VFAT\n\n" + Colors.ENDC)
            else:
                print (err_str)
                logfile.write(err_str + "\n")

            time_prev = time()

    print ("\nEnd Error Counting:")
    logfile.write("\nEnd Error Counting: \n")

    # Disable QUESO BERT 
    sleep(0.1)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_EN"), 0)

    # Final errors
    for oh_select in oh_gbt_vfat_map:
        vfat_list = oh_gbt_vfat_map[oh_select]["VFAT"]
        for vfat in vfat_list:
            for elink in range(9):
                prbs_errors[oh_select][vfat][elink] = read_backend_reg(queso_prbs_nodes[oh_select][vfat][elink])
   
    # Printing results
    ber_ul = (-math.log(1-cl))/ (data_rate * runtime * 60)
    print("BERT Reuslts for OH SNs: " + " ".join(oh_ser_nr_list) +":\n")
    logfile.write("BERT Reuslts for OH SNs: " + " ".join(oh_ser_nr_list) +":\n\n")
    for oh_select in oh_gbt_vfat_map:
        vfat_list = oh_gbt_vfat_map[oh_select]["VFAT"]
        for vfat in vfat_list:
            print ("  OH %d VFAT %d:"%(oh_select,vfat))
            logfile.write("  OH %d VFAT %d:\n"%(oh_select,vfat))
            for elink in prbs_errors[oh_select][vfat]:
                err_str = ""
                if prbs_errors[oh_select][vfat][elink] == 0:
                    err_str += Colors.GREEN
                else:
                    err_str += Colors.RED
                err_str += "    ELINK %d: Nr. of PRBS errors = %d"%(elink, prbs_errors[oh_select][vfat][elink])
                if prbs_errors[oh_select][vfat][elink] == 0:
                    err_str += ", BER < {:.2e}".format(ber_ul) 
                err_str += Colors.ENDC
                print (err_str)
                logfile.write(err_str + "\n")
    print ("")
    logfile.write("\n")

    # Reset QUESO BERT registers
    write_backend_reg(queso_reset_node, 1)

    
    prbs_errors_oh_sn = {}
    for queso,oh_serial_nr in queso_dict.items():
        oh_select = queso_oh_map[queso]["OH"]
        vfat_list = queso_oh_map[queso]["VFAT"]
        prbs_errors_oh_sn[oh_serial_nr] = {}
        for vfat in vfat_list:
            prbs_errors_oh_sn[oh_serial_nr][vfat] = {}
            for elink in range(0, 9):
                if prbs_errors[oh_select][vfat][elink] == 0:
                    prbs_errors_oh_sn[oh_serial_nr][vfat][elink] = "< {:.2e}".format(ber_ul)
                else:
                    prbs_errors_oh_sn[oh_serial_nr][vfat][elink] = "%s"%(prbs_errors[oh_select][vfat][elink])

    with open(results_fn, "w") as resultsfile:
        resultsfile.write(json.dumps(prbs_errors_oh_sn))

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
    parser.add_argument("-i", "--input_file", action="store", dest="input_file", help="INPUT_FILE = input file containing OH serial numers for QUESOs")
    parser.add_argument("-t", "--time", action="store", dest="time", help="TIME = measurement time in minutes")
    parser.add_argument("-b", "--ber", action="store", dest="ber", help="BER = measurement till this BER. eg. 1e-12")
    parser.add_argument("-c", "--cl", action="store", dest="cl", default="0.95", help="CL = confidence level desired for BER measurement, default = 0.95")
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
            continue
        queso_nr = line.split()[0]
        oh_serial_nr = line.split()[1]
        if oh_serial_nr != "-9999":
            if int(oh_serial_nr) not in range(1, 1019):
                print(Colors.YELLOW + "Valid OH serial number between 1 and 1018" + Colors.ENDC)
                sys.exit() 
            queso_dict[queso_nr] = oh_serial_nr
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
    initialize(args.gem, args.system)
    print("Initialization Done\n")

    # Scanning/setting bitslips
    try:
        queso_bert(args.system, queso_dict, oh_gbt_vfat_map, args.time, args.ber, float(args.cl))
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()
