from board.manager import *
import sys
import re
import os
import time
from datetime import datetime


# Constants (to be moved to config file later)
STABILIZE_SENSITIVITY = 0.01
MAX_TEMP=70.0
QSFP_MAX_T=50
MIN_ITERS=1
CYCLE_TIME=4
TOLERANCE=0.05
HEADERS = ["12V0_V","3V3_STANDBY_V","3V3_SI5395J_V","1V8_SI5395J_XO2_V","2V5_OSC_NE_V","1V8_MGTVCCAUX_VUP_N_V","2V5_OSC_NW_V","2V5_OSC_K7_V","1V2_MGTAVTT_K7_V","1V0_MGTAVCC_K7_V","0V675_DDRVTT_V","1V35_DDR_V","1V8_VCCAUX_K7_V","2V5_OSC_SE_V","1V8_MGTVCCAUX_VUP_S_V","2V5_OSC_SW_V",
            "0V85_VCCINT_VUP_T0","0V85_VCCINT_VUP_T1","0V85_VCCINT_VUP_T2","0V85_VCCINT_VUP_T3","0V85_VCCINT_VUP_T4","0V85_VCCINT_VUP_T5",'1V2_MGTAVTT_VUP_S_TL','1V2_MGTAVTT_VUP_S_TR','1V2_MGTAVTT_VUP_S_TL','1V2_MGTAVTT_VUP_S_TR','KINTEX7_TL','KINTEX7_TR','0V9_MGTAVCC_VUP_S_TL','0V9_MGTAVCC_VUP_S_TR','0V9_MGTAVCC_VUP_S_TL','0V9_MGTAVCC_VUP_S_TR','2V7_INTERMEDIATE_TL','2V7_INTERMEDIATE_TR','1V2_MGTAVTT_VUP_N_TL','1V2_MGTAVTT_VUP_N_TR','VIRTEXUPLUS_TL','VIRTEXUPLUS_TR','0V9_MGTAVCC_VUP_S_TL','0V9_MGTAVCC_VUP_S_TR','TOTAL_ERRORS']
V_EXPECT={'12V0':12,'3V3_STANDBY':3.3,'3V3_SI5395J':3.3,'1V8_SI5395J_XO2':1.8,'2V5_OSC_NE':2.5,'1V8_MGTVCCAUX_VUP_N':1.8,'2V5_OSC_NW':2.5,'2V5_OSC_K7':2.5,'1V2_MGTAVTT_K7':1.2,'1V0_MGTAVCC_K7':1.0,'0V675_DDRVTT':0.675,'1V35_DDR':1.35,'1V8_VCCAUX_K7':1.8,'2V5_OSC_SE':2.5,'1V8_MGTVCCAUX_VUP_S':1.8,'2V5_OSC_SW':2.5,'0V9_MGTAVCC_VUP_N':0.9,'1V8_VCCAUX_VUP':1.8,'1V0_VCCINT_K7':1.0,'1V2_MGTAVTT_VUP_N':1.2,'2V7_INTERMEDIATE':2.7,'0V9_MGTAVCC_VUP_S':0.9,'1V2_MGTAVTT_VUP_S':1.2}
# End of constants

DATA_DICT = {}
def printRed(st):
    return "\033[91m"+st+"\033[0m"

def printGreen(st):
    return "\033[92m"+st+"\033[0m"

m=manager(optical_add_on_ver=2)
m.peripheral.autodetect_optics()
p_data = m.peripheral.monitor(verbose=False)
p_data = m.peripheral.monitor(verbose=False)
for device in p_data.keys():
    if device in ['optics','0V85_VCCINT_VUP']:
        continue
    if 'T' in p_data[device].keys():
        for i in range(len(p_data[device]['T'])):
            if p_data[device]['T'][i]>MAX_TEMP:
                print(printRed("Aborting, high temperature"))
                print(str(p_data[device]['T'][i]))
                print(device)
                sys.exit(1)

if 'optics' in p_data.keys() and len(p_data['optics'].keys())>0:
    for cage,info in p_data['optics'].items():
        if(info['T']>QSFP_MAX_T):
            print("Device:QSFP: "+str(cage)+", temp: "+str(t))
            print("Temperature too high, aborting run")
            sys.exit(1)
print(printGreen("Temperature check passed"))
