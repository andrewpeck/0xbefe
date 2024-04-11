import sys
import os
import subprocess

# there are two Si5341 synthesizers with I2C addresses 0xe8 (synth A) and 0xea (synth B)
CVP13_SYNTH_I2C_ADDR = [0xe8, 0xea]

def detect_cvp13_cards():
    devices_dir = "/sys/bus/pci/devices"
    dirs = os.listdir(devices_dir)
    cvp13s = []
    for dir in dirs:
        device_file = devices_dir + "/" + dir + "/device"
        if not os.path.isfile(device_file):
            continue
        f = open(device_file, "r")
        dev = f.read().replace("\n", "")
        f.close()
        if dev == "0xbefe":
            cvp13s.append(devices_dir + "/" + dir)

    return cvp13s

def cvp13_get_bwtk_path():
    path = "/opt/bwtk"
    # check if /opt/bwtk exists
    if not os.path.isdir(path):
        return None

    versions = os.listdir(path)

    if len(versions) == 0:
        return None

    path += "/" + versions[0]

    # override I2C control

    bwmonitor = path + "/bin/bwmonitor"
    proc = subprocess.Popen([bwmonitor, '--dev=0', '--type=BMC', '--write', '--i2c_own=0xff'], stdout=subprocess.DEVNULL)
    proc.wait()

    return path

# Reads the RX optical power of all channels, prints it, and returns an array of the measurements (units are micro watts)
def cvp13_read_qsfp_rx_power_all(bwtk_path, do_print=True):
    ret = []
    if do_print:
        print("------------------")
    for qsfp in range(4):
        for ch in range(4):
            global_channel = (qsfp * 4) + ch
            power_uw = cvp13_read_qsfp_rx_power(bwtk_path, global_channel)
            ret.append(power_uw)
            if do_print:
                print("QSFP%d ch%d: %duW" % (qsfp, ch, power_uw))
        if do_print:
            print("------------------")

    return ret

# Reads the RX optical power of the given channel (channels are counted starting from the QSFP closest to the PCIe connetor).
# Returned power value is in units of micro watts
def cvp13_read_qsfp_rx_power(bwtk_path, channel):
    qsfp = 3 - int(channel / 4) # QSFPs are counted in the opposite direction (in our counting, the first QSFP is the one closest to the PCIe connector)
    qsfp_chan = channel % 4
    
    i2c_addr = (4 + qsfp) * 0x100 + 0xa0 # e.g. 4a0 for QSFP0, 5a0 for QSFP1, etc..
    reg_addr = 34 + qsfp_chan * 2
    b = cvp13_i2c_read(bwtk_path, i2c_addr, reg_addr, count=2)
    if b is None:
        return []

    value = 0
    if len(b) > 0:
        value = (b[0] << 8) + b[1]
    power_uw = value / 10

    return power_uw

def cvp13_read_synth_status(bwtk_path, do_print=True):

    ret = []

    for synth in range(2):
        cvp13_i2c_write(bwtk_path, CVP13_SYNTH_I2C_ADDR[synth], 1, 0) # select page 0
        regs_c_d = cvp13_i2c_read(bwtk_path, CVP13_SYNTH_I2C_ADDR[synth], 0xc, count=2) # regs 0xC and 0xD that indicate the lock status
        if regs_c_d is None or len(regs_c_d) < 2:
            print("ERROR: cannot read the status registers from synth A")
            return None

        # reg_1e = cvp13_i2c_read(bwtk_path, CVP13_SYNTH_I2C_ADDR[synth], 0x1e, count=1) # reg 0x1E
        # if reg_1e is None or len(reg_1e) < 1:
        #     print("ERROR: cannot read the power down register from synth A")
        #     return None

        status = {}
        status["calibrating"] = regs_c_d[0] & 0x1
        status["los_xa"] = (regs_c_d[0] & 0x2) >> 1 # no signal on XA
        status["los_ref"] = (regs_c_d[0] & 0x4) >> 2 # no signal on XAXB, IN2, IN1, IN0
        status["lol"] = (regs_c_d[0] & 0x8) >> 3 # loss of lock
        status["los_in0"] = (regs_c_d[1] & 0x1) # no clock on IN0
        status["los_in1"] = (regs_c_d[1] & 0x2) >> 1 # no clock on IN1
        status["los_in2"] = (regs_c_d[1] & 0x4) >> 2 # no clock on IN2
        status["los_fb_in"] = (regs_c_d[1] & 0x8) >> 3 # no clock on FB_IN
        # status["power_down"] = (reg_1e[0] & 0x1) # power down

        ret.append(status)

        if do_print:
            synth_a_b = "A" if synth == 0 else "B"
            print("")
            print("======== Synth %s ========" % synth_a_b)
            for key in status:
                print("    %s: %d" % (key, status[key]))

    return ret

# Powers a given synthesizer up or down by writing to the PDN register (Rice at UCLA was found with synth B powered down)
# synth: 0 for synth A, 1 for synth B
# power_up: True for power up, false for power_down
def cvp13_synth_power_control(bwtk_path, synth, power_up):
    cvp13_i2c_write(bwtk_path, CVP13_SYNTH_I2C_ADDR[synth], 1, 0) # select page 0
    reg_val = 0 if power_up else 1
    cvp13_i2c_write(bwtk_path, CVP13_SYNTH_I2C_ADDR[synth], 0x1e, reg_val) # power down/up

def cvp13_i2c_write(bwtk_path, i2c_addr, reg_addr, reg_val):
    if bwtk_path == "":
        print("ERROR: Invalid Bittware Toolkit Path")
        return None

    bwmonitor = bwtk_path + "/bin/bwmonitor"

    proc = subprocess.Popen([bwmonitor, '--dev=0', '--i2cwrite', '--devaddr=%d' % i2c_addr, '--addr=%d' % reg_addr, '--hexval=%X' % reg_val], stdout=subprocess.DEVNULL)
    proc.wait()

    return 0

def cvp13_i2c_read(bwtk_path, i2c_addr, reg_addr, count=1):
    if bwtk_path == "":
        print("ERROR: Invalid Bittware Toolkit Path")
        return None

    bwmonitor = bwtk_path + "/bin/bwmonitor"

    proc = subprocess.Popen([bwmonitor, '--dev=0', '--i2cread', '--devaddr=%d' % i2c_addr, '--addr=%d' % reg_addr, '--count=%d' % count, '--file=/tmp/bwmonitor_out'], stdout=subprocess.DEVNULL)
    proc.wait()

    f = open("/tmp/bwmonitor_out", mode="rb")
    b = f.read(count)
    f.close()

    return b


if __name__ == '__main__':
    if len(sys.argv) > 1:
        if sys.argv[1] == "detect":
            cvp13s = detect_cvp13_cards()
            if len(cvp13s) == 0:
                print("No CVP13 card running 0xBEFE firmware is detected on your system")
                exit()
            print("These CVP13 cards have been detected")
            i = 0
            for cvp13 in cvp13s:
                print("%d: %s" % (i, cvp13))
                i += 1
        elif sys.argv[1] == "optics":
            bwtk_path = cvp13_get_bwtk_path()
            cvp13_read_qsfp_rx_power_all(bwtk_path, do_print=True)
        elif sys.argv[1] == "clocks":
            bwtk_path = cvp13_get_bwtk_path()
            cvp13_read_synth_status(bwtk_path, do_print=True)
        elif sys.argv[1] == "synth_power_control":
            if len(sys.argv) < 4:
                print("Not enough arguments")
                print("Usage: cvp13_utils.py synth_power_control <synth> <power_up_down>")
                print("    synth: 0 for synth A, 1 for synth B")
                print("    power_up_down: 0 for power down, 1 for power up")
                sys.exit()
            bwtk_path = cvp13_get_bwtk_path()
            synth = int(sys.argv[2])
            if synth < 0 or synth > 1:
                print("Invalid synth number, should be 0 or 1")
                sys.exit()
            power_up_down = int(sys.argv[3])
            if power_up_down < 0 or power_up_down > 1:
                print("Invalid power_up_down argument, should be 0 for power down or 1 for power up")
                sys.exit()
            cvp13_synth_power_control(bwtk_path, synth, power_up_down)
        else:
            print("Unrecognized command")
    else:
        print("Usage: cvp13_utils.py <command> [command_dependent_arguments]")
        print("Available commands:")
        print("    detect: detect installed CVP13 cards")
        print("    optics: reads optics status and prints it out (for now just RX optical power)")
        print("    clocks: reads status from the clock synthesizers and prints it out")
        print("    synth_power_control <synth> <power_up_down>: power down/up the given synthesizer. synth=0 means synth A, synth=1 means synth B, power_up_down=0 means power down, power_up_down=1 means power up")
        