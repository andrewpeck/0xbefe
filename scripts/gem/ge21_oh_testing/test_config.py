import sys
import os

# 10^12 = 8*10^6[MegaWord] * 0.125*10^6
BER_Acceptance_Criteria = 12500
MWRD_LIMIT = 125000

# Number of iterations for testing OH FPGA Loading Path
PROMless_Load_Iters = 1000

PHASE_SCAN_NUM_SLOW_CONTROL_READS = 10000
PHASE_SCAN_FPGA_ACCUM_TIME = 10 # [ s ]

########## JUST FOR DEVELOPMENT, TO REMOVE!!!!!!!!! #############
# PROMless_Load_Iters = 10
# PHASE_SCAN_NUM_SLOW_CONTROL_READS = 100
# PHASE_SCAN_FPGA_ACCUM_TIME = 0 # [ s ]
# MWRD_LIMIT = 1
#################################################################
