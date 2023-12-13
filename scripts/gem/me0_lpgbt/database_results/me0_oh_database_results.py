import os,sys
from glob import glob
import json
import xmltodict
import argparse
import numpy as np
from common.utils import get_befe_scripts_dir
from gem.me0_lpgbt.rw_reg_lpgbt import Colors

scripts_gem_dir = get_befe_scripts_dir() + '/gem'
dbDir = scripts_gem_dir + '/me0_lpgbt/database_results'
inputDir = dbDir + '/input'
resultDir = dbDir + '/results'

quesoDir = scripts_gem_dir + '/me0_lpgbt/queso_testing/results'
gebDir = scripts_gem_dir + '/me0_lpgbt/oh_testing/results'

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

def get_input_data(inputDataDir):
    list_of_files = glob(inputDataDir+'/*')
    input_dataset = {}
    for filename in list_of_files:
        with open(filename,'r') as input_file:
            data = json.load(input_file)
        oh_vtrxp_key = filename.replace('.json','').split('/')[-1]
        input_dataset[oh_vtrxp_key] = data
    
    return input_dataset

def combine_data(sn,input_data,*dataset,hardware='OH'):
    data_out = {}
    data_out["ROOT"]={}
    data_out["ROOT"]["HEADER"]={}
    data_out["ROOT"]["HEADER"]['TYPE']={}
    if hardware=='OH':
        sn_str = 'ME0-OH-v2-%s'%sn
        data_out["ROOT"]["HEADER"]['TYPE']['EXTENSION_TABLE_NAME']='ME0_OH_QC'
        data_out["ROOT"]["HEADER"]['TYPE']['NAME']='ME0 OH QC Hardware'
    elif hardware=='VTRxPlus':
        sn_str = 'ME0-VTRxPlus-%s'%sn
        data_out["ROOT"]["HEADER"]['TYPE']['EXTENSION_TABLE_NAME']='ME0_VTRxPlus_QC'
        data_out["ROOT"]["HEADER"]['TYPE']['NAME']='ME0 VTRxPlus QC Hardware'
    else:
        raise Exception("Valid entries for keyword:'hardware' are ['OH','VTRxPlus'].")
    
    data_out["ROOT"]["HEADER"]['RUN']=input_data['RUN']

    data_out["ROOT"]['DATA_SET']={}
    if hardware=='OH':
        data_out['ROOT']['DATA_SET']['PART']={'KIND_OF_PART':'ME0 Opto Hybrid','SERIAL_NUMBER':sn_str}
    elif hardware=='VTRxPlus':
        data_out['ROOT']['DATA_SET']['PART']={'KIND_OF_PART':'ME0 VTRxPlus','SERIAL_NUMBER':sn_str}
    data_out["ROOT"]['DATA_SET']['DATA']={}
    if hardware=='OH':
        data_out["ROOT"]['DATA_SET']['DATA'].update(**input_data['DATA'][0])
    for data in dataset:
        # Search for matching serial number
        for results_dict in data:
            if results_dict['SERIAL_NUMBER'] == sn:
                # Check for conflicting data
                for key, result in results_dict.items():
                    if key in data and data[key]!=result:
                        print('Conflicting result for %s found while merging datasets for OH %s:'%(key,sn))
                        print('Current value:',data[key])
                        print('Incoming value:',result)
                        while True:
                            user_input = input('Which data would you like to save? 1: Keep current value, 2: Update to incoming value >> ')
                            if user_input == '1':
                                results_dict[key] = data[key]
                                break
                            elif user_input == '2':
                                data[key] = result
                                break
                            else:
                                print('Valid entries: 1, 2')
                # append results
                data_out["ROOT"]['DATA_SET']['DATA'].update(**results_dict)
                break
    if hardware=='OH':
        data_out["ROOT"]['DATA_SET']['DATA'].update(**input_data['DATA'][1])
    del data_out["ROOT"]['DATA_SET']['DATA']['SERIAL_NUMBER']
    return data_out

def main():
    parser = argparse.ArgumentParser(description="OptoHybrid Production Tests")
    parser.add_argument("-o", "--oh_sns", action="store", nargs="+", dest="oh_sns", help="OH_SNS = list of OH SERIAL NUMBERS matching a test batch of up to 8 OHs.")
    parser.add_argument("-vxp", "--vtrxp_sns", action="store", nargs="+", dest="vtrxp_sns", help="VTRXP_SNS = list of VTRx+ SERIAL NUMBERS for indexing.")
    parser.add_argument("-t", "--test_type", action="store", dest="test_type", help="TEST_TYPE = name of test batch; valid entries: [pre_production, pre_series, production, acceptance]")
    parser.add_argument("-v", "--verbose", action="store_true", dest="verbose", help="VERBOSE = print combined results output when saving to xml")
    args = parser.parse_args()

    # Check for valid args
    if not (args.oh_sns and args.vtrxp_sns):
        if not args.oh_sns:
            print(Colors.RED + 'Missing OH SERIAL NUMBERS.' + Colors.ENDC)
        if not args.vtrxp_sns:
            print(Colors.RED + 'Missing VTRxPlus SERIAL NUMBERS.' + Colors.ENDC)
        print(Colors.RED + 'Must provide both OH SERIAL NUMBER and VTRx+ SERIAL NUMBER arguments.' + Colors.ENDC)
        sys.exit()
    elif len(args.oh_sns) > 8:
        print(Colors.RED + 'Program can only take up to 8 OH SERIAL NUMBERS. List should match 1 QUESO TESTING and 2 OH TESTING directories exactly' + Colors.ENDC)
        sys.exit()
    elif len(args.oh_sns)!= len(args.vtrxp_sns):
        print(Colors.RED + 'Must provide a list of VTRxPlus SERIAL NUMBERs ordered according to the OHs on which they are installed.' + Colors.ENDC)
    # Check valid serial numbers for batch
    for oh_sn in args.oh_sns:
        try:
            if args.test_type=='pre_production':
                if int(oh_sn) not in range(1,1000):
                    print(Colors.RED + "Invalid OH SERIAL NUMBER entered: %s. Must be in range 1-1000 for pre-production."%oh_sn + Colors.ENDC)
                    sys.exit()
            elif args.test_type=='pre_series':
                if int(oh_sn) not in range(1001,1021):
                    print(Colors.RED + "Invalid OH SERIAL NUMBER entered: %s. Must be in range 1001-1020 for pre-series."%oh_sn + Colors.ENDC)
                    sys.exit()
            elif args.test_type in ['production','acceptance']:
                if int(oh_sn) not in range(1021,2019):
                    print(Colors.RED + "Invalid OH SERIAL NUMBER entered: %s. Must be in range 1021-2018 for %s."%(oh_sn,args.test_type) + Colors.ENDC)
                    sys.exit()
        except ValueError:
            print(Colors.RED + "OH SERIAL NUMBERS must be an integer. '%s' is an invalid entry."%oh_sn + Colors.ENDC)
            sys.exit()
    oh_sn_list = args.oh_sns

    for vtrxp_sn in args.vtrxp_sns:
        try:
            if int(vtrxp_sn) not in range(1,1000000):
                print(Colors.RED + "Invalid VTRx+ SERIAL NUMBER entered: %s. Must be a 6-digit number."%vtrxp_sn + Colors.ENDC)
                sys.exit()
        except ValueError:
            print(Colors.RED + "VTRx+ SERIAL NUMBER must be an integer. 's' is an invalid entry."%vtrxp_sn + Colors.ENDC)
            sys.exit()
    vtrxp_sn_list = args.vtrxp_sns

    if len(oh_sn_list) > 4:
        # Create list for both oh directories
        oh_sn_str = '_'.join(oh_sn_list)
        oh_sn_str1 = '_'.join(oh_sn_list[0:4])
        oh_sn_str2 = '_'.join(oh_sn_list[4:])
    else:
        oh_sn_str = '_'.join(oh_sn_list)
    
    # Check if data directories exist
    if args.test_type!='acceptance':
        queso_data_dir = quesoDir + '/%s_tests/OH_SNs_%s/'%(args.test_type,oh_sn_str)
        if not os.path.exists(queso_data_dir):
            print(Colors.RED + 'QUESO results data directory: %s not found. Please ensure correct list of OH SERIAL NUMBERS and order.'%queso_data_dir + Colors.ENDC)
            sys.exit()
        queso_init_fn = queso_data_dir + 'queso_initialization_results.json'
        queso_bert_fn = queso_data_dir + 'queso_elink_bert_results.json'
    if len(oh_sn_list) > 4:
        geb_data2_dir = gebDir + '/%s_tests/OH_SNs_%s/'%(args.test_type,oh_sn_str2)
        geb_data1_dir = gebDir + '/%s_tests/OH_SNs_%s/'%(args.test_type,oh_sn_str1)
        if not os.path.exists(geb_data1_dir):
            print(Colors.RED + 'GEB results data directory: %s not found. OH SERIAL NUMBER order must match test batch directories exactly.'%geb_data1_dir + Colors.ENDC)
            sys.exit()
        if not os.path.exists(geb_data2_dir):
            print(Colors.RED + 'GEB results data directory: %s not found. OH SERIAL NUMBER order must match test batch directories exactly.'%geb_data2_dir + Colors.ENDC)
            sys.exit()
        geb_data1_fn = geb_data1_dir + 'me0_oh_database_results.json'
        geb_data2_fn = geb_data2_dir + 'me0_oh_database_results.json'
        vtrxp_data1_fn = geb_data1_dir + 'me0_vtrxp_database_results.json'
        vtrxp_data2_fn = geb_data2_dir + 'me0_vtrxp_database_results.json'
    else:
        geb_data_dir = gebDir + '/%s_tests/OH_SNs_%s/'%(args.test_type,oh_sn_str)
        if not os.path.exists(geb_data_dir):
            print(Colors.RED + 'GEB results data directory: %s not found. OH SERIAL NUMBER order must match test batch directories exactly.'%geb_data_dir + Colors.ENDC)
            sys.exit()
        geb_data_fn = geb_data_dir + 'me0_oh_database_results.json'
        vtrxp_data_fn = geb_data_dir + 'me0_vtrxp_database_results.json'

    # input data directory
    inputDataDir = inputDir + '/OH_SNs_%s'%oh_sn_str
    # output data directory
    dataDir = resultDir + '/OH_SNs_%s'%oh_sn_str

    # Check if directories exist
    if not os.path.exists(inputDataDir) or not os.path.exists(dataDir):
        print(Colors.YELLOW + 'Could not find data directories for /OH_SNs_%s. Run generate_input.py to generate necessary input files and data directories.'%oh_sn_str + Colors.ENDC)
        sys.exit()
    
    # Get input data
    input_dataset = get_input_data(inputDataDir)
    # check for input data
    input_data_found = [False for _ in range(len(oh_sn_list))]
    for i,(oh_sn,vtrxp_sn) in enumerate(zip(oh_sn_list,vtrxp_sn_list)):
        if 'OH_%s_VTRxPlus_%s'%(oh_sn,vtrxp_sn) in input_dataset:
            input_data_found[i] = True
        else:
            print(Colors.RED + "Missing INPUT data for OH %s and VTRxPlus %s"%(oh_sn,vtrxp_sn) + Colors.ENDC)
    if not np.all(input_data_found):
        print(Colors.RED + 'Please run generate_input.py again. Only data present for the following:'+Colors.ENDC)
        print(', '.join(input_dataset))
        sys.exit()

    # -- Begin creating datasets --

    oh_dataset = []
    if args.test_type!='acceptance':
        # Load and check queso data
        queso_data_found = [False for _ in range(len(oh_sn_list))]
        try:
            queso_init_data = get_json_data(queso_init_fn)
        except FileNotFoundError:
            print(Colors.RED + 'QUESO INITIALIZATION RESULTS file not found.')
            sys.exit()
        for i,oh_sn in enumerate(oh_sn_list):
            for j,data in enumerate(queso_init_data):
                if data['SERIAL_NUMBER']==oh_sn:
                    queso_data_found[i] = True
                    break
                elif j==len(queso_init_data)-1:
                    queso_data_found[i] = False
                    print(Colors.RED + "Missing QUESO INITIALIZATION RESULTS data for OH %s"%oh_sn + Colors.ENDC)
        try:
            queso_bert_data = get_json_data(queso_bert_fn)
        except FileNotFoundError:
            print(Colors.RED + 'QUESO ELINK BERT RESULTS file not found.')
            sys.exit()
        for i,oh_sn in enumerate(oh_sn_list):
            for j,data in enumerate(queso_bert_data):
                if data['SERIAL_NUMBER']==oh_sn:
                    queso_data_found[i] = True
                    break
                elif j==len(queso_bert_data)-1:
                    print(Colors.RED + "Missing QUESO ELINK BERT RESULTS data for OH %s"%oh_sn + Colors.ENDC)
        
        if not np.all(queso_data_found):
                print(Colors.RED + 'Please check QUESO results files for missing data.' + Colors.ENDC)
                sys.exit()
        else:
            oh_dataset += [queso_init_data,queso_bert_data]

    # Load and check geb (oh + vtrxp) data
    if len(oh_sn_list) > 4:
        try:
            geb_data = get_json_data(geb_data1_fn)
        except FileNotFoundError:
            print(Colors.RED + 'GEB RESULTS file 1 not found.')
            sys.exit()

        try:
            geb_data += get_json_data(geb_data2_fn)
        except FileNotFoundError:
            print(Colors.RED + 'GEB RESULTS file 2 not found.')
            sys.exit()

        try:
            vtrxp_dataset = get_json_data(vtrxp_data1_fn)
        except FileNotFoundError:
            print(Colors.RED + 'VTRx+ RESULTS file 1 not found.')
            sys.exit()

        try:
            vtrxp_dataset += get_json_data(vtrxp_data2_fn)
        except FileNotFoundError:
            print(Colors.RED + 'VTRx+ RESULTS file 1 not found.')
            sys.exit()
    else:
        try:
            geb_data = get_json_data(geb_data_fn)
        except FileNotFoundError:
            print(Colors.RED + 'GEB RESULTS file not found.')
            sys.exit()
        try:
            vtrxp_dataset = get_json_data(vtrxp_data_fn)
        except FileNotFoundError:
            print(Colors.RED + 'VTRx+ RESULTS file not found.')
            sys.exit()

    # Check for missing data and that oh serial numbers and vtrxp serial numbers match
    geb_data_found = [False for _ in range(len(oh_sn_list))]
    vtrxp_data_found = [False for _ in range(len(vtrxp_sn_list))]
    oh_vtrxp_mismatch = [False for _ in range(len(oh_sn_list))]
    for i,(oh_sn,vtrxp_sn) in enumerate(zip(oh_sn_list,vtrxp_sn_list)):
        for j,(geb_result,vtrxp_result) in enumerate(zip(geb_data,vtrxp_dataset)):
            # Check for oh sn present in geb data
            if geb_result['SERIAL_NUMBER']==oh_sn:
                geb_data_found[i] = True
                oh_i = j
            # Check for vtrxp sn present in geb data
            if vtrxp_result['SERIAL_NUMBER']==vtrxp_sn:
                vtrxp_data_found[i] = True
                vtrxp_i = j
            if geb_data_found[i] and vtrxp_data_found[i]:
                break

        if not geb_data_found[i]:
            print(Colors.RED + "Missing GEB RESULTS data for OH %s"%oh_sn + Colors.ENDC)
        if not vtrxp_data_found[i]:
            print(Colors.RED + "Missing RESULTS data for VTRxPlus %s"%vtrxp_sn + Colors.ENDC)
        
        # Check for correct vtrxp sn in oh dataset
        if geb_data[oh_i]['VTRXPLUS_SERIAL_NUMBER']!=vtrxp_dataset[vtrxp_i]['SERIAL_NUMBER']:
            oh_vtrxp_mismatch[i] = True
            print(Colors.RED + 'Mismatch VTRxPlus SERIAL NUMBER. In OH results: %s, In VTRxPlus results: %s'%(geb_data['VTRXPLUS_SERIAL_NUMBER'],vtrxp_dataset['SERIAL_NUMBER']) + Colors.ENDC)

    if not np.all(geb_data_found):
        print(Colors.RED + 'Please check GEB results files for missing data.' + Colors.ENDC)
        sys.exit()
    if not np.all(vtrxp_data_found):
        print(Colors.RED + 'Please check VTRxPlus results files for missing data.' + Colors.ENDC)
        sys.exit()
    elif np.any(oh_vtrxp_mismatch):
        print(Colors.RED + 'VTRx+ SERIAL NUMBER order must match the OHs on which they are mounted.' + Colors.ENDC)
        sys.exit()
    else:
        oh_dataset+=[geb_data]

    for oh_sn,vtrxp_sn in zip(oh_sn_list,vtrxp_sn_list):
        input_oh = input_dataset['OH_%s_VTRxPlus_%s'%(oh_sn,vtrxp_sn)]['OH']
        input_vtrxp = input_dataset['OH_%s_VTRxPlus_%s'%(oh_sn,vtrxp_sn)]['VTRxPlus']
        print(Colors.BLUE + "Merging results data for OH %s"%oh_sn + Colors.ENDC)
        oh_data = combine_data(oh_sn,input_oh,*oh_dataset,hardware='OH')
        if args.verbose:
            print('\ncombined data for OH %s:\n----------------------'%oh_sn)
            for key,value in oh_data.items():
                print('%s: '%key, value)
                print()
        # save to xml file
        results_fn = dataDir + '/ME0_OH_%s.xml'%oh_sn
        print('Saving to xml file at directory: %s'%results_fn)
        with open(results_fn,'w') as results_file:
            xmltodict.unparse(oh_data,results_file,pretty=True,indent='  ')
        
        vtrxp_data = combine_data(vtrxp_sn,input_vtrxp,vtrxp_dataset,hardware='VTRxPlus')
        if args.verbose:
            print('\ncombined data for VTRx+ %s:\n----------------------'%vtrxp_sn)
            for key,value in vtrxp_data.items():
                print('%s: '%key, value)
                print()
        # save to xml file
        results_fn = dataDir + '/VTRxPlus_%s.xml'%vtrxp_sn
        print('Saving to xml file at directory: %s\n'%results_fn)
        with open(results_fn,'w') as results_file:
            xmltodict.unparse(vtrxp_data,results_file,pretty=True,indent='  ')

if __name__ == '__main__':
    main()
