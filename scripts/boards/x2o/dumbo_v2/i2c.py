from smbus import SMBus
import time
import csv
import pkgutil
from math import log10

class bus(object):
    def __init__(self,busid,delay=0.01,max_retries=10,verbose=True):
        self.bus = SMBus(busid)
        self.busid = busid
        self.delay=delay
        self.max_retries = max_retries
        self.verbose = verbose

    def write_byte(self, addr,data):
        success=False
        attempt_cnt = 0
        while not success and attempt_cnt < self.max_retries:
            attempt_cnt += 1
            #select page
            try:
                self.bus.write_byte(addr,data)
            except:
                time.sleep(self.delay)
                success=False
            else:
                success=True

        if not success and self.verbose:
            print("I2C write_byte() failed, bus = %d, addr = %d, data = %d" % (self.busid, addr, data))

        return success

    def read_byte(self, addr):
        success=False
        result=-1
        attempt_cnt = 0
        while not success and attempt_cnt < self.max_retries:
            attempt_cnt += 1
            #select page
            try:
                result=self.bus.read_byte(addr)
            except:
                time.sleep(self.delay)
                success=False
            else:
                success=True

        if not success and self.verbose:
            print("I2C read_byte() failed, bus = %d, addr = %d" % (self.busid, addr))

        return result


    def write_byte_data(self, addr,command,data):
        success=False
        attempt_cnt = 0
        while not success and attempt_cnt < self.max_retries:
            attempt_cnt += 1
            #select page
            try:
                self.bus.write_byte_data(addr,command,data)
            except:
                time.sleep(self.delay)
                success=False
            else:
                success=True

        if not success and self.verbose:
            print("I2C write_byte_data() failed, bus = %d, addr = %d, cmd = %d, data = %d" % (self.busid, addr, command, data))

        return success

    def read_byte_data(self, addr,command):
        success=False
        result=-1
        attempt_cnt = 0
        while not success and attempt_cnt < self.max_retries:
            attempt_cnt += 1
            #select page
            try:
                result= self.bus.read_byte_data(addr,command)
            except:
                time.sleep(self.delay)
                success=False
            else:
                success=True

        if not success and self.verbose:
            print("I2C read_byte_data() failed, bus = %d, addr = %d, cmd = %d" % (self.busid, addr, command))

        return result

    def write_block_data(self, addr, command, data):
        success=False
        attempt_cnt = 0
        while not success and attempt_cnt < self.max_retries:
            attempt_cnt += 1
            try:
                self.bus.write_i2c_block_data(addr,command,data)
            except:
                time.sleep(self.delay)
                success=False
            else:
                success=True

        if not success and self.verbose:
            print("I2C write_block_data() failed, bus = %d, addr = %d, cmd = %d" % (self.busid, addr, command))

        return success

    def read_block_data(self, addr,command,num_bytes):
        success=False
        result=[]
        attempt_cnt = 0
        while not success and attempt_cnt < self.max_retries:
            attempt_cnt += 1
            #select page
            try:
                result= self.bus.read_i2c_block_data(addr,command,num_bytes)
            except:
                time.sleep(self.delay)
                success=False
            else:
                success=True

        if not success and self.verbose:
            print("I2C read_byte_data() failed, bus = %d, addr = %d, cmd = %d" % (self.busid, addr, command))

        return result


    #wrap every command to create a time delay
    def __getattr__(self, name):
        success=False
        attempt_cnt = 0
        while not success and attempt_cnt < self.max_retries:
            attempt_cnt += 1
            #select page
            try:
                result = getattr(self.bus,name)

            except:
                time.sleep(self.delay)
                success=False
            else:
                success=True

        return result


#Our custom Lattice firmware for Octopus
#can be used as both a slave but also as a bus
#therefore providing a bus class for it
class octopus_bus(object):
    def __init__(self,bus,address,channel,delay=0.01):
        self.bus = bus
        self.delay=delay
        self.address = address
        self.channel=channel

    def write_byte_data(self, addr,command,data,register_16b=0):
        #bring i2c in reset
        self.bus.write_byte_data(self.address,1,0)
        #write address
        self.bus.write_byte_data(self.address,2,addr<<1)
        #write register
        self.bus.write_byte_data(self.address,3,command &0xff)
        self.bus.write_byte_data(self.address,4,(command >>8) &0xff)
        #write data
        self.bus.write_byte_data(self.address,5,data &0xff)
        self.bus.write_byte_data(self.address,6,(data>>8) &0xff)

        d=0
        if register_16b:
            d = 0x5
        else:
            d = 0x7
        d = d | (self.channel << 4)

        #run the command
        self.bus.write_byte_data(self.address,1,d)

        while True:
            res = self.bus.read_byte_data(self.address,0)
            if res != 0:
                break
        if res == 0x02:
            raise Exception('I2C acknowledge failed')

    def write_word_data(self, addr,command,data,register_16b=0):
        #bring i2c in reset
        self.bus.write_byte_data(self.address,1,0)
        #write address
        self.bus.write_byte_data(self.address,2,addr<<1)
        #write register
        self.bus.write_byte_data(self.address,3,command &0xff)
        self.bus.write_byte_data(self.address,4,(command >>8) &0xff)
        #write data
        self.bus.write_byte_data(self.address,5,data &0xff)
        self.bus.write_byte_data(self.address,6,(data>>8) &0xff)

        d=0
        if register_16b:
            d = 1
        else:
            d = 0x3
        d = d | (self.channel << 4)

        #run the command
        self.bus.write_byte_data(self.address,1,d)

        while True:
            res = self.bus.read_byte_data(self.address,0)
            if res != 0:
                break
        if res == 0x02:
            raise Exception('I2C acknowledge failed')

    def read_byte_data(self, addr,command,register_16b=0):
        #bring i2c in reset
        self.bus.write_byte_data(self.address,1,0)
        #write address
        self.bus.write_byte_data(self.address,2,addr<<1)
        #write register
        self.bus.write_byte_data(self.address,3,command &0xff)
        self.bus.write_byte_data(self.address,4,(command >>8) &0xff)
        d = 0
        if register_16b:
            d = 0xd
        else:
            d = 0xf

        # Mux channel
        d = d | (self.channel << 4)
        self.bus.write_byte_data(self.address,1,d)

        while True:
            res = self.bus.read_byte_data(self.address,0)
            if res != 0:
                break
        if res == 0x02:
            raise Exception('I2C acknowledge failed addr={addr}')
        return self.bus.read_byte_data(self.address,1)

    def read_word_data(self, addr,command,register_16b=0):
        #bring i2c in reset
        self.bus.write_byte_data(self.address,1,0)
        #write address
        self.bus.write_byte_data(self.address,2,addr<<1)
        #write register
        self.bus.write_byte_data(self.address,3,command &0xff)
        self.bus.write_byte_data(self.address,4,(command >>8) &0xff)
        d = 0
        if register_16b:
            d = 0x9
        else:
            d = 0xb
        # Mux channel
        d = d | (self.channel << 4)
        self.bus.write_byte_data(self.address,1,d)

        while True:
            res = self.bus.read_byte_data(self.address,0)
            if res != 0:
                break
        if res == 0x02:
            raise Exception('I2C acknowledge failed')
        return ((self.bus.read_byte_data(self.address,2)<<8) | self.bus.read_byte_data(self.address,1))


    def read_byte(self, addr):
        return self.read_byte_data(addr,0x0)
    def write_byte(self, addr,data):
        return self.write_byte_data(addr,0x0,data)


class optical_bus(object):
    def __init__(self,bus,address,channel,delay=0.01):
        self.bus = bus
        self.delay=delay
        self.address = address
        self.channel=channel




    def write_byte_data(self, addr,command,data,register_16b=0):
        #bring i2c in reset
        self.bus.write_byte_data(self.address,0,0)
        #write address
        self.bus.write_byte_data(self.address,1,addr<<1)
        #write register
        self.bus.write_byte_data(self.address,2,command &0xff)
        self.bus.write_byte_data(self.address,3,(command >>8) &0xff)
        #write data
        self.bus.write_byte_data(self.address,4,data &0xff)
        self.bus.write_byte_data(self.address,5,(data>>8) &0xff)
        self.bus.write_byte_data(self.address,6,self.channel)

        d=0
        if register_16b:
            d = 0x5
        else:
            d = 0x7
        #run the command
        self.bus.write_byte_data(self.address,0,d)

        while True:
            res = self.bus.read_byte_data(self.address,0)
            if res != 0:
                break
        if res == 0x02:
            raise Exception('I2C acknowledge failed')

    def write_word_data(self, addr,command,data,register_16b=0):
        #bring i2c in reset
        self.bus.write_byte_data(self.address,0,0)
        #write address
        self.bus.write_byte_data(self.address,1,addr<<1)
        #write register
        self.bus.write_byte_data(self.address,2,command &0xff)
        self.bus.write_byte_data(self.address,3,(command >>8) &0xff)
        #write data
        self.bus.write_byte_data(self.address,4,data &0xff)
        self.bus.write_byte_data(self.address,5,(data>>8) &0xff)
        self.bus.write_byte_data(self.address,6,self.channel)

        d=0
        if register_16b:
            d = 1
        else:
            d = 0x3


        #run the command
        self.bus.write_byte_data(self.address,0,d)

        while True:
            res = self.bus.read_byte_data(self.address,0)
            if res != 0:
                break
        if res == 0x02:
            raise Exception('I2C acknowledge failed')



    def read_byte_data(self, addr,command,register_16b=0):
        #bring i2c in reset
        self.bus.write_byte_data(self.address,0,0)
        #write address
        self.bus.write_byte_data(self.address,1,addr<<1)
        #write register
        self.bus.write_byte_data(self.address,2,command &0xff)
        self.bus.write_byte_data(self.address,3,(command >>8) &0xff)
        self.bus.write_byte_data(self.address,6,self.channel)
        d = 0
        if register_16b:
            d = 0xd
        else:
            d = 0xf

        # Mux channel
        self.bus.write_byte_data(self.address,0,d)

        while True:
            res = self.bus.read_byte_data(self.address,0)
            if res != 0:
                break
        if res == 0x02:
            raise Exception('I2C acknowledge failed addr={addr}')
        return self.bus.read_byte_data(self.address,1)

    def read_word_data(self, addr,command,register_16b=0):
        #bring i2c in reset
        self.bus.write_byte_data(self.address,0,0)
        #write address
        self.bus.write_byte_data(self.address,1,addr<<1)
        #write register
        self.bus.write_byte_data(self.address,2,command &0xff)
        self.bus.write_byte_data(self.address,3,(command >>8) &0xff)
        self.bus.write_byte_data(self.address,6,self.channel)

        d = 0
        if register_16b:
            d = 0x9
        else:
            d = 0xb
        # Mux channel
        self.bus.write_byte_data(self.address,0,d)

        while True:
            res = self.bus.read_byte_data(self.address,0)
            if res != 0:
                break
        if res == 0x02:
            raise Exception('I2C acknowledge failed')
        return ((self.bus.read_byte_data(self.address,2)<<8) | self.bus.read_byte_data(self.address,1))


    def read_byte(self, addr):
        return self.read_byte_data(addr,0x0)
    def write_byte(self, addr,data):
        return self.write_byte_data(addr,0x0,data)





class octopus_bus_old(object):
    def __init__(self,bus,address,channel,delay=0.01):
        self.bus = bus
        self.delay=delay
        self.address = address
        self.channel=channel




    def write_byte_data(self, addr,command,data,register_16b=0):
        #bring i2c in reset
        self.bus.write_byte_data(self.address,1,1)
        #write address
        self.bus.write_byte_data(self.address,2,addr<<1)
        #write register
        self.bus.write_byte_data(self.address,3,command &0xff)
        self.bus.write_byte_data(self.address,4,(command >>8) &0xff)
        #write data
        self.bus.write_byte_data(self.address,5,data &0xff)
        self.bus.write_byte_data(self.address,6,(data>>8) &0xff)

        d=0
        if register_16b:
            d = 0x4
        else:
            d = 0x6
        d = d | (self.channel << 4)

        #run the command
        self.bus.write_byte_data(self.address,1,d)

        while True:
            res = self.bus.read_byte_data(self.address,0)
            if res != 0:
                break
        if res == 0x02:
            raise Exception('I2C acknowledge failed')

    def write_word_data(self, addr,command,data,register_16b=0):
        #bring i2c in reset
        self.bus.write_byte_data(self.address,1,1)
        #write address
        self.bus.write_byte_data(self.address,2,addr<<1)
        #write register
        self.bus.write_byte_data(self.address,3,command &0xff)
        self.bus.write_byte_data(self.address,4,(command >>8) &0xff)
        #write data
        self.bus.write_byte_data(self.address,5,data &0xff)
        self.bus.write_byte_data(self.address,6,(data>>8) &0xff)

        d=0
        if register_16b:
            d = 0
        else:
            d = 0x2
        d = d | (self.channel << 4)

        #run the command
        self.bus.write_byte_data(self.address,1,d)

        while True:
            res = self.bus.read_byte_data(self.address,0)
            if res != 0:
                break
        if res == 0x02:
            raise Exception('I2C acknowledge failed')



    def read_byte_data(self, addr,command,register_16b=0):
        #bring i2c in reset
        self.bus.write_byte_data(self.address,1,1)
        #write address
        self.bus.write_byte_data(self.address,2,addr<<1)
        #write register
        self.bus.write_byte_data(self.address,3,command &0xff)
        self.bus.write_byte_data(self.address,4,(command >>8) &0xff)
        d = 0
        if register_16b:
            d = 0xc
        else:
            d = 0xe

        # Mux channel
        d = d | (self.channel << 4)
        self.bus.write_byte_data(self.address,1,d)

        while True:
            res = self.bus.read_byte_data(self.address,0)
            if res != 0:
                break
        if res == 0x02:
            raise Exception('I2C acknowledge failed addr={addr}')
        return self.bus.read_byte_data(self.address,1)

    def read_word_data(self, addr,command,register_16b=0):
        #bring i2c in reset
        self.bus.write_byte_data(self.address,1,1)
        #write address
        self.bus.write_byte_data(self.address,2,addr<<1)
        #write register
        self.bus.write_byte_data(self.address,3,command &0xff)
        self.bus.write_byte_data(self.address,4,(command >>8) &0xff)
        d = 0
        if register_16b:
            d = 0x8
        else:
            d = 0xa
        # Mux channel
        d = d | (self.channel << 4)
        self.bus.write_byte_data(self.address,1,d)

        while True:
            res = self.bus.read_byte_data(self.address,0)
            if res != 0:
                break
        if res == 0x02:
            raise Exception('I2C acknowledge failed')
        return ((self.bus.read_byte_data(self.address,2)<<8) | self.bus.read_byte_data(self.address,1))


    def read_byte(self, addr):
        return self.read_byte_data(addr,0x0)
    def write_byte(self, addr,data):
        return self.write_byte_data(addr,0x0,data)




class device(object):
    def __init__(self,bus,address,route=[]):
        self.bus=bus
        self.addr=address
        self.route=route

    def select(self):
        if len(self.route):
            for obj in self.route:
                if obj['type']==-1:
                    obj['expander'].selectPort(obj['port'],True)
                if obj['type']==0:
                    obj['expander'].selectPort(obj['port'])
                if obj['type']==1:
                    obj['expander'].ioHigh(obj['port'])
                if obj['type']==2:
                    obj['expander'].ioLow(obj['port'])
                if obj['type']==3:
                    obj['expander'].activeLowOrZ(obj['port'])


    def getBit(self,number,bit):
        return ((1<<bit) & number)>>bit


    def reverseBytes(self,word):
        byte0 = word & 255
        byte1 = (word & (255<<8))>>8
        return (byte0<<8) | byte1
        return word

    def twos_comp(self,val, bits):
        if (val & (1 << (bits - 1))) != 0: # if sign bit is set e.g., 8bit: 128-255
            val = val - (1 << bits)        # compute negative value
        return val


    def linear11(self,word):
        Y = 0x7ff & word

        Y=self.twos_comp(Y,11)
        N = (0xf800 & word)>>11
        N=self.twos_comp(N,5)
        return Y*pow(2,N)

    def linear16(self,word):
        return word/float(1<<12)

    def __call__(self,func,*args):
        return getattr(self,func)(*args)




class device_group(object):
    def __init__(self,devices):
        self.devices=devices

    def __call__(self,func,*args):
        result=[]
        for d in self.devices:
            d.select()
            if not hasattr(d,func):
                result.append(None)
            else:
                result.append(getattr(d,func)(*args))
        return result





class firefly(device):
    def __init__(self,bus,address,route=[],info=""):
        super(firefly,self).__init__(bus,address,route)
        self.information=info

    def info(self):
        return self.information

    def ping(self):
        return (self.bus.read_byte_data(self.addr,0)!=-6)

    def status(self):
        return self.bus.read_byte_data(self.addr,2)


    def temperature(self):
        return (self.bus.read_byte_data(self.addr,22))

    def VCC3V3(self):
        return ((self.bus.read_byte_data(self.addr,26)<<8)|(self.bus.read_byte_data(self.addr,27)))*100.0e-6


    def setAddress(self,address):
        self.bus.write_byte_data(self.addr,127,0x02)
        self.bus.write_byte_data(self.addr,127,address)


class firefly28G(firefly):
    def __init__(self,bus,address,route=[],info=""):
        super().__init__(bus,address,route,info)

    def alarms(self):
        alarm=[]
        lossOfSignal=self.bus.read_byte_data(self.addr,3)
        for i in range (0,8):
            if i<=3:
                TR='RX'
                offset=0
            else:
                TR='TX'
                offset=4
            if self.getBit(lossOfSignal,i):
                alarm.append("Loss Of Signal "+TR+str(i-offset))
        txLoss= self.bus.read_byte_data(self.addr,4)
        for i in range (0,8):
            if self.getBit(lossOfSignal,i):
                alarm.append("TX FAULT "+str(i))
        cdr= self.bus.read_byte_data(self.addr,5)
        for i in range (0,8):
            if i<=3:
                TR='RX'
                offset=0
            else:
                TR='TX'
                offset=4
            if self.getBit(cdr,i):
                alarm.append("CDR Loss Of Signal "+TR+str(i-offset))
        temperature=self.bus.read_byte_data(self.addr,6)
        while self.getBit(temperature,0)==1:
            temperature=self.bus.read_byte_data(self.addr,6)
        for i in range (4,8):
            if self.getBit(temperature,i):
                if i==4:
                    alarm.append("temperature Low Warning")
                if i==5:
                    alarm.append("temperature Low Alarm")
                if i==6:
                    alarm.append("temperature High Warning")
                if i==7:
                    alarm.append("temperature High Alarm")

        vcc =self.bus.read_byte_data(self.addr,7)
        for i in range (0,8):
            if self.getBit(vcc,i):
                if i==0:
                    alarm.append("VCC 1.8V low Warning")
                if i==1:
                    alarm.append("VCC 1.8V high Warning")
                if i==2:
                    alarm.append("VCC 1.8V low Alarm")
                if i==3:
                    alarm.append("VCC 1.8V high Alarm")
                if i==4:
                    alarm.append("VCC 3.3V low Warning")
                if i==5:
                    alarm.append("VCC 3.3V high Warning")
                if i==6:
                    alarm.append("VCC 3.3V low Alarm")
                if i==7:
                    alarm.append("VCC 3.3V high Alarm")

        power=(self.bus.read_byte_data(self.addr,10)<<8)|(self.bus.read_byte_data(self.addr,9))
        for i in range (0,16):
            if self.getBit(power,i):
                if i==0:
                    alarm.append("RX4 Power Low Warning")
                if i==1:
                    alarm.append("RX4 Power High Warning")
                if i==2:
                    alarm.append("RX4 Power Low Alarm")
                if i==3:
                    alarm.append("RX4 Power High Alarm")
                if i==4:
                    alarm.append("RX3 Power Low Warning")
                if i==5:
                    alarm.append("RX3 Power High Warning")
                if i==6:
                    alarm.append("RX3 Power Low Alarm")
                if i==7:
                    alarm.append("RX3 Power High Alarm")
                if i==8:
                    alarm.append("RX2 Power Low Warning")
                if i==9:
                    alarm.append("RX2 Power High Warning")
                if i==10:
                    alarm.append("RX2 Power Low Alarm")
                if i==11:
                    alarm.append("RX2 Power High Alarm")
                if i==12:
                    alarm.append("RX1 Power Low Warning")
                if i==13:
                    alarm.append("RX1 Power High Warning")
                if i==14:
                    alarm.append("RX1 Power Low Alarm")
                if i==15:
                    alarm.append("RX1 Power High Alarm")


        return alarm

    def VCC1V8(self):
        return ((self.bus.read_byte_data(self.addr,28)<<8)|(self.bus.read_byte_data(self.addr,29)))*100.0e-6


    def operatingTime(self):
        return ((self.bus.read_byte_data(self.addr,19)<<8)|(self.bus.read_byte_data(self.addr,20)))*2



    def opticalPower(self):
        power={}
        power['RX1']=((self.bus.read_byte_data(self.addr,34)<<8)|(self.bus.read_byte_data(self.addr,35)))*0.1e-6
        power['RX2']=((self.bus.read_byte_data(self.addr,36)<<8)|(self.bus.read_byte_data(self.addr,37)))*0.1e-6
        power['RX3']=((self.bus.read_byte_data(self.addr,38)<<8)|(self.bus.read_byte_data(self.addr,39)))*0.1e-6
        power['RX4']=((self.bus.read_byte_data(self.addr,40)<<8)|(self.bus.read_byte_data(self.addr,41)))*0.1e-6
        return power

    def txChannelDisabled(self):
        return self.bus.read_byte_data(self.addr,86)

    def enableChannelTX(self,channel):
        status=self.txChannelDisabled()
        mask = 255^(1<<channel)
        self.bus.write_byte_data(self.addr,86,status&mask)

    def disableChannelTX(self,channel):
        status=self.txChannelDisabled()
        self.bus.write_byte_data(self.addr,86,status|(1<<channel))

    def rxChannelDisabled(self):
        self.bus.write_byte_data(self.addr,127,0x3)
        status=self.bus.read_byte_data(self.addr,241)
        self.bus.write_byte_data(self.addr,127,0x0)
        return status

    def enableChannelRX(self,channel):
        status=self.rxChannelDisabled()
        mask = 255^(1<<channel)
        self.bus.write_byte_data(self.addr,127,0x3)
        self.bus.write_byte_data(self.addr,241,status&mask)
        self.bus.write_byte_data(self.addr,127,0x0)

    def disableChannelRX(self,channel):
        status=self.rxChannelDisabled()
        self.bus.write_byte_data(self.addr,127,0x3)
        self.bus.write_byte_data(self.addr,241,status|(1<<channel))
        self.bus.write_byte_data(self.addr,127,0x0)

    def rxOutputAmplitude(self,channel,output):
        self.bus.write_byte_data(self.addr,127,0x3)
        status= (self.bus.read_byte_data(self.addr,239)<<8)|(self.bus.read_byte_data(self.addr,238))
        mask = 0xf <<((3-channel)*4)
        mask =0xffff ^ mask
        val = (output<<((3-channel)*4)) & 0xffff
        status = (status&mask)|val
        self.bus.write_byte_data(self.addr,238,status)
        self.bus.write_byte_data(self.addr,239,status>>8)
        self.bus.write_byte_data(self.addr,127,0x0)


        return status


    def cdr(self):
        return self.bus.read_byte_data(self.addr,98)
    def cdrRate(self):
        return self.bus.read_byte_data(self.addr,99)

    def cdrEnableRX(self,channel):
        val = self.cdr()
        self.bus.write_byte_data(self.addr,98,(1<<channel) | val)
    def cdrEnableTX(self,channel):
        val = self.cdr()
        self.bus.write_byte_data(self.addr,98,(1<<(channel+4)) | val)
    def cdrDisableRX(self,channel):
        val = self.cdr()
        mask = 255 ^ (1<<channel)
        self.bus.write_byte_data(self.addr,98,val &mask)

    def cdrDisableTX(self,channel):
        val = self.cdr()
        mask = 255 ^ (1<<(4+channel))
        self.bus.write_byte_data(self.addr,98,mask & val)

    def cdrRateRX28(self,channel):
        val = self.cdrRate()
        self.bus.write_byte_data(self.addr,99,(1<<channel) | val)
    def cdrRateTX28(self,channel):
        val = self.cdrRate()
        self.bus.write_byte_data(self.addr,99,(1<<(channel+4)) | val)
    def cdrRateRX25(self,channel):
        val = self.cdrRate()
        mask = 255^(1<<channel)
        self.bus.write_byte_data(self.addr,99,mask & val)
    def cdrRateTX25(self,channel):
        val = self.cdrRate()
        mask = 255^(1<<(4+channel))
        self.bus.write_byte_data(self.addr,99,mask & val)

    def channelPolarity(self):
        self.bus.write_byte_data(self.addr,127,0x03)
        polarity = self.bus.read_byte_data(self.addr,226)
        self.bus.write_byte_data(self.addr,127,0x00)
        return polarity


    def normalPolarityTX(self,channel):
        self.bus.write_byte_data(self.addr,127,0x03)
        polarity = self.bus.read_byte_data(self.addr,226)
        mask = 255 ^ (1<<channel)
        self.bus.write_byte_data(self.addr,226,mask & polarity)
        self.bus.write_byte_data(self.addr,127,0x00)

    def normalPolarityRX(self,channel):
        self.bus.write_byte_data(self.addr,127,0x03)
        polarity = self.bus.read_byte_data(self.addr,226)
        mask = 255 ^ (1<<(4+channel))
        self.bus.write_byte_data(self.addr,226,mask & polarity)
        self.bus.write_byte_data(self.addr,127,0x00)

    def reversePolarityTX(self,channel):
        self.bus.write_byte_data(self.addr,127,0x03)
        polarity = self.bus.read_byte_data(self.addr,226)
        self.bus.write_byte_data(self.addr,226,(1<<channel)|polarity)
        self.bus.write_byte_data(self.addr,127,0x00)

    def reversePolarityRX(self,channel):
        self.bus.write_byte_data(self.addr,127,0x03)
        polarity = self.bus.read_byte_data(self.addr,226)
        self.bus.write_byte_data(self.addr,226,(1<<(4+channel))|polarity)
        self.bus.write_byte_data(self.addr,127,0x00)


    def rxOutputState(self):
        self.bus.write_byte_data(self.addr,127,0x03)
        rxdisabled = self.bus.read_byte_data(self.addr,241)
        self.bus.write_byte_data(self.addr,127,0x00)
        return rxdisabled


class firefly16GRX(firefly):
    def __init__(self,bus,address,route=[],info=""):
        super(firefly16GRX,self).__init__(bus,address,route,info)

    def alarms(self):
        alarm=[]
        LOS=(self.bus.read_byte_data(self.addr,9)<<7) | (self.bus.read_byte_data(self.addr,8))
        for i in range (0,12):
            if self.getBit(LOS,i):
                alarm.append("Loss Of Signal "+str(i))
        temperature=self.bus.read_byte_data(self.addr,17)
        if self.getBit(temperature,6):
            alarm.append("temperature LOW")
        if self.getBit(temperature,7):
            alarm.append("temperature HIGH")


        vcc =self.bus.read_byte_data(self.addr,18)
        if self.getBit(vcc,6):
            alarm.append("VCC 3.3V LOW")
        if self.getBit(vcc,7):
            alarm.append("VCC 3.3V HIGH")
        return alarm

    def operatingTime(self):
        return ((self.bus.read_byte_data(self.addr,38)<<8)|(self.bus.read_byte_data(self.addr,39)))*2

    def rxChannelDisabled(self):
        return (self.bus.read_byte_data(self.addr,52)<<8) | (self.bus.read_byte_data(self.addr,53))

    def enableChannelRX(self,channel):
        status=self.rxChannelDisabled() & (0xffff ^(1<<channel))
        self.bus.write_byte_data(self.addr,52,status>>8)
        self.bus.write_byte_data(self.addr,53,status & 255)

    def disableChannelRX(self,channel):
        status=self.rxChannelDisabled()|(1<<channel)
        self.bus.write_byte_data(self.addr,52,status>>8)
        self.bus.write_byte_data(self.addr,53,status & 255)

    def amplitude(self):
        a1 = self.bus.read_byte_data(self.addr,62)
        a2 = self.bus.read_byte_data(self.addr,63)
        a3 = self.bus.read_byte_data(self.addr,64)
        a4 = self.bus.read_byte_data(self.addr,65)
        a5 = self.bus.read_byte_data(self.addr,66)
        a6 = self.bus.read_byte_data(self.addr,67)
        val = (a1<<(5*8)) | (a2<<(4*8)) |(a3<<(3*8)) |(a4<<(2*8)) |(a5<<(1*8)) | a6
        return val

    def setAmplitude(self,channel,amplitude):
        channelMap={
            0:{'addr':67,'shift':0,'mask':0xf0 },
            1:{'addr':67,'shift':4,'mask':0x0f },
            2:{'addr':66,'shift':0,'mask':0xf0 },
            3:{'addr':66,'shift':4,'mask':0x0f },
            4:{'addr':65,'shift':0,'mask':0xf0 },
            5:{'addr':65,'shift':4,'mask':0x0f },
            6:{'addr':64,'shift':0,'mask':0xf0 },
            7:{'addr':64,'shift':4,'mask':0x0f },
            8:{'addr':63,'shift':0,'mask':0xf0 },
            9:{'addr':63,'shift':4,'mask':0x0f },
            10:{'addr':62,'shift':0,'mask':0xf0 },
            11:{'addr':62,'shift':4,'mask':0x0f }
            }


        byte = self.bus.read_byte_data(self.addr,channelMap[channel]['addr'])
        byte = byte & channelMap[channel]['mask']
        byte = byte | amplitude <<channelMap[channel]['shift']
        self.bus.write_byte_data(self.addr,channelMap[channel]['addr'],byte)




    def outputDisabled(self):
        return (self.bus.read_byte_data(self.addr,54)<<8) | (self.bus.read_byte_data(self.addr,55))

    def enableOutput(self,channel):
        status=self.outputDisabled() & ( 0xfff ^ (1<<channel))
        self.bus.write_byte_data(self.addr,54,status>>8)
        self.bus.write_byte_data(self.addr,55,status & 255)

    def disableOutput(self,channel):
        status=self.outputDisabled()|(1<<channel)
        self.bus.write_byte_data(self.addr,54,status>>8)
        self.bus.write_byte_data(self.addr,55,status & 255)



class firefly16GTX(firefly):
    def __init__(self,bus,address,route=[],info=""):
        super(firefly16GTX,self).__init__(bus,address,route,info)



    def alarms(self):
        alarm=[]
        laserFault=(self.bus.read_byte_data(self.addr,9)<<8) | (self.bus.read_byte_data(self.addr,10))
        for i in range (0,12):
            if self.getBit(laserFault,i):
                alarm.append("Laser Fault "+str(i))
        temperature=self.bus.read_byte_data(self.addr,17)
        if self.getBit(temperature,6):
            alarm.append("temperature LOW")
        if self.getBit(temperature,7):
            alarm.append("temperature HIGH")


        vcc =self.bus.read_byte_data(self.addr,18)
        if self.getBit(vcc,6):
            alarm.append("VCC 3.3V LOW")
        if self.getBit(vcc,7):
            alarm.append("VCC 3.3V HIGH")
        return alarm

    def operatingTime(self):
        return ((self.bus.read_byte_data(self.addr,38)<<8)|(self.bus.read_byte_data(self.addr,39)))*2

    def txChannelDisabled(self):
        return (self.bus.read_byte_data(self.addr,52)<<8) | (self.bus.read_byte_data(self.addr,53))

    def enableChannelTX(self,channel):
        status=self.txChannelDisabled()
        mask = 0xffff ^(1<<channel)
        status=status & mask
        self.bus.write_byte_data(self.addr,52,status>>8)
        self.bus.write_byte_data(self.addr,53,status & 255)

    def disableChannelTX(self,channel):
        status=self.txChannelDisabled()|(1<<channel)
        self.bus.write_byte_data(self.addr,52,status>>8)
        self.bus.write_byte_data(self.addr,53,status & 255)


    def channelPolarity(self):
        return (self.bus.read_byte_data(self.addr,58)<<8) | (self.bus.read_byte_data(self.addr,59))

    def normalPolarityTX(self,channel):
        status = self.channelPolarity() & (255^(1<<channel))
        self.bus.write_byte_data(self.addr,58,status>>8)
        self.bus.write_byte_data(self.addr,59,(status & 255))

    def reversePolarityTX(self,channel):
        status = self.channelPolarity()|(1<<channel)
        self.bus.write_byte_data(self.addr,58,status>>8)
        self.bus.write_byte_data(self.addr,59,(status & 255))



class si539x(device):
    def __init__(self,bus,address,route=[]):
        super(si539x,self).__init__(bus,address,route)

    def ping(self):
        self.bus.write_byte_data(self.addr,0x01,0)
        diag = self.bus.read_i2c_block_data(self.addr,0x0002,4)
        print("Reading Part: {number}{grade}-{rev}".format(number = ((diag[1]<<8)|diag[0]),grade=str(diag[2]),rev=str(diag[3])))

    def custom_read(self,page,reg):
        self.bus.write_byte_data(self.addr,0x01,page)
        return hex(self.bus.read_byte_data(self.addr,reg))
    def custom_write(self,page,reg,data):
        self.bus.write_byte_data(self.addr,0x01,page)
        self.bus.write_byte_data(self.addr,reg,data)




    def status(self):
        self.bus.write_byte_data(self.addr,0x01,0x00)
        status= self.bus.read_byte_data(self.addr,0x0c)
        out=[]
        if self.getBit(status,0):
            out.append("Device is calibrating")
        if self.getBit(status,1):
            out.append("No signal in XAXB pins")
        if self.getBit(status,3):
            out.append("Cannot lock in XAXB pins")
        if self.getBit(status,5):
            out.append("SMBus Error")

        status= self.bus.read_byte_data(self.addr,0x0d)
        if self.getBit(status,4):
            out.append("Out of Frequency for input 0")
        if self.getBit(status,5):
            out.append("Out of Frequency for input 1")
        if self.getBit(status,6):
            out.append("Out of Frequency for input 2")
        if self.getBit(status,7):
            out.append("Out of Frequency for input 3")
        if self.getBit(status,0):
            out.append("Loss Of Signal for input 0")
        if self.getBit(status,1):
            out.append("Loss Of Signal for input 1")
        if self.getBit(status,2):
            out.append("Loss Of Signal for input 2")
        if self.getBit(status,3):
            out.append("Loss Of Signal for input 3")


        return out




    def load(self,package,resource):
        gtclockdata=pkgutil.get_data(package,resource).decode('utf-8').split('\r\n')

        for data in gtclockdata:
            row=data.split(',')
            if len(row)==2:
                if row[0]=='delay':
                    print("Waiting")
                    time.sleep(float(row[1]))
                    continue
                slave_addr = int(row[0],16)
                data = int(row[1],16)
                page = slave_addr>>8
                reg = slave_addr & 0x00ff
                #pick page
                self.bus.write_byte_data(self.addr,0x01,page)
                #write setting
                self.bus.write_byte_data(self.addr,reg,data)




    def load_config(self,filename):
        self.last_command = "Success"
        with open(filename) as csv_file:
            csv_reader = csv.reader(csv_file, delimiter=',')
            for row in csv_reader:
                if len(row)==2:
                    if row[0]=='delay':
                        print("Waiting")
                        time.sleep(float(row[1]))
                        continue
                    slave_addr = int(row[0],16)
                    data = int(row[1],16)
                    page = slave_addr>>8
                    reg = slave_addr & 0x00ff
                    #pick page
                    self.bus.write_byte_data(self.addr,0x01,page)
                    #write setting
                    self.bus.write_byte_data(self.addr,reg,data)



    def input_select(self,in_ch):
        if (in_ch < 0 or in_ch > 3):
            print("Error: in_ch must be 0, 1, 2, or 3\n")
            return
        mask = 0x01
        page = 0x05
        reg = 0x2A
        data = 0
        self.bus.write_byte_data(self.addr,0x01,page)
        data = hex(self.bus.read_byte_data(self.addr,0x07))
        print("Active Input: {}".format(data))
        data = (in_ch << 1) | mask
        self.bus.write_byte_data(self.addr,reg,data)
        data = hex(self.bus.read_byte_data(self.addr,0x07))
        print("Active Input: {}".format(data))
        return




class lmk5c33216(device):
    def __init__(self,bus,address,route=[]):
        super(lmk5c33216,self).__init__(bus,address,route)

    def readback(self):
        for reg in range(0,1288):
            data = self.bus.read_byte_data(self.addr,reg,1)
            print('R{} = '.format(reg),data)

    def read_reg(self, reg):
        return self.bus.read_byte_data(self.addr,reg,1)

    def sync(self):
        r21=self.bus.read_byte_data(self.addr,21,1)
        self.bus.write_byte_data(self.addr,21,r21|(1<<6),1)
        r23=self.bus.read_byte_data(self.addr,23,1)
        self.bus.write_byte_data(self.addr,23,r23|(1<<6),1)
        r23=self.bus.read_byte_data(self.addr,23,1)
        self.bus.write_byte_data(self.addr,23,r23&0xbf,1)
        r21=self.bus.read_byte_data(self.addr,21,1)
        self.bus.write_byte_data(self.addr,21,r21&0xbf,1)

    def reset(self):
        r23=self.bus.read_byte_data(self.addr,23,1)
        self.bus.write_byte_data(self.addr,23,r23|(1<<6),1)
        r23=self.bus.read_byte_data(self.addr,23,1)
        self.bus.write_byte_data(self.addr,23,r23&0xbf,1)



    def validate_config(self,filename):
        values={}
        with open(filename) as csv_file:
            csv_reader = csv.reader(csv_file, delimiter='\t')
            for row in csv_reader:
                raw=int(row[1],16)
                reg = (raw>>8) & 0xffff
                data=raw&0xff
                values[reg]=data
                rback=self.bus.read_byte_data(self.addr,reg,1)
                if rback!=data:
                    print('Difference in R{}: write value={} read value={}'.format(reg,data,rback))



    def load_config(self,filename):
        values={}
        with open(filename) as csv_file:
            csv_reader = csv.reader(csv_file, delimiter='\t')
            for row in csv_reader:
                raw=int(row[1],16)
                reg = (raw>>8) & 0xffff
                data=raw&0xff
                values[reg]=data
                if reg==23:
                    continue
                self.bus.write_byte_data(self.addr,reg,data,1)


        r21=self.bus.read_byte_data(self.addr,21,1)
        self.bus.write_byte_data(self.addr,21,r21|(1<<6),1)
        r23=self.bus.read_byte_data(self.addr,23,1)
        self.bus.write_byte_data(self.addr,23,r23|(1<<6),1)
        self.bus.write_byte_data(self.addr,23,r23,1)
        time.sleep(0.1)
        self.bus.write_byte_data(self.addr,21,r21,1)

class tca6408a(device):
        def __init__(self,bus,address,route=[],configPort=0xff,outputData=0):
            super(tca6408a,self).__init__(bus,address,route)
            super(tca6408a,self).select()
            #First write the outputs
            self.bus.write_byte_data(self.addr,0x01,outputData)
            #Then configure
            self.bus.write_byte_data(self.addr,0x03,configPort)



        def input(self):
            return self.bus.read_byte_data(self.addr,0x00)

        def output(self):
            return self.bus.read_byte_data(self.addr,0x01)

        def config(self):
            return self.bus.read_byte_data(self.addr,0x03)


        def setOutput(self,data):
            self.bus.write_byte_data(self.addr,0x01,data)


        def selectPort(self,bit,invert=False):
            data = 1<<bit
            if invert:
                data=0xff ^ (1<<bit)
            self.bus.write_byte_data(self.addr,0x01,data & 255)



        def ioHigh(self,bit):
            state =self.bus.read_byte(self.addr)
            data = (1<<bit)| state
            self.bus.write_byte_data(self.addr,0x01,data & 255)



        def ioLow(self,bit):
            state =self.bus.read_byte(self.addr)
            data = (1<<bit)^state
            self.bus.write_byte_data(self.addr,0x01,data & 255)


class tca9539(device):
        def __init__(self,bus,address,route=[],configPort=65535,outputData=0):
            super(tca9539,self).__init__(bus,address,route)
            super(tca9539,self).select()
            #First write the outputs
            self.bus.write_byte_data(self.addr,0x02,outputData & 0xff)
            self.bus.write_byte_data(self.addr,0x03,outputData >>8 )
            #Then configure
            self.bus.write_byte_data(self.addr,0x06,configPort & 255)
            self.bus.write_byte_data(self.addr,0x07,configPort >>8)


        def input(self):
            return (self.bus.read_byte_data(self.addr,1)<<8 | self.bus.read_byte_data(self.addr,0))

        def output(self):
            return (self.bus.read_byte_data(self.addr,3)<<8 | self.bus.read_byte_data(self.addr,2))

        def config(self):
            return (self.bus.read_byte_data(self.addr,7)<<8 | self.bus.read_byte_data(self.addr,6))


        def setOutput(self,data):
            self.bus.write_byte_data(self.addr,0x02,data & 255)
            self.bus.write_byte_data(self.addr,0x03,data >>8 )

        def setConfig(self,data):
            self.bus.write_byte_data(self.addr,0x06,data & 255)
            self.bus.write_byte_data(self.addr,0x07,data >>8 )

        def selectPort(self,bit,invert=False):
            data = 1<<bit
            if invert:
                data=0xffff ^ (1<<bit)
            self.bus.write_byte_data(self.addr,0x02,data & 255)
            self.bus.write_byte_data(self.addr,0x03,(data >>8) )

        def activeLowOrZ(self,bit):
            #set the output value for the bit we want
            data = (1<<bit)^0xffff

            self.bus.write_byte_data(self.addr,0x02,data & 0xff)
            self.bus.write_byte_data(self.addr,0x03,(data >>8) )

            self.bus.write_byte_data(self.addr,0x06,data & 0xff)
            self.bus.write_byte_data(self.addr,0x07,(data >>8) )


        def ioHigh(self,bit):
            state =self.bus.read_byte(self.addr)
            data = (1<<bit)| state
            self.bus.write_byte_data(self.addr,0x02,data & 255)
            self.bus.write_byte_data(self.addr,0x03,data >>8 )


        def ioLow(self,bit):
            state =self.bus.read_byte(self.addr)
            data = (1<<bit)^state
            self.bus.write_byte_data(self.addr,0x02,data & 255)
            self.bus.write_byte_data(self.addr,0x03,data >>8 )


class tca9548a(device):
        def __init__(self,bus,address,route=[]):
            super(tca9548a,self).__init__(bus,address,route)
            super(tca9548a,self).select()


        def status(self):
            info = self.bus.read_byte(self.addr)
            info = (31<<3) ^ info
            return info

        def interrupts(self):
            info = self.bus.read_byte(self.addr) >>4
            return info

        def selectPort(self,port):
            data =  (1<<port)
            self.bus.write_byte(self.addr,data)



class tmp461(device):
    def __init__(self,bus,address,limits,etafactor=1.002,offset=0,route=[]):
        super(tmp461,self).__init__(bus,address,route)
        super(tmp461,self).select()
        self.bus.write_byte_data(address,0x21,10)
        if len(limits)!=2:
            raise Exception('Need limits for both local and remote')
        self.bus.write_byte_data(self.addr,0x19,limits[0])
        self.bus.write_byte_data(self.addr,0x20,limits[1])
        self.limits = limits
        self.adjust = self.twos_comp(int(1.008*2088/etafactor-2088),8)
        self.bus.write_byte_data(self.addr,0x23,self.adjust)
        offset_int = int(offset/0.0625)
        self.bus.write_byte_data(self.addr,0x11,(offset_int>>8)&0xff)
        self.bus.write_byte_data(self.addr,0x12,offset_int & 0xff)




    def temperatures(self):
        local = (self.bus.read_byte_data(self.addr,0x0)<<4) | (self.bus.read_byte_data(self.addr,0x15)>>4)
        local=self.twos_comp(local,12)*0.0625
        remote= (self.bus.read_byte_data(self.addr,0x1)<<4) | (self.bus.read_byte_data(self.addr,0x10)>>4)
        remote=self.twos_comp(remote,12)*0.0625
        return [local,remote]

    def validate(self):
        t=self.temperatures()
        for temp,lim in zip(t,self.limits):
            if temp>lim:
                return False
        return True

class adc128d818(device):
    def __init__(self,bus,address,channelMap,route=[],mode = 0x02):
        super().__init__(bus,address,route)

        self.select()
        self.bus.write_byte_data(self.addr,0x0b,mode)
        self.channelMap =   channelMap

    def ping(self):
        info =self.bus.read_byte_data(self.addr,0x3e)
        return info

    def configuration(self):
        return self.bus.read_byte_data(self.addr,0x00)

    def interrupts(self):
         return self.bus.read_byte_data(self.addr,0x01)

    def adc12bit(self,channel):
        while True:
            if self.bus.read_byte_data(self.addr, 0xC) == 0:
                break
            time.sleep(0.01)
        self.bus.write_byte_data(self.addr,0x9,1)
        while True:
            if self.bus.read_byte_data(self.addr, 0xC) == 0:
                break
            time.sleep(0.01)

        return self.bus.read_word_data(self.addr,channel+0x20)



    def voltage(self,rail):
        return 2.56*self.adc12bit(self.channelMap[rail]['ch']) *self.channelMap[rail]['factor']/65536.0

    def validate(self,rail):
        v=self.voltage(rail)
        if abs(v-self.channelMap[rail]['nominal'])<self.channelMap[rail]['error']:
            return True
        else:
            return False

class ina226(device):
    def __init__(self,bus,address,calib,route=[]):
        super().__init__(bus,address,route)
        self.calib = calib
    def ping(self):
        return self.bus.read_word_data(self.addr,0xfe)

    def current(self):
        data = self.bus.read_word_data(self.addr,0x01)
        return self.twos_comp(data,16)*0.0000025/self.calib

    def voltage(self):
        data = self.bus.read_word_data(self.addr,0x02)
        return self.twos_comp(data,16)*0.00125

    def power(self):
        return self.current()*self.voltage()



class ltm4700(device):
    def __init__(self,bus,address,route,templimits):
        super().__init__(bus,address,route)
        self.limits=templimits

        #set RSense
        self.select()
        self.bus.write_word_data(self.addr,0xe8,0xf801)

    def ping(self):
        info =self.bus.read_block_data(self.addr,0x99)
        return info

    def set_pulse_skipping_mode(self,channel):
        self.bus.write_byte_data(self.addr,0x0,channel)
        self.bus.write_byte_data(self.addr,0xd4,0xc6)
        self.bus.write_byte_data(self.addr,0x0,0x0)


    def set_operation_mode(self,channel,mode):
        self.bus.write_byte_data(self.addr,0x0,channel)
        self.bus.write_byte_data(self.addr,0x02,mode)
        self.bus.write_byte_data(self.addr,0x0,0x0)

    def turn_on(self,channel):
        self.bus.write_byte_data(self.addr,0x0,channel)
        self.bus.write_byte_data(self.addr,0x01,0x80)
        self.bus.write_byte_data(self.addr,0x0,0x0)

    def turn_off(self,channel):
        self.bus.write_byte_data(self.addr,0x0,channel)
        self.bus.write_byte_data(self.addr,0x01,0x00)
        self.bus.write_byte_data(self.addr,0x0,0x0)

    def vin(self):
        info = self.reverseBytes(self.bus.read_word_data(self.addr,0x88))
        return self.linear11(info)

    def iin(self):
        info = self.reverseBytes(self.bus.read_word_data(self.addr,0x89))
        return self.linear11(info)

    def pin(self):
        info = self.reverseBytes(self.bus.read_word_data(self.addr,0x97))
        return self.linear11(info)


    def vmax(self):
        info = self.reverseBytes(self.bus.read_word_data(self.addr,0x24))
        return self.linear16(info)


    def voltage(self):
        info = self.reverseBytes(self.bus.read_word_data(self.addr,0x8b))
        return self.linear16(info)

    def current(self):
        info = self.reverseBytes(self.bus.read_word_data(self.addr,0x8c))
        return self.linear11(info)

    def temperatures(self):
        info1 = self.reverseBytes(self.bus.read_word_data(self.addr,0x8d))
        info2 = self.reverseBytes(self.bus.read_word_data(self.addr,0x8e))
        return [self.linear11(info1),self.linear11(info2)]

    def frequency(self):
        info = self.reverseBytes(self.bus.read_word_data(self.addr,0x95))
        return self.linear11(info)

    def power(self):
        info = self.reverseBytes(self.bus.read_word_data(self.addr,0x96))
        return self.linear11(info)

    def validate(self):
        t=self.temperatures()
        for temp,lim in zip(t,self.limits):
            if temp>lim:
                return False
        return True


class optical_transceiver(device):
    def __init__(self,bus,address,cage,selectFunc):
        super().__init__(bus,address,[])
        self.selectF = selectFunc
        self.cage=cage
        self.ident={
            0 : 'Unknown / Unspecified',
            1 : 'GBIC',
            2 : 'Module / connector soldered to motherboard',
            3 : 'SFP or SFP+',
            4 : '300 pin XBI',
            5 : 'XENPAK',
            6 : 'XFP',
            7 : 'XFF',
            8 : 'XFP-E',
            9 : 'XPAK',
            10 : 'X2',
            11 : 'DWDM-SFP',
            12 : 'QSFP',
            13 : 'QSFP+ or later',
            14 : 'CXP or later',
            15 : 'Shielded Mini Multilane HD 4X',
            16 : 'Shielded Mini Multilane HD 8X',
            17 : 'QSFP28 or later',
            18 : 'CXP2 (aka CXP28) or later',
            19 : 'CDFP (Style 1/2)',
            20 : 'Shielded Mini Multilane HD 4X Fanout Cable',
            21 : 'Shielded Mini Multilane HD 8X Fanout Cable',
            22 : 'CDFP (Style 3)',
            23 : 'microQSFP',
            24 : 'QSFP-DD 8X Pluggable Transceiver (INF-8628)',
            25 : 'OSFP 8X Pluggable Transceiver',
            26 : 'SFP-DD 2X Pluggable Transceiver',
            27 : 'DSFP Dual Pluggable Transceiver',
            28 : 'x4 MiniLink/OcuLink',
            29 : 'x8 MiniLink',
            30 : 'QSFP+ or later with CMIS'
        }
        self.select()

    def select(self):
        self.selectF(self.cage)

    def identifier(self):
        i = self.bus.read_byte_data(self.addr,0x0)
        if i in self.ident.keys():
            return (self.ident[i])
        else:
            return ("Unknown Transceiver")

    def id(self):
        return self.bus.read_byte_data(self.addr,0x0)

class qsfp(optical_transceiver):
    def __init__(self,bus,address,cage,selectFunc):
        super().__init__(bus,address,cage,selectFunc)

        self.tx_tech = {
            0 : '850nm VCSEL',
            1 : '1310 nm VCSEL',
            2 : '1550 nm VCSEL',
            3 : '1310 nm FP',
            4 : '1310 nm DFB',
            5 : '1550 nm DFB',
            6 : '1310 nm EML',
            7 : '1550 nm EML',
            8 : 'Copper or others'
        }

    def version(self):
        v = self.bus.read_byte_data(self.addr,0x1)
        return v

    def state(self):
        return "Not Implemented"

    def temperature(self):
        t1 = self.bus.read_byte_data(self.addr,22)
        t2 = self.bus.read_byte_data(self.addr,23)
        t=(t1<<8)|t2
        temp = self.twos_comp(t,16)/256.
        return temp
    def voltage(self):
        t1 = self.bus.read_byte_data(self.addr,26)
        t2 = self.bus.read_byte_data(self.addr,27)
        t=(t1<<8)|t2
        voltage =float(t)*100e-6
        return voltage

    def tx_enabled(self):
        return 0xf^self.bus.read_byte_data(self.addr,86)

    def enable_tx(self,mask):
        v=(~mask) &0xf
        self.bus.write_byte_data(self.addr,86,v)

    def rx_enabled(self):
        return 0xf

    def enable_rx(self,mask):
        pass


    def tx_cdr_enabled(self):
        return (self.bus.read_byte_data(self.addr,98)>>4) &0xf
    def rx_cdr_enabled(self):
        return (self.bus.read_byte_data(self.addr,98)) &0xf

    def enable_tx_cdr(self,mask):
        v=(self.bus.read_byte_data(self.addr,98)>>4)|(mask&0xf)
        self.bus.write_byte_data(self.addr,98,v)

    def enable_rx_cdr(self,mask):
        v=(self.bus.read_byte_data(self.addr,98)& 0xf0)|(mask&0xf)
        v=self.bus.write_byte_data(self.addr,98,v)

    def rx_power(self):
        power_values = []
        for i in range(34,42,2):
                MSB = self.bus.read_byte_data(self.addr,i)
                LSB = self.bus.read_byte_data(self.addr,i+1)
                d = (MSB << 8) | (LSB)
                power =  d / 10000.
                if power>0:
                    power_values.append(10*log10(power))
                else:
                    power_values.append(-999)
        return power_values

    def alarms(self):
        alarms = []
        los = self.bus.read_byte_data(self.addr, 3)
        tx_fault = self.bus.read_byte_data(self.addr, 4)
        los_str = ""
        tx_fault_str = ""
        for ch in range(4):
            if (los >> ch) & 1:
                los_str += "Rx%d " % (ch + 1)
            if (los >> ch + 4) & 1:
                los_str += "Tx%d " % (ch + 1)
            if (tx_fault >> ch) & 1:
                tx_fault_str += "Tx%d " % (ch + 1)

        if len(los_str) > 0:
            alarms.append("LOS: " + los_str)
        if len(tx_fault_str) > 0:
            alarms.append("Tx Fault: " + tx_fault_str)

        temp_alarm = self.bus.read_byte_data(self.addr, 6)

        if temp_alarm & 0x80:
            alarms.append("Temp High Alarm")
        elif temp_alarm & 0x20:
            alarms.append("Temp High Warning")
        if temp_alarm & 0x40:
            alarms.append("Temp Low Alarm")
        elif temp_alarm & 0x10:
            alarms.append("Temp Low Warning")

        vcc_alarm = self.bus.read_byte_data(self.addr, 7)

        if vcc_alarm & 0x80:
            alarms.append("VCC High Alarm")
        elif vcc_alarm & 0x20:
            alarms.append("VCC High Warning")
        if vcc_alarm & 0x40:
            alarms.append("VCC Low Alarm")
        elif vcc_alarm & 0x10:
            alarms.append("VCC Low Warning")

        return alarms

    def vendor(self):
        vendor = ""
        for i in range(148, 164):
            vendor += chr(self.bus.read_byte_data(self.addr, i))

        return vendor.replace(" ", "")

    def part_number(self):
        pn = ""
        for i in range(168, 183):
            pn += chr(self.bus.read_byte_data(self.addr, i))

        return pn.replace(" ", "")

    def serial_number(self):
        sn = ""
        for i in range(196, 211):
            sn += chr(self.bus.read_byte_data(self.addr, i))

        return sn.replace(" ", "")

    def technology(self):
        tech = self.bus.read_byte_data(self.addr, 147)
        tx_tech = self.tx_tech[tech >> 4]
        if tech & 1:
            tx_tech += ", tuneable"
        else:
            tx_tech += ", not tuneable"

        if tech & 4:
            tx_tech += ", cooled"
        else:
            tx_tech += ", not cooled"

        if tech & 8:
            tx_tech += ", active wavelength control"

        rx_tech = "PIN detector" if tech & 2 else "APD detector"

        return "TX: %s | RX: %s" % (tx_tech, rx_tech)

    def options(self):
        opts = []
        opts_194 = self.bus.read_byte_data(self.addr, 194)
        if opts_194 & 0x1:
            opts.append("Tx Squelch implemented")
        if opts_194 & 0x2:
            opts.append("Tx Squelch Disable implemented")
        if opts_194 & 0x4:
            opts.append("Rx_Output Disable capable")
        if opts_194 & 0x8:
            opts.append("Rx_Squelch Disable implemented")

        opts_195 = self.bus.read_byte_data(self.addr, 195)
        if opts_195 & 0x2:
            opts.append("Loss of Signal implemented")
        if opts_195 & 0x4:
            opts.append("Tx Squelch implemented to reduce OMA")
        if opts_195 & 0x8:
            opts.append("TX_FAULT signal implemented")
        if opts_195 & 0x10:
            opts.append("TX_DISABLE is implemented and disables the serial output")
        if opts_195 & 0x20:
            opts.append("RATE_SELECT is implemented")
        if opts_195 & 0x40:
            opts.append("Memory page 01 provided")
        if opts_195 & 0x80:
            opts.append("Memory page 02 provided")

        return opts

    def rx_squelch_disabled(self):
        # switch to page 3, and back to 0
        self.bus.write_byte_data(self.addr, 127, 3)
        ret = (self.bus.read_byte_data(self.addr, 240) >> 4) & 0xf
        self.bus.write_byte_data(self.addr, 127, 0)
        return ret

    def tx_squelch_disabled(self):
        # switch to page 3
        self.bus.write_byte_data(self.addr, 127, 3)
        ret = self.bus.read_byte_data(self.addr, 240) & 0xf
        self.bus.write_byte_data(self.addr, 127, 0)
        return ret

    def disable_rx_squelch(self, mask):
        # switch to page 3
        self.bus.write_byte_data(self.addr, 127, 3)
        new_mask = (self.bus.read_byte_data(self.addr, 240) & 0xf) | ((mask & 0xf) << 4)
        self.bus.write_byte_data(self.addr, 240, new_mask)
        self.bus.write_byte_data(self.addr, 127, 0)

    def disable_tx_squelch(self, mask):
        # switch to page 3
        self.bus.write_byte_data(self.addr, 127, 3)
        new_mask = (self.bus.read_byte_data(self.addr, 240) & 0xf0) | (mask & 0xf)
        self.bus.write_byte_data(self.addr, 240, new_mask)
        self.bus.write_byte_data(self.addr, 127, 0)

    def set_rx_output_emphasis(self, emphasis_arr):
        self.bus.write_byte_data(self.addr, 127, 3)
        if len(emphasis_arr) != 4:
            raise Exception("qsfp.set_rx_output_emphasis() emphasis_arr parameter must have a length of 4 (one value per channel)")
        reg_val = ((emphasis_arr[0] & 0xf) << 4) | (emphasis_arr[1] & 0xf)
        self.bus.write_byte_data(self.addr, 236, reg_val)
        reg_val = ((emphasis_arr[2] & 0xf) << 4) | (emphasis_arr[3] & 0xf)
        self.bus.write_byte_data(self.addr, 237, reg_val)
        self.bus.write_byte_data(self.addr, 127, 0)

    def set_rx_output_amplitude(self, amplitude_arr):
        self.bus.write_byte_data(self.addr, 127, 3)
        if len(amplitude_arr) != 4:
            raise Exception("qsfp.set_rx_output_amplitude() amplitude_arr parameter must have a length of 4 (one value per channel)")
        reg_val = ((amplitude_arr[0] & 0xf) << 4) | (amplitude_arr[1] & 0xf)
        self.bus.write_byte_data(self.addr, 238, reg_val)
        reg_val = ((amplitude_arr[2] & 0xf) << 4) | (amplitude_arr[3] & 0xf)
        self.bus.write_byte_data(self.addr, 239, reg_val)
        self.bus.write_byte_data(self.addr, 127, 0)

    def read_reg(self, page, reg_addr):
        self.bus.write_byte_data(self.addr, 127, page)
        val = self.bus.read_byte_data(self.addr, reg_addr)
        self.bus.write_byte_data(self.addr, 127, 0)
        return val

    def write_reg(self, page, reg_addr, value):
        self.bus.write_byte_data(self.addr, 127, page)
        self.bus.write_byte_data(self.addr, reg_addr, value)
        self.bus.write_byte_data(self.addr, 127, 0)

class qsfpdd_v2(optical_transceiver):
    def __init__(self,bus,address,cage,selectFunc):
        super().__init__(bus,address,cage,selectFunc)
    def version(self):
        v = self.bus.read_byte_data(self.addr,0x1)
        return v

    def state(self):
        self.bus.write_byte_data(self.addr,127,0x0)
        state_identifier={
            0x0: "Management Ready",
            0x1: "Data Path Init",
            0x2: "Data Path Powered",
            0x3: "Data Path DeInit"
        }
        state1 = self.bus.read_byte_data(self.addr,0x12)
        state2 = self.bus.read_byte_data(self.addr,0x13)
        state =(state2<<8) |(state1)
        states=[]
        for i in range(0,8):
            states.append(state_identifier[(state>>(2*i))&0x3])
        return states

    def temperature(self):
        self.bus.write_byte_data(self.addr,127,0x0)
        t1 = self.bus.read_byte_data(self.addr,0x1a)
        t2 = self.bus.read_byte_data(self.addr,0x1b)
        t=(t1<<8)|t2
        temp = self.twos_comp(t,16)/256.
        return temp
    def voltage(self):
        self.bus.write_byte_data(self.addr,127,0x0)
        t1 = self.bus.read_byte_data(self.addr,0x1e)
        t2 = self.bus.read_byte_data(self.addr,0x1f)
        t=(t1<<8)|t2
        voltage =float(t)*100e-6
        return voltage

    def tx_enabled(self):
        self.bus.write_byte_data(self.addr,127,0x0)
        return 0xff^self.bus.read_byte_data(self.addr,0x54)

    def enable_tx(self,mask):
        v=(~mask) &0xff
        self.bus.write_byte_data(self.addr,0x54,v)

    def rx_enabled(self):
        self.bus.write_byte_data(self.addr,127,0x0)
        return 0xff^self.bus.read_byte_data(self.addr,0x5a)

    def enable_rx(self,mask):
        mask=0xff&(~mask)
        self.bus.write_byte_data(self.addr,0x5a,v)

    def tx_cdr_enabled(self):
        #default for V20
        self.bus.write_byte_data(self.addr,127,0x0)
        return self.bus.read_byte_data(self.addr,0x58)

    def enable_tx_cdr(self,mask):
        self.bus.write_byte_data(self.addr,0x58,mask)

    def rx_cdr_enabled(self):
        self.bus.write_byte_data(self.addr,127,0x0)
        return self.bus.read_byte_data(self.addr,0x59)

    def enable_rx_cdr(self,mask):
        self.bus.write_byte_data(self.addr,0x59,mask)


    def rx_power(self):
        power_values = []
        for i in range(0x20,0x30,2):
                MSB = self.bus.read_byte_data(self.addr,i)
                LSB = self.bus.read_byte_data(self.addr,i+1)
                d = (MSB << 8) | (LSB)
                power =  d / 10000.
                if power>0:
                    power_values.append(10*log10(power))
                else:
                    power_values.append(-999)
        return power_values



class qsfpdd_v4(optical_transceiver):
    def __init__(self,bus,address,cage,selectFunc):
        super().__init__(bus,address,cage,selectFunc)
        self.select()
        ###Set explicit control
        for lane in range(0,8):
            cfg = self.lane_configuration(lane)
            self.configure_lane(lane,cfg['ApSel'],1,cfg['ID'])

    def capabilities(self):
        interface = {
            1 :'1000BASE-CX',
            2  :'XAUI',
            3  :'XFI',
            4  :'SFI',
            5  :'25GAUI C2M (Annex 109B)',
            6  :'XLAUI C2M (Annex 83B)',
            7  :'XLPPI (Annex 86A)',
            8  :'LAUI-2 C2M (Annex 135C)',
            9  :'50GAUI-2 C2M (Annex 135E)',
            10 :'50GAUI-1 C2M (Annex 135G)',
            11 :'CAUI-4 C2M (Annex 83E)',
            65 :'CAUI-4 C2M (Annex 83E) without FEC',
            66 :'CAUI-4 C2M (Annex 83E) with RS(528,514) FEC',
            12 :'100GAUI-4 C2M (Annex 135E)',
            13 :'100GAUI-2 C2M (Annex 135G)',
            75 :'100GAUI-1-S C2M (Annex 120G)',
            76 :'100GAUI-1-L C2M (Annex 120G)',
            14 :'200GAUI-8 C2M (Annex 120C)',
            15 :'200GAUI-4 C2M (Annex 120E)',
            77 :'200GAUI-2-S C2M (Annex 120G)',
            78 :'200GAUI-2-L C2M (Annex 120G)',
            16 :'400GAUI-16 C2M (Annex 120C)',
            17 :'400GAUI-8 C2M (Annex 120E)',
            79 :'400GAUI-4-S C2M (Annex 120G)',
            80 :'400GAUI-4-L C2M (Annex 120G)',
            81 :'800G S C2M (placeholder)',
            82 :'800G L C2M (placeholder)',
            18 :'Reserved',
            19 :'10GBASE-CX4 (Clause 54)',
            20 :'25GBASE-CR CA-25G-L (Clause 110)' ,
            21 :'25GBASE-CR or 25GBASE-CR-SCA-25G-S (Clause 110)',
            22 :'25GBASE-CR or 25GBASE-CR-SCA-25G-N (Clause 110)',
            23 :'40GBASE-CR4 (Clause 85)',
            67 :'50GBASE-CR2 (Ethernet Technology Consortium) with RS(528,514)(Clause 91) FEC',
            68 :'50GBASE-CR2 (Ethernet Technology Consortium) with BASE-R (Clause74), Fire code FEC',
            69 :'50GBASE-CR2 (Ethernet Technology Consortium) with no FEC',
            24 :'50GBASE-CR (Clause 126)' ,
            25 :'100GBASE-CR10 (Clause 85)',
            26 :'100GBASE-CR4 (Clause 92)' ,
            27 :'100GBASE-CR2 (Clause 136)' ,
            70 :'100GBASE-CR1 (Clause 162)' ,
            28 :'200GBASE-CR4 (Clause 136)' ,
            71 :'200GBASE-CR2 (Clause 162)' ,
            29 :'400G CR8 (Ethernet Technology Consortium)',
            72 :'400GBASE-CR4 (Clause 162)' ,
            73 :'800GBASE-CR8 (placeholder)' ,
            37 :'8GFC (FC-PI-4)',
            38 :'10GFC (10GFC)',
            39 :'16GFC (FC-PI-5)',
            40 :'32GFC (FC-PI-6)',
            41 :'64GFC (FC-PI-7)',
            74 :'128GFC (FC-PI-8)',
            42 :'128GFC (FC-PI-6P)',
            43 :'256GFC (FC-PI-7P)',
            44 :'IB SDR (Arch.Spec.Vol.2)',
            45 :'IB DDR (Arch.Spec.Vol.2)',
            46 :'IB QDR (Arch.Spec.Vol.2)',
            47 :'IB FDR (Arch.Spec.Vol.2)',
            48 :'IB EDR (Arch.Spec.Vol.2)',
            49 :'IB HDR (Arch.Spec.Vol.2)',
            50 :'IB NDR4',
            51 :'E.96 (CPRI Specification V7.0)',
            52 :'E.99 (CPRI Specification V7.0)' ,
            53 :'E.119 (CPRI Specification V7.0)' ,
            54 :'E.238 (CPRI Specification V7.0)',
            55 :'OTL3.4 (ITU-T G.709/Y.1331G.Sup58)',
            56 :'OTL4.10 (ITU-T G.709/Y.1331G.Sup58)',
            57 :'OTL4.4 (ITU-T G.709/Y.1331G.Sup58)',
            58 :'OTLC.4 (ITU-T G.709.1/Y.1331G.Sup58)',
            59 :'FOIC1.4 (ITU-T G.709.1/Y.1331G.Sup58)',
            60 :'FOIC1.2 (ITU-T G.709.1/Y.1331G.Sup58)',
            61 :'FOIC2.8 (ITU-T G.709.1/Y.1331G.Sup58)',
            62 :'FOIC2.4 (ITU-T G.709.1/Y.1331G.Sup58)',
            63 :'FOIC4.16 (ITU-T G.709.1G.Sup58)',
            64 :'FOIC4.8 (ITU-T G.709.1 G.Sup58)'
        }

        media = {0:'Undefined',
                 1:'840 nm Multi-Mode Fiber',
                 2:' 1300/1550 Single-Mode Fiber',
                 3:'Passive Copper',
                 4:'Active Cable',
                 5:'Base-T'}
        for i in range(0,8):
            sffid                =   self.bus.read_byte_data(self.addr,86+i*4)
            moduleMedia          =   self.bus.read_byte_data(self.addr,87+i*4)
            count                =   self.bus.read_byte_data(self.addr,88+i*4)
            hostCount            = count>>4 &0xf
            mediaCount           = count &0xf
            hostAssignment       =   self.bus.read_byte_data(self.addr,89+i*4)
            print('------Application {} ------'.format(i))
            if sffid in interface.keys():
                print (sffid,interface[sffid])
            else:
                print ('Unknown host interface')
            if moduleMedia<6:
                print("Media Type:",media[moduleMedia])
            print ("Lanes counted by Host= {}, and by interface ={}".format(hostCount,mediaCount))
            print ("Lanes to be active: {}".format(hostAssignment))



    def version(self):
        v = self.bus.read_byte_data(self.addr,0x1)
        return v


    def module_state(self):
        state = self.bus.read_byte_data(self.addr,0x3)

        state_identifier={
            0x0: "Reserved",
            0x1: "Low Power",
            0x2: "Power Up",
            0x3: "Ready",
            0x4: "Power Down",
            0x5: "Fault",
            0x6: "Reserved",
            0x7: "Reserved"
        }
        return state_identifier[(state>>1)&0x7]

    def datapath_state(self):
        self.bus.write_byte_data(self.addr,126,0)
        self.bus.write_byte_data(self.addr,127,0x11)

        state_identifier={
            0x0: "Reserved",
            0x1: "Deactivated",
            0x2: "Init",
            0x3: "DeInit",
            0x4: "Activated",
            0x5: "TX On",
            0x6: "TX Off",
            0x7: "Reserved"
        }
        state=[]
        for i in [128,129,130,131]:
            data = self.bus.read_byte_data(self.addr,i)
            state.append(state_identifier[data &0xf])
            state.append(state_identifier[(data>>4) &0xf])
        self.bus.write_byte_data(self.addr,127,0x0)
        return state

    def state(self):
        return (self.module_state(),self.datapath_state())

    def module_characteristics(self):
        c=[]
        self.bus.write_word_data(self.addr,126,0x0001)
        v = self.bus.read_byte_data(self.addr,145)
        if v& (1<<7):
            c.append("Cooling Implemented")
        else:
            c.append("Cooling Not Implemented")
        v = self.bus.read_byte_data(self.addr,146)
        if v!=0:
            c.append("Maximum Temperature={}".format(v))
        v = self.bus.read_byte_data(self.addr,151)
        if v&0x10:
            c.append("Average Power Measured")
        else:
            c.append("OMA Measured")

        v = self.bus.read_byte_data(self.addr,155)
        if v&0x40:
            c.append("Tunable Transmitter")
        else:
            c.append("Non-Tunable Transmitter")

        if v&0x80:
            c.append("Wavelength Control Implemented")
        else:
            c.append("Wavelength Control Not Implemented")

        v = self.bus.read_byte_data(self.addr,161)
        if v& 0x8:
            c.append("Adaptive Equalization Implemented")
        else:
            c.append("Adaptive Equalization Not Implemented")
        if v& 0x4:
            c.append("Fixed Equalization Manual conrtol Implemented")
        else:
            c.append("Fixed Equalization Manual Control Not Implemented")


        self.bus.write_word_data(self.addr,126,0x0000)

        return c



    def temperature(self):
        t1 = self.bus.read_byte_data(self.addr,14)
        t2 = self.bus.read_byte_data(self.addr,15)
        t=(t1<<8)|t2
        temp = self.twos_comp(t,16)/256.
        return temp

    def voltage(self):
        t1 = self.bus.read_byte_data(self.addr,16)
        t2 = self.bus.read_byte_data(self.addr,17)
        t=(t1<<8)|t2
        voltage =float(t)*100e-6
        return voltage

    def reset(self):
        self.bus.write_byte_data(self.addr,126,0x0)
        self.bus.write_byte_data(self.addr,127,0x0)
        self.bus.write_byte_data(self.addr,26,0x8)
        time.sleep(0.5)
        self.bus.write_byte_data(self.addr,26,0x0)

    def datapath_deinit(self,lanes=0xff):
        self.bus.write_word_data(self.addr,126,0x0010)
        self.bus.write_byte_data(self.addr,128,lanes)
        self.bus.write_word_data(self.addr,126,0x0000)

    def lane_configuration(self,lane):
        self.bus.write_word_data(self.addr,126,0x0011)
        data=self.bus.read_byte_data(self.addr,206+lane)
        output={'ID':(data>>1)&0x7,
                'ApSel':(data>>4)&0xf,
                'explicit':data&0x1}
        self.bus.write_word_data(self.addr,126,0x0)
        return output

    def configure_lane(self,lane,ap_sel,explicit_control=1,lane_id=0x0):
        word = (explicit_control &0x1) | ((lane_id &0x7) <<1 ) |(ap_sel<<4)
        self.bus.write_word_data(self.addr,126,0x0010)
        self.bus.write_byte_data(self.addr,145+lane,word)
        self.bus.write_byte_data(self.addr,144,0xff)
        self.bus.write_word_data(self.addr,126,0x0000)


    def enable_tx(self,mask):
        self.bus.write_word_data(self.addr,126,0x0010)
        self.bus.write_byte_data(self.addr,130,~mask)
        self.bus.write_word_data(self.addr,126,0x0000)

    def enable_rx(self,mask):
        self.bus.write_word_data(self.addr,126,0x0010)
        self.bus.write_byte_data(self.addr,138,~mask)
        self.bus.write_word_data(self.addr,126,0x0000)

    def tx_enabled(self):
        self.bus.write_word_data(self.addr,126,0x0010)
        data=self.bus.read_byte_data(self.addr,130)
        self.bus.write_word_data(self.addr,126,0x0000)
        return (~data) &0xff

    def rx_enabled(self):
        self.bus.write_word_data(self.addr,126,0x0010)
        data=self.bus.read_byte_data(self.addr,138)
        self.bus.write_word_data(self.addr,126,0x0010)
        return (~data) & 0xff

    def tx_adaptive_equalization_enabled(self):#
        self.bus.write_word_data(self.addr,126,0x0011)
        data=self.bus.read_byte_data(self.addr,214)
        self.bus.write_word_data(self.addr,126,0x0000)
        return data

    def tx_manual_equalization_values(self):#
        self.bus.write_word_data(self.addr,126,0x0011)
        data=[]
        for reg in [217,218,219,220]:
            v = self.bus.read_byte_data(self.addr,reg)
            data.append(v&0xf)
            data.append((v>>4)&0xf)
        self.bus.write_word_data(self.addr,126,0x0000)
        return data

    def enable_tx_adaptive_equalization(self,mask):
        self.bus.write_word_data(self.addr,126,0x0010)
        self.bus.write_byte_data(self.addr,153,mask)
        self.bus.write_byte_data(self.addr,144,0xff)
        self.bus.write_word_data(self.addr,126,0x0000)

    def set_tx_manual_equalization_values(self,equalizations = [0,0,0,0,0,0,0,0]):
        self.bus.write_word_data(self.addr,126,0x0010)
        self.bus.write_byte_data(self.addr,156,equalizations[0]|(equalizations[1]<<4))
        self.bus.write_byte_data(self.addr,157,equalizations[2]|(equalizations[3]<<4))
        self.bus.write_byte_data(self.addr,158,equalizations[4]|(equalizations[5]<<4))
        self.bus.write_byte_data(self.addr,159,equalizations[6]|(equalizations[7]<<4))
        self.bus.write_byte_data(self.addr,144,0xff)
        self.bus.write_word_data(self.addr,126,0x0000)



    def tx_cdr_enabled(self):
        self.bus.write_word_data(self.addr,126,0x0011)
        data=self.bus.read_byte_data(self.addr,221)
        self.bus.write_word_data(self.addr,126,0x0011)
        return data

    def rx_cdr_enabled(self):
        self.bus.write_word_data(self.addr,126,0x0011)
        data=self.bus.read_byte_data(self.addr,222)
        self.bus.write_word_data(self.addr,126,0x0000)
        return data


    def enable_tx_cdr(self,mask):
        self.bus.write_word_data(self.addr,126,0x0010)
        self.bus.write_byte_data(self.addr,160,mask)
        self.bus.write_byte_data(self.addr,144,0xff)
        self.bus.write_word_data(self.addr,126,0x0000)


    def enable_rx_cdr(self,mask):
        self.bus.write_word_data(self.addr,126,0x0010)
        self.bus.write_byte_data(self.addr,161,mask)
        self.bus.write_byte_data(self.addr,144,0xff)
        self.bus.write_word_data(self.addr,126,0x0000)

    def lane_specific_flags(self):
        self.bus.write_word_data(self.addr,126,0x0011)

        lane_specific_flags_dict = {
            135: "Latched TX Fault Flag For Lane {}",
            136: "Latched TX LOS Flag for lane {}",
            137: "Latched TX CDR LOL Flag for lane {}",
            138: "Latched TX Adaptive Input Eq. Fault for lane {}",
            139: "TX Output Power High Alarm for lane {}",
            140: "TX Output Power Low Alarm for lane {}",
            141: "TX Output Power High Warning for lane {}",
            142: "TX Output Power Low Warning for lane {}",
            143: "TX Bias High Alarm for lane {}",
            144: "TX Bias Low Alarm for lane {}",
            145: "TX Bias High Warning for lane {}",
            146: "TX Bias Low Warning for lane {}",
            147: "Latched RX LOS Flag for lane  {}",
            148: "Latched RX CDR LOL Flag for lane {}",
            149: "RX Input Power High Alarm for lane {}",
            150: "RX Input Power Low Alarm for lane {}",
            151: "RX Input Power High Warning for lane {}",
            152: "RX Input Power Low Warning for lane {}"

        }
        output = []
        for reg in range(135, 153):
            data = self.bus.read_byte_data(self.addr,reg)
            for i in range(8):
                d = data & (1 << i)
                if d != 0:
                    x = lane_specific_flags_dict[reg].format(i + 1)
                    output.append(x)
                else:
                    pass
        self.bus.write_word_data(self.addr,126,0x0000)
        return output

    def rx_power(self):
        self.bus.write_word_data(self.addr, 126, 0x0001)
        check = self.bus.read_byte_data(self.addr, 160)
        c = check & (1 << 2)

        if c == 0:
            print("rx power monitor not implemented")

        else:

            self.bus.write_word_data(self.addr, 126, 0x0011)
            power_values = []

            for MSB_reg in range(186, 202, 2):
                data_MSB = self.bus.read_byte_data(self.addr, MSB_reg)
                LSB_reg = MSB_reg + 1
                data_LSB = self.bus.read_byte_data(self.addr, LSB_reg)

                d = (data_MSB << 8) + (data_LSB)

                power =  d / 10000.
                if power>0:
                    power_values.append(10*log10(power))
                else:
                    power_values.append(-999)
        self.bus.write_word_data(self.addr, 126, 0x0000)

        return power_values


class x2o_base(device):
    def __init__(self):
        self.devices={}

    def configure_temperatures(self,bus,addr,identifier,local,remote,hyst=10,ideality=1.008):
        bus.write_byte_data(addr,0x19,remote,0)
        bus.write_byte_data(addr,0x20,local,0)
        bus.write_byte_data(addr,0x21,hyst,0)
        adjust = self.twos_comp(int(1.008*2088/ideality-2088),8)
        bus.write_byte_data(addr,0x23,adjust)

    def configure_voltages_adc(self,bus,addr,information):
        #first generate mask
        mask=0x0
        for i in information:
            mask=mask|(1<<i['ch'])
        mask=mask^0xff
        bus.write_byte_data(addr,0x0,0x80)
        busy=bus.read_byte_data(addr,0xc) &0x2
        while busy:
            busy = bus.read_byte_data(addr,0xc) &0x2
            time.sleep(10)
        bus.write_byte_data(addr,0x3,mask) #change this to mask
        bus.write_byte_data(addr,0x7,1)
        bus.write_byte_data(addr,0x8,mask)
        bus.write_byte_data(addr,0xb,2)
        for n,info in enumerate(information):
            self.devices[info['name']] = {'voltage':{'bus':bus,'addr':addr,'ch':info['ch'],'factor':info['factor'],'nominal':info['nominal'],'margin':info['margin']}}
            maxV=int(256.0 * info['nominal']*(1.0+info['margin']) / (info['factor'] * 2.56))
            minV=int(256.0 * info['nominal']*(1.0-info['margin']) / (info['factor'] * 2.56))
            bus.write_byte_data(addr,0x2a+2*info['ch'],maxV)
            bus.write_byte_data(addr,0x2a+2*info['ch']+1,minV)
        bus.write_byte_data(addr,0x0,3)

    def validate_rail(self,rail,timeout=0,abort=False,verbose=False):
        if not (rail in self.devices):
            return 0

        info=self.devices[rail]['voltage']
        val = info['bus'].read_word_data(info['addr'],0x20+info['ch'])
        converted = 2.56*val*info['factor']/65536.0
        success = converted>(info['nominal']*(1-info['margin'])) and converted<(info['nominal']*(1+info['margin']))

        time=0;
        while (not success) and (time<timeout):
            val = info['bus'].read_word_data(info['addr'],0x20+info['ch'])
            converted = 2.56*val*info['factor']/65536.0
            success = converted>(info['nominal']*(1-info['margin'])) and converted<(info['nominal']*(1+info['margin']))
            time=time+1
        if verbose:
            print("Rail {0:20}".format(rail)+" V={:2.3f} V0={:2.3f} +-{:2.3f}".format(converted,info['nominal'],info['nominal']*info['margin'])+ " success:{}".format(success))
        if abort & (not success):
            self.power_down_emergency()
        return success


    def validate_shutdown_rail(self,rail,timeout=0,verbose=False):
        if not (rail in self.devices):
            return 0

        info=self.devices[rail]['voltage']
        val = info['bus'].read_word_data(info['addr'],0x20+info['ch'])
        converted = 2.56*val*info['factor']/65536.0
        success = converted<(0.2*info['nominal'])

        t=0;
        while (not success) and (t<timeout):
            val = info['bus'].read_word_data(info['addr'],0x20+info['ch'])
            converted = 2.56*val*info['factor']/65536.0
            success = converted<(0.2*info['nominal'])
            time.sleep(0.01)
            t=t+1
            if verbose:
                print("Rail {0:20}".format(rail)+" V={:2.3f} V0={:2.3f} +-{:2.3f}".format(converted,info['nominal'],info['nominal']*info['margin'])+ " success:{}".format(success))
        return success



    def print_monitor(self,mon):
            st='--------------------------------------------------------------------------------------------------------------\n'
            st=st+"{0:20}".format("Device")+'\tV\t\t'+"I\t\t"+'P\t\t'+'T\n'
            for i in range(len(list(mon.keys()))-1,-1,-1):
                device = list(mon.keys())[i]
                if device in ['KINTEX7','VIRTEXUPLUS','OCTOPUS','OPTICAL_MODULE','slot','optics']:
                    continue
                st =st+ "{0:20}".format(device)
                if 'V' in mon[device].keys():
                    st=st+'\t'+'{:2.3f} V'.format(mon[device]['V'])
                else:
                    st=st+'\t'+'         '

                if 'I' in mon[device].keys():
                    st=st+'\t\t'+'{:+3.2f} A'.format(mon[device]['I'])
                else:
                    st=st+'\t\t'+'          '

                if 'P' in mon[device].keys():
                    st=st+'\t\t'+'{:+3.2f} W'.format(mon[device]['P'])
                else:
                    st=st+'\t\t'+'          '

                if 'T' in mon[device].keys():
                    tstr=[]
                    for t in mon[device]['T']:
                        tstr.append("{:3.1f} C".format(t))

                    st=st+'\t\t'+','.join(tstr)
                st=st+'\n'
            st=st+'--------------------------------------------------------------------------------------------------------------\n'
            for device in ['KINTEX7','VIRTEXUPLUS']:
                if not device in mon.keys():
                    continue
                st =st+ "{0:20}".format(device)
                if 'V' in mon[device].keys():
                    st=st+'\t'+'{:2.3f} V'.format(mon[device]['V'])
                else:
                    st=st+'\t'+'         '

                if 'I' in mon[device].keys():
                    st=st+'\t'+'{:+3.2f} A'.format(mon[device]['I'])
                else:
                    st=st+'\t'+'          '

                if 'P' in mon[device].keys():
                    st=st+'\t'+'{:+3.2f} W'.format(mon[device]['P'])
                else:
                    st=st+'\t'+'          '

                if 'T' in mon[device].keys():
                    tstr=[]
                    for t in mon[device]['T']:
                        tstr.append("{:3.1f} C".format(t))

                    if mon['12V0']['V'] >= int(5.0):
                        if device == 'KINTEX7':
                            st=st+'\t\t'+','.join(tstr)
                        else:
                            st=st+'\t'+','.join(tstr)
                    else:
                        if device == "KINTEX7":
                            st=st+'\t\t'+','.join(tstr)
                        else:
                            st=st+'\t\t'+','.join(tstr)
                st=st+'\n'

            st=st+'--------------------------------------------------------------------------------------------------------------\n'
            for device in ['slot']:
                if not device in mon.keys():
                    continue
                st =st+ "{0:20}".format(device)
                if 'V' in mon[device].keys():
                    st=st+'\t'+'{:2.3f} V'.format(mon[device]['V'])
                else:
                    st=st+'\t'+'         '

                if 'I' in mon[device].keys():
                    st=st+'\t'+'{:+3.2f} A'.format(mon[device]['I'])
                else:
                    st=st+'\t'+'         '

                if 'P' in mon[device].keys():
                    st=st+'\t'+'{:+3.2f} W'.format(mon[device]['P'])
                else:
                    st=st+'\t'+'         '

                if 'T' in mon[device].keys():
                    tstr=[]
                    for t in mon[device]['T']:
                        tstr.append("{:3.1f} C".format(t))
                    st=st+'\t'+','.join(tstr)
                st=st+'\n'

            st=st+'--------------------------------------------------------------------------------------------------------------\n'
            #OPTICS"
            if 'optics' in mon.keys() and len(mon['optics'].keys())>0:
                st=st+'----------------------------------------------OPTICS----------------------------------------------------------\n'
                st =st+ " cage {0:45}\t ".format("Type")+"{0:8}  ".format("V")+"{0:7} ".format("T")+" {0:4} ".format("RX")+" {0:4} ".format("TX")+" {0:5} ".format("RXCDR")+" {0:5} ".format("TXCDR")+" {0:12} ".format("RX Optical Power")+"\n"
                for cage,info in mon['optics'].items():
                    st =st+"{0:3}: ".format(str(cage))+ "{0:45}\t ".format(info['type'])+" {:2.3f} V".format(info['V'])+" {:+2.1f} C ".format(info['T'])+" {0:4} ".format(hex(info['rx_enabled']))+" {0:4} ".format(hex(info['tx_enabled']))+" {0:5} ".format(hex(info['rx_cdr']))+" {0:5} ".format(hex(info['tx_cdr']))+"  "','.join(info['rx_power'])+'\n'
                st=st+'--------------------------------------------------------------------------------------------------------------\n'
            print(st)


class octopus_rev1(x2o_base):
    def __init__(self,i2c_bus):
        super(octopus_rev1,self).__init__()

        self.OCTOPUS_BUS = i2c_bus.busid
        self.i2c1 = i2c_bus
        self.octopus_addr=0x69


        self.north_bus   = octopus_bus(self.i2c1,self.octopus_addr,0)
        self.south_bus   = octopus_bus(self.i2c1,self.octopus_addr,1)
        self.clock_bus   = octopus_bus(self.i2c1,self.octopus_addr,2)
        self.optics_bus  = octopus_bus(self.i2c1,self.octopus_addr,4)

    def configure_ltm4700(self,bus,addr,max_temp):
        #set pulse skipping mode
        for ch in [0,1]:
            bus.write_byte_data(addr,0x0,ch)
            bus.write_byte_data(addr,0xd4,0xc6)
            bus.write_byte_data(addr,0x1,0x80)

    def configure(self):
        self.devices={}
        self.configure_temperatures(self.north_bus,0x4d,'2V7_INTERMEDIATE',90,100,10)
        self.configure_temperatures(self.north_bus,0x48,'0V9_MGTAVCC_VUP_N',90,95,10)
        self.configure_temperatures(self.north_bus,0x49,'0V9_MGTAVCC_VUP_N',90,95,10)
        self.configure_temperatures(self.north_bus,0x4b,'1V2_MGTAVTT_VUP_N',90,95,10)
        self.configure_temperatures(self.north_bus,0x4c,'1V2_MGTAVTT_VUP_N',90,95,10)
        self.configure_temperatures(self.south_bus,0x48,'0V9_MGTAVCC_VUP_S',90,95,10)
        self.configure_temperatures(self.south_bus,0x49,'0V9_MGTAVCC_VUP_S',90,95,10)
        self.configure_temperatures(self.south_bus,0x4b,'1V2_MGTAVTT_VUP_S',90,95,10)
        self.configure_temperatures(self.south_bus,0x4c,'1V2_MGTAVTT_VUP_S',90,95,10)
        self.configure_temperatures(self.south_bus,0x4a,'KINTEX7',85,85,10,1.010)
        self.configure_temperatures(self.north_bus,0x4a,'VIRTEXUPLUS',90,90,10,1.026)
        self.configure_voltages_adc(self.north_bus,0x1d,[{'name':'12V0','ch':0,'nominal':12.0,'factor':7.72,'margin':0.05},
                                                         {'name':'3V3_STANDBY','ch':2,'nominal':3.3,'factor':2.0,'margin':0.1},
                                                         {'name':'3V3_SI5395J','ch':4,'nominal':3.3,'factor':2.0,'margin':0.1},
                                                         {'name':'1V8_SI5395J_XO2','ch':7,'nominal':1.8,'factor':1.0,'margin':0.1}])
        self.configure_voltages_adc(self.north_bus,0x1f,[{'name':'2V5_OSC_NE','ch':0,'nominal':2.5,'factor':2.0,'margin':0.1},
                                                         {'name':'1V8_MGTVCCAUX_VUP_N','ch':1,'nominal':1.8,'factor':1.0,'margin':0.05},
                                                         {'name':'1V2_MGTAVTT_VUP_N','ch':2,'nominal':1.2,'factor':1.0,'margin':0.05},
                                                         {'name':'2V7_INTERMEDIATE','ch':3,'nominal':2.7,'factor':2.0,'margin':0.1},
                                                         {'name':'0V9_MGTAVCC_VUP_N','ch':4,'nominal':0.9,'factor':1.0,'margin':0.05},
                                                         {'name':'2V5_OSC_NW','ch':5,'nominal':2.5,'factor':2.0,'margin':0.1}])
        self.configure_voltages_adc(self.south_bus,0x1d,[{'name':'1V0_VCCINT_K7','ch':0,'nominal':1.0,'factor':1.0,'margin':0.05},
                                                         {'name':'2V5_OSC_K7','ch':1,'nominal':2.5,'factor':2.0,'margin':0.1},
                                                         {'name':'1V2_MGTAVTT_K7','ch':2,'nominal':1.2,'factor':1.0,'margin':0.05},
                                                         {'name':'1V0_MGTAVCC_K7','ch':3,'nominal':1.0,'factor':1.0,'margin':0.05},
#                                                         {'name':'0V675_DDRVTT','ch':4,'nominal':0.675,'factor':1.0,'margin':0.05},
                                                         {'name':'1V35_DDR','ch':5,'nominal':1.35,'factor':1.0,'margin':0.05},
                                                         {'name':'1V8_VCCAUX_K7','ch':6,'nominal':1.8,'factor':1.0,'margin':0.05},
                                                         {'name':'2V5_OSC_SE','ch':7,'nominal':2.5,'factor':2.0,'margin':0.1}])
        self.configure_voltages_adc(self.south_bus,0x1f,[{'name':'1V8_MGTVCCAUX_VUP_S','ch':0,'nominal':1.8,'factor':1.0,'margin':0.05},
                                                         {'name':'0V9_MGTAVCC_VUP_S','ch':1,'nominal':0.9,'factor':1.0,'margin':0.05},
                                                         {'name':'1V2_MGTAVTT_VUP_S','ch':2,'nominal':1.2,'factor':1.0,'margin':0.05},
                                                         {'name':'0V85_VCCINT_VUP','ch':3,'nominal':0.85,'factor':1.0,'margin':0.1},
                                                         {'name':'1V8_VCCAUX_VUP','ch':4,'nominal':1.8,'factor':1.0,'margin':0.05},
                                                         {'name':'2V5_OSC_SW','ch':5,'nominal':2.5,'factor':2.0,'margin':0.2}])
    def clear_interrupts(self):
        #ADCs first
        self.north_bus.read_byte_data(0x1d,0x1)
        self.south_bus.read_byte_data(0x1d,0x1)
        self.north_bus.read_byte_data(0x1f,0x1)
        self.south_bus.read_byte_data(0x1f,0x1)

    def alerts(self):
        return self.i2c1.read_byte_data(self.octopus_addr,0x4)


    def power_up(self,timeout=50,verbose=False):
        alert=0
        self.i2c1.write_byte_data(self.octopus_addr,10,1)
        self.power_down()
        #configure
        self.configure()

        if self.validate_rail('12V0',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('3V3_STANDBY',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,7,0x1)
        if self.validate_rail('2V5_INTERMEDIATE',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,7,0x7)
        if self.validate_rail('1V8_MACHXO2',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('3V3_SI5395J',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,7,0x1f)
        if self.validate_rail('2V5_OSC_NE',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,7,0x3f)
        if self.validate_rail('2V5_OSC_NW',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,7,0x7f)
        if self.validate_rail('2V5_OSC_SE',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,7,0xff)
        if self.validate_rail('2V5_OSC_SW',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,9,0x1)
        if self.validate_rail('1V0_VCCINT_K7',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,9,0x3)
        if self.validate_rail('1V8_VCCAUX_K7',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,9,0x7)
        if self.validate_rail('1V35_DDR',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,9,0xf)
        if self.validate_rail('1V0_MGTAVCC_K7',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,9,0x1f)
        if self.validate_rail('1V2_MGTAVTT_K7',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,8,0x1)
        if self.validate_rail('0V85_VCCINT_VUP',timeout,1,verbose)==0:
            return 0
        self.configure_ltm4700(self.south_bus,0x4d,90)
        self.configure_ltm4700(self.south_bus,0x4e,90)
        self.configure_ltm4700(self.south_bus,0x4f,90)
        if self.validate_rail('0V85_VCCINT_VUP',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,8,0x3)
        if self.validate_rail('1V8_VCCAUX_VUP',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,8,0x7)
        if self.validate_rail('0V9_MGTAVCC_VUP_N',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,8,0xf)
        if self.validate_rail('1V2_MGTAVTT_VUP_N',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,8,0x1f)
        if self.validate_rail('0V9_MGTAVCC_VUP_S',timeout,1,verbose)==0:
            return 0
        self.i2c1.write_byte_data(self.octopus_addr,8,0x3f)
        if self.validate_rail('1V2_MGTAVTT_VUP_S',timeout,1,verbose)==0:
            return 0
        self.clear_interrupts()
        #check alerts
        alert=self.alerts()
        if alert !=0xff:
            self.power_down()
            if verbose:
                print("Power Up Failed with alert code:",alert)
            return
        #enable latches
        self.i2c1.write_byte_data(self.octopus_addr,10,0)


    def jtag_chain(self,chain):
        self.i2c1.write_byte_data(self.octopus_addr,0x0,chain&0x1)

    def power_down_emergency(self):
        self.i2c1.write_byte_data(self.octopus_addr,9,0x0)
        time.sleep(delay)
        self.i2c1.write_byte_data(self.octopus_addr,8,0x0)
        time.sleep(delay)
        self.i2c1.write_byte_data(self.octopus_addr,7,0x0)
        time.sleep(delay)

    def monitor(self,verbose=True):
        data=[]
        #trigger monitoring cycle
        self.i2c1.read_byte_data(self.octopus_addr,142)
        #wait for data
        done=False
        while not done:
            r =self.i2c1.read_byte_data(self.octopus_addr,3)
            done= (r&0x40)==0
        #read monitoring data
        for addr in range(7,143):
            data.append(self.i2c1.read_byte_data(self.octopus_addr,addr))
        mon={}
        board_power=0;

        #convert to dict and print
        mon['0V85_VCCINT_VUP']={'T':[]}

        for i in range(0,12,2):
            w = data[i] | (data[i+1] << 8)
            w = ((r & 0xFF) << 8) | ((r >> 8) & 0xFF)
            mon['0V85_VCCINT_VUP']['T'].append(self.linear11(w))

        devs=['1V2_MGTAVTT_VUP_S','1V2_MGTAVTT_VUP_S','KINTEX7','0V9_MGTAVCC_VUP_S','0V9_MGTAVCC_VUP_S','2V7_INTERMEDIATE','1V2_MGTAVTT_VUP_N','1V2_MGTAVTT_VUP_N','VIRTEXUPLUS','0V9_MGTAVCC_VUP_S','0V9_MGTAVCC_VUP_S']
        for i in range(12,56,4):
            N=int((i-12)/4)
            if not devs[N] in mon.keys():
                mon[devs[N]]={'T':[]}
            l = (data[i+3] << 4) | (data[i+2] >> 4)
            mon[devs[N]]['T'].append(self.twos_comp(l,12)*0.0625)
            r = (data[i+1] << 4) | (data[i+0] >> 4)
            mon[devs[N]]['T'].append(self.twos_comp(r,12)*0.0625)

        devs=['1V2_MGTAVTT_VUP_S','0V85_VCCINT_VUP','1V0_VCCINT_K7','0V9_MGTAVCC_VUP_S','2V7_INTERMEDIATE','1V8_VCCAUX_VUP','1V2_MGTAVTT_VUP_N','0V9_MGTAVCC_VUP_N']
        dividers=[0.01,0.0005,0.01,0.01,0.01,0.01,0.01,0.01]
        vup_power=0
        k7_power=0
        for i in range(56,88,4):
            N=int((i-56)/4)
            if devs[N] in mon.keys():
                mon[devs[N]]['I']=0
                mon[devs[N]]['P']=0
            else:
                mon[devs[N]]={'I':0,'P':0}
            mon[devs[N]]['I'] = self.twos_comp(data[i]|(data[i+1]<<8),16)*0.0000025/dividers[N]
            mon[devs[N]]['P'] = self.twos_comp(data[i+2]|(data[i+3]<<8),16)*0.00125*mon[devs[N]]['I']
            board_power=board_power+mon[devs[N]]['P']
            if 'VUP' in devs[N]:
                vup_power=vup_power+mon[devs[N]]['P']
            if 'K7' in devs[N]:
                k7_power=k7_power+mon[devs[N]]['P']


        devs=['2V5_OSC_SW','1V8_VCCAUX_VUP','0V85_VCCINT_VUP','1V2_MGTAVTT_VUP_S','0V9_MGTAVCC_VUP_S','1V8_MGTVCCAUX_VUP_S','2V5_OSC_SE','1V8_VCCAUX_K7','1V35_DDR','0V675_DDRVTT','1V0_MGTAVCC_K7','1V2_MGTAVTT_K7','2V5_OSC_K7','1V0_VCCINT_K7','2V5_OSC_NW','0V9_MGTAVCC_VUP_N','2V7_INTERMEDIATE','1V2_MGTAVTT_VUP_N','1V8_MGTVCCAUX_VUP_N','2V5_OSC_NE','1V8_SI5395J_XO2','3V3_SI5395J','3V3_STANDBY','12V0']
        factor=[2.0,1.0,1.0,1.0,1.0,1.0,2.0,1.0,1.0,1.0,1.0,1.0,2.0,1.0,2.0,1.0,2.0,1.0,1.0,2.0,1.0,2.0,2.0,7.72]
        for i in range(88,135,2):
            N=int((i-88)/2)
            if not devs[N] in mon.keys():
                mon[devs[N]] = {'V':0}
            else:
                mon[devs[N]]['V'] = 0
            value = data[i] |( data[i+1] << 8)
            mon[devs[N]]['V'] = value * factor[N] * 2.56 / 65536.0


        mon['VIRTEXUPLUS']['P']=vup_power
        mon['KINTEX7']['P']=k7_power
        mon['OCTOPUS'] = {'P':board_power}
        if verbose:
            self.print_monitor(mon)


        return mon


    def load_clock_file(self,script):
        synth =si539x(self.clock_bus,0x68)
        synth.load_config(script)




class octopus_rev2(x2o_base):
    def __init__(self,i2c_bus):
        super(octopus_rev2,self).__init__()

        self.OCTOPUS_BUS = i2c_bus.busid
        self.i2c1 = i2c_bus
        self.octopus_addr=0x69


        self.north_bus   = octopus_bus(self.i2c1,self.octopus_addr,0)
        self.south_bus   = octopus_bus(self.i2c1,self.octopus_addr,1)
        self.clock_bus   = octopus_bus(self.i2c1,self.octopus_addr,2)
        self.optics_bus  = octopus_bus(self.i2c1,self.octopus_addr,4)
        self.lmk =lmk5c33216(self.clock_bus,0x64)


    def configure_ltm4700(self,bus,addr,max_temp):
        #set pulse skipping mode
        for ch in [0,1]:
            bus.write_byte_data(addr,0x0,ch)
            bus.write_byte_data(addr,0xd4,0xc6)
            bus.write_byte_data(addr,0x1,0x80)

    def configure(self):
        self.devices={}
        self.configure_temperatures(self.north_bus,0x4d,'2V7_INTERMEDIATE',90,100,10)
        self.configure_temperatures(self.north_bus,0x48,'0V9_MGTAVCC_VUP_N',90,95,10)
        self.configure_temperatures(self.north_bus,0x49,'0V9_MGTAVCC_VUP_N',90,95,10)
        self.configure_temperatures(self.north_bus,0x4b,'1V2_MGTAVTT_VUP_N',90,95,10)
        self.configure_temperatures(self.north_bus,0x4c,'1V2_MGTAVTT_VUP_N',90,95,10)
        self.configure_temperatures(self.south_bus,0x48,'0V9_MGTAVCC_VUP_S',90,95,10)
        self.configure_temperatures(self.south_bus,0x49,'0V9_MGTAVCC_VUP_S',90,95,10)
        self.configure_temperatures(self.south_bus,0x4b,'1V2_MGTAVTT_VUP_S',90,95,10)
        self.configure_temperatures(self.south_bus,0x4c,'1V2_MGTAVTT_VUP_S',90,95,10)
        self.configure_temperatures(self.north_bus,0x4a,'VIRTEXUPLUS',85,85,10,1.026)
        self.configure_voltages_adc(self.north_bus,0x1d,[{'name':'12V0','ch':0,'nominal':12.0,'factor':7.72,'margin':0.05},
                                                         {'name':'3V3_STANDBY','ch':2,'nominal':3.3,'factor':2.0,'margin':0.1},
                                                         {'name':'1V8_MACHXO2','ch':7,'nominal':1.8,'factor':1.0,'margin':0.1}])
        self.configure_voltages_adc(self.north_bus,0x1f,[{'name':'2V5_OSC_NE','ch':0,'nominal':2.5,'factor':2.0,'margin':0.1},
                                                         {'name':'1V8_MGTVCCAUX_VUP_N','ch':1,'nominal':1.8,'factor':1.0,'margin':0.05},
                                                         {'name':'1V2_MGTAVTT_VUP_N','ch':2,'nominal':1.2,'factor':1.0,'margin':0.05},
                                                         {'name':'3V5_INTERMEDIATE','ch':3,'nominal':3.5,'factor':2.0,'margin':0.1},
                                                         {'name':'0V9_MGTAVCC_VUP_N','ch':4,'nominal':0.9,'factor':1.0,'margin':0.05},
                                                         {'name':'2V5_OSC_NW','ch':5,'nominal':2.5,'factor':2.0,'margin':0.1}])
        self.configure_voltages_adc(self.south_bus,0x1f,[{'name':'1V8_MGTVCCAUX_VUP_S','ch':0,'nominal':1.8,'factor':1.0,'margin':0.05},
                                                         {'name':'0V9_MGTAVCC_VUP_S','ch':1,'nominal':0.9,'factor':1.0,'margin':0.05},
                                                         {'name':'1V2_MGTAVTT_VUP_S','ch':2,'nominal':1.2,'factor':1.0,'margin':0.05},
                                                         {'name':'0V85_VCCINT_VUP','ch':3,'nominal':0.85,'factor':1.0,'margin':0.1},
                                                         {'name':'1V8_VCCAUX_VUP','ch':4,'nominal':1.8,'factor':1.0,'margin':0.05},
                                                         {'name':'2V5_OSC_SW','ch':5,'nominal':2.5,'factor':2.0,'margin':0.2},
                                                         {'name':'2V5_OSC_SE','ch':6,'nominal':2.5,'factor':2.0,'margin':0.2},
                                                         {'name':'3V3_LMK','ch':7,'nominal':3.3,'factor':2.0,'margin':0.2}])
    def clear_interrupts(self):
        #ADCs first
        self.north_bus.read_byte_data(0x1d,0x1)
        self.north_bus.read_byte_data(0x1f,0x1)
        self.south_bus.read_byte_data(0x1f,0x1)

    def alerts(self):
        return self.i2c1.read_byte_data(self.octopus_addr,0x4)

    def single_rail_test(self,rail,timeout=50):
        self.i2c1.write_byte_data(self.octopus_addr,10,1)
        rail_data = {
            '3V5_INTERMEDIATE':{'r':0x7,'v':0x1},
            '1V8_MACHXO2':{'r':0x7,'v':0x3},
            '3V3_LMK':{'r':0x7,'v':0x7},
            '2V5_OSC_NE':{'r':0x7,'v':0x17},
            '2V5_OSC_NW':{'r':0x7,'v':0x37},
            '2V5_OSC_SE':{'r':0x7,'v':0x77},
            '2V5_OSC_SW':{'r':0x7,'v':0xf7},
            '0V85_VCCINT_VUP':{'r':0x8,'v':0x1},
            '1V8_VCCAUX_VUP':{'r':0x8,'v':0x3},
            '0V9_MGTAVCC_VUP_N':{'r':0x8,'v':0x7},
            '1V2_MGTAVTT_VUP_N':{'r':0x8,'v':0xf},
            '0V9_MGTAVCC_VUP_S':{'r':0x8,'v':0x1f},
            '1V2_MGTAVTT_VUP_S':{'r':0x8,'v':0x3f}
        }
        if rail=="0V85_VCCINT_VUP":
            self.configure_ltm4700(self.south_bus,0x4d,90)
            self.configure_ltm4700(self.south_bus,0x4e,90)
            self.configure_ltm4700(self.south_bus,0x4f,90)
        self.i2c1.write_byte_data(self.octopus_addr,rail_data[rail]['r'],rail_data[rail]['v'])
        return self.validate_rail(rail,timeout,1,1)



    def power_down(self,timeout=50,verbose=False):
        success = 0
        self.i2c1.write_byte_data(self.octopus_addr,10,1)
        time.sleep(0.01)
        self.i2c1.write_byte_data(self.octopus_addr,8,0x17)
        time.sleep(0.01)
        self.i2c1.write_byte_data(self.octopus_addr,8,0x3)
        time.sleep(0.01)
        self.i2c1.write_byte_data(self.octopus_addr,8,0x1)
        time.sleep(0.01)
        self.i2c1.write_byte_data(self.octopus_addr,8,0x0)
        time.sleep(0.01)
        self.i2c1.write_byte_data(self.octopus_addr,7,0x0)
        time.sleep(0.01)
        return 1


    def power_up(self,timeout=50,verbose=False):
        alert=0
        #disable safety
        self.i2c1.write_byte_data(self.octopus_addr,10,1)
        self.power_down()
        #configure
        self.configure()

        if self.validate_rail('12V0',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('3V3_STANDBY',timeout,1,verbose)==0:
            return 0

        #Required input power is there so just start
        #Register 7 is peripherals+ MGTVCCAUX that does not need sequencing
        self.i2c1.write_byte_data(self.octopus_addr,7,0xff)
        if self.validate_rail('3V5_INTERMEDIATE',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('1V8_MACHXO2',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('3V3_LMK',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('2V5_OSC_NE',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('2V5_OSC_NW',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('2V5_OSC_SE',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('2V5_OSC_SW',timeout,1,verbose)==0:
            return 0
        #OK Now the FPGA

        #These commands configure the LTM4700 through the internal I2C switch
        #so they cannot be trivially translated toi2cset/get
        self.configure_ltm4700(self.south_bus,0x4d,90)
        self.configure_ltm4700(self.south_bus,0x4e,90)
        self.configure_ltm4700(self.south_bus,0x4f,90)
        #bring up VCCINT
        self.i2c1.write_byte_data(self.octopus_addr,8,0x1)
        time.sleep(0.01)
        #bring up VCCAUX
        self.i2c1.write_byte_data(self.octopus_addr,8,0x3)
        time.sleep(0.01)
        #bring up MGTVCC
        self.i2c1.write_byte_data(self.octopus_addr,8,0x17)
        time.sleep(0.01)
        #bring up MGTVTT
        self.i2c1.write_byte_data(self.octopus_addr,8,0x3f)
        self.clear_interrupts()
        #now validate the rails using the ADC
        if self.validate_rail('0V85_VCCINT_VUP',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('1V8_VCCAUX_VUP',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('0V9_MGTAVCC_VUP_N',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('0V9_MGTAVCC_VUP_S',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('1V2_MGTAVTT_VUP_N',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('1V2_MGTAVTT_VUP_S',timeout,1,verbose)==0:
            return 0

        #check alerts
        alert=self.alerts()
        if alert !=0xff:
            self.power_down()
            if verbose:
                print("Power Up Failed with alert code:",alert)
            return
        #enable latches
        self.i2c1.write_byte_data(self.octopus_addr,10,0)


    def jtag_chain(self,chain):
        self.i2c1.write_byte_data(self.octopus_addr,0x0,chain&0x1)

    def power_down_emergency(self):
        self.i2c1.write_byte_data(self.octopus_addr,9,0x0)
        self.i2c1.write_byte_data(self.octopus_addr,8,0x0)
        self.i2c1.write_byte_data(self.octopus_addr,7,0x0)

    def monitor(self,verbose=True):
        data=[]
        #trigger monitoring cycle
        self.i2c1.read_byte_data(self.octopus_addr,120)
        #wait for data
        done=False
        while not done:
            r =self.i2c1.read_byte_data(self.octopus_addr,3)
            done= (r&0x40)==0
        #read monitoring data
        for addr in range(7,121):
            data.append(self.i2c1.read_byte_data(self.octopus_addr,addr))
        mon={}
        board_power=0;

        #convert to dict and print
        mon['0V85_VCCINT_VUP']={'T':[]}

        for i in range(0,12,2):
            w = data[i] | (data[i+1] << 8)
            w = ((r & 0xFF) << 8) | ((r >> 8) & 0xFF)
            mon['0V85_VCCINT_VUP']['T'].append(self.linear11(w))

        devs=['1V2_MGTAVTT_VUP_S','1V2_MGTAVTT_VUP_S','0V9_MGTAVCC_VUP_S','0V9_MGTAVCC_VUP_S','3V5_INTERMEDIATE','1V2_MGTAVTT_VUP_N','1V2_MGTAVTT_VUP_N','VIRTEXUPLUS','0V9_MGTAVCC_VUP_S','0V9_MGTAVCC_VUP_S']
        for i in range(12,52,4):
            N=int((i-12)/4)
            if not devs[N] in mon.keys():
                mon[devs[N]]={'T':[]}
            l = (data[i+3] << 4) | (data[i+2] >> 4)
            mon[devs[N]]['T'].append(self.twos_comp(l,12)*0.0625)
            r = (data[i+1] << 4) | (data[i+0] >> 4)
            mon[devs[N]]['T'].append(self.twos_comp(r,12)*0.0625)

        devs=['1V2_MGTAVTT_VUP_S','0V85_VCCINT_VUP','0V9_MGTAVCC_VUP_S','3V5_INTERMEDIATE','1V8_VCCAUX_VUP','1V2_MGTAVTT_VUP_N','0V9_MGTAVCC_VUP_N']
        dividers=[0.01,0.0005,0.01,0.01,0.01,0.01,0.01,0.01]
        vup_power=0
        for i in range(52,80,4):
            N=int((i-52)/4)
            if devs[N] in mon.keys():
                mon[devs[N]]['I']=0
                mon[devs[N]]['P']=0
            else:
                mon[devs[N]]={'I':0,'P':0}
            mon[devs[N]]['I'] = self.twos_comp(data[i]|(data[i+1]<<8),16)*0.0000025/dividers[N]
            mon[devs[N]]['P'] = self.twos_comp(data[i+2]|(data[i+3]<<8),16)*0.00125*mon[devs[N]]['I']
            board_power=board_power+mon[devs[N]]['P']
            if 'VUP' in devs[N]:
                vup_power=vup_power+mon[devs[N]]['P']

        devs=['3V3_LMK','2V5_OSC_SE','2V5_OSC_SW','1V8_VCCAUX_VUP','0V85_VCCINT_VUP','1V2_MGTAVTT_VUP_S','0V9_MGTAVCC_VUP_S','1V8_MGTVCCAUX_VUP_S','2V5_OSC_NW','0V9_MGTAVCC_VUP_N','3V5_INTERMEDIATE','1V2_MGTAVTT_VUP_N','1V8_MGTVCCAUX_VUP_N','2V5_OSC_NE','1V8_MACHXO2','3V3_STANDBY','12V0']

        factor=[2.0,2.0,2.0,1.0,1.0,1.0,1.0,1.0,2.0,1.0,2.0,1.0,1.0,2.0,1.0,2.0,7.722]
        for i in range(80,114,2):
            N=int((i-80)/2)
            if not devs[N] in mon.keys():
                mon[devs[N]] = {'V':0}
            else:
                mon[devs[N]]['V'] = 0
            value = data[i] |( data[i+1] << 8)
            mon[devs[N]]['V'] = value * factor[N] * 2.56 / 65536.0


        mon['VIRTEXUPLUS']['P']=vup_power
        mon['OCTOPUS'] = {'P':board_power}
        if verbose:
            self.print_monitor(mon)


        return mon

    def load_clock_file(self,script):
        self.lmk.load_config(script)




class qsfp_module(x2o_base):
    def __init__(self, i2c_bus = 3, delay = 0.00, revision = 3):
        self.i2c_bus = i2c_bus
        self.i2c = bus(self.i2c_bus, delay)
        self.devices={}
        self.revision = revision
        if revision == 2:
            self.exp_addrs = [0x10, 0x12]
            self.num_cages = 30

            # this map defines the value of the 3 bytes to be sent to I2C expansion chips A and B to select a specific QSFP module
            # When viewing the front panel, the cages are numbered from left to right, and top to bottom (like reading text):
            # 0  |  1
            # 2  |  3
            # 4  |  5
            # .. | ..
            # 28 | 29
            self.map_qsfp_exp_addr = [
                [[0xff, 0xff, 0x7f], [0xff, 0xff, 0xff]], # Cage 0
                [[0xff, 0xff, 0xbf], [0xff, 0xff, 0xff]], # Cage 1
                [[0xff, 0xff, 0xef], [0xff, 0xff, 0xff]], # Cage 2
                [[0xff, 0xff, 0xf7], [0xff, 0xff, 0xff]], # Cage 3
                [[0xff, 0xff, 0xfb], [0xff, 0xff, 0xff]], # Cage 4
                [[0xff, 0xff, 0xfd], [0xff, 0xff, 0xff]], # Cage 5
                [[0xff, 0x7f, 0xff], [0xff, 0xff, 0xff]], # Cage 6
                [[0xff, 0xbf, 0xff], [0xff, 0xff, 0xff]], # Cage 7
                [[0xff, 0xdf, 0xff], [0xff, 0xff, 0xff]], # Cage 8
                [[0xff, 0xef, 0xff], [0xff, 0xff, 0xff]], # Cage 9
                [[0xff, 0xfb, 0xff], [0xff, 0xff, 0xff]], # Cage 10
                [[0xff, 0xfd, 0xff], [0xff, 0xff, 0xff]], # Cage 11
                [[0xff, 0xff, 0xff], [0xfe, 0xff, 0xff]], # Cage 12
                [[0xff, 0xff, 0xff], [0xfd, 0xff, 0xff]], # Cage 13
                [[0xff, 0xff, 0xff], [0xfb, 0xff, 0xff]], # Cage 14
                [[0xff, 0xff, 0xff], [0xf7, 0xff, 0xff]], # Cage 15
                [[0xff, 0xff, 0xff], [0xef, 0xff, 0xff]], # Cage 16
                [[0xff, 0xff, 0xff], [0xdf, 0xff, 0xff]], # Cage 17
                [[0xff, 0xff, 0xff], [0xbf, 0xff, 0xff]], # Cage 18
                [[0xff, 0xff, 0xff], [0x7f, 0xff, 0xff]], # Cage 19
                [[0xff, 0xff, 0xff], [0xff, 0xfe, 0xff]], # Cage 20
                [[0xff, 0xff, 0xff], [0xff, 0xfd, 0xff]], # Cage 21
                [[0xff, 0xff, 0xff], [0xff, 0xfb, 0xff]], # Cage 22
                [[0xff, 0xff, 0xff], [0xff, 0xf7, 0xff]], # Cage 23
                [[0xff, 0xff, 0xff], [0xff, 0xef, 0xff]], # Cage 24
                [[0xff, 0xff, 0xff], [0xff, 0xdf, 0xff]], # Cage 25
                [[0xff, 0xff, 0xff], [0xff, 0xbf, 0xff]], # Cage 26
                [[0xff, 0xff, 0xff], [0xff, 0x7f, 0xff]], # Cage 27
                [[0xff, 0xff, 0xff], [0xff, 0xff, 0xfe]], # Cage 28
                [[0xff, 0xff, 0xff], [0xff, 0xff, 0xfd]], # Cage 29
            ]

        elif revision == 3:
            self.exp_addrs = [0x44, 0x41]
            self.num_cages = 30

            # this map defines the chip ID and address that has to be set to 0 in order to select a specific QSFP module
            # When viewing the front panel, the cages are numbered from left to right, and top to bottom (like reading text):
            # 0  |  1
            # 2  |  3
            # 4  |  5
            # .. | ..
            # 28 | 29
            self.map_qsfp_exp_addr = [
                [1, 0x24], # Cage 0
                [1, 0x3e], # Cage 1
                [1, 0x3d], # Cage 2
                [1, 0x3b], # Cage 3
                [1, 0x39], # Cage 4
                [1, 0x36], # Cage 5
                [0, 0x29], # Cage 6
                [0, 0x2b], # Cage 7
                [0, 0x30], # Cage 8
                [0, 0x32], # Cage 9
                [0, 0x38], # Cage 10
                [0, 0x3a], # Cage 11
                [0, 0x3c], # Cage 12
                [0, 0x3d], # Cage 13
                [0, 0x3f], # Cage 14
                [1, 0x3f], # Cage 15
                [1, 0x26], # Cage 16
                [1, 0x27], # Cage 17
                [1, 0x3a], # Cage 18
                [1, 0x38], # Cage 19
                [1, 0x35], # Cage 20
                [0, 0x2e], # Cage 21
                [0, 0x2f], # Cage 22
                [0, 0x31], # Cage 23
                [0, 0x33], # Cage 24
                [0, 0x39], # Cage 25
                [0, 0x3b], # Cage 26
                [0, 0x27], # Cage 27
                [0, 0x25], # Cage 28
                [0, 0x24], # Cage 29
            ]

        else:
            raise Exception("Unsupported QSFP module revision %d" % revision)

        self.check_map()

    def configure(self,tmpConf,voltageConf):
        if self.revision == 3:
            #configure the outputs on the GPIO chips
            self.i2c.write_byte_data(0x44, 0x9, 0x65)
            self.i2c.write_byte_data(0x44, 0xa, 0x66)
            self.i2c.write_byte_data(0x44, 0xb, 0x5a)
            self.i2c.write_byte_data(0x44, 0xc, 0x55)
            self.i2c.write_byte_data(0x44, 0xd, 0xaa)
            self.i2c.write_byte_data(0x44, 0xe, 0x55)
            self.i2c.write_byte_data(0x44, 0xf, 0x65)

            self.i2c.write_byte_data(0x41, 0x9, 0x59)
            self.i2c.write_byte_data(0x41, 0xa, 0xaa)
            self.i2c.write_byte_data(0x41, 0xb, 0xaa)
            self.i2c.write_byte_data(0x41, 0xc, 0xaa)
            self.i2c.write_byte_data(0x41, 0xd, 0x96)
            self.i2c.write_byte_data(0x41, 0xe, 0x55)
            self.i2c.write_byte_data(0x41, 0xf, 0x56)

            # set all outputs high and enable the chips
            for chip in range(2):
                self.i2c.write_byte_data(self.exp_addrs[chip], 0x44, 0xff)
                self.i2c.write_byte_data(self.exp_addrs[chip], 0x4c, 0xff)
                self.i2c.write_byte_data(self.exp_addrs[chip], 0x54, 0xff)
                self.i2c.write_byte_data(self.exp_addrs[chip], 0x5c, 0xff)
                self.i2c.write_byte_data(self.exp_addrs[chip], 0x4, 0x1)

    # checks the qsfp address map for duplicates
    def check_map(self):
        if self.revision == 2:
            map_good = True
            for i in range(len(self.map_qsfp_exp_addr)):
                check_addr = str(self.map_qsfp_exp_addr[i])
                for j in range(len(self.map_qsfp_exp_addr)):
                    if j == i:
                        continue
                    addr = str(self.map_qsfp_exp_addr[j])
                    if addr == check_addr:
                        print("WARNING: address of cage %d is equal to the address of cage %d = %s" % (i, j, addr))
                        map_good = False

            return map_good
        elif self.revision ==3:
            return True
        else:
            return False

    def select_cage(self, cage):
        if self.revision == 2:
            exp_reg_bytes = self.map_qsfp_exp_addr[cage]
            for chip in range(2):
                self.i2c.write_block_data(self.exp_addrs[chip], exp_reg_bytes[chip][0], [exp_reg_bytes[chip][1], exp_reg_bytes[chip][2]])
        if self.revision == 3:
            exp_set = self.map_qsfp_exp_addr[cage]
            # reset everything
            for chip in range(2):
                self.i2c.write_byte_data(self.exp_addrs[chip], 0x44, 0xff)
                self.i2c.write_byte_data(self.exp_addrs[chip], 0x4c, 0xff)
                self.i2c.write_byte_data(self.exp_addrs[chip], 0x54, 0xff)
                self.i2c.write_byte_data(self.exp_addrs[chip], 0x5c, 0xff)
            # select the cage
            self.i2c.write_byte_data(self.exp_addrs[exp_set[0]], exp_set[1], 0)

    # returns a bitmask where 1 indicates that the module is NOT present
    def optics_presence(self):
        mask = 0
        ver = self.i2c.verbose
        self.i2c.verbose = False
        for cage in range(self.num_cages):
            self.select_cage(cage)
            res = self.i2c.read_byte_data(0x50, 0)
            # print("presence test cage %d: %d" % (cage, res))
            if res == -1:
                mask = mask | (1 << cage)
        self.i2c.verbose = ver
        # print("optics presence returning 0x%x" % mask)
        return mask

    #Michalis This needs small modifications (optics bus)
    def autodetect_optics(self,timeout=0.0,verbose=False):
        if verbose:
            print("Autodetecting Optics")
            print("Waiting for 2 s for optics to start")
        time.sleep(timeout)
        mask = self.optics_presence()
        self.devices['optics']={}
        modules=[]
        num_cages = self.num_cages
        for i in range(0,num_cages):
            if mask &(1<<i):
                continue
            self.select_cage(i)
            pluggable =optical_transceiver(self.i2c,0x50,i,self.select_cage)
            pluggable.select()
            identifier=pluggable.id()
            if verbose:
                print("Cage {0:2}:".format(i)+pluggable.identifier())
            if identifier in [12,13,17]: #QSFP/#QSFP+/QSFP28
                self.devices['optics'][i] =qsfp(self.i2c,0x50,i,self.select_cage)
            if identifier==24 and self.optical_add_on_ver == 0: #QSFP-DD
                version = self.i2c.read_byte_data(0x50,1)
                if version>=0x40:
                    self.devices['optics'][i] =qsfpdd_v4(self.i2c,0x50,i,self.select_cage)
                else:
                    self.devices['optics'][i] =qsfpdd_v2(self.i2c,0x50,i,self.select_cage)
        self.optics = device_group(modules)
        self.select_cage(-1)
    #Michalis This needs small modifications (optics bus)

    def command(self,cages,func,*args):
        if cages=='all':
            cages=[]
            c=self.optics_presence()
            for i in range(0,15):
                if (1<<i) & c==0:
                    cages.append(i)
        r={}
        for c in cages:
            if c in self.devices['optics'].keys() :
                opt = self.devices['optics'][c]
                opt.select()
                if hasattr(opt,func):
                    r[c]=getattr(opt,func)(*args)
                else:
                    print("Function {} not implemented".format(func))
            else:
                print("Cage {} not found. Did you run optics detection".format(c))
        return r



class qsfpdd_module(x2o_base):
    def __init__(self, i2c,address,bus):
        self.optical_slave_bus  = octopus_bus(i2c,address,bus)
        self.optics_bus  = octopus_bus(i2c,address,4)
        self.optical_addr=0x42
        self.optical_bus_0 = optical_bus(self.optical_slave_bus,self.optical_addr,0x0)
        self.optical_bus_1 = optical_bus(self.optical_slave_bus,self.optical_addr,0x1)
        self.devices={}

    def configure(self,tmpConf,voltageConf):
        tmpConf(self.optical_bus_1,0x48,'3V3_OPTICAL_G0',90,95,10)
        tmpConf(self.optical_bus_1,0x49,'3V3_OPTICAL_G1',90,95,10)
        tmpConf(self.optical_bus_1,0x4a,'3V3_OPTICAL_G2',90,95,10)
        tmpConf(self.optical_bus_0,0x48,'3V3_OPTICAL_G3',90,95,10)
        tmpConf(self.optical_bus_0,0x49,'3V3_OPTICAL_G4',90,95,10)
        voltageConf(self.optical_bus_0,0x1d,[  {'name':'12V0_OPTICAL','ch':1,'nominal':12.0,'factor':11,'margin':0.2},
                                                               {'name':'3V3_OPTICAL_G0','ch':2,'nominal':3.3,'factor':11,'margin':0.1},
                                                               {'name':'3V3_OPTICAL_G1','ch':3,'nominal':3.3,'factor':11,'margin':0.1},
                                                               {'name':'3V3_OPTICAL_G2','ch':4,'nominal':3.3,'factor':11,'margin':0.1},
                                                               {'name':'3V3_OPTICAL_G3','ch':5,'nominal':3.3,'factor':11,'margin':0.1},
                                                               {'name':'3V3_OPTICAL_G4','ch':6,'nominal':3.3,'factor':11,'margin':0.1},
                                                               {'name':'3V3_OPTICAL_STBY','ch':7,'nominal':3.3,'factor':11,'margin':0.1}])



    # returns a bitmask where 1 indicates that the module is NOT present
    def optics_presence(self):
        msb=self.optical_slave_bus.read_byte_data(self.optical_addr,5)
        lsb=self.optical_slave_bus.read_byte_data(self.optical_addr,4)
        return (msb<<8)|lsb

    def select_cage(self,cage):
        if cage == -1:
            self.optical_slave_bus.write_byte_data(self.optical_addr,13,0xff)
            self.optical_slave_bus.write_byte_data(self.optical_addr,14,0xff)
        else:
            i = 1 << cage
            i ^= 0x7FFF
            self.optical_slave_bus.write_byte_data(self.optical_addr,13,0xff & i)
            self.optical_slave_bus.write_byte_data(self.optical_addr,14,0xff &(i>>8))

    def reset_cage(self,cage):
        if cage == -1:
            self.optical_slave_bus.write_byte_data(self.optical_addr,9,0x00)
            self.optical_slave_bus.write_byte_data(self.optical_addr,10,0x00)
            time.sleep(0.5)
            self.optical_slave_bus.write_byte_data(self.optical_addr,9,0xff)
            self.optical_slave_bus.write_byte_data(self.optical_addr,10,0xff)

        else:
            i = 1 << cage
            i ^=0x7fff
            self.optical_slave_bus.write_byte_data(self.optical_addr,9,i)
            self.optical_slave_bus.write_byte_data(self.optical_addr,10,(i>>8))
            time.sleep(0.5)
            self.optical_slave_bus.write_byte_data(self.optical_addr,9,0xff)
            self.optical_slave_bus.write_byte_data(self.optical_addr,10,0xff)


    def alerts(self):
        return self.optical_slave_bus.read_byte_data(self.optical_addr,0x3)

    def command(self,cages,func,*args):
        if cages=='all':
            cages=[]
            c=self.optics_presence()
            for i in range(0,15):
                if (1<<i) & c==0:
                    cages.append(i)
        r={}
        for c in cages:
            if c in self.devices['optics'].keys() :
                opt = self.devices['optics'][c]
                opt.select()
                if hasattr(opt,func):
                    r[c]=getattr(opt,func)(*args)
                else:
                    print("Function {} not implemented".format(func))
            else:
                print("Cage {} not found. Did you run optics detection".format(c))
        return r

    def autodetect_optics(self,timeout=0.0,verbose=False):
        if verbose:
            print("Autodetecting Optics")
            print("Waiting for 2 s for optics to start")
        time.sleep(timeout)
        mask = self.optics_presence()
        self.devices['optics']={}
        modules=[]
        num_cages = 15
        for i in range(0,num_cages):
            if mask &(1<<i):
                continue
            self.select_cage(i)
            pluggable =optical_transceiver(self.optics_bus,0x50,i,self.select_cage)
            pluggable.select()
            identifier=pluggable.id()
            if verbose:
                print("Cage {0:2}:".format(i)+pluggable.identifier())
            if identifier in [12,13,17]: #QSFP/#QSFP+/QSFP28
                self.devices['optics'][i] =qsfp(self.optics_bus,0x50,i,self.select_cage)
            if identifier==24:#QSFP-DD
                version = self.optics_bus.read_byte_data(0x50,1)
                if version>=0x40:
                    self.devices['optics'][i] =qsfpdd_v4(self.optics_bus,0x50,i,self.select_cage)
                else:
                    self.devices['optics'][i] =qsfpdd_v2(self.optics_bus,0x50,i,self.select_cage)
        self.optics = device_group(modules)
        self.select_cage(-1)

    def power_up(self,timeout=50,verbose=False):
        alert=0
        self.optical_slave_bus.write_byte_data(self.optical_addr,8,0x1)
        if self.validate_rail('12V0_OPTICAL',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('3V3_OPTICAL_STBY',timeout,1,verbose)==0:
            return 0
        self.optical_slave_bus.write_byte_data(self.optical_addr,7,0x1f)
        if self.validate_rail('3V3_OPTICAL_G0',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('3V3_OPTICAL_G1',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('3V3_OPTICAL_G2',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('3V3_OPTICAL_G3',timeout,1,verbose)==0:
            return 0
        if self.validate_rail('3V3_OPTICAL_G4',timeout,1,verbose)==0:
            return 0
        self.clear_interrupts()
        #check alerts
        alert=self.alerts()
        if alert !=0xff:
            self.power_down(True)
            if verbose:
                print("Power Up Failed on Optical Module with alert code:",alert)
            return
        #enable latches
        self.optical_slave_bus.write_byte_data(self.optical_addr,8,0x0)
        #initialize optics
        self.select_cage(-1)
        #set LPMode to 0: Hardware Control of optics
        self.optical_slave_bus.write_byte_data(self.optical_addr,11,0x0)
        self.optical_slave_bus.write_byte_data(self.optical_addr,12,0x0)
        #reset optics
        self.optical_slave_bus.write_byte_data(self.optical_addr,9,0x0)
        self.optical_slave_bus.write_byte_data(self.optical_addr,10,0x0)
        time.sleep(0.1)
        self.optical_slave_bus.write_byte_data(self.optical_addr,9,0xff)
        self.optical_slave_bus.write_byte_data(self.optical_addr,10,0xff)
        #disco mode
        for i in range(0,15):
            self.set_led(i,3,3,3)
        self.autodetect_optics(2,verbose)
        return alert

    def power_down(self):
        self.optical_slave_bus.write_byte_data(self.optical_addr,7,0x0)

    def handle_switch(self):
        return self.optical_slave_bus.read_byte_data(self.optical_addr,6) &0x4
    def set_led(self,cage,red_mode,green_mode,blue_mode):
        mode = ((blue_mode&3) << 4) | ((green_mode&3) << 2) | (red_mode&3)
        self.optical_slave_bus.write_byte_data(self.optical_addr,15+cage,mode)

    def monitor(self,verbose=True):

        optical_data=[]

        #trigger monitoring cycle
        self.optical_slave_bus.read_byte_data(self.optical_addr,62)
        #wait for data
        done=False
        while not done:
            r=self.optical_slave_bus.read_byte_data(self.optical_addr,6)
            done= (r&0x2)==0
            #read monitoring data
        for addr in range(7,63):
            optical_data.append(self.optical_slave_bus.read_byte_data(self.optical_addr,addr))

        mon={}
        board_power=0;
        devs=['3V3_OPTICAL_G4','3V3_OPTICAL_G3','3V3_OPTICAL_G2','3V3_OPTICAL_G1','3V3_OPTICAL_G0']
        for i in range(0,20,4):
            N=int(i/4)
            if not devs[N] in mon.keys():
                mon[devs[N]]={'T':[]}
            l = (optical_data[i+3] << 4) | (optical_data[i+2] >> 4)
            mon[devs[N]]['T'].append(self.twos_comp(l,12)*0.0625)
            r = (optical_data[i+1] << 4) | (optical_data[i+0] >> 4)
            mon[devs[N]]['T'].append(self.twos_comp(r,12)*0.0625)



        for i in range(20,40,4):
            N=int((i-20)/4)
            if devs[N] in mon.keys():
                mon[devs[N]]['I']=0
                mon[devs[N]]['P']=0
            else:
                mon[devs[N]]={'I':0,'P':0}
            mon[devs[N]]['I'] = self.twos_comp(optical_data[i]|(optical_data[i+1]<<8),16)*0.0000025/0.01
            mon[devs[N]]['P'] = self.twos_comp(optical_data[i+2]|(optical_data[i+3]<<8),16)*0.00125*mon[devs[N]]['I']
            board_power=board_power+mon[devs[N]]['P']
        mon['OPTICAL MODULE']={'P':board_power}
        devs=['3V3_OPTICAL_STBY','3V3_OPTICAL_G4','3V3_OPTICAL_G3','3V3_OPTICAL_G2','3V3_OPTICAL_G1','3V3_OPTICAL_G0','12V0_OPTICAL']
        for i in range(40,54,2):
            N=int((i-40)/2)
            if not devs[N] in mon.keys():
                mon[devs[N]] = {'V':0}
            else:
                mon[devs[N]]['V'] = 0
            value = optical_data[i] |( optical_data[i+1] << 8)
            mon[devs[N]]['V'] = value * 11.0 * 2.56 / 65536.0


        if 'optics' in self.devices.keys() and len(self.devices['optics'].keys())>0:
            mon['optics']={}
            for cage,pluggable in self.devices['optics'].items():
                pluggable.select()
                mon['optics'][cage]={'type':pluggable.identifier(),'V':pluggable.voltage(),'T':pluggable.temperature(),'tx_enabled':pluggable.tx_enabled(),'rx_enabled':pluggable.rx_enabled(),'rx_cdr':pluggable.rx_cdr_enabled(),'tx_cdr':pluggable.tx_cdr_enabled(),'rx_power':[]}
                po = pluggable.rx_power()
                for p in po:
                    mon['optics'][cage]['rx_power'].append(str(p)+ " dBm")
        if verbose:
            self.print_monitor(mon)
        return mon
