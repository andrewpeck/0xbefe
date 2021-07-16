from common.utils import *
from csc.data_processing_utils import *
import signal
import sys
import os
import struct
import numpy as np
from time import *

#IGNORE_DMBS = [[1, 1], [12, 1]]  # these DMBs will get ignored
IGNORE_DMBS = [[0, 0]]  # dummy DMB ignore list
REMOVE_EMPTY_EVENTS = False

def main():

    ldaqFilename = ""
    maxFiles = None

    if len(sys.argv) < 2:
        print('Usage: local_daq_analyze.py <local_daq_data_file_pattern> [max_num_files_match]')
        print('file patterns can be exact filenames or have a * indicating a wildcard, but only for the part number (last number in the local daq filename)')
        print('if a wildcard is used, you can optionally provide a max number of files to match to (default is no limit)')
        return
    else:
        ldaqFilename = sys.argv[1]

    if len(sys.argv) > 2:
        maxFiles = int(sys.argv[2])

    heading('Welcome to Local DAQ raw file analyzer')

    files = getAllLocalDaqRawFiles(ldaqFilename, maxFiles)

    events = []
    fileIdx = -1
    evtNum = 0
    idx = -1

    # error log
    errors = []

    # size stats
    totalWords = 0
    minWords = 99999
    maxWords = 0
    maxWordsEvtNum = 0
    totalDmbWords = {} # dictionary of total words per DMB, where key is "crateID, DMBID", and value is an array holding the total word count, number of blocks, min word count, and max word count

    while True:
        evtNum += 1
        idx += 1

        # read the next file if we got to the end, and exit the loop if we got to the last file already
        if idx >= len(events):
            fileIdx += 1
            if fileIdx >= len(files):
                print("DONE")
                break
            del events[:]
            events = unpackFile(files[fileIdx], REMOVE_EMPTY_EVENTS, IGNORE_DMBS)
            idx1 = 0

        if (evtNum % 1000 == 0):
            print("Checking event %d" % evtNum)

        evt = events[idx]

        # error checking
        err = checkEventErrors(evt)
        if len(err) > 0:
            errors.append(["Global event #%d (file %d, local event #%d)" % (evtNum, fileIdx, idx)] + err)
            print_red("Error in event #%d (file %d, local event #%d)" % (evtNum, fileIdx, idx))
            for e in err:
                print_red(e)
            dumpEventsNumpy(evt.words, None)

        # statistics
        totalWords += evt.words.size
        if evt.words.size < minWords:
            minWords = evt.words.size
        if evt.words.size > maxWords:
            maxWords = evt.words.size
            maxWordsEvtNum = evtNum
        if evt.words.size > 10000:
            print_red("Size of this event is larger than 10000: %d" % evt.words.size)
            if idx > 0:
                print_red("Dumping previous event:")
                dumpEventsNumpy(events[idx-1].words, None)
            else:
                print_red("Previous event is not available")
            print_red("Dumping the big event:")
            dumpEventsNumpy(evt.words, None)
            print_red("Exiting due to the above error")
            return

        for dmb in evt.dmbs:
            id = getDmbIdStr(dmb)
            if id not in totalDmbWords:
                totalDmbWords[id] = [dmb.words.size, 1, dmb.words.size, dmb.words.size]
            else:
                totalDmbWords[id][0] += dmb.words.size
                totalDmbWords[id][1] += 1
                if dmb.words.size < totalDmbWords[id][2]:
                    totalDmbWords[id][2] = dmb.words.size
                if dmb.words.size > totalDmbWords[id][3]:
                    totalDmbWords[id][3] = dmb.words.size

    print("===================================================================")
    print("Total number of events checked: %d" % evtNum)
    print("Total number of events with errors: %d" % len(errors))
    print("===================================================================")

    if (len(errors) > 0):
        print_red("===============================================================")
        print_red("======================= ERRORS ================================")
        print_red("===============================================================")

        for err in errors:
            print_red(err[0])
            for i in range(1, len(err)):
                print_red("    %s" % err[i])


    print("===============================================================")
    print("======================= STATISTICS ============================")
    print("===============================================================")

    print("Average FED block size (in 64bit words): %f" % (float(totalWords) / float(evtNum)))
    print("Minimum FED block size (in 64bit words): %d" % minWords)
    print("Maximum FED block size (in 64bit words): %d (event #%d)" % (maxWords, maxWordsEvtNum))
    print("DMB block sizes (in 64bit words):")
    for id, stat in totalDmbWords.iteritems():
        print("    %s: average = %f, min = %d, max = %d" % (id, (float(stat[0]) / float(stat[1])), stat[2], stat[3]))

def getDmbIdStr(dmb):
    return "Crate %d, DMB %d" % (dmb.crateId, dmb.dmbId)

if __name__ == '__main__':
    main()
