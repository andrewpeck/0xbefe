from common.fw_utils import *
from common.utils import *
import sys
import os
import signal
import subprocess
import time
from os import path

######## gather the config params ########
board_type = os.environ.get('BOARD_TYPE')
if board_type.lower() != "apex":
    print("BOARD_TYPE is not set to apex: please source the env.sh script with correct parameters. Exiting...")
    exit(1)

flavor = os.environ.get('BEFE_FLAVOR')
fpga_idx = int(os.environ.get('BOARD_IDX'))
top_bot = "top" if fpga_idx == 0 else "bot" if fpga_idx == 1 else "UNKNOWN"
x2o_sw_dir = get_config("CONFIG_X2O_SW_DIR")
bitfile = None
if flavor.lower() == "ge11":
    bitfile = get_config("CONFIG_APEX_GE11_BITFILE")
elif flavor.lower() == "ge21":
    bitfile = get_config("CONFIG_APEX_GE21_BITFILE")
elif flavor.lower() == "me0":
    bitfile = get_config("CONFIG_APEX_ME0_BITFILE")
elif flavor.lower() == "csc":
    bitfile = get_config("CONFIG_APEX_CSC_BITFILE")

if not path.exists(bitfile):
    print_red("Could not find the bitfile: %s" % bitfile)
    exit()

######## check if XVC is already running, and if so, ask the user to kill it ########
#
# pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]
# xvc_pids = []
# xvc_cmds = []
#
# for pid in pids:
#     try:
#         cmdfile = open(os.path.join('/proc', pid, 'cmdline'), 'r')
#         cmd = cmdfile.read()
#         cmdfile.close()
#         if "xvc" in cmd:
#             xvc_pids.append(pid)
#             xvc_cmds.append(cmd)
#     except IOError: # proc has already terminated
#         continue

######## configure clocks ########
heading("Configuring %s clock synthesizers" % top_bot)
subheading("Configuring sync clocks with 160.32MHz...")
cmd = "cd %s/clock/clock_sync && %s/clock/clock_sync/clock_sync_160M_noref %s/clock/clock_sync/CONFIGS/config_%s.toml" % (x2o_sw_dir, x2o_sw_dir, x2o_sw_dir, top_bot)
print(cmd)
sync_clk_proc = subprocess.Popen(cmd, shell=True, executable="/bin/bash")
while sync_clk_proc.poll() is None:
    time.sleep(0.1)

subheading("Configuring async clocks with 156.25MHz on GTYs and 250MHz on GTHs...")
cmd = "cd %s/clock/clock_async && %s/clock/clock_async/clock_async_Y156_H250 %s/clock/clock_async/CONFIGS/config_%s.toml" % (x2o_sw_dir, x2o_sw_dir, x2o_sw_dir, top_bot)
print(cmd)
async_clk_proc = subprocess.Popen(cmd, shell=True, executable="/bin/bash")
while async_clk_proc.poll() is None:
    time.sleep(0.1)

######## program FPGA ########
heading("Programming %s FPGA with %s firmware" % (top_bot, flavor))
cmd = "cd %s && %s/fw_program_%s.sh %s" % (x2o_sw_dir, x2o_sw_dir, top_bot, bitfile)
print(cmd)
program_proc = subprocess.Popen(cmd, shell=True, executable="/bin/bash")
while program_proc.poll() is None:
    time.sleep(1)

######## reset C2C ########
heading("Resetting C2C")
cmd = "cd %s && %s/c2c_reset_%s.sh" % (x2o_sw_dir, x2o_sw_dir, top_bot)
print(cmd)
c2c_reset_proc = subprocess.Popen(cmd, shell=True, executable="/bin/bash")
while c2c_reset_proc.poll() is None:
    time.sleep(0.1)
time.sleep(0.5)

######## check reg access ########
heading("Checking register access and firmware version")
parse_xml()
befe_print_fw_info()

heading("======================= DONE! =======================")
init_script = "gem/init_backend.py" if flavor.lower() in ["ge11", "ge21", "me0"] else "csc/init.py" if flavor.lower() == "csc" else "init script"
print("you can run %s now" % init_script)
