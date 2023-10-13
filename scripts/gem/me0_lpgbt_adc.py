import sys, os, glob
from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep
import argparse
import statistics
from common.utils import *
import numpy as np

gain_settings = {
        2: 0x00,
        8: 0x01,
        16: 0x10,
        32: 0x11
    }


def convert_adc_reg(adc):
    reg_data = 0
    bit = adc
    reg_data |= (0x01 << bit)
    return reg_data


def poly5(x, a, b, c, d, e, f):
    return (a * np.power(x,5)) + (b * np.power(x,4)) + (c * np.power(x,3)) + (d * np.power(x,2)) + (e * x) + f


def get_vin(vout, fit_results):
    vin_range = np.linspace(0, 1, 1000)
    vout_range = poly5(vin_range, *fit_results)
    diff = 9999
    vin = 0
    for i in range(0,len(vout_range)):
        if abs(vout - vout_range[i])<=diff:
            diff = abs(vout - vout_range[i])
            vin = vin_range[i]
    return vin


def get_local_adc_calib_from_file(oh_select, gbt_select):
    adc_calib_results = []
    scripts_dir = get_befe_scripts_dir()
    adc_calibration_dir = scripts_dir = get_befe_scripts_dir()+"/gem/results/me0_lpgbt_data/adc_calibration_data/"
    if not os.path.isdir(adc_calibration_dir):
        print (Colors.YELLOW + "ADC calibration not present, using raw ADC values" + Colors.ENDC)
    list_of_files = glob.glob(adc_calibration_dir+"ME0_OH%d_GBT%d_adc_calibration_results_*.txt"%(oh_select, gbt_select))
    if len(list_of_files)==0:
        print (Colors.YELLOW + "ADC calibration not present, using raw ADC values" + Colors.ENDC)
    elif len(list_of_files)>1:
        print ("Mutliple ADC calibration results found, using latest file")
    if len(list_of_files)!=0:
        latest_file = max(list_of_files, key=os.path.getctime)
        adc_calib_file = open(latest_file)
        adc_calib_results = adc_calib_file.readlines()[0].split()
        adc_calib_results_float = [float(a) for a in adc_calib_results]
        adc_calib_results_array = np.array(adc_calib_results_float)
        adc_calib_file.close()
    return adc_calib_results, adc_calib_results_array


def read_central_adc_calib_file():
    scripts_dir = get_befe_scripts_dir()
    adc_calib = {}
    if not os.path.isfile(scripts_dir+"/resources/lpgbt_calibration.csv"):
        return adc_calib
    adc_calib_file = open(scripts_dir+"/resources/lpgbt_calibration.csv")
    vars = []

    for line in adc_calib_file.readlines():
        if "#" in line:
            continue
        if "CHIPID" in line:    
            vars = line.split("\n")[0].split(",")
            continue
        try:
            chip_id = int(line.split(",")[0], 16)
        except:
            try:
                chip_id = int(line.split(",")[0])
            except:
                chip_id = int(float(line.split(",")[0]))
        adc_calib[chip_id] = {}
        for (i,v) in enumerate(vars):
            if v == "CHIPID":
                continue
            adc_calib[chip_id][v] = float(line.split("\n")[0].split(",")[i])
    adc_calib_file.close()
    return adc_calib


def read_efuse(system, reg_adr):
    lpgbt_writeReg(getNode("LPGBT.RW.EFUSES.FUSEREAD"), 0x1)
    valid = 0
    while (valid==0):
        if system!="dryrun":
            valid = lpgbt_readReg(getNode("LPGBT.RO.FUSE_READ.FUSEDATAVALID"))
        else:
            valid = 1
        
    fuse_block_adr = reg_adr & 0xfffc
    lpgbt_writeReg(getNode("LPGBT.RW.EFUSES.FUSEBLOWADDH"), 0xff&(fuse_block_adr>>8))
    lpgbt_writeReg(getNode("LPGBT.RW.EFUSES.FUSEBLOWADDL"), 0xff&(fuse_block_adr>>0)) 
    read=4*[0]
    read[0] = lpgbt_readReg(getNode("LPGBT.RO.FUSE_READ.FUSEVALUESA")) 
    read[1] = lpgbt_readReg(getNode("LPGBT.RO.FUSE_READ.FUSEVALUESB")) 
    read[2] = lpgbt_readReg(getNode("LPGBT.RO.FUSE_READ.FUSEVALUESC")) 
    read[3] = lpgbt_readReg(getNode("LPGBT.RO.FUSE_READ.FUSEVALUESD")) 

    lpgbt_writeReg(getNode("LPGBT.RW.EFUSES.FUSEREAD"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RW.EFUSES.FUSEBLOWADDH"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RW.EFUSES.FUSEBLOWADDL"), 0x0)
    read_word = (read[0]) | (read[1]<<8) | (read[2] << 16) | (read[3] << 24)
    return read_word


def read_chip_id(system, oh_ver):
    if oh_ver == 1:
        return 0
    CHIPID_A = read_efuse(system, 0x00)
    CHIPID_B = read_efuse(system, 0x08) >> 6
    CHIPID_C = read_efuse(system, 0x0c) >> 12
    CHIPID_D = read_efuse(system, 0x10) >> 18
    CHIPID_E = read_efuse(system, 0x14) >> 24
    chip_id = statistics.mode([CHIPID_A, CHIPID_B, CHIPID_C, CHIPID_D, CHIPID_E])
    if (CHIPID_B == 0 and CHIPID_C == 0 and CHIPID_D == 0 and CHIPID_E == 0):
        chip_id = CHIPID_A
    return chip_id


def get_adc_val(system):
    vals = []
    for i in range(0,100):
        done = 0
        while (done==0):
            if system!="dryrun":
                 done = lpgbt_readReg(getNode("LPGBT.RO.ADC.ADCDONE"))
            else:
                done=1
        val = lpgbt_readReg(getNode("LPGBT.RO.ADC.ADCVALUEL"))
        val |= (lpgbt_readReg(getNode("LPGBT.RO.ADC.ADCVALUEH")) << 8)
        vals.append(val)
    mean_val = round(sum(vals)/len(vals))
    return mean_val


def read_junc_temp(system, chip_id, adc_calib):
    junc_temp = -9999
    junc_temp_unc = -9999
    if chip_id not in adc_calib:
        junc_temp = 328 # in K
        junc_temp_unc = 20 # in K
    else:
        lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFENABLE"), 0x1) # vref enable
        lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFTUNE"), round(adc_calib[chip_id]["VREF_OFFSET"])) # vref tune
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.TEMPSENSRESET"), 0x1) # resets temp sensor
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x1) # enable ADC
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCGAINSELECT"), gain_settings[2])
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINPSELECT"), 0xe) # temp sensor
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINNSELECT"), 0xf)
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCCONVERT"), 0x1)
        adc_val = get_adc_val(system)
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCCONVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINPSELECT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINNSELECT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCGAINSELECT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFENABLE"), 0x0) 
        lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFTUNE"), 0x0) 
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.TEMPSENSRESET"), 0x0)

        junc_temp = adc_val * adc_calib[chip_id]["TEMPERATURE_UNCALVREF_SLOPE"] + adc_calib[chip_id]["TEMPERATURE_UNCALVREF_OFFSET"]
        junc_temp_unc = 5 # in K

    return junc_temp, junc_temp_unc


def read_vref_tune(chip_id, adc_calib, junc_temp, junc_temp_unc):
    vref_tune = -9999
    vref_tune_unc = -9999
    if chip_id not in adc_calib:
        vref_tune = 0x63
        vref_tune_unc = 1.5e-3 # in V
    else:
        vref_tune = round(junc_temp * adc_calib[chip_id]["VREF_SLOPE"] + adc_calib[chip_id]["VREF_OFFSET"])
        if junc_temp_unc == 5:
            vref_tune_unc = 2.5e-3 # in V
        elif junc_temp_unc == 10:
            vref_tune_unc = 3.5e-3 # in V
        else:
            vref_tune_unc = 3.5e-3 + ((junc_temp_unc-10)/5)*1.5e-3 # in V

    return vref_tune, vref_tune_unc


def adc_conversion_lpgbt(chip_id, adc_calib, junc_temp, adc, gain):
    voltage = -9999
    no_calib = 0
    if chip_id not in adc_calib:
        no_calib = 1
    if "ADC_X%d_SLOPE"%gain not in adc_calib[chip_id] or "ADC_X%d_SLOPE_TEMP"%gain not in adc_calib[chip_id] or "ADC_X%d_OFFSET"%gain not in adc_calib[chip_id] or "ADC_X%d_OFFSET_TEMP"%gain not in adc_calib[chip_id]:
        no_calib = 1

    if no_calib:
        gain = 1.87
        offset = 531.1
        #voltage = adc/1024.0
        #voltage = (adc - 38.4)/(1.85 * 512)
        voltage = (adc - offset + (0.5*gain*offset))/(gain*offset)
    else:
        voltage = adc * (adc_calib[chip_id]["ADC_X%d_SLOPE"%gain] + junc_temp * adc_calib[chip_id]["ADC_X%d_SLOPE_TEMP"%gain]) + adc_calib[chip_id]["ADC_X%d_OFFSET"%gain] + junc_temp * adc_calib[chip_id]["ADC_X%d_OFFSET_TEMP"%gain]

    return voltage


def current_dac_conversion_lpgbt(chip_id, adc_calib, junc_temp, channel, current):
    dac = -9999
    if chip_id not in adc_calib:
        LSB = 3.55e-06
        dac = round(current/LSB)
        R_out = 0
    else:
        dac = round(current * (adc_calib[chip_id]["CDAC%d_SLOPE"%channel] + junc_temp * adc_calib[chip_id]["CDAC%d_SLOPE_TEMP"%channel]) + adc_calib[chip_id]["CDAC%d_OFFSET"%channel] + junc_temp * adc_calib[chip_id]["CDAC%d_OFFSET_TEMP"%channel])
        R_out = (adc_calib[chip_id]["CDAC%d_R0"%channel] + junc_temp * adc_calib[chip_id]["CDAC%d_R0_TEMP"%channel]) / dac
    return dac, R_out


def get_current_from_dac(chip_id, adc_calib, junc_temp, channel, R_load, dac):
    actual_current= - 9999
    if chip_id not in adc_calib:
        LSB = 3.55e-06
        actual_current = dac * LSB
    else:
        current = (dac - (adc_calib[chip_id]["CDAC%d_OFFSET"%channel] + junc_temp * adc_calib[chip_id]["CDAC%d_OFFSET_TEMP"%channel]))/ (adc_calib[chip_id]["CDAC%d_SLOPE"%channel] + junc_temp * adc_calib[chip_id]["CDAC%d_SLOPE_TEMP"%channel])
        R_out = (adc_calib[chip_id]["CDAC%d_R0"%channel] + junc_temp * adc_calib[chip_id]["CDAC%d_R0_TEMP"%channel]) / dac
        actual_current = (current * R_out) / (R_out + R_load)
    return actual_current


def get_resistance_from_current_dac(chip_id, adc_calib, voltage, current, R_out, adc_calib_results, adc_calib_results_array):
    resistance = -9999
    no_calib = 0
    if chip_id not in adc_calib:
        no_calib = 1
    if R_out == 0:
        no_calib = 1
    
    if no_calib:
        if len(adc_calib_results)!=0:
            Vin = get_vin(voltage, adc_calib_results_array)
        else:
            Vin = voltage
        resistance = Vin/current
    else:
        resistance = (voltage * R_out) / (voltage - current * R_out)
    return resistance


def get_vmon(chip_id, adc_calib, junc_temp, voltage):
    vmon_voltage = -9999
    if chip_id not in adc_calib:
        vmon_voltage = voltage
    else:
       vmon_voltage = voltage * (adc_calib[chip_id]["VDDMON_SLOPE"] + junc_temp * adc_calib[chip_id]["VDDMON_SLOPE_TEMP"]) 
    return vmon_voltage


def get_temp_sensor(chip_id, adc_calib, junc_temp, voltage):
    temp = -9999
    if chip_id not in adc_calib:
        temp = 0
    else:
        temp = (voltage * adc_calib[chip_id]["TEMPERATURE_SLOPE"]) + adc_calib[chip_id]["TEMPERATURE_OFFSET"]
    return temp


def init_current_dac(channel, dac):
    reg_data = convert_adc_reg(channel)
    lpgbt_writeReg(getNode("LPGBT.RWF.VOLTAGE_DAC.CURDACENABLE"), 0x1)  # Enables current DAC.
    lpgbt_writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACCHNENABLE"), reg_data)
    lpgbt_writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACSELECT"), dac)  # Sets output current for the current DAC.


def powerdown_current_dac():
    lpgbt_writeReg(getNode("LPGBT.RWF.VOLTAGE_DAC.CURDACENABLE"), 0x0) 
    lpgbt_writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACSELECT"), 0x0)  
    lpgbt_writeReg(getNode("LPGBT.RWF.CUR_DAC.CURDACCHNENABLE"), 0x0)


def init_adc(oh_ver, vref_tune):
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x1) # enable ADC
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.TEMPSENSRESET"), 0x1) # resets temp sensor
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDMONENA"), 0x1) # enable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDTXMONENA"), 0x1) # enable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDRXMONENA"), 0x1) # enable dividers
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDPSTMONENA"), 0x1)  # enable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDANMONENA"), 0x1) # enable dividers
    lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFENABLE"), 0x1) # vref enable
    lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFTUNE"), vref_tune) # vref tune
    sleep (0.01)


def powerdown_adc(oh_ver):
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x0) # disable ADC
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.TEMPSENSRESET"), 0x0) # disable temp sensor
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDMONENA"), 0x0) # disable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDTXMONENA"), 0x0) # disable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDRXMONENA"), 0x0) # disable dividers
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDPSTMONENA"), 0x0) # disable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDANMONENA"), 0x0) # disable dividers
    lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFENABLE"), 0x0) # vref disable
    lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFTUNE"), 0x0) # vref tune


def read_adc(channel, gain, system):

    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINPSELECT"), channel)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINNSELECT"), 0xf)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCGAINSELECT"), gain_settings[gain])
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCCONVERT"), 0x1)
    mean_val = get_adc_val(system)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCCONVERT"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCGAINSELECT"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINPSELECT"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINNSELECT"), 0x0)

    return mean_val



