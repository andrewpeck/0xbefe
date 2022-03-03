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
# Demo Python class to read and write GBTx ASIC with the USB-I2C dongle                                     #
# Written with Python 3 - requires pywinusb                                                             #
# ********************************************************************************************************* #
# ********************************************************************************************************* #
#   History:                                                                                                #
#   2015/09/06      D. Porret   : Created.     
#   2018.08.29      E. Mendes   : 3 new functions: Dump Configuration + reset + read Idle state 		    #
# ********************************************************************************************************* #

__author__ = 'dporret'

from . import usb_dongle as dongle
import time
import xml.etree.ElementTree as ET

class GBTx():
    """Class for GBTx functions"""
    def __init__(self):
        self.gbtx_address=1
        # dongle init
        self.my_interface=dongle.USB_dongle()
        self.my_interface.setvtargetldo(1)
        self.my_interface.i2c_connect(1)
        #print self.my_interface.i2c_scan(1,50)

    def gbtx_write_register(self,register,value):
        """write a value to a register"""
        reg_add_l=register&0xFF
        reg_add_h=(register>>8)&0xFF
        payload=[reg_add_l]+[reg_add_h]+[value]
        #print payload
        self.my_interface.i2c_write(self.gbtx_address,payload)

    def gbtx_read_register(self,register):
        """read a value from a register - return register byte value"""
        reg_add_l=register&0xFF
        reg_add_h=(register>>8)&0xFF
        payload=[reg_add_l]+[reg_add_h]
        answer= self.my_interface.i2c_writeread(self.gbtx_address,1,payload)
        return answer[1]

    def gbtx_read_block_registers(self,register_idx=45):
        """return error code + 15 consecutive registers from index value as list"""
        reg_add_l=register_idx&0xFF
        reg_add_h=(register_idx>>8)&0xFF
        payload=[reg_add_l]+[reg_add_h]
        #print "registers : %d -> %d" %(register_idx,register_idx+13)
        return self.my_interface.i2c_writeread(self.gbtx_address,15,payload)[1:]

    def gbtx_dump_config(self,config_file = 'Loopback_test.xml'): # 'GBTx_config_hptd_test.txt'
        """dump configuration to GBTx - accepts .txt of .xml input"""
        # Read configuration file
        if(config_file[-4:] == '.xml'):
            tree = ET.parse(config_file)
            root = tree.getroot()
            reg_config = []
            for i in range(0,366):
                reg_config.append([0,0]) # Value / Mask

            for child in root:
                name_signal = child.attrib['name']
                triplicated = child.attrib['triplicated']
                reg_value   = int(child[0].text)
                if(triplicated in ['true', 'True', 'TRUE']) : n=3
                else                                        : n=1
                for i in range(1,n+1):
                    #print(name_signal)
                    #print(triplicated)
                    #print(reg_value)
                    reg_addr = int(child[i].attrib['startAddress'])
                    startbit = int(child[i].attrib['startBitIndex'])
                    endbit   = int(child[i].attrib['lastBitIndex'])
                    mask     = 2**(startbit+1) - 2**(endbit)
                    reg_config[reg_addr][0] = reg_config[reg_addr][0] | (reg_value << startbit)
                    reg_config[reg_addr][1] = reg_config[reg_addr][1] | mask

            for reg_addr in range(0,len(reg_config)):
                value = reg_config[reg_addr][0]
                mask  = reg_config[reg_addr][1]
                if(mask != 0):
                    value = self.gbtx_read_register(reg_addr)
                    value = (value & (~mask)) | value
                    self.gbtx_write_register(reg_addr, value)
        else:
            with open(config_file, 'r') as f:
                config = f.read()
                config = config.split('\n')
                for reg_addr in range(0,len(config)-1):
                    value = int(config[reg_addr],16)
                    self.gbtx_write_register(reg_addr, value)
        print('GBTx Configuration Done')

    def gbtx_reset(self,register_idx=45):
        """reset the 1.5V DC-DC to GBTx"""
        self.my_interface.setod1(1)
        time.sleep(0.5)
        self.my_interface.setod1(0)
        time.sleep(0.5)

    def vtrx_reset(self,register_idx=45):
        """reset the 2.5V DC-DC to VTRx"""
        self.my_interface.setod2(1)
        time.sleep(0.5)
        self.my_interface.setod2(0)
        time.sleep(0.5)

    def get_gbtx_idle(self):
        """read a value from a register - return register byte value"""
        idle_bool = ((self.gbtx_read_register(431) >> 2) & 0x1F) == 0b11000 
        return int(idle_bool)

if __name__ == '__main__':

    gbt=GBTx()
    gbt.gbtx_address=1
    #print(gbt.my_interface.get_firmware_version())

    gbt.vtrx_reset()
    time.sleep(1)

    gbt.gbtx_reset()
    time.sleep(1)

    #gbt.gbtx_dump_config('Loopback_test.xml')
    gbt.gbtx_dump_config('GBTx_config_hptd_test.txt')

    #for i in range (0, 421,15):
    #    print (gbt.gbtx_read_block_registers(i))

    # BEGIN GBLD write example
    # gbt.gbtx_write_register(253,0x7e) # GBLD default Id = 0x7E
    # print gbt.gbtx_read_register(253)

    #gbt.gbtx_write_register(319,0x01)  # register value


    #gbt.gbtx_read_block_registers(318)
    #gbt.gbtx_write_register(56,0x02)  # register value
    #gbt.gbtx_write_register(57,0x03)  # register value
    #gbt.gbtx_write_register(58,0x04)  # register value
    #gbt.gbtx_write_register(59,0x05)  # register value
    #gbt.gbtx_write_register(60,0x06)  # register value
    #gbt.gbtx_write_register(61,0x07)  # register value
    #gbt.gbtx_write_register(388,0x00)  # dummy write to trigger GBLD write
    # END GBLD write example

    #print my_interface.gbtx_read_register(253)

    #gbt.gbtx_read_all_registers()

    #gbt.gbtx_read_block_registers()

    # BEGIN GBLD  read example
    #gbt.gbtx_write_register(253,0x7e) #GBLD default Id = 0x7E
    #gbt.gbtx_write_register(389,0x1) # dummy write to trigger GBLD read
    #gbld_val= my_interface.gbtx_read_register(385)  # read GBLD pre-driver register
    #print hex(gbld_val[1])
    # END GBLD read example
    # END DCDC example

    # BEGIN SCA test


    # END SCA test
