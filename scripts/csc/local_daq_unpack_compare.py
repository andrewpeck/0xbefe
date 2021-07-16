from common.utils import *
from csc.data_processing_utils import *
import signal
import sys
import os
import struct
import numpy as np
from time import *

IGNORE_DMBS = [[1, 1], [12, 1]]  # these DMBs will get ignored
MAX_LOOKAHEAD = 150000 # how many future events should be searched for a match
EXIT_ON_FIRST_ERROR = False

def main():

    ldaqFilename1 = ""
    ldaqFilename2 = ""
    maxFiles = None

    if len(sys.argv) < 3:
        print('Usage: local_daq_unpack_compare.py <local_daq_data_file_pattern_1> <local_daq_data_file_pattern_2> [max_num_files_match]')
        print('file patterns can be exact filenames or have a * indicating a wildcard, but only for the part number (last number in the local daq filename)')
        print('if a wildcard is used, you can optionally provide a max number of files to match to (default is no limit)')
        return
    else:
        ldaqFilename1 = sys.argv[1]
        ldaqFilename2 = sys.argv[2]

    if len(sys.argv) > 3:
        maxFiles = int(sys.argv[3])

    heading('Welcome to Local DAQ raw file unpacking and comparison tool')

    files1 = getAllLocalDaqRawFiles(ldaqFilename1, maxFiles)
    files2 = getAllLocalDaqRawFiles(ldaqFilename2, maxFiles)

    events1 = []
    events2 = []
    fileIdx1 = -1
    fileIdx2 = -1
    idx1 = -1
    idx2 = -1
    ids1 = []
    ids2 = []
    id1 = -1
    id2 = -1
    lastFile1 = False
    lastFile2 = False

    skippedEvents1 = 0
    skippedEvents2 = 0
    mismatchedDmbBlocks = 0
    errors = []
    dmbNumberMismatches = 0
    eventsChecked = 0

    while True:
        idx1 += 1
        idx2 += 1

        # if we're at the end of the last file, then quit
        if (lastFile1 and idx1 >= len(events1)) or (lastFile2 and idx2 >= len(events2)):
            print("DONE")
            break

        # read the next file if we're getting close to the end
        if not lastFile1 and (idx1 + MAX_LOOKAHEAD >= len(events1)):
            fileIdx1 += 1
            if fileIdx1 + 1 >= len(files1):
                lastFile1 = True
            del events1[:idx1]
            del ids1[:idx1]
            newEvents = unpackFile(files1[fileIdx1], True, IGNORE_DMBS)
            events1 += newEvents
            newIds = getIds(newEvents)
            ids1 += newIds
            idx1 = 0

        if not lastFile2 and (idx2 + MAX_LOOKAHEAD >= len(events2)):
            fileIdx2 += 1
            if fileIdx2 + 1 >= len(files2):
                lastFile2 = True
            del events2[:idx2]
            del ids2[:idx2]
            newEvents = unpackFile(files2[fileIdx2], True, IGNORE_DMBS)
            events2 += newEvents
            newIds = getIds(newEvents)
            ids2 += newIds
            idx2 = 0


        # zz = len(ids1)
        # if zz > len(ids2):
        #     zz = len(ids2)
        # for i in range(0, zz):
        #     print("L1A IDS: %d %d ||| BX IDs: %d %d" % (ids1[i] >> 12, ids2[i] >> 12, ids1[i] & 0xfff, ids2[i] & 0xfff))
        # return

        evt1 = events1[idx1]
        evt2 = events2[idx2]

        id1 = (evt1.l1Id << 12) + evt1.bxId
        id2 = (evt2.l1Id << 12) + evt2.bxId

        matchingIdFound = True
        # if L1 IDs don't match, it means that local DAQ has skipped some events on one of the RUIs, so look ahead in both files to see where we can find the match
        if id1 != id2:
            matchIdx1 = None
            matchIdx2 = None
            if id1 in ids2[idx2:]:
                matchIdx2 = ids2[idx2:].index(id1)
            if id2 in ids1[idx1:]:
                matchIdx1 = ids1[idx1:].index(id2)

            if matchIdx1 is not None and matchIdx2 is not None:
                if matchIdx1 - idx1 < matchIdx2 - idx2:
                    idx1 += matchIdx1
                    skippedEvents1 += matchIdx1
                else:
                    idx2 += matchIdx2
                    skippedEvents2 += matchIdx2
            elif matchIdx1 is not None:
                idx1 += matchIdx1
                skippedEvents1 += matchIdx1
            elif matchIdx2 is not None:
                idx2 += matchIdx2
                skippedEvents2 += matchIdx2
            else:
                matchingIdFound = False
                skippedEvents1 += 1
                skippedEvents2 += 1

        if matchingIdFound:
            eventsChecked += 1
            evt1 = events1[idx1]
            evt2 = events2[idx2]
            if (evt1.l1Id != evt2.l1Id or evt1.bxId != evt2.bxId):
                print_red("Script error: after matching IDs were found, they still seem to be different hmmm. L1ID1 = %d, L1ID2 = %d, BXID1 = %d, BXID2 = %d" % (evt1.l1Id, evt2.l1Id, evt1.bxId, evt2.bxId))
                return

            print("Checking event %d, L1 ID = %d, BX ID = %d. Num skipped events in file1 = %d, file2 = %d" % (eventsChecked, evt1.l1Id, evt1.bxId, skippedEvents1, skippedEvents2))

            if len(evt1.dmbs) != len(evt2.dmbs):
                err = "Event #%d: The number of DMBs don't match. Expected %d, but found %d in file 2" % (eventsChecked, len(evt1.dmbs), len(evt2.dmbs))
                print_red(err)
                errors.append(err)
                dmbNumberMismatches += 1
                if EXIT_ON_FIRST_ERROR:
                    return
            else:
                for i in range(0, len(evt1.dmbs)):
                    smallerSize = evt1.dmbs[i].words.size
                    if evt2.dmbs[i].words.size < smallerSize:
                        smallerSize = evt2.dmbs[i].words.size
                    mismatches = (evt1.dmbs[i].words[0:smallerSize] != evt2.dmbs[i].words[0:smallerSize])
                    if ((evt1.dmbs[i].words.size != evt2.dmbs[i].words.size) or mismatches.any()):
                        print_red("DMB words don't match")
                        dumpEventsNumpy(evt1.dmbs[i].words, evt2.dmbs[i].words)
                        if EXIT_ON_FIRST_ERROR:
                            return
                        mismatchedDmbBlocks += 1
                        firstMismatchStr = "none"
                        if mismatches.any():
                            firstMismatch64Idx = np.where(mismatches == True)[0][0]
                            firstMismatch64_1 = int(evt1.dmbs[i].words[firstMismatch64Idx])
                            firstMismatch64_2 = int(evt2.dmbs[i].words[firstMismatch64Idx])
                            for j in range(0, 4):
                                word16_1 = (firstMismatch64_1 >> (16 * j)) & 0xffff
                                word16_2 = (firstMismatch64_2 >> (16 * j)) & 0xffff
                                if word16_1 != word16_2:
                                    firstMismatchStr = hex_padded(word16_1, 2, True) + " ---- " + hex_padded(word16_2, 2, True)
                                    break
                        errors.append("Event #%d: Crate %d DMB %d, first mismatched word = %s" % (eventsChecked, evt1.dmbs[i].crateId, evt1.dmbs[i].dmbId, firstMismatchStr))

    print("Total number of events checked: %d" % eventsChecked)
    print("Total number of events skipped due to syncing on file1 = %d, file2 = %d" % (skippedEvents1, skippedEvents2))
    print("Total number of events where the number of DMBs didn't match: %d" % dmbNumberMismatches)
    print("Total number of DMB blocks with size or data mismatches: %d" % mismatchedDmbBlocks)
    if (len(errors) > 0):
        print_red("Errors found:")
        for error in errors:
            print_red("      %s" % error)




    return

    heading("Unpacking the first file")
    tt1 = clock()
    t1 = clock()
    events1 = unpackFile(ldaqFilename1)
    t2 = clock()
    print("Unpacking the first file took %f" % (t2 - t1))

    heading("Unpacking the second file")
    t1 = clock()
    events2 = unpackFile(ldaqFilename2)
    t2 = clock()
    print("Unpacking the second file took %f" % (t2 - t1))

    heading("Comparing the data")
    t1 = clock()
    idx2 = 0
    syncing = True
    skipped_events_syncing1 = 0
    skipped_events_syncing2 = 0
    mismatched_dmb_blocks = 0
    mismatched_dmb_errs = []
    dmb_number_mismatches = 0
    dmb_blocks_checked = 0
    for idx1 in range(0, len(events1)):
        event1 = events1[idx1]
        l1Id = event1.l1Id
        print("Checking event #%d, L1 ID = %d" % (idx1, l1Id))
        #find the indexes of the DMBs that we want to compare (ignoring the ones in IGNORE_DMBS mask)
        dmbs1 = []
        for dmb in event1.dmbs:
            if [dmb.crateId, dmb.dmbId] not in IGNORE_DMBS:
                dmbs1.append(dmb)

        # if we still have DMBs left here, lets check them against the file 2
        if len(dmbs1) != 0:
            if idx2 >= len(events2):
                break

            if syncing and l1Id > events2[idx2].l1Id:
                while idx2 < len(events2) and events2[idx2].l1Id < l1Id:
                    # print_cyan("Syncing the two files (skipping L1 ID %d on file 2, because we need to start at L1 ID %d)" % (events2[idx2].l1Id, l1Id))
                    idx2 += 1
                    skipped_events_syncing2 += 1
                # syncing = False

            if idx2 >= len(events2):
                break

            event2 = events2[idx2]
            if (l1Id != event2.l1Id):
                if syncing and idx1 < 1000 and l1Id < event2.l1Id:
                    # print_cyan("Syncing the two files (skipping L1 ID %d on file 1, because we need to start at L1 ID %d)" % (l1Id, event2.l1Id))
                    skipped_events_syncing1 += 1
                    continue
                else:
                    print_red("L1 IDs don't match! expected %d, but found %d in file 2" % (l1Id, event2.l1Id))
                    continue
            # syncing = False
            idx2 += 1
            if (len(dmbs1) != len(event2.dmbs)):
                print_red("The number of DMBs don't match. Expected %d, but found %d in file 2" % (len(dmbs1), len(event2.dmbs)))
                dmb_number_mismatches += 1
            for i in range(0, len(dmbs1)):
                dmb_blocks_checked += 1
                smaller_size = dmbs1[i].words.size
                if event2.dmbs[i].words.size < smaller_size:
                    smaller_size = event2.dmbs[i].words.size
                mismatches = (dmbs1[i].words[0:smaller_size] != event2.dmbs[i].words[0:smaller_size])
                if ((dmbs1[i].words.size != event2.dmbs[i].words.size) or mismatches.any()):
                    print_red("DMB words don't match")
                    dumpEventsNumpy(dmbs1[i].words, event2.dmbs[i].words)
                    mismatched_dmb_blocks += 1
                    firstMismatchStr = "none"
                    if mismatches.any():
                        firstMismatch64Idx = np.where(mismatches == True)[0][0]
                        firstMismatch64_1 = int(dmbs1[i].words[firstMismatch64Idx])
                        firstMismatch64_2 = int(event2.dmbs[i].words[firstMismatch64Idx])
                        for j in range(0, 4):
                            word16_1 = (firstMismatch64_1 >> (16*j)) & 0xffff
                            word16_2 = (firstMismatch64_2 >> (16*j)) & 0xffff
                            if word16_1 != word16_2:
                                firstMismatchStr = hex_padded(word16_1, 2, True) + " ---- " + hex_padded(word16_2, 2, True)
                                break
                    mismatched_dmb_errs.append("Crate %d DMB %d, event %d, first mismatched word = %s" % (dmbs1[i].crateId, dmbs1[i].dmbId, idx1, firstMismatchStr))
                    # return

    print("Total number of events skipped due to syncing on file1 = %d, file2 = %d" % (skipped_events_syncing1, skipped_events_syncing2))
    if (mismatched_dmb_blocks > 0):
        print_red("Total mismatched DMB words = %d out of %d checked" % (mismatched_dmb_blocks, dmb_blocks_checked))
        for dmbId in mismatched_dmb_errs:
            print_red("      %s" % dmbId)
    else:
        print("Total mismatched DMB words = %d out of %d checked" % (mismatched_dmb_blocks, dmb_blocks_checked))

    print("Number of events with different number of DMBs = %d" % dmb_number_mismatches)

    t2 = clock()
    tt2 = clock()
    print("Comparing the data took %f" % (t2 - t1))
    print("Total time spent = %f" % (tt2 - tt1))

# this function returns a list of event IDs where the lowest 12 bits are BX, and the top bits are L1A ID
def getIds(events):
    ret = []
    for event in events:
        id = event.l1Id << 12
        id += event.bxId
        ret.append(id)
    return ret

if __name__ == '__main__':
    main()
