import signal
import sys
import os
import struct
import numpy as np
from time import *
from random import randint
import tkinter
import matplotlib.pyplot as plt

PRESCALE = 1

BX_PER_SECOND = int(40079000 / PRESCALE)

L1A_RATE = int(750000 / PRESCALE)

# 9 board setup
INPUT_TYPES = ["ME1/1", "ME1/1", "ME1/1", "ME1/1", "ME1/1", "ME1/1", "ME1/1", "ME1/1",
               "ME1/2", "ME1/2", "ME1/2", "ME1/2", "ME1/2", "ME1/2", "ME1/2", "ME1/2",
               "ME1/3", "ME1/3", "ME1/3", "ME1/3", "ME1/3", "ME1/3", "ME1/3", "ME1/3",
               "ME2/1", "ME2/1", "ME2/1", "ME2/1",
               "ME2/2", "ME2/2", "ME2/2", "ME2/2", "ME2/2", "ME2/2", "ME2/2", "ME2/2",
               "ME3/1", "ME3/1", "ME3/1", "ME3/1",
               "ME3/2", "ME3/2", "ME3/2", "ME3/2", "ME3/2", "ME3/2", "ME3/2", "ME3/2",
               "ME4/1", "ME4/1", "ME4/1", "ME4/1",
               "ME4/2", "ME4/2", "ME4/2", "ME4/2", "ME4/2", "ME4/2", "ME4/2", "ME4/2"]

# old estimates
# DATA_RATES_MBPS = {"ME1/1": 9600/PRESCALE, "ME2/1": 6400/PRESCALE, "ME3/1": 3600/PRESCALE, "ME4/1": 3500/PRESCALE, "ME1/2": 600/PRESCALE, "ME1/3": 100/PRESCALE, "ME2/2": 400/PRESCALE, "ME3/2": 400/PRESCALE, "ME4/2": 900/PRESCALE} # data rate in Mb/s
# BANDWIDTH_BPBX = {"ME1/1": 200*4, "ME2/1": 200*3, "ME3/1": 200*2, "ME4/1": 200*2, "ME1/2": 32, "ME1/3": 32, "ME2/2": 32, "ME3/2": 32, "ME4/2": 32} # link bandwidth in bits per BX
# OUTPUT_BANDWDIDTH_BPBX = 5000 # 200Gb/s per card

# new estimates
DATA_RATES_MBPS = {"ME1/1": 24200/PRESCALE, "ME2/1": 6400/PRESCALE, "ME3/1": 3600/PRESCALE, "ME4/1": 3500/PRESCALE, "ME1/2": 600/PRESCALE, "ME1/3": 100/PRESCALE, "ME2/2": 400/PRESCALE, "ME3/2": 400/PRESCALE, "ME4/2": 900/PRESCALE} # data rate in Mb/s
# DATA_RATES_MBPS = {"ME1/1": 24200/PRESCALE, "ME2/1": 8900/PRESCALE, "ME3/1": 8000/PRESCALE, "ME4/1": 6000/PRESCALE, "ME1/2": 1700/PRESCALE, "ME1/3": 100/PRESCALE, "ME2/2": 300/PRESCALE, "ME3/2": 500/PRESCALE, "ME4/2": 1100/PRESCALE} # data rate in Mb/s
BANDWIDTH_BPBX = {"ME1/1": 250*4, "ME2/1": 250*3, "ME3/1": 250*2, "ME4/1": 250*2, "ME1/2": 32, "ME1/3": 32, "ME2/2": 32, "ME3/2": 32, "ME4/2": 32} # link bandwidth in bits per BX
OUTPUT_BANDWDIDTH_BPBX = 10000 # 400Gb/s per card

INPUT_LATENCY_BX = 220 # 5.5us, which is the time it takes to send one full DCFEB packet to ODMB + 0.5us of delay over the fiber (I'm not sure if this is a correct thing to use, should check ODMB firmware to see when it starts sending an event)

CONSTANT_DATA_SIZE = 23424
CFEB_DATA_SIZE = 12800

DAQ_HEADER_SIZE_BITS = 384
DAQ_TRAILER_SIZE_BITS = 384

frontend_buffers = []
input_buffers = []

daq = None

max_buf_usage = []
total_buf_usage = np.zeros(shape=(BX_PER_SECOND), dtype="uint32")

input_data_rate = np.zeros(shape=(BX_PER_SECOND), dtype="uint16")
output_data_rate = np.zeros(shape=(BX_PER_SECOND), dtype="uint16")

class Daq:

    output_bandwidth_bpbx = 3000
    header_size_bits = 384
    trailer_size_bits = 384

    l1a_fifo = []
    state = "IDLE"
    header_bits_sent = 0
    trailer_bits_sent = 0
    l1a = -1
    input_idx = 0

    def __init__(self, outputBandwidthBpbx, headerSize, trailerSize):
        self.output_bandwidth_bpbx = outputBandwidthBpbx
        self.header_size_bits = headerSize
        self.trailer_size_bits = trailerSize
        self.l1a_fifo = []
        self.state = "IDLE"
        self.header_bits_sent = 0
        self.trailer_bits_sent = 0
        self.l1a = -1
        self.input_idx = 0

    def addL1a(self, l1aId):
        self.l1a_fifo.append(l1aId)

    def runOneBx(self, inputBuffers):
        bitsToSend = self.output_bandwidth_bpbx

        while bitsToSend > 0:
            if self.state == "IDLE":
                self.header_bits_sent = 0
                self.trailer_bits_sent = 0
                self.input_idx = 0

                if len(self.l1a_fifo) == 0:
                    return self.output_bandwidth_bpbx - bitsToSend
                else:
                    if not self.allBuffersHaveL1a(self.l1a_fifo[0], inputBuffers):
                        return self.output_bandwidth_bpbx - bitsToSend

                    self.l1a = self.l1a_fifo[0]
                    del self.l1a_fifo[0]
                    self.header_bits_sent = 0
                    self.trailer_bits_sent = 0
                    self.state = "HEADER"

            elif self.state == "HEADER":
                if bitsToSend > self.header_size_bits - self.header_bits_sent:
                    bitsToSend -= self.header_size_bits - self.header_bits_sent
                    self.header_bits_sent = self.header_size_bits
                    self.state = "SENDING_DATA"
                else:
                    self.header_bits_sent = bitsToSend
                    bitsToSend = 0

            elif self.state == "SENDING_DATA":
                (is_bits_left, bits_read) = inputBuffers[self.input_idx].readEvent(self.l1a, bitsToSend)
                bitsToSend -= bits_read
                if not is_bits_left:
                    inputBuffers[self.input_idx].removeL1a(self.l1a)
                    if self.input_idx == len(inputBuffers) - 1:
                        self.state = "TRAILER"
                    else:
                        self.input_idx += 1

            elif self.state == "TRAILER":
                if bitsToSend > self.trailer_size_bits - self.trailer_bits_sent:
                    bitsToSend -= self.trailer_size_bits - self.trailer_bits_sent
                    self.trailer_bits_sent = self.trailer_size_bits
                    self.state = "IDLE"
                else:
                    self.trailer_bits_sent = bitsToSend
                    bitsToSend = 0

        return self.output_bandwidth_bpbx - bitsToSend

    def allBuffersHaveL1a(self, l1aId, inputBuffers):
        for i in range(len(inputBuffers)):
            if (inputBuffers[i].getFirstL1A() != l1aId) or (not inputBuffers[i].getEvent(l1aId).is_complete):
                return False

        return True

class Buffer:

    bit_cnt = 0
    events = {}
    l1as = []

    def __init__(self):
        self.bit_cnt = 0
        self.events = {}
        self.l1as = []

    def addEvent(self, event):
        self.events[event.l1a_id] = event
        self.bit_cnt += event.size
        self.l1as.append(event.l1a_id)

    def addBitsToEvent(self, bxId, l1aId, numBits, isSetComplete):
        if l1aId not in self.events:
            self.addEvent(Event(bxId, l1aId, numBits, isSetComplete))
        event = self.events[l1aId]
        event.addBits(numBits)
        self.bit_cnt += numBits
        if isSetComplete:
            event.setComplete(True)

    def readEvent(self, l1aId, numBits):
        if l1aId in self.events:
            event = self.events[l1aId]
            (is_bits_left, bits_read) = event.read(numBits)
            if not is_bits_left:
                del self.events[l1aId]
            self.bit_cnt -= bits_read
            return is_bits_left, bits_read
        else:
            return False, 0

    def getEvent(self, l1aId):
        return self.events[l1aId]

    def isCompleteEvent(self, l1aId):
        if l1aId in self.events:
            return self.events[l1aId].is_complete
        else:
            return False

    def removeL1a(self, l1aId):
        if (self.l1as[0] == l1aId):
            del self.l1as[0]
        else:
            raise "Attempting to delete L1A from a buffer which is not the first L1A in the FIFO"

    def getFirstL1A(self):
        if (len(self.l1as) > 0):
            return self.l1as[0]
        else:
            return -1

    def getNumBits(self):
        return self.bit_cnt

class Event:

    bx_id = 0
    l1a_id = 0
    size = 0
    is_complete = False

    def __init__(self, bxId, l1aId, size, isComplete):
        self.bx_id = bxId
        self.l1a_id = l1aId
        self.size = size
        self.is_complete = isComplete

    def read(self, numBits):
        if self.size > numBits:
            self.size -= numBits
            return True, numBits
        else:
            size_before = self.size
            self.size = 0
            return False, size_before

    def addBits(self, numBits):
        self.size += numBits

    def setComplete(self, isComplete):
        self.is_complete = isComplete

def main():

    for i in range(len(INPUT_TYPES)):
        frontend_buffers.append(Buffer())
        input_buffers.append(Buffer())
        max_buf_usage.append(0)

    global daq
    daq = Daq(OUTPUT_BANDWDIDTH_BPBX, DAQ_HEADER_SIZE_BITS, DAQ_TRAILER_SIZE_BITS)

    # global buf_usage
    # buf_usage = np.zeros(shape=(len(INPUT_TYPES), BX_PER_SECOND), dtype="uint32")

    t1 = time()

    runOneSecond()

    printStats()

    t2 = time()

    print("time took: %fs" % (t2 - t1))

def runOneSecond():
    print("generating L1As")
    bx_l1a_id = [-1] * BX_PER_SECOND
    for i in range(L1A_RATE):
        bx_id = randint(0, BX_PER_SECOND - 1)
        while bx_l1a_id[bx_id] >= 0:
            bx_id = randint(0, BX_PER_SECOND - 1)
        bx_l1a_id[bx_id] = i

    print("sorting L1As")
    l1a_id = 0
    for bx in range(BX_PER_SECOND):
        if bx_l1a_id[bx] >= 0:
            bx_l1a_id[bx] = l1a_id
            l1a_id += 1

    print("generating input events")
    input_data = []
    for i in range(len(INPUT_TYPES)):
        input_data.append({})
        input_type = INPUT_TYPES[i]
        data_to_send = DATA_RATES_MBPS[input_type] * 1000000
        while data_to_send > 0:
            #this is just using a simple constant event size, this has to be changed of course
            l1a_id = randint(0, L1A_RATE - 1)
            if l1a_id in input_data[i]:
                # TODO: in this case consider adding a smaller amount e.g. something like one more CFEB worth of data
                input_data[i][l1a_id] += CFEB_DATA_SIZE
                data_to_send -= CFEB_DATA_SIZE
            else:
                input_data[i][l1a_id] = CONSTANT_DATA_SIZE
                data_to_send -= CONSTANT_DATA_SIZE

            # while l1a_id in input_data[i]:
            #     l1a_id = randint(0, L1A_RATE - 1)
            # input_data[i][l1a_id] = CONSTANT_DATA_SIZE

    print("start clocking DAQ")
    for bx in range(BX_PER_SECOND):
        if bx % 10000 == 0:
            print("processing bx #%d" % bx)

        l1a_id = bx_l1a_id[bx]

        # L1A
        if l1a_id != -1:
            daq.addL1a(l1a_id)
            for i in range(len(INPUT_TYPES)):
                size = 0
                if l1a_id in input_data[i]:
                    size = input_data[i][l1a_id]
                event = Event(bx, l1a_id, size, True)
                frontend_buffers[i].addEvent(event)

        # frontend to FED
        total_bits_received = 0
        for i in range(len(INPUT_TYPES)):
            first_l1a = frontend_buffers[i].getFirstL1A()
            if (first_l1a != -1) and (bx - frontend_buffers[i].getEvent(first_l1a).bx_id >= INPUT_LATENCY_BX):
                (is_bits_left, bits_read) = frontend_buffers[i].readEvent(first_l1a, BANDWIDTH_BPBX[INPUT_TYPES[i]])
                if not is_bits_left:
                    frontend_buffers[i].removeL1a(first_l1a)
                input_buffers[i].addBitsToEvent(bx, first_l1a, bits_read, not is_bits_left)
                total_bits_received += bits_read

        input_data_rate[bx] = total_bits_received

        # execute DAQ logic
        bits_sent = daq.runOneBx(input_buffers)
        output_data_rate[bx] = bits_sent

        #collect stats
        collectStats(bx)

def collectStats(bx):

    total_buf = 0
    for i in range(len(input_buffers)):
        bits_used = input_buffers[i].getNumBits()
        total_buf += bits_used
        # buf_usage[i, bx] = bits_used
        if bits_used > max_buf_usage[i]:
            max_buf_usage[i] = bits_used

    total_buf_usage[bx] = total_buf

def printStats():

    max_total = 0
    print("max buffer usage per input:")
    for i in range(len(max_buf_usage)):
        print("    %d (%s): %d" % (i, INPUT_TYPES[i], max_buf_usage[i]))
        max_total += max_buf_usage[i]
    print("Max total buffer usage: %dMb" % (max_total/1000000))


    # fig = plt.figure(figsize=(30, 30))
    # ax = plt.axes()
    # x = np.linspace(0, BX_PER_SECOND - 1, BX_PER_SECOND, dtype="uint32")
    # ax.plot(x, input_data_rate)
    # ax.plot(x, output_data_rate)
    # # plt.plot(np.linspace(0, 9, 10, dtype="uint16"), np.linspace(0, 9, 10, dtype="uint16"))
    # fig.show()

    # tk = tkinter.Tk()

    fig = plt.figure(figsize=(30, 30))
    ax = plt.axes()
    x = np.linspace(0, BX_PER_SECOND - 1, BX_PER_SECOND, dtype="uint32")
    ax.plot(x, total_buf_usage)
    plt.show()
    # fig.show()

    # tk.mainloop()

if __name__ == '__main__':
    main()
