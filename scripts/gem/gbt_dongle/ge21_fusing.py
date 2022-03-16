import usb_dongle
import time
import sys
import datetime

# from gbt_vldb import GBTx

# check for paused for config
# read GBTX serial number
# configure
# check for idle
# check FEC and SEU counters
# scan charge pump
# reconfigure
# check idle and FEC / SEU counters
# fuse
# ask to disconnect the dongle, and power cycle
# run the whole fused chip check
# check the link on the backed
#
# LOG everything!

######################### USER DEFINED CONSTANTS #########################
DRY_RUN = False # if this is set to true, the script will not fuse the chip, and also the tests will not terminate if they encounter an error
CONFIG_FILES = ["../../resources/ge21_gbt0_config.txt", "../../resources/ge21_gbt1_config.txt"] # config file paths for GBT0 and GBT1
FUSING_TEST = False # setting this to true will only fuse the lowest bit of the serial number
###########################################################################


USE_DONGLE_LDO = 1 # normally should be set to 1, but if you're using a dongle that has SW2 shorted, then you can set this to 0
NUM_CONFIG_REGS = 366
READ_ERRORS_TIME_WINDOW_SEC = 10
SLEEP_AFTER_CONFIGURE = 5
MAX_WRITE_REG_BLOCK_SIZE = 5
MAX_ATTEMPTS_TO_LOAD_FUSE_DATA = 100

DEBUG = False

# some globals for printing
G_GBT_ID = None
G_BOARD_SN = None
G_GBT_SN = None
LOG_FILE = None

# copy pasting some stuff from utils.py because this has to run on python2, which utils.py doesn't like...
class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ORANGE  = '\033[38;5;208m'
    ENDC    = '\033[39m'

def get_config(config_name):
    return eval("befe_config." + config_name)

def check_bit(byteval, idx):
    return ((byteval & (1 << idx)) != 0)

def print_to_log(msg):
    if LOG_FILE is not None:
        LOG_FILE.write(msg + "\n")

def print_normal(msg):
    print(msg)
    print_to_log(msg)

def print_color(msg, color):
    print(color + msg + Colors.ENDC)
    print_to_log(msg)

def color_string(msg, color):
    return color + msg + Colors.ENDC

def heading(msg):
    print_color('\n>>>>>>> ' + str(msg).upper() + ' <<<<<<<', Colors.BLUE)

def subheading(msg):
    print_color('---- ' + str(msg) + ' ----', Colors.YELLOW)

def print_cyan(msg):
    print_color(msg, Colors.CYAN)

def print_yellow(msg):
    print_color(msg, Colors.YELLOW)

def print_red(msg):
    print_color(msg, Colors.RED)

def print_green(msg):
    print_color(msg, Colors.GREEN)

def print_green_red(msg, controlValue, expectedValue):
    col = Colors.GREEN
    if controlValue != expectedValue:
        col = Colors.RED
    print_color(msg, col)

def hex(number):
    if number is None:
        return 'None'
    else:
        return "0x%x" % number

def hex8(number):
    if number is None:
        return 'None'
    else:
        return "0x%02x" % number

def hex32(number):
    if number is None:
        return 'None'
    else:
        return "0x%08x" % number

def parse_int(string):
    if string is None:
        return None
    elif isinstance(string, int):
        return string
    elif string.startswith('0x'):
        return int(string, 16)
    elif string.startswith('0b'):
        return int(string, 2)
    else:
        return int(string)

if sys.version_info > (3, 6):
    def raw_input(s):
        return input(Colors.YELLOW + s + Colors.ENDC)

# ---------------------------------------------------------------------------------

class GE21_dongle():

    PUSM_STATES = {0: "RESET", 19: "waitVCOstable", 1: "FCLRN", 2: "Contention", 3: "FSETP", 4: "Update", 5: "pauseForConfig", 6: "initXPLL", 7: "waitXPLLLock",
                   8: "resetDES", 9: "resetDES", 10: "waitDESLock", 11: "resetRXEPLL", 12: "resetRXEPLL", 13: "waitRXEPLLLock", 14: "resetSER", 15: "resetSER",
                   16: "waitSERLock", 17: "resetTXEPLL", 18: "resetTXEPLL", 19: "waitTXEPLLLock", 20: "dllReset", 21: "waitdllLocked", 22: "paReset", 23: "initScram",
                   26: "resetPSpll", 27: "resetPSpll", 28: "waitPSpllLocked", 29: "resetPSdll", 30: "waitPSdllLocked", 24: "IDLE"}

    def __init__(self, use_dongle_ldo):
        self.use_dongle_ldo = use_dongle_ldo
        self.dongle = usb_dongle.USB_dongle()
        fw = self.dongle.get_firmware_version()
        print("Dongle: %s" % fw)
        self.dongle.setvtargetldo(use_dongle_ldo)
        if use_dongle_ldo == 1:
            self.dongle.i2c_connect(1)

    def scan(self):
        addrs = self.dongle.i2c_scan()
        if len(addrs) > 0:
            self.gbtx_address = addrs[0]
        return addrs

    def disconnect(self):
        if self.use_dongle_ldo == 1:
            self.dongle.i2c_connect(0)

    def write_register(self, register, value):
        """write a value to a register"""
        reg_add_l=register&0xFF
        reg_add_h=(register>>8)&0xFF
        payload=[reg_add_l]+[reg_add_h]+[value]
        #print payload
        self.dongle.i2c_write(self.gbtx_address,payload)

    def write_register_block(self, start_addr, values):
        """write a value to a register"""

        val_idx = 0
        addr = start_addr
        regs_left = len(values)
        while regs_left > 0:
            n_write = regs_left if regs_left < MAX_WRITE_REG_BLOCK_SIZE else MAX_WRITE_REG_BLOCK_SIZE

            reg_add_l=addr&0xFF
            reg_add_h=(addr>>8)&0xFF
            payload=[reg_add_l]+[reg_add_h]+values[val_idx:val_idx+n_write]
            #print payload
            self.dongle.i2c_write(self.gbtx_address,payload)

            regs_left -= n_write
            addr += n_write
            val_idx += n_write

    def read_register(self, register):
        """read a value from a register - return register byte value"""
        reg_add_l=register&0xFF
        reg_add_h=(register>>8)&0xFF
        payload=[reg_add_l]+[reg_add_h]
        answer= self.dongle.i2c_writeread(self.gbtx_address,1,payload)
        return answer[1]

    def read_register_block(self, start_addr, num_regs):
        ret = []
        regs_left = num_regs
        addr = start_addr
        while regs_left > 0:
            n_read = regs_left if regs_left < 15 else 15
            reg_add_l=addr&0xFF
            reg_add_h=(addr>>8)&0xFF
            payload=[reg_add_l]+[reg_add_h]
            values = self.dongle.i2c_writeread(self.gbtx_address,n_read,payload)[1:]
            ret = ret + values
            regs_left -= n_read
            addr += n_read
        return ret

    def read_state(self):
        state = (self.read_register(431) >> 2) & 0x1F
        state_name = "Unknown"
        if state not in self.PUSM_STATES:
            print_red("Unknown GBTX PUSM state value %d" % state)
        else:
            state_name = self.PUSM_STATES[state]

        return state, state_name

    def fuse(self):
        self.dongle.burnefuse()

def log_open(board_sn, gbt_id):
    prefix = "gbtx_test_oh_sn_%d_gbt%d_" % (board_sn, gbt_id)
    datestr = datetime.datetime.now().strftime("%Y-%m-%d_%H:%M:%S")
    fname = prefix + datestr + ".log"
    global LOG_FILE
    LOG_FILE = open(fname, "w")

def log_close():
    if LOG_FILE is not None:
        LOG_FILE.close()

def fail(ignore_dry_run=False):
    if not DRY_RUN or ignore_dry_run:
        print_red("================================================================================")
        print_red("===================================== FAIL =====================================")
        print_red("================================================================================")
        print_red("GBT%d (SN: %d) on board SN %d has failed GBT test due to the above errors" % (G_GBT_ID, G_GBT_SN, G_BOARD_SN))
        log_close()
        exit(-1)

def read_config_file(filename):
    heading("Reading configuration file %s" % filename)
    ret = []
    with open(filename, 'r') as f:
        config = f.read()
        config = config.split('\n')
        for reg_addr in range(0, len(config) - 1):
            value = int(config[reg_addr], 16)
            ret.append(value)

    if len(ret) < NUM_CONFIG_REGS:
        print_red("ERROR: bad configuration file, expect at least %d register values, but found %d" % (NUM_CONFIG_REGS, len(ret)))
        log_close()
        exit(-1)

    return ret

def check_state0(state):
    if state == 0:
        print_red("ERROR: GBTX state is 0 (RESET)")
        print_red("This is usually a sign that I2C communication with the chip is not working")
        print_red("Most common cause is that the I2C communication is not enabled on the board: please make sure that SW3-4 is set to the ON position")
        print_red("If the switch is set correctly, you can try a power-cycle, but if the error persists after multiple power-cycles, set this board aside for investigation")
        print_red("IMPORTANT: don't forget to disconnect the dongle from the computer before power cycling the OH")
        print_red("Exiting...")
        log_close()
        exit(-1)

def test_state(dongle, is_fused):
    heading("TEST: GBTX state check")
    state, state_name = dongle.read_state()

    if not is_fused:
        if state_name != "pauseForConfig":
            check_state0(state)
            print_red("ERROR: GBTX state is %s, while pauseForConfig state is expected on a blank chip" % state_name)
            print_red("This can sometimes happen on a blank chip if the chip has not powered up correctly, please power-cycle and try again. If the error continues after multiple power-cycles, set this board aside for investigation.")
            print_red("IMPORTANT: don't forget to disconnect the dongle from the computer before power cycling the OH")
            fail()
        else:
            print_green("PASS: GBTX state is pauseForConfig as expected on a blank chip")
    else:
        if state_name != "IDLE":
            check_state0(state)
            print_red("ERROR: GBTX state is %s, while IDLE state is expected on a fused chip" % state_name)
            print_red("This means that the chip is not locked to the GBT data stream coming from the backend. There can be many causes for that, including bad fiber connection, bad chip configuration, etc..")
            fail()
        else:
            print_green("PASS: GBTX state is IDLE as expected on a fused chip")

# checks if the update from fuses bit is set, if it is it means the chip is reading the config from fuses on startup
def test_fuse_update_enabled(dongle, expected_value):
    heading("TEST: check if the 'update from fuses' bit is set (expect 0 for blank chip, and 1 for fused chip)")
    fuse_config = dongle.read_register(366)
    if (fuse_config & 1 == expected_value) and ((fuse_config & 2) >> 1 == expected_value) and ((fuse_config & 4) >> 2 == expected_value):
        print_green("PASS: fuse update enable bit is set to %d as expected" % expected_value)
    else:
        print_red("ERROR: fuse update enable bit value is not correct, expected %d, but read the triplicated value as %d%d%d" % (expected_value, fuse_config & 1, (fuse_config >> 1) & 1, (fuse_config >> 2) & 1))
        fail()

def read_gbtx_sn(dongle):
    heading("TEST: reading GBTX serial number from the test fuses")
    test_fuse1 = dongle.read_register(367)
    test_fuse2 = dongle.read_register(368)
    sn = (test_fuse2 << 8) + test_fuse1
    if sn != 0:
        print_green("PASS: GBTX serial number is not zero: %d (test fuse1 = %s, test fuse2 = %s)" % (sn, hex8(test_fuse1), hex8(test_fuse2)))
        return sn
    else:
        print_red("ERROR: GBTX serial number is 0")
        fail()

def configure(dongle, config):
    if len(config) < NUM_CONFIG_REGS:
        print_red("ERROR: configuration file has less than %d register values" % NUM_CONFIG_REGS)
        log_close()
        exit(-1)

    heading("Configuring GBTX...")
    dongle.write_register_block(0, config[:NUM_CONFIG_REGS])
    # for addr in range(NUM_CONFIG_REGS):
    #     dongle.write_register(addr, config[addr])

    print_green("Configuration DONE")

def read_and_compare_config(dongle, config):
    if len(config) < NUM_CONFIG_REGS:
        print_red("ERROR: configuration file has less than %d register values" % NUM_CONFIG_REGS)
        log_close()
        exit(-1)

    heading("Reading GBTX configuration from the chip, and comparing to the expected configuration")
    read_config = dongle.read_register_block(0, NUM_CONFIG_REGS)

    if DEBUG:
        print("Config dump:")
        for i in range(len(read_config)):
            print("    %d: %s" % (i, hex8(read_config[i])))

    # print("Received %d regs" % len(read_config))
    # read_config = []
    # for addr in range(NUM_CONFIG_REGS):
    #     value = dongle.read_register(addr)
    #     read_config.append(value)

    match = True
    for addr in range(NUM_CONFIG_REGS - 1):
        if read_config[addr] != config[addr]:
            match = False
            print_red("   Configuration register %d does not match the expected value, read %s, expect %s" % (addr, hex8(read_config[addr]), hex8(config[addr])))

    if not match:
        print_red("ERROR: Readback configuration does not match the expected configuration")
        fail()
    else:
        print_green("PASS: all readback register values match the values in the config file")

def read_errors(dongle, time_to_wait_sec):
    # 435 -- FEC correction count
    # 375 -- SEU correction count
    # 376 -- TX loss of lock count
    # 432 -- Ref PLL loss of lock count
    # 433 -- EPLL-TX loss of lock count
    # 434 -- EPLL-RX loss of lock count

    heading("TEST: Reading GBTX error counters in a %d second time window" % time_to_wait_sec)
    fec_err_cnt = dongle.read_register(435)
    seu_err_cnt = dongle.read_register(375)
    tx_lock_loss_cnt = dongle.read_register(376)
    ref_pll_lock_loss_cnt = dongle.read_register(432)
    epll_tx_lock_loss_cnt = dongle.read_register(433)
    epll_rx_lock_loss_cnt = dongle.read_register(434)

    time.sleep(time_to_wait_sec)

    fec_err_cnt = dongle.read_register(435) - fec_err_cnt
    seu_err_cnt = dongle.read_register(375) - seu_err_cnt
    tx_lock_loss_cnt = dongle.read_register(376) - tx_lock_loss_cnt
    ref_pll_lock_loss_cnt = dongle.read_register(432) - ref_pll_lock_loss_cnt
    epll_tx_lock_loss_cnt = dongle.read_register(433) - epll_tx_lock_loss_cnt
    epll_rx_lock_loss_cnt = dongle.read_register(434) - epll_rx_lock_loss_cnt

    print_green_red("    FEC error correction count: %d" % fec_err_cnt, fec_err_cnt, 0)
    print_green_red("    SEU correction count (register triplication correction): %d" % seu_err_cnt, seu_err_cnt, 0)
    print_green_red("    Serializer loss of lock count: %d" % tx_lock_loss_cnt, tx_lock_loss_cnt, 0)
    print_green_red("    Ref PLL loss of lock count: %d" % ref_pll_lock_loss_cnt, ref_pll_lock_loss_cnt, 0)
    print_green_red("    Elink TX PLL loss of lock count: %d" % epll_tx_lock_loss_cnt, epll_tx_lock_loss_cnt, 0)
    print_green_red("    Elink RX PLL loss of lock count: %d" % epll_rx_lock_loss_cnt, epll_rx_lock_loss_cnt, 0)

    if fec_err_cnt + seu_err_cnt + tx_lock_loss_cnt + ref_pll_lock_loss_cnt + epll_tx_lock_loss_cnt + epll_rx_lock_loss_cnt != 0:
        print_red("ERROR: GBTX error counters are not zero")
        print_red("Possible causes: bad fiber connection, bad VTRX, or a bad chip")
        fail()
    else:
        print_green("PASS: All GBTX error counters are zero")

def fuse(dongle, address, value):
    print("Fusing address %d to value %s" % (address, hex8(value)))
    addr_l = address & 0xff
    addr_h = (address >> 8) & 0xff

    ready = False
    attempt_cnt = 0
    while (ready == False) and (attempt_cnt < MAX_ATTEMPTS_TO_LOAD_FUSE_DATA):
        dongle.write_register(238, addr_l) # load the lower address byte
        dongle.write_register(239, addr_h) # load the higher address byte
        dongle.write_register(240, value)  # load the value to be fused
        addr_l_read = dongle.read_register(238)
        addr_h_read = dongle.read_register(239)
        value_read = dongle.read_register(240)

        if addr_l_read == addr_l and addr_h_read == addr_h and value_read == value:
            print_normal("Fusing data register readback for address %d is correct: addr_l readback = %s expected = %s, addr_h readback = %s expected %s, value readback = %s expected %s" % (address, hex8(addr_l_read), hex8(addr_l), hex8(addr_h_read), hex8(addr_h), hex8(value_read), hex8(value)))
            ready = True
        else:
            print_yellow("Attempt #%d to load fusing data for address %d failed: addr_l readback = %s expected = %s, addr_h readback = %s expected %s, value readback = %s expected %s" % (attempt_cnt, address, hex8(addr_l_read), hex8(addr_l), hex8(addr_h_read), hex8(addr_h), hex8(value_read), hex8(value)))
        attempt_cnt += 1

    if ready:
        dongle.fuse() # apply 3.3V fuse power and send the fuse pulse
    else:
        print_red("Made %d attempts to load fusing data for address %d, but all of them failed, giving up.." % (attempt_cnt, address))
        fail(True)

def fuse_all_non_zero(dongle, config):
    # go through the config, and fuse all regs that have a non-zero value
    for addr in range(NUM_CONFIG_REGS):
        val = config[addr]
        if val != 0:
            fuse(dongle, addr, val)

    # fuse the update enable bit which will cause the GBTX to load the config from fuses on power-up
    fuse(dongle, 366, 0x7)

def dongle_connect():
    dongle = None
    try:
        dongle = GE21_dongle(USE_DONGLE_LDO)
        print_green("Connected to the dongle")
    except Exception as e:
        print_red(e)
        print_red("ERROR: Could not connect to the dongle")
        print_red("Please check that you have the dongle connected to the computer")
        print_red("If you are running this application as a non-root user, make sure you have a file in /etc/udev/rules.d with the following contents:")
        print_red('ACTION=="add", ATTR{idVendor}=="16c0", ATTR{idProduct}=="05df", MODE:="666"')
        print_red("If you didn't have the file and now you created it, you have to execute: sudo udevadm control --reload-rules")
        print_red("Exiting...")
        log_close()
        exit(-1)

    return dongle

def get_gbt_id(dongle):
    gbt_addrs = dongle.scan()
    if len(gbt_addrs) < 1:
        print_red("ERROR: No GBTX chip detected on the I2C bus")
        print_red("Please check that the dongle is connected to the OH")
        print_red("Exiting...")
        log_close()
        exit(-1)

    if len(gbt_addrs) > 1:
        print_red("ERROR: more than one GBTX detected on the I2C bus... this should not be the case on GE2/1 OH..")
        print_red("Exiting...")
        log_close()
        exit(-1)

    gbt_addr = gbt_addrs[0]
    gbt_id = -1
    if gbt_addr == 1:
        gbt_id = 0
    elif gbt_addr == 3:
        gbt_id = 1
    else:
        print_red("ERROR: unknown GBT I2C address detected: %d" % gbt_addr)
        print_red("Is the dongle connected to a GE2/1 OH board or something else?..")
        print_red("Exiting...")
        log_close()
        exit(-1)

    return gbt_id

def run_all_tests(dongle, board_sn, expected_gbt_id, is_fused):

    gbt_id = get_gbt_id(dongle)
    if gbt_id != expected_gbt_id:
        print_red("ERROR: Detected GBT%d, but expected GBT%d, exiting" % (gbt_id, expected_gbt_id))
        print_red("Please check if you connected the dongle to the correct GBT")
        log_close()
        exit(-1)

    if LOG_FILE is None:
        log_open(board_sn, gbt_id)

    print_green("GE2/1 GBT%d chip detected" % gbt_id)
    sn = read_gbtx_sn(dongle)
    global G_GBT_SN
    G_GBT_SN = sn

    test_state(dongle, is_fused)
    expect_update_fuse = 1 if is_fused else 0
    test_fuse_update_enabled(dongle, expect_update_fuse)

    config_filename = CONFIG_FILES[gbt_id]
    config = read_config_file(config_filename)

    if not is_fused:
        configure(dongle, config)
        time.sleep(SLEEP_AFTER_CONFIGURE)
        read_and_compare_config(dongle, config)
        test_state(dongle, True)
    else:
        read_and_compare_config(dongle, config)

    read_errors(dongle, READ_ERRORS_TIME_WINDOW_SEC)

    return config

if __name__ == '__main__':

    heading("Welcome to the GE2/1 GBTX testing and fusing application")

    if DRY_RUN:
        subheading("NOTE: the software is running in DRY RUN mode")
        subheading("This means that it will not fuse the chip, and will also not terminate if errors / problems are found")
        subheading("To disable the DRY_RUN mode, edit this python file and change the DRY_RUN constant to False")

    board_sn_str = raw_input(Colors.YELLOW + "Please enter the board serial number: " + Colors.ENDC)
    board_sn = parse_int(board_sn_str)
    test_blank_str = raw_input('Are you testing a blank chip or a fused chip? Please type in "blank" or "fused": ')
    is_fused = None
    if test_blank_str == "blank":
        is_fused = False
    elif test_blank_str == "fused":
        is_fused = True
    else:
        print_red('ERROR: unrecognized answer "%s", blank or fused are the only valid answers..' % test_blank_str)
        print_red("Exiting...")
        log_close()
        exit(-1)

    dongle = dongle_connect()
    gbt_id = get_gbt_id(dongle)

    G_GBT_ID = gbt_id
    G_BOARD_SN = board_sn

    config = run_all_tests(dongle, board_sn, gbt_id, is_fused)

    if (not is_fused) and ((not DRY_RUN) or FUSING_TEST):
        print("")
        print_yellow("================================================================================")
        print_yellow("==================================== FUSING ====================================")
        print_yellow("================================================================================")
        print("")
        print_yellow("Are you sure you want to fuse? Please type YES (in capital letters) to continue")
        fuse_answer = raw_input('')
        if fuse_answer != "YES":
            print("You did not enter YES, exiting without fusing")
            log_close()
            exit(0)
        else:
            if FUSING_TEST:
                fuse(dongle, 367, 0x1) # fuse the lowest bit of SN
            else:
                fuse_all_non_zero(dongle, config)

        time.sleep(1)
        dongle.disconnect()

        print_yellow("Fusing DONE")
        print("")
        print_yellow("Please do the following steps in the exact order:")
        print_yellow("    1) Disconnect the dongle from the PC USB (do not disconnect from OH)")
        print_yellow("    2) Power cycle the OH")
        print_yellow("    3) Connect the dongle back to the PC USB")
        print_yellow("    4) Press enter here, and this script will check if the fusing was successful")
        raw_input("")

        dongle = dongle_connect()
        run_all_tests(dongle, board_sn, gbt_id, True)

    dongle.disconnect()

    print("")
    print_yellow("As the last step, please check that the GBT is ready on the backend using reg_interface.py:")
    for backend in ["CTP7", "CVP13"]:
        print_color("==================== Instructions for %s ====================" % backend, Colors.CYAN)
        print_yellow("    1) write BEFE.GEM.GEM_SYSTEM.CTRL.LINK_RESET 1" % befe_str)
        print_yellow("    2) wait 10s")
        print_yellow("    3) read BEFE.GEM.OH_LINKS.OH0.GBT%d_READY" % (befe_str, gbt_id))
        print_yellow("    4) read BEFE.GEM.OH_LINKS.OH0.GBT%d_WAS_NOT_READY" % (befe_str, gbt_id))

    print("")
    print_yellow("Please enter the GBT READY value you read: ")
    gbt_ready_str = raw_input("")
    gbt_ready = parse_int(gbt_ready_str)
    print_yellow("Please enter the GBT WAS NOT READY value you read: ")
    gbt_was_not_ready_str = raw_input("")
    gbt_was_not_ready = parse_int(gbt_was_not_ready_str)

    if (gbt_ready == 0) or (gbt_was_not_ready == 1):
        print_red("ERROR: GBT is not locked on the backend, or the lock is unstable")
        print_red("Please check the fibers..")
        fail()

    print("")
    print_green("================================================================================")
    print_green("===================================== PASS =====================================")
    print_green("================================================================================")
    print_green("GBT%d (SN: %d) on board SN %d has passed all tests" % (G_GBT_ID, G_GBT_SN, G_BOARD_SN))

    log_close()
