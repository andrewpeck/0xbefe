#!/usr/bin/env python

from rw_reg import *
from time import *
import array
import struct

class Colors:            
    WHITE   = '\033[97m' 
    CYAN    = '\033[96m' 
    MAGENTA = '\033[95m' 
    BLUE    = '\033[94m' 
    YELLOW  = '\033[93m' 
    GREEN   = '\033[92m' 
    RED     = '\033[91m' 
    ENDC    = '\033[0m'  

ROUNDS = 20
NUM_SHIFTS_PER_ROUND = 672 #1344

def main():

    parseXML()

    heading("Scanning through the TTC sampling clock phase:")

    for round in range(ROUNDS):
        print("resetting the phase alignment")
        writeReg(getNode('GEM_AMC.TTC.CTRL.PA_MANUAL_OVERRIDE'), 0)
        writeReg(getNode('GEM_AMC.TTC.CTRL.PHASE_ALIGNMENT_RESET'), 1)
        sleep(0.1)
        writeReg(getNode('GEM_AMC.TTC.CTRL.MODULE_RESET'), 1)
        sleep(0.1)
        phaseLocked = parseInt(readReg(getNode('GEM_AMC.TTC.STATUS.CLK.PHASE_LOCKED')))
        if phaseLocked != 1:
            printRed("Phase is not locked after realignment, exit")
            exit(0)
        print("phase monitor reading: %f" % readPhaseMonitor())
        getTtcStatus(True)

        writeReg(getNode('GEM_AMC.TTC.CTRL.PA_MANUAL_OVERRIDE'), 1)
        first_bad = -1
        bad_size = 0
        for phase in range(NUM_SHIFTS_PER_ROUND):
            writeReg(getNode('GEM_AMC.TTC.CTRL.PA_MANUAL_SHIFT_EN'), 1)
            sleep(0.00001)
            writeReg(getNode('GEM_AMC.TTC.CTRL.CNT_RESET'), 1)
            sleep(0.001)
            good = getTtcStatus()
            if good:
                print("-"),
            else:
                print("X"),
                if first_bad == -1:
                    first_bad = phase
                else:
                    bad_size += 1

        writeReg(getNode('GEM_AMC.TTC.CTRL.PA_MANUAL_OVERRIDE'), 0)
        print("")
        printCyan("Bad spot starts at %d, size of the bad spot = %d" % (first_bad, bad_size))
 
    writeReg(getNode('GEM_AMC.TTC.CTRL.PA_MANUAL_OVERRIDE'), 0)

def readPhaseMonitor():
    return parseInt(readReg(getNode('GEM_AMC.TTC.STATUS.CLK.PHASE_MONITOR.PHASE_MEAN'))) * 18.6012

def getTtcStatus(verbose=False):
    singleErr = parseInt(readReg(getNode('GEM_AMC.TTC.STATUS.TTC_SINGLE_ERROR_CNT')))
    doubleErr = parseInt(readReg(getNode('GEM_AMC.TTC.STATUS.TTC_DOUBLE_ERROR_CNT')))
    bc0Locked = parseInt(readReg(getNode('GEM_AMC.TTC.STATUS.BC0.LOCKED')))

    good = False
    if singleErr == 0 and doubleErr == 0 and bc0Locked == 1:
        good = True

    if verbose:
        print("TTC status: single err cnt = %d, double err cnt = %d, BC0 locked = %d" % (singleErr, doubleErr, bc0Locked))

    return good


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

def binary(number, length):
    if number is None:
        return 'None'
    else:
        return "{0:#0{1}b}".format(number, length + 2)

if __name__ == '__main__':
    main()
