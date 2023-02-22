import sys
import csv

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

VFAT_SC0_WORD = 0x96
VFAT_SC1_WORD = 0x99

def main():

    if len(sys.argv) < 1:
        print('Usage: parse_vfat_sc_ila.py <ila_csv_dump_filename>')
        return

    f = open(sys.argv[1])

    csv_reader = csv.reader(f, delimiter=',')
    line_num = 0
    tx_data_col_num = -1
    sc_bit_arr = []
    for row in csv_reader:
        if line_num == 0:
            for i in range(len(row)):
                if "tx_data" in row[i]:
                    tx_data_col_num = i
            if tx_data_col_num < 0:
                print("ERROR: could not find a column for tx_data")
                return
        else:
            if row[tx_data_col_num] == "HEX": # new vivado inserts some extra line after the header.... :/
                line_num += 1
                continue
            word = int(row[tx_data_col_num], 16)
            if word == VFAT_SC0_WORD:
                sc_bit_arr.append(0)
            elif word == VFAT_SC1_WORD:
                sc_bit_arr.append(1)

        line_num += 1

    f.close()

    print("Found %d slow control bits: " % len(sc_bit_arr))
    for bit in sc_bit_arr:
        sys.stdout.write("%d" % bit)
    print("")

    # search for the SOF
    start_idx = 0
    end_idx = 0
    word = 0
    sof_found = False
    eof_found = False
    for i in range(len(sc_bit_arr)):
        word = (word << 1) + sc_bit_arr[i]
        if (word & 0xff) == 0x7e:
            if not sof_found: # Start of frame
                sof_found = True
                start_idx = i + 1
            else: # End of frame
                eof_found = True
                end_idx = i - 8
                break

    if not sof_found:
        print("SOF not found... exit.")
        return

    if not eof_found:
        print("EOF not found... exit.")
        return

    # decode the bit array to words, undoing the bit stuffing
    words = []
    bit_idx = 0
    num_ones = 0
    word = 0
    for bit in sc_bit_arr[start_idx:end_idx+1]:
        if num_ones == 5: # remove stuffed bits
            num_ones = 0
            continue

        if bit == 1:
            num_ones += 1
        else:
            num_ones = 0

        word = word | (bit << bit_idx)
        bit_idx += 1

        if bit_idx == 8:
            words.append(word)
            bit_idx = 0
            word = 0

    print("got %d words, and the bit_idx after parsing the message = %d (should be = 0)" % (len(words), bit_idx))
    is_read = False
    for i in range(len(words)):
        comment = ""
        if i == 0:
            comment = "HDLC Address"
        elif i == 1:
            comment = "HDLC Control, should be = 0x03"
        elif i == 2:
            comment = "000 + is_write_i + 0xf"
            if ((words[i] >> 4) & 0x1) == 0:
                is_read = True
        elif i == 3:
            comment = "Transaction ID"
        elif i == 4:
            comment = "Num regs"
        elif i == 5:
            comment = "IPBus version & 0x0, should be = 0x20"
        elif i >= 6 and i <= 9:
            addr_word_idx = (i - 6)
            comment = "Reg address [%d:%d]" % (addr_word_idx * 8 + 7, addr_word_idx * 8)
        elif not is_read and i >= 10 and i <= 13:
            val_word_idx = (i - 6)
            comment = "Reg write value [%d:%d]" % (val_word_idx * 8 + 7, val_word_idx * 8)
        elif (is_read and i >= 10 and i <= 11) or (not is_read and i >= 14 and i <= 15):
            comment = "CRC"
        else:
            comment = "????????????????????????????"

        print("%s   <<<< %s" % (hex_padded(words[i], 1), comment))


def printWithColor(string, color):
    print color + string + Colors.ENDC

def hex_padded(number, numBytes):
    if number is None:
        return 'None'
    else:
        return "{0:#0{1}x}".format(number, int(numBytes * 2) + 2)


if __name__ == '__main__':
    main()
