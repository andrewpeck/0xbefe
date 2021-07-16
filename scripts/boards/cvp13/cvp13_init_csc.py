#!/usr/bin/env python

from common.rw_reg import *
from time import *
import array
import struct

def main():

    parse_xml()

    write_reg(get_node("CSC_FED.TTC.CTRL.DISABLE_PHASE_ALIGNMENT"), 1)

    for chan in range(16):
        write_reg(get_node("CSC_FED.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.TX_DIFF_CTRL" % chan), 0x18)
        write_reg(get_node("CSC_FED.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.TX_POLARITY" % chan), 0)
        write_reg(get_node("CSC_FED.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.RX_POLARITY" % chan), 0)
        write_reg(get_node("CSC_FED.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.RX_LOW_POWER_MODE" % chan), 1)
        write_reg(get_node("CSC_FED.OPTICAL_LINKS.MGT_CHANNEL_%d.RESET" % chan), 1)

    sleep(0.1)
    write_reg(get_node("CSC_FED.SYSTEM.CTRL.GLOBAL_RESET"), 1)

    sleep(0.3)
    write_reg(get_node("CSC_FED.SYSTEM.CTRL.LINK_RESET"), 1)

    print("DONE")

if __name__ == '__main__':
    main()
