#!/bin/env python
from common.rw_reg import *
from time import *

def main():

    # the parse_xml() call is only needed once, before any write_reg() or read_reg() functions are called
    parse_xml()

    #Example of writing a register
    write_reg('BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET', 1)

    #Example of reading a register
    result = read_reg('BEFE.SYSTEM.CTRL.BOARD_ID')
    print("Board ID: 0x%x" % result)

    # if you write or read from a particular register many times, you can improve the performance by looking up the XML node first and then reusing it in writeReg and readReg functions
    # if you just pass a string to writeReg or readReg like above, the XML node is looked up internally each time
    board_id_reg = get_node('BEFE.SYSTEM.CTRL.BOARD_ID')
    write_reg(board_id_reg, 0xbefe)
    board_id = read_reg(link_reset_reg)

if __name__ == '__main__':
    main()
