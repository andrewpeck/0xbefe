from common.rw_reg import *
from common.utils import *
import common.tables.tableformatter as tf
from enum import Enum

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

    def reset(self, include_pll_reset=False):
        if include_pll_reset:
            self.pll.reset()
        write_reg("BEFE.MGTS.MGT%d.CTRL.%s_RESET" % (self.idx, self.txrx.name), 1)

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

    def get_mgt(self, txrx):
        if txrx == MgtTxRx.TX:
            return self.tx_mgt
        elif txrx == MgtTxRx.RX:
            return self.rx_mgt
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

def befe_get_all_links():
    num_links = read_reg("BEFE.SYSTEM.RELEASE.NUM_LINKS")

    # get the link usage (depends if it's CSC or GEM)
    tx_usage = ["NONE"] * num_links
    rx_usage = ["NONE"] * num_links
    flavor = read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")

    ############### GEM ###############
    if flavor.to_string() == "GEM_AMC": # GEM
        ### OH links ###
        num_ohs = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.NUM_OF_OH")
        num_gbts = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.NUM_OF_GBTS_PER_OH")
        for oh in range(num_ohs):
            # GBT links
            for gbt in range(num_gbts):
                tx_link = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.OH_LINK_CONFIG.OH%d.GBT%d_TX" % (oh, gbt))
                rx_link = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.OH_LINK_CONFIG.OH%d.GBT%d_RX" % (oh, gbt))
                gbt_label = color_string("OH%d GBT%d" % (oh, gbt), Colors.GREEN)
                if tx_link < num_links:
                    tx_usage[tx_link] = gbt_label
                if rx_link < num_links:
                    rx_usage[rx_link] = gbt_label

        ### trigger TX links ###
        use_trig_tx = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.USE_TRIG_TX_LINKS")
        num_trig_tx = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.NUM_TRIG_TX_LINKS")
        for trig_tx in range(num_trig_tx):
            tx_link = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.TRIG_TX_LINK_CONFIG.TX%d_LINK" % trig_tx)
            if tx_link < num_links:
                tx_usage[tx_link] = color_string("TRIG TX%d" % trig_tx, Colors.GREEN)

        ### Local DAQ ###
        use_ldaq_link = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.USE_LOCAL_DAQ_LINK")
        if use_ldaq_link != 0:
            ldaq_link = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.LOCAL_DAQ_LINK")
            if ldaq_link < num_links:
                tx_usage[ldaq_link] = color_string("Local DAQ", Colors.GREEN)
                rx_usage[ldaq_link] = color_string("Local DAQ", Colors.GREEN)

    ############### CSC ###############
    elif flavor.to_string() == "CSC_FED":
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

def befe_config_links():
    # check if we need to invert GBT TX or RX
    gbt_tx_invert = False
    gbt_rx_invert = False
    flavor = read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
    if flavor == 0: # GEM
        gem_station = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.GEM_STATION")
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

def befe_print_fw_info():
    fw_flavor = read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
    board_type = read_reg("BEFE.SYSTEM.RELEASE.BOARD_TYPE")
    fw_version = read_reg("BEFE.SYSTEM.RELEASE.VERSION").to_string(use_color=False)
    fw_date = read_reg("BEFE.SYSTEM.RELEASE.DATE")
    fw_time = read_reg("BEFE.SYSTEM.RELEASE.TIME")
    fw_git_sha = read_reg("BEFE.SYSTEM.RELEASE.GIT_SHA")

    flavor_str = "UNKNOWN FLAVOR"
    if fw_flavor == 0:
        gem_station = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.GEM_STATION")
        flavor_str = "GE1/1" if gem_station == 1 else "GE2/1" if gem_station == 2 else "ME0" if gem_station == 0 else "UNKNOWN GEM STATION"
        oh_version = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.OH_VERSION")
        num_ohs = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.NUM_OF_OH")
        flavor_str += " (%d OHv%d)" % (num_ohs, oh_version)
    elif fw_flavor == 1:
        num_dmbs = read_reg("BEFE.CSC_FED.CSC_SYSTEM.RELEASE.NUM_OF_DMBS")
        flavor_str = "CSC (%d DMBs)" % num_dmbs

    heading("BEFE %s %s running on %s (built on %s at %s, git SHA: %08x)" % (flavor_str, fw_version, board_type, fw_date, fw_time, fw_git_sha))

    return {"fw_flavor": fw_flavor, "fw_flavor_str": fw_flavor.to_string(), "board_type": board_type.to_string(), "fw_version": fw_version, "fw_date": fw_date, "fw_time": fw_time, "fw_git_sha": fw_git_sha}

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
