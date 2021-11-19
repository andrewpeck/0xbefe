import usb_dongle
import time
import sys

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
#
#
# LOG everything!

USE_DONGLE_LDO = 1
DRY_RUN = True
NUM_CONFIG_REGS = 366
READ_ERRORS_TIME_WINDOW_SEC = 10
SLEEP_AFTER_CONFIGURE = 3

DEBUG = False

CONFIG_FILES = ["../../resources/ge21_gbt0_config.txt", "../../resources/ge21_gbt1_config.txt"]

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

def print_color(msg, color):
    print(color + msg + Colors.ENDC)

def color_string(msg, color):
    return color + msg + Colors.ENDC

def heading(msg):
    print_color('\n>>>>>>> ' + str(msg).upper() + ' <<<<<<<', Colors.BLUE)

def subheading(msg):
    print_color('---- ' + str(msg) + ' ----', Colors.YELLOW)

def print_cyan(msg):
    print_color(msg, Colors.CYAN)

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
            n_write = regs_left if regs_left < 15 else 15

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
        exit(-1)

def test_state(dongle, is_fused):
    heading("TEST0: GBTX state check")
    state, state_name = dongle.read_state()

    if not is_fused:
        if state_name != "pauseForConfig":
            check_state0(state)
            print_red("ERROR: GBTX state is %s, while pauseForConfig state is expected on a blank chip" % state_name)
            print_red("This can sometimes happen on a blank chip if the chip has not powered up correctly, please power-cycle and try again. If the error continues after multiple power-cycles, set this board aside for investigation.")
            print_red("IMPORTANT: don't forget to disconnect the dongle from the computer before power cycling the OH")
            if not DRY_RUN:
                print_red("Exiting...")
                exit(-1)
        else:
            print_green("PASS: GBTX state is pauseForConfig as expected on a blank chip")
    else:
        if state_name != "IDLE":
            check_state0(state)
            print_red("ERROR: GBTX state is %s, while IDLE state is expected on a fused chip" % state_name)
            print_red("This means that the chip is not locked to the GBT data stream coming from the backend. There can be many causes for that, including bad fiber connection, bad chip configuration, etc..")
            if not DRY_RUN:
                print_red("Exiting...")
                exit(-1)
        else:
            print_green("PASS: GBTX state is IDLE as expected on a fused chip")

# checks if the update from fuses bit is set, if it is it means the chip is reading the config from fuses on startup
def test_fuse_update_enabled(dongle, expected_value):
    heading("TEST1: check if the 'update from fuses' bit is set (expect 0 for blank chip, and 1 for fused chip)")
    fuse_config = dongle.read_register(366)
    if (fuse_config & 1 == expected_value) and ((fuse_config & 2) >> 1 == expected_value) and ((fuse_config & 4) >> 2 == expected_value):
        print_green("PASS: fuse update enable bit is set to %d as expected" % expected_value)
    else:
        print_red("ERROR: fuse update enable bit value is not correct, expected %d, but read the triplicated value as %d%d%d" % (expected_value, fuse_config & 1, (fuse_config >> 1) & 1, (fuse_config >> 2) & 1))
        if not DRY_RUN:
            print_red("Exiting...")
            exit(-1)

def read_gbtx_sn(dongle):
    heading("TEST2: reading GBTX serial number from the test fuses")
    test_fuse1 = dongle.read_register(367)
    test_fuse2 = dongle.read_register(368)
    sn = (test_fuse2 << 8) + test_fuse1
    if sn != 0:
        print_green("PASS: GBTX serial number is not zero: %d (test fuse1 = %s, test fuse2 = %s)" % (sn, hex8(test_fuse1), hex8(test_fuse2)))
        return sn
    else:
        print_red("FAIL: GBTX serial number is 0")
        if not DRY_RUN:
            print_red("Exiting...")
            exit(-1)

def configure(dongle, config):
    if len(config) < NUM_CONFIG_REGS:
        print_red("ERROR: configuration file has less than %d register values" % NUM_CONFIG_REGS)
        exit(-1)

    heading("Configuring GBTX...")
    dongle.write_register_block(0, config[:NUM_CONFIG_REGS])
    # for addr in range(NUM_CONFIG_REGS):
    #     dongle.write_register(addr, config[addr])

    print_green("Configuration DONE")

def read_and_compare_config(dongle, config):
    if len(config) < NUM_CONFIG_REGS:
        print_red("ERROR: configuration file has less than %d register values" % NUM_CONFIG_REGS)
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
        if not DRY_RUN:
            print_red("Exiting...")
            exit(-1)
    else:
        print_green("PASS: all readback register values match the values in the config file")

def read_errors(dongle, time_to_wait_sec):
    # 435 -- FEC correction count
    # 375 -- SEU correction count
    # 376 -- TX loss of lock count
    # 432 -- Ref PLL loss of lock count
    # 433 -- EPLL-TX loss of lock count
    # 434 -- EPLL-RX loss of lock count

    heading("TEST3: Reading GBTX error counters in a %d second time window" % time_to_wait_sec)
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
        if not DRY_RUN:
            print_red("Exiting...")
            exit(-1)
    else:
        print_green("PASS: All GBTX error counters are zero")

if __name__ == '__main__':

    heading("Welcome to the GE2/1 GBTX testing and fusing application")

    if DRY_RUN:
        subheading("NOTE: the software is running in DRY RUN mode")
        subheading("This means that it will not fuse the chip, and will also not terminate if errors / problems are found")
        subheading("To disable the DRY_RUN mode, edit this python file and change the DRY_RUN constant to False")

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
        exit(-1)

    gbt_addrs = dongle.scan()
    if len(gbt_addrs) < 1:
        print_red("ERROR: No GBTX chip detected on the I2C bus")
        print_red("Please check that the dongle is connected to the OH")
        print_red("Exiting...")
        exit(-1)

    if len(gbt_addrs) > 1:
        print_red("ERROR: more than one GBTX detected on the I2C bus... this should not be the case on GE2/1 OH..")
        print_red("Exiting...")
        exit(-1)

    board_sn = raw_input(Colors.YELLOW + "Please enter the board serial number: " + Colors.ENDC)
    test_blank_str = raw_input('Are you testing a blank chip or a fused chip? Please type in "blank" or "fused": ')
    test_blank = None
    if test_blank_str == "blank":
        test_blank = True
    elif test_blank_str == "fused":
        test_blank = False
    else:
        print_red('ERROR: unrecognized answer "%s", blank or fused are the only valid answers..' % test_blank_str)
        print_red("Exiting...")
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
        exit(-1)

    print_green("GE2/1 GBT%d chip detected (I2C address = %d)" % (gbt_id, gbt_addr))

    test_state(dongle, not test_blank)
    expect_update_fuse = 0 if test_blank else 1
    test_fuse_update_enabled(dongle, expect_update_fuse)
    sn = read_gbtx_sn(dongle)

    config_filename = CONFIG_FILES[gbt_id]
    config = read_config_file(config_filename)

    if test_blank:
        configure(dongle, config)
        time.sleep(SLEEP_AFTER_CONFIGURE)
        read_and_compare_config(dongle, config)
        test_state(dongle, True)
    else:
        read_and_compare_config(dongle, config)

    read_errors(dongle, READ_ERRORS_TIME_WINDOW_SEC)

    dongle.disconnect()
