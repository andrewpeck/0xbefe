import sys, os, glob
import time
import argparse
import numpy as np
import json
import re
from gem.me0_lpgbt.rw_reg_lpgbt import *

# slot to OH mapping
geb_oh_map = {}
geb_oh_map["1"] = {}
geb_oh_map["1"]["OH"] = 0
geb_oh_map["1"]["GBT"] = [0, 1]
geb_oh_map["1"]["VFAT"] = [0, 1, 8, 9, 16, 17]
geb_oh_map["2"] = {}
geb_oh_map["2"]["OH"] = 0
geb_oh_map["2"]["GBT"] = [2, 3]
geb_oh_map["2"]["VFAT"] = [2, 3, 10, 11, 18, 19]
geb_oh_map["3"] = {}
geb_oh_map["3"]["OH"] = 0
geb_oh_map["3"]["GBT"] = [4, 5]
geb_oh_map["3"]["VFAT"] = [4, 5, 12, 13, 20, 21]
geb_oh_map["4"] = {}
geb_oh_map["4"]["OH"] = 0
geb_oh_map["4"]["GBT"] = [6, 7]
geb_oh_map["4"]["VFAT"] = [6, 7, 14, 15, 22, 23]
geb_oh_map["5"] = {}
geb_oh_map["5"]["OH"] = 1
geb_oh_map["5"]["GBT"] = [0, 1]
geb_oh_map["5"]["VFAT"] = [0, 1, 8, 9, 16, 17]
geb_oh_map["6"] = {}
geb_oh_map["6"]["OH"] = 1
geb_oh_map["6"]["GBT"] = [2, 3]
geb_oh_map["6"]["VFAT"] = [2, 3, 10, 11, 18, 19]
geb_oh_map["7"] = {}
geb_oh_map["7"]["OH"] = 1
geb_oh_map["7"]["GBT"] = [4, 5]
geb_oh_map["7"]["VFAT"] = [4, 5, 12, 13, 20, 21]
geb_oh_map["8"] = {}
geb_oh_map["8"]["OH"] = 1
geb_oh_map["8"]["GBT"] = [6, 7]
geb_oh_map["8"]["VFAT"] = [6, 7, 14, 15, 22, 23]

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OptoHybrid Production Tests")
    parser.add_argument("-i", "--input_file", action="store", dest="input_file", help="INPUT_FILE = input file containing OH serial numbers for slots")
    args = parser.parse_args()

    if args.input_file is None:
        print(Colors.YELLOW + "Need Input File" + Colors.ENDC)
        sys.exit()

    geb_dict = {}
    slot_name_dict = {}
    vtrx_dict = {}
    input_file = open(args.input_file)
    for line in input_file.readlines():
        if "#" in line:
            if "BATCH" in line:
                batch = line.split()[2]
                if batch not in ["prototype", "pre_production", "pre_series", "production", "long_production", "acceptance", "debug"]:
                    print(Colors.YELLOW + 'Valid test batch codes are "prototype", "pre_production", "pre_series", "production", "long_production" or "acceptance"' + Colors.ENDC)
                    sys.exit()
            continue
        slot = line.split()[0]
        oh_sn = line.split()[1]
        slot_name = line.split()[2]
        vtrx_sn = line.split()[3]
        if oh_sn != "-9999":
            if batch in ["prototype", "pre_production"]:
                if int(oh_sn) not in range(1,1001):
                    print(Colors.YELLOW + "Valid %s OH serial number between 1 and 1000"%batch.replace('_','-') + Colors.ENDC)
                    sys.exit()
            elif batch in ["pre_series", "production", "long_production", "acceptance"]:
                if int(oh_sn) not in range(1001, 2019):
                    print(Colors.YELLOW + "Valid %s OH serial number between 1001 and 2018"%batch.replace('_','-') + Colors.ENDC)
                    sys.exit()
            elif batch=="debug":
                if int(oh_sn) not in range(1, 2019):
                    print(Colors.YELLOW + "Valid %s OH serial number between 1001 and 2018"%batch.replace('_','-') + Colors.ENDC)
                    sys.exit()
            if int(slot) > 4:
                print(Colors.YELLOW + "Tests for more than 1 OH layer is not yet supported. Valid slots (1-4)" + Colors.ENDC)
                sys.exit()
            geb_dict[slot] = oh_sn
            slot_name_dict[slot] = slot_name
            vtrx_dict[slot] = vtrx_sn
    input_file.close()

    if len(geb_dict) == 0:
        print(Colors.YELLOW + "At least 1 slot needs to have valid OH serial number" + Colors.ENDC)
        sys.exit()
    print("")

    oh_sn_list = []
    for slot,oh_sn in geb_dict.items():
        oh_sn_list.append(oh_sn)
    
    oh_gbt_vfat_map = {}
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
    
    oh_ver_list = []
    for oh in oh_gbt_vfat_map:
        oh_ver_list += [get_oh_ver(oh,gbt) for gbt in oh_gbt_vfat_map[oh]["GBT"]]
    
    resultDir = "me0_lpgbt/oh_testing/results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass

    try:
        dataDir = resultDir + "/%s_tests"%batch
    except NameError:
        print(Colors.YELLOW + 'Must include test batch in input file as "# BATCH: <test_batch>"' + Colors.ENDC)
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

    log_fn = dataDir + "/oh_tests_log.txt"
    logfile = open(log_fn, "w")
    results_fn = dataDir + "/oh_tests_results.json"

    results_oh_sn = {}
    # log results for each asiago by serial #
    for slot,oh_sn in geb_dict.items():
        results_oh_sn[oh_sn]={}
        results_oh_sn[oh_sn]["Batch"]=batch
        results_oh_sn[oh_sn]["Slot"]=slot_name_dict[slot]
        results_oh_sn[oh_sn]["VTRx"]={}
        results_oh_sn[oh_sn]["VTRx"]["Serial_Number"]=vtrx_dict[slot]
        for gbt in geb_oh_map[slot]["GBT"]:
            results_oh_sn[oh_sn][gbt]={}
    
    debug = True if batch=="debug" else False 
    
    print ("\n#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 1 - run init_frontend
    print (Colors.BLUE + "Step 1: Initializing\n" + Colors.ENDC)
    logfile.write("Step 1: Initializing\n\n")
    logfile.close()

    os.system("python3 init_frontend.py")
    os.system("python3 status_frontend.py >> %s"%log_fn)
    os.system("python3 clean_log.py -i %s"%log_fn)
    list_of_files = glob.glob("results/gbt_data/gbt_status_data/*.json")
    latest_file = max(list_of_files, key=os.path.getctime)
    with open(latest_file,"r") as statusfile:
        status_dict = json.load(statusfile)
        for oh,status_dict_oh in status_dict.items():
            for gbt,status in status_dict_oh.items():
                for slot,oh_sn in geb_dict.items():
                    if geb_oh_map[slot]["OH"]==int(oh) and int(gbt) in geb_oh_map[slot]["GBT"]:
                        results_oh_sn[oh_sn][int(gbt)]["ready"]=int(status)
                        break 

    logfile = open(log_fn, "a")
    for slot,oh_sn in geb_dict.items():
        results_oh_sn[oh_sn]["Initialization"]=1
        for gbt in geb_oh_map[slot]["GBT"]:
            results_oh_sn[oh_sn]["Initialization"] &= results_oh_sn[oh_sn][gbt]["ready"]
    for slot,oh_sn in geb_dict.items():
        if not results_oh_sn[oh_sn]["Initialization"]:
            print(Colors.YELLOW + "\n Step 1: Initialization Failed" + Colors.ENDC)
            logfile.write("\n Step 1: Initialization Failed\n")
            # log results and exit
            with open(results_fn,"w") as resultsfile:
                json.dump(results_oh_sn,resultsfile,indent=2)
            logfile.close()
            sys.exit()

    print (Colors.GREEN + "\nStep 1: Initialization Complete\n" + Colors.ENDC)
    logfile.write("\nStep 1: Initialization Complete\n\n")

    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 2 - check lpGBT status
    print (Colors.BLUE + "Step 2: Checking lpGBT Registers\n" + Colors.ENDC)
    logfile.write("Step 2: Checking lpGBT Registers\n\n")

    for slot in geb_dict:
        oh_select = geb_oh_map[slot]["OH"]
        for gbt in geb_oh_map[slot]["GBT"]:
            os.system("python3 me0_lpgbt_status.py -s backend -q ME0 -o %d -g %d > out.txt"%(oh_select,gbt))
            # even gbt indexes are boss, odd are sub
            if gbt%2==0:
                # boss lpgbts
                list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_status_data/status_boss*.txt")
                latest_file = max(list_of_files, key=os.path.getctime)
                os.system("cp %s %s/status_boss_slot%s.txt"%(latest_file, dataDir, slot))
            elif (gbt+1)%2==0:
                # sub lpgbts
                list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_status_data/status_sub*.txt")
                latest_file = max(list_of_files, key=os.path.getctime)
                os.system("cp %s %s/status_sub_slot%s.txt"%(latest_file, dataDir, slot))

    config_files = []
    for oh_ver in oh_ver_list:
        config_files.append(open("../resources/me0_boss_config_ohv%d.txt"%oh_ver))
        config_files.append(open("../resources/me0_sub_config_ohv%d.txt"%oh_ver))
    status_files = []
    for slot in geb_dict:
        oh_select = geb_oh_map[slot]["OH"]
        for gbt in geb_oh_map[slot]["GBT"]:
            if gbt%2==0:
                # boss lpgbts
                status_files.append(open(dataDir+"/status_boss_slot%s.txt"%slot))
            else:
                # sub lpgbts
                status_files.append(open(dataDir+"/status_sub_slot%s.txt"%slot))
    status_registers = {}
    # Read all status registers from files
    for gbt,(status_file,config_file) in enumerate(zip(status_files,config_files)):
        slot = np.floor_divide(gbt,2) + 1
        status_registers[slot]={}
        if gbt%2 == 0: # boss lpgbts
            # Get status registers
            status_registers[slot]["BOSS"]={}
            for line in status_file.readlines():
                reg,value = int(line.split()[0],16),int(line.split()[1],16)
                status_registers[slot]["BOSS"][reg] = value
            # Check against config files
            print ("Checking Slot %d OH Boss lpGBT:"%slot) 
            logfile.write("Checking Slot %d OH Boss lpGBT:\n"%slot)
            n_error = 0
            for line in config_file.readlines():
                reg,value = int(line.split()[0],16),int(line.split()[1],16)
                if reg in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
                    continue
                if status_registers[slot]["BOSS"][reg] != value:
                    n_error += 1
                    print(Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(reg, value, status_registers[slot]["BOSS"][reg]) + Colors.ENDC)
                    logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(reg, value, status_registers[slot]["BOSS"][reg]))
                    try:
                        results_oh_sn[geb_dict[str(slot)]][gbt]["Bad_Registers"]+=[reg] # save bad registers as int array
                    except KeyError:
                        results_oh_sn[geb_dict[str(slot)]][gbt]["Bad_Registers"]=[]
                        results_oh_sn[geb_dict[str(slot)]][gbt]["Bad_Registers"]+=[reg]

        else: # sub lpgbts
            # Get status registers
            status_registers[slot]["SUB"]={}
            for line in status_file.readlines():
                reg,value = int(line.split()[0],16),int(line.split()[1],16)
                status_registers[slot]["SUB"][reg] = value
            # Check against config files
            print("Checking Slot %d OH Sub lpGBT:"%slot) 
            logfile.write("Checking Slot %d OH Sub lpGBT:\n"%slot)
            n_error = 0
            for line in config_file.readlines():
                reg,value = int(line.split()[0],16),int(line.split()[1],16)
                if reg in [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFC, 0xFD, 0xFE, 0xFF]:
                    continue
                if status_registers[slot]["SUB"][reg] != value:
                    n_error += 1
                    print(Colors.RED + "  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X"%(reg, value, status_registers[slot]["SUB"][reg]) + Colors.ENDC)
                    logfile.write("  Register mismatch for register 0x%03X, value in config: 0x%02X, value in lpGBT: 0x%02X\n"%(reg, value, status_registers[slot]["SUB"][reg]))
                    try:
                        results_oh_sn[geb_dict[str(slot)]][gbt]["Bad_Registers"]+=[reg] # save bad registers as int array
                    except KeyError:
                        results_oh_sn[geb_dict[str(slot)]][gbt]["Bad_Registers"]=[]
                        results_oh_sn[geb_dict[str(slot)]][gbt]["Bad_Registers"]+=[reg]
        if not n_error:
            print(Colors.GREEN + "  No register mismatches" + Colors.ENDC)
            logfile.write("  No register mismatches\n")
        results_oh_sn[geb_dict[str(slot)]][gbt]["Status"] = int(not n_error)

        status_file.close()
        config_file.close()
    
    for slot,oh_sn in geb_dict.items():
        for gbt in geb_oh_map[slot]["GBT"]:
            if not results_oh_sn[oh_sn][gbt]["Status"]:
                print(Colors.YELLOW + "\nStep 2: Checking lpGBT Status Failed\n" + Colors.ENDC)
                logfile.write("\nStep 2: Checking lpGBT Status Failed\n\n")
                with open(results_fn,"w") as resultsfile:
                    json.dump(results_oh_sn,resultsfile,indent=2)
                logfile.close()
                sys.exit()
            
    print(Colors.GREEN + "\nStep 2: Checking lpGBT Status Complete\n" + Colors.ENDC)
    logfile.write("\nStep 2: Checking lpGBT Status Complete\n\n")
    time.sleep(1)
    print("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
   
    # Step 3 - Downlink eye diagrams
    print(Colors.BLUE + "Step 3: Downlink Eye Diagram\n" + Colors.ENDC)
    logfile.write("Step 3: Downlink Eye Diagram\n\n")

    if batch in ["prototype", "pre_production", "pre_series"]:
        for slot,oh_sn in geb_dict.items():
            print (Colors.BLUE + "Running Eye diagram for Slot %s, Boss lpGBT"%slot + Colors.ENDC)
            logfile.write("Running Eye diagram for Slot %s, Boss lpGBT\n"%slot)
            os.system("python3 me0_eye_scan.py -s backend -q ME0 -o %d -g %d > out.txt"%(geb_oh_map[slot]["OH"],geb_oh_map[slot]["GBT"][0]))
            list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("python3 plotting_scripts/me0_eye_scan_plot.py -f %s -s > out.txt"%latest_file)
            list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*.pdf")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("cp %s %s/downlink_optical_eye_boss_slot%s.pdf"%(latest_file, dataDir, slot))
            list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_eye_scan_results/eye_data*out.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            eye_result_file=open(latest_file)
            result = eye_result_file.readlines()[0]
            eye_result_file.close()
            print(result)
            logfile.write(result+"\n")
            results_oh_sn[oh_sn]["Downlink_Eye_Diagram"] = float(result.split()[5])
        for oh_sn in results_oh_sn:
            if results_oh_sn[oh_sn]["Downlink_Eye_Diagram"] < 0.5:
                print (Colors.YELLOW + "Step 3: Downlink Eye Diagram Failed\n" + Colors.ENDC)
                logfile.write("Step 3: Downlink Eye Diagram Failed\n\n")
                with open(results_fn,"w") as resultsfile:
                    json.dump(results_oh_sn,resultsfile,indent=2)
                logfile.close()
                sys.exit()
    else:
        print(Colors.BLUE + "Skipping downlink eye diagram for %s tests"%batch.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping downlink eye diagram for %s tests\n"%batch.replace("_","-"))

    print (Colors.GREEN + "\nStep 3: Downlink Eye Diagram Complete\n" + Colors.ENDC)
    logfile.write("\nStep 3: Downlink Eye Diagram Complete\n\n")
    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 4 - Downlink Optical BERT
    print (Colors.BLUE + "Step 4: Downlink Optical BERT\n" + Colors.ENDC)
    logfile.write("Step 4: Downlink Optical BERT\n\n")

    if not debug:
        for slot,oh_sn in geb_dict.items():
            print (Colors.BLUE + "Running Downlink Optical BERT for Slot %s Boss lpGBT\n"%slot + Colors.ENDC)
            logfile.write("Running Downlink Optical BERT for Slot %s Boss lpGBT\n\n"%slot)
            if debug:
                os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %d -p downlink -r run -t 0.2 -z"%(geb_oh_map[slot]["OH"],geb_oh_map[slot]["GBT"][0]))
            else:
                os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %d -p downlink -r run -b 1e-12 -z"%(geb_oh_map[slot]["OH"],geb_oh_map[slot]["GBT"][0]))
            list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_optical_link_bert_fec_results/*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            read_next = False
            with open(latest_file,"r") as bertfile:
                # Just read the last 10 lines to save time. Know results are at the end.
                for line in bertfile.readlines():
                    if "BER Test Results" in line:
                        read_next = True
                    if read_next:
                        if "GBT" in line:
                            gbt = int(line.split()[-1])
                            results_oh_sn[oh_sn][gbt]["Downlink_BERT"] = {}
                        elif "Number of FEC errors" in line:
                            results_oh_sn[oh_sn][gbt]["Downlink_BERT"]["Errors"] = float(line.split()[-1])
                        elif "Bit Error Ratio" in line:
                            results_oh_sn[oh_sn][gbt]["Downlink_BERT"]["Limit"]=float(line.split()[-1])
            read_next = False
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")

        for slot,oh_sn in geb_dict.items():
            for gbt in geb_oh_map[slot]["GBT"]:
                if not debug and results_oh_sn[oh_sn]["Downlink_BERT"]["Limit"] > 1e-12:
                    print (Colors.YELLOW + "\nStep 4: Downlink Optical BERT Failed\n" + Colors.ENDC)
                    logfile.write("\nStep 4: Downlink Optical BERT Failed\n\n")
                    with open(results_fn,"w") as resultsfile:
                        json.dump(results_oh_sn,resultsfile,indent=2)
                    logfile.close()
                    sys.exit()
    else:
        print(Colors.BLUE + "Skipping Downlink Optical BERT for %s tests"%batch.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping Downlink Optical BERT for %s tests\n"%batch.replace("_","-"))

    print (Colors.GREEN + "\nStep 4: Downlink Optical BERT Complete\n" + Colors.ENDC)
    logfile.write("\nStep 4: Downlink Optical BERT Complete\n\n")
    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 5 - Uplink Optical BERT
    print (Colors.BLUE + "Step 5: Uplink Optical BERT\n" + Colors.ENDC)
    logfile.write("Step 5: Uplink Optical BERT\n\n")

    if not debug:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            print(Colors.BLUE + "Running Uplink Optical BERT for OH %d, Boss and Sub lpGBTs\n"%oh_select + Colors.ENDC)
            logfile.write("Running Uplink Optical BERT for OH %d, Boss and Sub lpGBTs\n\n"%oh_select)
            if debug:
                os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p uplink -r run -t 0.2 -z"%(oh_select," ".join(map(str,gbt_vfat_dict["GBT"]))))
            else:
                os.system("python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o %d -g %s -p uplink -r run -b 1e-12 -z"%(oh_select," ".join(map(str,gbt_vfat_dict["GBT"]))))
            list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_optical_link_bert_fec_results/*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            read_next = False
            with open(latest_file,"r") as bertfile:
                # Just read the last 10 lines to save time. Know results are at the end.
                for line in bertfile.readlines():
                    if "BER Test Results" in line:
                        read_next = True
                    if read_next:
                        if "GBT" in line:
                            gbt = int(line.split()[-1])
                            for slot,oh_sn in geb_dict.items():
                                if gbt in geb_oh_map[slot]["GBT"]:
                                    results_oh_sn[oh_sn][gbt]["Uplink_BERT"] = {}
                                    break
                        elif "Number of FEC errors" in line:
                            results_oh_sn[oh_sn][gbt]["Uplink_BERT"]["Errors"] = float(line.split()[-1])
                        elif "Bit Error Ratio" in line:
                            results_oh_sn[oh_sn][gbt]["Uplink_BERT"]["Limit"]=float(line.split()[-1])
            read_next = False
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")
        for slot,oh_sn in geb_dict.items():
            for gbt in geb_oh_map[slot]["GBT"]:
                if not debug and results_oh_sn[oh_sn][gbt]["Uplink_BERT"]["Limit"] > 1e-12:
                    print (Colors.YELLOW + "\nStep 5: Uplink Optical BERT Failed\n" + Colors.ENDC)
                    logfile.write("\nStep 5: Uplink Optical BERT Failed\n\n")
                    with open(results_fn,"w") as resultsfile:
                        json.dump(results_oh_sn,resultsfile,indent=2)
                    logfile.close()
                    sys.exit()
    else:
        print(Colors.BLUE + "Skipping Uplink Optical BERT for %s tests"%batch.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping Uplink Optical BERT for %s tests\n"%batch.replace("_","-"))

    print (Colors.GREEN + "\nStep 5: Uplink Optical BERT Complete\n" + Colors.ENDC)
    logfile.write("\nStep 5: Uplink Optical BERT Complete\n\n")
    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 6 - DAQ Phase Scan
    print (Colors.BLUE + "Step 6: DAQ Phase Scan\n" + Colors.ENDC)
    logfile.write("Step 6: DAQ Phase Scan\n\n")

    if not debug:
        for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Running DAQ Phase Scan for OH %d on all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running DAQ Phase Scan for OH %d on all VFATs\n\n"%oh_select)
            os.system("python3 me0_phase_scan.py -s backend -q ME0 -o %d -v %s -c"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            list_of_files = glob.glob("results/vfat_data/vfat_phase_scan_results/*_data_*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("python3 clean_log.py -i %s"%latest_file) # Clean output file for parsing

            read_next = False
            with open(latest_file,"r") as ps_file:
                for line in ps_file.readlines():
                    if "Phase Scan Results" in line:
                        read_next = True
                    elif read_next:
                        vfat = int(line.split()[0].replace("VFAT","").replace(":",""))
                        phase = int(line.split()[2].replace('(center=','').replace(',',''))
                        width = int(line.split()[3].replace('width=','').replace(')',''))
                        status =  1 if line.split()[4] == "GOOD" else 0
                        for slot,oh_sn in geb_dict.items():
                            if vfat in geb_oh_map[slot]["VFAT"]:
                                if "DAQ_Phase_Scan" in results_oh_sn[oh_sn]:
                                    results_oh_sn[oh_sn]["DAQ_Phase_Scan"].append({'Status':status,'Phase':phase,'Width':width})
                                else:
                                    results_oh_sn[oh_sn]["DAQ_Phase_Scan"]=[{'Status':status,'Phase':phase,'Width':width}]
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")

        for oh_sn in results_oh_sn:
            for result in results_oh_sn[oh_sn]['DAQ_Phase_Scan']:
                if not result['Status']:
                    print (Colors.YELLOW + "\nStep 6: DAQ Phase Scan Failed\n" + Colors.ENDC)
                    logfile.write("\nStep 6: DAQ Phase Scan Failed\n\n")
                    with open(results_fn,"w") as resultsfile:
                        json.dump(results_oh_sn,resultsfile,indent=2)
                    logfile.close()
                    sys.exit()
    else:
        print(Colors.BLUE + "Skipping DAQ Phase Scan for %s tests"%batch.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping DAQ Phase Scan for %s tests\n"%batch.replace("_","-"))

    print (Colors.GREEN + "\nStep 6: DAQ Phase Scan Complete\n" + Colors.ENDC)
    logfile.write("\nStep 6: DAQ Phase Scan Complete\n\n")
    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 7 - S-bit Phase Scan, Bitslipping, Mapping, Cluster Mapping
    print (Colors.BLUE + "Step 7: S-bit Phase Scan, Bitslipping,  Mapping, Cluster Mapping\n" + Colors.ENDC)
    logfile.write("Step 7: S-bit Phase Scan, Bitslipping, Mapping, Cluster Mapping\n\n")

    if not debug:
        for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Running S-bit Phase Scan on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running S-bit Phase Scan on OH %d all VFATs\n\n"%oh_select)
            os.system("python3 me0_vfat_sbit_phase_scan.py -s backend -q ME0 -o %d -v %s -l -a"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            list_of_files = glob.glob("results/vfat_data/vfat_sbit_phase_scan_results/*_data_*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("python3 clean_log.py -i %s"%latest_file)

            read_next = False
            with open(latest_file,"r") as ps_file:
                # parse sbit phase scan results
                for line in ps_file.readlines():
                    if 'Phase Scan Results' in line:
                        read_next = True
                    elif read_next:
                        if 'VFAT' in line:
                            vfat = int(line.split()[1])
                        elif 'ELINK' in line:
                            elink = int(line.split()[1].replace(':',''))
                            phase = int(line.split()[3].replace('(center=','').replace(',',''))
                            width = int(line.split()[4].replace('width=','').replace(')',''))
                            status = 1 if line.split()[5] == "GOOD" else 0

                            for slot,oh_sn in geb_dict.items():
                                if vfat in geb_oh_map[slot]["VFAT"]:
                                    i = geb_oh_map[slot]["VFAT"].index(vfat)
                                    break
                            if 'SBIT_Phase_Scan' in results_oh_sn[oh_sn]:
                                results_oh_sn[oh_sn]['SBIT_Phase_Scan'][i]+=[{'Status':status,'Phase':phase,'Width':width}]
                            else:
                                results_oh_sn[oh_sn]['SBIT_Phase_Scan']=[[]]*6
                                results_oh_sn[oh_sn]['SBIT_Phase_Scan'][i]+=[{'Status':status,'Phase':phase,'Width':width}]
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")
        for oh_sn in results_oh_sn:
            for vfat_results in results_oh_sn[oh_sn]["SBIT_Phase_Scan"]:
                for result in vfat_results:
                    if not result['Status']:
                        print (Colors.YELLOW + "\nStep 7: S-Bit Phase Scan Failed\n" + Colors.ENDC)
                        logfile.write("\nStep 7: S-Bit Phase Scan Failed\n\n")
                        with open(results_fn,"w") as resultsfile:
                            json.dump(results_oh_sn,resultsfile,indent=2)
                        logfile.close()
                        sys.exit()
        time.sleep(1)
    else:
        print(Colors.BLUE + "Skipping S-Bit Phase Scan for %s tests"%batch.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping S-Bit Phase Scan for %s tests\n"%batch.replace("_","-"))

    if not debug:
        for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "\n\nRunning S-bit Bitslipping on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("\n\nRunning S-bit Bitslipping on OH %d, all VFATs\n\n"%oh_select)
            os.system("python3 me0_vfat_sbit_bitslip.py -s backend -q ME0 -o %d -v %s -l"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            list_of_files = glob.glob("results/vfat_data/vfat_sbit_bitslip_results/*_data_*.txt")
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
                            status = 1 if bitslip!=-9999 else 0
                            if 'SBIT_Bitslip' in results_oh_sn[oh_sn]:
                                if results_oh_sn[oh_sn]['SBIT_Bitslip'][i] == {}:
                                    results_oh_sn[oh_sn]['SBIT_Bitslip'][i]={'Status':status,'Bitslips':[bitslip]}
                                else:
                                    results_oh_sn[oh_sn]['SBIT_Bitslip'][i]['Status']&=status
                                    results_oh_sn[oh_sn]['SBIT_Bitslip'][i]['Bitslips']+=[bitslip]
                            else:
                                results_oh_sn[oh_sn]['SBIT_Bitslip'] = [{}]*6
                                results_oh_sn[oh_sn]['SBIT_Bitslip'][i]={'Status':status,'Bitslips':[bitslip]}
                    elif "Bad Elinks:" in line:
                        read_next = False # rule out "VFAT" and "ELINK" appearing at the end in bad elinks
                        continue
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")

        for oh_sn in results_oh_sn:
            for result in results_oh_sn[oh_sn]["SBIT_Bitslip"]:
                if not result['Status']:
                    print (Colors.YELLOW + "\nStep 7: S-Bit Bitslip Failed\n" + Colors.ENDC)
                    logfile.write("\nStep 7: S-Bit Bitslip Failed\n\n")
                    with open(results_fn,"w") as resultsfile:
                        json.dump(results_oh_sn,resultsfile,indent=2)
                    logfile.close()
                    sys.exit()
        time.sleep(1)
    else:
        print(Colors.BLUE + "Skipping S-Bit Bitslip for %s tests"%batch.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping S-Bit Bitslip for %s tests\n"%batch.replace("_","-"))
    

    if not debug:
        for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "\n\nRunning S-bit Mapping on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("\n\nRunning S-bit Mapping on OH %d, all VFATs\n\n"%oh_select)
            os.system("python3 me0_vfat_sbit_mapping.py -s backend -q ME0 -o %d -v %s -l"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            list_of_files = glob.glob("results/vfat_data/vfat_sbit_mapping_results/*_data_*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("python3 clean_log.py -i %s"%latest_file) # Clean output file for logging
            logfile.close()
            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")
        time.sleep(1)
    else:
        print(Colors.BLUE + "Skipping S-Bit Mapping for %s tests"%batch.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping S-Bit Mapping for %s tests\n"%batch.replace("_","-"))

    if not debug:
        for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Running S-bit Cluster Mapping on OH %d, all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running S-bit Cluster Mapping on OH %d, all VFATs\n\n"%oh_select)
            logfile.close()
            os.system("python3 vfat_sbit_monitor_clustermap.py -s backend -q ME0 -o %d -v %s -l -f >> %s"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])),log_fn))
            list_of_files = glob.glob("results/vfat_data/vfat_sbit_monitor_cluster_mapping_results/*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)

            with open(latest_file,"r") as mapping_file:
                for line in mapping_file.readlines()[2:]:
                    data = line.split()
                    data = data[:3] + data[3].split(',') + data[4].split(',')
                    data.remove('')
                    vfat = int(data[0])
                    channel = int(data[1])
                    sbit = int(data[2])
                    cluster_counts = [int(x) for x in data[3:10]]
                    cluster_size = int(data[10])
                    cluster_address = int(data[11])

                    sbit_status = 1 if sbit != -9999 else 0
                    cluster_status = 1 if cluster_address != -9999 else 0
                    
                    for slot,oh_sn in geb_dict.items():
                        if vfat in geb_oh_map[slot]['VFAT']:
                            i = geb_oh_map[slot]['VFAT'].index(vfat)
                            break
                    if 'SBIT_Mapping' in results_oh_sn[oh_sn]:
                        if results_oh_sn[oh_sn]['SBIT_Mapping'][i] != {}:
                            results_oh_sn[oh_sn]['SBIT_Mapping'][i]["SBIT_Status"] &= sbit_status
                            results_oh_sn[oh_sn]['SBIT_Mapping'][i]["SBIT_Address"] += [sbit]
                            results_oh_sn[oh_sn]['SBIT_Mapping'][i]["Cluster_Status"] &= cluster_status
                            results_oh_sn[oh_sn]['SBIT_Mapping'][i]["Cluster_Address"] += [cluster_address]
                        else:
                            results_oh_sn[oh_sn]['SBIT_Mapping'][i].update({'SBIT_Status':sbit_status,'SBIT_Address':[sbit],'Cluster_Status':cluster_status,'Cluster_Address':[cluster_address]})
                    else:
                        results_oh_sn[oh_sn]['SBIT_Mapping']=[{}]*6
                        results_oh_sn[oh_sn]['SBIT_Mapping'][i].update({'SBIT_Status':sbit_status,'SBIT_Address':[sbit],'Cluster_Status':cluster_status,'Cluster_Address':[cluster_address]})

            os.system("cp %s %s/vfat_clustermap.txt"%(latest_file, dataDir))
            logfile = open(log_fn, "a")

        for oh_sn in results_oh_sn:
            for result in results_oh_sn[oh_sn]["SBIT_Mapping"]:
                if not result['SBIT_Status']:
                    print (Colors.YELLOW + "\nStep 7: S-Bit Mapping Failed\n" + Colors.ENDC)
                    logfile.write("\nStep 7: S-Bit Mapping Failed\n\n")
                    with open(results_fn,"w") as resultsfile:
                        json.dump(results_oh_sn,resultsfile,indent=2)
                    logfile.close()
                    sys.exit()
                elif not result['Cluster_Status']:
                    pass
                    # print (Colors.YELLOW + "\nStep 7: S-Bit Cluster Mapping Failed\n" + Colors.ENDC)
                    # logfile.write("\nStep 7: S-Bit Cluster Mapping Failed\n\n")
                    # with open(results_fn,"w") as resultsfile:
                    #     json.dump(results_oh_sn,resultsfile,indent=2)
                    # logfile.close()
                    # sys.exit()
        time.sleep(1)
    else:
        print(Colors.BLUE + "Skipping S-Bit Cluster Mapping for %s tests"%batch.replace("_","-") + Colors.ENDC)
        logfile.write("Skipping S-Bit Cluster Mapping for %s tests\n"%batch.replace("_","-"))

    print (Colors.GREEN + "\nStep 7: S-bit Phase Scan, Bitslipping, Mapping, Cluster Mapping Complete\n" + Colors.ENDC)
    logfile.write("\nStep 7: S-bit Phase Scan, Bitslipping, Mapping, Cluster Mapping Complete\n\n")
    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")


    # Step 8 - VFAT Reset
    print (Colors.BLUE + "Step 8: VFAT Reset\n" + Colors.ENDC)
    logfile.write("Step 8: VFAT Reset\n\n")

    if debug:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Configuring all VFATs for OH %d\n"%oh_select + Colors.ENDC)
            logfile.write("Configuring all VFATs for OH %d\n\n"%oh_select)
            for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
                os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v %s -c 1"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            time.sleep(1)
            
            print (Colors.BLUE + "Resetting all VFATs for OH %d\n"%oh_select + Colors.ENDC)
            logfile.write("Resetting all VFATs for OH %d\n\n"%oh_select)
            logfile.close()
            os.system("python3 me0_vfat_reset.py -s backend -q ME0 -o %d -v %s >> %s"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])),log_fn))
            os.system("python3 clean_log.py -i %s"%log_fn)
            read_next = False
            with open(log_fn,"r") as logfile:
                for line in logfile.readlines():
                    if 'VFAT Reset Results' in line:
                        read_next = True
                    elif read_next:
                        if line=='\n':
                            read_next = False
                            continue
                        vfat = int(line.split()[1].replace(':',''))
                        for slot,oh_sn in geb_dict.items():
                            if vfat in geb_oh_map[slot]['VFAT']:
                                break
                        status_str = line.split(':')[1]
                        if "VFAT RESET from RUN mode to SLEEP mode" in status_str:
                            if 'VFAT_Reset' in results_oh_sn[oh_sn]:
                                results_oh_sn[oh_sn]['VFAT_Reset'] += [1]
                            else:
                                results_oh_sn[oh_sn]['VFAT_Reset'] = [1]
                        else:
                            if 'VFAT_Reset' in results_oh_sn[oh_sn]:
                                results_oh_sn[oh_sn]['VFAT_Reset'] += [0]
                            else:
                                results_oh_sn[oh_sn]['VFAT_Reset'] = [0]

        logfile = open(log_fn,"a")    
        print (Colors.BLUE + "Unconfiguring all VFATs\n" + Colors.ENDC)
        logfile.write("Unconfiguring all VFATs\n\n")
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v %s -c 0"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
        
        for oh_sn in results_oh_sn:
            if np.any(results_oh_sn[oh_sn]['VFAT_Reset']==0):
                print (Colors.YELLOW + "\nStep 8: VFAT Reset Failed\n" + Colors.ENDC)
                logfile.write("\nStep 8: VFAT Reset Failed\n\n")
                with open(results_fn,"w") as resultsfile:
                    json.dump(results_oh_sn,resultsfile,indent=2)
                logfile.close()
                sys.exit()

    if debug:
        # Exit sequence
        with open(results_fn,"w") as resultsfile:
            json.dump(results_oh_sn,resultsfile,indent=2)
        logfile.close()
        sys.exit()

    print (Colors.GREEN + "\nStep 8: VFAT Reset Complete\n" + Colors.ENDC)
    logfile.write("\nStep 8: VFAT Reset Complete\n\n")
    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 9 - Slow Control Error Rate Test
    print (Colors.BLUE + "Step 9: Slow Control Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 9: Slow Control Error Rate Test\n\n")

    for oh_select, gbt_vfat_dict in oh_gbt_vfat_map.items():
        if batch in ["prototype", "pre_production", "pre_series"]:
            os.system("python3 vfat_slow_control_test.py -s backend -q ME0 -o %d -v %s -r TEST_REG -t 30"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
        else:
            os.system("python3 vfat_slow_control_test.py -s backend -q ME0 -o %d -v %s -r TEST_REG -t 10"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
        list_of_files = glob.glob("results/vfat_data/vfat_slow_control_test_results/*.txt")
        latest_file = max(list_of_files, key=os.path.getctime)
        with open(latest_file,"r") as slow_control_results_file:
            read_next = False
            for line in slow_control_results_file.readlines():
                if "Error test results" in line:
                    read_next = True
                if read_next:
                    logfile.write(line)
                    if "link is" in line:
                        vfat = int(line.split()[1].replace(',',''))
                        status = 1 if line.split()[-1]=="GOOD" else 0
                        for slot,oh_sn in geb_dict.items():
                            if vfat in geb_oh_map[slot]["VFAT"]:
                                try:
                                    results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]={}
                                    results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["link"]=status
                                except KeyError:
                                    results_oh_sn[oh_sn]["Slow_Control_Errors"]={}
                                    results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]={}
                                    results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["link"]=status
                                finally:
                                    break
                    elif "sync errors" in line:
                        sync_errors = int(line.split()[-1])
                        results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["Sync_Errors"]=sync_errors
                    elif "bus errors" in line:
                        bus_errors = int(line.split()[6].replace(',',''))
                        bus_er = float(line.split()[-1])
                        results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["Bus_Errors"]=bus_errors
                        results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["Bus_ER"]=bus_er
                    elif "register mismatch" in line:
                        mm_errors = int(line.split()[7].replace(',',''))
                        mm_er = float(line.split()[-1])
                        results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["Mismatch_Errors"]=mm_errors
                        results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["Mismatch_ER"]=mm_er
                    elif "CRC" in line:
                        crc_errors = int(round(float(line.split()[10].replace(',',''))))
                        uplink_ber = float(line.split()[-1])
                        results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["CRC_Errors"]=crc_errors
                        results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["Uplink_BER"]=uplink_ber
                    elif "Timeout" in line:
                        to_errors = int(round(float(line.split()[10].replace(',',''))))
                        downlink_ber = float(line.split()[-1])
                        results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["Timeout_Errors"]=to_errors
                        results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["Downlink_BER"]=downlink_ber

    for slot,oh_sn in geb_dict.items():
        results_oh_sn[oh_sn]["Slow_Control_Errors"]["Total_Errors"]=0
        for vfat in geb_oh_map[slot]["VFAT"]:
            results_oh_sn[oh_sn]["Slow_Control_Errors"]["Total_Errors"] += results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["Sync_Errors"]
            results_oh_sn[oh_sn]["Slow_Control_Errors"]["Total_Errors"] += results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["Bus_Errors"]
            results_oh_sn[oh_sn]["Slow_Control_Errors"]["Total_Errors"] += results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["Mismatch_Errors"]
            results_oh_sn[oh_sn]["Slow_Control_Errors"]["Total_Errors"] += results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["CRC_Errors"]
            results_oh_sn[oh_sn]["Slow_Control_Errors"]["Total_Errors"] += results_oh_sn[oh_sn]["Slow_Control_Errors"][vfat]["Timeout_Errors"]
    for oh_sn in results_oh_sn:
        if results_oh_sn[oh_sn]["Slow_Control_Errors"]["Total_Errors"]:
            print (Colors.YELLOW + "\nStep 9: Slow Control Error Rate Test Failed\n" + Colors.ENDC)
            logfile.write("\nStep 9: Slow Control Error Rate Test Failed\n\n")
            with open(results_fn,"w") as resultsfile:
                json.dump(results_oh_sn,resultsfile,indent=2)
            logfile.close()
            sys.exit()

    print (Colors.GREEN + "\nStep 9: Slow Control Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 9: Slow Control Error Rate Test Complete\n\n")
    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 10 - DAQ Error Rate Test
    print (Colors.BLUE + "Step 10: DAQ Error Rate Test\n" + Colors.ENDC)
    logfile.write("Step 10: DAQ Error Rate Test\n\n")
    
    for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
        if batch in ["prototype", "pre_production", "pre_series"]:
            os.system("python3 vfat_daq_test.py -s backend -q ME0 -o %d -v %s -t 30"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
        else:
            os.system("python3 vfat_daq_test.py -s backend -q ME0 -o %d -v %s -t 10"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
        list_of_files = glob.glob("results/vfat_data/vfat_daq_test_results/*.txt")
        latest_file = max(list_of_files, key=os.path.getctime)
        with open(latest_file) as daq_results_file:
            read_next = False
            for line in daq_results_file.readlines():
                if "Error test results" in line:
                    read_next = True
                if read_next:
                    logfile.write(line)
                    if "link is" in line:
                        vfat = int(line.split()[1].replace(',',''))
                        status = 1 if line.split()[-1]=="GOOD" else 0
                        for slot,oh_sn in geb_dict.items():
                            if vfat in geb_oh_map[slot]["VFAT"]:
                                try:
                                    results_oh_sn[oh_sn]["DAQ_Errors"][vfat]={}
                                    results_oh_sn[oh_sn]["DAQ_Errors"][vfat]["link"]=status
                                except KeyError:
                                    results_oh_sn[oh_sn]["DAQ_Errors"]={}
                                    results_oh_sn[oh_sn]["DAQ_Errors"][vfat]={}
                                    results_oh_sn[oh_sn]["DAQ_Errors"][vfat]["link"]=status
                                finally:
                                    break
                    elif "sync errors" in line:
                        sync_errors = int(line.split()[-1])
                        results_oh_sn[oh_sn]["DAQ_Errors"][vfat]["Sync_Errors"]=sync_errors
                    elif "DAQ Events" in line:
                        events = float(line.split()[2].replace(',',''))
                        crc_errors = int(line.split()[-1])
                        results_oh_sn[oh_sn]["DAQ_Errors"][vfat]["Events"]=events
                        results_oh_sn[oh_sn]["DAQ_Errors"][vfat]["CRC_Errors"]=crc_errors
                    elif "Bit Error Ratio" in line:
                        errors = int(line.split()[4].replace(',',''))
                        ber = float(line.split()[10].replace(',',''))
                        results_oh_sn[oh_sn]["DAQ_Errors"][vfat]["Errors"]=errors
                        results_oh_sn[oh_sn]["DAQ_Errors"][vfat]["BER"]=ber
    
    for slot,oh_sn in geb_dict.items():
        results_oh_sn[oh_sn]["DAQ_Errors"]["Total_Errors"]=0
        for vfat in geb_oh_map[slot]["VFAT"]:
            results_oh_sn[oh_sn]["DAQ_Errors"]["Total_Errors"] += results_oh_sn[oh_sn]["DAQ_Errors"][vfat]["Errors"]
    for oh_sn in results_oh_sn:
        if results_oh_sn[oh_sn]["DAQ_Errors"]["Total_Errors"]:
            print (Colors.YELLOW + "\nStep 10: DAQ Error Rate Test Failed\n" + Colors.ENDC)
            logfile.write("\nStep 10: DAQ Error Rate Test Failed\n\n")
            with open(results_fn,"w") as resultsfile:
                json.dump(results_oh_sn,resultsfile,indent=2)
            logfile.close()
            sys.exit()
    print (Colors.GREEN + "\nStep 10: DAQ Error Rate Test Complete\n" + Colors.ENDC)
    logfile.write("\nStep 10: DAQ Error Rate Test Complete\n\n")
    time.sleep(1)
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 11 - ADC Measurements
    print (Colors.BLUE + "Step 11: ADC Measurements\n" + Colors.ENDC)
    logfile.write("Step 11: ADC Measurements\n\n")
    
    for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
        print (Colors.BLUE + "Configuring all VFATs\n" + Colors.ENDC)
        logfile.write("Configuring all VFATs\n\n")
        logfile.close()
        os.system("python3 vfat_config.py -s backend -q ME0 -o %d -v %s -c 1 >> %s"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"])),log_fn))
        logfile = open(log_fn, "a")
    time.sleep(1)

    for slot,oh_sn in geb_dict.items():
        oh_select = geb_oh_map[slot]["OH"]
        for gbt in geb_oh_map[slot]["GBT"]:
            print (Colors.BLUE + "\nRunning ADC Calibration Scan for gbt %d\n"%gbt + Colors.ENDC)
            logfile.write("Running ADC Calibration Scan for gbt %d\n\n"%gbt)
            logfile.close()
            os.system("python3 me0_lpgbt_adc_calibration_scan.py -s backend -q ME0 -o %d -g %d >> %s"%(oh_select,gbt,log_fn))
            logfile = open(log_fn,"a")
            list_of_files = glob.glob("results/me0_lpgbt_data/adc_calibration_data/*GBT%d*results*.txt"%gbt)
            latest_file = max(list_of_files,key=os.path.getctime)
            os.system("cp %s %s/adc_calib_results_slot%s_gbt%d.txt"%(latest_file,dataDir,slot,gbt))
            with open(latest_file) as adc_calib_file:
                try:
                    results_oh_sn[oh_sn][gbt]["ADC_Calibration"] = [float(p) for p in adc_calib_file.read().split()]
                except:
                    print(adc_calib_file.read().split())
                    sys.exit()
            list_of_files = glob.glob("results/me0_lpgbt_data/adc_calibration_data/*GBT%d*.pdf"%gbt)
            if len(list_of_files)>0:
                latest_file = max(list_of_files, key=os.path.getctime)
                if gbt%2==0:
                    os.system("cp %s %s/adc_calib_slot%s_boss.pdf"%(latest_file, dataDir, slot))
                else:
                    os.system("cp %s %s/adc_calib_slot%s_boss.pdf"%(latest_file, dataDir, slot))
    time.sleep(1)

    for slot,oh_sn in geb_dict.items():
        oh_select = geb_oh_map[slot]["OH"]
        results_oh_sn[oh_sn]["Voltage_Scan"]={}
        voltages={}
        for gbt in geb_oh_map[slot]["GBT"]:
            print (Colors.BLUE + "\nRunning lpGBT Voltage Scan for gbt %d\n"%gbt + Colors.ENDC)
            logfile.write("Running lpGBT Voltage Scan for gbt %d\n\n"%gbt)
            logfile.close()
            os.system("python3 me0_voltage_monitor.py -s backend -q ME0 -o %d -g %d -n 10 >> %s"%(oh_select,gbt,log_fn))
            os.system("python3 clean_log.py -i %s"%log_fn)
            logfile = open(log_fn,"a")
            list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_voltage_data/*GBT%d*.txt"%gbt)
            latest_file = max(list_of_files,key=os.path.getctime)
            os.system("cp %s %s/lpgbt_voltage_scan_slot%s_gbt%d"%(latest_file,dataDir,slot,gbt))
            with open(latest_file) as voltage_scan_file:
                line = voltage_scan_file.readline()
                for i in [2,4,8,12,16,20,24]:
                    key = line.split()[i]
                    if key not in voltages:
                        voltages[key]=[]
                for line in voltage_scan_file.readlines():
                    for key,val in zip(voltages,line.split()[1:]):
                        if float(val)!=-9999:
                            voltages[key]+=[float(val)]
            list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_voltage_data/*GBT%d*.pdf"%gbt)
            if len(list_of_files)>0:
                latest_file = max(list_of_files, key=os.path.getctime)
                if gbt%2==0:
                    os.system("cp %s %s/voltage_slot%s_boss.pdf"%(latest_file, dataDir, slot))
                else:
                    os.system("cp %s %s/voltage_slot%s_sub.pdf"%(latest_file, dataDir, slot))
        for key,values in voltages.items():
            results_oh_sn[oh_sn]["Voltage_Scan"][key]=np.mean(values)
    time.sleep(1)


    for slot,oh_sn in geb_dict.items():
        print (Colors.BLUE + "\nRunning RSSI Scan for slot %s\n"%slot + Colors.ENDC)
        logfile.write("Running RSSI Scan for slot %s\n\n"%slot)
        oh_select = geb_oh_map[slot]["OH"]
        gbt = geb_oh_map[slot]["GBT"][-1]
        os.system("python3 me0_rssi_monitor.py -s backend -q ME0 -o %d -g %d -v 2.56 -n 10 >> %s"%(oh_select,gbt,log_fn))
        list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_vtrx+_rssi_data/*GBT%d*.txt"%gbt)
        latest_file = max(list_of_files, key=os.path.getctime)
        os.system('cp %s %s/rssi_scan_slot%s'%(latest_file,dataDir,slot))
        with open(latest_file) as rssi_file:
            key = rssi_file.readline().split()[2]
            rssi=[]
            for line in rssi_file.readlines():
                rssi += [float(line.split()[1])]
        list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_vtrx+_rssi_data/*GBT%d*.pdf"%gbt)
        if len(list_of_files)>0:
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("cp %s %s/rssi_slot%s.pdf"%(latest_file, dataDir, slot))
        results_oh_sn[oh_sn]["VTRx"][key]=np.mean(rssi)
    time.sleep(1)

    for slot,oh_sn in geb_dict.items():
        print (Colors.BLUE + "\nRunning GEB Current and Temperature Scan for slot %s\n"%slot + Colors.ENDC)
        logfile.write("Running GEB Current and Temperature Scan for slot %s\n\n"%slot)
        oh_select = geb_oh_map[slot]["OH"]
        gbt = geb_oh_map[slot]["GBT"][0]
        os.system("python3 me0_asense_monitor.py -s backend -q ME0 -o %d -g %d -n 10 >> %s"%(oh_select,gbt,log_fn))
        list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_asense_data/*GBT%d*.txt"%gbt)
        latest_file = max(list_of_files,key=os.path.getctime)
        os.system('cp %s %s/geb_current_slot%s'%(latest_file,dataDir,slot))
        results_oh_sn[oh_sn]["Asense"]={}
        with open(latest_file) as asense_file:
            line = asense_file.readline().split()
            asense = {}
            asense["_".join(line[3:5]).replace('(','').replace(')','').replace('.','_')]=[]
            asense["_".join(line[7:9]).replace('(','').replace(')','')]=[]
            asense["_".join(line[11:13]).replace('(','').replace(')','').replace('.','_')]=[]
            asense["_".join(line[15:16]).replace('(','').replace(')','')]=[]
            for line in asense_file.readlines():
                for key,value in zip(asense,line.split()[1:]):
                    asense[key]+=[float(value)]
        for key,values in asense.items():
            results_oh_sn[oh_sn]["Asense"][key]=np.mean(values)

        list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_asense_data/*GBT%d_pg_current*.pdf"%gbt)
        if len(list_of_files)>0:
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("cp %s %s/pg_current_slot%s.pdf"%(latest_file, dataDir,slot))
        list_of_files = glob.glob("results/me0_lpgbt_data/lpgbt_asense_data/*GBT%d_rt_voltage*.pdf"%gbt)
        if len(list_of_files)>0:
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("cp %s %s/rt_voltage_slot%s.pdf"%(latest_file, dataDir,slot))
    time.sleep(1)


    for slot,oh_sn in geb_dict.items():
        print (Colors.BLUE + "\nRunning OH Temperature Scan on slot %s\n"%slot + Colors.ENDC)
        logfile.write("Running OH Temperature Scan on slot %s\n\n"%slot)
        oh_select = geb_oh_map[slot]["OH"]
        gbt = geb_oh_map[slot]["GBT"][-1]
        os.system("python3 me0_temp_monitor.py -s backend -q ME0 -o %d -g %d -t OH -n 10 >> %s"%(oh_select,gbt,log_fn))
        list_of_files = glob.glob("results/me0_lpgbt_data/temp_monitor_data/*GBT%d*.txt"%gbt)
        latest_file = max(list_of_files,key=os.path.getctime)
        os.system('cp %s %s/oh_temperature_scan_slot%s'%(latest_file,dataDir,slot))
        results_oh_sn[oh_sn]["OH_Temperature_Scan"]={}
        with open(latest_file) as temp_file:
            keys = temp_file.readline().split()[2:7:2]
            temperatures = {}
            for key in keys:
                temperatures[key]=[]
            for line in temp_file.readlines():
                for key,value in zip(temperatures,line.split()[1:]):
                    temperatures[key]+=[float(value)]
        list_of_files = glob.glob("results/me0_lpgbt_data/temp_monitor_data/*GBT%d_temp_OH*.pdf"%gbt)
        if len(list_of_files)>0:
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("cp %s %s/oh_temp_slot%s.pdf"%(latest_file, dataDir,slot))
        for key,values in temperatures.items():
            results_oh_sn[oh_sn]["OH_Temperature_Scan"][key]=np.mean(values)
    time.sleep(1)

    for slot,oh_sn in geb_dict.items():
        print (Colors.BLUE + "\nRunning VTRx+ Temperature Scan for slot %s\n"%slot + Colors.ENDC)
        logfile.write("Running VTRx+ Temperature Scan for slot %s\n\n"%slot)
        oh_select = geb_oh_map[slot]["OH"]
        gbt = geb_oh_map[slot]["GBT"][-1]
        os.system("python3 me0_temp_monitor.py -s backend -q ME0 -o %d -g %d -t VTRX -n 10 >> %s"%(oh_select,gbt,log_fn))
        list_of_files = glob.glob('results/me0_lpgbt_data/temp_monitor_data/*GBT%d*.txt'%gbt)
        latest_file = max(list_of_files,key=os.path.getctime)
        os.system('cp %s %s/vtrx_temperature_scan_slot%s'%(latest_file,dataDir,slot))
        results_oh_sn[oh_sn]["VTRx"]["Temperature_Scan"]={}
        with open(latest_file) as vtrx_temp_file:
            keys = vtrx_temp_file.readline().split()[2:7:2]
            temperatures = {}
            for key in keys:
                temperatures[key]=[]
            for line in vtrx_temp_file.readlines():
                for key,value in zip(temperatures,line.split()[1:]):
                    temperatures[key]+=[float(value)]
        list_of_files = glob.glob("results/me0_lpgbt_data/temp_monitor_data/*GBT%d_temp_VTRX*.pdf"%gbt)
        if len(list_of_files)>0:
            latest_file = max(list_of_files, key=os.path.getctime)
            os.system("cp %s %s/vtrx+_temp_slot%s.pdf"%(latest_file, dataDir,slot))
        for key,values in temperatures.items():
            results_oh_sn[oh_sn]["VTRx"]["Temperature_Scan"][key]=np.mean(values)
    time.sleep(5)
    
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

    for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
        print (Colors.BLUE + "Running DAQ SCurves for OH %d all VFATs\n"%oh_select + Colors.ENDC)
        logfile.write("Running DAQ SCurves for OH %d all VFATs\n\n"%oh_select)
        # change back to n = 1000 for actual test
        os.system("python3 vfat_daq_scurve.py -s backend -q ME0 -o %d -v %s -n 1"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
        list_of_files = glob.glob("results/vfat_data/vfat_daq_scurve_results/*.txt")
        latest_file = max(list_of_files, key=os.path.getctime)
        scurve = {}
        with open(latest_file) as scurve_file:
            for line in scurve_file.readlines()[1:]:
                vfat = int(line.split()[0])
                channel = int(line.split()[1])
                fired = int(line.split()[3])
                if vfat in scurve:
                    if channel in scurve:
                        scurve[vfat][channel]+=[fired]
                    else:
                        scurve[vfat][channel]=[fired]
                else:
                    scurve[vfat]={}
                    scurve[vfat][channel]=[fired]
        bad_channels = {}
        for vfat in scurve:
            bad_channels[vfat]=[]
            for channel in scurve[vfat]:
                if np.all(scurve[vfat][channel]==0):
                    bad_channels[vfat].append([channel])
        print (Colors.BLUE + "Plotting DAQ SCurves for OH %d all VFATs\n"%oh_select + Colors.ENDC)
        logfile.write("Plotting DAQ SCurves for OH %d all VFATs\n\n"%oh_select)
        os.system("python3 plotting_scripts/vfat_analysis_scurve.py -c 0 -m voltage -f %s"%latest_file)
        latest_dir = latest_file.split(".txt")[0]
        if os.path.isdir(latest_dir):
            os.system("cp %s/scurve2Dhist_ME0_OH%d.png %s/daq_scurve_2D_hist_OH%d.png"%(latest_dir, oh_select, dataDir,oh_select))
            os.system("cp %s/scurveENCdistribution_ME0_OH%d.pdf %s/daq_scurve_ENC_OH%d.pdf"%(latest_dir, oh_select, dataDir,oh_select))
            os.system("cp %s/scurveThreshdistribution_ME0_OH%d.pdf %s/daq_scurve_Threshold_OH%d.pdf"%(latest_dir, oh_select, dataDir,oh_select))
        else:
            print (Colors.RED + "DAQ Scurve result directory not found" + Colors.ENDC)
            logfile.write("DAQ SCurve result directory not found\n")

        for slot,oh_sn in geb_dict.items():
            for vfat in geb_oh_map[slot]["VFAT"]:
                if vfat < 10:
                    scurve_fn = glob.glob('%s/fitResults_*VFAT0%d.txt'%(latest_dir,vfat))[0]
                else:
                    scurve_fn = glob.glob('%s/fitResults_*VFAT%d.txt'%(latest_dir,vfat))[0]
                with open(scurve_fn) as scurve_file:
                    read_next = False
                    for line in scurve_file.readlines():
                        if "Summary" in line:
                            read_next = True
                        elif read_next:
                            if "ENC" in line:
                                enc = float(line.split()[2])
                                if "DAQ_SCurve" in results_oh_sn[oh_sn]:
                                    if "ENC" in results_oh_sn[oh_sn]["DAQ_SCurve"]:
                                        results_oh_sn[oh_sn]["DAQ_SCurve"]["ENC"]+=[enc]
                                    else:
                                        results_oh_sn[oh_sn]["DAQ_SCurve"]["ENC"]=[enc]
                                else:
                                    results_oh_sn[oh_sn]["DAQ_SCurve"]={}
                                    results_oh_sn[oh_sn]["DAQ_SCurve"]["ENC"]=[enc]
                                read_next=False
                if "Bad_Channels" in results_oh_sn[oh_sn]["DAQ_SCurve"]:
                    results_oh_sn[oh_sn]["DAQ_SCurve"]["Bad_Channels"]+=[bad_channels[vfat]]
                else:
                    results_oh_sn[oh_sn]["DAQ_SCurve"]["Bad_Channels"]=[bad_channels[vfat]]
        
    print (Colors.GREEN + "\nStep 12: DAQ SCurve Complete\n" + Colors.ENDC)
    logfile.write("\nStep 12: DAQ SCurve Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 14 - DAQ Crosstalk
    print (Colors.BLUE + "Step 14: DAQ Crosstalk\n" + Colors.ENDC)
    logfile.write("Step 14: DAQ Crosstalk\n\n")

    for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
        print (Colors.BLUE + "Running DAQ Crosstalk for OH %d all VFATs\n"%oh_select + Colors.ENDC)
        logfile.write("Running DAQ Crosstalk for OH %d all VFATs\n\n"%oh_select)
        # change back to n = 1000 for actual test
        os.system("python3 vfat_daq_crosstalk.py -s backend -q ME0 -o %d -v %s -n 1"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
        logfile.close()

        list_of_files = glob.glob("results/vfat_data/vfat_daq_crosstalk_results/*_result.txt")
        latest_file = max(list_of_files, key=os.path.getctime)
        for slot,oh_sn in geb_dict.items():
            results_oh_sn[oh_sn]["DAQ_Crosstalk"]=[{}]*6
        with open(latest_file) as crosstalk_file:
            read_next = False
            crosstalk = {}
            for line in crosstalk_file.readlines():
                if "Cross Talk Results" in line:
                    read_next = True
                elif read_next:
                    if 'No Cross Talk observed' in line:
                        for slot,oh_sn in geb_dict.items():
                            for i in range(6):
                                results_oh_sn[oh_sn]["DAQ_Crosstalk"][i].update({"Status":1})
                    elif 'VFAT' in line:
                        vfat = int(line.split()[1].replace(',',''))
                        channel_inj = int(line.split()[6])
                        channels_obs = line.split()[9:]
                        for i,ch in enumerate(channels_obs):
                            channels_obs[i] = int(ch.replace(',',''))
                        try:
                            crosstalk[vfat][channel_inj]=channels_obs
                        except KeyError:
                            crosstalk[vfat]={}
                            crosstalk[vfat][channel_inj]=channels_obs
        if crosstalk!={}:
            for vfat in crosstalk:
                for slot,oh_sn in geb_dict.items():
                    for i,map_vfat in enumerate(geb_oh_map[slot]["VFAT"]):
                        if vfat == map_vfat:
                            results_oh_sn[oh_sn]["DAQ_Crosstalk"][i]["Status"]=0
                            if 'Bad_Channels' in results_oh_sn[oh_sn]["DAQ_Crosstalk"][i]:
                                results_oh_sn[oh_sn]["DAQ_Crosstalk"][i]["Bad_Channels"].update(crosstalk[vfat])
                            else:
                                results_oh_sn[oh_sn]["DAQ_Crosstalk"][i]["Bad_Channels"]=crosstalk[vfat]
                            break
                    if i!=7:
                        break
            for slot,oh_sn in geb_dict.items():
                for i,result in enumerate(results_oh_sn[oh_sn]["DAQ_Crosstalk"]):
                    if result == {}:
                        results_oh_sn[oh_sn]["DAQ_Crosstalk"][i].update({"Status":1})

        os.system("cat %s >> %s"%(latest_file, log_fn))
        logfile = open(log_fn, "a")
        list_of_files = glob.glob("results/vfat_data/vfat_daq_crosstalk_results/*_data.txt")
        latest_file = max(list_of_files, key=os.path.getctime)
    
        print (Colors.BLUE + "Plotting DAQ Crosstalk for OH %d all VFATs\n"%oh_select + Colors.ENDC)
        logfile.write("Plotting DAQ Crosstalk for OH %d all VFATs\n\n"%oh_select)
        os.system("python3 plotting_scripts/vfat_plot_crosstalk.py -f %s"%latest_file)
        latest_dir = latest_file.split(".txt")[0]
        if os.path.isdir(latest_dir):
            os.system("cp %s/crosstalk_ME0_OH%d.pdf %s/daq_crosstalk_OH%d.pdf"%(latest_dir,oh_select, dataDir,oh_select))
        else:
            print (Colors.RED + "DAQ Crosstalk result directory not found" + Colors.ENDC)
            logfile.write("DAQ Crosstalk result directory not found\n")
    
    for oh_sn,results in results_oh_sn.items():
        for result in results["DAQ_Crosstalk"]:
            if not result["Status"]:
                print (Colors.YELLOW + "\nStep 14: DAQ Crosstalk Failed\n" + Colors.ENDC)
                logfile.write("\nStep 14: DAQ Crosstalk Failed\n\n")
                with open(results_fn,"w") as resultsfile:
                    json.dump(results_oh_sn,resultsfile,indent=2)
                logfile.close()
                sys.exit()

    print (Colors.GREEN + "\nStep 14: DAQ Crosstalk Complete\n" + Colors.ENDC)
    logfile.write("\nStep 14: DAQ Crosstalk Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 15 - S-bit SCurve
    print (Colors.BLUE + "Step 15: S-bit SCurve\n" + Colors.ENDC)
    logfile.write("Step 15: S-bit SCurve\n\n")

    if batch in ["prototype", "pre_production", "pre_series"]:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():    
            print (Colors.BLUE + "Running S-bit SCurves for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running S-bit SCurves for OH %d all VFATs\n\n"%oh_select)
            # change back to n = 1000 for actual test
            os.system("python3 me0_vfat_sbit_scurve.py -s backend -q ME0 -o %d -v %s -n 1 -l -f"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            list_of_files = glob.glob("results/vfat_data/vfat_sbit_scurve_results/*.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            scurve = {}
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
            bad_channels = {}
            for vfat in scurve:
                bad_channels[vfat]=[]
                for channel in scurve[vfat]:
                    if np.all(scurve[vfat][channel]==0):
                        bad_channels[vfat].append([channel])
            print (Colors.BLUE + "Plotting S-bit SCurves for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Plotting S-bit SCurves for OH %d all VFATs\n\n"%oh_select)
            os.system("python3 plotting_scripts/vfat_analysis_scurve.py -c 0 -m current -f %s"%latest_file)
            latest_dir = latest_file.split(".txt")[0]
            if os.path.isdir(latest_dir):
                os.system("cp %s/scurve2Dhist_ME0_OH%d.png %s/sbit_scurve_2D_hist_OH%d.png"%(latest_dir, oh_select, dataDir, oh_select))
                os.system("cp %s/scurveENCdistribution_ME0_OH%d.pdf %s/sbit_scurve_ENC_OH%d.pdf"%(latest_dir, oh_select, dataDir, oh_select))
                os.system("cp %s/scurveThreshdistribution_ME0_OH%d.pdf %s/sbit_scurve_Threshold_OH%d.pdf"%(latest_dir, oh_select, dataDir, oh_select))
            else:
                print (Colors.RED + "S-bit Scurve result directory not found" + Colors.ENDC)
                logfile.write("S-bit SCurve result directory not found\n")
            
            for slot,oh_sn in geb_dict.items():
                for vfat in geb_oh_map[slot]["VFAT"]:
                    if vfat < 10:
                        scurve_fn = glob.glob('%s/fitResults_*VFAT0%d.txt'%(latest_dir,vfat))[0]
                    else:
                        scurve_fn = glob.glob('%s/fitResults_*VFAT%d.txt'%(latest_dir,vfat))[0]
                    with open(scurve_fn) as scurve_file:
                        read_next = False
                        for line in scurve_file.readlines():
                            if "Summary" in line:
                                read_next = True
                            elif read_next:
                                if "ENC" in line:
                                    enc = float(line.split()[2])
                                    if "SBIT_SCurve" in results_oh_sn[oh_sn]:
                                        if "ENC" in results_oh_sn[oh_sn]["SBIT_SCurve"]:
                                            results_oh_sn[oh_sn]["SBIT_SCurve"]["ENC"]+=[enc]
                                        else:
                                            results_oh_sn[oh_sn]["SBIT_SCurve"]["ENC"]=[enc]
                                    else:
                                        results_oh_sn[oh_sn]["SBIT_SCurve"]={}
                                        results_oh_sn[oh_sn]["SBIT_SCurve"]["ENC"]=[enc]
                                    read_next=False
                    if "Bad_Channels" in results_oh_sn[oh_sn]["SBIT_SCurve"]:
                        results_oh_sn[oh_sn]["SBIT_SCurve"]["Bad_Channels"].update(bad_channels[vfat])
                    else:
                        results_oh_sn[oh_sn]["SBIT_SCurve"]["Bad_Channels"]=bad_channels[vfat]
    else:
        print(Colors.BLUE + "Skipping S-bit SCurves for %s tests"%batch.replace("_"," ") + Colors.ENDC)
        logfile.write("Skipping S-bit SCurves for %s tests\n"%batch.replace("_"," "))

    print (Colors.GREEN + "\nStep 15: S-bit SCurve Complete\n" + Colors.ENDC)
    logfile.write("\nStep 15: S-bit SCurve Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 16 - S-bit Crosstalk
    print (Colors.BLUE + "Step 16: S-bit Crosstalk\n" + Colors.ENDC)
    logfile.write("Step 16: S-bit Crosstalk\n\n")
    
    if batch in ["prototype", "pre_production", "pre_series"]:
        for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
            print (Colors.BLUE + "Running S-bit Crosstalk for OH %d all VFATs\n"%oh_select + Colors.ENDC)
            logfile.write("Running S-bit Crosstalk for OH %d all VFATs\n\n"%oh_select)
            # change back to n = 1000 for actual test
            os.system("python3 me0_vfat_sbit_crosstalk.py -s backend -q ME0 -o %d -v %s -n 1 -l -f"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
            logfile.close()
            list_of_files = glob.glob("results/vfat_data/vfat_sbit_crosstalk_results/*_result.txt")
            latest_file = max(list_of_files, key=os.path.getctime)
            for slot,oh_sn in geb_dict.items():
                results_oh_sn[oh_sn]["SBIT_Crosstalk"]=[{}]*6
            with open(latest_file) as crosstalk_file:
                read_next = False
                crosstalk = {}
                for line in crosstalk_file.readlines():
                    if "Cross Talk Results" in line:
                        read_next = True
                    elif read_next:
                        if 'No Cross Talk observed' in line:
                            for slot,oh_sn in geb_dict.items():
                                for i in range(6):
                                    results_oh_sn[oh_sn]["SBIT_Crosstalk"][i].update({"Status":1})
                        elif 'VFAT' in line:
                            vfat = int(line.split()[1].replace(',',''))
                            channel_inj = int(line.split()[6])
                            channels_obs = line.split()[9:]
                            for i,ch in enumerate(channels_obs):
                                channels_obs[i] = int(ch.replace(',',''))
                            try:
                                crosstalk[vfat][channel_inj]=channels_obs
                            except KeyError:
                                crosstalk[vfat]={}
                                crosstalk[vfat][channel_inj]=channels_obs
            if crosstalk!={}:
                for vfat in crosstalk:
                    for slot,oh_sn in geb_dict.items():
                        for i,map_vfat in enumerate(geb_oh_map[slot]["VFAT"]):
                            if vfat == map_vfat:
                                results_oh_sn[oh_sn]["SBIT_Crosstalk"][i]["Status"]=0
                                if 'Bad_Channels' in results_oh_sn[oh_sn]["SBIT_Crosstalk"][i]:
                                    results_oh_sn[oh_sn]["SBIT_Crosstalk"][i]["Bad_Channels"].update(crosstalk[vfat])
                                else:
                                    results_oh_sn[oh_sn]["SBIT_Crosstalk"][i]["Bad_Channels"]=crosstalk[vfat]
                                break
                        if i!=7:
                            break
                for slot,oh_sn in geb_dict.items():
                    for i,result in enumerate(results_oh_sn[oh_sn]["SBIT_Crosstalk"]):
                        if result == {}:
                            results_oh_sn[oh_sn]["SBIT_Crosstalk"][i].update({"Status":1})

            os.system("cat %s >> %s"%(latest_file, log_fn))
            logfile = open(log_fn, "a")
            list_of_files = glob.glob("results/vfat_data/vfat_sbit_crosstalk_results/*_data.txt")
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
    else:
        print(Colors.BLUE + "Skipping S-bit crosstalk for %s tests"%batch.replace("_"," ") + Colors.ENDC)
        logfile.write("Skipping S-bit crosstalk for %s tests\n"%batch.replace("_"," "))

    print (Colors.GREEN + "\nStep 16: S-bit Crosstalk Complete\n" + Colors.ENDC)
    logfile.write("\nStep 16: S-bit Crosstalk Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 17 - S-bit Noise Rate
    print (Colors.BLUE + "Step 17: S-bit Noise Rate\n" + Colors.ENDC)
    logfile.write("Step 17: S-bit Noise Rate\n\n")

    for oh_select,gbt_vfat_dict in oh_gbt_vfat_map.items():
        print (Colors.BLUE + "Running S-bit Noise Rate for OH %d all VFATs\n"%oh_select + Colors.ENDC)
        logfile.write("Running S-bit Noise Rate for OH %d all VFATs\n\n"%oh_select)
        os.system("python3 me0_vfat_sbit_noise_rate.py -s backend -q ME0 -o %d -v %s -a -z -f"%(oh_select," ".join(map(str,gbt_vfat_dict["VFAT"]))))
        list_of_files = glob.glob("results/vfat_data/vfat_sbit_noise_results/*.txt")
        latest_file = max(list_of_files, key=os.path.getctime)
        for slot,oh_sn in geb_dict.items():
            if geb_oh_map[slot]["OH"]==oh_select:
                results_oh_sn[oh_sn]["SBIT_Noise_Rate"]=[]
        read_next = False
        sbit_noise = {}
        fired_list = []
        with open(latest_file) as sbit_noise_file:
            for line in sbit_noise_file.readlines()[1:]:
                vfat = int(line.split()[0])
                sbit = line.split()[1]
                threshold = int(line.split()[2])
                fired = int(float(line.split()[3]))
                if sbit == "all":
                    if fired == 0:
                        # save the first threshold with no hits
                        if vfat not in sbit_noise:
                            sbit_noise[vfat]=threshold
                    elif threshold==255:
                        # save 255 if still hits on threshold 255
                        sbit_noise[vfat]=threshold
        for vfat,threshold in sbit_noise.items():
            for slot,oh_sn in geb_dict.items():
                if vfat in geb_oh_map[slot]["VFAT"]:
                    results_oh_sn[oh_sn]["SBIT_Noise_Rate"]+=[threshold]
                    break
        
        print (Colors.BLUE + "Plotting S-bit Noise Rate for OH %d all VFATs\n"%oh_select + Colors.ENDC)
        logfile.write("Plotting S-bit Noise Rate for OH %d all VFATs\n\n"%oh_select)
        os.system("python3 plotting_scripts/vfat_plot_sbit_noise_rate.py -f %s"%latest_file)
        latest_dir = latest_file.split(".txt")[0]
        if os.path.isdir(latest_dir):
            if os.path.isdir(dataDir + "/sbit_noise_rate_results"):
                os.system("rm -rf " + dataDir + "/sbit_noise_rate_results")
            os.makedirs(dataDir + "/sbit_noise_rate_results")
            os.system("cp %s/*_mean_*.pdf %s/sbit_noise_rate_results/sbit_noise_rate_mean_OH%d.pdf"%(latest_dir, dataDir, oh_select))
            os.system("cp %s/*_or_*.pdf %s/sbit_noise_rate_results/sbit_noise_rate_or_OH%d.pdf"%(latest_dir, dataDir, oh_select))
            os.system("cp %s/2d*.pdf %s/sbit_noise_rate_results/sbit_2d_threshold_noise_rate_OH%d.pdf"%(latest_dir, dataDir, oh_select))
            os.system("cp %s/*_channels_*.pdf %s/sbit_noise_rate_results/"%(latest_dir, dataDir))
        else:
            print (Colors.RED + "S-bit Noise Rate result directory not found" + Colors.ENDC)
            logfile.write("S-bit Noise Rate result directory not found\n")    

    print (Colors.GREEN + "\nStep 17: S-bit Noise Rate Complete\n" + Colors.ENDC)
    logfile.write("\nStep 17: S-bit Noise Rate Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    with open(results_fn,"w") as resultsfile:
        json.dump(results_oh_sn,resultsfile,indent=2)

    logfile.close()
    os.system("rm -rf out.txt")
