from gem.gem_utils import *
from time import sleep, time
import sys
import argparse
import random
import glob

vfat_register_config = {}
vfat_calib_iref = {}
vfat_calib_vref = {}
vfat_register_dac_scan = {}
vfat_channel_trimming = {}

def initialize_vfat_config(gem, oh_select, use_dac_scan_results, use_channel_trimming):
    global vfat_register_config
    global vfat_calib_iref
    global vfat_calib_vref
    global vfat_register_dac_scan
    global vfat_channel_trimming

    # Generic register list
    vfat_register_config_file_path = "../resources/vfatConfig.txt"
    if not os.path.isfile(vfat_register_config_file_path):
        print (Colors.YELLOW + "VFAT config text file not present in vfat_data/" + Colors.ENDC)
        sys.exit()
    vfat_register_config_file = open(vfat_register_config_file_path)
    for line in vfat_register_config_file.readlines():
        vfat_register_config[line.split()[0]] = int(line.split()[1])
    vfat_register_config_file.close()

    # IREF from calib
    vfat_calib_iref_path = "results/vfat_data/vfat_calib_data/%s_OH%d_vfat_calib_info_iref.txt"%(gem,oh_select)
    if not os.path.isfile(vfat_calib_iref_path):
        print ("IREF calib file for VFATs not present, using default values")
    else:
        vfat_calib_iref_file = open(vfat_calib_iref_path)
        for line in vfat_calib_iref_file.readlines():
            if "vfat" in line:
                continue
            vfat_calib_iref[int(line.split(";")[0])] = int(line.split(";")[2])
        vfat_calib_iref_file.close()

    # VREF from calib
    vfat_calib_vref_path = "results/vfat_data/vfat_calib_data/%s_OH%d_vfat_calib_info_vref.txt"%(gem, oh_select)
    if not os.path.isfile(vfat_calib_vref_path):
        print ("VREF calib file for VFATs not present, using default values")
    else:
        vfat_calib_vref_file = open(vfat_calib_vref_path)
        for line in vfat_calib_vref_file.readlines():
            if "vfat" in line:
                continue
            vfat_calib_vref[int(line.split(";")[0])] = int(line.split(";")[2])
        vfat_calib_vref_file.close()

    # DAC Scan Results
    if use_dac_scan_results:
        dac_scan_results_base_path = "results/vfat_data/vfat_dac_scan_results"
        if os.path.isdir(dac_scan_results_base_path):
            list_of_dirs = []
            for d in glob.glob(dac_scan_results_base_path+"/*"):
                if os.path.isdir(d):
                    list_of_dirs.append(d)
            if len(list_of_dirs)>0:
                latest_dir = max(list_of_dirs, key=os.path.getctime)
                dac_scan_results_path = latest_dir
                for f in glob.glob(dac_scan_results_path+"/nominalValues_%s_OH%d_*.txt"%(gem, oh_select)):
                    reg = f.split("nominalValues_%s_OH%d_"%(gem, oh_select))[1].split(".txt")[0]
                    vfat_register_dac_scan[reg] = {}
                    file_in = open(f)
                    for line in file_in.readlines():
                        vfat = int(line.split(";")[1])
                        dac = int(line.split(";")[2])
                        vfat_register_dac_scan[reg][vfat] = dac
                    file_in.close()
            else:
                print (Colors.YELLOW + "DAC scan results not present, using default regsiter values" + Colors.ENDC)
        else:
            print (Colors.YELLOW + "DAC scan results not present, using default regsiter values" + Colors.ENDC)

    # Channel Trimming Results
    if use_channel_trimming is not None:
        trim_results_base_path = ""
        if use_channel_trimming == "daq":
            trim_results_path = "results/vfat_data/vfat_daq_trimming_results"
        elif use_channel_trimming == "sbit":
            trim_results_path = "results/vfat_data/vfat_sbit_trimming_results"
        if os.path.isdir(trim_results_path):
            trim_file_list = glob.glob(trim_results_path+"/*.txt")
            if len(trim_file_list)>0:
                trim_file_latest = max(trim_file_list, key=os.path.getctime)
                trim_file_in = open(trim_file_latest)
                for line in trim_file_in.readlines():
                    if "VFAT" in line:
                        continue
                    if len(line.split())==0:
                        continue
                    vfat = int(line.split()[0])
                    channel = int(line.split()[1])
                    trim_amp = int(line.split()[2])
                    trim_polarity = int(line.split()[3])
                    if vfat not in vfat_channel_trimming:
                        vfat_channel_trimming[vfat] = {}
                    vfat_channel_trimming[vfat][channel] = {}
                    vfat_channel_trimming[vfat][channel]["trim_amp"] = trim_amp
                    vfat_channel_trimming[vfat][channel]["trim_polarity"] = trim_polarity
                trim_file_in.close()
            else:
                print (Colors.YELLOW + "Trimming results not present, not using trimming" + Colors.ENDC)
        else:
            print (Colors.YELLOW + "Trimming results not present, not using trimming" + Colors.ENDC)

def setVfatchannelTrim(vfatN, ohN, channel, trim_polarity, trim_amp):
    channel_trim_polarity_node = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.VFAT_CHANNELS.CHANNEL%i.ARM_TRIM_POLARITY"%(ohN, vfatN, channel))
    channel_trim_amp_node = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.VFAT_CHANNELS.CHANNEL%i.ARM_TRIM_AMPLITUDE"%(ohN, vfatN, channel))
    write_backend_reg(channel_trim_polarity_node, trim_polarity)
    write_backend_reg(channel_trim_amp_node, trim_amp)

def enableVfatchannel(vfatN, ohN, channel, mask, enable_cal):
    #channel_node = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.VFAT_CHANNELS.CHANNEL%i"%(ohN, vfatN, channel))
    channel_enable_node = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.VFAT_CHANNELS.CHANNEL%i.CALPULSE_ENABLE"%(ohN, vfatN, channel))
    channel_mask_node = get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.VFAT_CHANNELS.CHANNEL%i.MASK"%(ohN, vfatN, channel))
    if mask: # mask and disable calpulsing
        #write_backend_reg(channel_node, 0x4000)
        write_backend_reg(channel_enable_node, 0)
        write_backend_reg(channel_mask_node, 1)
    else:
        if enable_cal: # unmask and enable calpulsing
            #write_backend_reg(channel_node, 0x8000)
            write_backend_reg(channel_enable_node, 1)
            write_backend_reg(channel_mask_node, 0)
        else: # unmask but disable calpulsing
            #write_backend_reg(channel_node, 0x0000)
            write_backend_reg(channel_enable_node, 0)
            write_backend_reg(channel_mask_node, 0)
    
def configureVfat(configure, vfatN, ohN, low_thresh):

    for i in range(128):
        enableVfatchannel(vfatN, ohN, i, 0, 0) # unmask all channels and disable calpulsing

    if configure:
        #print ("Configuring VFAT")
        register_written = []

        if vfatN in vfat_calib_iref:
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_IREF"     % (ohN, vfatN)), vfat_calib_iref[vfatN])
            register_written.append("CFG_IREF")
        if vfatN in vfat_calib_vref:
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_VREF_ADC"     % (ohN, vfatN)), vfat_calib_vref[vfatN])
            register_written.append("CFG_VREF_ADC")
        for reg in vfat_register_dac_scan:
            if vfatN in vfat_register_dac_scan[reg]:
                write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.%s"     % (ohN, vfatN, reg)), vfat_register_dac_scan[reg][vfatN])
                register_written.append(reg)
        for reg in vfat_register_config:
            if reg in register_written:
                continue
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.%s"     % (ohN, vfatN, reg)), vfat_register_config[reg])
            register_written.append(reg)

        if low_thresh:
            write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_THR_ARM_DAC"     % (ohN, vfatN)) , 0)

        for i in range(128):
            trim_polarity = 0
            trim_amp = 0
            if vfatN in vfat_channel_trimming:
                if i in vfat_channel_trimming[vfatN]:
                    trim_polarity = vfat_channel_trimming[vfatN][i]["trim_polarity"]
                    trim_amp = vfat_channel_trimming[vfatN][i]["trim_amp"]
            setVfatchannelTrim(vfatN, ohN, i, trim_polarity, trim_amp)
            
        write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN"%(ohN, vfatN)), 1)

    else:
        #print ("Unconfiguring VFAT")
        for i in range(128):
            setVfatchannelTrim(vfatN, ohN, i, 0, 0)
        write_backend_reg(get_backend_node("BEFE.GEM.OH.OH%d.GEB.VFAT%d.CFG_RUN"%(ohN, vfatN)), 0)

def vfat_config(system, oh_select, vfat_list, low_thresh, configure):
    print ("VFAT Configuration\n")
    
    gem_link_reset()
    sleep(0.1)

    for vfat in vfat_list:
        gbt, gbt_select, elink, gpio = me0_vfat_to_gbt_elink_gpio(vfat)
        check_gbt_link_ready(oh_select, gbt_select)
        if configure:
            print ("Configuring VFAT#: %02d" %(vfat))
        else:
            print ("Unconfiguring VFAT#: %02d" %(vfat))
        configureVfat(configure, vfat, oh_select, low_thresh)
        print ("")

    print ("\nVFAT configuration done\n")

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="VFAT Configuration")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 or GE21 or GE11")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-v", "--vfats", action="store", nargs="+", dest="vfats", help="vfats = list of VFAT numbers (0-23)")
    parser.add_argument("-c", "--config", action="store", dest="config", help="config = 1 for configure, 0 for unconfigure")
    parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
    parser.add_argument("-lt", "--low_thresh", action="store_true", dest="low_thresh", help="low_thresh = to set low threshold for channels")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for VFAT Configuration")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running vfat configuration")
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

    if args.config not in ["0", "1"]:
        print (Colors.YELLOW + "Only allowed options for configure: 0 and 1" + Colors.ENDC)
        sys.exit()
    configure = int(args.config)

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
        vfat_config(args.system, int(args.ohid), vfat_list, args.low_thresh, configure)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()

    # Termination
    terminate()




