from common.fw_utils import *
from common.utils import *
import sys
import os
import signal
import subprocess
import time
from os import path
from board.manager import *

######## gather the config params ########
board_type = os.environ.get('BOARD_TYPE')
if board_type.lower() != "x2o":
    print("BOARD_TYPE is not set to apex: please source the env.sh script with correct parameters. Exiting...")
    exit(1)

flavor = os.environ.get('BEFE_FLAVOR')
fpga_idx = int(os.environ.get('BOARD_IDX'))

bitfile = sys.argv[1]
if not path.exists(bitfile):
    print_red("ERROR: Could not find the bitfile: %s" % bitfile)
    exit()
print(bitfile)

#sync_clock_config = get_config("CONFIG_X2O_SYNC_CLOCK_CONFIG")
#if not path.exists(sync_clock_config):
#    print_red("ERROR: Could not find the sync clock config file: %s" % sync_clock_config)
#    exit()


######## create the board manager, and check if we can detect the FPGA, and power up if needed ########
#m=manager(1, 0)
m=manager(optical_add_on_ver=2)
fpgas = m.detect_fpgas()
if not ("Xilinx VU13P" in fpgas):
    print("Powering up...")
    m.power_up()
fpgas = m.detect_fpgas()
if not ("Xilinx VU13P" in fpgas):
    print_red("ERROR: could not detect VU13P FPGA")
    exit(1)
else:
    print_green("VU13P FPGA detected")

######## configure clocks ########
#subheading("Configuring sync clocks with 160.32MHz...")
#m.load_clock_file(sync_clock_config)

######## program FPGA ########
heading("Programming VU13P FPGA with %s firmware" % flavor)
m.load_firmware_vup(bitfile)

######## reset C2C ########
heading("Resetting C2C")
c2c_up = m.reset_c2c_bridge(port=0)
if c2c_up:
    print_green("C2C is up!")
else:
    print_red("C2C is down...")
    exit(1)

time.sleep(0.5)

######## check reg access ########
heading("Checking register access and firmware version")
parse_xml()
befe_print_fw_info()

heading("======================= DONE! =======================")
