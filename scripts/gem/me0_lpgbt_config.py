from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep, time
import sys
import argparse
from me0_lpgbt_vtrx import i2cmaster_write, i2cmaster_read

def main(system, oh_ver, boss, input_config_file, reset_before_config, minimal):

    # enable TX2 (also TX1 which is enabled by default) channel on VTRX+
    if boss and not readback:
        # Check if old VTRx+ for OH-v1
        check_data = 0x00
        if oh_ver == 1:
            check_data = i2cmaster_read(system, oh_ver, 0x01)
        if check_data == 0x00:
            print ("Enabling TX2 channel for VTRX+")
            i2cmaster_write(system, oh_ver, 0x00, 0x03, True)

    # Set the PLLCONFIGDONE and DLLCONFIGDONE first to 0 if re-configuring using I2C/IC
    if system!="dryrun":
        lpgbt_writeReg(getNode("LPGBT.RWF.POWERUP.DLLCONFIGDONE"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.POWERUP.PLLCONFIGDONE"), 0x0)

    # Optionally reset LPGBT
    if (reset_before_config):
        reset_lpgbt()

    if input_config_file is not None:
        lpgbt_dump_config(oh_ver, input_config_file)
        #lpgbt_check_config_with_file(oh_ver, input_config_file)
    else:
        # configure clocks, chip config, line driver
        configLPGBT(oh_ver)

        if not minimal:
            # eportrx dll configuration
            configure_eport_dlls(oh_ver)

            # eportrx channel configuration
            configure_eprx()

        # configure downlink
        if (boss):
            configure_downlink(oh_ver)

        if not minimal:
            # configure eport tx
            if (boss):
                configure_eptx()

            # configure phase shifter on boss lpgbt
            if (boss):
                configure_phase_shifter()

            # configure ec channels
            configure_ec_channel(oh_ver, boss)

        # invert hsio
        invert_hsio(oh_ver, boss)

        if not minimal:
            # invert eprx
            invert_eprx(boss)

            # invert epclk
            invert_epclk(boss)

            # invert eptx
            invert_eptx(boss)

            # configure reset + led outputs
            configure_gpio(oh_ver, boss)

        # Powerup settings
        lpgbt_writeReg(getNode("LPGBT.RWF.POWERUP.PUSMPLLTIMEOUTCONFIG"), 0x3)
        lpgbt_writeReg(getNode("LPGBT.RWF.POWERUP.PUSMDLLTIMEOUTCONFIG"), 0x3)

        #set_uplink_group_data_source("normal", readback, pattern=0x55555555)

    print("Configuration finished... asserting config done")
    # Finally, Set pll&dllConfigDone to run chip:
    lpgbt_writeReg(getNode("LPGBT.RWF.POWERUP.DLLCONFIGDONE"), 0x1)
    lpgbt_writeReg(getNode("LPGBT.RWF.POWERUP.PLLCONFIGDONE"), 0x1)

    # Check READY status
    sleep(1) # Waiting for 1 sec for the lpGBT configuration to be complete
    pusmstate = lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMSTATE"))
    print ("PUSMSTATE register value: " + str(pusmstate))
    ready_value = -9999
    if oh_ver == 1:
        ready_value = 18
    elif oh_ver == 2:
        ready_value = 19
    if (pusmstate==ready_value):
        print ("lpGBT status is READY")

    # Writing lpGBT configuration to text file
    resultDir = "results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    me0Dir = "results/me0_lpgbt_data"
    try:
        os.makedirs(me0Dir) # create directory for ME0 lpGBT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = "results/me0_lpgbt_data/lpgbt_config_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    
    if boss:
        lpgbt_write_config_file(oh_ver, dataDir+"/config_boss_ohv%d.txt"%oh_ver)
    else:
        lpgbt_write_config_file(oh_ver, dataDir+"/config_sub_ohv%d.txt"%oh_ver)

def configLPGBT(oh_ver):
    print ("Configuring Clock Generator, Line Drivers, Power Good for CERN configuration...")
    # Configure ClockGen Block:
    
    # [0x020] CLKGConfig0
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCALIBRATIONENDOFCOUNT"), 0xC)
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCALIBRATIONENDOFCOUNT"), 0xE)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGBIASGENCONFIG"), 0x8)
    
    # [0x021] CLKGConfig1
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CDRCONTROLOVERRIDEENABLE"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGDISABLEFRAMEALIGNERLOCKCONTROL"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCDRRES"), 0x1)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGVCODAC"), 0x8)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGVCORAILMODE"), 0x1)
    
    # [0x022] CLKGPllRes
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGPLLRESWHENLOCKED"), 0x4)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGPLLRES"), 0x4)
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGPLLRESWHENLOCKED"), 0x2)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGPLLRES"), 0x2)
        
    #[0x023] CLKGPLLIntCur
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGPLLINTCURWHENLOCKED"), 0x5)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGPLLINTCUR"), 0x5)
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGPLLINTCURWHENLOCKED"), 0x9)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGPLLINTCUR"), 0x9)
      
    #[0x024] CLKGPLLPropCur
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGPLLPROPCURWHENLOCKED"), 0x5)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGPLLPROPCUR"), 0x5)
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGPLLPROPCURWHENLOCKED"), 0x9)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGPLLPROPCUR"), 0x9)
    
    #[0x025] CLKGCDRPropCur
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCDRPROPCURWHENLOCKED"), 0x5)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCDRPROPCUR"), 0x5)

    #[0x026] CLKGCDRIntCur
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCDRINTCURWHENLOCKED"), 0x5)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCDRINTCUR"), 0x5)
    
    #[0x027] CLKGCDRFFPropCur
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCDRFEEDFORWARDPROPCURWHENLOCKED"), 0x5)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCDRFEEDFORWARDPROPCUR"), 0x5)
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCDRFEEDFORWARDPROPCURWHENLOCKED"), 0x6)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCDRFEEDFORWARDPROPCUR"), 0x6)
        
    #[0x028] CLKGFLLIntCur
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGFLLINTCURWHENLOCKED"), 0x0)
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGFLLINTCURWHENLOCKED"), 0x5)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGFLLINTCUR"), 0x5)
    
    #[0x029] CLKGFFCAP
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CDRCOCONNECTCDR"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCAPBANKOVERRIDEENABLE"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGFEEDFORWARDCAPWHENLOCKED"), 0x3)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGFEEDFORWARDCAP"), 0x3)

    #[0x02a] CLKGCntOverride
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCOOVERRIDEVC"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CDRCOREFCLKSEL"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CDRCOENABLEPLL"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CDRCOENABLEFD"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CDRCOENABLECDR"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CDRCODISDATACOUNTERREF"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CDRCODISDESVBIASGEN"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CDRCOCONNECTPLL"), 0x0)

    #[0x02b] CLKGOverrideCapBank
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCAPBANKSELECT_7TO0"), 0x00)

    #[0x02c] CLKGWaitTime
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGWAITCDRTIME"), 0x8)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGWAITPLLTIME"), 0x8)
    
    #[0x02d] CLKGLFCONFIG0
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGLOCKFILTERLOCKTHRCOUNTER"), 0x9)
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGLOCKFILTERLOCKTHRCOUNTER"), 0xF)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGLOCKFILTERENABLE"), 0x1)
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGCAPBANKSELECT_8"), 0x0)
    
    #[0x02e] CLKGLFConfig1
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGLOCKFILTERRELOCKTHRCOUNTER"), 0x9)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGLOCKFILTERUNLOCKTHRCOUNTER"), 0x9)
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGLOCKFILTERRELOCKTHRCOUNTER"), 0xF)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.CLKGLOCKFILTERUNLOCKTHRCOUNTER"), 0xF)
    
    #[0x033] PSDllConfig
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.PSDLLCONFIRMCOUNT"), 0x1) # 4 40mhz clock cycles to confirm lock
    lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.PSDLLCURRENTSEL"), 0x1)
    
    #[0x039] Set H.S. Uplink Driver current:
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.LINE_DRIVER.LDMODULATIONCURRENT"), 0x20)
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.LINE_DRIVER.LDMODULATIONCURRENT"), 0x7F)
    lpgbt_writeReg(getNode("LPGBT.RWF.LINE_DRIVER.LDEMPHASISENABLE"), 0x0)
    
    # [0x03b] REFCLK
    #lpgbt_writeReg(getNode("LPGBT.RWF.LINE_DRIVER.REFCLKACBIAS"), 0x1)
    lpgbt_writeReg(getNode("LPGBT.RWF.LINE_DRIVER.REFCLKTERM"), 0x1)

    #[0x03E] PGCONFIG
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.POWER_GOOD.PGLEVEL"), 0x5)
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.POWER_GOOD.PGLEVEL"), 0x4)
    lpgbt_writeReg(getNode("LPGBT.RWF.POWER_GOOD.PGENABLE"), 0x1)
    lpgbt_writeReg(getNode("LPGBT.RWF.POWER_GOOD.PGDELAY"), 0xC)

    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.EPRXLOCKTHRESHOLD"), 0x5)
        lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.EPRXRELOCKTHRESHOLD"), 0x5)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.EPRXUNLOCKTHRESHOLD"), 0x5)
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXLOCKTHRESHOLD"), 0x5)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXRELOCKTHRESHOLD"), 0x5)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXUNLOCKTHRESHOLD"), 0x5)

def set_uplink_group_data_source(type, pattern=0x55555555):
    setting = 0
    if (type=="normal"):
        setting = 0
    elif(type=="prbs7"):
        setting = 1
    elif(type=="cntup"):
        setting = 2
    elif(type=="cntdown"):
        setting = 3
    elif(type=="pattern"):
        setting = 4
    elif(type=="invpattern"):
        setting = 5
    elif(type=="loopback"):
        setting = 6
    else:
        print ("Setting invalid in set_uplink_group_data_source")
        rw_terminate()

    lpgbt_writeReg(getNode("LPGBT.RW.TESTING.ULG0DATASOURCE"), setting) #
    lpgbt_writeReg(getNode("LPGBT.RW.TESTING.ULG1DATASOURCE"), setting) #
    lpgbt_writeReg(getNode("LPGBT.RW.TESTING.ULG2DATASOURCE"), setting) #
    lpgbt_writeReg(getNode("LPGBT.RW.TESTING.ULG3DATASOURCE"), setting) #
    lpgbt_writeReg(getNode("LPGBT.RW.TESTING.ULG4DATASOURCE"), setting) #
    lpgbt_writeReg(getNode("LPGBT.RW.TESTING.ULG5DATASOURCE"), setting) #
    lpgbt_writeReg(getNode("LPGBT.RW.TESTING.ULG6DATASOURCE"), setting) #

    if (setting==4 or setting==5):
        lpgbt_writeReg(getNode("LPGBT.RW.TESTING.DPDATAPATTERN0"), 0xff & (pattern>>0)) #
        lpgbt_writeReg(getNode("LPGBT.RW.TESTING.DPDATAPATTERN1"), 0xff & (pattern>>8)) #
        lpgbt_writeReg(getNode("LPGBT.RW.TESTING.DPDATAPATTERN2"), 0xff & (pattern>>16)) #
        lpgbt_writeReg(getNode("LPGBT.RW.TESTING.DPDATAPATTERN3"), 0xff & (pattern>>24)) #

def configure_eptx():
    #[0x0a7] EPTXDataRate
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX0DATARATE"), 0x3)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX1DATARATE"), 0x3)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX2DATARATE"), 0x3)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX3DATARATE"), 0x3)

    #EPTXxxEnable
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX12ENABLE"), 0x1) #boss 6
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX10ENABLE"), 0x1) #boss 4
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX20ENABLE"), 0x1) #boss 8
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX00ENABLE"), 0x1) #boss 0
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX23ENABLE"), 0x1) #boss 11
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX02ENABLE"), 0x1) #boss 2

    #EPTXxxDriveStrength
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX_CHN_CONTROL.EPTX6DRIVESTRENGTH"), 0x3) #boss 6
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX_CHN_CONTROL.EPTX4DRIVESTRENGTH"), 0x3) #boss 4
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX_CHN_CONTROL.EPTX8DRIVESTRENGTH"), 0x3) #boss 8
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX_CHN_CONTROL.EPTX0DRIVESTRENGTH"), 0x3) #boss 0
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX_CHN_CONTROL.EPTX11DRIVESTRENGTH"), 0x3) #boss 11
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX_CHN_CONTROL.EPTX2DRIVESTRENGTH"), 0x3) #boss 2

    # enable mirror feature
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX0MIRRORENABLE"), 0x1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX1MIRRORENABLE"), 0x1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX2MIRRORENABLE"), 0x1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX3MIRRORENABLE"), 0x1)

    #turn on 320 MHz clocks
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK3FREQ"), 0x4)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK5FREQ"), 0x4)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK6FREQ"), 0x4)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK7FREQ"), 0x4)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK15FREQ"), 0x4)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK16FREQ"), 0x4)

    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK3DRIVESTRENGTH"), 0x3)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK5DRIVESTRENGTH"), 0x3)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK6DRIVESTRENGTH"), 0x3)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK7DRIVESTRENGTH"), 0x3)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK15DRIVESTRENGTH"), 0x3)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK16DRIVESTRENGTH"), 0x3)

def invert_hsio(oh_ver, boss):
    print ("Configuring pin inversion...")
    if (boss):
        if oh_ver == 1:
            lpgbt_writeReg(getNode("LPGBT.RWF.CHIPCONFIG.HIGHSPEEDDATAININVERT"), 0x1)
        elif oh_ver == 2:
            lpgbt_writeReg(getNode("LPGBT.RWF.CHIPCONFIG.HIGHSPEEDDATAININVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.CHIPCONFIG.HIGHSPEEDDATAOUTINVERT"), 0x0)
    else:
        lpgbt_writeReg(getNode("LPGBT.RWF.CHIPCONFIG.HIGHSPEEDDATAININVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.CHIPCONFIG.HIGHSPEEDDATAOUTINVERT"), 0x1)

def invert_eprx(boss):
    if (boss):
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX9INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX4INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX2INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX0INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX19INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX17INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX18INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX20INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX22INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX24INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX26INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX25INVERT"), 0x1)
    else:
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX21INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX23INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX27INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX24INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX25INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX9INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX10INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX3INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX5INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX1INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX12INVERT"), 0x1)

def invert_epclk(boss):
    if (boss):
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK7INVERT"), 0x1)

def invert_eptx(boss):
    if (boss):
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX10INVERT"), 0x1) #boss 4
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX23INVERT"), 0x1) #boss 11

def configure_ec_channel(oh_ver, boss):
    print ("Configuring external control channels...")

    # enable EC output
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTXECENABLE"), 0x1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTXECDRIVESTRENGTH"), 0x3)

    # enable EC input
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXECTERM"),   0x1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXECENABLE"), 0x1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXECPHASESELECT"), 0x0)

    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXECTRACKMODE"), 0x2) # continuous phase tracking
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXECTRACKMODE"), 0x0)

    #if (boss):
        # turn on 80 Mbps EC clock
        #lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK28INVERT"), 0x1)
        #lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK28FREQ"), 0x2)
        #lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK28DRIVESTRENGTH"), 0x3)

def configure_gpio(oh_ver, boss):
    print ("Configuring gpio...")
    if oh_ver == 1:
        if (boss):
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRH"), 0x80) # set as outputs (15) - only LED
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRL"), 0x00)
            #lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRH"), 0x80 | 0x01) # set as outputs (15, 1)
            #lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRL"), 0x01 | 0x04) # set as outputs (1, 2)
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIOOUTH"), 0x80) # enable LED
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIOOUTL"), 0x00)
        else:
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRH"), 0x00)
            #lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRH"), 0x02 | 0x04 | 0x08) # set as outputs (9, 10, 11)
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRL"), 0x00)
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIOOUTH"), 0x00)
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIOOUTL"), 0x00)
    elif oh_ver == 2:
        if (boss):
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRH"), 0x00)
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRL"), 0x20) # set as outputs (5) - only LED
            #lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRH"), 0x01 | 0x02 | 0x20) # set as outputs (8, 9, 13)
            #lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRL"), 0x01 | 0x04 | 0x20) # set as outputs (0, 2, 5)
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIOOUTH"), 0x00)
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIOOUTL"), 0x20) # enable LED
        else:
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRH"), 0x01 | 0x20) # set as outputs (8, 13) - only LEDs
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRL"), 0x01 | 0x02 | 0x08) # set as outputs (0, 1, 3) - only LEDs
            #lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRH"), 0x01 | 0x02 | 0x04 | 0x08 | 0x20) # set as outputs (8, 9, 10, 11, 13)
            #lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIODIRL"), 0x01 | 0x02 | 0x08) # set as outputs (0, 1, 3)
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIOOUTH"), 0x00)
            lpgbt_writeReg(getNode("LPGBT.RWF.PIO.PIOOUTL"), 0x00)

def configure_downlink(oh_ver):
    print ("Configuring downlink...")
    #2.2.6. Downlink: Frame aligner settings (if high speed receiver is used)
    # downlink
    if oh_ver == 1:
        # The following 4 register values might change for lpGBT_v1
        # [0x02f] FAMaxHeaderFoundCount
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.FAMAXHEADERFOUNDCOUNT"), 0x0A)
        # [0x030] FAMaxHeaderFoundCountAfterNF
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.FAMAXHEADERFOUNDCOUNTAFTERNF"), 0x1A)
        # [0x031] FAMaxHeaderNotFoundCount
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.FAMAXHEADERNOTFOUNDCOUNT"), 0x2A)
        # [0x032] FAFAMaxSkipCycleCountAfterNF
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.FAMAXSKIPCYCLECOUNTAFTERNF"), 0x3A)
    elif oh_ver == 2:
        # [0x02f] FAMaxHeaderFoundCount
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.FAMAXHEADERFOUNDCOUNT"), 0x10)
        # [0x030] FAMaxHeaderFoundCountAfterNF
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.FAMAXHEADERFOUNDCOUNTAFTERNF"), 0x10)
        # [0x031] FAMaxHeaderNotFoundCount
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.FAMAXHEADERNOTFOUNDCOUNT"), 0x10)

    # [0x037] EQConfig
    lpgbt_writeReg(getNode("LPGBT.RWF.EQUALIZER.EQATTENUATION"), 0x3)

def configure_eprx():
    print ("Configuring elink inputs...")
    # Enable Elink-inputs

    #set banks to 320 Mbps
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX0DATARATE"), 1) # 1=320mbps in 10gbps mode
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX1DATARATE"), 1) # 1=320mbps in 10gbps mode
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX2DATARATE"), 1) # 1=320mbps in 10gbps mode
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX3DATARATE"), 1) # 1=320mbps in 10gbps mode
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX4DATARATE"), 1) # 1=320mbps in 10gbps mode
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX5DATARATE"), 1) # 1=320mbps in 10gbps mode
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX6DATARATE"), 1) # 1=320mbps in 10gbps mode

    #set banks to fixed phase
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX0TRACKMODE"), 0) # 0 = fixed phase
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX1TRACKMODE"), 0) # 0 = fixed phase
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX2TRACKMODE"), 0) # 0 = fixed phase
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX3TRACKMODE"), 0) # 0 = fixed phase
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX4TRACKMODE"), 0) # 0 = fixed phase
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX5TRACKMODE"), 0) # 0 = fixed phase
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX6TRACKMODE"), 0) # 0 = fixed phase

    #enable inputs
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX00ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX01ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX02ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX03ENABLE"), 1)

    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX10ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX11ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX12ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX13ENABLE"), 1)

    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX20ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX21ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX22ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX23ENABLE"), 1)

    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX30ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX31ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX32ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX33ENABLE"), 1)

    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX40ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX41ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX42ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX43ENABLE"), 1)

    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX50ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX51ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX52ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX53ENABLE"), 1)

    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX60ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX61ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX62ENABLE"), 1)
    lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX63ENABLE"), 1)

    #enable 100 ohm termination
    for i in range (28):
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX%dTERM" % i), 1)

def reset_lpgbt():
    lpgbt_writeReg(getNode("LPGBT.RW.RESET.RSTPLLDIGITAL"), 1)
    lpgbt_writeReg(getNode("LPGBT.RW.RESET.RSTFUSES"),      1)
    #lpgbt_writeReg(getNode("LPGBT.RW.RESET.RSTCONFIG"),     1)
    lpgbt_writeReg(getNode("LPGBT.RW.RESET.RSTRXLOGIC"),    1)
    lpgbt_writeReg(getNode("LPGBT.RW.RESET.RSTTXLOGIC"),    1)

    lpgbt_writeReg(getNode("LPGBT.RW.RESET.RSTPLLDIGITAL"), 0)
    lpgbt_writeReg(getNode("LPGBT.RW.RESET.RSTFUSES"),      0)
    #lpgbt_writeReg(getNode("LPGBT.RW.RESET.RSTCONFIG"),     0)
    lpgbt_writeReg(getNode("LPGBT.RW.RESET.RSTRXLOGIC"),    0)
    lpgbt_writeReg(getNode("LPGBT.RW.RESET.RSTTXLOGIC"),    0)

def configure_eport_dlls(oh_ver):
    print ("Configuring eport dlls...")
    #2.2.2. Uplink: ePort Inputs DLLs
    #[0x034] EPRXDllConfig
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.EPRXDLLCURRENT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.EPRXDLLCONFIRMCOUNT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.EPRXDLLFSMCLKALWAYSON"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.EPRXDLLCOARSELOCKDETECTION"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.EPRXENABLEREINIT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.CLOCKGENERATOR.EPRXDATAGATINGENABLE"), 0x1)
    elif oh_ver == 2:
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXDLLCURRENT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXDLLCONFIRMCOUNT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXDLLFSMCLKALWAYSON"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXDLLCOARSELOCKDETECTION"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXENABLEREINIT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRXDATAGATINGDISABLE"), 0x0)

def configure_phase_shifter():
    # turn on phase shifter clock
    lpgbt_writeReg(getNode("LPGBT.RWF.PHASE_SHIFTER.PS1DELAY_8"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.PHASE_SHIFTER.PS1DELAY_7TO0"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.PHASE_SHIFTER.PS1ENABLEFINETUNE"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RWF.PHASE_SHIFTER.PS1DRIVESTRENGTH"), 0x3)
    lpgbt_writeReg(getNode("LPGBT.RWF.PHASE_SHIFTER.PS1FREQ"), 0x1)
    lpgbt_writeReg(getNode("LPGBT.RWF.PHASE_SHIFTER.PS1PREEMPHASISMODE"), 0x0)


if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="lpGBT Configuration for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-i", "--input", action="store", dest="input_config_file", help="input_config_file = .txt file")
    parser.add_argument("-r", "--reset_before_config", action="store", dest="reset_before_config", default="0", help="reset_before_config = 1 or 0 (default)")
    parser.add_argument("-m", "--minimal", action="store", dest="minimal", default="0", help="minimal = Set 1 for a minimal configuration, 0 by default")
    parser.add_argument("-w", "--write_only", action="store_true", dest="write_only", help="write_only = only write, no read")
    args = parser.parse_args()

    if args.system == "chc":
        print ("Using Rpi CHeeseCake for configuration")
    elif args.system == "backend":
        print ("Using Backend for configuration")
    elif args.system == "dryrun":
        print ("Dry Run - not actually configuring lpGBT")
    else:
        print (Colors.YELLOW + "Only valid options: chc, backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem != "ME0":
        print(Colors.YELLOW + "Valid gem station: ME0" + Colors.ENDC)
        sys.exit()

    if args.ohid is None:
        print(Colors.YELLOW + "Need OHID" + Colors.ENDC)
        sys.exit()
    #if int(args.ohid) > 1:
    #    print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
    #    sys.exit()
    
    if args.gbtid is None:
        print(Colors.YELLOW + "Need GBTID" + Colors.ENDC)
        sys.exit()
    if int(args.gbtid) > 7:
        print(Colors.YELLOW + "Only GBTID 0-7 allowed" + Colors.ENDC)
        sys.exit()

    oh_ver = get_oh_ver(args.ohid, args.gbtid)
    boss = None
    if int(args.gbtid)%2 == 0:
        boss = 1
    else:
        boss = 0
    
    if args.system in ["chc", "backend"]:
        if args.input_config_file is None or ".txt" not in args.input_config_file:
            print (Colors.YELLOW + "Need input .txt file to configure from chc or backend" + Colors.ENDC)
            sys.exit()

    if args.input_config_file is not None:
        print ("Configruing lpGBT from file: " + args.input_config_file)

    if args.reset_before_config not in ["0","1"]:
        print (Colors.YELLOW + "Only 0 or 1 allowed for reset_before_config" + Colors.ENDC)
        sys.exit()
    if args.minimal not in ["0","1"]:
        print (Colors.YELLOW + "Only 0 or 1 allowed for minimal" + Colors.ENDC)
        sys.exit()

    # Initialization 
    rw_initialize(args.gem, args.system, oh_ver, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")

    # Check if GBT is READY
    if args.system == "backend" and not args.write_only:
        check_lpgbt_ready(args.ohid, args.gbtid)

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun" and not args.write_only:
        check_rom_readback(args.ohid, args.gbtid)
        check_lpgbt_mode(boss, args.ohid, args.gbtid)

    # Configuring LPGBT
    try:
        main(args.system, oh_ver, boss, args.input_config_file, int(args.reset_before_config), int(args.minimal))
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
