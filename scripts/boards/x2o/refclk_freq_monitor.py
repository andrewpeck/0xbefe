from common.rw_reg import *
from common.utils import *
from time import *
import statistics

def main():
    num_mgts = read_reg("BEFE.SYSTEM.RELEASE.NUM_MGTS")
    num_mgts = 8
    
    #header
    header = "CLK40"
    results=[[]]
    for i in range(0, num_mgts, 4):
        header += ",MGT%d_REFCLK0,MGT%d_REFCLK1" % (i, i)
        results.append([])
        results.append([])
    print(header)
    n_iters=0
    max_iters=30
    
    while n_iters<max_iters:
        data = "%d" % read_reg("BEFE.GEM.TTC.STATUS.CLK.CLK40_FREQUENCY")
        results[0].append(read_reg("BEFE.GEM.TTC.STATUS.CLK.CLK40_FREQUENCY"))
        for i in range(0, num_mgts, 4):
            results[i//2+1].append(read_reg("BEFE.MGTS.MGT%d.STATUS.REFCLK0_FREQ" % i))
            results[i//2+2].append(read_reg("BEFE.MGTS.MGT%d.STATUS.REFCLK1_FREQ" % i))
            data += ",%d" % read_reg("BEFE.MGTS.MGT%d.STATUS.REFCLK0_FREQ" % i)
            data += ",%d" % read_reg("BEFE.MGTS.MGT%d.STATUS.REFCLK1_FREQ" % i)

        print(data)
        n_iters+=1
        sleep(1)
    print("CLK40_AVG:"+str(statistics.mean(results[0])))
    print("CLK40_STDEV:"+str(statistics.stdev(results[0])))
    for i in range(0,num_mgts,4):
        print("MGT%d_0_AVG: %s" % (i,statistics.mean(results[i//2+1])))
        print("MGT%d_0_DEV: %s" % (i,statistics.stdev(results[i//2+1])))
        print("MGT%d_1_AVG: %s" % (i,statistics.mean(results[i//2+2])))
        print("MGT%d_1_DEV: %s" % (i,statistics.stdev(results[i//2+2])))



if __name__ == '__main__':
    parse_xml()
    main()

