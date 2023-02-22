#!/usr/bin/env python

from common.rw_reg import *
from time import *
import array
import struct
import subprocess
import math

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

CXP_IDX = 0
NUM_ITER = 500
LOSS_THRESH_DB = -1.5

REF_POWER_CXP0 = [743, 895, 797, 825, 704, 873, 789, 879, 803, 794, 982, 904]
REF_POWER_CXP1 = [0] * 12
REF_POWER_CXP2 = [724, 825, 933, 729, 820, 987, 854, 813, 882, 788, 785, 728]

REF_POWER = [REF_POWER_CXP0, REF_POWER_CXP1, REF_POWER_CXP2]

MGT_TX_CHAN_CXP0 = [1, 3, 5, 0, 2, 4, 10, 8, 6, 11, 9, 7]

def main():

    os.system("rawi2c /dev/i2c-2 w 0x54 127 1 > /dev/null")
    os.system("rawi2c /dev/i2c-3 w 0x54 127 1 > /dev/null")
    os.system("rawi2c /dev/i2c-4 w 0x54 127 1 > /dev/null")

    cableType = ""

    if len(sys.argv) < 2:
        print('Usage: ge21_fiber_test.py <cable_type> [params_specific_to_type]')
        print('Cable types:')
        print('  c2: tests the C2 cable, no extra parameters are needed -- the C2 should be connected to CTP7 on one side, and to a 12 channel loopback on the other side')
        print('  c6: tests the C6 cable, this requires 2 parameters -- the number of the cable plugged in to the transmitters, and the number of the cable plugged in to the receivers, so e.g.: ge21_fiber_test.py c6 2 1')
        return
    else:
        cableType = sys.argv[1]

    if cableType == "c2":
        c2Power()
        c2Mapping()
    if cableType == "c6":
        if len(sys.argv) < 4:
            print("For C6 cable test you have to provide the TX cable number and the RX cable number that are currently connected (read help for more info)")
            exit()
        txCableIdx = int(sys.argv[2])
        rxCableIdx = int(sys.argv[3])
        c6Power(txCableIdx, rxCableIdx)
        c6Mapping(txCableIdx, rxCableIdx)
    else:
        print("Unrecognized cable type: %s" % cableType)

def c2Mapping():
    heading("C2 cable mapping test...")
    parse_xml()

    for oh in range(4):
        write_reg(get_node("BEFE.GEM.GEM_SYSTEM.TESTS.GBT_LOOPBACK_EN"), 0)
        write_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.CTRL.OH_SELECT"), oh)
        write_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.CTRL.RESET"), 1)
        write_reg(get_node("BEFE.GEM.GEM_SYSTEM.TESTS.GBT_LOOPBACK_EN"), 1)
        sleep(0.1)
        for gbt in range(3):
            locked = read_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_0.PRBS_LOCKED" % gbt))
            wordCnt = read_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_0.MEGA_WORD_CNT" % gbt))
            errCnt = read_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_0.ERROR_CNT" % gbt))
            # make sure there are no errors
            if (locked == 0) or (wordCnt < 3) or (errCnt > 0):
                print("ERROR: loopback counters are showing a problem on OH %d GBT %d before MGT reset. Locked = %d, mega word cnt = %d, err cnt = %d" % (oh, gbt, locked, wordCnt, errCnt))
                print("Call Evaldas...")
                exit()
            # reset the TX MGT and check if we see errors on the expected channel
            linkNum = (oh * 3) + gbt
            txMgtChan = MGT_TX_CHAN_CXP0[linkNum]
            write_reg(get_node("BEFE.GEM.OPTICAL_LINKS.MGT_CHANNEL_%d.RESET.TX_RESET" % txMgtChan), 1)
            sleep(0.1)
            locked = read_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_0.PRBS_LOCKED" % gbt))
            wordCnt = read_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_0.MEGA_WORD_CNT" % gbt))
            errCnt = read_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_0.ERROR_CNT" % gbt))
            # make sure there are some errors on the expected channel
            if (locked == 0) or (wordCnt < 3) or (errCnt == 0):
                print("ERROR: loopback counters are not showing errors after TX MGT reset on OH %d GBT %d. Locked = %d, mega word cnt = %d, err cnt = %d" % (oh, gbt, locked, wordCnt, errCnt))
                print("!!!!!!!!!!!!!!!! MAPPING TEST FAILED !!!!!!!!!!!!!!!!")
                exit()

    print("")
    print("================================================================================")
    print("MAPPING TEST PASSED")

def c2Power():
    heading("C2 cable power loss test...")

    refPower = REF_POWER[CXP_IDX]
    rxPower, lossDBm, failedChannels = readPowerLoss(CXP_IDX, NUM_ITER, refPower, LOSS_THRESH_DB)

    readStr = ""
    refStr = ""
    lossStr = ""
    for ch in range(12):
        readStr += "%d " % rxPower[ch]
        refStr += "%d " % refPower[ch]
        lossStr += "%.2f " % (lossDBm[ch])

    print("Power reading:")
    print(readStr)

    print("Reference power:")
    print(refStr)

    print("Loss over the test cable (dB):")
    print(lossStr)

    print("===================================================================")
    if len(failedChannels) == 0:
        print("TEST PASSED")
    else:
        print("!!!!!!!! TEST FAILED !!!!!!!!")
        print("Failed channels:")
        for ch in failedChannels:
            print("%d" % ch)

def c6Power(txCableNum, rxCableNum):
    heading("C6 cable power loss test... TX cable num = %d, RX cable num = %d" % (txCableNum, rxCableNum))
    refPower = REF_POWER[CXP_IDX]
    rxPower, lossDBm, failedChannels = readPowerLoss(CXP_IDX, NUM_ITER, refPower, LOSS_THRESH_DB)

    channelsToTest = []
    if txCableNum == 1 and rxCableNum == 1:
        channelsToTest = [0, 1, 2, 3, 4, 6]
    elif txCableNum == 2 and rxCableNum == 1:
        channelsToTest = [5, 7]
    elif txCableNum == 2 and rxCableNum == 2:
        channelsToTest = [0, 1, 2, 3]
    else:
        print("Invalid combination of TX and RX cable numbers.. You can only test 1-1, 1-2, and 2-2 combinations")
        exit()

    readStr = ""
    refStr = ""
    lossStr = ""
    failedChannels = []
    for ch in channelsToTest:
        readStr += "%d " % rxPower[ch]
        refStr += "%d " % refPower[ch]
        lossStr += "%.2f " % (lossDBm[ch])
        if lossDBm[ch] < LOSS_THRESH_DB:
            failedChannels.append(ch)

    print("Power reading:")
    print(readStr)

    print("Reference power:")
    print(refStr)

    print("Loss over the test cable (dB):")
    print(lossStr)

    print("===================================================================")
    if len(failedChannels) == 0:
        print("TEST PASSED")
    else:
        print("!!!!!!!! TEST FAILED !!!!!!!!")
        print("Failed channels:")
        for ch in failedChannels:
            print("%d" % ch)

def c6Mapping(txCableNum, rxCableNum):
    heading("C6 cable mapping test... TX cable num = %d, RX cable num = %d" % (txCableNum, rxCableNum))

    txChannels = []
    rxChannels = []
    if txCableNum == 1 and rxCableNum == 1:
        txChannels = [0, 1, 2, 3, 11, 10]
        rxChannels = [0, 1, 2, 3, 4, 6]
    elif txCableNum == 2 and rxCableNum == 1:
        txChannels = [11, 10]
        rxChannels = [5, 7]
    elif txCableNum == 2 and rxCableNum == 2:
        txChannels = [0, 1, 2, 3]
        rxChannels = [0, 1, 2, 3]
    else:
        print("Invalid combination of TX and RX cable numbers.. You can only test 1-1, 1-2, and 2-2 combinations")
        exit()

    parse_xml()

    for i in range(len(txChannels)):
        tx = txChannels[i]
        rx = rxChannels[i]
        rxOh = rx / 3
        rxGbt = rx % 3

        write_reg(get_node("BEFE.GEM.GEM_SYSTEM.TESTS.GBT_LOOPBACK_EN"), 0)
        write_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.CTRL.OH_SELECT"), rxOh)
        write_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.CTRL.RESET"), 1)
        write_reg(get_node("BEFE.GEM.GEM_SYSTEM.TESTS.GBT_LOOPBACK_EN"), 1)
        sleep(0.1)

        locked = read_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_0.PRBS_LOCKED" % rxGbt))
        wordCnt = read_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_0.MEGA_WORD_CNT" % rxGbt))
        errCnt = read_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_0.ERROR_CNT" % rxGbt))
        # make sure there are no errors
        if (locked == 0) or (wordCnt < 3) or (errCnt > 0):
            print("ERROR: loopback counters are showing a problem on OH %d GBT %d before MGT reset. Locked = %d, mega word cnt = %d, err cnt = %d" % (rxOh, rxGbt, locked, wordCnt, errCnt))
            print("Call Evaldas...")
            exit()
        # reset the TX MGT and check if we see errors on the expected channel
        txMgtChan = MGT_TX_CHAN_CXP0[tx]
        write_reg(get_node("BEFE.GEM.OPTICAL_LINKS.MGT_CHANNEL_%d.RESET.TX_RESET" % txMgtChan), 1)
        sleep(0.1)
        locked = read_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_0.PRBS_LOCKED" % rxGbt))
        wordCnt = read_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_0.MEGA_WORD_CNT" % rxGbt))
        errCnt = read_reg(get_node("BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_0.ERROR_CNT" % rxGbt))
        # make sure there are some errors on the expected channel
        if (locked == 0) or (wordCnt < 3) or (errCnt == 0):
            print("ERROR: loopback counters are not showing errors after TX MGT reset on OH %d GBT %d. Locked = %d, mega word cnt = %d, err cnt = %d" % (rxOh, rxGbt, locked, wordCnt, errCnt))
            print("!!!!!!!!!!!!!!!! MAPPING TEST FAILED !!!!!!!!!!!!!!!!")
            exit()

    print("")
    print("================================================================================")
    print("MAPPING TEST PASSED")

#reads CXP power, and returns 3 arrays: rxPower (uW), loss (dB), failedChannels. Requires refPower and lossThresholdDb to be passed as parameters.
def readPowerLoss(cxpIdx, numIter, refPower, lossThresholdDb):
    rxPower = readCxpRxPower(cxpIdx, numIter)

    refPowerDBm = []
    rxPowerDBm = []
    lossDBm = []
    failedChannels = []
    for i in range(12):
        if rxPower[i] == 0:
            rxPowerDBm.append(-1000)
        else:
            rxPowerDBm.append(10.0 * math.log10(float(rxPower[i]) / 1000.0))
        refPowerDBm.append(10.0 * math.log10(float(refPower[i]) / 1000.0))
        lossCh = rxPowerDBm[i] - refPowerDBm[i]
        lossDBm.append(lossCh)
        if lossCh < lossThresholdDb:
            failedChannels.append(i)

    return rxPower, lossDBm, failedChannels

def readCxpRxPower(cxpIdx, numIter=1):
    power = [-1] * 12 * numIter

    for i in range(0, numIter):
        p = subprocess.Popen(["rawi2c", "/dev/i2c-%d" % (cxpIdx + 2), "r", "0x54", "206", "24"], stdout=subprocess.PIPE)
        out = p.communicate()
        res = out[0].split(" ")
        for ch in range(12):
            ch_msb_idx = 5 + (11 - ch) * 2
            ch_lsb_idx = 6 + (11 - ch) * 2
            ch_msb = str(res[ch_msb_idx])
            ch_lsb = str(res[ch_lsb_idx])
            ch_pwr = "0x" + ch_msb + ch_lsb
            power[i * 12 + ch] = int(ch_pwr, 0) / 10
            # print "iter %d ch %d = %d" % (i, ch, int(ch_pwr,0)/10)

    ret = [0] * 12
    # min = [9999, 9999, 9999, 9999, 9999]
    # max = [0, 0, 0, 0, 0]
    for i in range(0, numIter):
        for j in range(12):
            ret[j] += power[i * 12 + j]
            # if power[i*5+j] < min[j]:
            #     min[j] = power[i*5+j]
            # if power[i*5+j] > max[j]:
            #     max[j] = power[i*5+j]

    for j in range(12):
        ret[j] = ret[j] / numIter

    # print min
    # print max
    # print ret

    return ret

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

def print_green(string):
    print Colors.GREEN
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
