#!/usr/bin/env python

from common.rw_reg import *
from time import *
import array
import struct

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

DEBUG = False

RSSI_R1 = 2000.0
RSSI_R2 = 1000.0
RSSI_VCC = 2.5

def main():

    out_file_name = ""
    out_file = None
    ohMask = 0
    ohList = []

    if len(sys.argv) < 2:
        print('Usage: ge21_oh_rssi_monitor.py <oh_mask> [out_file]')
        return
    else:
        ohMask = parse_int(sys.argv[1])
        for i in range(0, 12):
            if check_bit(ohMask, i):
                ohList.append(i)
        if len(sys.argv) > 2:
            out_file_name = sys.argv[2]
            out_file = open(out_file_name, "w")
            header = ""
            for i in range(12):
                if i != 0:
                    header += "\t"
                header += "OH%d_VTRX1_RSSI_uA\tOH%d_VTRX2_RSSI_uA" % (i, i)
            out_file.write("%s\n" % header)
            out_file.flush()

    parse_xml()

    # check if SCA status is good on all selected OHs
    checkStatus(ohList)

    iter = 0
    while(True):
        rssi = "%d\t" % iter
        for oh in range(12):
            if oh in ohList:
                write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.LINK_ENABLE_MASK'), 1 << oh)
                for ch in range(6, 8): # ADC channels 6 and 8 are connected to the RSSI of the two VTRXs
                    sendScaCommand(ohList, 0x14, 0x50, 0x4, ch << 24, False)
                    results = sendScaCommand([oh], 0x14, 0x02, 0x4, 1 << 24, True)
                    res = (results[0] >> 24) + ((results[0] >> 8) & 0xff00)
                    res_v = (1.0 / 0xfff) * float(res)
                    res_mv = res_v * 1000
                    res_a = (((res_v / (RSSI_R2 / (RSSI_R1 + RSSI_R2))) - RSSI_VCC) / RSSI_R1) * -1
                    res_ua = res_a * 1000000
                    rssi += "%f\t" % res_ua
                    sleep(0.001)
            else:
                rssi += "0.0\t0.0\t"
        print(rssi)
        if out_file is not None:
            out_file.write("%s\n" % rssi)
            out_file.flush()
        sleep(1.0)
        iter += 1


def check_bit(byteval, idx):
    return ((byteval & (1 << idx)) != 0)

def sendScaCommand(ohList, sca_channel, sca_command, data_length, data, doRead):
    #print('fake send: channel ' + hex(sca_channel) + ', command ' + hex(sca_command) + ', length ' + hex(data_length) + ', data ' + hex(data) + ', doRead ' + str(doRead))
    #return

    d = data

    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_CHANNEL'), sca_channel)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_COMMAND'), sca_command)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_LENGTH'), data_length)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_DATA'), d)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_EXECUTE'), 0x1)
    reply = []
    if doRead:
        for i in ohList:
            reply.append(read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_REPLY_OH%d.SCA_RPY_DATA' % i)))
    return reply

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

def heading(string):
    print Colors.BLUE
    print '\n>>>>>>> '+str(string).upper()+' <<<<<<<'
    print Colors.ENDC

def subheading(string):
    print Colors.YELLOW
    print '---- '+str(string)+' ----',Colors.ENDC

def print_cyan(string):
    print Colors.CYAN
    print string, Colors.ENDC

def print_red(string):
    print Colors.RED
    print string, Colors.ENDC

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
