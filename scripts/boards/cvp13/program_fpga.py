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

heading("Programming done, applying the PCIe config")
cvp13s = cvp13.detect_cvp13_cards()
if len(cvp13s) == 0:
    print_red("Hmm no CVP13 running 0xBEFE firmware was found on the system.. exiting..")
    exit()
elif len(cvp13s) > 1:
    print_red("You have more than one CVP13 in the system, not sure which one to configure.. exiting..")
    exit()

cvp13_dev_path = cvp13s[0]
pcie_config = get_config("CONFIG_CVP13_PCIE_CONFIG")

if not path.exists(pcie_config):
    print_red("Could not find the CVP13 PCIe config: %s" % pcie_config)
    print_red("If you don't have it, program the PROM of the CVP13 with 0xBEFE firmware, and power-cycle the computer (not just reboot, but power off and power on), and then make a copy of %s/config, and link it to where the CONFIG_CVP13_PCIE_CONFIG in befe_config.py is pointing to." % cvp13_dev_path)
    exit()

print("Found CVP13 on this bus: %s" % cvp13_dev_path)
print("Applying this config: %s" % pcie_config)
config_cmd = "cp %s %s" % (pcie_config, cvp13_dev_path + "/config")
subprocess.Popen(config_cmd, shell=True, executable="/bin/bash")

heading("Checking register access and firmware version")
parse_xml()
befe_print_fw_info()

heading("======================= DONE! =======================")
init_script = "gem/init_backend.py" if flavor.lower() in ["ge11", "ge21", "me0"] else "csc/init.py" if flavor.lower() == "csc" else "init script"
print("you can run %s now" % init_script)

if hw_server_proc is not None:
    os.killpg(os.getpgid(hw_server_proc.pid), signal.SIGTERM)
