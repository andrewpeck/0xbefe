from gem.me0_lpgbt.rw_reg_lpgbt import *
from time import sleep
import datetime
import sys
import os
import glob
import argparse

def main(system, oh_ver, count, eq_attn, eq_cap, eq_res3, eq_res2, eq_res1, eq_res0, boss):

    cntsel = count
    writeReg(getNode("LPGBT.RW.EOM.EOMENDOFCOUNTSEL"), cntsel, 0)
    writeReg(getNode("LPGBT.RW.EOM.EOMENABLE"), 1, 0)

    #ymin=1
    #ymax=30
    ymin=0
    ymax=31
    xmin=0
    xmax=64

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

    eq_attn_node = getNode("LPGBT.RWF.EQUALIZER.EQATTENUATION")
    eq_cap_node = getNode("LPGBT.RWF.EQUALIZER.EQCAP")
    eq_res3_node = getNode("LPGBT.RWF.EQUALIZER.EQRES3")
    eq_res2_node = getNode("LPGBT.RWF.EQUALIZER.EQRES2")
    eq_res1_node = getNode("LPGBT.RWF.EQUALIZER.EQRES1")
    eq_res0_node = getNode("LPGBT.RWF.EQUALIZER.EQRES0")

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
    
    files = glob.glob(dataDir+"/eye_data_eqa*.py", recursive=True)
    for f in files:
        os.remove(f)

    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    foldername = dataDir+"/"

    print ("\n")
    # Start Loop Over Equalizer Settings
    for eq_attn_setting in eq_attn:
        writeReg(eq_attn_node, int(eq_attn_setting,16), 0)
        for eq_cap_setting in eq_cap:
            writeReg(eq_cap_node, int(eq_cap_setting,16), 0)
            for eq_res3_setting in eq_res3:
                writeReg(eq_res3_node, int(eq_res3_setting,16), 0)
                for eq_res2_setting in eq_res2:
                    writeReg(eq_res2_node, int(eq_res2_setting,16), 0)
                    for eq_res1_setting in eq_res1:
                        writeReg(eq_res1_node, int(eq_res1_setting,16), 0)
                        for eq_res0_setting in eq_res0:
                            writeReg(eq_res0_node, int(eq_res0_setting,16), 0)
                            print ("Scanning EQATTENUATION = " + eq_attn_setting)
                            print ("Scanning EQCAP = " + eq_cap_setting)
                            print ("Scanning EQRES3 = " + eq_res3_setting)
                            print ("Scanning EQRES2 = " + eq_res2_setting)
                            print ("Scanning EQRES1 = " + eq_res1_setting)
                            print ("Scanning EQRES0 = " + eq_res0_setting)

                            eyeimage = [[0 for y in range(31)] for x in range(64)]
                            cntvalmax = 0
                            cntvalmin = 2**20

                            # Start loop for Eye Scan
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
                            # End loop for Eye Scan
                            sys.stdout.write("\n")

                            print ("Counter value max=%d \n" % cntvalmax)
                            
                            
                            filename = foldername + "eye_data_eqa_"+eq_attn_setting+"_eqc_"+eq_cap_setting+"_eqr3_"+eq_res3_setting+"_eqr2_"+eq_res2_setting+"_eqr1_"+eq_res1_setting+"_eqr0_"+eq_res0_setting+".txt"
                            f = open(filename, "w+")
                            f.write("eye_data=[\n")
                            for y  in range (ymin,ymax):
                                f.write("    [")
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
    # End Loop Over Equalizer Settings

    # Setting back Default Equalizer settings
    writeReg(getNode("LPGBT.RWF.EQUALIZER.EQATTENUATION"), 0x3, 0)
    writeReg(getNode("LPGBT.RWF.EQUALIZER.EQCAP"), 0x0, 0)
    writeReg(getNode("LPGBT.RWF.EQUALIZER.EQRES0"), 0x0, 0)
    writeReg(getNode("LPGBT.RWF.EQUALIZER.EQRES1"), 0x0, 0)
    writeReg(getNode("LPGBT.RWF.EQUALIZER.EQRES2"), 0x0, 0)
    writeReg(getNode("LPGBT.RWF.EQUALIZER.EQRES3"), 0x0, 0)

if __name__ == "__main__":
    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 Eye vs Equalizer")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-c", "--count", action="store", dest="count", default="0x7", help="EOMendOfCountSel[3:0] in hex")
    parser.add_argument("-eqa", "--eq_attn", action="store", nargs="+", dest="eq_attn", default=["0x3"], help="EQAttenuation[1:0] (in hex) = See lpGBT manual Section 15.1.5 for options, default=[0x3]")
    parser.add_argument("-eqc", "--eq_cap", action="store", nargs="+", dest="eq_cap", default=["0x0"], help="EQCap[1:0] (in hex) = See lpGBT manual Section 15.1.5 for options, default=[0x0]")
    parser.add_argument("-eqr3", "--eq_res3", action="store", nargs="+", dest="eq_res3", default=["0x0"], help="EQRes3[1:0] (in hex) = See lpGBT manual Section 15.1.5 for options, default=[0x0]")
    parser.add_argument("-eqr2", "--eq_res2", action="store", nargs="+", dest="eq_res2", default=["0x0"], help="EQRes2[1:0] (in hex) = See lpGBT manual Section 15.1.5 for options, default=[0x0]")
    parser.add_argument("-eqr1", "--eq_res1", action="store", nargs="+", dest="eq_res1", default=["0x0"], help="EQRes1[1:0] (in hex) = See lpGBT manual Section 15.1.5 for options, default=[0x0]")
    parser.add_argument("-eqr0", "--eq_res0", action="store", nargs="+", dest="eq_res0", default=["0x0"], help="EQRes0[1:0] (in hex) = See lpGBT manual Section 15.1.5 for options, default=[0x0]")
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

    if int(args.count,16) > 15:
        print (Colors.YELLOW + "EOMendOfCountSel[3:0] can be max 4 bits" + Colors.ENDC)
        sys.exit()

    for e in args.eq_attn:
        if int(e,16) > 3:
            print (Colors.YELLOW + "Setting can be max 2 bits, therefore: 0x0, 0x1, 0x2, 0x3" + Colors.ENDC)
            sys.exit()
    for e in args.eq_cap:
        if int(e,16) > 3:
            print (Colors.YELLOW + "Setting can be max 2 bits, therefore: 0x0, 0x1, 0x2, 0x3" + Colors.ENDC)
            sys.exit()
    for e in args.eq_res3:
        if int(e,16) > 3:
            print (Colors.YELLOW + "Setting can be max 2 bits, therefore: 0x0, 0x1, 0x2, 0x3" + Colors.ENDC)
            sys.exit()
    for e in args.eq_res2:
        if int(e,16) > 3:
            print (Colors.YELLOW + "Setting can be max 2 bits, therefore: 0x0, 0x1, 0x2, 0x3" + Colors.ENDC)
            sys.exit()
    for e in args.eq_res1:
        if int(e,16) > 3:
            print (Colors.YELLOW + "Setting can be max 2 bits, therefore: 0x0, 0x1, 0x2, 0x3" + Colors.ENDC)
            sys.exit()
    for e in args.eq_res0:
        if int(e,16) > 3:
            print (Colors.YELLOW + "Setting can be max 2 bits, therefore: 0x0, 0x1, 0x2, 0x3" + Colors.ENDC)
            sys.exit()

    # Initialization 
    rw_initialize(args.gem, args.system, oh_ver, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun":
        check_rom_readback(args.ohid, args.gbtid)
        check_lpgbt_mode(boss, args.ohid, args.gbtid)

    # Check if lpGBT is READY
    check_lpgbt_ready(args.ohid, args.gbtid) 

    try:
        main(args.system, oh_ver, int(args.count,16), args.eq_attn, args.eq_cap, args.eq_res3, args.eq_res2, args.eq_res1, args.eq_res0, boss)
    except KeyboardInterrupt:
        print (Colors.RED + "\nKeyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()

