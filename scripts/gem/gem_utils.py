from common.rw_reg import *
from common.utils import *
import tableformatter as tf
import sys

try:
    imp.find_module('colorama')
    from colorama import Back
except:
    print("Note: if you install python36-colorama package, the table row background will be colored in an alternating way, making them more readable")

def gem_print_status():
    max_ohs = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.NUM_OF_OH")
    gbts_per_oh = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.NUM_OF_GBTS_PER_OH")
    vfats_per_oh = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.NUM_VFATS_PER_OH")
    gem_station = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.GEM_STATION")

    cols = ["OH"]
    if gem_station != 0:
        cols.append("OH FPGA fw version")

    cols.append("GBTs %d-%d" % (0, gbts_per_oh))

    if gem_station in [1, 2]:
        cols.append("SCA")

    num_vfats_per_col = 4
    for vfat in range(0, vfats_per_oh, num_vfats_per_col):
        cols.append("VFATs %d-%d" % (vfat, vfat + num_vfats_per_col - 1))

    rows = []
    for oh in range(max_ohs):
        row = [oh]

        ### OH FPGA FW ###
        if gem_station != 0:
            #read_reg("BEFE.GEM_AMC.OH.OH%d.FPGA.CONTROL.HOG.GLOBAL_DATE")
            oh_fw_version = read_reg("BEFE.GEM_AMC.OH.OH%d.FPGA.CONTROL.HOG.OH_VER" % oh, False)
            row.append(color_string("NO COMMUNICATION", Colors.RED) if oh_fw_version == 0xdeaddead else str(oh_fw_version))

        ### GBTs ###
        status_block = ""
        first = True
        for gbt in range(gbts_per_oh):
            ready = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt))
            status = "%d: " % gbt + ready.to_string()
            if ready == 1:
                was_not_ready = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_WAS_NOT_READY" % (oh, gbt))
                had_ovf = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_RX_HAD_OVERFLOW" % (oh, gbt))
                had_unf = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_RX_HAD_UNDERFLOW" % (oh, gbt))
                fec_err_cnt = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_FEC_ERR_CNT" % (oh, gbt))
                had_header_unlock = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_RX_HEADER_HAD_UNLOCK" % (oh, gbt))
                tx_ready = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_TX_READY" % (oh, gbt)) if gem_station != 0 or gbt % 2 == 0 else 1 # Odd GBT TX numbers are not used on ME0

                if was_not_ready == 1:
                    status += "\n" + color_string("(HAD UNLOCK)", Colors.RED)
                elif had_header_unlock == 1:
                    status += "\n" + color_string("(HAD HEADER UNLOCK)", Colors.RED)
                elif had_ovf == 1 or had_unf == 1:
                    status += "\n" + color_string("(HAD FIFO OVF/UNF)", Colors.RED)
                elif fec_err_cnt > 0:
                    status += "\n" + color_string("(FEC ERR CNT = %d)" % fec_err_cnt, Colors.YELLOW)
                elif tx_ready == 0:
                    status += "\n" + color_string("(TX NOT READY)", Colors.RED)

            status_block = status if first else status_block + "\n" + status
            first = False

        row.append(status_block)

        ### SCA ###
        if gem_station in [1, 2]:
            sca_ready = (read_reg("BEFE.GEM_AMC.SLOW_CONTROL.SCA.STATUS.READY") >> oh) & 1
            not_ready_cnt = read_reg("BEFE.GEM_AMC.SLOW_CONTROL.SCA.STATUS.NOT_READY_CNT_OH%d" % oh)
            sca_status = color_string("READY", Colors.GREEN) if sca_ready == 1 else color_string("NOT_READY", Colors.RED)
            if sca_ready == 1 and not_ready_cnt > 2:
                sca_status += "\n" + color_string("(HAD UNLOCKS)", Colors.YELLOW)

            row.append(sca_status)

        ### VFATs ###
        for vfat_block in range(0, vfats_per_oh, num_vfats_per_col):
            vfat_block_status = ""
            first = True
            for vfat in range(vfat_block, vfat_block + num_vfats_per_col):
                link_good = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh, vfat))
                status = "%d: " % vfat + color_string("GOOD", Colors.GREEN) if link_good == 1 else "%d: " % vfat + color_string("LINK BAD", Colors.RED)
                if link_good == 1:
                    sync_err_cnt = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh, vfat))
                    daq_crc_err_cnt = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.DAQ_CRC_ERROR_CNT" % (oh, vfat))

                    if sync_err_cnt > 0:
                        status = "%d: " % vfat + color_string("SYNC ERRORS", Colors.RED)
                    elif daq_crc_err_cnt > 0:
                        status = "%d: " % vfat + color_string("DAQ CRC ERRORS", Colors.YELLOW)

                    cfg_run = read_reg("BEFE.GEM_AMC.OH.OH%d.GEB.VFAT%d.CFG_RUN" % (oh, vfat), False)
                    if cfg_run == 0xdeaddead:
                        if "GOOD" in status:
                            status = "%d: " % vfat + color_string("NO COMM", Colors.RED)
                    elif cfg_run == 1:
                        status += color_string(" (RUN)", Colors.GREEN)
                    elif cfg_run == 0:
                        status += color_string(" (SLEEP)", Colors.GREEN)
                    else:
                        status += color_string(" (UNKNOWN RUN MODE = %s)" % str(cfg_run), colors.RED)

                vfat_block_status = status if first else vfat_block_status + "\n" + status
                first = False

            row.append(vfat_block_status)

        rows.append(row)

    print(tf.generate_table(rows, cols, grid_style=FULL_TABLE_GRID_STYLE))

def gem_hard_reset():
    ttc_gen_en = read_reg("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE")
    write_reg("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE", 1)
    write_reg("BEFE.GEM_AMC.SLOW_CONTROL.SCA.CTRL.TTC_HARD_RESET_EN", 0xffffffff)
    write_reg("BEFE.GEM_AMC.TTC.GENERATOR.SINGLE_HARD_RESET", 1)
    if ttc_gen_en != 1:
        write_reg("BEFE.GEM_AMC.TTC.GENERATOR.ENABLE", ttc_gen_en)

def gem_link_reset():
    write_reg("BEFE.GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET", 1)

if __name__ == '__main__':
    if len(sys.argv) > 1:
        parse_xml()
        if sys.argv[1] == "status":
            gem_print_status()
        elif sys.argv[1] == "hard-reset":
            gem_hard_reset()
    else:
        print("gem_utils.py <command>")
        print("commands:")
        print("   * status: prints the GEM frontend status")
        print("   * hard-reset: sends a TTC hard reset")
