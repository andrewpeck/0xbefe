import os
import sys

from test_classes import *
from test_config import *
from test_utils import *
from ADC_read import *
from oh_fw_programming import *
from phase_scan import *
from loopback import *
from vttx_optical_link import *
# from sbit_timing_scan_oh_sbit_hitmap import *

from gem.init_backend import init_gem_backend
from gem.init_frontend import init_gem_frontend
from gem.gbt import *
from gem.sca import *
from gem.sbit_scan_oh_hitmap import *

import xml.etree.ElementTree as ET
from xml.dom import minidom
from xml import etree
# from lxml import etree


WORKING_DIR = get_befe_scripts_dir() + "/gem/ge21_oh_testing"
# WORKING_DIR = os.getcwd()

Serial = "dummy_file"
OutputPath = WORKING_DIR+"/database/"
xml_head = XML_HEADER()
hw_info = HW_Info()
test_conditions = Test_Condition()
test_conditions.LOCATION = TEST_STAND_LOCATION
VERBOSE = False
COLD_BOOT = False

MWRD_LIMIT = MWRD_LIMIT_FULL
PROMless_Load_Iters = PROMless_Load_Iters_FULL
VTTX_testing_time = VTTX_testing_time_FULL
IS_REDUCED = False

if len(sys.argv) > 1:
    if sys.argv[1] == "PARTIAL":
        print("=========================== Running in partial testing mode ===========================")
        MWRD_LIMIT = MWRD_LIMIT_REDUCED
        PROMless_Load_Iters = PROMless_Load_Iters_REDUCED
        VTTX_testing_time = VTTX_testing_time_REDUCED
        IS_REDUCED = True

if not IS_REDUCED:
    print("=========================== Running in FULL testing mode ===========================")


def main():
    # Set the Serial Number based on User Input from Test_Condition Constructor
    OutputPath = WORKING_DIR + "/database/"
    Serial = hw_info.OH_SERIAL_NUMBER
    print(OutputPath)
    OutputPath = CheckRunNumber(Serial, test_conditions, OutputPath)
    print(OutputPath)

    testStatus = Test_Result()
    ADC_Reading = ADC_Data()
    ELINKS = []  # Array stores ELINK Best Phases + relevant Data
    VFATS = []  # Array stores VFAT S-bit results

    # Initialize OH / CTP7 System for Testing
    Init_Status = OH_sys_init(COLD_BOOT)
    print(Init_Status)  # Replace w testStatus Method
    testStatus.Validate_Sys_Init(Init_Status)

    # Validate Proper CTP7 <-> OH Communications
    CTP7_OH_Comm_Result = Check_CTP7_OH_Comm(VERBOSE)
    print(CTP7_OH_Comm_Result)  # Replace w/ testStatus Method
    testStatus.Validate_CTP7_COMM(CTP7_OH_Comm_Result)

    ADC_Reading.set_RSSI_Init(readRSSI())
    print('RSSI Initial Reading')
    print('RSSI1: '+str(ADC_Reading.RSSI_1_INIT) +
          ' RSSI2: '+str(ADC_Reading.RSSI_2_INIT))

    # Test PROMless FPGA load path
    PROMLESS_LOAD_CYCLES = program_fw_iter(PROMless_Load_Iters)
    testStatus.PROMLESS_LOAD_CYCLES = PROMLESS_LOAD_CYCLES
    print('Successful FW Load Iters = ' + str(PROMLESS_LOAD_CYCLES))
    testStatus.Validate_Promless_Load(
        PROMLESS_LOAD_CYCLES, PROMless_Load_Iters)

    # Check VTTX Optical Link Health
    # print_red("Skipping VTTX optical link test since OTMB receivers are not implemented in CVP13")
    VTTX_Optical_Result = Check_VTTX_Optical_Link(VERBOSE, VTTX_testing_time)
    print(VTTX_Optical_Result)
    testStatus.Validate_VTTX_Optical_Link(VTTX_Optical_Result)

    # Check ADC Readings
    ADC_Check_Result = ADC_Test()
    ADC_Reading.set_ADC_Readings(ADC_Check_Result)
    testStatus.Validate_ADC_Reading(ADC_Check_Result)

    # PRBS Scan
    load_fw_prbs()
    sleep(0.1)
    # Switch to PRBS firmware
    # program_fw_single(VERBOSE)
    # check_current_fw()
    #FPGA_Phase_Result = scan_FPGA_integrated()
    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    #!!!!!!!!!!! ADD PRBS FUNCTION !!!!!!!!!!
    BER_Result = PRBS_Loopback_Test()
    testStatus.Validate_PRBS_BER(BER_Result, BER_Acceptance_Criteria)

    # Switch to Full FW:
    load_fw_full()
    sleep(0.1)
    resetSca()
    program_fw_single()

    # VFAT PHASE SCAN
    VFAT_Phase_Result = VFAT_Phase_Scan(VERBOSE)
    testStatus.Validate_VFAT_ELINK_Phase(
        VFAT_Phase_Result[1], VFAT_Phase_Result[0])
    ELINKS = VFAT_Phase_Result[1]
    ELINKS = ELINKS + BER_Result

    # Perform VFAT S-bits Tests
    VFATS = sbit_phase_scan(0, 0, 11, VERBOSE, True)
    testStatus.Validate_SBIT(VFATS)

    # Do Final Check All Tests Passed
    testStatus.Validate_ALL_Tests()

    # After all variables are gathered than generate the XML header
    root, DataSet = BuildRunCommonXML(
        xml_head, hw_info, test_conditions, "all", "all")
    root, DataSet = FillXML(root, DataSet, testStatus,
                            ADC_Reading, ELINKS, VFATS)

    gbt_qc, DataSet = BuildRunCommonXML(
        xml_head, hw_info, test_conditions, "OH_GBT_QC", "GE21 OH GBT")
    gbt_qc, DataSet = Make_GBT_QC_XML(gbt_qc, DataSet, ELINKS)

    gbt_sbit, DataSet = BuildRunCommonXML(
        xml_head, hw_info, test_conditions, "OH_SBIT_QC", "GE21 OH SBIT")
    gbt_sbit, DataSet = Make_GBT_SBIT_XML(gbt_sbit, DataSet, VFATS)

    oh_qc, DataSet = BuildRunCommonXML(
        xml_head, hw_info, test_conditions, "OH_QC", "GE21 OH QC Hardware")
    oh_qc, DataSet = Make_OH_QC_XML(
        oh_qc, DataSet, hw_info, test_conditions, testStatus, ADC_Reading)
    WriteRunXML(root, gbt_qc, gbt_sbit, oh_qc,
                Serial, test_conditions, OutputPath)

    return


def OH_sys_init(Cold_boot_tf=False):
    parse_xml()

    if(Cold_boot_tf):
        init_gem_backend()

    init_gem_frontend()
    gbt_0_ready = checkGbtReady(0, 0)
    gbt_1_ready = checkGbtReady(0, 0)

    # Returns status of GBT Configuration Attempt
    return [gbt_0_ready, gbt_1_ready]


def Check_CTP7_OH_Comm(verbose=False):

    # Perform Link Reset : clear gbt flags
    gbt_link_reset()
    sleep(0.1)

    # read GBT 0 status flags
    GBT_0_Status = read_GBT_Status(0, verbose)
    # read GBT 1 status flags
    GBT_1_Status = read_GBT_Status(1, verbose)

    # Interpret results from GBT status reads
    GBT_Results = Check_GBT_Flags(GBT_0_Status, GBT_1_Status, verbose)

    # Reset SCA , Clear Error Counters
    SCA_reset()
    sleep(0.1)

    # Read SCA Status Flags
    SCA_Status = read_SCA_Status(verbose)

    # Interpret SCA Status Flags
    SCA_Results = Check_SCA_Flags(SCA_Status, verbose)

    # Return Results of GBTx & SCA Status Checks
    return [GBT_Results, SCA_Results]


def Check_VTTX_Optical_Link(verbose=False, testing_time=300):
    print("Testing VTTX optical link")

    # Reset Trigger Module
    Trigger_reset()

    # read relevant VTTX Registers
    sleep(testing_time)
    VTTX_Reading = read_vttx_optical_link(verbose)
    # Check that VTTX readings were good
    VTTX_Test_Result = check_vttx_optical_link_result(VTTX_Reading, verbose)

    return VTTX_Test_Result


def VFAT_Phase_Scan(verbose=False):
    # Perform the VFAT Phase Scan, {Best Phases are programmed here}
    vfat_Scan_Data = scan_VFAT_integrated(verbose)

    # Organize Data
    ALL_PHASE_GOOD = vfat_Scan_Data[0]
    GBT_0_Data = vfat_Scan_Data[1]
    GBT_1_Data = vfat_Scan_Data[2]

    ELINKS_out = []

    # Format GBT_0
    for elink in range(0, 6):
        ELINKS_out.append(GBT_ELINK(
            0, elink, GBT_0_Data[0][elink], GBT_0_Data[1][elink], GBT_0_Data[2][elink]))
        if(verbose):
            print('GBT0 ELINK' + str(elink)+' Container Contents:')
            print(ELINKS_out[-1].LINK_GOOD)
            print(ELINKS_out[-1].SYNC_ERR_CNT)
            print(ELINKS_out[-1].DAQ_CRC_ERR_CNT)
    # Format GBT_1
    for elink in range(0, 6):
        ELINKS_out.append(GBT_ELINK(
            1, elink, GBT_1_Data[0][elink], GBT_1_Data[1][elink], GBT_1_Data[2][elink]))
        if(verbose):
            print('GBT1 ELINK' + str(elink)+' Container Contents:')
            print(ELINKS_out[-1].LINK_GOOD)
            print(ELINKS_out[-1].SYNC_ERR_CNT)
            print(ELINKS_out[-1].DAQ_CRC_ERR_CNT)

    return [ALL_PHASE_GOOD, ELINKS_out]


def PRBS_Loopback_Test(Verbose=False):
    print("Running PRBS loopback test")
    FPGA_ELINKS = []  # Container for Output ELINK Objects
    # SCA Reset for Extra Safety
    resetSca()
    sleep(1)
    # Load PRBS firmware to CTP7
    load_fw_prbs()
    print("fw loaded!!!")
    # Program the PRBS firmware to OH FPGA
    program_fw_single()
    print("fw programmed!!!")
    # Double Check the Firmware
    if(Verbose):
        check_current_fw()
    # Do Phase Scan on FPGA (integrated => best phase is programmed within)
    scan_FPGA_integrated()
    # Make sure to Select OptoHybrid
    select_OH(0)
    # clear Loopback Counters before starting...
    clear_loopback_counters()
    # Enable Loopback Mode
    enable_loopback()

    # Start PRBS Loop, Runs until all MWRD Count >= MWRD_LIMIT
    PRBS_counts = prbs_loop(MWRD_LIMIT, Verbose)

    # Disable Loopback Mode once Limits are reached
    disable_loopback()

    # Convert Data to ELINK Containers for DB output
    for gbt in range(0, 2):
        for elink in PRBS_ELINKS[gbt]:
            FPGA_ELINKS.append(GBT_ELINK(
                gbt, elink, (PRBS_counts[gbt][elink-6][1]/(7*PRBS_counts[gbt][elink-6][0]*10**6)), 0, 0))

    return FPGA_ELINKS


def Make_GBT_SBIT_XML(root, DataSet, VFATS):
    for vfat in VFATS:
        #Sbit = ET.SubElement(DataSet,'DATA')
        #head_Vfat = 'VFAT_'+str(vfat.VFAT)
        Vfat_ET = ET.SubElement(DataSet, 'DATA')
        WriteField = ET.SubElement(Vfat_ET, "VFAT_NUMBER")
        WriteField.text = str(vfat.VFAT)
        WriteField = ET.SubElement(Vfat_ET, "SBIT_CENTER")
        WriteField.text = ", ".join(map(str, vfat.SBIT_CENTER))
        WriteField = ET.SubElement(Vfat_ET, "SBIT_BEST_DLY")
        WriteField.text = ", ".join(map(str, vfat.SBIT_BEST_DLY))
        WriteField = ET.SubElement(Vfat_ET, "SBIT_WIDTH")
        WriteField.text = ", ".join(map(str, vfat.SBIT_WIDTH))
    return root, DataSet


def Make_GBT_QC_XML(root, DataSet, ELINKS):
    #Elink = ET.SubElement(root,'ELINK_RESULT')
    for gbt in range(2):
        #Elink = ET.SubElement(DataSet, 'DATA')
        #head_gbt = "GBT_"+str(gbt)
        #Gbt = ET.SubElement(Elink,head_gbt)
        for elink in ELINKS:
            if(elink.GBT == gbt):
                Elink = ET.SubElement(DataSet, 'DATA')
                WriteField = ET.SubElement(Elink, 'GBT_NUMBER')
                WriteField.text = str(gbt)
                WriteField = ET.SubElement(Elink, 'ELINK')
                WriteField.text = str(elink.ELINK)
                if(hasattr(elink, 'BER')):
                    WriteField = ET.SubElement(Elink, 'BER')
                    WriteField.text = str(elink.BER)
                if(hasattr(elink, 'LINK_GOOD')):
                    WriteField = ET.SubElement(Elink, 'LINK_GOOD')
                    WriteField.text = ", ".join(map(str, elink.LINK_GOOD))
                if(hasattr(elink, 'SYNC_ERR_CNT')):
                    WriteField = ET.SubElement(Elink, 'SNYC_ERR_CNT')
                    WriteField.text = ", ".join(map(str, elink.SYNC_ERR_CNT))
                #if(hasattr(elink, 'DAQ_CRC_ERR_CNT')):
                #    WriteField = ET.SubElement(Elink, 'DAQ_CRC_ERR_CNT')
                #    WriteField.text = ", ".join(map(str, elink.DAQ_CRC_ERR_CNT))

    return root, DataSet


def Make_OH_QC_XML(root, DataSet, hw_info, test_conditions, test_results, adc_reading):
    Part = ET.SubElement(DataSet, 'DATA')
    WriteField = ET.SubElement(Part, 'VERSION')
    WriteField.text = str(4)
    WriteField = ET.SubElement(Part, 'OH_SERIAL_NUMBER')
    WriteField.text = str(hw_info.OH_SERIAL_NUMBER).zfill(4)
    WriteField = ET.SubElement(Part, 'PRODUCTION_OH')
    WriteField.text = str(hw_info.PRODUCTION_OH)
    WriteField = ET.SubElement(Part, 'FPGA_DNA')
    WriteField.text = str(hw_info.FPGA_DNA)
    WriteField = ET.SubElement(Part, 'SCA_SERIAL')
    WriteField.text = str(hw_info.SCA_SERIAL)
    WriteField = ET.SubElement(Part, 'GEB_ID')
    WriteField.text = str(hw_info.GEB_ID)
    WriteField = ET.SubElement(Part, 'FUSING_DATE')
    #stdFormatTimestamp = datetime.datetime.strptime(hw_info.FUSING_DATE,'%Y%m%d_%H-%M')
    #WriteField.text = datetime.datetime.strftime(stdFormatTimestamp,'%Y-%m-%d %H:%M:%S')
    WriteField.text = str(hw_info.FUSING_DATE)
    WriteField = ET.SubElement(Part, 'GBT_0_SERIAL')
    WriteField.text = str(hw_info.GBT_0_SERIAL)
    WriteField = ET.SubElement(Part, 'GBT_1_SERIAL')
    WriteField.text = str(hw_info.GBT_1_SERIAL)
    WriteField = ET.SubElement(Part, 'GBT_0_FUSE_FILE')
    WriteField.text = str(hw_info.GBT_0_FUSE_FILE)
    WriteField = ET.SubElement(Part, 'GBT_1_FUSE_FILE')
    WriteField.text = str(hw_info.GBT_1_FUSE_FILE)
    WriteField = ET.SubElement(Part, 'GBT_0_TEST_FILE')
    WriteField.text = str(hw_info.GBT_0_TEST_FILE)
    WriteField = ET.SubElement(Part, 'GBT_1_TEST_FILE')
    WriteField.text = str(hw_info.GBT_1_TEST_FILE)

    #Data = ET.SubElement(DataSet, 'TEST_RESULTS')
    PassFail = Part  # ET.SubElement(Data,'PASS_FAIL')
    WriteField = ET.SubElement(PassFail, 'ALL_TEST_PASSED')
    WriteField.text = str(int(test_results.All_TEST_PASSED))
    WriteField = ET.SubElement(PassFail, 'CTP7_COMM_GOOD')
    WriteField.text = str(int(test_results.CTP7_COMM_GOOD))
    WriteField = ET.SubElement(PassFail, 'VTTX_OPTICAL_LINK_GOOD')
    WriteField.text = str(int(test_results.VTTX_OPTICAL_LINK_GOOD))
    WriteField = ET.SubElement(PassFail, 'PROMLESS_LOAD_PATH_GOOD')
    WriteField.text = str(int(test_results.PROMLESS_LOAD_PATH_GOOD))
    WriteField = ET.SubElement(PassFail, 'ADC_READINGS_GOOD')
    WriteField.text = str(int(test_results.ADC_READINGS_GOOD))
    WriteField = ET.SubElement(PassFail, 'VFAT_ELINK_PHASE_SCAN_GOOD')
    WriteField.text = str(int(test_results.VFAT_ELINK_PHASE_SCAN_GOOD))
    WriteField = ET.SubElement(PassFail, 'FPGA_ELINK_PRBS_GOOD')
    WriteField.text = str(int(test_results.FPGA_ELINK_PRBS_GOOD))
    WriteField = ET.SubElement(PassFail, 'ALL_SBIT_GOOD')
    WriteField.text = str(int(test_results.ALL_SBIT_GOOD))

    WriteField = ET.SubElement(Part, 'PROMLESS_LOAD_CYCLES')
    WriteField.text = str(test_results.PROMLESS_LOAD_CYCLES)

    ADC_Readings = Part  # ET.SubElement(Data,'ADC_READINGS')
    WriteField = ET.SubElement(ADC_Readings, 'FPGA_CORE_V')
    WriteField.text = str(adc_reading.FPGA_CORE_V)
    WriteField = ET.SubElement(ADC_Readings, 'MGTAVCC')
    WriteField.text = str(adc_reading.MGTAVCC)
    WriteField = ET.SubElement(ADC_Readings, 'MGTAVTT')
    WriteField.text = str(adc_reading.MGTAVTT)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_1_V')
    WriteField.text = str(adc_reading.FEAST_1_V)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_1_I')
    WriteField.text = str(adc_reading.FEAST_1_I)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_2_V')
    WriteField.text = str(adc_reading.FEAST_2_V)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_2_I')
    WriteField.text = str(adc_reading.FEAST_2_I)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_3_V')
    WriteField.text = str(adc_reading.FEAST_3_V)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_3_I')
    WriteField.text = str(adc_reading.FEAST_3_I)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_4_I')
    WriteField.text = str(adc_reading.FEAST_4_I)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_5_I')
    WriteField.text = str(adc_reading.FEAST_5_I)
    WriteField = ET.SubElement(ADC_Readings, 'GBT_1_TEMP')
    WriteField.text = str(adc_reading.GBT_1_TEMP)
    WriteField = ET.SubElement(ADC_Readings, 'GBT_2_TEMP')
    WriteField.text = str(adc_reading.GBT_2_TEMP)
    WriteField = ET.SubElement(ADC_Readings, 'VTRX_TEMP')
    WriteField.text = str(adc_reading.VTRX_TEMP)
    WriteField = ET.SubElement(ADC_Readings, 'LDO_1V5_TEMP')
    WriteField.text = str(adc_reading.LDO_1v5_TEMP)
    WriteField = ET.SubElement(ADC_Readings, 'SCA_TEMP')
    WriteField.text = str(adc_reading.SCA_TEMP)
    WriteField = ET.SubElement(ADC_Readings, 'GND_1K_I')
    WriteField.text = str(adc_reading.GND_1K_I)
    WriteField = ET.SubElement(ADC_Readings, 'GBT_0_QP_I')
    WriteField.text = str(adc_reading.GBT_0_QP_I)
    WriteField = ET.SubElement(ADC_Readings, 'GBT_1_QP_I')
    WriteField.text = str(adc_reading.GBT_1_QP_I)
    WriteField = ET.SubElement(ADC_Readings, 'RSSI_1_INIT')
    WriteField.text = str(adc_reading.RSSI_1_INIT)
    WriteField = ET.SubElement(ADC_Readings, 'RSSI_2_INIT')
    WriteField.text = str(adc_reading.RSSI_2_INIT)
    WriteField = ET.SubElement(ADC_Readings, 'RSSI_1_MID')
    WriteField.text = str(adc_reading.RSSI_1_MID)
    WriteField = ET.SubElement(ADC_Readings, 'RSSI_2_MID')
    WriteField.text = str(adc_reading.RSSI_2_MID)
    WriteField = ET.SubElement(ADC_Readings, 'RSSI_1_END')
    WriteField.text = str(adc_reading.RSSI_1_END)
    WriteField = ET.SubElement(ADC_Readings, 'RSSI_2_END')
    WriteField.text = str(adc_reading.RSSI_2_END)
    WriteField = ET.SubElement(ADC_Readings, 'FPGA_TEMP')
    WriteField.text = str(adc_reading.FPGA_TEMP)
    return root, DataSet


def FillXML(root, DataSet, test_results, adc_reading, ELINKS, VFATS):
    Data = ET.SubElement(DataSet, 'TEST_RESULTS')
    PassFail = ET.SubElement(Data, 'PASS_FAIL')
    WriteField = ET.SubElement(PassFail, 'ALL_TEST_PASSED')
    WriteField.text = str(test_results.All_TEST_PASSED)
    WriteField = ET.SubElement(PassFail, 'CTP7_COMM_GOOD')
    WriteField.text = str(test_results.CTP7_COMM_GOOD)
    WriteField = ET.SubElement(PassFail, 'VTTX_OPTICAL_LINK_GOOD')
    WriteField.text = str(test_results.VTTX_OPTICAL_LINK_GOOD)
    WriteField = ET.SubElement(PassFail, 'PROMLESS_LOAD_PATH_GOOD')
    WriteField.text = str(test_results.PROMLESS_LOAD_PATH_GOOD)
    WriteField = ET.SubElement(PassFail, 'ADC_READINGS_GOOD')
    WriteField.text = str(test_results.ADC_READINGS_GOOD)
    WriteField = ET.SubElement(PassFail, 'VFAT_ELINK_PHASE_SCAN_GOOD')
    WriteField.text = str(test_results.VFAT_ELINK_PHASE_SCAN_GOOD)
    WriteField = ET.SubElement(PassFail, 'FPGA_ELINK_PRBS_GOOD')
    WriteField.text = str(test_results.FPGA_ELINK_PRBS_GOOD)
    WriteField = ET.SubElement(PassFail, 'ALL_SBIT_GOOD')
    WriteField.text = str(test_results.ALL_SBIT_GOOD)

    WriteField = ET.SubElement(Data, 'PROMLESS_LOAD_CYCLES')
    WriteField.text = str(test_results.PROMLESS_LOAD_CYCLES)

    ADC_Readings = ET.SubElement(Data, 'ADC_READINGS')
    WriteField = ET.SubElement(ADC_Readings, 'FPGA_CORE_V')
    WriteField.text = str(adc_reading.FPGA_CORE_V)
    WriteField = ET.SubElement(ADC_Readings, 'MGTAVCC')
    WriteField.text = str(adc_reading.MGTAVCC)
    WriteField = ET.SubElement(ADC_Readings, 'MGTAVTT')
    WriteField.text = str(adc_reading.MGTAVTT)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_1_V')
    WriteField.text = str(adc_reading.FEAST_1_V)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_1_I')
    WriteField.text = str(adc_reading.FEAST_1_I)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_2_V')
    WriteField.text = str(adc_reading.FEAST_2_V)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_2_I')
    WriteField.text = str(adc_reading.FEAST_2_I)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_3_V')
    WriteField.text = str(adc_reading.FEAST_3_V)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_3_I')
    WriteField.text = str(adc_reading.FEAST_3_I)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_4_I')
    WriteField.text = str(adc_reading.FEAST_4_I)
    WriteField = ET.SubElement(ADC_Readings, 'FEAST_5_I')
    WriteField.text = str(adc_reading.FEAST_5_I)
    WriteField = ET.SubElement(ADC_Readings, 'GBT_1_TEMP')
    WriteField.text = str(adc_reading.GBT_1_TEMP)
    WriteField = ET.SubElement(ADC_Readings, 'GBT_2_TEMP')
    WriteField.text = str(adc_reading.GBT_2_TEMP)
    WriteField = ET.SubElement(ADC_Readings, 'VTRX_TEMP')
    WriteField.text = str(adc_reading.VTRX_TEMP)
    WriteField = ET.SubElement(ADC_Readings, 'LDO_1V5_TEMP')
    WriteField.text = str(adc_reading.LDO_1v5_TEMP)
    WriteField = ET.SubElement(ADC_Readings, 'SCA_TEMP')
    WriteField.text = str(adc_reading.SCA_TEMP)
    WriteField = ET.SubElement(ADC_Readings, 'GND_1K_I')
    WriteField.text = str(adc_reading.GND_1K_I)
    WriteField = ET.SubElement(ADC_Readings, 'GBT_0_QP_I')
    WriteField.text = str(adc_reading.GBT_0_QP_I)
    WriteField = ET.SubElement(ADC_Readings, 'GBT_1_QP_I')
    WriteField.text = str(adc_reading.GBT_1_QP_I)
    WriteField = ET.SubElement(ADC_Readings, 'RSSI_1_INIT')
    WriteField.text = str(adc_reading.RSSI_1_INIT)
    WriteField = ET.SubElement(ADC_Readings, 'RSSI_2_INIT')
    WriteField.text = str(adc_reading.RSSI_2_INIT)
    WriteField = ET.SubElement(ADC_Readings, 'RSSI_1_MID')
    WriteField.text = str(adc_reading.RSSI_1_MID)
    WriteField = ET.SubElement(ADC_Readings, 'RSSI_2_MID')
    WriteField.text = str(adc_reading.RSSI_2_MID)
    WriteField = ET.SubElement(ADC_Readings, 'RSSI_1_END')
    WriteField.text = str(adc_reading.RSSI_1_END)
    WriteField = ET.SubElement(ADC_Readings, 'RSSI_2_END')
    WriteField.text = str(adc_reading.RSSI_2_END)
    WriteField = ET.SubElement(ADC_Readings, 'FPGA_TEMP')
    WriteField.text = str(adc_reading.FPGA_TEMP)

    Elink = ET.SubElement(Data, 'ELINK_RESULT')
    for gbt in range(2):
        head_gbt = "GBT_"+str(gbt)
        Gbt = ET.SubElement(Elink, head_gbt)
        for elink in ELINKS:
            if(elink.GBT == gbt):
                head_elink = "ELINK_"+str(elink.ELINK)
                Elink_ET = ET.SubElement(Gbt, head_elink)
                if(hasattr(elink, 'BER')):
                    WriteField = ET.SubElement(Elink_ET, 'BER')
                    WriteField.text = str(elink.BER)
                if(hasattr(elink, 'LINK_GOOD')):
                    WriteField = ET.SubElement(Elink_ET, 'LINK_GOOD')
                    WriteField.text = ", ".join(map(str, elink.LINK_GOOD))
                if(hasattr(elink, 'SYNC_ERR_CNT')):
                    WriteField = ET.SubElement(Elink_ET, 'SNYC_ERR_CNT')
                    WriteField.text = ", ".join(map(str, elink.SYNC_ERR_CNT))
                #if(hasattr(elink, 'DAQ_CRC_ERR_CNT')):
                #    WriteField = ET.SubElement(Elink, 'DAQ_CRC_ERR_CNT')
                #    WriteField.text = ", ".join(map(str, elink.DAQ_CRC_ERR_CNT))

    Sbit = ET.SubElement(Data, 'SBIT')
    for vfat in VFATS:
        head_Vfat = 'VFAT_'+str(vfat.VFAT)
        Vfat_ET = ET.SubElement(Sbit, head_Vfat)
        WriteField = ET.SubElement(Vfat_ET, "SBIT_CENTER")
        WriteField.text = ", ".join(map(str, vfat.SBIT_CENTER))
        WriteField = ET.SubElement(Vfat_ET, "SBIT_BEST_DLY")
        WriteField.text = ", ".join(map(str, vfat.SBIT_BEST_DLY))
        WriteField = ET.SubElement(Vfat_ET, "SBIT_WIDTH")
        WriteField.text = ", ".join(map(str, vfat.SBIT_WIDTH))

    return root, DataSet


def BuildRunCommonXML(xml_head, hw_info, test_conditions, xmltype, xmltype2):
    root = ET.Element('ROOT')
    Header = ET.SubElement(root, 'HEADER')
    Type = ET.SubElement(Header, 'TYPE')
    WriteField = ET.SubElement(Type, 'EXTENSION_TABLE_NAME')
    WriteField.text = xmltype
    WriteField = ET.SubElement(Type, 'NAME')
    WriteField.text = xmltype2
    Run = ET.SubElement(Header, 'RUN')
    WriteField = ET.SubElement(Run, 'RUN_TYPE')
    WriteField.text = xmltype2
    WriteField = ET.SubElement(Run, 'RUN_NUMBER')
    WriteField.text = str(test_conditions.RUN_NUMBER)

    WriteField = ET.SubElement(Run, 'RUN_BEGIN_TIMESTAMP')
    stdFormatTimestamp = datetime.datetime.strptime(
        test_conditions.RUN_BEGIN_TIMESTAMP, '%Y%m%d_%H-%M')
    WriteField.text = datetime.datetime.strftime(
        stdFormatTimestamp, '%Y-%m-%d %H:%M:%S')

    WriteField = ET.SubElement(Run, 'RUN_END_TIMESTAMP')
    stdFormatTimestamp = datetime.datetime.strptime(
        test_conditions.RUN_END_TIMESTAMP, '%Y%m%d_%H-%M')
    WriteField.text = datetime.datetime.strftime(
        stdFormatTimestamp, '%Y-%m-%d %H:%M:%S')

    WriteField = ET.SubElement(Run, 'LOCATION')
    WriteField.text = test_conditions.LOCATION
    WriteField = ET.SubElement(Run, 'INITIATED_BY_USER')
    WriteField.text = test_conditions.USER

    WriteField = ET.SubElement(Run, 'COMMENT_DESCRIPTION')
    WriteField.text = test_conditions.COMMENT

    # Hardware INFO:
    DataSet = ET.SubElement(root, 'DATA_SET')
    Part = ET.SubElement(DataSet, 'PART')
    WriteField = ET.SubElement(Part, 'KIND_OF_PART')
    WriteField.text = hw_info.KIND_OF_PART
    #WriteField = ET.SubElement(Part, 'VERSION')
    #WriteField.text = str(hw_info.VERSION)
    WriteField = ET.SubElement(Part, 'SERIAL_NUMBER')
    WriteField.text = "GE21-OH-v4-"+str(hw_info.OH_SERIAL_NUMBER).zfill(4)

    return root, DataSet


def WriteRunXML(root, GBT_QC_DATA, GBT_SBIT_DATA, OH_QC_DATA, Serial, test_conditions, OutputPath):
    # if(not os.path.isdir(OutputPath+"/Board_"+Serial)):
    # 	os.mkdir(OutputPath+"/Board_"+Serial)
    # OutputPath=OutputPath+"/Board_"+Serial
    # while(os.path.exists(OutputPath+"/"+Serial+'_'+str(test_conditions.RUN_NUMBER)+".xml")):
    # 	if(raw_input("This run and board number already exists. Are you sure you want to overwrite (enter y or n)? ")!='y'):
    # 		test_conditions.RUN_NUMBER=int(test_conditions.RUN_NUMBER)+1
    # 		print("Incrementing run number")
    # 	else:
    # 		break
    mydata = ET.tostring(root)

    print(ET.tostring(root))

    mydata = minidom.parseString(ET.tostring(root)).toprettyxml(indent="   ")
    myfile = open(OutputPath + "/"+Serial+"_" +
                  str(test_conditions.RUN_NUMBER) + ".xml", "w")
    myfile.write(mydata)
    print("Output file is writen.")
    myfile.close()

    mydata = ET.tostring(GBT_QC_DATA)  # encoding='utf-8', method='xml')
    mydata = minidom.parseString(ET.tostring(
        GBT_QC_DATA)).toprettyxml(indent="   ")
    GBT_QC = open(OutputPath+"/"+Serial+"_" +
                  str(test_conditions.RUN_NUMBER)+".OH_GBT_QC.xml", "w")
    # GBT_QC.write("GBTQC File")
    GBT_QC.write(mydata)
    GBT_QC.close()

    mydata = ET.tostring(GBT_SBIT_DATA)  # encoding='utf-8', method='xml')
    mydata = minidom.parseString(ET.tostring(
        GBT_SBIT_DATA)).toprettyxml(indent="   ")
    GBT_SBIT = open(OutputPath+"/"+Serial+"_" +
                    str(test_conditions.RUN_NUMBER)+".OH_GBT_SBIT.xml", "w")
    # GBT_SBIT.write("GBT SBIT File")
    GBT_SBIT.write(mydata)
    GBT_SBIT.close()

    mydata = ET.tostring(OH_QC_DATA)  # encoding='utf-8', method='xml')
    mydata = minidom.parseString(ET.tostring(
        OH_QC_DATA)).toprettyxml(indent="   ")
    OH_QC = open(OutputPath+"/"+Serial+"_" +
                 str(test_conditions.RUN_NUMBER)+".OH_QC.xml", "w")
    # OH_QC.write("OH QC File")
    OH_QC.write(mydata)
    OH_QC.close()


def CheckRunNumber(Serial, test_conditions, OutputPath):
    if(not os.path.isdir(OutputPath+"/Board_"+Serial)):
        os.mkdir(OutputPath+"Board_"+Serial)
    OutputPath = OutputPath+"Board_"+Serial
    while(os.path.exists(OutputPath+"/"+Serial+'_'+str(test_conditions.RUN_NUMBER)+".xml")):
        # if(raw_input("This run and board number already exists. Are you sure you want to continue (enter y or n)? ")!='y'):
        test_conditions.RUN_NUMBER = int(test_conditions.RUN_NUMBER)+1
        print("Files for run number " +
              str(test_conditions.RUN_NUMBER-1) + " already exist")
        print("Incrementing run number to " + str(test_conditions.RUN_NUMBER))
        # else:
        #	break
    return OutputPath


if __name__ == '__main__':
    main()
