from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
import time
import sys
import random

def reg_perf(num_iter):
    board_id_node = get_node("BEFE.SYSTEM.CTRL.BOARD_ID")
    heading("Performing a static value repeated read test...")
    regTest([board_id_node.address], [0xbefe], [0xffff], True, num_iter)
    heading("Performing a random write/read test...")
    regTest([board_id_node.address], [0xbefe], [0xffff], True, num_iter, rand_write_read=True)

def regTest(regAddresses, initValues, regMasks, doInitWrite, numIterations, rand_write_read=False):
    if (doInitWrite):
        for i in range(len(regAddresses)):
            wReg(regAddresses[i], initValues[i])

    busErrors = 0
    valueErrors = 0


    timeStart = time.clock()
    chunkSize = int(numIterations / 10)
    numChunks = int(numIterations / chunkSize)

    for chunk in range(0, numChunks):
        for chi in range(0, chunkSize):
            for regi in range(len(regAddresses)):
#                sleep(0.01)
                regAddress = regAddresses[regi]
                initValue = initValues[regi]
                regMask = regMasks[regi]

                if rand_write_read:
                    initValue = random.getrandbits(32)
                    wReg(regAddress, initValue)

                value = rReg(regAddress) & regMask
                if value != initValue & regMask:
                    i = chunk * chunkSize + chi
                    if value == 0xdeaddead & regMask:
                        busErrors += 1
                        print_red("Bus error in iteration #%d" % i)
                        exit()
                    else:
                        valueErrors += 1
                        print_red("Value error. Expected " + hex(initValue & regMask) + ", got " + hex(value) + " in iteration #" + str(i))

        print("Progress: %d / %d" % ((chunk + 1) * chunkSize, numIterations))

    totalTime = time.clock() - timeStart

    print_cyan("Test finished " + str(numIterations) + " iterations in " + str(totalTime) + " seconds. Bus errors = " + str(busErrors) + ", value errors = " + str(valueErrors))
    avg_reg_access_time_us = ((totalTime / numIterations) / len(regAddresses)) * 1000000.0
    print_cyan("Average reg access time: %dus" % avg_reg_access_time_us)


if __name__ == '__main__':
    num_iter = 100000
    if len(sys.argv) < 2:
        print("USAGE: reg_access_performance.py <num_iterations>")
        exit()
    else:
        num_iter = int(sys.argv[1])

    parse_xml()
    reg_perf(num_iter)
