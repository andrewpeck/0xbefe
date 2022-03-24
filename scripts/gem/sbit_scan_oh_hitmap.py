#!/usr/bin/env python

from common.rw_reg import *
from common.utils import *
import gem.gem_utils as gem
from time import *
import array
import struct
import sys

SCAN_RANGE = 18
N_SBIT = 8

class VFAT_SBIT:
    def __init__(self,vfat,center,best_dly,width):
        if len(center) != N_SBIT or len(best_dly) != N_SBIT or len(width) != N_SBIT:
            pritn("ERROR Entries DO NOT match number of S-bits!")
        else:
            self.VFAT = vfat
            self.SBIT_CENTER = center
            self.SBIT_BEST_DLY = best_dly
            self.SBIT_WIDTH = width

def configureVfatForPulsing(vfatN, ohN):

        write_reg(get_node("BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET"), 1)

        sleep (0.1)

        write_reg(get_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)
        #print "\tLink good: "
        #print "\t\t" + read_reg(get_node("BEFE.GEM.OH_LINKS.OH%i.VFAT%i.LINK_GOOD"%(ohN,vfatN)))
        #print "\tSync Error: "
        #print "\t\t" + read_reg(get_node("BEFE.GEM.OH_LINKS.OH%i.VFAT%i.SYNC_ERR_CNT"%(ohN,vfatN)))

        if (read_reg(get_node("BEFE.GEM.OH_LINKS.OH%i.VFAT%i.SYNC_ERR_CNT"%(ohN,vfatN))) > 0):
            print ("\tLink errors.. exiting")
            sys.exit()


           #Configure TTC generator on CTP7
        write_reg(get_node("BEFE.GEM.TTC.GENERATOR.RESET"),  1)
        write_reg(get_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 1)
        write_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 50)
        write_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_GAP"),  500)
        write_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_COUNT"),  0)

        write_reg(get_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.OH_SELECT"), ohN)

        write_reg(get_node("BEFE.GEM.OH.OH%i.FPGA.TRIG.CTRL.VFAT_MASK" % ohN), 0xffffff ^ (1 << (vfatN)))

        write_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START"), 1)

        for i in range(128):
            write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.VFAT_CHANNELS.CHANNEL%i"%(ohN,vfatN,i)), 0x4000)  # mask all channels and disable the calpulse

        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_PULSE_STRETCH"       % (ohN , vfatN)) , 7)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SYNC_LEVEL_MODE"     % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SELF_TRIGGER_MODE"   % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_DDR_TRIGGER_MODE"    % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SPZS_SUMMARY_ONLY"   % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SPZS_MAX_PARTITIONS" % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SPZS_ENABLE"         % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SZP_ENABLE"          % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SZD_ENABLE"          % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_TIME_TAG"            % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_EC_BYTES"            % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BC_BYTES"            % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_FP_FE"               % (ohN , vfatN)) , 7)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_RES_PRE"             % (ohN , vfatN)) , 1)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAP_PRE"             % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_PT"                  % (ohN , vfatN)) , 15)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_EN_HYST"             % (ohN , vfatN)) , 1)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SEL_POL"             % (ohN , vfatN)) , 1)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_FORCE_EN_ZCC"        % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_FORCE_TH"            % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SEL_COMP_MODE"       % (ohN , vfatN)) , 1)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_VREF_ADC"            % (ohN , vfatN)) , 3)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_MON_GAIN"            % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_MONITOR_SELECT"      % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_IREF"                % (ohN , vfatN)) , 32)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_THR_ZCC_DAC"         % (ohN , vfatN)) , 10)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_THR_ARM_DAC"         % (ohN , vfatN)) , 100)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_HYST"                % (ohN , vfatN)) , 5)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_LATENCY"             % (ohN , vfatN)) , 45)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_SEL_POL"         % (ohN , vfatN)) , 1)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_PHI"             % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_EXT"             % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DAC"             % (ohN , vfatN)) , 50)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"            % (ohN , vfatN)) , 1)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_FS"              % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"             % (ohN , vfatN)) , 200)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_CFD_DAC_2"      % (ohN , vfatN)) , 40)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_CFD_DAC_1"      % (ohN , vfatN)) , 40)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BSF"      % (ohN , vfatN)) , 13)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BIT"      % (ohN , vfatN)) , 150)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BLCC"     % (ohN , vfatN)) , 25)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_VREF"       % (ohN , vfatN)) , 86)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BFCAS"     % (ohN , vfatN)) , 250)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BDIFF"     % (ohN , vfatN)) , 150)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BFAMP"     % (ohN , vfatN)) , 0)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BDIFF"     % (ohN , vfatN)) , 255)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BSF"       % (ohN , vfatN)) , 15)
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BFCAS"     % (ohN , vfatN)) , 255)

        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_PULSE_STRETCH"       % (ohN , vfatN)) , 3)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SYNC_LEVEL_MODE"     % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SELF_TRIGGER_MODE"   % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_DDR_TRIGGER_MODE"    % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SPZS_SUMMARY_ONLY"   % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SPZS_MAX_PARTITIONS" % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SPZS_ENABLE"         % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SZP_ENABLE"          % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SZD_ENABLE"          % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_TIME_TAG"            % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_EC_BYTES"            % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BC_BYTES"            % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_FP_FE"               % (ohN , vfatN)) , 7)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_RES_PRE"             % (ohN , vfatN)) , 2)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAP_PRE"             % (ohN , vfatN)) , 1)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_PT"                  % (ohN , vfatN)) , 15)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_EN_HYST"             % (ohN , vfatN)) , 1)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SEL_POL"             % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_FORCE_EN_ZCC"        % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_FORCE_TH"            % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SEL_COMP_MODE"       % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_VREF_ADC"            % (ohN , vfatN)) , 3)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_MON_GAIN"            % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_MONITOR_SELECT"      % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_IREF"                % (ohN , vfatN)) , 32)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_THR_ZCC_DAC"         % (ohN , vfatN)) , 10)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_THR_ARM_DAC"         % (ohN , vfatN)) , 100)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_HYST"                % (ohN , vfatN)) , 5)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_LATENCY"             % (ohN , vfatN)) , 57)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_SEL_POL"         % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_PHI"             % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_EXT"             % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DAC"             % (ohN , vfatN)) , 50) # voltage pulse
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"            % (ohN , vfatN)) , 1) # voltage pulse
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DAC"             % (ohN , vfatN)) , 250) # current pulse
        # write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"            % (ohN , vfatN)) , 2) # current pulse
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_FS"              % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"             % (ohN , vfatN)) , 200)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_CFD_DAC_2"      % (ohN , vfatN)) , 40)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_CFD_DAC_1"      % (ohN , vfatN)) , 40)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BSF"      % (ohN , vfatN)) , 13)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BIT"      % (ohN , vfatN)) , 150)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BLCC"     % (ohN , vfatN)) , 25)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_VREF"       % (ohN , vfatN)) , 86)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BFCAS"     % (ohN , vfatN)) , 130)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BDIFF"     % (ohN , vfatN)) , 80)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BFAMP"     % (ohN , vfatN)) , 1)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BDIFF"     % (ohN , vfatN)) , 140)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BSF"       % (ohN , vfatN)) , 15)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BFCAS"     % (ohN , vfatN)) , 135)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_RUN"%(ohN,vfatN)), 1)
        write_reg(get_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)

def main():

    ohN = 0
    vfatN = 0

    if len(sys.argv) < 3:
        print('Usage: sbit_timing_scan.py <oh_num> <vfat_num_min> <vfat_num_max>')
        return
    if len(sys.argv) == 4:
        ohN      = int(sys.argv[1])
        vfatNMin = int(sys.argv[2])
        vfatNMax = int(sys.argv[3])
    else:
        ohN      = int(sys.argv[1])
        vfatNMin = int(sys.argv[2])
        vfatNMax = vfatNMin

    if ohN > 11:
        print_red("The given OH index (%d) is out of range (must be 0-11)" % ohN)
        return
    if vfatNMin > 23:
        print_red("The given VFAT index (%d) is out of range (must be 0-23)" % vfatN)
        return
    if vfatNMax > 23:
        print_red("The given VFAT index (%d) is out of range (must be 0-23)" % vfatN)
        return

    verbose = False
    if (vfatNMin == vfatNMax):
        verbose = True

    parse_xml()
    sbit_phase_scan(ohN, vfatNMin, vfatNMax, verbose, True)

# if print_result is set to False, all prints are suppressed
def sbit_phase_scan(ohN, vfatNMin = 0, vfatNMax=11, verbose=False, print_result=True):

    VFAT_SBITS_out = []

    addrSbitMonReset = get_node('BEFE.GEM.OH.OH%d.FPGA.TRIG.SBIT_MONITOR.RESET' % ohN)
    write_reg(get_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.OH_SELECT"), ohN)

    ##################
    # hard reset
    ##################

    for vfatN in range (vfatNMin, vfatNMax+1):

        if print_result:
            print("")
            print("####################################################################################################")
            print("Scanning VFAT %i" % vfatN)
            print("####################################################################################################")
            print("")

        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.MODULE_RESET'), 0x1)
        gem.gem_hard_reset()
        sleep(0.3)
        gem.gem_link_reset()
        sleep(0.1)

        ##################
        #
        ##################

        addrCluster = [0]*8
        for i in range(8):
            addrCluster[i] = get_node('BEFE.GEM.OH.OH%d.FPGA.TRIG.SBIT_MONITOR.CLUSTER%i' % (ohN, i))

        configureVfatForPulsing(vfatN, ohN)

        err_matrix = [[0 for i in range(0,2*SCAN_RANGE+1)] for j in range(8)]

        write_reg(get_node("BEFE.GEM.OH.OH%i.FPGA.TRIG.CTRL.ALIGNED_COUNT_TO_READY" % ohN), 0xfff)

        sot_reg          = get_node('BEFE.GEM.OH.OH%d.FPGA.TRIG.TIMING.SOT_TAP_DELAY_VFAT%s' % (ohN, vfatN))
        sot_dly_original = read_reg(sot_reg)

        for sot_dly in range(2):

            dly_offset = 0
            if(sot_dly == 0):
                dly_offset = SCAN_RANGE
            else:
                dly_offset = 0

            write_reg(sot_reg, dly_offset)
            sleep(0.0001) # otherwise too fast on CVP13 :)
            sot_rdy = read_reg(get_node("BEFE.GEM.OH.OH%i.FPGA.TRIG.CTRL.SBIT_SOT_READY" % ohN))
            sleep(0.1)
            if (not (sot_rdy >> vfatN)&0x1):
                print("Sot not ready... cannot scan")
                sys.exit()

            for ibit in range(8):

                #   Set the SoT delay to 0 (min)
                tap_dly_reg      = get_node('BEFE.GEM.OH.OH%d.FPGA.TRIG.TIMING.TAP_DELAY_VFAT%i_BIT%i' % (ohN, vfatN, ibit))
                tap_dly_original = read_reg(tap_dly_reg)

#                sbit_monitor_cluster_reg = get_node('BEFE.GEM.OH.OH%d.FPGA.TRIG.SBIT_MONITOR.CLUSTER0' % (ohN))
#                sbit_monitor_reset_reg   = get_node('BEFE.GEM.OH.OH%d.FPGA.TRIG.SBIT_MONITOR.RESET' % (ohN))

                sbit_hitmap_msb_reg = get_node('BEFE.GEM.OH.OH%d.FPGA.TRIG.SBIT_HITMAP.VFAT%d_MSB' % (ohN, vfatN))
                sbit_hitmap_lsb_reg = get_node('BEFE.GEM.OH.OH%d.FPGA.TRIG.SBIT_HITMAP.VFAT%d_LSB' % (ohN, vfatN))
                sbit_hitmap_reset_reg = get_node('BEFE.GEM.OH.OH%d.FPGA.TRIG.SBIT_HITMAP.RESET' % (ohN))
                sbit_hitmap_ack_reg = get_node('BEFE.GEM.OH.OH%d.FPGA.TRIG.SBIT_HITMAP.ACQUIRE' % (ohN))


                write_reg(get_node("BEFE.GEM.OH.OH%i.FPGA.TRIG.CTRL.TU_MASK.VFAT%i_TU_MASK" % (ohN, vfatN)), 0xff ^ (1 << (ibit)))

                for delay in range(SCAN_RANGE+1):

                    write_reg(tap_dly_reg, delay);

                    for islice in range (8):

                        trigger_channel = ibit*8 + islice

                        for strip_odd in range (1):

                            strip = trigger_channel*2+strip_odd


                            write_reg(get_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)
                            write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.VFAT_CHANNELS.CHANNEL%i"%(ohN,vfatN,strip)), 0x8000) # enable calpulse and unmask
                            write_reg(get_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)


                            for ipulse in range(1):

                                sleep(0.0001)

                                write_reg(sbit_hitmap_reset_reg, 1)
                                write_reg(sbit_hitmap_ack_reg, 1)

                                sleep(0.0001)

                                write_reg(sbit_hitmap_ack_reg, 0)

                                hit_map = (read_reg(sbit_hitmap_msb_reg) << 32) + read_reg(sbit_hitmap_lsb_reg)
                                hit_map_expected = 1 << trigger_channel

                                err = hit_map_expected != hit_map;
                                if (err):
                                    err_matrix[ibit][delay-dly_offset+SCAN_RANGE] += 1

                                if (hit_map != 0):
                                    if (err):
                                        if (verbose): print("FAIL:"),
                                    else:
                                        if (verbose): print("PASS:"),

                                    if (verbose): print("ibit=%d, delay=%3i, slice=%i, ch_expect = %2d, hitmap=%s" % (ibit, delay-dly_offset,islice,  trigger_channel, hex(hit_map)))
                                else:
                                    if (verbose): print("FAIL: no cluster found");

                            write_reg(get_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)
                            write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.VFAT_CHANNELS.CHANNEL%i"%(ohN,vfatN,strip)), 0x4000) # disable calpulse and mask
                            write_reg(get_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)

            write_reg(tap_dly_reg, tap_dly_original);

        ngood_center = [0 for i in range (8)]
        ngood_width  = [0 for i in range (8)]
        best_tap_delay  = [0 for i in range (8)]

        min_center = 1000

        line =  "      "
        for dly in range (2*SCAN_RANGE+1):
            text = "%2X" % (abs(dly-SCAN_RANGE) % 16)
            line = line + text

        print(line)

        for ibit in range(8):

            ngood        = 0
            ngood_max    = 0
            ngood_edge   = 0

            for dly in range (2*SCAN_RANGE+1):
                if (err_matrix[ibit][dly]==0):
                    ngood+=1
                    if (dly==2*SCAN_RANGE):
                        if (ngood > 0 and ngood >= ngood_max):
                            ngood_max  = ngood
                            ngood_edge = dly
                            ngood=0
                else:
                    if (ngood > 0 and ngood >= ngood_max):
                        ngood_max  = ngood
                        ngood_edge = dly
                        ngood=0
                    #print("%3i" % err_matrix[ibit][dly]),

            if (ngood_max>0):
                ngood_width[ibit] = ngood_max

                # even windows
                if (ngood_max % 2 == 0):
                    ngood_center[ibit]=ngood_edge-(ngood_max/2)-1;
                if (err_matrix[ibit][ngood_edge] > err_matrix[ibit][ngood_edge-ngood_max-1]):
                    ngood_center[ibit]=ngood_center[ibit]
                else:
                    ngood_center[ibit]=ngood_center[ibit]+1

                # oddwindows
                if (ngood_max % 2 == 1):
                    ngood_center[ibit]=ngood_edge-(ngood_max/2)-1;

                # minimum
                if (ngood_center[ibit] < min_center):
                    min_center = ngood_center[ibit]

        ################################################################################
        # Printout Timing Window
        ################################################################################

        for ibit in range(8):

            line = ("Sbit%i: " % ibit)

            for dly in range (2*SCAN_RANGE+1):
                if (err_matrix[ibit][dly]==0):
                    if (dly == ngood_center[ibit]):
                        line = line + Colors.GREEN + "| "
                    else:
                        line = line + Colors.GREEN + "- "
                else:
                    line = line + Colors.RED + "x "

            line = line + Colors.ENDC
            if print_result:
                print(line)

        ################################################################################
        # Printout Summary
        ################################################################################

        if print_result:
            print("min center = %i" % min_center)

        best_sot_tap_delay = 99
        if (min_center - SCAN_RANGE < 0):
            best_sot_tap_delay = -1 * (min_center-SCAN_RANGE)
        else:
            best_sot_tap_delay = min_center

        if print_result:
            print("sot :           best_dly=% 2d" % ( best_sot_tap_delay))
        ngood_center_offset = []
        for ibit in range(8):
            best_tap_delay [ibit] = ngood_center[ibit] - min_center
            if print_result:
                print("bit%i: center=% 2d best_dly=% 2d width=% 2d (%f ns)" % (ibit, ngood_center[ibit]-SCAN_RANGE, best_tap_delay[ibit], ngood_width[ibit], ngood_width[ibit]*78./1000))
            ngood_center_offset.append(ngood_center[ibit] - SCAN_RANGE)
        VFAT_SBITS_out.append(VFAT_SBIT(vfatN, ngood_center_offset, best_tap_delay, ngood_width))

    if print_result:
        print("")
        print("bye now..")

    return VFAT_SBITS_out

if __name__ == '__main__':
    main()
