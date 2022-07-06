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
                gbt_config = get_config("CONFIG_GE21_OH_GBT_CONFIGS")[gbt][oh]
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
        initGbtRegAddrs()

        # Reset boss lpGBTs 
        for oh in range(max_ohs):
            gbt_ver_list = get_config("CONFIG_ME0_GBT_VER")[oh]
            for gbt in range(num_gbts):
                gbt_ver = gbt_ver_list[gbt]
                if gbt%2 != 0:
                    continue
                selectGbt(oh, gbt)
                if gbt_ver == 0:
                    writeGbtRegAddrs(0x130, 0xA3)
                elif gbt_ver == 1:
                    writeGbtRegAddrs(0x140, 0xA3)
                sleep(0.1)
                if gbt_ver == 0:
                    writeGbtRegAddrs(0x12F, 0x80)
                elif gbt_ver == 1:
                    writeGbtRegAddrs(0x13F, 0x80)
                sleep(0.1)
        sleep(2)

        # Reset sub lpGBTs separately for OH-v2
        for oh in range(max_ohs):
            gbt_ver_list = get_config("CONFIG_ME0_GBT_VER")[oh]
            for gbt in range(num_gbts):
                gbt_ver = gbt_ver_list[gbt]
                if gbt_ver == 0:
                    continue
                if gbt%2 != 0:
                    continue
                selectGbt(oh, gbt)
                writeGbtRegAddrs(0x053, 0x02)
                writeGbtRegAddrs(0x055, 0x00)
                sleep(0.1)
                writeGbtRegAddrs(0x053, 0x00)
                sleep(0.1)
        sleep(2)

        # Do some lpGBT read operations for sub in OH-v1s to get the EC working
        for oh in range(max_ohs):
            gbt_ver_list = get_config("CONFIG_ME0_GBT_VER")[oh]
            for gbt in range(num_gbts):
                gbt_ver = gbt_ver_list[gbt]
                selectGbt(oh, gbt)
                gbt_ready = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt))
                if gbt%2 != 0:
                    if gbt_ver == 0 and gbt_ready == 1:
                        for i in range(0,10):
                            read_data = readGbtRegAddrs(0x00)
                else:
                    continue

        # Configure lpGBTs and vfat phase
        for oh in range(max_ohs):
            gbt_ver_list = get_config("CONFIG_ME0_GBT_VER")[oh]
            # configure lpGBTs now
            for gbt in range(num_gbts):
                gbt_ver = gbt_ver_list[gbt]
                oh_ver = -9999
                if gbt_ver == 0:
                    oh_ver = 1
                elif gbt_ver == 1:
                    oh_ver = 2
                gbt_ready = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt))
                if oh_ver == 1 and gbt_ready == 0:
                    print("Skipping configuration of OH%d GBT%d, because it is not ready" % (oh, gbt))
                    continue
                gbt_config = get_config("CONFIG_ME0_OH_GBT_CONFIGS")[gbt%2][oh]
                gbt_config = gbt_config.split("_ohv*")[0] + "_ohv%d"%oh_ver  + gbt_config.split("_ohv*")[1]
                print("Configuring OH%d GBT%d with %s config" % (oh, gbt, gbt_config))
                if not path.exists(gbt_config):
                    printRed("GBT config file %s does not exist. Please create a symlink there, or edit the CONFIG_ME0_OH_GBT*_CONFIGS constant in your befe_config.py file" % gbt_config)
                gbt_command(oh, gbt, "config", [gbt_config])

                # Enable TX channels of VTRx+
                if gbt%2 != 0:
                    continue
                selectGbt(oh, gbt)
                nbytes_write = 2
                control_register_data = nbytes_write<<2 | 0 # using 100 kHz
                nbytes_check = 1
                control_register_data_check = nbytes_check<<2 | 0 # using 100 kHz
                reg_addr = 0x00
                check_reg_addr = 0x01
                data = 0x03
                vtrx_slave_addr = 0x50
                old_vtrx = 0
                if oh_ver == 1:
                    # Read first to check if old VTRx+
                    writeGbtRegAddrs(0x100, control_register_data_check)
                    writeGbtRegAddrs(0x104, 0x0)
                    sleep(0.01)
                    writeGbtRegAddrs(0x100, check_reg_addr)
                    writeGbtRegAddrs(0x104, 0x8)
                    sleep(0.01)
                    writeGbtRegAddrs(0x0FF, vtrx_slave_addr)
                    writeGbtRegAddrs(0x104, 0xC)
                    sleep(0.01)
                    writeGbtRegAddrs(0x100, control_register_data_check)
                    writeGbtRegAddrs(0x104, 0x0)
                    sleep(0.01)
                    writeGbtRegAddrs(0x0FF, vtrx_slave_addr)
                    writeGbtRegAddrs(0x104, 0xD)
                    sleep(0.01)
                    vtrx_data = readGbtRegAddrs(0x19D)
                    if vtrx_data == 0x01:
                        old_vtrx = 1
                    writeGbtRegAddrs(0x100, 0x0)
                    writeGbtRegAddrs(0x101, 0x0)
                    writeGbtRegAddrs(0x0FF, 0x0)
                    writeGbtRegAddrs(0x104, 0x0)
                    sleep(0.01)

                    # Write
                    if not old_vtrx:
                        writeGbtRegAddrs(0x100, control_register_data)
                        writeGbtRegAddrs(0x104, 0x0)
                        sleep(0.01)
                        writeGbtRegAddrs(0x100, reg_addr)
                        writeGbtRegAddrs(0x101, data)
                        writeGbtRegAddrs(0x104, 0x8)
                        sleep(0.01)
                        writeGbtRegAddrs(0x0FF, vtrx_slave_addr)
                        writeGbtRegAddrs(0x104, 0xC)
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
                    #writeGbtRegAddrs(0x10F, vtrx_slave_addr)
                    #writeGbtRegAddrs(0x114, 0xC)
                    #sleep(0.01)
                    #writeGbtRegAddrs(0x110, control_register_data_check)
                    #writeGbtRegAddrs(0x114, 0x0)
                    #sleep(0.01)
                    #writeGbtRegAddrs(0x10F, vtrx_slave_addr)
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
                    if not old_vtrx:
                        writeGbtRegAddrs(0x110, control_register_data)
                        writeGbtRegAddrs(0x114, 0x0)
                        sleep(0.01)
                        writeGbtRegAddrs(0x110, reg_addr)
                        writeGbtRegAddrs(0x111, data)
                        writeGbtRegAddrs(0x114, 0x8)
                        sleep(0.01)
                        writeGbtRegAddrs(0x10F, vtrx_slave_addr)
                        writeGbtRegAddrs(0x114, 0xC)
                        sleep(0.01)
                        writeGbtRegAddrs(0x110, 0x0)
                        writeGbtRegAddrs(0x111, 0x0)
                        writeGbtRegAddrs(0x10F, 0x0)
                        writeGbtRegAddrs(0x114, 0x0)
                        sleep(0.01)

                # Sleep after configuring boss for OH_v2 if not fused or configured by I2C
                if gbt%2 == 0 and oh_ver == 2 and not gbt_ready:
                    sleep(2.5)
            
            # Read in me0 phase scan results
            bestphase_list = {}
            file_in = open(get_config("CONFIG_ME0_PHASE_SCAN"))
            for line in file_in.readlines():
                if "vfat" in line:
                    continue
                vfat = int(line.split()[0])
                phase = int(line.split()[1],16)
                bestphase_list[vfat] = phase
            file_in.close()

            # Read in sbit phase scan result
            bestphase_list_sbit = {}
            file_in = open(get_config("CONFIG_ME0_VFAT_SBIT_PHASE_SCAN"))
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

            # Set the phases
            for vfat in range(0, 24):
                set_bestphase = bestphase_list[vfat]
                lpgbt, gbt_num, elink_num, gpio = ME0_VFAT_TO_GBT_ELINK_GPIO[vfat]
                gbt_ver = gbt_ver_list[gbt_num]

                gbt_ready = read_reg("BEFE.GEM.OH_LINKS.OH%d.GBT%d_READY" % (oh, gbt_num))
                if not gbt_ready:
                    continue
                print ("\nSetting DAQ and Sbit phases for VFAT# %02d"%vfat)

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
                addr = GBT_ELINK_SAMPLE_PHASE_BASE_REG + elink_num

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

                value = (config[addr] & 0x0f) | (set_bestphase << 4)
                selectGbt(oh, gbt_num)
                writeGbtRegAddrs(addr, value)
                sleep(0.01)
                #print ("DAQ Elink phase set for VFAT#%02d to: %s" % (vfat, hex(set_bestphase)))
                
                sbit_elinks = ME0_VFAT_TO_SBIT_ELINK[vfat]
                for elink in range(0,8):
                    set_bestphase = bestphase_list_sbit[vfat][elink]
                    
                    addr = GBT_ELINK_SAMPLE_PHASE_BASE_REG + sbit_elinks[elink]
                    value = (config[addr] & 0x0f) | (set_bestphase << 4)
                    writeGbtRegAddrs(addr, value)
                    sleep(0.1)
                    #print ("VFAT %02d: Sbit Elink phase set for ELINK %02d to: %s" % (vfat, elink, hex(set_bestphase)))


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
