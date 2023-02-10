#!/bin/env python
from common.rw_reg import *
from time import *
import array
import struct
import random

SLEEP_BETWEEN_COMMANDS = 0.1
DEBUG = False
CTP7HOSTNAME = "eagle33"

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

REG_CTP7_BOARD_ID = None
REG_OH1_FW = None
REG_OH1_VFAT_MASK = None
REG_VFAT_CONTROL_REG = None
REG_LINK_ENABLE_MASK = None

def main():

    instructions = ""

    if len(sys.argv) < 2:
        print('Usage: evkatest.py <instructions>')
        print('instructions:')
        print('  contains ctp7:     test ctp7 reg access')
        print('  contains oh:       test oh reg access')
        print('  contains vfat:     test vfat reg access')
        return
    else:
        instructions = sys.argv[1]

    parse_xml()
    initRegAddrs(10)

    if instructions == 'ctp7':
        subheading('Testing CTP7')
        regTest(REG_LINK_ENABLE_MASK, 0, 0xffffffff, False, 1000000, True)
#        regTest(REG_CTP7_BOARD_ID, 0xbeef, 0xffff, True, 1000000)
#        regTest(REG_CTP7_BOARD_ID, 0xbeef, 0xffff, True, 2300000000)
    elif instructions == 'oh':
        print_red("OHv3 not supported yet...")
        return
        subheading('Testing OH0')
        regTest(REG_OH1_FW, 0x20170302, 0xffffffff, False, 100000)
    elif instructions == 'vfat':
        if len(sys.argv) < 3:
            print_red("Please provide the VFAT number")
            return
        initRegAddrs(parse_int(sys.argv[2]))
        subheading('Testing OH0 VFAT #%d' % parse_int(sys.argv[2]))
        regTest(REG_VFAT_CONTROL_REG, 0x1234, 0xffff, True, 10000)


def initRegAddrs(vfat_idx):
    global REG_CTP7_BOARD_ID
    global REG_OH1_FW
    global REG_OH1_VFAT_MASK
    global REG_VFAT_CONTROL_REG
    global REG_LINK_ENABLE_MASK
    REG_CTP7_BOARD_ID = get_node('BEFE.GEM.GEM_SYSTEM.BOARD_ID').address
    REG_LINK_ENABLE_MASK = get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.LINK_ENABLE_MASK').address
    #REG_OH1_FW = get_node('BEFE.GEM.OH.OH0.STATUS.FW.DATE').address
    #REG_OH1_VFAT_MASK = get_node('BEFE.GEM.OH.OH0.CONTROL.VFAT.SBIT_MASK').address
    REG_VFAT_CONTROL_REG = get_node('BEFE.GEM.OH.OH0.GEB.VFAT%d.VFAT_CHANNELS.CHANNEL0' % vfat_idx).address

def regTest(regAddress, initValue, regMask, doInitWrite, numIterations, rand_write_read=False):
    if (doInitWrite):
        wReg(regAddress, initValue)

    busErrors = 0
    valueErrors = 0


    timeStart = clock()
    chunkSize = 100000
    numChunks = numIterations / chunkSize

    for chunk in range(0, numChunks):
        for chi in range(0, chunkSize):
            if rand_write_read:
                initValue = random.getrandbits(32)
                wReg(regAddress, initValue)

            value = rReg(regAddress) & regMask
            if value != initValue & regMask:
                if value == 0xdeaddead & regMask:
                    busErrors += 1
                else:
                    valueErrors += 1
                    i = chunk * chunkSize + chi
                    print_red("Value error. Expected " + hex(initValue & regMask) + ", got " + hex(value) + " in iteration #" + str(i))

        print("Progress: %d / %d" % ((chunk+1)*chunkSize, numIterations))

    totalTime = clock() - timeStart

    print_cyan("Test finished " + str(numIterations) + " iterations in " + str(totalTime) + " seconds. Bus errors = " + str(busErrors) + ", value errors = " + str(valueErrors))

# freqDiv -- JTAG frequency expressed as a divider of 20MHz, so e.g. a value of 2 would give 10MHz, value of 10 would give 2MHz
def enableJtag(freqDiv=None):
    subheading('Disabling SCA ADC monitoring')
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.ADC_MONITORING.MONITORING_OFF'), 0x1)
    sleep(0.01)
    subheading('Enable JTAG module')
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.ENABLE'), 0x1)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.SHIFT_MSB'), 0x0)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.EXEC_ON_EVERY_TDO'), 0x0)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.NO_SCA_LENGTH_UPDATE'), 0x0)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.SHIFT_TDO_ASYNC'), 0x0)

    if freqDiv is not None:
        subheading('Setting JTAG CLK frequency to ' + str(20 / (freqDiv)) + 'MHz (divider value = ' + hex((freqDiv - 1) << 24) + ')')
        sendScaCommand(0x13, 0x90, 0x4, (freqDiv - 1) << 24, False)


def disableJtag():
    subheading('Disabling JTAG module')
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.ENABLE'), 0x0)
#    subheading('Enabling SCA ADC monitoring')
#    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.ADC_MONITORING.MONITORING_OFF'), 0x0)


# restoreIdle -- if True then will restore to IDLE state before doing anything else
# ir          -- instruction register, set it to None if it's not needed to shift the instruction register
# irLen       -- number of bits in the instruction register
# dr          -- data register, set it to None if it's not needed to shift the data register
# drLen       -- number of bits in the data register
# drRead      -- read the TDI during the data register shifting
def jtagCommand(restoreIdle, ir, irLen, dr, drLen, drRead):
    totalLen = 0
    if ir is not None:
        totalLen += irLen + 6       # instruction register length plus 6 TMS bits required to get to the IR shift state and back to IDLE
    if dr is not None:
        totalLen += drLen + 5       # data register length plus 5 TMS bits required to get to the DR shift state and back to IDLE
    if restoreIdle:
        totalLen += 6
    if totalLen > 128:
        raise ValueError('JTAG command request needs more than 128 bits -- not possible. Please break up your command into smaller pieces.')

    tms = 0
    tdo = 0
    len = 0
    readIdx = 0

    if restoreIdle:
        tms = 0b011111
        len = 6

    if ir is not None:
        tms |= 0b0011 << len         # go to IR SHIFT state
        len += 4
        tdo |= ir << len
        tms |= 0b1 << (irLen - 1 + len)  # exit IR shift
        len += irLen
        tms |= 0b01 << len    # update IR and go to IDLE
        len += 2

    if dr is not None:
        tms |= 0b001 << len    # go to DR SHIFT state
        len += 3
        readIdx = len
        tdo |= dr << len
        tms |= 0b1 << (drLen -1 + len) # exit DR shift
        len += drLen
        tms |= 0b01 << len     # update DR and go to IDLE
        len += 2


    debug('Length = ' + str(len))
    debug('TMS = ' + binary(tms, len))
    debug('TDO = ' + binary(tdo, len))
    debug('Read start index = ' + str(readIdx))

    debugCyan('Setting command length = ' + str(len))
    fw_len = len if len < 128 else 0 # in firmware 0 means 128 bits
    #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.NUM_BITS'), fw_len)
    wReg(ADDR_JTAG_LENGTH, fw_len)

    # ================= SENDING LENGTH COMMAND JUST FOR TEST!! ===================
    #debugCyan('Setting config registers: bit number = ' + hex(fw_len))
    #sendScaCommand(0x13, 0x80, 0x4, 0xc00 | (fw_len << 24), False) # TX falling edge, shift LSB first, and set length
    # ============================================================================

    #raw_input("press any key to send tms and tdo")

    debugCyan('Setting TMS 0 = ' + binary(tms & 0xffffffff, 32))
    #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TMS'), tms0)
    wReg(ADDR_JTAG_TMS, tms & 0xffffffff)

    debugCyan('Setting TDO 0 = ' + binary(tdo & 0xffffffff, 32))
    #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDO'), tdo0)
    wReg(ADDR_JTAG_TDO, tdo & 0xffffffff)

    if len > 32:
        tms = tms >> 32
        debugCyan('Setting TMS 1 = ' + binary(tms & 0xffffffff, 32))
        #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TMS'), tms1)
        wReg(ADDR_JTAG_TMS, tms & 0xffffffff)

        #raw_input("press any key to send the last TDO")

        tdo = tdo >> 32
        debugCyan('Setting TDO 1 = ' + binary(tdo & 0xffffffff, 32))
        #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDO'), tdo1)
        wReg(ADDR_JTAG_TDO, tdo & 0xffffffff)

    if len > 64:
        tms = tms >> 32
        debugCyan('Setting TMS 2 = ' + binary(tms & 0xffffffff, 32))
        #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TMS'), tms2)
        wReg(ADDR_JTAG_TMS, tms & 0xffffffff)

        tdo = tdo >> 32
        debugCyan('Setting TDO 2 = ' + binary(tdo & 0xffffffff, 32))
        #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDO'), tdo2)
        wReg(ADDR_JTAG_TDO, tdo & 0xffffffff)

    if len > 96:
        tms = tms >> 32
        debugCyan('Setting TMS 3 = ' + binary(tms & 0xffffffff, 32))
        #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TMS'), tms3)
        wReg(ADDR_JTAG_TMS, tms & 0xffffffff)

        tdo = tdo >> 32
        debugCyan('Setting TDO 3 = ' + binary(tdo & 0xffffffff, 32))
        #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDO'), tdo3)
        wReg(ADDR_JTAG_TDO, tdo & 0xffffffff)

    # ================= SENDING JTAG GO COMMAND JUST FOR TEST!! ===================
    #debugCyan('JTAG GO!')
    #sendScaCommand(0x13, 0xa2, 0x1, 0x0, False)
    # ============================================================================

    #raw_input("Press any key to read TDI...")

    if drRead:
        debugCyan('Read TDI 0')
        tdi = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI'))
        #tdi0_fast = parse_int(rReg(parse_int(ADDR_JTAG_TDI)))
        #print('normal tdi read = ' + hex(tdi0) + ', fast C tdi read = ' + hex(tdi0_fast) + ', parsed = ' + '{0:#010x}'.format(tdi0_fast))
        debug('tdi = ' + hex(tdi))

        if len > 32:
            debugCyan('Read TDI 1')
            tdi1 = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI'))
            tdi |= tdi1 << 32
            debug('tdi1 = ' + hex(tdi1))
            debug('tdi = ' + hex(tdi))

        if len > 64:
            debugCyan('Read TDI 2')
            tdi2 = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI'))
            tdi |= tdi2 << 64
            debug('tdi2 = ' + hex(tdi2))
            debug('tdi = ' + hex(tdi))

        if len > 96:
            debugCyan('Read TDI 3')
            tdi3 = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI'))
            tdi |= tdi3 << 96
            debug('tdi3 = ' + hex(tdi3))
            debug('tdi = ' + hex(tdi))

        readValue = (tdi >> readIdx) & (0xffffffffffffffffffffffffffffffff >> (128  - drLen))
        debug('Read pos = ' + str(readIdx))
        debug('Read = ' + hex(readValue))
        return readValue
    else:
        return 0


def sendScaCommand(sca_channel, sca_command, data_length, data, doRead):
    #print('fake send: channel ' + hex(sca_channel) + ', command ' + hex(sca_command) + ', length ' + hex(data_length) + ', data ' + hex(data) + ', doRead ' + str(doRead))
    #return

    d = data

    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD_CHANNEL'), sca_channel)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD_COMMAND'), sca_command)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD_LENGTH'), data_length)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD_DATA'), d)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD_EXECUTE'), 0x1)
    reply = 0
    if doRead:
        reply = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_RPY_DATA'))
    return reply

def checkStatus():
    rxReady       = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.READY'))
    criticalError = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.CRITICAL_ERROR'))
    return (rxReady == 1) and (criticalError == 0)

def check_bit(byteval,idx):
    return ((byteval&(1<<idx))!=0);

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
