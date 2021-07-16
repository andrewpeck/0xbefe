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
    print("GEM station: %s" % gem_station.to_string(False))

    if gem_station == 1 or gem_station == 2:
        # configure GBTs
        max_ohs = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.NUM_OF_OH")
        num_gbts = 2 if gem_station == 2 else 3 if gem_station == 1 else None
        for oh in range(max_ohs):
            for gbt in range(num_gbts):
                print("Configuring GBT%d" % gbt)
                gbt_config = CONFIG_GE21_OH_GBT_CONFIGS[gbt][oh]
                if not path.exists(gbt_config):
                    printRed("GBT config file %s does not exist. Please create a symlink there, or edit the CONFIG_GE*_OH_GBT*_CONFIGS constant in your befe_config.py file" % gbt_config)
                gbt(oh, gbt, "config", gbt_config)

        print("Resetting SCAs")
        write_reg("BEFE.GEM_AMC.SLOW_CONTROL.SCA.CTRL.MODULE_RESET", 1)


        print("Sending a hard-reset")
        ttc_gen_en = read_reg("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE")
        write_reg("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE", 1)
        write_reg("BEFE.GEM_AMC.SLOW_CONTROL.SCA.CTRL.TTC_HARD_RESET_EN", 1)
        write_reg("BEFE.GEM_AMC.TTC.GENERATOR.SINGLE_HARD_RESET", 1)
        write_reg("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE", ttc_gen_en)

    print("Setting VFAT HDLC addresses")
    vfats_per_oh = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.NUM_VFATS_PER_OH")
    hdlc_addr = CONFIG_ME0_VFAT_HDLC_ADDRESSES if gem_station == 0 else CONFIG_GE11_VFAT_HDLC_ADDRESSES if gem_station == 1 else CONFIG_GE21_VFAT_HDLC_ADDRESSES if gem_station == 2 else None
    for vfat in range(vfats_per_oh):
        write_reg("BEFE.GEM_AMC.GEM_SYSTEM.VFAT3.VFAT%d_HDLC_ADDRESS" % vfat, hdlc_addr[vfat])

    print("Sending a command to VFATs to exit slow-control-only mode in case they are in this mode")
    write_reg("BEFE.GEM_AMC.GEM_SYSTEM.VFAT3.SC_ONLY_MODE", 0)

    print("Frontend status:")
    print_oh_status()

    print("Frontend initialization done")

if __name__ == '__main__':
    parse_xml()
    init_gem_frontend()
