from common.rw_reg import *
from common.utils import *
import tableformatter as tf
import sys

def csc_print_status():
    print_red("CSC print status is not implemented yet")

def csc_hard_reset():
    ttc_gen_en = read_reg("BEFE.CSC_FED.TTC.GENERATOR.ENABLE")
    write_reg("BEFE.CSC_FED.TTC.GENERATOR.ENABLE", 1)
    write_reg("BEFE.CSC_FED.TTC.GENERATOR.SINGLE_HARD_RESET", 1)
    if ttc_gen_en != 1:
        write_reg("BEFE.CSC_FED.TTC.GENERATOR.ENABLE", ttc_gen_en)

if __name__ == '__main__':
    if len(sys.argv) > 1:
        parse_xml()
        if sys.argv[1] == "status":
            csc_print_status()
        elif sys.argv[1] == "hard-reset":
            csc_hard_reset()
    else:
        print("csc_utils.py <command>")
        print("commands:")
        print("   * status: prints the CSC frontend status")
        print("   * hard-reset: sends a TTC hard reset")
