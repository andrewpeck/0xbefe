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

LATENCY = 7
# LATENCY = 5

def main():

    if len(sys.argv) < 1:
        print('Usage: parse_emtf_loopback_ila.py <ila_csv_dump_filename>')
        return

    f = open(sys.argv[1])

    frames = []
    words = []

    csv_reader = csv.reader(f, delimiter=',')
    line_num = 0
    frame_col_num = -1
    word_col_num = -1
    first_frame = -1
    frame_repeat_cycle = -1
    for row in csv_reader:
        if line_num == 0:
            for i in range(len(row)):
                if "tx_dp_frame" in row[i]:
                    frame_col_num = i
                elif "tx_gb_out_data" in row[i]:
                    word_col_num = i
            if frame_col_num < 0:
                print("ERROR: could not found a column for frame")
                return
            if word_col_num < 0:
                print("ERROR: could not found a column for word")
                return
        elif line_num > 1:
            frame = reverse_bits(int(row[frame_col_num], 16))
            if first_frame == -1:
                first_frame = frame
            elif frame_repeat_cycle == -1:
                if frame != first_frame:
                    frame_repeat_cycle = 0

            if frame_repeat_cycle != -1:
                if frame_repeat_cycle == 0:
                    frames.append(frame)
                elif frame != frames[-1]:
                    print("ERROR: frame not stable")
                    return

                if frame_repeat_cycle < 3:
                    frame_repeat_cycle += 1
                else:
                    frame_repeat_cycle = 0

                words.append(int(row[word_col_num], 16))

        line_num += 1

    f.close()

    for frame_idx in range(len(frames)):
        frame = frames[frame_idx]
        # print(hex_padded(frame, 32))

        for i in range(4):
            frame_word = (frame >> (i * 64)) & 0xffffffffffffffff
            word_idx = (frame_idx * 4) + i + LATENCY
            if word_idx >= len(words):
                break

            ila_word = words[word_idx]
            if frame_word != ila_word:
                print("ERROR: mismatch, expected %s from the frame data, but saw %s on the ILA word data" % (hex_padded(frame_word, 8), hex_padded(ila_word, 8)))
                return
            else:
                print("Match!")


def reverse_bits(frame):
    ret = 0
    for i in range(256):
        bit = (frame >> i) & 1
        ret += bit << (255 - i)
    return ret

def hex_padded(number, numBytes):
    if number is None:
        return 'None'
    else:
        return "{0:#0{1}x}".format(number, int(numBytes * 2) + 2)


if __name__ == '__main__':
    main()
