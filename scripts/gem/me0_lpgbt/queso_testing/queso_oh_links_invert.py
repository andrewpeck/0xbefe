from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep, time
import sys
import argparse

def invert_eprx(boss):
    if (boss):
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX9INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX4INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX2INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX0INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX19INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX17INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX18INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX20INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX22INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX24INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX26INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX25INVERT"), 0x0)

        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX1INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX10INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX12INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX13INVERT"), 0x1)
        #lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX17INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX18INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX21INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX23INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX24INVERT"), 0x1)

    else:
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX21INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX23INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX27INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX24INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX25INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX9INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX10INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX3INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX5INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX1INVERT"), 0x0)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX12INVERT"), 0x0)
        
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX2INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX3INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX4INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX5INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX7INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX8INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX9INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX12INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX13INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTRX.EPRX_CHN_CONTROL.EPRX19INVERT"), 0x1)

def invert_epclk(boss):
    if (boss):
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK7INVERT"), 0x0)
    
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTCLK.EPCLK3INVERT"), 0x1)

def invert_eptx(boss):
    if (boss):
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX10INVERT"), 0x0) 
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX23INVERT"), 0x0) 

        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX11INVERT"), 0x1)
        lpgbt_writeReg(getNode("LPGBT.RWF.EPORTTX.EPTX23INVERT"), 0x1)
	

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Invert elinks in ME0 OH")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or queso or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    args = parser.parse_args()

    if args.system == "chc":
        print ("Using Rpi CHeeseCake for configuration")
    elif args.system == "queso":
        print ("Using QUESO for configuration")
    elif args.system == "backend":
        print ("Using Backend for configuration")
    elif args.system == "dryrun":
        print ("Dry Run - not actually configuring lpGBT")
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

    # Configuring LPGBT
    try:
        invert_eprx(boss)
        invert_eptx(boss)
        invert_epclk(boss)

    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()
