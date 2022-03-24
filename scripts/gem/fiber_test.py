#!/usr/bin/env python

import sys
from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from common.optics import read_rx_power_from_gbt
import time

RX_POWER_THRESHOLD_ERR = 150
RX_POWER_THRESHOLD_WARN = 200

def check_gbt_errors(ber_power, num_oh, num_gbts_per_oh):
    write_reg("BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET", 1)

    sleep_time = pow(10, ber_power) / (4.8 * pow(10, 9))
    print("Waiting for %d seconds to allow 10^%d bits to pass through for error counting..." % (sleep_time, ber_power))

    wait_division = 10
    percent_complete = 0
    for i in range(wait_division):
        time.sleep(sleep_time / wait_division)
        percent_complete += 100 / wait_division
        print("    progress: %d%%" % percent_complete)

    for oh in range(num_oh):
        subheading("OH%d" % oh)
        for gbt in range(num_gbts_per_oh):
            locked = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt))
            had_unlock = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_WAS_NOT_READY" % (oh, gbt))
            fec_errors = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_FEC_ERR_CNT" % (oh, gbt))

            color = Colors.GREEN
            pass_fail_text = "PASS"
            if locked == 0 or had_unlock == 1:
                color = Colors.RED
                pass_fail_text = "FAIL"
            elif fec_errors > 0:
                color = Colors.ORANGE
                pass_fail_text = "WARNING"

            print_color("GBT%d locked = %r, had unlocks = %r, FEC error count = %d (%s)" % (gbt, locked, had_unlock, fec_errors, pass_fail_text), color)

def main(loopback):
    if loopback:
        print("Configuring the links for loopback")
        befe_config_links(loopback_test=True)

    # get the number of OHs and GBTs supported by the firmware
    num_oh = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_OF_OH")
    num_gbts_per_oh = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_OF_GBTS_PER_OH")

    # test optical power
    heading("Optical power test")
    for oh in range(num_oh):
        subheading("OH%d" % oh)
        for gbt in range(num_gbts_per_oh):
            power_uw = read_rx_power_from_gbt(oh, gbt)
            color = Colors.GREEN
            pass_fail_text = "PASS"
            if power_uw < RX_POWER_THRESHOLD_ERR:
                color = Colors.RED
                pass_fail_text = "FAIL"
            elif power_uw < RX_POWER_THRESHOLD_WARN:
                color = Colors.ORANGE
                pass_fail_text = "WARNING"

            print_color("GBT%d RX power: %duW (%s)" % (gbt, power_uw, pass_fail_text), color)

    heading("Quick GBT lock and FEC error test to BER 10^10")
    check_gbt_errors(10, num_oh, num_gbts_per_oh)

    print("")

    try:
        ber_power_str = input(Colors.YELLOW + "Would you like to do a longer and more thorough FEC error test? If yes, please enter the BER power to test to (12 is the industry standard, would take around 3.5 minutes):" + Colors.ENDC)
        ber_power = 0
        ber_power = int(ber_power_str)
        heading("GBT lock and FEC error test to BER 10^%d" % ber_power)
        check_gbt_errors(ber_power, num_oh, num_gbts_per_oh)
    except ValueError:
        pass

    print("")
    if loopback:
        print("Configuring the links for normal operation")
        befe_config_links()

if __name__ == '__main__':
    mode = ""
    if len(sys.argv) < 2:
        print("Usage: fiber_test.py <mode>")
        print('Mode: specify "loopback" if you are testing fibers in a loopback configuration, or "normal" if you have the fibers connected to the OH')
        exit(0)
    else:
        mode = sys.argv[1]
        if mode not in ["loopback", "normal"]:
            print_red('Unrecognized mode "%s", please specify either "loopback" or "normal"' % mode)
            exit(0)

    parse_xml()
    loopback = (mode == "loopback")
    main(loopback)
