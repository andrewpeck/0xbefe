from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep
import datetime
import sys
import os
import argparse

def main(system, oh_ver, cap, r0, r1, r2, r3, count, boss):

    cntsel = count
    writeReg(getNode("LPGBT.RW.EOM.EOMENDOFCOUNTSEL"), cntsel, 0)
    writeReg(getNode("LPGBT.RW.EOM.EOMENABLE"), 1, 0)

    # Configured Equalizer settings
    cap_config = readReg(getNode("LPGBT.RWF.EQUALIZER.EQCAP"))
    r0_config = readReg(getNode("LPGBT.RWF.EQUALIZER.EQRES0"))
    r1_config = readReg(getNode("LPGBT.RWF.EQUALIZER.EQRES1"))
    r2_config = readReg(getNode("LPGBT.RWF.EQUALIZER.EQRES2"))
    r3_config = readReg(getNode("LPGBT.RWF.EQUALIZER.EQRES3"))

    # Equalizer settings
    if cap is not None:
        writeReg(getNode("LPGBT.RWF.EQUALIZER.EQCAP"), cap, 0)
    if r0 is not None:
        writeReg(getNode("LPGBT.RWF.EQUALIZER.EQRES0"), r0, 0)
    if r1 is not None:
        writeReg(getNode("LPGBT.RWF.EQUALIZER.EQRES1"), r1, 0)
    if r2 is not None:
        writeReg(getNode("LPGBT.RWF.EQUALIZER.EQRES2"), r2, 0)
    if r3 is not None:
        writeReg(getNode("LPGBT.RWF.EQUALIZER.EQRES3"), r3, 0)

    eyeimage = [[0 for y in range(31)] for x in range(64)]

    datavalregh = getNode("LPGBT.RO.EOM.EOMCOUNTERVALUEH")
    datavalregl = getNode("LPGBT.RO.EOM.EOMCOUNTERVALUEL")

    #cntvalregh = getNode("LPGBT.RO.EOM.EOMCOUNTER40MH")
    #cntvalregl = getNode("LPGBT.RO.EOM.EOMCOUNTER40ML")
    eomphaseselreg = getNode("LPGBT.RW.EOM.EOMPHASESEL")
    eomstartreg = getNode("LPGBT.RW.EOM.EOMSTART")
    eomstatereg = getNode("LPGBT.RO.EOM.EOMSMSTATE")
    eombusyreg = getNode("LPGBT.RO.EOM.EOMBUSY")
    eomendreg = getNode("LPGBT.RO.EOM.EOMEND")
    eomvofsel = getNode("LPGBT.RW.EOM.EOMVOFSEL")

    cntvalmax = 0
    cntvalmin = 2**20

    #ymin=1
    #ymax=31
    ymin=0
    ymax=30
    xmin=0
    xmax=64

    print ("Starting loops: \n")
    for y_axis in range (ymin,ymax):
        # update yaxis
        writeReg(eomvofsel, y_axis, 0)

        for x_axis in range (xmin,xmax):
            #if (x_axis >= 32):
            #    x_axis_wr = 63-(x_axis-32)
            #else:
            x_axis_wr = x_axis

            # update xaxis
            writeReg(eomphaseselreg, x_axis_wr, 0)

            # wait few miliseconds
            sleep(0.005)

            # start measurement
            writeReg(eomstartreg, 0x1, 0)

            # wait until measurement is finished
            busy = 1
            end = 0
            while (busy and not end):
                if system!="dryrun":
                    busy = readReg(eombusyreg)
                    end = readReg(eomendreg)
                else:
                    busy = 0
                    end = 1

            countervalue = (readReg(datavalregh)) << 8 |readReg(datavalregl)
            if (countervalue > cntvalmax):
                cntvalmax = countervalue
            if (countervalue < cntvalmin):
                cntvalmin = countervalue
            eyeimage[x_axis][y_axis] = countervalue

            # deassert eomstart bit
            writeReg(eomstartreg, 0x0, 0)

            #sys.stdout.write("%x" % (eyeimage[x_axis][y_axis]/1000))
            sys.stdout.write("%x" % (eyeimage[x_axis][y_axis]))
            sys.stdout.flush()

        sys.stdout.write("\n")
        #percent_done = 100. * (y_axis*64. +64. ) / (32.*64.)
        #print ("%f percent done" % percent_done)
    print ("\nEnd Loops \n")

    print ("Counter value max=%d" % cntvalmax)
    
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
    dataDir = "results/me0_lpgbt_data/lpgbt_eye_scan_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
        
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    foldername = dataDir+"/"
    filename = foldername + "eye_data_" + now + ".txt"    
    f = open (filename, "w+")
    f.write ("eye_data=[\n")
    for y  in range (ymin,ymax):
        f.write ("    [")
        for x in range (xmin,xmax):
            # normalize for plotting
            if system!="dryrun":
                f.write("%d" % (100*(cntvalmax - eyeimage[x][y])/(cntvalmax-cntvalmin)))
            else:
                f.write("0")
            if (x<(xmax-1)):
                f.write(",")
            else:
                f.write("]")
        if (y<(ymax-1)):
            f.write(",\n")
        else:
            f.write("]\n")

    # Setting back Equalizer settings to configured values
    writeReg(getNode("LPGBT.RWF.EQUALIZER.EQCAP"), cap_config, 0)
    writeReg(getNode("LPGBT.RWF.EQUALIZER.EQRES0"), r0_config, 0)
    writeReg(getNode("LPGBT.RWF.EQUALIZER.EQRES1"), r1_config, 0)
    writeReg(getNode("LPGBT.RWF.EQUALIZER.EQRES2"), r2_config, 0)
    writeReg(getNode("LPGBT.RWF.EQUALIZER.EQRES3"), r3_config, 0)

if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 Eye Scan")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-c", "--cap", action="store", dest="cap", help="EQCAP in hex (0x00 - 0x03)")
    parser.add_argument("-r0", "--r0", action="store", dest="r0", help="EQRES0 in hex (0x00 - 0x03)")
    parser.add_argument("-r1", "--r1", action="store", dest="r1", help="EQRES1 in hex (0x00 - 0x03)")
    parser.add_argument("-r2", "--r2", action="store", dest="r2", help="EQRES2 in hex (0x00 - 0x03)")
    parser.add_argument("-r3", "--r3", action="store", dest="r3", help="EQRES3 in hex (0x00 - 0x03)")
    parser.add_argument("-n", "--count", action="store", dest="count", default="0x7", help="EOMendOfCountSel[3:0] in hex")
    args = parser.parse_args()

    if args.system == "chc":
        print ("Using Rpi CHeeseCake for lpGBT eye scan")
    elif args.system == "backend":
        print ("Using Backend for lpGBT eye scan")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running on lpGBT")
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
    if not boss:
        print (Colors.YELLOW + "Only boss lpGBT allowed" + Colors.ENDC)
        sys.exit()

    if args.cap is not None:
        if "0x" not in args.cap:
            print (Colors.YELLOW + "Enter EQCAP in hex" + Colors.ENDC)
            sys.exit()
        cap = int(args.cap,16)
        if cap>3:
            print (Colors.YELLOW + "EQCAP can be max 2 bits" + Colors.ENDC)
            sys.exit()
    else:
        cap = args.cap
    if args.r0 is not None:
        if "0x" not in args.r0:
            print (Colors.YELLOW + "Enter EQRES0 in hex" + Colors.ENDC)
            sys.exit()
        r0 = int(args.r0,16)
        if r0>3:
            print (Colors.YELLOW + "EQRES0 can be max 2 bits" + Colors.ENDC)
            sys.exit()
    else:
        r0 = args.r0
    if args.r1 is not None:
        if "0x" not in args.r1:
            print (Colors.YELLOW + "Enter EQRES1 in hex" + Colors.ENDC)
            sys.exit()
        r1 = int(args.r1,16)
        if r1>3:
            print (Colors.YELLOW + "EQRES1 can be max 2 bits" + Colors.ENDC)
            sys.exit()
    else:
        r1 = args.r1
    if args.r2 is not None:
        if "0x" not in args.r2:
            print (Colors.YELLOW + "Enter EQRES2 in hex" + Colors.ENDC)
            sys.exit()
        r2 = int(args.r2,16)
        if r2>3:
            print (Colors.YELLOW + "EQRES2 can be max 2 bits" + Colors.ENDC)
            sys.exit()
    else:
        r2 = args.r2
    if args.r3 is not None:
        if "0x" not in args.r3:
            print (Colors.YELLOW + "Enter EQRES3 in hex" + Colors.ENDC)
            sys.exit()
        r3 = int(args.r3,16)
        if r3>3:
            print (Colors.YELLOW + "EQRES3 can be max 2 bits" + Colors.ENDC)
            sys.exit()
    else:
        r3 = args.r3

    if "0x" not in args.count:
        print (Colors.YELLOW + "Enter EOMendOfCountSel[3:0] in hex" + Colors.ENDC)
        sys.exit()
    if int(args.count,16) > 15:
        print (Colors.YELLOW + "EOMendOfCountSel[3:0] can be max 4 bits" + Colors.ENDC)
        sys.exit()

    # Initialization 
    rw_initialize(args.gem, args.system, oh_ver, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun":
        check_rom_readback(args.ohid, args.gbtid)
        check_lpgbt_mode(boss, args.ohid, args.gbtid)

    # Check if GBT is READY
    check_lpgbt_ready(args.ohid, args.gbtid)
    
    try:
        main(args.system, oh_ver, cap, r0, r1, r2, r3, int(args.count,16), boss)
    except KeyboardInterrupt:
        print (Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()

