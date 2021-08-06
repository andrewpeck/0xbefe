import sys
import os

def detect_cvp13_cards():
    devices_dir = "/sys/bus/pci/devices"
    dirs = os.listdir(devices_dir)
    cvp13s = []
    for dir in dirs:
        f = open(devices_dir + "/" + dir + "/device", "r")
        dev = f.read().replace("\n", "")
        f.close()
        if dev == "0xbefe":
            cvp13s.append(devices_dir + "/" + dir)

    return cvp13s


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
