#!/usr/bin/env python3
import os, sys
import math
import shutil, subprocess
import RPi.GPIO as GPIO
import smbus
import time

class Colors:
    WHITE   = "\033[97m"
    CYAN    = "\033[96m"
    MAGENTA = "\033[95m"
    BLUE    = "\033[94m"
    YELLOW  = "\033[93m"
    GREEN   = "\033[92m"
    RED     = "\033[91m"
    ENDC    = "\033[0m"
    
class rpi_chc:
    # Raspberry CHeeseCake interface for I2C
    def __init__(self):
        # Setting the pin numbering scheme
        GPIO.setmode(GPIO.BCM)
        GPIO.setwarnings(False)
        # Set up the I2C bus
        device_bus = 1  # for SDA1 and SCL1
        self.bus = smbus.SMBus(device_bus)
        self.lpgbt_address = 0

    def __del__(self):
        self.bus.close()
        GPIO.cleanup()

    def set_lpgbt_address(self, oh_ver, boss):
        if oh_ver == 1:
            self.lpgbt_address = 0x70
        elif oh_ver == 2:
            if boss:
                self.lpgbt_address = 0x70
            else:
                self.lpgbt_address = 0x71

    def config_select(self, boss):
        # Setting GPIO 13/26 high, connected to config_select enabling I2C
        config_channel = 0
        if boss:
            config_channel = 13
        else:
            config_channel = 26

        config_success = 0
        try:
            GPIO.setup(config_channel, GPIO.OUT)
            GPIO.output(config_channel, 1)
            print("Config Select set to I2C for Pin : " + str(config_channel) + "\n")
            config_success = 1
        except:
            print(Colors.RED + "ERROR: Unable to set config select, check RPi connection" + Colors.ENDC)
        return config_success

    def en_i2c_switch(self):
        # Setting GPIO17 to High to disable Reset for I2C switch
        reset_channel = 17
        reset_success = 0
        try:
            GPIO.setup(reset_channel, GPIO.OUT)
            GPIO.output(reset_channel, 1)
            print("GPIO17 set to high, can now select channels in I2C Switch")
            reset_success = 1
        except:
            print(Colors.RED + "ERROR: Unable to disable reset, check RPi connection" + Colors.ENDC)
        return reset_success

    def i2c_channel_sel(self, boss):
        # Select the boss or sub channel in I2C Switch
        i2c_switch_addr = 0x73  # 01110011
        channel_sel_success = 0
        try:
            if boss:
                self.bus.write_byte(i2c_switch_addr, 0x01)
                print("Channel for Boss selected")
            else:
                self.bus.write_byte(i2c_switch_addr, 0x02)
                print("Channel for Sub selected")
            channel_sel_success = 1
        except:
            print(Colors.RED + "ERROR: Channel for Boss/Sub in I2C Switch could not be selected, check RPi or I2C Switch on Cheesecake" + Colors.ENDC)
        return channel_sel_success

    def i2c_device_scan(self):
        # Scans all possible I2C addresses for connected devices
        for device in range(128):
            try:
                self.bus.read_byte(device)
                print("I2C device found at: " + str(hex(device)))
            except:  # exception if read_byte fails
                pass

    def terminate(self):
        # Setting GPIO17 to Low to deselect both channels for I2C switch
        reset_channel = 17
        reset_success = 0
        try:
            GPIO.output(reset_channel, 0)
            print("GPIO17 set to low, deselect both channels in I2C Switch")
            reset_success = 1
        except:
            print(Colors.RED + "ERROR: Unable to enable reset, check RPi connection" + Colors.ENDC)

        # Setting GPIO 13 and 26 low, connected to config_select enabling I2C
        config_channel = 13
        config_success_13 = 0
        try:
            GPIO.setup(config_channel, GPIO.OUT)
            GPIO.output(config_channel, 0)
            print("GPIO 13 (config select) set to low")
            config_success_13 = 1
        except:
            print(Colors.RED + "ERROR: Unable to set GPIO 13 to low, check RPi connection" + Colors.ENDC)

        config_channel = 26
        config_success_26 = 0
        try:
            GPIO.setup(config_channel, GPIO.OUT)
            GPIO.output(config_channel, 0)
            print("GPIO 26 (config select) set to low")
            config_success_26 = 1
        except:
            print(Colors.RED + "ERROR: Unable to set GPIO 26 to low, check RPi connection" + Colors.ENDC)

        return reset_success * config_success_13 * config_success_26

    def lpgbt_write_register(self, register, value):
        # Write to the LpGBT register given an address and value using I2C
        reg_add_l = register & 0xFF
        reg_add_h = (register >> 8) & 0xFF
        success = 1
        try:
            self.bus.write_i2c_block_data(self.lpgbt_address, reg_add_l, [reg_add_h, value])
        except IOError:
            print(Colors.YELLOW + "ERROR: I/O error in I2C connection for register: " + str(hex(register)) + ", Trying again" + Colors.ENDC)
            time.sleep(0.00001)
            try:
                self.bus.write_i2c_block_data(self.lpgbt_address, reg_add_l, [reg_add_h, value])
            except IOError:
                print(Colors.RED + "ERROR: I/O error in I2C connection again, check RPi or CHC connection" + Colors.ENDC)
                success = 0
        except Exception as e:
            print(Colors.RED + "ERROR: " + str(e) + Colors.ENDC)
            success = 0
        return success

    def lpgbt_read_register(self, register):
        # Read the LpGBT register given an address
        reg_add_l = register & 0xFF
        reg_add_h = (register >> 8) & 0xFF
        data = 0
        success = 1

        try:
            self.bus.write_i2c_block_data(self.lpgbt_address, reg_add_l, [reg_add_h])
        except IOError:
            print(Colors.YELLOW + "ERROR: I/O error in I2C connection for register: " + str(hex(register)) + ", Trying again" + Colors.ENDC)
            time.sleep(0.00001)
            try:
                self.bus.write_i2c_block_data(self.lpgbt_address, reg_add_l, [reg_add_h])
            except IOError:
                print(Colors.RED + "ERROR: I/O error in I2C connection again, check RPi or CHC connection" + Colors.ENDC)
                success = 0
        except Exception as e:
            print(Colors.RED + "ERROR: " + str(e) + Colors.ENDC)
            success = 0
        if not success:
            return success, data

        try:
            data = self.bus.read_byte(self.lpgbt_address)
        except IOError:
            print(Colors.YELLOW + "ERROR: I/O error in I2C connection for register: " + str(hex(register)) + ", Trying again" + Colors.ENDC)
            time.sleep(0.00001)
            try:
                data = self.bus.read_byte(self.lpgbt_address)
            except IOError:
                print(Colors.RED + "ERROR: I/O error in I2C connection again, check RPi or CHC connection" + Colors.ENDC)
                success = 0
        except Exception as e:
            print(Colors.RED + "ERROR: " + str(e) + Colors.ENDC)
            success = 0

        return success, data

    def fuse_arm_disarm(self, boss, enable):
        # Given selection of Boss or Sub, drives LDO for EFUSE at 2.5V
        efuse_pwr = 0
        if boss:
            efuse_pwr = 12
        else:
            efuse_pwr = 19

        efuse_success = 0
        if enable not in [0,1]:
            print(Colors.RED + "ERROR: Unable to arm/disarm fuse, invalid option" + Colors.ENDC)
            return efuse_success
        try:
            GPIO.setup(efuse_pwr, GPIO.OUT)
            GPIO.output(efuse_pwr, enable)
            if enable:
                print("GPIO" + str(efuse_pwr) + "set to high, EFUSE ARMED")
            else:
                print("GPIO" + str(efuse_pwr) + "set to low, EFUSE DISARMED")
            efuse_success = 1
        except:
            print(Colors.RED + "ERROR: Unable to arm/disarm fuse, check RPi connection" + Colors.ENDC)
        return efuse_success

    def fuse_status(self, boss):
        # Return the status of the EFUSE GPIO
        efuse_pwr = 0
        if boss:
            efuse_pwr = 12
        else:
            efuse_pwr = 19

        efuse_success = 0
        status = 0
        try:
            GPIO.setup(efuse_pwr, GPIO.IN)
            status = GPIO.input(efuse_pwr)
            efuse_success = 1
        except:
            print(Colors.RED + "ERROR: Unable to check status of fuse, check RPi connection" + Colors.ENDC)
        return efuse_success, status




