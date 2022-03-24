from common.rw_reg import *
from common.utils import *
from csc.data_processing_utils import *
from time import *
import datetime
import array
import struct
import signal
import sys
import os
import zlib

DEBUG = False

# SOURCE_MAC = 0x00151714809e
# SOURCE_MAC = 0xdbdbdbdbdbdb
SOURCE_MAC = 0x3cfdfeee4ba0

# DESTINATION_MAC = 0x00151714809e
# DESTINATION_MAC = 0xa0369f14c8c0
DESTINATION_MAC = 0x3cfdfeee4ba0

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

REG_PUSH_GBE_DATA = None
REG_START_TRANSMIT = None
REG_EMPTY_BUSY = None
REG_MANUAL_READ = None
REG_PREFIX_GEM = "BEFE.GEM.GEM_TESTS"
REG_PREFIX_CSC = "BEFE.CSC_FED.TEST"
REG_PREFIX = REG_PREFIX_CSC

def main():

    localDaqFilename = None
    localDaqEventNum = None
    localDaqNumOfEvents = None
    logFilename = None

    if (len(sys.argv) > 1) and ('help' in sys.argv[1]):
        print('Usage: csc_eth_packet_test.py [local_daq_data_file or ila_dump_csv_file] [local_daq_event_number_to_start_from] [local_daq_number_of_events_to_send] [raw_log_file]')
        print('if no arguments are given, a dummy eth packet will be sent')
        print('if local daq data file is supplied but no event number is supplied, the whole file will be read and sent out event by event')
        print('if ila_dump_csv_file is supplied the whole file will be read and sent out event by event')
        print('if local_daq_event_number_to_start_from is supplied and local_daq_number_of_events_to_send, it will send this many events starting at the given position')
        print('if local_daq_number_of_events_to_send is ommited, it will send the whole file starting at local_daq_event_number_to_start_from')
        return

    if len(sys.argv) > 1:
        localDaqFilename = sys.argv[1]

    if len(sys.argv) > 2:
        if "none" not in sys.argv[2]:
            localDaqEventNum = parse_int(sys.argv[2])

    if len(sys.argv) > 3:
        localDaqNumOfEvents = parse_int(sys.argv[3])

    if len(sys.argv) > 4:
        logFilename = sys.argv[4]

    parse_xml()
    initRegAddrs()

    if localDaqFilename is None:
        # sendAutoNegAckPacket()
        # sendDummyEmptyDduPacket()
        sendDummyEthPacket()
        return

    if localDaqFilename[-4:] == ".csv":
        print("Sending the data from the CSV file")
        f = open(localDaqFilename)
        packet = []
        for line in f:
            if "csc_fed" in line or "HEX" in line:
                continue
            split = line.split(",")
            word = int(split[3], 16)
            kchar = int(split[4], 16)
            if word == 0x50bc:
                continue
            word = word + (kchar << 16)
            packet.append(word)
        f.close()

        # packet[4] = 0xdbdb
        # packet[5] = 0xdbdb
        # packet[6] = 0xdbdb
        # packet[4] = 0x36a0
        # packet[5] = 0x149f
        # packet[6] = 0xc0c8
        # packet[7] = 0x36a0
        # packet[8] = 0x149f
        # packet[9] = 0xc0c8
        # packet[10] = 0x0008
        # packet[10] = 0x7088
        # packet[10] = 0x8870
        # packet[10] = 0x0000

        # packet = packet[:756] + packet[-10:]
        # packet = packet[:758] + packet[-10:]
        # packet = packet[:200] + packet[-10:]

        crc_sent = (packet[-3] << 16) + packet[-4]
        frame_payload = ""
        for word in packet[4:-4]:
            frame_payload += chr(word & 0xff) + chr((word >> 8) & 0xff)
        calc_crc = zlib.crc32(frame_payload.encode("8859")) & 0xffffffff

        # replace the CRC
        packet[-3] = calc_crc >> 16
        packet[-4] = calc_crc & 0xffff

        # packet = packet[:-1]
        # packet[-1] = 0x3f7fd

        print("Sent CRC: " + hex32(crc_sent))
        print("Calculated CRC: " + hex32(calc_crc))
        if crc_sent != calc_crc:
            print_red("CRC mismatch!")
        else:
            print_green("CRC matches")

        # send the frame
        write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.ENABLE'), 0x1)
        for word in packet[0:]:
            pushGbeWord16(word)
        write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.START_TRANSMIT'), 0x1)

        return

    localDaqFile = open(localDaqFilename, 'rb')
    events = []
    smallest_size = 99999
    smallest_size_idx = -1
    largest_size = 0
    largest_size_idx = -1
    events_read = 0
    if localDaqEventNum is not None:
        events.append(dduReadEventRaw(localDaqFile, localDaqEventNum))
        events_read = 1
        print("read event #%d, size = %d bytes" % (localDaqEventNum, len(events[0]) * 8))
        localDaqEventNum = None

    size = 1
    words_read = 0
    while size > 0 and ((events_read < localDaqNumOfEvents) or localDaqNumOfEvents is None):
        event = dduReadEventRaw(localDaqFile, localDaqEventNum)
        size = len(event)
        words_read += size
        events.append(event)
        print("read event #%d, size = %d bytes, total bytes read = %d" % (events_read, size * 8, words_read * 8))
        events_read += 1
        if size > 48 and size < smallest_size:
            smallest_size = size
            smallest_size_idx = events_read
        if size > largest_size:
            largest_size = size
            largest_size_idx = events_read

    print_cyan("Smallest event size (excluding empty events): %d bytes (event #%d)" % (smallest_size * 8, smallest_size_idx))
    print_cyan("Largest event size: %d bytes (event #%d)" % (largest_size * 8, largest_size_idx))

    heading("Starting to send the events out!")
    write_reg(get_node('BEFE.CSC_FED.TEST.CTRL.MODULE_RESET'), 0x1)
    sleep(0.1)
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.ENABLE'), 0x1)

    logFile = None
    if logFilename is not None:
        logFile = open(logFilename, 'w')

    packet_counter = 0
    for event in events:
        #print("Event size = %d bytes" % (len(event)*8))
        #split up the events into multiple packets of max payload size = 994 64bit words
        i = 0
        last_fragment = False
        while i < len(event):
            end = i + 994 #180 #994 #255
            if end >= len(event):
                end = len(event)
                last_fragment = True
            if i > 0:
                print_cyan("Split event is being sent! i = %d, end = %d, event length = %d" % (i, end, len(event)))
            event_fragment = event[i:end]
            #make sure the FIFO is empty and there's no active transmission before pushing in new data
            while i == 0 and rReg(REG_EMPTY_BUSY) != 2:
                sleep(0.00001)
            i += 994 #180 #994 #255
            #print("Sending a packet of size %d bytes" % (len(event_fragment) * 8))
            if not sendDduEthPacket(event_fragment, packet_counter, True, last_fragment, False, logFile, True):
                return
            if packet_counter == 0xffff:
                packet_counter = 0
            else:
                packet_counter += 1

    localDaqFile.close()
    if logFile is not None:
        logFile.close()

    return

def initRegAddrs():
    global REG_PUSH_GBE_DATA
    global REG_START_TRANSMIT
    global REG_EMPTY_BUSY
    global REG_MANUAL_READ
    REG_PUSH_GBE_DATA = get_node('%s.GBE_TEST.PUSH_GBE_DATA' % REG_PREFIX).address
    REG_START_TRANSMIT = get_node('%s.GBE_TEST.START_TRANSMIT' % REG_PREFIX).address
    REG_EMPTY_BUSY = get_node('%s.GBE_TEST.BUSY' % REG_PREFIX).address
    REG_MANUAL_READ = get_node('%s.GBE_TEST.MANUAL_READ' % REG_PREFIX).address

# this function pushes an ETH frame with the provided payload to the CTP7 and sends it out
# note that the payload can be provided as either an array of 64 bit words (default), or an array of 16bit words (only used for fake packet testing)
def sendStandardEthPacket(payload_words64, ethType = 0x0800, payload_words16 = None):

    heading("Sending an ethernet packet")

    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.ENABLE'), 0x1)

    s = "" # eth frame as char vector, to be used for crc

    ########## preamble and SOF ##########
    pushGbeWord16(0x155FB)
    pushGbeWord16(0x5555)
    pushGbeWord16(0x5555)
    pushGbeWord16(0xD555)

    ########## source MAC ##########
    s += pushGbeWord16(((SOURCE_MAC >> 24) & 0xff00) + (SOURCE_MAC >> 40))
    print(hex(((SOURCE_MAC >> 24) & 0xff00) + (SOURCE_MAC >> 40)))
    s += pushGbeWord16(((SOURCE_MAC >> 8) & 0xff00) + ((SOURCE_MAC >> 24) & 0xff))
    print(hex(((SOURCE_MAC >> 8) & 0xff00) + ((SOURCE_MAC >> 24) & 0xff)))
    s += pushGbeWord16(((SOURCE_MAC & 0xff) << 8) + ((SOURCE_MAC >> 8) & 0xff))
    print(hex(((SOURCE_MAC & 0xff) << 8) + ((SOURCE_MAC >> 8) & 0xff)))

    ########## destination MAC (simply use the same as source) ##########
    s += pushGbeWord16(((DESTINATION_MAC >> 24) & 0xff00) + (DESTINATION_MAC >> 40))
    print(hex(((DESTINATION_MAC >> 24) & 0xff00) + (DESTINATION_MAC >> 40)))
    s += pushGbeWord16(((DESTINATION_MAC >> 8) & 0xff00) + ((DESTINATION_MAC >> 24) & 0xff))
    print(hex(((DESTINATION_MAC >> 8) & 0xff00) + ((DESTINATION_MAC >> 24) & 0xff)))
    s += pushGbeWord16(((DESTINATION_MAC & 0xff) << 8) + ((DESTINATION_MAC >> 8) & 0xff))
    print(hex(((DESTINATION_MAC & 0xff) << 8) + ((DESTINATION_MAC >> 8) & 0xff)))

    ########## ETH type ##########
    s += pushGbeWord16(((ethType & 0xff) << 8) + (ethType >> 8))

    if payload_words64 is not None:
        for word64 in payload_words64:
            s += pushGbeWord16(word64 & 0xffff)
            s += pushGbeWord16((word64 >> 16) & 0xffff)
            s += pushGbeWord16((word64 >> 32) & 0xffff)
            s += pushGbeWord16((word64 >> 48) & 0xffff)
            # s += pushGbeWord16(word64 & 0xffff, False, True)
            # s += pushGbeWord16((word64 >> 16) & 0xffff, False, True)
            # s += pushGbeWord16((word64 >> 32) & 0xffff, False, True)
            # s += pushGbeWord16((word64 >> 48) & 0xffff, False, True)
    elif payload_words16 is not None:
        for word16 in payload_words16:
            s += pushGbeWord16(word16)
    else:
        print_red("No payload provided to the sendEthPacket() function! exiting..")
        exit(1)

    crc = zlib.crc32(s.encode("8859")) & 0xffffffff
    # print("CRC: " + hex(crc))

    ########## CRC ##########
    pushGbeWord16(crc & 0xffff)
    pushGbeWord16(crc >> 16)

    ########## EOF and carrier extend ##########
    pushGbeWord16(0x3f7fd)

    ########## SEND!! ##########
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.START_TRANSMIT'), 0x1)
    heading("DONE")

# DDU doesn't send the ethernet header at all, and also appends a 16bit packet counter just before the CRC -- that's what this function will do.
def sendDduEthPacket(payload_words64, packet_counter, add_idles = False, send = True, test_readback_mode = False, log_file = None, include_eth_header = False):

    if log_file is not None:
        log_file.write("-------- packet %d --------\n" % packet_counter)

    s = "" # eth frame as char vector, to be used for crc

    ########## preamble and SOF ##########
    pushGbeWord16(0x155FB, log_file)
    pushGbeWord16(0x5555, log_file)
    pushGbeWord16(0x5555, log_file)
    pushGbeWord16(0xD555, log_file)

    if include_eth_header:
        ########## source MAC ##########
        s += pushGbeWord16(((SOURCE_MAC >> 24) & 0xff00) + (SOURCE_MAC >> 40), log_file)
        s += pushGbeWord16(((SOURCE_MAC >> 8) & 0xff00) + ((SOURCE_MAC >> 24) & 0xff), log_file)
        s += pushGbeWord16(((SOURCE_MAC & 0xff) << 8) + ((SOURCE_MAC >> 8) & 0xff), log_file)

        ########## destination MAC (simply use the same as source) ##########
        s += pushGbeWord16(((DESTINATION_MAC >> 24) & 0xff00) + (DESTINATION_MAC >> 40), log_file)
        s += pushGbeWord16(((DESTINATION_MAC >> 8) & 0xff00) + ((DESTINATION_MAC >> 24) & 0xff), log_file)
        s += pushGbeWord16(((DESTINATION_MAC & 0xff) << 8) + ((DESTINATION_MAC >> 8) & 0xff), log_file)

        ########## ETH type ##########
        s += pushGbeWord16(0x7088, log_file)

    for word64 in payload_words64:
        s += pushGbeWord16(word64 & 0xffff, log_file)
        s += pushGbeWord16((word64 >> 16) & 0xffff, log_file)
        s += pushGbeWord16((word64 >> 32) & 0xffff, log_file)
        s += pushGbeWord16((word64 >> 48) & 0xffff, log_file)

    # append filler words if the payload is short to meet the ethernet minimum packet size requirement
    bytes_pushed = len(payload_words64) * 8
    first_filler = True
    while bytes_pushed < 64:
        if first_filler:
            s += pushGbeWord16(0xff00 + bytes_pushed, log_file)
            first_filler = False
        else:
            s += pushGbeWord16(0xffff, log_file)
        bytes_pushed += 2

    s += pushGbeWord16(packet_counter, log_file)

    crc = zlib.crc32(s.encode("8859")) & 0xffffffff
    # print("CRC: " + hex(crc))

    ########## CRC ##########
    pushGbeWord16(crc & 0xffff, log_file)
    pushGbeWord16(crc >> 16, log_file)

    ########## EOF and carrier extend ##########
    pushGbeWord16(0x3f7fd, log_file)
    pushGbeWord16(0x1c5bc, log_file)

    if add_idles:
        for i in range(0, 7):
            pushGbeWord16(0x150bc, log_file)

    ########## SEND!! ##########
    if send and not test_readback_mode:
        wReg(REG_START_TRANSMIT, 0x1)
    print("Packet #%d sent (payload bytes pushed = %d)" % (packet_counter, bytes_pushed))

    if test_readback_mode:
        expected_words16 = []
        expected_words16.append(0x155FB)
        expected_words16.append(0x5555)
        expected_words16.append(0x5555)
        expected_words16.append(0xD555)
        for i in range (0, len(s), 2):
            expected_words16.append(ord(s[i]) + (ord(s[i+1]) << 8))
        expected_words16.append(crc & 0xffff)
        expected_words16.append(crc >> 16)
        expected_words16.append(0x3f7fd)
        for i in range(0, 7):
            expected_words16.append(0x150bc)
        return readBackTest(expected_words16)
    else:
        return True

def pushGbeWord16(word16, logFile = None, verbose = False):
    wReg(REG_PUSH_GBE_DATA, word16)
    if verbose:
        print('pushing ' + hex(word16))
    if logFile is not None:
        logFile.write("%s\n" % hex_padded(word16, 2))
    return chr(word16 & 0xff) + chr((word16 >> 8) & 0xff)

def readBackTest(expected_words16):
    read_words16 = []
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.MANUAL_READ_ENABLE'), 1)
    while (rReg(REG_EMPTY_BUSY) & 0x2) == 0:
        # read_words16.append(read_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.MANUAL_READ')))
        read_words16.append(rReg(REG_MANUAL_READ))
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.MANUAL_READ_ENABLE'), 0)

    if len(read_words16) != len(expected_words16):
        print_red("readback and expected word count doesn't match. Expected %d words, read %d words" % (len(expected_words16), len(read_words16)))
        return False

    for i in range(0, len(read_words16)):
        if read_words16[i] != expected_words16[i]:
            print_red("readback word #%d did not match the expected word. Expected %s, but read %s" % (i, hex_padded(expected_words16[i], 2), hex_padded(read_words16[i], 2)))
            return False

    return True

def sendAutoNegAckPacket():
    # words16_1 = [0x142bc, 0x0000, 0x1b5bc, 0x0000, 0x142bc, 0x0000, 0x1b5bc, 0x0000, 0x142bc, 0x0000, 0x1b5bc, 0x0000] * 100
    # words16_2 = [0x142bc, 0x0040, 0x1b5bc, 0x0040, 0x142bc, 0x0040, 0x1b5bc, 0x0040, 0x142bc, 0x0040, 0x1b5bc, 0x0040] * 100
    words16_2 = [0x195bc, 0xb5b5] * 10000
    # words16 = [0x3fefe] * 100

    write_reg(get_node('BEFE.' + REG_PREFIX + '.GEM_TESTS.GBE_TEST.ENABLE'), 0x1)
    pushNode = get_node('BEFE.' + REG_PREFIX + '.GEM_TESTS.GBE_TEST.PUSH_GBE_DATA')
    transmitNode = get_node('BEFE.' + REG_PREFIX + '.GEM_TESTS.GBE_TEST.START_TRANSMIT')
    for i in range(100000):
        # for word in words16_1:
        #     write_reg(pushNode, word)
        for word in words16_2:
            write_reg(pushNode, word)
        write_reg(transmitNode, 0x1)

    print("Auto neg test packet sent")

def sendDummyEthPacket():
    words16 = []
    # for i in range(0, 23):
    for i in range(0, 64):
        words16.append(0x0000)

    sendStandardEthPacket(None, 0x800, words16)

def sendDummyEmptyDduPacket():
    preamble = [0x155fb, 0x5555, 0x5555, 0xd555]
    dduHeader = [0x4770, 0x7313, 0x04ce, 0x5000, 0x0000, 0x8000, 0x0001, 0x8000, 0x0080, 0x0000, 0x3031, 0x7fff]
    dduTrailer = [0x8000, 0x8000, 0xffff, 0x8000, 0x0000, 0x0000, 0x0000, 0x2010, 0x0080, 0x3a6d, 0x0006, 0xa000]
    padding = [0xff30, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff]
    packet_cnt = [0x04cf]
    crc = [0x30ba, 0xe514]
    # crc = [0xca63, 0xb596]
    eofHmm = [0x3f7fd, 0x1c5bc]

    packetPayload = dduHeader + dduTrailer + padding + packet_cnt


    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.ENABLE'), 0x1)

    for word in preamble:
        pushGbeWord16(word)

    s = ""
    print("packet payload:")
    for word in packetPayload:
        s += pushGbeWord16(word)

    print("crc:")
    for word in crc:
        pushGbeWord16(word)

    print("eof:")
    for word in eofHmm:
        pushGbeWord16(word)

    calcCrc = zlib.crc32(s.encode("8859")) & 0xffffffff
    print("Calculated CRC: " + hex(calcCrc))


    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.START_TRANSMIT'), 0x1)
    heading("DONE")

def sendDummyEthPacketOld():
    heading("Sending a dummy ethernet packet")

    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.ENABLE'), 0x1)

    ########## preamble and SOF ##########
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x155FB)
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x5555)
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x5555)
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0xD555)

    ########## source MAC ##########
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x1500)
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x1417)
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x9e80)

    ########## destination MAC ##########
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x1500)
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x1417)
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x9e80)

    ########## ETH type ##########
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x0008)

    ########## Payload ##########
    for i in range(0, 23):
        write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x0000)

    ########## CRC ##########
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0xabb8)
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x962d)

    ########## EOF and carrier extend ##########
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.PUSH_GBE_DATA'), 0x3f7fd)



    ########## SEND!! ##########
    write_reg(get_node('BEFE.CSC_FED.TEST.GBE_TEST.START_TRANSMIT'), 0x1)
    heading("DONE")

if __name__ == '__main__':
    main()
