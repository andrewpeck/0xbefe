import sys
import csv
from common.utils import *
import struct

MAX_FW_SIZE = 16000000

def main():

    if len(sys.argv) < 3:
        print('Usage: parse_promless_ila.py <ila_csv_dump_filename> <oh_fw_bitfile_to_compare_to>')
        return

    f = open(sys.argv[1])

    csv_reader = csv.reader(f, delimiter=',')
    line_num = 0

    valid_col_num = -1
    data_col_num = -1

    bytes = []

    for row in csv_reader:
        if line_num == 0:
            for i in range(len(row)):
                if "from_gem_loader_i[valid]" in row[i]:
                    valid_col_num = i
                if "from_gem_loader_i[data]" in row[i]:
                    data_col_num = i
            if valid_col_num < 0 or data_col_num < 0:
                print("ERROR: could not find a column for data or valid")
                return
        else:
            if row[data_col_num] == "HEX": # new vivado inserts some extra line after the header.... :/
                line_num += 1
                continue
            if int(row[valid_col_num]) == 1:
                bytes.append(int(row[data_col_num], 16))

        line_num += 1

    f.close()

    print("Found %d promless bytes in the ILA: " % len(bytes))

    f = open(sys.argv[2], "rb")

    dataStr = f.read(MAX_FW_SIZE)
    bitfileBytes = struct.unpack("%dB" % len(dataStr), dataStr)

    f.close()

    numErrors = 0
    for bidx in range(len(bytes)):
        if bitfileBytes[bidx] != bytes[bidx]:
            # print(hex_padded(bytes[bidx], 1))
            print("ERROR: mismatch at index %d, expected %s (from the bitfile), but found %s in the ILA" % (bidx, hex_padded(bitfileBytes[bidx], 1), hex_padded(bytes[bidx], 1)))
            numErrors += 1
            # return

    print("Total number of errors: %d" % numErrors)

if __name__ == '__main__':
    main()
