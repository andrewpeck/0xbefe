from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from common.promless import *
from csc.csc_utils import *
import time
from os import path

def init_csc_backend():

    parse_xml()

    fw_flavor = read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
    if fw_flavor != 1:
        print_red("The board is not running CSC firmware (flavor = %s). Exiting.." % fw_flavor)
        return

    befe_print_fw_info()

    # Reset PLLs, reset and configure MGTs
    print("Resetting all MGT PLLs")
    befe_reset_all_plls()
    time.sleep(0.3)
    print("Configuring and resetting all links")
    links = befe_config_links()

    time.sleep(0.1)

    heading("TX link status")
    befe_print_link_status(links, MgtTxRx.TX)
    heading("RX link status")
    befe_print_link_status(links, MgtTxRx.RX)

    # Reset user logic
    print("Resetting user logic")
    write_reg("BEFE.CSC_FED.CSC_SYSTEM.CTRL.GLOBAL_RESET", 1)
    time.sleep(0.3)
    write_reg("BEFE.CSC_FED.CSC_SYSTEM.CTRL.LINK_RESET", 1)

    # Configure XDCFEB PROMless
    xdcfeb_bitfile = get_config("CONFIG_CSC_XDCFEB_BITFILE")
    print("Loading XDCFEB bitfile to the PROMLESS RAM: %s" % xdcfeb_bitfile)
    if not path.exists(xdcfeb_bitfile):
        print_red("XDCFEB bitfile %s does not exist. Please create a symlink there, or edit the CONFIG_CSC_XDCFEB_BITFILE constant in your befe_config.py file" % xdcfeb_bitfile)
        return
    promless_load(xdcfeb_bitfile, promless_type="CFEB")

    # Configure ALCT PROMless
    alct_bitfile = get_config("CONFIG_CSC_ALCT_BITFILE")
    print("Loading ALCT bitfile to the PROMLESS RAM: %s" % alct_bitfile)
    if not path.exists(alct_bitfile):
        print_red("ALCT bitfile %s does not exist. Please create a symlink there, or edit the CONFIG_CSC_ALCT_BITFILE constant in your befe_config.py file" % alct_bitfile)
        return
    promless_load(alct_bitfile, promless_type="ALCT")

    # Send a hard reset
    print("Sending a hard-reset")
    csc_hard_reset()
    time.sleep(0.3)

    print("DONE")

if __name__ == '__main__':
    init_csc_backend()
