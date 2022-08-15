from gem.gem_utils import *
from time import sleep, time
import sys
import argparse
import random
import datetime
from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel

REGISTER_DAC_MONITOR_MAP = {
    "CFG_CAL_DAC_I": 1,
    "CFG_BIAS_PRE_I_BIT": 2,
    "CFG_BIAS_PRE_I_BLCC": 3,
    "CFG_BIAS_PRE_I_BSF": 4,
    "CFG_BIAS_SH_I_BFCAS": 5,
    "CFG_BIAS_SH_I_BDIFF": 6,
    "CFG_BIAS_SD_I_BDIFF": 7,
    "CFG_BIAS_SD_I_BFCAS": 8,
    "CFG_BIAS_SD_I_BSF": 9,
    "CFG_BIAS_CFD_DAC_1": 10,
    "CFG_BIAS_CFD_DAC_2": 11,
    "CFG_HYST": 12,
    #"Imon CFD Ireflocal": 13, # ??
    #"Imon SLVS Ibias": 16, # ??
    #"Vmon BGR": 32, # ??
    "CFG_CAL_DAC_V_HIGH": 33,
    "CFG_CAL_DAC_V_LOW": 33,
    "CFG_BIAS_PRE_VREF": 34,
    "CFG_THR_ARM_DAC": 35,
    "CFG_THR_ZCC_DAC": 36,
    #"V Tsens Int": 37, # ??
    #"V Tsens Ext": 38, # ??
    "CFG_VREF_ADC": 39,
    #"CFG_MON_GAIN": 40,
    #"SLVS Vref": 41 # ??
}

MAX_DAC_SIZE = {
     "CFG_CAL_DAC_I": 255,
     "CFG_BIAS_PRE_I_BIT": 255,
     "CFG_BIAS_PRE_I_BLCC": 63,
     "CFG_BIAS_PRE_I_BSF": 63,
     "CFG_BIAS_SH_I_BFCAS": 255,
     "CFG_BIAS_SH_I_BDIFF": 255,
     "CFG_BIAS_SD_I_BDIFF": 255,
     "CFG_BIAS_SD_I_BFCAS": 255,
     "CFG_BIAS_SD_I_BSF": 63,
     "CFG_BIAS_CFD_DAC_1": 63,
     "CFG_BIAS_CFD_DAC_2": 63,
     "CFG_HYST": 63,
     "CFG_THR_ARM_DAC": 255,
     "CFG_THR_ZCC_DAC": 255,
     "CFG_CAL_DAC_V_HIGH": 255,
     "CFG_CAL_DAC_V_LOW": 255,
     "CFG_BIAS_PRE_VREF": 255,
     "CFG_VREF_ADC": 3 
}

def parseList(inFile):
    with open(inFile) as file:
        dacList = file.readlines()
        dacList = [line.rstrip("\n") for line in dacList]
    return dacList

def vfat_dac_scan(gem, system, oh_select, vfat_list, dac_list, lower, upper_list, step, niter, adc_ref, vref_list):

    resultDir = "results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    vfatDir = "results/vfat_data"
    try:
        os.makedirs(vfatDir) # create directory for VFAT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = "results/vfat_data/vfat_dac_scan_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    filename = dataDir + "/%s_OH%d_vfat_dac_scan_output_"%(gem, oh_select) + now + ".txt"
    file_out = open(filename,"w+") # OH number, DAC register name, VFAT number, dac scan point, value, error
    file_out.write("OH;DAC_reg;vfat;DAC_point;value;error\n")
    file_out.close()
    print ("VFAT DAC Scan for VFATs:")
    print (vfat_list)
    print ("")

    gem_link_reset()
    sleep(0.1)

    link_good_node = {}
    sync_error_node = {}
    dac_node = {}
    vfat_hyst_en_node = {}
    vfat_cfg_run_node = {}
    vfat_cfg_calmode_node = {}
    vfat_cfg_calselpol_node = {}
    adc_monitor_select_node = {}
    adc0_cached_node = {}
    adc0_update_node = {}
    adc1_cached_node = {}
    adc1_update_node = {}
    dac_scan_results = {}
    dac_scan_errors = {}

    # Check ready and get nodes
    for vfat in vfat_list:
        gbt, gbt_select, elink, gpio = me0_vfat_to_gbt_elink_gpio(vfat)
        check_gbt_link_ready(oh_select, gbt_select)

        print("Configuring VFAT %d" % (vfat))
        configureVfat(1, vfat, oh_select, 0)

        link_good_node[vfat] = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.LINK_GOOD" % (oh_select, vfat))
        sync_error_node[vfat] = get_backend_node("BEFE.GEM.OH_LINKS.OH%d.VFAT%d.SYNC_ERR_CNT" % (oh_select, vfat))
        link_good = read_backend_reg(link_good_node[vfat])
        sync_err = read_backend_reg(sync_error_node[vfat])
        if system!="dryrun" and (link_good == 0 or sync_err > 0):
            print (Colors.RED + "Link is bad for VFAT# %02d"%(vfat) + Colors.ENDC)
            terminate()

        dac_node[vfat] = {}
        for dac in dac_list:
            dac_actual = dac
            if dac in ["CFG_CAL_DAC_I", "CFG_CAL_DAC_V_HIGH", "CFG_CAL_DAC_V_LOW"]:
                dac_actual = "CFG_CAL_DAC"
            dac_node[vfat][dac] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.%s" % (oh_select, vfat, dac_actual))
        vfat_hyst_en_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_EN_HYST" % (oh_select, vfat))
        vfat_cfg_run_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN" % (oh_select, vfat))
        vfat_cfg_calmode_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_CAL_MODE" % (oh_select, vfat))
        vfat_cfg_calselpol_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_CAL_SEL_POL" % (oh_select, vfat))
        adc_monitor_select_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_MONITOR_SELECT" % (oh_select, vfat))
        adc0_cached_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.ADC0_CACHED" % (oh_select, vfat))
        adc0_update_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.ADC0_UPDATE" % (oh_select, vfat))
        adc1_cached_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.ADC1_CACHED" % (oh_select, vfat))
        adc1_update_node[vfat] = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.ADC1_UPDATE" % (oh_select, vfat))

        write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%i.GEB.VFAT%d.CFG_VREF_ADC" % (oh_select, vfat)) , vref_list[vfat])

        dac_scan_results[vfat] = {}
        for dac in dac_list:
            dac_scan_results[vfat][dac] = {}
            for reg in range(lower, MAX_DAC_SIZE[dac] + 1, step):
                dac_scan_results[vfat][dac][reg] = -9999
       
        dac_scan_errors[vfat] = {}
        for dac in dac_list:
            dac_scan_errors[vfat][dac] = {}
            for reg in range(lower, MAX_DAC_SIZE[dac] + 1, step):
                dac_scan_errors[vfat][dac][reg] = -9999

    sleep(1)

    # Loop over VFATs
    for vfat in vfat_list:
        print ("VFAT %02d"%vfat)
        #write_backend_reg(vfat_hyst_en_node[vfat], 0) # disable hysteresis for testing the DACs

        # Loop over DACs
        for dac in dac_list:
            print ("  Scanning DAC: " + dac)
            upper = upper_list[dac]

            # Setup DAC Monitor
            write_backend_reg(adc_monitor_select_node[vfat], REGISTER_DAC_MONITOR_MAP[dac])

            calmode_initial = read_backend_reg(vfat_cfg_calmode_node[vfat])
            calselpol_initial = read_backend_reg(vfat_cfg_calselpol_node[vfat])
            if dac=="CFG_CAL_DAC_I":
                write_backend_reg(vfat_cfg_calmode_node[vfat], 0x2)
                write_backend_reg(vfat_cfg_calselpol_node[vfat], 0x0)
            elif dac in ["CFG_CAL_DAC_V_HIGH", "CFG_CAL_DAC_V_LOW"]:
                write_backend_reg(vfat_cfg_calmode_node[vfat], 0x1)
                if dac=="CFG_CAL_DAC_V_HIGH":
                    write_backend_reg(vfat_cfg_calselpol_node[vfat], 0x0)
                elif dac=="CFG_CAL_DAC_V_LOW":
                    write_backend_reg(vfat_cfg_calselpol_node[vfat], 0x1)

            # Set VFAT to Run Mode
            #write_backend_reg(vfat_cfg_run_node[vfat], 0x1)

            # Initial value of DAC
            dac_initial = read_backend_reg(dac_node[vfat][dac])

            write_backend_reg(dac_node[vfat][dac], 0x0)
            for ii in range(0, niter):
                if adc_ref == "internal": # use ADC0
                    adc_update_read = read_backend_reg(adc0_update_node[vfat]) # read/write to this register triggers a cache update
                    sleep(20e-6) # sleep for 20 us
            
            # Looping over DAC values
            for reg in range(lower, upper + 1, step):

                # Set DAC value
                write_backend_reg(dac_node[vfat][dac], reg)

                adc_value = []
                # Taking average
                for i in range(0,niter):
                    if adc_ref == "internal": # use ADC0
                        adc_update_read = read_backend_reg(adc0_update_node[vfat]) # read/write to this register triggers a cache update
                        sleep(20e-6) # sleep for 20 us
                        adc_value.append(read_backend_reg(adc0_cached_node[vfat]))
                    elif adc_ref == "external": # use ADC1
                        adc_update_read = read_backend_reg(adc1_update_node[vfat]) # read/write to this register triggers a cache update
                        sleep(20e-6) # sleep for 20 us
                        adc_value.append(read_backend_reg(adc1_cached_node[vfat]))
                dac_scan_results[vfat][dac][reg] = sum(adc_value) / len(adc_value)
                var = sum([((x - dac_scan_results[vfat][dac][reg]) ** 2) for x in adc_value]) / len(adc_value)
                dac_scan_errors[vfat][dac][reg] = var ** 0.5

            # Set VFAT to Sleep Mode
            #write_backend_reg(vfat_cfg_run_node[vfat], 0x0)

            # Set back DAC to initial value
            write_backend_reg(dac_node[vfat][dac], dac_initial)
            write_backend_reg(vfat_cfg_calmode_node[vfat], calmode_initial)
            write_backend_reg(vfat_cfg_calselpol_node[vfat], calselpol_initial)

            # Reset DAC Monitor
            write_backend_reg(adc_monitor_select_node[vfat], 0)

            # Writing results in output file
            file_out = open(filename,"a")
            for reg in range(lower, upper + 1, step):
                file_out.write("%d;%s;%d;%d;%d;%i\n"%(oh_select, dac, vfat, reg, dac_scan_results[vfat][dac][reg], dac_scan_errors[vfat][dac][reg]))
            file_out.close()

        #write_backend_reg(vfat_hyst_en_node[vfat], 1)

    print ("")
    for vfat in vfat_list:
        print("Unconfiguring VFAT %d" % (vfat))
        configureVfat(0, vfat, oh_select, 0)

    print ("")
    print ("DAC Scan completed\n")

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="VFAT DAC Scan")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 or GE21 or GE11")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-x", "--regs", action="store", nargs="+", dest="regs", help="DACs to scan")
    parser.add_argument("-f", "--dacList", action="store", dest="dacList", help="Input text file with list of DACs")
    parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
    parser.add_argument("-ll", "--lower", action="store", dest="lower", default="0", help="lower = Lower limit for DAC scan (default=0)")
    parser.add_argument("-ul", "--upper", action="store", dest="upper", help="upper = Upper limit for DAC scan (default=max size for each DAC)")
    parser.add_argument("-t", "--step", action="store", dest="step", default="1", help="step = Step size for DAC scan (default=1)")
    parser.add_argument("-n", "--niter", action="store", dest="niter", default="100", help="niter = Number of times to read ADC for averaging (default=100)")
    parser.add_argument("-e", "--ref", action="store", dest="ref", default = "internal", help="ref = ADC reference: internal or external (default=internal)")
    parser.add_argument("-vr", "--vref", action="store", dest="vref", help="vref = CFG_VREF_ADC (0-3) (default = taken from calib file or 3)")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for DAC scan")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running DAC scan")
    else:
        print (Colors.YELLOW + "Only valid options: backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem not in ["ME0", "GE21" or "GE11"]:
        print(Colors.YELLOW + "Valid gem stations: ME0, GE21, GE11" + Colors.ENDC)
        sys.exit()

    if args.ohid is None:
        print(Colors.YELLOW + "Need OHID" + Colors.ENDC)
        sys.exit()
    #if int(args.ohid) > 1:
    #    print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
    #    sys.exit()

    if args.vfats is None:
        print (Colors.YELLOW + "Enter VFAT numbers" + Colors.ENDC)
        sys.exit()
    vfat_list = []
    for v in args.vfats:
        v_int = int(v)
        if v_int not in range(0,24):
            print (Colors.YELLOW + "Invalid VFAT number, only allowed 0-23" + Colors.ENDC)
            sys.exit()
        vfat_list.append(v_int)

    if args.regs is None and args.dacList is None:
        print(Colors.YELLOW + "Need list of Registers to scan" + Colors.ENDC)
        sys.exit()
    if args.dacList is not None and args.regs is not None:
        print(Colors.YELLOW + "Must specify registers in a text file (-d) OR with -r and a space-separated list of DACs" + Colors.ENDC)
        sys.exit()

    dac_list = []
    if args.regs is not None:
        dac_list = args.regs
        for reg in dac_list:
            if reg not in REGISTER_DAC_MONITOR_MAP:
                print(Colors.YELLOW + "Register %s not supported for DAC scan"%reg + Colors.ENDC)
                sys.exit()
    if args.dacList is not None:
        dac_list = parseList(args.dacList)
        for reg in dac_list:    
            if reg not in REGISTER_DAC_MONITOR_MAP:
                print(Colors.YELLOW + "Register %s not supported for DAC scan"%reg + Colors.ENDC)
                sys.exit()

    lower = int(args.lower)
    upper_list = {}
    for dac in dac_list:
        if lower > MAX_DAC_SIZE[dac]:
            print(Colors.YELLOW + "Lower limit is larger than the maximum DAC size. Please select a smaller lower limit or use the default" + Colors.ENDC)
            sys.exit()
        if args.upper is not None:
            upper = int(args.upper)
            if upper > MAX_DAC_SIZE[dac]:
                print(Colors.YELLOW + "Max scannable DAC size for %s is %d" % (dac, MAX_DAC_SIZE[dac]) + Colors.ENDC)
                print(Colors.YELLOW + "Since upper limit is larger than the max DAC size for %s, setting maximum DAC value to %d" % (dac, MAX_DAC_SIZE[dac]) + Colors.ENDC)
                upper = MAX_DAC_SIZE[dac]
        else:
            upper = MAX_DAC_SIZE[dac]
        if lower>upper:
            print (Colors.YELLOW + "Upper limit has to be >= Lower limit" + Colors.ENDC)
            sys.exit()
        upper_list[dac] = upper

    if lower not in range(0,256):
        print (Colors.YELLOW + "Lower limit can only be between 0 and 255" + Colors.ENDC)
        sys.exit()
    for dac in upper_list:
        if upper_list[dac] not in range(0,256):
            print (Colors.YELLOW + "Upper limit can only be between 0 and 255" + Colors.ENDC)
            sys.exit()

    step = int(args.step)
    if step not in range(1,257):
        print (Colors.YELLOW + "Step size can only be between 1 and 256" + Colors.ENDC)
        sys.exit()

    if args.ref not in ["internal", "external"]:
        print (Colors.YELLOW + "ADC reference can only be internal or external" + Colors.ENDC)
        sys.exit()

    vref_list = {}
    if args.vref is not None:
        vref = int(args.vref)
        if vref>3:
            print (Colors.YELLOW + "Allowed VREF: 0-3" + Colors.ENDC)
            sys.exit()
        for vfat in vfat_list:
            vref_list[vfat] = vref
    else:
        calib_path = "results/vfat_data/vfat_calib_data/%s_OH%s_vfat_calib_info_vref.txt"%(args.gem, args.ohid)
        vref_calib = {}
        if os.path.isfile(calib_path):
            calib_file = open(calib_path)
            for line in calib_file.readlines():
                if "vfat" in line:
                    continue
                vfat = int(line.split(";")[0])
                vref_calib[vfat] = int(line.split(";")[2])
            calib_file.close()
        for vfat in vfat_list:
            if vfat in vref_calib:
                vref_list[vfat] = vref_calib[vfat]
            else:
                vref_list[vfat] = 3

    if args.use_channel_trimming is not None:
        if args.use_channel_trimming not in ["daq", "sbit"]:
            print (Colors.YELLOW + "Only allowed options for use_channel_trimming: daq or sbit" + Colors.ENDC)
            sys.exit()

    # Initialization 
    initialize(args.gem, args.system)
    initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")
    
    # Running Phase Scan
    try:
        vfat_dac_scan(args.gem, args.system, int(args.ohid), vfat_list, dac_list, lower, upper_list, step, int(args.niter), args.ref, vref_list)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()


