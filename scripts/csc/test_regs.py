from common.rw_reg import *
from time import *
import array
import struct
import random
import sys

NUM_ITERATIONS = 100000
CHUNK_SIZE = 10000

def main():

    num_iter = NUM_ITERATIONS
    if len(sys.argv) > 1:
        num_iter = int(sys.argv[1])

    parse_xml()

    reg_board_id = get_node('BEFE.SYSTEM.CTRL.BOARD_ID')
    reg_release_date = get_node('BEFE.SYSTEM.RELEASE.DATE')
    reg_release_time = get_node('BEFE.SYSTEM.RELEASE.TIME')
    reg_release_sha = get_node('BEFE.SYSTEM.RELEASE.GIT_SHA')

    board_id_val = 0xbefe
    date_val = read_reg(reg_release_date)
    time_val = read_reg(reg_release_time)
    sha_val = read_reg(reg_release_sha)

    print("release date: %s, time: %s, sha: %s.. do these values look ok? no way of knowing automatically, so assuming they're correct, will use for further comparison" % (date_val, time_val, sha_val.to_string(hex=True)))

    heading("Reading only test on board_id, release date, release time, and release git sha....")
    reg_test([reg_board_id.address, reg_release_date.address, reg_release_time.address, reg_release_sha.address], [board_id_val, date_val, time_val, sha_val], [0xffff, 0xffffffff, 0xffffffff, 0xffffffff], False, num_iter)

def reg_test(reg_addresses, init_values, reg_masks, do_init_write, num_iterations, rand_write_read=False):
    if (do_init_write):
        for i in range(len(reg_addresses)):
            wReg(reg_addresses[i], init_values[i])

    bus_errors = 0
    value_errors = 0


    time_start = clock()
    chunkSize = CHUNK_SIZE
    numChunks = int(num_iterations / chunkSize)
    if numChunks == 0:
        numChunks = 1

    for chunk in range(0, numChunks):
        for chi in range(0, chunkSize):
            for regi in range(len(reg_addresses)):
#                sleep(0.01)
                regAddress = reg_addresses[regi]
                initValue = init_values[regi]
                regMask = reg_masks[regi]

                if rand_write_read:
                    initValue = random.getrandbits(32)
                    wReg(regAddress, initValue)

                value = rReg(regAddress) & regMask
                if value != initValue & regMask:
                    i = chunk * chunkSize + chi
                    if value == 0xdeaddead & regMask:
                        bus_errors += 1
                        printRed("Bus error in iteration #%d" % i)
                        exit()
                    else:
                        value_errors += 1
                        printRed("Value error. Expected " + hex(initValue & regMask) + ", got " + hex(value) + " in iteration #" + str(i))

        print("Progress: %d / %d" % ((chunk + 1) * chunkSize, num_iterations))

    total_time = clock() - time_start

    avg_reg_access_time_us = ((total_time / num_iterations) / len(reg_addresses)) * 1000000.0
    print_cyan("Test finished %d iterations in %f seconds, average reg access time = %dus. Bus errors = %d, value errors = %d" % (num_iterations, total_time, avg_reg_access_time_us, bus_errors, value_errors))

if __name__ == '__main__':
    main()
