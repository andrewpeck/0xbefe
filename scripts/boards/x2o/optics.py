from board.manager import *
import tableformatter as tf
from common.utils import *
import time
import argparse

try:
    imp.find_module('colorama')
    from colorama import Back
except:
    pass

X2O_NUM_CAGES = 30
X2O_QSFP_TEMP_WARN = 40
X2O_QSFP_TEMP_CRITICAL = 60
X2O_QSFP_RX_POWER_WARN = -11.0
X2O_QSFP_RX_POWER_CRITICAL = -13.0

def x2o_get_qsfps():
    x2o_manager = manager(optical_add_on_ver=2)
    qsfps = x2o_manager.peripheral.autodetect_optics(verbose=False)
    return qsfps

def x2o_optics(qsfps=None, show_opts=False, show_rx_squelch=True):
    if qsfps is None:
        qsfps = x2o_get_qsfps()

    qsfp_present_cages = qsfps.keys()

    cols = ["Cage", "Type", "Vendor", "Temperature", "RX power", "Alarms"]
    if show_opts:
        cols.append("Options")
    if show_rx_squelch:
        cols.append("RX Squelch Disabled")

    rows = []
    for i in range(X2O_NUM_CAGES):
        cage = "%d" % i
        type = "----"
        tech = "----"
        vendor = "----"
        temp = "----"
        rx_power = "----"
        alarms = "----"
        options = "----"
        rx_squelch_dis = "----"
        if i in qsfp_present_cages:
            qsfp = qsfps[i]
            qsfp.select()
            type = qsfp.identifier().replace(" or later", "")
            vendor = qsfp.vendor()
            temp = qsfp.temperature()
            temp_col = Colors.GREEN
            if temp > X2O_QSFP_TEMP_CRITICAL:
                temp_col = Colors.RED
            elif temp > X2O_QSFP_TEMP_WARN:
                temp_col = Colors.ORANGE
            temp = color_string("%.1f" % temp, temp_col)
            pa = qsfp.rx_power()
            rx_power = ""
            for ii in range(len(pa)):
                p = pa[ii]
                col = Colors.GREEN
                if p < X2O_QSFP_RX_POWER_CRITICAL:
                    col = Colors.RED
                elif p < X2O_QSFP_RX_POWER_WARN:
                    col = Colors.ORANGE
                rx_power += color_string("%.2f" % p, col)
                if ii < len(pa) - 1:
                    rx_power += "\n"

            alarms_arr = qsfp.alarms()
            alarms = ""
            for ii in range(len(alarms_arr)):
                alarm = alarms_arr[ii]
                col = Colors.ORANGE if "Warn" in alarm else Colors.RED
                alarms += color_string(alarm, col)
                if ii < len(alarms_arr) - 1:
                    alarms += "\n"

            # tech = qsfp.technology()
            if show_opts:
                opts_arr = qsfp.options()
                options = ""
                for ii in range(len(opts_arr)):
                    opt = opts_arr[ii]
                    options += opt
                    if ii < len(opts_arr) - 1:
                        options += "\n"

            if show_rx_squelch:
                rx_squelch_dis = hex(qsfp.rx_squelch_disabled())


        row = [cage, type, vendor, temp, rx_power, alarms]
        if show_opts:
            row.append(options)
        if show_rx_squelch:
            row.append(rx_squelch_dis)
        rows.append(row)

    grid_style = FULL_TABLE_GRID_STYLE
    # grid_style = DEFAULT_TABLE_GRID_STYLE
    print(tf.generate_table(rows, cols, grid_style=grid_style))

def x2o_disable_rx_squelch(qsfp):
    qsfp.select()
    qsfp.disable_rx_squelch(0xf)

def x2o_enable_rx_squelch(qsfp):
    qsfp.select()
    qsfp.disable_rx_squelch(0x0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-o',
                        '--show_opts',
                        action="store_true",
                        dest='show_opts',
                        help="Show QSFP options")

    # parser.add_argument('-s',
    #                     '--show_rx_squelch',
    #                     action="store_true",
    #                     dest='show_rx_squelch',
    #                     help="Show if RX squelch disabled mask")

    parser.add_argument('-sd',
                        '--disable_rx_squelch',
                        dest='disable_rx_squelch',
                        help="Disable RX squelch on the given cage")

    parser.add_argument('-se',
                        '--enable_rx_squelch',
                        dest='enable_rx_squelch',
                        help="Enable RX squelch on the given cage")

    args = parser.parse_args()

    qsfps = x2o_get_qsfps()

    if args.disable_rx_squelch is not None:
        cage = int(args.disable_rx_squelch)
        if cage not in qsfps:
            print_red("Cannot disable RX squelch on cage %d, because there's no QSFP installed in that cage" % cage)
        else:
            print("Disabling RX squelch on cage %d" % cage)
            x2o_disable_rx_squelch(qsfps[cage])

    if args.enable_rx_squelch is not None:
        cage = int(args.enable_rx_squelch)
        if cage not in qsfps:
            print_red("Cannot enable RX squelch on cage %d, because there's no QSFP installed in that cage" % cage)
        else:
            print("Enabling RX squelch on cage %d" % cage)
            x2o_enable_rx_squelch(qsfps[cage])


    x2o_optics(qsfps, show_opts=args.show_opts, show_rx_squelch=True)
