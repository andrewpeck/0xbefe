from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import time, sleep
import sys
import os
import argparse

vtrx_slave_addr = 0x50

# VTRX+ registers
TX_reg = {}
TX_reg["TX1"] = { "biascur_reg": 0x03, "modcur_reg":0x04, "empamp_reg":0x05}
TX_reg["TX2"] = { "biascur_reg": 0x06, "modcur_reg":0x07, "empamp_reg":0x08}
TX_reg["TX3"] = { "biascur_reg": 0x09, "modcur_reg":0x0A, "empamp_reg":0x0B}
TX_reg["TX4"] = { "biascur_reg": 0x0C, "modcur_reg":0x0D, "empamp_reg":0x0E}

enable_reg = 0x00
TX_enable_bit = {}
TX_enable_bit["TX1"] = 0
TX_enable_bit["TX2"] = 1
TX_enable_bit["TX3"] = 2
TX_enable_bit["TX4"] = 3

i2c_master_timeout = 1 # 1s

def i2cmaster_write(system, reg_addr, data):

    # Writing control register of I2CMaster 2
    nbytes = 2
    control_register_data = nbytes<<2 | 0 # using 100 kHz
    writeReg(getNode("LPGBT.RW.I2C.I2CM2DATA0"), control_register_data, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2CMD"), 0x0, 0) # I2C_WRITE_CR
    
    # Writing multi byte data to I2CMaster 2
    writeReg(getNode("LPGBT.RW.I2C.I2CM2DATA0"), reg_addr, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2DATA1"), data, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2CMD"), 0x8, 0) # I2C_W_MULTI_4BYTE0
    
    writeReg(getNode("LPGBT.RW.I2C.I2CM2ADDRESS"), vtrx_slave_addr, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2CMD"), 0xC, 0) # I2C_WRITE_MULTI
    
    success=0
    t0 = time()
    while(success==0):
        # Status register of I2CMaster 2
        if system!="dryrun" and system!="backend":
            status = readReg(getNode("LPGBT.RO.I2CREAD.I2CM2STATUS"))
        else:
            status = 0x04
        if (status>>6) & 0x1:
            print (Colors.RED + "ERROR: Last transaction was not acknowledged by the I2C slave" + Colors.ENDC)
            rw_terminate()
        elif (status>>3) & 0x1:
            print (Colors.RED + "ERROR: I2C master port finds that the SDA line is pulled low 0 before initiating a transaction. Indicates a problem with the I2C bus." + Colors.ENDC)
            rw_terminate()
        success = (status>>2) & 0x1
        if int(round((time() - t0))) > i2c_master_timeout:
            print (Colors.RED + "ERROR: I2C master timeout" + Colors.ENDC)
            rw_terminate()

    reg_addr_string = "0x%02X" % (reg_addr)
    data_string = "0x%02X" % (data)
    print ("Successful I2C write to slave register: " + reg_addr_string + ", data: " + data_string + " (" + "{0:08b}".format(data) + ")")

    # Reset the I2C Master registers
    writeReg(getNode("LPGBT.RW.I2C.I2CM2DATA0"), 0x00, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2DATA1"), 0x00, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2ADDRESS"), 0x00, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2CMD"), 0x00, 0)


def i2cmaster_read(system, reg_addr):

    # Writing control register of I2CMaster 2
    nbytes = 1
    control_register_data = nbytes<<2 | 0 # using 100 kHz
    writeReg(getNode("LPGBT.RW.I2C.I2CM2DATA0"), control_register_data, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2CMD"), 0x0, 0) # I2C_WRITE_CR

    # Writing register address to I2CMaster 2
    writeReg(getNode("LPGBT.RW.I2C.I2CM2DATA0"), reg_addr, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2CMD"), 0x8, 0) # I2C_W_MULTI_4BYTE0

    writeReg(getNode("LPGBT.RW.I2C.I2CM2ADDRESS"), vtrx_slave_addr, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2CMD"), 0xC, 0) # I2C_WRITE_MULTI

    success=0
    t0 = time()
    while(success==0):
        # Status register of I2CMaster 2
        if system!="dryrun" and system!="backend":
            status = readReg(getNode("LPGBT.RO.I2CREAD.I2CM2STATUS"))
        else:
            status = 0x04
        if (status>>6) & 0x1:
            print (Colors.RED + "ERROR: Last transaction was not acknowledged by the I2C slave" + Colors.ENDC)
            rw_terminate()
        elif (status>>3) & 0x1:
            print (Colors.RED + "ERROR: I2C master port finds that the SDA line is pulled low 0 before initiating a transaction. Indicates a problem with the I2C bus." + Colors.ENDC)
            rw_terminate()
        success = (status>>2) & 0x1
        if int(round((time() - t0))) > i2c_master_timeout:
            print (Colors.RED + "ERROR: I2C master timeout" + Colors.ENDC)
            rw_terminate()

    # Reading the register value to I2CMaster 2
    nbytes = 1
    control_register_data = nbytes<<2 | 0 # using 100 kHz
    writeReg(getNode("LPGBT.RW.I2C.I2CM2DATA0"), control_register_data, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2CMD"), 0x0, 0) # I2C_WRITE_CR

    writeReg(getNode("LPGBT.RW.I2C.I2CM2ADDRESS"), vtrx_slave_addr, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2CMD"), 0xD, 0) # I2C_READ_MULTI
    
    success=0
    t0 = time()
    while(success==0):
        # Status register of I2CMaster 2
        if system!="dryrun" and system!="backend":
            status = readReg(getNode("LPGBT.RO.I2CREAD.I2CM2STATUS"))
        else:
            status = 0x04
        if (status>>6) & 0x1:
            print (Colors.RED + "ERROR: Last transaction was not acknowledged by the I2C slave" + Colors.ENDC)
            rw_terminate()
        elif (status>>3) & 0x1:
            print (Colors.RED + "ERROR: I2C master port finds that the SDA line is pulled low 0 before initiating a transaction. Indicates a problem with the I2C bus." + Colors.ENDC)
            rw_terminate()
        success = (status>>2) & 0x1
        if int(round((time() - t0))) > i2c_master_timeout:
            print (Colors.RED + "ERROR: I2C master timeout" + Colors.ENDC)
            rw_terminate()
    
    data = readReg(getNode("LPGBT.RO.I2CREAD.I2CM2READ15"))
    reg_addr_string = "0x%02X" % (reg_addr)
    data_string = "0x%02X" % (data)
    print ("Successful read from slave register: " + reg_addr_string + ", data: " + data_string + " (" + "{0:08b}".format(data) + ")")
    return data

    # Reset the I2C Master registers
    writeReg(getNode("LPGBT.RW.I2C.I2CM2DATA0"), 0x00, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2DATA1"), 0x00, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2ADDRESS"), 0x00, 0)
    writeReg(getNode("LPGBT.RW.I2C.I2CM2CMD"), 0x00, 0)
    

def main(system, boss, channel, enable, reg_list, data_list):

    if not boss:
        print (Colors.RED + "ERROR: VTRX+ control only for boss since I2C master of boss connected to VTRX+" + Colors.ENDC)
        return

    # Enabling TX Channel
    if channel is not None and enable is not None:
        if system!="backend":
            enable_status = i2cmaster_read(system, enable_reg)
        else:
            enable_status = 0x00
        for c in channel:
            en = 0
            if int(enable):
                print ("Enabling channel: "+c)
                en = 1
            else:
                print ("Disabling channel: "+c)
            enable_channel_bit = TX_enable_bit[c]  
            enable_mask = (1 << enable_channel_bit)                           
            enable_data = (enable_status & (~enable_mask)) | (en << enable_channel_bit)    
            enable_status = enable_data         
        i2cmaster_write(system, enable_reg, enable_data)
        if system!="backend":
            enable_status = i2cmaster_read(system, enable_reg)
        else:
            enable_status = 0x00
        print ("")
 
    if len(reg_list) == 0:
        return

    # Reading registers
    print ("Initial Reading of VTRX+ registers: ")
    for reg in reg_list:
        data = i2cmaster_read(system, reg)
    print ("")
    
    if len(data_list) == 0:
        return
    
    # Writing registers
    print ("Writing to VTRX+ registers: ")
    for i, reg in enumerate(reg_list):
        i2cmaster_write(system, reg, data_list[i])
    print ("")  

    # Reading registers
    print ("Final Reading of VTRX+ registers: ")
    for reg in reg_list:
        data = i2cmaster_read(system, reg)
    print ("")
    

if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="lPGBT VTRX+ Control for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dongle or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-l", "--lpgbt", action="store", dest="lpgbt", help="lpgbt = boss or sub")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number (only needed for backend)")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number (only needed for backend)")
    parser.add_argument("-t", "--type", action="store", dest="type", help="type = reg or name")
    parser.add_argument("-r", "--reg", action="store", nargs="+", dest="reg", help="reg = list of registers to read/write; only use with type: reg")
    parser.add_argument("-c", "--channel", action="store", dest="channel", nargs="+", help="channel = TX1, TX2, TX3, TX4; only use with type: name")
    parser.add_argument("-e", "--enable", action="store", dest="enable", help="enable = 0 or 1; only use with type: name")
    parser.add_argument("-n", "--name", action="store", dest="name", nargs="+", help="name = biascur_reg, modcur_reg, empamp_reg; only use with type: name")
    parser.add_argument("-d", "--data", action="store", nargs="+", dest="data", help="data = list of data values to write")
    args = parser.parse_args()

    if args.system == "chc":
        print ("Using Rpi CHeeseCake for checking VTRx+")
    elif args.system == "backend":
        print ("Using Backend for checking VTRx+")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running on lpGBT")
    else:
        print (Colors.YELLOW + "Only valid options: chc, backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem != "ME0":
        print(Colors.YELLOW + "Valid gem station: ME0" + Colors.ENDC)
        sys.exit()

    boss = None
    if args.lpgbt is None:
        print (Colors.YELLOW + "Please select boss" + Colors.ENDC)
        sys.exit()
    elif (args.lpgbt=="boss"):
        print ("VTRX+ control for boss")
        boss=1
    elif (args.lpgbt=="sub"):
        print (Colors.YELLOW + "VTRX+ control only for boss since I2C master of boss connected to VTRX+" + Colors.ENDC)
        boss=0
        sys.exit()
    else:
        print (Colors.YELLOW + "Please select boss" + Colors.ENDC)
        sys.exit()
    if boss is None:
        sys.exit()

    if args.system == "backend":
        if args.ohid is None:
            print (Colors.YELLOW + "Need OHID for backend" + Colors.ENDC)
            sys.exit()
        if args.gbtid is None:
            print (Colors.YELLOW + "Need GBTID for backend" + Colors.ENDC)
            sys.exit()
        #if int(args.ohid) > 1:
        #    print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
        #    sys.exit()
        #if int(args.gbtid) > 7:
        #    print(Colors.YELLOW + "Only GBTID 0-7 allowed" + Colors.ENDC)
        #    sys.exit()
    else:
        if args.ohid is not None or args.gbtid is not None:
            print (Colors.YELLOW + "OHID and GBTID only needed for backend" + Colors.ENDC)
            sys.exit()

    reg_list = []
    data_list = []
    if args.type == None:
        print ("Enter type")
        sys.exit()
    elif args.type == "reg":
        if args.channel is not None or args.name is not None:
            print (Colors.YELLOW + "For type reg only register values can be given" + Colors.ENDC)
            sys.exit()
        if args.enable is not None:
            print (Colors.YELLOW + "Enable option not available for type: reg" + Colors.ENDC)
            sys.exit()
        if args.reg == None:
            print (Colors.YELLOW + "Enter registers to read/write" + Colors.ENDC)
            sys.exit()
        for reg in args.reg:
            if int(reg,16) > 255:
                print (Colors.YELLOW + "Register address can only be 8 bit" + Colors.ENDC)
                sys.exit()
            reg_list.append(int(reg,16))
    elif args.type == "name":
        if args.reg is not None:
            print (Colors.YELLOW + "For type name only channel, enable or name can be given" + Colors.ENDC)
            sys.exit()
        if args.channel == None:
            print (Colors.YELLOW + "Enter channel" + Colors.ENDC)
            sys.exit()          
        if args.enable is not None:
            if args.enable not in ["0", "1"]:
                print (Colors.YELLOW + "Enter valid value for enable: 0 or 1" + Colors.ENDC)
                sys.exit()
        if args.enable is None and args.name is None:
            print (Colors.YELLOW + "Enter enable option or register name" + Colors.ENDC)
            sys.exit() 
        for c in args.channel:
            if c not in ["TX1", "TX2", "TX3", "TX4"]:
                print (Colors.YELLOW + "Only allowed channels: TX1, TX2, TX3, TX4" + Colors.ENDC)
                sys.exit()
            if args.name is not None:
                for name in args.name:
                    if name not in ["biascur_reg", "modcur_reg", "empamp_reg"]:
                        print (Colors.YELLOW + "Invalid register name" + Colors.ENDC)
                        sys.exit()
                    reg_list.append(TX_reg[c][name])
    else:
        print (Colors.YELLOW + "Only allowed type: reg, name")
        sys.exit()

    if args.data is not None:
        if args.type == "reg":
            if len(reg_list) != len(args.data):
                print (Colors.YELLOW + "Number of registers and data values do not match" + Colors.ENDC)
                sys.exit()
            for data in args.data:
                if int(data,16) > 255:
                    print (Colors.YELLOW + "Data value can only be 8 bit" + Colors.ENDC)
                    sys.exit()
                data_list.append(int(data,16))
        elif  args.type == "name":
            if len(reg_list) != len(args.channel) * len(args.data):
                print (Colors.YELLOW + "Number of registers and data values do not match" + Colors.ENDC)
                sys.exit()
            for c in args.channel:
                for data in args.data:
                    if int(data,16) > 255:
                        print (Colors.YELLOW + "Data value can only be 8 bit" + Colors.ENDC)
                        sys.exit()
                    data_list.append(int(data,16))

    # Initialization 
    rw_initialize(args.gem, args.system, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun" and args.system != "backend":
        check_rom_readback()

    try:
        main(args.system, boss, args.channel, args.enable, reg_list, data_list)
    except KeyboardInterrupt:
        print (Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()

