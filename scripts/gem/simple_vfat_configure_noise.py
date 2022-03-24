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


def configureVfat(vfatN, ohN, threshold):

        if (read_reg(get_node("BEFE.GEM.OH_LINKS.OH%i.VFAT%i.SYNC_ERR_CNT"%(ohN,vfatN))) > 0):
            print ("\tLink errors.. exiting")
            sys.exit()

        for i in range(128):
            write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.VFAT_CHANNELS.CHANNEL%i"%(ohN,vfatN,i)), 0x0000)  # unmask all channels

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
        write_reg(get_node("BEFE.GEM.OH.OH%i.GEB.VFAT%i.CFG_THR_ARM_DAC"         % (ohN , vfatN)) , threshold)
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

def main():

    ohN = 0
    threshold = 0

    if len(sys.argv) < 3:
        print('Usage: vfat_configure_noise.py <oh_num> <threshold>')
        return

    ohN = int(sys.argv[1])
    print("OH = %d" % ohN)
    if ohN > 11:
        print_red("The given OH index (%d) is out of range (must be 0-11)" % ohN)
        return

    threshold = int(sys.argv[2])
    print("threshold = %d" % threshold)
    if threshold < 0 or threshold > 255:
        print_red("Invalid threshold, must be in the range of 0-255: %d" % threshold)
        return

    parse_xml()

    write_reg(get_node("BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET"), 1)

    sleep (0.1)

    # unmask everything
    write_reg(get_node("BEFE.GEM.OH.OH%i.FPGA.TRIG.CTRL.VFAT_MASK" % ohN), 0)
    for i in range(12):
        write_reg(get_node("BEFE.GEM.OH.OH%i.FPGA.TRIG.CTRL.TU_MASK.VFAT%i_TU_MASK" % (ohN, i)), 0)

    write_reg(get_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 1)

    # configure all vfats
    for i in range(12):
        cfg_run = read_reg("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN" % (ohN, i), False)
        if cfg_run == 0xdeaddead:
            print("Skipping VFAT %d, because it's not reachable via slow control" % i)
        else:
            print("Configuring VFAT %d" % i)
            configureVfat(i, ohN, threshold)

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
