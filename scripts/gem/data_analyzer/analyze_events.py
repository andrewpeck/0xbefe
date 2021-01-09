#!/usr/bin/env python

from utils import *
import math
from text_histogram import histogram

def analyzeBxDiff(events):
    ohAmcBxOffsets = []
    vfatOhBxOffsets = []
    vfatAmcBxOffsets = []

    for event in events:
        for chamber in event.chambers:
            ohAmcBxOffsets.append(chamber.ohBc - event.bxId)
            for vfat in chamber.vfats:
                vfatOhBxOffsets.append(vfat.bc - chamber.ohBc)
                vfatAmcBxOffsets.append(vfat.bc - event.bxId)

    # print "===================================================="
    # print "OH BC - AMC BC histogram:"
    # print ""
    # histogram(ohAmcBxOffsets, -3564, 3564, 100)
    #
    # print ""
    # print "===================================================="
    # print "VFAT BC - OH BC histogram:"
    # print ""
    # histogram(vfatOhBxOffsets, -3564, 3564, 100)

    print ""
    print "===================================================="
    print "VFAT BC - AMC BC histogram:"
    print ""
    # histogram(vfatAmcBxOffsets, -3564, 3564, 100)
    histogram(vfatAmcBxOffsets, -3564, 3564, 7130)

def analyzeBx(events):
    amcBxs = []
    ohBxs = []
    vfatBxs = []

    amcBxMin = 5000
    amcBxMax = -1
    numAmcBxOvf = 0

    ohBxMin = 5000
    ohBxMax = -1
    numOhBxOvf = 0

    vfatBxMin = 5000
    vfatBxMax = -1
    numVfatBxOvf = 0

    for event in events:
        amcBxs.append(event.bxId)
        if event.bxId < amcBxMin:
            amcBxMin = event.bxId
        if event.bxId > amcBxMax:
            amcBxMax = event.bxId
        if event.bxId > 3564:
            numAmcBxOvf += 1

        for chamber in event.chambers:
            ohBxs.append(chamber.ohBc)
            if chamber.ohBc < ohBxMin:
                ohBxMin = chamber.ohBc
            if chamber.ohBc > ohBxMax:
                ohBxMax = chamber.ohBc
            if chamber.ohBc > 3564:
                numOhBxOvf += 1

            for vfat in chamber.vfats:
                vfatBxs.append(vfat.bc)
                if vfat.bc < vfatBxMin:
                    vfatBxMin = vfat.bc
                if vfat.bc > vfatBxMax:
                    vfatBxMax = vfat.bc
                if vfat.bc > 3564:
                    numVfatBxOvf += 1

    print ""
    print "===================================================="
    print "AMC BC histogram:"
    print ""
    histogram(amcBxs, 0, 4095, 4096)

    print "AMC BX Min: %d, AMC BX Max: %d, AMC BX > 3564: %d" % (amcBxMin, amcBxMax, numAmcBxOvf)

    print ""
    print "===================================================="
    print "OH BC histogram:"
    print ""
    histogram(ohBxs, 0, 4095, 4096)

    print "OH BX Min: %d, OH BX Max: %d, OH BX > 3564: %d" % (ohBxMin, ohBxMax, numOhBxOvf)

    print ""
    print "===================================================="
    print "VFAT BC histogram:"
    print ""
    histogram(vfatBxs, 0, 4095, 4096)

    print "VFAT BX Min: %d, VFAT BX Max: %d, VFAT BX > 3564: %d" % (vfatBxMin, vfatBxMax, numVfatBxOvf)

def analyzeVfatBxMatching(events):

    numMatchingInEvent = 0
    numMatchingInChamber = 0
    numMismatchInEvent = 0
    numMismatchInChamber = 0

    for event in events:
        bxs = []
        numVfats = 0
        for chamber in event.chambers:
            chamberBxs = []
            numChamberVfats = 0
            for vfat in chamber.vfats:
                if vfat.bc not in bxs:
                    bxs.append(vfat.bc)
                if vfat.bc not in chamberBxs:
                    chamberBxs.append(vfat.bc)
                numChamberVfats += 1
                numVfats += 1

            if len(chamberBxs) > 1:
                numMismatchInChamber += 1
            elif numChamberVfats > 1:
                numMatchingInChamber += 1

        if len(bxs) > 1:
            numMismatchInEvent += 1
        elif numVfats > 1:
            numMatchingInEvent += 1

    print ""
    print "===================================================="
    print "Number of events with matching VFAT BXs: %d" % numMatchingInEvent
    print "Number of chamber events with matching VFAT BXs: %d" % numMatchingInChamber
    print "Number of events with mismatching VFAT BXs: %d" % numMismatchInEvent
    print "Number of chamber events with mismatching VFAT BXs: %d" % numMismatchInChamber

def analyzeOhBxMatching(events):

    numMatchingBx = 0
    numMatchingEc = 0
    numMismatchingBx = 0
    numMismatchingEc = 0

    for event in events:
        bxs = []
        ecs = []
        numOhs = 0
        for chamber in event.chambers:
            if chamber.ohBc not in bxs:
                bxs.append(chamber.ohBc)
            if chamber.ohEc not in ecs:
                ecs.append(chamber.ohEc)
            numOhs += 1

        if len(bxs) > 1:
            numMismatchingBx += 1
        elif numOhs > 1:
            numMatchingBx += 1

        if len(ecs) > 1:
            numMismatchingEc += 1
        elif numOhs > 1:
            numMatchingEc += 1

    print ""
    print "===================================================="
    print "Number of events with matching OH BXs: %d" % numMatchingBx
    print "Number of events with matching OH ECs: %d" % numMatchingEc
    print "Number of events with mismatching OH BXs: %d" % numMismatchingBx
    print "Number of events with mismatching OH ECs: %d" % numMismatchingEc


def analyzeNumVfats(events):
    numVfats = []
    for event in events:
        vfats = 0
        for chamber in event.chambers:
            vfats += len(chamber.vfats)
            numVfats.append(vfats)


    print "===================================================="
    print "Number of VFATs per event histogram:"
    print ""
    histogram(numVfats)


def analyzeNumChambers(events):
    numChambers = []

    for event in events:
        numChambers.append(len(event.chambers))

    print "===================================================="
    print "Number of chambers per event histogram:"
    print ""
    histogram(numChambers, 0, 8, 8)
