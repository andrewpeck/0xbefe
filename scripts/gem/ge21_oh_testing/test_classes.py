#import numpy as np
from common.utils import *
import datetime

N_PHASES = 15
N_SBIT = 8
N_VFAT = 12

class XML_HEADER:
    def __init__(self):
        self.ET_NAME = "OH_QC"
        self.NAME = "OptoHybrid Quality Control"
        return


class HW_Info:

    def __init__(self):
        self.KIND_OF_PART = 'GEM Opto Hybrid V3'
        self.OH_SERIAL_NUMBER = raw_input("What board number are you testing? ")
        self.VERSION = 3
        self.PRODUCTION_OH = True
        self.FPGA_DNA = 12310230131230
        self.SCA_SERIAL = 1141
        self.GEB_ID = 10101
        self.FUSING_DATE = '20210606'
        if(raw_input("Did you fuse this board today? ")=="y"):
            today=datetime.datetime.now()
            self.FUSING_DATE=today.strftime("%Y%m%d")
        else:
            self.FUSING_DATE=input("When was it fused (enter as YYYYMMDD eg 20210615)? ")
        self.GBT_0_SERIAL = 1123409
        self.GBT_1_SERIAL = 2530992
        self.GBT_0_FUSE_FILE = 'GBTX_GE21_OHv2_GBT_0_minimal_2020-01-17.txt'
        self.GBT_1_FUSE_FILE = 'GBTX_GE21_OHv2_GBT_1_minimal_2020-01-31.txt'
        if(raw_input("Did you fuse GBT0 with file GBTX_GE21_OHv2_GBT_0_minimal_2020-01-17.txt? ")!="y"):
            self.GBT_0_FUSE_FILE = raw_input("What GBT0 fuse file did you use? ")
        if(raw_input("Did you fuse GBT1 with file GBTX_GE21_OHv2_GBT_1_minimal_2020-01-31.txt? ")!="y"):
            self.GBT_1_FUSE_FILE = raw_input("What GBT1 fuse file did you use? ")
        self.GBT_0_TEST_FILE = 'GBTX_GE21_OHv2_GBT_0_minimal_2020-01-17.txt'
        self.GBT_1_TEST_FILE = 'GBTX_GE21_OHv2_GBT_1_minimal_2020-01-31.txt'
        return

class Test_Condition:
    def __init__(self):
        self.RUN_TYPE = 'OH Routine'
        self.RUN_NUMBER = raw_input("What is the run number?" )
        today=datetime.datetime.now()
        self.RUN_BEGIN_TIMESTAMP = today.strftime("%Y%m%d_%H-%M")
        self.RUN_END_TIMESTAMP =  '20210606_00-10'
        self.LOCATION = "TAMU"
        self.USER = 'Cameron Wetzel'
        self.COMMENT = "comment description"
        return

class ADC_Data:
    def __init__(self):
        self.RSSI_1_INIT = 512.1
        self.RSSI_2_INIT = 499.8

        self.FPGA_CORE_V = 0.998
        self.MGTAVCC = 1.001
        self.MGTAVTT = 1.299

        self.FEAST_1_V = 1.803
        self.FEAST_1_I = 1.1
        self.FEAST_2_V = 1.499
        self.FEAST_2_I = 0.678
        self.FEAST_3_V = 2.499
        self.FEAST_3_I = 0.345

        self.FEAST_4_I = 0.289
        self.FEAST_5_I = 0.87

        self.GBT_1_TEMP = 38.6
        self.GBT_2_TEMP = 37.5
        self.VTRX_TEMP = 40.1
        self.LDO_1v5_TEMP = 33.6
        self.SCA_TEMP = 41.8

        self.GND_1K_I = 98.67
        self.RSSI_1_MID = 505.3
        self.RSSI_2_MID = 489.7
        self.GBT_0_QP_I = 123
        self.GBT_1_QP_I = 123

        self.FPGA_TEMP = 45.1

        self.RSSI_1_END = 505.3
        self.RSSI_2_END = 489.7
        return
    def set_RSSI_Init(self,RSSI_READING):
        self.RSSI_1_INIT = RSSI_READING[1]
        self.RSSI_2_INIT = RSSI_READING[2]
        return

    def set_RSSI_End(self,RSSI_READING):
        self.RSSI_1_END = RSSI_READING[1]
        self.RSSI_2_END = RSSI_READING[2]
        return
    def set_ADC_Readings(self,ADC_READINGS):
        self.RSSI_1_MID = ADC_READINGS[0][0]
        self.RSSI_2_MID = ADC_READINGS[0][1]

        self.FPGA_CORE_V = ADC_READINGS[2][0]
        self.MGTAVCC = ADC_READINGS[2][1]
        self.MGTAVTT = ADC_READINGS[2][2]

        self.FEAST_1_V = ADC_READINGS[2][3]
        self.FEAST_1_I = ADC_READINGS[3][0]
        self.FEAST_2_V = ADC_READINGS[2][4]
        self.FEAST_2_I = ADC_READINGS[3][1]
        self.FEAST_3_V = ADC_READINGS[2][5]
        self.FEAST_3_I = ADC_READINGS[3][2]

        self.FEAST_4_I = ADC_READINGS[3][3]
        self.FEAST_5_I = ADC_READINGS[3][4]

        self.GBT_1_TEMP = ADC_READINGS[1][2]
        self.GBT_2_TEMP = ADC_READINGS[1][3]
        self.VTRX_TEMP = ADC_READINGS[1][4]
        self.LDO_1v5_TEMP = ADC_READINGS[1][5]
        self.SCA_TEMP = ADC_READINGS[1][1]

        self.GND_1K_I = ADC_READINGS[4]

        # !!!!! NEEDS PROCESS !!!!!!!
        #self.GBT_0_QP_I = 123
        #self.GBT_1_QP_I = 123
        return

    def set_FPGA_Temp(self,FPGA_TEMP_in):
        self.FPGA_TEMP = FPGA_TEMP_in
        return

class Test_Result:
    def __init__(self):
        # Initialize with All Results Bad, Set good throughout Test Process
        self.All_TEST_PASSED = False
        self.CTP7_COMM_GOOD = False
        self.VTTX_OPTICAL_LINK_GOOD = False
        self.PROMLESS_LOAD_PATH_GOOD = False
        self.ADC_READINGS_GOOD = False
        self.VFAT_ELINK_PHASE_SCAN_GOOD = False
        self.FPGA_ELINK_PRBS_GOOD = False
        self.ALL_SBIT_GOOD = False

        self.PROMLESS_LOAD_CYCLES = 0
        return

    def Validate_Sys_Init(self, Init_Status):
        # Verifies System Initialized Properly
        # Checking if GBT 0 and GBT 1 Configured correctly
        # Inputs [Bool , Bool]... both should be True
        ret = False
        if len(Init_Status) != 2:
            print(Colors.RED + 'Something Went Wrong...' + Colors.ENDC)
        elif Init_Status[0] and Init_Status[1]:
            print(Colors.GREEN + 'SUCCESS:' + Colors.ENDC + ' OH\'s GBT 1 & 2 Initialized')
            ret = True
        else:
            if not Init_Status[0]:
                print(Colors.RED + 'ERROR' + Colors.ENDC + ' GBT 0 Was not Initialized Correctly')
            if not Init_Status[1]:
                print(Colors.RED + 'ERROR' + Colors.ENDC + ' GBT 1 Was not Initialized Correctly')

        return ret

    def Validate_CTP7_COMM(self, CTP7_COMM_Result):
        # Verify CTP7 <=> OH are communicating Properly
        # Expected Input :
        #   CTP7_COMM_Result[0] = GBT_Results
        #   CTP7_COMM_Result[1] = SCA_Results
        # Format  ==  [ Bool 'All good' , {list of Error messages} ]

        if CTP7_COMM_Result[0][0] and CTP7_COMM_Result[1][0]:
            self.CTP7_COMM_GOOD = True
            print(Colors.GREEN +  'SUCCESS: ' + Colors.ENDC + ' Communication with CTP7 <--> OH is Good')
            return True
        else:
            self.CTP7_COMM_GOOD = False
            for ii in range(len(CTP7_COMM_Result)):
                for xx in range(len(CTP7_COMM_Result[ii][1])):
                    print(Colors.RED + 'ERROR: ' + Colors.ENDC + CTP7_COMM_Result[ii][1][xx])
            return False

    def Validate_Promless_Load(self, LOAD_CYCLES, ATTEMPTED_CYCLES):
        # Verify FPGA could reload >1000 times w/out Failure
        if(LOAD_CYCLES == ATTEMPTED_CYCLES):
            self.PROMLESS_LOAD_PATH_GOOD = True

        return self.PROMLESS_LOAD_PATH_GOOD

    def Validate_VTTX_Optical_Link(self, VTTX_Link_Result):
        # FIX ME!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        self.VTTX_OPTICAL_LINK_GOOD = True
        return

    def Validate_ADC_Reading(self, ADC_Result):
        # FIX ME!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        self.ADC_READINGS_GOOD = True
        return self.ADC_READINGS_GOOD

    def Validate_VFAT_ELINK_Phase(self, ELINK, VFAT_Phase_Result):
        # FIX ME!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        self.VFAT_ELINK_PHASE_SCAN_GOOD = VFAT_Phase_Result
        return self.VFAT_ELINK_PHASE_SCAN_GOOD

    def Validate_FPGA_ELINK_Phase(self, FPGA_Phase_Result):
        # FIX ME!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        self.FPGA_ELINK_PRBS_GOOD = True
        return Best_Phases

    def Validate_PRBS_BER(self, BER_Result):
        # FIX ME!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        self.FPGA_ELINK_PRBS_GOOD = True
        return

    def Validate_SBIT(self, SBIT_Result):
        # FIX ME!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        self.ALL_SBIT_GOOD = True
        return

    def Validate_ALL_Tests(self):
        self.All_TEST_PASSED = ((self.CTP7_COMM_GOOD))
        self.All_TEST_PASSED = (self.All_TEST_PASSED and (self.VTTX_OPTICAL_LINK_GOOD))
        self.All_TEST_PASSED = (self.All_TEST_PASSED and (self.PROMLESS_LOAD_PATH_GOOD))
        self.All_TEST_PASSED = (self.All_TEST_PASSED and (self.ADC_READINGS_GOOD))
        self.All_TEST_PASSED = (self.All_TEST_PASSED and (self.VFAT_ELINK_PHASE_SCAN_GOOD))
        self.All_TEST_PASSED = (self.All_TEST_PASSED and (self.FPGA_ELINK_PRBS_GOOD))
        self.All_TEST_PASSED = (self.All_TEST_PASSED and (self.ALL_SBIT_GOOD))
        return self.All_TEST_PASSED

class GBT_ELINK:
    def __init__(self,gbt,elink,arg_1, arg_2):
        self.GBT = gbt
        self.ELINK = elink

        if elink > 5:
            self.BER = arg_1
        elif len(arg_1) < N_PHASES or len(arg_2) < N_PHASES or len(arg_1) != len(arg_2):
            print('Error Invalid size of Phase Arrays!')
        else:
            self.LINK_GOOD = arg_1
            self.SYNC_ERR_CNT = arg_2
        return

def QContinue(flag):
    if(flag):
        if(raw_input("There was a failure, would you like to continue? ")=="y"):
            print("Continuing tests")
            return true
        else:
            return false
        return true

def endTest(c):
    today=datetime.now()
    c.RUN_END_TIMESTAMP = today.strftime("%Y%m%d_%H-%M")
    print("Tests ended")
