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

def main():

    if len(sys.argv) < 1:
        print('Usage: parse_emtf_loopback_ila.py <ila_csv_dump_filename>')
        return

    f = open(sys.argv[1])

    csv_reader = csv.reader(f, delimiter=',')
    line_num = 0
    rx_data_col_num = -1
    for row in csv_reader:
        if line_num == 0:
            for i in range(len(row)):
                if "rx_data" in row[i]:
                    rx_data_col_num = i
            if rx_data_col_num < 0:
                print("ERROR: could not found a column for rx_data")
                return
        else:
            printDecodedRxData(int(row[rx_data_col_num], 16), line_num)

        line_num += 1

    f.close()

def printDecodedRxData(data, line_num):
    bc0 = data & 0x1
    mode = (data >> 1) & 0x1
    if bc0 == 1:
        printWithColor("BX %d: BC0" % line_num, Colors.MAGENTA)
    if mode == 1:
        sector = (data >> 2) & 0xf
        link = (data >> 6) & 0xf
        printWithColor("BX %d: metadata mode, sector = %d, link = %d" % (line_num, sector, link), Colors.GREEN)
    else:
        num_clusters_ly1 = (data >> 2) & 0xf
        num_clusters_ly2 = (data >> 6) & 0xf
        printWithColor("BX %d: normal mode, num clusters on layer 1: %d, layer 2: %d " % (line_num, num_clusters_ly1, num_clusters_ly2), Colors.RED)
        print("%s" % hex_padded(data, 30))
        for layer in range(2):
            for cluster in range(8):
                cluster_data = (data >> (layer * 112 + 10 + cluster * 14)) & 0x3fff
                size = (cluster_data >> 11) & 0x7
                address = cluster_data & 0x7ff
                vfat = address / 64
                pad = address % 64
                if (address > 1536):
                    print("    layer %d cluster %d: NULL (size = %d, address = %d)" % (layer, cluster, size, address))
                else:
                    printWithColor("    layer %d cluster %d: size = %d, address = %d, VFAT = %d, pad = %d" % (layer, cluster, size, address, vfat, pad), Colors.RED)


    # print("BX %d: %d" % (line_num, data))

def printWithColor(string, color):
    print color + string + Colors.ENDC

def hex_padded(number, numBytes):
    if number is None:
        return 'None'
    else:
        return "{0:#0{1}x}".format(number, int(numBytes * 2) + 2)


if __name__ == '__main__':
    main()