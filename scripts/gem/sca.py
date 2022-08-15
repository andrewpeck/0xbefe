#!/usr/bin/env python

from common.rw_reg import *
from common.utils import *
from time import *
import array
import struct

SLEEP_BETWEEN_COMMANDS = 0.1
DEBUG = False
CTP7HOSTNAME = "eagle34"

class Virtex6Instructions:
    FPGA_ID     = 0x3C9
    USER_CODE   = 0x3C8
    SYSMON      = 0x3F7
    BYPASS      = 0x3FF
    CFG_IN      = 0x3C5
    CFG_OUT     = 0x3C4
    SHUTDN      = 0x3CD
    JPROG       = 0x3CB
    JSTART      = 0x3CC
    ISC_NOOP    = 0x3D4
    ISC_ENABLE  = 0x3D0
    ISC_PROGRAM = 0x3D1
    ISC_DISABLE = 0x3D6

class Artix7Instructions:
    FPGA_ID     = 0x9
    USER_CODE   = 0x8
    BYPASS      = 0x3f
    CFG_IN      = 0x5
    CFG_OUT     = 0x4
    SHUTDN      = 0xd
    JPROG       = 0xb
    JSTART      = 0xc
    ISC_NOOP    = 0x14
    ISC_ENABLE  = 0x10
    ISC_PROGRAM = 0x11
    ISC_DISABLE = 0x16


VIRTEX6_IR_LENGTH = 10
ARTIX7_IR_LENGTH = 6

ARTIX7_75T_FIRMWARE_SIZE = 3825768
ARTIX7_75T_FPGA_ID = 0x49c0
ARTIX7_200T_FPGA_ID = 0x13636093
VIRTEX6_FIRMWARE_SIZE = 5464972
VIRTEX6_FPGA_ID = 0x6424a093

FIRMWARE_SIZE = ARTIX7_75T_FIRMWARE_SIZE

ADDR_JTAG_LENGTH = None
ADDR_JTAG_TMS = None
ADDR_JTAG_TDO = None
ADDR_JTAG_TDI = None

def main():

    instructions = ""
    ohMask = 0
    ohList = []

    if len(sys.argv) < 3:
        print('Usage: sca.py <oh_mask> <instructions>')
        print('instructions:')
        print('  r:                  SCA reset will be done')
        print('  h:                  FPGA hard reset will be done')
        print('  hh:                 FPGA hard reset will be asserted and held')
        print('  fpga-id-virtex6:    Virtex6 FPGA ID will be read through JTAG')
        print('  fpga-id-artix7:     Artix7 FPGA ID will be read through JTAG')
        print('  sysmon:             Read FPGA sysmon data repeatedly')
        print('  program-fpga:       Program OH FPGA with a bitfile or an MCS file. Requires a parameter "bit" or "mcs" and a filename')
        print('  adc-read:           Reads all ADC channels')
        print('  adc-readv1:         Reads all ADC channels on v1 SCA chip (these chips should no longer be used in GEMs)')
        print('  compare-mcs-bit:    Compares an MCS file with a bitstream file (requires two more args: <mcs_filename> <bit_filename>)')
        print('  gpio-set-direction: Sets the GPIO direction, requires an additional argument <direction-mask> which is a 32 bit number where each bit represents a GPIO channel -- if a given bit is high it means that this GPIO channel will be set to OUTPUT mode, and otherwise it will be set to INPUT mode')
        print('  gpio-set-output:    Sets the GPIO output, requires an additional argument <output-data>, which is a 32 bit number representing the 32 GPIO channels state')
        print('  gpio-read-input:    Reads the GPIO input')
        return
    else:
        ohMask = parse_int(sys.argv[1])
        for i in range(0, 12):
            if check_bit(ohMask, i):
                ohList.append(i)
        instructions = sys.argv[2]

    parse_xml()
    initJtagRegAddrs()

    heading("Hola, I'm SCA controller tester :)")

    if 'r' not in instructions:
        if not checkScaStatus(ohList):
            exit()

    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.LINK_ENABLE_MASK'), ohMask)

    if instructions == 'r':
        subheading('Reseting the SCA')
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.MODULE_RESET'), 0x1)
        checkScaStatus(ohList)
    elif instructions == 'hh':
        sleep(0.01)
        subheading('Asserting FPGA Hard Reset (and keeping it in reset)')
        sendScaCommand(ohList, 0x2, 0x10, 0x4, 0x0, False)
    elif instructions == 'h':
        subheading('Issuing FPGA Hard Reset')
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.OH_FPGA_HARD_RESET'), 0x1)
    elif 'fpga-id' in instructions:
        enableJtag(ohMask)

        if 'virtex6' not in instructions and 'artix7' not in instructions:
            print("ERROR: cannot determine the FPGA type, please include the fpga type in the instruction e.g. fpga-id-virtex6 or fpga-id-artix7")
            return

        ir = Virtex6Instructions.FPGA_ID if 'virtex6' in instructions else Artix7Instructions.FPGA_ID
        irLen = VIRTEX6_IR_LENGTH if 'virtex6' in instructions else ARTIX7_IR_LENGTH
        expectedId = VIRTEX6_FPGA_ID if 'virtex6' in instructions else ARTIX7_200T_FPGA_ID

        errors = 0
        timeStart = clock()
        for i in range(1):
            value = jtagCommand(True, ir, irLen, 0x0, 32, ohList)
            for oh in ohList:
                print(('OH #%d FPGA ID= ' % oh) + hex(value[oh]))
                if value[oh] != expectedId:
                    errors += 1

        totalTime = clock() - timeStart
        print_cyan('Num errors = ' + str(errors) + ', time took = ' + str(totalTime))

        disableJtag()

    elif instructions == 'sysmon':
        enableJtag(ohMask, 2)

        while True:
            jtagCommand(True, Virtex6Instructions.SYSMON, 10, 0x04000000, 32, False)
            adc1 = jtagCommand(False, None, 0, 0x04010000, 32, ohList)
            adc2 = jtagCommand(False, None, 0, 0x04020000, 32, ohList)
            adc3 = jtagCommand(False, None, 0, 0x04030000, 32, ohList)
            jtagCommand(True, Virtex6Instructions.BYPASS, 10, None, 0, False)

            ohIdx = 0
            for oh in ohList:
                coreTemp = ((adc1[ohIdx] >> 6) & 0x3FF) * 503.975 / 1024.0 - 273.15
                volt1 = ((adc2[ohIdx] >> 6) & 0x3FF) * 3.0 / 1024.0
                volt2 = ((adc3[ohIdx] >> 6) & 0x3FF) * 3.0 / 1024.0

                #print_cyan('adc1 = ' + hex(adc1) + ', adc2 = ' + hex(adc2) + ', adc3 = ' + hex(adc3))
                print_cyan(('=== OH #%d ===' % oh) + 'Core temp = ' + str(coreTemp) + ', voltage #1 = ' + str(volt1) + ', voltage #2 = ' + str(volt2))
                ohIdx += 1

            sleep(0.5)

        disableJtag()

    elif instructions == 'program-fpga':
        if len(sys.argv) < 5:
            print('Usage: sca.py program-fpga <file-type> <filename>')
            print('file-type can be "mcs" or "bit"')
            return

        type = sys.argv[3]
        filename = sys.argv[4]

        if (type != "bit") and (type != "mcs"):
            print('Unrecognized type "' + type + '".. must be either "bit" or "mcs"')
            return

        if type != filename[-3:]:
            print("The type " + type + " doesn't match the file type, which is " + filename[-3:] + "... sorry, exiting..")
            return

        words = []
        if type == "mcs":
            print("Reading the MCS file...")
            bytes = readMcs(filename)
            if len(bytes) < FIRMWARE_SIZE:
                raise ValueError("MCS file is too short.. For Virtex6 we expect it to be " + str(FIRMWARE_SIZE) + " bytes long")

            print("Swapping bytes...")
            for i in range(0, FIRMWARE_SIZE / 4):
                words.append((bytes[i * 4 + 2] << 24) + (bytes[i * 4 + 3] << 16) + (bytes[i * 4] << 8) + (bytes[i * 4 + 1]))

        elif type == "bit":
            f = open(filename, "rb")
            f.read(119) # skip the header
            print("Reading the bit file")
            bitWords = []
            bitWords = struct.unpack('>{}I'.format(FIRMWARE_SIZE / 4), f.read(FIRMWARE_SIZE))
            print("reversing bits")

            # reverse the bits using a lookup table -- that's the fastest way
            bitReverseTable256 = [0x00, 0x80, 0x40, 0xC0, 0x20, 0xA0, 0x60, 0xE0, 0x10, 0x90, 0x50, 0xD0, 0x30, 0xB0, 0x70, 0xF0,
                                  0x08, 0x88, 0x48, 0xC8, 0x28, 0xA8, 0x68, 0xE8, 0x18, 0x98, 0x58, 0xD8, 0x38, 0xB8, 0x78, 0xF8,
                                  0x04, 0x84, 0x44, 0xC4, 0x24, 0xA4, 0x64, 0xE4, 0x14, 0x94, 0x54, 0xD4, 0x34, 0xB4, 0x74, 0xF4,
                                  0x0C, 0x8C, 0x4C, 0xCC, 0x2C, 0xAC, 0x6C, 0xEC, 0x1C, 0x9C, 0x5C, 0xDC, 0x3C, 0xBC, 0x7C, 0xFC,
                                  0x02, 0x82, 0x42, 0xC2, 0x22, 0xA2, 0x62, 0xE2, 0x12, 0x92, 0x52, 0xD2, 0x32, 0xB2, 0x72, 0xF2,
                                  0x0A, 0x8A, 0x4A, 0xCA, 0x2A, 0xAA, 0x6A, 0xEA, 0x1A, 0x9A, 0x5A, 0xDA, 0x3A, 0xBA, 0x7A, 0xFA,
                                  0x06, 0x86, 0x46, 0xC6, 0x26, 0xA6, 0x66, 0xE6, 0x16, 0x96, 0x56, 0xD6, 0x36, 0xB6, 0x76, 0xF6,
                                  0x0E, 0x8E, 0x4E, 0xCE, 0x2E, 0xAE, 0x6E, 0xEE, 0x1E, 0x9E, 0x5E, 0xDE, 0x3E, 0xBE, 0x7E, 0xFE,
                                  0x01, 0x81, 0x41, 0xC1, 0x21, 0xA1, 0x61, 0xE1, 0x11, 0x91, 0x51, 0xD1, 0x31, 0xB1, 0x71, 0xF1,
                                  0x09, 0x89, 0x49, 0xC9, 0x29, 0xA9, 0x69, 0xE9, 0x19, 0x99, 0x59, 0xD9, 0x39, 0xB9, 0x79, 0xF9,
                                  0x05, 0x85, 0x45, 0xC5, 0x25, 0xA5, 0x65, 0xE5, 0x15, 0x95, 0x55, 0xD5, 0x35, 0xB5, 0x75, 0xF5,
                                  0x0D, 0x8D, 0x4D, 0xCD, 0x2D, 0xAD, 0x6D, 0xED, 0x1D, 0x9D, 0x5D, 0xDD, 0x3D, 0xBD, 0x7D, 0xFD,
                                  0x03, 0x83, 0x43, 0xC3, 0x23, 0xA3, 0x63, 0xE3, 0x13, 0x93, 0x53, 0xD3, 0x33, 0xB3, 0x73, 0xF3,
                                  0x0B, 0x8B, 0x4B, 0xCB, 0x2B, 0xAB, 0x6B, 0xEB, 0x1B, 0x9B, 0x5B, 0xDB, 0x3B, 0xBB, 0x7B, 0xFB,
                                  0x07, 0x87, 0x47, 0xC7, 0x27, 0xA7, 0x67, 0xE7, 0x17, 0x97, 0x57, 0xD7, 0x37, 0xB7, 0x77, 0xF7,
                                  0x0F, 0x8F, 0x4F, 0xCF, 0x2F, 0xAF, 0x6F, 0xEF, 0x1F, 0x9F, 0x5F, 0xDF, 0x3F, 0xBF, 0x7F, 0xFF]

            #reversing the bit order
            for word in bitWords:
                words.append(bitReverseTable256[word & 0xff] << 24 | bitReverseTable256[(word >> 8) & 0xff] << 16 | bitReverseTable256[(word >> 16) & 0xff] << 8 | bitReverseTable256[(word >> 24) & 0xff])

            if len(words) < FIRMWARE_SIZE / 4:
                raise ValueError("Bit file is too short.. For Virtex6 we expect it to be " + str(FIRMWARE_SIZE) + " bytes long")

        numWords = FIRMWARE_SIZE / 4

        timeStart = clock()
        enableJtag(ohMask, 2)

        fpgaIds = jtagCommand(True, Virtex6Instructions.FPGA_ID, 10, 0x0, 32, ohList)
        sleep(0.0001)
        fpgaIdIdx = 0
        for oh in ohList:
            print('FPGA ID = ' + hex(fpgaIds[fpgaIdIdx]))
            fpgaIdIdx += 1
            #if fpgaIds[oh] != FPGA_ID:
            #    raise ValueError("Bad FPGA-ID (should be " + hex(FPGA_ID) + ")... Hands off...")

        jtagCommand(False, Virtex6Instructions.SHUTDN, 10, None, 0, False)

        # send 400 empty clocks
        wReg(ADDR_JTAG_LENGTH, 0x00)
        for i in range(0, 4):
            wReg(ADDR_JTAG_TMS, 0x00000000)
        for i in range(0, 12):
            wReg(ADDR_JTAG_TDO, 0x00000000)
        wReg(ADDR_JTAG_LENGTH, 0x10)
        wReg(ADDR_JTAG_TDO, 0x00000000)

        sleep(0.01)

        jtagCommand(False, Virtex6Instructions.JPROG, 10, None, 0, False)
        jtagCommand(False, Virtex6Instructions.ISC_NOOP, 10, None, 0, False)
        sleep(0.01)
        jtagCommand(False, Virtex6Instructions.ISC_ENABLE, 10, 0x00, 5, False)

        # 128 empty clocks
        wReg(ADDR_JTAG_LENGTH, 0x00)
        for i in range(0, 4):
            wReg(ADDR_JTAG_TMS, 0x00000000)
            wReg(ADDR_JTAG_TDO, 0x00000000)

        sleep(0.0005)

        jtagCommand(False, Virtex6Instructions.ISC_PROGRAM, 10, None, 0, False)
        sleep(0.001)

        print("sending data...")

        # send the data
        # optimization -- don't use the jtagCommand(), do this instead (looks messy, but it's way faster)
        #   1) enter a DR-shift state
        #   2) setup the TMS and length so that at the end of 32 bit shift it will update DR and go back to shift DR state
        #   3) stuff those bits in there only by calling set-TDO twice per 32bit word -- first with data and then with dummy zeros just to trigger it to send everything (including the extra TMS bits, which are after the 32 bit data word)
        #   4) after sending the last 32bit data word, do not enter back to shift-DR but just return to IDLE

        tms = 0b001
        tdo = 0b000
        wReg(ADDR_JTAG_LENGTH, 3)
        wReg(ADDR_JTAG_TMS, tms & 0xffffffff)
        wReg(ADDR_JTAG_TDO, tdo & 0xffffffff)

        tms = 0b001011 << 31
        wReg(ADDR_JTAG_LENGTH, 37)
        wReg(ADDR_JTAG_TMS, tms & 0xffffffff)
        tms = tms >> 32
        wReg(ADDR_JTAG_TMS, tms & 0xffffffff)

        # send the first byte so that the LENGTH is updated
        wReg(ADDR_JTAG_TDO, words[0])
        wReg(ADDR_JTAG_TDO, 0x0)

        # enter optimized mode that executes JTAG_GO on every TDO shift and doesn't update the LENGTH with every JTAG_GO
        sleep(0.001)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.EXEC_ON_EVERY_TDO'), 0x1)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.NO_SCA_LENGTH_UPDATE'), 0x1)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.SHIFT_TDO_ASYNC'), 0x1)

        cnt = 0
        for i in range(1, numWords - 1):
            wReg(ADDR_JTAG_TDO, words[i])
            #wReg(ADDR_JTAG_TDO, 0x0) # not needed when EXEC_ON_EVERY_TDO is set to 0x1
            #jtagCommand(False, None, 0, (bytes[i*4 + 2] << 24) + (bytes[i*4 + 3] << 16) + (bytes[i*4] << 8) + (bytes[i*4 + 1]), 32, False)
            cnt += 1
            if cnt >= 10000:
                print("word " + str(i) + " out of " + str(numWords))
                cnt = 0

        # exit the optimized mode and send the last word (also exit the FSM to IDLE)
        sleep(0.01)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.EXEC_ON_EVERY_TDO'), 0x0)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.NO_SCA_LENGTH_UPDATE'), 0x0)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.SHIFT_TDO_ASYNC'), 0x0)
        tms = 0b011 << 31 #go back to idle and don't enter DR shift again
        wReg(ADDR_JTAG_LENGTH, 34)
        wReg(ADDR_JTAG_TMS, tms & 0xffffffff)
        tms = tms >> 32
        wReg(ADDR_JTAG_TMS, tms & 0xffffffff)
        wReg(ADDR_JTAG_TDO, words[i]) #send the last word
        wReg(ADDR_JTAG_TDO, 0x0)


        print("DONE sending data")

        jtagCommand(False, Virtex6Instructions.ISC_DISABLE, 10, None, 0, False)
        # 128 empty clocks
        wReg(ADDR_JTAG_LENGTH, 0x00)
        for i in range(0, 4):
            wReg(ADDR_JTAG_TMS, 0x00000000)
            wReg(ADDR_JTAG_TDO, 0x00000000)

        sleep(0.0001)

        jtagCommand(False, Virtex6Instructions.BYPASS, 10, None, 0, False)
        jtagCommand(False, Virtex6Instructions.JSTART, 10, None, 0, False)

        # 128 empty clocks
        wReg(ADDR_JTAG_LENGTH, 0x00)
        for i in range(0, 4):
            wReg(ADDR_JTAG_TMS, 0x00000000)
            wReg(ADDR_JTAG_TDO, 0x00000000)

        sleep(0.0005)

        jtagCommand(True, Virtex6Instructions.BYPASS, 10, None, 0, False)

        print("FPGA programming DONE!!")

        disableJtag()

        totalTime = clock() - timeStart
        print_cyan('time took to program = ' + str(totalTime))

    elif instructions == 'test1':
        timeStart = clock()
        nn = get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI')
        for i in range(0, 1000000):
            #print(str(i))
            #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD_CHANNEL'), 0x02)
            #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD_COMMAND'), 0x10)
            #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD_LENGTH'), 0x4)
            #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD_DATA'), 0x0)

            #read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI'))
            wReg(ADDR_JTAG_TMS, 0x00000000)

            #sleep(0.01)
            #print('execute')
            #write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD_EXECUTE'), 0x1)
        totalTime = clock() - timeStart
        print_cyan('time took = ' + str(totalTime))

    elif instructions == 'test2':
        timeStart = clock()
        nn = get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI')
        for i in range(0, 10000):
            print(str(i))
            sleep(0.001)
            write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.FPGA_HARD_RESET'), 0x1)

    elif instructions == 'adc-read':
        sleep(0.1)

        # enable the current source on channels 13-17 (GE2/1 OHv2 PT1000)
        #sendScaCommand(ohList, 0x14, 0x60, 0x4, 0x00a00300, False)
        sendScaCommand(ohList, 0x14, 0x60, 0x4, 0x00e00300, False)

        for ch in range(32):
#            if ch == 6 or ch == 7:
#                continue

            sendScaCommand(ohList, 0x14, 0x50, 0x4, ch << 24, False)
            results = sendScaCommand(ohList, 0x14, 0x02, 0x4, 1 << 24, True)
            for oh in range(len(results)):
                #print results[oh], results[oh] >> 24, results[oh] >> 8
                #print results[oh] >> 24 + results[oh] >> 8 & 0xff00
                res = (results[oh] >> 24) + ((results[oh] >> 8) & 0xff00)
                if (res > 0xfff):
                    print_red("ERROR: ADC returned a reading above 0xfff!!")
                res_mv = ((1.0 / 0xfff) * float(res)) * 1000
                res_x4_v = (res_mv * 4) / 1000.0
                print("Channel %d OH %d: %d counts (%s) = %fmV, x4 = %fV" % (ch, oh, res, hex(res), res_mv, res_x4_v))
                #print "curr = %s" % hex(curr[oh])
            sleep(0.001)

    elif instructions == 'adc-read-v1':
        sleep(0.1)

        for ch in range(32):
            sendScaCommand(ohList, 0x14, 0x30, 0x4, ch << 24, False)
            results = sendScaCommand(ohList, 0x14, 0xb2, 0x4, 0, True)
            for oh in range(len(results)):
                res = ((results[oh] >> 24) + ((results[oh] >> 8) & 0xff00)) & 0xfff
                if (res > 0xfff):
                    print_red("ERROR: ADC returned a reading above 0xfff!!")
                res_mv = ((1.0 / 0xfff) * float(res)) * 1000
                print("Channel %d OH %d: %d counts (%s) = %fmV" % (ch, oh, res, hex(res), res_mv))
            sleep(0.001)

    elif instructions == 'compare-mcs-bit':
        if len(sys.argv) < 5:
            print("Usage: sca.py compare-mcs-bit <mcs_filename> <bit_filename>")
            return

        mcsFilename = sys.argv[3]
        bitFilename = sys.argv[4]
        mcsBytes = readMcs(mcsFilename)

        bitBytes = array.array('L')
        f = open(bitFilename, "rb")
        f.read(119)
        print("reading")
        bitWords = []
        bitWords = struct.unpack('>{}I'.format(FIRMWARE_SIZE / 4), f.read(FIRMWARE_SIZE))
        print("reversing bits")
        timeStart = clock()

        BitReverseTable256 = [0x00, 0x80, 0x40, 0xC0, 0x20, 0xA0, 0x60, 0xE0, 0x10, 0x90, 0x50, 0xD0, 0x30, 0xB0, 0x70, 0xF0,
                              0x08, 0x88, 0x48, 0xC8, 0x28, 0xA8, 0x68, 0xE8, 0x18, 0x98, 0x58, 0xD8, 0x38, 0xB8, 0x78, 0xF8,
                              0x04, 0x84, 0x44, 0xC4, 0x24, 0xA4, 0x64, 0xE4, 0x14, 0x94, 0x54, 0xD4, 0x34, 0xB4, 0x74, 0xF4,
                              0x0C, 0x8C, 0x4C, 0xCC, 0x2C, 0xAC, 0x6C, 0xEC, 0x1C, 0x9C, 0x5C, 0xDC, 0x3C, 0xBC, 0x7C, 0xFC,
                              0x02, 0x82, 0x42, 0xC2, 0x22, 0xA2, 0x62, 0xE2, 0x12, 0x92, 0x52, 0xD2, 0x32, 0xB2, 0x72, 0xF2,
                              0x0A, 0x8A, 0x4A, 0xCA, 0x2A, 0xAA, 0x6A, 0xEA, 0x1A, 0x9A, 0x5A, 0xDA, 0x3A, 0xBA, 0x7A, 0xFA,
                              0x06, 0x86, 0x46, 0xC6, 0x26, 0xA6, 0x66, 0xE6, 0x16, 0x96, 0x56, 0xD6, 0x36, 0xB6, 0x76, 0xF6,
                              0x0E, 0x8E, 0x4E, 0xCE, 0x2E, 0xAE, 0x6E, 0xEE, 0x1E, 0x9E, 0x5E, 0xDE, 0x3E, 0xBE, 0x7E, 0xFE,
                              0x01, 0x81, 0x41, 0xC1, 0x21, 0xA1, 0x61, 0xE1, 0x11, 0x91, 0x51, 0xD1, 0x31, 0xB1, 0x71, 0xF1,
                              0x09, 0x89, 0x49, 0xC9, 0x29, 0xA9, 0x69, 0xE9, 0x19, 0x99, 0x59, 0xD9, 0x39, 0xB9, 0x79, 0xF9,
                              0x05, 0x85, 0x45, 0xC5, 0x25, 0xA5, 0x65, 0xE5, 0x15, 0x95, 0x55, 0xD5, 0x35, 0xB5, 0x75, 0xF5,
                              0x0D, 0x8D, 0x4D, 0xCD, 0x2D, 0xAD, 0x6D, 0xED, 0x1D, 0x9D, 0x5D, 0xDD, 0x3D, 0xBD, 0x7D, 0xFD,
                              0x03, 0x83, 0x43, 0xC3, 0x23, 0xA3, 0x63, 0xE3, 0x13, 0x93, 0x53, 0xD3, 0x33, 0xB3, 0x73, 0xF3,
                              0x0B, 0x8B, 0x4B, 0xCB, 0x2B, 0xAB, 0x6B, 0xEB, 0x1B, 0x9B, 0x5B, 0xDB, 0x3B, 0xBB, 0x7B, 0xFB,
                              0x07, 0x87, 0x47, 0xC7, 0x27, 0xA7, 0x67, 0xE7, 0x17, 0x97, 0x57, 0xD7, 0x37, 0xB7, 0x77, 0xF7,
                              0x0F, 0x8F, 0x4F, 0xCF, 0x2F, 0xAF, 0x6F, 0xEF, 0x1F, 0x9F, 0x5F, 0xDF, 0x3F, 0xBF, 0x7F, 0xFF]

        bitWordsReversed = []
        for word in bitWords:
            #bitWordsReversed.append(sum(1<<(31-i) for i in range(32) if word>>i&1))
            bitWordsReversed.append(BitReverseTable256[word & 0xff] << 24 | BitReverseTable256[(word >> 8) & 0xff] << 16 | BitReverseTable256[(word >> 16) & 0xff] << 8 | BitReverseTable256[(word >> 24) & 0xff])

        totalTime = clock() - timeStart
        print_cyan('time took to program = ' + str(totalTime))

        #bitBytes.fromfile(f, 30)
        f.close()

        # for i in range(0, 30):
        #     #print(hex(bitBytes[i]))
        #     print(hex(bitWordsReversed[i]))

        print("comparing bytes")
        errors = 0
        for i in range(0, FIRMWARE_SIZE / 4):
            if (mcsBytes[i * 4 + 2] << 24) + (mcsBytes[i * 4 + 3] << 16) + (mcsBytes[i * 4] << 8) + (mcsBytes[i * 4 + 1]) != bitWordsReversed[i]:
                errors += 1
                print("Ooops, bytes #%d are not equal : " % i + hex(mcsBytes[i]) + ", " + hex(bitBytes[i]))
                sleep(0.5)

        print("Num errors: " + str(errors))
    elif instructions == 'gpio-set-direction':
        if len(sys.argv) < 4:
            print('Usage: sca.py gpio-set-direction <direction-mask>')
            print('direction-mask is a 32 bit number where each bit represents a GPIO channel -- if a given bit is high it means that this GPIO channel will be set to OUTPUT mode, and otherwise it will be set to INPUT mode')
            return
        directionMask = parse_int(sys.argv[3])

        sleep(0.01)
        subheading('Setting the GPIO direction mask to ' + hex(directionMask))
        sendScaCommand(ohList, 0x2, 0x20, 0x4, directionMask, False)
    elif instructions == 'gpio-set-output':
        if len(sys.argv) < 4:
            print('Usage: sca.py gpio-set-output <output-data>')
            print('output-data is a 32 bit number representing the 32 GPIO channels state')
            return
        outputData = parse_int(sys.argv[3])

        sleep(0.01)
        subheading('Setting the GPIO output to ' + hex(outputData))
        sendScaCommand(ohList, 0x2, 0x10, 0x4, outputData, False)
    elif instructions == 'gpio-read-input':
        sleep(0.01)
        subheading('Reading the GPIO input')
        readData = sendScaCommand(ohList, 0x2, 0x1, 0x1, 0x0, True)
        idx = 0
        for oh in ohList:
            print('OH %d  GPIO Input = ' % (oh) + hex(readData[idx]))
            idx += 1


def initJtagRegAddrs():
    global ADDR_JTAG_LENGTH
    global ADDR_JTAG_TMS
    global ADDR_JTAG_TDO
    global ADDR_JTAG_TDI
    ADDR_JTAG_LENGTH = get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.NUM_BITS').address
    ADDR_JTAG_TMS = get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TMS').address
    ADDR_JTAG_TDO = get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDO').address
    #ADDR_JTAG_TDI = get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI').address

# freqDiv -- JTAG frequency expressed as a divider of 20MHz, so e.g. a value of 2 would give 10MHz, value of 10 would give 2MHz
def enableJtag(ohMask, freqDiv=None):
    sleep(0.01)
    subheading('Enable JTAG module with mask ' + hex(ohMask))
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.ENABLE_MASK'), ohMask)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.SHIFT_MSB'), 0x0)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.EXEC_ON_EVERY_TDO'), 0x0)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.NO_SCA_LENGTH_UPDATE'), 0x0)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.SHIFT_TDO_ASYNC'), 0x0)

    if freqDiv is not None:
        subheading('Setting JTAG CLK frequency to ' + str(20 / (freqDiv)) + 'MHz (divider value = ' + hex((freqDiv - 1) << 24) + ')')
        ohList = []
        for i in range(0, 12):
            if check_bit(ohMask, i):
                ohList.append(i)
        sendScaCommand(ohList, 0x13, 0x90, 0x4, (freqDiv - 1) << 24, False)


def disableJtag():
    subheading('Disabling JTAG module')
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.ENABLE_MASK'), 0x0)
#    subheading('Enabling SCA ADC monitoring')
#    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.ADC_MONITORING.MONITORING_OFF'), 0x0)


# restoreIdle  -- if True then will restore to IDLE state before doing anything else
# ir           -- instruction register, set it to None if it's not needed to shift the instruction register
# irLen        -- number of bits in the instruction register
# dr           -- data register, set it to None if it's not needed to shift the data register
# drLen        -- number of bits in the data register
# drReadOhList -- read the TDI during the data register shifting from this list of OHs
def jtagCommand(restoreIdle, ir, irLen, dr, drLen, drReadOhList):
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
        tms |= 0b1 << (drLen - 1 + len) # exit DR shift
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

    readValues = []

    if drReadOhList == False:
        return readValues

    for i in drReadOhList:
        debugCyan('Read TDI 0')
        tdi = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI_OH%d' % i))
        #tdi0_fast = parse_int(rReg(parse_int(ADDR_JTAG_TDI)))
        #print('normal tdi read = ' + hex(tdi0) + ', fast C tdi read = ' + hex(tdi0_fast) + ', parsed = ' + '{0:#010x}'.format(tdi0_fast))
        debug('tdi = ' + hex(tdi))

        if len > 32:
            debugCyan('Read TDI 1')
            tdi1 = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI_OH%d' % i))
            tdi |= tdi1 << 32
            debug('tdi1 = ' + hex(tdi1))
            debug('tdi = ' + hex(tdi))

        if len > 64:
            debugCyan('Read TDI 2')
            tdi2 = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI_OH%d' % i))
            tdi |= tdi2 << 64
            debug('tdi2 = ' + hex(tdi2))
            debug('tdi = ' + hex(tdi))

        if len > 96:
            debugCyan('Read TDI 3')
            tdi3 = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI_OH%d' % i))
            tdi |= tdi3 << 96
            debug('tdi3 = ' + hex(tdi3))
            debug('tdi = ' + hex(tdi))

        readValue = (tdi >> readIdx) & (0xffffffffffffffffffffffffffffffff >> (128  - drLen))
        readValues.append(readValue)
        debug('Read pos = ' + str(readIdx))
        debug('Read = ' + hex(readValue))
    return readValues


def sendScaCommand(ohList, sca_channel, sca_command, data_length, data, doRead):
    #print('fake send: channel ' + hex(sca_channel) + ', command ' + hex(sca_command) + ', length ' + hex(data_length) + ', data ' + hex(data) + ', doRead ' + str(doRead))
    #return

    d = data

    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_CHANNEL'), sca_channel)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_COMMAND'), sca_command)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_LENGTH'), data_length)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_DATA'), d)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_EXECUTE'), 0x1)
    sleep(0.00015) # max ADC conversion time
    reply = []
    if doRead:
        for i in ohList:
            reply.append(read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_REPLY_OH%d.SCA_RPY_DATA' % i)))
    return reply

def check_bit(byteval, idx):
    return ((byteval & (1 << idx)) != 0)

def checkScaStatus(ohList):
    rxReady       = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.READY'))
    criticalError = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.CRITICAL_ERROR'))

    statusGood = True
    for i in ohList:
        if not check_bit(rxReady, i):
            print_red("OH #%d is not ready: RX ready = %d, critical error = %d" % (i, (rxReady >> i) & 0x1, (criticalError >> i) & 0x1))
            statusGood = False

    return statusGood

def resetSca():
    # reset SCA
    write_reg('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.MODULE_RESET', 1)

def debug(string):
    if DEBUG:
        print('DEBUG: ' + string)

def debugCyan(string):
    if DEBUG:
        print_cyan('DEBUG: ' + string)

if __name__ == '__main__':
    main()
