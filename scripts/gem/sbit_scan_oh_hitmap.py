#!/usr/bin/env python

from rw_reg import *
from time import *
import array
import struct
import sys

#VFAT DEFAULTS

ADDR_JTAG_LENGTH = None
ADDR_JTAG_TMS = None
ADDR_JTAG_TDO = None
ADDR_JTAG_TDI = None

SCAN_RANGE = 18

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'


def configureVfatForPulsing(vfatN, ohN):

        writeReg(getNode("GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET"), 1)

        sleep (0.1)

        writeReg(getNode("GEM_AMC.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)
        #print "\tLink good: "
        #print "\t\t" + readReg(getNode("GEM_AMC.OH_LINKS.OH%i.VFAT%i.LINK_GOOD"%(ohN,vfatN)))
        #print "\tSync Error: "
        #print "\t\t" + readReg(getNode("GEM_AMC.OH_LINKS.OH%i.VFAT%i.SYNC_ERR_CNT"%(ohN,vfatN)))

        if (parseInt(readReg(getNode("GEM_AMC.OH_LINKS.OH%i.VFAT%i.SYNC_ERR_CNT"%(ohN,vfatN)))) > 0):
            print ("\tLink errors.. exiting")
            sys.exit()


           #Configure TTC generator on CTP7
        writeReg(getNode("GEM_AMC.TTC.GENERATOR.RESET"),  1)
        writeReg(getNode("GEM_AMC.TTC.GENERATOR.ENABLE"), 1)
        writeReg(getNode("GEM_AMC.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 50)
        writeReg(getNode("GEM_AMC.TTC.GENERATOR.CYCLIC_L1A_GAP"),  500)
        writeReg(getNode("GEM_AMC.TTC.GENERATOR.CYCLIC_L1A_COUNT"),  0)

        writeReg(getNode("GEM_AMC.TRIGGER.SBIT_MONITOR.OH_SELECT"), ohN)

        writeReg(getNode("GEM_AMC.OH.OH%i.FPGA.TRIG.CTRL.VFAT_MASK" % ohN), 0xffffff ^ (1 << (vfatN)))

        writeReg(getNode("GEM_AMC.TTC.GENERATOR.CYCLIC_START"), 1)

        for i in range(128):
            writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.VFAT_CHANNELS.CHANNEL%i"%(ohN,vfatN,i)), 0x4000)  # mask all channels and disable the calpulse

        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_PULSE_STRETCH"       % (ohN , vfatN)) , 7)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SYNC_LEVEL_MODE"     % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SELF_TRIGGER_MODE"   % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_DDR_TRIGGER_MODE"    % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SPZS_SUMMARY_ONLY"   % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SPZS_MAX_PARTITIONS" % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SPZS_ENABLE"         % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SZP_ENABLE"          % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SZD_ENABLE"          % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_TIME_TAG"            % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_EC_BYTES"            % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BC_BYTES"            % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_FP_FE"               % (ohN , vfatN)) , 7)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_RES_PRE"             % (ohN , vfatN)) , 1)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAP_PRE"             % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_PT"                  % (ohN , vfatN)) , 15)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_EN_HYST"             % (ohN , vfatN)) , 1)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SEL_POL"             % (ohN , vfatN)) , 1)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_FORCE_EN_ZCC"        % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_FORCE_TH"            % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SEL_COMP_MODE"       % (ohN , vfatN)) , 1)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_VREF_ADC"            % (ohN , vfatN)) , 3)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_MON_GAIN"            % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_MONITOR_SELECT"      % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_IREF"                % (ohN , vfatN)) , 32)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_THR_ZCC_DAC"         % (ohN , vfatN)) , 10)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_THR_ARM_DAC"         % (ohN , vfatN)) , 100)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_HYST"                % (ohN , vfatN)) , 5)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_LATENCY"             % (ohN , vfatN)) , 45)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_SEL_POL"         % (ohN , vfatN)) , 1)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_PHI"             % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_EXT"             % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DAC"             % (ohN , vfatN)) , 50)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"            % (ohN , vfatN)) , 1)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_FS"              % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"             % (ohN , vfatN)) , 200)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_CFD_DAC_2"      % (ohN , vfatN)) , 40)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_CFD_DAC_1"      % (ohN , vfatN)) , 40)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BSF"      % (ohN , vfatN)) , 13)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BIT"      % (ohN , vfatN)) , 150)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BLCC"     % (ohN , vfatN)) , 25)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_VREF"       % (ohN , vfatN)) , 86)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BFCAS"     % (ohN , vfatN)) , 250)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BDIFF"     % (ohN , vfatN)) , 150)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BFAMP"     % (ohN , vfatN)) , 0)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BDIFF"     % (ohN , vfatN)) , 255)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BSF"       % (ohN , vfatN)) , 15)
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BFCAS"     % (ohN , vfatN)) , 255)

        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_PULSE_STRETCH"       % (ohN , vfatN)) , 3)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SYNC_LEVEL_MODE"     % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SELF_TRIGGER_MODE"   % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_DDR_TRIGGER_MODE"    % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SPZS_SUMMARY_ONLY"   % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SPZS_MAX_PARTITIONS" % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SPZS_ENABLE"         % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SZP_ENABLE"          % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SZD_ENABLE"          % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_TIME_TAG"            % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_EC_BYTES"            % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BC_BYTES"            % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_FP_FE"               % (ohN , vfatN)) , 7)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_RES_PRE"             % (ohN , vfatN)) , 2)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAP_PRE"             % (ohN , vfatN)) , 1)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_PT"                  % (ohN , vfatN)) , 15)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_EN_HYST"             % (ohN , vfatN)) , 1)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SEL_POL"             % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_FORCE_EN_ZCC"        % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_FORCE_TH"            % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SEL_COMP_MODE"       % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_VREF_ADC"            % (ohN , vfatN)) , 3)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_MON_GAIN"            % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_MONITOR_SELECT"      % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_IREF"                % (ohN , vfatN)) , 32)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_THR_ZCC_DAC"         % (ohN , vfatN)) , 10)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_THR_ARM_DAC"         % (ohN , vfatN)) , 100)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_HYST"                % (ohN , vfatN)) , 5)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_LATENCY"             % (ohN , vfatN)) , 57)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_SEL_POL"         % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_PHI"             % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_EXT"             % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DAC"             % (ohN , vfatN)) , 50) # voltage pulse
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"            % (ohN , vfatN)) , 1) # voltage pulse
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DAC"             % (ohN , vfatN)) , 250) # current pulse
        # writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"            % (ohN , vfatN)) , 2) # current pulse
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_FS"              % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"             % (ohN , vfatN)) , 200)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_CFD_DAC_2"      % (ohN , vfatN)) , 40)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_CFD_DAC_1"      % (ohN , vfatN)) , 40)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BSF"      % (ohN , vfatN)) , 13)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BIT"      % (ohN , vfatN)) , 150)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BLCC"     % (ohN , vfatN)) , 25)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_VREF"       % (ohN , vfatN)) , 86)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BFCAS"     % (ohN , vfatN)) , 130)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BDIFF"     % (ohN , vfatN)) , 80)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BFAMP"     % (ohN , vfatN)) , 1)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BDIFF"     % (ohN , vfatN)) , 140)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BSF"       % (ohN , vfatN)) , 15)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BFCAS"     % (ohN , vfatN)) , 135)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_RUN"%(ohN,vfatN)), 1)
        writeReg(getNode("GEM_AMC.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)

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
        printRed("The given OH index (%d) is out of range (must be 0-11)" % ohN)
        return
    if vfatNMin > 23:
        printRed("The given VFAT index (%d) is out of range (must be 0-23)" % vfatN)
        return
    if vfatNMax > 23:
        printRed("The given VFAT index (%d) is out of range (must be 0-23)" % vfatN)
        return

    verbose = 0
    if (vfatNMin == vfatNMax):
        verbose = 1

    parseXML()
    initJtagRegAddrs()

    addrSbitMonReset = getNode('GEM_AMC.OH.OH%d.FPGA.TRIG.SBIT_MONITOR.RESET' % ohN)
    writeReg(getNode("GEM_AMC.TRIGGER.SBIT_MONITOR.OH_SELECT"), ohN)

    ##################
    # hard reset
    ##################

    for vfatN in range (vfatNMin, vfatNMax+1):

        print ("")
        print ("####################################################################################################")
        print ("Scanning VFAT %i" % vfatN)
        print ("####################################################################################################")
        print ("")

        writeReg(getNode('GEM_AMC.SLOW_CONTROL.SCA.CTRL.MODULE_RESET'), 0x1)
        writeReg(getNode('GEM_AMC.SLOW_CONTROL.SCA.MANUAL_CONTROL.LINK_ENABLE_MASK'), 0x1<<ohN)
        writeReg(getNode('GEM_AMC.TTC.GENERATOR.ENABLE'), 0x1)
        writeReg(getNode('GEM_AMC.SLOW_CONTROL.SCA.CTRL.TTC_HARD_RESET_EN'), 0x0)
#        writeReg(getNode('GEM_AMC.SLOW_CONTROL.SCA.ADC_MONITORING.MONITORING_OFF'), 0xffffffff)

        gpio_dir = 0xff0fe0
        gpio_default_out = 0x60
        gpio_hr_out = 0xff0fe0

        ohList=[ohN]

        sendScaCommand(ohList, 0x2, 0x20, 0x4, gpio_dir, False)
        sleep(0.1)

        sendScaCommand(ohList, 0x2, 0x10, 0x4, gpio_hr_out, False)
        sleep(0.01)

        sendScaCommand(ohList, 0x2, 0x10, 0x4, gpio_default_out, False)
        sleep(0.01)

        writeReg(getNode('GEM_AMC.TTC.GENERATOR.SINGLE_HARD_RESET'), 0x1)
        sleep(0.15)

        ##################
        #
        ##################

        addrCluster = [0]*8
        for i in range(8):
            addrCluster[i] = getNode('GEM_AMC.OH.OH%d.FPGA.TRIG.SBIT_MONITOR.CLUSTER%i' % (ohN, i))

        configureVfatForPulsing(vfatN, ohN)

        err_matrix = [[0 for i in range(0,2*SCAN_RANGE+1)] for j in range(8)]

        writeReg(getNode("GEM_AMC.OH.OH%i.FPGA.TRIG.CTRL.ALIGNED_COUNT_TO_READY" % ohN), 0xfff)

        sot_reg          = getNode('GEM_AMC.OH.OH%d.FPGA.TRIG.TIMING.SOT_TAP_DELAY_VFAT%s' % (ohN, vfatN))
        sot_dly_original = parseInt(readReg(sot_reg))

        for sot_dly in range(2):

            dly_offset = 0
            if(sot_dly == 0):
                dly_offset = SCAN_RANGE
            else:
                dly_offset = 0

            writeReg(sot_reg, dly_offset)
            sot_rdy = parseInt(readReg(getNode("GEM_AMC.OH.OH%i.FPGA.TRIG.CTRL.SBIT_SOT_READY" % ohN)))
            sleep (0.1)
            if (not (sot_rdy >> vfatN)&0x1):
                print ("Sot not ready... cannot scan")
                sys.exit()

            for ibit in range(8):

                #   Set the SoT delay to 0 (min)
                tap_dly_reg      = getNode('GEM_AMC.OH.OH%d.FPGA.TRIG.TIMING.TAP_DELAY_VFAT%i_BIT%i' % (ohN, vfatN, ibit))
                tap_dly_original = parseInt(readReg(tap_dly_reg))

#                sbit_monitor_cluster_reg = getNode('GEM_AMC.OH.OH%d.FPGA.TRIG.SBIT_MONITOR.CLUSTER0' % (ohN))
#                sbit_monitor_reset_reg   = getNode('GEM_AMC.OH.OH%d.FPGA.TRIG.SBIT_MONITOR.RESET' % (ohN))

                sbit_hitmap_msb_reg = getNode('GEM_AMC.OH.OH%d.FPGA.TRIG.SBIT_HITMAP.VFAT%d_MSB' % (ohN, vfatN))
                sbit_hitmap_lsb_reg = getNode('GEM_AMC.OH.OH%d.FPGA.TRIG.SBIT_HITMAP.VFAT%d_LSB' % (ohN, vfatN))
                sbit_hitmap_reset_reg = getNode('GEM_AMC.OH.OH%d.FPGA.TRIG.SBIT_HITMAP.RESET' % (ohN))
                sbit_hitmap_ack_reg = getNode('GEM_AMC.OH.OH%d.FPGA.TRIG.SBIT_HITMAP.ACQUIRE' % (ohN))


                writeReg(getNode("GEM_AMC.OH.OH%i.FPGA.TRIG.CTRL.TU_MASK.VFAT%i_TU_MASK" % (ohN, vfatN)), 0xff ^ (1 << (ibit)))

                for delay in range(SCAN_RANGE+1):

                    writeReg(tap_dly_reg, delay);

                    for islice in range (8):

                        trigger_channel = ibit*8 + islice

                        for strip_odd in range (1):

                            strip = trigger_channel*2+strip_odd


                            writeReg(getNode("GEM_AMC.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)
                            writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.VFAT_CHANNELS.CHANNEL%i"%(ohN,vfatN,strip)), 0x8000) # enable calpulse and unmask
                            writeReg(getNode("GEM_AMC.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)


                            for ipulse in range(1):

                                sleep(0.0001)

                                writeReg(sbit_hitmap_reset_reg, 1)
                                writeReg(sbit_hitmap_ack_reg, 1)

                                sleep(0.0001)

                                writeReg(sbit_hitmap_ack_reg, 0)

                                hit_map = (parseInt(readReg(sbit_hitmap_msb_reg)) << 32) + parseInt(readReg(sbit_hitmap_lsb_reg))
                                hit_map_expected = 1 << trigger_channel

                                err = hit_map_expected != hit_map;
                                if (err):
                                    err_matrix[ibit][delay-dly_offset+SCAN_RANGE] += 1

                                if (hit_map != 0):
                                    if (err):
                                        if (verbose): print ("FAIL:"),
                                    else:
                                        if (verbose): print ("PASS:"),

                                    if (verbose): print ("ibit=%d, delay=%3i, slice=%i, ch_expect = %2d, hitmap=%s" % (ibit, delay-dly_offset,islice,  trigger_channel, hex(hit_map)))
                                else:
                                    if (verbose): print ("FAIL: no cluster found");

                            writeReg(getNode("GEM_AMC.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)
                            writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.VFAT_CHANNELS.CHANNEL%i"%(ohN,vfatN,strip)), 0x4000) # disable calpulse and mask
                            writeReg(getNode("GEM_AMC.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)

            writeReg(tap_dly_reg, tap_dly_original);

        ngood_center = [0 for i in range (8)]
        ngood_width  = [0 for i in range (8)]
        best_tap_delay  = [0 for i in range (8)]

        min_center = 1000

        line =  "      "
        for dly in range (2*SCAN_RANGE+1):
            text = "%2X" % (abs(dly-SCAN_RANGE) % 16)
            line = line + text

        print (line)

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
            print line

        ################################################################################
        # Printout Summary
        ################################################################################

        print ("min center = %i" % min_center)

        best_sot_tap_delay = 99
        if (min_center - SCAN_RANGE < 0):
            best_sot_tap_delay = -1 * (min_center-SCAN_RANGE)
        else:
            best_sot_tap_delay = min_center

        print ("sot :           best_dly=% 2d" % ( best_sot_tap_delay))
        for ibit in range(8):
            best_tap_delay [ibit] = ngood_center[ibit] - min_center
            print ("bit%i: center=% 2d best_dly=% 2d width=% 2d (%f ns)" % (ibit, ngood_center[ibit]-SCAN_RANGE, best_tap_delay[ibit], ngood_width[ibit], ngood_width[ibit]*78./1000))


    print("")
    print("bye now..")

def sendScaCommand(ohList, sca_channel, sca_command, data_length, data, doRead):
    #print('fake send: channel ' + hex(sca_channel) + ', command ' + hex(sca_command) + ', length ' + hex(data_length) + ', data ' + hex(data) + ', doRead ' + str(doRead))
    #return

    d = data

    writeReg(getNode('GEM_AMC.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_CHANNEL'), sca_channel)
    writeReg(getNode('GEM_AMC.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_COMMAND'), sca_command)
    writeReg(getNode('GEM_AMC.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_LENGTH'), data_length)
    writeReg(getNode('GEM_AMC.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_DATA'), d)
    writeReg(getNode('GEM_AMC.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_EXECUTE'), 0x1)
    reply = []
    if doRead:
        for i in ohList:
            reply.append(parseInt(readReg(getNode('GEM_AMC.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_REPLY_OH%d.SCA_RPY_DATA' % i))))
    return reply

def initJtagRegAddrs():
    global ADDR_JTAG_LENGTH
    global ADDR_JTAG_TMS
    global ADDR_JTAG_TDO
    global ADDR_JTAG_TDI
    ADDR_JTAG_LENGTH = getNode('GEM_AMC.SLOW_CONTROL.SCA.JTAG.NUM_BITS').real_address
    ADDR_JTAG_TMS = getNode('GEM_AMC.SLOW_CONTROL.SCA.JTAG.TMS').real_address
    ADDR_JTAG_TDO = getNode('GEM_AMC.SLOW_CONTROL.SCA.JTAG.TDO').real_address
    #ADDR_JTAG_TDI = getNode('GEM_AMC.SLOW_CONTROL.SCA.JTAG.TDI').real_address

def check_bit(byteval,idx):
    return ((byteval&(1<<idx))!=0);

def debug(string):
    if DEBUG:
        print('DEBUG: ' + string)

def debugCyan(string):
    if DEBUG:
        printCyan('DEBUG: ' + string)

def heading(string):
    print (Colors.BLUE)
    print ('\n>>>>>>> '+str(string).upper()+' <<<<<<<')
    print (Colors.ENDC)

def subheading(string):
    print (Colors.YELLOW)
    print ('---- '+str(string)+' ----',Colors.ENDC)

def printCyan(string):
    print (Colors.CYAN)
    print (string, Colors.ENDC)

def printRed(string):
    print (Colors.RED)
    print (string, Colors.ENDC)

def hex(number):
    if number is None:
        return 'None'
    else:
        return "{0:#0x}".format(number)

def binary(number, length):
    if number is None:
        return 'None'
    else:
        return "{0:#0{1}b}".format(number, length + 2)

if __name__ == '__main__':
    main()
