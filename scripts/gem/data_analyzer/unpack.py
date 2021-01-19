#!/usr/bin/env python

from utils import *
import signal
import sys
import os
import fnmatch
import struct
import zlib
import math
import analyze_events
from enum import Enum

IS_MINIDAQ_FORMAT = False
VERBOSE = False
DEBUG = False

class Error(Enum):
    AMC_BUF_STATUS = 1
    AMC_TTS_STATE = 2
    AMC_DAV_TIMEOUT = 3
    AMC_DAQLINK_FULL = 4
    AMC_MMCM_UNLOCKED = 5
    AMC_DAQ_CLK_UNLOCKED = 6
    AMC_DAQ_NOT_READY = 7
    AMC_BC0_NOT_LOCKED = 8

    CHAMBER_EVT_FIFO_FULL = 51
    CHAMBER_IN_FIFO_FULL = 52
    CHAMBER_L1A_FIFO_FULL = 53
    CHAMBER_EVENT_SIZE_OVF = 54
    CHAMBER_EVT_FIFO_NEAR_FULL = 55
    CHAMBER_IN_FIFO_NEAR_FULL = 56
    CHAMBER_L1A_FIFO_NEAR_FULL = 57
    CHAMBER_EVT_SIZE_MORE_THAN_24 = 58
    CHAMBER_NO_VFAT_MARKER = 59
    CHAMBER_EVT_FIFO_UNF = 60
    CHAMBER_IN_FIFO_UNF = 61
    CHAMBER_NUM_VFATS_NOT_24 = 62

    VFAT_BC_MISMATCH = 101
    VFAT_BAD_HEADER = 102
    VFAT_WARNING = 103
    VFAT_CRC_ERR = 104

class Amc13(object):

    #header data
    headerMarker1 = None # should be 0x5
    headerMarker2 = None # should be 0x0
    eventType = None
    l1aId = None
    bxId = None
    fedId = None
    numberAmcs = None
    orbitId = None

    amcBlockSizes = []
    amcIds = []

    #trailer data
    trailerMarker = None # should be 0xa
    eventLength = None
    eventStatus = None
    ttsState = None

    amcs = []

    def __init__(self):
        self.amcs = []
        self.amcBlockSizes = []
        self.amcIds = []

    def unpackAmc13Block(self, str, verbose=False):
        # pad with zeros if necessary to align to 64bit boundary
        while len(str) % 8 != 0:
            if verbose:
                print "adding a zero at the end of the string to align to 64bit boundary"
            str += '\0'

        words = struct.unpack("%dQ" % int(len(str) / 8), str)

        idx = self.unpackAmc13Header(words, 0, verbose)

        for i in range(len(self.amcIds)):
            amc = GemAmc(self)
            self.amcs.append(amc)
            idx_before = idx
            idx = amc.unpackGemAmcBlock(words, idx, verbose)
            if (amc.prematureEoeReached):
                idx = idx_before + self.amcBlockSizes[i]

        idx = self.unpackAmc13Trailer(words, idx, verbose)

    def unpackAmc13Header(self, words, idx, verbose=False):
        self.headerMarker1 = (words[idx] >> 60) & 0xf
        self.eventType = (words[idx] >> 56) & 0xf
        self.l1aId = (words[idx] >> 32) & 0xffffff
        self.bxId = (words[idx] >> 20) & 0xfff
        self.fedId = (words[idx] >> 8) & 0xfff
        idx += 1
        self.numberAmcs = (words[idx] >> 52) & 0xf
        self.orbitId = (words[idx] >> 4) & 0xffffffff
        self.headerMarker2 = (words[idx] >> 0) & 0xf
        idx += 1

        for i in range(self.numberAmcs):
            self.amcBlockSizes.append((words[idx] >> 32) & 0xffffff)
            self.amcIds.append((words[idx] >> 16) & 0xf)
            idx += 1

        if verbose:
            self.printAmc13Header()

        return idx

    def unpackAmc13Trailer(self, words, idx, verbose=False):
        idx += 1
        self.trailerMarker = (words[idx] >> 60) & 0xf
        self.eventLength = (words[idx] >> 32) & 0xffffff
        self.eventStatus = (words[idx] >> 8) & 0xf
        self.ttsState = (words[idx] >> 4) & 0xf

        if verbose:
            self.printAmc13Trailer()

        return idx


    def printAmc13Header(self):
        printCyan("--------------------------------------")
        printCyan("AMC13 Header")
        printCyan("--------------------------------------")
        printGreenRed("Header marker1: %s" % hexPadded(self.headerMarker1, 0.5), self.headerMarker1, 0x5)
        printGreenRed("Header marker2: %s" % hexPadded(self.headerMarker2, 0.5), self.headerMarker2, 0x0)
        print "Event type: %s" % hexPadded(self.eventType, 0.5)
        print "FED ID: %s" % hexPadded(self.fedId, 1.5)
        print "Number of AMCs: %d" % self.numberAmcs
        print "L1A ID: %d" % self.l1aId
        print "BX ID: %d" % self.bxId
        print "Orbit ID: %d" % self.orbitId

        print "AMC block data:"
        for i in range(self.numberAmcs):
            print "    Slot %d, size = %d" % (self.amcIds[i], self.amcBlockSizes[i])


    def printAmc13Trailer(self):
        printCyan("--------------------------------------")
        printCyan("AMC13 Trailer")
        printCyan("--------------------------------------")
        printGreenRed("Trailer marker: %s" % hexPadded(self.trailerMarker, 0.5), self.trailerMarker, 0xa)
        printGreenRed("TTS state: %s" % hexPadded(self.ttsState, 0.5), self.ttsState, 0x8)
        print "Event status: %s" % hexPadded(self.eventStatus, 0.5)
        print "Event length: %d" % self.eventLength


    def printEvent(self):
        self.printAmc13Header()
        for amc in self.amcs:
            amc.printEvent()
        self.printAmc13Trailer()


    def hasError(self, verbose):
        for amc in self.amcs:
            if amc.hasError(verbose):
                return True
        return False

class GemAmc(object):

    amc13 = None

    #header data
    amcNum = None
    l1aId = None
    bxId = None
    formatVersion = None
    runType = None
    runParams = None
    orbitId = None
    boardId = None
    davList = None
    bufStatus = None
    davCount = None
    ttsState = None

    #trailer data
    davTimeoutFlags = None
    daqAlmostFull = None
    mmcmLocked = None
    daqClkLocked = None
    daqReady = None
    bc0Locked = None
    l1aIdTrail = None
    wordCnt = None

    #errors
    prematureEoeReached = False

    chambers = []

    def __init__(self, amc13):
        self.amc13 = amc13
        self.chambers = []
        pass

    def unpackGemAmcBlockStr(self, str, verbose=False):
        # pad with zeros if necessary to align to 64bit boundary
        while len(str) % 8 != 0:
            if verbose:
                print "adding a zero at the end of the string to align to 64bit boundary"
            str += '\0'

        words = struct.unpack("%dQ" % int(len(str) / 8), str)

    def unpackGemAmcBlock(self, words, idx, verbose=False):
        idx = self.unpackGemAmcHeader(words, idx, verbose)
        idx = self.unpackGemEventHeader(words, idx, verbose)
        chamberIdx = 0
        while chamberIdx < self.davCount:
            chamber = GemChamber(self, chamberIdx)
            self.chambers.append(chamber)
            chamberIdx += 1
            idx = chamber.unpackGemChamberBlock(words, idx, verbose)
            if (chamber.prematureEoeReached):
                self.prematureEoeReached = True
                return idx

        idx = self.unpackGemEventTrailer(words, idx, verbose)
        idx = self.unpackGemAmcTrailer(words, idx, verbose)

        return idx

    def unpackGemAmcHeader(self, words, idx, verbose=False):
        self.amcNum = (words[idx] >> 56) & 0xf
        self.l1aId = (words[idx] >> 32) & 0xffffff
        self.bxId = (words[idx] >> 20) & 0xfff
        idx += 1
        self.formatVersion = (words[idx] >> 60) & 0xf
        self.runType = (words[idx] >> 56) & 0xf
        self.runParams = (words[idx] >> 32) & 0xffffff
        self.orbitId = (words[idx] >> 16) & 0xffff
        self.boardId = (words[idx] >> 0) & 0xffff
        idx += 1

        if verbose:
            self.printGemAmcHeader()

        return idx

    def printGemAmcHeader(self):
        printCyan("--------------------------------------")
        printCyan("AMC Header")
        printCyan("--------------------------------------")
        print "Format version: %d" % self.formatVersion
        print "AMC number: %d" % self.amcNum
        print "Board ID: %s" % hexPadded(self.boardId, 2)
        print "L1A ID: %d" % self.l1aId
        print "Orbit ID: %d" % self.orbitId
        print "BX ID: %d" % self.bxId
        print "Run type: %d" % self.runType
        print "Run params: %s" % hexPadded(self.runParams, 3)

    def unpackGemEventHeader(self, words, idx, verbose=False):
        self.davList = (words[idx] >> 40) & 0xffffff
        self.bufStatus = (words[idx] >> 16) & 0xffffff
        self.davCount = (words[idx] >> 11) & 0x1f
        self.ttsState = (words[idx] >> 0) & 0xf
        idx += 1

        if verbose:
            self.printGemEventHeader()

        return idx

    def printGemEventHeader(self):
        printCyan("--------------------------------------")
        printCyan("GEM Event Header")
        printCyan("--------------------------------------")
        print "DAV count: %d" % self.davCount
        print "DAV list: %s" % hexPadded(self.davList, 3)
        printGreenRed("Buffer status: %s" % hexPadded(self.bufStatus, 3), self.bufStatus, 0)
        printGreenRed("TTS state: %s" % hexPadded(self.ttsState, 1), self.ttsState, 8)
        printGreenRed("Premature EOE reached: %r" % self.prematureEoeReached, self.prematureEoeReached, False)


    def unpackGemEventTrailer(self, words, idx, verbose=False):
        self.davTimeoutFlags = (words[idx] >> 40) & 0xffffff
        self.daqAlmostFull = True if ((words[idx] >> 7) & 0x1) == 1 else False
        self.mmcmLocked = True if ((words[idx] >> 6) & 0x1) == 1 else False
        self.daqClkLocked = True if ((words[idx] >> 5) & 0x1) == 1 else False
        self.daqReady = True if ((words[idx] >> 4) & 0x1) == 1 else False
        self.bc0Locked = True if ((words[idx] >> 3) & 0x1) == 1 else False
        idx += 1

        if verbose:
            self.printGemEventTrailer()

        return idx


    def printGemEventTrailer(self):
        printCyan("--------------------------------------")
        printCyan("GEM Event Trailer")
        printCyan("--------------------------------------")
        printGreenRed("DAV timeout flags: %s" % hexPadded(self.davTimeoutFlags, 3), self.davTimeoutFlags, 0)
        printGreenRed("DAQ almost full: %r" % self.daqAlmostFull, self.daqAlmostFull, False)
        printGreenRed("MMCM locked: %r" % self.mmcmLocked, self.mmcmLocked, True)
        printGreenRed("DAQ clock locked: %r" % self.daqClkLocked, self.daqClkLocked, True)
        printGreenRed("DAQ ready: %r" % self.daqReady, self.daqReady, True)
        printGreenRed("BC0 locked: %r" % self.bc0Locked, self.bc0Locked, True)


    def unpackGemAmcTrailer(self, words, idx, verbose=False):
        self.l1aIdTrail = (words[idx] >> 24) & 0xff
        self.wordCnt = (words[idx] >> 0) & 0xfffff
        idx += 1

        if verbose:
            self.printGemAmcTrailer(idx)

        return idx


    def printGemAmcTrailer(self, idx=-1):
        printCyan("--------------------------------------")
        printCyan("GEM AMC Trailer")
        printCyan("--------------------------------------")
        printGreenRed("L1A ID in the trailer: %d" % self.l1aIdTrail, self.l1aIdTrail, self.l1aId & 0xff)
        if idx == -1:
            print "Total 64bit word count: %d" % self.wordCnt
        else:
            printGreenRed("Total 64bit word count: %d" % self.wordCnt, self.wordCnt, idx)

    def printEvent(self):
        self.printGemAmcHeader()
        self.printGemEventHeader()
        for chamber in self.chambers:
            chamber.printChamber()
        self.printGemEventTrailer()
        self.printGemAmcTrailer()

    def getNumVfatBlocks(self):
        numVfats = 0
        for chamber in self.chambers:
            numVfats += len(chamber.vfats)

        return numVfats

    def hasError(self, verbose):
        ret = False

        if (self.bufStatus != 0 or self.ttsState != 8 or self.davTimeoutFlags != 0 or self.daqAlmostFull or not self.mmcmLocked or not self.daqClkLocked or not self.daqReady or not self.bc0Locked or self.prematureEoeReached):
            if verbose:
                printRed("AMC error:")
                self.printGemAmcHeader()
                self.printGemEventHeader()
                self.printGemEventTrailer()
                self.printGemAmcTrailer()

            ret = True

        for chamber in self.chambers:
            if chamber.hasError(verbose):
                ret = True

        return ret

class GemChamber(object):

    event = None
    chamberIdx = None

    #header data
    zsWordCnt = None
    inputId = None
    vfatWordCnt = None
    evtFifoFull = None
    inFifoFull = None
    l1aFifoFull = None
    evtSizeOvf = None
    evtFifoNearFull = None
    inFifoNearFull = None
    l1aFifoNearFull = None
    evtSizeMoreThan24 = None
    noVfatMarker = None

    #errors
    prematureEoeReached = False

    #trailer data
    vfatWordCntTrail = None
    evtFifoUnf = None
    inFifoUnf = None

    #vfat data
    vfats = []

    def __init__(self, event, chamberIdx):
        self.event = event
        self.chamberIdx = chamberIdx
        self.vfats = []

    def unpackGemChamberBlock(self, words, idx, verbose=False):
        idx = self.unpackGemChamberHeader(words, idx, verbose)

        if self.vfatWordCnt % 3 != 0:
            printRed("Invalid VFAT word count that doesn't divide by 3: %d !! exiting.." % self.vfatWordCnt)
            sys.exit(0)

        if (idx + self.vfatWordCnt > len(words)):
            self.prematureEoeReached = True
            return idx

        vfatIdx = 0
        while vfatIdx < self.vfatWordCnt / 3:
            vfat = GemVfat3(self, vfatIdx)
            self.vfats.append(vfat)
            vfatIdx += 1
            idx = vfat.unpackVfatBlock(words, idx, verbose)

        idx = self.unpackGemChamberTrailer(words, idx, verbose)

        return idx

    def unpackGemChamberHeader(self, words, idx, verbose=False):
        self.zsWordCnt = (words[idx] >> 40) & 0xfff
        self.inputId = (words[idx] >> 35) & 0x1f
        self.vfatWordCnt = (words[idx] >> 23) & 0xfff
        self.evtFifoFull = True if ((words[idx] >> 22) & 0x1) == 1 else False
        self.inFifoFull = True if ((words[idx] >> 21) & 0x1) == 1 else False
        self.l1aFifoFull = True if ((words[idx] >> 20) & 0x1) == 1 else False
        self.evtSizeOvf = True if ((words[idx] >> 19) & 0x1) == 1 else False
        self.evtFifoNearFull = True if ((words[idx] >> 18) & 0x1) == 1 else False
        self.inFifoNearFull = True if ((words[idx] >> 17) & 0x1) == 1 else False
        self.l1aFifoNearFull = True if ((words[idx] >> 16) & 0x1) == 1 else False
        self.evtSizeMoreThan24 = True if ((words[idx] >> 15) & 0x1) == 1 else False
        self.noVfatMarker = True if ((words[idx] >> 14) & 0x1) == 1 else False

        idx += 1

        if verbose:
            self.printGemChamberHeader()

        return idx

    def printGemChamberHeader(self):
        printCyan("    --------------------------------------")
        printCyan("    Chamber #%d Event Header" % self.chamberIdx)
        printCyan("    --------------------------------------")
        print "    Zero-suppressed word count: %d" % self.zsWordCnt
        print "    Input ID: %d" % self.inputId
        print "    VFAT word count: %d" % self.vfatWordCnt
        printGreenRed("    Event FIFO full: %r" % self.evtFifoFull, self.evtFifoFull, False)
        printGreenRed("    Input FIFO full: %r" % self.inFifoFull, self.inFifoFull, False)
        printGreenRed("    L1A FIFO full: %r" % self.l1aFifoFull, self.l1aFifoFull, False)
        printGreenRed("    Event size overflow: %r" % self.evtSizeOvf, self.evtSizeOvf, False)
        printGreenRed("    Event FIFO near full: %r" % self.evtFifoNearFull, self.evtFifoNearFull, False)
        printGreenRed("    Input FIFO near full: %r" % self.inFifoNearFull, self.inFifoNearFull, False)
        printGreenRed("    L1A FIFO near full: %r" % self.l1aFifoNearFull, self.l1aFifoNearFull, False)
        printGreenRed("    Event size more than 24 VFATs: %r" % self.evtSizeMoreThan24, self.evtSizeMoreThan24, False)
        printGreenRed("    No VFAT marker: %r" % self.noVfatMarker, self.noVfatMarker, False)
        printGreenRed("    Premature EOE reached: %r" % self.prematureEoeReached, self.prematureEoeReached, False)
        printGreenRed("    Number of VFAT blocks: %d" % len(self.vfats), len(self.vfats), 24)


    def unpackGemChamberTrailer(self, words, idx, verbose=False):
        self.vfatWordCntTrail = (words[idx] >> 36) & 0xfff
        self.evtFifoUnf = True if ((words[idx] >> 35) & 0x1) == 1 else False
        self.inFifoUnf = True if ((words[idx] >> 33) & 0x1) == 1 else False

        idx += 1

        if verbose:
            self.printGemChamberTrailer()

        return idx


    def printGemChamberTrailer(self):
        printCyan("    --------------------------------------")
        printCyan("    Chamber #%d Event Trailer" % self.chamberIdx)
        printCyan("    --------------------------------------")
        printGreenRed("    VFAT word count in trailer: %d" % self.vfatWordCntTrail, self.vfatWordCntTrail, self.vfatWordCnt)
        printGreenRed("    Event FIFO underflow: %r" % self.evtFifoUnf, self.evtFifoUnf, False)
        printGreenRed("    Input FIFO underflow: %r" % self.inFifoUnf, self.inFifoUnf, False)

    def printChamber(self):
        self.printGemChamberHeader()
        for vfat in self.vfats:
            vfat.printVfatBlock()
        self.printGemChamberTrailer()


    def hasError(self, verbose):
        ret = False

        if (self.evtFifoFull or self.inFifoFull or self.l1aFifoFull or self.evtSizeOvf or self.evtFifoNearFull or self.inFifoNearFull or self.l1aFifoNearFull or self.evtSizeMoreThan24 or self.noVfatMarker or self.evtFifoUnf or self.inFifoUnf or len(self.vfats) != 24 or self.prematureEoeReached):
            if verbose:
                printRed("Chamber error")
                self.printGemChamberHeader()
                self.printGemChamberTrailer()

            ret = True

        for vfat in self.vfats:
            if vfat.hasError(verbose):
                ret = True

        return ret

class GemVfat2(object):

    chamber = None
    vfatIdx = None

    marker = None
    bc = None
    ec = None
    chipId = None
    hammingErr = None
    almostFull = None
    seuLogic = None
    seuI2C = None
    chanData = None
    numHits = None
    crc = None

    def __init__(self, chamber, vfatIdx):
        self.chamber = chamber
        self.vfatIdx = vfatIdx

    def unpackVfatBlock(self, words, idx, verbose=False):
        self.marker = ((words[idx] >> 60) & 0xf) << 8
        self.bc = (words[idx] >> 48) & 0xfff
        self.marker += ((words[idx] >> 44) & 0xf) << 4
        self.ec = (words[idx] >> 36) & 0xff
        self.hammingErr = True if ((words[idx] >> 35) & 0x1) == 1 else False
        self.almostFull = True if ((words[idx] >> 34) & 0x1) == 1 else False
        self.seuLogic = True if ((words[idx] >> 33) & 0x1) == 1 else False
        self.seuI2C = True if ((words[idx] >> 32) & 0x1) == 1 else False
        self.marker += (words[idx] >> 28) & 0xf
        self.chipId = (words[idx] >> 16) & 0xfff
        self.chanData = ((words[idx] >> 0) & 0xffff) << 112
        idx += 1
        self.chanData += words[idx] << 48
        idx += 1
        self.chanData += (words[idx] >> 16) & 0xffffffffffff
        self.crc = (words[idx] >> 0) & 0xffff
        idx += 1
        self.numHits = bin(self.chanData).count("1")

        if verbose:
            self.printVfatBlock()

        return idx

    def printVfatBlock(self):
        printCyan("        --------------------------------------")
        printCyan("        VFAT Block #%d" % self.vfatIdx)
        printCyan("        --------------------------------------")
        printGreenRed("        BC: %d" % self.bc, self.bc, self.chamber.event.bxId)
        print "        EC: %d" % self.ec
        print "        Chip ID: %s" % hexPadded(self.chipId, 1.5)
        printGreenRed("        Marker: %s" % hexPadded(self.marker, 1.5), self.marker, 0xace)
        printGreenRed("        Hamming error: %r" % self.hammingErr, self.hammingErr, False)
        printGreenRed("        Almost full: %r" % self.almostFull, self.almostFull, False)
        printGreenRed("        SEU logic: %r" % self.seuLogic, self.seuLogic, False)
        printGreenRed("        SEU I2C: %r" % self.seuI2C, self.seuI2C, False)
        print "        Channel data: %s" % hexPadded(self.chanData, 16)
        print "        Number of hit channels: %d" % self.numHits
        print "        CRC: %s" % hexPadded(self.crc, 2)

class GemVfat3(object):

    chamber = None
    vfatIdx = None

    header = None
    bc = None
    ec = None
    position = None
    warning = None
    crcError = None
    chanData = None
    numHits = None
    crc = None

    def __init__(self, chamber, vfatIdx):
        self.chamber = chamber
        self.vfatIdx = vfatIdx

    def unpackVfatBlock(self, words, idx, verbose=False):
        self.position = (words[idx] >> 56) & 0xff
        self.crcError = True if ((words[idx] >> 48) & 0x1) == 1 else False
        self.header = (words[idx] >> 40) & 0xff
        self.warning = True if (self.header == 0x5e or self.header == 0x56) else False
        self.bc = (words[idx] >> 16) & 0xffff
        self.ec = (words[idx] >> 32) & 0xff
        self.chanData = ((words[idx] >> 0) & 0xffff) << 112
        idx += 1
        self.chanData += words[idx] << 48
        idx += 1
        self.chanData += (words[idx] >> 16) & 0xffffffffffff
        self.crc = (words[idx] >> 0) & 0xffff
        idx += 1
        self.numHits = bin(self.chanData).count("1")

        if verbose:
            self.printVfatBlock()

        return idx

    def printVfatBlock(self):
        printCyan("        --------------------------------------")
        printCyan("        VFAT Block #%d" % self.vfatIdx)
        printCyan("        --------------------------------------")
        print("        Position: %d" % self.position)
        printGreenRed("        BC: %s" % hexPadded(self.bc, 2), self.bc, self.chamber.event.bxId + 1)
        print "        EC: %s" % hexPadded(self.ec, 1)
        printGreenRed("        Header: %s" % hexPadded(self.header, 1), self.header, 0x1e)
        printGreenRed("        Warning: %r" % self.warning, self.warning, False)
        printGreenRed("        CRC error: %r" % self.crcError, self.crcError, False)
        print "        Channel data: %s" % hexPadded(self.chanData, 16)
        print "        Number of hit channels: %d" % self.numHits
        print "        CRC: %s" % hexPadded(self.crc, 2)

    def hasError(self, verbose):
        if (self.bc != self.chamber.event.bxId + 1) or (self.header != 0x1e) or self.warning or self.crcError:
            if verbose:
                printRed("VFAT error")
                self.printVfatBlock()

            return True

def main():

    rawFilename = ''
    command = ''
    evtNumToPrint = -1
    countNonZero = False
    printError = False

    if len(sys.argv) < 3:
        print('Usage: unpack.py <gem_raw_file> <command> [command_params]')
        print('The filename can contain some regexp features to match multiple files. Supported expressions are: * -- wildcard, ? -- match any single character, [seq] -- matches any char in seq, [!seq] -- matches any char not in seq')
        print('When using regexp filename, make sure to enclose that in double quotes')
        print('Commands:')
        print('    print <evt_number> -- prints the requested event')
        print('    print_non_zero_event <non_zero_evt_number> -- prints the requested event while only counting events that contain at least one vfat block')
        print('    print_error -- prints the first even with error')
        return
    else:
        rawFilename = sys.argv[1]
        command = sys.argv[2]

    files = []

    # do regexp
    if ("*" in rawFilename or "?" in rawFilename or "[" in rawFilename):
        dir = os.path.expanduser(os.path.dirname(rawFilename))
        for file in sorted(os.listdir(dir)):
            if fnmatch.fnmatch(file, os.path.basename(rawFilename)):
                files.append(dir + "/" + file)
        if len(files) == 0:
            printRed("No files found..")
            return
    else:
        files.append(rawFilename)
        if not os.path.exists(rawFilename):
            printRed("Input file %s does not exist." % rawFilename)
            return


    if "print" in command:
        evtNumToPrint = int(sys.argv[3])
        print("Event num to print: %d" % evtNumToPrint)
    if "non_zero_event" in command:
        countNonZero = True
    if "print_error" in command:
        printError = True
        print "Will print errors"
        evtNumToPrint = int(sys.argv[3])
        if evtNumToPrint >= 0:
            print "Will start printing errors only after event #%d" % evtNumToPrint

    events = []
    i = 0
    nonZeroI = 0

    for file in files:
        print("Opening file: %s" % file)
        f = open(file, 'rb')
        fileSize = os.fstat(f.fileno()).st_size

        if IS_MINIDAQ_FORMAT:
            evtHeaderSize = readInitRecord(f, VERBOSE)

        print "File size = %d bytes" % fileSize

        while True:
            if f.tell() >= fileSize - 1:
                printCyan("End of file reached")
                f.close()
                break

            event = None
            if IS_MINIDAQ_FORMAT:
                event = readEvtRecord(f, fileSize, evtHeaderSize, VERBOSE, DEBUG, i)
            else:
                event = readAmc13Evt(f, fileSize, VERBOSE, DEBUG, i)

            if event is not None:
                #events.append(event)

                if printError:
                    if i > evtNumToPrint and event.hasError(True):
                        #event.printEvent()
                        printRed("Event #%d (ending at byte %d in file %s)" % (i, f.tell(), file))
                        print("Print the whole event? (y/n)")
                        yn = raw_input()
                        if (yn == "y"):
                            print ""
                            print ""
                            print "======================================================================================"
                            print ""
                            event.printEvent()

                        print("Do you want to continue? (y/n)")
                        yn = raw_input()
                        if (yn != "y"):
                            return
                elif not countNonZero and (i == evtNumToPrint):
                    event.printEvent()
                    printRed("Event #%d (ending at byte %d in file %s)" % (i, f.tell(), file))
                    return
                elif countNonZero and (event.getNumVfatBlocks() > 0):
                    if nonZeroI == evtNumToPrint:
                        event.printEvent()
                        printRed("Event #%d (ending at byte %d in file %s)" % (i, f.tell(), file))
                        return
                    nonZeroI += 1

                i += 1

            #print "Read event #%d ending at byte %d" % (i, f.tell())

        f.close()

    # some quick and dirty analysis runs
    if "analyze_bx_diff" in sys.argv:
        analyze_events.analyzeBxDiff(events)

    if "analyze_bx" in sys.argv:
        analyze_events.analyzeBx(events)

    if "analyze_num_chambers" in sys.argv:
        analyze_events.analyzeNumChambers(events)

    if "analyze_num_vfats" in sys.argv:
        analyze_events.analyzeNumVfats(events)

    if "analyze_vfat_bx_matching" in sys.argv:
        analyze_events.analyzeVfatBxMatching(events)

def readInitRecord(f, verbose=False):
    code = readNumber(f, 1)
    initRecordSize = readNumber(f, 4)
    protocol = readNumber(f, 1)
    f.read(16)
    runNumber = readNumber(f, 4)
    initHeaderSize = readNumber(f, 4)
    evtHeaderSize = readNumber(f, 4)
    f.read(initRecordSize - 34) # finish reading the init block

    if verbose:
        print ""
        print "====================================================="
        print "INIT MESSAGE"
        print "====================================================="
        print "code = %s" % hexPadded(code, 1)
        print "size = %d" % initRecordSize
        print "protocol = %s" % hexPadded(protocol, 1)
        print "run number = %d" % runNumber
        print "init header size = %d" % initHeaderSize
        print "event header size = %d" % evtHeaderSize

    return evtHeaderSize

def readEvtRecord(f, fileSize, evtHeaderSize, verbose=False, debug=False, evtNum=-1):
    startIdx = f.tell()
    code = readNumber(f, 1)
    size = readNumber(f, 4)
    protocol = readNumber(f, 1)
    runNumber = readNumber(f, 4)
    evtNumber = readNumber(f, 4)
    f.read(evtHeaderSize - 14 - 4)
    fedBlockSizeCompressed = readNumber(f, 4)
    compressedEvtBlobIdx = f.tell()
    if compressedEvtBlobIdx + fedBlockSizeCompressed >= fileSize:
        f.read(fileSize - compressedEvtBlobIdx)
        if verbose:
            printRed("End of file reached")
        return None
    fedDataCompressed = f.read(fedBlockSizeCompressed)
    fedData = zlib.decompress(fedDataCompressed)[0x1c81:] #0x1c81 is a magic position inside this blob where I found the FED data to start totally emptyrically, so it may not be true for each file...
    fedBlockSize = len(fedData)

    if verbose:
        print ""
        print "====================================================="
        print "EVENT MESSAGE (event #%d)" % evtNum
        print "====================================================="
        print "start idx = %s" % hexPadded(startIdx, 4)
        print "code = %s" % hexPadded(code, 1)
        print "size = %d" % size
        print "protocol = %s" % hexPadded(protocol, 1)
        print "run number = %d" % runNumber
        print "event number = %d" % evtNumber

        print "compressed event blob size = %d" % fedBlockSizeCompressed
        print "compressed event blob idx: %s" % hexPadded(compressedEvtBlobIdx, 4)

        print "decompressed event blob size = %d" % fedBlockSize

        if debug:
            print "----------------------------------------------"
            print "FED data:"
            printHexBlock64BigEndian(fedData, fedBlockSize)
            print "----------------------------------------------"

        printCyan("**********************************************")

    event = GemAmc(None)
    event.unpackGemAmcBlockStr(fedData, verbose)

    if verbose:
        printCyan("**********************************************")

    return event

def readAmc13Evt(f, fileSize, verbose=False, debug=False, evtNum=-1):
    startIdx = f.tell()
    if (startIdx + 24 >= fileSize):
        printRed("Unexpected end of file, startIdx = %d, filesize = %d" % (startIdx, fileSize))
    f.read(16)
    fedBlockSize = readNumber(f, 2)
    f.read(6)
    if (startIdx + 24 + fedBlockSize > fileSize):
        printRed("Unexpected end of file, startIdx = %d, fedBlockSize = %d, filesize = %d" % (startIdx, fedBlockSize, fileSize))
    fedData = f.read(fedBlockSize)

    if verbose:
        print ""
        print "====================================================="
        print "EVENT MESSAGE (event #%d)" % evtNum
        print "====================================================="
        print "start idx = %s" % hexPadded(startIdx, 4)
        print "fed block size = %d" % fedBlockSize

        if debug:
            print "----------------------------------------------"
            print "FED data:"
            printHexBlock64BigEndian(fedData, fedBlockSize)
            print "----------------------------------------------"

        printCyan("**********************************************")

    event = Amc13()
    event.unpackAmc13Block(fedData, verbose)

    if verbose:
        printCyan("**********************************************")

    return event

def readNumber(f, numBytes):
    formatStr = "<"
    if numBytes == 1:
        formatStr += "B"
    elif numBytes == 2:
        formatStr += "H"
    elif numBytes == 4:
        formatStr += "I"
    elif numBytes == 8:
        formatStr += "Q"
    else:
        raise "Unsupported number byte count of %d" % numBytes

    word = struct.unpack(formatStr, f.read(numBytes))[0]

    return word

def printHexBlock64BigEndian(str, length):
    fedBytes = struct.unpack("%dB" % length, str)
    # print "length: %d, str length: %d, num of 8 byte words: %d" % (len(fedBytes), len(str), int(math.ceil(length / 8.0)))
    for i in range(0, int(math.ceil(length / 8.0))):
        idx = i * 8
        sys.stdout.write("{0:#0{1}x}: ".format(idx, 4 + 2))
        # sys.stdout.write("%d: " % idx)
        for j in range(0, 8):
            if (i+1) * 8 - (j + 1) >= length:
                sys.stdout.write("-- ")
            else:
                sys.stdout.write("%s " % (format(fedBytes[(i+1) * 8 - (j + 1)], '02x')))
        sys.stdout.write('\n')
    sys.stdout.flush()

if __name__ == '__main__':
    main()
