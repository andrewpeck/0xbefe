from common.utils import *
from csc.data_processing_utils import *
import signal
import sys
import os
import struct

def main():

    cfedFilename = ""
    dduFilename = ""

    if len(sys.argv) < 3:
        print('Usage: ddu_compare.py <csc_fed_data_file> <ddu_data_file>')
        return
    else:
        cfedFilename = sys.argv[1]
        dduFilename = sys.argv[2]

    heading('Welcome to CSC_FED - DDU raw file comparison tool')

    cfedFile = open(cfedFilename, 'r')
    dduFile = open(dduFilename, 'rb')

    numEvents = 0
    while True:
        cfedWords = cfedReadNextEvent(cfedFile)
        l1aId = (cfedWords[0] >> 32) & 0xffffff;
        sys.stdout.write("\rEvent: %i (L1A ID %d)" % (numEvents, l1aId))
        sys.stdout.flush()
        dduWords = dduReadEventRaw(dduFile, l1aId)

        # empty event in both paths (this shouldn't happen in 904 when it's self triggering, but hmm, whatever)
        if (len(cfedWords) == 8 and len(dduWords) == 6):
            print_cyan("\nEmpty event hmm\n")
            numEvents += 1
            continue

        # check event size first
        #forgive this error if CSC_FED event size is 1023, because in this particular firmware the spy fifo was only 1023 deep, so it will chop off very big events
        #also in this firmware CSC_FED is including DMB lone words (empty events), which DDU skips, so forgive that error too
        if (len(cfedWords) - 1 != len(dduWords)) and (len(cfedWords) < 1023):
            print_red("\n\nEvent length doesn't match! CSC FED has %d words and DDU has %d words\n\n" % (len(cfedWords), len(dduWords)))
            dumpEvents(cfedWords[4:-3], dduWords[3:-3])
            return

        for i in range(4, len(cfedWords) - 3):
            if (cfedWords[i] != dduWords[i - 1]):
                print_red("\n\nEvent #%d (L1A ID %d) do not match in word %d\n\n" % (numEvents, l1aId, i))
                dumpEvents(cfedWords[4:-3], dduWords[3:-3])
                return

        numEvents += 1

    # heading("CSC FED event")
    # numWords = 0
    # for w in cfedWords[4:-3]:
    #     print(hex_padded64(w))
    #     numWords += 1
    #
    # print("Num words = %d" % numWords)
    #
    # heading("DDU event")
    # numWords = 0
    # for w in dduWords[3:-3]:
    #     print(hex_padded64(w))
    #     numWords += 1
    #
    # print("Num words = %d" % numWords)

    cfedFile.close()
    dduFile.close()

def cfedReadNextEvent(file):

    line = "dummy"

    # find the beginning of event
    while ("======================== Event" not in line) and (line != ""):
        line = file.readline()

    line = "dummy"

    # read event contents
    words = []
    while True:
        line = file.readline()
        if ("========" in line) or (line == ''):
            break
        word = int(line[2:], 16)
        words.append(word)

    return words

def dumpEvents(cfedEvent, dduEvent):
    cfedLen = len(cfedEvent)
    dduLen = len(dduEvent)
    length = cfedLen
    if (dduLen > length):
        length = dduLen

    line = ""
    for i in range(0, length):
        if (i < cfedLen):
            line = hex_padded64(cfedEvent[i])
        else:
            line = "                  "

        line += "  ----  "

        if (i < dduLen):
            line += hex_padded64(dduEvent[i])

        if (i < cfedLen) and (i < dduLen) and (cfedEvent[i] != dduEvent[i]):
            print_red(line)
        else:
            print(line)

if __name__ == '__main__':
    main()
