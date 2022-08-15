from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from common.promless import *
from gem.gbt import *
from gem.gem_utils import *
import sys

def lhc_freq_scan(oh, qpll):

    sdm_data_start = 9286363 # approx 40.0739MHz (40.0786 - 4.7kHz)
    sdm_data_end = 9528599 # approx 40.0833MHz (40.0786 + 4.7kHz)
    sdm_data_num_steps = 100
    sdm_data_step = int((sdm_data_end - sdm_data_start) / sdm_data_num_steps)

    write_reg("BEFE.MGTS.MGT%d.CTRL.QPLL_SDM_DATA" % qpll, sdm_data_start)
    write_reg("BEFE.MGTS.MGT%d.CTRL.QPLL_SDM_RESET" % qpll, 1)
    write_reg("BEFE.MGTS.MGT%d.CTRL.QPLL_SDM_RESET" % qpll, 0)
    print("Resetting all MGT PLLs")
    befe_reset_all_plls()
    time.sleep(1)
    print("Resetting the main MMCM")
    write_reg("BEFE.GEM.TTC.CTRL.MMCM_RESET", 1)
    time.sleep(1)
    print("Configuring and resetting all links")
    links = befe_config_links()
    time.sleep(0.1)
    write_reg("BEFE.GEM.GEM_SYSTEM.CTRL.GLOBAL_RESET", 1)
    time.sleep(0.3)
    write_reg("BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET", 1)
    time.sleep(0.1)

    i = 0
    for sdm_data in range(sdm_data_start, sdm_data_end, sdm_data_step):
        write_reg("BEFE.MGTS.MGT%d.CTRL.QPLL_SDM_DATA" % qpll, sdm_data)
        write_reg("BEFE.MGTS.MGT%d.CTRL.QPLL_SDM_RESET" % qpll, 1)
        write_reg("BEFE.MGTS.MGT%d.CTRL.QPLL_SDM_RESET" % qpll, 0)
        sleep(1)
        write_reg("BEFE.GEM.GEM_SYSTEM.CTRL.GLOBAL_RESET", 1)
        time.sleep(0.3)
        write_reg("BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET", 1)
        time.sleep(0.1)
        expected_line_rate = 156250000.0 * (61.0 + (float(sdm_data) / float(2**24))) / 2.0
        expected_txusrclk2_freq = expected_line_rate / 40.0
        expected_ttc40_freq = expected_txusrclk2_freq / 3.0
        ttc40_freq = read_reg("BEFE.GEM.TTC.STATUS.CLK.CLK40_FREQUENCY")
        ttc40_freq_diff = ttc40_freq - expected_ttc40_freq
        txusrclk2_freq = read_reg("BEFE.MGTS.MGT%d.STATUS.TXUSRCLK2_FREQ" % qpll)
        txusrclk2_freq_diff = txusrclk2_freq - expected_txusrclk2_freq

        gbt_ready = [0, 0]
        gbt_was_not_ready = [0, 0]
        for gbt in range(2):
            gbt_ready[gbt] = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt))
            gbt_was_not_ready[gbt] = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_WAS_NOT_READY" % (oh, gbt))

        print("======== step %d / %d ========" % (i, sdm_data_num_steps))
        col = Colors.GREEN if abs(ttc40_freq_diff) < 500 else Colors.ORANGE if abs(ttc40_freq_diff) < 1000 else Colors.RED
        print_color("  TTC40 FREQ: %.4fMHz, expected %.4fMHz, difference: %dHz" % (ttc40_freq/1000000.0, expected_ttc40_freq/1000000.0, int(ttc40_freq_diff)), col)
        col = Colors.GREEN if abs(txusrclk2_freq_diff) < 500 else Colors.ORANGE if abs(txusrclk2_freq_diff) < 1000 else Colors.RED
        print_color("  TXUSRCLK2 FREQ: %.4fMHz, expected %.4fMHz, difference: %dHz" % (txusrclk2_freq/1000000.0, expected_txusrclk2_freq/1000000.0, int(txusrclk2_freq_diff)), col)
        for gbt in range(2):
            col = Colors.GREEN if gbt_ready[gbt] == 1 and gbt_was_not_ready[gbt] == 0 else Colors.ORANGE if gbt_ready[gbt] == 1 and gbt_was_not_ready[gbt] == 1 else Colors.RED
            print_color("  OH%d GBT0 READY: %d, WAS NOT READY: %d" % (oh, gbt_ready[gbt], gbt_was_not_ready[gbt]), col)

        i += 1

if __name__ == '__main__':
    parse_xml()
    if len(sys.argv) < 3:
        print('Usage: gbt_manual_rx_slide.py <oh_num> <qpll_num>')
        sys.exit()

    lhc_freq_scan(int(sys.argv[1]), int(sys.argv[2]))
