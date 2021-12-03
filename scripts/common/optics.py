from common.rw_reg import *
from common.utils import *
from common.fw_utils import *


if __name__ == '__main__':
    parse_xml()
    info = befe_get_fw_info()
    if info["board_type"] == "CVP13":
        from boards.cvp13.cvp13_utils import *
        bwtk_path = cvp13_get_bwtk_path()
        if bwtk_path is None:
            print_red("Bittware Toolkit Lite is not installed")
            exit(-1)
        print("Using Bittware Toolkit Lite in this path: %s" % bwtk_path)

        cvp13_read_qsfp_rx_power(bwtk_path)

    else:
        print_red("Board type %s is not yet supported" % info["board_type"])
        exit(-1)
