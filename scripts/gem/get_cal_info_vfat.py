from gem.gem_utils import *
from time import *
import argparse
import cx_Oracle
import pandas as pd
import os
from collections import OrderedDict

def getVfatList(inFile): # parse input file
    vfatList = OrderedDict()
    with open(inFile) as file:
        vfatList_line = file.readlines()
        vfatList_line = [line.rstrip('\n') for line in vfatList_line]
        for x in vfatList_line:
            vfatList[int(x.split()[0])] = int(x.split()[1])
    return vfatList

def checkEnvVars(): # check if environment variables set for DB access
    try:
        name = os.environ["GEM_ONLINE_DB_NAME"]
        conn = os.environ["GEM_ONLINE_DB_CONN"]
    except KeyError:
        print("Please set the following environment variables:\n GEM_ONLINE_DB_NAME\nGEM_ONLINE_DB_CONN")
        sys.exit()
    return name, conn

def main(gem, oh_select, id_type, write):

    serialN = OrderedDict()
    gem_link_reset()
    sleep(0.1)

    for vfat in range(0,24):
        register = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.HW_CHIP_ID"%(oh_select, vfat))
        serialN[vfat] = simple_read_backend_reg(register, -9999)
    print("=" * 31)
    print("====== VFAT Chip Numbers ======")
    print("=" * 31)
    print("VFAT\t|\t Chip Number")
    print("-" * 31)
    for vfat in range(0,24):
        if serialN[vfat] == -9999:
            print(Colors.RED + "%s" % vfat + Colors.ENDC + "\t|\t" + Colors.RED + "Link bad" + Colors.ENDC)
        else:
            print(Colors.GREEN + "%s" % vfat + Colors.ENDC + "\t|\t" + Colors.GREEN + "%s" % hex(serialN[vfat]) + Colors.ENDC)
    print("-" * 31)
    
    #if write:
    #    vfatFile = open("vfatDict.txt", "w")
    #    vfatInfo = str(serialN)
    #    vfatFile.write(vfatInfo)
    #    vfatFile.close()
    #serialN = {key:val for key, val in serialN.items() if val != -9999} # remove vfats with no serial number 
    
    name, conn = checkEnvVars() # get environment variables
    db = cx_Oracle.connect(conn + name) # connect to the database

    vfatQueryString0 = ('SELECT data.* FROM CMS_GEM_MUON_VIEW.GEM_VFAT3_PROD_SUMMARY_V_RH data '
            'INNER JOIN (SELECT vfat3_barcode, MAX(run_number) AS run_number FROM CMS_GEM_MUON_VIEW.GEM_VFAT3_PROD_SUMMARY_V_RH GROUP BY vfat3_barcode) data_select '
            'ON data.vfat3_barcode = data_select.vfat3_barcode AND data.run_number = data_select.run_number') # form query
    vfatQueryString1 = " AND ("

    if id_type=="hw_id":
        vfatList = serialN
    elif id_type=="file":
        inFile = "../resources/vfatID.txt"
        if not os.path.isfile(inFile):
            print (Colors.YELLOW + "Missing vfatID file for OH %d"%(oh_select) + Colors.ENDC)
            sys.exit()
        vfatList = getVfatList(inFile) # get list of vfats from input file

    for vfat in vfatList: # format query with vfat chip IDs
        serialNum = vfatList[vfat]
        if serialNum == -9999:
            continue
        if vfatQueryString1 == " AND (":
            vfatQueryString1 += " data.VFAT3_SER_NUM='0x{:x}'".format(serialNum)
        else:
            vfatQueryString1 += " OR data.VFAT3_SER_NUM='0x{:x}'".format(serialNum)
            pass
        pass

    vfatQueryString1 += " )\n"
    vfatQueryString0 += vfatQueryString1 # add chip IDs to main query
    
    vfatCalInfo = pd.read_sql(vfatQueryString0, db) # read database info
    vfatCalInfo.columns = [str.lower(col) for col in vfatCalInfo.columns] # set column names to lowercase

    pd.set_option('display.max_columns', 500) # show 500 columns
    vfatCalInfo.info() # display dataframe variables, data types, etc.
    print(vfatCalInfo) 
    
    if write: # write data to output files
        vfatCalInfo["vfat3_ser_num"] = vfatCalInfo["vfat3_ser_num"].transform(lambda x: int(x, 0)) # convert hex serial number into decimal

        vfatCalInfo_results = []
        for vfat in vfatList:
            result = {}
            result["vfat"] = vfat
            result["vfat3_ser_num"] = vfatList[vfat]
            serial_num_match = 0
            for i in vfatCalInfo.index:
                if vfatCalInfo["vfat3_ser_num"][i] == vfatList[vfat]:
                    result["vref_adc"] = vfatCalInfo["vref_adc"][i]
                    result["iref"] = vfatCalInfo["iref"][i]
                    result["adc0m"] = vfatCalInfo["adc0m"][i]
                    result["adc0b"] = vfatCalInfo["adc0b"][i]
                    result["cal_dacm"] = vfatCalInfo["cal_dacm"][i]
                    result["cal_dacb"] = vfatCalInfo["cal_dacb"][i]
                    serial_num_match = 1
                    break
            if not serial_num_match:
                result["vref_adc"] = -9999
                result["iref"] = -9999
                result["adc0m"] = -9999
                result["adc0b"] = -9999
                result["cal_dacm"] = -9999
                result["cal_dacb"] = -9999
            vfatCalInfo_results.append(result)
        vfatCalInfo_mod = pd.DataFrame(vfatCalInfo_results)

        resultDir = "results"
        try:
            os.makedirs(resultDir) # create directory for results
        except FileExistsError: # skip if directory already exists
            pass
        vfatDir = "results/vfat_data"
        try:
            os.makedirs(vfatDir) # create directory for vfat data
        except FileExistsError: # skip if directory already exists
            pass
        calDataDir = "results/vfat_data/vfat_calib_data"
        try:
            os.makedirs(calDataDir) # create directory for calibration datas
        except FileExistsError: # skip if directory already exists
            pass
        
        calInfoFile = calDataDir + "/%s_OH%d_vfat_calib_info_vref.txt"%(gem, oh_select)
        vfatCalInfo_mod.to_csv(calInfoFile, sep = ";", columns = ["vfat", "vfat3_ser_num", "vref_adc"], index = False)

        calInfoFile = calDataDir + "/%s_OH%d_vfat_calib_info_iref.txt"%(gem, oh_select)
        vfatCalInfo_mod.to_csv(calInfoFile, sep = ";", columns = ["vfat", "vfat3_ser_num", "iref"], index = False)
        
        calInfoFile = calDataDir + "/%s_OH%d_vfat_calib_info_adc0.txt"%(gem, oh_select)
        vfatCalInfo_mod.to_csv(calInfoFile, sep = ";", columns = ["vfat", "vfat3_ser_num", "adc0m", "adc0b"], index = False)

        calInfoFile = calDataDir + "/%s_OH%d_vfat_calib_info_calDac.txt"%(gem, oh_select)
        vfatCalInfo_mod.to_csv(calInfoFile, sep = ";", columns = ["vfat", "vfat3_ser_num", "cal_dacm", "cal_dacb"], index = False)
        #fileName = calDataDir + "/NominalValues_IREF.txt" 
        #vfatCalInfo_mod.to_csv(
        #        path_or_buf=fileName,
        #        sep=";",
        #        columns=['vfatN','iref'],
        #        header=False,
        #        index=False,
        #        mode='w')
    
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Retrieve VFAT calibration info from database.')
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 or GE21 or GE11")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-w", "--write", action="store_true", dest="write", help="write calib data to file")
    parser.add_argument("-t", "--type", action="store", dest="type", help="type = hw_id or file")
    #parser.add_argument("-i", "--inFile", action="store", dest="inFile", help="input file with list of VFAT serial numbers")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running on hardware")
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

    #if args.type not in ["hw_id", "file"]:
    if args.type != "file":
        print(Colors.YELLOW + "Input type can only file" + Colors.ENDC)
        #print(Colors.YELLOW + "Input type can only be hw_id or file" + Colors.ENDC)
        sys.exit()

    # Initialization
    initialize(args.gem, args.system)
    print("Initialization Done\n")

    try: 
        main(args.gem, int(args.ohid), args.type, args.write)
    except KeyboardInterrupt:
        print(Colors.YELLOW + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    
    terminate()
