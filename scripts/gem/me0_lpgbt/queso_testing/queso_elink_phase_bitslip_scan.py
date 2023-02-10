from gem.gem_utils import *
from time import sleep, time
import datetime
import sys
import argparse

def set_bitslips(queso_bitslip_nodes, phase_bitslip_list):
    for vfat in queso_bitslip_nodes:
        for elink in queso_bitslip_nodes[vfat]:
            write_backend_reg(queso_bitslip_nodes[vfat][elink], phase_bitslip_list[vfat][elink]["bitslip"])

def set_phase(oh_select, vfat, elink, phase):
    gbt, gbt_select, rx_elink, gpio = me0_vfat_to_gbt_elink_gpio(vfat)
    sbit_elinks = me0_vfat_to_sbit_elink(vfat)
    select_ic_link(oh_select, gbt_select)
    if elink==0:
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX%dPHASESELECT"%rx_elink), phase)
    else:
        sbit_elink = sbit_elinks[elink-1]
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX%dPHASESELECT"%sbit_elink), phase)
    sleep(0.000001) 

def set_phases(oh_select, phase_bitslip_list):
    for vfat in phase_bitslip_list:
        for elink in phase_bitslip_list[vfat]:
            phase = phase_bitslip_list[vfat][elink]["phase"]
            set_phase(oh_select, vfat, elink, phase)

def find_phase_center(err_list):
    lower_edge_min = -1
    upper_edge_max = 15
    center = 0
    width = 0

    bad_phases = []
    for phase in range(0, len(err_list)):
        if err_list[phase] != 0:
            bad_phases.append(phase)

    if len(bad_phases) == 0:
        width = upper_edge_max - lower_edge_min - 1
        center = int((lower_edge_min + upper_edge_max)/2)
    elif len(bad_phases) == 1:
        if bad_phases[0] <= 7:
            center = bad_phases[0] + 4
            width = upper_edge_max - bad_phases[0] - 1
        else:
            center = bad_phases[0] - 4
            width = bad_phases[0] - lower_edge_min - 1
    else:
        lower_edge = -1
        upper_edge = 15
        l = -9999
        u = -9999
        diff = 0
        max_diff = 0
        bad_phase_mean = -9999
        for i in range(0, len(bad_phases)-1):
            bad_phase_mean += bad_phases[i]
            l = bad_phases[i]
            u = bad_phases[i+1]
            diff = u - l - 1
            if diff >= max_diff:
                lower_edge = l
                upper_edge = u
                max_diff = diff
        bad_phase_mean = int(bad_phase_mean/len(bad_phases))
        width = upper_edge - lower_edge - 1
        lower_edge_width = bad_phases[0] - lower_edge_min - 1
        upper_edge_width = upper_edge_max - bad_phases[-1] - 1
        if max(lower_edge_width, width, upper_edge_width) == lower_edge_width:
            center = bad_phases[0] - 4
            width = lower_edge_width
        elif max(lower_edge_width, width, upper_edge_width) == upper_edge_width:
            center = bad_phases[-1] + 4
            width = upper_edge_width
        else:                   
            if width%2 != 0:
                center = int((lower_edge + upper_edge)/2)
            else:
                if err_list[lower_edge] <= err_list[upper_edge]:
                   center = int((lower_edge + upper_edge)/2)
                else:
                   center = int((lower_edge + upper_edge)/2) + 1

    if center < 0:
        center = 0
    elif center > 14:
        center = 14
    return center, width

def scan_set_phase_bitslip(system, oh_select, queso_select, vfat_list, phase_bitslip_list):
    
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

    if phase_bitslip_list != {}:
        print ("Setting phases and bitslips:")
        set_phases(oh_select, phase_bitslip_list)
        set_bitslips(queso_bitslip_nodes, phase_bitslip_list)
    else:
        print ("Scanning phase and bitslips:")
        resultDir = "me0_lpgbt/queso_testing/results"
        try:
            os.makedirs(resultDir) # create directory for results
        except FileExistsError: # skip if directory already exists
            pass
        quesoDir = "me0_lpgbt/queso_testing/results/phase_bitslip_results"
        try:
            os.makedirs(quesoDir) # create directory for results
        except FileExistsError: # skip if directory already exists
            pass
        dataDir = "me0_lpgbt/queso_testing/results/phase_bitslip_results/queso%d"%queso_select
        try:
            os.makedirs(dataDir) # create directory for results
        except FileExistsError: # skip if directory already exists
            pass
        now = str(datetime.datetime.now())[:16]
        now = now.replace(":", "_")
        now = now.replace(" ", "_")
        file_out = open(dataDir+"/queso%d_vfat_elink_phase_bitslip_results_"%(queso_select)+now+".txt", "w")

        phase_bitslip_list = {}
        prbs_min_err_list = {}
        bitslip_list_perphase = {}
        for vfat in vfat_list:
            phase_bitslip_list[vfat] = {}
            prbs_min_err_list[vfat] = {}
            bitslip_list_perphase[vfat] = {}
            for elink in range(0,9):
                phase_bitslip_list[vfat][elink]["phase"] = -9999
                phase_bitslip_list[vfat][elink]["bitslip"] = -9999
                prbs_min_err_list[vfat][elink] = {}
                bitslip_list_perphase[vfat][elink] = {}
                for phase in range(0, 15):
                    prbs_min_err_list[vfat][elink][phase] = 9999
                    bitslip_list_perphase[vfat][elink][phase] = -9999

        # Enable QUESO BERT
        write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_EN"), 1)

        # Reset QUESO BERT registers
        write_backend_reg(queso_reset_node, 1)
        sleep(0.1)

        print ("")
        # Scan over phases
        for phase in range(0, 15):
            print ("Scanning Phase %d\n:"%phase)
            for vfat in queso_bitslip_nodes:
                for elink in queso_bitslip_nodes[vfat]:
                    set_phase(oh_select, vfat, elink, phase):

            # Scan over bitslip and check PRBS errors
            for bitslip in range(0,9):
                print ("  Checking Bitslip %d\n"%bitslip)

                # Set the bitslip for all vfats and elinks
                for vfat in queso_bitslip_nodes:
                    for elink in queso_bitslip_nodes[vfat]:
                    write_backend_reg(queso_bitslip_nodes[vfat][elink], bitslip)
                sleep(0.1)

                # Reset and wait
                write_backend_reg(queso_reset_node, 1)
                sleep(0.1)

                # Check PRBS errors
                for vfat in queso_bitslip_nodes:
                    for elink in queso_bitslip_nodes[vfat]:
                        prbs_err = read_backend_reg(queso_prbs_nodes[vfat][elink])
                        if prbs_err <= prbs_min_err_list[vfat][elink][phase]:
                            bitslip_list_perphase[vfat][elink][phase] = bitslip
                            prbs_min_err_list[vfat][elink][phase] = prbs_err

        # Disable QUESO BERT 
        sleep(0.1)
        write_backend_reg(get_backend_node("BEFE.GEM.GEM_TESTS.CTRL.QUESO_EN"), 0)

        # Reset QUESO BERT registers
        write_backend_reg(queso_reset_node, 1)

        # Find best phase and bitslip
        print ("\nPhase Scan Results:")
        for vfat in queso_bitslip_nodes:
            centers = 9*[0]
            widths  = 9*[0]
            for elink in queso_bitslip_nodes[vfat]:
                centers[elink], widths[elink] = find_phase_center(prbs_min_err_list[vfat][elink])
            print ("\nVFAT %02d :" %(vfat))
            for elink in queso_bitslip_nodes[vfat]:
                phase_print = "  ELINK %02d: " % (elink)
                min_errors = 0
                for phase in range(0, 15):
                    if (widths[elink]>0 and phase==centers[elink]):
                        char=Colors.GREEN + "+" + Colors.ENDC
                        phase_bitslip_list[vfat][elink]["phase"] = phase
                        phase_bitslip_list[vfat][elink]["bitslip"] = bitslip_list_perphase[vfat][elink][phase]
                elif (prbs_min_err_list[vfat][elink][phase] > 0):
                        char=Colors.RED + "-" + Colors.ENDC
                    else:
                        char = Colors.YELLOW + "x" + Colors.ENDC
                    phase_print += "%s" %char
                if widths[elink]<3:
                    phase_print += Colors.RED + " (center=%d, width=%d, bitslip at center=%d) BAD" % (centers[elink], widths[elink], bitslip_list_perphase[vfat][elink][phase]) + Colors.ENDC
                elif widths[elink]<5:
                    phase_print += Colors.YELLOW + " (center=%d, width=%d, bitslip at center=%d) WARNING" % (centers[elink], widths[elink], bitslip_list_perphase[vfat][elink][phase]) + Colors.ENDC
                else:
                    phase_print += Colors.GREEN + " (center=%d, width=%d, bitslip at center=%d) GOOD" % (centers[elink], widths[elink], bitslip_list_perphase[vfat][elink][phase]) + Colors.ENDC
                print(phase_print)

        for vfat in queso_bitslip_nodes:
            for elink in queso_bitslip_nodes[vfat]:
                if phase_bitslip_list[vfat][elink]["phase"] == -9999:
                    print (Colors.YELLOW + "Correct phase not found for VFAT %d Elink %d"%(vfat, elink) + Colors.ENDC)
                    phase_bitslip_list[vfat][elink]["phase"] = 0
                if phase_bitslip_list[vfat][elink]["bitslip"] == -9999:
                    print (Colors.YELLOW + "Correct bitslip not found for VFAT %d Elink %d"%(vfat, elink) + Colors.ENDC)
                    phase_bitslip_list[vfat][elink]["bitslip"] = 0
                if prbs_min_err_list[vfat][elink][phase_bitslip_list[vfat][elink]["phase"]] != 0:
                    print (Colors.YELLOW + "PRBS errors not zero best bitslip for the best phase for VFAT %d Elink %d, min PRBS errors = %d"%(vfat, elink, prbs_min_err_list[vfat][elink][phase_bitslip_list[vfat][elink]["phase"]]) + Colors.ENDC)

        print ("Setting phase and bitslips:")
        set_phases(oh_select, phase_bitslip_list)
        set_bitslips(queso_bitslip_nodes, phase_bitslip_list)

        file_out.write("vfat  elink  phase  bitslip\n")
        for vfat in queso_bitslip_nodes:
            for elink in queso_bitslip_nodes[vfat]:
                file_out.write("%d  %d  %01x  %01x\n"%(vfat, elink, phase_bitslip_list[vfat][elink]["phase"], phase_bitslip_list[vfat][elink]["bitslip"]))
        file_out.close()

    print ("Bitslips set for all Elink of all VFATs")
    

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Phase + Bitslip Scan for QUESO")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-u", "--queso", action="store", dest="queso", help="queso = QUESO number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-p", "--phase", action="store", dest="phase", help="phase = Best value of the elinkRX bitslip")
    parser.add_argument("-t", "--bitslip", action="store", dest="bitslip", help="bitslip = Best value of the elinkRX bitslip")
    parser.add_argument("-f", "--phase_bitslip_file", action="store", dest="phase_bitslip_file", help="phase_bitslip_file = Text file with best value of the elinkRX phase and bitslip")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for phase + bitslip scan")
    elif args.system == "dryrun":
        print ("Dry Run - not actually scanning phase and bitslip")
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

    phase_bitslip_list = {}
    if (args.bitslip is not None and args.phase is None) or (args.bitslip is None and args.phase is not None):
        print(Colors.YELLOW + "If you are providing a fixed value of phase or bitslip you have to provide both" + Colors.ENDC)
        sys.exit()
    if (args.bitslip is not None and args.phase is not None) and args.phase_bitslip_file is not None:
        print(Colors.YELLOW + "Only give either phase-bitslip value or file but not both" + Colors.ENDC)
        sys.exit()
    if args.bitslip is not None and args.phase is not None:
        for vfat in vfat_list:
            phase_bitslip_list[vfat] = {}
            for elink in range(0,9):
                phase_bitslip_list[vfat][elink] = {}
                phase_bitslip_list[vfat][elink]["phase"] = 0x00
                phase_bitslip_list[vfat][elink]["bitslip"] = 0x00
        for vfat in vfat_list:
            for elink in range(0,9):
                bitslip_list[vfat][elink]["phase"] = int(args.phase, 16)
                bitslip_list[vfat][elink]["bitslip"] = int(args.bitslip, 16)
    if args.phase_bitslip_file is not None:
        for vfat in vfat_list:
            phase_bitslip_list[vfat] = {}
            for elink in range(0,9):
                phase_bitslip_list[vfat][elink] = {}
                phase_bitslip_list[vfat][elink]["phase"] = 0x00
                phase_bitslip_list[vfat][elink]["bitslip"] = 0x00
        phase_bitslip_list_file = {}
        phase_bitslip_file = open(args.phase_bitslip_file)
        for line in phase_bitslip_file.readlines():
            if "vfat" in line:
                continue
            vfat = int(line.split()[0])
            elink = int(line.split()[1])
            phase = int(line.split()[2], 16)
            bitslip = int(line.split()[3], 16)
            if vfat not in phase_bitslip_list_file:
                phase_bitslip_list_file[vfat] = {}
            phase_bitslip_list_file[vfat][elink] = {}
            phase_bitslip_list_file[vfat][elink]["phase"] = phase
            phase_bitslip_list_file[vfat][elink]["bitslip"] = bitslip
        phase_bitslip_file.close()
        for vfat in vfat_list:
            for elink in range(0,9):
                if vfat in phase_bitslip_list_file:
                    if elink in phase_bitslip_list_file[vfat]:
                        phase_bitslip_list[vfat][elink]["phase"] = phase_bitslip_list_file[vfat][elink]["phase"]
                        phase_bitslip_list[vfat][elink]["bitslip"] = phase_bitslip_list_file[vfat][elink]["bitslip"]
                    else:
                        print(Colors.YELLOW + "Bitslip for VFAT %d Elink %d not in input file"%(vfat, elink) + Colors.ENDC)
                else:
                    print(Colors.YELLOW + "Bitslip for VFAT %d not in input file"%vfat + Colors.ENDC)

    # Initialization 
    initialize(args.gem, args.system)
    print("Initialization Done\n")

    # Scanning/setting bitslips
    try:
        scan_set_phase_bitslip(args.system, int(args.ohid), int(args.queso), vfat_list, phase_bitslip_list)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()