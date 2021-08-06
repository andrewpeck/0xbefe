import struct
from common.utils import *
import numpy as np
import time
import os

##########################
######## unpacker ########
##########################

class FedEvent:

    l1Id = None
    bxId = None
    unpackErrors = None

    def __init__(self, words):
        self.words = words
        self.dmbs = []
        self.unpackErrors = []
        self.init()

    # does the absolute minimum to get L1A ID, BX ID, and find DMB blocks and create DMB objects, without unpacking the DMB contents except for some minimal information like crate ID and DMB ID
    def init(self):
        self.l1Id = (int(self.words[0]) >> 32) & 0xffffff
        self.bxId = (int(self.words[0]) >> 20) & 0xfff

        if self.words.size < 6:
            self.errors.append("FED block size is smaller than 6 words (size = %d words)" % self.words.size)

        dmbHeaders = np.where(self.words & 0xf000f000f000f000 == 0x9000900090009000)[0]
        if dmbHeaders.size == 0:
            return
        for i in range(1, dmbHeaders.size):
            self.dmbs.append(DmbEvent(self.words[dmbHeaders[i - 1]:dmbHeaders[i]]))
        self.dmbs.append(DmbEvent(self.words[dmbHeaders[dmbHeaders.size - 1]:self.words.size - 3]))

        for dmb in self.dmbs:
            for err in dmb.unpackErrors:
                self.unpackErrors.append("DMB error (crateId = %d, dmbId = %d): %s" % (dmb.crateId, dmb.dmbId, err))

    def unpackAll(self):
        self.unpackHeader()
        self.unpackTrailer()
        for dmb in self.dmbs:
            dmb.unpackAll()
            for err in dmb.unpackErrors:
                self.unpackErrors.append("DMB error (crateId = %d, dmbId = %d): %s" % (dmb.crateId, dmb.dmbId, err))


    # TODO: implement unpacking of the FED header and trailer
    def unpackHeader(self):
        pass

    def unpackTrailer(self):
        misalignedDmb = (int(self.words[words.size - 1]) >> 59) & 0x1
        if misalignedDmb == 1:
            self.unpackErrors.append("64bit misalignment bit set in FED trailer")


class DmbEvent:

    crateId = 0
    dmbId = 0
    l1Id = 0
    bxId = 0
    unpackErrors = None

    def __init__(self, words):
        self.words = words
        self.cfebs = []
        self.unpackErrors = []
        self.init()

    def init(self):
        if self.words.size < 4:
            self.unpackErrors.append("DMB block size is smaller than 4 words (size = %d words)" % self.words.size)
        else:
            self.crateId = (int(self.words[1]) >> 20) & 0xff
            self.dmbId = (int(self.words[1]) >> 16) & 0xf

    def unpackAll(self):
        if len(self.unpackErrors) > 0:
            return

        self.unpackHeader()
        self.unpackTrailer()

        cfebBlockIdx = 2
        trigHeaders = np.where(self.words & 0xf000f000f000f000 == 0xd000d000d000d000)[0]
        #TODO: unpack the ALCT and TMB
        if trigHeaders.size > 0:
            cfebBlockIdx = trigHeaders[trigHeaders.size - 1] + 1

        cfebIdx = 1
        while cfebBlockIdx + 25*8 <= self.words.size - 2:
            cfeb = CfebEvent(self.words[cfebBlockIdx:cfebBlockIdx+25*8])
            cfeb.unpackAll()
            for err in cfeb.unpackErrors:
                self.unpackErrors.append("CFEB #%d error: %s" % (cfebIdx, err))

            self.cfebs.append(cfeb)
            cfebIdx += 1
            cfebBlockIdx += 25*8

        if cfebBlockIdx != self.words.size - 2:
            self.unpackErrors.append("CFEB #%d block did not end in the correct place: CFEB block start word idx = %d, expected CFEB block end word idx = %d, first DMB trailer word idx = %d" % (cfebIdx, cfebBlockIdx, cfebBlockIdx+25*8, self.words.size - 2))

    # TODO: implement unpacking of the DMB header and trailer
    def unpackHeader(self):
        head1 = int(self.words[0])
        head2 = int(self.words[1])
        self.l1Id = ((head1 & 0xfff0000) >> 4) + (head1 & 0xfff)
        self.bxId = (head1 >> 48) & 0xfff


    def unpackTrailer(self):
        pass

    def printDmbInfo(self):
        print("Crate %d DMB %d" % (self.crateId, self.dmbId))

class AlctEvent:

    def __init__(self, words):
        self.words = words
        self.unpackErrors = []
        self.init()

    def init(self):
        pass

    # TODO: implement unpacking of the ALCT data
    def unpackAll(self):
        pass

class TmbEvent:

    def __init__(self, words):
        self.words = words
        self.unpackErrors = []
        self.init()

    def init(self):
        pass

    # TODO: implement unpacking of the TMB data
    def unpackAll(self):
        pass

class CfebEvent:

    l1Id = None

    def __init__(self, words):
        self.words = words
        self.unpackErrors = []
        self.timeSamples = []
        self.init()

    def init(self):
        if self.words.size < 25*8:
            self.unpackErrors.append("CFEB block size is smaller than 25*8 words: %d" % self.words.size)

    # TODO: implement unpacking of the CFEB data
    def unpackAll(self):
        if len(self.unpackErrors) > 0:
            return

        for i in range(0, 8):
            timeSample = CfebTimeSample(self.words[i*25:(i+1)*25])
            timeSample.unpackAll()
            for err in timeSample.unpackErrors:
                self.unpackErrors.append("Time sample #%d error: %s" % (i, err))
            self.timeSamples.append(timeSample)
            if self.l1Id is None:
                self.l1Id = timeSample.l1Id
            # elif self.l1Id != timeSample.l1Id:
            #     self.unpackErrors.append("Time sample #%d has a different L1 ID than others: expected %d, but got %d" % (i, self.l1Id, timeSample.l1Id))


class CfebTimeSample:

    l1Id = 0

    def __init__(self, words):
        self.words = words
        self.unpackErrors = []
        self.init()

    def init(self):
        pass

    # TODO: implement full unpacking of the CFEB time sample
    def unpackAll(self):
        trail = int(self.words[self.words.size - 1])
        self.l1Id = (trail >> 38) & 0x3f

def unpackFile(localDaqFilename, removeEmptyEvents = False, removeDmbs = []):

    # read the whole file into a numpy array
    print("Reading the file")
    f = open(localDaqFilename, 'rb')
    raw = np.fromfile(f, dtype=np.dtype('u8'))
    f.close()

    eoes = np.where(raw==0x8000ffff80008000)

    print("Unpacking events")
    events = []
    start = 0
    i = 0
    for eoe in eoes[0]:
        event = FedEvent(raw[start:eoe+3])
        if removeEmptyEvents:
            dmbsToRemove = []
            for j in range(0, len(event.dmbs)):
                if [event.dmbs[j].crateId, event.dmbs[j].dmbId] in removeDmbs:
                    dmbsToRemove.append(j)
            for j in reversed(dmbsToRemove):
                del event.dmbs[j]
            if len(event.dmbs) > 0:
                events.append(event)
        else:
            events.append(event)
        start = eoe + 3
        i += 1
        if (i % 1000 == 0):
            print("%d events unpacked (out of %d)" % (i, eoes[0].size))


    # for i in range(0, 20):
    #     print("=============== event %d, L1 ID %d ===============" % (i, events[i].l1Id))
    #     for dmb in events[i].dmbs:
    #         dmb.printDmbInfo()

    print("=============== DONE ===============")
    print("read %d bytes" % (raw.size * 8))
    print("unpacked %d events" % len(events))

    return events

def checkEventErrors(event):
    errors = []
    event.unpackAll()
    errors += event.unpackErrors

    for dmb in event.dmbs:
        # check L1 ID consistency
        if dmb.l1Id != event.l1Id:
            errors.append("DMB (crate %d dmb %d) L1A ID doesn't match the FED L1A ID: FED = %d, DMB = %d" % (dmb.crateId, dmb.dmbId, event.l1Id, dmb.l1Id))
        for cfebIdx in range(0, len(dmb.cfebs)):
            cfeb = dmb.cfebs[cfebIdx]
            if cfeb.l1Id != (dmb.l1Id & 0x3f):
                pass
                # errors.append("CFEB #%d (crate %d dmb %d) L1A ID doesn't match the DMB L1A ID: DMB = %d, CFEB = %d, CFEB expected = %d" % (cfebIdx, dmb.crateId, dmb.dmbId, dmb.l1Id, cfeb.l1Id, dmb.l1Id & 0x3f))
        # check BX ID consistency
        # if dmb.bxId != event.bxId:
        #     errors.append("DMB (crate %d dmb %d) BX ID doesn't match the FED BX ID: FED = %d, DMB = %d" % (dmb.crateId, dmb.dmbId, event.bxId, dmb.bxId))

        #check that the DMB trailer words have the correct DDU codes
        if dmb.words[dmb.words.size - 2] & 0xf000f000f000f000 != 0xf000f000f000f000 or dmb.words[dmb.words.size - 1] & 0xf000f000f000f000 != 0xe000e000e000e000:
            errors.append("DMB (crate %d dmb %d) trailer words don't have the correct DDU codes, suspect that it's misaligned with 64bit boundaries: trailer1 = %s, trailer2 = %s" % (dmb.crateId, dmb.dmbId, hex_padded64(dmb.words[dmb.words.size - 2]), hex_padded64(dmb.words[dmb.words.size - 1])))


        # TODO: check L1 ID consistency of ALCT and TMB

    # TODO: implement many other consistency checks, including perhaps also the CRC checking..

    return errors

##########################
######## raw utils ########
##########################
def dduReadEventRaw(file, eventIdx):

    words = []
    word = 0
    lastWord = 0
    # look for beginning of the event with requested index
    while ((word & 0xffffffffffff0000) != 0x8000000180000000) or (lastWord & 0xf000000000000000 != 0x5000000000000000) or (((lastWord >> 32) & 0xffffff != eventIdx) and (eventIdx is not None)):
        lastWord = word
        wordStr = file.read(8)
        if (len(wordStr) < 8):
            return words
        word = struct.unpack("Q", wordStr)[0]

    words.append(lastWord)
    words.append(word)

    #read the current event until the DDU trailer2
    while (word != 0x8000ffff80008000):
        wordStr = file.read(8)
        if (len(wordStr) < 8):
            return words
        word = struct.unpack("Q", wordStr)[0]
        words.append(word)

    # read the last two ddu trailer words
    words.append(struct.unpack("Q", file.read(8))[0])
    words.append(struct.unpack("Q", file.read(8))[0])

    return words

def dumpEvents(cfedEvent, dduEvent):
    cfedLen = len(cfedEvent)
    dduLen = len(dduEvent)
    length = cfedLen
    if (dduLen > length):
        length = dduLen

    line = ""
    for i in range(0, length):
        line = hex_padded(i*8, 2) + ":   "
        if (i < cfedLen):
            # line = hex_padded(cfedEvent[i], 8, False)
            line += hex_padded((cfedEvent[i] >> 48) & 0xffff, 2, False) + " " + hex_padded((cfedEvent[i] >> 32) & 0xffff, 2, False) + " " + hex_padded((cfedEvent[i] >> 16) & 0xffff, 2, False) + " " + hex_padded(cfedEvent[i] & 0xffff, 2, False)
        else:
            line = "                  "

        line += "  ----  "

        if (i < dduLen):
            # line += hex_padded(dduEvent[i], 8, False)
            line += hex_padded((dduEvent[i] >> 48) & 0xffff, 2, False) + " " + hex_padded((dduEvent[i] >> 32) & 0xffff, 2, False) + " " + hex_padded((dduEvent[i] >> 16) & 0xffff, 2, False) + " " + hex_padded(dduEvent[i] & 0xffff, 2, False)

        if (i < cfedLen) and (i < dduLen) and (cfedEvent[i] != dduEvent[i]):
            print_red(line)
        else:
            print(line)

def dumpEventsNumpy(words1, words2, annotateWords1 = True, maxSize = 5000):
    len1 = words1.size
    len2 = 0
    if words2 is not None:
        len2 = words2.size

    length = len1
    if (len2 > len1):
        length = len2
    if length > maxSize:
        length = maxSize

    line = ""
    dmbHead2Idx = -9999
    alctHeadIdx = None
    alctTrailIdx = None
    tmbHeadIdx = None
    tmbTrailIdx = None
    cfebData = False
    cfebWordCnt = 0
    dmbTrail2Idx = None
    for i in range(0, length):
        line = hex_padded(i*8, 2) + ":   "
        if (i < len1):
            line += hex_padded((int(words1[i]) >> 48) & 0xffff, 2, False) + " " + hex_padded((int(words1[i]) >> 32) & 0xffff, 2, False) + " " + hex_padded((int(words1[i]) >> 16) & 0xffff, 2, False) + " " + hex_padded(int(words1[i]) & 0xffff, 2, False)
            if annotateWords1:
                if  (int(words1[i]) & 0xf000f000f000f000) == 0xa000a000a000a000:
                    dmbHead2Idx = i
                    cfebData = False
                    cfebWordCnt = 0
                elif (int(words1[i]) & 0xf000f000f000f000) == 0xe000e000e000e000:
                    dmbTrail2Idx = i
                elif (int(words1[i]) & 0xf000f000f000ffff) == 0xd000d000d000db0a:
                    alctHeadIdx = i
                elif (int(words1[i]) & 0xf000f000f000ffff) == 0xd000d000d000de0d:
                    alctTrailIdx = i
                elif (int(words1[i]) & 0xf000f000f000ffff) == 0xd000d000d000db0c:
                    tmbHeadIdx = i
                elif (int(words1[i]) & 0xf000f000f000ffff) == 0xd000d000d000de0f:
                    tmbTrailIdx = i

                if ((dmbHead2Idx == i - 1) and (alctHeadIdx is None) and (tmbHeadIdx is None)) or \
                   ((alctTrailIdx is not None) and (alctTrailIdx == i -1) and (tmbHeadIdx is None)) or \
                   ((tmbTrailIdx is not None) and (tmbTrailIdx == i - 1)):
                    cfebData = True

                if cfebData:
                    cfebWordCnt += 1
        else:
            line = "                  "

        if words2 is not None:
            line += "  ----  "

            if (i < len2):
                line += hex_padded((int(words2[i]) >> 48) & 0xffff, 2, False) + " " + hex_padded((int(words2[i]) >> 32) & 0xffff, 2, False) + " " + hex_padded((int(words2[i]) >> 16) & 0xffff, 2, False) + " " + hex_padded(int(words2[i]) & 0xffff, 2, False)

        if annotateWords1:
            if dmbHead2Idx == i:
                line += "   <=== DMB HEADER #2"
            elif dmbTrail2Idx == i:
                line += "   <=== DMB TRAILER #2"
            elif alctHeadIdx == i:
                line += "   <=== ALCT HEADER"
            elif alctTrailIdx == i:
                line += "   <=== ALCT TRAILER"
            elif tmbHeadIdx == i:
                line += "   <=== TMB HEADER"
            elif tmbTrailIdx == i:
                line += "   <=== TMB TRAILER"
            elif (cfebWordCnt > 0) and (cfebWordCnt % 25 == 0):
                line += "   <=== CFEB SAMPLE %d TRAILER" % int(cfebWordCnt / 25)

        if words2 is not None and (i < len1) and (i < len2) and (words1[i] != words2[i]):
            print_red(line)
        else:
            print(line)

def printRawWords(words64):
    i = 0
    for word in words64:
        print("%d\t: %s" % (i, hex_padded64(word)))
        i += 1

#given a local daq raw file pattern, which can include a * for the part number (last number in the filename), this returns all available filenames
def getAllLocalDaqRawFiles(rawFilenamePattern, maxFiles = None):
    ret = []
    if '*' in rawFilenamePattern:
        partIdx = 0
        filename = rawFilenamePattern.replace("*", "%03d" % partIdx)
        while os.path.isfile(filename):
            ret.append(filename)
            partIdx += 1
            if maxFiles is not None and (partIdx >= maxFiles):
                break
            filename = rawFilenamePattern.replace("*", "%03d" % partIdx)
    else:
        ret.append(rawFilenamePattern)

    return ret
