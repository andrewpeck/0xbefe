from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from common.promless import *
from gem.gbt import *
from gem.gem_utils import *
import json
import datetime

def main():
    print("Frontend status:")
    gem_print_status()

    # Writing GBT status to text file
    resultDir = "results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    gbtDir = resultDir+"/gbt_data"
    try:
        os.makedirs(gbtDir) # create directory for GBT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = gbtDir+"/gbt_status_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    file_out = open(dataDir+"/gbt_status_"+now+".json", "w")
    with open(file_out,"w") as logfile:
        status_dict = get_gbt_link_status()
        json.dump(status_dict,logfile,indent=4)

if __name__ == '__main__':
    parse_xml()
    main()
