#!/usr/bin/env python

from rw_reg import *
from time import *
import array
import struct
import sys

def configureVfat(vfatN, ohN):

        if (parseInt(readReg(getNode("GEM_AMC.OH_LINKS.OH%i.VFAT%i.SYNC_ERR_CNT"%(ohN,vfatN)))) > 0):
            print ("\tLink errors.. exiting")
            sys.exit()

        for i in range(128):
            writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.VFAT_CHANNELS.CHANNEL%i"%(ohN,vfatN,i)), 0x0)

        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_PULSE_STRETCH"       % (ohN , vfatN)) , 7)
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
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_RES_PRE"             % (ohN , vfatN)) , 1)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAP_PRE"             % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_PT"                  % (ohN , vfatN)) , 15)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_EN_HYST"             % (ohN , vfatN)) , 1)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SEL_POL"             % (ohN , vfatN)) , 1)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_FORCE_EN_ZCC"        % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_FORCE_TH"            % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_SEL_COMP_MODE"       % (ohN , vfatN)) , 1)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_VREF_ADC"            % (ohN , vfatN)) , 3)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_MON_GAIN"            % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_MONITOR_SELECT"      % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_IREF"                % (ohN , vfatN)) , 32)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_THR_ZCC_DAC"         % (ohN , vfatN)) , 10)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_THR_ARM_DAC"         % (ohN , vfatN)) , 100)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_HYST"                % (ohN , vfatN)) , 5)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_LATENCY"             % (ohN , vfatN)) , 45)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_SEL_POL"         % (ohN , vfatN)) , 1)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_PHI"             % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_EXT"             % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DAC"             % (ohN , vfatN)) , 50)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"            % (ohN , vfatN)) , 1)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_FS"              % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"             % (ohN , vfatN)) , 200)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_CFD_DAC_2"      % (ohN , vfatN)) , 40)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_CFD_DAC_1"      % (ohN , vfatN)) , 40)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BSF"      % (ohN , vfatN)) , 13)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BIT"      % (ohN , vfatN)) , 150)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BLCC"     % (ohN , vfatN)) , 25)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_VREF"       % (ohN , vfatN)) , 86)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BFCAS"     % (ohN , vfatN)) , 250)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BDIFF"     % (ohN , vfatN)) , 150)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BFAMP"     % (ohN , vfatN)) , 0)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BDIFF"     % (ohN , vfatN)) , 255)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BSF"       % (ohN , vfatN)) , 15)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BFCAS"     % (ohN , vfatN)) , 255)
        writeReg(getNode("GEM_AMC.OH.OH%i.GEB.VFAT%i.CFG_RUN"%(ohN,vfatN)), 1)

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

    parseXML()
    
    writeReg(getNode("GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET"), 1)
    sleep (0.1)

    for vfatN in range (vfatNMin, vfatNMax+1):
        print("configuring OH%d VFAT%d" % (ohN, vfatN))
        configureVfat(vfatN, ohN)
    

if __name__ == '__main__':
    main()
