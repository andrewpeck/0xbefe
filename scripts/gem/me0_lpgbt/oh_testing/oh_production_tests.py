import sys, os, glob
import time
import argparse
import numpy as np
import json
from common.utils import get_befe_scripts_dir
from gem.me0_lpgbt.rw_reg_lpgbt import *

# slot to OH mapping
#   SLOT    OH      GBT     VFAT
#   1       0       0, 1    0, 1,  8,  9, 16, 17
#   2       0       2, 3    2, 3, 10, 11, 18, 19
#   3       0       4, 5    4, 5, 12, 13, 20, 21
#   4       0       6, 7    6, 7, 14, 15, 22, 23
#   5       1       0, 1    0, 1,  8,  9, 16, 17
#   6       1       2, 3    2, 3, 10, 11, 18, 19
#   7       1       4, 5    4, 5, 12, 13, 20, 21
#   8       1       6, 7    6, 7, 14, 15, 22, 23

geb_oh_map = {}
for slot in range(1,9):
    o = (slot - 1)%4
    geb_oh_map[str(slot)] = {}
    geb_oh_map[str(slot)]["OH"] = (slot - 1) // 4
    geb_oh_map[str(slot)]["GBT"] = [2*o, 2*o + 1]
    geb_oh_map[str(slot)]["VFAT"] = [2*o, 2*o+1, 2*o+8, 2*o+9, 2*o+16, 2*o+17]

NULL = -9999

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OptoHybrid Production Tests")
    parser.add_argument("-i", "--input_file", action="store", dest="input_file", help="INPUT_FILE = input file containing OH and VTRx+ serial numbers for slots")
    args = parser.parse_args()

    if args.input_file is None:
        print(Colors.YELLOW + "Need Input File" + Colors.ENDC)
        sys.exit()

    geb_dict = {}
    slot_name_dict = {}
    vtrxp_dict = {}
    pigtail_dict = {}
    input_file = open(args.input_file)
    for line in input_file.readlines():
        if "#" in line:
            if "TEST_TYPE" in line:
                test_type = line.split()[2]
                if test_type not in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance", "debug"]:
                    print(Colors.YELLOW + 'Valid test type codes are "prototype", "pre_production", "pre_series", "production", "long_production", "acceptance" or debug' + Colors.ENDC)
                    sys.exit()
            continue
        slot = line.split()[0]
        slot_name = line.split()[1]
        oh_sn = line.split()[2]
        vtrx_sn = line.split()[3]
        pigtail = float(line.split()[4])
        if oh_sn != str(NULL):
            if test_type in ["prototype", "pre_production"]:
                if int(oh_sn) not in range(1,1001):
                    print(Colors.YELLOW + "Valid %s OH serial number between 1 and 1000"%test_type.replace('_','-') + Colors.ENDC)
                    sys.exit()
            elif test_type in ["pre_series", "production", "long_production", "acceptance"]:
                if int(oh_sn) not in range(1001, 2019):
                    print(Colors.YELLOW + "Valid %s OH serial number between 1001 and 2018"%test_type.replace('_','-') + Colors.ENDC)
                    sys.exit()
            elif test_type=="debug":
                if int(oh_sn) not in range(1, 2019):
                    print(Colors.YELLOW + "Valid %s OH serial number between 1 and 2018"%test_type.replace('_','-') + Colors.ENDC)
                    sys.exit()
            if int(slot) > 4:
                print(Colors.YELLOW + "Tests for more than 1 OH layer is not yet supported. Valid slots (1-4)" + Colors.ENDC)
                sys.exit()
            geb_dict[slot] = oh_sn
            slot_name_dict[slot] = slot_name
            vtrxp_dict[slot] = vtrx_sn
            pigtail_dict[slot] = pigtail
    input_file.close()

    if len(geb_dict) == 0:
        print(Colors.YELLOW + "At least 1 slot needs to have valid OH serial number" + Colors.ENDC)
        sys.exit()
    print("")

    oh_sn_list = []
    for slot,oh_sn in geb_dict.items():
        oh_sn_list.append(oh_sn)
    
    oh_gbt_vfat_map = {}
    oh_ver_dict = {}
    for slot in geb_dict:
        oh = geb_oh_map[slot]["OH"]
        if oh not in oh_gbt_vfat_map:
            oh_gbt_vfat_map[oh] = {}
            oh_gbt_vfat_map[oh]["GBT"] = []
            oh_gbt_vfat_map[oh]["VFAT"] = []
        oh_gbt_vfat_map[oh]["GBT"] += geb_oh_map[slot]["GBT"]
        oh_gbt_vfat_map[oh]["VFAT"] += geb_oh_map[slot]["VFAT"]
        oh_gbt_vfat_map[oh]["GBT"].sort()
        oh_gbt_vfat_map[oh]["VFAT"].sort()

        oh_ver_dict[slot] = [get_oh_ver(oh,gbt) for gbt in oh_gbt_vfat_map[oh]["GBT"]]
    
    scripts_gem_dir = get_befe_scripts_dir() + '/gem'
    resultDir = scripts_gem_dir + "/me0_lpgbt/oh_testing/results"

    try:
        dataDir = resultDir + "/%s_tests"%test_type
    except NameError:
        print(Colors.YELLOW + 'Must include test type in input file as "# TEST_TYPE: <test_type>"' + Colors.ENDC)
        sys.exit()

    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass

    dataDir += "/OH_SNs_"+"_".join(oh_sn_list)
    try:
        os.makedirs(dataDir) # create directory for ohid under test
    except FileExistsError: # skip if directory already exists
        pass

    log_fn = dataDir + "/me0_oh_tests_log.txt"
    logfile = open(log_fn, "w")
    xml_results_fn = dataDir + "/me0_oh_database_results.json"
    vtrxp_results_fn = dataDir + "/me0_vtrxp_database_results.json"
    full_results_fn = dataDir + "/me0_oh_tests_results.json"

    full_results = {}
    xml_results = {}
    vtrxp_results = {}
    # initialize results dictionaries indexed by oh serial #
    for slot,oh_sn in geb_dict.items():
        xml_results[oh_sn] = {}
        xml_results[oh_sn]["VTRXP_SERIAL_NUMBER"] = vtrxp_dict[slot]
        vtrxp_results[vtrxp_dict[slot]] = {}
        vtrxp_results[vtrxp_dict[slot]]['OH_SERIAL_NUMBER'] = oh_sn
        vtrxp_results[vtrxp_dict[slot]]["PIGTAIL_LENGTH"] = pigtail_dict[slot]

        xml_results[oh_sn]["TEST_TYPE"] = test_type
        xml_results[oh_sn]["GEB_SLOT"] = slot_name_dict[slot]
        xml_results[oh_sn]['VFAT_SLOTS'] = str(geb_oh_map[slot]['VFAT'])
        full_results[oh_sn] = xml_results[oh_sn].copy()

    debug = True if test_type=="debug" else False
    test_failed = False
    test_failed_override = False
    t0 = time.time()
    
    print ("\n#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    print (Colors.BLUE + "\nStarting %s tests\n"%test_type + Colors.ENDC)
    print (Colors.BLUE + "Optohybrid Serial Numbers: %s\n"%(', '.join(oh_sn_list)) + Colors.ENDC)
    print ("")

    logfile.write("\nStarting %s tests\n\n"%test_type)
    logfile.write("Optohybrid Serial Numbers: %s\n\n"%(', '.join(oh_sn_list)))

    print ("\n#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 1 - Run init_frontend
    print (Colors.BLUE + "Step 1: Initializing\n" + Colors.ENDC)
    logfile.write("Step 1: Initializing\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance", "debug"]:
        logfile.close()
        os.system("python3 init_frontend.py")
        os.system("python3 status_frontend.py >> %s"%log_fn)
        os.system("python3 clean_log.py -i %s"%log_fn)
        list_of_files = glob.glob(scripts_gem_dir+"/results/gbt_data/gbt_status_data/*.json")
        latest_file = max(list_of_files, key=os.path.getctime)
        init_dict = {}
        with open(latest_file,"r") as statusfile:
            status_dict = json.load(statusfile)
            for oh,status_dict_oh in status_dict.items():
                for gbt,status in status_dict_oh.items():
                    gbt_type = 'M' if int(gbt)%2==0 else 'S'
                    for slot,oh_sn in geb_dict.items():
                        if geb_oh_map[slot]["OH"]==int(oh) and int(gbt) in geb_oh_map[slot]["GBT"]:
                            full_results[oh_sn]['LPGBT_%s_INITIALIZATION_STATUS'%gbt_type] = int(status)
        os.system('cp %s %s/gbt_status.json'%(latest_file,dataDir))
        logfile = open(log_fn, "a")
        for slot,oh_sn in geb_dict.items():
            xml_results[oh_sn]["INITIALIZATION"] = int(full_results[oh_sn]['LPGBT_M_INITIALIZATION_STATUS'] & full_results[oh_sn]['LPGBT_S_INITIALIZATION_STATUS'])

        for slot,oh_sn in geb_dict.items():
            if not xml_results[oh_sn]["INITIALIZATION"]:
                if not test_failed:
                    print(Colors.RED + "\nStep 1: Initialization Failed" + Colors.ENDC)
                    logfile.write("\nStep 1: Initialization Failed\n")
                    test_failed = True
                for gbt,status in enumerate([full_results[oh_sn]['LPGBT_M_INITIALIZATION_STATUS'],full_results[oh_sn]['LPGBT_S_INITIALIZATION_STATUS']]):
                    gbt_type = 'BOSS' if not gbt else 'SUB'
                    if not status:
                        print(Colors.RED + 'ERROR encountered at OH %s %s lpGBT'%(oh_sn,gbt_type) + Colors.ENDC)
                        logfile.write('ERROR encountered at OH %s %s lpGBT\n'%(oh_sn,gbt_type))                        
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')

    else:
        print(Colors.BLUE + "Skipping Initialization %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping Initialization %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    print (Colors.GREEN + "\nStep 1: Initialization Complete\n" + Colors.ENDC)
    logfile.write("\nStep 1: Initialization Complete\n\n")
    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 2 - Check lpGBT status
    print (Colors.BLUE + "Step 2: Checking lpGBT Registers\n" + Colors.ENDC)
    logfile.write("Step 2: Checking lpGBT Registers\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        read_next = False
        for slot,oh_sn in geb_dict.items():
            oh_select = geb_oh_map[slot]["OH"]
            for gbt in geb_oh_map[slot]["GBT"]:
                os.system("python3 me0_lpgbt_status.py -s backend -q ME0 -o %d -g %d > out.txt"%(oh_select,gbt))
                # Copy status files
                gbt_type = 'boss' if gbt%2==0 else 'sub'
                list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_status_data/status_%s*.txt"%gbt_type)
                latest_file = max(list_of_files, key=os.path.getctime)
                os.system("cp %s %s/status_OH%s_%s.txt"%(latest_file, dataDir, oh_sn, gbt_type))
                with open('out.txt','r') as out_file:
                    for line in out_file.readlines():
                        if 'CHIP ID:' in line:
                            read_next = True
                        elif read_next:
                            gbt_type = 'M' if gbt%2==0 else 'S'
                            chip_id = line.split()[0]
                            xml_results[oh_sn]['LPGBT_%s_CHIP_ID'%gbt_type] = full_results[oh_sn]['LPGBT_%s_CHIP_ID'%gbt_type] = chip_id
                            read_next = False

        config_files = {}
        for slot,oh_ver_list in oh_ver_dict.items():
            config_files[slot] = []
            for oh_ver in oh_ver_list:
                config_files[slot].append(open("../resources/me0_boss_config_ohv%d.txt"%oh_ver))
                config_files[slot].append(open("../resources/me0_sub_config_ohv%d.txt"%oh_ver))

        status_files = {}
        for slot,oh_sn in geb_dict.items():
            status_files[slot] = []
            for gbt in geb_oh_map[slot]["GBT"]:
                gbt_type = 'boss' if gbt%2==0 else 'sub'
                status_files[slot].append(open("%s/status_OH%s_%s.txt"%(dataDir,oh_sn,gbt_type)))

        status_registers = {}
        # Read all status registers from files
        for slot,oh_sn in geb_dict.items():
            status_registers[slot]={}
            for gbt,status_file,config_file in zip(geb_oh_map[slot]['GBT'],status_files[slot],config_files[slot]):
                gbt_type = 'M' if gbt%2==0 else 'S'
                gbt_type_long = 'BOSS' if gbt%2==0 else 'SUB'
                status_registers[slot][gbt_type_long]={}
                # Get status registers
                for line in status_file.readlines():
                    reg,value = int(line.split()[0],16),int(line.split()[1],16)
                    status_registers[slot][gbt_type_long][reg] = value
                # Check against config files
                print ("Checking slot %s %s lpGBT:"%(slot,gbt_type_long))
                logfile.write("Checking slot %s %s lpGBT:\n"%(slot,gbt_type_long))
                n_error = 0
                for line in config_file.readlines():
                    reg,value = int(line.split()[0],16),int(line.split()[1],16)
                    if reg in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
                        continue
                    if status_registers[slot][gbt_type_long][reg] != value:
                        n_error += 1
                        print(Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(reg, value, status_registers[slot][gbt_type_long][reg]) + Colors.ENDC)
                        logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(reg, value, status_registers[slot][gbt_type_long][reg]))

                        if 'LPGBT_%s_BAD_REGISTERS'%gbt_type in full_results[oh_sn]:
                            full_results[oh_sn]['LPGBT_%s_BAD_REGISTERS'%gbt_type]+=["0x%03X"%reg] # save bad registers as hex string array
                        else:
                            full_results[oh_sn]['LPGBT_%s_BAD_REGISTERS'%gbt_type]=[]
                            full_results[oh_sn]['LPGBT_%s_BAD_REGISTERS'%gbt_type]+=["0x%03X"%reg]
                if not n_error:
                    print(Colors.GREEN + "  No register mismatches" + Colors.ENDC)
                    logfile.write("  No register mismatches\n")
                xml_results[oh_sn]['LPGBT_%s_REG_STATUS'%gbt_type] = full_results[oh_sn]['LPGBT_%s_REG_STATUS'%gbt_type] = int(not n_error)

                status_file.close()
                config_file.close()
        
        for slot,oh_sn in geb_dict.items():
            for gbt in geb_oh_map[slot]["GBT"]:
                gbt_type = 'M' if gbt%2==0 else 'S'
                if not xml_results[oh_sn]['LPGBT_%s_REG_STATUS'%gbt_type]:
                    if not test_failed:
                        print(Colors.RED + "\nStep 2: Checking lpGBT Status Failed" + Colors.ENDC)
                        logfile.write("\nStep 2: Checking lpGBT Status Failed\n")
                        test_failed = True
                    gbt_type = 'BOSS' if gbt_type == 'M' else 'SUB'
                    print(Colors.RED + 'ERROR encountered at OH %s %s lpGBT'%(oh_sn,gbt_type) + Colors.ENDC)
                    logfile.write('ERROR encountered at OH %s %s lpGBT\n'%(oh_sn,gbt_type))                    
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping Checking lpGBT Status %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping Checking lpGBT Status %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)
    
    time.sleep(1)
    print(Colors.GREEN + "\nStep 2: Checking lpGBT Status Complete\n" + Colors.ENDC)
    logfile.write("\nStep 2: Checking lpGBT Status Complete\n\n")

    time.sleep(1)
    print("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
   
    # Step 3 - Downlink eye diagrams
    print(Colors.BLUE + "Step 3: Downlink Eye Diagram\n" + Colors.ENDC)
    logfile.write("Step 3: Downlink Eye Diagram\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "acceptance"]:
        for slot,oh_sn in geb_dict.items():
            gbt = geb_oh_map[slot]["GBT"][0]
            print (Colors.BLUE + "Running Eye diagram for slot %s BOSS lpGBT"%slot + Colors.ENDC)
            logfile.write("Running Eye diagram for slot %s BOSS lpGBT\n"%slot)
            os.system("python3 me0_eye_scan.py -s backend -q ME0 -o %d -g %d > out.txt"%(geb_oh_map[slot]["OH"],gbt))
            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("python3 plotting_scripts/me0_eye_scan_plot.py -f %s -s > out.txt"%latest_file)
            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*.pdf")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("cp %s %s/downlink_optical_eye_boss_OH%s.pdf"%(latest_file, dataDir, oh_sn))
            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*out.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            eye_result_file=open(latest_file)
            result = eye_result_file.readlines()[0]
            eye_result_file.close()
            print(result)
            logfile.write(result+"\n")
            xml_results[oh_sn]['LPGBT_M_DOWNLINK_EYE_DIAGRAM'] = full_results[oh_sn]['LPGBT_M_DOWNLINK_EYE_DIAGRAM'] = float(result.split()[5])
        for slot,oh_sn in geb_dict.items():
            if xml_results[oh_sn]['LPGBT_M_DOWNLINK_EYE_DIAGRAM'] < 0.5:
                if not test_failed:
                    print (Colors.RED + "\nStep 3: Downlink Eye Diagram Failed" + Colors.ENDC)
                    logfile.write("\nStep 3: Downlink Eye Diagram Failed\n")
                    test_failed = True
                print(Colors.RED + 'ERROR:OUTSIDE_ACCEPTANCE_RANGE encountered at OH %s BOSS lpGBT'%oh_sn + Colors.ENDC)
                logfile.write('ERROR:OUTSIDE_ACCEPTANCE_RANGE encountered at OH %s BOSS lpGBT\n'%oh_sn)
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping downlink eye diagram for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping downlink eye diagram for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    print (Colors.GREEN + "\nStep 3: Downlink Eye Diagram Complete\n" + Colors.ENDC)
    logfile.write("\nStep 3: Downlink Eye Diagram Complete\n\n")

    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 4 - Downlink Optical BERT
    print (Colors.BLUE + "Step 4: Downlink Optical BERT\n" + Colors.ENDC)
    logfile.write("Step 4: Downlink Optical BERT\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
            # Configure all VFATs at low threshold
            print (Colors.BLUE + "Configuring all VFATs for OH %d\n"%oh_select + Colors.ENDC)
            logfile.write("Configuring all VFATs for OH %d\n\n"%oh_select)
            logfile.close()
            os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v %s -c 1 -lt >> %s"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])), log_fn))
            logfile = open(log_fn,"a")
            time.sleep(1)

            print (Colors.BLUE + "Running Downlink Optical BERT for OH %s BOSS lpGBTs\n"%oh_select + Colors.ENDC)
            logfile.write("Running Downlink Optical BERT for OH %s BOSS lpGBTs\n\n"%oh_select)
            if debug:
                os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p downlink -r run -t 0.2 -z"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT'][0::2]))))
            else:
                os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p downlink -r run -b 1e-12 -z"%(oh_select,' '.join(map(str,gbt_vfat_dict['GBT'][0::2]))))
            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_optical_link_bert_fec_results/*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            read_next = False
            with open(latest_file,"r") as bertfile:
                for line in bertfile.readlines():
                    if read_next:
                        if "GBT" in line:
                            gbt = int(line.split()[-1])
                            for slot,oh_sn in geb_dict.items():
                                if gbt in geb_oh_map[slot]["GBT"]:
                                    break
                        elif "Number of FEC errors" in line:
                            errors = int(line.split()[-1])
                            xml_results[oh_sn]['LPGBT_M_DOWNLINK_ERROR_COUNT'] = full_results[oh_sn]['LPGBT_M_DOWNLINK_ERROR_COUNT'] = errors
                        elif "Bit Error Ratio" in line:
                            if errors:
                                xml_results[oh_sn]['LPGBT_M_DOWNLINK_BER_UPPER_LIMIT'] = full_results[oh_sn]['LPGBT_M_DOWNLINK_BER_UPPER_LIMIT'] = NULL
                            else:
                                xml_results[oh_sn]['LPGBT_M_DOWNLINK_BER_UPPER_LIMIT'] = full_results[oh_sn]['LPGBT_M_DOWNLINK_BER_UPPER_LIMIT'] = float(line.split()[-1])
                    elif "BER Test Results" in line:
                        read_next = True
            read_next = False
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")

            # Unconfigure all VFATs at low threshold
            print (Colors.BLUE + "Configuring all VFATs for OH %d\n"%oh_select + Colors.ENDC)
            logfile.write("Configuring all VFATs for OH %d\n\n"%oh_select)
            logfile.close()
            os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v %s -c 0 >> %s"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])), log_fn))
            logfile = open(log_fn,"a")
            time.sleep(1)

        for slot,oh_sn in geb_dict.items():
            if xml_results[oh_sn]['LPGBT_M_DOWNLINK_ERROR_COUNT']:
                if not test_failed:
                    print (Colors.RED + "\nStep 4: Downlink Optical BERT Failed" + Colors.ENDC)
                    logfile.write("\nStep 4: Downlink Optical BERT Failed\n")
                    test_failed = True
                print(Colors.RED + 'ERROR encountered at OH %s BOSS lpGBT'%oh_sn + Colors.ENDC)
                logfile.write('ERROR encountered at OH %s BOSS lpGBT\n'%oh_sn)                
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping Downlink Optical BERT for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping Downlink Optical BERT for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    print (Colors.GREEN + "\nStep 4: Downlink Optical BERT Complete\n" + Colors.ENDC)
    logfile.write("\nStep 4: Downlink Optical BERT Complete\n\n")

    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 5 - Uplink Optical BERT
    print (Colors.BLUE + "Step 5: Uplink Optical BERT\n" + Colors.ENDC)
    logfile.write("Step 5: Uplink Optical BERT\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            # Configure all VFATs at low threshold
            print (Colors.BLUE + "Configuring all VFATs for OH %d\n"%oh_select + Colors.ENDC)
            logfile.write("Configuring all VFATs for OH %d\n\n"%oh_select)
            logfile.close()
            os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v %s -c 1 -lt >> %s"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])), log_fn))
            logfile = open(log_fn,"a")
            time.sleep(1)

            print(Colors.BLUE + "Running Uplink Optical BERT for OH %s, BOSS and Sub lpGBTs\n"%oh_select + Colors.ENDC)
            logfile.write("Running Uplink Optical BERT for OH %s, BOSS and Sub lpGBTs\n\n"%oh_select)
            if debug:
                os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p uplink -r run -t 0.2 -z"%(oh_select," ".join(map(str,gbt_vfat_dict["GBT"]))))
            else:
                os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p uplink -r run -b 1e-12 -z"%(oh_select," ".join(map(str,gbt_vfat_dict["GBT"]))))
            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_optical_link_bert_fec_results/*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            read_next = False
            with open(latest_file,"r") as bertfile:
                # Just read the last 10 lines to save time. Know results are at the end.
                for line in bertfile.readlines():
                    if read_next:
                        if "GBT" in line:
                            gbt = int(line.split()[-1])
                            gbt_type = 'M' if gbt%2==0 else 'S'
                            for slot,oh_sn in geb_dict.items():
                                if gbt in geb_oh_map[slot]["GBT"]:
                                    break
                        elif "Number of FEC errors" in line:
                            errors = int(line.split()[-1])
                            xml_results[oh_sn]['LPGBT_%s_UPLINK_ERROR_COUNT'%gbt_type] = full_results[oh_sn]['LPGBT_%s_UPLINK_ERROR_COUNT'%gbt_type] = errors
                        elif "Bit Error Ratio" in line:
                            if errors:
                                xml_results[oh_sn]['LPGBT_%s_UPLINK_BER_UPPER_LIMIT'%gbt_type] = full_results[oh_sn]['LPGBT_%s_UPLINK_BER_UPPER_LIMIT'%gbt_type] = NULL
                            else:
                                xml_results[oh_sn]['LPGBT_%s_UPLINK_BER_UPPER_LIMIT'%gbt_type] = full_results[oh_sn]['LPGBT_%s_UPLINK_BER_UPPER_LIMIT'%gbt_type] = float(line.split()[-1])
                    elif "BER Test Results" in line:
                        read_next = True
            read_next = False
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")

            # Unconfigure all VFATs at low threshold
            print (Colors.BLUE + "Configuring all VFATs for OH %d\n"%oh_select + Colors.ENDC)
            logfile.write("Configuring all VFATs for OH %d\n\n"%oh_select)
            logfile.close()
            os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v %s -c 0 >> %s"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])), log_fn))
            logfile = open(log_fn,"a")
            time.sleep(1)

        for slot,oh_sn in geb_dict.items():
            for gbt in geb_oh_map[slot]["GBT"]:
                gbt_type = 'M' if gbt%2==0 else 'S'
                if xml_results[oh_sn]['LPGBT_%s_UPLINK_ERROR_COUNT'%gbt_type]:
                    if not test_failed:
                        print (Colors.RED + "\nStep 5: Uplink Optical BERT Failed" + Colors.ENDC)
                        logfile.write("\nStep 5: Uplink Optical BERT Failed\n")
                        test_failed = True
                    gbt_type = 'BOSS' if gbt%2==0 else 'SUB'
                    print(Colors.RED + 'ERROR encountered at OH %s %s lpGBT'%(oh_sn,gbt_type) + Colors.ENDC)
                    logfile.write('ERROR encountered at OH %s %s lpGBT\n'%(oh_sn,gbt_type))            
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping Uplink Optical BERT for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping Uplink Optical BERT for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    print (Colors.GREEN + "\nStep 5: Uplink Optical BERT Complete\n" + Colors.ENDC)
    logfile.write("\nStep 5: Uplink Optical BERT Complete\n\n")

    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 6 - VFAT Reset
    print (Colors.BLUE + "Step 6: VFAT Reset\n" + Colors.ENDC)
    logfile.write("Step 6: VFAT Reset\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Configuring all VFATs for OH %d\n"%oh_select + Colors.ENDC)
            logfile.write("Configuring all VFATs for OH %d\n\n"%oh_select)
            logfile.close()
            os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v %s -c 1 >> %s"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])), log_fn))
            logfile = open(log_fn,"a")
            time.sleep(1)
            
            print (Colors.BLUE + "Resetting all VFATs for OH %d\n"%oh_select + Colors.ENDC)
            logfile.write("Resetting all VFATs for OH %d\n\n"%oh_select)
            logfile.close()
            os.system("python3 me0_vfat_reset.py -s backend -q ME0 -o %d -v %s >> %s"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])),log_fn))
            os.system("python3 clean_log.py -i %s"%log_fn)

            read_next = False
            with open(log_fn,"r") as logfile:
                for line in logfile.readlines():
                    if read_next:
                        if line=='\n':
                            read_next = False
                            continue
                        vfat = int(line.split()[1].removesuffix(':'))
                        for slot,oh_sn in geb_dict.items():
                            if vfat in geb_oh_map[slot]['VFAT']:
                                break
                        status_str = line.split(':')[1]
                        if "VFAT RESET from RUN mode to SLEEP mode" in status_str:
                            if 'VFAT_RESETS' in xml_results[oh_sn]:
                                xml_results[oh_sn]['VFAT_RESETS'] += [1]
                            else:
                                xml_results[oh_sn]['VFAT_RESETS'] = full_results[oh_sn]['VFAT_RESETS'] = [1]
                        else:
                            if 'VFAT_RESETS' in xml_results[oh_sn]:
                                xml_results[oh_sn]['VFAT_RESETS'] += [0]
                            else:
                                xml_results[oh_sn]['VFAT_RESETS'] = full_results[oh_sn]['VFAT_RESETS'] = [0]
                    elif 'VFAT Reset Results' in line:
                        read_next = True

        logfile = open(log_fn,"a")    
        print (Colors.BLUE + "Unconfiguring all VFATs\n" + Colors.ENDC)
        logfile.write("Unconfiguring all VFATs\n\n")
        logfile.close()
        os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v %s -c 0 >> %s"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])), log_fn))
        logfile = open(log_fn,'a')

        for slot,oh_sn in geb_dict.items():
            for i,result in enumerate(xml_results[oh_sn]['VFAT_RESETS']):
                if not result:
                    if not test_failed:
                        print (Colors.RED + "\nStep 8: VFAT Reset Failed\n" + Colors.ENDC)
                        logfile.write("\nStep 8: VFAT Reset Failed\n\n")
                        test_failed = True
                    print(Colors.RED + 'ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                    logfile.write('ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
        for oh_sn in xml_results:
            xml_results[oh_sn]['VFAT_RESETS'] = str(xml_results[oh_sn]['VFAT_RESETS'])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping VFAT Reset for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping VFAT Reset for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    print (Colors.GREEN + "\nStep 6: VFAT Reset Complete\n" + Colors.ENDC)
    logfile.write("\nStep 6: VFAT Reset Complete\n\n")

    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 7 - DAQ Phase Scan
    print (Colors.BLUE + "Step 7: DAQ Phase Scan\n" + Colors.ENDC)
    logfile.write("Step 7: DAQ Phase Scan\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Running DAQ Phase Scan for OH %s on all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running DAQ Phase Scan for OH %s on all VFATs\n\n"%oh_select)
            os.system("python3 me0_phase_scan.py -s backend -q ME0 -o %d -v %s -c -x"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_phase_scan_results/*_data_*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("python3 clean_log.py -i %s"%latest_file) # Clean output file for parsing
            read_next = False
            with open(latest_file,"r") as ps_file:
                for line in ps_file.readlines():
                    if read_next:
                        vfat = int(line.split()[0].replace("VFAT","").replace(":",""))
                        phase = int(line.split()[2].replace('(center=','').removesuffix(','))
                        width = int(line.split()[3].replace('width=','').removesuffix(')'))
                        status =  1 if line.split()[4] == "GOOD" else 0
                        for slot,oh_sn in geb_dict.items():
                            if vfat in geb_oh_map[slot]["VFAT"]:
                                if "VFAT_DAQ_PHASE_SCAN" in xml_results[oh_sn]:
                                    xml_results[oh_sn]["VFAT_DAQ_PHASE_SCAN"].append({'STATUS':status,'PHASE':phase,'WIDTH':width})
                                else:
                                    xml_results[oh_sn]["VFAT_DAQ_PHASE_SCAN"] = full_results[oh_sn]["VFAT_DAQ_PHASE_SCAN"] = [{'STATUS':status,'PHASE':phase,'WIDTH':width}]
                                break
                    elif "Phase Scan Results" in line:
                        read_next = True
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")

            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_phase_scan_results/*_results_*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system('cp %s %s/me0_oh%d_vfat_phase_scan.txt'%(latest_file,dataDir,oh_select))

        for slot,oh_sn in geb_dict.items():
            for i,result in enumerate(xml_results[oh_sn]['VFAT_DAQ_PHASE_SCAN']):
                if not result['STATUS']:
                    if not test_failed:
                        print (Colors.RED + "\nStep 6: DAQ Phase Scan Failed" + Colors.ENDC)
                        logfile.write("\nStep 6: DAQ Phase Scan Failed\n")
                        test_failed = True
                    print(Colors.RED + 'ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                    logfile.write('ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))                   
        for oh_sn in xml_results:
            xml_results[oh_sn]['VFAT_DAQ_PHASE_SCAN'] = str(xml_results[oh_sn]['VFAT_DAQ_PHASE_SCAN'])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping DAQ Phase Scan for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping DAQ Phase Scan for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    print (Colors.GREEN + "\nStep 7: DAQ Phase Scan Complete\n" + Colors.ENDC)
    logfile.write("\nStep 7: DAQ Phase Scan Complete\n\n")

    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 8 - S-bit Phase Scan, Bitslipping, Mapping, Cluster Mapping
    # print (Colors.BLUE + "Step 8: S-bit Phase Scan, Bitslipping,  Mapping, Cluster Mapping\n" + Colors.ENDC)
    # logfile.write("Step 8: S-bit Phase Scan, Bitslipping, Mapping, Cluster Mapping\n\n")
    print (Colors.BLUE + "Step 8: S-bit Phase Scan, Bitslipping, Mapping\n" + Colors.ENDC)
    logfile.write("Step 8: S-bit Phase Scan, Bitslipping, Mapping\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Running S-bit Phase Scan on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running S-bit Phase Scan on OH %d all VFATs\n\n"%oh_select)
            os.system("python3 me0_vfat_sbit_phase_scan.py -s backend -q ME0 -o %d -v %s -l -a"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_sbit_phase_scan_results/*_data_*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("python3 clean_log.py -i %s"%latest_file)
            read_next = False
            with open(latest_file,"r") as ps_file:
                # parse sbit phase scan results
                for line in ps_file.readlines():
                    if read_next:
                        if 'VFAT' in line:
                            vfat = int(line.split()[1])
                        elif 'ELINK' in line:
                            elink = int(line.split()[1].removesuffix(':'))
                            phase = int(line.split()[3].replace('(center=','').removesuffix(','))
                            width = int(line.split()[4].replace('width=','').removesuffix(')'))
                            status = 1 if line.split()[5] == "GOOD" else 0

                            for slot,oh_sn in geb_dict.items():
                                if vfat in geb_oh_map[slot]["VFAT"]:
                                    i = geb_oh_map[slot]["VFAT"].index(vfat)
                                    break
                            if 'VFAT_SBIT_PHASE_SCAN' in xml_results[oh_sn]:
                                xml_results[oh_sn]['VFAT_SBIT_PHASE_SCAN'][i]+=[{'STATUS':status,'PHASE':phase,'WIDTH':width}]
                            else:
                                xml_results[oh_sn]['VFAT_SBIT_PHASE_SCAN'] = full_results[oh_sn]['VFAT_SBIT_PHASE_SCAN'] = [[] for _ in range(6)]
                                xml_results[oh_sn]['VFAT_SBIT_PHASE_SCAN'][i]+=[{'STATUS':status,'PHASE':phase,'WIDTH':width}]
                    elif 'Phase Scan Results' in line:
                        read_next = True
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")

            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_sbit_phase_scan_results/*_results_*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system('cp %s %s/me0_oh%d_vfat_sbit_phase_scan.txt'%(latest_file,dataDir,oh_select))

        for slot,oh_sn in geb_dict.items():
            for v,vfat_results in enumerate(xml_results[oh_sn]["VFAT_SBIT_PHASE_SCAN"]):
                for e,result in enumerate(vfat_results):
                    if not result['STATUS']:
                        if not test_failed:
                            print (Colors.RED + "\nStep 7: S-Bit Phase Scan Failed" + Colors.ENDC)
                            logfile.write("\nStep 7: S-Bit Phase Scan Failed\n")
                            test_failed = True
                        print(Colors.RED + 'ERROR encountered at OH %s VFAT %d ELINK %d'%(oh_sn,geb_oh_map[slot],['VFAT'][v],e) + Colors.ENDC)
                        logfile.write('ERROR encountered at OH %s VFAT %d ELINK %d\n'%(oh_sn,geb_oh_map[slot],['VFAT'][v],e))
        for oh_sn in xml_results:
            xml_results[oh_sn]["VFAT_SBIT_PHASE_SCAN"] = str(xml_results[oh_sn]["VFAT_SBIT_PHASE_SCAN"])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping S-Bit Phase Scan for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping S-Bit Phase Scan for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "\n\nRunning S-bit Bitslipping on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("\n\nRunning S-bit Bitslipping on OH %d, all VFATs\n\n"%oh_select)
            os.system("python3 me0_vfat_sbit_bitslip.py -s backend -q ME0 -o %d -v %s -l"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_sbit_bitslip_results/*_data_*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("python3 clean_log.py -i %s"%latest_file) # Clean output file for parsing
            read_next=True
            with open(latest_file,"r") as bitslip_file:
                # parse bitslip scan results
                for line in bitslip_file.readlines():
                    if read_next:
                        if "VFAT" in line:
                            vfat = int(line.split()[1].replace(":",""))
                            for slot,oh_sn in geb_dict.items():
                                if vfat in geb_oh_map[slot]["VFAT"]:
                                    i = geb_oh_map[slot]["VFAT"].index(vfat)
                                    break
                        elif "ELINK" in line and not read_next:
                            elink = int(line.split()[1].replace(":",""))
                        elif "Bit slip" in line:
                            bitslip = int(line.split()[-1])
                            status = 1 if bitslip!=NULL else 0
                            if 'VFAT_SBIT_BITSLIP' in xml_results[oh_sn]:
                                if xml_results[oh_sn]['VFAT_SBIT_BITSLIP'][i] == {}:
                                    xml_results[oh_sn]['VFAT_SBIT_BITSLIP'][i]={'STATUS':status,'Bitslips':[bitslip]}
                                else:
                                    xml_results[oh_sn]['VFAT_SBIT_BITSLIP'][i]['STATUS']&=status
                                    xml_results[oh_sn]['VFAT_SBIT_BITSLIP'][i]['Bitslips']+=[bitslip]
                            else:
                                xml_results[oh_sn]['VFAT_SBIT_BITSLIP'] = full_results[oh_sn]['VFAT_SBIT_BITSLIP'] = [{} for _ in range(6)]
                                xml_results[oh_sn]['VFAT_SBIT_BITSLIP'][i]={'STATUS':status,'Bitslips':[bitslip]}
                    elif "Bad Elinks:" in line:
                        read_next = False # rule out "VFAT" and "ELINK" appearing at the end in bad elinks
                        continue
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")

            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_sbit_bitslip_results/*_results_*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system('cp %s %s/me0_oh%d_vfat_sbit_bitslip.txt'%(latest_file,dataDir,oh_select))

        for slot,oh_sn in geb_dict.items():
            for i,result in enumerate(xml_results[oh_sn]["VFAT_SBIT_BITSLIP"]):
                if not result['STATUS']:
                    if not test_failed:
                        print (Colors.RED + "\nStep 7: S-Bit Bitslip Failed" + Colors.ENDC)
                        logfile.write("\nStep 7: S-Bit Bitslip Failed\n")
                        test_failed = True
                    print(Colors.RED + 'ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                    logfile.write('ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
        for oh_sn in xml_results:
            xml_results[oh_sn]["VFAT_SBIT_BITSLIP"] = str(xml_results[oh_sn]["VFAT_SBIT_BITSLIP"])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping S-Bit Bitslip for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping S-Bit Bitslip for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "\n\nRunning S-bit Mapping on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("\n\nRunning S-bit Mapping on OH %d, all VFATs\n\n"%oh_select)
            os.system("python3 me0_vfat_sbit_mapping.py -s backend -q ME0 -o %d -v %s -l"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_sbit_mapping_results/*_data_*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("python3 clean_log.py -i %s"%latest_file) # Clean output file for logging
            no_bad_channels = False
            no_rotated_elinks = False
            bad_channels = {}
            rotated_elinks = {}
            read_next = False
            with open(latest_file,'r') as mapping_file:
                for line in mapping_file.readlines():
                    if 'No Bad Channels' in line:
                        no_bad_channels = True
                    elif 'No Rotated Elinks' in line:
                        no_rotated_elinks = True
                    elif 'Bad Channels:' in line:
                        read_next = True
                    elif 'Rotated Elinks:' in line:
                        read_next = True
                    elif read_next:
                        if 'Channel' in line:
                            vfat = int(line.split()[1].removesuffix(','))
                            channel = int(line.split()[5])
                            if vfat in bad_channels:
                                bad_channels[vfat]+=[channel]
                            else:
                                bad_channels[vfat]={}
                                bad_channels[vfat]=[channel]
                        elif 'VFAT' in line:
                            vfat = int(line.split()[1].removesuffix(','))
                            elink = int(line.split()[3])
                            if vfat in rotated_elinks:
                                rotated_elinks[vfat]+=[elink]
                            else:
                                rotated_elinks[vfat]=[elink]
                        else:
                            read_next = False
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn)) 
            logfile = open(log_fn, "a")

            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_sbit_mapping_results/*_results_*.py")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system('cp %s %s/me0_oh%d_vfat_sbit_mapping.py'%(latest_file,dataDir,oh_select))

        for slot,oh_sn in geb_dict.items():
            xml_results[oh_sn]['VFAT_SBIT_MAPPING'] = full_results[oh_sn]['VFAT_SBIT_MAPPING'] = [{'STATUS':1,'BAD_CHANNELS':[],'ROTATED_ELINKS':[]} for _ in range(6)]
            #xml_results[oh_sn]['VFAT_SBIT_MAPPING'] = full_results[oh_sn]['VFAT_SBIT_MAPPING'] = [{'STATUS':1,'BAD_CHANNELS':[],'ROTATED_ELINKS':[],'BAD_CHANNELS_CLUSTER':[]} for _ in range(6)]
        if bad_channels:
            for vfat in bad_channels:
                for slot,oh_sn in geb_dict.items():
                    if vfat in geb_oh_map[slot]['VFAT']:
                        i = geb_oh_map[slot]['VFAT'].index(vfat)
                        xml_results[oh_sn]['VFAT_SBIT_MAPPING'][i]['STATUS'] = int(no_bad_channels)
                        xml_results[oh_sn]['VFAT_SBIT_MAPPING'][i]['BAD_CHANNELS'] += bad_channels[vfat]
                        break
        if rotated_elinks:
            for vfat in rotated_elinks:
                for slot,oh_sn in geb_dict.items():
                    if vfat in geb_oh_map[slot]['VFAT']:
                        i = geb_oh_map[slot]['VFAT'].index(vfat)
                        xml_results[oh_sn]['VFAT_SBIT_MAPPING'][i]['STATUS'] = int(no_rotated_elinks)
                        xml_results[oh_sn]['VFAT_SBIT_MAPPING'][i]['ROTATED_ELINKS'] += rotated_elinks[vfat]
                        break

        if not no_bad_channels or not no_rotated_elinks:
            for slot,oh_sn in geb_dict.items():
                for i,result in enumerate(xml_results[oh_sn]['VFAT_SBIT_MAPPING']):
                    if not result['STATUS']:
                        if not test_failed:
                            print (Colors.RED + "\nStep 7: S-Bit Mapping Failed" + Colors.ENDC)
                            logfile.write("\nStep 7: S-Bit Mapping Failed\n")
                            test_failed = True
                        print(Colors.RED + 'ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                        logfile.write('ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
        # Convert results to string
        # Comment next 2 lines if running cluster mapping too
        for oh_sn in xml_results:
            xml_results[oh_sn]["VFAT_SBIT_MAPPING"] = str(xml_results[oh_sn]["VFAT_SBIT_MAPPING"])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping S-Bit Mapping for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping S-Bit Mapping for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    # if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
    #     for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
    #         print (Colors.BLUE + "Running S-bit Cluster Mapping on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
    #         logfile.write("Running S-bit Cluster Mapping on OH %d, all VFATs\n\n"%oh_select)
    #         os.system("python3 vfat_sbit_monitor_clustermap.py -s backend -q ME0 -o %d -v %s -l -f "%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
    #         list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_sbit_monitor_cluster_mapping_results/*_results_*.txt")
    #         latest_file = max(list_of_files, key=os.path.getctime)
    #         with open(latest_file,"r") as mapping_file:
    #             for line in mapping_file.readlines()[2:]:
    #                 data = line.split()
    #                 data = data[:3] + data[3].split(',') + data[4].split(',')
    #                 data.remove('')
    #                 vfat = int(data[0])
    #                 channel = int(data[1])
    #                 cluster_address = int(data[11])


    #                 # sbit_status = 1 if sbit != NULL else 0
    #                 cluster_status = 1 if cluster_address != NULL else 0
                    
    #                 for slot,oh_sn in geb_dict.items():
    #                     if vfat in geb_oh_map[slot]['VFAT']:
    #                         i = geb_oh_map[slot]['VFAT'].index(vfat)
    #                         if cluster_status:
    #                             xml_results[oh_sn]['VFAT_SBIT_MAPPING'][i]["STATUS"] &= cluster_status
    #                         else:
    #                             xml_results[oh_sn]['VFAT_SBIT_MAPPING'][i]["STATUS"] &= cluster_status
    #                             xml_results[oh_sn]['VFAT_SBIT_MAPPING'][i]["BAD_CHANNELS_CLUSTER"]+=[channel]
    #                         break

    #         os.system('cp %s %s/me0_oh%d_vfat_sbit_clustermap.txt'%(latest_file,dataDir,oh_select))

    #     for slot,oh_sn in geb_dict.items():
    #         for i,result in enumerate(xml_results[oh_sn]["VFAT_SBIT_MAPPING"]):
    #             if not result['STATUS']:
    #                 if not test_failed:
    #                     print (Colors.RED + "\nStep 7: S-Bit Cluster Mapping Failed" + Colors.ENDC)
    #                     logfile.write("\nStep 7: S-Bit Cluster Mapping Failed\n")
    #                     test_failed = True
    #                     test_failed_override = True
    #                 print(Colors.RED + 'ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
    #                 logfile.write('ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
    #     # Convert results to string
    #     for oh_sn in xml_results:
    #         xml_results[oh_sn]["VFAT_SBIT_MAPPING"] = str(xml_results[oh_sn]["VFAT_SBIT_MAPPING"])
    #     if test_failed_override:
    #         test_failed = False
    #         test_failed_override = False
    #     while test_failed:
    #         end_tests = input('\nWould you like to exit testing? >> ')
    #         if end_tests.lower() in ['y','yes']:
    #             print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
    #             logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
    #             print('\nLogging full results at directory: %s\n'%full_results_fn)
    #             logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
    #             xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
    #             full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
    #             vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
    #             with open(xml_results_fn,"w") as xml_results_file:
    #                 json.dump(xml_results,xml_results_file,indent=2)
    #             with open(full_results_fn,'w') as full_results_file:
    #                 json.dump(full_results,full_results_file,indent=2)
    #             with open(vtrxp_results_fn,'w') as vtrxp_results_file:
    #                 json.dump(vtrxp_results,vtrxp_results_file,indent=2)
    #             logfile.close()
    #             sys.exit()
    #         elif end_tests.lower() in ['n','no']:
    #             test_failed = False
    #         else:
    #             print('Valid entries: y, yes, n, no')
    # else:
    #     print(Colors.BLUE + "Skipping S-Bit Cluster Mapping for %s tests"%test_type.replace("_","-") + Colors.ENDC)
    #     logfile.write("Skipping S-Bit Cluster Mapping for %s tests\n"%test_type.replace("_","-"))
    #     time.sleep(1)

    # print (Colors.GREEN + "\nStep 8: S-bit Phase Scan, Bitslipping, Mapping, Cluster Mapping Complete\n" + Colors.ENDC)
    # logfile.write("\nStep 8: S-bit Phase Scan, Bitslipping, Mapping, Cluster Mapping Complete\n\n")

    print (Colors.GREEN + "\nStep 8: S-bit Phase Scan, Bitslipping, Mapping Complete\n" + Colors.ENDC)
    logfile.write("\nStep 8: S-bit Phase Scan, Bitslipping, Mapping Complete\n\n")

    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 9 - Slow Control Error Rate Test
    print (Colors.BLUE + "Step 9: Slow Control Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 9: Slow Control Error Rate Test\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Running Slow Control Error Rate Test on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running Slow Control Error Rate Test on OH %d, all VFATs\n\n"%oh_select)

            if test_type in ["prototype", "pre_production", "pre_series"]:
                runtime = 30
            elif test_type == 'debug':
                runtime = 1
            else:
                runtime = 10
            os.system("python3 vfat_slow_control_test.py -s backend -q ME0 -o %d -v %s -r TEST_REG -t %d"%(oh_select, " ".join(map(str,gbt_vfat_dict["VFAT"])), runtime))
            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_slow_control_test_results/*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            read_next = False
            with open(latest_file,"r") as sc_errors_file:
                for line in sc_errors_file.readlines():
                    if read_next:
                        logfile.write(line)
                        if 'link is' in line:
                            vfat = int(line.split()[1].removesuffix(','))
                            link_good = 1 if line.split()[-1] == 'GOOD' else 0
                        if 'sync errors' in line:
                            sync_errors = int(line.split()[-1])
                        elif 'bus errors' in line:
                            bus_errors = int(line.split()[6].removesuffix(','))
                        elif "mismatch" in line:
                            mismatch_errors = int(line.split()[7].removesuffix(','))
                        elif 'CRC errors' in line:
                            crc_errors = float(line.split()[10].removesuffix(','))
                            crc_errors = int(np.ceil(crc_errors)) if (crc_errors > 0 and crc_errors < 1) else int(crc_errors)
                        elif 'Timeout errors' in line:
                            timeout_errors = float(line.split()[10].removesuffix(','))
                            timeout_errors = int(np.ceil(timeout_errors)) if (timeout_errors > 0 and timeout_errors < 1) else int(timeout_errors)
                            for slot,oh_sn in geb_dict.items():
                                if vfat in geb_oh_map[slot]["VFAT"]:
                                    if 'VFAT_SLOW_CONTROL_ERROR_COUNT' in xml_results[oh_sn]:
                                        xml_results[oh_sn]["VFAT_SLOW_CONTROL_ERROR_COUNT"] += [sync_errors+bus_errors+mismatch_errors+crc_errors+timeout_errors]
                                    else:
                                        xml_results[oh_sn]["VFAT_SLOW_CONTROL_ERROR_COUNT"] = [sync_errors+bus_errors+mismatch_errors+crc_errors+timeout_errors]

                                    if 'Slow_Control_Errors' in full_results[oh_sn]:
                                        full_results[oh_sn]['VFAT_SLOW_CONTROL_ERROR_SCAN'] += [{'TIME':runtime,'LINK_GOOD':link_good,'SYNC_ERROR_COUNT':sync_errors,'REGISTER_MISMATCH_ERROR_COUNT':mismatch_errors,'TOTAL_ERROR_COUNT':sync_errors+bus_errors+mismatch_errors+crc_errors+timeout_errors}]
                                    else:
                                        full_results[oh_sn]['VFAT_SLOW_CONTROL_ERROR_SCAN'] = [{'TIME':runtime,'LINK_GOOD':link_good,'SYNC_ERROR_COUNT':sync_errors,'REGISTER_MISMATCH_ERROR_COUNT':mismatch_errors,'TOTAL_ERROR_COUNT':sync_errors+bus_errors+mismatch_errors+crc_errors+timeout_errors}]
                                    break
                    elif "Error test results" in line:
                        read_next = True
        for slot,oh_sn in geb_dict.items():
            for i,result in enumerate(full_results[oh_sn]['VFAT_SLOW_CONTROL_ERROR_SCAN']):
                if not result['LINK_GOOD'] or result['TOTAL_ERROR_COUNT']:
                    if not test_failed:
                        print (Colors.RED + "\nStep 9: Slow Control Error Rate Test Failed" + Colors.ENDC)
                        logfile.write("\nStep 9: Slow Control Error Rate Test Failed\n")
                        test_failed = True
                    if not result['LINK_GOOD']:
                        print(Colors.RED + 'ERROR:LINK_BAD encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                        logfile.write('ERROR:LINK_BAD encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
                    if result['REGISTER_MISMATCH_ERROR_COUNT']:
                        print(Colors.RED + 'ERROR:REGISTER_MISMATCH_ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                        logfile.write('ERROR:REGISTER_MISMATCH_ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
                    if result['SYNC_ERROR_COUNT']:
                        print(Colors.RED + 'ERROR:SYNC_ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                        logfile.write('ERROR:SYNC_ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
                    if result['TOTAL_ERROR_COUNT'] and not (result['REGISTER_MISMATCH_ERROR_COUNT'] or result['SYNC_ERROR_COUNT']):
                        print(Colors.RED + 'ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                        logfile.write('ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
        for oh_sn in xml_results:
            xml_results[oh_sn]['VFAT_SLOW_CONTROL_ERROR_COUNT'] = str(xml_results[oh_sn]['VFAT_SLOW_CONTROL_ERROR_COUNT'])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping Slow Control Error Rate Test for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping Slow Control Error Rate Test for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    print (Colors.GREEN + "\nStep 9: Slow Control Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 9: Slow Control Error Rate Test Complete\n\n")

    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 10 - DAQ Error Rate Test
    print (Colors.BLUE + "Step 10: DAQ Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 10: DAQ Error Rate Test\n\n")
    time.sleep(1)
    
    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Running DAQ Error Rate Test on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running DAQ Error Rate Test on OH %d, all VFATs\n\n"%oh_select)
            if test_type in ["prototype", "pre_production", "pre_series"]:
                runtime = 30
            elif test_type == 'debug':
                runtime = 1
            else:
                runtime = 10
            os.system("python3 vfat_daq_test.py -s backend -q ME0 -o %d -v %s -t %d"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])),runtime))
            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_daq_test_results/*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            read_next = False
            with open(latest_file) as daq_results_file:
                for line in daq_results_file.readlines():
                    if read_next:
                        logfile.write(line)
                        if 'link is' in line:
                            vfat = int(line.split()[1].removesuffix(','))
                            link_good = 1 if line.split()[-1]=='GOOD' else 0
                            daq_l1a_counter_mismatch = 0 # reset mismatch flag
                        elif 'sync errors' in line:
                            sync_errors = int(line.split()[-1])
                        elif 'Mismatch between DAQ_EVENT_CNT and L1A counter' in line:
                            daq_l1a_counter_mismatch = int(line.split()[-1])
                        elif "CRC Errors" in line:
                            crc_errors = int(line.split()[-1])
                            for slot,oh_sn in geb_dict.items():
                                if vfat in geb_oh_map[slot]["VFAT"]:
                                    if 'VFAT_DAQ_CRC_ERROR_COUNT' in xml_results[oh_sn]:
                                        xml_results[oh_sn]["VFAT_DAQ_CRC_ERROR_COUNT"] += [crc_errors]
                                    else:
                                        xml_results[oh_sn]["VFAT_DAQ_CRC_ERROR_COUNT"] = [crc_errors]
                                    if 'VFAT_DAQ_ERROR_SCAN' in full_results[oh_sn]:
                                        full_results[oh_sn]["VFAT_DAQ_ERROR_SCAN"] += [{'TIME':runtime,'LINK_GOOD':link_good,'SYNC_ERROR_COUNT':sync_errors,'CRC_ERROR_COUNT':crc_errors,'DAQ_L1A_COUNTER_MISMATCH':daq_l1a_counter_mismatch}]
                                    else:
                                        full_results[oh_sn]["VFAT_DAQ_ERROR_SCAN"] = [{'TIME':runtime,'LINK_GOOD':link_good,'SYNC_ERROR_COUNT':sync_errors,'CRC_ERROR_COUNT':crc_errors,'DAQ_L1A_COUNTER_MISMATCH':daq_l1a_counter_mismatch}]
                                    break
                    elif "Error test results" in line:
                        read_next = True

        for slot,oh_sn in geb_dict.items():
            for i,result in enumerate(full_results[oh_sn]["VFAT_DAQ_ERROR_SCAN"]):
                if not result['LINK_GOOD'] or result['SYNC_ERROR_COUNT'] or result['CRC_ERROR_COUNT'] or result['DAQ_L1A_COUNTER_MISMATCH']:
                    if not test_failed:
                        print (Colors.RED + "\nStep 10: DAQ Error Rate Test Failed" + Colors.ENDC)
                        logfile.write("\nStep 10: DAQ Error Rate Test Failed\n")
                        test_failed = True
                    if not result['LINK_GOOD']:
                        print(Colors.RED + 'ERROR:LINK_BAD encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                        logfile.write('ERROR:LINK_BAD encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
                    if result['SYNC_ERROR_COUNT']:
                        print(Colors.RED + 'ERROR:SYNC_ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                        logfile.write('ERROR:SYNC_ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))      
                    if result['DAQ_L1A_COUNTER_MISMATCH']:
                        print(Colors.RED + 'ERROR:DAQ_L1A_COUNTER_MISMATCH encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                        logfile.write('ERROR:DAQ_L1A_COUNTER_MISMATCH encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
                    if result['CRC_ERROR_COUNT']:
                        print(Colors.RED + 'ERROR:DAQ_CRC_ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                        logfile.write('ERROR:DAQ_CRC_ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
        for oh_sn in xml_results:
            xml_results[oh_sn]["VFAT_DAQ_CRC_ERROR_COUNT"] = str(xml_results[oh_sn]["VFAT_DAQ_CRC_ERROR_COUNT"])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping DAQ Error Rate Test for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping DAQ Error Rate Test for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    print (Colors.GREEN + "\nStep 10: DAQ Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 10: DAQ Error Rate Test Complete\n\n")

    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 11 - ADC Measurements
    print (Colors.BLUE + "Step 11: ADC Measurements\n" + Colors.ENDC)
    logfile.write("Step 11: ADC Measurements\n\n")
    time.sleep(1)
    
    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Configuring all VFATs\n" + Colors.ENDC)
            logfile.write("Configuring all VFATs\n\n")
            logfile.close()
            os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v %s -c 1 -lt >> %s"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])),log_fn))
            logfile = open(log_fn, "a")
    else:
        print(Colors.BLUE + "Skipping VFAT Configuration for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping VFAT Configuration for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for slot,oh_sn in geb_dict.items():
            oh_select = geb_oh_map[slot]["OH"]
            for gbt in geb_oh_map[slot]["GBT"]:
                gbt_type = 'M' if gbt%2==0 else 'S'
                print (Colors.BLUE + "\nRunning ADC Calibration Scan for gbt %d\n"%gbt + Colors.ENDC)
                logfile.write("Running ADC Calibration Scan for gbt %d\n\n"%gbt)
                logfile.close()
                os.system("python3 me0_lpgbt_adc_calibration_scan.py -s backend -q ME0 -o %d -g %d >> %s"%(oh_select,gbt,log_fn))
                logfile = open(log_fn,"a")
                list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/adc_calibration_data/*GBT%d*results*.txt"%gbt)
                latest_file = max(list_of_files,key=os.path.getctime)
                os.system("cp %s %s/adc_calib_results_OH%s_%s.txt"%(latest_file,dataDir,oh_sn,gbt_type))
                with open(latest_file) as adc_calib_file:
                    try:
                        xml_results[oh_sn]['LPGBT_%s_OH_CALIB'%gbt_type] = full_results[oh_sn]['LPGBT_%s_OH_CALIB'%gbt_type] = [float(p) for p in adc_calib_file.read().split()]
                    except:
                        xml_results[oh_sn]['LPGBT_%s_OH_CALIB'%gbt_type] = full_results[oh_sn]['LPGBT_%s_OH_CALIB'%gbt_type] = NULL
                list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/adc_calibration_data/*GBT%d*.pdf"%gbt)
                if len(list_of_files)>0:
                    gbt_type = 'BOSS' if gbt%2==0 else 'SUB'
                    latest_file = max(list_of_files, key=os.path.getctime)
                    os.system("cp %s %s/adc_calib_OH%s_%s.pdf"%(latest_file, dataDir, oh_sn, gbt_type))

        for slot,oh_sn in geb_dict.items():
            for gbt in geb_oh_map[slot]['GBT']:
                gbt_type = 'M' if gbt%2==0 else 'S'
                if xml_results[oh_sn]['LPGBT_%s_OH_CALIB'%gbt_type]==NULL:
                    if not test_failed:
                        print (Colors.RED + "\nStep 11: ADC Calibration Scan Failed" + Colors.ENDC)
                        logfile.write("\nStep 11: ADC Calibration Scan Failed\n")
                        test_failed = True
                    gbt_type = 'BOSS' if gbt%2==0 else 'SUB'
                    print(Colors.RED + 'ERROR encountered at OH %s %s lpGBT'%(oh_sn,gbt_type) + Colors.ENDC)
                    logfile.write('ERROR encountered at OH %s %s lpGBT\n'%(oh_sn,gbt_type))
        for oh_sn in xml_results:
            xml_results[oh_sn]['LPGBT_M_OH_CALIB'] = str(xml_results[oh_sn]['LPGBT_M_OH_CALIB'])
            xml_results[oh_sn]['LPGBT_S_OH_CALIB'] = str(xml_results[oh_sn]['LPGBT_S_OH_CALIB'])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping ADC Calibration Scan for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping ADC Calibration Scan for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for slot,oh_sn in geb_dict.items():
            voltages={}
            oh_select = geb_oh_map[slot]["OH"]
            for gbt in geb_oh_map[slot]["GBT"]:
                gbt_type = 'M' if gbt%2==0 else 'S'
                gbt_type_long = 'BOSS' if gbt%2==0 else 'SUB'
                voltages[gbt_type_long] = {}
                print (Colors.BLUE + "\nRunning lpGBT Voltage Scan for OH %s %s lpGBT\n"%(oh_sn,gbt_type_long) + Colors.ENDC)
                logfile.write("Running lpGBT Voltage Scan for OH %s %s lpGBT\n\n"%(oh_sn,gbt_type_long))
                logfile.close()
                os.system("python3 me0_voltage_monitor.py -s backend -q ME0 -o %d -g %d -n 10 >> %s"%(oh_select,gbt,log_fn))
                os.system("python3 clean_log.py -i %s"%log_fn)
                logfile = open(log_fn,"a")
                list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_voltage_data/*GBT%d*.txt"%gbt)
                latest_file = max(list_of_files,key=os.path.getctime)
                os.system("cp %s %s/lpgbt_voltage_scan_OH%s_%s.txt"%(latest_file,dataDir,oh_sn,gbt_type_long))
                with open(latest_file) as voltage_scan_file:
                    line = voltage_scan_file.readline()
                    for i in [2,4,8,12,16,20,24]:
                        key = line.split()[i]
                        if key not in voltages[gbt_type_long]:
                            voltages[gbt_type_long][key]=[]
                    for line in voltage_scan_file.readlines():
                        for key,val in zip(voltages[gbt_type_long],line.split()[1:]):
                            if val!=str(NULL):
                                voltages[gbt_type_long][key]+=[float(val)]
                list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_voltage_data/*GBT%d*.pdf"%gbt)
                if len(list_of_files)>0:
                    latest_file = max(list_of_files, key=os.path.getctime)
                    os.system("cp %s %s/voltage_OH%s_%s.pdf"%(latest_file, dataDir, oh_sn, gbt_type_long))

                full_results[oh_sn]['LPGBT_%s_OH_VOLTAGE_SCAN'%gbt_type] = {}
                for key,values in voltages[gbt_type_long].items():
                    if values != []:
                        full_results[oh_sn]['LPGBT_%s_OH_VOLTAGE_SCAN'%gbt_type][key] = np.mean(values)
                    else:
                        full_results[oh_sn]['LPGBT_%s_OH_VOLTAGE_SCAN'%gbt_type][key] = NULL

            if voltages['SUB']['V2V5']!=[]:
                xml_results[oh_sn]['OH_2V5_VOLTAGE'] = np.mean(voltages['SUB']['V2V5'])
            else:
                xml_results[oh_sn]['OH_2V5_VOLTAGE'] = NULL
            if voltages['BOSS']['VDD']!=[]:
                xml_results[oh_sn]['OH_1V2_VOLTAGE'] = np.mean(voltages['BOSS']['VDD'])
            else:
                xml_results[oh_sn]['OH_1V2_VOLTAGE'] = NULL

        voltage_ranges = {'V2V5':[2.4,2.8],'VSSA':[1.05,1.45],'VDDTX':[1.05,1.45],'VDDRX':[1.05,1.45],'VDD':[1.05,1.45],'VDDA':[1.05,1.45],'VREF':[0.85,1.15]}
        for oh_sn in xml_results:
            for voltage,reading in zip(['V2V5','VDD'],[xml_results[oh_sn]['OH_2V5_VOLTAGE'],xml_results[oh_sn]['OH_1V2_VOLTAGE']]):
                if reading == NULL:
                    if not test_failed:
                        print (Colors.RED + "\nStep 11: lpGBT Voltage Scan Failed\n" + Colors.ENDC)
                        logfile.write("\nStep 11: lpGBT Voltage Scan Failed\n\n")
                        test_failed = True
                    print(Colors.RED + 'ERROR:MISSING_VALUE encountered at OH %s %s'%(oh_sn,voltage) + Colors.ENDC)
                    logfile.write('ERROR:MISSING_VALUE encountered at OH %s %s\n'%(oh_sn,voltage))
                elif reading < voltage_ranges[voltage][0] or reading > voltage_ranges[voltage][1]:
                    if not test_failed:
                        print (Colors.RED + "\nStep 11: lpGBT Voltage Scan Failed\n" + Colors.ENDC)
                        logfile.write("\nStep 11: lpGBT Voltage Scan Failed\n\n")
                        test_failed = True
                    print(Colors.RED + 'ERROR:OUTSIDE_ACCEPTANCE_RANGE encountered at OH %s %s'%(oh_sn,voltage) + Colors.ENDC)
                    logfile.write('ERROR:OUTSIDE_ACCEPTANCE_RANGE encountered at OH %s %s\n'%(oh_sn,voltage))
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping lpGBT Voltage Scan for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping lpGBT Voltage Scan for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for slot,oh_sn in geb_dict.items():
            print (Colors.BLUE + "\nRunning RSSI Scan for slot %s\n"%slot + Colors.ENDC)
            logfile.write("Running RSSI Scan for slot %s\n\n"%slot)
            oh_select = geb_oh_map[slot]["OH"]
            gbt = geb_oh_map[slot]["GBT"][-1]
            logfile.close()
            os.system("python3 me0_rssi_monitor.py -s backend -q ME0 -o %d -g %d -v 2.56 -n 10 >> %s"%(oh_select,gbt,log_fn))
            logfile = open(log_fn,'a')
            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_vtrx+_rssi_data/*GBT%d*.txt"%gbt)
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system('cp %s %s/rssi_scan_OH%s.txt'%(latest_file,dataDir,oh_sn))
            with open(latest_file) as rssi_file:
                key = rssi_file.readline().split()[2]
                rssi=[]
                for line in rssi_file.readlines():
                    if line.split()[1] != str(NULL):
                        rssi += [float(line.split()[1])]
            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_vtrx+_rssi_data/*GBT%d*.pdf"%gbt)
            if len(list_of_files)>0:
                latest_file = max(list_of_files, key=os.path.getctime)
                os.system("cp %s %s/rssi_OH%s.pdf"%(latest_file, dataDir, oh_sn))
            if rssi != []:
                vtrxp_results[vtrxp_dict[slot]]['RSSI'] = np.mean(rssi)
            else:
                vtrxp_results[vtrxp_dict[slot]]['RSSI'] = NULL
        for slot,oh_sn in geb_dict.items():
            if vtrxp_results[vtrxp_dict[slot]]['RSSI'] == NULL:
                if not test_failed:
                    print (Colors.RED + "\nStep 11: RSSI Scan Failed" + Colors.ENDC)
                    logfile.write("\nStep 11: RSSI Scan Failed\n")
                    test_failed = True
                print(Colors.RED + 'ERROR:MISSING_VALUE encountered at OH %s'%oh_sn + Colors.ENDC)
                logfile.write('ERROR:MISSING_VALUE encountered at OH %s\n'%oh_sn)
            elif vtrxp_results[vtrxp_dict[slot]]['RSSI'] < 250:
                if not test_failed:
                    print (Colors.RED + "\nStep 11: RSSI Scan Failed" + Colors.ENDC)
                    logfile.write("\nStep 11: RSSI Scan Failed\n")
                    test_failed = True
                print(Colors.RED + 'ERROR:OUTSIDE_ACCEPTANCE_RANGE encountered at OH %s'%oh_sn + Colors.ENDC)
                logfile.write('ERROR:OUTSIDE_ACCEPTANCE_RANGE encountered at OH %s\n'%oh_sn)
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping RSSI Scan for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping RSSI Scan for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for slot,oh_sn in geb_dict.items():
            print (Colors.BLUE + "\nRunning GEB Current and Temperature Scan for slot %s\n"%slot + Colors.ENDC)
            logfile.write("Running GEB Current and Temperature Scan for slot %s\n\n"%slot)
            oh_select = geb_oh_map[slot]["OH"]
            gbt = geb_oh_map[slot]["GBT"][0]
            logfile.close()
            os.system("python3 me0_asense_monitor.py -s backend -q ME0 -o %d -g %d -n 10 >> %s"%(oh_select,gbt,log_fn))
            logfile = open(log_fn,'a')
            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_asense_data/*GBT%d*.txt"%gbt)
            latest_file = max(list_of_files,key=os.path.getctime)
            os.system('cp %s %s/geb_current_OH%s.txt'%(latest_file,dataDir,oh_sn))
            full_results[oh_sn]["ASENSE_SCAN"]={}
            with open(latest_file) as asense_file:
                line = asense_file.readline().split()
                asense = {}
                asense["_".join(line[3:5]).removeprefix('(PG').removesuffix(')').replace('V','').replace('.','V')] = []
                asense["_".join(line[7:9]).removeprefix('(').removesuffix(')')]=[]
                asense["_".join(line[11:13]).removeprefix('(PG').removesuffix(')').replace('V','').replace('.','V')] = []
                asense["_".join(line[15:17]).removeprefix('(').removesuffix(')')]=[]
                for line in asense_file.readlines():
                    for key,value in zip(asense,line.split()[1:]):
                        if value != str(NULL):
                            asense[key]+=[float(value)]
            for key,values in asense.items():
                if values:
                    full_results[oh_sn]["ASENSE_SCAN"][key]=np.mean(values)
                else:
                    full_results[oh_sn]["ASENSE_SCAN"][key]=NULL
            
            if int(slot)%2==0:
                prev_slot = int(slot) - 1
                if str(prev_slot) in geb_dict:
                    oh_sn_prev = geb_dict[str(prev_slot)]
                    full_results[oh_sn]['ASENSE_SCAN'] = full_results[oh_sn_prev]['ASENSE_SCAN'] = {**full_results[oh_sn]['ASENSE_SCAN'],**full_results[oh_sn_prev]['ASENSE_SCAN']}
                else:
                    geb_slot = full_results[oh_sn]['GEB_SLOT'].split('_')[0]
                    layer = geb_oh_map[slot]['OH']
                    print(Colors.YELLOW + 'WARNING: Only 1 OH board installed on LAYER %d %s module\nNot all ASENSE results could be stored for this GEB'%(layer,geb_slot) + Colors.ENDC)
                    logfile.write('WARNING: Only 1 OH board installed on LAYER %d %s module\nNot all ASENSE results could be stored for this GEB\n'%(layer,geb_slot))
            else:
                next_slot = int(slot) + 1
                if str(next_slot) not in geb_dict:
                    geb_slot = full_results[oh_sn]['GEB_SLOT'].split('_')[0]
                    layer = geb_oh_map[slot]['OH']
                    print(Colors.YELLOW + 'WARNING: Only 1 OH board installed on LAYER %d %s module\nNot all ASENSE results could be stored for this GEB'%(layer,geb_slot) + Colors.ENDC)
                    logfile.write('WARNING: Only 1 OH board installed on LAYER %d %s module\nNot all ASENSE results could be stored for this GEB\n'%(layer,geb_slot))

            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_asense_data/*GBT%d_pg_current*.pdf"%gbt)
            if len(list_of_files)>0:
                latest_file = max(list_of_files, key=os.path.getctime)
                os.system("cp %s %s/pg_current_OH%s.pdf"%(latest_file, dataDir,oh_sn))
            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/lpgbt_asense_data/*GBT%d_rt_voltage*.pdf"%gbt)
            if len(list_of_files)>0:
                latest_file = max(list_of_files, key=os.path.getctime)
                os.system("cp %s %s/rt_voltage_OH%s.pdf"%(latest_file, dataDir,oh_sn))
        for oh_sn in full_results:
            # Convert to temperature but pass missing value keys
            V_to_T = lambda v: 115*v - 22 if v!=NULL else v
            try:
                xml_results[oh_sn]['DCDC_1V2D_CURRENT'] = full_results[oh_sn]["ASENSE_SCAN"]['1V2D_current']
                xml_results[oh_sn]['DCDC_1V2A_CURRENT'] = full_results[oh_sn]["ASENSE_SCAN"]['1V2A_current']
            except KeyError:
                xml_results[oh_sn]['DCDC_1V2D_CURRENT'] = NULL
                xml_results[oh_sn]['DCDC_1V2A_CURRENT'] = NULL
            try:
                xml_results[oh_sn]['DCDC_2V5_CURRENT'] = full_results[oh_sn]["ASENSE_SCAN"]['2V5_current']
            except KeyError:
                xml_results[oh_sn]['DCDC_2V5_CURRENT'] = NULL
            try:
                xml_results[oh_sn]['DCDC_1V2D_TEMP'] = V_to_T(full_results[oh_sn]["ASENSE_SCAN"]['Rt3_voltage'])
                xml_results[oh_sn]['DCDC_1V2A_TEMP'] = V_to_T(full_results[oh_sn]["ASENSE_SCAN"]['Rt4_voltage'])
            except KeyError:
                xml_results[oh_sn]['DCDC_1V2D_TEMP'] = NULL
                xml_results[oh_sn]['DCDC_1V2A_TEMP'] = NULL
            try:
                xml_results[oh_sn]['DCDC_2V5_TEMP'] = V_to_T(full_results[oh_sn]["ASENSE_SCAN"]['Rt2_voltage'])
            except KeyError:
                xml_results[oh_sn]['DCDC_2V5_TEMP'] = NULL

        asense_ranges = {'DCDC_1V2D_CURRENT':3,'DCDC_1V2A_CURRENT':3,'DCDC_2V5_CURRENT':0.5,'DCDC_2V5_TEMP':35,'DCDC_1V2D_TEMP':35,'DCDC_1V2A_TEMP':35}
        for oh_sn in xml_results:
            for key,limit in asense_ranges.items():
                try:
                    if xml_results[oh_sn][key] == NULL:
                        if not test_failed:
                            print (Colors.RED + "\nStep 11: GEB Current and Temperature Scan Failed" + Colors.ENDC)
                            logfile.write("\nStep 11: GEB Current and Temperature Scan Failed\n")
                            test_failed = True
                        print(Colors.RED + 'ERROR:MISSING_VALUE encountered at OH %s %s'%(oh_sn,key) + Colors.ENDC)
                        logfile.write('ERROR:MISSING_VALUE encountered at OH %s %s\n'%(oh_sn,key))
                    elif xml_results[oh_sn][key] > limit:
                        if not test_failed:
                            print (Colors.RED + "\nStep 11: GEB Current and Temperature Scan Failed" + Colors.ENDC)
                            logfile.write("\nStep 11: GEB Current and Temperature Scan Failed\n")
                            test_failed = True
                        print(Colors.RED + 'ERROR:OUTSIDE_ACCEPTANCE_RANGE encountered at OH %s %s'%(oh_sn,key) + Colors.ENDC)
                        logfile.write('ERROR:OUTSIDE_ACCEPTANCE_RANGE encountered at OH %s %s\n'%(oh_sn,key))
                except KeyError:
                    print(Colors.YELLOW + 'WARNING: Missing result for %s for OH %s'%(key,oh_sn) + Colors.ENDC)
                    logfile.write('WARNING: Missing result for %s for OH %s'%(key,oh_sn))
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping GEB Current and Temperature Scan for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping GEB Current and Temperature Scan for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for slot,oh_sn in geb_dict.items():
            print (Colors.BLUE + "\nRunning OH Temperature Scan on slot %s\n"%slot + Colors.ENDC)
            logfile.write("Running OH Temperature Scan on slot %s\n\n"%slot)
            oh_select = geb_oh_map[slot]["OH"]
            gbt = geb_oh_map[slot]["GBT"][-1]
            logfile.close()
            os.system("python3 me0_temp_monitor.py -s backend -q ME0 -o %d -g %d -t OH -n 10 >> %s"%(oh_select,gbt,log_fn))
            logfile = open(log_fn,'a')
            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/temp_monitor_data/*GBT%d*.txt"%gbt)
            latest_file = max(list_of_files,key=os.path.getctime)
            os.system('cp %s %s/oh_temperature_scan_OH%s.txt'%(latest_file,dataDir,oh_sn))
            with open(latest_file) as temp_file:
                keys = temp_file.readline().split()[2:7:2]
                temperatures = {}
                for key in keys:
                    temperatures[key]=[]
                for line in temp_file.readlines():
                    for key,value in zip(temperatures,line.split()[1:]):
                        if float(value) != NULL:
                            temperatures[key]+=[float(value)]
            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/temp_monitor_data/*GBT%d_temp_OH*.pdf"%gbt)
            if len(list_of_files)>0:
                latest_file = max(list_of_files, key=os.path.getctime)
                os.system("cp %s %s/oh_temp_OH%s.pdf"%(latest_file, dataDir,oh_sn))
            if temperatures['Temperature'] != []:
                xml_results[oh_sn]["OH_TEMP"] = np.mean(temperatures['Temperature'])
            else:
                xml_results[oh_sn]["OH_TEMP"] = NULL
            full_results[oh_sn]['OH_TEMP'] = xml_results[oh_sn]['OH_TEMP']
        temperature_range = 45
        for oh_sn in xml_results:
            if xml_results[oh_sn]['OH_TEMP'] == NULL:
                if not test_failed:
                    print (Colors.RED + "\nStep 11: OH Temperature Scan Failed" + Colors.ENDC)
                    logfile.write("\nStep 11: OH Temperature Scan Failed\n")
                    test_failed = True
                print(Colors.RED + 'ERROR:MISSING_VALUE encountered at OH %s %s'%(oh_sn,key) + Colors.ENDC)
                logfile.write('ERROR:MISSING_VALUE encountered at OH %s %s\n'%(oh_sn,key))
            elif xml_results[oh_sn]['OH_TEMP'] > temperature_range:
                if not test_failed:
                    print (Colors.RED + "\nStep 11: OH Temperature Scan Failed" + Colors.ENDC)
                    logfile.write("\nStep 11: OH Temperature Scan Failed\n")
                    test_failed = True
                print(Colors.RED + 'ERROR:OUTSIDE_ACCEPTANCE_RANGE encountered at OH %s %s'%(oh_sn,key) + Colors.ENDC)
                logfile.write('ERROR:OUTSIDE_ACCEPTANCE_RANGE encountered at OH %s %s\n'%(oh_sn,key))
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping OH Temperature Scan for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping OH Temperature Scan for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)
    
    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for slot,oh_sn in geb_dict.items():
            print (Colors.BLUE + "\nRunning VTRx+ Temperature Scan for slot %s\n"%slot + Colors.ENDC)
            logfile.write("Running VTRx+ Temperature Scan for slot %s\n\n"%slot)
            oh_select = geb_oh_map[slot]["OH"]
            gbt = geb_oh_map[slot]["GBT"][-1]
            logfile.close()
            os.system("python3 me0_temp_monitor.py -s backend -q ME0 -o %d -g %d -t VTRX -n 10 >> %s"%(oh_select,gbt,log_fn))
            logfile = open(log_fn,'a')
            list_of_files = glob.glob('results/me0_lpgbt_data/temp_monitor_data/*GBT%d*.txt'%gbt)
            latest_file = max(list_of_files,key=os.path.getctime)
            os.system('cp %s %s/vtrx_temperature_scan_OH%s.txt'%(latest_file,dataDir,oh_sn))
            with open(latest_file) as vtrx_temp_file:
                keys = vtrx_temp_file.readline().split()[2:7:2]
                temperatures = {}
                for key in keys:
                    temperatures[key]=[]
                for line in vtrx_temp_file.readlines():
                    for key,value in zip(temperatures,line.split()[1:]):
                        if float(value)!=NULL:
                            temperatures[key]+=[float(value)]
            list_of_files = glob.glob(scripts_gem_dir + "/results/me0_lpgbt_data/temp_monitor_data/*GBT%d_temp_VTRX*.pdf"%gbt)
            if len(list_of_files)>0:
                latest_file = max(list_of_files, key=os.path.getctime)
                os.system("cp %s %s/vtrx+_temp_OH%s.pdf"%(latest_file, dataDir,oh_sn))
            if temperatures['Temperature']!=[]:
                vtrxp_results[vtrxp_dict[slot]]['TEMP'] = np.mean(temperatures['Temperature'])
            else:
                vtrxp_results[vtrxp_dict[slot]]['TEMP'] = NULL
        temperature_range = 45
        for slot,oh_sn in geb_dict.items():
            if vtrxp_results[vtrxp_dict[slot]]['TEMP'] == NULL:
                if not test_failed:
                    print (Colors.RED + "\nStep 11: VTRx+ Temperature Scan Failed" + Colors.ENDC)
                    logfile.write("\nStep 11: VTRx+ Temperature Scan Failed\n")
                    test_failed = True
                print(Colors.RED + 'ERROR:MISSING_VALUE encountered at OH %s %s'%(oh_sn,key) + Colors.ENDC)
                logfile.write('ERROR:MISSING_VALUE encountered at OH %s %s\n'%(oh_sn,key))
            elif vtrxp_results[vtrxp_dict[slot]]['TEMP'] > temperature_range:
                if not test_failed:
                    print (Colors.RED + "\nStep 11: VTRx+ Temperature Scan Failed" + Colors.ENDC)
                    logfile.write("\nStep 11: VTRx+ Temperature Scan Failed\n")
                    test_failed = True
                print(Colors.RED + 'ERROR:OUTSIDE_ACCEPTANCE_RANGE encountered at OH %s %s'%(oh_sn,key) + Colors.ENDC)
                logfile.write('ERROR:OUTSIDE_ACCEPTANCE_RANGE encountered at OH %s %s\n'%(oh_sn,key))
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping VTRx+ Temperature Scan for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping VTRx+ Temperature Scan for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        print (Colors.BLUE + "\nUnconfiguring all VFATs\n" + Colors.ENDC)
        logfile.write("Unconfiguring all VFATs\n\n")
        logfile.close()
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v %s -c 0 >> %s"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])),log_fn))    
        logfile = open(log_fn, "a")
    
    print (Colors.GREEN + "\nStep 11: ADC Measurements Complete\n" + Colors.ENDC)
    logfile.write("\nStep 11: ADC Measurements Complete\n\n")

    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 12 - DAQ SCurve 
    print (Colors.BLUE + "Step 12: DAQ SCurve\n" + Colors.ENDC)
    logfile.write("Step 12: DAQ SCurve\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Running DAQ SCurves for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running DAQ SCurves for OH %d all VFATs\n\n"%oh_select)
            if debug:
                os.system("python3 vfat_daq_scurve.py -s backend -q ME0 -o %d -v %s -n 10"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            else:
                os.system("python3 vfat_daq_scurve.py -s backend -q ME0 -o %d -v %s -n 1000"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))

            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_daq_scurve_results/*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            latest_dir = latest_file.split(".txt")[0]

            print (Colors.BLUE + "Plotting DAQ SCurves for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Plotting DAQ SCurves for OH %d all VFATs\n\n"%oh_select)
            os.system("python3 plotting_scripts/vfat_analysis_scurve.py -c 0 -m voltage -f %s"%latest_file)
            if os.path.isdir(latest_dir):
                os.system("cp %s/scurve2Dhist_ME0_OH%d.png %s/daq_scurve_2D_hist_OH%d.png"%(latest_dir, oh_select, dataDir,oh_select))
                os.system("cp %s/scurveENCdistribution_ME0_OH%d.pdf %s/daq_scurve_ENC_OH%d.pdf"%(latest_dir, oh_select, dataDir,oh_select))
                os.system("cp %s/scurveThreshdistribution_ME0_OH%d.pdf %s/daq_scurve_Threshold_OH%d.pdf"%(latest_dir, oh_select, dataDir,oh_select))
            else:
                print (Colors.RED + "DAQ Scurve result directory not found" + Colors.ENDC)
                logfile.write("DAQ SCurve result directory not found\n")
            
            scurve = {}
            bad_channels = {}                
            with open(latest_file) as scurve_file:
                for line in scurve_file.readlines()[1:]:
                    vfat = int(line.split()[0])
                    channel = int(line.split()[1])
                    fired = int(line.split()[3])
                    if vfat in scurve:
                        if channel in scurve[vfat]:
                            scurve[vfat][channel]+=[fired]
                        else:
                            scurve[vfat][channel]=[fired]
                    else:
                        scurve[vfat]={}
                        scurve[vfat][channel]=[fired]
            for vfat in scurve:
                bad_channels[vfat]=[]
                for channel in scurve[vfat]:
                    if np.all(np.equal(scurve[vfat][channel],0)):
                        bad_channels[vfat].append([channel])

            for slot,oh_sn in geb_dict.items():
                if geb_oh_map[slot]['OH']==oh_select:
                    full_results[oh_sn]['VFAT_DAQ_S_CURVE']=[{} for _ in range(6)]
                    for i,vfat in enumerate(geb_oh_map[slot]["VFAT"]):
                        if vfat < 10:
                            scurve_fn = glob.glob('%s/fitResults_*VFAT0%d.txt'%(latest_dir,vfat))[0]
                        else:
                            scurve_fn = glob.glob('%s/fitResults_*VFAT%d.txt'%(latest_dir,vfat))[0]
                        read_next = False
                        with open(scurve_fn) as scurve_file:
                            for line in scurve_file.readlines():
                                if read_next:
                                    if "ENC" in line:
                                        enc = float(line.split()[2])
                                        if bad_channels[vfat]:
                                            full_results[oh_sn]['VFAT_DAQ_S_CURVE'][i]['STATUS']=0
                                            full_results[oh_sn]['VFAT_DAQ_S_CURVE'][i]['ENC']=enc
                                            full_results[oh_sn]['VFAT_DAQ_S_CURVE'][i]['NUM_BAD_CHANNELS']=len(bad_channels[vfat])
                                            full_results[oh_sn]['VFAT_DAQ_S_CURVE'][i]['BAD_CHANNELS']=bad_channels[vfat]
                                        else:
                                            full_results[oh_sn]['VFAT_DAQ_S_CURVE'][i]['STATUS']=1
                                            full_results[oh_sn]['VFAT_DAQ_S_CURVE'][i]['ENC']=enc
                                            full_results[oh_sn]['VFAT_DAQ_S_CURVE'][i]['NUM_BAD_CHANNELS']=0
                                            full_results[oh_sn]['VFAT_DAQ_S_CURVE'][i]['BAD_CHANNELS']=[]
                                elif "Summary" in line:
                                    read_next = True
                else:
                    continue
        for oh_sn in full_results:
            xml_results[oh_sn]['VFAT_DAQ_S_CURVE_ENC'] = []
            xml_results[oh_sn]['VFAT_DAQ_S_CURVE_BAD_CHANNELS'] = []
            for result in full_results[oh_sn]['VFAT_DAQ_S_CURVE']:
                xml_results[oh_sn]['VFAT_DAQ_S_CURVE_ENC'].append(result['ENC'])
                xml_results[oh_sn]['VFAT_DAQ_S_CURVE_BAD_CHANNELS'].append(result['NUM_BAD_CHANNELS'])
        for oh_sn in xml_results:
            for i,result in enumerate(xml_results[oh_sn]['VFAT_DAQ_S_CURVE_BAD_CHANNELS']):
                if result:
                    if not test_failed:
                        print (Colors.RED + "\nStep 12: DAQ SCurve Failed\n" + Colors.ENDC)
                        logfile.write("\nStep 12: DAQ SCurve Failed\n\n")
                        test_failed = True
                    print(Colors.RED + 'ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                    logfile.write('ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
        for oh_sn in xml_results:
            xml_results[oh_sn]['VFAT_DAQ_S_CURVE_ENC'] = str(xml_results[oh_sn]['VFAT_DAQ_S_CURVE_ENC'])
            xml_results[oh_sn]['VFAT_DAQ_S_CURVE_BAD_CHANNELS'] = str(xml_results[oh_sn]['VFAT_DAQ_S_CURVE_BAD_CHANNELS'])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping DAQ SCurve for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping DAQ SCurve for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    print (Colors.GREEN + "\nStep 12: DAQ SCurve Complete\n" + Colors.ENDC)
    logfile.write("\nStep 12: DAQ SCurve Complete\n\n")

    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 13 - DAQ Crosstalk
    print (Colors.BLUE + "Step 13: DAQ Crosstalk\n" + Colors.ENDC)
    logfile.write("Step 13: DAQ Crosstalk\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Running DAQ Crosstalk for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running DAQ Crosstalk for OH %d all VFATs\n\n"%oh_select)
            if debug:
                os.system("python3 vfat_daq_crosstalk.py -s backend -q ME0 -o %d -v %s -n 10"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            else:
                os.system("python3 vfat_daq_crosstalk.py -s backend -q ME0 -o %d -v %s -n 1000"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))

            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_daq_crosstalk_results/*_result.txt")
            latest_file = max(list_of_files, key=os.path.getctime)            
            read_next = False
            no_crosstalk = False
            crosstalk = {}
            with open(latest_file) as crosstalk_file:
                for line in crosstalk_file.readlines():
                    if read_next:
                        if 'No Cross Talk observed' in line:
                            no_crosstalk = True
                        elif 'VFAT' in line:
                            vfat = int(line.split()[1].removesuffix(','))
                            channel_inj = int(line.split()[6])
                            channels_obs = line.split()[9:]
                            for i,ch in enumerate(channels_obs):
                                channels_obs[i] = int(ch.removesuffix(','))
                            if vfat in crosstalk:
                                crosstalk[vfat][channel_inj]=channels_obs
                            else:
                                crosstalk[vfat]={}
                                crosstalk[vfat][channel_inj]=channels_obs
                    elif "Cross Talk Results" in line:
                        read_next = True
            
            for slot,oh_sn in geb_dict.items():
                if geb_oh_map[slot]['OH']==oh_select:
                    full_results[oh_sn]["VFAT_DAQ_CROSSTALK"]=[{} for _ in range(6)]
                    if no_crosstalk:
                        for i in range(6):
                            full_results[oh_sn]["VFAT_DAQ_CROSSTALK"][i]['STATUS']=1
                            full_results[oh_sn]['VFAT_DAQ_CROSSTALK'][i]['NUM_BAD_CHANNELS']=0
                            full_results[oh_sn]['VFAT_DAQ_CROSSTALK'][i]['BAD_CHANNELS']=[]
                    elif crosstalk:
                        for i,vfat in enumerate(geb_oh_map[slot]['VFAT']):
                            if vfat in crosstalk:
                                full_results[oh_sn]["VFAT_DAQ_CROSSTALK"][i]['STATUS']=0
                                full_results[oh_sn]["VFAT_DAQ_CROSSTALK"][i]['NUM_BAD_CHANNELS']=len(crosstalk[vfat])
                                full_results[oh_sn]["VFAT_DAQ_CROSSTALK"][i]['BAD_CHANNELS']=[{'Channel_inj':channel_inj,'Channels_obs':channels_obs} for channel_inj,channels_obs in crosstalk[vfat].items()]
                            else:
                                full_results[oh_sn]["VFAT_DAQ_CROSSTALK"][i]['STATUS']=1
                                full_results[oh_sn]['VFAT_DAQ_CROSSTALK'][i]['NUM_BAD_CHANNELS']=0
                                full_results[oh_sn]['VFAT_DAQ_CROSSTALK'][i]['BAD_CHANNELS']=[]
                else:
                    continue
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")
            print (Colors.BLUE + "Plotting DAQ Crosstalk for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Plotting DAQ Crosstalk for OH %d all VFATs\n\n"%oh_select)

            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_daq_crosstalk_results/*_data.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            latest_dir = latest_file.split(".txt")[0]
            os.system("python3 plotting_scripts/vfat_plot_crosstalk.py -f %s"%latest_file)
            if os.path.isdir(latest_dir):
                os.system("cp %s/crosstalk_ME0_OH%d.pdf %s/daq_crosstalk_OH%d.pdf"%(latest_dir,oh_select, dataDir,oh_select))
            else:
                print (Colors.RED + "DAQ Crosstalk result directory not found" + Colors.ENDC)
                logfile.write("DAQ Crosstalk result directory not found\n")
        
        for oh_sn in full_results:
            xml_results[oh_sn]['VFAT_DAQ_CROSSTALK_BAD_CHANNELS'] = []
            for result in full_results[oh_sn]['VFAT_DAQ_CROSSTALK']:
                xml_results[oh_sn]['VFAT_DAQ_CROSSTALK_BAD_CHANNELS'].append(result['NUM_BAD_CHANNELS'])
        
        for slot,oh_sn in geb_dict.items():
            for i,result in enumerate(xml_results[oh_sn]["VFAT_DAQ_CROSSTALK_BAD_CHANNELS"]):
                if result:
                    if not test_failed:
                        print (Colors.RED + "\nStep 13: DAQ Crosstalk Failed\n" + Colors.ENDC)
                        logfile.write("\nStep 13: DAQ Crosstalk Failed\n\n")
                        test_failed = True
                    print(Colors.RED + 'ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                    logfile.write('ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
        for oh_sn in xml_results:
            xml_results[oh_sn]['VFAT_DAQ_CROSSTALK_BAD_CHANNELS'] = str(xml_results[oh_sn]['VFAT_DAQ_CROSSTALK_BAD_CHANNELS'])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping DAQ Crosstalk for %s tests"%test_type.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping DAQ Crosstalk for %s tests\n"%test_type.replace("_","-"))
        time.sleep(1)

    print (Colors.GREEN + "\nStep 13: DAQ Crosstalk Complete\n" + Colors.ENDC)
    logfile.write("\nStep 13: DAQ Crosstalk Complete\n\n")
    
    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 14 - S-bit SCurve
    print (Colors.BLUE + "Step 14: S-bit SCurve\n" + Colors.ENDC)
    logfile.write("Step 14: S-bit SCurve\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series"]:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():    
            print (Colors.BLUE + "Running S-bit SCurves for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running S-bit SCurves for OH %d all VFATs\n\n"%oh_select)
            if debug:
                os.system("python3 me0_vfat_sbit_scurve.py -s backend -q ME0 -o %d -v %s -n 10 -l -f"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            else:
                os.system("python3 me0_vfat_sbit_scurve.py -s backend -q ME0 -o %d -v %s -n 1000 -l -f"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            
            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_sbit_scurve_results/*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            latest_dir = latest_file.split(".txt")[0]

            print (Colors.BLUE + "Plotting S-bit SCurves for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Plotting S-bit SCurves for OH %d all VFATs\n\n"%oh_select)
            os.system("python3 plotting_scripts/vfat_analysis_scurve.py -c 0 -m current -f %s"%latest_file)
            if os.path.isdir(latest_dir):
                os.system("cp %s/scurve2Dhist_ME0_OH%d.png %s/sbit_scurve_2D_hist_OH%d.png"%(latest_dir, oh_select, dataDir, oh_select))
                os.system("cp %s/scurveENCdistribution_ME0_OH%d.pdf %s/sbit_scurve_ENC_OH%d.pdf"%(latest_dir, oh_select, dataDir, oh_select))
                os.system("cp %s/scurveThreshdistribution_ME0_OH%d.pdf %s/sbit_scurve_Threshold_OH%d.pdf"%(latest_dir, oh_select, dataDir, oh_select))
            else:
                print (Colors.RED + "S-bit Scurve result directory not found" + Colors.ENDC)
                logfile.write("S-bit SCurve result directory not found\n")

            scurve = {}
            bad_channels = {}

            with open(latest_file) as scurve_file:
                for line in scurve_file.readlines()[1:]:
                    vfat = int(line.split()[0])
                    channel = int(line.split()[1])
                    fired = int(line.split()[3])
                    if vfat in scurve:
                        if channel in scurve[vfat]:
                            scurve[vfat][channel]+=[fired]
                        else:
                            scurve[vfat][channel]=[fired]
                    else:
                        scurve[vfat]={}
                        scurve[vfat][channel]=[fired]
            for vfat in scurve:
                bad_channels[vfat]=[]
                for channel in scurve[vfat]:
                    if np.all(np.equal(scurve[vfat][channel],0)):
                        bad_channels[vfat].append([channel])

            for slot,oh_sn in geb_dict.items():
                if geb_oh_map[slot]['OH']==oh_select:
                    full_results[oh_sn]["VFAT_SBIT_S_CURVE"]=[{} for _ in range(6)]
                    for i,vfat in enumerate(geb_oh_map[slot]["VFAT"]):
                        if vfat < 10:
                            scurve_fn = glob.glob('%s/fitResults_*VFAT0%d.txt'%(latest_dir,vfat))[0]
                        else:
                            scurve_fn = glob.glob('%s/fitResults_*VFAT%d.txt'%(latest_dir,vfat))[0]
                        read_next = False
                        with open(scurve_fn) as scurve_file:
                            for line in scurve_file.readlines():
                                if read_next:
                                    if "ENC" in line:
                                        enc = float(line.split()[2])
                                        if bad_channels[vfat]:
                                            full_results[oh_sn]["VFAT_SBIT_S_CURVE"][i]['STATUS']=0
                                            full_results[oh_sn]["VFAT_SBIT_S_CURVE"][i]['ENC']=enc
                                            full_results[oh_sn]["VFAT_SBIT_S_CURVE"][i]['NUM_BAD_CHANNELS']=len(bad_channels[vfat])
                                            full_results[oh_sn]["VFAT_SBIT_S_CURVE"][i]['BAD_CHANNELS']=bad_channels[vfat]
                                        else:
                                            full_results[oh_sn]["VFAT_SBIT_S_CURVE"][i]['STATUS']=1
                                            full_results[oh_sn]["VFAT_SBIT_S_CURVE"][i]['ENC']=enc
                                            full_results[oh_sn]["VFAT_SBIT_S_CURVE"][i]['NUM_BAD_CHANNELS']=0
                                            full_results[oh_sn]["VFAT_SBIT_S_CURVE"][i]['BAD_CHANNELS']=[]
                                elif "Summary" in line:
                                    read_next = True
                else:
                    continue
        for oh_sn in full_results:
            xml_results[oh_sn]['VFAT_SBIT_S_CURVE_ENC'] = []
            xml_results[oh_sn]['VFAT_SBIT_S_CURVE_BAD_CHANNELS'] = []
            for result in full_results[oh_sn]['VFAT_SBIT_S_CURVE']:
                xml_results[oh_sn]['VFAT_SBIT_S_CURVE_ENC'].append(result['ENC'])
                xml_results[oh_sn]['VFAT_SBIT_S_CURVE_BAD_CHANNELS'].append(result['NUM_BAD_CHANNELS'])
        for oh_sn in xml_results:
            for i,result in enumerate(xml_results[oh_sn]['VFAT_SBIT_S_CURVE_BAD_CHANNELS']):
                if result:
                    if not test_failed:
                        print (Colors.RED + "\nStep 14: S-bit SCurves Failed\n" + Colors.ENDC)
                        logfile.write("\nStep 14: S-bit SCurves Failed\n\n")
                        test_failed = True
                    print(Colors.RED + 'ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                    logfile.write('ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
        for oh_sn in xml_results:
            xml_results[oh_sn]['VFAT_SBIT_S_CURVE_ENC'] = str(xml_results[oh_sn]['VFAT_SBIT_S_CURVE_ENC'])
            xml_results[oh_sn]['VFAT_SBIT_S_CURVE_BAD_CHANNELS'] = str(xml_results[oh_sn]['VFAT_SBIT_S_CURVE_BAD_CHANNELS'])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping S-bit SCurves for %s tests"%test_type.replace("_"," ") + Colors.ENDC)
        logfile.write("Skipping S-bit SCurves for %s tests\n"%test_type.replace("_"," "))
        time.sleep(1)

    print (Colors.GREEN + "\nStep 14: S-bit SCurve Complete\n" + Colors.ENDC)
    logfile.write("\nStep 14: S-bit SCurve Complete\n\n")
    
    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 15 - S-bit Crosstalk
    print (Colors.BLUE + "Step 15: S-bit Crosstalk\n" + Colors.ENDC)
    logfile.write("Step 15: S-bit Crosstalk\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series"]:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Running S-bit Crosstalk for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running S-bit Crosstalk for OH %d all VFATs\n\n"%oh_select)
            if debug:
                os.system("python3 me0_vfat_sbit_crosstalk.py -s backend -q ME0 -o %d -v %s -n 10 -l -f"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            else:
                os.system("python3 me0_vfat_sbit_crosstalk.py -s backend -q ME0 -o %d -v %s -n 1000 -l -f"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))

            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_sbit_crosstalk_results/*_result.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            read_next = False
            no_crosstalk = False
            crosstalk = {}
            with open(latest_file) as crosstalk_file:
                for line in crosstalk_file.readlines():
                    if read_next:
                        if 'No Cross Talk observed' in line:
                            no_crosstalk = True
                        elif 'VFAT' in line:
                            vfat = int(line.split()[1].removesuffix(','))
                            channel_inj = int(line.split()[6])
                            channels_obs = line.split()[9:]
                            for i,ch in enumerate(channels_obs):
                                channels_obs[i] = int(ch.removesuffix(','))
                            if vfat in crosstalk:
                                crosstalk[vfat][channel_inj]=channels_obs
                            else:
                                crosstalk[vfat]={}
                                crosstalk[vfat][channel_inj]=channels_obs
                    elif "Cross Talk Results" in line:
                        read_next = True
            
            for slot,oh_sn in geb_dict.items():
                if geb_oh_map[slot]['OH']==oh_select:
                    full_results[oh_sn]["VFAT_SBIT_CROSSTALK"]=[{} for _ in range(6)]
                    if no_crosstalk:
                        for i in range(6):
                            full_results[oh_sn]["VFAT_SBIT_CROSSTALK"][i]['STATUS']=1
                            full_results[oh_sn]['VFAT_SBIT_CROSSTALK'][i]['NUM_BAD_CHANNELS']=0
                            full_results[oh_sn]['VFAT_SBIT_CROSSTALK'][i]['BAD_CHANNELS']=[]
                    elif crosstalk:
                        for i,vfat in enumerate(geb_oh_map[slot]['VFAT']):
                            if vfat in crosstalk:
                                full_results[oh_sn]["VFAT_SBIT_CROSSTALK"][i]['STATUS']=0
                                full_results[oh_sn]["VFAT_SBIT_CROSSTALK"][i]['NUM_BAD_CHANNELS']=len(crosstalk[vfat])
                                full_results[oh_sn]["VFAT_SBIT_CROSSTALK"][i]['BAD_CHANNELS']=[{'CHANNEL_INJ':channel_inj,'CHANNELS_OBS':channels_obs} for channel_inj,channels_obs in crosstalk[vfat].items()]
                            else:
                                full_results[oh_sn]["VFAT_SBIT_CROSSTALK"][i]['STATUS']=1
                                full_results[oh_sn]['VFAT_SBIT_CROSSTALK'][i]['NUM_BAD_CHANNELS']=0
                                full_results[oh_sn]['VFAT_SBIT_CROSSTALK'][i]['BAD_CHANNELS']=[]
                else:
                    continue
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")
            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_sbit_crosstalk_results/*_data.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            print (Colors.BLUE + "Plotting S-bit Crosstalk for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Plotting S-bit Crosstalk for OH %d all VFATs\n\n"%oh_select)
            os.system("python3 plotting_scripts/vfat_plot_crosstalk.py -f %s"%latest_file)
            latest_dir = latest_file.split(".txt")[0]
            if os.path.isdir(latest_dir):
                os.system("cp %s/crosstalk_ME0_OH%d.pdf %s/sbit_crosstalk_OH%d.pdf"%(latest_dir, oh_select, dataDir, oh_select))
            else:
                print (Colors.RED + "S-bit Crosstalk result directory not found" + Colors.ENDC)
                logfile.write("S-bit Crosstalk result directory not found\n")

        for oh_sn in full_results:
            xml_results[oh_sn]['VFAT_SBIT_CROSSTALK_BAD_CHANNELS'] = []
            for result in full_results[oh_sn]['VFAT_SBIT_CROSSTALK']:
                xml_results[oh_sn]['VFAT_SBIT_CROSSTALK_BAD_CHANNELS'].append(result['NUM_BAD_CHANNELS'])
        
        for slot,oh_sn in geb_dict.items():
            for i,result in enumerate(xml_results[oh_sn]["VFAT_SBIT_CROSSTALK_BAD_CHANNELS"]):
                if result:
                    if not test_failed:
                        print (Colors.RED + "\nStep 15: S-bit Crosstalk Failed\n" + Colors.ENDC)
                        logfile.write("\nStep 15: S-bit Crosstalk Failed\n\n")
                        test_failed = True
                    print(Colors.RED + 'ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                    logfile.write('ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
        for oh_sn in xml_results:
            xml_results[oh_sn]["VFAT_SBIT_CROSSTALK_BAD_CHANNELS"] = str(xml_results[oh_sn]["VFAT_SBIT_CROSSTALK_BAD_CHANNELS"])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping S-bit crosstalk for %s tests"%test_type.replace("_"," ") + Colors.ENDC)
        logfile.write("Skipping S-bit crosstalk for %s tests\n"%test_type.replace("_"," "))
        time.sleep(1)
    
    print (Colors.GREEN + "\nStep 15: S-bit Crosstalk Complete\n" + Colors.ENDC)
    logfile.write("\nStep 15: S-bit Crosstalk Complete\n\n")
    
    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 16 - S-bit Noise Rate
    print (Colors.BLUE + "Step 16: S-bit Noise Rate\n" + Colors.ENDC)
    logfile.write("Step 16: S-bit Noise Rate\n\n")
    time.sleep(1)

    if test_type in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance"]:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Running S-bit Noise Rate for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running S-bit Noise Rate for OH %d all VFATs\n\n"%oh_select)
            os.system("python3 me0_vfat_sbit_noise_rate.py -s backend -q ME0 -o %d -v %s -a -z -f"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            list_of_files = glob.glob(scripts_gem_dir + "/results/vfat_data/vfat_sbit_noise_results/*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            read_next = False
            sbit_noise = {}
            with open(latest_file) as sbit_noise_file:
                for line in sbit_noise_file.readlines()[1:]:
                    vfat = int(line.split()[0])
                    sbit = line.split()[1]
                    threshold = int(line.split()[2])
                    fired = int(line.split()[3])
                    if vfat not in sbit_noise:
                        sbit_noise[vfat] = {}
                    if "all_elink" in sbit:
                        elink = int(sbit.removeprefix("all_elink"))
                        if fired == 0 or threshold==255:
                            # save the first threshold with no hits or max threshold if failed
                            if elink not in sbit_noise[vfat]:
                                sbit_noise[vfat][elink]=threshold
                            else:
                                continue
            
            for vfat,sbit_noise_elink in sbit_noise.items():
                status_list = []
                threshold_list = []
                bad_elinks = []
                for slot,oh_sn in geb_dict.items():
                    if geb_oh_map[slot]["OH"]==oh_select and vfat in geb_oh_map[slot]["VFAT"]:
                        if 'VFAT_SBIT_NOISE_SCAN' not in full_results[oh_sn]:
                            full_results[oh_sn]["VFAT_SBIT_NOISE_SCAN"]=[]
                        break
                for elink,threshold in sbit_noise_elink.items():
                    threshold_list += [threshold]
                    if threshold >= 100 or threshold == 0:
                        status_list += [0]
                        bad_elinks += [elink]
                    else:
                        status_list += [1]
                full_results[oh_sn]["VFAT_SBIT_NOISE_SCAN"]+=[{'ELINK_STATUS':status_list,'ELINK_THRESHOLDS':threshold_list, 'BAD_ELINKS': bad_elinks, 'NUM_BAD_ELINKS': len(bad_elinks)}]

            print (Colors.BLUE + "Plotting S-bit Noise Rate for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Plotting S-bit Noise Rate for OH %d all VFATs\n\n"%oh_select)
            os.system("python3 plotting_scripts/vfat_plot_sbit_noise_rate.py -f %s"%latest_file)
            latest_dir = latest_file.split(".txt")[0]
            if os.path.isdir(latest_dir):
                if os.path.isdir(dataDir + "/sbit_noise_rate_results"):
                    os.system("rm -rf " + dataDir + "/sbit_noise_rate_results")
                os.makedirs(dataDir + "/sbit_noise_rate_results")
                os.system("cp %s/*_or_*.pdf %s/sbit_noise_rate_results/"%(latest_dir, dataDir))
            else:
                print(Colors.RED + "S-bit Noise Rate result directory not found" + Colors.ENDC)
                logfile.write("S-bit Noise Rate result directory not found\n")

        for oh_sn in full_results:
            xml_results[oh_sn]['VFAT_SBIT_NOISE_SCAN_BAD_ELINKS'] = []
            for result in full_results[oh_sn]['VFAT_SBIT_NOISE_SCAN']:
                xml_results[oh_sn]['VFAT_SBIT_NOISE_SCAN_BAD_ELINKS'] += [result['NUM_BAD_ELINKS']]
        for oh_sn in xml_results:
            for i,result in enumerate(xml_results[oh_sn]['VFAT_SBIT_NOISE_SCAN_BAD_ELINKS']):
                if result:
                    if not test_failed:
                        print(Colors.RED + "\nStep 16: S-bit Noise Rate Failed\n" + Colors.ENDC)
                        logfile.write("\nStep 16: S-bit Noise Rate Failed\n\n")
                        test_failed = True
                    print(Colors.RED + 'ERROR encountered at OH %s VFAT %d'%(oh_sn,geb_oh_map[slot]['VFAT'][i]) + Colors.ENDC)
                    logfile.write('ERROR encountered at OH %s VFAT %d\n'%(oh_sn,geb_oh_map[slot]['VFAT'][i]))
        for oh_sn in xml_results:
            xml_results[oh_sn]['VFAT_SBIT_NOISE_SCAN_BAD_ELINKS'] = str(xml_results[oh_sn]['VFAT_SBIT_NOISE_SCAN_BAD_ELINKS'])
        while test_failed:
            end_tests = input('\nWould you like to exit testing? >> ')
            if end_tests.lower() in ['y','yes']:
                print('\nTerminating and logging database results at directory: %s'%xml_results_fn)
                logfile.write('\nTerminating and logging database results at directory: %s\n'%xml_results_fn)
                print('\nLogging full results at directory: %s\n'%full_results_fn)
                logfile.write('\nLogging full results at directory: %s\n\n'%full_results_fn)
                xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
                full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
                vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]
                with open(xml_results_fn,"w") as xml_results_file:
                    json.dump(xml_results,xml_results_file,indent=2)
                with open(full_results_fn,'w') as full_results_file:
                    json.dump(full_results,full_results_file,indent=2)
                with open(vtrxp_results_fn,'w') as vtrxp_results_file:
                    json.dump(vtrxp_results,vtrxp_results_file,indent=2)
                logfile.close()
                sys.exit()
            elif end_tests.lower() in ['n','no']:
                test_failed = False
            else:
                print('Valid entries: y, yes, n, no')
    else:
        print(Colors.BLUE + "Skipping S-bit Noise Rate for %s tests"%test_type.replace("_"," ") + Colors.ENDC)
        logfile.write("Skipping S-bit Noise Rate for %s tests\n"%test_type.replace("_"," "))
        time.sleep(1)

    print(Colors.GREEN + "\nStep 16: S-bit Noise Rate Complete\n" + Colors.ENDC)
    logfile.write("\nStep 16: S-bit Noise Rate Complete\n\n")

    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    print('Time taken to perform %s tests: %.3f'%(test_type.replace('_','-'),(time.time()-t0)/60))
    logfile.write('Time taken to perform %s tests: %.3f\n'%(test_type.replace('_','-'),(time.time()-t0)/60))

    xml_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in xml_results.items()]
    full_results = [{'SERIAL_NUMBER':oh_sn,**results} for oh_sn,results in full_results.items()]
    vtrxp_results = [{'SERIAL_NUMBER':vtrxp_sn,**results} for vtrxp_sn,results in vtrxp_results.items()]

    with open(xml_results_fn,"w") as xml_results_file:
        json.dump(xml_results,xml_results_file,indent=2)
    with open(full_results_fn,'w') as full_results_file:
        json.dump(full_results,full_results_file,indent=2)
    with open(vtrxp_results_fn,'w') as vtrxp_results_file:
        json.dump(vtrxp_results,vtrxp_results_file,indent=2)

    logfile.close()
    os.system("rm out.txt")
