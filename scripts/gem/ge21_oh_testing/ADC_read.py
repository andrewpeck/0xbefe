#!/bin/env python
import sys
import os
import array
import struct
import time

from common.rw_reg import *
from common.utils import *
from gem.sca import *

OH_NUM = 0
OH_MASK = 1
OUT_DIR = "./data/"
READ_WAIT_SEC = 1.0

RSSI_R1 = 2000.0
RSSI_R2 = 1000.0
RSSI_VCC = 2.5

# Temp(Resist) = Intercept + Slope*Resist
PT1000_Slope = 0.2597
PT1000_Intercept = -259.8956

# SCA Temp = Intercept + Slope*READ_mV
SCA_Temp_Slope = -0.5405
SCA_Temp_Intercept = 388.5135

#~~~~~~~~~~~~Tolerance Settings ~~~~~~~~~~~~~~~
# SEM Delta CNT
SEM1_DMAX = 5
SEM2_DMAX = 1
# VTRX RSSI
RSSI_WARN = 150 # uA
RSSI_MIN  = 100 # uA
# Temperature:
TEMP_WARN = 50
TEMP_MAX  = 60
# Voltage:
VOLT_WARN = 0.05  # 5% range for Warning
VOLT_MAX  = 0.10  # 10% range for Error
VOLT_NOM  = [1.0, 1.0, 1.2, 1.84, 1.5, 2.5]
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~~~~~~~CMD Line Output Headers~~~~~~~~~~~~~~~~
SEM_HEAD = ["SEM_CNT", "SEM_D", "CRIT_CNT", "CRIT_D"]
RSSI_HEAD = ["RSSI1","RSSI2"]
VOLT_HEAD = ["1.0V","AVCC","AVTT","1.8V","1.5V", "2.5V"]
TEMP_HEAD = ["FPGA","SCA","U2","U3","U22","U8"]
CURR_HEAD = ["FEAST1", "FEAST2", "FEAST3", "FEAST4", "FEAST5"]
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~~~~~~~~~~~~~~~Read Data Store~~~~~~~~~~~~~~~~
SEM_Val = [0,0,0,0] #1-bit cnt , 1-bit delta , +2-bit cnt , +2-bit delta
RSSI_Val = [0,0]    # VTRX1 , VTRX2
VOLT_Val = [0,0,0,0,0,0] # 6 Voltages
TEMP_Val = [0,0,0,0,0,0] # 6 Temperatures
CURR_Val = [0,0,0,0,0] # FEAST1 , FEAST2 , FEAST3 , FEAST4 , FEAST5
prev_sem_corr = 0   # Memory for SEM 1-bit Count
sem_corr = 0
prev_sem_crit = 0   # Memory for SEM Critical Count
sem_crit = 0
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



def ADC_Test():

    iter = 0
    data = {}
    while(iter == 0):
        # read FPGA temperature
        sleep(1)
        tempRaw = read_reg('BEFE.GEM.OH.OH%d.FPGA.ADC.CTRL.DATA_OUT' % OH_NUM)
        temp = ((tempRaw >> 4) * 503.975 / 4096) - 273.15
        TEMP_Val[0] = temp
        # print("FPGA temperature: %fC" % temp)

        # read the SCA ADCs
        write_reg('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.LINK_ENABLE_MASK', OH_MASK)
        sleep(0.01)
        sendScaCommand([OH_NUM], 0x14, 0x60, 0x4, 0x00e00300, False) # setup current sources
        sleep(0.01)
        # Channels 0-5 [Voltages]
        adc_1v0 = readScaAdc(OH_NUM, 0) * 0.004
        adc_1v0avcc = readScaAdc(OH_NUM, 1) * 0.004
        adc_1v2avtt = readScaAdc(OH_NUM, 2) * 0.004
        adc_1v8 = readScaAdc(OH_NUM, 3) * 0.004
        adc_1v5 = readScaAdc(OH_NUM, 4) * 0.004
        adc_2v5 = readScaAdc(OH_NUM, 5) * 0.004
        VOLT_Val[0] = adc_1v0
        VOLT_Val[1] = adc_1v0avcc
        VOLT_Val[2] = adc_1v2avtt
        VOLT_Val[3] = adc_1v8
        VOLT_Val[4] = adc_1v5
        VOLT_Val[5] = adc_2v5

        # Channels 6-7 [RSSI Currents]
        adc_rssi1_v = readScaAdc(OH_NUM, 6) / 1000.0
        adc_rssi1_a = (((adc_rssi1_v / (RSSI_R2/(RSSI_R1+RSSI_R2))) - RSSI_VCC) / RSSI_R1) * -1
        adc_rssi1_ua = adc_rssi1_a * 1000000
        adc_rssi2_v = readScaAdc(OH_NUM, 7) / 1000.0
        adc_rssi2_a = (((adc_rssi2_v / (RSSI_R2/(RSSI_R1+RSSI_R2))) - RSSI_VCC) / RSSI_R1) * -1
        adc_rssi2_ua = adc_rssi2_a * 1000000
        RSSI_Val[0] = adc_rssi1_ua
        RSSI_Val[1] = adc_rssi2_ua

        # Channels 8-12 [FEAST Currents]
        adc_feast1_a = (readScaAdc(OH_NUM,8) * 4) / (200)   # 1.8V
        adc_feast2_a = (readScaAdc(OH_NUM,9) * 4) / (200)   # 1.5V
        adc_feast3_a = (readScaAdc(OH_NUM,10) * 4) / (200)  # 2.5V
        adc_feast4_a = (readScaAdc(OH_NUM,11) * 4) / (200)  # Analog  VFAT power (unused in radtest)
        adc_feast5_a = (readScaAdc(OH_NUM,12) * 4) / (200)  # Digital VFAT power (unused in radtest)
        CURR_Val[0] = adc_feast1_a
        CURR_Val[1] = adc_feast2_a
        CURR_Val[2] = adc_feast3_a
        CURR_Val[3] = adc_feast4_a
        CURR_Val[4] = adc_feast5_a

        # read SCA temperature
        # Channel 31 [SCA internal Temp]
        adc_sca_temp = SCA_Temp_Intercept + SCA_Temp_Slope*(readScaAdc(OH_NUM,31))
        # Channels 13-16 [Temperature Sensors]
        adc_u2_ohm = (readScaAdc(OH_NUM,13) / (readScaAdc(OH_NUM,17) / 1000))
        adc_u2_temp = PT1000_Intercept + PT1000_Slope*adc_u2_ohm;
        adc_u3_ohm = (readScaAdc(OH_NUM,14) / (readScaAdc(OH_NUM,17) / 1000))
        adc_u3_temp = PT1000_Intercept + PT1000_Slope*adc_u3_ohm;
        adc_u22_ohm = (readScaAdc(OH_NUM,15) / (readScaAdc(OH_NUM,17) / 1000))
        adc_u22_temp = PT1000_Intercept + PT1000_Slope*adc_u22_ohm;
        adc_u8_ohm = (readScaAdc(OH_NUM,16) / (readScaAdc(OH_NUM,17) / 1000))
        adc_u8_temp = PT1000_Intercept + PT1000_Slope*adc_u8_ohm;
        TEMP_Val[1] = adc_sca_temp
        TEMP_Val[2] = adc_u2_temp
        TEMP_Val[3] = adc_u3_temp
        TEMP_Val[4] = adc_u22_temp
        TEMP_Val[5] = adc_u8_temp

        curr_Mirror_Cal = (readScaAdc(OH_NUM,17))
 
        sleep(READ_WAIT_SEC)
        iter += 1

        #CmdOut_SEM(SEM_Val)
        CmdOut_RSSI(Copy(RSSI_Val))
        CmdOut_TEMP(Copy(TEMP_Val))
        CmdOut_VOLT(Copy(VOLT_Val))
        CmdOut_Curr(Copy(CURR_Val))
        print("Current Mirror Calibration [uA]: %f" % curr_Mirror_Cal)
        print("=============================")

    return [RSSI_Val,TEMP_Val,VOLT_Val,CURR_Val,curr_Mirror_Cal]

def readRSSI():
    RSSI_Val = [False,0,0]
    adc_rssi1_v = readScaAdc(OH_NUM, 6) / 1000.0
    adc_rssi1_a = (((adc_rssi1_v / (RSSI_R2/(RSSI_R1+RSSI_R2))) - RSSI_VCC) / RSSI_R1) * -1
    adc_rssi1_ua = adc_rssi1_a * 1000000
    adc_rssi2_v = readScaAdc(OH_NUM, 7) / 1000.0
    adc_rssi2_a = (((adc_rssi2_v / (RSSI_R2/(RSSI_R1+RSSI_R2))) - RSSI_VCC) / RSSI_R1) * -1
    adc_rssi2_ua = adc_rssi2_a * 1000000
    RSSI_Val[1] = adc_rssi1_ua
    RSSI_Val[2] = adc_rssi2_ua
    if ((RSSI_Val[1] < RSSI_MIN) or (RSSI_Val[2] < RSSI_MIN)):
        RSSI_Val[0] = False
    else:
        RSSI_Val[0] = True

    return RSSI_Val

def readFPGA_Temp():
    # read FPGA temperature
    tempRaw = read_reg('BEFE.GEM.OH.OH%d.FPGA.ADC.CTRL.DATA_OUT' % OH_NUM)
    temp = ((tempRaw >> 4) * 503.975 / 4096) - 273.15
    return temp

def readTEMP():
    TEMP_Val = [0,0,0,0,0]
    # read SCA temperature
    # Channel 31 [SCA internal Temp]
    adc_sca_temp = SCA_Temp_Intercept + SCA_Temp_Slope*(readScaAdc(OH_NUM,31))
    # Channels 13-16 [Temperature Sensors]
    adc_u2_ohm = (readScaAdc(OH_NUM,13) / (readScaAdc(OH_NUM,17) / 1000))
    adc_u2_temp = PT1000_Intercept + PT1000_Slope*adc_u2_ohm;
    adc_u3_ohm = (readScaAdc(OH_NUM,14) / (readScaAdc(OH_NUM,17) / 1000))
    adc_u3_temp = PT1000_Intercept + PT1000_Slope*adc_u3_ohm;
    adc_u22_ohm = (readScaAdc(OH_NUM,15) / (readScaAdc(OH_NUM,17) / 1000))
    adc_u22_temp = PT1000_Intercept + PT1000_Slope*adc_u22_ohm;
    adc_u8_ohm = (readScaAdc(OH_NUM,16) / (readScaAdc(OH_NUM,17) / 1000))
    adc_u8_temp = PT1000_Intercept + PT1000_Slope*adc_u8_ohm;
    TEMP_Val[0] = adc_sca_temp
    TEMP_Val[1] = adc_u2_temp
    TEMP_Val[2] = adc_u3_temp
    TEMP_Val[3] = adc_u22_temp
    TEMP_Val[4] = adc_u8_temp
    return TEMP_Val

def readVOLT():
    VOLT_Val = [0,0,0,0,0,0]
    # read the SCA ADCs
    write_reg('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.LINK_ENABLE_MASK', OH_MASK)
    sleep(0.01)
    sendScaCommand([OH_NUM], 0x14, 0x60, 0x4, 0x00e00300, False) # setup current sources
    sleep(0.01)
    # Channels 0-5 [Voltages]
    adc_1v0 = readScaAdc(OH_NUM, 0) * 0.004
    adc_1v0avcc = readScaAdc(OH_NUM, 1) * 0.004
    adc_1v2avtt = readScaAdc(OH_NUM, 2) * 0.004
    adc_1v8 = readScaAdc(OH_NUM, 3) * 0.004
    adc_1v5 = readScaAdc(OH_NUM, 4) * 0.004
    adc_2v5 = readScaAdc(OH_NUM, 5) * 0.004
    VOLT_Val[0] = adc_1v0
    VOLT_Val[1] = adc_1v0avcc
    VOLT_Val[2] = adc_1v2avtt
    VOLT_Val[3] = adc_1v8
    VOLT_Val[4] = adc_1v5
    VOLT_Val[5] = adc_2v5
    return VOLT_Val

def readCURR():
    CURR_Val = [0,0,0,0,0,0]
    # Channels 8-12 [FEAST Currents]
    adc_feast1_a = (readScaAdc(OH_NUM,8) * 4) / (200)   # 1.8V
    adc_feast2_a = (readScaAdc(OH_NUM,9) * 4) / (200)   # 1.5V
    adc_feast3_a = (readScaAdc(OH_NUM,10) * 4) / (200)  # 2.5V
    adc_feast4_a = (readScaAdc(OH_NUM,11) * 4) / (200)  # Analog  VFAT power (unused in radtest)
    adc_feast5_a = (readScaAdc(OH_NUM,12) * 4) / (200)  # Digital VFAT power (unused in radtest)
    CURR_Val[0] = adc_feast1_a
    CURR_Val[1] = adc_feast2_a
    CURR_Val[2] = adc_feast3_a
    CURR_Val[3] = adc_feast4_a
    CURR_Val[4] = adc_feast5_a
    curr_Mirror_Cal = (readScaAdc(OH_NUM,17))
    CURR_Val[5] = curr_Mirror_Cal
    return CURR_Val


def readScaAdc(oh, channel):
    sendScaCommand([oh], 0x14, 0x50, 0x4, channel << 24, False)
    res = sendScaCommand([oh], 0x14, 0x02, 0x4, 1 << 24, True)[0]
    res = (res >> 24) + ((res >> 8) & 0xff00)
    if (res > 0xfff):
        return -1.0
    res_mv = ((1.0 / 0xfff) * float(res)) * 1000
    sleep(0.01)
    return res_mv

def myprint(msg, isError = False):
    col = Colors.RED if isError else Colors.GREEN
    print(col + "===> " + msg + Colors.ENDC)

def CmdOut_Curr(rdata):
    ostr_head = "Currents:"
    ostr_data = "    [A] "
    for x in range(len(rdata)):
        ostr_head = ostr_head + "\t" + CURR_HEAD[x]
        ostr_data = ostr_data + "\t" + Colors.GREEN + str(rdata[x]) + Colors.ENDC
    print(ostr_head)
    print(ostr_data)

def SemTolCheck(rdata):
    if(rdata[1] >= SEM1_DMAX):
        rdata[0] = "FAIL: " + Colors.RED + str(rdata[0]) + Colors.ENDC
        rdata[1] = "FAIL: " + Colors.RED + str(rdata[1]) + Colors.ENDC
    else:
        rdata[0] = Colors.GREEN + str(rdata[0]) + Colors.ENDC
        rdata[1] = Colors.GREEN + str(rdata[1]) + Colors.ENDC
    if(rdata[3] >= SEM2_DMAX):
        rdata[2] = Colors.RED + str(rdata[2]) + Colors.ENDC
        rdata[3] = Colors.RED + str(rdata[3]) + Colors.ENDC
    else:
        rdata[2] = Colors.GREEN + str(rdata[2]) + Colors.ENDC
        rdata[3] = Colors.GREEN + str(rdata[3]) + Colors.ENDC
    return rdata

def CmdOut_SEM(rdata):
    sem = SemTolCheck(rdata)
    ostr_head = "SEM Monitors:"
    ostr_data = "    [.] "
    for x in range(len(sem)):
        ostr_head = ostr_head + "\t" + SEM_HEAD[x]
        ostr_data = ostr_data + "\t" + sem[x]
    print(ostr_head)
    print(ostr_data)

def RssiTolCheck(rdata):
    for i in range(len(rdata)):
        if((rdata[i] < RSSI_MIN)):
            rdata[i] = "FAIL: " + Colors.RED + str(rdata[i]) + Colors.ENDC
        elif((rdata[i] < RSSI_WARN)):
            rdata[i] = Colors.YELLOW + str(rdata[i]) + Colors.ENDC
        else:
            rdata[i] = Colors.GREEN + str(rdata[i]) + Colors.ENDC
    return rdata

def CmdOut_RSSI(rdata):
        rssi = RssiTolCheck(rdata)
        ostr_head = "VTRX Strength:"
        ostr_data = "    [uA] "
        for x in range(len(rssi)):
                ostr_head = ostr_head + "\t" + RSSI_HEAD[x]
                ostr_data = ostr_data + "\t" + rssi[x]
        print(ostr_head)
        print(ostr_data)

def SymmTolCheck(rdata, nom, tol_warn, tol_max):
    for i in range(len(rdata)):
        if((rdata[i] > nom[i]*(1+tol_max)) or (rdata[i] < nom[i]*(1-tol_max))):
            rdata[i] = "FAIL: " + Colors.RED + str(rdata[i]) + Colors.ENDC
        elif((rdata[i] > nom[i]*(1+tol_warn)) or (rdata[i] < nom[i]*(1-tol_warn))):
            rdata[i] = Colors.YELLOW + str(rdata[i]) + Colors.ENDC
        else:
            rdata[i] = Colors.GREEN + str(rdata[i]) + Colors.ENDC
    return rdata

def CmdOut_VOLT(rdata):
    volts = SymmTolCheck(rdata,VOLT_NOM,VOLT_WARN,VOLT_MAX)
    ostr_head = "Voltages:"
    ostr_data = "    [V] "
    for x in range(len(volts)):
        ostr_head = ostr_head + "\t" + VOLT_HEAD[x]
        ostr_data = ostr_data + "\t" + volts[x]
    print(ostr_head)
    print(ostr_data)

def TempTolCheck(temps):
    for i in range(len(temps)):
        if(temps[i] > TEMP_MAX):
            temps[i] = "FAIL: " + Colors.RED + str(temps[i]) + Colors.ENDC
        elif(temps[i] > TEMP_WARN):
            temps[i] = Colors.YELLOW + str(temps[i]) + Colors.ENDC
        else:
            temps[i] = Colors.GREEN + str(temps[i]) + Colors.ENDC
    return temps

def CmdOut_TEMP(rdata):
    temps = TempTolCheck(rdata)
    ostr_head = "Temperature:"
    ostr_data = "    [C] "
    for x in range(len(temps)):
        ostr_head = ostr_head + "\t" + TEMP_HEAD[x]
        ostr_data = ostr_data + "\t" + temps[x]
    print(ostr_head)
    print(ostr_data)

def Copy(Arr):
    Out_Arr = []
    for x in Arr:
        Out_Arr.append(x)

    return Out_Arr

if __name__ == '__main__':
    parse_xml()
    ADC_Test()
