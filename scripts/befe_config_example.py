#!/usr/bin/env python3

import os
BEFE_SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))

# =================================================================================================
#            Backend configuration
# =================================================================================================

CONFIG_RWREG_CVP13 = [
    {
        # setting this to auto will scan /sys/bus/pci/devices and try to find the CVP13, you can also just set it to the exact device BAR2 resource e.g. /sys/bus/pci/devices/0000:05:00.0/resource2 (see lspci to find the correct bus)
        # note that auto setting can only be used if you only have one card in the system
        'DEVICE': 'auto',
        #    'DEVICE'                        : '/sys/bus/pci/devices/0000:05:00.0/resource2', # for CVP13 set this to the BAR2 resource of appropriate bus e.g. /sys/bus/pci/devices/0000:05:00.0/resource2 (see lspci to find the correct bus). For other boards this parameter is not yet used
        'BASE_ADDR': 0
    }
]

CONFIG_RWREG_CTP7 = [
    {
        'DEVICE': '',
        'BASE_ADDR': 0x64000000
    }
]

CONFIG_RWREG_APEX0 = [
    {
        'DEVICE': 'FPGA0',  # for APEX set this to either FPGA0 or FPGA1
        'BASE_ADDR': 0
    }
]

CONFIG_RWREG_APEX = [
    {
        'DEVICE': 'FPGA0',  # for APEX set this to either FPGA0 or FPGA1
        'BASE_ADDR': 0
    },
    {
        'DEVICE': 'FPGA1',  # for APEX set this to either FPGA0 or FPGA1
        'BASE_ADDR': 0
    }
]

CONFIG_RWREG = {"cvp13": CONFIG_RWREG_CVP13, "ctp7": CONFIG_RWREG_CTP7, "apex": CONFIG_RWREG_APEX}

# =================================================================================================
#            GE2/1 configuration
# =================================================================================================

# OH firmware bitfile (same file is loaded to all OHs)
CONFIG_GE21_OH_BITFILE = BEFE_SCRIPTS_DIR + "/resources/ge21_oh.bit"
# GBT0 and GBT1 config files: these are arrays that should have a length of at least how many OHs are connected
# NOTE: the example below is using the same config for all OHs, while in a real system you will likely need different files for each OH (e.g. containing correct phases for the GEB that they're installed on)
# To specify config files individually for each OH just make each element of the two arrays refer to the configs of the particular OH (and remove the * 16 at the end)
CONFIG_GE21_OH_GBT0_CONFIGS = [BEFE_SCRIPTS_DIR + "/resources/ge21_gbt0_config.txt"] * 16
CONFIG_GE21_OH_GBT1_CONFIGS = [BEFE_SCRIPTS_DIR + "/resources/ge21_gbt1_config.txt"] * 16
