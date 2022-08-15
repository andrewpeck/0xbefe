#!/usr/bin/env python

from common.rw_reg import *
from common.utils import *
from time import *
import array
import struct
import subprocess

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

RX_POWER_THRESH_UW = 100

VFAT_TO_GBT_MAP = {0: 1, 9: 2, 14: 0}
VFAT_CHIP_IDS = {0: 0x1861, 9: 0x1877, 14: 0x1872}

def main():

    os.system("rawi2c /dev/i2c-2 w 0x54 127 1 > /dev/null")
    os.system("rawi2c /dev/i2c-3 w 0x54 127 1 > /dev/null")
    os.system("rawi2c /dev/i2c-4 w 0x54 127 1 > /dev/null")

#    subprocess.call(["rawi2c", "/dev/i2c-2", "w", "0x54", "127", "1", ">", "/dev/null"])
#    subprocess.call(["rawi2c", "/dev/i2c-3", "w", "0x54", "127", "1", ">", "/dev/null"])
#    subprocess.call(["rawi2c", "/dev/i2c-4", "w", "0x54", "127", "1", ">", "/dev/null"])

    if "-oh" not in sys.argv:
        printHelp()
        return

    oh = parse_int(sys.argv[sys.argv.index("-oh") + 1])
    performMapping = "-m" in sys.argv

    heading("RX power measurement for OH #%d" % oh)
    rxPower = readOhRxPower(oh, 100)
    for gbt in range(0, 3):
        col = Colors.RED
        if rxPower[gbt] > RX_POWER_THRESH_UW:
            col = Colors.GREEN
        print("%sGBT%d RX power: %duW%s" % (col, gbt, rxPower[gbt], Colors.ENDC))

    for trig in range(0, 2):
        col = Colors.RED
        if rxPower[3 + trig] > RX_POWER_THRESH_UW:
            col = Colors.GREEN
        print("%sTRIG%d RX power: %duW%s" % (col, trig, rxPower[3 + trig], Colors.ENDC))

    if performMapping:

        heading("Fiber mapping test on OH #%d" % oh)
        parse_xml()
        # check GBT ready
        for gbt in range(0, 3):
            gbtReady = read_reg(get_node("BEFE.GEM.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt)))
            if gbtReady != 1:
                print_red("GBT #%d is not locked! Abort.." % gbt)
                return

        write_reg(get_node("BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET"), 1)
        sleep(0.1)

        for vfat, id in VFAT_CHIP_IDS.iteritems():
            idEnc = read_reg(get_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.HW_CHIP_ID" % (oh, vfat)))
            if idEnc == 0xdeaddead:
                print_red("Unable to read the chip ID of VFAT #%d. Abort.." % vfat)
                return
            idDec = decodeVfatChipId(idEnc)
            if idDec == -1:
                print_red("Unable to decode the chip ID for VFAT %d. Abort.." % vfat)

            if idDec != id:
                print_red("The chip ID of VFAT #%d corresponding to GBT #%d did not match the expected chip ID. This indicates a fiber mapping problem. Expected ID = %d, read ID = %d. Please check that the fibers are plugged in correctly." % (vfat, VFAT_TO_GBT_MAP[vfat], id, idDec))
                return

        print_green("Fiber mapping test was successful")

def printHelp():
    print("This script tests fiber connectivity with GE1/1 OH by reading RX power on the CTP7 on the corresponding inputs. You must pass -oh parameter followed by the OH number (0-11). Optionally you can also pass -m which will perform a fiber mapping test.")

def decodeVfatChipId(idEnc):
    p = subprocess.Popen(["rmdecode", "2", "5", "%d" % idEnc], stdout=subprocess.PIPE)
    out = p.communicate()
    res = out[0].split(" ")
    if "Unable" in res:
        return -1

    return parse_int(res[0])


def printRxPower(rawi2c_output):
    res = rawi2c_output.split(" ")
    for ch in range(0, 12):
        ch_msb_idx = 5 + (11 - ch) * 2
        ch_lsb_idx = 6 + (11 - ch) * 2
        ch_msb = str(res[ch_msb_idx])
        ch_lsb = str(res[ch_lsb_idx])
        ch_pwr = "0x" + ch_msb + ch_lsb
        print("Ch %02d :  %3d uW" % (ch, int(ch_pwr, 0) / 10))

# this function reads the RX power of channels corresponding to GBT0, GBT1, GBT2, trig1 and trig2 of the specified OH and returns an array of these values in that order (units are uW)
def readOhRxPower(oh, numIter=1):

    power = [-1, -1, -1, -1, -1] * numIter

    #read the GBT power
    cxp = oh / 4
    for i in range(0, numIter):
        p = subprocess.Popen(["rawi2c", "/dev/i2c-%d" % (cxp + 2), "r", "0x54", "206", "24"], stdout=subprocess.PIPE)
        out = p.communicate()
        res = out[0].split(" ")
        first_ch = oh * 3 - cxp * 12
        for ch in range(first_ch, first_ch + 3):
            ch_msb_idx = 5 + (11 - ch) * 2
            ch_lsb_idx = 6 + (11 - ch) * 2
            ch_msb = str(res[ch_msb_idx])
            ch_lsb = str(res[ch_lsb_idx])
            ch_pwr = "0x" + ch_msb + ch_lsb
            power[i * 5 + ch - first_ch] = int(ch_pwr, 0) / 10
            # print "iter %d ch %d = %d" % (i, ch, int(ch_pwr,0)/10)

    # read trigger input power
    mp_ch = 4 + oh * 2
    if oh > 9:
        mp_ch += 8

    mp = mp_ch / 12

    for i in range(0, numIter):
        p = subprocess.Popen(["rawi2c", "/dev/i2c-1", "r", "0x%d" % (mp + 30), "64", "24"], stdout=subprocess.PIPE)
        out = p.communicate()
        res = out[0].split(" ")
        first_ch = mp_ch - mp * 12
        for ch in range(first_ch, first_ch + 2):
            ch_msb_idx = 5 + (ch) * 2
            ch_lsb_idx = 6 + (ch) * 2
            ch_msb = str(res[ch_msb_idx])
            ch_lsb = str(res[ch_lsb_idx])
            ch_pwr = "0x" + ch_msb + ch_lsb
            power[i * 5 + 3 + ch - first_ch] = int(ch_pwr, 0) / 10

    ret = [0, 0, 0, 0, 0]
    # min = [9999, 9999, 9999, 9999, 9999]
    # max = [0, 0, 0, 0, 0]
    for i in range(0, numIter):
        for j in range(0, 5):
            ret[j] += power[i * 5 + j]
            # if power[i*5+j] < min[j]:
            #     min[j] = power[i*5+j]
            # if power[i*5+j] > max[j]:
            #     max[j] = power[i*5+j]

    for j in range(0, 5):
        ret[j] = ret[j] / numIter

    # print min
    # print max
    # print ret

    return ret

def debugCyan(string):
    if DEBUG:
        print_cyan('DEBUG: ' + string)

if __name__ == '__main__':
    main()
