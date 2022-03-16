#!/usr/bin/env python

from common.rw_reg import *
from time import *
import array
import struct
import time

OH_NUM = 0
OH_MASK = 1
OUT_DIR = "./data/"
READ_WAIT_SEC = 1.0

RSSI_R1 = 2000.0
RSSI_R2 = 1000.0
RSSI_VCC = 2.5

def main():

    out_file_name = OUT_DIR + "/" + time.strftime("%Y%m%d-%H%M%S") + ".csv"
    out_file = open(out_file_name, "w")
    out_file.write("FPGA_temperature\tSEM_critical_err_count\tSEM_single_bit_err_cnt\tADC_1.0V\tADC_1.0V_AVCC\tADC_1.2V_AVTT\tADC_1.8V\tADC_1.5V\tADC_2.5V\tADC_RSSI1\tADC_RSSI2\n")

    parse_xml()

    iter = 0
    data = {}
    while(True):
        # read temperature
        tempRaw = read_reg(get_node('BEFE.GEM.OH.OH%d.FPGA.ADC.CTRL.DATA_OUT' % OH_NUM))
        temp = ((tempRaw >> 4) * 503.975 / 4096) - 273.15
        print("FPGA temperature: %fC" % temp)

        # read SEM counters
        sem_crit = read_reg(get_node('BEFE.GEM.OH.OH%d.FPGA.CONTROL.SEM.CNT_SEM_CRITICAL' % OH_NUM))
        sem_corr = read_reg(get_node('BEFE.GEM.OH.OH%d.FPGA.CONTROL.SEM.CNT_SEM_CORRECTION' % OH_NUM))
        print("SEM single bit correction count: %d" % sem_corr)
        print("SEM double bit (critical) error count: %d" % sem_crit)

        # read the SCA ADCs
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.LINK_ENABLE_MASK'), OH_MASK)
        sleep(0.01)
        sendScaCommand([OH_NUM], 0x14, 0x60, 0x4, 0x00e00300, False) # setup current sources
        sleep(0.01)
        adc_1v0 = readScaAdc(OH_NUM, 0) * 0.004
        adc_1v0avcc = readScaAdc(OH_NUM, 1) * 0.004
        adc_1v2avtt = readScaAdc(OH_NUM, 2) * 0.004
        adc_1v8 = readScaAdc(OH_NUM, 3) * 0.004
        adc_1v5 = readScaAdc(OH_NUM, 4) * 0.004
        adc_2v5 = readScaAdc(OH_NUM, 5) * 0.004

        adc_rssi1_v = readScaAdc(OH_NUM, 6) / 1000.0
        adc_rssi1_a = (((adc_rssi1_v / (RSSI_R2 / (RSSI_R1 + RSSI_R2))) - RSSI_VCC) / RSSI_R1) * -1
        adc_rssi1_ua = adc_rssi1_a * 1000000
        adc_rssi2_v = readScaAdc(OH_NUM, 7) / 1000.0
        adc_rssi2_a = (((adc_rssi2_v / (RSSI_R2 / (RSSI_R1 + RSSI_R2))) - RSSI_VCC) / RSSI_R1) * -1
        adc_rssi2_ua = adc_rssi2_a * 1000000


        print("ADC 1.0V: %fV" % adc_1v0)
        print("ADC 1.0V AVCC: %fV" % adc_1v0avcc)
        print("ADC 1.2V AVTT: %fV" % adc_1v2avtt)
        print("ADC 1.8V: %fV" % adc_1v8)
        print("ADC 1.5V: %fV" % adc_1v5)
        print("ADC 2.5V: %fV" % adc_2v5)
        print("ADC RSSI1: %fuA" % adc_rssi1_ua)
        print("ADC RSSI2: %fuA" % adc_rssi2_ua)
        print("ADC board temp1: %fuA" % adc_rssi2_ua)

        # print and save the data
        data_csv = "%f\t%d\t%d\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f" % (temp, sem_crit, sem_corr, adc_1v0, adc_1v0avcc, adc_1v2avtt, adc_1v8, adc_1v5, adc_2v5, adc_rssi1_ua, adc_rssi2_ua)
        out_file.write("%s\n" % data_csv)
        out_file.flush()

        sleep(READ_WAIT_SEC)
        iter += 1

        print("=============================")

def readScaAdc(oh, channel):
    sendScaCommand([oh], 0x14, 0x50, 0x4, channel << 24, False)
    res = sendScaCommand([oh], 0x14, 0x02, 0x4, 1 << 24, True)[0]
    res = (res >> 24) + ((res >> 8) & 0xff00)
    if (res > 0xfff):
        return -1.0
    res_mv = ((1.0 / 0xfff) * float(res)) * 1000
    sleep(0.01)
    return res_mv

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

def hex(number):
    if number is None:
        return 'None'
    else:
        return "{0:#0x}".format(number)

def myprint(msg, isError=False):
    col = Colors.RED if isError else Colors.GREEN
    print(col + "===> " + msg + Colors.ENDC)

if __name__ == '__main__':
    main()
