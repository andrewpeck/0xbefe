#!/usr/bin/env python

from rw_reg import *
from time import *
import array
import struct

def main():

    parseXML()

    writeReg(getNode("GEM_AMC.TTC.CTRL.DISABLE_PHASE_ALIGNMENT"), 1)

    ### To prevent 0's getting written to slave lpGBT over EC link and prevent slave lpGBT locking to some internal clock
    # Disabling watchdog for master and slave lpGBTs
    writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.GBTX_I2C_ADDR"), 0x70)
    writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.READ_WRITE_LENGTH"), 1)
    for chan in range(16):
        writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.GBTX_LINK_SELECT"), chan)
        writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.ADDRESS"), 0xED)
        writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.WRITE_DATA"), 0x63)
        writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.EXECUTE_WRITE"), 1)
    sleep(0.1)

    # Reset MGT channels
    for chan in range(16):
        writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.TX_DIFF_CTRL" % chan), 0x18)
        writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.TX_POLARITY" % chan), 0)
        writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.RX_POLARITY" % chan), 0)
        writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.RESET" % chan), 1)

    sleep(0.1)
    # Enabling watchdog for master and slave lpGBTs
    for chan in range(16):
        writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.GBTX_LINK_SELECT"), chan)
        writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.ADDRESS"), 0xED)
        writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.WRITE_DATA"), 0x03)
        writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.EXECUTE_WRITE"), 1)

    sleep(0.1)
    # Only reset master lpGBTs (automatically resets slave lpGBTs)
    for chan in range(16):
        if chan%2==0:
            writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.GBTX_LINK_SELECT"), chan)
            writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.ADDRESS"), 0x130)
            writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.WRITE_DATA"), 0xA3)
            writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.EXECUTE_WRITE"), 1)
	    sleep(0.1)
	    writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.ADDRESS"), 0x12F)
            writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.WRITE_DATA"), 0x80)
            writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.EXECUTE_WRITE"), 1)

    sleep(0.1)
    writeReg(getNode("GEM_AMC.GEM_SYSTEM.CTRL.GLOBAL_RESET"), 1)

    sleep(0.3)
    writeReg(getNode("GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET"), 1)

    print("DONE")

if __name__ == '__main__':
    main()
