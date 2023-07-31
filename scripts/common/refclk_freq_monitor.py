from common.rw_reg import *
from common.utils import *
from time import *

def main():
    num_mgts = read_reg("BEFE.SYSTEM.RELEASE.NUM_MGTS")
    
    #header
    header = "CLK40"
    for i in range(0, num_mgts, 4):
        header += ",MGT%d_REFCLK0,MGT%d_REFCLK1" % (i, i)

    print(header)

    while True:
        data = "%d" % read_reg("BEFE.GEM.TTC.STATUS.CLK.CLK40_FREQUENCY")
        for i in range(0, num_mgts, 4):
            data += ",%d" % read_reg("BEFE.MGTS.MGT%d.STATUS.REFCLK0_FREQ" % i)
            data += ",%d" % read_reg("BEFE.MGTS.MGT%d.STATUS.REFCLK1_FREQ" % i)

        print(data)
        sleep(1)


if __name__ == '__main__':
    parse_xml()
    main()

