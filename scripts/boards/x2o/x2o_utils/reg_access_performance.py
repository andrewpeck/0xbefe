from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
import time
import sys
import random
from datetime import datetime

DATA_DIR="/root/gem/0xbefe_test_refclks/scripts/boards/x2o/data"
now = datetime.now()
d_time = now.strftime("%Y-%m-%d")
isExist = os.path.exists(DATA_DIR+"/reg_performance/"+d_time)
if not isExist:
   os.makedirs(DATA_DIR+"/reg_performance/"+d_time)
isExist = os.path.exists(DATA_DIR+"/summary/"+d_time)
if not isExist:
   os.makedirs(DATA_DIR+"/summary/"+d_time)
run_num=1
filename=DATA_DIR+"/summary/"+d_time+"/"+d_time+"_"+str(run_num)+".csv"
if(len(list(sys.argv))>2):
    run_num=int(sys.argv[2])
else:
    while(os.path.exists(filename)):
        run_num+=1
        filename=DATA_DIR+"/summary/"+d_time+"/"+d_time+"_"+str(run_num)+".csv"
filename=DATA_DIR+"/summary/"+d_time+"/"+d_time+"_"+str(run_num)+".csv"
sum_file=open(filename,"a")

ofile=open(DATA_DIR+"/reg_performance/"+d_time+"/"+d_time+"_"+str(run_num)+".csv","a")

def reg_perf(num_iter):
    board_id_node = get_node("BEFE.SYSTEM.CTRL.BOARD_ID")
    heading("Performing a static value repeated read test...")
    ofile.write("Static test\n")
    static_avg = regTest([board_id_node.address], [0xbefe], [0xffff], True, num_iter)
    heading("Performing a random write/read test...")
    ofile.write("random test\n")
    rand_avg = regTest([board_id_node.address], [0xbefe], [0xffff], True, num_iter, rand_write_read=True)
    sum_file.write("Static average reg access: %dus\n" % static_avg)
    sum_file.write("Random average reg access: %dus\n" % rand_avg)
    ofile.close()
    sum_file.close()
    if(static_avg>100):
        print_red("FAILURE: Average static read/write >100 us")
        exit(1)
    if(rand_avg>100):
        print_red("FAILURE: Random static read/write >100 us")
        exit(1)
    print_green("PASSED: read/write <100 us")




def regTest(regAddresses, initValues, regMasks, doInitWrite, numIterations, rand_write_read=False):
    if (doInitWrite):
        for i in range(len(regAddresses)):
            wReg(regAddresses[i], initValues[i])

    busErrors = 0
    valueErrors = 0
    randValues=[]
    if rand_write_read:
        for i in range(numIterations*len(regAddresses)):
            randValues.append(random.getrandbits(32))
    chunkSize = int(numIterations / 10)
    numChunks = int(numIterations / chunkSize)
    
    listIter = 0
    timeStart = time.clock()
    for chunk in range(0, numChunks):
        for chi in range(0, chunkSize):
            for regi in range(len(regAddresses)):
#                sleep(0.01)
                regAddress = regAddresses[regi]
                initValue = initValues[regi]
                regMask = regMasks[regi]

                if rand_write_read:
                    initValue = randValues[listIter]
                    wReg(regAddress, initValue)
                    listIter+=1

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
    ofile.write(("Average reg access time: %dus\n" % avg_reg_access_time_us))
    sum_file.write(("Average reg access time: %dus\n" % avg_reg_access_time_us))
    return avg_reg_access_time_us

if __name__ == '__main__':
    num_iter = 100000
    if len(sys.argv) < 2:
        print("USAGE: reg_access_performance.py <num_iterations>")
        exit()
    else:
        num_iter = int(sys.argv[1])

    parse_xml()
    reg_perf(num_iter)

