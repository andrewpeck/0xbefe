#!/usr/bin/env python

from common.rw_reg import *
from common.utils import *
from time import *
import array
import struct
import signal
import sys

DEBUG = False

ADDR_IC_ADDR = None
ADDR_IC_WRITE_DATA = None
ADDR_IC_EXEC_WRITE = None
ADDR_IC_EXEC_READ = None

ADDR_LINK_RESET = None

V3B_GBT0_ELINK_TO_VFAT = {0: 15, 1: 14, 2: 13, 3: 12, 6: 7, 8: 23}
V3B_GBT1_ELINK_TO_VFAT = {1: 4, 2: 2, 3: 3, 4: 8, 5: 0, 6: 6, 7: 16, 8: 5, 9: 1}
V3B_GBT2_ELINK_TO_VFAT = {1: 9, 2: 20, 3: 21, 4: 11, 5: 10, 6: 18, 7: 19, 8: 17, 9: 22}
V3B_GBT_ELINK_TO_VFAT = [V3B_GBT0_ELINK_TO_VFAT, V3B_GBT1_ELINK_TO_VFAT, V3B_GBT2_ELINK_TO_VFAT]

#GE21_GBT0_ELINK_TO_VFAT = {0: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5}
#GE21_GBT1_ELINK_TO_VFAT = {0: 6, 1: 7, 2: 8, 3: 9, 4: 10, 5: 11}
#GE21_GBT_ELINK_TO_VFAT = [GE21_GBT0_ELINK_TO_VFAT, GE21_GBT1_ELINK_TO_VFAT]

# NEW map from CTP7 v3.12.0 -- this is using the VFAT numbers on the GEB silkscreen as opposed to the J numbers
GE21_GBT0_ELINK_TO_VFAT = {0: 2, 1: 0, 2: 4, 3: 10, 4: 6, 5: 8}
GE21_GBT1_ELINK_TO_VFAT = {0: 9, 1: 11, 2: 7, 3: 1, 4: 5, 5: 3}
GE21_GBT_ELINK_TO_VFAT = [GE21_GBT0_ELINK_TO_VFAT, GE21_GBT1_ELINK_TO_VFAT]

GE21_GBT0_ELINK_TO_FPGA = [6, 7, 8, 9]
GE21_GBT1_ELINK_TO_FPGA = [6, 7, 8, 9, 10, 11, 12, 13]
GE21_GBT_ELINK_TO_FPGA = [GE21_GBT0_ELINK_TO_FPGA, GE21_GBT1_ELINK_TO_FPGA]

GBT_ELINK_SAMPLE_PHASE_REGS = [[69, 73, 77], [67, 71, 75], [93, 97, 101], [91, 95, 99], [117, 121, 125], [115, 119, 123], [141, 145, 149], [139, 143, 147], [165, 169, 173], [163, 167, 171], [189, 193, 197], [187, 191, 195], [213, 217, 221], [211, 215, 219]]

ME0_GBT0_ELINK_TO_VFAT = {3: 8, 25: 0, 27: 1}
ME0_GBT1_ELINK_TO_VFAT = {24: 16, 11: 9, 6: 17}
ME0_GBT2_ELINK_TO_VFAT = {3: 10, 25: 2, 27: 3}
ME0_GBT3_ELINK_TO_VFAT = {24: 18, 11: 11, 6: 19}
ME0_GBT4_ELINK_TO_VFAT = {27: 5, 25: 12, 3: 4}
ME0_GBT5_ELINK_TO_VFAT = {24: 20, 11: 13, 6: 21}
ME0_GBT6_ELINK_TO_VFAT = {27: 7, 25: 14, 3: 6}
ME0_GBT7_ELINK_TO_VFAT = {24: 22, 11: 15, 6: 23}
ME0_ELINK_TO_VFAT = [ME0_GBT0_ELINK_TO_VFAT, ME0_GBT1_ELINK_TO_VFAT, ME0_GBT2_ELINK_TO_VFAT, ME0_GBT3_ELINK_TO_VFAT, ME0_GBT4_ELINK_TO_VFAT, ME0_GBT5_ELINK_TO_VFAT, ME0_GBT6_ELINK_TO_VFAT, ME0_GBT7_ELINK_TO_VFAT]

ME0_GBT0_CLASSIC_ELINK_TO_VFAT = {3: 3, 27: 4, 25: 5}
ME0_GBT1_CLASSIC_ELINK_TO_VFAT = {6: 0, 24: 1, 11: 2}
ME0_CLASSIC_ELINK_TO_VFAT = [ME0_GBT0_CLASSIC_ELINK_TO_VFAT, ME0_GBT1_CLASSIC_ELINK_TO_VFAT]
ME0_GBT0_SPICY_ELINK_TO_VFAT = {6: 0, 16: 1, 15: 3}
ME0_GBT1_SPICY_ELINK_TO_VFAT = {18: 2, 3: 4, 17: 5}
ME0_SPICY_ELINK_TO_VFAT = [ME0_GBT0_SPICY_ELINK_TO_VFAT, ME0_GBT1_SPICY_ELINK_TO_VFAT]
ME0_PIZZA_ELINK_TO_VFAT = [ME0_CLASSIC_ELINK_TO_VFAT, ME0_SPICY_ELINK_TO_VFAT]

LPGBT_ELINK_SAMPLING_PHASE_BASE_ADDR = 0x0cc
ME0_MASTER_GBT_ELINK_CTRL_REG_DEFAULT = [0xa, 0x2, 0xa, 0x2, 0xa, 0x2, 0x2, 0x2, 0x2, 0xa, 0x2, 0x2, 0x2, 0x2, 0x2, 0x2, 0x2, 0xa, 0xa, 0xa, 0xa, 0x2, 0xa, 0x2, 0xa, 0xa, 0xa, 0x2, 0x3]
ME0_SLAVE_GBT_ELINK_CTRL_REG_DEFAULT = [0x2, 0xa, 0x2, 0xa, 0x2, 0xa, 0x2, 0x2, 0x2, 0xa, 0xa, 0x2, 0xa, 0x2, 0x2, 0x2, 0x2, 0x2, 0x2, 0x2, 0x2, 0xa, 0x2, 0xa, 0xa, 0xa, 0x2, 0xa, 0x3]

PHASE_SCAN_DEFAULT_NUM_SC_TRANSACTIONS = 10000
PHASE_SCAN_DEFAULT_NUM_DAQ_PACKETS = 1000000
PHASE_SCAN_L1A_GAP = 40 # 1MHz

def gbt(oh_idx, gbt_idx, command, command_args):

    ohSelect = oh_idx
    gbtSelect = gbt_idx

    if ohSelect > 11:
        print_red("The given OH index (%d) is out of range (must be 0-11)" % ohSelect)
        return
    if gbtSelect > 7:
        print_red("The given GBT index (%d) is out of range (must be 0-2)" % gbtSelect)
        return

    initGbtRegAddrs()

    signal.signal(signal.SIGINT, signal_handler)

    heading("Hello, I'm your GBT controller :)")

    if (checkGbtReady(ohSelect, gbtSelect) == 1):
        selectGbt(ohSelect, gbtSelect)
    else:
        print_red("Sorry, OH%d GBT%d link is not ready.. check the following: your OH is on, the fibers are plugged in correctly, the CTP7 TX polarity is correct, and muy importante, check that your GBTX is fused with at least the minimal config.." % (ohSelect, gbtSelect))
        return

    if command == "charge-pump-current-scan":
        write_reg(get_node("BEFE.GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET"), 1)
        sleep(0.1)
        for curr in range(15, 0, -1):
            wReg(ADDR_IC_ADDR, 35)
            wReg(ADDR_IC_WRITE_DATA, (curr << 4) + 2)
            wReg(ADDR_IC_EXEC_WRITE, 1)
            sleep(0.1)
            wasNotReady = read_reg(get_node("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_WAS_NOT_READY" % (ohSelect, gbtSelect)))
            color = Colors.GREEN if wasNotReady == 0 else Colors.RED
            statusText = "GOOD" if wasNotReady == 0 else "BAD"
            print(color + "Charge pump current = %d  ------ GBT status = %s" % (curr, statusText) + Colors.ENDC)
            if wasNotReady != 0:
                break

    elif (command == 'config') or (command == 'v3b-phase-scan') or (command == 'ge21-phase-scan') or ('ge21-fpga-phase-scan' in command) or (command == 'ge21-program-phases'):
        if len(command_args) < 1:
            print("For this command, you also need to provide a config file")
            return

        subheading('Configuring OH%d GBT%d' % (ohSelect, gbtSelect))
        filename = command_args[0]
        if filename[-3:] != "txt":
            print_red("Seems like the file is not a txt file, please provide a txt file generated with the GBT programmer software")
            return
        if not os.path.isfile(filename):
            print_red("Can't find the file %s" % filename)
            return

        timeStart = clock()

        regs = downloadConfig(ohSelect, gbtSelect, filename)

        totalTime = clock() - timeStart
        print('time took = ' + str(totalTime) + 's')

        if (command == 'v3b-phase-scan'):
            numScTrans = PHASE_SCAN_DEFAULT_NUM_SC_TRANSACTIONS if len(command_args) < 2 else parse_int(command_args[1])
            numDaqPackets = PHASE_SCAN_DEFAULT_NUM_DAQ_PACKETS if len(command_args) < 3 else parse_int(command_args[2])
            phaseScan(False, V3B_GBT_ELINK_TO_VFAT, ohSelect, gbtSelect, regs, numScTrans, numDaqPackets)

        if (command == 'ge21-phase-scan'):
            numScTrans = PHASE_SCAN_DEFAULT_NUM_SC_TRANSACTIONS if len(command_args) < 2 else parse_int(command_args[1])
            numDaqPackets = PHASE_SCAN_DEFAULT_NUM_DAQ_PACKETS if len(command_args) < 3 else parse_int(command_args[2])
            phaseScan(False, GE21_GBT_ELINK_TO_VFAT, ohSelect, gbtSelect, regs, numScTrans, numDaqPackets)

        if (command == 'ge21-fpga-phase-scan'):
            # if there's an additional argument -- take it as the number of seconds to spend on each phase
            timePerPhase = 5
            if len(command_args) > 1:
                timePerPhase = int(command_args[1])

            # prep
            write_reg(get_node('BEFE.GEM_AMC.GEM_TESTS.OH_LOOPBACK.CTRL.OH_SELECT'), ohSelect)

            # print the result table header
            tableColWidth = 13
            header = "Phase".ljust(tableColWidth)
            for elink in GE21_GBT_ELINK_TO_FPGA[gbtSelect]:
                header += ("e-link %d" % elink).ljust(tableColWidth)
            print("")
            print(header)

            # start the scan
            for phase in range(0, 15):
                write_reg(get_node('BEFE.GEM_AMC.GEM_SYSTEM.TESTS.GBT_LOOPBACK_EN'), 0)

                # set phase on all elinks
                for elink in GE21_GBT_ELINK_TO_FPGA[gbtSelect]:
                    for subReg in range(0, 3):
                        addr = GBT_ELINK_SAMPLE_PHASE_REGS[elink][subReg]
                        value = (regs[addr] & 0xf0) + phase
                        wReg(ADDR_IC_ADDR, addr)
                        wReg(ADDR_IC_WRITE_DATA, value)
                        wReg(ADDR_IC_EXEC_WRITE, 1)
                        sleep(0.000001) # writing is too fast for CVP13 :)

                # reset the PRBS tester, and give some time to accumulate statistics
                sleep(0.001)
                write_reg(get_node('BEFE.GEM_AMC.GEM_TESTS.OH_LOOPBACK.CTRL.RESET'), 1)
                write_reg(get_node('BEFE.GEM_AMC.GEM_SYSTEM.TESTS.GBT_LOOPBACK_EN'), 1)
                sleep(timePerPhase)

                # check all elinks for errors
                result = ("%d" % phase).ljust(tableColWidth)
                for elink in GE21_GBT_ELINK_TO_FPGA[gbtSelect]:
                    prbsLocked = read_reg(get_node('BEFE.GEM_AMC.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_%d.PRBS_LOCKED' % (gbtSelect, elink)))
                    megaWordCnt = read_reg(get_node('BEFE.GEM_AMC.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_%d.MEGA_WORD_CNT' % (gbtSelect, elink)))
                    errorCnt = read_reg(get_node('BEFE.GEM_AMC.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_%d.ERROR_CNT' % (gbtSelect, elink)))

                    color = Colors.GREEN if errorCnt == 0 else Colors.RED
                    res = ('%d' % errorCnt).ljust(tableColWidth)
                    if (prbsLocked == 0) or (megaWordCnt < 80):
                        color = Colors.RED
                        res = "NO LOCK".ljust(tableColWidth)

                    result += color + res + Colors.ENDC

                    if DEBUG:
                        print(color + 'Phase = %d, ELINK %d: PRBS_LOCKED=%d, MEGA_WORD_CNT=%d, ERROR_CNT=%d' % (phase, elink, prbsLocked, megaWordCnt, errorCnt) + Colors.ENDC)

                print(result)

            write_reg(get_node('BEFE.GEM_AMC.GEM_SYSTEM.TESTS.GBT_LOOPBACK_EN'), 0)

        if (command == 'ge21-program-phases'):
            initVfatRegAddrs()

            numPhases = len(command_args) - 1
            for elink in range(numPhases):
                phase = int(command_args[1 + elink])
                subheading('Setting phase = %d for elink %d' % (phase, elink))
                for subReg in range(0, 3):
                    addr = GBT_ELINK_SAMPLE_PHASE_REGS[elink][subReg]
                    value = (regs[addr] & 0xf0) + phase
                    wReg(ADDR_IC_ADDR, addr)
                    wReg(ADDR_IC_WRITE_DATA, value)
                    wReg(ADDR_IC_EXEC_WRITE, 1)

                if elink in GE21_GBT_ELINK_TO_VFAT[gbtSelect]:
                    vfat = GE21_GBT_ELINK_TO_VFAT[gbtSelect][elink]
                    # reset the link, give some time to lock and accumulate any sync errors and then check VFAT comms
                    sleep(0.1)
                    write_reg(get_node('BEFE.GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET'), 1)
                    sleep(0.001)
                    cfgRunGood = 1
                    cfgAddr = get_node('BEFE.GEM_AMC.OH.OH%d.GEB.VFAT%d.CFG_RUN' % (ohSelect, vfat)).address
                    for i in range(10000):
                        #ret = read_reg(get_node('BEFE.GEM_AMC.OH.OH%d.GEB.VFAT%d.CFG_RUN' % (ohSelect, vfat)))
                        ret = rReg(cfgAddr)
                        #if (ret != '0x00000000' and ret != '0x00000001'):
                        if (ret != 0 and ret != 1):
                            print("bad read of CFG_RUN on elink %d VFAT%d, iteration #%d: %s" % (elink, vfat, i, hex(ret)))
                            cfgRunGood = 0
                            break
                    #sleep(0.3)
                    #sleep(0.5)
                    linkGood = read_reg(get_node('BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.LINK_GOOD' % (ohSelect, vfat)))
                    syncErrCnt = read_reg(get_node('BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT' % (ohSelect, vfat)))
                    color = Colors.GREEN
                    prefix = 'COMMUNICATION GOOD on elink %d VFAT%d: ' % (elink, vfat)
                    if (linkGood == 0) or (syncErrCnt > 0) or (cfgRunGood == 0):
                        color = Colors.RED
                        prefix = 'COMMUNICATION BAD on elink %d VFAT%d: ' % (elink, vfat)
                    print color, prefix, 'Phase = %d, LINK_GOOD=%d, SYNC_ERR_CNT=%d, CFG_RUN_GOOD=%d' % (phase, linkGood, syncErrCnt, cfgRunGood), Colors.ENDC

    elif (command == 'me0-phase-scan'):
        numScTrans = PHASE_SCAN_DEFAULT_NUM_SC_TRANSACTIONS if len(command_args) < 1 else parse_int(command_args[0])
        numDaqPackets = PHASE_SCAN_DEFAULT_NUM_DAQ_PACKETS if len(command_args) < 2 else parse_int(command_args[1])
        phaseScan(True, ME0_ELINK_TO_VFAT, ohSelect, gbtSelect, [], numScTrans, numDaqPackets)

    elif command == 'destroy':
        subheading('Destroying configuration of OH%d GBT%d' % (ohSelect, gbtSelect))
        destroyConfig()

    else:
        print_red("Unrecognized command '%s'" % command)
        return

    print("")
    print("bye now..")

def phaseScan(isLpGbt, elinkToVfatMap, ohSelect, gbtSelect, gbtRegs, numSlowControlTransactions, numDaqPackets):
    if isLpGbt:
        write_reg(get_node('BEFE.GEM_AMC.SLOW_CONTROL.IC.GBTX_I2C_ADDR'), 0x70)
    else:
        write_reg(get_node('BEFE.GEM_AMC.SLOW_CONTROL.IC.GBTX_I2C_ADDR'), 0x1)

    # setup the TTC generator for a DAQ test
    write_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.RESET"), 1)
    genEn = read_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE"))
    write_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE"), 1)
    calpulseGap = read_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"))
    write_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 0)
    l1aCnt = read_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_L1A_COUNT"))
    write_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_L1A_COUNT"), numDaqPackets)
    l1aGap = read_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_L1A_GAP"))
    write_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_L1A_GAP"), PHASE_SCAN_L1A_GAP)

    # start the scan
    initVfatRegAddrs()
    subheading('Starting GBT%d phase scan checking %d slow control transactions and %d daq data packets on each phase' % (gbtSelect, numSlowControlTransactions, numDaqPackets))
    for elink, vfat in elinkToVfatMap[gbtSelect].items():
        subheading('Scanning elink %d phase, corresponding to VFAT%d' % (elink, vfat))
        goodPhases = []
        for phase in range(0, 15):
            setElinkPhase(isLpGbt, gbtSelect, gbtRegs, elink, phase)

            # reset the link, give some time to lock and accumulate any sync errors and then check VFAT comms
            sleep(0.1)
            write_reg(get_node('BEFE.GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET'), 1)
            sleep(0.001)

            # check slow control to the VFAT
            cfgRunGood = 1
            cfgAddr = get_node('BEFE.GEM_AMC.OH.OH%d.GEB.VFAT%d.CFG_RUN' % (ohSelect, vfat)).address
            for i in range(numSlowControlTransactions):
                #ret = read_reg(get_node('BEFE.GEM_AMC.OH.OH%d.GEB.VFAT%d.CFG_RUN' % (ohSelect, vfat)))
                ret = rReg(cfgAddr)
                #if (ret != '0x00000000' and ret != '0x00000001'):
                if (ret != 0 and ret != 1):
                    cfgRunGood = 0
                    break

            # check sync status
            linkGood = read_reg(get_node('BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.LINK_GOOD' % (ohSelect, vfat)))
            syncErrCnt = read_reg(get_node('BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT' % (ohSelect, vfat)))

            # if communication is good, set the VFAT to run mode, and do a DAQ packet CRC error test
            daqCrcErrCnt = -1
            if cfgRunGood == 1 and linkGood == 1 and syncErrCnt == 0:
                if numDaqPackets <= 0:
                    wReg(cfgAddr, 0) # set the VFAT to sleep mode
                else:
                    wReg(cfgAddr, 1) # set the VFAT to run mode
                    write_reg(get_node("BEFE.GEM_AMC.OH.OH%d.GEB.VFAT%d.CFG_THR_ARM_DAC" % (ohSelect, vfat)), 0) # set a low threshold (TODO: this may need tuning to get more or less random data)
                    write_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_START"), 1)
                    genRunning = 1
                    while genRunning == 1:
                        genRunning = read_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_RUNNING"))
                    daqCrcErrCnt = read_reg(get_node("BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.DAQ_CRC_ERROR_CNT" % (ohSelect, vfat)))
                    daqEvtCnt = read_reg(get_node("BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.DAQ_EVENT_CNT" % (ohSelect, vfat)))
                    if daqEvtCnt == 0:
                        daqCrcErrCnt = 999

            # print the results
            color = Colors.GREEN
            prefix = 'GOOD: '
            if (linkGood == 0) or (syncErrCnt > 0) or (cfgRunGood == 0) or (daqCrcErrCnt > 0):
                color = Colors.RED
                prefix = '>>>>>>>> BAD <<<<<<<< '
                goodPhases.append(False)
            else:
                goodPhases.append(True)
            print color, prefix, 'Phase = %d, VFAT%d LINK_GOOD=%d, SYNC_ERR_CNT=%d, CFG_RUN_GOOD=%d, DAQ_CRC_ERR_CNT=%d' % (phase, vfat, linkGood, syncErrCnt, cfgRunGood, daqCrcErrCnt), Colors.ENDC

        # select the best phase for this elink
        bestPhase = getBestPhase(goodPhases)
        print("Setting phase = %d" % bestPhase)
        setElinkPhase(isLpGbt, gbtSelect, gbtRegs, elink, bestPhase)

    # restore the TTC generator settings
    write_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.RESET"), 1)
    write_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE"), genEn)
    write_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), calpulseGap)
    write_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_L1A_COUNT"), l1aCnt)
    write_reg(get_node("BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_L1A_GAP"), l1aGap)

    # reset the links
    sleep(0.1)
    write_reg(get_node('BEFE.GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET'), 1)

def setElinkPhase(isLpGbt, gbtSelect, gbtRegs, elink, phase):
    # set phase
    if isLpGbt: # LpGBT
        isMaster = gbtSelect % 2 == 0
        ctrlRegDefault = ME0_MASTER_GBT_ELINK_CTRL_REG_DEFAULT[elink] if isMaster else ME0_SLAVE_GBT_ELINK_CTRL_REG_DEFAULT[elink]
        addr = LPGBT_ELINK_SAMPLING_PHASE_BASE_ADDR + elink
        value = (phase << 4) + ctrlRegDefault
        wReg(ADDR_IC_ADDR, addr)
        wReg(ADDR_IC_WRITE_DATA, value)
        wReg(ADDR_IC_EXEC_WRITE, 1)
        sleep(0.000001) # writing is too fast for CVP13 :)
    else: # GBTX
        for subReg in range(0, 3):
            addr = GBT_ELINK_SAMPLE_PHASE_REGS[elink][subReg]
            value = (gbtRegs[addr] & 0xf0) + phase
            wReg(ADDR_IC_ADDR, addr)
            wReg(ADDR_IC_WRITE_DATA, value)
            wReg(ADDR_IC_EXEC_WRITE, 1)
            sleep(0.000001) # writing is too fast for CVP13 :)

def getBestPhase(goodPhases):
    bestDistLeft = 0
    bestDistRight = 0
    bestPhase = 0
    for i in range(len(goodPhases)):
        distRight = 0
        for j in range(i, i + 15):
            phaseIdx = j if j < 15 else j - 15
            if not goodPhases[phaseIdx]:
                break
            else:
                distRight += 1
        distLeft = 0
        for j in range(i, i - 15, -1):
            phaseIdx = j
            if not goodPhases[phaseIdx]:
                break
            else:
                distLeft += 1

        if distLeft + distRight > bestDistLeft + bestDistRight or (distLeft + distRight == bestDistLeft + bestDistRight and abs(distLeft - distRight) < abs(bestDistLeft - bestDistRight)):
            if distLeft <= 4: # don't set a phase with distance more than 4 to the left (to protect against cases where the second bad spot is not detected)
                bestDistLeft = distLeft
                bestDistRight = distRight
                bestPhase = i

    print("Best phase is %d, distance to a bad spot on the left = %d, on the right = %d" % (bestPhase, bestDistLeft, bestDistRight))
    return bestPhase

def downloadConfig(ohIdx, gbtIdx, filename):
    f = open(filename, 'r')

    #for now we'll operate with 8 bit words only
    write_reg(get_node("BEFE.GEM_AMC.SLOW_CONTROL.IC.READ_WRITE_LENGTH"), 1)

    ret = []

    lines = 0
    addr = 0
    for line in f:
        value = int(line, 16)
        wReg(ADDR_IC_ADDR, addr)
        wReg(ADDR_IC_WRITE_DATA, value)
        wReg(ADDR_IC_EXEC_WRITE, 1)
        sleep(0.000001) # writing is too fast for CVP13 :)
        addr += 1
        lines += 1
        ret.append(value)

    print("Wrote %d registers to OH%d GBT%d" % (lines, ohIdx, gbtIdx))
    if lines < 366:
        print_red("looks like you gave me an incomplete file, since I found only %d registers, while a complete config should contain 366 registers")

    f.close()

    return ret

def destroyConfig():
    for i in range(0, 369):
        wReg(ADDR_IC_ADDR, i)
        wReg(ADDR_IC_WRITE_DATA, 0)
        wReg(ADDR_IC_EXEC_WRITE, 1)
        sleep(0.000001) # writing is too fast for CVP13 :)

def initGbtRegAddrs():
    global ADDR_IC_ADDR
    global ADDR_IC_WRITE_DATA
    global ADDR_IC_EXEC_WRITE
    global ADDR_IC_EXEC_READ
    ADDR_IC_ADDR = get_node('BEFE.GEM_AMC.SLOW_CONTROL.IC.ADDRESS').address
    ADDR_IC_WRITE_DATA = get_node('BEFE.GEM_AMC.SLOW_CONTROL.IC.WRITE_DATA').address
    ADDR_IC_EXEC_WRITE = get_node('BEFE.GEM_AMC.SLOW_CONTROL.IC.EXECUTE_WRITE').address
    ADDR_IC_EXEC_READ = get_node('BEFE.GEM_AMC.SLOW_CONTROL.IC.EXECUTE_READ').address

def initVfatRegAddrs():
    global ADDR_LINK_RESET
    ADDR_LINK_RESET = get_node('BEFE.GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET').address

def selectGbt(ohIdx, gbtIdx):
    station = read_reg(get_node('BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.GEM_STATION'))
    numGbtsPerOh = 3 if station == 1 else 8 if station == 0 else 2
    linkIdx = ohIdx * numGbtsPerOh + gbtIdx

    write_reg(get_node('BEFE.GEM_AMC.SLOW_CONTROL.IC.GBTX_LINK_SELECT'), linkIdx)

    return 0

def checkGbtReady(ohIdx, gbtIdx):
    return read_reg(get_node('BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_READY' % (ohIdx, gbtIdx)))

def signal_handler(sig, frame):
    print("Exiting..")
    write_reg(get_node('BEFE.GEM_AMC.GEM_SYSTEM.TESTS.GBT_LOOPBACK_EN'), 0)
    sys.exit(0)

def debug(string):
    if DEBUG:
        print('DEBUG: ' + string)

def debugCyan(string):
    if DEBUG:
        print_cyan('DEBUG: ' + string)

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print('Usage: gbt.py <oh_num> <gbt_num> <command>')
        print('available commands:')
        print('  config <config_filename_txt>:   Configures the GBT with the given config file (must use the txt version of the config file, can be generated with the GBT programmer software)')
        print('  v3b-phase-scan <base_config_filename_txt> [num_slow_control] [num_daq_packets]:   Configures the GBT with the given config file, and performs an elink phase scan while checking the VFAT communication for each phase. Optionally the number of slow control transactions (default %d) and the number of daq packets (default %d) to check can be provided.'  % (PHASE_SCAN_DEFAULT_NUM_SC_TRANSACTIONS, PHASE_SCAN_DEFAULT_NUM_DAQ_PACKETS))
        print('  ge21-phase-scan <base_config_filename_txt> [num_slow_control] [num_daq_packets]:   Configures the GBT with the given config file, and performs an elink phase scan while checking the VFAT communication for each phase. Optionally the number of slow control transactions (default %d) and the number of daq packets (default %d) to check can be provided.'  % (PHASE_SCAN_DEFAULT_NUM_SC_TRANSACTIONS, PHASE_SCAN_DEFAULT_NUM_DAQ_PACKETS))
        print('  ge21-fpga-phase-scan <base_config_filename_txt> [time_per_phase_sec]:   Configures the GBT with the given config file, and performs a phase scan on elinks connected to the FPGA while checking the PRBS error count for each phase. NOTE: This requires the FPGA to be loaded with a loopback firmware (future OH fw versions will probably have the PRBS sender built in). Optionally a number of seconds to spend on each phase can be supplied as the last argument.')
        print('  ge21-program-phases <elink_0_phase> <elink_1_phase> <elink_2_phase> <elink_3_phase> etc... :   Programs the provided GBTX sampling phases to as many elinks as the numbers provided (can also include wide-bus elinks)')
        print('  me0-phase-scan [num_slow_control] [num_daq_packets]:   Performs an elink phase scan while checking the VFAT communication for each phase (used with ME0 GEB). Optionally the number of slow control transactions (default %d) and the number of daq packets (default %d) to check can be provided.' % (PHASE_SCAN_DEFAULT_NUM_SC_TRANSACTIONS, PHASE_SCAN_DEFAULT_NUM_DAQ_PACKETS))
        print('  charge-pump-current-scan:   Scans the CDR phase detector charge pump current from highest to the lowest that still works')
        return

    oh_idx = int(sys.argv[1])
    gbt_idx = int(sys.argv[2])
    command = sys.argv[3]
    command_args = sys.argv[4:]

    parse_xml()

    gbt(oh_idx, gbt_idx, command, command_args):
