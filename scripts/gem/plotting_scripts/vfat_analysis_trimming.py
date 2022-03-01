import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib import cm
import numpy as np
import os, sys, glob
import argparse
from tqdm import tqdm
from scipy.optimize import curve_fit
import pandas as pd
import datetime
from collections import OrderedDict

def read_threshold_file(file_in, vfat):
    vfat_data = pd.read_csv(file_in, names=["vfatCH", "threshold", "ENC"], sep="    ", skiprows=[0,1], skipfooter=3, engine="python")
    vfat_data["vfatN"] = vfat
    return vfat_data

def pol1(x, a,b):
    y = a*x+b
    return (y)

def invertpol1(y, a,b):
    return (y-b)/a

def return_values(df):
    if(len(df)<2):
        return 0
    fit_params, pcov = curve_fit(pol1,df.trim_amp*2*(0.5-df.trim_pol),df.threshold)
    return np.rint(invertpol1(df.target.mean(),*fit_params)).astype(np.int32)

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Analyzing VFAT Channel Trimming")
    parser.add_argument("-nd", "--nom_res_dir", action="store", dest="nom_res_dir", help="Nominal SCurve result directory")
    parser.add_argument("-ud", "--up_res_dir", action="store", dest="up_res_dir", help="Trim Up SCurve result directory")
    parser.add_argument("-dd", "--down_res_dir", action="store", dest="down_res_dir", help="Trim Down SCurve result directory")
    args = parser.parse_args()

    nd_dir_name = args.nom_res_dir
    ud_dir_name = args.up_res_dir
    dd_dir_name = args.down_res_dir
    oh = args.nom_res_dir.split("/")[-1].split("_vfat")[0]

    resultDir = "results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    me0Dir = "results/vfat_data"
    try:
        os.makedirs(me0Dir) # create directory for ME0 lpGBT data
    except FileExistsError: # skip if directory already exists
        pass
    if "_sbit_" in nd_dir_name:
        dataDir = "results/vfat_data/vfat_sbit_trimming_results"
    else:
        dataDir = "results/vfat_data/vfat_daq_trimming_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    outfilename = ""
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    if "_sbit_" in nd_dir_name:
        outfilename = dataDir + "/" + oh + "_vfat_sbit_trimming_results_" + now + ".txt"
    else:
        outfilename = dataDir + "/" + oh + "_vfat_daq_trimming_results_" + now + ".txt"
    file_out = open(outfilename,"w+")
    file_out.write("VFAT    Channel    Trim_Amplitude    Trim_Polarity\n")

    nd_file_list = glob.glob(nd_dir_name+"/*.txt")
    ud_file_list = glob.glob(ud_dir_name+"/*.txt")
    dd_file_list = glob.glob(dd_dir_name+"/*.txt")
    n_nd_files = len(nd_file_list)
    n_ud_files = len(ud_file_list)
    n_dd_files = len(dd_file_list)

    if n_ud_files!=n_nd_files or n_dd_files!=n_nd_files:
        print ("Number of input files not equal for each trim setting")
        sys.exit()

    nominal_threshold_df_list = []
    up_threshold_df_list = []
    down_threshold_df_list = []
    count = 0

    for vfat_input_file in nd_file_list:
        filename = vfat_input_file.split("/")[-1]
        vfat = int(filename.split("_VFAT")[1].split(".txt")[0])
        nd_file_in = open(vfat_input_file, "r")
        try:
            ud_file_in = open(ud_dir_name+"/"+filename, "r")
        except:
            print ("Trim up file does not exist for VFAT %02d"%vfat)
            sys.exit()
        try:
            dd_file_in = open(dd_dir_name+"/"+filename, "r")
        except:
            print ("Trim down file does not exist for VFAT %02d"%vfat)
            sys.exit()

        nominal_threshold_df_list.append(read_threshold_file(nd_file_in, vfat))
        nominal_threshold_df_list[count]["trim_pol"] = 0
        nominal_threshold_df_list[count]["trim_amp"] = 0

        up_threshold_df_list.append(read_threshold_file(ud_file_in, vfat))
        up_threshold_df_list[count]["trim_pol"] = 0
        up_threshold_df_list[count]["trim_amp"] = 31

        down_threshold_df_list.append(read_threshold_file(dd_file_in, vfat))
        down_threshold_df_list[count]["trim_pol"] = 1
        down_threshold_df_list[count]["trim_amp"] = 31

        count += 1

        nd_file_in.close()
        ud_file_in.close()
        dd_file_in.close()

    nominal_threshold_df = pd.concat(nominal_threshold_df_list)
    up_threshold_df = pd.concat(up_threshold_df_list)
    down_threshold_df = pd.concat(down_threshold_df_list)
    threshold_df = pd.concat([nominal_threshold_df, up_threshold_df, down_threshold_df])

    threshold_df["target"] = threshold_df.groupby("vfatN").transform(lambda x: x.median())["threshold"]
    threshold_df["vfat_addr"] = threshold_df.vfatCH + 128*threshold_df.vfatN
    threshold_df["index"] = threshold_df.vfatCH + 128*threshold_df.vfatN
    threshold_df.set_index("index", inplace=True)

    sel = threshold_df.threshold == 0
    threshold_df1 = threshold_df[sel].copy()
    threshold_df1["val"] = 0
    threshold_df1["trim_pol_set"] = 0
    threshold_df1["trim_amp_set"] = 0

    sel = threshold_df.threshold > 0
    threshold_df2 = threshold_df[sel].copy()
    threshold_df2["val"] = threshold_df2.groupby("vfat_addr")[["threshold","target","trim_pol","trim_amp"]].apply(lambda x: return_values(x))
    threshold_df2["trim_pol_set"] = ((1-np.sign(threshold_df2["val"]))/2).astype(int)
    threshold_df2["trim_amp_set"] = np.clip(abs(threshold_df2["val"]), a_max=63, a_min=None)

    threshold_df = pd.concat([threshold_df1,threshold_df2])
    threshold_df = threshold_df.sort_values(by=['vfatN', 'vfatCH'])

    print (threshold_df)

    sel = threshold_df.trim_pol==0
    sel &= threshold_df.trim_amp==0
    for index,row in threshold_df[sel].iterrows():
        file_out.write("%i    %i    %i    %i\n"%(row["vfatN"], row["vfatCH"], row["trim_amp_set"], row["trim_pol_set"]))

    file_out.close()





