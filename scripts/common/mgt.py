from common.rw_reg import *
from common.utils import *
import common.tables.tableformatter as tf
from enum import Enum

class MgtTxRx(Enum):
    TX = 0
    RX = 1

class MgtPll:
    is_qpll = None
    qpll01 = None
    idx = None
    refclk01 = None

    def __init__(self, mgt):
        self.is_qpll = readReg("BEFE.MGTS.MGT%d.CONFIG.%s_USE_QPLL" % (mgt.idx, mgt.txrx.name))
        if self.is_qpll == 1:
            self.qpll01 = readReg("BEFE.MGTS.MGT%d.CONFIG.%s_QPLL_01" % (mgt.idx, mgt.txrx.name))
            self.idx = readReg("BEFE.MGTS.MGT%d.CONFIG.QPLL_IDX" % mgt.idx)
            self.refclk01 = readReg("BEFE.MGTS.MGT%d.CONFIG.QPLL%d_REFCLK_01" % (self.idx, self.qpll01))
        else:
            self.idx = mgt.idx
            self.refclk01 = readReg("BEFE.MGTS.MGT%d.CONFIG.CPLL_REFCLK_01" % self.idx)

    def get_locked(self):
        if self.is_qpll == 1:
            return readReg("BEFE.MGTS.MGT%d.STATUS.QPLL%d_LOCKED" % (self.idx, self.qpll01))
        else:
            return readReg("BEFE.MGTS.MGT%d.STATUS.CPLL_LOCKED" % self.idx)

    def __str__(self):
        return "CPLL" if self.is_qpll == 0 else "QPLL%d" % self.qpll01

class Mgt:
    idx = None
    txrx = None
    pll = None

    def __init__(self, idx, txrx):
        self.idx = idx
        self.txrx = txrx
        self.pll = MgtPll(self)

    def get_status_labels(self):
        return ["Reset Done", "Phase Align Done", "PLL Type", "PLL Locked", "Refclk Freq"]

    def get_status(self):
        reset_done = readReg("BEFE.MGTS.MGT%d.STATUS.%s_RESET_DONE" % (self.idx, self.txrx.name))
        phalign_done = readReg("BEFE.MGTS.MGT%d.STATUS.%s_PHALIGN_DONE" % (self.idx, self.txrx.name))
        pll_type = str(self.pll)
        pll_locked = self.pll.get_locked()
        refclk_freq = readReg("BEFE.MGTS.MGT%d.STATUS.REFCLK%d_FREQ" % (self.idx, self.pll.refclk01))

        return [reset_done, phalign_done, pll_type, pll_locked, refclk_freq]

def mgt_get_all(txrx):
    num_mgts = readReg("BEFE.SYSTEM.RELEASE.NUM_MGTS")
    mgts = []
    for i in range(num_mgts):
        mgt = Mgt(i, txrx)
        mgts.append(mgt)
    return mgts

def print_mgt_status_table(txrx):
    mgts = mgt_get_all(txrx)
    cols = mgts[0].get_status_labels()
    cols.insert(0, "MGT")
    rows = []
    for mgt in mgts:
        status = mgt.get_status()
        status.insert(0, "%s %d" % (txrx.name, mgt.idx))
        rows.append(status)
    print(tf.generate_table(rows, cols))

if __name__ == '__main__':
    parseXML()
    print_mgt_status_table(MgtTxRx.TX)
