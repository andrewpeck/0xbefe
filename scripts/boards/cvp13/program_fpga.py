from common.fw_utils import *
from common.utils import *
import boards.cvp13.cvp13_utils as cvp13
import sys
import os
import signal
import subprocess
import time
from os import path

if len(sys.argv) > 1 and sys.argv[1] == "help":
    print("This script loads the CVP13 firmware using vivado or vivado lab tools (make sure you have the relevant config parameters set correctly in your befe_config.py)")
    print("The firmware flavor is determined based on the environment variable BEFE_FLAVOR, which is set when sourcing the env.sh")

board_type = os.environ.get('BOARD_TYPE')
if board_type.lower() != "cvp13":
    print("BOARD_TYPE is not set to cvp13: please source the env.sh script with correct parameters. Exiting...")
    exit(1)

flavor = os.environ.get('BEFE_FLAVOR')
bitfile = None

if flavor.lower() == "ge11":
    bitfile = get_config("CONFIG_CVP13_GE11_BITFILE")
elif flavor.lower() == "ge21":
    bitfile = get_config("CONFIG_CVP13_GE21_BITFILE")
elif flavor.lower() == "me0":
    bitfile = get_config("CONFIG_CVP13_ME0_BITFILE")
elif flavor.lower() == "csc":
    bitfile = get_config("CONFIG_CVP13_CSC_BITFILE")

heading("Unloading XDMA driver")
subprocess.Popen("modprobe -r xdma", shell=True, executable="/bin/bash")

heading("Removing the CVP13 from the PCIe bus if present")
cvp13s = cvp13.detect_cvp13_cards()
if len(cvp13s) == 0:
    print_color("No CVP13 card was found on the PCIe bus, but will try to program anyway, and see then..", Colors.YELLOW)
elif len(cvp13s) > 1:
    print_red("You have more than one CVP13 in the system, not sure which one to configure.. exiting..")
    exit()
else:
    cvp13_dev_path = cvp13s[0]
    print("Found CVP13 on this bus: %s, removing" % cvp13_dev_path)
    remove_cmd = "echo 1 > %s/remove" % cvp13_dev_path
    subprocess.Popen(remove_cmd, shell=True, executable="/bin/bash")
    time.sleep(1)
    if len(cvp13.detect_cvp13_cards()) > 0:
        print_color("Hmm the CVP13 is still on the PCIe bus after removal..", Colors.YELLOW)

vivado_dir = get_config("CONFIG_VIVADO_DIR")

if not path.exists(bitfile):
    print_red("Could not find the bitfile: %s" % bitfile)
    exit()

if not path.exists(vivado_dir):
    print_red("Could not find the vivado directory: %s" % vivado_dir)
    exit()

hw_server_url = get_config("CONFIG_VIVADO_HW_SERVER")
hw_server_proc = None
if "localhost" in hw_server_url:
    heading("Starting Xilinx HW server...")
    hw_server_proc = subprocess.Popen("source %s/settings64.sh && hw_server" % vivado_dir, shell=True, executable="/bin/bash")

vivado_exec = "vivado_lab" if "vivado_lab" in vivado_dir.lower() else "vivado"
befe_dir = get_config("BEFE_SCRIPTS_DIR")
tcl_script = befe_dir + "/dev/vivado_program_fpga.tcl"

program_cmd = "source %s/settings64.sh && %s -mode batch -source %s -tclargs %s %s" % (vivado_dir, vivado_exec, tcl_script, bitfile, hw_server_url)
heading("Programming the FPGA")
print(program_cmd)
program_proc = subprocess.Popen(program_cmd, shell=True, executable="/bin/bash")

while program_proc.poll() is None:
    time.sleep(1)

print("Programming DONE")

## may need to do a hot reset before the rescan: https://unix.stackexchange.com/questions/73908/how-to-reset-cycle-power-to-a-pcie-device/474378#474378

heading("Rescanning the PCIe bus")
rescan_cmd = "echo 1 > /sys/bus/pci/rescan"
subprocess.Popen(rescan_cmd, shell=True, executable="/bin/bash")
time.sleep(1)

cvp13s = cvp13.detect_cvp13_cards()
if len(cvp13s) == 0:
    print_red("ERROR: No CVP13 running 0xBEFE firmware was found on the PCIe bus.. exiting..")
    exit()
elif len(cvp13s) > 1:
    print_red("You have more than one CVP13 in the system, not sure which one to configure.. exiting..")
    exit()

cvp13_dev_path = cvp13s[0]
print_green("Found CVP13 on this bus: %s" % cvp13_dev_path)

heading("Loading XDMA driver")
subprocess.Popen("modprobe xdma", shell=True, executable="/bin/bash")

heading("Checking register access and firmware version")
time.sleep(1.1)
parse_xml()
befe_print_fw_info()

heading("======================= DONE! =======================")
init_script = "gem/init_backend.py" if flavor.lower() in ["ge11", "ge21", "me0"] else "csc/init.py" if flavor.lower() == "csc" else "init script"
print("you can run %s now" % init_script)

if hw_server_proc is not None:
    os.killpg(os.getpgid(hw_server_proc.pid), signal.SIGTERM)
