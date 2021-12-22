import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import numpy as np
import os, sys, glob
import argparse

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Plotting LPGBT EYE")
    parser.add_argument("-f", "--file", action="store", dest="file", help="input text file")
    parser.add_argument("-s", "--shift", action="store_true", dest="shift", help="if you want to shift the axis to put the eye opening in the center")
    args = parser.parse_args()

    if args.file is None:
        print ("Give a file for eye scan results")
        sys.exit()
    if not os.path.isfile(args.file):
        print ("Give a valid input text file")
        sys.exit()
    out_file = args.file.split(".txt")[0] + "_out.txt"
    plot_file = args.file.split(".txt")[0] + ".pdf"
    os.system("rm -rf %s %s"%(out_file, plot_file))

    eye_data_file = open(args.file)
    eye_data = []
    for line in eye_data_file.readlines():
        if "eye_data" in line:
            continue
        line = line.split("[")[1]
        if "]," in line:
            line = line.split("],")[0]
        elif "]]" in line:
            line = line.split("]]")[0]
        data_list = line.split(",")
        data_int =  []
        for data in data_list:
            data_int.append(int(data))
        eye_data.append(data_int)
    eye_data_file.close()

    n_total = 0
    n_open = 0
    for y in eye_data:
        n_total += len(y)
        for x in y:
            if x<10:
                n_open+=1
    frac_open = float(n_open)/float(n_total)
    print ("Fraction of eye open = " + str(frac_open) + "\n")
    file_output = open(out_file, "w")
    file_output.write("Fraction of eye open = " + str(frac_open) + "\n")
    file_output.close()

    eye_center = []
    size  = 0
    for y in eye_data:
        size = len(y)
        y2 = y + y
        left = -9999
        right  = -9999
        for i in range(0,len(y2)):
            if y2[i]>=10:
                if i!=(len(y2)-1) and y2[i+1]<10:
                    left = i+1
            if y2[i]<10:
                if left==-9999:
                    continue
                if i!=(len(y2)-1) and y2[i+1]>=10:
                    right = i
                    break
        center = int((left+right)/2)
        eye_center.append(center)
    eye_center_avg = 0
    n_center = 0
    for center in eye_center:
        if center != -9999:
            eye_center_avg += center
            n_center += 1
    eye_center_avg = int(eye_center_avg/n_center)
    if eye_center_avg>=len(y):
        eye_center_avg = eye_center_avg - len(y)
    shift = eye_center_avg - int(size/2)
        
    eye_data_mod = []
    for y in eye_data:
        y_mod = [0 for i in range(len(y))]
        for i in range(0,len(y_mod)):
            i_mod = i - shift
            if i_mod<0:
                i_mod = len(y_mod) + i_mod
            if i_mod>=len(y_mod):
                i_mod = i_mod - len(y_mod)
            y_mod[i_mod] = y[i]
        eye_data_mod.append(y_mod)

    eye_data_plot = eye_data
    if args.shift:
        eye_data_plot = eye_data_mod

    (fig, axs) = plt.subplots(1, 1, figsize=(10, 8))
    print ("fig type = " + str(type(fig)))
    print ("axs type = " + str(type(axs)))
    axs.set_title("LpGBT 2.56 Gbps RX Eye Opening Monitor")
    plot = axs.imshow(eye_data_plot, alpha=0.9, vmin=0, vmax=100, cmap="jet",interpolation="nearest", aspect="auto",extent=[-384.52/2,384.52/2,-0.6,0.6,])
    plt.xlabel("ps")
    plt.ylabel("volts")
    fig.colorbar(plot, ax=axs)
    plt.savefig(plot_file)
    print ("")
