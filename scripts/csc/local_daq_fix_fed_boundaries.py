from common.utils import *
from csc.data_processing_utils import *
import signal
import sys
import os
import struct
import numpy as np
from time import *

def main():

    ldaqFilename = ""
    maxFiles = None

    if len(sys.argv) < 2:
        print('This utility is meant to fix local daq raw files which contain junk in between consecutive FED blocks (any data between FED trailer and FED header)')
        print('It will output fixed data on a file that has the same name appended with _fixed')
        print('Early versions of the CSC FED upgrade firmware contained a bug in the spy driver, which in rare occasions resulted in a few junk words in between consecutive events')
        print('The bug has already been fixed, but this script was written to fix the data that had already been collected while the bug was there')
        print('')
        print('Usage: local_fix_fed_block_boundaries.py <local_daq_data_file_pattern> [max_num_files_match]')
        print('file patterns can be exact filenames or have a * indicating a wildcard, but only for the part number (last number in the local daq filename)')
        print('if a wildcard is used, you can optionally provide a max number of files to match to (default is no limit)')
        return
    else:
        ldaqFilename = sys.argv[1]

    if len(sys.argv) > 2:
        maxFiles = int(sys.argv[2])

    heading('Welcome to Local DAQ raw file FED block boundary fixer')

    files = getAllLocalDaqRawFiles(ldaqFilename, maxFiles)
    print("Got %d files:" % len(files))
    for fname in files:
        print("    %s" % fname)

    errors = 0
    wordsSkipped = 0
    minWordsSkipped = 9999999
    maxWordsSkipped = 0
    trailersChecked = 0
    wordsToDelete = []
    for fname in files:
        print("Reading file %s" % fname)
        f = open(fname, 'rb')
        words = np.fromfile(f, dtype=np.dtype('u2'))
        f.close()

        print("Done reading %d words" % words.size)

        ffffIdxs = np.where(words == 0xffff)[0]
        print("Number of 0xffff occurances: %d" % ffffIdxs.size)
        for i in ffffIdxs:
            if words[i+1] == 0x8000 and words[i] == 0xffff and words[i-1] == 0x8000 and words[i-2] == 0x8000:
                trailersChecked += 1
                if trailersChecked % 100000 == 0:
                    print("Checking trailer %d, word %d out of %d" % (trailersChecked, i, words.size))
                # if this is not the last event, then check if the header of the next event is where it should be (also check if the trailer of the current event ends as it should)
                if words.size > i + 21:
                    # looks like a screwed up trailer, lets just abort here
                    if words[i+9] & 0xf000 != 0xa000:
                        print_red("Corrupted FED trailer! Found the 8000 ffff 8000 8000 word, but the last trailer word does not start with 0xa!")
                        print_red("Index of the top 16 bit word in the 8000 ffff 8000 8000 marker: %d" % i)
                        return
                    # okay, this is our case of missing header from the next event
                    if words[i+13] & 0xf000 != 0x5000 or words[i+15] != 0x8000 or words[i+16] != 0x0001 or words[i+17] != 0x8000:
                        print_red("Error detected in event #%d, word #%d" % (trailersChecked, i))
                        print_red("Below is a dump of this occurance, starting at the trailer:")
                        printWords16(words[i-2:i+62])
                        errors += 1

                        # search for the header
                        print_red("Searching for the header")
                        for j in xrange(i, words.size):
                            if words[j] & 0xf000 == 0x5000 and words[j+2] == 0x8000 and words[j+3] == 0x0001 and words[j+4] == 0x8000:
                                numJunkWords = j - (i + 13)
                                if numJunkWords < 0:
                                    print_red("ERROR: number of junk words is negative: %d" % numJunkWords)
                                    return
                                print_red("Found the header after %d junk words:" % numJunkWords)
                                s = ""
                                for jj in range(j-2-numJunkWords,j-2):
                                    s += hex_padded(words[jj], 2) + " "
                                    wordsToDelete.append(jj)
                                    if jj != j-2-numJunkWords and words[jj] != 0xffff:
                                        print_red("ERROR: The found junk word does not equal to 0xffff, which is expected: %s. Aborting." % hex_padded(words[jj], 2))
                                        return
                                print_red(s)
                                wordsSkipped += numJunkWords
                                if numJunkWords < minWordsSkipped:
                                    minWordsSkipped = numJunkWords
                                if numJunkWords > maxWordsSkipped:
                                    maxWordsSkipped = numJunkWords
                                break

        #remove the junk words and write out the fixed file
        fixedWords = np.delete(words, wordsToDelete)
        ofname = fname + "_fixed"
        print("Writing results to file %s" % ofname)
        of = open(ofname, 'wb')
        fixedWords.tofile(of)
        of.close()

        # for i in range(0, 10):
        #     s = ""
        #     for j in range(0, 4):
        #         s += hex_padded(raw[i*4+j], 2) + " "
        #     print(s)

    print("Number of FED trailers checked: %d" % trailersChecked)
    print("Total number of errors found: %d" % errors)
    print("Total number of 16bit words skipped in the fixed file: %d" % wordsSkipped)
    print("Minimum number of 16bit words skipped per error: %d" % minWordsSkipped)
    print("Maximum number of 16bit words skipped per error: %d" % maxWordsSkipped)


def printWords16(words):
    for i in range(0, words.size / 4):
        s = ""
        # for j in reversed(range(0, 4)):
        for j in range(0, 4):
            s += hex_padded(words[i*4+j], 2) + " "
        print(s)

if __name__ == '__main__':
    main()
