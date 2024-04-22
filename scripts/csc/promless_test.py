import time
import sys
from common.utils import *
import csc.ypage_status

# remote
if len(sys.argv) > 1 and "rpyc_classic.py" not in sys.argv[0]:
    hostname = sys.argv[1]
    heading("Connecting to %s" % hostname)
    import rpyc
    conn = rpyc.classic.connect(hostname)
    conn._config["sync_request_timeout"] = 240
    rw = conn.modules["common.rw_reg"]
    befe = conn.modules["common.fw_utils"]

# local
else:
    heading("Running locally")
    import common.rw_reg as rw
    import common.fw_utils as befe

# use ypage_status.py to construct a ypage object to pass here
def csc_promless_test(num_iter, ypage, ignore_cfeb_arr = [False] * 7, ignore_alct = False, print_warnings=True, prog_wait_time=0.3):
    # Set the XDCFEB and ALCT switches to enable PROMless programming
    rw.write_reg("BEFE.CSC_FED.CSC_SYSTEM.XDCFEB.GBT_OVERRIDE", 1) # only override is needed for XDCFEBs, other switches are ok as default
    rw.write_reg("BEFE.CSC_FED.CSC_SYSTEM.ALCT.SEL_GBT_CCLK_SRC", 0) # bad default in early firmware versions
    rw.write_reg("BEFE.CSC_FED.CSC_SYSTEM.ALCT.GBT_OVERRIDE", 1)
    # enable TTC generator
    rw.write_reg("BEFE.CSC_FED.TTC.GENERATOR.ENABLE", 1)

    cfeb_hr_fail_cnt = [0] * 7
    cfeb_prog_fail_cnt = [0] * 7
    alct_hr_fail_cnt = 0
    alct_prog_fail_cnt = 0
    hr_retry_cnt = 0
    any_fail_cnt = 0
    # enter a loop of issuing a hard reset, making sure the boards are unprogrammed, and then programming from X2O, and checking to make sure the boards are programmed
    for i in range(num_iter):
        print("==== Iteration %d ====" % i)
        any_fail = False

        # hard reset from YP
        # have seen cases where the YP hard reset didn't actually work 
        hr_attempts = 0
        hr_done = False
        while (not hr_done) and (hr_attempts < 3):
            if hr_attempts > 0:
                print("    WARN: Retrying YP hard reset")
                hr_retry_cnt += 1
            ypage.CCB_hard_rest_fast()
            hr_done = ypage.alct_status()["ALCT"]["FPGA DONE"] == 0
            hr_attempts += 1

        # sleep to make sure the boards get the chance to program from the PROM in case the GBT is not working, so that we can catch this condition by seeing DONE=1 in the status
        time.sleep(prog_wait_time)
        cfeb_status = ypage.cfeb_status()
        alct_status = ypage.alct_status()

        # since HR was done from YP and X2O has not sent the bitstream, all boards should be unprogrammed at this point
        for cfeb in range(7):
            if ignore_cfeb_arr[cfeb]:
                continue
            if cfeb_status[cfeb]["FPGA DONE"] != 0:
                if print_warnings:
                    print("    * FAIL: CFEB%d DONE is high after hard reset from YP but before programming from X2O" % cfeb)
                cfeb_hr_fail_cnt[cfeb] += 1
                any_fail = True
        
        if not ignore_alct and alct_status["ALCT"]["FPGA DONE"] != 0:
            if print_warnings:
                print("    * FAIL: ALCT DONE is high after hard reset from YP but before programming from X2O")
            alct_hr_fail_cnt += 1
            any_fail = True

        # execute the programming from the X2O, and check the status to see if the boards are now programmed
        rw.write_reg("BEFE.CSC_FED.TTC.GENERATOR.SINGLE_HARD_RESET", 1)
        time.sleep(prog_wait_time)
        cfeb_status = ypage.cfeb_status()
        alct_status = ypage.alct_status()

        for cfeb in range(7):
            if ignore_cfeb_arr[cfeb]:
                continue
            if cfeb_status[cfeb]["FPGA DONE"] != 1:
                if print_warnings:
                    print("    * FAIL: CFEB%d failed to program via PROMless after X2O HR" % cfeb)
                cfeb_prog_fail_cnt[cfeb] += 1
                any_fail = True
        
        if not ignore_alct and alct_status["ALCT"]["FPGA DONE"] != 1:
            if print_warnings:
                print("    * FAIL: ALCT failed to program via PROMless after X2O HR")
            alct_prog_fail_cnt += 1
            any_fail = True

        if any_fail:
            any_fail_cnt += 1
        if not any_fail:
            print("    * success for all boards")
        
        print("Total iterations with failures so far: %d" % any_fail_cnt)
        if hr_retry_cnt > 0:
            print("Total HR retries so far: %d" % hr_retry_cnt)
    
    print("")
    print("=========================================")
    print("================ SUMMARY ================")
    print("=========================================")
    print("Total number of PROMless cycles tested: %d" % num_iter)
    print("ALCT hard-reset fail count: %d" % alct_hr_fail_cnt)
    for cfeb in range(7):
        if not ignore_cfeb_arr[cfeb]:
            print("CFEB%d hard-reset fail count: %d" % (cfeb, cfeb_hr_fail_cnt[cfeb]))
        else:
            print("CFEB%d ignored" % cfeb)
    print("ALCT programming fail count: %d" % alct_prog_fail_cnt)
    for cfeb in range(7):
        if not ignore_cfeb_arr[cfeb]:
            print("CFEB%d programming fail count: %d" % (cfeb, cfeb_prog_fail_cnt[cfeb]))
        else:
            print("CFEB%d ignored" % cfeb)

    print("Total HR retries: %d" % hr_retry_cnt)

if __name__ == "__main__":
    rw.parse_xml()
    fw_flavor = rw.read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
    if fw_flavor == 0xdeaddead:
        print_red("ERROR: Cannot access X2O registers, is the board programmed?")
        exit()
    elif str(fw_flavor) != "CSC_FED":
        print_red("ERROR: X2O is not running CSC firmware: %s" % fw_flavor)
        exit()
    
    # if len(sys.argv) < 2:
    #     print("Usage: promless_test.py <num_iter>")
    #     exit()
    # num_iter = sys.argv[1]

    num_iter = 1000

    ypage = csc.ypage_status.yellowpageStatus()

    csc_promless_test(num_iter, ypage, ignore_cfeb_arr=[False, False, False, False, False, True, False], ignore_alct=False)