from time import *
from common.rw_reg import *

OH_NUM = 0
SLEEP = 1.0
SLEEP_AFTER_SOFT_RESET = 8.25 # @ 80MHz
SLEEP_AFTER_HARD_RESET = 0.3
SLEEP_AFTER_OBSERVATION_SINGLE = (22.875 + 0.76 + 0.9375) / 1000.0 # the time we give the SEM IP to find a single error after entering observation state (22.875ms for scanning the whole device + 0.76ms for correction + 0.9375ms for classification @ 80MHz clock)
SLEEP_AFTER_OBSERVATION_TWO_ADJ = (22.875 + 23.4875 + 0.9375) / 1000.0 # the time we give the SEM IP to find an uncorrectable error after entering observation state (22.875ms for scanning the whole device + 23.4875ms for correction + 0.9375ms for classification @ 80MHz clock)
SLEEP_AFTER_OBSERVATION_UNCORR = (22.875 + 11.3875 + 0.0125) / 1000.0 # the time we give the SEM IP to find an uncorrectable error after entering observation state (22.875ms for scanning the whole device + 11.3875ms for attempted correction + 0.0125ms for classification @ 80MHz clock)
DO_SOFT_RESET = False
DO_HARD_RESET = True
TEST_SINGLE = False
TEST_DOUBLE_ADJACENT = False
TEST_CRITICAL = False
TEST_MULTI_DOUBLE_ADJACENT = False
NUM_ADDRESSES_TO_TEST = 50
INJECT_ADDR_START = 65000000

def main():

    parse_xml()

    if DO_HARD_RESET:
        print("hard resetting the FPGA")
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.MODULE_RESET'), 1)
        write_reg(get_node('BEFE.GEM.TTC.GENERATOR.ENABLE'), 1)
        write_reg(get_node('BEFE.GEM.TTC.GENERATOR.SINGLE_HARD_RESET'), 1)
        print("waiting for the FPGA to load")
        sleep(SLEEP_AFTER_HARD_RESET)
        print("waiting for the SEM IP to initialize")
        init = 1
        obs = 0
        while init == 1 or obs == 0:
            init = read_reg(get_node("BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_INITIALIZATION"))
            obs = read_reg(get_node("BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_OBSERVATION"))
        print("=============== SEM IP is initialized and in OBSERVATION state ===============")

    addr = 0
#   if DO_SOFT_RESET:
#       print("entering idle state")
#       write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_LSBS'), addr)
#       write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xe0) # enter idle state
#       write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
#       sleep(SLEEP)
#       print("applying soft reset to the SEM IP")
#       write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xb0) # soft reset
#       write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
#       sleep(SLEEP_AFTER_SOFT_RESET)

    if TEST_SINGLE:
        injectSemError(INJECT_ADDR_START, True)
        readSemCounters(True)
        readSemStatus(True)
        return

    if TEST_CRITICAL:
        injectSemError(INJECT_ADDR_START, True, True)
        readSemCounters(True)
        readSemStatus(True)
        return

    if TEST_DOUBLE_ADJACENT:
        injectSemError(INJECT_ADDR_START, True, False, True)
        readSemCounters(True)
        readSemStatus(True)
        return

    print("Running the test of injecting an error to %d addresses (this will take a few minutes)" % NUM_ADDRESSES_TO_TEST)
    corrCntPrev, critCntPrev = readSemCounters()
    for addr in range(NUM_ADDRESSES_TO_TEST):
        if addr % 100 == 0:
            print("Progress: injecting to address %d" % addr)
        injectSemError(INJECT_ADDR_START, False, False, TEST_MULTI_DOUBLE_ADJACENT)
        corrCnt, critCnt = readSemCounters(False)
        if corrCnt - corrCntPrev != 1 or critCnt - critCntPrev != 0:
            print("ERROR: the correction count didn't increase by 1 or a critical error was found. Correction cnt = %d, previous correction cnt = %d, critical error cnt = %d, previous critical error cnt = %d" % (corrCnt, corrCntPrev, critCnt, critCntPrev))
            return
        corrCntPrev = corrCnt
        critCntPrev = critCnt

    print("DONE, tested injection at %d addresses, and found the correct number of errors" % NUM_ADDRESSES_TO_TEST)
    readSemCounters(True)
    readSemStatus(True)

def injectSemError(address, verbose=True, injectCritical=False, injectDoubleAdjacent=False):

    # enter idle state
    if verbose:
        print("entering idle state")
    write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xe0)
    write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
    idle = 0
    while idle == 0:
        idle = read_reg(get_node("BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_IDLE"))

    # inject error(s)
    addresses = range(address, address + 3, 2) if injectCritical else range(address, address + 2, 1) if injectDoubleAdjacent else [address]

    if verbose:
        if injectCritical:
            print("injecting an uncorrectable error at addresses: %s" % (addresses))
        elif injectDoubleAdjacent:
            print("injecting two correctable errors to adjacent bits at addresses: %s" % (addresses))
        else:
            print("injecting an error at address: %d" % addresses[0])

    for addr in addresses:
        write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_LSBS'), addr)
        write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xc0)
        write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
        inj = 1
        while inj == 1:
            inj = read_reg(get_node("BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_INJECTION"))

    # enter observation state
    if verbose:
        print("entering observation state")
    write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.INJ_ADDR_MSBS'), 0xa0)
    write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.INJ_PULSE'), 1)
    if not injectCritical:
        obs = 0
        while obs == 0:
            obs = read_reg(get_node("BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_OBSERVATION"))
    sleepTime = SLEEP_AFTER_OBSERVATION_UNCORR if injectCritical else SLEEP_AFTER_OBSERVATION_TWO_ADJ if injectDoubleAdjacent else SLEEP_AFTER_OBSERVATION_SINGLE
    if verbose:
        print("Waiting %fms to allow for detection of the error, attempted correction, and classification" % (sleepTime * 1000))
    sleep(sleepTime)

def readSemCounters(verbose=False):
    corrCnt = read_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.CNT_SEM_CORRECTION'))
    critCnt = read_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.CNT_SEM_CRITICAL'))
    if verbose:
        print("num corrections: %d, num critical errors: %d" % (corrCnt, critCnt))

    return corrCnt, critCnt

def readSemStatus(verbose=False):
    init = read_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_INITIALIZATION'))
    obs = read_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_OBSERVATION'))
    corr = read_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_CORRECTION'))
    classif = read_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_CLASSIFICATION'))
    inj = read_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_INJECTION'))
    ess = read_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_ESSENTIAL'))
    uncorr = read_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_UNCORRECTABLE'))
    idle = read_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.SEM.SEM_STATUS_IDLE'))

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
