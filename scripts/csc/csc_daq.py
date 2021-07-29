from common.rw_reg import *
from time import *
from common.utils import *
import datetime
import array
import struct
import signal
import sys
import os

DEBUG = False

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

    filename = input("Filename (default = $HOME/csc/data/run_<datetime>.raw): ")
    if not filename:
        filename = os.environ['HOME'] + "/csc/data/run_" + datetime.datetime.now().strftime("%Y-%m-%d__%H_%M_%S") + ".raw"

    inputMask = 0x1
    inputMaskStr = input("DAQ input enable bitmask as hex (default = 0x0001, meaning only the first input is enabled)")
    if inputMaskStr:
        inputMask = parse_int(inputMaskStr)

    ignoreAmc13 = 0x1
    ignoreAmc13Str = input("Should we ignore AMC13 path? (default = yes)")
    if (ignoreAmc13Str == "no") or (ignoreAmc13Str == "n"):
        ignoreAmc13 = 0x0

    readoutToCtp7 = False
    readoutToCtp7Str = input("Should we readout locally to the backend SD card? (default = no)")
    if (readoutToCtp7Str == "yes") or (readoutToCtp7Str == "y"):
        readoutToCtp7 = True

    waitForResync = 0x1
    waitForResyncStr = input("Should we keep the DAQ in reset until a resync? (default = yes)")
    if (waitForResyncStr == "no") or (waitForResyncStr == "n"):
        waitForResync = 0x0

    freezeOnError = 0x0
    freezeOnErrorStr = input("Should the DAQ freeze on TTS error? (default = no)")
    if (freezeOnErrorStr == "yes") or (freezeOnErrorStr == "y"):
        freezeOnError = 0x1

    useCscTtcEncoding = False
    useCscTtcEncodingStr = input("Should we use CSC TTC encoding? (default = no)")
    if (useCscTtcEncodingStr == "yes") or (useCscTtcEncodingStr == "y"):
        useCscTtcEncoding = True

    useLocalL1a = 0
    useLocalL1aStr = input("Should we use local L1A generation based on DAQ data (use when TCDS is not available)? (default = no)")
    if (useLocalL1aStr == "yes") or (useLocalL1aStr == "y"):
        useLocalL1a = 1

    parse_xml()

    if useCscTtcEncoding:
        heading("Configuring TTC with CSC encoding")
        write_reg(get_node('BEFE.CSC_FED.TTC.CONFIG.CMD_BC0'), 0x4)
        write_reg(get_node('BEFE.CSC_FED.TTC.CONFIG.CMD_EC0'), 0x2)
        write_reg(get_node('BEFE.CSC_FED.TTC.CONFIG.CMD_RESYNC'), 0xc)
        write_reg(get_node('BEFE.CSC_FED.TTC.CONFIG.CMD_OC0'), 0x8)
        write_reg(get_node('BEFE.CSC_FED.TTC.CONFIG.CMD_HARD_RESET'), 0x10)

    heading("Resetting and starting DAQ")
    write_reg(get_node('BEFE.CSC_FED.TTC.CTRL.MODULE_RESET'), 0x1)
    write_reg(get_node('BEFE.CSC_FED.TTC.CTRL.L1A_ENABLE'), 0x0)
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.ENABLE'), 0x0)
    write_reg(get_node('BEFE.CSC_FED.DAQ.CONTROL.DAQ_ENABLE'), 0x0)
    write_reg(get_node('BEFE.CSC_FED.DAQ.CONTROL.L1A_REQUEST_EN'), useLocalL1a)
    write_reg(get_node('BEFE.CSC_FED.DAQ.CONTROL.INPUT_ENABLE_MASK'), inputMask)
    write_reg(get_node('BEFE.CSC_FED.DAQ.CONTROL.IGNORE_AMC13'), ignoreAmc13)
    write_reg(get_node('BEFE.CSC_FED.DAQ.CONTROL.FREEZE_ON_ERROR'), freezeOnError)
    write_reg(get_node('BEFE.CSC_FED.DAQ.CONTROL.RESET_TILL_RESYNC'), waitForResync)
    write_reg(get_node('BEFE.CSC_FED.DAQ.CONTROL.SPY.SPY_SKIP_EMPTY_EVENTS'), 0x1)
    write_reg(get_node('BEFE.CSC_FED.DAQ.CONTROL.SPY.SPY_PRESCALE'), 0x1)
    write_reg(get_node('BEFE.CSC_FED.DAQ.CONTROL.RESET'), 0x1)
    write_reg(get_node('BEFE.CSC_FED.DAQ.LAST_EVENT_FIFO.DISABLE'), 0x0)
    write_reg(get_node('BEFE.CSC_FED.DAQ.CONTROL.DAQ_ENABLE'), 0x1)
    write_reg(get_node('BEFE.CSC_FED.TTC.CTRL.L1A_ENABLE'), 0x1)
    write_reg(get_node('BEFE.CSC_FED.DAQ.CONTROL.RESET'), 0x0)

    signal.signal(signal.SIGINT, exitHandler) #register SIGINT to gracefully exit
    RAW_FILE = None
    if readoutToCtp7:
        RAW_FILE = open(filename, 'w')

    heading("Taking data!")
    print_cyan("Filename = " + filename)
    print_cyan("Press Ctrl+C to stop (gracefully)")

    numEvents = 0
    numEventsSentToSpy = 0
    daqEmptyNode = get_node('BEFE.CSC_FED.DAQ.LAST_EVENT_FIFO.EMPTY')
    daqDataNode = get_node('BEFE.CSC_FED.DAQ.LAST_EVENT_FIFO.DATA')
    daqLastEventDisableNode = get_node('BEFE.CSC_FED.DAQ.LAST_EVENT_FIFO.DISABLE')
    spyEventsSentNode = get_node('BEFE.CSC_FED.DAQ.STATUS.SPY.SPY_EVENTS_SENT')
    ttsStateNode = get_node('BEFE.CSC_FED.DAQ.STATUS.TTS_STATE')
    empty = 0
    data = 0
    ttsState = 0
    evtSize = 0
    while True:
        if readoutToCtp7:
            empty = read_reg(daqEmptyNode)
            if empty == 0:
                RAW_FILE.write("======================== Event %i ========================\n" % numEvents)
                numEvents += 1
                evtSize = 0
                #block last event fifo until you're finished reading the event in order to know the event boundaries
                write_reg(daqLastEventDisableNode, 0x1)
                while empty == 0:
                    data = (read_reg(daqDataNode) << 32) + readReg(daqDataNode)
                    empty = readReg(daqEmptyNode)
                    evtSize += 1
                    RAW_FILE.write(hex_padded64(data) + '\n')
                write_reg(daqLastEventDisableNode, 0x0)
                RAW_FILE.write("==================== Num words = %i ====================\n" % evtSize)
                RAW_FILE.write("========================================================\n")

        numEventsSentToSpy = read_reg(spyEventsSentNode)
        if (numEvents % 10 == 0) or (numEventsSentToSpy % 1000 == 0):
            sys.stdout.write("\rEvents read to CTP7: %i, events sent to spy: %i" % (numEvents, numEventsSentToSpy))
            sys.stdout.flush()

        ttsState = read_reg(ttsStateNode)
        if ttsState == 0xc:
            print_red("TTS state = ERROR! Dumping regs and waiting for ready state...")
            # if readoutToCtp7:
            #     RAW_FILE.close()
            dumpDaqRegs()
            print("")
            while ttsState == 0xc:
                ttsState = read_reg(ttsStateNode)
                sleep(0.1)

def exitHandler(signal, frame):
    global RAW_FILE
    print('Exiting...')
    if RAW_FILE is not None:
        RAW_FILE.close()
    sys.exit(0)

# initialize the daq register addresses to be used with faster wReg and rReg C bindings
def initDaqRegAddrs():
    global ADDR_DAQ_EMPTY
    global ADDR_DAQ_DATA
    ADDR_DAQ_EMPTY = get_node('BEFE.CSC_FED.DAQ.LAST_EVENT_FIFO.EMPTY').address
    ADDR_DAQ_EMPTY = get_node('BEFE.CSC_FED.DAQ.LAST_EVENT_FIFO.DATA').address


def dumpDaqRegs():
    dump_regs("BEFE.CSC_FED.LINKS", False, "Link Registers")
    dump_regs("BEFE.CSC_FED.DAQ", False, "DAQ Registers")

#---------------------------- utils ------------------------------------------------

def debug(string):
    if DEBUG:
        print('DEBUG: ' + string)

def debugCyan(string):
    if DEBUG:
        print_cyan('DEBUG: ' + string)

if __name__ == '__main__':
    main()
