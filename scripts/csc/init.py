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

    print("Resetting user logic")
    write_reg("BEFE.CSC_FED.CSC_SYSTEM.CTRL.GLOBAL_RESET", 1)
    time.sleep(0.3)
    write_reg("BEFE.CSC_FED.CSC_SYSTEM.CTRL.LINK_RESET", 1)

    frontend_bitfile = get_config("CONFIG_CSC_PROMLESS_BITFILE")
    print("Loading frontend bitfile to the PROMLESS RAM: %s" % frontend_bitfile)
    if not path.exists(frontend_bitfile):
        print_red("Frontend bitfile %s does not exist. Please create a symlink there, or edit the CONFIG_CSC_PROMLESS_BITFILE constant in your befe_config.py file" % frontend_bitfile)
        return
    promless_load(frontend_bitfile)

    print("Sending a hard-reset")
    csc_hard_reset()
    time.sleep(0.3)

    print("DONE")

if __name__ == '__main__':
    init_csc_backend()
