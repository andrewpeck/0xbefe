import sys
from common.rw_reg import *
from common.utils import *

def ttc_ccb_init():

    print("Initializing CCB")

    # write_reg("BEFE.TTC_TX.CTRL.RESET", 1)

    # disable L1As and B commands
    write_reg("BEFE.TTC_TX.CTRL.TTC_RX.L1A_EN", 0)
    write_reg("BEFE.TTC_TX.CTRL.TTC_RX.BCMD_EN", 0)

    # configure the TTCrx
    # 1) TTCrx addr = 0, E = 0 (internal), subaddr = 0 (fine delay reg 1), data = 0
    # 2) TTCrx addr = 0, E = 0 (internal), subaddr = 1 (fine delay reg 2), data = 0
    # 3) TTCrx addr = 0, E = 0 (internal), subaddr = 1 (coarse delay reg), data = 0
    # 4) TTCrx addr = 0, E = 0 (internal), subaddr = 3 (control reg), data = 0xB1  (as far as I can see from TTCrx manual, this does the following: enable bunch counter, enable double bit error init, enable parallel addr/data bus, enable non-deskewed 40MHz output, and disables event counter, single bit err init, serial addr/data bus)
    # 5) TTCrx addr = 0, E = 1 (external), subaddr = 0, data = 0 (as far as I understand, this will assert the data strobe DoutStr, and set the Dout[7:0] = 0, SubAddr[7:0] = 0, DQ[3:0] = 0)
    write_reg("BEFE.TTC_TX.CTRL.SEND_MANUAL_ADDR_CMD", 0x00010000)
    write_reg("BEFE.TTC_TX.CTRL.SEND_MANUAL_ADDR_CMD", 0x00010100)
    write_reg("BEFE.TTC_TX.CTRL.SEND_MANUAL_ADDR_CMD", 0x00010200)
    write_reg("BEFE.TTC_TX.CTRL.SEND_MANUAL_ADDR_CMD", 0x000103b1)
    write_reg("BEFE.TTC_TX.CTRL.SEND_MANUAL_ADDR_CMD", 0x00030000)

    # enable L1As and B commands
    write_reg("BEFE.TTC_TX.CTRL.TTC_RX.L1A_EN", 1)
    write_reg("BEFE.TTC_TX.CTRL.TTC_RX.BCMD_EN", 1)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: ttc_tx.py <command>")
        print("Commands:")
        print("    init: configures the CCB")
        exit(0)

    cmd = sys.argv[1]

    parse_xml()

    if cmd == "init":
        ttc_ccb_init()
