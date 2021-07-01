#!/usr/bin/env python

from rw_reg import *
from time import *
import array
import struct
from config_me0 import *

RX_INVERTION = [1, 1, 0, 0, 1, 1, 1, 1] # channel inversion as it is on the APEX
TX_INVERTION = [0, 0, 0, 0, 1, 1, 1, 1] # channel inversion as it is on the APEX
ME0_VFAT_HDLC_ADDRESSES = [4, 3, 10, 9, 1, 3, 7, 9, 1, 5, 7, 11, 4, 5, 10, 11, 2, 6, 8, 12, 2, 6, 8, 12]

def main():

    parseXML()

    writeReg(getNode("GEM_AMC.TTC.CTRL.DISABLE_PHASE_ALIGNMENT"), 1)

    if config_param["watchdog_control"]:
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
    for chan in range(8):
        writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.TX_DIFF_CTRL" % chan), 0x18)
        writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.TX_POLARITY" % chan), TX_INVERTION[chan])
        writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.RX_POLARITY" % chan), RX_INVERTION[chan])
        writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.CTRL.RX_LOW_POWER_MODE" % chan), 1)
        if not config_param["add_sleep"]:
            writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.RESET" % chan), 1)
        else:
            # Only reset MGT channel for master lpGBTs
            if chan%2==0:
                writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.RESET" % chan), 1)

    if config_param["add_sleep"]:
        # Sleep and then reset MGT channel for slave lpGBTs (so that master lpGBTs are already ready)
        sleep(2)
        for chan in range(16):
            if chan%2!=0:
                writeReg(getNode("GEM_AMC.OPTICAL_LINKS.MGT_CHANNEL_%d.RESET" % chan), 1)

    if config_param["watchdog_control"]:
        sleep(0.1)
        # Enabling watchdog for master and slave lpGBTs
        for chan in range(16):
            writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.GBTX_LINK_SELECT"), chan)
            writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.ADDRESS"), 0xED)
            writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.WRITE_DATA"), 0x03)
            writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.EXECUTE_WRITE"), 1)

    if config_param["lpgbt_reset"]:
        sleep(0.1)
        writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.GBTX_I2C_ADDR"), 0x70)
        writeReg(getNode("GEM_AMC.SLOW_CONTROL.IC.READ_WRITE_LENGTH"), 1)
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
    for vfat in range(0,24):
        if config_param["hdlc_addr"]:
            writeReg(getNode("GEM_AMC.GEM_SYSTEM.VFAT3.VFAT%d_HDLC_ADDRESS"%(vfat)), ME0_VFAT_HDLC_ADDRESSES[vfat])
        else:
            writeReg(getNode("GEM_AMC.GEM_SYSTEM.VFAT3.VFAT%d_HDLC_ADDRESS"%(vfat)), 0)

    sleep(0.1)
    writeReg(getNode("GEM_AMC.GEM_SYSTEM.CTRL.GLOBAL_RESET"), 1)

    sleep(0.3)
    writeReg(getNode("GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET"), 1)

    print("DONE")

if __name__ == '__main__':
    main()
