from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse
import math

def queso_bert(system, oh_select, oh_ser_nr, vfat_list, runtime, ber_limit, cl):
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
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    file_out = open(dataDir+"/queso_OH_ser_%d_elink_bert"%(oh_ser_nr)+".txt", "w")
    print ("Checking BER for elinks: \n")
    file_out.write("Checking BER for elinks: \n\n")
    
    # Check if GBT is READY
    for gbt in [0,1]:
        link_ready = read_backend_reg(get_backend_node("BEFE.GEM.OH_LINKS.OH%s.GBT%s_READY" % (oh_select, gbt)))
        if (link_ready!=1):
            print (Colors.RED + "ERROR: OH lpGBT links are not READY, check fiber connections" + Colors.ENDC)
            file_out.close()
            terminate()

    print ("Checking PRBS errors for OH serial number: %d\n"%oh_ser_nr)
    file_out.write("Checking PRBS errors for OH serial number: %d\n\n"%oh_ser_nr)
    print ("Running for all Elink (0-9) for VFATs: ")
    print (" ".join(str(vfat) for vfat in vfat_list))
    print ("\n")
    file_out.write("Running for all Elink (0-9) for VFATs: \n")
    file_out.write(" ".join(str(vfat) for vfat in vfat_list))
    file_out.write("\n\n")

    prbs_errors = {}
    for vfat in vfat_list:
        prbs_errors[vfat] = {}
        for elink in range(0,9):
            prbs_errors[vfat][elink] = 0

    data_rate = 320 *1e6 # 320 Mb/s
    if runtime is None:
        ber_limit = float(ber_limit)
        runtime = (-math.log(1-cl))/(data_rate * ber_limit * 60)
    elif ber_limit is None:
        runtime = float(runtime)

    queso_reset_node = get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_RESET")
    queso_bitslip_nodes = {}
    queso_prbs_nodes = {}
    for vfat in vfat_list:
        queso_bitslip_nodes[vfat] = {}
        queso_prbs_nodes[vfat] = {}
        for elink in range(0,9):
            queso_bitslip_nodes[vfat][elink] = get_backend_node("BEFE.GEM.GEM_TESTS.QUESO_TEST.OH%d.VFAT%d.ELINK%d.ELINK_BITSLIP"%(oh_select, vfat, elink))
            queso_prbs_nodes[vfat][elink] = get_backend_node("BEFE.GEM.GEM_TESTS.QUESO_TEST.OH%d.VFAT%d.ELINK%d.PRBS_ERR_COUNT"%(oh_select, vfat, elink))

    print ("Start Error Counting for time = %.2f minutes" % (runtime))
    file_out.write("Start Error Counting for time = %.2f minutes\n" % (runtime))
    print ("")
    file_out.write("\n")

    # Enable QUESO BERT
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_EN"), 1)

    # Reset QUESO BERT registers
    write_backend_reg(queso_reset_node, 1)
    sleep(0.1)

    t0 = time()
    time_prev = t0
    while ((time()-t0)/60.0) < runtime:
        time_passed = (time()-time_prev)/60.0
        if time_passed >= 1:
            print ("Time passed: %.2f minutes: " % ((time()-t0)/60.0))
            file_out.write("Time passed: %.2f minutes\n" % ((time()-t0)/60.0))
            time_prev = time()

    print ("\nEnd Error Counting:")
    file_out.write("\nEnd Error Counting: \n")

    # Disable QUESO BERT 
    sleep(0.1)
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_EN"), 0)

    for vfat in queso_bitslip_nodes:
        for elink in queso_bitslip_nodes[vfat]:
            prbs_errors[vfat][elink] = read_backend_reg(queso_prbs_nodes[vfat][elink])
   
    # Printing results
    ber_ul = (-math.log(1-cl))/ (data_rate * runtime * 60)
    print ("BERT Reuslts for OH Ser %d:\n"%oh_ser_nr)
    file_out.write("BERT Reuslts for OH Ser %d:\n\n"%oh_ser_nr)
    for vfat in prbs_errors:
        print ("  VFAT %d:"%vfat)
        file_out.write("  VFAT %d:\n"%vfat)
        for elink in prbs_errors[vfat]:
            err_str = ""
            if prbs_errors[vfat][elink] == 0:
                err_str += Colors.GREEN
            else:
                err_str += Colors.RED
            err_str += "    ELINK %d: Nr. of PRBS errors = %d"%(elink, prbs_errors[vfat][elink])
            if prbs_errors[vfat][elink] == 0:
                err_str += ", BER < {:.2e}".format(ber_ul) 
            err_str += Colors.ENDC
            print (err_str)
            file_out.write(err_str + "\n")
    print ("")
    file_out.write("\n")

    # Reset QUESO BERT registers
    write_backend_reg(queso_reset_node, 1)

    print ("Finished PRBS errors for OH serial number: %d\n"%oh_ser_nr)
    file_out.write("Finished PRBS errors for OH serial number: %d\n\n"%oh_ser_nr)

    file_out.close()

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="QUESO BERT")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
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
        queso_bert(args.system, int(args.ohid), vfat_list, args.time, args.ber, float(args.cl))
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()