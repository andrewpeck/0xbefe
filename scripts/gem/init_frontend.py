from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from common.promless import *
from gem.gbt import *
from gem.me0_phase_scan import getConfig
from gem.gem_utils import *
import time
from os import path

def init_gem_frontend():

    gem_station = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.GEM_STATION")
    print("GEM station: %s" % gem_station)

    max_ohs = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_OF_OH")
    if gem_station == 1 or gem_station == 2: # GE1/1 or GE2/1
        # configure GBTs
        num_gbts = 2 if gem_station == 2 else 3 if gem_station == 1 else None
        for oh in range(max_ohs):
            for gbt in range(num_gbts):
                gbt_ready = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt))
                if gbt_ready == 0:
                    print("Skipping configuration of OH%d GBT%d, because it is not ready" % (oh, gbt))
                    continue
                gbt_config = get_config("CONFIG_GE21_OH_GBT_CONFIGS")[gbt][oh] if gem_station == 2 else get_config("CONFIG_GE11_OH_GBT_CONFIGS")[gbt][oh] if gem_station == 1 else None
                print("Configuring OH%d GBT%d with %s config" % (oh, gbt, gbt_config))
                if not path.exists(gbt_config):
                    printRed("GBT config file %s does not exist. Please create a symlink there, or edit the CONFIG_GE*_OH_GBT*_CONFIGS constant in your befe_config.py file" % gbt_config)
                gbt_command(oh, gbt, "config", [gbt_config])

        print("Resetting SCAs")
        write_reg("BEFE.GEM.SLOW_CONTROL.SCA.CTRL.MODULE_RESET", 1)

        print("Sending a hard-reset")
        gem_hard_reset()

    elif gem_station == 0: # ME0
        num_gbts = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_OF_GBTS_PER_OH")
        # Set address of different backend nodes
        initGbtRegAddrs()

        # Reset boss lpGBTs 
        for oh in range(max_ohs):
            gbt_ver_list = get_config("CONFIG_ME0_GBT_VER")[oh] # Get GBT version list for this OH from befe_config
            for gbt in range(num_gbts):
                gbt_ver = gbt_ver_list[gbt]

                # Only do this for boss lpGBT
                if gbt%2 != 0:  
                    continue

                selectGbt(oh, gbt) # Select link, I2C address for this specific OH and GBT
                # Set this register to the magic number to be able to force the PUSM state
                if gbt_ver == 0:
                    writeGbtRegAddrs(0x130, 0xA3)
                elif gbt_ver == 1:
                    writeGbtRegAddrs(0x140, 0xA3)
                sleep(0.1)

                # Set the FSM to state 0 (ARESET)
                if gbt_ver == 0:
                    writeGbtRegAddrs(0x12F, 0x80)
                elif gbt_ver == 1:
                    writeGbtRegAddrs(0x13F, 0x80)
                sleep(0.1)
        sleep(2)

        # Reset sub lpGBTs (from boss lpGBT using GPIO) separately for OH-v2
        for oh in range(max_ohs):
            gbt_ver_list = get_config("CONFIG_ME0_GBT_VER")[oh] # Get GBT version list for this OH from befe_config
            for gbt in range(num_gbts):
                gbt_ver = gbt_ver_list[gbt]
                if gbt_ver == 0: # Feature only available OH-v2
                    continue

                # Only do this for boss lpGBT
                if gbt%2 != 0:
                    continue

                selectGbt(oh, gbt) # Select link, I2C address for this specific OH and GBT
                writeGbtRegAddrs(0x053, 0x02) # Configure GPIO as output
                writeGbtRegAddrs(0x055, 0x00) # Set GPIO low - resets sub lpGBT
                sleep(0.1)
                writeGbtRegAddrs(0x053, 0x00) # Configure GPIO as input
                sleep(0.1)
        sleep(2)

        # Do some lpGBT read operations from sub lpGBT in OH-v1s to get the EC working
        for oh in range(max_ohs):
            gbt_ver_list = get_config("CONFIG_ME0_GBT_VER")[oh] # Get GBT version list for this OH from befe_config
            for gbt in range(num_gbts):
                gbt_ver = gbt_ver_list[gbt]
                selectGbt(oh, gbt) # Select link, I2C address for this specific OH and GBT
                gbt_ready = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt)) # Check if GBT is READY

                # Only do this for sub lpGBT
                if gbt%2 != 0:  
                    if gbt_ver == 0 and gbt_ready == 1: # Only for OH-v1 if GBT is already READY
                        for i in range(0,10):
                            read_data = readGbtRegAddrs(0x00) # Just do multiple read operations on a register
                else:
                    continue

        # Configure lpGBTs and vfat phase
        for oh in range(max_ohs):
            gbt_ver_list = get_config("CONFIG_ME0_GBT_VER")[oh] # Get GBT version list for this OH from befe_config

            for gbt in range(num_gbts):
                gbt_ver = gbt_ver_list[gbt]
                oh_ver = -9999
                if gbt_ver == 0:
                    oh_ver = 1
                elif gbt_ver == 1:
                    oh_ver = 2
                gbt_ready = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt)) # Check if GBT is READY
                if oh_ver == 1 and gbt_ready == 0: # OH-v1 can only be configured if its in a READY state
                    print("Skipping configuration of OH%d GBT%d, because it is not ready" % (oh, gbt))
                    continue

                # Configure lpGBT
                gbt_config = get_config("CONFIG_ME0_OH_GBT_CONFIGS")[gbt%2][oh] 
                gbt_config = gbt_config.split("_ohv*")[0] + "_ohv%d"%oh_ver  + gbt_config.split("_ohv*")[1] # Get the correct lpGBT config file
                print("Configuring OH%d GBT%d with %s config" % (oh, gbt, gbt_config))
                if not path.exists(gbt_config):
                    printRed("GBT config file %s does not exist. Please create a symlink there, or edit the CONFIG_ME0_OH_GBT*_CONFIGS constant in your befe_config.py file" % gbt_config)
                gbt_command(oh, gbt, "config", [gbt_config]) # configure lpGBT

                # Enable TX channels of VTRx+
                if gbt%2 != 0: # VTRx+ communication is with boss lpGBT
                    continue
                selectGbt(oh, gbt) # Select link, I2C address for this specific OH and GBT

                nbytes_write = 2
                control_register_data = nbytes_write<<2 | 0 # control register data for using 100 kHz
                nbytes_check = 1
                control_register_data_check = nbytes_check<<2 | 0 # control register data for using 100 kHz

                vtrx_i2c_addr = 0x50 # VTRx+ I2C address

                reg_addr = 0x00 # Register address on VTRx+ for enabliing TX channels 
                check_reg_addr = 0x01 # Register address on the VTRx+ to check for old vs new
                data = 0x03 # Data to write to register 0x00 to enable boss and sub lpGBT TX 0x03 = 0000 0011
                
                old_vtrx = 0
                if oh_ver == 1: 
                    # For OH-v1 check if connected to old or new VTRx+

                    # Read first to check if old VTRx+
                    writeGbtRegAddrs(0x100, control_register_data_check) # I2CM2 data - for control register
                    writeGbtRegAddrs(0x104, 0x0) # Write to I2CM2 control register
                    sleep(0.01)
                    writeGbtRegAddrs(0x100, check_reg_addr) # I2CM2 data - register address to read on VTRx+
                    writeGbtRegAddrs(0x104, 0x8) # I2CM2 data stored locally for write command
                    sleep(0.01)
                    writeGbtRegAddrs(0x0FF, vtrx_i2c_addr) # Set I2C address for VTRx+
                    writeGbtRegAddrs(0x104, 0xC) # I2CM2 send write command to VTRx+
                    sleep(0.01)
                    writeGbtRegAddrs(0x100, control_register_data_check) # I2CM2 data - for control register
                    writeGbtRegAddrs(0x104, 0x0) # Write to I2CM2 control register
                    sleep(0.01)
                    writeGbtRegAddrs(0x0FF, vtrx_i2c_addr) # Set I2C address for VTRx+
                    writeGbtRegAddrs(0x104, 0xD) # I2CM2 single byte read from VTRx+
                    sleep(0.01)
                    vtrx_data = readGbtRegAddrs(0x19D) # Data read out from VTRx+ register
                    if vtrx_data == 0x01:
                        old_vtrx = 1
                    writeGbtRegAddrs(0x100, 0x0)
                    writeGbtRegAddrs(0x101, 0x0)
                    writeGbtRegAddrs(0x0FF, 0x0)
                    writeGbtRegAddrs(0x104, 0x0)
                    sleep(0.01)

                    # Write
                    if not old_vtrx: # Need to enable TX channel of VTRx+ only for new VTRx+
                        writeGbtRegAddrs(0x100, control_register_data) # I2CM2 data - for control register
                        writeGbtRegAddrs(0x104, 0x0) # Write to I2CM2 control register
                        sleep(0.01) 
                        writeGbtRegAddrs(0x100, reg_addr) # I2CM2 data - register address to write to on VTRx+
                        writeGbtRegAddrs(0x101, data) # I2CM2 data to write to register on VTRx+
                        writeGbtRegAddrs(0x104, 0x8)  # I2CM2 data stored locally for write command
                        sleep(0.01)
                        writeGbtRegAddrs(0x0FF, vtrx_i2c_addr) # Set I2C address for VTRx+
                        writeGbtRegAddrs(0x104, 0xC) # I2CM2 send write command to VTRx+
                        sleep(0.01)
                        writeGbtRegAddrs(0x100, 0x0)
                        writeGbtRegAddrs(0x101, 0x0)
                        writeGbtRegAddrs(0x0FF, 0x0)
                        writeGbtRegAddrs(0x104, 0x0)
                        sleep(0.01)
                elif oh_ver == 2:
                    # Assuming OHv2 never connected to an old VTRx+

                    # Read first to check if old VTRx+
                    #writeGbtRegAddrs(0x110, control_register_data_check)
                    #writeGbtRegAddrs(0x114, 0x0)
                    #sleep(0.01)
                    #writeGbtRegAddrs(0x110, check_reg_addr)
                    #writeGbtRegAddrs(0x114, 0x8)
                    #sleep(0.01)
                    #writeGbtRegAddrs(0x10F, vtrx_i2c_addr)
                    #writeGbtRegAddrs(0x114, 0xC)
                    #sleep(0.01)
                    #writeGbtRegAddrs(0x110, control_register_data_check)
                    #writeGbtRegAddrs(0x114, 0x0)
                    #sleep(0.01)
                    #writeGbtRegAddrs(0x10F, vtrx_i2c_addr)
                    #writeGbtRegAddrs(0x114, 0xD)
                    #sleep(0.01)
                    #vtrx_data = readGbtRegAddrs(0x1AD)
                    #if vtrx_data == 0x01:
                    #    old_vtrx = 1
                    #writeGbtRegAddrs(0x110, 0x0)
                    #writeGbtRegAddrs(0x111, 0x0)
                    #writeGbtRegAddrs(0x10F, 0x0)
                    #writeGbtRegAddrs(0x114, 0x0)
                    #sleep(0.01)

                    # Write
                    if not old_vtrx: # Need to enable TX channel of VTRx+ only for new VTRx+
                        writeGbtRegAddrs(0x110, control_register_data) # I2CM2 data - for control register
                        writeGbtRegAddrs(0x114, 0x0) # Write to I2CM2 control register
                        sleep(0.01)
                        writeGbtRegAddrs(0x110, reg_addr) # I2CM2 data - register address to write to on VTRx+
                        writeGbtRegAddrs(0x111, data) # I2CM2 data to write to register on VTRx+
                        writeGbtRegAddrs(0x114, 0x8) # I2CM2 data stored locally for write command
                        sleep(0.01)
                        writeGbtRegAddrs(0x10F, vtrx_i2c_addr) # Set I2C address for VTRx+
                        writeGbtRegAddrs(0x114, 0xC) # I2CM2 send write command to VTRx+
                        sleep(0.01)
                        writeGbtRegAddrs(0x110, 0x0)
                        writeGbtRegAddrs(0x111, 0x0)
                        writeGbtRegAddrs(0x10F, 0x0)
                        writeGbtRegAddrs(0x114, 0x0)
                        sleep(0.01)

                # Sleep after configuring boss for OH_v2 if not fused or configured by I2C
                if gbt%2 == 0 and oh_ver == 2 and not gbt_ready:
                    sleep(2.5)
            
            # Read in me0 DAQ phase scan results
            bestphase_list = {}
            phase_scan_filename = get_config("CONFIG_ME0_VFAT_PHASE_SCAN")
            if phase_scan_filename != "":
                phase_scan_filename = phase_scan_filename.split("*")[0] + str(oh) + phase_scan_filename.split("*")[1]
                file_in = open(phase_scan_filename)
                for line in file_in.readlines():
                    if "vfat" in line:
                        continue
                    vfat = int(line.split()[0])
                    phase = int(line.split()[1],16)
                    bestphase_list[vfat] = phase
                file_in.close()

            # Read in sbit phase scan result
            bestphase_list_sbit = {}
            sbit_phase_scan_filename = get_config("CONFIG_ME0_VFAT_SBIT_PHASE_SCAN")
            if sbit_phase_scan_filename != "":
                sbit_phase_scan_filename = sbit_phase_scan_filename.split("*")[0] + str(oh) + sbit_phase_scan_filename.split("*")[1]
                file_in = open(sbit_phase_scan_filename)
                for line in file_in.readlines():
                    if "vfat" in line:
                        continue
                    vfat = int(line.split()[0])
                    elink = int(line.split()[1])
                    phase = int(line.split()[2],16)
                    if vfat not in bestphase_list_sbit:
                        bestphase_list_sbit[vfat] = {}
                    bestphase_list_sbit[vfat][elink] = phase
                file_in.close()
            
            # Read in sbit bitslip result
            bitslip_list_sbit = {}
            sbit_bitslip_filename = get_config("CONFIG_ME0_VFAT_SBIT_BITSLIP")
            if sbit_bitslip_filename != "":
                sbit_bitslip_filename = sbit_bitslip_filename.split("*")[0] + str(oh) + sbit_bitslip_filename.split("*")[1]
                file_in = open(sbit_bitslip_filename)
                for line in file_in.readlines():
                    if "VFAT" in line:
                        continue
                    vfat = int(line.split()[0])
                    elink = int(line.split()[1])
                    bitslip = int(line.split()[2])
                    if vfat not in bitslip_list_sbit:
                        bitslip_list_sbit[vfat] = {}
                    bitslip_list_sbit[vfat][elink] = bitslip
                file_in.close()

            # Set the phases and bitslipsb
            for vfat in range(0, 24):
                lpgbt, gbt_num, elink_num, gpio = ME0_VFAT_TO_GBT_ELINK_GPIO[vfat] # Get the lpGBT and elink info for this VFAT
                sbit_elinks = ME0_VFAT_TO_SBIT_ELINK[vfat] # Get the sbit elink info for this VFAT
                gbt_ver = gbt_ver_list[gbt_num]

                gbt_ready = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt_num))
                if not gbt_ready: # Only set phases if GBT for this VFAT is READY
                    continue

                oh_ver = -9999
                if gbt_ver == 0:
                    oh_ver = 1
                elif gbt_ver == 1:
                    oh_ver = 2
                
                GBT_ELINK_SAMPLE_PHASE_BASE_REG = -9999
                if oh_ver == 1:
                    GBT_ELINK_SAMPLE_PHASE_BASE_REG = 0x0CC
                elif oh_ver == 2:
                    GBT_ELINK_SAMPLE_PHASE_BASE_REG = 0x0D0
                addr = GBT_ELINK_SAMPLE_PHASE_BASE_REG + elink_num # lpGBT register address for DAQ phase setting for this VFAT

                # Read the configuration of the corresponding lpGBT from the text file
                if lpgbt == "boss":
                    if oh_ver == 1:
                        config = getConfig("../resources/me0_boss_config_ohv1.txt")
                    elif oh_ver == 2:
                        config = getConfig("../resources/me0_boss_config_ohv2.txt")
                elif lpgbt == "sub":
                    if oh_ver == 1:
                        config = getConfig("../resources/me0_sub_config_ohv1.txt")
                    elif oh_ver == 2:
                        config = getConfig("../resources/me0_sub_config_ohv2.txt")

                if vfat in bestphase_list and vfat in bestphase_list_sbit and vfat in bitslip_list_sbit:
                    print ("\nSetting DAQ, Sbit Phases and Bitslips for OH %d VFAT# %02d"%(oh,vfat))
                elif vfat in bestphase_list and vfat in bestphase_list_sbit and vfat not in bitslip_list_sbit:
                    print ("\nSetting DAQ and Sbit Phases for OH %d VFAT# %02d"%(oh,vfat))
                elif vfat in bestphase_list and vfat not in bestphase_list_sbit and vfat in bitslip_list_sbit:
                    print ("\nSetting DAQ phases and Sbit Bitslips for OH %d VFAT# %02d"%(oh,vfat))
                elif vfat not in bestphase_list and vfat in bestphase_list_sbit and vfat in bitslip_list_sbit:
                    print ("\nSetting Sbit Phases and Bitslips for OH %d VFAT# %02d"%(oh,vfat))
                elif vfat in bestphase_list and vfat not in bestphase_list_sbi and vfat not in bitslip_list_sbit:
                    print ("\nSetting DAQ phases for OH %d VFAT# %02d"%(oh,vfat))
                elif vfat not in bestphase_list and vfat in bestphase_list_sbit and vfat not in bitslip_list_sbit:
                    print ("\nSetting Sbit phases for OH %d VFAT# %02d"%(oh,vfat))
                elif vfat not in bestphase_list and vfat not in bestphase_list_sbit and vfat in bitslip_list_sbit:
                    print ("\nSetting Sbit Bitslips for OH %d VFAT# %02d"%(oh,vfat))
                else:
                    continue

                # Write DAQ phase setting to the lpGBT register for this VFAT
                if vfat in bestphase_list:
                    set_bestphase = bestphase_list[vfat]
                    value = (config[addr] & 0x0f) | (set_bestphase << 4)
                    selectGbt(oh, gbt_num)
                    writeGbtRegAddrs(addr, value)
                    sleep(0.01)
                    #print ("  DAQ Elink phase set for OH %d VFAT#%02d to: %s" % (oh, vfat, hex(set_bestphase)))
                
                # Get the lpGBT register address and write the phase setting for the 8 Sbit Elinks for this VFAT
                if vfat in bestphase_list_sbit:
                    for elink in range(0,8):
                        set_bestphase = bestphase_list_sbit[vfat][elink]
                    
                        addr = GBT_ELINK_SAMPLE_PHASE_BASE_REG + sbit_elinks[elink]
                        value = (config[addr] & 0x0f) | (set_bestphase << 4)
                        writeGbtRegAddrs(addr, value)
                        sleep(0.1)
                        #print ("    OH %d VFAT %02d: Sbit Elink phase set for ELINK %02d to: %s" % (oh, vfat, elink, hex(set_bestphase)))

                # Write the Sbit bitslips
                if vfat in bitslip_list_sbit:
                    for elink in range(0,8):
                        set_bitslip = bitslip_list_sbit[vfat][elink]
                        write_reg("BEFE.GEM.SBIT_ME0.OH%d_VFAT_MAP.VFAT%d.ELINK%d_MAP"%(oh,vfat,elink), set_bitslip)


    print("\nSetting VFAT HDLC addresses")
    vfats_per_oh = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_VFATS_PER_OH")
    hdlc_addr = get_config("CONFIG_ME0_VFAT_HDLC_ADDRESSES") if gem_station == 0 else get_config("CONFIG_GE11_VFAT_HDLC_ADDRESSES") if gem_station == 1 else get_config("CONFIG_GE21_VFAT_HDLC_ADDRESSES") if gem_station == 2 else None
    for vfat in range(vfats_per_oh):
        write_reg("BEFE.GEM.GEM_SYSTEM.VFAT3.VFAT%d_HDLC_ADDRESS" % vfat, hdlc_addr[vfat])

    print("Sending a link reset (also issues a SYNC command to the VFATs)")
    write_reg("BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET", 1)
    time.sleep(0.1)

    print("Sending a command to VFATs to exit slow-control-only mode in case they are in this mode")
    write_reg("BEFE.GEM.GEM_SYSTEM.VFAT3.SC_ONLY_MODE", 0)

    time.sleep(0.3)
    print("Frontend status:")
    gem_print_status()

    print("Frontend initialization done")

if __name__ == '__main__':
    parse_xml()
    init_gem_frontend()
