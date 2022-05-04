from common.rw_reg import *
from os import path
import struct
from common.utils import *
from common.fw_utils import *
from common.optics import *
from common.prbs import *
import tableformatter as tf
import argparse
from time import time, sleep
import math

try:
    imp.find_module('colorama')
    from colorama import Back
except:
    pass

if __name__ == '__main__':
    # Parsing arguments
    parser = argparse.ArgumentParser(description="QSFP PRBS BERT")
    parser.add_argument("-t", "--time", action="store", dest="time", help="TIME = measurement time in minutes")
    parser.add_argument("-b", "--ber", action="store", dest="ber", help="BER = measurement till this BER. eg. 1e-12")
    parser.add_argument("-c", "--cl", action="store", dest="cl", default="0.95", help="CL = confidence level desired for BER measurement, default = 0.95")
    args = parser.parse_args()

    data_rate = 2.56 * 1e9
    if args.time is None and args.ber is None:
        print (Colors.YELLOW + "Provide either time or BER limit" + Colors.ENDC)
        sys.exit()
    if args.time is not None and args.ber is not None:
        print (Colors.YELLOW + "Provide either time or BER limit, not both" + Colors.ENDC)
        sys.exit()
    if args.time is not None:
        ber = 0
        cl = float(args.cl)
        runtime = float(args.time)
    if args.ber is not None:
        ber_limit = float(args.ber)
        cl = float(args.cl)
        runtime = (-math.log(1-cl))/(data_rate * ber_limit * 60)

    parse_xml()
    links = befe_get_all_links()

    # Print RX power at QSFP
    print ("\nQSFP RX Power for all Channels: ")
    ret = read_rx_power_all()
    print ("")

    # PRBS Disable 
    prbs_control(links, 0) # 0 means normal mode
    print("PRBS mode has been disabled on all links (TX and RX)")
    print("NOTE: TX and RX polarity is set to be non-inverted")
    prbs_status(links)
    print ("")

    # PRBS Enable 
    prbs_control(links, 5) # 5 means PRBS-31
    print("PRBS-31 has been enabled on all links (TX and RX)")
    print("NOTE: TX and RX polarity is set to be non-inverted")
    prbs_status(links)
    print ("")

    # PRBS Check Status
    t0 = time()
    time_prev = t0
    ber_passed_log = -1
    while ((time()-t0)/60.0) < runtime:
        ber_t = (-math.log(1-cl))/(data_rate * (time()-t0))
        ber_t_log = math.log(ber_t, 10)
        if ber_t_log<=-9 and (ber_passed_log-ber_t_log)>=1:
            print ("\nBER: ")
            for link in links:
                rx_mgt = link.get_mgt(MgtTxRx.RX)
                tx_mgt = link.get_mgt(MgtTxRx.TX)
                prbs_err_cnt = link.get_prbs_err_cnt()
                curr_ber_str = ""
                if prbs_err_cnt == 0:
                    curr_ber_str += Colors.GREEN + "  Link %d: BER "%link.idx
                    curr_ber_str += "< {:.2e}".format(ber_t)
                else:
                    curr_ber_str += Colors.RED + "  Link %d: Number of FEC Errors = %d"%(link.idx,prbs_err_cnt)
                curr_ber_str += " (time = %.2f min)"%((time()-t0)/60.0) + Colors.ENDC
                print (curr_ber_str)
            print ("\n")
            ber_passed_log = ber_t_log
                
        time_passed = (time()-time_prev)/60.0
        if time_passed >= 1:
            print ("Time passed: %f minutes: " % ((time()-t0)/60.0))
            for link in links:
                rx_mgt = link.get_mgt(MgtTxRx.RX)
                tx_mgt = link.get_mgt(MgtTxRx.TX)
                prbs_err_cnt = link.get_prbs_err_cnt()
                print ("  Link %d: number of FEC errors accumulated = %d" % (link.idx, prbs_err_cnt))
                print ("")
            time_prev = time() 
    print ("")

    # PRBS Disable 
    prbs_errors = {}
    for link in links:
        rx_mgt = link.get_mgt(MgtTxRx.RX)
        tx_mgt = link.get_mgt(MgtTxRx.TX)
        prbs_err_cnt = link.get_prbs_err_cnt()
        prbs_errors[link.idx] = prbs_err_cnt
    prbs_control(links, 0) # 0 means normal mode 
    print("PRBS mode has been disabled on all links (TX and RX)")
    print("NOTE: TX and RX polarity is set to be non-inverted")

    # BER Calculation 
    for link in links:
        ber_ul = (-math.log(1-cl))/ (data_rate * runtime * 60)
        ber_str = ""
        errors = prbs_errors[link.idx]
        if errors == 0:
            ber_str = "< {:.2e}".format(ber_ul)
        result_string = ""
        if errors == 0:
            result_string += Colors.GREEN
        else:
            result_string += Colors.YELLOW
        result_string += "Link %d\n"%link.idx
        result_string += "  Number of FEC errors in %.1f minutes: %d\n"%(runtime, errors)
        if errors == 0:
            result_string += "  Bit Error Ratio (BER) " + ber_str + "\n"
        print (result_string)







