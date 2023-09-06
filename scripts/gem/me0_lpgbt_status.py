from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep
import sys
import argparse

def adc_conversion_lpgbt(adc):
    gain = 1.87
    offset = 531.1
    #voltage = adc/1024.0
    #voltage = (adc - 38.4)/(1.85 * 512)
    voltage = (adc - offset + (0.5*gain*offset))/(gain*offset)
    return voltage

def main(system, oh_ver, boss):

    # Checking Status of Registers

    if oh_ver == 1:
        print ("CHIP ID:")
        print ("\t0x%08x" % (lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.CHIPID0")) << 24 | \
                            lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.CHIPID1")) << 16 | \
                            lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.CHIPID2")) << 8  | \
                            lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.CHIPID3")) << 0))

        print ("USER ID:")
        print ("\t0x%08x" % (lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.USERID0")) << 24 | \
                            lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.USERID1")) << 16 | \
                            lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.USERID2")) << 8  | \
                            lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.USERID3")) << 0))
    elif oh_ver == 2:
        print ("CHIP ID:")
        print ("\t0x%08x" % (lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.CHIPID3")) << 24 | \
                            lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.CHIPID2")) << 16 | \
                            lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.CHIPID1")) << 8  | \
                            lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.CHIPID0")) << 0))

        print ("USER ID:")
        print ("\t0x%08x" % (lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.USERID3")) << 24 | \
                            lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.USERID2")) << 16 | \
                            lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.USERID1")) << 8  | \
                            lpgbt_readReg(getNode("LPGBT.RWF.CHIPID.USERID0")) << 0))

    print ("Lock mode:")
    if (lpgbt_readReg(getNode("LPGBT.RO.LPGBTSETTINGS.LOCKMODE"))):
        print ("\t1 = Reference-less locking. Recover frequency from the data stream.")
    else:
        print ("\t0 = Use external 40 MHz reference clock.")

    print ("LpGBT Mode:")
    mode = lpgbt_readReg(getNode("LPGBT.RO.LPGBTSETTINGS.LPGBTMODE"))

    if (mode==0) : print ("\t4b0000    5 Gbps     FEC5    Off")
    if (mode==1) : print ("\t4b0001    5 Gbps     FEC5    Simplex TX")
    if (mode==2) : print ("\t4b0010    5 Gbps     FEC5    Simplex RX")
    if (mode==3) : print ("\t4b0011    5 Gbps     FEC5    Transceiver")
    if (mode==4) : print ("\t4b0100    5 Gbps     FEC12   Off")
    if (mode==5) : print ("\t4b0101    5 Gbps     FEC12   Simplex TX")
    if (mode==6) : print ("\t4b0110    5 Gbps     FEC12   Simplex RX")
    if (mode==7) : print ("\t4b0111    5 Gbps     FEC12   Transceiver")
    if (mode==8) : print ("\t4b1000    10 Gbps    FEC5    Off")
    if (mode==9) : print ("\t4b1001    10 Gbps    FEC5    Simplex TX")
    if (mode==10): print ("\t4b1010    10 Gbps    FEC5    Simplex RX")
    if (mode==11): print ("\t4b1011    10 Gbps    FEC5    Transceiver")
    if (mode==12): print ("\t4b1100    10 Gbps    FEC12   Off")
    if (mode==13): print ("\t4b1101    10 Gbps    FEC12   Simplex TX")
    if (mode==14): print ("\t4b1110    10 Gbps    FEC12   Simplex RX")
    if (mode==15): print ("\t4b1111    10 Gbps    FEC12   Transceiver")
        
    if oh_ver == 2:
        print ("Boot Config:")
        boot_config = lpgbt_readReg(getNode("LPGBT.RO.LPGBTSETTINGS.BOOTCONFIG"))
        if boot_config == 0:
            print ("\tLoad register values from fuses. If checksum does not match copy values from ROM")
        elif boot_config == 1:
            print ("\tCopy values from ROM")
        elif boot_config == 2:
            print ("\tLoad register values from fuses without checking the checksum")
        elif boot_config == 3:
            print ("\tSkip chip initialization")

    if oh_ver == 1:
        print ("State Override:")
        if (lpgbt_readReg(getNode("LPGBT.RO.LPGBTSETTINGS.STATEOVERRIDE"))):
            print ("\t1 = Power up state machine halted.")
        else:
            print ("\t0 = Normal operation.")
            
        print ("VCO Bypass:")
        if (lpgbt_readReg(getNode("LPGBT.RO.LPGBTSETTINGS.VCOBYPASS"))):
            print ("\t1 = VCO Bypass mode. System clock come from TSTCLKINP/N (5.12 GHz).")
        else:
            print ("\t0 = Normal operation. System clocks comes from PLL/CDR.")

    print ("VCO Bypass:")
    if (lpgbt_readReg(getNode("LPGBT.RO.LPGBTSETTINGS.VCOBYPASS"))):
        print ("\t1 = VCO Bypass mode. System clock come from TSTCLKINP/N (5.12 GHz).")
    else:
        print ("\t0 = Normal operation. System clocks comes from PLL/CDR.")

    pusmstate = lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMSTATE"))

    print ("PUSM State:")
    if oh_ver == 1:
        if (pusmstate==0):  print ("\t0  = ARESET - the FSM stays in this state when power-on-reset or an external reset (RSTB) is asserted. \n\t When external signal PORdisable is asserted, the signal generated by the internal power-on-reset is ignored. All action flags are reset in this state.")
        if (pusmstate==1):  print ("\t1  = RESET - synchronous reset state. In this state, the FSM produces synchronous reset signal for various circuits. \n\t All action flags are not reset in this state.")
        if (pusmstate==2):  print ("\t2  = WAIT_VDD_STABLE - the FSM waits for VDD to raise. It has fixed duration of 4,000 clock cycles (~100us).")
        if (pusmstate==3):  print ("\t3  = WAIT_VDD_HIGHER_THAN_0V90 - the FSM monitors the VDD voltage. \n\t It waits until VDD stays above 0.9V for a period longer than 1us.\n\t This state is bypassed if PORdisable is active.")
        if (pusmstate==4):  print ("\t4  = FUSE_SAMPLING - initiate fuse sampling.")
        if (pusmstate==5):  print ("\t5  = UPDATE FROM FUSES - transfer fuse values into registers. Transfer executed only if updateEnable fuse in POWERUP2 register is blown.")
        if (pusmstate==6):  print ("\t6  = PAUSE_FOR_PLL_CONFIG - this state is foreseen for initial testing of the chip when optimal registers settings are not yet known and the e-fuses have not been burned. The FSM will wait in this state until pllConfigDone bit is asserted. While in this state, the user can use the I2C interface to write values to the registers. For more details about intended use please refer to Section 3.7.")
        if (pusmstate==7):  print ("\t7  = WAIT_POWER_GOOD - this state is foreseen to make sure that the power supply voltage is stable before proceeding with further initialization. When PGEnable bit is enabled the FSM will wait until VDD level stays above value configured by PGLevel[2:0] for longer than time configured by PGDelay[4:0]. If PGEnable is not set, one can use PGDelay[4:0] as a fixed delay. The PGLevel[2:0] and PGDelay[4:0] are interpreted according to Table 8.1 and Table 8.2.")
        if (pusmstate==8):  print ("\t8  = RESETOUT - in this state a reset signal is generated on the resetout pin. The reset signal is active low. The duration of the reset pulse is controlled by value of ResetOutLength[1:0] field according to Table 8.3.")
        if (pusmstate==9):  print ("\t9  = I2C_TRANS - this state is foreseen to execute one I2C transaction. This feature can be used to configure a laser driver chip or any other component in the system. To enable transaction, the I2CMTransEnable bit has to be programmed and master channel has to be selected by I2CMTransChannel[1:0]. Remaining configuration like I2CMTransAddressExt[2:0], I2CMTransAddress[6:0], and I2CMTransCtrl[127:0] should be configured according to the description in the I2C slaves chapter.")
        if (pusmstate==10): print ("\t10 = RESET_PLL - reset PLL/CDR control logic.")
        if (pusmstate==11): print ("\t11 = WAIT_PLL_LOCK - waits for the PLL/CDR to lock. \n\t When lpGBT is configured in simplex RX or transceiver mode the lock signal comes from frame aligner. \n\t It means that the valid lpGBT frame has to be sent in the downlink. \n\t This state can be interrupted by timeout action (see the description below).")
        if (pusmstate==12): print ("\t12 = INIT_SCRAM - initializes scrambler in the uplink data path.")
        if (pusmstate==13): print ("\t13 = PAUSE_FOR_DLL_CONFIG - this state is foreseen for the case in which user wants to use serial interface (IC/EC) to configure the chip. The FSM will wait in this state until dllConfigDone bit is asserted. While in this state, the user can use the serial interface (IC/EC) or I2C interface to write values to the registers. For more details about intended use please refer to Section 3.7.")
        if (pusmstate==14): print ("\t14 = RESET_DLLS - reset DLLs in ePortRx groups and phase-shifter.")
        if (pusmstate==15): print ("\t15 = WAIT_DLL_LOCK - wait until all DLL report to be locked. This state can be interrupted by timeout action (see the description below).")
        if (pusmstate==16): print ("\t16 = RESET_LOGIC_USING_DLL - reset a logic using DLL circuitry. In case of ePortRx groups, this signal is used to initialize automatic phase training. This state has no impact on a phase-shifter operation.")
        if (pusmstate==17): print ("\t17 = WAIT_CHNS_LOCKED - in this state, FSM waits until automatic phase training is finished for all enabled ePortRx groups. One should keep in mind, that data transitions have to be present on the enabled channels to acquire lock. By default this state is bypassed, it can be enabled asserting PUSMReadyWhenChnsLocked bit in POWERUP register. This state can be interrupted by timeout action (see the description below).")
        if (pusmstate==18): print ("\t18 = READY - initialization is completed. Chip is operational. READY signal is asserted.")
    elif oh_ver == 2:
        if (pusmstate==0):  print ("\t0  = ARESET - the FSM stays in this state when power-on-reset or the external reset (RSTB) is asserted (for more details please refer to Section 8.7.2). When the external signal PORdisable is asserted, the signal generated by the internal power-on-reset is ignored (for more details please refer to Section 8.7.1). All action flags are reset in this state.")
        if (pusmstate==1):  print ("\t1  = RESET - synchronous reset state. In this state, the FSM produces the synchronous reset signal for various circuits. The action flags are not reset in this state.")
        if (pusmstate==2):  print ("\t2  = WAIT_VDD_STABLE - the FSM waits for VDD to stabilize to its nominal value. It has a fixed duration of 0.5 seconds.")
        if (pusmstate==3):  print ("\t3  = WAIT_VDD_HIGHER_THAN_0V90 - the FSM monitors the VDD voltage. It waits for VDD to remain above 0.9V for a period longer than 0.5 s. This state is bypassed if PORdisable is active (for more details please refer to Section 8.7.1).")
        if (pusmstate==4):  print ("\t4  = STATE_COPY_FUSES - in this state the e-fuses are readout sequentially and the contents stored in the configuration registers. The transfer executed only if BOOTCNF[0] is set to zero (for more details please refer to Section 8.7.4).")
        if (pusmstate==5):  print ("\t5  = STATE_CALCULATE_CHECKSUM - in this state the CRC of the configuration memory is evaluated.")
        if (pusmstate==6):  print ("\t6  = COPY_ROM - in this state the ROM is readout sequentially and the results are stored in the corresponding configuration registers. This state can be reached if BOOTCNF[1:0] are set to 01 or if the process of reading e-fuses fails 256 times (for more details please refer to Section 8.7.4).")
        if (pusmstate==7):  print ("\t7  = PAUSE_FOR_PLL_CONFIG - this state is foreseen for initial testing of the chip when optimal registers settings are not yet known and the e-fuses have not been burned. The FSM will wait in this state until pllConfigDone bit is asserted. While in this state, the user can use the I2C interface to write values to the registers. For more details about intended use please refer to Section 3.9.")
        if (pusmstate==8):  print ("\t8  = WAIT_POWER_GOOD - this state is foreseen to make sure that the power supply voltage is stable before proceeding with further initialization. When PGEnable bit is enabled the FSM will wait for the VDD voltage to remain above the value set by PGLevel[2:0] for longer than time configured by PGDelay[3:0]. If PGEnable is not set, one can use PGDelay[3:0] as a fixed delay. The PGLevel[2:0] and PGDelay[3:0] are interpreted according to Table 8.1 and Table 8.2.")
        if (pusmstate==9):  print ("\t9  = RESET_PLL - reset PLL/CDR control logic.")
        if (pusmstate==10): print ("\t10 = WAIT_PLL_LOCK - waits for the PLL/CDR to lock. When lpGBT is configured in simplex RX or transceiver mode the lock signal comes from the frame aligner. It means that the valid lpGBT frames have been received through the downlink. This state can be interrupted by a timeout action (see the description below).")
        if (pusmstate==11): print ("\t11 = INIT_SCRAM - initializes the scrambler in the uplink data path.")
        if (pusmstate==12): print ("\t12 = RESETOUT - in this state a RSTOUTB signal is deasserted. Since the RSTOUTB signal is active low it means that it will transition from low to high level in this stage. Whenever the lpGBT goes through the re-initialization sequence (RE-INIT is true on the Fig. 8.1) due to timeout action, brown out action or CRC mismatch action the RESETOUT state will be bypassed and therefore the chip will not generate another pulse on RSTOUTB. For more details please refer to Section 8.7.5.")
        if (pusmstate==13): print ("\t13 = I2C_TRANS - this state is foreseen to execute one I2C transaction. This feature can be used to configure a laser driver chip or any other component in the system. To enable the transaction, the I2CMTransEnable bit has to be programmed and master channel has to be selected by I2CMTransChannel[1:0]. Remaining configuration like I2CMTransAddressExt[2:0], I2CMTransAddress[6:0], and I2CMTransCtrl[127:0] should be configured according to the description in the I2C slaves chapter. This state is bypassed in cases of chip re-initialization in the same way as RESETOUT state (for more details please refer to Section 8.7.5).")
        if (pusmstate==14): print ("\t14 = PAUSE_FOR_DLL_CONFIG - this state is foreseen for the case in which the user wants to use the serial interface (IC/EC) to configure the chip. user wants to use serial interface (IC/EC) to configure the chip. The FSM will wait in this state until dllConfigDone bit is asserted. While in this state, the user can use the serial interface (IC/EC) or I2C interface to write values to the registers. For more details about intended use please refer to Section 3.9.")
        if (pusmstate==15): print ("\t15 = RESET_DLLS - reset DLLs in ePortRx groups and phase-shifter.")
        if (pusmstate==16): print ("\t16 = WAIT_DLL_LOCK - wait until all DLLs report to be locked. This state can be interrupted by a timeout action (see the description below).")
        if (pusmstate==17): print ("\t17 = RESET_LOGIC_USING_DLL - reset logic relying on the stable phase output from the DLL. In case of ePortRx groups, this signal is used to initialize automatic phase training. This state has no impact on the phase-shifters operation.")
        if (pusmstate==18): print ("\t18 = WAIT_CHNS_LOCKED - in this state, FSM waits until automatic phase training is finished for all enabled ePortRx groups. One should keep in mind, that data transitions have to be present on the enabled channels to acquire lock. By default this state is bypassed, it can be enabled asserting PUSMReadyWhenChnsLocked bit in POWERUP register. This state can be interrupted by a timeout action (see the description below).")
        if (pusmstate==19): print ("\t19 = READY - initialization is completed. Chip is operational. READY signal is asserted. For more details please refer to Section 8.7.3.")

    if oh_ver == 1:
        if (lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMPLLTIMEOUTACTION"))):
            print ("PLL timeout:")
            print ("\tPLL timeout action has been executed since the last chip reset.")
        if (lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMDLLTIMEOUTACTION"))):
            print("DLL timeout:")
            print("\tDLL timeout action has been executed since the last chip reset.")
        if (lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMCHANNELSTIMEOUTACTION"))):
            print("Channels timeout:")
            print("\tWait for channels locked timeout action has been executed since the last chip reset.")
        if (lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMBROWNOUTACTION"))):
            print("Brownout:")
            print("\tThe brownout action has been executed since the last chip reset.")

        if (lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMPLLWATCHDOGACTION"))):
            print("PLL Watchdog:")
            print("\tPLL watchdog action has been executed since the last chip reset.")

        if (lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMDLLWATCHDOGACTION"))):
            print("DLL Watchdog:")
            print("\tDLL watchdog action has been executed since the last chip reset.")
    elif oh_ver == 2:
        print("PLL watchdog action counter:")
        print("\t" + str(lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMPLLWATCHDOGACTIONS"))))

        print ("DLL watchdog action counter:")
        print ("\t" + str(lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMDLLWATCHDOGACTIONS"))))

        print("Checksum watchdog action counter:")
        print("\t" + str(lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMCHECKSUMWATCHDOGACTIONS"))))

        if (lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMBROWNOUTACTIONFLAG"))):
            print("Brownout status register:")
            print("\tBrownout condition detected (VDD lower than brownout voltage level)")

        print("PLL timeout action counter:")
        print("\t" + str(lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMPLLTIMEOUTACTIONS"))))

        print("DLL timeout action counter:")
        print("\t" + str(lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMDLLTIMEOUTACTIONS"))))

        print("Channels locking timeout action counter:")
        print("\t" + str(lpgbt_readReg(getNode("LPGBT.RO.PUSM.PUSMCHANNELSTIMEOUTACTIONS"))))

    if oh_ver == 1:
        print ("Frame Aligner State:")
        print ("\t" + str(lpgbt_readReg(getNode("LPGBT.RO.PUSM.FASTATE"))))

        print ("Frame Aligner Counter:")
        print ("\t%d" % lpgbt_readReg(getNode("LPGBT.RO.PUSM.FACOUNTER")))
    elif oh_ver == 2:
        print("Frame Aligner State:")
        print("\t" + str(lpgbt_readReg(getNode("LPGBT.RO.DEBUG.FASTATE"))))

        print("Frame Aligner Status register:")
        print("\tValid headers found: %d" % lpgbt_readReg(getNode("LPGBT.RO.DEBUG.FAHEADERFOUNDCOUNT")))
        print("\tInvalid headers found: %d" % lpgbt_readReg(getNode("LPGBT.RO.DEBUG.FAHEADERNOTFOUNDCOUNT")))
        print("\tFrame aligner unlocks: %d" % lpgbt_readReg(getNode("LPGBT.RO.DEBUG.FALOSSOFLOCKCOUNT")))

    clkgfmstate = lpgbt_readReg(getNode("LPGBT.RO.CLKG.CLKG_SMSTATE"))
    print ("LJCDR State:")

    if (clkgfmstate==0x0):  print ("\t0x0 = smResetState reset state")
    if (clkgfmstate==0x1):  print ("\t0x1 = smInit initialization state (1cycle)")
    if (clkgfmstate==0x2):  print ("\t0x2 = smCapSearchStart start VCO calibration (jump to smPLLInit or smCDRInit when finished)")
    if (clkgfmstate==0x3):  print ("\t0x3 = smCapSearchClearCounters0 VCO calibration step; clear counters")
    if (clkgfmstate==0x4):  print ("\t0x4 = smCapSearchClearCounters1 VCO calibration step; clear counters")
    if (clkgfmstate==0x5):  print ("\t0x5 = smCapSearchEnableCounter VCO calibration step; start counters")
    if (clkgfmstate==0x6):  print ("\t0x6 = smCapSearchWaitFreqDecision; VCO calibration step; wait for race end")
    if (clkgfmstate==0x7):  print ("\t0x7 = smCapSearchVCOFaster VCO calibration step; VCO is faster than refClk, increase capBank")
    if (clkgfmstate==0x8):  print ("\t0x8 = smCapSearchRefClkFaster VCO calibration step; refClk is faster than VCO, decrease capBank")
    if (clkgfmstate==0x9):  print ("\t0x9 = smPLLInit PLL step; closing PLL loop and waiting for lock state. \n\t Waits for lockfilter (if enabled), waits for waitPllTime (~ifenabled)")
    if (clkgfmstate==0xa):  print ("\t0xa = smCDRInit CDR step; closing CDR loop and waiting for lock state")
    if (clkgfmstate==0xb):  print ("\t0xb = smPLLEnd PLL step; PLL is locked")
    if (clkgfmstate==0xc):  print ("\t0xc = smCDREnd CDR step; CDR is locked")

    clkglfstate = lpgbt_readReg(getNode("LPGBT.RO.CLKG.CLKG_LFSTATE"))
    print ("LJCDR Lock Filter State:")
    if (clkglfstate==0): print ("\t0 = lfUnlfLockedState low-pass lock filter is unlocked")
    if (clkglfstate==1): print ("\t1 = lfConfirmLockState low-pass lock filter is confirming lock")
    if (clkglfstate==2): print ("\t2 = lfLockedState low-pass lock filter is locked")
    if (clkglfstate==3): print ("\t3 = lfConfirmUnlockState")

    print ("Lock Filter Loss of Lock Count:")
    print ("\t%d" % lpgbt_readReg(getNode("LPGBT.RO.CLKG.CLKG_LFLOSSOFLOCKCOUNT")))

    print ("LJCDR Locked Flag:")
    print ("\t%d" % lpgbt_readReg(getNode("LPGBT.RO.CLKG.CLKG_SMLOCKED")))

    print ("Downlink FEC Errors:")
    if oh_ver == 1:
        print ("\t%d" % (lpgbt_readReg(getNode("LPGBT.RO.FEC.DLDPFECCORRECTIONCOUNT_H")) << 8 | lpgbt_readReg(getNode("LPGBT.RO.FEC.DLDPFECCORRECTIONCOUNT_L"))))
    elif oh_ver == 2:
        print ("\t%d" % (lpgbt_readReg(getNode("LPGBT.RO.FEC.DLDPFECCORRECTIONCOUNT0")) << 24 | lpgbt_readReg(getNode("LPGBT.RO.FEC.DLDPFECCORRECTIONCOUNT1")) << 16 | lpgbt_readReg(getNode("LPGBT.RO.FEC.DLDPFECCORRECTIONCOUNT2")) << 8 | lpgbt_readReg(getNode("LPGBT.RO.FEC.DLDPFECCORRECTIONCOUNT3")) ))

    print ("CDR Resistor:")
    if (lpgbt_readReg(getNode("LPGBT.RO.CLKG.CLKG_ENABLE_CDR_R"))):
        print ("\t1 = connected")
    else:
        print ("\t0 = disconnected")

    print ("CDR Proportional Charge Pump Current:")
    print ("\t%f uA" % (5.46 * lpgbt_readReg(getNode("LPGBT.RO.CLKG.CLKG_CONFIG_P_CDR"))))

    print ("CDR Proportional Feedforward Current:")
    print ("\t%f uA" % (5.46 * lpgbt_readReg(getNode("LPGBT.RO.CLKG.CLKG_CONFIG_P_FF_CDR"))))

    print ("CDR Integral Current:")
    print ("\t%f uA" % (5.46 * lpgbt_readReg(getNode("LPGBT.RO.CLKG.CLKG_CONFIG_I_CDR"))))

    print ("CDR FLL Current:")
    print ("\t%f uA" % (5.46 * lpgbt_readReg(getNode("LPGBT.RO.CLKG.CLKG_CONFIG_I_FLL"))))

    print ("VCO Cap Select:")
    print ("\t%d" % (lpgbt_readReg(getNode("LPGBT.RO.CLKG.CLKG_VCOCAPSELECTH")) << 1 | lpgbt_readReg(getNode("LPGBT.RO.CLKG.CLKG_VCOCAPSELECTL"))))

   #print ("Configuring adc...")
   #lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x1)
   #lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINNSELECT"), 0x15)
   #lpgbt_writeReg(getNode("LPGBT.RW.ADC.CONVERT"), 0x1)
   #lpgbt_writeReg(getNode("LPGBT.RW.ADC.GAINSELECT"), 0x1)

    init_adc(oh_ver)
    print ("ADC Readings:")
    
    if oh_ver == 1:
        if boss == 1:
            for i in range(16):
                name = ""
                if (i==0 ):  conv=1; name="N/A"
                if (i==1 ):  conv=1; name="ASENSE_2"
                if (i==2 ):  conv=1; name="ASENSE_1"
                if (i==3 ):  conv=1; name="ASENSE_3"
                if (i==4 ):  conv=1; name="ASENSE_0"
                if (i==5 ):  conv=1*2.0; name="1V2"
                if (i==6 ):  conv=1*3.0; name="2V5"
                if (i==7 ):  conv=1; name="RSSI"
                if (i==8 ):  conv=1; name="EOM DAC (internal signal)"
                if (i==9 ):  conv=1/0.42; name="VDDIO (internal signal)"
                if (i==10):  conv=1/0.42; name="VDDTX (internal signal)"
                if (i==11):  conv=1/0.42; name="VDDRX (internal signal)"
                if (i==12):  conv=1/0.42; name="VDD (internal signal)"
                if (i==13):  conv=1/0.42; name="VDDA (internal signal)"
                if (i==14):  conv=1; name="Temperature sensor (internal signal)"
                if (i==15):  conv=1/0.50; name="VREF (internal signal)"
                read = read_adc(i, system)
                print ("\tch %X: 0x%03X = %f, reading = %f (%s)" % (i, read, adc_conversion_lpgbt(read), conv*adc_conversion_lpgbt(read), name))
        elif boss == 0:
            for i in range(16):
                name = ""
                if (i==0 ):  conv=1; name="N/A"
                if (i==1 ):  conv=1; name="N/A"
                if (i==2 ):  conv=1; name="N/A"
                if (i==3 ):  conv=1; name="N/A"
                if (i==4 ):  conv=1; name="N/A"
                if (i==5 ):  conv=1; name="N/A"
                if (i==6 ):  conv=1; name="N/A"
                if (i==7 ):  conv=1; name="N/A"
                if (i==8 ):  conv=1; name="EOM DAC (internal signal)"
                if (i==9 ):  conv=1/0.42; name="VDDIO (internal signal)"
                if (i==10):  conv=1/0.42; name="VDDTX (internal signal)"
                if (i==11):  conv=1/0.42; name="VDDRX (internal signal)"
                if (i==12):  conv=1/0.42; name="VDD (internal signal)"
                if (i==13):  conv=1/0.42; name="VDDA (internal signal)"
                if (i==14):  conv=1; name="Temperature sensor (internal signal)"
                if (i==15):  conv=1/0.50; name="VREF (internal signal)"
                read = read_adc(i, system)
                print ("\tch %X: 0x%03X = %f, reading = %f (%s)" % (i, read, adc_conversion_lpgbt(read), conv*adc_conversion_lpgbt(read), name))
    elif oh_ver == 2:
        if boss == 1:
            for i in range(16):
                name = ""
                if (i == 0 ):  conv = 1; name = "ASENSE_2"
                if (i == 1 ):  conv = 1; name = "ASENSE_1"
                if (i == 2 ):  conv = 1; name = "Unused"
                if (i == 3 ):  conv = 1; name = "ASENSE_3"
                if (i == 4 ):  conv = 1; name = "Unused"
                if (i == 5 ):  conv = 1; name = "Unused"
                if (i == 6 ):  conv = 1; name = "ASENSE_0"
                if (i == 7 ):  conv = 1; name = "Precision calibration resistor"
                if (i == 8 ):  conv = 1; name = "Voltage DAC output (internal signal)"
                if (i == 9 ):  conv = 1; name = "VSSA (internal signal)"
                if (i == 10):  conv = 1/0.42; name = "VDDTX (internal signal)"
                if (i == 11):  conv = 1/0.42; name = "VDDRX (internal signal)"
                if (i == 12):  conv = 1/0.42; name = "VDD (internal signal)"
                if (i == 13):  conv = 1/0.42; name = "VDDA (internal signal)"
                if (i == 14):  conv = 1; name = "Temperature sensor (internal signal)"
                if (i == 15):  conv = 1/0.50; name = "VREF (internal signal)"
                read = read_adc(i, system)
                print ("\tch %X: 0x%03X = %f, reading = %f (%s)" % (i, read, adc_conversion_lpgbt(read), conv*adc_conversion_lpgbt(read), name))
        elif boss == 0:
            for i in range(16):
                name = ""
                if (i == 0 ):  conv = 1; name = "VTRx+ Temperature (TH1)"
                if (i == 1 ):  conv = 1*3.0; name = "2.5 V Voltage Divider"
                if (i == 2 ):  conv = 1; name = "Unused"
                if (i == 3 ):  conv = 1; name = "Precision Calibration Resistor"
                if (i == 4 ):  conv = 1; name = "Unused"
                if (i == 5 ):  conv = 1; name = "VTRx+ RSSI"
                if (i == 6 ):  conv = 1; name = "OH Temperature"
                if (i == 7 ):  conv = 1; name = "Unused"
                if (i == 8 ):  conv = 1; name = "Voltage DAC output (internal signal)"
                if (i == 9 ):  conv = 1; name = "VSSA (internal signal)"
                if (i == 10):  conv = 1/0.42; name = "VDDTX (internal signal)"
                if (i == 11):  conv = 1/0.42; name = "VDDRX (internal signal)"
                if (i == 12):  conv = 1/0.42; name = "VDD (internal signal)"
                if (i == 13):  conv = 1/0.42; name = "VDDA (internal signal)"
                if (i == 14):  conv = 1; name = "Temperature sensor (internal signal)"
                if (i == 15):  conv = 1/0.50; name = "VREF (internal signal)"
                read = read_adc(i, system)
                print ("\tch %X: 0x%03X = %f, reading = %f (%s)" % (i, read, adc_conversion_lpgbt(read), conv*adc_conversion_lpgbt(read), name))

    powerdown_adc(oh_ver)
    print ("")

    # CRC
    if oh_ver == 2:
        n_rw_fuse = (0xFF+1)

        print ("CRC value calculated from registers: ")
        protected_registers = (n_rw_fuse-4)*[0]
        for i in range(0, (n_rw_fuse-4)):
            protected_registers[i] = mpeek(i)
        crc_registers = calculate_crc(protected_registers)
        crc = crc_registers[0] | (crc_registers[1] << 8) | (crc_registers[2] << 16) | (crc_registers[3] << 24)
        print ("CRC: 0x%X\n"%crc)

        print ("CRC value written in EFuses: ")
        crc_registers = 4*[0]
        crc_registers[0] = lpgbt_readReg(getNode("LPGBT.RWF.POWERUP.CRC0"))
        crc_registers[1] = lpgbt_readReg(getNode("LPGBT.RWF.POWERUP.CRC1"))
        crc_registers[2] = lpgbt_readReg(getNode("LPGBT.RWF.POWERUP.CRC2"))
        crc_registers[3] = lpgbt_readReg(getNode("LPGBT.RWF.POWERUP.CRC3"))
        crc = crc_registers[0] | (crc_registers[1] << 8) | (crc_registers[2] << 16) | (crc_registers[3] << 24)
        print ("CRC: 0x%X\n"%crc)

        print ("CRC value last computed: ")
        crc_registers = 4*[0]
        crc_registers[0] = lpgbt_readReg(getNode("LPGBT.RO.PUSM.CRCVALUE0"))
        crc_registers[1] = lpgbt_readReg(getNode("LPGBT.RO.PUSM.CRCVALUE1"))
        crc_registers[2] = lpgbt_readReg(getNode("LPGBT.RO.PUSM.CRCVALUE2"))
        crc_registers[3] = lpgbt_readReg(getNode("LPGBT.RO.PUSM.CRCVALUE3"))
        crc = crc_registers[0] | (crc_registers[1] << 8) | (crc_registers[2] << 16) | (crc_registers[3] << 24)
        print ("CRC: 0x%X\n"%crc)
        print ("Number of CRC calculations which resulted in invalid checksum: %d\n"%(lpgbt_readReg(getNode("LPGBT.RO.PUSM.FAILEDCRCCOUNTER"))))
    
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
    dataDir = "results/me0_lpgbt_data/lpgbt_status_data"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    if boss:
        lpgbt_write_config_file(oh_ver, dataDir+"/status_boss_ohv%d.txt"%oh_ver, status=1)
    else:
        lpgbt_write_config_file(oh_ver, dataDir+"/status_sub_ohv%d.txt"%oh_ver, status=1)


def init_adc(oh_ver):
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x1) # enable ADC
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.TEMPSENSRESET"), 0x1) # resets temp sensor
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDMONENA"), 0x1) # enable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDTXMONENA"), 0x1) # enable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDRXMONENA"), 0x1) # enable dividers
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDPSTMONENA"), 0x1)  # enable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDANMONENA"), 0x1) # enable dividers
    lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFENABLE"), 0x1) # vref enable
    lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFTUNE"), 0x63) # vref tune
    sleep (0.01)

def powerdown_adc(oh_ver):
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCENABLE"), 0x0) # disable ADC
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.TEMPSENSRESET"), 0x0) # disable temp sensor
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDMONENA"), 0x0) # disable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDTXMONENA"), 0x0) # disable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDRXMONENA"), 0x0) # disable dividers
    if oh_ver == 1:
        lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDPSTMONENA"), 0x0) # disable dividers
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.VDDANMONENA"), 0x0) # disable dividers
    lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFENABLE"), 0x0) # vref disable
    lpgbt_writeReg(getNode("LPGBT.RWF.CALIBRATION.VREFTUNE"), 0x0) # vref tune

def read_adc(channel, system):
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINPSELECT"), channel)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINNSELECT"), 0xf)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCCONVERT"), 0x1)
    done = 0
    while (done==0):
        if system!="dryrun":
            done = lpgbt_readReg(getNode("LPGBT.RO.ADC.ADCDONE"))
        else:
            done=1
    val = lpgbt_readReg(getNode("LPGBT.RO.ADC.ADCVALUEL"))
    val |= (lpgbt_readReg(getNode("LPGBT.RO.ADC.ADCVALUEH")) << 8)

    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCCONVERT"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCGAINSELECT"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINPSELECT"), 0x0)
    lpgbt_writeReg(getNode("LPGBT.RW.ADC.ADCINNSELECT"), 0x0)

    return val

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Checking Status of lpGBT Configuration for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or queso or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    args = parser.parse_args()

    if args.system == "chc":
        print ("Using Rpi CHeeseCake for status check")
    elif args.system == "queso":
        print("Using QUESO for status check")
    elif args.system == "backend":
        print ("Using Backend for status check")
    elif args.system == "dryrun":
        print ("Dry Run - not actually checking status of lpGBT")
    else:
        print (Colors.YELLOW + "Only valid options: chc, queso, backend, dryrun" + Colors.ENDC)
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

    # Initialization 
    rw_initialize(args.gem, args.system, oh_ver, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")

    # Check if GBT is READY
    if args.system == "backend":
        check_lpgbt_ready(args.ohid, args.gbtid)

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun":
        check_rom_readback(args.ohid, args.gbtid)
        check_lpgbt_mode(boss, args.ohid, args.gbtid)   
        
    try:
        main(args.system, oh_ver, boss)
    except KeyboardInterrupt:
        print (Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()



