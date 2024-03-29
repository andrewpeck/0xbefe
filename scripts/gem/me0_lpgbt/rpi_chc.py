#!/usr/bin/env python3
import os, sys
import math
import shutil, subprocess
import RPi.GPIO as GPIO
import smbus
import spidev
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
        # Set up SPI
        self.spi = spidev.SpiDev()
        self.spi.open(0,0) # bus 0 device 0 - default
        self.spi.max_speed_hz = 1000000 # 1 MHz
        self.spi.mode = 1
        
        # Addresses
        self.reset_channel = 17
        self.i2c_switch_addr = 0x73  # 01110011
        self.lpgbt_address = 0
        self.config_channel = 0
        self.efuse_pwr_boss = 0
        self.efuse_pwr_sub = 0

        self.current_oh_1v2_addr = 0x40
        self.current_oh_2v5_addr = 0x42
        self.current_fpga_1v35_addr = 0x40
        self.current_fpga_2v5_addr = 0x42

        self.fpga_cs_1 = 20
        self.fpga_cs_2 = 16
        self.fpga_cs_3 = 12

    def __del__(self):
        self.bus.close()
        self.spi.close() 
        #GPIO.cleanup()
  
    def set_lpgbt_address(self, board, oh_ver, boss):
        if oh_ver == 1:
            self.lpgbt_address = 0x70
        elif oh_ver == 2:
            if boss:
                self.lpgbt_address = 0x70
            else:
                self.lpgbt_address = 0x71
        
        if board == "chc":
            if boss:
                self.config_channel = 13
            else:
                self.config_channel = 26
            self.efuse_pwr_boss = 12
            self.efuse_pwr_sub = 19
        elif board == "queso":
            if boss:
                self.config_channel = 21
            else:
                self.config_channel = 19
            self.efuse_pwr_boss = 26
            self.efuse_pwr_sub = 13

    def init_gpio(self, gpio, state):
        init_success = 0
        try: 
            if state == "out":
                GPIO.setup(gpio, GPIO.OUT)
                init_success = 1
            elif state == "in":
                GPIO.setup(gpio, GPIO.IN)
                init_success = 1
            else:
                print (Colors.RED + "ERROR: Invalid GPIO state" + Colors.ENDC)
        except:
            print (Colors.RED + "ERROR: Unable to setup GPIO" + Colors.ENDC)
        return init_success

    def gpio_action(self, operation, gpio, value = -9999):
        read = -9999
        if operation not in ["read", "write"]:
            return read
        if operation == "read":
            if value != -9999:
                return read
            GPIO.setup(gpio, GPIO.IN)
            time.sleep(0.1)
            read = GPIO.input(gpio)
        elif operation == "write":
            if value == -9999:
                return read
            GPIO.setup(gpio, GPIO.OUT)
            time.sleep(0.1)
            GPIO.output(gpio, value)
            read = 0
        return read
    
    def fpga_spi_cs(self, gpio, enable):
        #self.spi.close() 
        #self.spi.open(0,1) # bus 0 device 1 - unused
        if enable == 1:
            self.spi.no_cs = True
        else:
            self.spi.no_cs = False
        spi_success = 0
        try:
            read = self.gpio_action("write", gpio, enable)
            if read != -9999:
                print("    Chip Select set for FPGA for Pin : " + str(gpio) + " to %d"%enable + "\n")
                spi_success = 1
        except:
            print(Colors.RED + "ERROR: Unable to set chip select for FPGA, check RPi connection" + Colors.ENDC)
        return spi_success

    def config_select(self):
        # Setting GPIO 13/26 high, connected to config_select enabling I2C
        config_success = 0
        try:
            read = self.gpio_action("write", self.config_channel, 1)
            if read != -9999:
                print("Config Select set to I2C for Pin : " + str(self.config_channel) + "\n")
                config_success = 1
        except:
            print(Colors.RED + "ERROR: Unable to set config select, check RPi connection" + Colors.ENDC)
        return config_success

    def en_i2c_switch(self):
        # Setting GPIO17 to High to disable Reset for I2C switch
        reset_success = 0
        try:
            read = self.gpio_action("write", self.reset_channel, 1)
            if read != -9999:
                print("GPIO17 set to high, can now select channels in I2C Switch")
                reset_success = 1
        except:
            print(Colors.RED + "ERROR: Unable to disable reset, check RPi connection" + Colors.ENDC)
        return reset_success

    def i2c_channel_sel(self, boss, current_monitor=None):
        # Select the boss or sub channel in I2C Switch
        channel_sel_success = 0
        try:
            if current_monitor is not None:
                if current_monitor == "oh":
                    self.bus.write_byte(self.i2c_switch_addr, 0x04)
                    print("Channel for OH current monitor selected")
                elif current_monitor == "fpga":
                    self.bus.write_byte(self.i2c_switch_addr, 0x08)
                    print("Channel for FPGA current monitor selected")
                else:
                    print(Colors.RED + "ERROR: Current Monitor name for QUESO incorrect, only allowed: oh, fpga" + Colors.ENDC)
                    return channel_sel_success
            else:
                if boss:
                    self.bus.write_byte(self.i2c_switch_addr, 0x01)
                    print("Channel for Boss selected")
                else:
                    self.bus.write_byte(self.i2c_switch_addr, 0x02)
                    print("Channel for Sub selected")
            channel_sel_success = 1
        except:
            print(Colors.RED + "ERROR: Channel for Current Monitors or Boss/Sub in I2C Switch could not be selected, check RPi or I2C Switch on Cheesecake" + Colors.ENDC)
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
        # Setting GPIO17 to Low to deselect all channels for I2C switch
        reset_success = 0
        try:
            read = self.gpio_action("write", self.reset_channel, 0)
            if read != -9999:
                print("GPIO17 set to low, deselect both channels in I2C Switch")
                reset_success = 1
        except:
            print(Colors.RED + "ERROR: Unable to enable reset, check RPi connection" + Colors.ENDC)

        # Setting config_select enabling I2C to low
        config_success = 0
        if self.config_channel != 0:
            try:
                read = self.gpio_action("write", self.config_channel, 0)
                if read != -9999:
                    print("GPIO %d (config select) set to low"%self.config_channel)
                    config_success = 1
            except:
                print(Colors.RED + "ERROR: Unable to set GPIO %d to low, check RPi connection"%self.config_channel + Colors.ENDC)
        else:
            config_success = 1

        return reset_success * config_success

    def gpio_terminate(self):
        GPIO.cleanup()

    def current_monitor_write(self, monitor, value):
        # Write to current monitor using I2C
        success = 1
        monitor_address = 0
        if monitor == "oh_1v2":
            monitor_address = self.current_oh_1v2_addr
        elif monitor == "oh_2v5":
            monitor_address = self.current_oh_2v5_addr
        elif monitor == "fpga_1v35":
            monitor_address = self.current_fpga_1v35_addr
        elif monitor == "fpga_2v5":
            monitor_address = self.current_fpga_2v5_addr
        else:
            print(Colors.RED + "ERROR: Incorrect current monitor name" + Colors.ENDC)   
            success = 0
            return success
        
        try:
            self.bus.write_i2c_block_data(monitor_address, 0x00, [0, value])
        except IOError:
            print(Colors.YELLOW + "ERROR: I/O error in I2C connection, Trying again" + Colors.ENDC)
            time.sleep(0.00001)
            try:
                self.bus.write_i2c_block_data(monitor_address, 0x00, [0, value])
            except IOError:
                print(Colors.RED + "ERROR: I/O error in I2C connection, check RPi connection" + Colors.ENDC)
                success = 0
        except Exception as e:
            print(Colors.RED + "ERROR: " + str(e) + Colors.ENDC)
            success = 0
        return success

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
  
    def spi_rw(self, fpga=None, address=None, data=None):
        # Perform SPI read/write operations
        spi_data = 0
        spi_success = 1

        gpio = 0
        if fpga is not None:
            if fpga == "1":
                gpio = self.fpga_cs_1
            elif fpga == "2":
                gpio = self.fpga_cs_2
            elif fpga == "3":
                gpio = self.fpga_cs_3
            else:
                spi_success = 0
                print(Colors.RED + "ERROR: Incorrect FPGA number" + Colors.ENDC)
                return spi_success, spi_data

            # Enable corresponding chip select
            spi_success = self.fpga_spi_cs(gpio, 1)
            if not spi_success:
                print(Colors.RED + "ERROR: Cannot enable SPI Chip Select GPIO" + Colors.ENDC)
                return spi_success, spi_data
            time.sleep(0.1)

        # Perform the read/write
        command = []
        spi_success = 1
        if fpga is not None:
            if address is None:
                print(Colors.RED + "ERROR: Invalid Register Address" + Colors.ENDC)
                spi_success = 0
                return spi_success, spi_data
            if data is None: # read
                data = [0x00]
            else: # write
                address += 0x01
            command = [address]
            for d in data:
                command.append(d)
        else:
            command = data

        try:
            spi_data = self.spi.xfer2(command)
        except IOError:
            print(Colors.YELLOW + "ERROR: I/O error in SPI connection, Trying again" + Colors.ENDC)
            time.sleep(0.00001)
            try:
                spi_data = self.spi.xfer2(command)
            except IOError:
                print(Colors.RED + "ERROR: I/O error in SPI connection, Trying again" + Colors.ENDC)
                spi_success = 0
        except Exception as e:
            print(Colors.RED + "ERROR: " + str(e) + Colors.ENDC)
            spi_success = 0
        if not spi_success:
            return spi_success, spi_data
        time.sleep(0.1)

        if fpga is not None:
        # Disable corresponding chip select
            spi_success = 1
            spi_success = self.fpga_spi_cs(gpio, 0)
            if not spi_success:
                print(Colors.RED + "ERROR: Cannot disable SPI Chip Select GPIO" + Colors.ENDC)
                return spi_success, spi_data
            time.sleep(0.1)

        return spi_success, spi_data

    def fuse_arm_disarm(self, boss, enable):
        # Given selection of Boss or Sub, drives LDO for EFUSE at 2.5V
        efuse_pwr = 0
        if boss:
            efuse_pwr = self.efuse_pwr_boss
        else:
            efuse_pwr = self.efuse_pwr_sub

        efuse_success = 0
        if enable not in [0,1]:
            print(Colors.RED + "ERROR: Unable to arm/disarm fuse, invalid option" + Colors.ENDC)
            return efuse_success
        try:
            read = self.gpio_action("write", efuse_pwr, enable)
            if read != -9999:
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
            efuse_pwr = self.efuse_pwr_boss
        else:
            efuse_pwr = self.efuse_pwr_sub

        efuse_success = 0
        status = 0
        try:
            read = self.gpio_action("read", efuse_pwr)
            if read != -9999:
                status = read
                efuse_success = 1
        except:
            print(Colors.RED + "ERROR: Unable to check status of fuse, check RPi connection" + Colors.ENDC)
        return efuse_success, status




