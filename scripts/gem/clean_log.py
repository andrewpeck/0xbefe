import sys
import re
import argparse
from gem.me0_lpgbt.rw_reg_lpgbt import *

ansi_escape = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OptoHybrid Production Tests")
    parser.add_argument("-i", "--input_file", action="store", dest="input_file", help="INPUT_FILE = path to log file with dirty (escape characters) output")
    args = parser.parse_args()

    if args.input_file is None:
        print(Colors.YELLOW + "Need Input File" + Colors.ENDC)
        sys.exit()

    filename = args.input_file
    with open(filename, encoding="utf8") as logfile:
        data = logfile.read()
        data = ansi_escape.sub("",data)

    with open(filename, "w", encoding="utf8") as logfile:
        logfile.write(data)
