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
    scripts_gem_dir = get_befe_scripts_dir() + "/gem"
    resultDir = scripts_gem_dir = "/results"
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
    filename = dataDir+"/gbt_status_"+now+".json"
    with open(filename,"w") as logfile:
        status_dict = get_gbt_link_status()
        json.dump(status_dict,logfile,indent=2)

if __name__ == '__main__':
    parse_xml()
    main()
