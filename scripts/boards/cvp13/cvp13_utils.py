import sys
import os
import subprocess

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
    if bwtk_path == "":
        print_red("Invalid Bittware Toolkit Path")
        return []

    bwmonitor = bwtk_path + "/bin/bwmonitor"

    qsfp = 3 - int(channel / 4) # QSFPs are counted in the opposite direction (in our counting, the first QSFP is the one closest to the PCIe connector)
    qsfp_chan = channel % 4

    proc = subprocess.Popen([bwmonitor, '--dev=0', '--i2cread', '--devaddr=0x%da0' % (4 + qsfp), '--addr=%d' % (34 + qsfp_chan * 2), '--count=2', '--file=/tmp/bwmonitor_out'], stdout=subprocess.DEVNULL)
    proc.wait()
    # print("output: %s" % out)
    f = open("/tmp/bwmonitor_out", mode="rb")
    b = f.read(2)
    f.close()
    value = 0
    if len(b) > 0:
        value = (b[0] << 8) + b[1]
    power_uw = value / 10

    return power_uw

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
