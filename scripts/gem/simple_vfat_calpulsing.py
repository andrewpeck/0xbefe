#!/usr/bin/env python

from common.rw_reg import *
from time import *
import array
import struct
import sys

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'


CALPULSE_GAP = 500

def configureVfatForPulsing(vfatN, ohN, channel):

        if (read_reg(get_node("BEFE.GEM.OH_LINKS.OH%i.VFAT%i.SYNC_ERR_CNT"%(ohN,vfatN))) > 0):
            print ("\tLink errors.. exiting")
            sys.exit()

        for i in range(128):
            write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.VFAT_CHANNELS.CHANNEL%i"%(ohN,vfatN,i)), 0x4000)  # mask all channels and disable the calpulse

        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_PULSE_STRETCH"       % (ohN , vfatN)) , 7)
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
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_RES_PRE"             % (ohN , vfatN)) , 1)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAP_PRE"             % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_PT"                  % (ohN , vfatN)) , 15)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_EN_HYST"             % (ohN , vfatN)) , 1)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SEL_POL"             % (ohN , vfatN)) , 1)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_FORCE_EN_ZCC"        % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_FORCE_TH"            % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_SEL_COMP_MODE"       % (ohN , vfatN)) , 1)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_VREF_ADC"            % (ohN , vfatN)) , 3)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_MON_GAIN"            % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_MONITOR_SELECT"      % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_IREF"                % (ohN , vfatN)) , 32)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_THR_ZCC_DAC"         % (ohN , vfatN)) , 10)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_THR_ARM_DAC"         % (ohN , vfatN)) , 100)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_HYST"                % (ohN , vfatN)) , 5)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_LATENCY"             % (ohN , vfatN)) , 45)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_SEL_POL"         % (ohN , vfatN)) , 1)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_PHI"             % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_EXT"             % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DAC"             % (ohN , vfatN)) , 50)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_MODE"            % (ohN , vfatN)) , 1)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_FS"              % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_CAL_DUR"             % (ohN , vfatN)) , 200)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_CFD_DAC_2"      % (ohN , vfatN)) , 40)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_CFD_DAC_1"      % (ohN , vfatN)) , 40)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BSF"      % (ohN , vfatN)) , 13)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BIT"      % (ohN , vfatN)) , 150)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_I_BLCC"     % (ohN , vfatN)) , 25)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_PRE_VREF"       % (ohN , vfatN)) , 86)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BFCAS"     % (ohN , vfatN)) , 250)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BDIFF"     % (ohN , vfatN)) , 150)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SH_I_BFAMP"     % (ohN , vfatN)) , 0)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BDIFF"     % (ohN , vfatN)) , 255)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BSF"       % (ohN , vfatN)) , 15)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_BIAS_SD_I_BFCAS"     % (ohN , vfatN)) , 255)
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_RUN"%(ohN,vfatN)), 1)

        #unmask and enable calpulsing on the given channel
        if channel >= 0:
            write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.VFAT_CHANNELS.CHANNEL%i"%(ohN,vfatN,channel)), 0x8000)

def main():

    ohN = 0
    vfats = []
    channels = []
    vfatMask = 0xffffff

    if len(sys.argv) < 2:
        print('Usage: vfat_calpulsing.py <oh_num> [vfat_num_1] [vfat_channel_num_1] [vfat_num_2] [vfat_channel_num_2] [vfat_num_3] [vfat_channel_num_3]...')
        return

    ohN = int(sys.argv[1])
    print("OH = %d" % ohN)
    if ohN > 11:
        print_red("The given OH index (%d) is out of range (must be 0-11)" % ohN)
        return

    for i in range(2, len(sys.argv), 2):
        if i != len(sys.argv) - 1:
            vfat = int(sys.argv[i])
            chan = int(sys.argv[i+1])
            vfats.append(vfat)
            channels.append(chan)
            vfatMask = vfatMask ^ (1 << vfat)
            print("VFAT %d channel %d" % (vfat, chan))
            if vfat > 23 or chan > 127:
                print_red("Invalid VFAT or channel number, exiting")
                return

    parse_xml()

    # enable the generator
    write_reg(get_node("BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET"), 1)

    sleep (0.1)

    write_reg(get_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)
    #print "\tLink good: "
    #print "\t\t" + read_reg(get_node("BEFE.GEM.OH_LINKS.OH%i.VFAT%i.LINK_GOOD"%(ohN,vfatN)))
    #print "\tSync Error: "
    #print "\t\t" + read_reg(get_node("BEFE.GEM.OH_LINKS.OH%i.VFAT%i.SYNC_ERR_CNT"%(ohN,vfatN)))


       #Configure TTC generator on CTP7
    write_reg(get_node("BEFE.GEM.TTC.GENERATOR.RESET"),  1)
    write_reg(get_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 1)
    write_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 50)
    write_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_GAP"),  CALPULSE_GAP)
    write_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_COUNT"),  0)

    write_reg(get_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.OH_SELECT"), ohN)

    write_reg(get_node("BEFE.GEM.OH.OH%i.FPGA.TRIG.CTRL.VFAT_MASK" % ohN), vfatMask)

    for i in range(12):
        write_reg(get_node("BEFE.GEM.OH.OH%i.FPGA.TRIG.CTRL.TU_MASK.VFAT%i_TU_MASK" % (ohN, i)), 0)

    write_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START"), 1)

    # configure all vfats
    for i in range(12):
        syncErrCnt = read_reg(get_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (ohN, i)))
        if syncErrCnt > 0:
            print("Skipping VFAT%d because it seems dead (sync err cnt = %d)" % (i, syncErrCnt))
        else:
            print("Configuring VFAT %d with default configuration" % i)
            configureVfatForPulsing(i, ohN, -1)

    # configure the pulsing VFATs
    for i in range(len(vfats)):
        print("Configuring VFAT %d for pulsing on channel %d" % (vfats[i], channels[i]))
        configureVfatForPulsing(vfats[i], ohN, channels[i])

    write_reg(get_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)


def check_bit(byteval,idx):
    return ((byteval&(1<<idx))!=0);

def debug(string):
    if DEBUG:
        print('DEBUG: ' + string)

def debugCyan(string):
    if DEBUG:
        print_cyan('DEBUG: ' + string)

def heading(string):
    print (Colors.BLUE)
    print ('\n>>>>>>> '+str(string).upper()+' <<<<<<<')
    print (Colors.ENDC)

def subheading(string):
    print (Colors.YELLOW)
    print ('---- '+str(string)+' ----',Colors.ENDC)

def print_cyan(string):
    print (Colors.CYAN)
    print (string, Colors.ENDC)

def print_red(string):
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
