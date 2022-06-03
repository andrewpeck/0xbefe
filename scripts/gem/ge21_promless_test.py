#!/usr/bin/env python

from common.rw_reg import *
from common.utils import *
from time import *
import sys

def main():

    num_iter = 10
    ohMask = 0
    ohList = []

    if len(sys.argv) < 3:
        print('Usage: ge21_promless_test.py <oh_mask> <num_iter>')
        return
    else:
        ohMask = parse_int(sys.argv[1])
        for i in range(0, 12):
            if check_bit(ohMask, i):
                ohList.append(i)
        num_iter = parse_int(sys.argv[2])

    parse_xml()

#    readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
#    subheading('Read GPIO = %s' % hex(readData[0]))
#    return

#    subheading('Reseting the SCA')
#    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.MODULE_RESET'), 0x1)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.LINK_ENABLE_MASK'), ohMask)
    write_reg(get_node('BEFE.GEM.TTC.GENERATOR.ENABLE'), 0x1)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.TTC_HARD_RESET_EN'), 0x0)
    subheading('Disabling monitoring')
#    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.ADC_MONITORING.MONITORING_OFF'), 0xffffffff)
    sleep(0.1)

    gpio_dir = 0xff0fe0
    gpio_default_out = 0x60
    gpio_hr_out = 0xff0fe0

    subheading('Setting the GPIO direction mask to ' + hex(gpio_dir))
    sendScaCommand(ohList, 0x2, 0x20, 0x4, gpio_dir, False)
    sleep(0.1)

    readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
    subheading('Read GPIO = %s' % hex(readData[0]))
    sleep(0.1)

    hr_fail = 0
    program_fail = 0

    for i in range(num_iter):
        heading('Starting programming test (iteration #%d)' % i)

        subheading('Setting hard reset')
        sendScaCommand(ohList, 0x2, 0x10, 0x4, gpio_hr_out, False)
        sleep(0.01)

        readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
        subheading('Read GPIO = %s' % hex(readData[0]))
        fpga_done = (readData[0] >> 30) & 1
        if (fpga_done != 0):
            print_red('FPGA DONE is high, hard reset failed')
            hr_fail += 1
        sleep(0.01)

        subheading('Unsetting hard reset')
        sendScaCommand(ohList, 0x2, 0x10, 0x4, gpio_default_out, False)
        sleep(0.01)

        readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
        subheading('Read GPIO = %s' % hex(readData[0]))
        sleep(0.01)

        subheading('Executing PROMless programming')
        write_reg(get_node('BEFE.GEM.TTC.GENERATOR.SINGLE_HARD_RESET'), 0x1)
        sleep(0.1)

        readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
        subheading('Read GPIO = %s' % hex(readData[0]))
        fpga_done = (readData[0] >> 30) & 1
        if (fpga_done != 1):
            print_red('FPGA DONE is low, programming failed')
            program_fail += 1

        sleep(0.1)

    heading("RESULTS:")
    subheading('%d iterations done, HR fails: %d, program fails: %d' % (num_iter, hr_fail, program_fail))

    return

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

if __name__ == '__main__':
    main()
