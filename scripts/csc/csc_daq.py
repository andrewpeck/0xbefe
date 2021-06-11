from rw_reg import *
from time import *
from utils import *
import datetime
import array
import struct
import signal
import sys
import os

DEBUG=False

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

ADDR_DAQ_EMPTY = None
ADDR_DAQ_DATA = None
RAW_FILE = None

def main():
    global RAW_FILE

    filename = raw_input("Filename (default = $HOME/csc_fed/data/run_<datetime>.raw): ")
    if not filename:
        filename = os.environ['HOME'] + "/csc_fed/data/run_" + datetime.datetime.now().strftime("%Y-%m-%d__%H_%M_%S") + ".raw"

    inputMask = 0x7efd
    inputMaskStr = raw_input("DAQ input enable bitmask as hex (default = 0x7efd, meaning only the first input is enabled)")
    if inputMaskStr:
        inputMask = parseInt(inputMaskStr)

    ignoreAmc13 = 0x1
    ignoreAmc13Str = raw_input("Should we ignore AMC13 path? (default = yes)")
    if (ignoreAmc13Str == "no") or (ignoreAmc13Str == "n"):
        ignoreAmc13 = 0x0

    readoutToCtp7 = False
    readoutToCtp7Str = raw_input("Should we readout locally to CTP7 SD card? (default = no)")
    if (readoutToCtp7Str == "yes") or (readoutToCtp7Str == "y"):
        readoutToCtp7 = True

    waitForResync = 0x1
    waitForResyncStr = raw_input("Should we keep the DAQ in reset until a resync? (default = yes)")
    if (waitForResyncStr == "no") or (waitForResyncStr == "n"):
        waitForResync = 0x0

    freezeOnError = 0x0
    freezeOnErrorStr = raw_input("Should the DAQ freeze on TTS error? (default = no)")
    if (freezeOnErrorStr == "yes") or (freezeOnErrorStr == "y"):
        freezeOnError = 0x1

    useCscTtcEncoding = False
    useCscTtcEncodingStr = raw_input("Should we use CSC TTC encoding? (default = no)")
    if (useCscTtcEncodingStr == "yes") or (useCscTtcEncodingStr == "y"):
        useCscTtcEncoding = True

    useLocalL1a = 0
    useLocalL1aStr = raw_input("Should we use local L1A generation based on DAQ data (use when TCDS is not available)? (default = yes)")
    if (useLocalL1aStr == "yes") or (useLocalL1aStr == "y"):
        useLocalL1a = 1

    parseXML()

    if useCscTtcEncoding:
        heading("Configuring TTC with CSC encoding")
        writeReg(getNode('CSC_FED.TTC.CONFIG.CMD_BC0'), 0x4)
        writeReg(getNode('CSC_FED.TTC.CONFIG.CMD_EC0'), 0x2)
        writeReg(getNode('CSC_FED.TTC.CONFIG.CMD_RESYNC'), 0xc)
        writeReg(getNode('CSC_FED.TTC.CONFIG.CMD_OC0'), 0x8)
        writeReg(getNode('CSC_FED.TTC.CONFIG.CMD_HARD_RESET'), 0x10)

    heading("Resetting and starting DAQ")
    writeReg(getNode('CSC_FED.TTC.CTRL.MODULE_RESET'), 0x1)
    writeReg(getNode('CSC_FED.TTC.CTRL.L1A_ENABLE'), 0x0)
    writeReg(getNode('CSC_FED.TEST.GBE_TEST.ENABLE'), 0x0)
    writeReg(getNode('CSC_FED.DAQ.CONTROL.DAQ_ENABLE'), 0x0)
    writeReg(getNode('CSC_FED.DAQ.CONTROL.L1A_REQUEST_EN'), useLocalL1a)
    writeReg(getNode('CSC_FED.DAQ.CONTROL.INPUT_ENABLE_MASK'), inputMask)
    writeReg(getNode('CSC_FED.DAQ.CONTROL.IGNORE_AMC13'), ignoreAmc13)
    writeReg(getNode('CSC_FED.DAQ.CONTROL.FREEZE_ON_ERROR'), freezeOnError)
    writeReg(getNode('CSC_FED.DAQ.CONTROL.RESET_TILL_RESYNC'), waitForResync)
    writeReg(getNode('CSC_FED.DAQ.CONTROL.SPY.SPY_SKIP_EMPTY_EVENTS'), 0x1)
    writeReg(getNode('CSC_FED.DAQ.CONTROL.SPY.SPY_PRESCALE'), 0x1)
    writeReg(getNode('CSC_FED.DAQ.CONTROL.RESET'), 0x1)
    writeReg(getNode('CSC_FED.DAQ.LAST_EVENT_FIFO.DISABLE'), 0x0)
    writeReg(getNode('CSC_FED.DAQ.CONTROL.DAQ_ENABLE'), 0x1)
    writeReg(getNode('CSC_FED.TTC.CTRL.L1A_ENABLE'), 0x1)
    writeReg(getNode('CSC_FED.DAQ.CONTROL.RESET'), 0x0)

    signal.signal(signal.SIGINT, exitHandler) #register SIGINT to gracefully exit
    RAW_FILE = None
    if readoutToCtp7:
        RAW_FILE = open(filename, 'w')

    heading("Taking data!")
    printCyan("Filename = " + filename)
    printCyan("Press Ctrl+C to stop (gracefully)")

    numEvents = 0
    numEventsSentToSpy = 0
    daqEmptyNode = getNode('CSC_FED.DAQ.LAST_EVENT_FIFO.EMPTY')
    daqDataNode = getNode('CSC_FED.DAQ.LAST_EVENT_FIFO.DATA')
    daqLastEventDisableNode = getNode('CSC_FED.DAQ.LAST_EVENT_FIFO.DISABLE')
    spyEventsSentNode = getNode('CSC_FED.DAQ.STATUS.SPY.SPY_EVENTS_SENT')
    ttsStateNode = getNode('CSC_FED.DAQ.STATUS.TTS_STATE')
    empty = 0
    data = 0
    ttsState = 0
    evtSize = 0
    while True:
        if readoutToCtp7:
            empty = parseInt(readReg(daqEmptyNode))
            if empty == 0:
                RAW_FILE.write("======================== Event %i ========================\n" % numEvents)
                numEvents += 1
                evtSize = 0
                #block last event fifo until you're finished reading the event in order to know the event boundaries
                writeReg(daqLastEventDisableNode, 0x1)
                while empty == 0:
                    data = (parseInt(readReg(daqDataNode)) << 32) + parseInt(readReg(daqDataNode))
                    empty = parseInt(readReg(daqEmptyNode))
                    evtSize += 1
                    RAW_FILE.write(hexPadded64(data) + '\n')
                writeReg(daqLastEventDisableNode, 0x0)
                RAW_FILE.write("==================== Num words = %i ====================\n" % evtSize)
                RAW_FILE.write("========================================================\n")

        numEventsSentToSpy = parseInt(readReg(spyEventsSentNode))
        if (numEvents % 10 == 0) or (numEventsSentToSpy % 1000 == 0):
            sys.stdout.write("\rEvents read to CTP7: %i, events sent to spy: %i" % (numEvents, numEventsSentToSpy))
            sys.stdout.flush()

        ttsState = parseInt(readReg(ttsStateNode))
        if ttsState == 0xc:
            printRed("TTS state = ERROR! Dumping regs and waiting for ready state...")
            # if readoutToCtp7:
            #     RAW_FILE.close()
            dumpDaqRegs()
            print("")
            while ttsState == 0xc:
                ttsState = parseInt(readReg(ttsStateNode))
                sleep(0.1)

def exitHandler(signal, frame):
    global RAW_FILE
    print('Exiting...')
    RAW_FILE.close()
    sys.exit(0)

# initialize the daq register addresses to be used with faster wReg and rReg C bindings
def initDaqRegAddrs():
    global ADDR_DAQ_EMPTY
    global ADDR_DAQ_DATA
    ADDR_DAQ_EMPTY = getNode('CSC_FED.DAQ.LAST_EVENT_FIFO.EMPTY').real_address
    ADDR_DAQ_EMPTY = getNode('CSC_FED.DAQ.LAST_EVENT_FIFO.DATA').real_address


def dumpDaqRegs():
    dumpRegs("CSC_FED.LINKS", True, "Link Registers")
    dumpRegs("CSC_FED.DAQ", True, "DAQ Registers")

#---------------------------- utils ------------------------------------------------

def check_bit(byteval,idx):
    return ((byteval&(1<<idx))!=0);

def debug(string):
    if DEBUG:
        print('DEBUG: ' + string)

def debugCyan(string):
    if DEBUG:
        printCyan('DEBUG: ' + string)

def heading(string):
    print Colors.BLUE
    print '\n>>>>>>> '+str(string).upper()+' <<<<<<<'
    print Colors.ENDC

def subheading(string):
    print Colors.YELLOW
    print '---- '+str(string)+' ----',Colors.ENDC

def printCyan(string):
    print Colors.CYAN
    print string, Colors.ENDC

def printRed(string):
    print Colors.RED
    print string, Colors.ENDC

def hex(number):
    if number is None:
        return 'None'
    else:
        return "{0:#0x}".format(number)

def hexPadded64(number):
    if number is None:
        return 'None'
    else:
        return "{0:#0{1}x}".format(number, 18)

def binary(number, length):
    if number is None:
        return 'None'
    else:
        return "{0:#0{1}b}".format(number, length + 2)

def parseInt(string):
    if string is None:
        return None
    elif string.startswith('0x'):
        return int(string, 16)
    elif string.startswith('0b'):
        return int(string, 2)
    else:
        return int(string)

if __name__ == '__main__':
    main()
