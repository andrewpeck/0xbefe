import gem.me0_lpgbt.ucla_relay_test.ethernet_relay
from time import sleep
import sys
import argparse
from gem.me0_lpgbt.rw_reg_lpgbt import *

def main(system, oh_select, gbt_list, relay_number, niter):

    if sys.version_info[0] < 3:
        raise Exception("Python version 3.x required")

    relay_object = ethernet_relay.ethernet_relay()
    connect_status = relay_object.connectToDevice()
    if not connect_status:
        print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
        rw_terminate()

    ref_status_file_boss = "status_boss_ref.txt"
    ref_status_file_sub = "status_sub_ref.txt"
    status_file_boss = "status_boss.txt"
    status_file_sub = "status_sub.txt"

    reg_list_boss_ref = {}
    file_ref_boss = open(ref_status_file_boss)
    for line in file_ref_boss.readlines():
        reg_list_boss_ref[line.split()[0]] = line.split()[1]
    file_ref_boss.close()

    reg_list_sub_ref = {}
    file_ref_sub = open(ref_status_file_sub)
    for line in file_ref_sub.readlines():
        reg_list_sub_ref[line.split()[0]] = line.split()[1]
    file_ref_sub.close()

    n_error_mode_boss = 0
    n_error_pusm_boss = 0
    n_error_reg_list_boss = 0

    n_error_mode_sub = 0
    n_error_pusm_sub = 0
    n_error_reg_list_sub = 0

    print ("Begin powercycle iteration\n")
    # Power cycle interations
    for n in range(0,niter):
        print ("Iteration: %d\n"%(n+1))

        # Turn on relay
        set_status = relay_object.relay_set(relay_number, 1)
        if not set_status:
            print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
            rw_terminate()
        read_status = relay_object.relay_read(relay_number)
        if not read_status:
            print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
            rw_terminate()
        sleep(10)

        # Check lpGBT status
        # Boss
        boss = 1
        if system=="chc":
            config_initialize_chc(boss)
        elif system=="backend":
            select_ic_link(oh_select, gbt_list["boss"])
        if os.path.isfile(status_file_boss):
            os.remove(status_file_boss)
        mode, pusmstate = check_status(system, boss)
        print ("")
        chc_terminate()
        if mode!=11:
            n_error_mode_boss += 1
            print (Colors.YELLOW + "Incorrect mode: %d"%mode + Colors.ENDC)
        if pusmstate != 18:
            n_error_pusm_boss += 1
            print (Colors.YELLOW + "Incorrect PUSM State: %d"%pusmstate + Colors.ENDC)

        reg_list_boss = {}
        file_boss = open(status_file_boss)
        for line in file_boss.readlines():
            reg_list_boss[line.split()[0]] = line.split()[1]
        file_boss.close()

        n_error_reg_list_iter = 0
        for reg in reg_list_boss:
            if reg_list_boss[reg] != reg_list_boss_ref[reg]:
                n_error_reg_list_iter += 1
        if n_error_reg_list_iter != 0:
            print (Colors.YELLOW + "Register value mismatches: %d"%n_error_reg_list_iter + Colors.ENDC)
        n_error_reg_list_boss += n_error_reg_list_iter

        sleep(1)

        print ("")
        # Sub
        boss = 0
        if system=="chc":
            config_initialize_chc(boss)
        elif system=="backend":
            select_ic_link(oh_select, gbt_list["sub"])
        if os.path.isfile(status_file_sub):
            os.remove(status_file_sub)
        mode, pusmstate = check_status(system, boss)
        print ("")
        chc_terminate()
        if mode!=9:
            n_error_mode_sub += 1
            print (Colors.YELLOW + "Incorrect mode: %d"%mode + Colors.ENDC)
        if pusmstate != 18:
            n_error_pusm_sub += 1
            print (Colors.YELLOW + "Incorrect PUSM State: %d"%pusmstate + Colors.ENDC)

        reg_list_sub = {}
        file_sub = open(status_file_sub)
        for line in file_sub.readlines():
            reg_list_sub[line.split()[0]] = line.split()[1]
        file_sub.close()

        n_error_reg_list_iter = 0
        for reg in reg_list_sub:
            if reg_list_sub[reg] != reg_list_sub_ref[reg]:
                n_error_reg_list_iter += 1
        if n_error_reg_list_iter != 0:
            print (Colors.YELLOW + "Register value mismatches: %d"%n_error_reg_list_iter + Colors.ENDC)
        n_error_reg_list_sub += n_error_reg_list_iter

        sleep(1)
        print ("")
        # Turn off relay
        set_status = relay_object.relay_set(relay_number, 0)
        if not set_status:
            print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
            rw_terminate()
        read_status = relay_object.relay_read(relay_number)
        if not read_status:
            print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
            rw_terminate()

        sleep (10) # To allow power supply to ramp down

    print ("\nEnd of powercycle iteration")
    print ("Number of iterations: %d"%niter)
    # Results
    print ("For Boss lpGBT: ")
    str_n_error_mode_boss = ""
    str_n_error_pusm_boss = ""
    str_n_error_reg_list_boss = ""
    if n_error_mode_boss==0:
        str_n_error_mode_boss += Colors.GREEN
    else:
        str_n_error_mode_boss += Colors.YELLOW
    if n_error_pusm_boss==0:
        str_n_error_pusm_boss += Colors.GREEN
    else:
        str_n_error_pusm_boss += Colors.YELLOW
    if n_error_reg_list_boss==0:
        str_n_error_reg_list_boss += Colors.GREEN
    else:
        str_n_error_reg_list_boss += Colors.YELLOW
    str_n_error_mode_boss += "Number of Mode Errors: %d"%n_error_mode_boss
    str_n_error_pusm_boss += "Number of PUSMSTATE Errors: %d"%n_error_pusm_boss
    str_n_error_reg_list_boss += "Number of Register Value Errors: %d"%n_error_reg_list_boss
    str_n_error_mode_boss += Colors.ENDC
    str_n_error_pusm_boss += Colors.ENDC
    str_n_error_reg_list_boss += Colors.ENDC
    print (str_n_error_mode_boss)
    print (str_n_error_pusm_boss)
    print (str_n_error_reg_list_boss)

    print ("")
    print ("For Sub lpGBT: ")
    str_n_error_mode_sub = ""
    str_n_error_pusm_sub = ""
    str_n_error_reg_list_sub = ""
    if n_error_mode_sub==0:
        str_n_error_mode_sub += Colors.GREEN
    else:
        str_n_error_mode_sub += Colors.YELLOW
    if n_error_pusm_sub==0:
        str_n_error_pusm_sub += Colors.GREEN
    else:
        str_n_error_pusm_sub += Colors.YELLOW
    if n_error_reg_list_sub==0:
        str_n_error_reg_list_sub += Colors.GREEN
    else:
        str_n_error_reg_list_sub += Colors.YELLOW
    str_n_error_mode_sub += "Number of Mode Errors: %d"%n_error_mode_sub
    str_n_error_pusm_sub += "Number of PUSMSTATE Errors: %d"%n_error_pusm_sub
    str_n_error_reg_list_sub += "Number of Register Value Errors: %d"%n_error_reg_list_sub
    str_n_error_mode_sub += Colors.ENDC
    str_n_error_pusm_sub += Colors.ENDC
    str_n_error_reg_list_sub += Colors.ENDC
    print (str_n_error_mode_sub)
    print (str_n_error_pusm_sub)
    print (str_n_error_reg_list_sub)

    print ("")

def check_status(system, boss):
    # Checking Status of Registers
    print ("LpGBT Mode: ")
    mode = readReg(getNode("LPGBT.RO.LPGBTSETTINGS.LPGBTMODE"))
    pusmstate = readReg(getNode("LPGBT.RO.PUSM.PUSMSTATE"))

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

    print ("PUSM State ")
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

    # Writing lpGBT configuration to text file
    if boss:
        lpgbt_write_config_file("status_boss.txt")
    else:
        lpgbt_write_config_file("status_sub.txt")

    return mode, pusmstate


if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Checking Status of LpGBT Configuration for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend")
    #parser.add_argument("-l", "--lpgbt", action="store", dest="lpgbt", help="lpgbt = boss or sub")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = 0-1 (only needed for backend)")
    parser.add_argument("-bg", "--boss_gbtid", action="store", dest="boss_gbtid", help="boss_gbtid = Boss GBT ID 0-7 (only needed for backend)")
    parser.add_argument("-sg", "--sub_gbtid", action="store", dest="sub_gbtid", help="sub_gbtid = Sub GBT ID 0-7 (only needed for backend)")
    parser.add_argument("-r", "--relay_number", action="store", dest="relay_number", help="relay_number = Relay Number used")
    parser.add_argument("-n", "--niter", action="store", dest="niter", default="1000", help="niter = Number of iterations (default=1000)")
    args = parser.parse_args()

    if args.system == "chc":
        print ("Using Rpi CHeeseCake for configuration")
    elif args.system == "backend":
        #print ("Using Backend for configuration")
        print (Colors.YELLOW + "Only chc (Rpi Cheesecake) or dryrun supported at the moment" + Colors.ENDC)
        sys.exit()
    else:
        print (Colors.YELLOW + "Only valid options: chc, backend" + Colors.ENDC)
        sys.exit()

    gbt_list = {}
    gbt_list["boss"] = -9999
    gbt_list["sub"] = -9999
    oh_select = -9999
    if args.system == "backend":
        if args.ohid is None:
            print (Colors.YELLOW + "Need OHID for backend" + Colors.ENDC)
            sys.exit()
        if args.boss_gbtid is None:
            print (Colors.YELLOW + "Need Boss GBTID for backend" + Colors.ENDC)
            sys.exit()
        if args.sub_gbtid is None:
            print (Colors.YELLOW + "Need Sub GBTID for backend" + Colors.ENDC)
            sys.exit()
        oh_select = int(args.ohid)
        if oh_select > 1:
            print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
            sys.exit()
        if int(args.boss_gbtid) or int(args.sub_gbtid) > 7:
            print(Colors.YELLOW + "Only GBTID 0-7 allowed" + Colors.ENDC)
            sys.exit()
        gbt_list["boss"] = int(args.boss_gbtid)
        gbt_list["sub"] = int(args.sub_gbtid)
    else:
        if args.ohid is not None or args.boss_gbtid is not None or args.sub_gbtid is not None:
            print (Colors.YELLOW + "OHID and GBTIDs only needed for backend" + Colors.ENDC)
            sys.exit()

    relay_number = -9999
    if args.relay_number is None:
        print (Colors.YELLOW + "Enter Relay Number" + Colors.ENDC)
        sys.exit()
    relay_number = int(args.relay_number)
    if relay_number not in range(0,8):
        print (Colors.YELLOW + "Valid Relay Number: 0-7" + Colors.ENDC)
        sys.exit()

    # Parsing Registers XML File
    print("Parsing xml file...")
    parseXML()
    print("Parsing complete...")

    # Initialize
    rw_initialize(args.system)

    try:
        main(args.system, oh_select, gbt_list, relay_number, int(args.niter))
    except KeyboardInterrupt:
        print (Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()



