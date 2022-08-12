from turtle import color
import pandas as pd
import glob
import os
import matplotlib.pyplot as plt
import argparse

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='Plot the currents of OH and FPGA')
    parser.add_argument("-f", "--filename", action="store", dest="filename", help="filename = data filename")
    args = parser.parse_args()

    df = pd.read_csv(args.filename)
    plt.plot(df.oh_1v2, label = 'oh_1v2', color = 'blue')
    plt.plot(df.oh_2v5, label = 'oh_2v5', color = 'red')
    plt.plot(df.fpga_1v35, label = 'fpga_1v35', color = 'green')
    plt.plot(df.fpga_2v5, label = 'fpga_2v5', color = 'yellow')
    plt.title('Current v.s. Time')
    plt.xlabel('Time (30s)')
    plt.ylabel('Current (Amp)')
    plt.legend()
    plt.savefig(latest_file[:len(latest_file)-4] + '_image.png')


