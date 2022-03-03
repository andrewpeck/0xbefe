# ********************************************************************************************************* #
#   GBTX Project, Copyright (C) CERN                                                                        #
#                                                                                                           #
#   This source code is free for HEP experiments and other scientific research                              #
#   purposes. Commercial exploitation of the source code contained here is not                              #
#   permitted.  You can not redistribute the source code without written permission                         #
#   from the authors. Any modifications of the source code has to be communicated back                      #
#   to the authors. The use of the source code should be acknowledged in publications,                      #
#   public presentations, user manual, and other documents.                                                 #
#                                                                                                           #
#   This source code is distributed in the hope that it will be useful, but WITHOUT ANY                     #
#   WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS                               #
#   FOR A PARTICULAR PURPOSE.                                                                               #
# ********************************************************************************************************* #
# ********************************************************************************************************* #
# Python Class to handle the CERN USB-I2C interface - HID device compliant (no driver necessary on host)    #
# Reference hardware is LinkM interface based on ATMega88PA running V-USB library.                          #
# USB payload is limited according the feature report size in the firmware                                  #
# Written with Python 2.7.6 - requires pywinusb                                                             #
# ********************************************************************************************************* #
# ********************************************************************************************************* #
#   History:                                                                                                #
#   2015/09/06      D. Porret   : Created                                                                   #
#   2016.05.24      D. Porret   : Added 3 new commands (207,208,209)                                        #
# ********************************************************************************************************* #

__author__ = 'dporret'

try:
    import hid
except Exception as e:
    print(e)
    print("\033[91mERROR: hidapi is not instlled, please run the following commands:\033[39m")
    print("\033[91msudo yum install hidapi\033[39m")
    print("\033[91mpip3 install hid\033[39m")
    exit(-1)
import time

# USB Hardware ID
IDENT_VENDOR_NUM =       0x16C0
IDENT_PRODUCT_NUM =      0x05DF
IDENT_VENDOR_STRING =    "cern.ch"
IDENT_PRODUCT_STRING =   "usbi2c"

# USB Misc parameters
ID=0x1 # Required by USB protocol
START_BYTE = 0xDA # Header for LinkM USB command
REPORT_SIZE = 17 # Not used ?

# Command byte values
LINKM_CMD_NONE     = 0      # no command, do not use
#  I2C commands
LINKM_CMD_I2CTRANS = 1      # i2c read & write (N args: addr + other)
LINKM_CMD_I2CWRITE = 2      # i2c write to dev (N args: addr + other)
LINKM_CMD_I2CREAD  = 3      # i2c read         (1 args: addr)
LINKM_CMD_I2CSCAN  = 4      # i2c bus scan     (2 args: start,end)
LINKM_CMD_I2CCONN  = 5      # i2c connect/disc (1 args: 1/0)
LINKM_CMD_I2CINIT  = 6      # i2c init         (0 args: )
#
#  linkm board commands
LINKM_CMD_VERSIONGET = 100  # return linkm version
LINKM_CMD_STATLEDSET = 101  # status LED set   (1 args: 1/0)
LINKM_CMD_STATLEDGET = 102  # status LED get   (0 args)
LINKM_CMD_PLAYSET    = 103  # set params of player state machine
LINKM_CMD_PLAYGET    = 104  # get params of  player state machine
LINKM_CMD_EESAVE     = 105  # save linkm state to EEPROM
LINKM_CMD_EELOAD     = 106  # load linkm state from EEPROM
LINKM_CMD_GOBOOTLOAD = 107  # trigger USB bootload
#
# custom CERN dongle commands
GBT_CMD_VTARGETSET	= 200  # switch the target LDO on/off (1 args: 1/0)
GBT_CMD_VTARGETGET	= 201  # status V target LDO get   (0 args)
GBT_CMD_BURNFUSE	= 202  # apply Efuse voltage and pulse (0 args)
GBT_CMD_IO1SET		= 203  # switch the IO1 output on/off (1 args: 1/0)
GBT_CMD_IO1GET		= 204  # IO1 output status get (0 args)
GBT_CMD_IO2SET		= 205  # switch the IO2 output on/off (1 args: 1/0)
GBT_CMD_IO2GET		= 206  # IO2 output status get (0 args)
GBT_CMD_VFUSESET	= 207  # switch the 3.3V efuse LDO on/off (1 args: 1/0)
GBT_CMD_VFUSEGET	= 208  # get the 3.3V efuse LDO status (0 args)
GBT_CMD_FUSEPULSE	= 209  # trigger a 1 ms pulse width (0 args)
#
# Return codes
LINKM_ERR_NONE      =   0   #No error
LINKM_ERR_BADSTART  = 101
LINKM_ERR_BADARGS   = 102   # command could not be decoded properly
LINKM_ERR_I2C       = 103
LINKM_ERR_I2CREAD   = 104
LINKM_ERR_NOTOPEN   = 199
LINKM_ERR_USBOVERFLOW = 200  # dongle usb return buffer overflow

class InterfaceError(Exception):
    """Error class to manage returned codes from the interface"""
    def __init__(self,error_code):
        self.error_code=error_code
        self.error_string=''
        if (self.error_code==0):
            self.error_string='ERROR_NONE'
        elif (self.error_code==101):
            self.error_string='ERR_BADSTART'
        elif (self.error_code==102):
            self.error_string='ERR_BADARGS'
        elif (self.error_code==103):
            self.error_string='ERR_I2C'
        elif (self.error_code==104):
            self.error_string='ERR_I2CREAD'
        elif (self.error_code==199):
            self.error_string='ERR_NOTOPEN'
        elif (self.error_code==200):
            self.error_string='ERR_USBOVERFLOW'
        else :
            self.error_string='ERR_UNKNOWN'

    def __str__(self):
        return ('USB dongle error: '+self.error_string+'('+str(self.error_code)+')')

class USB_dongle():
    """ HID interface """
    def __init__(self):
        """

        :rtype : object
        """
        found = False
        for d in hid.enumerate():
            if ("vendor_id" in d) and (d["vendor_id"] == IDENT_VENDOR_NUM) and ("product_id" in d) and (d["product_id"] == IDENT_PRODUCT_NUM):
                print("USB-I2C dongle found on port %s" % d["path"])
                found = True
                self.device = hid.device()
                self.device.open(IDENT_VENDOR_NUM, IDENT_PRODUCT_NUM)
                # self.device.set_nonblocking(0)
                break
        if not found:
            raise IOError("No interface attached to USB")
        else:
            print ("USB-I2C Dongle Found")

    def __del__(self):
        """close connection when the object is destroyed"""
        if self.device:
            self.device.close()

    def close(self):
        """close connection by calling this method"""
        self.device.close() #close the connection and it supposed to kill the thread
        del self # delete the object - otherwise the main process will still run in windows after the main application is closed

    def __usb_command(self,cmd=0,num_send=0,num_recv=0,payload=[]):
        """ cmd : command byte
            num_send : number of payload bytes
            num_recv : number of byte to return
            payload : list of data bytes
            Return list with Error code and data bytes"""

        # byte 0 : Fix report id, required by usb functions
        # byte 1 : Fix start byte
        # byte 2 : Parameter command
        # byte 3 : Parameter num bytes to send (starting at byte 5)
        # byte 4 : Parameter num bytes to receive

        #header=[cmd,num_send,num_recv]
        header=[ID,START_BYTE,cmd,num_send,num_recv]
        buf=header+payload # merge header and payload

        for _ in range(132-len(buf)): # report needs to be 132 bytes - so we fill with 0x00
            buf.append(0x00)

        # transmit data to USB
        # self.device.write(buf)
        raw_data = self.device.send_feature_report(buf)
        # print("USB: send feature report returned %d bytes" % len(raw_data))

        time.sleep(0.04)

        # readback from USB
        # byte 0 : Transaction counter  (8-bit, wraps around)
        # byte 1 : Error code (0 = okay, other = error)
        # byte 2+++ : Command dependent

        # print("USB: requesting %d bytes" % (num_recv + 2))
        raw_data = self.device.get_feature_report(1,num_recv+2)
        # print("USB: received %d bytes" % len(raw_data))
        return raw_data[1:num_recv+2]


    # user functions
    # ---------------
    def setvtargetldo(self,value):
        """ drive target LDO (0/1)"""
        self.__usb_command(GBT_CMD_VTARGETSET,1,0,[int(value)])

    def setod1(self,value):
        """ drive open drain 1 output (0/1)"""
        self.__usb_command(GBT_CMD_IO1SET,1,0,[int(value)])

    def setod2(self,value):
        """ drive open drain 2 output (0/1)"""
        self.__usb_command(GBT_CMD_IO2SET,1,0,[int(value)])

    def burnefuse(self):
        """ apply 3.3V on target and pulse to burn E-Fuse"""
        self.__usb_command(GBT_CMD_BURNFUSE)

    def get_firmware_version(self):
        """Return dongle firmware version as string - major version.minor version"""
        answer=self.__usb_command(LINKM_CMD_VERSIONGET,1,3)
        return "Firmware version=" + str(answer[1])+"."+str(answer[2])

    def go_bootload(self):
        """put the dongle in bootloader mode"""
        self.__usb_command(LINKM_CMD_GOBOOTLOAD)

    def setvfuseldo(self,value):
        """ drive Efuse 3.3V LDO (0/1)"""
        self.__usb_command(GBT_CMD_VFUSESET,1,0,[int(value)])

    def fusepulse(self):
        """ trigger a 1.5V pulse"""
        self.__usb_command(GBT_CMD_FUSEPULSE)

    # user functions - I2C
    # -----------------------
    def i2c_reset(self):
        """Reset I2C bus - Stop and Init"""
        self.__usb_command(LINKM_CMD_I2CINIT)

    def i2c_connect(self,value):
        """enable or disable I2C voltage translator (0/1)"""
        self.__usb_command(LINKM_CMD_I2CCONN,1,0,[int(value)])

    def i2c_scan(self,start_addr=1,end_addr=40):
        """scan I2C bus for devices in a given address range (up to 14 slaves) - return list of slaves address"""
        ret= self.__usb_command(LINKM_CMD_I2CSCAN,2,14,[start_addr,end_addr])
        # ret[0] - status
        # ret[1] - number of slaves
        # ret[2..] - slaves addresses
        print ("found %d I2C slave(s)" %(ret[1]))
        devices= (ret[2+i] for i in range(ret[1]))
        return list (devices)

    def i2c_write(self,addr=1,data=[]):
        """write data to I2C slave at adress - data as bytes list"""
        payload=[addr]+data
        return self.__usb_command(LINKM_CMD_I2CWRITE,len(payload),0,payload)

    def i2c_read(self,addr=1,bytestoread=1):
        """read N bytes from I2C slave at adress - return error code + data as list"""
        return self.__usb_command(LINKM_CMD_I2CREAD,1,bytestoread,[addr])

    def i2c_writeread(self,addr=1,bytestoread=1,data=[]):
        """write data to slave and then read N bytes - return error code + data as list"""
        payload=[addr]+data
        return self.__usb_command(LINKM_CMD_I2CTRANS,len(payload),bytestoread,payload)


# class test
#------------

if __name__ == '__main__':
    my_interface=USB_dongle()

    print (my_interface.get_firmware_version())
    #my_interface.go_bootload()


    # Test functions
    # --------------
    # my_interface.burnefuse()
    # my_interface.setvtargetldo(1)
    # my_interface.i2c_connect(1)
    # print my_interface.i2c_scan()
    # print my_interface.i2c_write(38,[0x20])
    # my_interface.burnefuse()
    # print my_interface.i2c_write(38,[0x40])
    #my_interface.burnefuse()

    #my_interface.setvfuseldo(1)
    #time.sleep(5)
    #my_interface.setvfuseldo(0)
    # print my_interface.i2c_read(38, 1)
    # my_interface.i2c_write(38,[0x40])
    # my_interface.setod1(1)
    # my_interface.setod2(0)
    # print my_interface.i2c_read(38, 1)
    # print my_interface.i2c_writeread(38,1,[22])

    #my_interface.close()
