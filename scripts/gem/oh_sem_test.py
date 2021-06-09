from time import *
from rw_reg import *

OH_NUM = 0
SLEEP = 1.0
SLEEP_AFTER_SOFT_RESET = 16.5
SLEEP_AFTER_HARD_RESET = 0.3
DO_SOFT_RESET = False
DO_HARD_RESET = False
TEST_SINGLE = False
NUM_ADDRESSES_TO_TEST = 1000

def main():

    parseXML()

    if DO_HARD_RESET:
        print("hard resetting the FPGA")
        writeReg(getNode('GEM_AMC.TTC.GENERATOR.ENABLE'), 1)
        writeReg(getNode('GEM_AMC.TTC.GENERATOR.SINGLE_HARD_RESET'), 1)
        print("waiting for the FPGA to load")
        sleep(SLEEP_AFTER_HARD_RESET)
        print("waiting for the SEM IP to initialize")
        init = 1
        obs = 0
        while init == 1 or obs == 0:
            init = parseInt(readReg(getNode("GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_INITIALIZATION")))
            obs = parseInt(readReg(getNode("GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_OBSERVATION")))
        print("=============== SEM IP is initialized and in OBSERVATION state ===============")

    addr = 0
#   if DO_SOFT_RESET:
#       print("entering idle state")
#       writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_LSBS'), addr)
#       writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xe0) # enter idle state
#       writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
#       sleep(SLEEP)
#       print("applying soft reset to the SEM IP")
#       writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xb0) # soft reset
#       writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
#       sleep(SLEEP_AFTER_SOFT_RESET)

    if TEST_SINGLE:
        injectSingle(0, True)
        corrCnt, critCnt = readSemCounters()
        print("num corrections: %d, num critical errors: %d" % (corrCnt, critCnt))
        return

    corrCntPrev, critCntPrev = readSemCounters()
    for addr in range(NUM_ADDRESSES_TO_TEST):
        injectSingle(0, False)
        corrCnt, critCnt = readSemCounters()
        if corrCnt - corrCntPrev != 1 or critCnt - critCntPrev != 0:
            print("ERROR: the correction count didn't increase by 1 or a critical error was found. Correction cnt = %d, previous correction cnt = %d, critical error cnt = %d, previous critical error cnt = %d" % corrCnt, corrCntPrev, critCnt, critCntPrev)
            return
        corrCntPrev = corrCnt
        critCntPrev = critCnt

    print("DONE, tested injection at %d addresses, and found the correct number of errors" % NUM_ADDRESSES_TO_TEST)
    corrCnt, critCnt = readSemCounters()
    print("num corrections: %d, num critical errors: %d" % (corrCnt, critCnt))

def injectSingle(addr, verbose=True):
    if verbose:
        print("entering idle state")
    writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_LSBS'), addr)
    writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xe0) # enter idle state
    writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
    idle = 0
    while idle == 0:
        idle = parseInt(readReg(getNode("GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_IDLE")))
    if verbose:
        print("injecting an error at address: %d" % addr)
    writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xc0) # inject error
    writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
    inj = 1
    while inj == 1:
        inj = parseInt(readReg(getNode("GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_INJECTION")))
    if verbose:
        print("entering observation state")
    writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xa0) # enter observation state
    writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
    obs = 0
    while obs == 0:
        obs = parseInt(readReg(getNode("GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_OBSERVATION")))
    sleep(0.1)

def readSemCounters():
    corrCnt = parseInt(readReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.CNT_SEM_CORRECTION')))
    critCnt = parseInt(readReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.CNT_SEM_CRITICAL')))
    return corrCnt, critCnt


if __name__ == '__main__':
    main()

