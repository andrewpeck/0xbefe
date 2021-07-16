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
        print('Usage: parse_sca_packet_ila.py <ila_csv_dump_filename>')
        return

    f = open(sys.argv[1])

    csv_reader = csv.reader(f, delimiter=',')
    line_num = 0
    tx_data_col_num = -1
    rx_data_col_num = -1
    tx_bit_arr = []
    rx_bit_arr = []
    tx_word = 0
    rx_word = 0
    tx_sof_found = False
    tx_eof_found = False
    rx_sof_found = False
    rx_eof_found = False
    for row in csv_reader:
        if line_num == 0:
            for i in range(len(row)):
                if "tx_data" in row[i]:
                    tx_data_col_num = i
                elif "gbt_rx_data" in row[i]:
                    rx_data_col_num = i
            if tx_data_col_num < 0 or rx_data_col_num < 0:
                print("ERROR: could not find a column for tx_data or rx_data")
                return
        else:
            if row[tx_data_col_num] == "HEX": # new vivado inserts some extra line after the header.... :/
                line_num += 1
                continue

            sca_tx_bits = (int(row[tx_data_col_num], 16) >> 80) & 0x3
            sca_rx_bits = (int(row[rx_data_col_num], 16) >> 80) & 0x3

            for bit in range(1, -1, -1):
                tx_bit = (sca_tx_bits >> bit) & 0x1
                rx_bit = (sca_rx_bits >> bit) & 0x1

                if tx_sof_found and not tx_eof_found:
                    tx_bit_arr.append(tx_bit)
                if rx_sof_found and not rx_eof_found:
                    rx_bit_arr.append(rx_bit)

                tx_word = ((tx_word << 1) | tx_bit) & 0xff
                rx_word = ((rx_word << 1) | rx_bit) & 0xff

                if (tx_word == 0x7e):
                    print("line %d: TX SOF" % line_num)
                    if not tx_sof_found:
                        tx_sof_found = True
                    else:
                        tx_eof_found = True
                if (rx_word == 0x7e):
                    print("line %d: RX SOF" % line_num)
                    if not rx_sof_found:
                        rx_sof_found = True
                    else:
                        rx_eof_found = True

        line_num += 1

    f.close()

    print("")
    print("")
    print("=========== TX packet ===========")
    decodeScaPacket(tx_bit_arr)

    print("")
    print("")
    print("=========== RX packet ===========")
    decodeScaPacket(rx_bit_arr)

def decodeScaPacket(bits):
    print("Have %d slow control bits: " % len(bits))
    for bit in bits:
        sys.stdout.write("%d" % bit)
    print("")

    # decode the bit array to words, undoing the bit stuffing
    words = []
    bit_idx = 0
    num_ones = 0
    word = 0
    for bit in bits:
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
    print("")
    # for i in range(len(words)):
    #     print("%d: %s" % (i, hex_padded(words[i], 1)))
    # return

    data_length = 0
    for i in range(len(words)):
        comment = ""
        if i == 0:
            comment = "HDLC Address"
        elif i == 1:
            comment = "HDLC Control = rx_seq_num_i & \"0\" & tx_seq_num_i & \"0\""
        elif i == 2:
            comment = "Transaction ID"
        elif i == 3:
            comment = "SCA channel"
        elif i == 4:
            comment = "Length"
            data_length = words[i]
        elif i == 5:
            comment = "SCA command / error"
        elif i >= 6 and i < 6 + data_length:
            comment = "Data [%d:%d]" % ((i-6) * 8 + 7, (i-6) * 8)
        elif (i == 6 + data_length) or (i == 6 + data_length + 1):
            comment = "FCS [%d:%d]" % ((i-6-data_length) * 8 + 7, (i-6-data_length) * 8)
        elif words[i] == 0x7e:
            comment = "EOF"
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
