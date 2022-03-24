import sys
import os

TEST_STAND_LOCATION = "TAMU-CVP13"

##################### FULL TEST #################################
# number of words to check in PRBS loopback test, NOTE: UNITS ARE IN 1 MILLION WORDS
MWRD_LIMIT_FULL = 125000
# Number of iterations for testing OH FPGA Loading Path
PROMless_Load_Iters_FULL = 1000
# VTTX link testing time: number of seconds to wait after resetting the error counters
VTTX_testing_time_FULL = 300
#################################################################

##################### REDUCED TEST #################################
# number of words to check in PRBS loopback test, NOTE: UNITS ARE IN 1 MILLION WORDS
MWRD_LIMIT_REDUCED = 1250
# Number of iterations for testing OH FPGA Loading Path
PROMless_Load_Iters_REDUCED = 100
# VTTX link testing time: number of seconds to wait after resetting the error counters
VTTX_testing_time_REDUCED = 30
#################################################################

# BER acceptance
BER_Acceptance_Criteria = 10 ** -12

PHASE_SCAN_NUM_SLOW_CONTROL_READS = 10000
PHASE_SCAN_FPGA_ACCUM_TIME = 10 # [ s ]
NUM_DAQ_PACKETS=1000000
PHASE_SCAN_L1A_GAP = 40


########## JUST FOR DEVELOPMENT, TO REMOVE!!!!!!!!! #############
# PROMless_Load_Iters = 10
# PHASE_SCAN_NUM_SLOW_CONTROL_READS = 100
# PHASE_SCAN_FPGA_ACCUM_TIME = 0 # [ s ]
# MWRD_LIMIT = 1
#################################################################
