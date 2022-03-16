import sys
import os
import subprocess
import math

ohMask = 1

from common.rw_reg import *
from common.utils import *
from gem.sca import *
from test_config import *

from common.fw_utils import *

ADDR_IC_ADDR = None
ADDR_IC_WRITE_DATA = None
ADDR_IC_EXEC_WRITE = None
ADDR_IC_EXEC_READ = None

ADDR_LINK_RESET = None

V3B_GBT0_ELINK_TO_VFAT = {0: 15, 1: 14, 2: 13, 3: 12, 6: 7, 8: 23}
V3B_GBT1_ELINK_TO_VFAT = {1: 4, 2: 2, 3: 3, 4: 8, 5: 0, 6: 6, 7: 16, 8: 5, 9: 1}
V3B_GBT2_ELINK_TO_VFAT = {1: 9, 2: 20, 3: 21, 4: 11, 5: 10, 6: 18, 7: 19, 8: 17, 9: 22}
V3B_GBT_ELINK_TO_VFAT = [V3B_GBT0_ELINK_TO_VFAT, V3B_GBT1_ELINK_TO_VFAT, V3B_GBT2_ELINK_TO_VFAT]

# NEW map from CTP7 v3.12.0 -- this is using the VFAT numbers on the GEB silkscreen as opposed to the J numbers                                                                                             
GE21_GBT0_ELINK_TO_VFAT = {0: 2, 1: 0, 2: 4, 3: 10, 4: 6, 5: 8}
GE21_GBT1_ELINK_TO_VFAT = {0: 9, 1: 11, 2: 7, 3: 1, 4: 5, 5: 3}
GE21_GBT_ELINK_TO_VFAT = [GE21_GBT0_ELINK_TO_VFAT, GE21_GBT1_ELINK_TO_VFAT]

GE21_GBT0_ELINK_TO_FPGA = [6, 7, 8, 9]
GE21_GBT1_ELINK_TO_FPGA = [6, 7, 8, 9, 10, 11, 12, 13]
GE21_GBT_ELINK_TO_FPGA = [GE21_GBT0_ELINK_TO_FPGA, GE21_GBT1_ELINK_TO_FPGA]

GBT_ELINK_SAMPLE_PHASE_REGS = [[69, 73, 77], [67, 71, 75], [93, 97, 101], [91, 95, 99], [117, 121, 125], [115, 119, 123], [141, 145, 149], [139, 143, 147], [165, 169, 173], [163, 167, 171], [189, 193, 197], [187, 191, 195], [213, 217, 221], [211, 215, 219]]

GBT_0_Config_File = get_config("CONFIG_GE21_OH_GBT0_CONFIGS")[0]
GBT_1_Config_File = get_config("CONFIG_GE21_OH_GBT1_CONFIGS")[0]


minWindowWidth = 5

def scan_FPGA_integrated():
    ohSelect = 0
    gbtSelect = 0
    filename = "gbt_config/GBTX_GE21_OHv2_GBT_0_minimal_2020-01-17.txt"

    initGbtRegAddrs()

    Gbt_0_PhaseRes = scan_fpga(0,0,GBT_0_Config_File)
    Gbt_1_PhaseRes = scan_fpga(0,1,GBT_1_Config_File)
    ## ADD VFAT phase Picking / Programming HERE!!!!
    program_phase_fpga(Gbt_0_PhaseRes, Gbt_1_PhaseRes)
    return

def scan_VFAT_integrated(verbose = False):
    ohSelect = 0
    gbtSelect = 0
    filename = "gbt_config/GBTX_GE21_OHv2_GBT_0_minimal_2020-01-17.txt"

    AllWindowGood = True

    initGbtRegAddrs()

    Gbt_0_PhaseRes_ScanResult = scan_vfats(0,0,GBT_0_Config_File)
    Gbt_1_PhaseRes_ScanResult = scan_vfats(0,1,GBT_1_Config_File)

    Gbt_0_PhaseRes = Gbt_0_PhaseRes_ScanResult[0]
    Gbt_1_PhaseRes = Gbt_1_PhaseRes_ScanResult[0]

    Gbt_0_Return_Data = [Gbt_0_PhaseRes_ScanResult[1], Gbt_0_PhaseRes_ScanResult[2], Gbt_0_PhaseRes_ScanResult[3]]
    Gbt_1_Return_Data = [Gbt_1_PhaseRes_ScanResult[1], Gbt_1_PhaseRes_ScanResult[2], Gbt_1_PhaseRes_ScanResult[3]]

    if verbose:
        print(Colors.MAGENTA+'Gbt_0_PhaseRes Content : (from scan_VFAT_integrated, in phase_scan.py)'+Colors.ENDC)
        print(Gbt_0_PhaseRes)
        print(Colors.MAGENTA+'Gbt_1_PhaseRes Content : (from scan_VFAT_integrated, in phase_scan.py)'+Colors.ENDC)
        print(Gbt_1_PhaseRes)

    ## ADD VFAT phase Picking / Programming HERE!!!!
    PhaseArray_Gbt_0 = []
    PhaseArray_Gbt_1 = []

    WindowSpecs_Gbt_0 = [[-1] * 2 for x in range(len(Gbt_0_PhaseRes))]
    if verbose:
        print(Colors.MAGENTA+'WindowSpecs_Gbt_0 Content (pre window select) : (from scan_VFAT_integrated, in phase_scan.py)'+Colors.ENDC)
        print(WindowSpecs_Gbt_0)

    i=0
    for Arr in Gbt_0_PhaseRes:
        #print('')
        #print('Status[',i,'][  ]:')
        WindowSpecs_Gbt_0[i] = findBestWindow(Arr, verbose)
        i+=1
    if verbose:
        print(Colors.MAGENTA+'WindowSpecs_Gbt_0 Content (post window select) : (from scan_VFAT_integrated, in phase_scan.py)'+Colors.ENDC)
        print(WindowSpecs_Gbt_0)

    WindowSpecs_Gbt_1 = [[-1] * 2 for x in range(len(Gbt_1_PhaseRes))]
    if verbose:
        print(Colors.MAGENTA+'WindowSpecs_Gbt_1 Content (pre window select) : (from scan_VFAT_integrated, in phase_scan.py)'+Colors.ENDC)
        print(WindowSpecs_Gbt_1)
    i=0
    for Arr in Gbt_1_PhaseRes:
        #print('')
        #print('Status[',i,'][  ]:')
        WindowSpecs_Gbt_1[i] = findBestWindow(Arr, verbose)
        i+=1
    if verbose:
        print(Colors.MAGENTA+'WindowSpecs_Gbt_1 Content (post window select) : (from scan_VFAT_integrated, in phase_scan.py)'+Colors.ENDC)
        print(WindowSpecs_Gbt_1)

    # Select Best Phases, using Phase Scan data
    iter = 0
    for width , phi in WindowSpecs_Gbt_0:
        if width < minWindowWidth:
            print("Fail: Gbt0 Elink%d has No Acceptable phase Window" % iter)
            PhaseArray_Gbt_0.append(0)
            AllWindowGood = False
        else:
            PhaseArray_Gbt_0.append(int(phi))
        iter += 1
    iter = 0
    for width , phi in WindowSpecs_Gbt_1:
        if width < minWindowWidth:
            print("Fail: Gbt1 Elink%d has No Acceptable phase Window" % iter)
            PhaseArray_Gbt_1.append(0)
            AllWindowGood = False
        else:
            PhaseArray_Gbt_1.append(int(phi))
        iter += 1
    # Program Best Phases using results of Best Phase window Algorithm
    if verbose:
        print(Colors.MAGENTA + 'Output of Phase Programming Content (pre window select) : (from program_phase, in scan_VFAT_integrated, in phase_scan.py)' + Colors.ENDC)
    program_phase(0,0,GBT_0_Config_File,PhaseArray_Gbt_0)
    program_phase(0,1,GBT_1_Config_File,PhaseArray_Gbt_1)
    return [AllWindowGood , Gbt_0_Return_Data, Gbt_1_Return_Data]


def program_phase(ohSelect , gbtSelect , configFile , Phases):

    heading("Hello, I'm you GBT controller :)")

    if(checkGbtReady(ohSelect,gbtSelect) == 1):
        selectGbt(ohSelect,gbtSelect)
    else:
        print_red("Sorry, OH%d GBT%d link is not ready.. check the following your OH is on, the fibers are plugged in correctly, the CTP7 TX polarity is correct, and muy importante, check that your GBTX is fused with at least the minimal config.." % (ohSelect, gbtSelect))
        return

    subheading('Configuring OH%d GBT%d' % (ohSelect, gbtSelect))

    if configFile[-3:] != "txt":
        print_red("Seems like the file is not a txt file, please provide a txt file generated with the GBT programmer software")
        return
    if not os.path.isfile(configFile):
        print_red("Can't find the file %s" % configFile)
        return

    timeStart = clock()

    regs = downloadConfig(ohSelect, gbtSelect, configFile)

    totalTime = clock() - timeStart
    print('time took = ' + str(totalTime) + 's')
    # prep
    write_reg(get_node('BEFE.GEM.GEM_TESTS.OH_LOOPBACK.CTRL.OH_SELECT'), ohSelect)

    initVfatRegAddrs()

    for elink in range(len(Phases)):
        phase = int(Phases[elink])
        subheading('Setting phase = %d for elink %d' % (phase, elink))
        for subReg in range(0, 3):
            addr = GBT_ELINK_SAMPLE_PHASE_REGS[elink][subReg]
            value = (regs[addr] & 0xf0) + phase
            wReg(ADDR_IC_ADDR, addr)
            wReg(ADDR_IC_WRITE_DATA, value)
            wReg(ADDR_IC_EXEC_WRITE, 1)
            sleep(0.000001) # writing is too fast for CVP13 :)

        if elink in GE21_GBT_ELINK_TO_VFAT[gbtSelect]:
            vfat = GE21_GBT_ELINK_TO_VFAT[gbtSelect][elink]
            # reset the link, give some time to lock and accumulate any sync errors and then check VFAT comms
            sleep(0.1)
            write_reg(get_node('BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET'), 1)
            sleep(0.001)
            cfgRunGood = 1
            cfgAddr = get_node('BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN' % (ohSelect, vfat)).address
            for i in range(10000):
                #ret = read_reg(get_node('BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN' % (ohSelect, vfat)))
                ret = rReg(cfgAddr)
                #if (ret != '0x00000000' and ret != '0x00000001'):
                if (ret != 0 and ret != 1):
                    print("bad read of CFG_RUN on elink %d VFAT%d, iteration #%d: %s" % (elink, vfat, i, hex(ret)))
                    cfgRunGood = 0
                    break
            #sleep(0.3)
            #sleep(0.5)
            linkGood = int(read_reg(get_node('BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD' % (ohSelect, vfat))))
            syncErrCnt = int(read_reg(get_node('BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT' % (ohSelect, vfat))))
            color = Colors.GREEN
            prefix = 'COMMUNICATION GOOD on elink %d VFAT%d: ' % (elink, vfat)
            if (linkGood == 0) or (syncErrCnt > 0) or (cfgRunGood == 0):
                color = Colors.RED
                prefix = 'COMMUNICATION BAD on elink %d VFAT%d: ' % (elink, vfat)
            print(color, prefix, 'Phase = %d, LINK_GOOD=%d, SYNC_ERR_CNT=%d, CFG_RUN_GOOD=%d' % (phase, linkGood, syncErrCnt, cfgRunGood), Colors.ENDC)



def program_phase_fpga(Gbt_0_Phase, Gbt_1_Phase, verbose = False):
    # Default program VFATs to 0's phases...
    vfatPhases_gbt_0 = [0 , 0 , 0 , 0 , 0 , 0]
    vfatPhases_gbt_1 = [0 , 0 , 0 , 0 , 0 , 0]

    WindowSpecs_Gbt_0 = [[-1] * 2 for x in range(len(Gbt_0_Phase))]
    print(WindowSpecs_Gbt_0)
    i=0
    for Arr in Gbt_0_Phase:
        #print('')
        #print('Status[',i,'][  ]:')
        WindowSpecs_Gbt_0[i] = findBestWindow(Arr, verbose)
        i+=1
    print(WindowSpecs_Gbt_0)
    #print(WindowSpecs_Gbt_0[0])
    #print(WindowSpecs_Gbt_0[:][0])

    WindowSpecs_Gbt_1 = [[-1] * 2 for x in range(len(Gbt_1_Phase))]
    print(WindowSpecs_Gbt_1)
    i=0
    for Arr in Gbt_1_Phase:
        #print('')
        #print('Status[',i,'][  ]:')
        WindowSpecs_Gbt_1[i] = findBestWindow(Arr, verbose)
        i+=1
    print(WindowSpecs_Gbt_1)
    #print(WindowSpecs_Gbt_1[0])
    #print(WindowSpecs_Gbt_1[:][0])

    # Organize "Best Phases" into Arrays
    PhaseArray_Gbt_0 = vfatPhases_gbt_0
    for x , y in WindowSpecs_Gbt_0:
        #print('X=%d'%x)
        #print('Y=%d'%y)
        PhaseArray_Gbt_0.append(int(y))

    PhaseArray_Gbt_1 = vfatPhases_gbt_1
    for xx , yy in WindowSpecs_Gbt_1:
        #print('X=%d'%xx)
        #print('Y=%d'%yy)
        PhaseArray_Gbt_1.append(int(yy))
    if verbose:
        print('PhaseArray_Gbt_0 Contents: (from file \'phase_scan.py\')')
        print(PhaseArray_Gbt_0)
        print(Colors.MAGENTA + 'PhaseArray_Gbt_1 Contents: (from file \'phase_scan.py\')' + Colors.ENDC)
        print(PhaseArray_Gbt_1)
    # Actually Program the Best Phases
    # GBT 0
    program_phase(0, 0, GBT_0_Config_File, PhaseArray_Gbt_0)
    program_phase(0, 1, GBT_1_Config_File, PhaseArray_Gbt_1)
    return

def findBestWindow(statArr, verbose=False, EXTRA_Verbose=False):
    BestStart = -1
    BestEnd   = -1
    CurrStart = -1
    CurrEnd   = -1
    BestWindowSpecs = [-1,-1]

    for phi in range(len(statArr)):
        if EXTRA_Verbose:
            print('Current Phase = ',phi,' Status = ',statArr[phi])
        if(statArr[phi]):
            #Check if Start of new Window
            if(CurrStart == -1):
                # New Window Set Bounds to Current phase
                CurrStart = phi
                CurrEnd = phi
            else:
                # Continuing Window Set End to Current phase
                CurrEnd = phi
        else:   # Window Has ended
            if((BestStart == -1) & (CurrStart != -1)):    # No Best Window Has been Set yet
                BestStart = CurrStart
                BestEnd   = CurrEnd
            elif((BestEnd-BestStart)<(CurrEnd-CurrStart)): # Better Window has been detected
                BestStart = CurrStart
                BestEnd   = CurrEnd
            CurrStart = -1
            CurrEnd = -1

    # Checks if no "Bad" phases were detected, sets Best window as full range
    if(CurrEnd!=-1 and CurrStart !=-1):
        if((BestEnd-BestStart)<(CurrEnd-CurrStart)):
            BestStart = CurrStart
            BestEnd   = CurrEnd

    if((BestStart == -1) & (CurrStart != -1)):
        BestStart = CurrStart
        BestEnd = CurrEnd

    BestWidth = (BestEnd - BestStart) + 1
    CenterWindow = math.ceil((BestStart + BestEnd)/2)
    if verbose:
        print('Best Window: Width = ' + str(BestWidth) + ';  Center = ' + str(CenterWindow))

    BestWindowSpecs[0] = BestWidth
    BestWindowSpecs[1] = CenterWindow

    return BestWindowSpecs


def scan_fpga(ohSelect,gbtSelect,configFile):
    PhaseResult = [[False] * 15 for x in range(len(GE21_GBT_ELINK_TO_FPGA[gbtSelect]))]

    heading("Hello, I'm you GBT controller :)")

    if(checkGbtReady(ohSelect,gbtSelect) == 1):
        selectGbt(ohSelect,gbtSelect)
    else:
        print_red("Sorry, OH%d GBT%d link is not ready.. check the following your OH is on, the fibers are plugged in correctly, the CTP7 TX polarity is correct, and muy importante, check that your GBTX is fused with at least the minimal config.." % (ohSelect, gbtSelect))
        return

    subheading('Configuring OH%d GBT%d' % (ohSelect, gbtSelect))

    if configFile[-3:] != "txt":
        print_red("Seems like the file is not a txt file, please provide a txt file generated with the GBT programmer software")
        return
    if not os.path.isfile(configFile):
        print_red("Can't find the file %s" % configFile)
        return

    timeStart = clock()

    regs = downloadConfig(ohSelect, gbtSelect, configFile)

    totalTime = clock() - timeStart
    print('time took = ' + str(totalTime) + 's')
    # prep
    write_reg(get_node('BEFE.GEM.GEM_TESTS.OH_LOOPBACK.CTRL.OH_SELECT'), ohSelect)

    # print the result table header
    tableColWidth = 13
    header = "Phase".ljust(tableColWidth)
    for elink in GE21_GBT_ELINK_TO_FPGA[gbtSelect]:
        header += ("e-link %d" % elink).ljust(tableColWidth)
    print("")
    print(header)

    # start the scan
    for phase in range(0, 15):
        write_reg(get_node('BEFE.GEM.GEM_SYSTEM.TESTS.GBT_LOOPBACK_EN'), 0)

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
        write_reg(get_node('BEFE.GEM.GEM_TESTS.OH_LOOPBACK.CTRL.RESET'), 1)
        write_reg(get_node('BEFE.GEM.GEM_SYSTEM.TESTS.GBT_LOOPBACK_EN'), 1)
        sleep(PHASE_SCAN_FPGA_ACCUM_TIME)

        # check all elinks for errors
        ELINK_ITER = 0
        result = ("%d" % phase).ljust(tableColWidth)
        for elink in GE21_GBT_ELINK_TO_FPGA[gbtSelect]:
            prbsLocked = int(read_reg(get_node('BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_%d.PRBS_LOCKED' % (gbtSelect, elink))))
            megaWordCnt = int(read_reg(get_node('BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_%d.MEGA_WORD_CNT' % (gbtSelect, elink))))
            errorCnt = int(read_reg(get_node('BEFE.GEM.GEM_TESTS.OH_LOOPBACK.GBT_%d.ELINK_%d.ERROR_CNT' % (gbtSelect, elink))))

            color = Colors.GREEN if errorCnt == 0 else Colors.RED
            res = ('%d' % errorCnt).ljust(tableColWidth)
            if (prbsLocked == 0) or (megaWordCnt < 80):
                color = Colors.RED
                res = "NO LOCK".ljust(tableColWidth)

            result += color + res + Colors.ENDC

            if DEBUG:
                print(color + 'Phase = %d, ELINK %d: PRBS_LOCKED=%d, MEGA_WORD_CNT=%d, ERROR_CNT=%d' % (phase, elink, prbsLocked, megaWordCnt, errorCnt) + Colors.ENDC)
            if (errorCnt == 0) and (prbsLocked != 0):
                PhaseResult[ELINK_ITER][phase] = True
            ELINK_ITER += 1
        print(result)

    write_reg(get_node('BEFE.GEM.GEM_SYSTEM.TESTS.GBT_LOOPBACK_EN'), 0)
    return PhaseResult

def scan_vfats(ohSelect, gbtSelect, configFile, verbose=False):
    PhaseResult = [[False] * 15 for x in range(len(GE21_GBT_ELINK_TO_VFAT[gbtSelect]))]
    LINK_GOOD_Arr = [[-1] * 15 for x in range(len(GE21_GBT_ELINK_TO_VFAT[gbtSelect]))]
    SYNC_ERR_CNT_Arr = [[-1] * 15 for x in range(len(GE21_GBT_ELINK_TO_VFAT[gbtSelect]))]
    DAQ_CRC_ERR_CNT_Arr = [[-1] * 15 for x in range(len(GE21_GBT_ELINK_TO_VFAT[gbtSelect]))]
    if verbose:
        heading("Hello, I'm you GBT controller :)")

    if(checkGbtReady(ohSelect,gbtSelect) == 1):
        selectGbt(ohSelect,gbtSelect)
    else:
        print_red("Sorry, OH%d GBT%d link is not ready.. check the following your OH is on, the fibers are plugged in correctly, the CTP7 TX polarity is correct, and muy importante, check that your GBTX is fused with at least the minimal config.." % (ohSelect, gbtSelect))
        return
    if verbose:
        subheading('Configuring OH%d GBT%d' % (ohSelect, gbtSelect))

    if configFile[-3:] != "txt":
        print_red("Seems like the file is not a txt file, please provide a txt file generated with the GBT programmer software")
        return
    if not os.path.isfile(configFile):
        print_red("Can't find the file %s" % configFile)
        return

    timeStart = clock()

    regs = downloadConfig(ohSelect, gbtSelect, configFile)

    totalTime = clock() - timeStart
    print('time took = ' + str(totalTime) + 's')


    # setup the TTC generator for a DAQ test
    write_reg(get_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
    genEn = read_reg(get_node("BEFE.GEM.TTC.GENERATOR.ENABLE"))
    write_reg(get_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 1)
    calpulseGap = read_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"))
    write_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_CALPULSE_TO_L1A_GAP"), 0)
    l1aCnt = read_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_COUNT"))
    write_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_COUNT"), NUM_DAQ_PACKETS)
    l1aGap = read_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_GAP"))
    write_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_GAP"), PHASE_SCAN_L1A_GAP)




    # Phase Scanning:
    initVfatRegAddrs()
    for elink, vfat in GE21_GBT_ELINK_TO_VFAT[gbtSelect].items():
        if verbose:
            subheading('Scanning elink %d phase, corresponding to VFAT%d' % (elink, vfat))
        for phase in range(0, 15):
            # set phase
            for subReg in range(0, 3):
                addr = GBT_ELINK_SAMPLE_PHASE_REGS[elink][subReg]
                value = (regs[addr] & 0xf0) + phase
                wReg(ADDR_IC_ADDR, addr)
                wReg(ADDR_IC_WRITE_DATA, value)
                wReg(ADDR_IC_EXEC_WRITE, 1)
                sleep(0.000001) # writing is too fast for CVP13 :)
            # reset the link, give some time to lock and accumulate any sync errors and then check VFAT comms
            sleep(0.1)
            write_reg(get_node('BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET'), 1)
            sleep(0.001)
            cfgRunGood = 1
            cfgAddr = get_node('BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN' % (ohSelect, vfat)).address
            for i in range(PHASE_SCAN_NUM_SLOW_CONTROL_READS):
                #ret = read_reg(get_node('BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN' % (ohSelect, vfat)))
                ret = rReg(cfgAddr)
                #if (ret != '0x00000000' and ret != '0x00000001'):
                if (ret != 0 and ret != 1):
                    cfgRunGood = 0
                    break
            #sleep(0.3)
            #sleep(0.5)
            linkGood = int(read_reg(get_node('BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD' % (ohSelect, vfat))))
            syncErrCnt = int(read_reg(get_node('BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT' % (ohSelect, vfat))))
            # if communication is good, set the VFAT to run mode, and do a DAQ packet CRC error test
            daqCrcErrCnt = -1
            if cfgRunGood == 1 and linkGood == 1 and syncErrCnt == 0:
                if NUM_DAQ_PACKETS <= 0:
                    wReg(cfgAddr, 0) # set the VFAT to sleep mode
                else:
                    wReg(cfgAddr, 1) # set the VFAT to run mode
                    write_reg(get_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_THR_ARM_DAC" % (ohSelect, vfat)), 0) # set a low threshold (TODO: this may need tuning to get more or less random data)
                    write_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START"), 1)
                    genRunning = 1
                    while genRunning == 1:
                        genRunning = read_reg(get_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_RUNNING"))
                    daqCrcErrCnt = read_reg(get_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.DAQ_CRC_ERROR_CNT" % (ohSelect, vfat)))
                    daqEvtCnt = read_reg(get_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.DAQ_EVENT_CNT" % (ohSelect, vfat)))
                    if daqEvtCnt == 0:
                        daqCrcErrCnt = 999

            # print the results
            color = Colors.GREEN
            prefix = 'GOOD: '
            if (linkGood == 0) or (syncErrCnt > 0) or (cfgRunGood == 0) or (daqCrcErrCnt > 0):
                color = Colors.RED
                prefix = '>>>>>>>> BAD <<<<<<<< '
            else:
                PhaseResult[elink][phase] = True
            print(color + prefix + 'Phase = %d, VFAT%d LINK_GOOD=%d, SYNC_ERR_CNT=%d, CFG_RUN_GOOD=%d, DAQ_CRC_ERR_CNT=%d' % (phase, vfat, linkGood, syncErrCnt, cfgRunGood, daqCrcErrCnt) + Colors.ENDC)
            LINK_GOOD_Arr[elink][phase] = linkGood
            SYNC_ERR_CNT_Arr[elink][phase] = syncErrCnt
            DAQ_CRC_ERR_CNT_Arr[elink][phase]=daqCrcErrCnt

    # End of Phase Scanning
    return [PhaseResult, LINK_GOOD_Arr, SYNC_ERR_CNT_Arr, DAQ_CRC_ERR_CNT_Arr]

def downloadConfig(ohIdx, gbtIdx, filename):
    f = open(filename, 'r')

    #for now we'll operate with 8 bit words only
    write_reg(get_node("BEFE.GEM.SLOW_CONTROL.IC.READ_WRITE_LENGTH"), 1)

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
    ADDR_IC_ADDR = get_node('BEFE.GEM.SLOW_CONTROL.IC.ADDRESS').address
    ADDR_IC_WRITE_DATA = get_node('BEFE.GEM.SLOW_CONTROL.IC.WRITE_DATA').address
    ADDR_IC_EXEC_WRITE = get_node('BEFE.GEM.SLOW_CONTROL.IC.EXECUTE_WRITE').address
    ADDR_IC_EXEC_READ = get_node('BEFE.GEM.SLOW_CONTROL.IC.EXECUTE_READ').address

def initVfatRegAddrs():
    global ADDR_LINK_RESET
    ADDR_LINK_RESET = get_node('BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET').address

def selectGbt(ohIdx, gbtIdx):
    linkIdx = ohIdx * 2 + gbtIdx

    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.IC.GBTX_LINK_SELECT'), linkIdx)

    return 0

def checkGbtReady(ohIdx, gbtIdx):
    return int(read_reg(get_node('BEFE.GEM.OH_LINKS.OH%d.GBT%d_READY' % (ohIdx, gbtIdx))))

def signal_handler(sig, frame):
    print("Exiting..")
    write_reg(get_node('BEFE.GEM.GEM_SYSTEM.TESTS.GBT_LOOPBACK_EN'), 0)
    sys.exit(0)
