from common.rw_reg import *
from common.utils import *
import tableformatter as tf
from enum import Enum
from time import sleep

try:
    imp.find_module('colorama')
    from colorama import Back
except:
    pass

class MgtTxRx(Enum):
    TX = 0
    RX = 1

class MgtPll:
    is_qpll = None
    qpll01 = None
    idx = None
    mgt = None
    refclk01 = None

    def __init__(self, mgt):
        self.mgt = mgt
        self.is_qpll = read_reg("BEFE.MGTS.MGT%d.CONFIG.%s_USE_QPLL" % (mgt.idx, mgt.txrx.name))
        if self.is_qpll == 1:
            self.qpll01 = read_reg("BEFE.MGTS.MGT%d.CONFIG.%s_QPLL_01" % (mgt.idx, mgt.txrx.name))
            self.idx = read_reg("BEFE.MGTS.MGT%d.CONFIG.QPLL_IDX" % mgt.idx)
            self.refclk01 = read_reg("BEFE.MGTS.MGT%d.CONFIG.QPLL%d_REFCLK_01" % (self.idx, self.qpll01))
        else:
            self.idx = mgt.idx
            self.refclk01 = read_reg("BEFE.MGTS.MGT%d.CONFIG.CPLL_REFCLK_01" % self.idx)

    def get_locked(self):
        # use the MGT index here, because the QPLL lock status is mapped to MGT channels in the firmware
        if self.is_qpll == 1:
            return read_reg("BEFE.MGTS.MGT%d.STATUS.QPLL%d_LOCKED" % (self.mgt.idx, self.qpll01))
        else:
            return read_reg("BEFE.MGTS.MGT%d.STATUS.CPLL_LOCKED" % self.idx)

    def reset(self):
        if self.isqpll == 1:
            write_reg("BEFE.MGTS.MGT%d.CTRL.QPLL%d_RESET" % (self.idx, self.qpll01), 1)
        else:
            write_reg("BEFE.MGTS.MGT%d.CTRL.CPLL_RESET" % self.idx, 1)

    def __str__(self):
        return "CPLL" if self.is_qpll == 0 else "QPLL%d" % self.qpll01

def mgt_get_status_labels():
    return ["MGT", "Type", "Rst Done", "PhAlign Done", "PLL", "PLL Lock", "Refclk Freq"]

class Mgt:
    idx = None
    txrx = None
    pll = None
    type = None

    def __init__(self, idx, txrx):
        self.idx = idx
        self.txrx = txrx
        self.pll = MgtPll(self)
        self.type = read_reg("BEFE.MGTS.MGT%d.CONFIG.LINK_TYPE" % self.idx)

    def get_status(self):
        reset_done = read_reg("BEFE.MGTS.MGT%d.STATUS.%s_RESET_DONE" % (self.idx, self.txrx.name))
        phalign_done = read_reg("BEFE.MGTS.MGT%d.STATUS.%s_PHALIGN_DONE" % (self.idx, self.txrx.name))
        pll_type = str(self.pll)
        pll_locked = self.pll.get_locked()
        refclk_freq = read_reg("BEFE.MGTS.MGT%d.STATUS.REFCLK%d_FREQ" % (self.idx, self.pll.refclk01))
        refclk_freq_config = read_reg("BEFE.MGTS.MGT%d.CONFIG.%s_REFCLK_FREQ" % (self.idx, self.txrx.name))
        refclk_freq_str = refclk_freq.to_string(hex=False, use_color=False)
        if (refclk_freq < refclk_freq_config - refclk_freq_config * 0.0001) or (refclk_freq > refclk_freq_config + refclk_freq_config * 0.0001):
            refclk_freq_str = color_string(refclk_freq_str, Colors.RED)
        else:
            refclk_freq_str = color_string(refclk_freq_str, Colors.GREEN)

        return ["%d" % self.idx, self.type, reset_done, phalign_done, pll_type + " #%d" % self.pll.idx, pll_locked, refclk_freq_str]

    def config(self, invert, tx_diff_ctrl=0x18, tx_pre_cursor=0, tx_post_cursor=0):
        polarity = 1 if invert else 0
        write_reg("BEFE.MGTS.MGT%d.CTRL.%s_POLARITY" % (self.idx, self.txrx.name), polarity)
        if self.txrx == MgtTxRx.TX:
            write_reg("BEFE.MGTS.MGT%d.CTRL.TX_DIFF_CTRL" % self.idx, tx_diff_ctrl)
            write_reg("BEFE.MGTS.MGT%d.CTRL.TX_PRE_CURSOR" % self.idx, tx_pre_cursor)
            write_reg("BEFE.MGTS.MGT%d.CTRL.TX_POST_CURSOR" % self.idx, tx_post_cursor)

    def set_prbs_mode(self, mode):
        if self.txrx == MgtTxRx.TX and self.type.to_string() in ["MGT_25GBE", "MGT_10GBE", "MGT_TX_10GBE_RX_LPGBT"]:
            if mode != 0:
                # UG578 section "Using TX Pattern Generator" (selecting TXOUTCLKSEL is done in the firmware)
                print("MGT %d TX is using async gearbox, which due to a silicon bug needs to be disabled over DRP to enable PRBS. Disabling async gearbox..." % self.idx)
                write_reg("BEFE.MGTS.MGT%d.CTRL.TX_PCS_RESET" % self.idx, 1)
                reg124 = self.drp_read(124)
                reg124 = reg124 & 0xdfff # TXGEARBOX_EN = 0
                reg124 = reg124 | 0x0080 # TXBUF_EN = 1
                self.drp_write(124, reg124)
                write_reg("BEFE.MGTS.MGT%d.CTRL.TX_PRBS_SEL" % self.idx, mode)
                write_reg("BEFE.MGTS.MGT%d.CTRL.TX_PCS_RESET" % self.idx, 0)
            else:
                print("MGT %d TX is using async gearbox, which due to a silicon bug needs to be disabled over DRP to enable PRBS. Disabling PRBS, enabling back the async gearbox..." % self.idx)
                write_reg("BEFE.MGTS.MGT%d.CTRL.TX_PCS_RESET" % self.idx, 1)
                reg124 = self.drp_read(124)
                reg124 = reg124 | 0x2000 # TXGEARBOX_EN = 1
                reg124 = reg124 & 0xff7f # TXBUF_EN = 1
                self.drp_write(124, reg124)
                write_reg("BEFE.MGTS.MGT%d.CTRL.TX_PRBS_SEL" % self.idx, mode)
                write_reg("BEFE.MGTS.MGT%d.CTRL.TX_PCS_RESET" % self.idx, 0)
        else:
            write_reg("BEFE.MGTS.MGT%d.CTRL.%s_PRBS_SEL" % (self.idx, self.txrx.name), mode)

    def get_prbs_mode(self):
        return read_reg("BEFE.MGTS.MGT%d.CTRL.%s_PRBS_SEL" % (self.idx, self.txrx.name))

    def reset_prbs_err_cnt(self):
        if self.txrx == MgtTxRx.RX:
            write_reg("BEFE.MGTS.MGT%d.CTRL.RX_PRBS_CNT_RESET" % self.idx, 1)

    def force_prbs_err(self):
        if self.txrx == MgtTxRx.TX:
            write_reg("BEFE.MGTS.MGT%d.CTRL.TX_PRBS_FORCE_ERR" % self.idx, 1)

    def get_prbs_err_cnt(self):
        if self.txrx == MgtTxRx.RX:
            return read_reg("BEFE.MGTS.MGT%d.STATUS.PRBS_ERROR_CNT" % self.idx)
        else:
            return None

    def drp_read(self, addr):
        # DRP integrated in the MGT addr table
        write_reg("BEFE.MGTS.CHANNEL_DRP.MGT_SELECT", self.idx)
        write_reg("BEFE.MGTS.CHANNEL_DRP.ADDRESS", addr)
        return read_reg("BEFE.MGTS.CHANNEL_DRP.READ_VALUE")
        # DRP with a separate address table (not used due to long loading of the address table)
        # return read_reg("BEFE.MGT_CHAN_DRP.CHAN%d.REG%d" % (self.idx, addr))

    def drp_write(self, addr, value):
        # DRP integrated in the MGT addr table
        write_reg("BEFE.MGTS.CHANNEL_DRP.MGT_SELECT", self.idx)
        write_reg("BEFE.MGTS.CHANNEL_DRP.ADDRESS", addr)
        write_reg("BEFE.MGTS.CHANNEL_DRP.WRITE_VALUE", value)
        # DRP with a separate address table (not used due to long loading of the address table)
        # write_reg("BEFE.MGT_CHAN_DRP.CHAN%d.REG%d" % (self.idx, addr), value)

    def reset(self, include_pll_reset=False):
        if include_pll_reset:
            self.pll.reset()
        write_reg("BEFE.MGTS.MGT%d.CTRL.%s_RESET" % (self.idx, self.txrx.name), 1)
        if self.txrx.name.lower() == "rx":
            write_reg("BEFE.MGTS.MGT%d.CTRL.RX_PRBS_CNT_RESET" % (self.idx), 1)

    def set_eyescan_reset(self, value):
        write_reg("BEFE.MGTS.MGT%d.CTRL.EYESCAN_RESET" % (self.idx), value)

    def set_low_power_mode(self, value):
        if self.txrx.name.lower() == "rx":
            write_reg("BEFE.MGTS.MGT%d.CTRL.RX_LOW_POWER_MODE" % (self.idx), value)

class Link:
    idx = None
    tx_mgt = None
    rx_mgt = None
    tx_inv = None
    rx_inv = None
    tx_usage = None
    rx_usage = None

    def __init__(self, idx, tx_usage=None, rx_usage=None):
        self.idx = idx
        max_mgts = read_reg("BEFE.SYSTEM.RELEASE.NUM_MGTS")
        tx_mgt_idx = read_reg("BEFE.SYSTEM.LINK_CONFIG.LINK%d.TX_MGT_IDX" % self.idx)
        rx_mgt_idx = read_reg("BEFE.SYSTEM.LINK_CONFIG.LINK%d.RX_MGT_IDX" % self.idx)
        self.tx_usage = tx_usage
        self.rx_usage = rx_usage
        if tx_mgt_idx < max_mgts:
            self.tx_mgt = Mgt(tx_mgt_idx, MgtTxRx.TX)
            self.tx_inv = True if read_reg("BEFE.SYSTEM.LINK_CONFIG.LINK%d.TX_INVERTED" % self.idx) == 1 else False
        if rx_mgt_idx < max_mgts:
            self.rx_mgt = Mgt(rx_mgt_idx, MgtTxRx.RX)
            self.rx_inv = True if read_reg("BEFE.SYSTEM.LINK_CONFIG.LINK%d.RX_INVERTED" % self.idx) == 1 else False

    def config_tx(self, invert=False):
        if self.tx_mgt is not None:
            inv = self.tx_inv if not invert else not self.tx_inv
            self.tx_mgt.config(inv)

    def config_rx(self, invert=False):
        if self.tx_mgt is not None:
            inv = self.rx_inv if not invert else not self.rx_inv
            self.rx_mgt.config(inv)

    def reset_tx(self):
        if self.tx_mgt is not None:
            self.tx_mgt.reset()

    def reset_rx(self):
        if self.rx_mgt is not None:
            self.rx_mgt.reset()

    def set_low_power_mode_rx(self, value):
        if self.rx_mgt is not None:
            self.rx_mgt.set_low_power_mode(value)

    def get_mgt(self, txrx):
        if txrx == MgtTxRx.TX:
            return self.tx_mgt
        elif txrx == MgtTxRx.RX:
            return self.rx_mgt
        else:
            return None

    def set_prbs_mode(self, txrx, mode):
        mgt = self.get_mgt(txrx)
        if mgt is not None:
            mgt.set_prbs_mode(mode)

    def get_prbs_mode(self, txrx):
        mgt = self.get_mgt(txrx)
        if mgt is not None:
            return mgt.get_prbs_mode()
        else:
            return None

    def reset_prbs_err_cnt(self):
        mgt = self.get_mgt(MgtTxRx.RX)
        if mgt is not None:
            mgt.reset_prbs_err_cnt()

    def force_prbs_err(self):
        mgt = self.get_mgt(MgtTxRx.TX)
        if mgt is not None:
            mgt.force_prbs_err()

    def get_prbs_err_cnt(self):
        mgt = self.get_mgt(MgtTxRx.RX)
        if mgt is not None:
            return mgt.get_prbs_err_cnt()
        else:
            return None

    def get_status_labels(self):
        mgt_cols = mgt_get_status_labels()
        cols = ["Link", "TX Usage", "RX Usage"]
        for col in mgt_cols:
            cols.append("TX " + col)
            cols.append("RX " + col)
        return cols

    def get_status(self):
        none_status = ["NONE"] * len(mgt_get_status_labels())
        if self.tx_mgt is not None:
            tx_status = self.tx_mgt.get_status()
        else:
            tx_status = none_status
        if self.rx_mgt is not None:
            rx_status = self.rx_mgt.get_status()
        else:
            rx_status = none_status

        tx_usage = "NONE" if self.tx_usage is None else self.tx_usage
        rx_usage = "NONE" if self.rx_usage is None else self.rx_usage
        status = [self.idx, tx_usage, rx_usage]
        for i in range(len(tx_status)):
            status.append(tx_status[i])
            status.append(rx_status[i])

        return status

    def get_txrx_status_labels(self, txrx):
        mgt_cols = mgt_get_status_labels()
        cols = ["Link", "%s Usage" % txrx.name]
        for col in mgt_cols:
            cols.append(("%s " % txrx.name) + col)
        return cols

    def get_txrx_status(self, txrx):
        none_status = ["NONE"] * len(mgt_get_status_labels())
        mgt = self.get_mgt(txrx)
        if mgt is not None:
            status = mgt.get_status()
        else:
            status = none_status

        txrx_usage = self.tx_usage if txrx == MgtTxRx.TX else self.rx_usage if txrx == MgtTxRx.RX else None
        usage = "NONE" if txrx_usage is None else txrx_usage

        return [self.idx, usage] + status

def befe_get_all_mgts(txrx):
    num_mgts = read_reg("BEFE.SYSTEM.RELEASE.NUM_MGTS")
    mgts = []
    for i in range(num_mgts):
        mgt = Mgt(i, txrx)
        mgts.append(mgt)
    return mgts

def befe_print_mgt_status(txrx):
    mgts = befe_get_all_mgts(txrx)
    cols = mgt_get_status_labels()
    rows = []
    for mgt in mgts:
        status = mgt.get_status()
        status[0] = txrx.name + " " + status[0]
        rows.append(status)
    print(tf.generate_table(rows, cols, grid_style=DEFAULT_TABLE_GRID_STYLE))

def befe_get_all_links(skip_usage_data=False):
    num_links = read_reg("BEFE.SYSTEM.RELEASE.NUM_LINKS")

    # get the link usage (depends if it's CSC or GEM)
    tx_usage = ["NONE"] * num_links
    rx_usage = ["NONE"] * num_links
    flavor = read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")

    ############### GEM ###############
    if flavor.to_string() == "GEM" and not skip_usage_data:
        ### OH links ###
        num_ohs = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_OF_OH")
        num_gbts = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_OF_GBTS_PER_OH")
        for oh in range(num_ohs):
            # GBT links
            for gbt in range(num_gbts):
                tx_link = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.OH_LINK_CONFIG.OH%d.GBT%d_TX" % (oh, gbt))
                rx_link = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.OH_LINK_CONFIG.OH%d.GBT%d_RX" % (oh, gbt))
                gbt_label = color_string("OH%d GBT%d" % (oh, gbt), Colors.GREEN)
                if tx_link < num_links:
                    tx_usage[tx_link] = gbt_label
                if rx_link < num_links:
                    rx_usage[rx_link] = gbt_label

        ### trigger TX links ###
        use_trig_tx = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.USE_TRIG_TX_LINKS")
        num_trig_tx = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_TRIG_TX_LINKS")
        for trig_tx in range(num_trig_tx):
            tx_link = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.TRIG_TX_LINK_CONFIG.TX%d_LINK" % trig_tx)
            if tx_link < num_links:
                tx_usage[tx_link] = color_string("TRIG TX%d" % trig_tx, Colors.GREEN)

        ### Local DAQ ###
        use_ldaq_link = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.USE_LOCAL_DAQ_LINK")
        if use_ldaq_link != 0:
            ldaq_link = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.LOCAL_DAQ_LINK")
            if ldaq_link < num_links:
                tx_usage[ldaq_link] = color_string("Local DAQ", Colors.GREEN)
                rx_usage[ldaq_link] = color_string("Local DAQ", Colors.GREEN)

    ############### CSC ###############
    elif flavor.to_string() == "CSC_FED" and not skip_usage_data:
        ### DMB links ###
        num_dmbs = read_reg("BEFE.CSC_FED.CSC_SYSTEM.RELEASE.NUM_OF_DMBS")
        for i in range(num_dmbs):
            dmb_type = read_reg("BEFE.CSC_FED.CSC_SYSTEM.RELEASE.DMB_LINK_CONFIG.DMB%d.TYPE" % i)
            dmb_label = color_string("DMB%d (%s)" % (i, dmb_type), Colors.GREEN)
            tx_link = read_reg("BEFE.CSC_FED.CSC_SYSTEM.RELEASE.DMB_LINK_CONFIG.DMB%d.TX_LINK" % i)
            if tx_link < num_links:
                tx_usage[tx_link] = dmb_label
            num_rx_links = read_reg("BEFE.CSC_FED.CSC_SYSTEM.RELEASE.DMB_LINK_CONFIG.DMB%d.NUM_RX_LINKS" % i)
            for j in range(num_rx_links):
                rx_link = read_reg("BEFE.CSC_FED.CSC_SYSTEM.RELEASE.DMB_LINK_CONFIG.DMB%d.RX%d_LINK" % (i, j))
                if rx_link < num_links:
                    rx_usage[rx_link] = dmb_label

        ### Local DAQ link ###
        use_ldaq_link = read_reg("BEFE.CSC_FED.CSC_SYSTEM.RELEASE.USE_LOCAL_DAQ_LINK")
        if use_ldaq_link != 0:
            ldaq_link = read_reg("BEFE.CSC_FED.CSC_SYSTEM.RELEASE.LOCAL_DAQ_LINK")
            if ldaq_link < num_links:
                tx_usage[ldaq_link] = color_string("Local DAQ", Colors.GREEN)
                rx_usage[ldaq_link] = color_string("Local DAQ", Colors.GREEN)
    else:
        print_red("Unknown firmware flavor %s" % str(flavor))

    # get the links
    links = []
    for i in range(num_links):
        links.append(Link(i, tx_usage[i], rx_usage[i]))

    return links

def befe_print_link_status(links, txrx=None):
    if len(links) == 0:
        return
    cols = links[0].get_status_labels() if txrx is None else links[0].get_txrx_status_labels(txrx)
    rows = []
    for link in links:
        status = link.get_status() if txrx is None else link.get_txrx_status(txrx)
        rows.append(status)

    print(tf.generate_table(rows, cols, grid_style=DEFAULT_TABLE_GRID_STYLE)) # FULL_TABLE_GRID_STYLE

def befe_reset_all_plls():
    num_mgts = read_reg("BEFE.SYSTEM.RELEASE.NUM_MGTS")
    for i in range(num_mgts):
        write_reg("BEFE.MGTS.MGT%d.CTRL.CPLL_RESET" % i, 1)
        write_reg("BEFE.MGTS.MGT%d.CTRL.QPLL0_RESET" % i, 1)
        write_reg("BEFE.MGTS.MGT%d.CTRL.QPLL1_RESET" % i, 1)

# if loopback test is set to true, links will not be inverted regardless of the station
def befe_config_links(loopback_test=False):
    # check if we need to invert GBT TX or RX
    gbt_tx_invert = False
    gbt_rx_invert = False
    flavor = read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
    if flavor == 0 and not loopback_test: # GEM
        gem_station = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.GEM_STATION")
        if gem_station == 1:
            gbt_tx_invert = True
        elif gem_station == 2:
            gbt_rx_invert = True

    links = befe_get_all_links()
    for link in links:
        tx_invert = False
        rx_invert = False
        if link.tx_mgt is not None and "GBTX" in link.tx_mgt.type.to_string():
            tx_invert = gbt_tx_invert
        if link.rx_mgt is not None and "GBTX" in link.rx_mgt.type.to_string():
            rx_invert = gbt_rx_invert

        if flavor == 0 and tx_invert:
            print("Inverting TX because it's a GBTX link on station %d" % gem_station)
        if flavor == 0 and rx_invert:
            print("Inverting RX because it's a GBTX link on station %d" % gem_station)

        link.config_tx(invert=tx_invert)
        link.reset_tx()
        link.config_rx(invert=rx_invert)
        link.reset_rx()

    return links

def befe_toggle_dfe_lpm():
    gem_station = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.GEM_STATION")
    if gem_station !=0:
        return
    links = befe_get_all_links()
    for link in links:
        link.set_low_power_mode_rx(0)
        link.reset_rx()
        sleep(0.01)
        link.set_low_power_mode_rx(1)
        link.reset_rx()
        sleep(0.01)

def befe_get_fw_info():
    fw_flavor = read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
    board_type = read_reg("BEFE.SYSTEM.RELEASE.BOARD_TYPE")
    fw_version = read_reg("BEFE.SYSTEM.RELEASE.VERSION").to_string(use_color=False)
    fw_date = read_reg("BEFE.SYSTEM.RELEASE.DATE")
    fw_time = read_reg("BEFE.SYSTEM.RELEASE.TIME")
    fw_git_sha = read_reg("BEFE.SYSTEM.RELEASE.GIT_SHA")

    flavor_str = "UNKNOWN FLAVOR"
    if fw_flavor == 0:
        gem_station = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.GEM_STATION")
        flavor_str = "GE1/1" if gem_station == 1 else "GE2/1" if gem_station == 2 else "ME0" if gem_station == 0 else "UNKNOWN GEM STATION"
        oh_version = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.OH_VERSION")
        num_ohs = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_OF_OH")
        flavor_str += " (%d OHv%d)" % (num_ohs, oh_version)
    elif fw_flavor == 1:
        num_dmbs = read_reg("BEFE.CSC_FED.CSC_SYSTEM.RELEASE.NUM_OF_DMBS")
        flavor_str = "CSC (%d DMBs)" % num_dmbs

    description = "BEFE %s %s running on %s (built on %s at %s, git SHA: %08x)" % (flavor_str, fw_version, board_type, fw_date, fw_time, fw_git_sha)

    return {"fw_flavor": fw_flavor, "fw_flavor_str": flavor_str, "board_type": board_type.to_string(), "fw_version": fw_version, "fw_date": fw_date, "fw_time": fw_time, "fw_git_sha": fw_git_sha, "description": description}

def befe_print_fw_info():
    fw_info = befe_get_fw_info()
    heading(fw_info["description"])
    return fw_info

if __name__ == '__main__':
    parse_xml()
    print()
    print("=============== TX MGT Status ===============")
    befe_print_mgt_status(MgtTxRx.TX)
    print("=============== RX MGT Status ===============")
    befe_print_mgt_status(MgtTxRx.RX)
    print("=============== Link Status ===============")
    links = befe_get_all_links()
    befe_print_link_status(links)
    print("=============== TX Link Status ===============")
    befe_print_link_status(links, MgtTxRx.TX)
    print("=============== RX Link Status ===============")
    befe_print_link_status(links, MgtTxRx.RX)
