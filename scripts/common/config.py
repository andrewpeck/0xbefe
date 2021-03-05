#!/usr/bin/env python3

CONFIG_RWREG_CVP13 = {
    'DEVICE'                        : 'auto', # setting this to auto will scan /sys/bus/pci/devices and try to find the CVP13, you can also just set it to the exact device BAR2 resource e.g. /sys/bus/pci/devices/0000:05:00.0/resource2 (see lspci to find the correct bus)
#    'DEVICE'                        : '/sys/bus/pci/devices/0000:05:00.0/resource2', # for CVP13 set this to the BAR2 resource of appropriate bus e.g. /sys/bus/pci/devices/0000:05:00.0/resource2 (see lspci to find the correct bus). For other boards this parameter is not yet used
    'BASE_ADDR'                     : 0
}

CONFIG_RWREG_CTP7 = {
    'DEVICE'                        : '',
    'BASE_ADDR'                     : 0x64000000
}

CONFIG_RWREG_APEX = {
    'DEVICE'                        : 'FPGA0', # for APEX set this to either FPGA0 or FPGA1
    'BASE_ADDR'                     : 0
}

CONFIG_RWREG = {"cvp13": CONFIG_RWREG_CVP13, "ctp7": CONFIG_RWREG_CTP7, "apex": CONFIG_RWREG_APEX}
