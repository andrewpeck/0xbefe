from common.utils import *
from csc.data_processing_utils import *
import signal
import sys
import os
import struct

def main():

    ldaqFilename1 = ""
    ldaqFilename2 = ""

    if len(sys.argv) < 3:
        print('Usage: local_daq_compare.py <local_daq_data_file_1> <local_daq_data_file_2>')
        return
    else:
        ldaqFilename1 = sys.argv[1]
        ldaqFilename2 = sys.argv[2]

    heading('Welcome to Local DAQ raw file comparison tool')

    ldaqFile1 = open(ldaqFilename1, 'rb')
    ldaqFile2 = open(ldaqFilename2, 'rb')

    numEvents = 0
    while True:
        dduWords1 = dduReadEventRaw(ldaqFile1, None)
        dduWords2 = dduReadEventRaw(ldaqFile2, None)

        # check event size first
        if (len(dduWords1) != len(dduWords2)):
            print_red("Length mismatch in event #%d (length1 = %d bytes, length2 = %d bytes)" % (numEvents, len(dduWords1) * 8, len(dduWords2) * 8))
            dumpEvents(dduWords1, dduWords2)
            ldaqFile1.close()
            ldaqFile2.close()
            return
        else:
            for i in range(0, len(dduWords1)):
                if dduWords1[i] != dduWords2[i]:
                    print_red("Mismatch in event #%d" % numEvents)
                    dumpEvents(dduWords1, dduWords2)
                    ldaqFile1.close()
                    ldaqFile2.close()
                    return

        print_cyan("Event #%d matches (length = %d bytes)" % (numEvents, len(dduWords1) * 8))

        numEvents += 1

    ldaqFile1.close()
    ldaqFile2.close()

if __name__ == '__main__':
    main()
