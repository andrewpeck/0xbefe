import os,sys
import json
import xmltodict
import argparse

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

def combine_json_data(oh_sn,*dataset):
    data_oh_sn = {}
    for data in dataset:
        for results_dict in data:
            if results_dict['SERIAL_NUMBER'] == oh_sn:
                for key, result in results_dict.items():
                    if key in data_oh_sn:
                        if data_oh_sn[key]!=result:
                            print('Conflicting result for %s found while merging datasets for OH %s:'%(key,oh_sn))
                            print('Current value:',data_oh_sn[key])
                            print('Incoming value:',result)
                            while True:
                                user_input = input('Which data would you like to save? 1: Keep current value, 2: Update to incoming value >> ')
                                if user_input == '1':
                                    results_dict[key] = data_oh_sn[key]
                                    break
                                elif user_input == '2':
                                    data_oh_sn[key] = result
                                    break
                                else:
                                    print('Valid entries: 1, 2')
                data_oh_sn.update(**results_dict)
                break
    return data_oh_sn

def main():
    parser = argparse.ArgumentParser(description="OptoHybrid Production Tests")
    parser.add_argument("-o", "--oh_sns", action="store", nargs="+", dest="oh_sns", help="OH_SNS = list of Optohybrid SERIAL NUMBERS for indexing")
    parser.add_argument("-vxp", "--vtrxp_sns", action="store", nargs="+", dest="vtrxp_sns", help="VTRXP_SNS = list of VTRx+ SERIAL NUMBERS for indexing")
    parser.add_argument("-qf1", "--queso_file1", action="store", dest="queso_file1", help="QUESO_FILE1 = input file path for QUESO INITIALIZATION test results")
    parser.add_argument("-qf2", "--queso_file2", action="store", dest="queso_file2", help="QUESO_FILE2 = input file path for QUESO ELINK BER test results")
    parser.add_argument("-gf1", "--geb_file1", action="store", dest="geb_file1", help="GEB_FILE1 = input file path 1 for GEB test results")
    parser.add_argument("-gf2", "--geb_file2", action="store", dest="geb_file2", help="GEB_FILE2 = input file path 2 for GEB test results")
    parser.add_argument("-vf1", "--vtrxp_file1", action="store", dest="vtrxp_file1", help="VTRXP_FILE1 = input file path 1 for VTRx+ test results")
    parser.add_argument("-vf2", "--vtrxp_file2", action="store", dest="vtrxp_file2", help="VTRXP_FILE2 = input file path 2 for VTRx+ test results")
    args = parser.parse_args()

    # --------------------------
    # Check valid serial numbers
    # --------------------------

    oh_sn_list = args.oh_sns
    vtrxp_sn_list = args.vtrxp_sns
    
    # --------------------------
    # Check for all files and all serial numbers match
    # --------------------------

    resultDir = "me0_lpgbt/database_results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass

    queso_init_data  = get_json_data(args.queso_file1)
    queso_bert_data  = get_json_data(args.queso_file2)
    geb_data1        = get_json_data(args.geb_file1)
    geb_data2        = get_json_data(args.geb_file2)
    vtrxp_data1      = get_json_data(args.vtrxp_file1)
    vtrxp_data2      = get_json_data(args.vtrxp_file2)

    for oh_sn in oh_sn_list:
        oh_data = combine_json_data(oh_sn,queso_init_data,queso_bert_data,geb_data1,geb_data2)
        print('\ncombined data for OH %s:\n----------------------'%oh_sn)
        for key,value in oh_data.items():
            print('%s: '%key, value)
        print()
        # save to xml file
    
    for vtrxp_sn in vtrxp_sn_list:
        vtrxp_data = combine_json_data(vtrxp_sn,vtrxp_data1,vtrxp_data2)
        print('\ncombined data for VTRx+ %s:\n----------------------'%vtrxp_sn)
        for key,value in vtrxp_data.items():
            print('%s: '%key, value)
        print()
        # save to xml file

if __name__ == '__main__':
    main()
