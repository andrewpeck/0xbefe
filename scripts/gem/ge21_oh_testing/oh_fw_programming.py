import sys
import os
from os import path
import subprocess
from time import *

ohMask = 1

from common.rw_reg import *
from common.promless import *
from common.fw_utils import *

from ADC_read import *
from gem.sca import *

from test_utils import *

def main():
    load_fw_full()
    #load_fw_prbs()
    for i in range(0,1):
        program_fw_single()
        check_SCA_ASIC()
        check_current_fw()
        load_fw_prbs()
        program_fw_single()
        check_SCA_ASIC()
        check_current_fw()

    program_fw_iter(5)

def check_current_fw():
    oh = 0
    print(read_reg("BEFE.GEM.OH.OH%d.FPGA.CONTROL.HOG.OH_VER" % oh, False))
    return

def load_fw_full():
    oh_bitfile = get_config("CONFIG_GE21_OH_BITFILE")
    load_fw(oh_bitfile)

def load_fw_prbs():
    oh_bitfile = get_config("CONFIG_GE21_OH_LOOPBACK_BITFILE")
    load_fw(oh_bitfile)

def load_fw(oh_bitfile):
    if not path.exists(oh_bitfile):
        print_red("OH bitfile %s does not exist. Please create a symlink there, or edit the CONFIG_GE*_OH_BITFILE constant in your befe_config.py file" % oh_bitfile)
        return
    promless_load(oh_bitfile, False)

def program_fw_single(verbose=False):
    ohList = []
    for i in range(0,12):
        if check_bit(ohMask,i):
            ohList.append(i)

        write_reg('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.LINK_ENABLE_MASK', ohMask)
        write_reg('BEFE.GEM.TTC.GENERATOR.ENABLE', 0x1)
        write_reg('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.TTC_HARD_RESET_EN', 0x0)
        if verbose:
            subheading('Disabling monitoring')
        sleep(0.1)

        gpio_dir = 0xff0fe0
        gpio_default_out = 0x60
        gpio_hr_out = 0xff0fe0
        if verbose:
            subheading('Setting the GPIO direction mask to ' + hex(gpio_dir))
        sendScaCommand(ohList, 0x2, 0x20, 0x4, gpio_dir, False)
        sleep(0.1)

        readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
        if verbose:
            subheading('Read GPIO = %s' % hex(readData[0]))
        sleep(0.1)

        hr_fail = 0
        program_fail = 0

        for i in range(0,1):
            if verbose:
                subheading('Starting hard reset')
            sendScaCommand(ohList, 0x2, 0x10, 0x4, gpio_hr_out, False)
            sleep(0.01)

            readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
            if verbose:
                subheading('Read GPIO = %s' % hex(readData[0]))
            fpga_done = (readData[0] >> 30) & 1
            if (fpga_done != 0):
                print_red('FPGA DONE is high, hard reset failed')
                hr_fail += 1
            sleep(0.01)

            if verbose:
                subheading('Unsetting hard reset')
            sendScaCommand(ohList, 0x2, 0x10, 0x4, gpio_default_out, False)
            sleep(0.01)

            readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
            if verbose:
                subheading('Read GPIO = %s' % hex(readData[0]))
            sleep(0.01)
            if verbose:
                subheading('Executing PROMless programming')
            write_reg('BEFE.GEM.TTC.GENERATOR.SINGLE_HARD_RESET', 0x1)
            sleep(0.1)

            readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
            if verbose:
                subheading('Read GPIO = %s' % hex(readData[0]))
            fpga_done = (readData[0] >> 30) & 1
            if (fpga_done != 1):
                print_red('FPGA DONE is low, programming failed')
                program_fail += 1

        sleep(0.1)
        if verbose:
            subheading('HR Errors: %d, program Errors: %d' % (hr_fail, program_fail))

    resetSca()
    sleep(0.1)

def program_fw_iter(num_iter, verbose=False):
    print("Running OH FPGA programming test with %d programming cycles" % num_iter)
    ohList = []
    for i in range(0,12):
        if check_bit(ohMask,i):
            ohList.append(i)

    write_reg('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.LINK_ENABLE_MASK', ohMask)
    write_reg('BEFE.GEM.TTC.GENERATOR.ENABLE', 0x1)
    write_reg('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.TTC_HARD_RESET_EN', 0x0)

    sleep(0.1)

    gpio_dir = 0xff0fe0
    gpio_default_out = 0x60
    gpio_hr_out = 0xff0fe0
    if verbose:
        subheading('Setting the GPIO direction mask to ' + hex(gpio_dir))
    sendScaCommand(ohList, 0x2, 0x20, 0x4, gpio_dir, False)
    sleep(0.1)

    readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
    if verbose:
        subheading('Read GPIO = %s' % hex(readData[0]))
    sleep(0.1)

    hr_fail = 0
    program_fail = 0

    for i in range(num_iter):
        if verbose:
            heading('Starting programming test (iteration #%d)' % i)
        if verbose:
            subheading('Setting hard reset')
        sendScaCommand(ohList, 0x2, 0x10, 0x4, gpio_hr_out, False)
        sleep(0.01)

        readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
        if verbose:
            subheading('Read GPIO = %s' % hex(readData[0]))
        fpga_done = (readData[0] >> 30) & 1
        if (fpga_done != 0):
            print_red('FPGA DONE is high, hard reset failed')
            hr_fail += 1
        sleep(0.01)

        if verbose:
            subheading('Unsetting hard reset')
        sendScaCommand(ohList, 0x2, 0x10, 0x4, gpio_default_out, False)
        sleep(0.01)

        readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
        if verbose:
            subheading('Read GPIO = %s' % hex(readData[0]))
        sleep(0.01)

        if verbose:
            subheading('Executing PROMless programming')
        write_reg('BEFE.GEM.TTC.GENERATOR.SINGLE_HARD_RESET', 0x1)
        sleep(0.1)

        readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
        if verbose:
            subheading('Read GPIO = %s' % hex(readData[0]))
        fpga_done = (readData[0] >> 30) & 1
        if (fpga_done != 1):
            print_red('FPGA DONE is low, programming failed')
            program_fail += 1

        if (i % (num_iter / 10) == 0) and i != 0:
            progress = (i * 100) / num_iter
            print("  Programming test progress: %d%%" % progress)

    sleep(0.1)

    subheading('%d iterations done, HR Errors: %d, program Errors: %d' % (num_iter, hr_fail, program_fail))

    resetSca()
    sleep(0.1)
    return num_iter - (hr_fail+program_fail)

if __name__ == '__main__':
    parse_xml()
    main()
