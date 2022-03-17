import subprocess
from time import *
from common.rw_reg import *
import random

class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

BEFE_ROOT = "../.."
OH_NUM = 0
OH_MASK = 1
GBT0_CONFIG_FILE = "/home/cscdev/gbt_config/GBTX_GE21_OHv2_GBT_0_minimal_2020-01-17.txt"
TEST_REG_ITERATIONS = 1000

def main():

    parse_xml()

    myprint("Init")
    write_reg(get_node('BEFE.GEM.TTC.GENERATOR.ENABLE'), 1)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.TTC_HARD_RESET_EN'), 1)

    myprint("Configuring GBT0")
    subprocess.call(["python", BEFE_ROOT + "/scripts/gem/gbt.py", "0", "0", "config", GBT0_CONFIG_FILE])

    myprint("Resetting SCA")
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.MODULE_RESET'), 1)

    myprint("Sending a hard reset")
    write_reg(get_node('BEFE.GEM.TTC.GENERATOR.SINGLE_HARD_RESET'), 1)

    sleep(0.3)

    myprint("Reading the OH FPGA DONE output")
    fpgaDone = readDone()
    if fpgaDone == 0:
        myprint("ERROR: OH FPGA DONE output is low!", True)
        return
    else:
        myprint("OH FPGA DONE is high")

    myprint("Testing communication with the OH FPGA (%d write-read random data check)" % TEST_REG_ITERATIONS)
    prevVal = 0
    val = 0
    for i in xrange(TEST_REG_ITERATIONS):
        prevVal = val
        val = random.randint(0, 0xffffffff)
        write_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.LOOPBACK.DATA'), val)
        loopVal = read_reg(get_node('BEFE.GEM.OH.OH0.FPGA.CONTROL.LOOPBACK.DATA'))
        if loopVal != val:
            myprint("ERROR while reading back OH register (iteration %d), expected to read %s, but received %s (value written during previous iteration is %s)" % (i, val, loopVal, prevVal))
            return

    myprint("Communication with the OH FPGA is GOOD!")

    myprint("DONE")

    # write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.LINK_ENABLE_MASK'), ohMask)

def readDone():
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.LINK_ENABLE_MASK'), OH_MASK)
    gpioDir = 0xff0fe0
    sendScaCommand([OH_NUM], 0x2, 0x20, 0x4, gpioDir, False)
    sleep(0.1)
    readData = sendScaCommand([OH_NUM], 0x2, 0x1, 0x1, 0x0, True)
    fpgaDone = (readData[0] >> 30) & 1
    return fpgaDone

def sendScaCommand(ohList, sca_channel, sca_command, data_length, data, doRead):
    #print('fake send: channel ' + hex(sca_channel) + ', command ' + hex(sca_command) + ', length ' + hex(data_length) + ', data ' + hex(data) + ', doRead ' + str(doRead))
    #return

    d = data

    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_CHANNEL'), sca_channel)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_COMMAND'), sca_command)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_LENGTH'), data_length)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_DATA'), d)
    write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_EXECUTE'), 0x1)
    reply = []
    if doRead:
        for i in ohList:
            reply.append(read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_REPLY_OH%d.SCA_RPY_DATA' % i)))
    return reply

def hex(number):
    if number is None:
        return 'None'
    else:
        return "{0:#0x}".format(number)

def myprint(msg, isError = False):
    col = Colors.RED if isError else Colors.GREEN
    print(col + "===> " + msg + Colors.ENDC)

if __name__ == '__main__':
    main()
