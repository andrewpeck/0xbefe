from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
import time

def main():

    parseXML()

    fw_flavor = readReg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
    if fw_flavor != 1:
        printRed("The board is not running CSC firmware (flavor = %s). Exiting.." % fw_flavor.to_string(False))
        return

    befe_print_fw_info()

    print("Resetting all MGT PLLs")
    befe_reset_all_plls()
    time.sleep(0.3)
    print("Configuring and resetting all links")
    links = befe_config_links()

    heading("TX link status")
    befe_print_link_status(links, MgtTxRx.TX)
    heading("RX link status")
    befe_print_link_status(links, MgtTxRx.RX)

    time.sleep(0.1)
    print("Resetting user logic")
    writeReg("CSC_FED.SYSTEM.CTRL.GLOBAL_RESET", 1)
    time.sleep(0.3)
    writeReg("CSC_FED.SYSTEM.CTRL.LINK_RESET", 1)

    print("DONE")

if __name__ == '__main__':
    main()
