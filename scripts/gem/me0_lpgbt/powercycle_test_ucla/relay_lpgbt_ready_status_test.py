import ethernet_relay
from gem.me0_lpgbt.rw_reg_lpgbt import *
import gem.gem_utils as gem_utils
from time import sleep
import sys
import argparse

def main(system, oh_select, gbt_list, relay_number, niter):

    if sys.version_info[0] < 3:
        raise Exception("Python version 3.x required")

    relay_object = ethernet_relay.ethernet_relay()
    connect_status = relay_object.connectToDevice()
    if not connect_status:
        print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
        rw_terminate()

    # Get first list of registers to compare
    print ("Turning on power and getting initial list of registers and turning off power")
    set_status = relay_object.relay_set(relay_number, 1)
    if not set_status:
        print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
        rw_terminate()
    read_status = relay_object.relay_read(relay_number)
    if not read_status:
        print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
        rw_terminate()
    sleep(10)

    reg_list_boss = {}
    reg_list_sub = {}
    n_rw_reg = 0
    for gbt in gbt_list["boss"]:
        reg_list_boss[gbt] = {}
        oh_ver = get_oh_ver(str(oh_select), str(gbt))
        if oh_ver == 1:
            n_rw_reg = (0x13C+1)
        if oh_ver == 2:
            n_rw_reg = (0x14F+1)
        select_ic_link(oh_select, gbt)
        for reg in range(n_rw_reg):
            reg_list_boss[gbt][reg] = mpeek(reg)
    for gbt in gbt_list["sub"]:
        reg_list_sub[gbt] = {}
        oh_ver = get_oh_ver(str(oh_select), str(gbt))
        select_ic_link(oh_select, gbt)
        if oh_ver == 1:
            for i in range(0,10):
                test_read = mpeek(0x00)
            n_rw_reg = (0x13C+1)
        if oh_ver == 2:
            n_rw_reg = (0x14F+1)
        for reg in range(n_rw_reg):
            reg_list_sub[gbt][reg] = mpeek(reg)

    set_status = relay_object.relay_set(relay_number, 0)
    if not set_status:
        print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
        rw_terminate()
    read_status = relay_object.relay_read(relay_number)
    if not read_status:
        print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
        rw_terminate()
    sleep(10)
   
    n_error_backend_ready_boss = {}
    n_error_backend_ready_sub = {}
    n_error_uplink_fec_boss = {}
    n_error_uplink_fec_sub = {}
    n_error_pusm_ready_boss = {}
    n_error_pusm_ready_sub = {}
    n_error_mode_boss = {}
    n_error_mode_sub = {}
    n_error_reg_list_boss = {}
    n_error_reg_list_sub = {}

    for gbt in gbt_list["boss"]:
        n_error_backend_ready_boss[gbt] = 0
        n_error_uplink_fec_boss[gbt] = 0
        n_error_pusm_ready_boss[gbt] = 0
        n_error_mode_boss[gbt] = 0
        n_error_reg_list_boss[gbt] = 0
    for gbt in gbt_list["sub"]:
        n_error_backend_ready_sub[gbt] = 0
        n_error_uplink_fec_sub[gbt] = 0
        n_error_pusm_ready_sub[gbt] = 0
        n_error_mode_sub[gbt] = 0
        n_error_reg_list_sub[gbt] = 0

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

        # Link reset
        gem_utils.gem_link_reset()
        sleep(2)

        # Check lpGBT status
        # Boss
        for gbt in gbt_list["boss"]:
            oh_ver = get_oh_ver(str(oh_select), str(gbt))
            select_ic_link(oh_select, gbt)
            n_rw_reg = 0
            print ("Boss lpGBT %d: "%gbt)

            # Check Link Ready
            link_ready = gem_utils.read_backend_reg(gem_utils.get_backend_node("BEFE.GEM.OH_LINKS.OH%s.GBT%s_READY" % (oh_select, gbt)))
            if (link_ready!=1):
                print (Colors.YELLOW + "  Link NOT READY" + Colors.ENDC)
                n_error_backend_ready_boss[gbt] += 1
            else:
                print (Colors.GREEN + "  Link READY" + Colors.ENDC)

            # Check Uplink FEC Errors
            n_fec_errors = gem_utils.read_backend_reg(gem_utils.get_backend_node("BEFE.GEM.OH_LINKS.OH%d.GBT%d_FEC_ERR_CNT" % (oh_select, gbt)))
            if n_fec_errors!=0:
                print (Colors.YELLOW + "  FEC Errors: %d"%(n_fec_errors) + Colors.ENDC)
                n_error_uplink_fec_boss[gbt] += 1
            else:
                print (Colors.GREEN + "  No FEC Errors" + Colors.ENDC)

            # Check lpGBT PUSM READY and MODE
            if oh_ver == 1:
                ready_value = 18
                mode_value = 11
                mode = (mpeek(0x140) & 0xF0) >> 4
                pusmstate = mpeek(0x1C7)
            elif oh_ver == 2:
                ready_value = 19
                mode_value = 11
                mode = (mpeek(0x150) & 0xF0) >> 4
                pusmstate = mpeek(0x1D9)

            if mode != mode_value:
                n_error_mode_boss[gbt] += 1
                print (Colors.YELLOW + "  Incorrect mode: %d"%mode + Colors.ENDC)
            else:
                print (Colors.GREEN + "  Correct mode: %d"%mode + Colors.ENDC)
            if pusmstate != ready_value:
                n_error_pusm_ready_boss[gbt] += 1
                print (Colors.YELLOW + "  Incorrect PUSM State: %d"%pusmstate + Colors.ENDC)
            else:
                print (Colors.GREEN + "  Correct PUSM State: %d"%pusmstate + Colors.ENDC)

            # Check register list
            if oh_ver == 1:
                n_rw_reg = (0x13C+1)
            if oh_ver == 2:
                n_rw_reg = (0x14F+1)
            for reg in range(n_rw_reg):
                val = mpeek(reg)
                if val != reg_list_boss[gbt][reg]:
                    n_error_reg_list_boss[gbt] += 1
                    print (Colors.YELLOW + "  Register 0x%02X value mismatch"%reg + Colors.ENDC)

        # Sub
        for gbt in gbt_list["sub"]:
            oh_ver = get_oh_ver(str(oh_select), str(gbt))
            select_ic_link(oh_select, gbt)
            n_rw_reg = 0
            print ("Sub lpGBT %d: "%gbt)

            # Check Link Ready
            link_ready = gem_utils.read_backend_reg(gem_utils.get_backend_node("BEFE.GEM.OH_LINKS.OH%s.GBT%s_READY" % (oh_select, gbt)))
            if (link_ready!=1):
                print (Colors.YELLOW + "  Link NOT READY" + Colors.ENDC)
                n_error_backend_ready_sub[gbt] += 1
            else:
                print (Colors.GREEN + "  Link READY" + Colors.ENDC)

            # Check Uplink FEC Errors
            n_fec_errors = gem_utils.read_backend_reg(gem_utils.get_backend_node("BEFE.GEM.OH_LINKS.OH%d.GBT%d_FEC_ERR_CNT" % (oh_select, gbt)))
            if n_fec_errors!=0:
                print (Colors.YELLOW + "  FEC Errors: %d"%(n_fec_errors) + Colors.ENDC)
                n_error_uplink_fec_sub[gbt] += 1
            else:
                print (Colors.GREEN + "  No FEC Errors" + Colors.ENDC)

            # Check lpGBT PUSM READY and MODE
            if oh_ver == 1:
                for i in range(0,10):
                    test_read = mpeek(0x00)
                ready_value = 18
                mode_value = 9
                mode = (mpeek(0x140) & 0xF0) >> 4
                pusmstate = mpeek(0x1C7)
            elif oh_ver == 2:
                ready_value = 19
                mode_value = 9
                mode = (mpeek(0x150) & 0xF0) >> 4
                pusmstate = mpeek(0x1D9)

            if mode != mode_value:
                n_error_mode_sub[gbt] += 1
                print (Colors.YELLOW + "  Incorrect mode: %d"%mode + Colors.ENDC)
            else:
                print (Colors.GREEN + "  Correct mode: %d"%mode + Colors.ENDC)
            if pusmstate != ready_value:
                n_error_pusm_ready_sub[gbt] += 1
                print (Colors.YELLOW + "  Incorrect PUSM State: %d"%pusmstate + Colors.ENDC)
            else:
                print (Colors.GREEN + "  Correct PUSM State: %d"%pusmstate + Colors.ENDC)

            # Check register list
            if oh_ver == 1:
                n_rw_reg = (0x13C+1)
            if oh_ver == 2:
                n_rw_reg = (0x14F+1)
            for reg in range(n_rw_reg):
                val = mpeek(reg)
                if val != reg_list_sub[gbt][reg]:
                    n_error_reg_list_sub[gbt] += 1
                    print (Colors.YELLOW + "  Register 0x%02X value mismatch"%reg + Colors.ENDC)

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
    print ("Number of iterations: %d\n"%niter)

    # Results
    print ("Result For lpGBTs: \n")
    for gbt in gbt_list["boss"]:
        print ("Boss lpGBT %d: "%gbt)
        str_n_error_backend_ready_boss = ""
        str_n_error_uplink_fec_boss = ""
        str_n_error_mode_boss = ""
        str_n_error_pusm_ready_boss = ""
        str_n_error_reg_list_boss = ""
        if n_error_backend_ready_boss[gbt]==0:
            str_n_error_backend_ready_boss += Colors.GREEN
        else:
            str_n_error_backend_ready_boss += Colors.YELLOW
        if n_error_uplink_fec_boss[gbt]==0:
            str_n_error_uplink_fec_boss += Colors.GREEN
        else:
            str_n_error_uplink_fec_boss += Colors.YELLOW
        if n_error_mode_boss[gbt]==0:
            str_n_error_mode_boss += Colors.GREEN
        else:
            str_n_error_mode_boss += Colors.YELLOW
        if n_error_pusm_ready_boss[gbt]==0:
            str_n_error_pusm_ready_boss += Colors.GREEN
        else:
            str_n_error_pusm_ready_boss += Colors.YELLOW
        if n_error_reg_list_boss[gbt]==0:
            str_n_error_reg_list_boss += Colors.GREEN
        else:
            str_n_error_reg_list_boss += Colors.YELLOW
        str_n_error_backend_ready_boss += "  Number of Backend READY Status Errors: %d"%(n_error_backend_ready_boss[gbt])
        str_n_error_uplink_fec_boss += "  Number of Powercycles with Uplink FEC Errors: %d"%n_error_uplink_fec_boss[gbt]
        str_n_error_mode_boss += "  Number of Mode Errors: %d"%n_error_mode_boss[gbt]
        str_n_error_pusm_ready_boss += "  Number of PUSMSTATE Errors: %d"%n_error_pusm_ready_boss[gbt]
        str_n_error_reg_list_boss += "  Number of Register Value Errors: %d"%n_error_reg_list_boss[gbt]
        str_n_error_backend_ready_boss += Colors.ENDC
        str_n_error_uplink_fec_boss += Colors.ENDC
        str_n_error_mode_boss += Colors.ENDC
        str_n_error_pusm_ready_boss += Colors.ENDC
        str_n_error_reg_list_boss += Colors.ENDC
        print (str_n_error_backend_ready_boss)
        print (str_n_error_uplink_fec_boss)
        print (str_n_error_mode_boss)
        print (str_n_error_pusm_ready_boss)
        print (str_n_error_reg_list_boss)

    print ("")
    for gbt in gbt_list["sub"]:
        print ("Sub lpGBT %d: "%gbt)
        str_n_error_backend_ready_sub = ""
        str_n_error_uplink_fec_sub = ""
        str_n_error_mode_sub = ""
        str_n_error_pusm_ready_sub = ""
        str_n_error_reg_list_sub = ""
        if n_error_backend_ready_sub[gbt]==0:
            str_n_error_backend_ready_sub += Colors.GREEN
        else:
            str_n_error_backend_ready_sub += Colors.YELLOW
        if n_error_uplink_fec_sub[gbt]==0:
            str_n_error_uplink_fec_sub += Colors.GREEN
        else:
            str_n_error_uplink_fec_sub += Colors.YELLOW
        if n_error_mode_sub[gbt]==0:
            str_n_error_mode_sub += Colors.GREEN
        else:
            str_n_error_mode_sub += Colors.YELLOW
        if n_error_pusm_ready_sub[gbt]==0:
            str_n_error_pusm_ready_sub += Colors.GREEN
        else:
            str_n_error_pusm_ready_sub += Colors.YELLOW
        if n_error_reg_list_sub[gbt]==0:
            str_n_error_reg_list_sub += Colors.GREEN
        else:
            str_n_error_reg_list_sub += Colors.YELLOW
        str_n_error_backend_ready_sub += "  Number of Backend READY Status Errors: %d"%(n_error_backend_ready_sub[gbt])
        str_n_error_uplink_fec_sub += "  Number of Powercycles with Uplink FEC Errors: %d"%n_error_uplink_fec_sub[gbt]
        str_n_error_mode_sub += "  Number of Mode Errors: %d"%n_error_mode_sub[gbt]
        str_n_error_pusm_ready_sub += "  Number of PUSMSTATE Errors: %d"%n_error_pusm_ready_sub[gbt]
        str_n_error_reg_list_sub += "  Number of Register Value Errors: %d"%n_error_reg_list_sub[gbt]
        str_n_error_backend_ready_sub += Colors.ENDC
        str_n_error_uplink_fec_sub += Colors.ENDC
        str_n_error_mode_sub += Colors.ENDC
        str_n_error_pusm_ready_sub += Colors.ENDC
        str_n_error_reg_list_sub += Colors.ENDC
        print (str_n_error_backend_ready_sub)
        print (str_n_error_uplink_fec_sub)
        print (str_n_error_mode_sub)
        print (str_n_error_pusm_ready_sub)
        print (str_n_error_reg_list_sub)

    print ("")

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Checking Status of LpGBT Configuration for ME0 Optohybrid")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", nargs="+", dest="gbtid", help="gbtid = List of GBT IDs")
    parser.add_argument("-r", "--relay_number", action="store", dest="relay_number", help="relay_number = Relay Number used")
    parser.add_argument("-n", "--niter", action="store", dest="niter", default="1000", help="niter = Number of iterations (default=1000)")
    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for testing")
    else:
        print (Colors.YELLOW + "Only valid options: backend" + Colors.ENDC)
        sys.exit()

    gbt_list = {}
    gbt_list["boss"] = []
    gbt_list["sub"] = []
    oh_select = -9999
    if args.ohid is None:
        print (Colors.YELLOW + "Need OHID for backend" + Colors.ENDC)
        sys.exit()
    if args.gbtid is None:
        print (Colors.YELLOW + "Need Boss GBTID for backend" + Colors.ENDC)
        sys.exit()
    oh_select = int(args.ohid)
    #if oh_select > 1:
    #    print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
    #    sys.exit()
    for gbt in args.gbtid:
        if int(gbt) > 7:
            print(Colors.YELLOW + "Only GBTID 0-7 allowed" + Colors.ENDC)
            sys.exit()
        if int(gbt)%2 == 0:
            gbt_list["boss"].append(int(gbt))
        else:
            gbt_list["sub"].append(int(gbt))

    relay_number = -9999
    if args.relay_number is None:
        print (Colors.YELLOW + "Enter Relay Number" + Colors.ENDC)
        sys.exit()
    relay_number = int(args.relay_number)
    if relay_number not in range(0,8):
        print (Colors.YELLOW + "Valid Relay Number: 0-7" + Colors.ENDC)
        sys.exit()

    # Initialization
    rw_initialize(args.gem, args.system)
    print("Initialization Done\n")

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



