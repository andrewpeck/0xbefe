from common.rw_reg import *
from os import path
import struct
from common.utils import *
from common.fw_utils import *
import tableformatter as tf
import time
import csv

PRBS_MODE = 5 # PRBS-31
#PRBS_MODE = 1 # PRBS-7

TX_INVERT = False
RX_INVERT = False
#RX_INVERT = True

SKIP_USAGE_DATA = False # set this to true if GEM block slow control is not available

try:
    imp.find_module('colorama')
    from colorama import Back
except:
    pass

def prbs_control(links, prbs_mode):
    for link in links:
        link.set_prbs_mode(MgtTxRx.TX, prbs_mode)
        # if prbs_mode == 0:
        if True:
            link.config_tx(TX_INVERT) # no inversion
            link.reset_tx()

    time.sleep(0.1)

    for link in links:
        link.set_prbs_mode(MgtTxRx.RX, prbs_mode)
        # if prbs_mode == 0:
        if True:
            link.config_rx(RX_INVERT) # no inversion
            link.reset_rx()

    time.sleep(0.1)

    for link in links:
        link.reset_prbs_err_cnt()

def prbs_force_err(links):
    for link in links:
        link.force_prbs_err()

def prbs_status(links):
    cols = ["Link", "RX Usage", "RX Type", "RX MGT", "RX PRBS Mode", "TX PRBS Mode", "PRBS Error Count"]
    rows = []
    for link in links:
        rx_mgt = link.get_mgt(MgtTxRx.RX)
        tx_mgt = link.get_mgt(MgtTxRx.TX)
        if tx_mgt is None or rx_mgt is None:
            continue
        prbs_err_cnt = link.get_prbs_err_cnt()
        row = [link.idx, link.rx_usage, rx_mgt.type, rx_mgt.idx, rx_mgt.get_prbs_mode(), tx_mgt.get_prbs_mode(), prbs_err_cnt]
        rows.append(row)

    print(tf.generate_table(rows, cols, grid_style=DEFAULT_TABLE_GRID_STYLE))

def prbs_error_monitor(links, filename, sleep_between_reads=1.0):
    with open(filename, 'w') as csvfile:
        csvwriter = csv.writer(csvfile)
        links_row = []
        for link in links:
            links_row.append("link_%d" % link.idx)
        csvwriter.writerow(links_row)
        print("entering an infinite monitoring loop...")
        while True:
            err_row = []
            for link in links:
                err_row.append(link.get_prbs_err_cnt())
            csvwriter.writerow(err_row)
            time.sleep(sleep_between_reads)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: prbs.py <command> [command_specific_options]")
        print("Commands:")
        print("    enable: enables PRBS-31 mode on all TXs and RXs")
        print("    disable: disables PRBS mode on all TXs and RXs")
        print("    status: prints the PRBS error counters from all RXs")
        print("    monitor <filename> [interval_sec]: starts an infinite loop of reading the prbs error counters from all links periodicall (every interval_sec seconds) and logging that to the given file")
        print("    force_error: force an error on the TX")
        exit()

    command = sys.argv[1]
    if command not in ["enable", "disable", "status", "monitor", "force_error"]:
        print_red("Unknown command %s. Run the script without parameters to see the possible commmands" % command)
        exit()

    parse_xml()

    links = befe_get_all_links(skip_usage_data=SKIP_USAGE_DATA)

    if command == "enable":
        prbs_control(links, PRBS_MODE) # 5 means PRBS-31
        print("PRBS-31 has been enabled on all links (TX and RX)")
        print("NOTE: TX and RX polarity is set to be non-inverted")
        prbs_status(links)
    elif command == "disable":
        prbs_control(links, 0) # 0 means normal mode
        print("PRBS mode has been disabled on all links (TX and RX)")
        print("NOTE: TX and RX polarity is set to be non-inverted")
        prbs_status(links)
    elif command == "status":
        prbs_status(links)
    elif command == "monitor":
        if len(sys.argv) < 3:
            print_red("monitor command requires an extra parameter: filename, and there can be an optional paramter for interval between reads")
            exit()
        interval = 1.0 if len(sys.argv) < 4 else int(sys.argv[3])
        prbs_error_monitor(links, sys.argv[2], sleep_between_reads=interval)
    elif command == "force_error":
        prbs_force_err(links)
        prbs_status(links)
