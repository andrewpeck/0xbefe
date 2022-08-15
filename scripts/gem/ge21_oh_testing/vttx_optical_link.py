import sys
import os
from os import path
import subprocess
from time import *

from common.rw_reg import *
from common.fw_utils import *

from test_utils import *

def Trigger_reset():
    write_reg(get_node('BEFE.GEM.TRIGGER.CTRL.MODULE_RESET'), 1)
    return

def read_vttx_optical_link(verbose=False):
    Link_CNT = []
    Delta_Link_CNT = []
    Link_CNT.append(read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK0_MISSED_COMMA_CNT')))
    Link_CNT.append(read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK1_MISSED_COMMA_CNT')))
    Link_CNT.append(read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK0_OVERFLOW_CNT')))
    Link_CNT.append(read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK1_OVERFLOW_CNT')))
    Link_CNT.append(read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK0_UNDERFLOW_CNT')))
    Link_CNT.append(read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK1_UNDERFLOW_CNT')))
    if verbose:
        print('VTTX Optical Link Readings First Read:')
        readKW('BEFE.GEM.TRIGGER.OH0') # prints status for log file

    sleep(3)
    Delta_Link_CNT.append(read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK0_MISSED_COMMA_CNT')) - Link_CNT[0])
    Delta_Link_CNT.append(read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK1_MISSED_COMMA_CNT')) - Link_CNT[1])
    Delta_Link_CNT.append(read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK0_OVERFLOW_CNT')) - Link_CNT[2])
    Delta_Link_CNT.append(read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK1_OVERFLOW_CNT')) - Link_CNT[3])
    Delta_Link_CNT.append(read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK0_UNDERFLOW_CNT')) - Link_CNT[4])
    Delta_Link_CNT.append(read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK1_UNDERFLOW_CNT')) - Link_CNT[5])
    if verbose:
        print('VTTX Optical Link Readings Second Read (3s Delay):')
        readKW('BEFE.GEM.TRIGGER.OH0') # prints status for log file
    return [Link_CNT , Delta_Link_CNT]

def check_vttx_optical_link_result(VTTX_Result, verbose=False):
    PF_Flag = True
    ErrorMessage = []
    regs = ['BEFE.GEM.TRIGGER.OH0.LINK0_MISSED_COMMA_CNT', 'BEFE.GEM.TRIGGER.OH0.LINK1_MISSED_COMMA_CNT', 'BEFE.GEM.TRIGGER.OH0.LINK0_OVERFLOW_CNT', 'BEFE.GEM.TRIGGER.OH0.LINK1_OVERFLOW_CNT','BEFE.GEM.TRIGGER.OH0.LINK0_UNDERFLOW_CNT','BEFE.GEM.TRIGGER.OH0.LINK1_UNDERFLOW_CNT']
    expectedValue = 2   # Should be less Than 2 for all Readings
    for ii in range(len(VTTX_Result[0])):
        if VTTX_Result[0][ii] > expectedValue:
            PF_Flag = False
            ErrorMessage.append(regs[ii] + ' = ' + str(VTTX_Result[0][ii]))

    for ii in range(len(VTTX_Result[1])):
        if VTTX_Result[1][ii] > 0:
            PF_Flag = False
            ErrorMessage.append(regs[ii] + ' Incremented by: ' +str(VTTX_Result[1][ii]+'  Between Reads'))

    return [PF_Flag, ErrorMessage]


########################################################################################################################################

def vttx_link_health_test():

    PASS = True

#    write_reg(get_node('BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET'), 1)
#    sleep(0.25)
    write_reg(get_node('BEFE.GEM.TRIGGER.CTRL.CNT_RESET'), 1)
    write_reg(get_node('BEFE.GEM.TRIGGER.CTRL.MODULE_RESET'), 1)
    print('Sleeping, to build up Bits Tx\'d for VTTX Health Test...')
    sleep(300)
    print('Done Sleeping!')
    # verify error counters are 0 or low value, not increment
    PASS = check_vttx_link()

    word = ''
    if PASS:
        word = 'PASSED'
    else :
        word = 'FAILED'

    print('Test VTTX Optical Links with CTP7: %s' % word)

    return PASS


def check_vttx_link():
    #returns true if test passes
    passFail = True

    link0_missed = read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK0_MISSED_COMMA_CNT'))
    link1_missed = read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK1_MISSED_COMMA_CNT'))
    link0_overflow = read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK0_OVERFLOW_CNT'))
    link1_overflow = read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK1_OVERFLOW_CNT'))
    link0_underflow = read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK0_UNDERFLOW_CNT'))
    link1_underflow = read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK1_UNDERFLOW_CNT'))

    # wait a few seconds to ensure no increment
    sleep(1)

    cntChange = link0_missed - read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK0_MISSED_COMMA_CNT'))
    if cntChange != 0:
        print('FAIL: BEFE.GEM.TRIGGER.OH0.LINK0_MISSED_COMMA_CNT incremented by, %d' % cntChange)
        passFail = False

    cntChange = link1_missed - read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK1_MISSED_COMMA_CNT'))
    if cntChange != 0:
        print('FAIL: BEFE.GEM.TRIGGER.OH0.LINK1_MISSED_COMMA_CNT incremented by, %d' % cntChange)
        passFail = False

    cntChange = link0_overflow - read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK0_OVERFLOW_CNT'))
    if cntChange != 0:
        print('FAIL: BEFE.GEM.TRIGGER.OH0.LINK0_OVERFLOW_CNT incremented by, %d' % cntChange)
        passFail = False

    cntChange =  link1_overflow - read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK1_OVERFLOW_CNT'))
    if cntChange != 0:
        print('FAIL: BEFE.GEM.TRIGGER.OH0.LINK1_OVERFLOW_CNT incremented by, %d' % cntChange)
        passFail = False

    cntChange = link0_underflow - read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK0_UNDERFLOW_CNT'))
    if cntChange != 0:
        print('FAIL: BEFE.GEM.TRIGGER.OH0.LINK0_UNDERFLOW_CNT incremented by, %d' % cntChange)
        passFail = False

    cntChange = link1_underflow - read_reg(get_node('BEFE.GEM.TRIGGER.OH0.LINK1_UNDERFLOW_CNT'))
    if cntChange != 0:
        print('FAIL: BEFE.GEM.TRIGGER.OH0.LINK1_UNDERFLOW_CNT incremented by, %d' % cntChange)
        passFail = False


    print('readKW BEFE.GEM.TRIGGER.OH0')
    print_red("NEED TO IMPLEMENT READKW!")
    # readKW('BEFE.GEM.TRIGGER.OH0') # prints status for log file

    return passFail
