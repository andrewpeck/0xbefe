from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse

def set_bitslip(bitslip_list, queso_bitslip_nodes):
    for vfat in queso_bitslip_nodes:
        for elink in queso_bitslip_nodes[vfat]:
            write_backend_reg(queso_bitslip_nodes[vfat][elink], bitslip_list[vfat][elink])

def scan_set_bitslip(system, oh_select, queso_select, vfat_list, bitslip_list):
    
    queso_reset_node = get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_RESET")
    queso_bitslip_nodes = {}
    queso_prbs_nodes = {}
    for vfat in vfat_list:
        queso_bitslip_nodes[vfat] = {}
        queso_prbs_nodes[vfat] = {}
        for elink in range(0,9):
            queso_bitslip_nodes[vfat][elink] = get_backend_node("BEFE.GEM.GEM_TESTS.QUESO_TEST.OH%d.VFAT%d.ELINK%d.ELINK_BITSLIP"%(oh_select, vfat, elink))
            queso_prbs_nodes[vfat][elink] = get_backend_node("BEFE.GEM.GEM_TESTS.QUESO_TEST.OH%d.VFAT%d.ELINK%d.PRBS_ERR_COUNT"%(oh_select, vfat, elink))

    # Check if GBT is READY
    for gbt in [0,1]:
        link_ready = read_backend_reg(get_backend_node("BEFE.GEM.OH_LINKS.OH%s.GBT%s_READY" % (oh_select, gbt)))
        if (link_ready!=1):
            print (Colors.RED + "ERROR: OH lpGBT links are not READY, check fiber connections" + Colors.ENDC)
            file_out.close()
            terminate()

    if bitslip_list != {}:
        print ("Setting bitslips:")
        set_bitslip(bitslip_list, queso_bitslip_nodes)
    else:
        print ("Scanning bitslips:")
        resultDir = "me0_lpgbt/queso_testing/results"
        try:
            os.makedirs(resultDir) # create directory for results
        except FileExistsError: # skip if directory already exists
            pass
        quesoDir = "me0_lpgbt/queso_testing/results/bitslip_results"
        try:
            os.makedirs(quesoDir) # create directory for results
        except FileExistsError: # skip if directory already exists
            pass
        dataDir = "me0_lpgbt/queso_testing/results/bitslip_results/queso%d"%queso_select
        try:
            os.makedirs(dataDir) # create directory for results
        except FileExistsError: # skip if directory already exists
            pass
        now = str(datetime.datetime.now())[:16]
        now = now.replace(":", "_")
        now = now.replace(" ", "_")
        file_out = open(dataDir+"/queso%d_vfat_elink_bitslip_results_"%(queso_select)+now+".txt", "w")

        bitslip_list = {}
        for vfat in vfat_list:
            bitslip_list[vfat] = {}
            for elink in range(0,9):
                bitslip_list[vfat][elink] = -9999

        # Enable QUESO BERT
        write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_EN"), 1)

        # Reset QUESO BERT registers
        write_backend_reg(queso_reset_node, 1)
        sleep(0.1)

        # Scan over bitslip and check PRBS errors
        for bitslip in range(0,9):
            # Set the bitslip for all vfats and elinks
            for vfat in queso_bitslip_nodes:
                for elink in queso_bitslip_nodes[vfat]:
                    write_backend_reg(queso_bitslip_nodes[vfat][elink], bitslip)
            sleep(0.1)

            # Reset and wait
            write_backend_reg(queso_reset_node, 1)
            sleep(1)

            # Check PRBS errors
            for vfat in queso_bitslip_nodes:
                for elink in queso_bitslip_nodes[vfat]:
                    prbs_err = read_backend_reg(queso_prbs_nodes[vfat][elink])
                    if prbs_err == 0:
                        bitslip_list[vfat][elink] = bitslip

        # Disable QUESO BERT 
        sleep(0.1)
        write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_EN"), 0)

        # Reset QUESO BERT registers
        write_backend_reg(queso_reset_node, 1)

        for vfat in queso_bitslip_nodes:
            for elink in queso_bitslip_nodes[vfat]:
                if bitslip_list[vfat][elink] == -9999:
                    print (Colors.YELLOW + "Correct bitslip not found for VFAT %d Elink %d"%(vfat, elink) + Colors.ENDC)
                    bitslip_list[vfat][elink] = 0

        print ("Setting bitslips:")
        set_bitslip(bitslip_list, queso_bitslip_nodes)

        file_out.write("vfat  elink  bitslip\n")
        for vfat in queso_bitslip_nodes:
            for elink in queso_bitslip_nodes[vfat]:
                file_out.write("%d  %d  %01x\n"%(vfat, elink, bitslip_list[vfat][elink]))
        file_out.close()

    print ("Bitslips set for all Elink of all VFATs")
    

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Bitslip Scan for QUESO")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-u", "--queso", action="store", dest="queso", help="queso = QUESO number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-p", "--bitslip", action="store", dest="bitslip", help="bitslip = Best value of the elinkRX bitslip")
    parser.add_argument("-f", "--bitslip_file", action="store", dest="bitslip_file", help="bitslip_file = Text file with best value of the elinkRX bitslip")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for bitslip scan")
    elif args.system == "dryrun":
        print ("Dry Run - not actually scanning bitslip")
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

    bitslip_list = {}
    if args.bitslip is not None and args.bitslip_file is not None:
        print(Colors.YELLOW + "Only give either bitslip value or file but not both" + Colors.ENDC)
        sys.exit()
    if args.bitslip is not None:
        for vfat in vfat_list:
            bitslip_list[vfat] = {}
            for elink in range(0,9):
                bitslip_list[vfat][elink] = 0x0
        for vfat in vfat_list:
            for elink in range(0,9):
                bitslip_list[vfat][elink] = int(args.bitslip, 16)
    if args.bitslip_file is not None:
        for vfat in vfat_list:
            bitslip_list[vfat] = {}
            for elink in range(0,9):
                bitslip_list[vfat][elink] = 0x0
        bitslip_list_file = {}
        bitslip_file = open(args.bitslip_file)
        for line in bitslip_file.readlines():
            if "vfat" in line:
                continue
            vfat = int(line.split()[0])
            elink = int(line.split()[1])
            bitslip = int(line.split()[2], 16)
            if vfat not in bitslip_list_file:
                bitslip_list_file[vfat] = {}
            bitslip_list_file[vfat][elink] = bitslip
        bitslip_file.close()
        for vfat in vfat_list:
            for elink in range(0,9):
                if vfat in bitslip_list_file:
                    if elink in bitslip_list_file[vfat]:
                        bitslip_list[vfat][elink] = bitslip_list_file[vfat][elink]
                    else:
                        print(Colors.YELLOW + "Bitslip for VFAT %d Elink %d not in input file"%(vfat, elink) + Colors.ENDC)
                else:
                    print(Colors.YELLOW + "Bitslip for VFAT %d not in input file"%vfat + Colors.ENDC)

    # Initialization 
    initialize(args.gem, args.system)
    print("Initialization Done\n")

    # Scanning/setting bitslips
    try:
        scan_set_bitslip(args.system, int(args.ohid), int(args.queso), vfat_list, bitslip_list)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()
