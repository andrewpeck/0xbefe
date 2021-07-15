from common.rw_reg import *
from common.utils import *
from common.links import *

def print_fw_info():
    board_type = readReg("BEFE.SYSTEM.RELEASE.BOARD_TYPE")
    fw_major = readReg("BEFE.SYSTEM.RELEASE.MAJOR")
    fw_minor = readReg("BEFE.SYSTEM.RELEASE.MINOR")
    fw_build = readReg("BEFE.SYSTEM.RELEASE.BUILD")
    fw_date = readReg("BEFE.SYSTEM.RELEASE.DATE")
    fw_time = readReg("BEFE.SYSTEM.RELEASE.TIME")
    fw_git_sha = readReg("BEFE.SYSTEM.RELEASE.GIT_SHA")
    gem_station = readReg("GEM_AMC.GEM_SYSTEM.RELEASE.GEM_STATION")
    oh_version = readReg("GEM_AMC.GEM_SYSTEM.RELEASE.OH_VERSION")
    num_ohs = readReg("GEM_AMC.GEM_SYSTEM.RELEASE.NUM_OF_OH")

    fw_date_str = "%04x" % fw_date
    heading("BEFE v%d.%d.%d running on %s (built on %)")

def main():

    fw_flavor = readReg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
    if fw_flavor != 0:
        printRed("The board is not running GEM firmware. Exiting..")
        return


    heading("")

    print("Resetting all MGT PLLs")
    links_reset_all_plls()

if __name__ == '__main__':
    main()
