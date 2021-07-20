from common.rw_reg import *
from common.utils import *
import common.tables.tableformatter as tf

try:
    imp.find_module('colorama')
    from colorama import Back
except:
    pass

def print_oh_status():
    max_ohs = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.NUM_OF_OH")
    gbts_per_oh = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.NUM_OF_GBTS_PER_OH")
    vfats_per_oh = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.NUM_VFATS_PER_OH")
    gem_station = read_reg("BEFE.GEM_AMC.GEM_SYSTEM.RELEASE.GEM_STATION")

    cols = ["OH"]
    if gem_station != 0:
        cols.append("OH FPGA fw")

    for gbt in range(gbts_per_oh):
        cols.append("GBT%d" % gbt)

    for vfat in range(vfats_per_oh):
        cols.append("VFAT%d" % vfat)

    rows = []
    for oh in range(max_ohs):
        row = [oh]

        # OH FPGA FW check
        #read_reg("BEFE.GEM_AMC.OH.OH%d.FPGA.CONTROL.HOG.GLOBAL_DATE")
        oh_fw_version = read_reg("BEFE.GEM_AMC.OH.OH%d.FPGA.CONTROL.HOG.OH_VER" % oh, False)
        row.append(color_string("NO COMMUNICATION", Colors.RED) if oh_fw_version == 0xdeaddead else str(oh_fw_version))

        for gbt in range(gbts_per_oh):
            ready = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt))
            status = ready.to_string(False)
            if ready == 1:
                status = ready.to_string(False)
                was_not_ready = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_WAS_NOT_READY" % (oh, gbt))
                had_ovf = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_RX_HAD_OVERFLOW" % (oh, gbt))
                had_unf = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_RX_HAD_UNDERFLOW" % (oh, gbt))
                fec_err_cnt = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_FEC_ERR_CNT" % (oh, gbt))
                had_header_unlock = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_RX_HEADER_HAD_UNLOCK" % (oh, gbt))
                tx_ready = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.GBT%d_TX_READY" % (oh, gbt))

                if was_not_ready == 1:
                    status += color_string(" (HAD UNLOCK)", Colors.RED)
                elif had_header_unlock == 1:
                    status += color_string(" (HAD HEADER UNLOCK)", Colors.RED)
                elif had_ovf == 1 or had_unf == 1:
                    status += color_string(" (HAD FIFO OVF/UNF)", Colors.RED)
                elif fec_err_cnt > 0:
                    status += color_string(" (FEC ERR CNT = %d)" % fec_err_cnt, Colors.YELLOW)
                elif tx_ready == 0:
                    status += color_string(" (TX NOT READY)", Colors.RED)

            row.append(status)

        for vfat in range(vfats_per_oh):
            link_good = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh, vfat))
            status = color_string("GOOD", Colors.GREEN) if link_good == 1 else color_string("LINK BAD", Colors.RED)
            if link_good == 1:
                sync_err_cnt = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh, vfat))
                daq_crc_err_cnt = read_reg("BEFE.GEM_AMC.OH_LINKS.OH%d.VFAT%d.DAQ_CRC_ERROR_CNT" % (oh, vfat))

                if sync_err_cnt > 0:
                    status = color_string("SYNC ERRORS", Colors.RED)
                elif daq_crc_err_cnt > 0:
                    status = color_string("DAQ CRC ERRORS", Colors.RED)

                cfg_run = read_reg("BEFE.GEM_AMC.OH.OH%d.GEB.VFAT%d.CFG_RUN" % (oh, vfat), False)
                if cfg_run == 0xdeaddead:
                    if "GOOD" in status:
                        status = color_string("NO COMM", Colors.RED)
                elif cfg_run == 1:
                    status += color_string(" (RUN)", colors.GREEN)
                elif cfg_run == 0:
                    status += color_string(" (SLEEP)", colors.GREEN)
                else:
                    status += color_string(" (UNKNOWN RUN MODE = %s)" % str(cfg_run), colors.RED)

            row.append(status)

        rows.append(row)

    print(tf.generate_table(rows, cols, grid_style=DEFAULT_TABLE_GRID_STYLE))
