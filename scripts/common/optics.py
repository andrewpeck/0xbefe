from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from boards.cvp13.cvp13_utils import *

OPTICS_BOARD_TYPE = None
CVP13_BWTK_PATH = None

def init_optics_vars():
    info = befe_get_fw_info()
    global OPTICS_BOARD_TYPE
    OPTICS_BOARD_TYPE = info["board_type"]
    if OPTICS_BOARD_TYPE == "CVP13":
        bwtk_path = cvp13_get_bwtk_path()
        if bwtk_path is None:
            print_red("Bittware Toolkit Lite is not installed")
        global CVP13_BWTK_PATH
        CVP13_BWTK_PATH = bwtk_path
    else:
        print_red("Board type %s is not yet supported" % info["board_type"])

def read_rx_power(channel):
    if OPTICS_BOARD_TYPE is None:
        init_optics_vars()

    if OPTICS_BOARD_TYPE == "CVP13":
        return cvp13_read_qsfp_rx_power(CVP13_BWTK_PATH, channel)
    else:
        return None

def read_rx_power_from_gbt(oh, gbt):
    # get the optical channel for this OH and GBT
    chan = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.OH_LINK_CONFIG.OH%d.GBT%d_RX" % (oh, gbt))
    return read_rx_power(chan)

def read_rx_power_all():
    if OPTICS_BOARD_TYPE is None:
        init_optics_vars()

    if OPTICS_BOARD_TYPE == "CVP13":
        return cvp13_read_qsfp_rx_power_all(CVP13_BWTK_PATH)
    else:
        return None

if __name__ == '__main__':
    parse_xml()
    ret = read_rx_power_all()
