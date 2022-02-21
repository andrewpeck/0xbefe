from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from csc.csc_utils import *
import time
from os import path
import random

VERBOSE = False

def check_xdcfeb_rx(patterns, links):
    success_cnt = [0] * len(links)
    write_reg("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.PATTERN_EN", 1)
    pattern_data_addr = get_node("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.PATTERN_DATA").address
    rx_data_addr = get_node("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.RX_DATA").address
    rx_sel_node = get_node("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.RX_SELECT")
    for pat in patterns:
        p = pat & 0xffff
        wReg(pattern_data_addr, p)
        for i in range(len(links)):
            link = links[i]
            write_reg(rx_sel_node, link)
            rx_data = rReg(rx_data_addr) & 0xffff
            if rx_data == p:
                success_cnt[i] += 1
            elif VERBOSE:
                print("Link %d: Pattern check failed, received %s, expected %s" % (link, hex32(rx_data), hex32(p)))

    write_reg("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.PATTERN_EN", 0)
    return success_cnt

def xdcfeb_promless_test(links, num_iter, num_patterns_per_check):
    heading("Starting XDCFEB PROMless programming test")
    print("Number of iterations: %d" % num_iter)
    print("Links that will be checked: %s" % array_to_string(links))

    # read the TTC generator state, and enable it if necessary
    ttc_gen_en = read_reg("BEFE.CSC_FED.TTC.GENERATOR.ENABLE")
    if ttc_gen_en != 1:
        write_reg("BEFE.CSC_FED.TTC.GENERATOR.ENABLE", 1)

    # configure the XDCFEB switches
    write_reg("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.PROG_EN", 1) # enable PROG_B through GBT
    write_reg("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.GBT_OVERRIDE", 1) # override the switch configuration
    write_reg("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.SEL_GBT", 1) # select GBT as the programming source
    write_reg("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.SEL_8BIT", 1) # select 8bit mode
    write_reg("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.SEL_MASTER", 0) # select slave mode
    write_reg("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.SEL_CCLK_SRC", 1) # select the GBT clock for CCLK
    write_reg("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.SEL_GBT_CCLK_SRC", 0) # select elink clock for CCLK

    # check the GBT RX link status
    print("GBT RX link status:")
    for link in links:
        gbt_ready = read_reg("BEFE.CSC_FED.LINKS.GBT%d.READY" % link)
        print("    Link %d: %s" % (link, gbt_ready))

    # pre-generate random patterns for the RX check
    patterns = []
    for i in range(num_patterns_per_check):
        patterns.append(random.getrandbits(16))

    reset_fail_cnt = [0] * len(links)
    reset_success_cnt = [0] * len(links)
    program_fail_cnt = [0] * len(links)
    program_success_cnt = [0] * len(links)
    for i in range(num_iter):
        print("Iteration #%d" % i)
        # send a hard reset
        write_reg("BEFE.CSC_FED.TTC.GENERATOR.SINGLE_HARD_RESET", 1)
        # check the RX immediately with just one pattern -- we expect it to be bad, because the XDCFEB FPGA should still be programming
        success_cnt = check_xdcfeb_rx([0xbefe], links)
        for j in range(len(links)):
            if success_cnt[j] != 0:
                print_red("Reset failed for link %d" % links[j])
                reset_fail_cnt[j] += 1
            else:
                reset_success_cnt[j] += 1
        # sleep 150ms to let the FPGA to program
        time.sleep(0.15)
        # check the RX again, this time we expect it to be good
        success_cnt = check_xdcfeb_rx(patterns, links)
        for j in range(len(links)):
            if success_cnt[j] != num_patterns_per_check:
                print_red("Programming failed for link %d (number of successful pattern checks = %d out of %d)" % (links[j], success_cnt[j], num_patterns_per_check))
                program_fail_cnt[j] += 1
            else:
                program_success_cnt[j] += 1

    # return the TTC generator enable state to its initial value
    if ttc_gen_en != 1:
        write_reg("BEFE.CSC_FED.TTC.GENERATOR.ENABLE", ttc_gen_en)

    # print the test summary
    print("")
    print("=============================================================================================")
    print("Summary:")
    for i in range(len(links)):
        col = Colors.GREEN if reset_fail_cnt[i] == 0 and program_fail_cnt[i] == 0 else Colors.RED
        print_color("    Link %d: reset success cnt = %d, programming success cnt = %d, reset fail cnt = %d, programming fail cnt = %d" % (links[i], reset_success_cnt[i], program_success_cnt[i], reset_fail_cnt[i], program_fail_cnt[i]), col)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("xdcfeb_promless_test.py <link_mask> <num_iterations> [num_patterns_per_check]")
        print("   * link_mask: a bitmask indicating which XDCFEB links should be checked e.g. a value of 0x5 (0101 in binary) means that links 0 and 2 will be cheked")
        print("   * num_iterations: number of programming cycles to do")
        print("   * num_patterns_per_check: defines how many words are used to check the RX link after programming (default is 100)")
        exit()

    parse_xml()
    link_mask = parse_int(sys.argv[1])
    links = bitmask_to_array(link_mask)
    num_iter = parse_int(sys.argv[2])
    num_patterns_per_check = 100
    if len(sys.argv) > 3:
        num_patterns_per_check = parse_int(sys.argv[3])

    xdcfeb_promless_test(links, num_iter, num_patterns_per_check)
