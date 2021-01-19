#!/usr/bin/env python

from rw_reg import *
from time import *
import array
import struct
from text_histogram import histogram

class Colors:            
    WHITE   = '\033[97m' 
    CYAN    = '\033[96m' 
    MAGENTA = '\033[95m' 
    BLUE    = '\033[94m' 
    YELLOW  = '\033[93m' 
    GREEN   = '\033[92m' 
    RED     = '\033[91m' 
    ENDC    = '\033[0m'  

NUM_READS = 10000
PHASE_UNITS_PS = 1.85963 # 18.6012 when using my phasemon, and 1.859630739 when using the DMTD from TCDS

def main():

    parseXML()

    heading("Collecting phase data")
    f = open("phase.csv", "w")

    lastSampleCnt = parseInt(readReg(getNode('GEM_AMC.TTC.STATUS.CLK.PHASE_MONITOR.SAMPLE_COUNTER')))
    phaseArr = []
    for i in range(NUM_READS):
        phaseRaw = parseInt(readReg(getNode('GEM_AMC.TTC.STATUS.CLK.PHASE_MONITOR.PHASE')))
        phasePs = phaseRaw * PHASE_UNITS_PS
        phaseArr.append(phasePs)
        f.write("%f\n" % phasePs)
        sampleCnt = lastSampleCnt
        while sampleCnt == lastSampleCnt:
            sampleCnt = parseInt(readReg(getNode('GEM_AMC.TTC.STATUS.CLK.PHASE_MONITOR.SAMPLE_COUNTER')))
            sleep(0.0001)
        lastSampleCnt = sampleCnt
        if i % 1000 == 0:
            print("Progress: %d / %d" % (i, NUM_READS))

    histogram(phaseArr)

    f.close()

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
