from common.rw_reg import *
from common.utils import *

from time import *

################################################################################################
def read_GBT_Status(gbt, verbose=False):
    Status_Reg = []
    Status_Reg.append(read_reg('BEFE.GEM.OH_LINKS.OH0.GBT'+str(gbt)+'_READY'))
    Status_Reg.append(read_reg('BEFE.GEM.OH_LINKS.OH0.GBT'+str(gbt)+'_WAS_NOT_READY'))
    Status_Reg.append(read_reg('BEFE.GEM.OH_LINKS.OH0.GBT'+str(gbt)+'_RX_HAD_OVERFLOW'))
    Status_Reg.append(read_reg('BEFE.GEM.OH_LINKS.OH0.GBT'+str(gbt)+'_RX_HAD_UNDERFLOW'))
    if(verbose):
        print('readKW OH_LINKS.OH0.GBT'+str(gbt))
        readKW('OH_LINKS.OH0.GBT'+str(gbt))
    return Status_Reg

def gbt_link_reset():
    write_reg("BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET", 1)

def Check_GBT_Flags(GBT_0_Status, GBT_1_Status, verbose=False):
    PF_Flag = True
    ErrorMessage = []
    regs_PRE = 'BEFE.GEM.OH_LINKS.OH0.GBT'
    regs_POST = ['_READY', '_WAS_NOT_READY', '_RX_HAD_OVERFLOW', '_RX_HAD_UNDERFLOW']
    expectedValue = [1 , 0 , 0 , 0]
    for ii in range(len(expectedValue)):
        if GBT_0_Status[ii] != expectedValue[ii]:
            PF_Flag = False
            ErrorMessage.append(regs_PRE + '0' + regs_POST[ii] + '  =  ' + str(GBT_0_Status[ii]))
        if GBT_1_Status[ii] != expectedValue[ii]:
            PF_Flag = False
            ErrorMessage.append(regs_PRE + '1' + regs_POST[ii] + '  =  ' + str(GBT_1_Status[ii]))
    return [PF_Flag, ErrorMessage]

def read_SCA_Status(verbose=False):
    Status_Reg = []
    Status_Reg.append(read_reg('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.READY'))
    Status_Reg.append(read_reg('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.CRITICAL_ERROR'))
    Status_Reg.append(read_reg('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.NOT_READY_CNT_OH0'))
    sleep(3)
    Status_Reg.append(read_reg('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.NOT_READY_CNT_OH0') - Status_Reg[-1])
    if(verbose):
        readKW('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.READY')
        readKW('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.CRITICAL_ERROR')
        readKW('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.NOT_READY_CNT_OH0')
    return Status_Reg

def SCA_reset():
    write_reg('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.MODULE_RESET', 1)
    return

def Check_SCA_Flags(SCA_Status, verbose=False):
    PF_Flag = True
    ErrorMessage = []
    regs = ['BEFE.GEM.SLOW_CONTROL.SCA.STATUS.READY' , 'BEFE.GEM.SLOW_CONTROL.SCA.STATUS.CRITICAL_ERROR', 'BEFE.GEM.SLOW_CONTROL.SCA.STATUS.NOT_READY_CNT_OH0', 'NOT_READY Increment']
    expectedValue = [1 , 0 , 2, 0]
    for ii in range(len(SCA_Status)):
        if SCA_Status[ii] != expectedValue[ii]:
            PF_Flag = False
            ErrorMessage.append(regs[ii] + '  =  ' + str(SCA_Status[ii]))

    return [PF_Flag, ErrorMessage]

################################################################################################

def check_GBTx_transmission_CTP7():
    #returns true if test passes
    passFAIL = True

    #perform link-reset
    write_reg('BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET', 1)

    #check GBT0
    if read_reg('BEFE.GEM.OH_LINKS.OH0.GBT0_READY') == 0:
        passFAIL =  False
    if read_reg('BEFE.GEM.OH_LINKS.OH0.GBT0_WAS_NOT_READY') == 1:
        passFAIL =  False
    if read_reg('BEFE.GEM.OH_LINKS.OH0.GBT0_RX_HAD_OVERFLOW') == 1:
        passFAIL =  False
    if read_reg('BEFE.GEM.OH_LINKS.OH0.GBT0_RX_HAD_UNDERFLOW') == 1:
        passFAIL =  False
    #check GBT1
    if read_reg('BEFE.GEM.OH_LINKS.OH0.GBT1_READY') == 0:
        passFAIL =  False
    if read_reg('BEFE.GEM.OH_LINKS.OH0.GBT1_WAS_NOT_READY') == 1:
        passFAIL =  False
    if read_reg('BEFE.GEM.OH_LINKS.OH0.GBT1_RX_HAD_OVERFLOW') == 1:
        passFAIL =  False
    if read_reg('BEFE.GEM.OH_LINKS.OH0.GBT1_RX_HAD_UNDERFLOW') == 1:
        passFAIL =  False

    print('readKW OH_LINKS.OH0.GBT')
    readKW('OH_LINKS.OH0.GBT') # prints status for log file

    return passFAIL

def check_SCA_ASIC():
    #returns true if test passes
    passFAIL = True

    # clear error counters + reset SCA
    write_reg('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.MODULE_RESET', 1)

    if read_reg('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.READY') != 1:
        print("FAIL: SCA ASIC not READY!")
        passFAIL =  False
    if read_reg('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.CRITICAL_ERROR') != 0:
        print("FAIL: SCA ASIC nonzero critical error count!")
        passFAIL =  False

    errorCount = read_reg('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.NOT_READY_CNT_OH0')
    if errorCount > 2:
        print("WARN: more errors that usual\n BEFE.GEM.SLOW_CONTROL.SCA.STATUS.NOT_READY_CNT_OH0 = %d" % errorCount)
    #wait a few seconds between reads to ensure no increment
    sleep(3)
    errorCount -= read_reg('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.NOT_READY_CNT_OH0')
    if errorCount != 0:
        print("FAIL: SCA ASIC error counter increasing!")
        passFAIL =  False

    readKW('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.READY')
    readKW('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.CRITICAL_ERROR')
    readKW('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.NOT_READY_CNT_OH0')
    return passFAIL

def readKW(args):
    nodes = get_nodes_containing(args)
    if nodes is not None:
        for reg in nodes:
            if 'r' in str(reg.permission):
                print(display_reg(reg))
            elif reg.isModule:
                print(hex(reg.address).rstrip('L') + " " + reg.permission + '\t' + tab_pad(reg.name, 7)) #,'Module!'
            else:
                print(hex(reg.address).rstrip('L') + " " + reg.permission + '\t' + tab_pad(reg.name, 7)) #,'No read permission!'
    else:
        print(args + ' not found!')
