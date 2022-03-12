import sys, os, glob
import time
import argparse
from gem.me0_lpgbt.rw_reg_lpgbt import *

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Testing Step 3 - VFAT DAQ and S-bit Tests")
    parser.add_argument("-s1", "--slot1", action="store", dest="slot1", help="slot1 = OH serial number on slot 1")
    parser.add_argument("-s2", "--slot2", action="store", dest="slot2", help="slot2 = OH serial number on slot 2")
    args = parser.parse_args()

    if args.slot1 is "None" or args.slot2 is None:
        print (Colors.YELLOW + "Enter OH serial numbers for both slot 1 and 2" + Colors.ENDC) 
        sys.exit()

    resultDir = "results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    me0Dir = "me0_lpgbt/oh_testing/results/OH_slot1_%s_slot2_%s"%(args.slot1, args.slot2)
    try:
        os.makedirs(me0Dir) # create directory for OH under test
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = me0Dir+"/step3_vfat_daq_sbit_tests"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    filename = dataDir + "/step_3_log.txt"
    logfile = open(filename, "w")
    
    oh_ver_slot1 = get_oh_ver("0", "0")
    oh_ver_slot2 = get_oh_ver("0", "2")
    
    print ("\n#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 1 - DAQ SCurve
    print (Colors.BLUE + "Step 1: DAQ SCurve\n" + Colors.ENDC)
    logfile.write("Step 1: DAQ SCurve\n\n")
    
    print (Colors.BLUE + "Running DAQ SCurves for all VFATs\n" + Colors.ENDC)
    logfile.write("Running DAQ SCurves for all VFATs\n\n")
    os.system("python3 vfat_daq_scurve.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -n 1000")
    list_of_files = glob.glob("results/vfat_data/vfat_daq_scurve_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    
    print (Colors.BLUE + "Plotting DAQ SCurves for all VFATs\n" + Colors.ENDC)
    logfile.write("Plotting DAQ SCurves for all VFATs\n\n")
    os.system("python3 plotting_scripts/vfat_analysis_scurve.py -c 0 -m voltage -f %s"%latest_file)
    latest_dir = latest_file.split(".txt")[0]
    if os.path.isdir(latest_dir):
        os.system("cp %s/scurve2Dhist_ME0_OH0.pdf %s/daq_scurve_2D_hist.pdf"%(latest_dir, dataDir))
        os.system("cp %s/scurveENCdistribution_ME0_OH0.pdf %s/daq_scurve_ENC.pdf"%(latest_dir, dataDir))
    else:
        print (Colors.RED + "DAQ Scurve result directory not found" + Colors.ENDC)
        logfile.write("DAQ SCurve result directory not found\n")    
    
    print (Colors.GREEN + "\nStep 1: DAQ SCurve Complete\n" + Colors.ENDC)
    logfile.write("\nStep 1: DAQ SCurve Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 2 - DAQ Crosstalk
    print (Colors.BLUE + "Step 2: DAQ Crosstalk\n" + Colors.ENDC)
    logfile.write("Step 2: DAQ Crosstalk\n\n")
    
    print (Colors.BLUE + "Running DAQ Crosstalk for all VFATs\n" + Colors.ENDC)
    logfile.write("Running DAQ Crosstalk for all VFATs\n\n")
    os.system("python3 vfat_daq_crosstalk.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -n 1000")
    logfile.close()
    list_of_files = glob.glob("results/vfat_data/vfat_daq_crosstalk_results/*_result.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cat %s >> %s"%(latest_file, filename))
    logfile = open(filename, "a")
    list_of_files = glob.glob("results/vfat_data/vfat_daq_crosstalk_results/*_data.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    
    print (Colors.BLUE + "Plotting DAQ Crosstalk for all VFATs\n" + Colors.ENDC)
    logfile.write("Plotting DAQ Crosstalk for all VFATs\n\n")
    os.system("python3 plotting_scripts/vfat_plot_crosstalk.py -f %s"%latest_file)
    latest_dir = latest_file.split(".txt")[0]
    if os.path.isdir(latest_dir):
        os.system("cp %s/crosstalk_ME0_OH0.pdf %s/daq_crosstalk.pdf"%(latest_dir, dataDir))
    else:
        print (Colors.RED + "DAQ Crosstalk result directory not found" + Colors.ENDC)
        logfile.write("DAQ Crosstalk result directory not found\n")    
    
    print (Colors.GREEN + "\nStep 2: DAQ Crosstalk Complete\n" + Colors.ENDC)
    logfile.write("\nStep 2: DAQ Crosstalk Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 3 - S-bit SCurve
    print (Colors.BLUE + "Step 3: S-bit SCurve\n" + Colors.ENDC)
    logfile.write("Step 3: S-bit SCurve\n\n")
    
    print (Colors.BLUE + "Running S-bit SCurves for all VFATs\n" + Colors.ENDC)
    logfile.write("Running S-bit SCurves for all VFATs\n\n")
    os.system("python3 me0_vfat_sbit_scurve.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -n 1000 -b 20 -l")
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_scurve_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    
    print (Colors.BLUE + "Plotting S-bit SCurves for all VFATs\n" + Colors.ENDC)
    logfile.write("Plotting S-bit SCurves for all VFATs\n\n")
    os.system("python3 plotting_scripts/vfat_analysis_scurve.py -c 0 -m current -f %s"%latest_file)
    latest_dir = latest_file.split(".txt")[0]
    if os.path.isdir(latest_dir):
        os.system("cp %s/scurve2Dhist_ME0_OH0.pdf %s/sbit_scurve_2D_hist.pdf"%(latest_dir, dataDir))
        os.system("cp %s/scurveENCdistribution_ME0_OH0.pdf %s/sbit_scurve_ENC.pdf"%(latest_dir, dataDir))
    else:
        print (Colors.RED + "S-bit Scurve result directory not found" + Colors.ENDC)
        logfile.write("S-bit SCurve result directory not found\n")    
    
    print (Colors.GREEN + "\nStep 3: S-bit SCurve Complete\n" + Colors.ENDC)
    logfile.write("\nStep 3: S-bit SCurve Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 4 - S-bit Crosstalk
    print (Colors.BLUE + "Step 4: S-bit Crosstalk\n" + Colors.ENDC)
    logfile.write("Step 4: S-bit Crosstalk\n\n")
    
    print (Colors.BLUE + "Running S-bit Crosstalk for all VFATs\n" + Colors.ENDC)
    logfile.write("Running S-bit Crosstalk for all VFATs\n\n")
    os.system("python3 me0_vfat_sbit_crosstalk.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -n 1000 -b 20 -l")
    logfile.close()
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_crosstalk_results/*_result.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    os.system("cat %s >> %s"%(latest_file, filename))
    logfile = open(filename, "a")
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_crosstalk_results/*_data.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    
    print (Colors.BLUE + "Plotting S-bit Crosstalk for all VFATs\n" + Colors.ENDC)
    logfile.write("Plotting S-bit Crosstalk for all VFATs\n\n")
    os.system("python3 plotting_scripts/vfat_plot_crosstalk.py -f %s"%latest_file)
    latest_dir = latest_file.split(".txt")[0]
    if os.path.isdir(latest_dir):
        os.system("cp %s/crosstalk_ME0_OH0.pdf %s/sbit_crosstalk.pdf"%(latest_dir, dataDir))
    else:
        print (Colors.RED + "S-bit Crosstalk result directory not found" + Colors.ENDC)
        logfile.write("S-bit Crosstalk result directory not found\n")    
    
    print (Colors.GREEN + "\nStep 4: S-bit Crosstalk Complete\n" + Colors.ENDC)
    logfile.write("\nStep 4: S-bit Crosstalk Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")
    
    # Step 5 - S-bit Noise Rate
    print (Colors.BLUE + "Step 5: S-bit Noise Rate\n" + Colors.ENDC)
    logfile.write("Step 5: S-bit Noise Rate\n\n")
    
    print (Colors.BLUE + "Running S-bit Noise Rate for all VFATs\n" + Colors.ENDC)
    logfile.write("Running S-bit Noise Rate for all VFATs\n\n")
    os.system("python3 me0_vfat_sbit_noise_rate.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -z")
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_noise_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    
    print (Colors.BLUE + "Plotting S-bit Noise Rate for all VFATs\n" + Colors.ENDC)
    logfile.write("Plotting S-bit Noise Rate for all VFATs\n\n")
    os.system("python3 plotting_scripts/vfat_plot_sbit_noise_rate.py -f %s"%latest_file)
    latest_dir = latest_file.split(".txt")[0]
    if os.path.isdir(latest_dir):
        if os.path.isdir(dataDir + "/sbit_noise_rate_results"):
            os.system("rm -rf " + dataDir + "/sbit_noise_rate_results")
        os.makedirs(dataDir + "/sbit_noise_rate_results")
        os.system("cp %s/*_mean_*.pdf %s/sbit_noise_rate_mean.pdf"%(latest_dir, dataDir))
        os.system("cp %s/*_or_*.pdf %s/sbit_noise_rate_or.pdf"%(latest_dir, dataDir))
        os.system("cp %s/2d*.pdf %s/sbit_2d_threshold_noise_rate.pdf"%(latest_dir, dataDir))
        os.system("cp %s/*_channels_*.pdf %s/sbit_noise_rate_results/"%(latest_dir, dataDir))
    else:
        print (Colors.RED + "S-bit Noise Rate result directory not found" + Colors.ENDC)
        logfile.write("S-bit Noise Rate result directory not found\n")    
    
    print (Colors.GREEN + "\nStep 5: S-bit Noise Rate Complete\n" + Colors.ENDC)
    logfile.write("\nStep 5: S-bit Noise Rate Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 6 - S-bit Cluster SCurve
    print (Colors.BLUE + "Step 6: S-bit Cluster SCurve\n" + Colors.ENDC)
    logfile.write("Step 6: S-bit Cluster SCurve\n\n")
    
    print (Colors.BLUE + "Running S-bit Cluster SCurves for all VFATs\n" + Colors.ENDC)
    logfile.write("Running S-bit Cluster SCurves for all VFATs\n\n")
    os.system("python3 vfat_sbit_cluster_scurve.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -n 1000 -b 20 -l")
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_cluster_scurve_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    
    print (Colors.BLUE + "Plotting S-bit Cluster SCurves for all VFATs\n" + Colors.ENDC)
    logfile.write("Plotting S-bit Cluster SCurves for all VFATs\n\n")
    os.system("python3 plotting_scripts/vfat_analysis_scurve.py -c 0 -m current -f %s"%latest_file)
    latest_dir = latest_file.split(".txt")[0]
    if os.path.isdir(latest_dir):
        os.system("cp %s/scurve2Dhist_ME0_OH0.pdf %s/sbit_cluster_scurve_2D_hist.pdf"%(latest_dir, dataDir))
        os.system("cp %s/scurveENCdistribution_ME0_OH0.pdf %s/sbit_cluster_scurve_ENC.pdf"%(latest_dir, dataDir))
    else:
        print (Colors.RED + "S-bit Cluster Scurve result directory not found" + Colors.ENDC)
        logfile.write("S-bit Cluster SCurve result directory not found\n")    
    
    print (Colors.GREEN + "\nStep 6: S-bit Cluster SCurve Complete\n" + Colors.ENDC)
    logfile.write("\nStep 6: S-bit Cluster SCurve Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    # Step 7 - S-bit Cluster Noise Rate
    print (Colors.BLUE + "Step 7: S-bit Cluster Noise Rate\n" + Colors.ENDC)
    logfile.write("Step 7: S-bit Cluster Noise Rate\n\n")
    
    print (Colors.BLUE + "Running S-bit Cluster Noise Rate for all VFATs\n" + Colors.ENDC)
    logfile.write("Running S-bit Cluster Noise Rate for all VFATs\n\n")
    os.system("python3 vfat_sbit_cluster_noise_rate.py -s backend -q ME0 -o 0 -v 0 1 2 3 8 9 10 11 16 17 18 19 -x -z")
    list_of_files = glob.glob("results/vfat_data/vfat_sbit_cluster_noise_results/*.txt")
    latest_file = max(list_of_files, key=os.path.getctime)
    
    print (Colors.BLUE + "Plotting S-bit Cluster Noise Rate for all VFATs\n" + Colors.ENDC)
    logfile.write("Plotting S-bit Cluster Noise Rate for all VFATs\n\n")
    os.system("python3 plotting_scripts/vfat_plot_sbit_cluster_noise_rate.py -f %s"%latest_file)
    latest_dir = latest_file.split(".txt")[0]
    if os.path.isdir(latest_dir):
        os.system("cp %s/*_total_*.pdf %s/sbit_cluster_noise_rate_total.pdf"%(latest_dir, dataDir))
        os.system("cp %s/2d*.pdf %s/sbit_cluster_2d_threshold_noise_rate.pdf"%(latest_dir, dataDir))
    else:
        print (Colors.RED + "S-bit Cluster Noise Rate result directory not found" + Colors.ENDC)
        logfile.write("S-bit Cluster Noise Rate result directory not found\n")    
    
    print (Colors.GREEN + "\nStep 7: S-bit Cluster Noise Rate Complete\n" + Colors.ENDC)
    logfile.write("\nStep 7: S-bit Cluster Noise Rate Complete\n\n")
    print ("#####################################################################################################################################\n")
    logfile.write("#####################################################################################################################################\n\n")

    logfile.close()
    os.system("rm -rf out.txt")






