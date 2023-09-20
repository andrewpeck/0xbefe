import os,sys
from glob import glob
import json
import xmltodict
import argparse
import numpy as np
from gem.me0_lpgbt.rw_reg_lpgbt import Colors

def get_json_data(fn):
    with open(fn,'r') as fp:
        json_data = json.load(fp)
    return json_data

def print_json_data(fn):
    json_data = get_json_data(fn)
    for result_dict in json_data:
        for key,value in result_dict.items():
            print('%s: '%key, value)
        print()

def get_input_data(sn,hardware='OH'):
    if hardware=='OH':
        list_of_files = glob('me0_lpgbt/database_results/input/input_OH_%s_*.json'%sn)
        latest_file = max(list_of_files, key=os.path.getctime)
        with open(latest_file,'r') as input_file:
            data = json.load(input_file)
        return data['OH']
    elif hardware=='VTRXP':
        list_of_files = glob('me0_lpgbt/database_results/input/input_*VTRXP_%s.json'%sn)
        latest_file = max(list_of_files, key=os.path.getctime)
        with open(latest_file,'r') as input_file:
            data = json.load(input_file)
        return data['VTRXP']
    else:
        raise Exception("Valid entries for keyword:'hardware' are ['OH','VTRXP'].")

def combine_data(sn,*dataset,hardware='OH'):
    data_sn = {}
    data_sn["ROOT"]={}
    data_sn["ROOT"]["HEADER"]={}
    data_sn["ROOT"]["HEADER"]['TYPE']={}
    if hardware=='OH':
        data_sn["ROOT"]["HEADER"]['TYPE']['EXTENSION_TABLE_NAME']='ME0_OH_QC'
        data_sn["ROOT"]["HEADER"]['TYPE']['NAME']='ME0 OH QC Hardware'
    elif hardware=='VTRXP':
        data_sn["ROOT"]["HEADER"]['TYPE']['EXTENSION_TABLE_NAME']='ME0_VTRXP_QC'
        data_sn["ROOT"]["HEADER"]['TYPE']['NAME']='ME0 VTRxp QC Hardware'
    else:
        raise Exception("Valid entries for keyword:'hardware' are ['OH','VTRXP'].")
    input_data = get_input_data(sn,hardware=hardware)
    data_sn["ROOT"]["HEADER"]['RUN']=input_data['RUN']

    data_sn["ROOT"]['DATA_SET']={}
    if hardware=='OH':
        data_sn['ROOT']['DATA_SET']['PART']={'KIND_OF_PART':'ME0 Opto Hybrid','SERIAL_NUMBER':sn}
    elif hardware=='VTRXP':
        data_sn['ROOT']['DATA_SET']['PART']={'KIND_OF_PART':'ME0 VTRxp','SERIAL_NUMBER':sn}
    data_sn["ROOT"]['DATA_SET']['DATA']={}
    if hardware=='OH':
        data_sn["ROOT"]['DATA_SET']['DATA'].update(**input_data['DATA'][0])
    print(len(dataset))
    for data in dataset:
        print(data)
    for data in dataset:
        # Search for matching serial number
        for results_dict in data:
            if results_dict['SERIAL_NUMBER'] == sn:
                # Check for conflicting data
                for key, result in results_dict.items():
                    if key in data_sn and data_sn[key]!=result:
                        print('Conflicting result for %s found while merging datasets for OH %s:'%(key,sn))
                        print('Current value:',data_sn[key])
                        print('Incoming value:',result)
                        while True:
                            user_input = input('Which data would you like to save? 1: Keep current value, 2: Update to incoming value >> ')
                            if user_input == '1':
                                results_dict[key] = data_sn[key]
                                break
                            elif user_input == '2':
                                data_sn[key] = result
                                break
                            else:
                                print('Valid entries: 1, 2')
                # append results
                data_sn["ROOT"]['DATA_SET']['DATA'].update(**results_dict)
                break
    if hardware=='OH':
        data_sn["ROOT"]['DATA_SET']['DATA'].update(**input_data['DATA'][1])
    del data_sn["ROOT"]['DATA_SET']['DATA']['SERIAL_NUMBER']
    return data_sn

def main():
    parser = argparse.ArgumentParser(description="OptoHybrid Production Tests")
    parser.add_argument("-o", "--oh_sns", action="store", nargs="+", dest="oh_sns", help="OH_SNS = list of Optohybrid SERIAL NUMBERS for indexing")
    parser.add_argument("-vxp", "--vtrxp_sns", action="store", nargs="+", dest="vtrxp_sns", help="VTRXP_SNS = list of VTRx+ SERIAL NUMBERS for indexing")
    parser.add_argument("-b", "--batch", action="store", dest="batch", help="BATCH = name of test batch; valid entries: [pre_production, pre_series, production, acceptance]")
    parser.add_argument("-qf1", "--queso_file1", action="store", dest="queso_file1", help="QUESO_FILE1 = input file path for QUESO INITIALIZATION test results")
    parser.add_argument("-qf2", "--queso_file2", action="store", dest="queso_file2", help="QUESO_FILE2 = input file path for QUESO ELINK BER test results")
    parser.add_argument("-gf1", "--geb_file1", action="store", dest="geb_file1", help="GEB_FILE1 = input file path 1 for GEB test results")
    parser.add_argument("-gf2", "--geb_file2", action="store", dest="geb_file2", help="GEB_FILE2 = input file path 2 for GEB test results")
    parser.add_argument("-vf1", "--vtrxp_file1", action="store", dest="vtrxp_file1", help="VTRXP_FILE1 = input file path 1 for VTRx+ test results")
    parser.add_argument("-vf2", "--vtrxp_file2", action="store", dest="vtrxp_file2", help="VTRXP_FILE2 = input file path 2 for VTRx+ test results")
    parser.add_argument("-v", "--verbose", action="store_true", dest="verbose", help="VERBOSE = print combined results output when saving to xml")
    args = parser.parse_args()

    # Check valid serial numbers
    if not args.oh_sns and not args.vtrxp_sns:
        print(Colors.RED + 'Must provide at least one OH SERIAL NUMBER or VTRx+ SERIAL NUMBER argument.' + Colors.ENDC)
        sys.exit()
    
    skip_oh = False
    skip_vtrxp = False

    if args.oh_sns:
        for oh_sn in args.oh_sns:
            try:
                if args.batch=='pre_production':
                    if int(oh_sn) not in range(1,1000):
                        print(Colors.RED + "Invalid OH SERIAL NUMBER entered: %s. Must be in range 1-1000 for pre-production."%oh_sn + Colors.ENDC)
                        sys.exit()
                elif args.batch=='pre_series':
                    if int(oh_sn) not in range(1001,1021):
                        print(Colors.RED + "Invalid OH SERIAL NUMBER entered: %s. Must be in range 1001-1020 for pre-series."%oh_sn + Colors.ENDC)
                        sys.exit()
                elif args.batch in ['production','acceptance']:
                    if int(oh_sn) not in range(1021,2019):
                        print(Colors.RED + "Invalid OH SERIAL NUMBER entered: %s. Must be in range 1021-2018 for %s."%(oh_sn,args.batch) + Colors.ENDC)
                        sys.exit()
            except ValueError:
                print(Colors.RED + "OH SERIAL NUMBERS must be an integer. '%s' is an invalid entry."%oh_sn + Colors.ENDC)
                sys.exit()
        oh_sn_list = args.oh_sns
    else:
        print(Colors.YELLOW + "No OH SERIAL NUMBERS provided. Skipping results for OH" + Colors.ENDC)
        skip_oh = True

    if args.vtrxp_sns:
        for vtrxp_sn in args.vtrxp_sns:
            try:
                if int(vtrxp_sn) not in range(1,1000000):
                    print(Colors.RED + "Invalid VTRx+ SERIAL NUMBER entered: %s. Must be a 6-digit number."%vtrxp_sn + Colors.ENDC)
                    sys.exit()
            except ValueError:
                print(Colors.RED + "VTRx+ SERIAL NUMBER must be an integer. 's' is an invalid entry."%vtrxp_sn + Colors.ENDC)
                sys.exit()
        vtrxp_sn_list = args.vtrxp_sns
    else:
        print(Colors.YELLOW + "No VTRx+ SERIAL NUMBERS provided. Skipping results for VTRx+" + Colors.ENDC)
        skip_vtrxp = True

    # Check for all necessary files
    if not skip_oh:
        oh_dataset = []
        queso_data_found = [True for _ in range(len(oh_sn_list))]
        if args.batch!='acceptance':
            if args.queso_file1:
                try:
                    queso_init_data = get_json_data(args.queso_file1)
                except FileNotFoundError:
                    print(Colors.RED + 'Invalid path for QUESO INITIALIZATION RESULTS file.')
                    sys.exit()
                for i,oh_sn in enumerate(oh_sn_list):
                    for j,data in enumerate(queso_init_data):
                        if data['SERIAL_NUMBER']==oh_sn:
                            queso_data_found[i] &= True
                            break
                        elif j==len(queso_init_data)-1:
                            queso_data_found[i] = False
                            print(Colors.RED + "Missing QUESO INITIALIZATION RESULTS data for OH %s"%oh_sn + Colors.ENDC)
            else:
                print(Colors.RED + 'Must include a QUESO INITIALIZATION RESULTS file path (-qf1/--queso_file1 argument).')
                sys.exit()
            if args.queso_file2:
                try:
                    queso_bert_data = get_json_data(args.queso_file2)
                except FileNotFoundError:
                    print(Colors.RED + 'Invalid path for QUESO ELINK BERT RESULTS file.')
                    sys.exit()
                for i,oh_sn in enumerate(oh_sn_list):
                    for j,data in enumerate(queso_bert_data):
                        if data['SERIAL_NUMBER']==oh_sn:
                            queso_data_found[i] &= True
                            break
                        elif j==len(queso_bert_data)-1:
                            queso_data_found[i] = False
                            print(Colors.RED + "Missing QUESO ELINK BERT RESULTS data for OH %s"%oh_sn + Colors.ENDC)
            else:
                print(Colors.RED + 'Must include a QUESO ELINK BERT RESULTS file path (-qf2/--queso_file2 argument).')
                sys.exit()
            if not np.all(queso_data_found):
                    print(Colors.RED + 'Please check that all OH SERIAL NUMBERS and file paths provided are accurate.' + Colors.ENDC)
                    sys.exit()
            else:
                oh_dataset += [queso_init_data,queso_bert_data]

        geb_data_found = [True for _ in range(len(oh_sn_list))]
        if args.geb_file1:
            try:
                geb_data = get_json_data(args.geb_file1)
            except FileNotFoundError:
                print(Colors.RED + 'Invalid path for GEB RESULTS file 1.')
                sys.exit()
        else:
            print(Colors.RED + 'Must include at least one GEB RESULTS file path (-gf1/--geb_file1 argument).')
            sys.exit()
        if args.geb_file2:
            try:
                geb_data += get_json_data(args.geb_file2)
            except FileNotFoundError:
                print(Colors.RED + 'Invalid path for GEB RESULTS file 2.')
                sys.exit()
        for i,oh_sn in enumerate(oh_sn_list):
            for j,data in enumerate(geb_data):
                if data['SERIAL_NUMBER']==oh_sn:
                    geb_data_found[i] &= True
                    break
                elif j==len(queso_bert_data)-1:
                    geb_data_found[i] = False
                    print(Colors.RED + "Missing GEB RESULTS data for OH %s"%oh_sn + Colors.ENDC)
        if not np.all(geb_data_found):
            if not args.geb_file2:
                print(Colors.RED + 'Please check the OH SERIAL NUMBERS and that all files are provided (use -gf2/--geb_file2 and enter second GEB RESULTS file).' + Colors.ENDC)
                sys.exit()
            else:
                print(Colors.RED + 'Please check that all OH SERIAL NUMBERS and file paths provided are accurate.' + Colors.ENDC)
                sys.exit()
        else:
            oh_dataset+=[geb_data]
        
        for oh_sn in oh_sn_list:
            print(Colors.BLUE + "Merging results data for OH %s"%oh_sn)
            oh_data = combine_data(oh_sn,*oh_dataset,hardware='OH')
            if args.verbose:
                print('\ncombined data for OH %s:\n----------------------'%oh_sn)
                for key,value in oh_data.items():
                    print('%s: '%key, value)
            print()
            # save to xml file
            results_fn = 'me0_lpgbt/database_results/results/ME0_OH_%s.xml'%oh_sn
            print('Saving to xml file at directory: %s'%results_fn)
            with open(results_fn,'w') as results_file:
                xmltodict.unparse(oh_data,results_file,pretty=True)


    if not skip_vtrxp:
        vtrxp_dataset = []
        vtrxp_data_found = [True for _ in range(len(vtrxp_sn_list))]
        if args.vtrxp_file1:
            try:
                vtrxp_dataset += get_json_data(args.vtrxp_file1)
            except FileNotFoundError:
                print(Colors.RED + 'Invalid path for VTRx+ RESULTS file 1.')
                sys.exit()
        if args.vtrxp_file2:
            try:
                vtrxp_dataset += get_json_data(args.vtrxp_file2)
            except FileNotFoundError:
                print(Colors.RED + 'Invalid path for VTRx+ RESULTS file 1.')
                sys.exit()
        for i,vtrxp_sn in enumerate(vtrxp_sn_list):
            for j,data in enumerate(vtrxp_dataset):
                if data['SERIAL_NUMBER']==vtrxp_sn:
                    vtrxp_data_found[i] &= True
                    break
                elif j==len(vtrxp_dataset)-1:
                    vtrxp_data_found[i] = False
                    print(Colors.RED + "Missing VTRx+ RESULTS data for OH %s"%vtrxp_sn + Colors.ENDC)
        if not np.all(vtrxp_data_found):
            if not args.vtrxp_file2:
                print(Colors.RED + 'Please check the VTRx+ SERIAL NUMBERS and that all files are provided (use -gf2/--geb_file2 and enter second GEB RESULTS file).' + Colors.ENDC)
                sys.exit()
            else:
                print(Colors.RED + 'Please check that all VTRx+ SERIAL NUMBERS and file paths provided are accurate.' + Colors.ENDC)
                sys.exit()
        for vtrxp_sn in vtrxp_sn_list:
            vtrxp_data = combine_data(vtrxp_sn,vtrxp_dataset,hardware='VTRXP')
            if args.verbose:
                print('\ncombined data for VTRx+ %s:\n----------------------'%vtrxp_sn)
                for key,value in vtrxp_data.items():
                    print('%s: '%key, value)
            print()
            # save to xml file
            results_fn = 'me0_lpgbt/database_results/results/VTRXP_%s.xml'%vtrxp_sn
            print('Saving to xml file at directory: %s'%results_fn)
            with open(results_fn,'w') as results_file:
                xmltodict.unparse(vtrxp_data,results_file,pretty=True)

    resultDir = "me0_lpgbt/database_results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass

if __name__ == '__main__':
    main()
