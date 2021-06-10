#!/usr/bin/env python

from rw_reg import *
from time import *
import array
import struct

RX_INVERTION = [0, 1, 1, 1] # channel inversion as it is on the APEX
TX_INVERTION = [0, 0, 0, 0] # channel inversion as it is on the APEX

def main():

    parseXML()

    writeReg(getNode("CSC_FED.TTC.CTRL.DISABLE_PHASE_ALIGNMENT"), 1)

    for chan in range(4):
        writeReg(getNode("CSC_FED.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.TX_DIFF_CTRL" % chan), 0x18)
        writeReg(getNode("CSC_FED.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.TX_POLARITY" % chan), TX_INVERTION[chan])
        writeReg(getNode("CSC_FED.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.RX_POLARITY" % chan), RX_INVERTION[chan])
        writeReg(getNode("CSC_FED.OPTICAL_LINKS.MGT_CHANNEL_%d.RESET" % chan), 1)

    sleep(0.1)
    writeReg(getNode("CSC_FED.GEM_SYSTEM.CTRL.GLOBAL_RESET"), 1)

    sleep(0.3)
    writeReg(getNode("CSC_FED.GEM_SYSTEM.CTRL.LINK_RESET"), 1)

    print("DONE")

if __name__ == '__main__':
    main()
