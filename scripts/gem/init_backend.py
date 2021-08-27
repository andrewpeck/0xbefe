from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from common.promless import *
from gem.gbt import *
from gem.init_frontend import *
import time
from os import path

def init_gem_backend():

    fw_info = befe_print_fw_info()

    if fw_info["fw_flavor"].to_string() != "GEM_AMC":
        print_red("The board is not running GEM firmware (flavor = %s). Exiting.." % fw_info["fw_flavor_str"])
        return

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

    print("Use TCDS: %r" % get_config("CONFIG_USE_TCDS"))
    write_reg("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE", 0 if get_config("CONFIG_USE_TCDS") else 1)

    print("Resetting user logic")
    write_reg("BEFE.GEM_AMC.GEM_SYSTEM.CTRL.GLOBAL_RESET", 1)
    time.sleep(0.3)
    write_reg("BEFE.GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET", 1)

    gem_station = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.GEM_STATION")
    print("GEM station: %s" % gem_station)

    if gem_station == 1 or gem_station == 2:
        print("Loading %s OH bitfile to the PROMLESS RAM" % gem_station)
        oh_bitfile = get_config("CONFIG_GE21_OH_BITFILE") if gem_station == 2 else get_config("CONFIG_GE11_OH_BITFILE") if gem_station == 1 else None
        if not path.exists(oh_bitfile):
            print_red("OH bitfile %s does not exist. Please create a symlink there, or edit the CONFIG_GE*_OH_BITFILE constant in your befe_config.py file" % oh_bitfile)
            return
        promless_load(oh_bitfile)

    print("Initializing frontend..")
    init_gem_frontend()

    print("")
    print("=========== DONE ===========")

if __name__ == '__main__':
    parse_xml()
    init_gem_backend()
