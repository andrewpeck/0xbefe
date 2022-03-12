import sys
from common.utils import *

def hamming_8_13(data):
    dbits = []
    for i in range(8):
        bit = (data >> i) & 1
        dbits.append(bit)

    hbits = [0, 0, 0, 0, 0]

    hbits[0] = dbits[0] ^ dbits[1] ^ dbits[2] ^ dbits[3]
    hbits[1] = dbits[0] ^ dbits[4] ^ dbits[5] ^ dbits[6]
    hbits[2] = dbits[1] ^ dbits[2] ^ dbits[4] ^ dbits[5] ^ dbits[7]
    hbits[3] = dbits[1] ^ dbits[3] ^ dbits[4] ^ dbits[6] ^ dbits[7]
    hbits[4] = hbits[0] ^ hbits[1] ^ hbits[2] ^ hbits[3] ^ dbits[0] ^ dbits[1] ^ dbits[2] ^ dbits[3] ^ dbits[4] ^ dbits[5] ^ dbits[6] ^ dbits[7]

    hamming = (hbits[4] << 4) | (hbits[3] << 3) | (hbits[2] << 2) | (hbits[1] << 1) | (hbits[0] << 0)

    return hamming

def main(cmd):
    print("Command: %s" % hex_padded(cmd, 1))
    hamming = hamming_8_13(cmd)

    # frame = (0 << 15)      | '''START''' \
    #         (0 << 14)      | '''FMT (Broadcast)''' \
    #         (cmd << 6)     | '''data''' \
    #         (hamming << 1) | '''hamming code''' \
    #         1                '''STOP'''

    frame = (0 << 15) | (0 << 14) | (cmd << 6) | (hamming << 1) | 1

    print("Encoded B channel data: %s" % hex_padded(frame, 2))

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: ttc_tx.py <broadcast_command_data>")
        exit(0)

    cmd = parse_int(sys.argv[1])
    main(cmd)
