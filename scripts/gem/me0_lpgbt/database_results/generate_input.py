import os,sys
from glob import glob
import json
import xmltodict
import argparse
from common.utils import get_befe_scripts_dir

def main():
    parser = argparse.ArgumentParser(description="Generate Input Files for OptoHybrid Production Tests")
    parser.add_argument('-u','--user',action='store_true',dest='user',help='USER = create input files from user input parameters')
    parser.add_argument('-f','--filename',action='store',dest='filename',help='FILENAME = input file with input parameters')
    args = parser.parse_args()

    if not (args.user ^ bool(args.filename)):
        print('Must provide an input method (-u/--user for user input OR -f/--filename an input file for parsing)')
        sys.exit()
    if args.filename:
        print('Parsing results from file not implemented. Choose -u/--user for user prompted input.')
        sys.exit()
    
    scripts_gem_dir = get_befe_scripts_dir() + '/gem'
    dbDir = scripts_gem_dir + '/me0_lpgbt/database_results'
    inputDir = dbDir + '/input'
    resultDir = dbDir + '/results'

    if args.user:
        oh_sn = input('Enter OH SERIAL NUMBER(s): ')
        oh_sn_list = oh_sn.split()
        if len(oh_sn_list)>1:
            multiple_ohs = True
            one_for_all = False
            multiple_params = False
        else:
            multiple_ohs=False
        
        num_ohs = len(oh_sn_list)
        num_batches = -(num_ohs // -8) # ceiling divide by batch size of 8

        for b in range(num_batches):
            if multiple_ohs:
                options = input('\nWould you like to duplicate responses to all OHs in this batch (%d/%d)? (1)\nAssign some genereral parameters to all OHs? (2)\nOr assign unique values to each OH? (3)\nOptionally type "help" to view what is copied in option 2 >> '%(b+1,num_batches))
                while options=='help':
                    print('\nGENERAL PARAMETERS: ["RUN_NUMBER", "RUN_BEGIN_TIMESTAMP","RUN_END_TIMESTAMP", "LOCATION", "USER", "BATCH", "SHIPPING_BOX", "BOARD_LOCATION"]\n')
                    options = input('Would you like to duplicate responses to all OHs? (1)\nAssign some genereral parameters to all OHs? (2)\nOr assign unique values to each OH? (3)\nOptionally type "help" to view what is copied in option (2) >> ')
                while options.lower() not in ['1', '2', '3', 'help']:
                    print('\nInvalid input. Valid entries are [1, 2, 3, help]\n')
                    options = input('Would you like to duplicate responses to all OHs? (1)\nAssign some genereral parameters to all OHs? (2)\nOr assign unique values to each OH? (3)\nOptionally type "help" to view what is copied in option (2) >> ')
                if options=='1':
                    print('Will generate JSON files for all OHs based of one batch of responses.\n')
                    one_for_all = True
                elif options=='2':
                    print('Will assign some general parameters to all OHs, but prompt for specific results.\n')
                elif options=='3':
                    print('Will prompt for all results for each OH.\n')
                    multiple_params = True
                else:
                    print('\nInvalid input. Valid entries are [1, 2, 3, help]\n')
                    sys.exit()

            reg_oh_data = {'ROOT':{'PARTS':{'PART':[]}}}
            reg_vtrxp_data = {'ROOT':{'PARTS':{'PART':[]}}}

            oh_sn_batch_list = oh_sn_list[b*8:min(b*8+8,num_ohs)]
            oh_sn_str = '_'.join(oh_sn_batch_list)

            input_OHSNs_Dir = inputDir + '/OH_SNs_%s'%oh_sn_str
            try:
                os.makedirs(input_OHSNs_Dir) # create batch directory for input files
            except FileExistsError: # skip if already exists
                pass

            data_OHSNs_Dir = resultDir + '/OH_SNs_%s'%oh_sn_str
            try:
                os.makedirs(data_OHSNs_Dir) # create batch directory for data files
            except FileExistsError:
                pass

            for i,oh_sn in enumerate(oh_sn_batch_list):
                vtrxp_sn = input('Enter VTRXP SERIAL NUMBER for OH %s: '%oh_sn)
                
                print('\nSection: OH.RUN:\n----------------')
                
                if multiple_ohs:
                    if i==0 or multiple_params:
                        run_number = input('Enter RUN NUMBER (integer) for OH %s: '%oh_sn)
                else:
                    run_number = input('Enter RUN NUMBER (integer) for OH %s: '%oh_sn)
                run_number = int(run_number)

                if multiple_ohs:
                    if i==0 or multiple_params:
                        run_begin_timestamp = input('Enter RUN BEGIN TIMESTAMP in "YYYY-MM-DD hh:mm:ss" (24-hr) format for OH %s: '%oh_sn)
                else:
                    run_begin_timestamp = input('Enter RUN BEGIN TIMESTAMP in "YYYY-MM-DD hh:mm:ss" (24-hr) format for OH %s: '%oh_sn)
                while len(run_begin_timestamp) != 19:
                    print('Timestamp was not input in the suggested format of "YYYY-MM-DD hh:mm:ss"! Please re-enter... ')
                    run_begin_timestamp = input('Enter RUN BEGIN TIMESTAMP in "YYYY-MM-DD hh:mm:ss" (24-hr) format for OH %s: '%oh_sn)
                
                if multiple_ohs:
                    if i==0 or multiple_params:
                        run_end_timestamp = input('Enter RUN END TIMESTAMP in "YYYY-MM-DD hh:mm:ss" (24-hr) format for OH %s: '%oh_sn)
                else:
                    run_end_timestamp = input('Enter RUN END TIMESTAMP in "YYYY-MM-DD hh:mm:ss" (24-hr) format for OH %s: '%oh_sn)
                while len(run_end_timestamp) != 19:
                    print('Timestamp was not input in the suggested format of "YYYY-MM-DD hh:mm:ss"! Please re-enter... ')
                    run_end_timestamp = input('Enter RUN END TIMESTAMP in "YYYY-MM-DD hh:mm:ss" (24-hr) format for OH %s: '%oh_sn)
                
                if multiple_ohs:
                    if i==0 or multiple_params:
                        location = input('Enter test LOCATION for OH %s (leave blank if you want default = UCLA): '%oh_sn)
                else:
                    location = input('Enter test LOCATION for OH %s (leave blank if you want default = UCLA): '%oh_sn)
                if location=="":
                    location = 'UCLA'
                
                if multiple_ohs:
                    if i==0 or multiple_params:
                        user = input('Enter USER who performed tests: ')
                else:
                    user = input('Enter USER who performed tests: ')
                
                comments_oh = input('Enter any comments for OH %s (leave blank if no comments): '%oh_sn)

                # Append data to xml registration datasets
                reg_oh_data['ROOT']['PARTS']['PART'].append(
                    {
                        'SERIAL_NUMBER': 'ME0-OH-v2-%s'%oh_sn,
                        'LOCATION': location,
                        'KIND_OF_PART': 'ME0 Opto Hybrid',
                        'RECORD_INSERTION_USER': user,
                        'MUNUFACTURER': 'Pactron',
                        'CHILDREN':{
                            'PART':{
                                'SERIAL_NUMBER':'ME0-VTRXP-%s'%vtrxp_sn,
                                'KIND_OF_PART': 'ME0 VTRxPlus'
                                    }
                                    }
                    }
                )
                reg_vtrxp_data['ROOT']['PARTS']['PART'].append(
                    {
                        'SERIAL_NUMBER': 'ME0-VTRXP-%s'%vtrxp_sn,
                        'LOCATION': location,
                        'KIND_OF_PART': 'ME0 VTRxPlus',
                        'RECORD_INSERTION_USER': user,
                        'MUNUFACTURER': 'CERN',
                    }
                )
                
                print('\nSection: OH.DATA(1/2):\n-------------')
                
                batch_dict = {'0': 'pre_production', '1': 'pre_series', '2': 'production'}
                batch_dict_str = ', '.join(['%s = %s'%(value,key) for key,value in batch_dict.items()])
                if multiple_ohs:
                    if i==0 or multiple_params:
                        options = input('Enter BATCH for OH %s (%s): '%(oh_sn,batch_dict_str))
                else:
                    options = input('Enter BATCH for OH %s (%s): '%(oh_sn,batch_dict_str))
                while options not in batch_dict:
                    print('\nInvalid input! Valid entries are [%s]\n'%', '.join(batch_dict))
                    options = input('Enter BATCH for OH %s (%s): '%(oh_sn,batch_dict_str))
                batch = batch_dict[options]
                
                if multiple_ohs:
                    if i==0 or not one_for_all:
                        thermal_testing = input('Was THERMAL TESTING performed on OH %s? (y/n) '%oh_sn)
                        if thermal_testing.lower() in 'yes':
                            thermal_testing = input('Did this board (OH %s) pass? (y/n) '%oh_sn)
                            thermal_testing_pass = 1 if thermal_testing.lower() in 'yes' else 0
                            thermal_testing = 1
                        else:
                            thermal_testing = 0
                            thermal_testing_pass = 0
                else:
                    thermal_testing = input('Was THERMAL TESTING performed on OH %s? (y/n) '%oh_sn)
                    if thermal_testing.lower() in 'yes':
                        thermal_testing = input('Did this board (OH %s) pass? (y/n) '%oh_sn)
                        thermal_testing_pass = 1 if thermal_testing.lower() in 'yes' else 0
                        thermal_testing = 1
                    else:
                        thermal_testing = 0
                        thermal_testing_pass = 0
                if multiple_ohs:
                    if i==0 or not one_for_all:
                        power_cycle_testing = input('Was POWER CYCLE TESTING performed on OH %s? (y/n) '%oh_sn)
                        if power_cycle_testing.lower() in 'yes':
                            power_cycle_testing = input('Did this board (OH %s) pass? (y/n) '%oh_sn)
                            power_cycle_testing_pass = 1 if power_cycle_testing.lower() in 'yes' else 0
                            power_cycle_testing = 1
                        else:
                            power_cycle_testing = 0
                            power_cycle_testing_pass = 0
                else:
                    power_cycle_testing = input('Was POWER CYCLE TESTING performed on OH %s? (y/n) '%oh_sn)
                    if power_cycle_testing.lower() in 'yes':
                        power_cycle_testing = input('Did this board (OH %s) pass? (y/n) '%oh_sn)
                        power_cycle_testing_pass = 1 if power_cycle_testing.lower() in 'yes' else 0
                        power_cycle_testing = 1
                    else:
                        power_cycle_testing = 0
                        power_cycle_testing_pass = 0

                if multiple_ohs:
                    if i==0 or not one_for_all:
                        link_rst_testing = input('Was LINK RESET TESTING performed on OH %s? (y/n) '%oh_sn)
                        if link_rst_testing.lower() in 'yes':
                            link_rst_testing = input('Did this board (OH %s) pass? (y/n) '%oh_sn)
                            link_rst_testing_pass = 1 if link_rst_testing.lower() in 'yes' else 0
                            link_rst_testing = 1
                        else:
                            link_rst_testing = 0
                            link_rst_testing_pass = 0
                else:
                    link_rst_testing = input('Was LINK RESET TESTING performed on OH %s? (y/n) '%oh_sn)
                    if link_rst_testing.lower() in 'yes':
                        link_rst_testing = input('Did this board (OH %s) pass? (y/n) '%oh_sn)
                        link_rst_testing_pass = 1 if link_rst_testing.lower() in 'yes' else 0
                        link_rst_testing = 1
                    else:
                        link_rst_testing = 0
                        link_rst_testing_pass = 0
                
                if multiple_ohs:
                    if i==0 or not one_for_all:
                        uplink_eye_diagram = input('Was UPLINK EYE DIAGRAM performed on OH %s? (y/n) '%oh_sn)
                        if uplink_eye_diagram.lower() in 'yes':
                            while True:
                                try:
                                    open_eye_fraction_M = float(input('Enter open eye fraction for OH %s Main lpGBT (float): '%oh_sn))
                                    break
                                except ValueError:
                                    print('Must enter a float for open eye fraction.')
                            while True:
                                try:
                                    open_eye_fraction_S = float(input('Enter open eye fraction for OH %s Secondary lpGBT (float): '%oh_sn))
                                    break
                                except ValueError:
                                    print('Must enter a float for open eye fraction.')
                        else:
                            open_eye_fraction_M = open_eye_fraction_S = -9999
                    elif uplink_eye_diagram.lower() in 'yes':
                        while True:
                            try:
                                open_eye_fraction_M = float(input('Enter open eye fraction for OH %s Main lpGBT (float): '%oh_sn))
                                break
                            except ValueError:
                                print('Must enter a float for open eye fraction.')
                        while True:
                            try:
                                open_eye_fraction_S = float(input('Enter open eye fraction for OH %s Secondary lpGBT (float): '%oh_sn))
                                break
                            except ValueError:
                                print('Must enter a float for open eye fraction.')            
                else:
                    uplink_eye_diagram = input('Was UPLINK EYE DIAGRAM performed on OH %s? (y/n) '%oh_sn)
                    if uplink_eye_diagram.lower() in 'yes':
                        while True:
                            try:
                                open_eye_fraction_M = float(input('Enter open eye fraction for OH %s Main lpGBT (float): '%oh_sn))
                                break
                            except ValueError:
                                print('Must enter a float for open eye fraction.')
                        while True:
                            try:
                                open_eye_fraction_S = float(input('Enter open eye fraction for OH %s Secondary lpGBT (float): '%oh_sn))
                                break
                            except ValueError:
                                print('Must enter a float for open eye fraction.')
                    else:
                        open_eye_fraction_M = open_eye_fraction_S = -9999
            
                if multiple_ohs:
                    if i==0 or not one_for_all:
                        vis_inspection = input('Did this board (OH %s) pass visual inspection with no shorts? (y/n) '%oh_sn)
                        vis_inspection = 1 if vis_inspection.lower() in 'yes' else 0
                else:
                    vis_inspection = input('Did this board (OH %s) pass visual inspection with no shorts? (y/n) '%oh_sn)
                    vis_inspection = 1 if vis_inspection.lower() in 'yes' else 0

                if multiple_ohs:
                    if i==0 or not one_for_all:
                        passed_all_tests = input('Did this board (OH %s) pass all tests? (y/n) '%oh_sn)
                        passed_all_tests = 1 if passed_all_tests.lower() in 'yes' else 0
                else:
                    passed_all_tests = input('Did this board (OH %s) pass all tests? (y/n) '%oh_sn)
                    passed_all_tests = 1 if passed_all_tests.lower() in 'yes' else 0

                print('\nSection: OH.DATA(2/2):\n-------------')
                if multiple_ohs:
                    if i==0 or multiple_params:
                        shipping_box = input('Enter SHIPPING BOX # (integer) for OH %s: '%oh_sn)
                else:
                    shipping_box = input('Enter SHIPPING BOX # (integer) for OH %s: '%oh_sn)
                shipping_box = int(shipping_box)

                if multiple_ohs:
                    if i==0 or multiple_params:
                        board_location = input('Enter current BOARD LOCATION for OH %s: '%oh_sn)
                else:
                    board_location = input('Enter current BOARD LOCATION for OH %s: '%oh_sn)
                
                board_state_dict = {'1': 'GOOD', '0': 'BAD'}
                if multiple_ohs:
                    if i==0 or not one_for_all:
                        options = input('Enter the BOARD STATE for OH %s (GOOD = 1, BAD = 0): '%oh_sn)
                        while options not in board_state_dict:
                            print('\nInvalid input! Valid entries are [%s]\n'%', '.join(board_state_dict))
                            options = input('Enter the BOARD STATE for OH %s (GOOD = 1, BAD = 0): '%oh_sn)
                        board_state = board_state_dict[options]
                else:
                    options = input('Enter the BOARD STATE for OH %s (GOOD = 1, BAD = 0): '%oh_sn)
                    while options not in board_state_dict:
                        print('\nInvalid input! Valid entries are [%s]\n'%', '.join(board_state_dict))
                        options = input('Enter the BOARD STATE for OH %s (GOOD = 1, BAD = 0): '%oh_sn)
                    board_state = board_state_dict[options]

                board_purpose_dict = {'1': 'teststand', '2': 'on_detector', '3': 'spare'}
                board_purpose_dict_str = ', '.join(['%s = %s'%(value,key) for key,value in board_purpose_dict.items()])
                if multiple_ohs:
                    if i==0 or not one_for_all:
                        options = input('Enter BOARD PURPOSE for OH %s (%s): '%(oh_sn,board_purpose_dict_str))
                        while options not in board_purpose_dict:
                            print('\nInvalid input! Valid entries are [%s]\n'%', '.join(board_purpose_dict))
                            options = input('Enter BOARD PURPOSE for OH %s (%s): '%(oh_sn,board_purpose_dict_str))
                        board_purpose = board_purpose_dict[options]
                else:
                    options = input('Enter BOARD PURPOSE for OH %s (%s): '%(oh_sn,board_purpose_dict_str))
                    while options not in board_purpose_dict:
                        print('\nInvalid input! Valid entries are [%s]\n'%', '.join(board_purpose_dict))
                        options = input('Enter BOARD PURPOSE for OH %s (%s): '%(oh_sn,board_purpose_dict_str))
                    board_purpose = board_purpose_dict[options]

                print('\nSection VTRXP.RUN is automatically generated from OH %s info.\n'%oh_sn)
                comments_vtrxp = input('Enter any comments for VTRXP %s (mounted on OH %s): '%(vtrxp_sn,oh_sn))

                # JSON input file
                json_filename = input_OHSNs_Dir + '/OH_%s_VTRXP_%s.json'%(oh_sn,vtrxp_sn)
                print('\nGenerating input JSON file at: %s\n'%json_filename)

                # populate JSON data dict
                data = {'OH':{'RUN':{}, 'DATA':[{},{}]}, 'VTRXP':{'RUN':{}}}
                data['OH']['RUN']['RUN_TYPE'] = "ME0 OH QC Hardware"
                data['VTRXP']['RUN']['RUN_TYPE'] = "ME0 VTRxp QC Hardware"
                data['OH']['RUN']['RUN_NUMBER'] = data['VTRXP']['RUN']['RUN_NUMBER'] = run_number
                data['OH']['RUN']['RUN_BEGIN_TIMESTAMP'] = data['VTRXP']['RUN']['RUN_BEGIN_TIMESTAMP'] = run_begin_timestamp
                data['OH']['RUN']['RUN_END_TIMESTAMP'] = data['VTRXP']['RUN']['RUN_END_TIMESTAMP'] = run_end_timestamp
                data['OH']['RUN']['LOCATION'] = data['VTRXP']['RUN']['LOCATION'] = location
                data['OH']['RUN']['INITIATED_BY_USER'] = data['VTRXP']['RUN']['INITIATED_BY_USER'] = user
                data['OH']['RUN']['COMMENT_DESCRIPTION'] = comments_oh
                data['VTRXP']['RUN']['COMMENT_DESCRIPTION'] = comments_vtrxp
                data['OH']['DATA'][0]['BATCH'] = batch
                data['OH']['DATA'][0]['THERMAL_TESTING_DONE'] = thermal_testing
                data['OH']['DATA'][0]['THERMAL_TESTING_PASS'] = thermal_testing_pass
                data['OH']['DATA'][0]['POWER_CYCLE_TESTING_DONE'] = power_cycle_testing
                data['OH']['DATA'][0]['POWER_CYCLE_TESTING_PASS'] = power_cycle_testing_pass
                data['OH']['DATA'][0]['LINK_RESET_TESTING_DONE'] = link_rst_testing
                data['OH']['DATA'][0]['LINK_RESET_TESTING_PASS'] = link_rst_testing_pass
                data['OH']['DATA'][0]['VISUAL_INSPECTION_NO_SHORTS'] = vis_inspection
                data['OH']['DATA'][0]['PASSED_ALL_TESTS'] = passed_all_tests
                data['OH']['DATA'][0]['LPGBT_M_UPLINK_EYE_DIAGRAM'] = open_eye_fraction_M
                data['OH']['DATA'][0]['LPGBT_S_UPLINK_EYE_DIAGRAM'] = open_eye_fraction_S
                data['OH']['DATA'][1]['SHIPPING_BOX'] = shipping_box
                data['OH']['DATA'][1]['BOARD_LOCATION'] = board_location
                data['OH']['DATA'][1]['BOARD_STATE'] = board_state
                data['OH']['DATA'][1]['BOARD_PURPOSE'] = board_purpose

                with open(json_filename,'w') as jsonfile:
                    json.dump(data,jsonfile,indent=2)
            # -- end of batch --

            # Register oh's,vtrxp's xml file
            oh_xml_fn = data_OHSNs_Dir + '/ME0-OH.xml'
            vtrxp_xml_fn = data_OHSNs_Dir + '/ME0-VTRXP.xml'

            with open(oh_xml_fn,'w') as xmlfile:
                xmltodict.unparse(reg_oh_data,xmlfile,pretty=True,indent='  ')
            with open(vtrxp_xml_fn,'w') as xmlfile:
                xmltodict.unparse(reg_vtrxp_data,xmlfile,pretty=True,indent='  ')
            
if __name__=='__main__':
    main()