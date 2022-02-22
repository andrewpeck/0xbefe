import sys
import os

# number of words to check in PRBS loopback test, NOTE: UNITS ARE IN 1 MILLION WORDS
MWRD_LIMIT = 125000

# BER acceptance
BER_Acceptance_Criteria = 10 ** -12

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
