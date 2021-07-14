#!/bin/env python
from common.rw_reg import *
from time import *
import array
import struct

def main():

    parseXML()

    #Example of writing a register
    writeReg(getNode('GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET'), 1)

    #Example of reading a register
    result = parseInt(readReg(getNode('GEM_AMC.OH_LINKS.OH0.GBT0_READY')))
    print("OH0 GBT0 ready = %d" % result)


if __name__ == '__main__':
    main()
