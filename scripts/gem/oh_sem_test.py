from time import *
from rw_reg import *

OH_NUM = 0
SLEEP = 1.0
SLEEP_AFTER_SOFT_RESET = 16.5
SLEEP_AFTER_HARD_RESET = 0.3
SLEEP_AFTER_OBSERVATION_SINGLE = 0.06 # the time we give the SEM IP to find a single error after entering observation state
SLEEP_AFTER_OBSERVATION_UNCORR = 0.2 # the time we give the SEM IP to find an uncorrectable error after entering observation state
DO_SOFT_RESET = False
DO_HARD_RESET = True
TEST_SINGLE = False
TEST_CRITICAL = False
NUM_ADDRESSES_TO_TEST = 50

def main():

    parseXML()

    if DO_HARD_RESET:
        print("hard resetting the FPGA")
        writeReg(getNode('GEM_AMC.SLOW_CONTROL.SCA.CTRL.MODULE_RESET'), 1)
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
        injectSemError(0, True)
        readSemCounters(True)
        readSemStatus(True)
        return

    if TEST_CRITICAL:
        injectSemError(0, True, True)
        readSemCounters(True)
        readSemStatus(True)
        return

    print("Running the test of injecting an error to %d addresses (this will take a few minutes)" % NUM_ADDRESSES_TO_TEST)
    corrCntPrev, critCntPrev = readSemCounters()
    for addr in range(NUM_ADDRESSES_TO_TEST):
        if addr % 100 == 0:
            print("Progress: injecting to address %d" % addr)
        injectSemError(0, False)
        corrCnt, critCnt = readSemCounters(False)
        if corrCnt - corrCntPrev != 1 or critCnt - critCntPrev != 0:
            print("ERROR: the correction count didn't increase by 1 or a critical error was found. Correction cnt = %d, previous correction cnt = %d, critical error cnt = %d, previous critical error cnt = %d" % (corrCnt, corrCntPrev, critCnt, critCntPrev))
            return
        corrCntPrev = corrCnt
        critCntPrev = critCnt

    print("DONE, tested injection at %d addresses, and found the correct number of errors" % NUM_ADDRESSES_TO_TEST)
    readSemCounters(True)
    readSemStatus(True)

def injectSemError(address, verbose=True, injectCritical=False):

    # enter idle state
    if verbose:
        print("entering idle state")
    writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xe0)
    writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
    idle = 0
    while idle == 0:
        idle = parseInt(readReg(getNode("GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_IDLE")))

    # inject error(s)
    addresses = [address] if not injectCritical else range(address, address + 10, 1)

    if verbose:
        if injectCritical:
            print("injecting an uncorrectable error at addresses: %s" % (addresses))
        else:
            print("injecting an error at address: %d" % addresses[0])

    for addr in addresses:
        writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_LSBS'), addr)
        writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xc0)
        writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
        inj = 1
        while inj == 1:
            inj = parseInt(readReg(getNode("GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_INJECTION")))

    # enter observation state
    if verbose:
        print("entering observation state")
    writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xa0)
    writeReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
    if not injectCritical:
        obs = 0
        while obs == 0:
            obs = parseInt(readReg(getNode("GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_OBSERVATION")))
    sleepTime = SLEEP_AFTER_OBSERVATION_SINGLE if not injectCritical else SLEEP_AFTER_OBSERVATION_UNCORR
    sleep(sleepTime)

def readSemCounters(verbose=False):
    corrCnt = parseInt(readReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.CNT_SEM_CORRECTION')))
    critCnt = parseInt(readReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.CNT_SEM_CRITICAL')))
    if verbose:
        print("num corrections: %d, num critical errors: %d" % (corrCnt, critCnt))

    return corrCnt, critCnt

def readSemStatus(verbose=False):
    init = parseInt(readReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_INITIALIZATION')))
    obs = parseInt(readReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_OBSERVATION')))
    corr = parseInt(readReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_CORRECTION')))
    classif = parseInt(readReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_CLASSIFICATION')))
    inj = parseInt(readReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_INJECTION')))
    ess = parseInt(readReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_ESSENTIAL')))
    uncorr = parseInt(readReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_UNCORRECTABLE')))
    idle = parseInt(readReg(getNode('GEM_AMC.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_IDLE')))

    if verbose:
        print("SEM status:")
        print("    * initialization = %d" % init)
        print("    * observation = %d" % obs)
        print("    * correction = %d" % corr)
        print("    * classification = %d" % classif)
        print("    * injection = %d" % inj)
        print("    * essential = %d" % ess)
        print("    * uncorrectable = %d" % uncorr)
        print("    * idle = %d" % idle)

    return init, obs, corr, classif, inj, ess, uncorr, idle

if __name__ == '__main__':
    main()
