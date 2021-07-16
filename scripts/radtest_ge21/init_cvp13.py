import subprocess
from time import *
from common.rw_reg import *

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

# the following constants should be edited according to the local environment
BITTWORKS_SW_DIR = "/opt/bwtk/2019.3L"
PCIE_CONFIG_FILE = "/home/cscdev/cvp13/cvp13_pcie_config"
PCIE_BUS = "0000:05:00.0"
BEFE_ROOT = "../.."
OH_FW_BITFILE = "/home/cscdev/oh_fw/optohybrid_ge21_200t_reshuffled_vfats_compressed.bit"
# OH_FW_BITFILE = "/home/evka/oh_fw/oh_ge21.200-v4.1.4.bit"
OH_FW_XML = "/home/cscdev/oh_fw/optohybrid_registers.xml"

def main():
    myprint("Reseting the CVP13 FPGA")
    subprocess.call([BITTWORKS_SW_DIR + "/bin/bwconfig", "--erase", "--dev=0", "--type=fpga"])
    myprint("Programming the CVP13 FPGA")
    subprocess.call([BITTWORKS_SW_DIR + "/bin/bwconfig", "--start", "--dev=0", "--type=fpga"])
    sleep(2)
    myprint("Restoring PCIe configuration")
    subprocess.call(["cp", PCIE_CONFIG_FILE, "/sys/bus/pci/devices/%s/config" % PCIE_BUS])
    sleep(0.1)
    myprint("Copying the OH XML file to BEFE")
    subprocess.call(["cp", OH_FW_XML, BEFE_ROOT + "/address_table/gem/generated/ge21_cvp13/"])
    myprint("Initializing the CVP13 firmware")
    subprocess.call(["python", BEFE_ROOT + "/scripts/boards/cvp13/cvp13_init_ge21.py"])

    myprint("Testing communication to CVP13")
    parse_xml()

    boardId = read_reg(get_node("BEFE.SYSTEM.CTRL.BOARD_ID"))
    if boardId == 0xbefe:
        myprint("Communication to CVP13 is GOOD")
    else:
        myprint("====================================", True)
        myprint("ERROR: cannot communicate to CVP13", True)
        myprint("====================================", True)
        return

    myprint("Uploading the OH firmware to CVP13 RAM")
    subprocess.call(["python", BEFE_ROOT + "/scripts/common/promless_load.py", OH_FW_BITFILE])

def myprint(msg, isError=False):
    col = Colors.RED if isError else Colors.GREEN
    print(col + "===> " + msg + Colors.ENDC)

if __name__ == '__main__':
    main()
