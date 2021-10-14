from gem.me0_lpgbt.rw_reg_lpgbt import *
import gem.gem_utils as gem_utils
from time import sleep, time
import datetime
import sys
import argparse
import random
import json
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel

config_boss_filename = "../resources/me0_boss_config.txt"
config_sub_filename = "../resources/me0_sub_config.txt"
config_boss = {}
config_sub = {}

def getConfig (filename):
    f = open(filename, "r")
    reg_map = {}
    for line in f.readlines():
        reg = int(line.split()[0], 16)
        data = int(line.split()[1], 16)
        reg_map[reg] = data
    f.close()
    return reg_map


def vfat_sbit(gem, system, oh_select, vfat_list, nl1a, l1a_bxgap, set_cal_mode, cal_dac, bestphase_list):
    print ("%s VFAT S-Bit Phase Scan\n"%gem)

    if bestphase_list!={}:
        print ("Setting phases for VFATs only, not scanning")
        for vfat in vfat_list:
            sbit_elinks = gem_utils.vfat_to_sbit_elink(vfat)
            for elink in range(0,8):
                set_bestphase = bestphase_list[vfat][elink]
                setVfatSbitPhase(system, oh_select, vfat, sbit_elinks[elink], set_bestphase)
                print ("VFAT %02d: Phase set for ELINK %02d to: %s" % (vfat, elink, hex(set_bestphase)))
        return

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
    dataDir = "results/vfat_data/vfat_sbit_phase_scan_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/%s_OH%d_vfat_sbit_phase_scan_results_"%(gem,oh_select) + now + ".txt"
    file_out = open(filename, "w")
    file_out.write("vfat  elink  phase\n")

    errs = [[[0 for phase in range(16)] for elink in range(0,8)] for vfat in range(24)]

    gem_utils.global_reset()
    sleep(0.1)
    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)

    # Reading S-bit counters
    cyclic_running_node = gem_utils.get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_RUNNING")
    l1a_node = gem_utils.get_backend_node("BEFE.GEM_AMC.TTC.CMD_COUNTERS.L1A")
    calpulse_node = gem_utils.get_backend_node("BEFE.GEM_AMC.TTC.CMD_COUNTERS.CALPULSE")

    elink_sbit_select_node = gem_utils.get_backend_node("BEFE.GEM_AMC.SBIT_ME0.TEST_SEL_ELINK_SBIT_ME0") # Node for selecting Elink to count
    channel_sbit_select_node = gem_utils.get_backend_node("BEFE.GEM_AMC.SBIT_ME0.TEST_SEL_SBIT_ME0") # Node for selecting S-bit to count
    elink_sbit_counter_node = gem_utils.get_backend_node("BEFE.GEM_AMC.SBIT_ME0.TEST_SBIT0XE_COUNT_ME0") # S-bit counter for elink
    channel_sbit_counter_node = gem_utils.get_backend_node("BEFE.GEM_AMC.SBIT_ME0.TEST_SBIT0XS_COUNT_ME0") # S-bit counter for specific channel
    reset_sbit_counter_node = gem_utils.get_backend_node("BEFE.GEM_AMC.SBIT_ME0.CTRL.SBIT_TEST_RESET")  # To reset all S-bit counters

    for vfat in vfat_list:
        gbt, gbt_select, elink_daq, gpio = gem_utils.vfat_to_gbt_elink_gpio(vfat)
        gem_utils.check_gbt_link_ready(oh_select, gbt_select)

        link_good = gem_utils.read_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat)))
        sync_err = gem_utils.read_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat)))
        if system!="dryrun" and (link_good == 0 or sync_err > 0):
            print (Colors.RED + "Link is bad for VFAT# %02d"%(vfat) + Colors.ENDC)
            terminate()

        # Configure the pulsing VFAT
        print("Configuring VFAT %02d" % (vfat))
        configureVfat(1, vfat, oh_select, 0)
        if set_cal_mode == "voltage":
            gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"% (oh_select, vfat)), 1)
            gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"% (oh_select, vfat)), 200)
        elif set_cal_mode == "current":
            gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"% (oh_select, vfat)), 2)
            gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"% (oh_select, vfat)), 0)
        else:
            gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"% (oh_select, vfat)), 0)
            gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"% (oh_select, vfat)), 0)
        gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DAC"% (oh_select, vfat)), cal_dac)
        for i in range(128):
            enableVfatchannel(vfat, oh_select, i, 1, 0) # mask all channels and disable calpulsing
        print ("")

    # Configure TTC generator
    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.RESET"), 1)
    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE"), 1)
    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_L1A_GAP"), l1a_bxgap)
    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_L1A_COUNT"), nl1a)
    if l1a_bxgap >= 40:
        gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 25)
    else:
        gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 2)

    for phase in range(0, 16):
        print("Scanning phase %d" % phase)

        # set phases for all vfats under test
        for vfat in vfat_list:
            sbit_elinks = vfat_to_sbit_elink(vfat)
            for elink in range(0,8):
                setVfatSbitPhase(system, oh_select, vfat, sbit_elinks[elink], phase)

        s_bit_channel_mapping = {}
        print ("Checking errors: ")
        for vfat in vfat_list:
            gbt, gbt_select, elink_daq, gpio = gem_utils.vfat_to_gbt_elink_gpio(vfat)
            # Reset the link, give some time to accumulate any sync errors and then check VFAT comms
            sleep(0.1)
            gem_utils.gem_link_reset()
            sleep(0.1)

            gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.SBIT_ME0.TEST_SEL_VFAT_SBIT_ME0"), vfat) # Select VFAT for reading S-bits

            s_bit_channel_mapping[vfat] = {}
            # Looping over all 8 elinks
            for elink in range(0,8):
                gem_utils.write_backend_reg(elink_sbit_select_node, elink) # Select elink for S-bit counter
                s_bit_channel_mapping[vfat][elink] = {}
                s_bit_matches = {}

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
                        gem_utils.global_reset()
                        gem_utils.write_backend_reg(reset_sbit_counter_node, 1)

                        gem_utils.write_backend_reg(channel_sbit_select_node, sbit) # Select S-bit for S-bit counter
                        s_bit_matches[sbit] = 0

                        # Start the cyclic generator
                        gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_START"), 1)
                        cyclic_running = gem_utils.read_backend_reg(cyclic_running_node)
                        while cyclic_running:
                            cyclic_running = gem_utils.read_backend_reg(cyclic_running_node)

                        # Stop the cyclic generator
                        gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.RESET"), 1)

                        elink_sbit_counter_final = gem_utils.read_backend_reg(elink_sbit_counter_node)
                        l1a_counter = gem_utils.read_backend_reg(l1a_node)
                        calpulse_counter = gem_utils.read_backend_reg(calpulse_node)

                        if elink_sbit_counter_final == 0:
                            # Elink did not register a hit
                            s_bit_channel_mapping[vfat][elink][channel] = -9999
                            break
                        channel_sbit_counter_final[sbit] = gem_utils.read_backend_reg(channel_sbit_counter_node)

                        if channel_sbit_counter_final[sbit] > 0:
                            if sbit_channel_match == 1:
                                # Multiple S-bits registered hits for calpulse on this channel
                                s_bit_channel_mapping[vfat][elink][channel] = -9999
                                break
                            if s_bit_matches[sbit] >= 2:
                                # S-bit already matched to 2 channels
                                s_bit_channel_mapping[vfat][elink][channel] = -9999
                                break
                            if s_bit_matches[sbit] == 1:
                                if s_bit_channel_mapping[vfat][elink][channel-1] != sbit:
                                    # S-bit matched to a different channel than the previous one
                                    s_bit_channel_mapping[vfat][elink][channel] = -9999
                                    break
                                if channel%2==0:
                                    # S-bit already matched to an earlier odd numbered channel"
                                    s_bit_channel_mapping[vfat][elink][channel] = -9999
                                    break
                            s_bit_channel_mapping[vfat][elink][channel] = sbit
                            sbit_channel_match = 1
                            s_bit_matches[sbit] += 1
                    # End of S-bit loop for this channel

                    if s_bit_channel_mapping[vfat][elink][channel] == -9999:
                        errs[vfat][elink][phase] += 1

                    # Disabling the pulsing channels
                    enableVfatchannel(vfat, oh_select, channel, 1, 0) # mask this channel and disable calpulsing
                # End of Channel loop

                if errs[vfat][elink][phase] == 0:
                    print (Colors.GREEN + "Results of VFAT %02d SBit ELINK %02d: nr. of channel errors=%d"%(vfat, elink, errs[vfat][elink][phase]) + Colors.ENDC)
                elif errs[vfat][elink][phase] < 16:
                    print (Colors.YELLOW + "Results of VFAT %02d SBit ELINK %02d: nr. of channel errors=%d"%(vfat, elink, errs[vfat][elink][phase]) + Colors.ENDC)
                else:
                    print (Colors.RED + "Results of VFAT %02d SBit ELINK %02d: nr. of channel errors=%d"%(vfat, elink, errs[vfat][elink][phase]) + Colors.ENDC)

            # End of Elink loop
            print ("")
        # End of VFAT loop
    # End of Phase loop
    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE"), 0)

    for vfat in vfat_list:
        # Unconfigure the pulsing VFAT
        print("Unconfiguring VFAT %02d" % (vfat))
        configureVfat(0, vfat, oh_select, 0)
        print ("")

    bestphase_vfat_elink = [[0 for elink in range(8)] for vfat in range(24)]
    for vfat in vfat_list:
        centers = 8*[0]
        widths  = 8*[0]
        for elink in range(0,8):
            centers[elink], widths[elink] = find_phase_center(errs[vfat][elink])

        print ("\nVFAT %02d :" %(vfat))
        for elink in range(0,8):
            sys.stdout.write("  ELINK %02d: " % (elink))
            for phase in range(0, 16):
                if (widths[elink]>0 and phase==centers[elink]):
                    char=Colors.GREEN + "+" + Colors.ENDC
                    bestphase_vfat_elink[vfat][elink] = phase
                elif (errs[vfat][elink][phase]):
                    char=Colors.RED + "-" + Colors.ENDC
                else:
                    char = Colors.YELLOW + "x" + Colors.ENDC

                sys.stdout.write("%s" % char)
                sys.stdout.flush()
            if widths[elink]<3:
                sys.stdout.write(Colors.RED + " (center=%d, width=%d) BAD\n" % (centers[elink], widths[elink]) + Colors.ENDC)
            elif widths[elink]<5:
                sys.stdout.write(Colors.YELLOW + " (center=%d, width=%d) WARNING\n" % (centers[elink], widths[elink]) + Colors.ENDC)
            else:
                sys.stdout.write(Colors.GREEN + " (center=%d, width=%d) GOOD\n" % (centers[elink], widths[elink]) + Colors.ENDC)
            sys.stdout.flush()

        # set phases for all elinks for this vfat
        print ("\nVFAT %02d: Setting all ELINK phases to best phases: "%(vfat))
        sbit_elinks = vfat_to_sbit_elink(vfat)
        for elink in range(0,8):
            set_bestphase = bestphase_vfat_elink[vfat][elink]
            setVfatSbitPhase(system, oh_select, vfat, sbit_elinks[elink], set_bestphase)
            print ("VFAT %02d: Phase set for ELINK %02d to: %s" % (vfat, elink, hex(set_bestphase)))
    for vfat in range(0,24):
        for elink in range(0,8):
            file_out.write("%d  %d  0x%x\n"%(vfat,elink,bestphase_vfat_elink[vfat][elink]))

    sleep(0.1)
    gem_utils.gem_link_reset()
    print ("")
    file_out.close()

    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM_AMC.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)
    print ("\nS-bit phase scan done\n")


def find_phase_center(err_list):
    # find the centers
    ngood        = 0
    ngood_max    = 0
    ngood_edge   = 0
    ngood_center = 0

    # duplicate the err_list to handle the wraparound
    err_list_doubled = err_list + err_list
    phase_max = len(err_list)-1

    for phase in range(0,len(err_list_doubled)):
        if (err_list_doubled[phase] == 0):
            ngood+=1
        else: # hit an edge
            if (ngood > 0 and ngood >= ngood_max):
                ngood_max  = ngood
                ngood_edge = phase
            ngood=0

    # cover the case when there are no edges, just pick the center
    if (ngood==len(err_list_doubled)):
        ngood_max  = int(ngood/2)
        ngood_edge = len(err_list_doubled)-1

    if (ngood_max>0):
        ngood_width = ngood_max
        # even windows
        if (ngood_max % 2 == 0):
            ngood_center = ngood_edge - int(ngood_max/2) -1
            if (err_list_doubled[ngood_edge] > err_list_doubled[ngood_edge-ngood_max-1]):
                ngood_center = ngood_center
            else:
                ngood_center = ngood_center+1
        # oddwindows
        else:
            ngood_center = ngood_edge - int(ngood_max/2) -1;

    ngood_center = ngood_center % phase_max - 1

    if (ngood_max==0):
        ngood_center=0

    return ngood_center, ngood_max


def setVfatSbitPhase(system, oh_select, vfat, sbit_elink, phase):
    gbt, gbt_select, rx_elink, gpio = gem_utils.vfat_to_gbt_elink_gpio(vfat)

    if lpgbt == "boss":
        config = config_boss
    elif lpgbt == "sub":
        config = config_sub

    # set phase
    GBT_ELINK_SAMPLE_PHASE_BASE_REG = 0x0CC
    addr = GBT_ELINK_SAMPLE_PHASE_BASE_REG + sbit_elink
    value = (config[addr] & 0x0f) | (phase << 4)

    gem_utils.check_gbt_link_ready(oh_select, gbt_select)
    select_ic_link(oh_select, gbt_select)
    if system!= "dryrun" and system!= "backend":
        check_rom_readback()
    mpoke(addr, value)
    sleep(0.000001) # writing too fast for CVP13

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 VFAT S-Bit Phase Scan")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    arser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0")
    #parser.add_argument("-l", "--lpgbt", action="store", dest="lpgbt", help="lpgbt = boss or sub")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number (only needed for backend)")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number (only needed for backend)")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
    parser.add_argument("-b", "--bestphase", action="store", dest="bestphase", help="bestphase = Best value of the elinkRX phase (in hex), calculated from phase scan by default")
    parser.add_argument("-f", "--bestphase_file", action="store", dest="bestphase_file", help="bestphase_file = Text file with best value of the elinkRX phase for each VFAT and ELINK (in hex), calculated from phase scan by default")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for S-bit test")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running sbit phase scan")
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

    if args.bestphase is not None and args.bestphase_file is not None:
        print (Colors.YELLOW + "Provide either best phase (same for all VFATs) or text file of best phases for each VFAT" + Colors.ENDC)
        sys.exit()
    bestphase_list = {}
    if args.bestphase is not None:
        if "0x" not in args.bestphase:
            print (Colors.YELLOW + "Enter best phase in hex format" + Colors.ENDC)
            sys.exit()
        if int(args.bestphase, 16)>16:
            print (Colors.YELLOW + "Phase can only be 4 bits" + Colors.ENDC)
            sys.exit()
        for vfat in range(0,24):
            for elink in range(0,8):
                bestphase_list[vfat][elink] = int(args.bestphase,16)
    if args.bestphase_file is not None:
        file_in = open(args.bestphase_file)
        for line in file_in.readlines():
            if "vfat" in line:
                continue
            vfat = int(line.split()[0])
            elink = int(line.split()[1])
            phase = int(line.split()[2],16)
            if vfat not in bestphase_list:
                bestphase_list[vfat] = {}
            bestphase_list[vfat][elink] = phase
        file_in.close()

    if args.use_channel_trimming is not None:
        if args.use_channel_trimming not in ["daq", "sbit"]:
            print (Colors.YELLOW + "Only allowed options for use_channel_trimming: daq or sbit" + Colors.ENDC)
            sys.exit()

    nl1a = 100 # Nr. of L1As
    l1a_bxgap = 100 # Gap between 2 L1As in nr. of BXs
    set_cal_mode = "current"
    cal_dac = 150 # should be 50 for voltage pulse mode

    # Initialization 
    initialize(args.gem, args.system)
    initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")

    if not os.path.isfile(config_boss_filename):
        print (Colors.YELLOW + "Missing config file for boss: config_boss.txt" + Colors.ENDC)
        sys.exit()

    if not os.path.isfile(config_sub_filename):
        print (Colors.YELLOW + "Missing config file for sub: sub_boss.txt" + Colors.ENDC)
        sys.exit()

    config_boss = getConfig(config_boss_filename)
    config_sub  = getConfig(config_sub_filename)

    # Running Phase Scan
    try:
        vfat_sbit(args.gem, args.system, int(args.ohid), vfat_list, nl1a, l1a_bxgap, set_cal_mode, cal_dac, bestphase_list)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




