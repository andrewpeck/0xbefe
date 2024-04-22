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

def x2o_optics(qsfps=None, show_opts=False, show_other=True):
    if qsfps is None:
        qsfps = x2o_get_qsfps()

    qsfp_present_cages = qsfps.keys()

    cols = ["Cage", "Type", "Part", "Temperature", "RX power", "Alarms", "CDR"]
    if show_opts:
        cols.append("Options")
    if show_other:
        cols.append("Other")

    rows = []
    for i in range(X2O_NUM_CAGES):
        cage = "%d" % i
        type = "----"
        tech = "----"
        vendor = "----"
        pn = "----"
        part = "----"
        temp = "----"
        rx_power = "----"
        alarms = "----"
        options = "----"
        other = "----"
        cdr_status = "----"
        if i in qsfp_present_cages:
            qsfp = qsfps[i]
            qsfp.select()
            type = qsfp.identifier().replace(" or later", "")
            vendor = qsfp.vendor()
            pn = qsfp.part_number()
            sn = qsfp.serial_number()
            # part = vendor + "\n" + type + "\n" + pn + "\nS/N: " + sn
            part = vendor + "\n" + pn + "\nS/N: " + sn
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

            if show_other:
                other = "RX squelch dis: %s" % hex(qsfp.rx_squelch_disabled())
                emph_01 = qsfp.read_reg(3, 236)
                emph_23 = qsfp.read_reg(3, 237)
                amp_01 = qsfp.read_reg(3, 238)
                amp_23 = qsfp.read_reg(3, 239)
                other += "\nRX emphasis: %d %d %d %d" % ((emph_01 >> 4) & 0xf, emph_01 & 0xf, (emph_23 >> 4) & 0xf, emph_23 & 0xf)
                other += "\nRX amplitude: %d %d %d %d" % ((amp_01 >> 4) & 0xf, amp_01 & 0xf, (amp_23 >> 4) & 0xf, amp_23 & 0xf)

            cdr_status = "TX: " + hex(qsfp.tx_cdr_enabled()) + ", RX: " + hex(qsfp.rx_cdr_enabled())



        row = [cage, type, part, temp, rx_power, alarms, cdr_status]
        if show_opts:
            row.append(options)
        if show_other:
            row.append(other)
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

def x2o_disable_tx_squelch(qsfp):
    qsfp.select()
    qsfp.disable_tx_squelch(0xf)

def x2o_enable_tx_squelch(qsfp):
    qsfp.select()
    qsfp.disable_tx_squelch(0x0)

def x2o_enable_rx_cdr(qsfp):
    qsfp.select()
    qsfp.enable_rx_cdr(0xf)

def x2o_disable_rx_cdr(qsfp):
    qsfp.select()
    qsfp.enable_rx_cdr(0x0)

def x2o_enable_tx_cdr(qsfp):
    qsfp.select()
    qsfp.enable_tx_cdr(0xf)

def x2o_disable_tx_cdr(qsfp):
    qsfp.select()
    qsfp.enable_tx_cdr(0x0)

def x2o_enable_tx(qsfp, channel=None):
    qsfp.select()
    mask = 0xf
    if channel is not None:
        mask = qsfp.tx_enabled() | (1 << channel)
    qsfp.enable_tx(mask)

def x2o_disable_tx(qsfp, channel=None):
    qsfp.select()
    mask = 0x0
    if channel is not None:
        mask = qsfp.tx_enabled() & ~(1 << channel)
    qsfp.enable_tx(mask)

def set_qsfp_rx_emphasis(qsfp, emphasis):
    qsfp.select()
    qsfp.set_rx_output_emphasis([emphasis]*4)

def set_qsfp_rx_amplitude(qsfp, amplitude):
    qsfp.select()
    qsfp.set_rx_output_amplitude([amplitude]*4)

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

    parser.add_argument('-rsd',
                        '--disable_rx_squelch',
                        dest='disable_rx_squelch',
                        help="Disable RX squelch on the given cage")

    parser.add_argument('-rse',
                        '--enable_rx_squelch',
                        dest='enable_rx_squelch',
                        help="Enable RX squelch on the given cage")

    parser.add_argument('-tsd',
                        '--disable_tx_squelch',
                        dest='disable_tx_squelch',
                        help="Disable TX squelch on the given cage")

    parser.add_argument('-tse',
                        '--enable_tx_squelch',
                        dest='enable_tx_squelch',
                        help="Enable TX squelch on the given cage")

    parser.add_argument('-rcd',
                        '--disable_rx_cdr',
                        dest='disable_rx_cdr',
                        help="Disable RX CDR on the given cage")

    parser.add_argument('-rce',
                        '--enable_rx_cdr',
                        dest='enable_rx_cdr',
                        help="Enable RX CDR on the given cage")

    parser.add_argument('-tcd',
                        '--disable_tx_cdr',
                        dest='disable_tx_cdr',
                        help="Disable TX CDR on the given cage")

    parser.add_argument('-tce',
                        '--enable_tx_cdr',
                        dest='enable_tx_cdr',
                        help="Enable TX CDR on the given cage")

    parser.add_argument('-vit100',
                        '--configure_vitex_100g',
                        dest='configure_vitex_100g',
                        help="Configures Vitex 100G QSFP for CSC operation (sets RX emphasis to 0, and amplitude to max)")

    parser.add_argument('-vit100all',
                        '--configure_vitex_100g_all',
                        action="store_true",
                        dest='configure_vitex_100g_all',
                        help="Configures all Vitex 100G QSFP for CSC operation (sets RX emphasis to 0, and amplitude to max)")

    parser.add_argument('-te',
                        '--enable_tx',
                        dest='enable_tx',
                        help="Enable TX on the given cage or channel: if only one number is provided, that whole cage will be switched on, and if two numbers separated by a comma are provided then only one channel will be turned on")

    parser.add_argument('-td',
                        '--disable_tx',
                        dest='disable_tx',
                        help="Disable TX on the given cage or channel: if only one number is provided, that whole cage will be switched off, and if two numbers separated by a comma are provided then only one channel will be turned off")

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

    if args.disable_tx_squelch is not None:
        cage = int(args.disable_tx_squelch)
        if cage not in qsfps:
            print_red("Cannot disable TX squelch on cage %d, because there's no QSFP installed in that cage" % cage)
        else:
            print("Disabling TX squelch on cage %d" % cage)
            x2o_disable_tx_squelch(qsfps[cage])

    if args.enable_tx_squelch is not None:
        cage = int(args.enable_tx_squelch)
        if cage not in qsfps:
            print_red("Cannot enable TX squelch on cage %d, because there's no QSFP installed in that cage" % cage)
        else:
            print("Enabling TX squelch on cage %d" % cage)
            x2o_enable_tx_squelch(qsfps[cage])

    if args.disable_rx_cdr is not None or args.enable_rx_cdr is not None or args.disable_tx_cdr is not None or args.enable_tx_cdr is not None:
        cage = int(args.disable_rx_cdr) if args.disable_rx_cdr is not None else int(args.enable_rx_cdr) if args.enable_rx_cdr is not None else int(args.disable_tx_cdr) if args.disable_tx_cdr is not None else int(args.enable_tx_cdr)
        if cage not in qsfps:
            print_red("Cannot control CDR on cage %d, because there's no QSFP installed in that cage" % cage)
        else:
            if args.disable_rx_cdr is not None:
                print("Disabling RX CDR on cage %d" % cage)
                x2o_disable_rx_cdr(qsfps[cage])
            if args.enable_rx_cdr is not None:
                print("Enabling RX CDR on cage %d" % cage)
                x2o_enable_rx_cdr(qsfps[cage])
            if args.disable_tx_cdr is not None:
                print("Disabling TX CDR on cage %d" % cage)
                x2o_disable_tx_cdr(qsfps[cage])
            if args.enable_tx_cdr is not None:
                print("Enabling TX CDR on cage %d" % cage)
                x2o_enable_tx_cdr(qsfps[cage])

    if args.configure_vitex_100g is not None:
        cage = int(args.configure_vitex_100g)
        if cage not in qsfps:
            print_red("Cannot configure Vitex QSFP on cage %d, because there's no QSFP installed in that cage" % cage)
        else:
            print("Configuring 100G QSFP for CSC operation: setting RX emphasis to 0, amplitude to max, and disable TX and RX CDR on cage %d" % cage)
            x2o_disable_rx_cdr(qsfps[cage])
            x2o_disable_tx_cdr(qsfps[cage])
            set_qsfp_rx_emphasis(qsfps[cage], 0)
            set_qsfp_rx_amplitude(qsfps[cage], 3)

    if args.configure_vitex_100g_all is not None and args.configure_vitex_100g_all == True:
        for i in range(X2O_NUM_CAGES):
            if i in qsfps.keys():
                qsfp = qsfps[i]
                qsfp.select()
                type = qsfp.identifier().replace(" or later", "")
                vendor = qsfp.vendor()
                if type == "QSFP28" and vendor == "Vitex":
                    print("Configuring Vitex 100G in cage %d for low speed operation (e.g. 10 or 12.5Gb/s)" % i)
                    x2o_disable_rx_cdr(qsfp)
                    x2o_disable_tx_cdr(qsfp)
                    set_qsfp_rx_emphasis(qsfp, 0)
                    set_qsfp_rx_amplitude(qsfp, 3)

    if args.enable_tx is not None:
        cage = int(args.enable_tx)
        if cage not in qsfps:
            print_red("Cannot enable/disable TX on cage %d, because there's no QSFP installed in that cage" % cage)
        else:
            print("Enabling TX on cage %d" % cage)
            x2o_enable_tx(qsfps[cage])

    if args.disable_tx is not None:
        cage = int(args.disable_tx)
        if cage not in qsfps:
            print_red("Cannot enable/disable TX on cage %d, because there's no QSFP installed in that cage" % cage)
        else:
            print("Disable TX on cage %d" % cage)
            x2o_disable_tx(qsfps[cage])

    x2o_optics(qsfps, show_opts=args.show_opts, show_other=True)
