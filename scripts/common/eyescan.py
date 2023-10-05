from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from boards.cvp13.cvp13_utils import *

#based on https://support.xilinx.com/s/article/66517?language=en_US

EYESCAN_DRP_REGS = {"ES_HORZ_OFFSET": {addr: 0x4f, mask: 0xfff0},
                    "USE_PCS_CLK_PHASE_SEL": {addr: 0x94, mask: 0x0400},
                    "ES_CONTROL": {addr: 0x3c, mask: 0xfc00},
                    "ES_PRESCALE": {addr: 0x3c, mask: 0x001f},
                    "ES_EYE_SCAN_EN": {addr: 0x3c, mask: 0x100},
                    "ES_ERRDET_EN": {addr: 0x3c, mask: 0x200},
                    "ES_QUAL_MASK0": {addr: 0x44, mask: 0xffff},
                    "ES_QUAL_MASK1": {addr: 0x45, mask: 0xffff},
                    "ES_QUAL_MASK2": {addr: 0x46, mask: 0xffff},
                    "ES_QUAL_MASK3": {addr: 0x47, mask: 0xffff},
                    "ES_QUAL_MASK4": {addr: 0x48, mask: 0xffff},
                    "ES_QUAL_MASK5": {addr: 0xec, mask: 0xffff},
                    "ES_QUAL_MASK6": {addr: 0xed, mask: 0xffff},
                    "ES_QUAL_MASK7": {addr: 0xee, mask: 0xffff},
                    "ES_QUAL_MASK8": {addr: 0xef, mask: 0xffff},
                    "ES_QUAL_MASK9": {addr: 0xf0, mask: 0xffff},
                    "ES_SDATA_MASK0": {addr: 0x49, mask: 0xffff},
                    "ES_SDATA_MASK1": {addr: 0x4a, mask: 0xffff},
                    "ES_SDATA_MASK2": {addr: 0x4b, mask: 0xffff},
                    "ES_SDATA_MASK3": {addr: 0x4c, mask: 0xffff},
                    "ES_SDATA_MASK4": {addr: 0x4d, mask: 0xffff},
                    "ES_SDATA_MASK5": {addr: 0xf1, mask: 0xffff},
                    "ES_SDATA_MASK6": {addr: 0xf2, mask: 0xffff},
                    "ES_SDATA_MASK7": {addr: 0xf3, mask: 0xffff},
                    "ES_SDATA_MASK8": {addr: 0xf4, mask: 0xffff},
                    "ES_SDATA_MASK9": {addr: 0xf5, mask: 0xffff},
                    "RX_EYESCAN_VS_NEG_DIR": {addr: 0x97, mask: 0x400},
                    "RX_EYESCAN_VS_UT_SIGN": {addr: 0x97, mask: 0x200},
                    "RX_EYESCAN_VS_CODE": {addr: 0x97, mask: 0x1fc},
                    "RX_EYESCAN_VS_RANGE": {addr: 0x97, mask: 0x3},
                    "ES_CONTROL_STATUS": {addr: 0x253, mask: 0xf},
                    "ES_ERROR_COUNT": {addr: 0x251, mask: 0xffff},
                    "ES_SAMPLE_COUNT": {addr: 0x252, mask: 0xffff}
                    }

def eyescan_read_reg(mgt, reg_name, value):
    reg = EYESCAN_DRP_REGS[reg_name]
    val = mgt.drp_read(reg["addr"])
    mask = reg["mask"]
    val = (val & mask) >> find_first_set_bit_pos(mask)

    return val

def eyescan_write_reg(mgt, reg_name, value):
    reg = EYESCAN_DRP_REGS[reg_name]
    addr = reg["addr"]
    val = mgt.drp_read(addr)
    mask = reg["mask"]
    first_bit_pos = find_first_set_bit_pos(mask)
    val = (val & ~mask) | ((value << first_bit_pos) & mask)
    mgt.drp_write(addr, val)

def eyescan_setup(links):
    for link in links:
        mgt = link.rx_mgt

        is_above_10g = mgt.type in ["MGT_LPGBT", "MGT_ODMB57", "MGT_ODMB57_BIDIR", "MGT_10GBE", "MGT_TX_GBE_RX_LPGBT", "MGT_TX_10GBE_RX_LPGBT", "MGT_25GBE"]

        if is_above_10g:
            print("link is faster than 10G")
            eyescan_write_reg("USE_PCS_CLK_PHASE_SEL", 0)
        else:
            print("link is slower than 10G")
            eyescan_write_reg("USE_PCS_CLK_PHASE_SEL", 1)

        # realign
        eyescan_write_reg("ES_HORZ_OFFSET", 0x880)
        mgt.set_eyescan_reset(1)
        eyescan_write_reg("ES_HORZ_OFFSET", 0x800)
        mgt.set_eyescan_reset(0)

        if not is_above_10g:
            eyescan_write_reg("ES_HORZ_OFFSET", 0x0)

        eyescan_write_reg("ES_CONTROL", 0)
        eyescan_write_reg("ES_EYE_SCAN_EN", 1)
        eyescan_write_reg("ES_ERRDET_EN", 1)

        #Step 3: Reset the GT. The reset is not necessary if ES_EYE_SCAN_EN = 1b1 is set in HDL.
        #TODO: try setting the ES_EYE_SCAN_EN to true in HDL
        mgt.reset()


if __name__ == '__main__':
    parse_xml()
    links = befe_get_all_links()
