from gem.me0_lpgbt.rw_reg_lpgbt import *
import gem.gem_utils as gem_utils
from time import sleep, time
import sys
import argparse
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel
from common.utils import get_befe_scripts_dir
import datetime

config_boss_filename_v1 = ""
config_sub_filename_v1 = ""
config_boss_v1 = {}
config_sub_v1 = {}
config_boss_filename_v2 = ""
config_sub_filename_v2 = ""
config_boss_v2 = {}
config_sub_v2 = {}

def getConfig (filename):
    f = open(filename, "r")
    reg_map = {}
    for line in f.readlines():
        reg = int(line.split()[0], 16)
        data = int(line.split()[1], 16)
        reg_map[reg] = data
    f.close()
    return reg_map

def phase_check(system, oh_select, vfat, sc_depth, crc_depth, phase, working_phases_sc, daq_err, cyclic_running_node):

    #print("  Scanning phase %d" % phase)

    # set phase
    setVfatRxPhase(system, oh_select, vfat, phase)

    gbt, gbt_select, elink, gpio = gem_utils.me0_vfat_to_gbt_elink_gpio(vfat)
    oh_ver = get_oh_ver(oh_select, gbt_select)
    # Reset the link, give some time to accumulate any sync errors and then check VFAT comms  
    sleep(0.1)
    gem_utils.gem_link_reset()
    sleep(0.1)

    # Check Link Good and Sync Errors
    link_state = 0
    sync_error = 0
    link_node = gem_utils.get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat))
    sync_node = gem_utils.get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat))
    link_state = gem_utils.read_backend_reg(link_node, False)
    if link_state == 0xdeaddead:
        link_state = 0
    sync_error = gem_utils.read_backend_reg(sync_node, False)
    if sync_error == 0xdeaddead:
        sync_error = 9999

    # Check Slow Control
    cfg_run_error = 0
    cfg_node = gem_utils.get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN" % (oh_select, vfat))
    for iread in range(sc_depth):
        vfat_cfg_run = gem_utils.read_backend_reg(cfg_node, False)
        if vfat_cfg_run == 0xdeaddead:
            vfat_cfg_run = 9999
        if vfat_cfg_run != 0 and vfat_cfg_run != 1:
            cfg_run_error = 1
            break
        #cfg_run[vfat][phase] += (vfat_cfg_run != 0 and vfat_cfg_run != 1)

    # Check DAQ event counter and CRC errors with L1A if link and slow control good
    daq_error = -1
    if daq_err:
        if system == "dryrun" or (link_state==1 and sync_error==0 and cfg_run_error==0):
            for vfat2 in vfat_list:
                if vfat2 != vfat:
                    setVfatRxPhase(system, oh_select, vfat2, working_phases_sc[vfat2], False)
            sleep(0.1)
            gem_utils.gem_link_reset()
            sleep(0.1)
            for vfat2 in vfat_list:
                gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN" % (oh_select, vfat2)), 1)
            #configureVfat(1, vfat, oh_select, 1) # configure VFAT with low threshold
            #for i in range(128):
            #   enableVfatchannel(vfat, oh_select, i, 0, 0) # unmask all channels and disable calpulsing

            # Send L1A to get DAQ events from VFATs
            #gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)
            gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.TTC.CTRL.MODULE_RESET"), 1)
            gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_COUNT"), crc_depth)
            sleep(0.001)
            gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START"), 1)
            sleep(0.001)
            cyclic_running = 1
            while cyclic_running:
                cyclic_running = gem_utils.read_backend_reg(cyclic_running_node)
            sleep(0.001)
            gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
            sleep(0.001)

            l1a_counter = gem_utils.read_backend_reg(gem_utils.get_backend_node("BEFE.GEM.TTC.CMD_COUNTERS.L1A"))
            nl1a_reg_cycles = int(crc_depth/(2**32))
            real_l1a_counter = nl1a_reg_cycles*(2**32) + l1a_counter
            daq_event_counter = gem_utils.read_backend_reg(gem_utils.get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.DAQ_EVENT_CNT" % (oh_select, vfat)))
            if system == "dryrun":
                daq_error = gem_utils.read_backend_reg(gem_utils.get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.DAQ_CRC_ERROR_CNT" % (oh_select, vfat)))
            else:
                if daq_event_counter != real_l1a_counter%(2**16):
                    print (Colors.YELLOW + "\tProblem with DAQ event counter=%d, L1A counter=%d (%d)"%(daq_event_counter, real_l1a_counter, real_l1a_counter%(2**16)) + Colors.ENDC)
                daq_error = gem_utils.read_backend_reg(gem_utils.get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.DAQ_CRC_ERROR_CNT" % (oh_select, vfat)))
            gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
       
            for vfat2 in vfat_list:
                gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN" % (oh_select, vfat2)), 0)
            for vfat2 in vfat_list:
                if vfat2 != vfat:
                    setVfatRxPhase(system, oh_select, vfat2, phase, False)
            sleep(0.1)
            gem_utils.gem_link_reset()
            sleep(0.1) 
            #configureVfat(0, vfat, oh_select, 0) # unconfigure VFAT
            #gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1) 
    else:
        daq_error=0

    result_str = ""
    if link_state==1 and sync_error==0 and cfg_run_error==0 and daq_error==0:
        result_str += Colors.GREEN
    else:
        result_str += Colors.RED
    if daq_err:
        result_str += "\tResults for phase %d: link_good=%d, sync_err_cnt=%d, slow_control_bad=%d, daq_crc_errors=%d" % (phase, link_state, sync_error, cfg_run_error, daq_error)
    else:
        result_str += "\tResults for phase %d: link_good=%d, sync_err_cnt=%d, slow_control_bad=%d" % (phase, link_state, sync_error, cfg_run_error)
    result_str += Colors.ENDC
    print(result_str)

    return link_state, sync_error, cfg_run_error, daq_error

def gbt_phase_scan(gem, system, oh_select, daq_err, vfat_list, sc_depth, crc_depth, fixed_crc, l1a_bxgap, bestphase_list):
    print ("ME0 Phase Scan")

    if bestphase_list!={}:
        print ("Setting phases for VFATs only, not scanning")
        for vfat in vfat_list:
            set_bestphase = bestphase_list[vfat]
            setVfatRxPhase(system, oh_select, vfat, set_bestphase)
            print ("Phase set for VFAT#%02d to: %s" % (vfat, hex(set_bestphase)))
        return
    scripts_gem_dir = get_befe_scripts_dir() + '/gem'
    resultDir = scripts_gem_dir + "/results"
    vfatDir = resultDir + "/vfat_data"
    try:
        os.makedirs(vfatDir) # create directory for VFAT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = vfatDir + "/vfat_phase_scan_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/%s_OH%d_vfat_phase_scan_results_"%(gem,oh_select) + now + ".txt"
    file_out = open(filename, "w")
    filename_data = dataDir + "/%s_OH%d_vfat_phase_scan_data_"%(gem,oh_select) + now + ".txt"
    file_out_data = open(filename_data, "w")
    file_out.write("vfat  phase\n")

    link_good    = [[0 for phase in range(15)] for vfat in range(24)]
    sync_err_cnt = [[0 for phase in range(15)] for vfat in range(24)]
    cfg_run      = [[0 for phase in range(15)] for vfat in range(24)]
    daq_crc_error      = [[0 for phase in range(15)] for vfat in range(24)]
    errs         = [[0 for phase in range(15)] for vfat in range(24)]

    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)

    # Setting phases of all VFATs first to 0
    for vfat in vfat_list:
        gbt, gbt_select, elink, gpio = gem_utils.me0_vfat_to_gbt_elink_gpio(vfat)
        oh_ver = get_oh_ver(oh_select, gbt_select)
        gem_utils.check_gbt_link_ready(oh_select, gbt_select)
        setVfatRxPhase(system, oh_select, vfat, 0, False)
    print ("")

    working_phases_sc = {}
    for vfat in vfat_list:
        gbt, gbt_select, elink, gpio = gem_utils.me0_vfat_to_gbt_elink_gpio(vfat)
        oh_ver = get_oh_ver(oh_select, gbt_select)
        gem_utils.check_gbt_link_ready(oh_select, gbt_select)

        print("Configuring VFAT %d" % (vfat))
        hwid_node = gem_utils.get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.HW_ID" % (oh_select, vfat))
        vfat_configured = 0
        for ph in range(0,15):
            setVfatRxPhase(system, oh_select, vfat, ph, False)
            sleep(0.1)
            gem_utils.gem_link_reset()
            sleep(0.1)
            output = gem_utils.read_backend_reg(hwid_node, False)
            if output == 0xdeaddead:
                continue
            else:
                working_phases_sc[vfat] = ph
                configureVfat(1, vfat, oh_select, 1) # configure VFAT with low threshold 
                for i in range(128):
                    enableVfatchannel(vfat, oh_select, i, 0, 0) # unmask all channels and disable calpulsing
                gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN" % (oh_select, vfat)), 0)
                vfat_configured = 1
                setVfatRxPhase(system, oh_select, vfat, 0, False)
                sleep(0.1)
                gem_utils.gem_link_reset()
                sleep(0.1)
                break
        if vfat_configured == 0:
            print (Colors.RED + "Cannot configure VFAT %d"%(vfat) + Colors.ENDC)
            rw_terminate()
    print ("\n")

    # Configure TTC Generator
    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 1)
    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_GAP"), l1a_bxgap) 
    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 0) # Disable Calpulse 
    cyclic_running_node = gem_utils.get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_RUNNING")

    for vfat in vfat_list:
        print ("Phase Scan for VFAT: %02d"%vfat)
        print ("Checking that phase 15 does not work to make sure we can set phases:")
        link_good_15, sync_err_cnt_15, cfg_run_15, daq_crc_error_15 = phase_check(system, oh_select, vfat, sc_depth, crc_depth, 15, working_phases_sc, daq_err, cyclic_running_node)
        phase_15_error = (not link_good_15==1) + (not sync_err_cnt_15==0) + (not cfg_run_15==0) + (not daq_crc_error_15==0)
        if phase_15_error == 0:
            print (Colors.RED + "\nPhase not being set correctly for VFAT %02d"%vfat + Colors.ENDC)
            rw_terminate()
        print ("")
        for phase in range(0, 15):
            link_good[vfat][phase], sync_err_cnt[vfat][phase], cfg_run[vfat][phase], daq_crc_error[vfat][phase] = phase_check(system, oh_select, vfat, sc_depth, crc_depth, phase, working_phases_sc, daq_err, cyclic_running_node)
      
        n_errors = 0
        for phase in range(0, 15):
            n_errors += (not link_good[vfat][phase]==1) + (not sync_err_cnt[vfat][phase]==0) + (not cfg_run[vfat][phase]==0) + (not daq_crc_error[vfat][phase]==0)
        if n_errors == 0 and not fixed_crc:
            print ("\nNo bad phase detected, redoing the phase scan with higher statistics:")
            for phase in range(0, 15):
                link_good[vfat][phase], sync_err_cnt[vfat][phase], cfg_run[vfat][phase], daq_crc_error[vfat][phase] = phase_check(system, oh_select, vfat, sc_depth, crc_depth*100, phase, working_phases_sc, daq_err, cyclic_running_node)

        n_errors = 0
        for phase in range(0, 15):
            n_errors += (not link_good[vfat][phase]==1) + (not sync_err_cnt[vfat][phase]==0) + (not cfg_run[vfat][phase]==0) + (not daq_crc_error[vfat][phase]==0)
        if n_errors == 0 and not fixed_crc:
            print ("\nNo bad phase detected again, redoing the phase scan with even higher statistics:")
            for phase in range(0, 15):
                link_good[vfat][phase], sync_err_cnt[vfat][phase], cfg_run[vfat][phase], daq_crc_error[vfat][phase] = phase_check(system, oh_select, vfat, sc_depth, crc_depth*10000, phase, working_phases_sc, daq_err, cyclic_running_node)

        print("")

    gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 0)
    centers = 24*[0]
    widths  = 24*[0]

    #gem_utils.write_backend_reg(gem_utils.get_backend_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)

    for vfat in vfat_list:
        for phase in range(0, 15):
            errs[vfat][phase] = (not link_good[vfat][phase]==1) + (not sync_err_cnt[vfat][phase]==0) + (not cfg_run[vfat][phase]==0) + (not daq_crc_error[vfat][phase]==0)
        centers[vfat], widths[vfat] = find_phase_center(errs[vfat])

    print ("\nPhase Scan Results:")
    file_out_data.write("\nPhase Scan Results:\n")
    bestphase_vfat = 24*[0]
    for vfat in vfat_list:
        phase_print = "VFAT%02d: " % (vfat)
        for phase in range(0, 15):

            if (widths[vfat]>0 and phase==centers[vfat]):
                char=Colors.GREEN + "+" + Colors.ENDC
                bestphase_vfat[vfat] = phase
            elif (errs[vfat][phase]):
                char=Colors.RED + "-" + Colors.ENDC
            else:
                char = Colors.YELLOW + "x" + Colors.ENDC

            phase_print += "%s" % char
        if widths[vfat]<3:
            phase_print += Colors.RED + " (center=%d, width=%d) BAD" % (centers[vfat], widths[vfat]) + Colors.ENDC
        elif widths[vfat]<5:
            phase_print += Colors.YELLOW + " (center=%d, width=%d) WARNING" % (centers[vfat], widths[vfat]) + Colors.ENDC
        else:
            phase_print += Colors.GREEN + " (center=%d, width=%d) GOOD" % (centers[vfat], widths[vfat]) + Colors.ENDC
        print(phase_print)
        file_out_data.write(phase_print + "\n")

    # set phases for all vfats under test
    print ("\nSetting all VFAT phases to best phases: ")
    for vfat in vfat_list:
        set_bestphase = bestphase_vfat[vfat]
        setVfatRxPhase(system, oh_select, vfat, set_bestphase)
        print ("Phase set for VFAT#%02d to: %s" % (vfat, hex(set_bestphase)))
    for vfat in range(0,24):
        file_out.write("%d  0x%x\n"%(vfat,bestphase_vfat[vfat]))

    sleep(0.1)
    gem_utils.gem_link_reset()
    print ("")
    file_out.close()
    file_out_data.close()

    # Unconfigure VFATs
    for vfat in vfat_list:
        print("Unconfiguring VFAT %d" % (vfat))
        configureVfat(0, vfat, oh_select, 0)

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

def find_phase_center_wrap(err_list):
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
        # odd windows
        else:
            ngood_center = ngood_edge - int(ngood_max/2) - 1;

    n_bad_phases = 0
    bad_phase_loc = 0
    for phase in range(0,len(err_list)-1):
        if err_list[phase] != 0:
            n_bad_phases += 1
            bad_phase_loc = phase
    if n_bad_phases == 1:
        if bad_phase_loc <= 7:
            ngood_center = bad_phase_loc + 4
        else:
            ngood_center = bad_phase_loc - 4

    if ngood_center > phase_max:
        ngood_center = ngood_center % phase_max - 1

    if (ngood_max==0):
        ngood_center=0

    return ngood_center, ngood_max

def setVfatRxPhase(system, oh_select, vfat, phase, verbose=True):

    if verbose:
        print ("Setting RX phase %s for VFAT%d" %(hex(phase), vfat))
    gbt, gbt_select, elink, gpio = gem_utils.me0_vfat_to_gbt_elink_gpio(vfat)
    oh_ver = get_oh_ver(oh_select, gbt_select)
    select_ic_link(oh_select, gbt_select)

    if gbt == "boss":
        if oh_ver == 1:
            config = config_boss_v1
        elif oh_ver == 2:
            config = config_boss_v2
    elif gbt == "sub":
        if oh_ver == 1:
            config = config_sub_v1
        elif oh_ver == 2:
            config = config_sub_v2
    
    # set phase
    GBT_ELINK_SAMPLE_PHASE_BASE_REG = -9999
    if oh_ver == 1:
        GBT_ELINK_SAMPLE_PHASE_BASE_REG = 0x0CC
    elif oh_ver == 2:
        GBT_ELINK_SAMPLE_PHASE_BASE_REG = 0x0D0
    addr = GBT_ELINK_SAMPLE_PHASE_BASE_REG + elink
    value = (config[addr] & 0x0f) | (phase << 4)
    #value = (mpeek(addr) & 0x0f) | (phase << 4)
    mpoke(addr, value)
    #lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX%dPHASESELECT"%elink), phase)

    sleep(0.000001) # writing too fast for CVP13
    
def test_find_phase_center():
    def check_finder(center, width, errs):
        if (center,width) == find_phase_center(errs):
            print ("OK")
        else:
            print ("FAIL")
    check_finder (5, 5,  [1,1,1,0,0,0,0,0,1,1,0,0,1,1,1,1]) # normal window
    check_finder (3, 4,  [1,0,0,0,0,1,1,1,1,1,0,0,0,1,1,1]) # symmetric goes to higher number (arbitrary)
    check_finder (0, 5,  [0,0,0,1,1,1,1,0,0,0,0,1,1,1,0,0]) # wraparound
    check_finder (3, 4,  [2,0,0,0,0,1,1,1,0,0,0,1,1,1,1,1]) # offset right
    check_finder (2, 4,  [1,0,0,0,0,2,1,1,0,0,0,1,1,1,1,1]) # offset left
    check_finder (0, 0,  [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]) # all bad (default to zero)
    check_finder (7, 16, [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]) # all good, pick the center (arbitrary)

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 Phase Scan")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-c", "--daq_err", action="store_true", dest="daq_err", help="if you want to check for DAQ CRC errors")
    parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
    parser.add_argument("-sd", "--sc_depth", action="store", dest="sc_depth", default="10000", help="sc_depth = number of times to check for slow control errors")
    parser.add_argument("-cd", "--crc_depth", action="store", dest="crc_depth", default="10000", help="crc_depth = number of times to check for crc errors")
    parser.add_argument("-x", "--fixed_crc", action="store_true", dest="fixed_crc", help="fixed_crc = only test for the starting number of CRC errors")
    parser.add_argument("-b", "--bxgap", action="store", dest="bxgap", default="40", help="bxgap = Nr. of BX between two L1As (default = 40 i.e. 1 us)")
    parser.add_argument("-p", "--bestphase", action="store", dest="bestphase", help="bestphase = Best value of the elinkRX phase (in hex), calculated from phase scan by default")
    parser.add_argument("-f", "--bestphase_file", action="store", dest="bestphase_file", help="bestphase_file = Text file with best value of the elinkRX phase for each VFAT (in hex), calculated from phase scan by default")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for Phase Scan")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running phase scan")
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
            bestphase_list[vfat] = int(args.bestphase,16)
    if args.bestphase_file is not None:
        file_in = open(args.bestphase_file)
        for line in file_in.readlines():
            if "vfat" in line:
                continue
            vfat = int(line.split()[0])
            phase = int(line.split()[1],16)
            bestphase_list[vfat] = phase
        file_in.close()

    if args.use_channel_trimming is not None:
        if args.use_channel_trimming not in ["daq", "sbit"]:
            print (Colors.YELLOW + "Only allowed options for use_channel_trimming: daq or sbit" + Colors.ENDC)
            sys.exit()

    l1a_bxgap = int(args.bxgap)
    l1a_timegap = l1a_bxgap * 25 * 0.001 # in microseconds
    if l1a_bxgap<25:
        print (Colors.YELLOW + "Gap between L1As should be at least 25 BX to read out enitre DAQ data packets" + Colors.ENDC)
        sys.exit()

    # Initialization 
    rw_initialize(args.gem, args.system)
    initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")

    config_boss_filename_v1 = "../resources/me0_boss_config_ohv1.txt"
    config_sub_filename_v1 = "../resources/me0_sub_config_ohv1.txt"
    config_boss_filename_v2 = "../resources/me0_boss_config_ohv2.txt"
    config_sub_filename_v2 = "../resources/me0_sub_config_ohv2.txt"
    
    if not os.path.isfile(config_boss_filename_v1):
        print (Colors.YELLOW + "Missing config file for boss for OH-v1" + Colors.ENDC)
        sys.exit()
    if not os.path.isfile(config_sub_filename_v1):
        print (Colors.YELLOW + "Missing config file for sub for OH-v1" + Colors.ENDC)
        sys.exit()
    if not os.path.isfile(config_boss_filename_v2):
        print (Colors.YELLOW + "Missing config file for boss for OH-v2" + Colors.ENDC)
        sys.exit()
    if not os.path.isfile(config_sub_filename_v2):
        print (Colors.YELLOW + "Missing config file for sub for OH-v2" + Colors.ENDC)
        sys.exit()
    
    config_boss_v1 = getConfig(config_boss_filename_v1)
    config_sub_v1  = getConfig(config_sub_filename_v1)
    config_boss_v2 = getConfig(config_boss_filename_v2)
    config_sub_v2  = getConfig(config_sub_filename_v2)
    
    # Running Phase Scan
    try:
        gbt_phase_scan(args.gem, args.system, int(args.ohid), args.daq_err, vfat_list, int(args.sc_depth), int(args.crc_depth), args.fixed_crc, l1a_bxgap, bestphase_list)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()




