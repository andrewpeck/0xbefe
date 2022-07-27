import sys, os, glob
import math
import argparse
import time
import collections
import shutil, subprocess
import RPi.GPIO as GPIO
import smbus

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Control the VOA attenuation')
    parser.add_argument("-r", "--reset", action="store_true", dest="reset", help="reset = to send a reset")
    parser.add_argument("-c", "--attenuation_check", action="store_true", dest="attenuation_check", help="attenuation_check = only check the current attenuation rate, return in dB")
    parser.add_argument("-a", "--attenuation", action="store", dest="attenuation", help="attenuation = give value in dB")
    parser.add_argument("-l", "--wavelength", action="store", dest="wavelength", help="wavelength = index 0, 1, 2, 3")
    args = parser.parse_args()

    # Setting the pin numbering scheme
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)

    '''''
    # Setting GPIO17 to High to disable Reset for I2C switch
    reset_channel = 17
    GPIO.setup(reset_channel, GPIO.OUT)
    GPIO.output(reset_channel, 1)
    print ("GPIO17 set to high, can now select channels in I2C Switch")
    '''''

    # Set up the I2C bus 
    device_bus = 1 # for SDA1 and SCL1 
    bus = smbus.SMBus(device_bus)

    '''''
    # Select the slave address for I2C Switch
    i2c_switch_addr = 0x73 # 01110011

    # Control Register for channel selection in I2C Switch
    ctrl_reg = {}
    ctrl_reg["Boss"] = 0x01 # 00000001
    ctrl_reg["Sub"] = 0x02 # 00000010
    bus.write_byte(i2c_switch_addr, ctrl_reg["Boss"])
    '''''

    # VOA
    device_addr = 0x49
    reset_addr = 0x32
    query_wavelength_index_addr = 0x78
    set_wavelength_index_addr = 0x79
    query_wavelength_addr = 0x89
    query_min_attenuation_addr = 0x82
    query_max_attenuation_addr = 0x83
    set_attenuation_addr = 0x80
    query_attenuation_addr = 0x81

    # Reset VOA
    if args.reset:
        bus.write_i2c_block_data(device_addr, reset_addr, [0x96, 0xA2])
        time.sleep(5)

    # Read and set basic registers
    wavelength_index = bus.read_i2c_block_data(device_addr, query_wavelength_index_addr, 1)[0]
    print ("Wavelength index = %d"%wavelength_index)
    if args.wavelength is not None:
        if int(args.wavelength) not in [0, 1, 2, 3]:
            print ("Wavelength index has to be either 0, 1, 2, or 3")
            sys.exit()
        print ("Setting Wavelength index = %d"%int(args.wavelength))
        bus.write_i2c_block_data(device_addr, set_wavelength_index_addr, [int(args.wavelength)])
        time.sleep(0.1)
        wavelength_index = bus.read_i2c_block_data(device_addr, query_wavelength_index_addr, 1)[0]
        print ("Wavelength index = %d"%wavelength_index)
    wavelength_data = bus.read_i2c_block_data(device_addr, query_wavelength_addr, 2)
    wavelength = wavelength_data[0]<<8 | wavelength_data[1]
    print ("Current working wavelength = %d nm"%wavelength)
    print("")

    min_attenuation_data = bus.read_i2c_block_data(device_addr, query_min_attenuation_addr, 2)
    max_attenuation_data = bus.read_i2c_block_data(device_addr, query_max_attenuation_addr, 2)
    min_attenuation = (min_attenuation_data[0]<<8 | min_attenuation_data[1])/100.0
    max_attenuation = (max_attenuation_data[0]<<8 | max_attenuation_data[1])/100.0
    print ("Minimum attenuation = %.2f dB"%min_attenuation)
    print ("Maximum attenuation = %.2f dB"%max_attenuation)
    print("")

    # Read or Set Attenuation
    current_attenuation_data = bus.read_i2c_block_data(device_addr, query_attenuation_addr, 2)
    current_attenuation = (current_attenuation_data[0]<<8 | current_attenuation_data[1])/100.0
    print("Current attenuation: %.2f dB ([0x%02X, 0x%02X])"%(current_attenuation, current_attenuation_data[0], current_attenuation_data[1]))
    print("")

    if not args.attenuation_check:
        if float(args.attenuation) is None:
            print ("Give a value of attenuation to set")
            sys.exit()
        set_att = float(args.attenuation)
        if (set_att > max_attenuation) or (set_att < min_attenuation):
            print ("Attenuation must be between %.2f dB and %.2f dB"%(min_attenuation, max_attenuation))
            sys.exit()
        print("Setting attenuation: %.2f dB"%set_att)

        set_att = int(set_att*100)
        data_array = []
        data_array.append((set_att & 0xFF00) >> 8)
        data_array.append(set_att & 0xFF)    
        print("Writing data: [0x%02X, 0x%02X]"%(data_array[0], data_array[1]))
        bus.write_i2c_block_data(device_addr, set_attenuation_addr, data_array)
        time.sleep(1)
        
        current_attenuation_data = bus.read_i2c_block_data(device_addr, query_attenuation_addr, 2)
        current_attenuation = (current_attenuation_data[0]<<8 | current_attenuation_data[1])/100.0
        print("Current attenuation: %.2f dB ([0x%02X, 0x%02X])"%(current_attenuation, current_attenuation_data[0], current_attenuation_data[1]))
        print("")

    ''''
    # Setting GPIO17 to Low to deselect both channels for I2C switch
    GPIO.output(reset_channel, 0)
    print ("GPIO17 set to low, deselect both channels in I2C Switch")
    ''''

    # Cleanup
    bus.close()
    GPIO.cleanup()





