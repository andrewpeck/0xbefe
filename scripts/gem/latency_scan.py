from cmd import Cmd
import sys, os, subprocess
from common.rw_reg import *
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

def print_cyan(string):
    print(Colors.CYAN)
    print(string + Colors.ENDC)

def print_green(string):
    print(Colors.GREEN)
    print(string + Colors.ENDC)

def printYellow(string):
    print(Colors.YELLOW)
    print(string + Colors.ENDC)

def print_red(string):
    print(Colors.RED)
    print(string + Colors.ENDC)

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

    parse_xml()

    print_cyan("Scanning VFAT%i. Min latency = %i, max latency = %i, latency step = %i, min L1As per latency = %i" % (vfat, min_latency, max_latency, latency_step, l1a_cnt_min))
    print_red("NOTE: you have to configurue the selected VFAT ***before*** this scan. This scan only changes the latency setting on the VFAT.")

    addrL1aCnt = get_node("BEFE.GEM.TTC.CMD_COUNTERS.L1A").address

    print_cyan("Configuring the CTP7...")

    write_reg(get_node("BEFE.GEM.TTC.CTRL.L1A_ENABLE"), 0)
    write_reg(get_node("BEFE.GEM.TTC.CTRL.CNT_RESET"), 1)

    write_reg(get_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.ENABLE"), 0)
    write_reg(get_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.RESET"), 1)
    write_reg(get_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.OH_SELECT"), 0)
    write_reg(get_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.VFAT_CHANNEL_GLOBAL_OR"), 1)

    l1aCounts = {}
    hitCounts = {}

    for lat in range(min_latency, max_latency + 1, latency_step):
        printYellow("Setting latency = %i" % lat)
        write_reg(get_node("BEFE.GEM.OH.OH0.GEB.VFAT%i.CFG_LATENCY" % vfat), lat)
        write_reg(get_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.RESET"), 1)
        write_reg(get_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.CTRL.ENABLE"), 1)
        write_reg(get_node("BEFE.GEM.TTC.CTRL.CNT_RESET"), 1)
        write_reg(get_node("BEFE.GEM.TTC.CTRL.L1A_ENABLE"), 1)

        l1aCnt = 0

        while(l1aCnt < l1a_cnt_min):
            l1aCnt = rReg(addrL1aCnt)
            time.sleep(0.00005)

        write_reg(get_node("BEFE.GEM.TTC.CTRL.L1A_ENABLE"), 0)
        l1aCnt = rReg(addrL1aCnt)

        hitCnt = read_reg(get_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.VFAT%i.CHANNEL_FIRE_COUNT" % vfat))
        evtCnt = read_reg(get_node("BEFE.GEM.GEM_TESTS.VFAT_DAQ_MONITOR.VFAT%i.GOOD_EVENTS_COUNT" % vfat))

        if (evtCnt != l1aCnt):
            print_red("Good event count is not equal to L1A count!!! Good evt cnt = %i, l1a cnt = %i" % (evtCnt, l1aCnt))

        l1aCounts[lat] = l1aCnt
        hitCounts[lat] = hitCnt

    print_cyan("Results (latency, l1a count, hit count):")
    print_cyan("The following section can be used with sbitDelayPlot.py to make a plot:")
    print("")
    print("Latency/I:L1As/I:hits/I")
    for lat in l1aCounts:
        print("%i, %i, %i" % (lat, l1aCounts[lat], hitCounts[lat]))
