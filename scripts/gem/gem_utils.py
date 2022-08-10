from common.rw_reg import *
from common.utils import *
import tableformatter as tf
import sys
from time import sleep

try:
    imp.find_module('colorama')
    from colorama import Back
except:
    print("Note: if you install python36-colorama package, the table row background will be colored in an alternating way, making them more readable")

# For ME0
ME0_VFAT_TO_GBT_ELINK_GPIO = {
        17 : ("sub"  , 1, 6,  10),
        16 : ("sub"  , 1, 24, 9),
        9  : ("sub"  , 1, 11, 11),
        8  : ("boss" , 0, 3,  0),
        1  : ("boss" , 0, 27, 2),
        0  : ("boss" , 0, 25, 8),

        19 : ("sub"  , 3, 6,  10),
        18 : ("sub"  , 3, 24, 9),
        11 : ("sub"  , 3, 11, 11),
        10 : ("boss" , 2, 3,  0),
        3  : ("boss" , 2, 27, 2),
        2  : ("boss" , 2, 25, 8),

        21 : ("sub"  , 5, 6,  10),
        20 : ("sub"  , 5, 24, 9),
        13 : ("sub"  , 5, 11, 11),
        4  : ("boss" , 4, 3,  0),
        5  : ("boss" , 4, 27, 2),
        12 : ("boss" , 4, 25, 8),

        23 : ("sub"  , 7, 6,  10),
        22 : ("sub"  , 7, 24, 9),
        15 : ("sub"  , 7, 11, 11),
        6  : ("boss" , 6, 3,  0),
        7  : ("boss" , 6, 27, 2),
        14 : ("boss" , 6, 25, 8),
}

ME0_VFAT_TO_SBIT_ELINK = {
    17 : [3, 13, 5, 1, 0, 2, 12, 4],
    16 : [18, 21, 20, 23, 22, 27, 26, 25],
    9  : [17, 19, 14, 7, 9, 10, 15, 8],
    8  : [6, 7, 9, 4, 5, 2, 0, 1],
    1  : [15, 14, 12, 10, 11, 13, 19, 17],
    0  : [16, 18, 20, 22, 24, 26, 21, 23],

    19 : [3, 13, 5, 1, 0, 2, 12, 4],
    18 : [18, 21, 20, 23, 22, 27, 26, 25],
    11 : [17, 19, 14, 7, 9, 10, 15, 8],
    10 : [6, 7, 9, 4, 5, 2, 0, 1],
    3  : [15, 14, 12, 10, 11, 13, 19, 17],
    2  : [16, 18, 20, 22, 24, 26, 21, 23],

    21 : [3, 13, 5, 1, 0, 2, 12, 4],
    20 : [18, 21, 20, 23, 22, 27, 26, 25],
    13 : [17, 19, 14, 7, 9, 10, 15, 8],
    4  : [6, 7, 9, 4, 5, 2, 0, 1],
    5  : [15, 14, 12, 10, 11, 13, 19, 17],
    12 : [16, 18, 20, 22, 24, 26, 21, 23],

    23 : [3, 13, 5, 1, 0, 2, 12, 4],
    22 : [18, 21, 20, 23, 22, 27, 26, 25],
    15 : [17, 19, 14, 7, 9, 10, 15, 8],
    6  : [6, 7, 9, 4, 5, 2, 0, 1],
    7  : [15, 14, 12, 10, 11, 13, 19, 17],
    14 : [16, 18, 20, 22, 24, 26, 21, 23],
}

hdlc_address_map = None
system = ""

# Registers for read/write tests
vfat_registers = {
        "HW_ID": "r",
        "HW_ID_VER": "r",
        "TEST_REG": "rw",
        "HW_CHIP_ID": "r"
}

def gem_print_status():
    max_ohs = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_OF_OH")
    gbts_per_oh = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_OF_GBTS_PER_OH")
    vfats_per_oh = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_VFATS_PER_OH")
    gem_station = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.GEM_STATION")

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
            #read_reg("BEFE.GEM.OH.OH%d.FPGA.CONTROL.HOG.GLOBAL_DATE")
            oh_fw_version = read_reg("BEFE.GEM.OH.OH%d.FPGA.CONTROL.HOG.OH_VER" % oh, False)
            row.append(color_string("NO COMMUNICATION", Colors.RED) if oh_fw_version == 0xdeaddead else str(oh_fw_version))

        ### GBTs ###
        status_block = ""
        first = True
        for gbt in range(gbts_per_oh):
            ready = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt))
            status = "%d: " % gbt + ready.to_string()
            if ready == 1:
                was_not_ready = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_WAS_NOT_READY" % (oh, gbt))
                had_ovf = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_RX_HAD_OVERFLOW" % (oh, gbt))
                had_unf = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_RX_HAD_UNDERFLOW" % (oh, gbt))
                fec_err_cnt = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_FEC_ERR_CNT" % (oh, gbt))
                had_header_unlock = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_RX_HEADER_HAD_UNLOCK" % (oh, gbt))
                tx_ready = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_TX_READY" % (oh, gbt)) if gem_station != 0 or gbt % 2 == 0 else 1 # Odd GBT TX numbers are not used on ME0

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
            sca_ready = (read_reg("BEFE.GEM.SLOW_CONTROL.SCA.STATUS.READY") >> oh) & 1
            not_ready_cnt = read_reg("BEFE.GEM.SLOW_CONTROL.SCA.STATUS.NOT_READY_CNT_OH%d" % oh)
            sca_status = color_string("READY", Colors.GREEN) if sca_ready == 1 else color_string("NOT_READY", Colors.RED)
            if sca_ready == 1 and not_ready_cnt > 2:
                sca_status += "\n" + color_string("(HAD UNLOCKS)", Colors.YELLOW)

            row.append(sca_status)

        ### VFATs ###
        for vfat_block in range(0, vfats_per_oh, num_vfats_per_col):
            vfat_block_status = ""
            first = True
            for vfat in range(vfat_block, vfat_block + num_vfats_per_col):
                link_good = read_reg("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh, vfat))
                status = "%d: " % vfat + color_string("GOOD", Colors.GREEN) if link_good == 1 else "%d: " % vfat + color_string("LINK BAD", Colors.RED)
                if link_good == 1:
                    sync_err_cnt = read_reg("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh, vfat))
                    daq_crc_err_cnt = read_reg("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.DAQ_CRC_ERROR_CNT" % (oh, vfat))

                    if sync_err_cnt > 0:
                        status = "%d: " % vfat + color_string("SYNC ERRORS", Colors.RED)
                    elif daq_crc_err_cnt > 0:
                        status = "%d: " % vfat + color_string("DAQ CRC ERRORS", Colors.YELLOW)

                    cfg_run = read_reg("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN" % (oh, vfat), False)
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
    ttc_gen_en = read_reg("BEFE.GEM.TTC.GENERATOR.ENABLE")
    write_reg("BEFE.GEM.TTC.GENERATOR.ENABLE", 1)
    write_reg("BEFE.GEM.SLOW_CONTROL.SCA.CTRL.TTC_HARD_RESET_EN", 0xffffffff)
    write_reg("BEFE.GEM.TTC.GENERATOR.SINGLE_HARD_RESET", 1)
    if ttc_gen_en != 1:
        write_reg("BEFE.GEM.TTC.GENERATOR.ENABLE", ttc_gen_en)

def gem_link_reset():
    write_reg("BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET", 1)

def initialize(station, system_val):
    parse_xml()
    global system
    system = system_val
    
    global hdlc_address_map

    if station == "ME0":
        hdlc_address_map = get_config("CONFIG_ME0_VFAT_HDLC_ADDRESSES")
    elif station == "GE21":
        hdlc_address_map = get_config("CONFIG_GE21_VFAT_HDLC_ADDRESSES")
    elif station == "GE11":
        hdlc_address_map = get_config("CONFIG_GE11_VFAT_HDLC_ADDRESSES")

def terminate():
    write_reg(get_node("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE"), 0)
    sys.exit()   

def check_gbt_link_ready(ohIdx, gbtIdx):
    if system == "backend":
        link_ready = read_backend_reg(get_backend_node("BEFE.GEM.OH_LINKS.OH%s.GBT%s_READY" % (ohIdx, gbtIdx)))
        if (link_ready!=1):
            print (Colors.RED + "ERROR: OH lpGBT links are not READY, check fiber connections" + Colors.ENDC)  
            terminate()

def me0_vfat_to_gbt_elink_gpio(vfat):
    gbt = ME0_VFAT_TO_GBT_ELINK_GPIO[vfat][0]
    gbtid = ME0_VFAT_TO_GBT_ELINK_GPIO[vfat][1]
    elink = ME0_VFAT_TO_GBT_ELINK_GPIO[vfat][2]
    gpio = ME0_VFAT_TO_GBT_ELINK_GPIO[vfat][3]
    return gbt, gbtid, elink, gpio

def me0_vfat_to_sbit_elink(vfat):
    sbit_elinks = ME0_VFAT_TO_SBIT_ELINK[vfat]
    return sbit_elinks

def enable_hdlc_addressing(addr_list):
    for vfat in addr_list:
        reg_name = "BEFE.GEM.GEM_SYSTEM.VFAT3.VFAT%d_HDLC_ADDRESS"%(vfat)
        address = hdlc_address_map[vfat]
        write_backend_reg(get_backend_node(reg_name), address)

def global_reset():
    write_backend_reg(get_backend_node("BEFE.GEM.GEM_SYSTEM.CTRL.GLOBAL_RESET"), 0x1)
    sleep(0.1)
    gem_link_reset()
    sleep(0.1)

def get_backend_node(name):
    node = None
    if system == "backend":
        node = get_node(name)
        if node is None:
            print (Colors.RED + "ERROR: Invalid register: %s"%name + Colors.ENDC)
            terminate()
    return node

def read_backend_reg(node, terminate = True):
    output = 0
    if system == "backend":
        output = read_reg(node)
        if output==0xdeaddead:
            if terminate:
                terminate()
    return output
    
def write_backend_reg(node, data, terminate = True):
    output = 0
    if system == "backend":
        output = write_reg(node, data)
        if output==-1:
            if terminate:
                terminate()
    return output

if __name__ == '__main__':
    if len(sys.argv) > 1:
        initialize(sys.argv[1])
        if sys.argv[2] == "status":
            gem_print_status()
        elif sys.argv[2] == "hard-reset":
            gem_hard_reset()
    else:
        print("gem_utils.py <station> <command>")
        print("station:")
        print("   * ME0")
        print("   * GE21")
        print("   * GE11")
        print("commands:")
        print("   * status: prints the GEM frontend status")
        print("   * hard-reset: sends a TTC hard reset")
