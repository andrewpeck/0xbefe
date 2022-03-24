#!/usr/bin/env python

from common.rw_reg import *
from time import *
import array
import struct

DEBUG = False

def main():

    out_file_name = ""
    out_file = None
    ohMask = 0
    ohList = []

    if len(sys.argv) < 2:
        print('Usage: temperature_monitor.py <oh_mask> [out_file]')
        return
    else:
        ohMask = parse_int(sys.argv[1])
        for i in range(0, 12):
            if check_bit(ohMask, i):
                ohList.append(i)
        if len(sys.argv) > 2:
            out_file_name = sys.argv[2]
            out_file = open(out_file_name, "w")

    parse_xml()

    iter = 0
    while(True):
        temps = "%d\t" % iter
        for oh in range(12):
            if oh in ohList:
                tempRaw = read_reg(get_node('BEFE.GEM.OH.OH%d.FPGA.ADC.CTRL.DATA_OUT' % oh))
                temp = ((tempRaw >> 4) * 503.975 / 4096) - 273.15
                temps += "%f\t" % temp
            else:
                temps += "0.0\t"
        print(temps)
        if out_file is not None:
            out_file.write("%s\n" % temps)
            out_file.flush()
        sleep(1.0)
        iter += 1


def check_bit(byteval, idx):
    return ((byteval & (1 << idx)) != 0)

def checkStatus(ohList):
    rxReady       = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.READY'))
    criticalError = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.CRITICAL_ERROR'))

    statusGood = True
    for i in ohList:
        if not check_bit(rxReady, i):
            print_red("OH #%d is not ready: RX ready = %d, critical error = %d" % (i, (rxReady >> i) & 0x1, (criticalError >> i) & 0x1))
            statusGood = False

    return statusGood

def debug(string):
    if DEBUG:
        print('DEBUG: ' + string)

def debugCyan(string):
    if DEBUG:
        print_cyan('DEBUG: ' + string)

if __name__ == '__main__':
    main()
