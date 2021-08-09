from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from common.promless import *
from gem.gbt import *
from gem.gem_utils import *
import time
from os import path

def init_gem_frontend():

    gem_station = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.GEM_STATION")
    print("GEM station: %s" % gem_station)

    if gem_station == 1 or gem_station == 2:
        # configure GBTs
        max_ohs = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.NUM_OF_OH")
        num_gbts = 2 if gem_station == 2 else 3 if gem_station == 1 else None
        for oh in range(max_ohs):
            for gbt in range(num_gbts):
                gbt_ready = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt))
                if gbt_ready == 0:
                    print("Skipping configuration of OH%d GBT%d, because it is not ready" % (oh, gbt))
                    continue
                gbt_config = get_config("CONFIG_GE21_OH_GBT_CONFIGS")[gbt][oh]
                print("Configuring OH%d GBT%d with %s config" % (oh, gbt, gbt_config))
                if not path.exists(gbt_config):
                    printRed("GBT config file %s does not exist. Please create a symlink there, or edit the CONFIG_GE*_OH_GBT*_CONFIGS constant in your befe_config.py file" % gbt_config)
                gbt_command(oh, gbt, "config", [gbt_config])

        print("Resetting SCAs")
        write_reg("BEFE.GEM_AMC.SLOW_CONTROL.SCA.CTRL.MODULE_RESET", 1)


        print("Sending a hard-reset")
        gem_hard_reset()

    print("Setting VFAT HDLC addresses")
    vfats_per_oh = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.NUM_VFATS_PER_OH")
    hdlc_addr = get_config("CONFIG_ME0_VFAT_HDLC_ADDRESSES") if gem_station == 0 else get_config("CONFIG_GE11_VFAT_HDLC_ADDRESSES") if gem_station == 1 else get_config("CONFIG_GE21_VFAT_HDLC_ADDRESSES") if gem_station == 2 else None
    for vfat in range(vfats_per_oh):
        write_reg("BEFE.GEM_AMC.GEM_SYSTEM.VFAT3.VFAT%d_HDLC_ADDRESS" % vfat, hdlc_addr[vfat])

    print("Sending a link reset (also issues a SYNC command to the VFATs)")
    write_reg("BEFE.GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET", 1)
    time.sleep(0.1)

    print("Sending a command to VFATs to exit slow-control-only mode in case they are in this mode")
    write_reg("BEFE.GEM_AMC.GEM_SYSTEM.VFAT3.SC_ONLY_MODE", 0)

    time.sleep(0.3)
    print("Frontend status:")
    gem_print_status()

    print("Frontend initialization done")

if __name__ == '__main__':
    parse_xml()
    init_gem_frontend()