from cmd import Cmd
import sys, os, subprocess
from rw_reg import *
import time

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

def printCyan(string):  
    print Colors.CYAN  
    print string, Colors.ENDC

def printGreen(string):
    print Colors.GREEN
    print string, Colors.ENDC
                          
def printYellow(string):
    print Colors.YELLOW
    print string, Colors.ENDC

def printRed(string):
    print Colors.RED
    print string, Colors.ENDC

vfat = 1
min_latency = 0
max_latency = 200
latency_step = 1
l1a_cnt_min = 100

if __name__ == '__main__':

    if (len(sys.argv) < 2):
        print("Usage: latency_scan.py <vfatN> <min_latency> <max_latency> <latency_step> <min_l1a_per_latency>")
        exit(0)
    else:
        vfat = int(sys.argv[1])
        min_latency = int(sys.argv[2])
        max_latency = int(sys.argv[3])
        latency_step = int(sys.argv[4])
        l1a_cnt_min = int(sys.argv[5])

    parseXML()

    printCyan("Scanning VFAT%i. Min latency = %i, max latency = %i, latency step = %i, min L1As per latency = %i" % (vfat, min_latency, max_latency, latency_step, l1a_cnt_min))
    printRed("NOTE: you have to configurue the selected VFAT ***before*** this scan. This scan only changes the latency setting on the VFAT.")

    addrL1aCnt = getNode("GEM_AMC.TTC.CMD_COUNTERS.L1A").real_address

    printCyan("Configuring the CTP7...")

    writeReg(getNode("GEM_AMC.TTC.CTRL.L1A_ENABLE"), 0)
    writeReg(getNode("GEM_AMC.TTC.CTRL.CNT_RESET"), 1)

    writeReg(getNode("GEM_AMC.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.ENABLE"), 0)
    writeReg(getNode("GEM_AMC.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.RESET"), 1)
    writeReg(getNode("GEM_AMC.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.OH_SELECT"), 0)
    writeReg(getNode("GEM_AMC.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.VFAT_CHANNEL_GLOBAL_OR"), 1)

    l1aCounts = {}
    hitCounts = {}

    for lat in range(min_latency, max_latency + 1, latency_step):
        printYellow("Setting latency = %i" % lat)
        writeReg(getNode("GEM_AMC.OH.OH0.GEB.VFAT%i.CFG_LATENCY" % vfat), lat)
        writeReg(getNode("GEM_AMC.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.RESET"), 1)
        writeReg(getNode("GEM_AMC.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.ENABLE"), 1)
        writeReg(getNode("GEM_AMC.TTC.CTRL.CNT_RESET"), 1)
        writeReg(getNode("GEM_AMC.TTC.CTRL.L1A_ENABLE"), 1)

        l1aCnt = 0

        while(l1aCnt < l1a_cnt_min):
            l1aCnt = rReg(addrL1aCnt)
            time.sleep(0.00005)

        writeReg(getNode("GEM_AMC.TTC.CTRL.L1A_ENABLE"), 0)
        l1aCnt = rReg(addrL1aCnt)

        hitCnt = int(readReg(getNode("GEM_AMC.GEM_TESTS.VFAT_DAQ_MONITOR.VFAT%i.CHANNEL_FIRE_COUNT" % vfat)), 0)
        evtCnt = int(readReg(getNode("GEM_AMC.GEM_TESTS.VFAT_DAQ_MONITOR.VFAT%i.GOOD_EVENTS_COUNT" % vfat)), 0)

        if (evtCnt != l1aCnt):
            printRed("Good event count is not equal to L1A count!!! Good evt cnt = %i, l1a cnt = %i" %(evtCnt, l1aCnt))

        l1aCounts[lat] = l1aCnt
        hitCounts[lat] = hitCnt

    printCyan("Results (latency, l1a count, hit count):")
    printCyan("The following section can be used with sbitDelayPlot.py to make a plot:")
    print("")
    print("Latency/I:L1As/I:hits/I")
    for lat in l1aCounts:
        print("%i, %i, %i" % (lat, l1aCounts[lat], hitCounts[lat]))