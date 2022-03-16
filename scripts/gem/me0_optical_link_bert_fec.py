from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import time, sleep
import sys
import argparse
import random
import datetime
import math

def check_fec_errors(gem, system, oh_ver, boss, path, opr, ohid, gbtid, runtime, ber_limit, vfat_list, verbose):

    resultDir = "results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    me0Dir = "results/me0_lpgbt_data"
    try:
        os.makedirs(me0Dir) # create directory for ME0 lpGBT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = "results/me0_lpgbt_data/lpgbt_optical_link_bert_fec_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    file_out = open(dataDir+"/%s_OH%d_GBT%s_%s_bert_fec_test_output_"%(gem,ohid,"_".join(gbtid), path)+now+".txt", "w")
    print ("Checking FEC Errors for: " + path + "\n")
    file_out.write("Checking FEC Errors for: " + path + "\n\n")
    fec_errors = 0

    if system != "chc" and opr in ["start", "run"]:
        gem_utils.gem_link_reset()
    sleep(0.1)

    gbt_list = []
    for gbt in gbtid:
        gbt_list.append(int(gbt))

    data_rate=0
    data_packet_size = 0
    if path=="uplink":
        print ("For Uplink:")
        file_out.write("For Uplink:\n")
        data_rate = 10.24 * 1e9
        data_packet_size = 256
    elif path=="downlink":
        print ("For Downlink:")
        file_out.write("For Downlink:\n")
        data_rate = 2.56 * 1e9
        data_packet_size = 64

    if runtime is None:
        ber_limit = float(ber_limit)
        runtime = 1.0/(data_rate * ber_limit * 60)
    elif ber_limit is None:
        runtime = float(runtime)

    if path == "uplink": # check FEC errors on backend
        if opr != "run" and opr != "read":
            print (Colors.YELLOW + "Only run and read operation allowed for uplink" + Colors.ENDC)
            rw_terminate()

        fec_node_list = {}
        for gbt in gbt_list:
            fec_node_list[gbt] = gem_utils.get_backend_node("BEFE.GEM.OH_LINKS.OH%d.GBT%d_FEC_ERR_CNT" % (ohid, gbt))

        if opr == "read":
            for gbt in fec_node_list:
                fec_node = fec_node_list[gbt]
                read_fec_errors = gem_utils.read_backend_reg(fec_node)
                read_fec_error_print = ""
                read_fec_error_write = ""
                if read_fec_errors==0:
                    read_fec_error_print += Colors.GREEN
                else:
                    read_fec_error_print += Colors.RED
                read_fec_error_print += "\nGBT %d, Number of FEC Errors = %d\n" %(gbt, read_fec_errors)
                read_fec_error_write += "\nGBT %d, Number of FEC Errors = %d\n" %(gbt, read_fec_errors)
                read_fec_error_print += Colors.ENDC
                print (read_fec_error_print)
                file_out.write(read_fec_error_write + "\n")
            return

        # Reset the error counters
        node = gem_utils.get_backend_node("BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET")
        gem_utils.write_backend_reg(node, 0x001)

        vfat_node = []
        for vfat in vfat_list:
            vfat_node.append(gem_utils.get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.%s" % (ohid, vfat-6*ohid, "TEST_REG")))
        
        # start error counting loop
        start_fec_errors = {}
        end_fec_errors = {}
        fec_errors = {}
        print ("Start Error Counting for time = %f minutes" % (runtime))
        file_out.write("Start Error Counting for time = %f minutes\n" % (runtime))
        print ("Starting with: ")
        file_out.write("Starting with: \n")
        for gbt in fec_node_list:
            fec_node = fec_node_list[gbt]
            start_fec_errors[gbt] = gem_utils.read_backend_reg(fec_node)
            print ("  GBT %d, number of FEC Errors = %d" % (gbt, start_fec_errors[gbt]))
            file_out.write("  GBT %d, number of FEC Errors = %d\n" % (gbt, start_fec_errors[gbt]))
        print ("")
        file_out.write("\n")

        t0 = time()
        time_prev = t0
        ber_passed_log = -1
        while ((time()-t0)/60.0) < runtime:
            for v_node in vfat_node:
                data_write = random.randint(0, (2**32 - 1)) # random number to write (32 bit)
                gem_utils.write_backend_reg(v_node, data_write)
                data_read = gem_utils.read_backend_reg(v_node)
                if system=="backend":
                    if data_read!=data_write:
                        print (Colors.RED + "Register value mismatch\n" + Colors.ENDC)
                        file_out.write("Register value mismatch\n\n")
                        rw_terminate()

            ber_t = 1.0/(data_rate * (time()-t0))
            ber_t_log = math.log(ber_t, 10)
            if ber_t_log<=-9 and (ber_passed_log-ber_t_log)>=1:
                print ("\nBER: ")
                file_out.write("\nBER: \n")
                for gbt in fec_node_list:
                    fec_node = fec_node_list[gbt]
                    curr_fec_errors = gem_utils.read_backend_reg(fec_node)
                    curr_ber_str = ""
                    curr_ber_str_write = ""
                    if curr_fec_errors == 0:
                        curr_ber_str += Colors.GREEN + "  GBT %d: BER "%gbt
                        curr_ber_str_write += "  GBT %d: BER "%gbt
                        curr_ber_str += "< {:.2e}".format(ber_t)
                        curr_ber_str_write += "< {:.2e}".format(ber_t)
                    else:
                        curr_ber_str += Colors.RED + "  GBT %d: BER "%gbt
                        curr_ber_str_write += "  GBT %d: BER "%gbt
                        curr_ber_str += "= {:.2e}".format(curr_fec_errors/(data_rate * (time()-t0)))
                        curr_ber_str_write += "= {:.2e}".format(curr_fec_errors/(data_rate * (time()-t0)))
                    curr_ber_str += " (time = %.2f min)"%((time()-t0)/60.0) + Colors.ENDC
                    curr_ber_str_write += " (time = %.2f min)"%((time()-t0)/60.0)
                    print (curr_ber_str)
                    file_out.write(curr_ber_str_write+"\n")
                print ("\n")
                file_out.write("\n\n")
                ber_passed_log = ber_t_log
                
            time_passed = (time()-time_prev)/60.0
            if time_passed >= 1:
                if verbose:
                    print ("Time passed: %f minutes: " % ((time()-t0)/60.0))
                    file_out.write("Time passed: %f minutes\n" % ((time()-t0)/60.0))
                    for gbt in fec_node_list:
                        fec_node = fec_node_list[gbt]
                        curr_fec_errors = gem_utils.read_backend_reg(fec_node)
                        print ("  GBT %d: number of FEC errors accumulated = %d" % (gbt, curr_fec_errors))
                        file_out.write("  GBT %d: number of FEC errors accumulated = %d\n" % (gbt, curr_fec_errors))
                    print ("")
                    file_out.write("\n")
                time_prev = time()

        print ("\nEnd Error Counting:")
        file_out.write("\nEnd Error Counting: \n" %(end_fec_errors))
        for gbt in fec_node_list:
            fec_node = fec_node_list[gbt]
            end_fec_errors[gbt] = gem_utils.read_backend_reg(fec_node)
            print ("  GBT %d, number of FEC Errors = %d" %(gbt, end_fec_errors[gbt]))
            file_out.write("  GBT %d, number of FEC Errors = %d\n" %(gbt, end_fec_errors[gbt]))
            #fec_errors[gbt] = end_fec_errors[gbt] - start_fec_errors[gbt]
            fec_errors[gbt] = end_fec_errors[gbt]
        print ("")
        file_out.write("\n")

    elif path == "downlink": # check FEC errors on lpGBT
        # Enable the counter
        if opr in ["start", "run"]:
            if oh_ver == 1:
                writeReg(getNode("LPGBT.RW.PROCESS_MONITOR.DLDPFECCOUNTERENABLE"), 0x1, 0)
            elif oh_ver == 2:
                writeReg(getNode("LPGBT.RW.DEBUG.DLDPFECCOUNTERENABLE"), 0x1, 0)
    
        # start error counting loop
        start_fec_errors = lpgbt_fec_error_counter(oh_ver)
        if opr == "run":
            print ("Start Error Counting for time = %f minutes" % (runtime))
            file_out.write("Start Error Counting for time = %f minutes\n" % (runtime))
        if opr in ["start", "run"]:
            print ("Starting with number of FEC Errors = %d\n" % (start_fec_errors))
            file_out.write("Starting with number of FEC Errors = %d\n\n" % (start_fec_errors))
        
        t0 = time()
        time_prev = t0
        ber_passed_log = -1
        if opr == "run":
            while ((time()-t0)/60.0) < runtime:
                ber_t = 1.0/(data_rate * (time()-t0))
                ber_t_log = math.log(ber_t, 10)
                if ber_t_log<=-9 and (ber_passed_log-ber_t_log)>=1:
                    print ("\nBER: ")
                    file_out.write("\nBER: \n")
                    curr_fec_errors = lpgbt_fec_error_counter(oh_ver)
                    curr_ber_str = ""
                    curr_ber_str_write = ""
                    if curr_fec_errors == 0:
                       curr_ber_str += Colors.GREEN + "  GBT %d: BER "%int(gbt_list[0])
                       curr_ber_str_write += "  GBT %d: BER "%int(gbt_list[0])
                       curr_ber_str += "< {:.2e}".format(ber_t)
                       curr_ber_str_write += "< {:.2e}".format(ber_t)
                    else:
                       curr_ber_str += Colors.RED + "  GBT %d: BER "%int(gbt_list[0])
                       curr_ber_str_write += "  GBT %d: BER "%int(gbt_list[0])
                       curr_ber_str += "= {:.2e}".format(curr_fec_errors/(data_rate * (time()-t0)))
                       curr_ber_str_write += "= {:.2e}".format(curr_fec_errors/(data_rate * (time()-t0)))
                    curr_ber_str += " (time = %.2f min)"%((time()-t0)/60.0) + Colors.ENDC
                    curr_ber_str_write += " (time = %.2f min)"%((time()-t0)/60.0)
                    print (curr_ber_str)
                    file_out.write(curr_ber_str_write)
                    print ()
                    file_out.write("\n")
                    ber_passed_log = ber_t_log
            
                time_passed = (time()-time_prev)/60.0
                if time_passed >= 1:
                    curr_fec_errors = lpgbt_fec_error_counter(oh_ver)
                    if verbose:
                        print ("Time passed: %f minutes, GBT %d: number of FEC errors accumulated = %d" % ((time()-t0)/60.0, int(gbt_list[0]), curr_fec_errors))
                        file_out.write("Time passed: %f minutes: GBT %d, number of FEC errors accumulated = %d\n" % ((time()-t0)/60.0, int(gbt_list[0]), curr_fec_errors))
                    time_prev = time()
        
        end_fec_errors = lpgbt_fec_error_counter(oh_ver)
        end_fec_error_print = ""
        end_fec_error_write = ""
        if end_fec_errors==0:
            end_fec_error_print += Colors.GREEN
        else:
            end_fec_error_print += Colors.RED
        if opr == "read":
            end_fec_error_print += "\nNumber of FEC Errors = %d\n" %(end_fec_errors)
            end_fec_error_write += "\nNumber of FEC Errors = %d\n" %(end_fec_errors)
            end_fec_error_print += Colors.ENDC
            print (end_fec_error_print)
            file_out.write(end_fec_error_write + "\n")
        elif opr == "stop":
            end_fec_error_print += "\nEnd Error Counting with number of FEC Errors = %d\n" %(end_fec_errors)
            end_fec_error_write += "\nEnd Error Counting with number of FEC Errors = %d\n" %(end_fec_errors)
            end_fec_error_print += Colors.ENDC
            print (end_fec_error_print)
            file_out.write(end_fec_error_write + "\n")
        elif opr == "run":
            print ("\nEnd Error Counting with number of FEC Errors = %d\n" %(end_fec_errors))
            file_out.write("\nEnd Error Counting with number of FEC Errors = %d\n\n" %(end_fec_errors))
        fec_errors = {}
        #fec_errors[gbt_list[0]] = end_fec_errors - start_fec_errors
        fec_errors[gbt_list[0]] = end_fec_errors
        
        # Disable the counter
        if opr in ["run", "stop"]:
            if oh_ver == 1:
                writeReg(getNode("LPGBT.RW.PROCESS_MONITOR.DLDPFECCOUNTERENABLE"), 0x0, 0)
            elif oh_ver == 2:
                writeReg(getNode("LPGBT.RW.DEBUG.DLDPFECCOUNTERENABLE"), 0x0, 0)

        if opr != "run":
            return  

    for gbt in gbt_list:
        fec_error_gbt = fec_errors[gbt]
        ber = float(fec_error_gbt) / (data_rate * runtime * 60)
        ineffi = ber * data_packet_size
        ber_ul = 1.0/ (data_rate * runtime * 60)
        ineffi_ul = ber_ul * data_packet_size
        ber_str = ""
        ineffi_str = ""
        if ber!=0:
            ber_str = "= {:.2e}".format(ber)
            ineffi_str = "= {:.2e}".format(ineffi)
        else:
            ber_str = "< {:.2e}".format(ber_ul)
            ineffi_str = "< {:.2e}".format(ineffi_ul)
        result_string = ""
        result_string_write = ""
        if fec_error_gbt == 0:
            result_string += Colors.GREEN
        else:
            result_string += Colors.YELLOW
        result_string += "GBT %d\n"%gbt
        result_string += "  Number of FEC errors in %.1f minutes: %d\n"%(runtime, fec_error_gbt)
        result_string += "  Bit Error Ratio (BER) " + ber_str + "\n"
        result_string += "  Inefficiency " + ineffi_str + Colors.ENDC + "\n"
        result_string_write += "GBT %d\n"%gbt
        result_string_write += "  Number of FEC errors in %.1f minutes: %d\n"%(runtime, fec_error_gbt)
        result_string_write += "  Bit Error Ratio (BER) " + ber_str + "\n"
        result_string_write += "  Inefficiency " + ineffi_str + "\n"
        print (result_string)
        file_out.write(result_string_write + "\n")
    file_out.close()
    
def lpgbt_fec_error_counter(oh_ver):
    error_counter = 0
    if oh_ver == 1:
        error_counter_h = readReg(getNode("LPGBT.RO.FEC.DLDPFECCORRECTIONCOUNT_H"))
        error_counter_l = readReg(getNode("LPGBT.RO.FEC.DLDPFECCORRECTIONCOUNT_L"))
        error_counter = (error_counter_h << 8) | error_counter_l
    elif oh_ver == 2:
        error_counter_0 = readReg(getNode("LPGBT.RO.FEC.DLDPFECCORRECTIONCOUNT0"))
        error_counter_1 = readReg(getNode("LPGBT.RO.FEC.DLDPFECCORRECTIONCOUNT1"))
        error_counter_2 = readReg(getNode("LPGBT.RO.FEC.DLDPFECCORRECTIONCOUNT2"))
        error_counter_3 = readReg(getNode("LPGBT.RO.FEC.DLDPFECCORRECTIONCOUNT3"))
        error_counter = (error_counter_0 << 24) | (error_counter_1 << 16) | (error_counter_2 << 8) | error_counter_3
    return error_counter   
       
if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 Bit Error Ratio Test (BERT) using FEC Error Counters")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", nargs="+", dest="gbtid", help="gbtid = list of GBT numbers (multiple only possible for uplink)")
    parser.add_argument("-p", "--path", action="store", dest="path", help="path = uplink, downlink")
    parser.add_argument("-r", "--opr", action="store", dest="opr", default="run", help="opr = start, run, read, stop (only allowed options for uplink: run, read)")
    parser.add_argument("-t", "--time", action="store", dest="time", help="TIME = measurement time in minutes")
    parser.add_argument("-b", "--ber", action="store", dest="ber", help="BER = measurement till this BER. eg. 1e-12")
    parser.add_argument("-v", "--vfats", action="store", dest="vfats", nargs="+", help="vfats = list of VFATs (0-23) for read/write TEST_REG")
    parser.add_argument("-z", "--verbose", action="store_true", dest="verbose", help="VERBOSE")
    args = parser.parse_args()

    if args.system == "chc":
        print ("Using Rpi CHeeseCake for BERT")
    elif args.system == "backend":
        print ("Using Backend for BERT")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running BERT on lpGBT")
    else:
        print (Colors.YELLOW + "Only valid options: chc, backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem != "ME0":
        print(Colors.YELLOW + "Valid gem station: ME0" + Colors.ENDC)
        sys.exit()

    if args.path not in ["uplink", "downlink"]:
        print (Colors.YELLOW + "Enter valid path" + Colors.ENDC)
        sys.exit()

    if args.path == "uplink":
        if args.system == "chc":
            print (Colors.YELLOW + "For uplink, cheesecake not possible" + Colors.ENDC)
            sys.exit()
        if args.opr != "run" and args.opr != "read":
            print (Colors.YELLOW + "For uplink, only run and read operation allowed" + Colors.ENDC)
            sys.exit()
    elif args.path == "downlink":
        if args.opr not in ["start", "run", "read", "stop"]:
            print (Colors.YELLOW + "Invalid operation" + Colors.ENDC)
            sys.exit()

    if args.ohid is None:
        print(Colors.YELLOW + "Need OHID" + Colors.ENDC)
        sys.exit()
    #if int(args.ohid) > 1:
    #    print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
    #    sys.exit()

    if args.gbtid is None:
        print(Colors.YELLOW + "Need GBTID" + Colors.ENDC)
        sys.exit()
    else:
        if args.path == "downlink" and len(args.gbtid) > 1:
            print (Colors.YELLOW + "Only 1 GBT allowd for downlink" + Colors.ENDC)
            sys.exit()
        for gbt in args.gbtid:
            if int(gbt) > 7:
                print(Colors.YELLOW + "Only GBTID 0-7 allowed" + Colors.ENDC)
                sys.exit()

    if args.path == "downlink":
        oh_ver = get_oh_ver(args.ohid, args.gbtid[0])
        boss = None
        if int(args.gbtid[0])%2 == 0:
            boss = 1
        else:
            boss = 0
    else:
        oh_ver = None
        boss = None

    if args.path == "downlink":
        if not boss:
            print (Colors.YELLOW + "Downlink can be checked only for boss lpGBT" + Colors.ENDC)
            sys.exit()

    if (args.path == "uplink" and args.opr == "run") or (args.path == "downlink" and args.opr == "run"):
        if args.time is None and args.ber is None:
            print (Colors.YELLOW + "BERT measurement time or BER limit required" + Colors.ENDC)
            sys.exit()
        if args.time is not None and args.ber is not None:
            print (Colors.YELLOW + "Only either BERT measurement time or BER limit should be given" + Colors.ENDC)
            sys.exit()
    else:
        if args.time is not None or args.ber is not None:
            print (Colors.YELLOW + "BERT measurement time or VER limit not required" + Colors.ENDC)
            sys.exit()
        args.time = "0"
        args.ber = "0"

    if args.system == "backend" or args.system == "dryrun":
        import gem.gem_utils as gem_utils
        global gem_utils

    vfat_list = []
    if args.vfats is not None:
        if args.path != "uplink":
            print (Colors.YELLOW + "VFAT only for uplink" + Colors.ENDC)
            sys.exit()
        for v in args.vfats:
            v_int = int(v)
            if v_int not in range(0,23):
                print (Colors.YELLOW + "Invalid VFAT number, only allowed 0-23" + Colors.ENDC)
                sys.exit()
            gbt, gbt_select, elink, gpio = gem_utils.me0_vfat_to_gbt_elink_gpio(vfat)
            if gbt!=args.lpgbt or gbt_select!=int(args.gbtid):
                print (Colors.YELLOW + "Invalid VFAT number for selected lpGBT" + Colors.ENDC)
                sys.exit()
            vfat_list.append(v_int)
        
    # Initialization
    if args.path == "downlink":
        rw_initialize(args.gem, args.system, oh_ver, boss, args.ohid, args.gbtid[0])
    else:
        rw_initialize(args.gem, args.system)
    print("Initialization Done\n")

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun" and args.path == "downlink":
        check_rom_readback(args.ohid, args.gbtid[0])
        check_lpgbt_mode(boss, args.ohid, args.gbtid[0])   
        
    # Check if GBT is READY
    if args.path == "downlink":
        for gbt in args.gbtid:
            check_lpgbt_ready(args.ohid, gbt)

    try:
        check_fec_errors(args.gem, args.system, oh_ver, boss, args.path, args.opr, int(args.ohid), args.gbtid, args.time, args.ber, vfat_list, args.verbose)
    except KeyboardInterrupt:
        print (Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
