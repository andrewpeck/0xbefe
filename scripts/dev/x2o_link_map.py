from common.rw_reg import *
from common.utils import *

# FPGA_TYPE = "VU27P"
FPGA_TYPE = "VU13P"
# RESERVED_GTYS = [124, 125, 126, 127] # reserved GTYs, which are e.g. used by the C2C
RESERVED_GTYS = [126, 127, 230] # reserved GTYs, which are e.g. used by the C2C
RESERVED_REFCLK0 = [126, 127]
# RESERVED_REFCLK1 = [125]
RESERVED_REFCLK1 = []
NUM_SLR = 4
USE_QSFPDD = True

###############################################################
########################## GEM / CSC ##########################
###############################################################

# FULL CONFIG
# GE11_NUM_OH = 0
# GE21_NUM_OH = 40
# ME0_NUM_OH = 12
# CSC_NUM_DMB = 56

# CONFIG FOR QSFP-DD
GE11_NUM_OH = 0
GE21_NUM_OH = 20
ME0_NUM_OH = 6
CSC_NUM_DMB = 28

###############################################################
########################## REF CLKS ###########################
###############################################################

# async
REFCLK0_VU13P = [
    {"mgt": 120, "pin_p": "BD39", "schematic_name": "SI545_CLK+_0", "freq": 156.25},
    {"mgt": 121, "pin_p": "BB39", "schematic_name": "SI545_CLK+_1", "freq": 156.25},
    {"mgt": 122, "pin_p": "AY39", "schematic_name": "SI545_CLK+_2", "freq": 156.25},
    {"mgt": 123, "pin_p": "AV39", "schematic_name": "SI545_CLK+_3", "freq": 156.25},
    {"mgt": 124, "pin_p": "AT39", "schematic_name": "SI545_CLK+_4", "freq": 156.25},
    {"mgt": 125, "pin_p": "AP39", "schematic_name": "SI545_CLK+_5", "freq": 156.25},
    {"mgt": 126, "pin_p": "AM39", "schematic_name": "SI545_CLK+_6", "freq": 156.25},
    {"mgt": 127, "pin_p": "AJ41", "schematic_name": "SI545_CLK+_7", "freq": 156.25},
    {"mgt": 128, "pin_p": "AE41", "schematic_name": "SI545_CLK+_8", "freq": 156.25},
    {"mgt": 129, "pin_p": "AA41", "schematic_name": "SI545_CLK+_9", "freq": 156.25},
    {"mgt": 130, "pin_p": "W41", "schematic_name": "SI545_CLK+_10", "freq": 156.25},
    {"mgt": 131, "pin_p": "U41", "schematic_name": "SI545_CLK+_11", "freq": 156.25},
    {"mgt": 132, "pin_p": "R41", "schematic_name": "SI545_CLK+_12", "freq": 156.25},
    {"mgt": 133, "pin_p": "N41", "schematic_name": "SI545_CLK+_13", "freq": 156.25},
    {"mgt": 134, "pin_p": "L41", "schematic_name": "SI545_CLK+_14", "freq": 156.25},
    {"mgt": 135, "pin_p": "J41", "schematic_name": "SI545_CLK+_15", "freq": 156.25},
    {"mgt": 220, "pin_p": "BD13", "schematic_name": "SI545_CLK+_16", "freq": 156.25},
    {"mgt": 221, "pin_p": "BB13", "schematic_name": "SI545_CLK+_17", "freq": 156.25},
    {"mgt": 222, "pin_p": "AY13", "schematic_name": "SI545_CLK+_18", "freq": 156.25},
    {"mgt": 223, "pin_p": "AV13", "schematic_name": "SI545_CLK+_19", "freq": 156.25},
    {"mgt": 224, "pin_p": "AT13", "schematic_name": "SI545_CLK+_20", "freq": 156.25},
    {"mgt": 225, "pin_p": "AP13", "schematic_name": "SI545_CLK+_21", "freq": 156.25},
    {"mgt": 226, "pin_p": "AM13", "schematic_name": "SI545_CLK+_22", "freq": 156.25},
    {"mgt": 227, "pin_p": "AJ11", "schematic_name": "SI545_CLK+_23", "freq": 156.25},
    {"mgt": 228, "pin_p": "AE11", "schematic_name": "SI545_CLK+_24", "freq": 156.25},
    {"mgt": 229, "pin_p": "AA11", "schematic_name": "SI545_CLK+_25", "freq": 156.25},
    {"mgt": 230, "pin_p": "W11", "schematic_name": "SI545_CLK+_26", "freq": 156.25},
    {"mgt": 231, "pin_p": "U11", "schematic_name": "SI545_CLK+_27", "freq": 156.25},
    {"mgt": 232, "pin_p": "R11", "schematic_name": "SI545_CLK+_28", "freq": 156.25},
    {"mgt": 233, "pin_p": "N11", "schematic_name": "SI545_CLK+_29", "freq": 156.25},
    {"mgt": 234, "pin_p": "L11", "schematic_name": "SI545_CLK+_30", "freq": 156.25},
    {"mgt": 235, "pin_p": "J11", "schematic_name": "SI545_CLK+_31", "freq": 156.25}
]

# sync
REFCLK1_VU13P = [
    {"mgt": 121, "pin_p": "BA41", "si_out": 4, "schematic_name": "SI5395J_VU+_CLK+_0", "freq": 160.0},
    {"mgt": 125, "pin_p": "AN41", "si_out": 5, "schematic_name": "SI5395J_VU+_CLK+_1", "freq": 160.0},
    {"mgt": 129, "pin_p": "Y39", "si_out": 7, "schematic_name": "SI5395J_VU+_CLK+_2", "freq": 160.0},
    {"mgt": 133, "pin_p": "M39", "si_out": 6, "schematic_name": "SI5395J_VU+_CLK+_3", "freq": 160.0},
    {"mgt": 221, "pin_p": "BA11", "si_out": 0, "schematic_name": "SI5395J_VU+_CLK+_4", "freq": 160.0},
    {"mgt": 225, "pin_p": "AN11", "si_out": 1, "schematic_name": "SI5395J_VU+_CLK+_5", "freq": 160.0},
    {"mgt": 229, "pin_p": "Y13", "si_out": 2, "schematic_name": "SI5395J_VU+_CLK+_6", "freq": 160.0},
    {"mgt": 233, "pin_p": "M13", "si_out": 3, "schematic_name": "SI5395J_VU+_CLK+_7", "freq": 160.0}
]

REFCLK0_VU27P = REFCLK0_VU13P[4:8] + REFCLK0_VU13P[20:24]
REFCLK1_VU27P = [REFCLK1_VU13P[1], REFCLK1_VU13P[5]]

REFCLK0 = REFCLK0_VU13P if FPGA_TYPE == "VU13P" else REFCLK0_VU27P if FPGA_TYPE == "VU27P" else None
REFCLK1 = REFCLK1_VU13P if FPGA_TYPE == "VU13P" else REFCLK1_VU27P if FPGA_TYPE == "VU27P" else None

# remove reserved clocks
REFCLK0 = [refclk for refclk in REFCLK0 if refclk["mgt"] not in RESERVED_REFCLK0]
REFCLK1 = [refclk for refclk in REFCLK1 if refclk["mgt"] not in RESERVED_REFCLK1]

REFCLKS = [REFCLK0, REFCLK1]

# There are 4 ARF7 connectors on the top and back side of the PCB to the left of the FPGA, and another 4 on the top and back side of the BCP to the right of the FPGA
# on the left of the FPGA, counting from top to bottom are ARF6 connectors J19 (back) & J20 (top), J5 (back) & J6 (top), J15 (back) & J16 (top), J12 (back) & J11 (top)
# on the right of the FPGA, counting from the bottom to top are ARF6 connectors J18 (back) & J17 (top), J4 (back) & J3 (top), J14 (back) & J13 (top), J7 (back) & J10 (top)
# our logical counting of the ARF6 connectors is as listed in the above two lines

###############################################################
########################## SLR 0 ARF6 #########################
###############################################################

# ARF6 #0 (LEFT SIDE SLR 0)
ARF6_TO_MGT_J19 = [
    {"mgt": 120, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 1},
    {"mgt": 120, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 1},
    {"mgt": 123, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 2},
    {"mgt": 123, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 2},
    {"mgt": 121, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 3},
    {"mgt": 120, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 3},
    {"mgt": 123, "mgt_chan": 0, "inv": True , "dir": "TX", "arf6_chan": 4},
    {"mgt": 123, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 4},
    {"mgt": 120, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 5},
    {"mgt": 121, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 5},
    {"mgt": 122, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 6},
    {"mgt": 122, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 6},
    {"mgt": 121, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 7},
    {"mgt": 121, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 7},
    {"mgt": 122, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 8},
    {"mgt": 122, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 8}
]

# ARF6 #1 (LEFT SIDE SLR 0)
ARF6_TO_MGT_J20 = [
    {"mgt": 123, "mgt_chan": 3, "inv": True , "dir": "TX", "arf6_chan": 1},
    {"mgt": 122, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 1},
    {"mgt": 120, "mgt_chan": 3, "inv": True , "dir": "TX", "arf6_chan": 2},
    {"mgt": 121, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 2},
    {"mgt": 123, "mgt_chan": 1, "inv": True , "dir": "TX", "arf6_chan": 3},
    {"mgt": 123, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 3},
    {"mgt": 121, "mgt_chan": 1, "inv": True , "dir": "TX", "arf6_chan": 4},
    {"mgt": 120, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 4},
    {"mgt": 122, "mgt_chan": 3, "inv": True , "dir": "TX", "arf6_chan": 5},
    {"mgt": 122, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 5},
    {"mgt": 120, "mgt_chan": 1, "inv": True , "dir": "TX", "arf6_chan": 6},
    {"mgt": 120, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 6},
    {"mgt": 121, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 7},
    {"mgt": 123, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 7},
    {"mgt": 122, "mgt_chan": 1, "inv": True , "dir": "TX", "arf6_chan": 8},
    {"mgt": 121, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 8}
]

# ARF6 #2 (RIGHT SIDE SLR 0)
ARF6_TO_MGT_J18 = [
    {"mgt": 223, "mgt_chan": 2, "inv": True , "dir": "TX", "arf6_chan": 1},
    {"mgt": 223, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 1},
    {"mgt": 220, "mgt_chan": 2, "inv": True , "dir": "TX", "arf6_chan": 2},
    {"mgt": 220, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 2},
    {"mgt": 223, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 3},
    {"mgt": 223, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 3},
    {"mgt": 221, "mgt_chan": 0, "inv": True , "dir": "TX", "arf6_chan": 4},
    {"mgt": 220, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 4},
    {"mgt": 222, "mgt_chan": 2, "inv": True , "dir": "TX", "arf6_chan": 5},
    {"mgt": 222, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 5},
    {"mgt": 220, "mgt_chan": 0, "inv": True , "dir": "TX", "arf6_chan": 6},
    {"mgt": 221, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 6},
    {"mgt": 222, "mgt_chan": 0, "inv": True , "dir": "TX", "arf6_chan": 7},
    {"mgt": 222, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 7},
    {"mgt": 221, "mgt_chan": 2, "inv": True , "dir": "TX", "arf6_chan": 8},
    {"mgt": 221, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 8}
]

# ARF6 #3 (RIGHT SIDE SLR 0)
ARF6_TO_MGT_J17 = [
    {"mgt": 220, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 1},
    {"mgt": 221, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 1},
    {"mgt": 223, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 2},
    {"mgt": 222, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 2},
    {"mgt": 221, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 3},
    {"mgt": 220, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 3},
    {"mgt": 223, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 4},
    {"mgt": 223, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 4},
    {"mgt": 220, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 5},
    {"mgt": 220, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 5},
    {"mgt": 222, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 6},
    {"mgt": 222, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 6},
    {"mgt": 222, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 7},
    {"mgt": 221, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 7},
    {"mgt": 221, "mgt_chan": 3, "inv": True , "dir": "TX", "arf6_chan": 8},
    {"mgt": 223, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 8}
]

###############################################################
########################## SLR 1 ARF6 #########################
###############################################################

# ARF6 #4 (LEFT SIDE SLR 1)
ARF6_TO_MGT_J12 = [
    {"mgt": 124, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 1},
    {"mgt": 124, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 1},
    {"mgt": 127, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 2},
    {"mgt": 127, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 2},
    {"mgt": 124, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 3},
    {"mgt": 124, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 3},
    {"mgt": 127, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 4},
    {"mgt": 127, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 4},
    {"mgt": 125, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 5},
    {"mgt": 125, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 5},
    {"mgt": 126, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 6},
    {"mgt": 126, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 6},
    {"mgt": 125, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 7},
    {"mgt": 125, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 7},
    {"mgt": 126, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 8},
    {"mgt": 126, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 8}
]

# ARF6 #5 (LEFT SIDE SLR 1)
ARF6_TO_MGT_J11 = [
    {"mgt": 127, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 1},
    {"mgt": 127, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 1},
    {"mgt": 124, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 2},
    {"mgt": 124, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 2},
    {"mgt": 127, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 3},
    {"mgt": 127, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 3},
    {"mgt": 124, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 4},
    {"mgt": 124, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 4},
    {"mgt": 126, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 5},
    {"mgt": 126, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 5},
    {"mgt": 125, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 6},
    {"mgt": 125, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 6},
    {"mgt": 126, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 7},
    {"mgt": 126, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 7},
    {"mgt": 125, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 8},
    {"mgt": 125, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 8}
]

# ARF6 #6 (RIGHT SIDE SLR 1)
ARF6_TO_MGT_J7 = [
    {"mgt": 227, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 1},
    {"mgt": 227, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 1},
    {"mgt": 224, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 2},
    {"mgt": 224, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 2},
    {"mgt": 227, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 3},
    {"mgt": 227, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 3},
    {"mgt": 224, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 4},
    {"mgt": 224, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 4},
    {"mgt": 226, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 5},
    {"mgt": 226, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 5},
    {"mgt": 225, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 6},
    {"mgt": 225, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 6},
    {"mgt": 226, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 7},
    {"mgt": 226, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 7},
    {"mgt": 225, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 8},
    {"mgt": 225, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 8}
]

# ARF6 #7 (RIGHT SIDE SLR 1)
ARF6_TO_MGT_J10 = [
    {"mgt": 224, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 1},
    {"mgt": 224, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 1},
    {"mgt": 227, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 2},
    {"mgt": 227, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 2},
    {"mgt": 224, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 3},
    {"mgt": 224, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 3},
    {"mgt": 227, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 4},
    {"mgt": 227, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 4},
    {"mgt": 225, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 5},
    {"mgt": 225, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 5},
    {"mgt": 226, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 6},
    {"mgt": 226, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 6},
    {"mgt": 225, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 7},
    {"mgt": 225, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 7},
    {"mgt": 226, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 8},
    {"mgt": 226, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 8}
]

###############################################################
########################## SLR 2 ARF6 #########################
###############################################################

# ARF6 #8 (LEFT SIDE SLR 2)
ARF6_TO_MGT_J15 = [
    {"mgt": 128, "mgt_chan": 0, "inv": True , "dir": "TX", "arf6_chan": 1},
    {"mgt": 128, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 1},
    {"mgt": 131, "mgt_chan": 2, "inv": True , "dir": "TX", "arf6_chan": 2},
    {"mgt": 131, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 2},
    {"mgt": 128, "mgt_chan": 2, "inv": True , "dir": "TX", "arf6_chan": 3},
    {"mgt": 128, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 3},
    {"mgt": 131, "mgt_chan": 0, "inv": True , "dir": "TX", "arf6_chan": 4},
    {"mgt": 131, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 4},
    {"mgt": 129, "mgt_chan": 0, "inv": True , "dir": "TX", "arf6_chan": 5},
    {"mgt": 129, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 5},
    {"mgt": 130, "mgt_chan": 2, "inv": True , "dir": "TX", "arf6_chan": 6},
    {"mgt": 130, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 6},
    {"mgt": 129, "mgt_chan": 2, "inv": True , "dir": "TX", "arf6_chan": 7},
    {"mgt": 129, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 7},
    {"mgt": 130, "mgt_chan": 0, "inv": True , "dir": "TX", "arf6_chan": 8},
    {"mgt": 130, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 8}
]

# ARF6 #9 (LEFT SIDE SLR 2)
ARF6_TO_MGT_J16 = [
    {"mgt": 131, "mgt_chan": 3, "inv": True , "dir": "TX", "arf6_chan": 1},
    {"mgt": 131, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 1},
    {"mgt": 128, "mgt_chan": 1, "inv": True , "dir": "TX", "arf6_chan": 2},
    {"mgt": 128, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 2},
    {"mgt": 131, "mgt_chan": 1, "inv": True , "dir": "TX", "arf6_chan": 3},
    {"mgt": 131, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 3},
    {"mgt": 128, "mgt_chan": 3, "inv": True , "dir": "TX", "arf6_chan": 4},
    {"mgt": 128, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 4},
    {"mgt": 130, "mgt_chan": 3, "inv": True , "dir": "TX", "arf6_chan": 5},
    {"mgt": 130, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 5},
    {"mgt": 129, "mgt_chan": 1, "inv": True , "dir": "TX", "arf6_chan": 6},
    {"mgt": 129, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 6},
    {"mgt": 130, "mgt_chan": 1, "inv": True , "dir": "TX", "arf6_chan": 7},
    {"mgt": 130, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 7},
    {"mgt": 129, "mgt_chan": 3, "inv": True , "dir": "TX", "arf6_chan": 8},
    {"mgt": 129, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 8}
]

# ARF6 #10 (RIGHT SIDE SLR 2)
ARF6_TO_MGT_J14 = [
    {"mgt": 231, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 1},
    {"mgt": 231, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 1},
    {"mgt": 228, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 2},
    {"mgt": 228, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 2},
    {"mgt": 231, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 3},
    {"mgt": 231, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 3},
    {"mgt": 228, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 4},
    {"mgt": 228, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 4},
    {"mgt": 230, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 5},
    {"mgt": 230, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 5},
    {"mgt": 229, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 6},
    {"mgt": 229, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 6},
    {"mgt": 230, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 7},
    {"mgt": 230, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 7},
    {"mgt": 229, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 8},
    {"mgt": 229, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 8}
]

# ARF6 #11 (RIGHT SIDE SLR 2)
ARF6_TO_MGT_J13 = [
    {"mgt": 228, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 1},
    {"mgt": 228, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 1},
    {"mgt": 231, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 2},
    {"mgt": 231, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 2},
    {"mgt": 228, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 3},
    {"mgt": 228, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 3},
    {"mgt": 231, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 4},
    {"mgt": 231, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 4},
    {"mgt": 229, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 5},
    {"mgt": 229, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 5},
    {"mgt": 230, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 6},
    {"mgt": 230, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 6},
    {"mgt": 229, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 7},
    {"mgt": 229, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 7},
    {"mgt": 230, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 8},
    {"mgt": 230, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 8}
]

###############################################################
########################## SLR 3 ARF6 #########################
###############################################################

# ARF6 #12 (LEFT SIDE SLR 3)
ARF6_TO_MGT_J5 = [
    {"mgt": 132, "mgt_chan": 0, "inv": True , "dir": "TX", "arf6_chan": 1},
    {"mgt": 132, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 1},
    {"mgt": 134, "mgt_chan": 2, "inv": True , "dir": "TX", "arf6_chan": 2},
    {"mgt": 134, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 2},
    {"mgt": 135, "mgt_chan": 2, "inv": True , "dir": "TX", "arf6_chan": 3},
    {"mgt": 132, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 3},
    {"mgt": 135, "mgt_chan": 0, "inv": True , "dir": "TX", "arf6_chan": 4},
    {"mgt": 135, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 4},
    {"mgt": 132, "mgt_chan": 2, "inv": True , "dir": "TX", "arf6_chan": 5},
    {"mgt": 133, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 5},
    {"mgt": 134, "mgt_chan": 0, "inv": True , "dir": "TX", "arf6_chan": 6},
    {"mgt": 135, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 6},
    {"mgt": 133, "mgt_chan": 0, "inv": True , "dir": "TX", "arf6_chan": 7},
    {"mgt": 133, "mgt_chan": 2, "inv": False, "dir": "RX", "arf6_chan": 7},
    {"mgt": 133, "mgt_chan": 2, "inv": True , "dir": "TX", "arf6_chan": 8},
    {"mgt": 134, "mgt_chan": 0, "inv": False, "dir": "RX", "arf6_chan": 8}
]

# ARF6 #13 (LEFT SIDE SLR 3)
ARF6_TO_MGT_J6 = [
    {"mgt": 134, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 1},
    {"mgt": 134, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 1},
    {"mgt": 132, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 2},
    {"mgt": 132, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 2},
    {"mgt": 135, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 3},
    {"mgt": 134, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 3},
    {"mgt": 132, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 4},
    {"mgt": 132, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 4},
    {"mgt": 135, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 5},
    {"mgt": 135, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 5},
    {"mgt": 133, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 6},
    {"mgt": 133, "mgt_chan": 1, "inv": True , "dir": "RX", "arf6_chan": 6},
    {"mgt": 134, "mgt_chan": 1, "inv": False, "dir": "TX", "arf6_chan": 7},
    {"mgt": 135, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 7},
    {"mgt": 133, "mgt_chan": 3, "inv": False, "dir": "TX", "arf6_chan": 8},
    {"mgt": 133, "mgt_chan": 3, "inv": True , "dir": "RX", "arf6_chan": 8}
]

# ARF6 #14 (RIGHT SIDE SLR 3)
ARF6_TO_MGT_J4 = [
    {"mgt": 234, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 1},
    {"mgt": 235, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 1},
    {"mgt": 232, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 2},
    {"mgt": 232, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 2},
    {"mgt": 235, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 3},
    {"mgt": 235, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 3},
    {"mgt": 235, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 4},
    {"mgt": 232, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 4},
    {"mgt": 234, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 5},
    {"mgt": 234, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 5},
    {"mgt": 232, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 6},
    {"mgt": 233, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 6},
    {"mgt": 233, "mgt_chan": 2, "inv": False, "dir": "TX", "arf6_chan": 7},
    {"mgt": 234, "mgt_chan": 0, "inv": True , "dir": "RX", "arf6_chan": 7},
    {"mgt": 233, "mgt_chan": 0, "inv": False, "dir": "TX", "arf6_chan": 8},
    {"mgt": 233, "mgt_chan": 2, "inv": True , "dir": "RX", "arf6_chan": 8}
]

# ARF6 #15 (RIGHT SIDE SLR 3)
ARF6_TO_MGT_J3 = [
    {"mgt": 232, "mgt_chan": 1, "inv": True , "dir": "TX", "arf6_chan": 1},
    {"mgt": 232, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 1},
    {"mgt": 234, "mgt_chan": 3, "inv": True , "dir": "TX", "arf6_chan": 2},
    {"mgt": 234, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 2},
    {"mgt": 232, "mgt_chan": 3, "inv": True , "dir": "TX", "arf6_chan": 3},
    {"mgt": 232, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 3},
    {"mgt": 235, "mgt_chan": 1, "inv": True , "dir": "TX", "arf6_chan": 4},
    {"mgt": 234, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 4},
    {"mgt": 233, "mgt_chan": 1, "inv": True , "dir": "TX", "arf6_chan": 5},
    {"mgt": 233, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 5},
    {"mgt": 235, "mgt_chan": 3, "inv": True , "dir": "TX", "arf6_chan": 6},
    {"mgt": 235, "mgt_chan": 1, "inv": False, "dir": "RX", "arf6_chan": 6},
    {"mgt": 233, "mgt_chan": 3, "inv": True , "dir": "TX", "arf6_chan": 7},
    {"mgt": 233, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 7},
    {"mgt": 234, "mgt_chan": 1, "inv": True , "dir": "TX", "arf6_chan": 8},
    {"mgt": 235, "mgt_chan": 3, "inv": False, "dir": "RX", "arf6_chan": 8}
]

###############################################################
########################## ALL ARF6s ##########################
###############################################################

ARF6_TO_MGT = [ARF6_TO_MGT_J19, ARF6_TO_MGT_J20, ARF6_TO_MGT_J18, ARF6_TO_MGT_J17, # SLR 0
               ARF6_TO_MGT_J12, ARF6_TO_MGT_J11, ARF6_TO_MGT_J7, ARF6_TO_MGT_J10,  # SLR 1
               ARF6_TO_MGT_J15, ARF6_TO_MGT_J16, ARF6_TO_MGT_J14, ARF6_TO_MGT_J13, # SLR 2
               ARF6_TO_MGT_J5, ARF6_TO_MGT_J6, ARF6_TO_MGT_J4, ARF6_TO_MGT_J3]     # SLR 3
ARF6_J_LABELS = ["J19", "J20", "J18", "J17",
                 "J12", "J11", "J7", "J10",
                 "J15", "J16", "J14", "J13",
                 "J5", "J6", "J4", "J3"]

###############################################################
############################ GTYs #############################
###############################################################

GTYS_VU13P_LEFT = list(range(120, 136))
GTYS_VU13P_RIGHT = list(range(220, 236))
GTYS_VU13P = GTYS_VU13P_LEFT + GTYS_VU13P_RIGHT

GTYS_VU27P_LEFT = list(range(124, 128))
GTYS_VU27P_RIGHT = list(range(224, 228))
GTYS_VU27P = GTYS_VU27P_LEFT + GTYS_VU27P_RIGHT

GTYS_LEFT = GTYS_VU27P_LEFT if FPGA_TYPE == "VU27P" else GTYS_VU13P_LEFT if FPGA_TYPE == "VU13P" else None
GTYS_RIGHT = GTYS_VU27P_RIGHT if FPGA_TYPE == "VU27P" else GTYS_VU13P_RIGHT if FPGA_TYPE == "VU13P" else None
GTYS = GTYS_VU27P if FPGA_TYPE == "VU27P" else GTYS_VU13P if FPGA_TYPE == "VU13P" else None
GTYS = [gty for gty in GTYS if gty not in RESERVED_GTYS]

GTY_SLR = {}
GTY_CHAN_LOC = {}

for gty in GTYS:
    x = 0
    y = 0
    if gty in GTYS_LEFT:
        x = 0
        y = (gty - GTYS_LEFT[0]) * 4
    elif gty in GTYS_RIGHT:
        x = 1
        y = (gty - GTYS_RIGHT[0]) * 4
    else:
        print_red("ERROR: unknown GTY for %s: %d" % (FPGA_TYPE, gty))
    chan_locs = []
    for chan in range(4):
        chan_locs.append([x, y + chan])
    GTY_CHAN_LOC[gty] = chan_locs
    GTY_SLR[gty] = 0 if y < 16 else 1 if y < 32 else 2 if y < 48 else 3 if y < 64 else 99

GTY_REFCLK_IDX = [[], []]

heading("REFCLK map")
for refclk01 in range(2):
    print("GTY refclk%d map:" % refclk01)
    for gty in GTYS:
        best_refclk = None
        best_refclk_dist = 99
        for refclk_idx in range(len(REFCLKS[refclk01])):
            refclk = REFCLKS[refclk01][refclk_idx]
            dist = abs(refclk["mgt"] - gty)
            if dist < best_refclk_dist:
                best_refclk = refclk_idx
                best_refclk_dist = dist
        if best_refclk_dist > 2:
            print_red("Closest refclk%d distance for quad %d is more than 2 quads away (closest refclk idx = %d, distance = %d)" % (refclk01, gty, best_refclk, best_refclk_dist))
            exit()
        GTY_REFCLK_IDX[refclk01].append(best_refclk)
        print("GTY %d closest refclk%d = %d (quad %d), distance = %d" % (gty, refclk01, best_refclk, REFCLKS[refclk01][best_refclk]["mgt"], best_refclk_dist))

####################################################################
############################ Cable map #############################
####################################################################

QSFP_PINS = {
    37: {"dir": "TX", "chan": 1, "pol": "n"},
    36: {"dir": "TX", "chan": 1, "pol": "p"},
    34: {"dir": "TX", "chan": 3, "pol": "n"},
    33: {"dir": "TX", "chan": 3, "pol": "p"},
    25: {"dir": "RX", "chan": 4, "pol": "p"},
    24: {"dir": "RX", "chan": 4, "pol": "n"},
    22: {"dir": "RX", "chan": 2, "pol": "p"},
    21: {"dir": "RX", "chan": 2, "pol": "n"},
    2:  {"dir": "TX", "chan": 2, "pol": "n"},
    3:  {"dir": "TX", "chan": 2, "pol": "p"},
    5:  {"dir": "TX", "chan": 4, "pol": "n"},
    6:  {"dir": "TX", "chan": 4, "pol": "p"},
    14: {"dir": "RX", "chan": 3, "pol": "p"},
    15: {"dir": "RX", "chan": 3, "pol": "n"},
    17: {"dir": "RX", "chan": 1, "pol": "p"},
    18: {"dir": "RX", "chan": 1, "pol": "n"}
}

ARF6_PINS = {
    3:  {"dir": "TX", "chan": 1, "pol": "p"},
    5:  {"dir": "TX", "chan": 1, "pol": "n"},
    6:  {"dir": "RX", "chan": 1, "pol": "p"},
    4:  {"dir": "RX", "chan": 1, "pol": "n"},
    45: {"dir": "TX", "chan": 2, "pol": "p"},
    47: {"dir": "TX", "chan": 2, "pol": "n"},
    48: {"dir": "RX", "chan": 2, "pol": "p"},
    46: {"dir": "RX", "chan": 2, "pol": "n"},
    9:  {"dir": "TX", "chan": 3, "pol": "p"},
    11: {"dir": "TX", "chan": 3, "pol": "n"},
    12: {"dir": "RX", "chan": 3, "pol": "p"},
    10: {"dir": "RX", "chan": 3, "pol": "n"},
    39: {"dir": "TX", "chan": 4, "pol": "p"},
    41: {"dir": "TX", "chan": 4, "pol": "n"},
    42: {"dir": "RX", "chan": 4, "pol": "p"},
    40: {"dir": "RX", "chan": 4, "pol": "n"},
    15: {"dir": "TX", "chan": 5, "pol": "p"},
    17: {"dir": "TX", "chan": 5, "pol": "n"},
    18: {"dir": "RX", "chan": 5, "pol": "p"},
    16: {"dir": "RX", "chan": 5, "pol": "n"},
    33: {"dir": "TX", "chan": 6, "pol": "p"},
    35: {"dir": "TX", "chan": 6, "pol": "n"},
    36: {"dir": "RX", "chan": 6, "pol": "p"},
    34: {"dir": "RX", "chan": 6, "pol": "n"},
    21: {"dir": "TX", "chan": 7, "pol": "p"},
    23: {"dir": "TX", "chan": 7, "pol": "n"},
    24: {"dir": "RX", "chan": 7, "pol": "p"},
    22: {"dir": "RX", "chan": 7, "pol": "n"},
    27: {"dir": "TX", "chan": 8, "pol": "p"},
    29: {"dir": "TX", "chan": 8, "pol": "n"},
    30: {"dir": "RX", "chan": 8, "pol": "p"},
    28: {"dir": "RX", "chan": 8, "pol": "n"}
}

# Pin mapping on the cable
# In Samtec drawings:
# J1 -- ARF6 #0
# J2 -- ARF6 #1
# J6 -- FQSFP #0
# J5 -- FQSFP #1
# J4 -- FQSFP #2
# J3 -- FQSFP #3
QUAD_QSFP_CABLE_MAP_PINS = [
    ####################### J1 -- ARF6 #0 #######################
    {"arf6_idx": 0, "arf6_pin": 3,  "qsfp_idx": 0, "qsfp_pin": 36},
    {"arf6_idx": 0, "arf6_pin": 5,  "qsfp_idx": 0, "qsfp_pin": 37},
    {"arf6_idx": 0, "arf6_pin": 9,  "qsfp_idx": 0, "qsfp_pin": 33},
    {"arf6_idx": 0, "arf6_pin": 11, "qsfp_idx": 0, "qsfp_pin": 34},

    {"arf6_idx": 0, "arf6_pin": 15, "qsfp_idx": 1, "qsfp_pin": 36},
    {"arf6_idx": 0, "arf6_pin": 17, "qsfp_idx": 1, "qsfp_pin": 37},
    {"arf6_idx": 0, "arf6_pin": 21, "qsfp_idx": 1, "qsfp_pin": 33},
    {"arf6_idx": 0, "arf6_pin": 23, "qsfp_idx": 1, "qsfp_pin": 34},

    {"arf6_idx": 0, "arf6_pin": 27, "qsfp_idx": 2, "qsfp_pin": 6 },
    {"arf6_idx": 0, "arf6_pin": 29, "qsfp_idx": 2, "qsfp_pin": 5 },
    {"arf6_idx": 0, "arf6_pin": 33, "qsfp_idx": 2, "qsfp_pin": 3 },
    {"arf6_idx": 0, "arf6_pin": 35, "qsfp_idx": 2, "qsfp_pin": 2 },

    {"arf6_idx": 0, "arf6_pin": 39, "qsfp_idx": 3, "qsfp_pin": 6 },
    {"arf6_idx": 0, "arf6_pin": 41, "qsfp_idx": 3, "qsfp_pin": 5 },
    {"arf6_idx": 0, "arf6_pin": 45, "qsfp_idx": 3, "qsfp_pin": 3 },
    {"arf6_idx": 0, "arf6_pin": 47, "qsfp_idx": 3, "qsfp_pin": 2 },

    {"arf6_idx": 0, "arf6_pin": 4,  "qsfp_idx": 0, "qsfp_pin": 17},
    {"arf6_idx": 0, "arf6_pin": 6,  "qsfp_idx": 0, "qsfp_pin": 18},
    {"arf6_idx": 0, "arf6_pin": 10, "qsfp_idx": 0, "qsfp_pin": 14},
    {"arf6_idx": 0, "arf6_pin": 12, "qsfp_idx": 0, "qsfp_pin": 15},

    {"arf6_idx": 0, "arf6_pin": 16, "qsfp_idx": 1, "qsfp_pin": 17},
    {"arf6_idx": 0, "arf6_pin": 18, "qsfp_idx": 1, "qsfp_pin": 18},
    {"arf6_idx": 0, "arf6_pin": 22, "qsfp_idx": 1, "qsfp_pin": 14},
    {"arf6_idx": 0, "arf6_pin": 24, "qsfp_idx": 1, "qsfp_pin": 15},

    {"arf6_idx": 0, "arf6_pin": 28, "qsfp_idx": 2, "qsfp_pin": 25},
    {"arf6_idx": 0, "arf6_pin": 30, "qsfp_idx": 2, "qsfp_pin": 24},
    {"arf6_idx": 0, "arf6_pin": 34, "qsfp_idx": 2, "qsfp_pin": 22},
    {"arf6_idx": 0, "arf6_pin": 36, "qsfp_idx": 2, "qsfp_pin": 21},

    {"arf6_idx": 0, "arf6_pin": 40, "qsfp_idx": 3, "qsfp_pin": 25},
    {"arf6_idx": 0, "arf6_pin": 42, "qsfp_idx": 3, "qsfp_pin": 24},
    {"arf6_idx": 0, "arf6_pin": 46, "qsfp_idx": 3, "qsfp_pin": 22},
    {"arf6_idx": 0, "arf6_pin": 48, "qsfp_idx": 3, "qsfp_pin": 21},

    ####################### J2 -- ARF6 #1 #######################
    {"arf6_idx": 1, "arf6_pin": 3,  "qsfp_idx": 3, "qsfp_pin": 36},
    {"arf6_idx": 1, "arf6_pin": 5,  "qsfp_idx": 3, "qsfp_pin": 37},
    {"arf6_idx": 1, "arf6_pin": 9,  "qsfp_idx": 3, "qsfp_pin": 33},
    {"arf6_idx": 1, "arf6_pin": 11, "qsfp_idx": 3, "qsfp_pin": 34},

    {"arf6_idx": 1, "arf6_pin": 15, "qsfp_idx": 2, "qsfp_pin": 36},
    {"arf6_idx": 1, "arf6_pin": 17, "qsfp_idx": 2, "qsfp_pin": 37},
    {"arf6_idx": 1, "arf6_pin": 21, "qsfp_idx": 2, "qsfp_pin": 33},
    {"arf6_idx": 1, "arf6_pin": 23, "qsfp_idx": 2, "qsfp_pin": 34},

    {"arf6_idx": 1, "arf6_pin": 27, "qsfp_idx": 1, "qsfp_pin": 6 },
    {"arf6_idx": 1, "arf6_pin": 29, "qsfp_idx": 1, "qsfp_pin": 5 },
    {"arf6_idx": 1, "arf6_pin": 33, "qsfp_idx": 1, "qsfp_pin": 3 },
    {"arf6_idx": 1, "arf6_pin": 35, "qsfp_idx": 1, "qsfp_pin": 2 },

    {"arf6_idx": 1, "arf6_pin": 39, "qsfp_idx": 0, "qsfp_pin": 6 },
    {"arf6_idx": 1, "arf6_pin": 41, "qsfp_idx": 0, "qsfp_pin": 5 },
    {"arf6_idx": 1, "arf6_pin": 45, "qsfp_idx": 0, "qsfp_pin": 3 },
    {"arf6_idx": 1, "arf6_pin": 47, "qsfp_idx": 0, "qsfp_pin": 2 },

    {"arf6_idx": 1, "arf6_pin": 4,  "qsfp_idx": 3, "qsfp_pin": 17},
    {"arf6_idx": 1, "arf6_pin": 6,  "qsfp_idx": 3, "qsfp_pin": 18},
    {"arf6_idx": 1, "arf6_pin": 10, "qsfp_idx": 3, "qsfp_pin": 14},
    {"arf6_idx": 1, "arf6_pin": 12, "qsfp_idx": 3, "qsfp_pin": 15},

    {"arf6_idx": 1, "arf6_pin": 16, "qsfp_idx": 2, "qsfp_pin": 17},
    {"arf6_idx": 1, "arf6_pin": 18, "qsfp_idx": 2, "qsfp_pin": 18},
    {"arf6_idx": 1, "arf6_pin": 22, "qsfp_idx": 2, "qsfp_pin": 14},
    {"arf6_idx": 1, "arf6_pin": 24, "qsfp_idx": 2, "qsfp_pin": 15},

    {"arf6_idx": 1, "arf6_pin": 28, "qsfp_idx": 1, "qsfp_pin": 25},
    {"arf6_idx": 1, "arf6_pin": 30, "qsfp_idx": 1, "qsfp_pin": 24},
    {"arf6_idx": 1, "arf6_pin": 34, "qsfp_idx": 1, "qsfp_pin": 22},
    {"arf6_idx": 1, "arf6_pin": 36, "qsfp_idx": 1, "qsfp_pin": 21},

    {"arf6_idx": 1, "arf6_pin": 40, "qsfp_idx": 0, "qsfp_pin": 25},
    {"arf6_idx": 1, "arf6_pin": 42, "qsfp_idx": 0, "qsfp_pin": 24},
    {"arf6_idx": 1, "arf6_pin": 46, "qsfp_idx": 0, "qsfp_pin": 22},
    {"arf6_idx": 1, "arf6_pin": 48, "qsfp_idx": 0, "qsfp_pin": 21},
]

# Pin mapping on the cable
# In Samtec drawings:
# J1 -- ARF6 #0
# J2 -- ARF6 #1
# J6 -- FQSFP #0
# J5 -- FQSFP #1
# J3 and J4 map to FF connectors which are meant for AXI and TCDS, and are not represented here
DUAL_QSFP_AXI_TCDS_CABLE_MAP_PINS = [
    ####################### J1 -- ARF6 #0 #######################
    {"arf6_idx": 0, "arf6_pin": 3,  "qsfp_idx": 0, "qsfp_pin": 36},
    {"arf6_idx": 0, "arf6_pin": 5,  "qsfp_idx": 0, "qsfp_pin": 37},
    {"arf6_idx": 0, "arf6_pin": 9,  "qsfp_idx": 0, "qsfp_pin": 33},
    {"arf6_idx": 0, "arf6_pin": 11, "qsfp_idx": 0, "qsfp_pin": 34},

    {"arf6_idx": 0, "arf6_pin": 15, "qsfp_idx": 1, "qsfp_pin": 36},
    {"arf6_idx": 0, "arf6_pin": 17, "qsfp_idx": 1, "qsfp_pin": 37},
    {"arf6_idx": 0, "arf6_pin": 21, "qsfp_idx": 1, "qsfp_pin": 33},
    {"arf6_idx": 0, "arf6_pin": 23, "qsfp_idx": 1, "qsfp_pin": 34},

    {"arf6_idx": 0, "arf6_pin": 4,  "qsfp_idx": 0, "qsfp_pin": 17},
    {"arf6_idx": 0, "arf6_pin": 6,  "qsfp_idx": 0, "qsfp_pin": 18},
    {"arf6_idx": 0, "arf6_pin": 10, "qsfp_idx": 0, "qsfp_pin": 14},
    {"arf6_idx": 0, "arf6_pin": 12, "qsfp_idx": 0, "qsfp_pin": 15},

    {"arf6_idx": 0, "arf6_pin": 16, "qsfp_idx": 1, "qsfp_pin": 17},
    {"arf6_idx": 0, "arf6_pin": 18, "qsfp_idx": 1, "qsfp_pin": 18},
    {"arf6_idx": 0, "arf6_pin": 22, "qsfp_idx": 1, "qsfp_pin": 14},
    {"arf6_idx": 0, "arf6_pin": 24, "qsfp_idx": 1, "qsfp_pin": 15},

    ####################### J2 -- ARF6 #1 #######################
    {"arf6_idx": 1, "arf6_pin": 27, "qsfp_idx": 1, "qsfp_pin": 6 },
    {"arf6_idx": 1, "arf6_pin": 29, "qsfp_idx": 1, "qsfp_pin": 5 },
    {"arf6_idx": 1, "arf6_pin": 33, "qsfp_idx": 1, "qsfp_pin": 3 },
    {"arf6_idx": 1, "arf6_pin": 35, "qsfp_idx": 1, "qsfp_pin": 2 },

    {"arf6_idx": 1, "arf6_pin": 39, "qsfp_idx": 0, "qsfp_pin": 6 },
    {"arf6_idx": 1, "arf6_pin": 41, "qsfp_idx": 0, "qsfp_pin": 5 },
    {"arf6_idx": 1, "arf6_pin": 45, "qsfp_idx": 0, "qsfp_pin": 3 },
    {"arf6_idx": 1, "arf6_pin": 47, "qsfp_idx": 0, "qsfp_pin": 2 },

    {"arf6_idx": 1, "arf6_pin": 28, "qsfp_idx": 1, "qsfp_pin": 25},
    {"arf6_idx": 1, "arf6_pin": 30, "qsfp_idx": 1, "qsfp_pin": 24},
    {"arf6_idx": 1, "arf6_pin": 34, "qsfp_idx": 1, "qsfp_pin": 22},
    {"arf6_idx": 1, "arf6_pin": 36, "qsfp_idx": 1, "qsfp_pin": 21},

    {"arf6_idx": 1, "arf6_pin": 40, "qsfp_idx": 0, "qsfp_pin": 25},
    {"arf6_idx": 1, "arf6_pin": 42, "qsfp_idx": 0, "qsfp_pin": 24},
    {"arf6_idx": 1, "arf6_pin": 46, "qsfp_idx": 0, "qsfp_pin": 22},
    {"arf6_idx": 1, "arf6_pin": 48, "qsfp_idx": 0, "qsfp_pin": 21},
]

# Construct a cable map of QSFP number and channel to ARF6 number and channel, and note if there is an inversion on the cable
# the map is a 2d array of dictionaries where the first array index refers to the QSFP index on the cable, and the second index refers to the QSFP channel

def find_arf6_pin(qsfp_idx, qsfp_chan, qsfp_dir, qsfp_pol, cable_pin_map):
    for cable_wire in cable_pin_map:
        qsfp_pin = QSFP_PINS[cable_wire["qsfp_pin"]]
        arf6_idx = cable_wire["arf6_idx"]
        arf6_pin = ARF6_PINS[cable_wire["arf6_pin"]]

        if cable_wire["qsfp_idx"] == qsfp_idx and qsfp_pin["chan"] == qsfp_chan + 1 and qsfp_pin["dir"] == qsfp_dir and qsfp_pin["pol"] == qsfp_pol:
            return arf6_idx, arf6_pin

def create_cable_map(num_qsfps, cable_pin_map):
    ret = []
    for qsfp_idx in range(num_qsfps):
        chans = []
        for qsfp_chan in range(4):
            for qsfp_dir in ["TX", "RX"]:
                arf6_idx_p, arf6_pin_p = find_arf6_pin(qsfp_idx, qsfp_chan, qsfp_dir, "p", cable_pin_map)
                arf6_idx_n, arf6_pin_n = find_arf6_pin(qsfp_idx, qsfp_chan, qsfp_dir, "n", cable_pin_map)

                if arf6_idx_p != arf6_idx_n or arf6_pin_p["chan"] != arf6_pin_n["chan"] or arf6_pin_p["dir"] != arf6_pin_n["dir"]:
                    print_red("QSFP cable ERROR: QSFP %d chan %d dir %s differential pair pins map to different ARF6 idx, chan, or dir" % (qsfp_idx, qsfp_chan, qsfp_dir))
                    exit()

                if arf6_pin_p["dir"] != qsfp_dir or arf6_pin_n["dir"] != qsfp_dir:
                    print_red("QSFP cable ERROR: QSFP %d chan %d dir %s pins map to a different direction in ARF6" % (qsfp_idx, qsfp_chan, qsfp_dir))
                    exit()

                inverted = None
                if arf6_pin_p["pol"] == "p" and arf6_pin_n["pol"] == "n":
                    inverted = False
                elif arf6_pin_p["pol"] == "n" and arf6_pin_n["pol"] == "p":
                    inverted = True
                else:
                    print_red("QSFP cable ERROR: QSFP %d chan %d dir %s pins map to unknown polarity on the ARF6 side" % (qsfp_idx, qsfp_chan, qsfp_dir))
                    exit()

                chan = {"qsfp_chan": qsfp_chan, "dir": qsfp_dir, "arf6_idx": arf6_idx_p, "arf6_chan": arf6_pin_p["chan"], "inv": inverted}
                chans.append(chan)

        ret.append(chans)
    return ret

QUAD_QSFP_CABLE_MAP = create_cable_map(4, QUAD_QSFP_CABLE_MAP_PINS)
DUAL_QSFP_CABLE_MAP = create_cable_map(2, QUAD_QSFP_CABLE_MAP_PINS)

# Define cable connections from each QSFP on the front panel to the ARF6s, and construct a full front panel QSFP to ARF6 connection map
# QSFPs are numbered from left (board bottom side) to right (board top side) and from top (crate top) to bottom (crate bottom) like this:
# 0  |  1
# 2  |  3
# 4  |  5
# .....
# 28 | 29

CABLE_CONNECTIONS = [
    # Octopus left
    {"type": "quad", "qsfp_idx": [0,  1,  2,  3 ], "arf6_j_labels": ["J19", "J20"]},
    {"type": "dual", "qsfp_idx": [4,  5 ],         "arf6_j_labels": ["J12", "J11"]},
    {"type": "quad", "qsfp_idx": [6,  7,  8,  9 ], "arf6_j_labels": ["J15", "J16"]},
    {"type": "quad", "qsfp_idx": [10, 11, 12, 13], "arf6_j_labels": ["J5",  "J6" ]},
    # Octopus right
    {"type": "quad", "qsfp_idx": [14, 15, 16, 17], "arf6_j_labels": ["J4",  "J3" ]},
    {"type": "quad", "qsfp_idx": [18, 19, 20, 21], "arf6_j_labels": ["J14", "J13"]},
    {"type": "quad", "qsfp_idx": [22, 23, 24, 25], "arf6_j_labels": ["J7",  "J10"]},
    {"type": "quad", "qsfp_idx": [26, 27, 28, 29], "arf6_j_labels": ["J18", "J17"]}
]

def find_qsfp_cable(qsfp_idx):
    for cable in CABLE_CONNECTIONS:
        if qsfp_idx in cable["qsfp_idx"]:
            return cable

QSFP_TO_MGT = []
for qsfp_idx in range(30):
    cable = find_qsfp_cable(qsfp_idx)
    qsfp_connector_idx = cable["qsfp_idx"].index(qsfp_idx)
    qsfp_entry = []
    for qsfp_chan_idx in range(8): # 4 TX and 4 RX channels
        exp_dir = "TX" if qsfp_chan_idx % 2 == 0 else "RX"
        qsfp_chan = int(qsfp_chan_idx / 2)
        cable_map = QUAD_QSFP_CABLE_MAP if cable["type"] == "quad" else DUAL_QSFP_CABLE_MAP if cable["type"] == "dual" else None
        cable_map_entry = cable_map[qsfp_connector_idx][qsfp_chan_idx]

        if cable_map_entry["qsfp_chan"] != qsfp_chan:
            print_red("Unexpected QSFP channel in the cable map")
            exit()
        if cable_map_entry["dir"] != exp_dir:
            print_red("Unexpected QSFP direction in the cable map")
            exit()

        cable_arf6_idx = cable_map_entry["arf6_idx"]
        cable_arf6_chan = cable_map_entry["arf6_chan"]
        cable_inverted = cable_map_entry["inv"]
        arf6_j_label = cable["arf6_j_labels"][cable_arf6_idx]

        arf6_to_mgt_map = ARF6_TO_MGT[ARF6_J_LABELS.index(arf6_j_label)]
        # find the entry in the map with the required ARF6 channel and direction
        arf6_to_mgt_map_entry = None
        for entry in arf6_to_mgt_map:
            if entry["arf6_chan"] == cable_arf6_chan and entry["dir"] == exp_dir:
                arf6_to_mgt_map_entry = entry
                break

        inverted = False if (cable_inverted and arf6_to_mgt_map_entry) or ((not cable_inverted) and (not arf6_to_mgt_map_entry)) else True
        qsfp_chan_entry = {"mgt": arf6_to_mgt_map_entry["mgt"], "mgt_chan": arf6_to_mgt_map_entry["mgt_chan"], "inv": inverted, "dir": exp_dir, "qsfp_chan": qsfp_chan, "arf6_j_label": arf6_j_label}
        qsfp_entry.append(qsfp_chan_entry)
    QSFP_TO_MGT.append(qsfp_entry)

######### when using QSFP-DD optical module with UCLA cables, the map is just hard-coded using UCLA's map #########
######### NOTE: in this case only half of the channels are available                                      #########
if USE_QSFPDD:
    QSFP_TO_MGT = [
        ########## QSFP 0 ##########
        [
            {'mgt': 220, 'mgt_chan': 3, 'inv': False, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J17'},
            {'mgt': 221, 'mgt_chan': 1, 'inv': True, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J17'},
            {'mgt': 220, 'mgt_chan': 2, 'inv': True, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J18'},
            {'mgt': 220, 'mgt_chan': 0, 'inv': False, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J18'},
            {'mgt': 221, 'mgt_chan': 1, 'inv': False, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J17'},
            {'mgt': 220, 'mgt_chan': 3, 'inv': True, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J17'},
            {'mgt': 221, 'mgt_chan': 0, 'inv': True, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J18'},
            {'mgt': 220, 'mgt_chan': 2, 'inv': False, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J18'}
        ],
        ########## QSFP 1 ##########
        [
            {'mgt': 223, 'mgt_chan': 2, 'inv': True, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J18'},
            {'mgt': 223, 'mgt_chan': 2, 'inv': False, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J18'},
            {'mgt': 223, 'mgt_chan': 3, 'inv': False, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J17'},
            {'mgt': 222, 'mgt_chan': 1, 'inv': True, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J17'},
            {'mgt': 223, 'mgt_chan': 0, 'inv': False, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J18'},
            {'mgt': 223, 'mgt_chan': 0, 'inv': False, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J18'},
            {'mgt': 223, 'mgt_chan': 1, 'inv': False, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J17'},
            {'mgt': 223, 'mgt_chan': 3, 'inv': True, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J17'}
        ],
        ########## QSFP 2 ##########
        [
            {'mgt': 224, 'mgt_chan': 1, 'inv': False, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J10'},
            {'mgt': 224, 'mgt_chan': 1, 'inv': True, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J10'},
            {'mgt': 224, 'mgt_chan': 0, 'inv': False, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J7'},
            {'mgt': 224, 'mgt_chan': 0, 'inv': False, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J7'},
            {'mgt': 224, 'mgt_chan': 3, 'inv': False, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J10'},
            {'mgt': 224, 'mgt_chan': 3, 'inv': True, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J10'},
            {'mgt': 224, 'mgt_chan': 2, 'inv': False, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J7'},
            {'mgt': 224, 'mgt_chan': 2, 'inv': False, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J7'}
        ],
        ########## QSFP 3 ##########
        [
            {'mgt': 227, 'mgt_chan': 2, 'inv': False, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J7'},
            {'mgt': 227, 'mgt_chan': 2, 'inv': False, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J7'},
            {'mgt': 227, 'mgt_chan': 3, 'inv': False, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J10'},
            {'mgt': 227, 'mgt_chan': 3, 'inv': True, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J10'},
            {'mgt': 227, 'mgt_chan': 0, 'inv': False, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J7'},
            {'mgt': 227, 'mgt_chan': 0, 'inv': False, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J7'},
            {'mgt': 227, 'mgt_chan': 1, 'inv': False, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J10'},
            {'mgt': 227, 'mgt_chan': 1, 'inv': True, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J10'}
        ],
        ########## QSFP 4 ##########
        [
            {'mgt': 228, 'mgt_chan': 1, 'inv': False, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J13'},
            {'mgt': 228, 'mgt_chan': 1, 'inv': False, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J13'},
            {'mgt': 228, 'mgt_chan': 0, 'inv': False, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J14'},
            {'mgt': 228, 'mgt_chan': 0, 'inv': True, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J14'},
            {'mgt': 228, 'mgt_chan': 3, 'inv': False, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J13'},
            {'mgt': 228, 'mgt_chan': 3, 'inv': False, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J13'},
            {'mgt': 228, 'mgt_chan': 2, 'inv': False, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J14'},
            {'mgt': 228, 'mgt_chan': 2, 'inv': True, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J14'}
        ],
        ########## QSFP 5 ##########
        [
            {'mgt': 231, 'mgt_chan': 2, 'inv': False, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J14'},
            {'mgt': 231, 'mgt_chan': 2, 'inv': True, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J14'},
            {'mgt': 231, 'mgt_chan': 3, 'inv': False, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J13'},
            {'mgt': 231, 'mgt_chan': 3, 'inv': False, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J13'},
            {'mgt': 231, 'mgt_chan': 0, 'inv': False, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J14'},
            {'mgt': 231, 'mgt_chan': 0, 'inv': True, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J14'},
            {'mgt': 231, 'mgt_chan': 1, 'inv': False, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J13'},
            {'mgt': 231, 'mgt_chan': 1, 'inv': False, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J13'}
        ],
        ########## QSFP 6 ##########
        [
            {'mgt': 232, 'mgt_chan': 1, 'inv': True, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J3'},
            {'mgt': 232, 'mgt_chan': 1, 'inv': False, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J3'},
            {'mgt': 232, 'mgt_chan': 0, 'inv': False, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J4'},
            {'mgt': 232, 'mgt_chan': 0, 'inv': True, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J4'},
            {'mgt': 232, 'mgt_chan': 3, 'inv': True, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J3'},
            {'mgt': 232, 'mgt_chan': 3, 'inv': False, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J3'},
            {'mgt': 235, 'mgt_chan': 2, 'inv': False, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J4'},
            {'mgt': 232, 'mgt_chan': 2, 'inv': True, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J4'}
        ],
        ########## QSFP 7 ##########
        [
            {'mgt': 234, 'mgt_chan': 2, 'inv': False, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J4'},
            {'mgt': 235, 'mgt_chan': 2, 'inv': True, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J4'},
            {'mgt': 234, 'mgt_chan': 3, 'inv': True, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J3'},
            {'mgt': 234, 'mgt_chan': 1, 'inv': False, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J3'},
            {'mgt': 235, 'mgt_chan': 0, 'inv': False, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J4'},
            {'mgt': 235, 'mgt_chan': 0, 'inv': True, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J4'},
            {'mgt': 235, 'mgt_chan': 1, 'inv': True, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J3'},
            {'mgt': 234, 'mgt_chan': 3, 'inv': False, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J3'}
        ],
        ########## QSFP 8 ##########
        [
            {'mgt': 134, 'mgt_chan': 3, 'inv': False, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J6'},
            {'mgt': 134, 'mgt_chan': 1, 'inv': True, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J6'},
            {'mgt': 134, 'mgt_chan': 2, 'inv': True, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J5'},
            {'mgt': 134, 'mgt_chan': 2, 'inv': False, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J5'},
            {'mgt': 135, 'mgt_chan': 1, 'inv': False, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J6'},
            {'mgt': 134, 'mgt_chan': 3, 'inv': True, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J6'},
            {'mgt': 135, 'mgt_chan': 0, 'inv': True, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J5'},
            {'mgt': 135, 'mgt_chan': 0, 'inv': False, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J5'}
        ],
        ########## QSFP 9 ##########
        [
            {'mgt': 132, 'mgt_chan': 0, 'inv': True, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J5'},
            {'mgt': 132, 'mgt_chan': 0, 'inv': False, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J5'},
            {'mgt': 132, 'mgt_chan': 1, 'inv': False, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J6'},
            {'mgt': 132, 'mgt_chan': 1, 'inv': True, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J6'},
            {'mgt': 135, 'mgt_chan': 2, 'inv': True, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J5'},
            {'mgt': 132, 'mgt_chan': 2, 'inv': False, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J5'},
            {'mgt': 132, 'mgt_chan': 3, 'inv': False, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J6'},
            {'mgt': 132, 'mgt_chan': 3, 'inv': True, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J6'}
        ],
        ########## QSFP 10 ##########
        [
            {'mgt': 131, 'mgt_chan': 3, 'inv': True, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J16'},
            {'mgt': 131, 'mgt_chan': 3, 'inv': True, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J16'},
            {'mgt': 131, 'mgt_chan': 2, 'inv': True, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J15'},
            {'mgt': 131, 'mgt_chan': 2, 'inv': False, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J15'},
            {'mgt': 131, 'mgt_chan': 1, 'inv': True, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J16'},
            {'mgt': 131, 'mgt_chan': 1, 'inv': True, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J16'},
            {'mgt': 131, 'mgt_chan': 0, 'inv': True, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J15'},
            {'mgt': 131, 'mgt_chan': 0, 'inv': False, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J15'}
        ],
        ########## QSFP 11 ##########
        [
            {'mgt': 128, 'mgt_chan': 0, 'inv': True, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J15'},
            {'mgt': 128, 'mgt_chan': 0, 'inv': False, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J15'},
            {'mgt': 128, 'mgt_chan': 1, 'inv': True, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J16'},
            {'mgt': 128, 'mgt_chan': 1, 'inv': True, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J16'},
            {'mgt': 128, 'mgt_chan': 2, 'inv': True, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J15'},
            {'mgt': 128, 'mgt_chan': 2, 'inv': False, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J15'},
            {'mgt': 128, 'mgt_chan': 3, 'inv': True, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J16'},
            {'mgt': 128, 'mgt_chan': 3, 'inv': True, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J16'}
        ],
        ########## QSFP 12 ##########
        [
            {'mgt': 124, 'mgt_chan': 0, 'inv': False, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J12'},
            {'mgt': 124, 'mgt_chan': 0, 'inv': True, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J12'},
            {'mgt': 124, 'mgt_chan': 1, 'inv': False, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J11'},
            {'mgt': 124, 'mgt_chan': 1, 'inv': False, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J11'},
            {'mgt': 124, 'mgt_chan': 2, 'inv': False, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J12'},
            {'mgt': 124, 'mgt_chan': 2, 'inv': True, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J12'},
            {'mgt': 124, 'mgt_chan': 3, 'inv': False, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J11'},
            {'mgt': 124, 'mgt_chan': 3, 'inv': False, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J11'}
        ],
        ########## QSFP 13 ##########
        [
            {'mgt': 123, 'mgt_chan': 3, 'inv': True, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J20'},
            {'mgt': 122, 'mgt_chan': 1, 'inv': False, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J20'},
            {'mgt': 123, 'mgt_chan': 2, 'inv': False, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J19'},
            {'mgt': 123, 'mgt_chan': 2, 'inv': True, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J19'},
            {'mgt': 123, 'mgt_chan': 1, 'inv': True, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J20'},
            {'mgt': 123, 'mgt_chan': 3, 'inv': False, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J20'},
            {'mgt': 123, 'mgt_chan': 0, 'inv': True, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J19'},
            {'mgt': 123, 'mgt_chan': 0, 'inv': True, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J19'}
        ],
        ########## QSFP 14 ##########
        [
            {'mgt': 120, 'mgt_chan': 2, 'inv': False, 'dir': 'TX', 'qsfp_chan': 0, 'arf6_j_label': 'J19'},
            {'mgt': 120, 'mgt_chan': 2, 'inv': True, 'dir': 'RX', 'qsfp_chan': 0, 'arf6_j_label': 'J19'},
            {'mgt': 120, 'mgt_chan': 3, 'inv': True, 'dir': 'TX', 'qsfp_chan': 1, 'arf6_j_label': 'J20'},
            {'mgt': 121, 'mgt_chan': 1, 'inv': False, 'dir': 'RX', 'qsfp_chan': 1, 'arf6_j_label': 'J20'},
            {'mgt': 121, 'mgt_chan': 0, 'inv': False, 'dir': 'TX', 'qsfp_chan': 2, 'arf6_j_label': 'J19'},
            {'mgt': 120, 'mgt_chan': 0, 'inv': True, 'dir': 'RX', 'qsfp_chan': 2, 'arf6_j_label': 'J19'},
            {'mgt': 121, 'mgt_chan': 1, 'inv': True, 'dir': 'TX', 'qsfp_chan': 3, 'arf6_j_label': 'J20'},
            {'mgt': 120, 'mgt_chan': 3, 'inv': False, 'dir': 'RX', 'qsfp_chan': 3, 'arf6_j_label': 'J20'}
        ]
    ]

# print the cable map
print("")
print("============================================================")
print("==   QSFP connections to MGT using the remapping cables   ==")
print("============================================================")
for qsfp_idx in range(len(QSFP_TO_MGT)):
    qsfp = QSFP_TO_MGT[qsfp_idx]
    tx_mgts_used = {}
    rx_mgts_used = {}
    print("")
    print("=============== QSFP %d ===============" % qsfp_idx)
    for qsfp_chan in range(4):
        tx_chan = qsfp[qsfp_chan * 2]
        rx_chan = qsfp[qsfp_chan * 2 + 1]

        if (tx_chan["qsfp_chan"] != qsfp_chan) or (tx_chan["dir"] != "TX") or (rx_chan["qsfp_chan"] != qsfp_chan) or (rx_chan["dir"] != "RX") or (tx_chan["arf6_j_label"] != rx_chan["arf6_j_label"]):
            print_red("Something wrong in the QSFP cable map, didn't get the expected qsfp channel or direction, or mismached tx/rx arf6 j label when printing the table, check the code")
            exit()

        arf6_j_label = tx_chan["arf6_j_label"]
        print("Channel %d: TX MGT %d_%d, RX MGT %d_%d (ARF6 %s)" % (qsfp_chan, tx_chan["mgt"], tx_chan["mgt_chan"], rx_chan["mgt"], rx_chan["mgt_chan"], arf6_j_label))

        if not tx_chan["mgt"] in tx_mgts_used:
            tx_mgts_used[tx_chan["mgt"]] = [tx_chan["mgt_chan"]]
        else:
            if tx_chan["mgt_chan"] in tx_mgts_used[tx_chan["mgt"]]:
                print_red("Something is wrong in the QSFP to ARF6 map -- the same TX MGT channel is used twice!")
                exit()
            tx_mgts_used[tx_chan["mgt"]].append(tx_chan["mgt_chan"])

        if not rx_chan["mgt"] in rx_mgts_used:
            rx_mgts_used[rx_chan["mgt"]] = [rx_chan["mgt_chan"]]
        else:
            if rx_chan["mgt_chan"] in rx_mgts_used[rx_chan["mgt"]]:
                print_red("Something is wrong in the QSFP to ARF6 map -- the same RX MGT channel is used twice!")
                exit()
            rx_mgts_used[rx_chan["mgt"]].append(rx_chan["mgt_chan"])

        if tx_chan["mgt"] != rx_chan["mgt"]:
            print_color("! this QSFP channel is connected to different MGT quads", Colors.YELLOW)
        elif tx_chan["mgt_chan"] != rx_chan["mgt_chan"]:
            print_color("! this QSFP channel is connected to different MGT channels", Colors.YELLOW)

    if len(tx_mgts_used) == 1 and len(rx_mgts_used) == 1:
        print_green("==> This QSFP is fully mapped to a single MGT quad")
    else:
        print_color("==> This QSFP is mapped to multiple MGT quads", Colors.YELLOW)

###############################################################
############ MGT & LINK CODE GENERATIONS FUNCTIONS ############
###############################################################

def check_arf6_map():
    gtys_used = []
    for arf6 in ARF6_TO_MGT:
        for arf6_chan in arf6:
            chan = "%s-%s%s" % (arf6_chan["mgt"], arf6_chan["dir"], arf6_chan["mgt_chan"])
            if chan in gtys_used:
                print_red("Channel %s is used twice!" % chan)
                return
            gtys_used.append(chan)

    for gty in GTYS:
        for chan in range(4):
            for dir in range(2):
                dirstr = "TX" if dir == 0 else "RX"
                chanstr = "%s-%s%s" % (gty, dirstr, chan)
                if chanstr not in gtys_used:
                    print_red("Channel %s is not in the ARF6 map!" % chanstr)
                    return

    print_green("The ARF6 to MGT map looks good (all GTY channels are used, and there are no duplicates)")

def bool_str_lower(b):
    ret = ("%r" % b).lower()
    if b:
        ret += " "
    return ret

# also returns gty_chan_idx map to tx/rx fiber idx
def generate_fiber_to_mgt_vhdl():
    gty_chan_to_fiber = [{} for i in range(len(GTYS) * 4)]
    fiber_to_slr = {}
    print("constant CFG_FIBER_TO_MGT_MAP : t_fiber_to_mgt_link_map := (")
    fiber_idx = 0
    for qsfp_idx in range(len(QSFP_TO_MGT)):
        qsfp = QSFP_TO_MGT[qsfp_idx]
        first = True
        for qsfp_chan_idx in range(0, len(qsfp), 2):
            qsfp_tx_chan = qsfp[qsfp_chan_idx]
            qsfp_rx_chan = qsfp[qsfp_chan_idx + 1]
            if qsfp_tx_chan["mgt"] not in GTYS and qsfp_rx_chan["mgt"] not in GTYS:
                continue
            if first:
                print("    --========= QSFP #%d =========--" % (qsfp_idx))
                first = False

            if qsfp_tx_chan["dir"] != "TX" or qsfp_rx_chan["dir"] != "RX":
                print_red("ERROR: unexpected QSFP channel direction (QSFP #%d chan #%d)" % (qsfp_idx, qsfp_chan_idx))
                return

            tx_gty_idx = GTYS.index(qsfp_tx_chan["mgt"])
            rx_gty_idx = GTYS.index(qsfp_rx_chan["mgt"])
            tx_gty_chan_idx = tx_gty_idx * 4  + qsfp_tx_chan["mgt_chan"]
            rx_gty_chan_idx = rx_gty_idx * 4 + qsfp_rx_chan["mgt_chan"]

            gty_chan_to_fiber[tx_gty_chan_idx]["tx"] = fiber_idx
            gty_chan_to_fiber[rx_gty_chan_idx]["rx"] = fiber_idx
            slr = GTY_SLR[qsfp_tx_chan["mgt"]]
            if slr != GTY_SLR[qsfp_rx_chan["mgt"]]:
                print_red("Mixed SLR on TX and RX fiber pair!")
                return

            fiber_to_slr[fiber_idx] = slr

            # fiber_idx = arf6_idx * 8 + arf6_chan_idx / 2
            print("    (%03d, %03d, %s, %s), -- fiber %d (SLR %d)" % (tx_gty_chan_idx, rx_gty_chan_idx, bool_str_lower(qsfp_tx_chan["inv"]), bool_str_lower(qsfp_rx_chan["inv"]), fiber_idx, slr))
            fiber_idx += 1

    print("    --=== DUMMY fiber - use for unconnected channels ===--")
    print("    (MGT_NULL, MGT_NULL, false, false)")
    print(");")

    return gty_chan_to_fiber, fiber_to_slr

def generate_refclk_constraints(refclk01):
    sync_async = "(async)" if refclk01 == 0 else "(sync) " if refclk01 == 1 else None
    print("###############################################################")
    print("####################### REFCLK%d %s #######################" % (refclk01, sync_async))
    print("###############################################################")
    print("")
    for i in range(len(REFCLKS[refclk01])):
        refclk = REFCLKS[refclk01][i]
        period = 1000.0 / refclk["freq"]
        desc = "%s (%.2fMHz)" % (refclk["schematic_name"], refclk["freq"])
        if refclk01 == 1:
            desc = "%s (Si5395J out%d, %.2fMHz)" % (refclk["schematic_name"], refclk["si_out"], refclk["freq"])
        print("# --------- Quad %d: %s ---------" % (refclk["mgt"], desc))
        print("set_property PACKAGE_PIN %s [get_ports {refclk%d_p_i[%d]}]" % (refclk["pin_p"], refclk01, i))
        print("create_clock -period %.3f -name mgt_refclk%d_%d [get_ports {refclk%d_p_i[%d]}]" % (period, refclk01, i, refclk01, i))
        print("set_clock_groups -group [get_clocks mgt_refclk%d_%d] -asynchronous" % (refclk01, i))
        print("")

def generate_loc_constraints():
    print("###############################################################")
    print("########################### MGT LOC ###########################")
    print("###############################################################")
    print("")
    chan = 0
    for gty in GTYS:
        loc = GTY_CHAN_LOC[gty]
        for quad_chan in range(4):
            quad_chan_loc = loc[quad_chan]
            print("set_property LOC GTYE4_CHANNEL_X%dY%d [get_cells {i_mgts/g_channels[%d].g_chan_*/i_gty_channel}]" % (quad_chan_loc[0], quad_chan_loc[1], chan))
            chan += 1

    print("")
    print("###############################################################")
    print("########################## IBERT LOC ##########################")
    print("###############################################################")
    print("")
    chan = 0
    for gty in GTYS:
        loc = GTY_CHAN_LOC[gty]
        for quad_chan in range(4):
            quad_chan_loc = loc[quad_chan]
            print("set_property -dict [list C_GTS_USED X%dY%d C_QUAD_NUMBER_0 16'd%d] [get_cells {i_mgts/g_channels[%d].g_insys_ibert.i_ibert/inst}]" % (quad_chan_loc[0], quad_chan_loc[1], gty, chan))
            chan += 1

###############################################################
################# GEM/CSC CODE GEN FUNCTIONS ##################
###############################################################

# also returns MGT types needed
def generate_gem_oh_link_map(fiber_to_slr):
    NUM_LINKS = len(QSFP_TO_MGT) * 4
    MAX_OHS = 48 if NUM_LINKS >= 60 else 4 if NUM_LINKS <= 16 else None # use 48 OHs on VU13P (max GE21 OHs), and 4 OHs on VU27P

    ## GE11 (dummy for now)
    ge11_link_types = []
    print("    constant CFG_OH_LINK_CONFIG_ARR_GE11 : t_oh_link_config_arr := (")
    for oh in range(MAX_OHS):
        comma = "," if oh < MAX_OHS - 1 else ""
        ge11_link_types.extend(["CFG_MGT_TYPE_NULL"] * 2)
        print("        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))%s" % (comma))
    print("    );")
    print("")

    ## GE21
    ge21_link_types = []
    print("    constant CFG_OH_LINK_CONFIG_ARR_GE21 : t_oh_link_config_arr := (")
    if GE21_NUM_OH % NUM_SLR != 0:
        print_red("ERROR: number of GE21 OHs (%d) is not divisible by number of SLRs (%d)" % (GE21_NUM_OH, NUM_SLR))
        return
    oh_per_slr = int(GE21_NUM_OH / NUM_SLR)
    fiber = 0
    for oh in range(MAX_OHS):
        comma = "," if oh < MAX_OHS - 1 else ""
        if oh >= GE21_NUM_OH or fiber >= NUM_LINKS:
            # fill the rest with dummies
            print("        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))%s" % (comma))
            continue

        slr = int(oh / oh_per_slr)
        while fiber_to_slr[fiber] != slr or fiber_to_slr[fiber + 1] != slr:
            fiber += 2
            ge21_link_types.extend(["CFG_MGT_TYPE_NULL"] * 2)

        gbt_tx = [fiber, fiber + 1]
        gbt_rx = gbt_tx
        fiber += 2
        ge21_link_types.extend(["CFG_MGT_GBTX"] * 2)
        print("        (((%03d, %03d), (%03d, %03d), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))%s -- OH%d, SLR %d" % (gbt_tx[0], gbt_rx[0], gbt_tx[1], gbt_rx[1], comma, oh, slr))

    print("    );")
    print("")

    ## ME0
    me0_link_types = []
    print("    constant CFG_OH_LINK_CONFIG_ARR_ME0 : t_oh_link_config_arr := (")
    if ME0_NUM_OH % NUM_SLR != 0:
        print_red("ERROR: number of ME0 OHs (%d) is not divisible by number of SLRs (%d)" % (ME0_NUM_OH, NUM_SLR))
        return
    oh_per_slr = int(ME0_NUM_OH / NUM_SLR)
    fiber = 0
    for oh in range(MAX_OHS):
        comma = "," if oh < MAX_OHS - 1 else ""
        if oh >= ME0_NUM_OH or fiber >= NUM_LINKS:
            # fill the rest with dummies
            print("        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))%s" % (comma))
            continue

        slr = int(oh / oh_per_slr)
        while fiber_to_slr[fiber] != slr or fiber_to_slr[fiber + 1] != slr or fiber_to_slr[fiber + 2] != slr or fiber_to_slr[fiber + 3] != slr or fiber_to_slr[fiber + 4] != slr or fiber_to_slr[fiber + 5] != slr or fiber_to_slr[fiber + 6] != slr or fiber_to_slr[fiber + 7] != slr:
            fiber += 8
            me0_link_types.extend(["CFG_MGT_TYPE_NULL"] * 8)

        gbt_tx = [fiber, fiber + 1, fiber + 2, fiber + 3]
        gbt_rx = [fiber, fiber + 1, fiber + 2, fiber + 3, fiber + 4, fiber + 5, fiber + 6, fiber + 7]
        fiber += 8
        me0_link_types.extend(["CFG_MGT_LPGBT"] * 8)
        print("        (((%03d, %03d), (TXRX_NULL, %03d), (%03d, %03d),  (TXRX_NULL, %03d),  (%03d, %03d),   (TXRX_NULL, %03d),  (%03d, %03d),  (TXRX_NULL, %03d)), (LINK_NULL, LINK_NULL))%s -- OH%d, SLR %d" %
              (gbt_tx[0], gbt_rx[0], gbt_rx[1], gbt_tx[1], gbt_rx[2], gbt_rx[3], gbt_tx[2], gbt_rx[4], gbt_rx[5], gbt_tx[3], gbt_rx[6], gbt_rx[7], comma, oh, slr))
    print("    );")

    return ge11_link_types, ge21_link_types, me0_link_types

# also returns MGT types needed
def generate_csc_dmb_link_map(fiber_to_slr):
    NUM_LINKS = len(QSFP_TO_MGT) * 4
    MAX_DMBS = 56 if NUM_LINKS >= 96 else 4 if NUM_LINKS <= 16 else None # use 56 DMBs on VU13P, and 4 DMBs on VU27P

    ## GE21
    csc_link_types = []
    print("    constant CFG_DMB_CONFIG_ARR : t_dmb_config_arr := (")
    if CSC_NUM_DMB % NUM_SLR != 0:
        print_red("ERROR: number of CSC DMBs (%d) is not divisible by number of SLRs (%d)" % (CSC_NUM_DMB, NUM_SLR))
        return
    dmb_per_slr = int(CSC_NUM_DMB / NUM_SLR)
    fiber = 0
    for dmb in range(MAX_DMBS):
        comma = "," if dmb < MAX_DMBS - 1 else ""
        if dmb >= CSC_NUM_DMB or fiber >= NUM_LINKS:
            # fill the rest with dummies
            print("        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS))%s" % (comma))
            continue

        slr = int(dmb / dmb_per_slr)
        while fiber_to_slr[fiber] != slr:
            fiber += 1
            csc_link_types.extend(["CFG_MGT_TYPE_NULL"] * 1)

        rx = [fiber]
        fiber += 1
        csc_link_types.extend(["CFG_MGT_DMB"] * 1)
        print("        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (%d, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS))%s -- DMB%d, SLR %d" % (rx[0], comma, dmb, slr))

    print("    );")
    print("")

    return csc_link_types


MGT_TYPE_QPLL = {"CFG_MGT_TYPE_NULL": "QPLL_NULL", "CFG_MGT_GBTX": "QPLL_GBTX", "CFG_MGT_LPGBT": "QPLL_LPGBT", "CFG_MGT_GBE": "QPLL_GBE_156",
                 "CFG_MGT_DMB": "QPLL_DMB_GBE_156", "CFG_MGT_ODMB57": "QPLL_ODMB57_156"}
NUM_IBERTS_PER_MGT_TYPE = {"CFG_MGT_TYPE_NULL": 0, "CFG_MGT_GBTX": 2, "CFG_MGT_LPGBT": 8, "CFG_MGT_GBE": 1,
                           "CFG_MGT_DMB": 1, "CFG_MGT_ODMB57": 1}

def generate_mgt_config(name, link_types, gty_chan_to_fiber):
    mgt_type_chars = len(max(MGT_TYPE_QPLL.keys(), key=len))
    qpll_type_chars = len(max(MGT_TYPE_QPLL.values(), key=len))
    print("    constant %s : t_mgt_config_arr := (" % name)
    mgt_types_used = []
    for quad_idx in range(len(GTYS)):
        quad = GTYS[quad_idx]
        slr = GTY_SLR[quad]
        qpll_type = None
        qpll_idx = quad_idx * 4
        num_iberts_left = NUM_IBERTS_PER_MGT_TYPE
        print("        ----------------------------- quad %d (SLR %d) -----------------------------" % (quad, slr))
        for quad_chan_idx in range(4):
            idx = quad_idx * 4 + quad_chan_idx
            comma = "," if idx < len(GTYS) * 4 - 1 else ""
            tx_fiber = gty_chan_to_fiber[idx]["tx"] if "tx" in gty_chan_to_fiber[idx] else 999
            rx_fiber = gty_chan_to_fiber[idx]["rx"] if "rx" in gty_chan_to_fiber[idx] else 999
            tx_type = link_types[tx_fiber] if tx_fiber < len(link_types) else "CFG_MGT_TYPE_NULL"
            rx_type = link_types[rx_fiber] if rx_fiber < len(link_types) else "CFG_MGT_TYPE_NULL"
            if tx_type != rx_type and tx_type != "CFG_MGT_TYPE_NULL" and rx_type != "CFG_MGT_TYPE_NULL":
                print_red("TX/RX link type conflict on MGT channel #%d (quad %d): tx_type = %s, rx_type = %s" % (idx, quad, tx_type, rx_type))
                return

            mgt_type = tx_type if tx_type != "CFG_MGT_TYPE_NULL" else rx_type if rx_type != "CFG_MGT_TYPE_NULL" else "CFG_MGT_TYPE_NULL"
            qpll_type_needed = MGT_TYPE_QPLL[mgt_type]
            qpll_inst = "QPLL_NULL"
            if qpll_type is None and qpll_type_needed != "QPLL_NULL":
                qpll_type = qpll_type_needed
                qpll_inst = qpll_type_needed
            elif qpll_type is not None and qpll_type_needed != "QPLL_NULL" and qpll_type != qpll_type_needed:
                print_red("QPLL type conflict on MGT channel #%d (quad %d): qpll type needed = %s, but the quad has instantiated type %s" % (idx, quad, qpll_type_needed, qpll_type))
                return

            is_master = "true " if mgt_type not in mgt_types_used and mgt_type != "CFG_MGT_TYPE_NULL" else "false"
            mgt_types_used.append(mgt_type)
            ibert_inst = "true " if num_iberts_left[mgt_type] > 0 else "false"
            num_iberts_left[mgt_type] -= 1

            refclk0_idx = GTY_REFCLK_IDX[0][quad_idx]
            refclk1_idx = GTY_REFCLK_IDX[1][quad_idx]

            print("        (mgt_type => %s, qpll_inst_type => %s, qpll_idx => %03d, refclk0_idx => %02d, refclk1_idx => %d, is_master => %s, ibert_inst => %s)%s" %
                  (mgt_type.ljust(mgt_type_chars), qpll_inst.ljust(qpll_type_chars), qpll_idx, refclk0_idx, refclk1_idx, is_master, ibert_inst, comma))

    print("    );")

###############################################################
############################# MAIN ############################
###############################################################

if __name__ == '__main__':
    heading("ARF6 to MGT map check")
    check_arf6_map()

    heading("MGT constraints")
    generate_refclk_constraints(0)
    generate_refclk_constraints(1)
    generate_loc_constraints()

    heading("fiber to MGT map")
    gty_chan_to_fiber, fiber_to_slr = generate_fiber_to_mgt_vhdl()

    heading("GEM OH link map")
    ge11_link_types, ge21_link_types, me0_link_types = generate_gem_oh_link_map(fiber_to_slr)
    heading("GEM MGT configuration")
    generate_mgt_config("CFG_MGT_LINK_CONFIG_GE11", ge11_link_types, gty_chan_to_fiber)
    generate_mgt_config("CFG_MGT_LINK_CONFIG_GE21", ge21_link_types, gty_chan_to_fiber)
    generate_mgt_config("CFG_MGT_LINK_CONFIG_ME0", me0_link_types, gty_chan_to_fiber)

    heading("CSC OH link map")
    csc_link_types = generate_csc_dmb_link_map(fiber_to_slr)
    heading("CSC MGT configuration")
    generate_mgt_config("CFG_MGT_LINK_CONFIG", csc_link_types, gty_chan_to_fiber)
