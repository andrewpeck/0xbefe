#!/usr/bin/env python

from rw_reg import *
from time import *
import array
import struct

RX_INVERTION = [1, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1] # channel inversion as it is on the APEX
TX_INVERTION = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1] # channel inversion as it is on the APEX
ME0_VFAT_HDLC_ADDRESSES = [4, 3, 10, 9, 1, 3, 7, 9, 1, 5, 7, 11, 4, 5, 10, 11, 2, 6, 8, 12, 2, 6, 8, 12]

def main():

    parseXML()

    writeReg(getNode("GEM_AMC.TTC.CTRL.DISABLE_PHASE_ALIGNMENT"), 1)

    for chan in range(12):
        writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.TX_DIFF_CTRL" % chan), 0x18)
        writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.TX_POLARITY" % chan), TX_INVERTION[chan])
        writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.RX_POLARITY" % chan), RX_INVERTION[chan])
        writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.RESET" % chan), 1)

    for vfat in range(24):
        writeReg(getNode("GEM_AMC.GEM_SYSTEM.VFAT3.VFAT%d_HDLC_ADDRESS" % vfat), ME0_VFAT_HDLC_ADDRESSES[vfat])

    sleep(0.1)
    writeReg(getNode("GEM_AMC.GEM_SYSTEM.CTRL.GLOBAL_RESET"), 1)

    sleep(0.3)
    writeReg(getNode("GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET"), 1)

    print("DONE")

if __name__ == '__main__':
    main()
