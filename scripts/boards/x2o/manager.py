from dumbo.i2c import bus,device,device_group,optical_bus,octopus_bus,si539x,device_group,tmp461,ina226,adc128d818,tca9539,optical_transceiver,qsfp,qsfpdd_v2,qsfpdd_v4,ltm4700,qsfp_module
from dumbo.fabric import slr
from dumbo.tcds2 import tcds2
import dumbo.dma as dma
from dumbo.bitstream import bscan
from  dumbo.pydma import pydma
import dumbo.semaphore as semaphore
import os
import time
import threading
from enum import Enum
from board.mappings import *


##REMOVE THIS FOR NEW FIRMWARE
#from dumbo.i2c import octopus_bus_old as octopus_bus


def twos_comp(val, bits):
    if (val & (1 << (bits - 1))) != 0: # if sign bit is set e.g., 8bit: 128-255
        val = val - (1 << bits)        # compute negative value
    return val
def linear11(word):
    Y = 0x7ff & word
    Y=twos_comp(Y,11)
    N = (0xf800 & word)>>11
    N=twos_comp(N,5)
    return Y*pow(2,N)

class peripheraltree(object):
    # optical_add_on_ver refers to optical module version, where version 0 refers to UCLA QSFP-DD module, and version 2 refers to UF QSFP module revision 2 (with 30 cages)
    def __init__(self,delay=0.00, octopus_add_on = True, optical_add_on = True, optical_add_on_ver = 0, i2c_bus = 2, optics_i2c_bus = 3):
        self.OCTOPUS_BUS = i2c_bus
        self.i2c1 = bus(self.OCTOPUS_BUS,delay)
        semaphore.create(i2c_bus)
        self.optics_sem = i2c_bus
        self.octopus_addr=0x69
        self.optical_addr=0x42
        self.delay=delay
        self.octopus_add_on = octopus_add_on
        self.optical_add_on = optical_add_on
        self.optical_add_on_ver = optical_add_on_ver

        #generate virtual buses on octopus
        if self.octopus_add_on:
            self.north_bus   = octopus_bus(self.i2c1,self.octopus_addr,0)
            self.south_bus   = octopus_bus(self.i2c1,self.octopus_addr,1)
            self.clock_bus   = octopus_bus(self.i2c1,self.octopus_addr,2)
            self.optics_bus   = octopus_bus(self.i2c1,self.octopus_addr,4)

        ###generate virtual buses on QSFP-DD Optical module
        if self.optical_add_on and self.optical_add_on_ver == 0:
            self.optical_slave_bus  = octopus_bus(self.i2c1,self.octopus_addr,3)
            self.optical_bus_0 = optical_bus(self.optical_slave_bus,self.optical_addr,0x0)
            self.optical_bus_1 = optical_bus(self.optical_slave_bus,self.optical_addr,0x1)

        if self.optical_add_on and self.optical_add_on_ver > 0:
            self.qsfp_module = qsfp_module(optics_i2c_bus, 0.00, self.optical_add_on_ver)
            self.optics_bus = self.qsfp_module.i2c
            self.optics_sem = optics_i2c_bus
            semaphore.create(self.optics_sem)

        self.devices={}
        self.devices['optics']={}

    def setup_power_module_retimer(self):
        i2c = bus(4,self.delay)
        i2c.write_byte_data(0x18,0xff,0x04)
        i2c.write_byte_data(0x18,0x60,0x4d)
        i2c.write_byte_data(0x18,0x61,0xb3)
        i2c.write_byte_data(0x18,0x62,0x4d)
        i2c.write_byte_data(0x18,0x63,0xb3)
        i2c.write_byte_data(0x18,0x64,0xdd)

    def configure_temperatures(self,bus,addr,identifier,local,remote,hyst=10,ideality=1.008):
        bus.write_byte_data(addr,0x19,remote,0)
        bus.write_byte_data(addr,0x20,local,0)
        bus.write_byte_data(addr,0x21,hyst,0)
        adjust = twos_comp(int(1.008*2088/ideality-2088),8)
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


    def configure_ltm4700(self,bus,addr,max_temp):
        #set pulse skipping mode
        for ch in [0,1]:
            bus.write_byte_data(addr,0x0,ch)
            bus.write_byte_data(addr,0xd4,0xc6)
            bus.write_byte_data(addr,0x1,0x80)

    def configure(self):
        self.devices={}
        if self.octopus_add_on:
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
            self.configure_voltages_adc(self.north_bus,0x1d,[{'name':'12V0','ch':0,'nominal':12.0,'factor':7.72,'margin':0.303030303030303030303030303030303030303030303030303030303030},
                                                             {'name':'3V3_STANDBY','ch':2,'nominal':3.3,'factor':2.0,'margin':0.1},
                                                             {'name':'3V3_SI5395J','ch':4,'nominal':3.3,'factor':2.0,'margin':0.1},
                                                             {'name':'1V8_SI5395J_XO2','ch':7,'nominal':1.8,'factor':1.0,'margin':0.1}])
            self.configure_voltages_adc(self.north_bus,0x1f,[{'name':'2V5_OSC_NE','ch':0,'nominal':2.5,'factor':2.0,'margin':0.1},
                                                             {'name':'1V8_MGTVCCAUX_VUP_N','ch':1,'nominal':1.8,'factor':1.0,'margin':0.05},
                                                             {'name':'1V2_MGTAVTT_VUP_N','ch':2,'nominal':1.2,'factor':1.0,'margin':0.05},
                                                             {'name':'2V7_INTERMEDIATE','ch':3,'nominal':2.7,'factor':2.0,'margin':0.1},
                                                             {'name':'0V9_MGTAVCC_VUP_N','ch':4,'nominal':0.9,'factor':1.0,'margin':0.05},
                                                             {'name':'2V5_OSC_NW','ch':5,'nominal':2.5,'factor':2.0,'margin':0.1}])
#            self.configure_voltages_adc(self.south_bus,0x1d,[{'name':'1V0_VCCINT_K7','ch':0,'nominal':1.0,'factor':1.0,'margin':0.05},
#                                                             {'name':'2V5_OSC_K7','ch':1,'nominal':2.5,'factor':2.0,'margin':0.1},
#                                                             {'name':'1V2_MGTAVTT_K7','ch':2,'nominal':1.2,'factor':1.0,'margin':0.05},
#                                                             {'name':'1V0_MGTAVCC_K7','ch':3,'nominal':1.0,'factor':1.0,'margin':0.05},
#                                                             {'name':'0V675_DDRVTT','ch':4,'nominal':0.675,'factor':1.0,'margin':0.05},
#                                                             {'name':'1V35_DDR','ch':5,'nominal':1.35,'factor':1.0,'margin':0.05},
#                                                             {'name':'1V8_VCCAUX_K7','ch':6,'nominal':1.8,'factor':1.0,'margin':0.05},
#                                                             {'name':'2V5_OSC_SE','ch':7,'nominal':2.5,'factor':2.0,'margin':0.1}])
            self.configure_voltages_adc(self.south_bus,0x1f,[{'name':'1V8_MGTVCCAUX_VUP_S','ch':0,'nominal':1.8,'factor':1.0,'margin':0.05},
                                                             {'name':'0V9_MGTAVCC_VUP_S','ch':1,'nominal':0.9,'factor':1.0,'margin':0.05},
                                                             {'name':'1V2_MGTAVTT_VUP_S','ch':2,'nominal':1.2,'factor':1.0,'margin':0.05},
                                                             {'name':'0V85_VCCINT_VUP','ch':3,'nominal':0.85,'factor':1.0,'margin':0.1},
                                                             {'name':'1V8_VCCAUX_VUP','ch':4,'nominal':1.8,'factor':1.0,'margin':0.05},
                                                             {'name':'2V5_OSC_SW','ch':5,'nominal':2.5,'factor':2.0,'margin':0.2}])


        if self.optical_add_on and self.optical_add_on_ver == 0:
            self.configure_temperatures(self.optical_bus_1,0x48,'3V3_OPTICAL_G0',90,95,10)
            self.configure_temperatures(self.optical_bus_1,0x49,'3V3_OPTICAL_G1',90,95,10)
            self.configure_temperatures(self.optical_bus_1,0x4a,'3V3_OPTICAL_G2',90,95,10)
            self.configure_temperatures(self.optical_bus_0,0x48,'3V3_OPTICAL_G3',90,95,10)
            self.configure_temperatures(self.optical_bus_0,0x49,'3V3_OPTICAL_G4',90,95,10)
            self.configure_voltages_adc(self.optical_bus_0,0x1d,[  {'name':'12V0_OPTICAL','ch':1,'nominal':12.0,'factor':11,'margin':0.2},
                                                                   {'name':'3V3_OPTICAL_G0','ch':2,'nominal':3.3,'factor':11,'margin':0.1},
                                                                   {'name':'3V3_OPTICAL_G1','ch':3,'nominal':3.3,'factor':11,'margin':0.1},
                                                                   {'name':'3V3_OPTICAL_G2','ch':4,'nominal':3.3,'factor':11,'margin':0.1},
                                                                   {'name':'3V3_OPTICAL_G3','ch':5,'nominal':3.3,'factor':11,'margin':0.1},
                                                                   {'name':'3V3_OPTICAL_G4','ch':6,'nominal':3.3,'factor':11,'margin':0.1},
                                                                   {'name':'3V3_OPTICAL_STBY','ch':7,'nominal':3.3,'factor':11,'margin':0.1}])
    def clear_interrupts_octopus(self):
        #ADCs first
        self.north_bus.read_byte_data(0x1d,0x1)
        self.south_bus.read_byte_data(0x1d,0x1)
        self.north_bus.read_byte_data(0x1f,0x1)
        self.south_bus.read_byte_data(0x1f,0x1)

    def clear_interrupts_optical(self):
        #ADCs first
        self.optical_bus_0.read_byte_data(0x1d,0x1)

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
            self.power_down_expert(True)
        return success

    # port: 0 = "top", 1 = "bottom"
    def reset_c2c_bridge(self, port=1):
        ch_up_bit = 15 if port == 0 else 17 if port == 1 else None
        slave_rst_bit = 16 if port == 0 else 18 if port == 1 else None
        link_status_bit = 12 if port == 0 else 14 if port == 1 else None

        p=pydma('/dev/mem',0x41220000,1,4)
        reg = p.read(0)
        #set TX polarity
        mask=0xffffffff^(0xf<<10)
        reg=reg &mask
        p.write(0,reg)
        #Channel Up=0
        mask=0xffffffff^(1<<ch_up_bit)
        reg=mask&reg
        p.write(0,reg)
        #slave reset
        reg=reg|(1<<slave_rst_bit)
        p.write(0,reg)
        mask=0xffffffff^(1<<slave_rst_bit)
        reg=reg&mask
        p.write(0,reg)
        #Channel Up=1
        reg=reg|(1<<ch_up_bit)
        p.write(0x0,reg)
        #slave reset=0
        #link status
        time.sleep(0.1)
        status  = (p.read(2) & (1<<link_status_bit))!=0
        p.close()
        return status

    def jtag_chain(self,chain):
        if self.octopus_add_on == False:
            print("octopus_add_on is False. Must be True to run this function")
            return
        self.i2c1.write_byte_data(self.octopus_addr,0x0,chain&0x1)

    def octopus_alerts(self):
        return self.i2c1.read_byte_data(self.octopus_addr,0x4)
    def optical_alerts(self):
        return self.optical_slave_bus.read_byte_data(self.optical_addr,0x3)

    def optics_command(self,cages,func,*args):
        semaphore.lock(self.optics_sem)

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
        semaphore.unlock(self.optics_sem)

        return r

    def set_ipmc_virtual_handle(self,value):
        filename='/root/UF_IPMC/CONFIG/CONFIG.toml'
        file1 = open(filename, "r")
        lines = file1.readlines()
        file1.close()
        for idx, line in enumerate(lines):
            if "man_handle_switch = " in line[0:20]:
                lines[idx] = "man_handle_switch = %s\n"%value
                file1 = open(filename, "w")
                file1.writelines(lines)
                break
            elif "man_handle_switch=" in line[0:18]:
                lines[idx] = "man_handle_switch = %s\n"%value
                file1 = open(filename, "w")
                file1.writelines(lines)
                break
            elif "man_handle_switch =" in line[0:19]:
                lines[idx] = "man_handle_switch = %s\n"%value
                file1 = open(filename, "w")
                file1.writelines(lines)
                break
            elif "man_handle_switch= " in line[0:19]:
                lines[idx] = "man_handle_switch = %s\n"%value
                file1 = open(filename, "w")
                file1.writelines(lines)
                break
        file1.close()

    def power_up(self,timeout=100):
#        semaphore.unlock(self.OCTOPUS_BUS)
        ipmc_status = os.system('systemctl is-active --quiet ipmc.service')
        counter=0
        if ipmc_status==0:
            self.set_ipmc_virtual_handle(0)
            #wait for PGOOD
            while 1:
                semaphore.lock(self.OCTOPUS_BUS)
                latches=self.octopus_alerts()
                if self.optical_add_on and self.optical_add_on_ver == 0:
                    latches=latches&self.optical_alerts()
                if latches==0xff or counter==timeout:
                    semaphore.unlock(self.OCTOPUS_BUS)
                    break
                time.sleep(0.3)
                counter=counter+1
                semaphore.unlock(self.OCTOPUS_BUS)

            if counter>=timeout:
                print("Failed to power, timeout exceeded,requesting power down")
                self.power_down()
            else:
                if self.optical_add_on:
                    self.autodetect_optics(2)
                print("Powered Up")
        else:
            print("IPMC is not running so not able to start in user mode. Maybe you want to start in expert mode?")

    def power_down(self):
        ipmc_status = os.system('systemctl is-active --quiet ipmc.service')
        if ipmc_status==0:
            self.set_ipmc_virtual_handle(1)
        else:
            print("IPMC is not running so not able to stop in user mode. Maybe you want to start in expert mode?If yes run the command m.peripheral.power_down_expert()")
        if self.optical_add_on:
            self.devices['optics']={}



    def power_up_expert(self,timeout=50,verbose=False,payloadOn=True):
        semaphore.lock(self.OCTOPUS_BUS)
        alert=0
        alert2=0
        #Disable latches to avoid trip
        if self.octopus_add_on:
            self.i2c1.write_byte_data(self.octopus_addr,10,1)
            self.power_down_expert(True,0.0,payloadOn)
        #configure
        self.configure()
        #First enable the payload using memory access
        if payloadOn:
            p=pydma('/dev/mem',0x41220000,1,4)
            reg = p.read(0)
            reg=reg| (1<<5)
            p.write(0,reg)
            p.close()
        if self.octopus_add_on:
            if self.validate_rail('12V0',timeout,1,verbose)==0:
                semaphore.unlock(self.OCTOPUS_BUS)
                return 0
            if self.validate_rail('3V3_STANDBY',timeout,1,verbose)==0:
                semaphore.unlock(self.OCTOPUS_BUS)
                return 0
            self.i2c1.write_byte_data(self.octopus_addr,7,0x1)
            if self.validate_rail('2V7_INTERMEDIATE',timeout,1,verbose)==0:
                semaphore.unlock(self.OCTOPUS_BUS)
                return 0
            self.i2c1.write_byte_data(self.octopus_addr,7,0x7)
            if self.validate_rail('1V8_SI5395J_XO2',timeout,1,verbose)==0:
                semaphore.unlock(self.OCTOPUS_BUS)
                return 0
            if self.validate_rail('3V3_SI5395J',timeout,1,verbose)==0:
                semaphore.unlock(self.OCTOPUS_BUS)
                return 0
            self.i2c1.write_byte_data(self.octopus_addr,7,0xf)
            #f self.validate_rail('2V5_OSC_K7',timeout,1,verbose)==0:
                #rint("Returned at 2V5_OSC_K7")
                #semaphore.unlock(self.OCTOPUS_BUS)
                #return 0
            self.i2c1.write_byte_data(self.octopus_addr,7,0x1f)
            #if self.validate_rail('2V5_OSC_NE',timeout,1,verbose)==0:
                #print("Returned at 2V5_OSC_NE")
                #semaphore.unlock(self.OCTOPUS_BUS)
                #return 0
            self.i2c1.write_byte_data(self.octopus_addr,7,0x3f)
            #if self.validate_rail('2V5_OSC_NW',timeout,1,verbose)==0:
                #print("Returned at 2V5_OSC_NW")
                #semaphore.unlock(self.OCTOPUS_BUS)
                #return 0
            self.i2c1.write_byte_data(self.octopus_addr,7,0x7f)
            #if self.validate_rail('2V5_OSC_SE',timeout,1,verbose)==0:
                #print("Returned at 2V5_OSC_SE")
                #semaphore.unlock(self.OCTOPUS_BUS)
                #return 0
            self.i2c1.write_byte_data(self.octopus_addr,7,0xff)
            #if self.validate_rail('2V5_OSC_SW',timeout,1,verbose)==0:
                #print("Returned at 2V5_OSC_SW")
                #semaphore.unlock(self.OCTOPUS_BUS)
                #return 0
            self.i2c1.write_byte_data(self.octopus_addr,9,0x1)
            #if self.validate_rail('1V0_VCCINT_K7',timeout,1,verbose)==0:
                #print("Returned at 1V0_VCCINT_K7")
                #semaphore.unlock(self.OCTOPUS_BUS)
                #return 0
            self.i2c1.write_byte_data(self.octopus_addr,9,0x3)
            #if self.validate_rail('1V8_VCCAUX_K7',timeout,1,verbose)==0:
                #print("Returned at 1V8_VCCAUX_K7")
                #semaphore.unlock(self.OCTOPUS_BUS)
                #return 0
            self.i2c1.write_byte_data(self.octopus_addr,9,0x7)
            #if self.validate_rail('1V35_DDR',timeout,1,verbose)==0:
                #print("Returned at 1V35_DDR")
                #semaphore.unlock(self.OCTOPUS_BUS)
                #return 0
            self.i2c1.write_byte_data(self.octopus_addr,9,0xf)
            #if self.validate_rail('1V0_MGTAVCC_K7',timeout,1,verbose)==0:
                #print("Returned at 1V0_MGTAVCC_K7")
                #semaphore.unlock(self.OCTOPUS_BUS)
                #return 0
            self.i2c1.write_byte_data(self.octopus_addr,9,0x1f)
            #if self.validate_rail('1V2_MGTAVTT_K7',timeout,1,verbose)==0:
                #print("Returned at 1V2_MGTAVTT_K7")
                #semaphore.unlock(self.OCTOPUS_BUS)
                #return 0
            self.i2c1.write_byte_data(self.octopus_addr,8,0x1)
            if self.validate_rail('0V85_VCCINT_VUP',timeout,1,verbose)==0:
                print("Returned at 0V85_VCCINT_VUP")
                semaphore.unlock(self.OCTOPUS_BUS)
                return 0
            self.configure_ltm4700(self.south_bus,0x4d,90)
            self.configure_ltm4700(self.south_bus,0x4e,90)
            self.configure_ltm4700(self.south_bus,0x4f,90)
            if self.validate_rail('0V85_VCCINT_VUP',timeout,1,verbose)==0:
                print("Returned at 0V85_VCCINT_VUP")
                semaphore.unlock(self.OCTOPUS_BUS)
                return 0
            self.i2c1.write_byte_data(self.octopus_addr,8,0x3)
            if self.validate_rail('1V8_VCCAUX_VUP',timeout,1,verbose)==0:
                print("Returned at 1V8_VCCAUX_VUP")
                semaphore.unlock(self.OCTOPUS_BUS)
                return 0
            self.i2c1.write_byte_data(self.octopus_addr,8,0x7)
            if self.validate_rail('0V9_MGTAVCC_VUP_N',timeout,1,verbose)==0:
                print("Returned at 0V9_MGTAVCC_VUP_N")
                semaphore.unlock(self.OCTOPUS_BUS)
                return 0
            self.i2c1.write_byte_data(self.octopus_addr,8,0xf)
            if self.validate_rail('1V2_MGTAVTT_VUP_N',timeout,1,verbose)==0:
                print("Returned at 1V2_MGTAVTT_VUP_N")
                semaphore.unlock(self.OCTOPUS_BUS)
                return 0
            self.i2c1.write_byte_data(self.octopus_addr,8,0x1f)
            if self.validate_rail('0V9_MGTAVCC_VUP_S',timeout,1,verbose)==0:
                print("Returned at 0V9_MGTAVCC_VUP_S")
                semaphore.unlock(self.OCTOPUS_BUS)
                return 0
            self.i2c1.write_byte_data(self.octopus_addr,8,0x3f)
            if self.validate_rail('1V2_MGTAVTT_VUP_S',timeout,1,verbose)==0:
                print("Returned at 1V2_MGTAVTT_VUP_S")
                semaphore.unlock(self.OCTOPUS_BUS)
                return 0
            self.clear_interrupts_octopus()
            #check alerts
            alert=self.octopus_alerts()
            if alert !=0xff:
                self.power_down_expert(True)
                if verbose:
                    print("Power Up Failed with alert code:",alert)
                semaphore.unlock(self.OCTOPUS_BUS)
                return
            #enable latches
            self.i2c1.write_byte_data(self.octopus_addr,10,0)

        if self.optical_add_on and self.optical_add_on_ver == 0:
            #disable latches
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
            self.clear_interrupts_optical()
            #check alerts
            alert2=self.optical_alerts()
            if alert2 !=0xff:
                self.power_down_expert(True)
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
        semaphore.unlock(self.OCTOPUS_BUS)
        if self.optical_add_on:
            self.autodetect_optics(2,verbose)
        return alert|(alert2<<8)


    def power_down_expert(self,locked=False,delay=0.0,payloadOff=True):
        if not locked:
            semaphore.lock(self.OCTOPUS_BUS)
        if self.octopus_add_on:
            self.i2c1.write_byte_data(self.octopus_addr,9,0x0)
            time.sleep(delay)
            self.i2c1.write_byte_data(self.octopus_addr,8,0x0)
            time.sleep(delay)
            self.i2c1.write_byte_data(self.octopus_addr,7,0x0)
            time.sleep(delay)

        if self.optical_add_on and self.optical_add_on_ver == 0:
            self.optical_slave_bus.write_byte_data(self.optical_addr,7,0x0)
        if not locked:
            semaphore.unlock(self.OCTOPUS_BUS)
        if payloadOff:
            p=pydma('/dev/mem',0x41220000,1,4)
            reg = p.read(0)
            mask=0xffffffff ^ (1<<5)
            p.write(0,reg&mask)
            p.close()
        self.devices['optics']={}

    def optics_presence(self):
        if self.optical_add_on_ver == 0:
            msb=self.optical_slave_bus.read_byte_data(self.optical_addr,5)
            lsb=self.optical_slave_bus.read_byte_data(self.optical_addr,4)
            return (msb<<8)|lsb

        else:
            return self.qsfp_module.optics_presence()

    def select_cage(self,cage):
        if self.optical_add_on_ver == 0:
            if cage == -1:
                self.optical_slave_bus.write_byte_data(self.optical_addr,13,0xff)
                self.optical_slave_bus.write_byte_data(self.optical_addr,14,0xff)
            else:
                i = 1 << cage
                i ^= 0x7FFF
                self.optical_slave_bus.write_byte_data(self.optical_addr,13,0xff & i)
                self.optical_slave_bus.write_byte_data(self.optical_addr,14,0xff &(i>>8))
        else:
            self.qsfp_module.select_cage(cage)

    def handle_switch(self):
        return self.optical_slave_bus.read_byte_data(self.optical_addr,6) &0x4

    def set_led(self,cage,red_mode,green_mode,blue_mode):
        mode = ((blue_mode&3) << 4) | ((green_mode&3) << 2) | (red_mode&3)
        self.optical_slave_bus.write_byte_data(self.optical_addr,15+cage,mode)


    def autodetect_optics(self,timeout=0.0,verbose=False):
        if verbose:
            print("Autodetecting Optics")
            print("Waiting for 2 s for optics to start")
        time.sleep(timeout)
        semaphore.lock(self.optics_sem)
        mask = self.optics_presence()
        self.devices['optics']={}
        modules=[]
        num_cages = 15 if self.optical_add_on_ver == 0 else self.qsfp_module.num_cages
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
            if identifier==24 and self.optical_add_on_ver == 0: #QSFP-DD
                version = self.optics_bus.read_byte_data(0x50,1)
                if version>=0x40:
                    self.devices['optics'][i] =qsfpdd_v4(self.optics_bus,0x50,i,self.select_cage)
                else:
                    self.devices['optics'][i] =qsfpdd_v2(self.optics_bus,0x50,i,self.select_cage)
        self.optics = device_group(modules)
        self.select_cage(-1)
        semaphore.unlock(self.optics_sem)

        return self.devices['optics']

    def monitor(self,verbose=True):
        semaphore.lock(self.OCTOPUS_BUS)
        optical_data=[]
        data=[]

        if self.optical_add_on and self.optical_add_on_ver == 0:
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

        if self.octopus_add_on:
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
        semaphore.unlock(self.OCTOPUS_BUS)

        mon={}
        board_power=0;


        if self.optical_add_on and self.optical_add_on_ver == 0:
            devs=['3V3_OPTICAL_G4','3V3_OPTICAL_G3','3V3_OPTICAL_G2','3V3_OPTICAL_G1','3V3_OPTICAL_G0']
            for i in range(0,20,4):
                N=int(i/4)
                if not devs[N] in mon.keys():
                    mon[devs[N]]={'T':[]}
                l = (optical_data[i+3] << 4) | (optical_data[i+2] >> 4)
                mon[devs[N]]['T'].append(twos_comp(l,12)*0.0625)
                r = (optical_data[i+1] << 4) | (optical_data[i+0] >> 4)
                mon[devs[N]]['T'].append(twos_comp(r,12)*0.0625)



            for i in range(20,40,4):
                N=int((i-20)/4)
                if devs[N] in mon.keys():
                    mon[devs[N]]['I']=0
                    mon[devs[N]]['P']=0
                else:
                    mon[devs[N]]={'I':0,'P':0}
                mon[devs[N]]['I'] = twos_comp(optical_data[i]|(optical_data[i+1]<<8),16)*0.0000025/0.01
                mon[devs[N]]['P'] = twos_comp(optical_data[i+2]|(optical_data[i+3]<<8),16)*0.00125*mon[devs[N]]['I']
                board_power=board_power+mon[devs[N]]['P']

            devs=['3V3_OPTICAL_STBY','3V3_OPTICAL_G4','3V3_OPTICAL_G3','3V3_OPTICAL_G2','3V3_OPTICAL_G1','3V3_OPTICAL_G0','12V0_OPTICAL']
            for i in range(40,54,2):
                N=int((i-40)/2)
                if not devs[N] in mon.keys():
                    mon[devs[N]] = {'V':0}
                else:
                    mon[devs[N]]['V'] = 0
                value = optical_data[i] |( optical_data[i+1] << 8)
                mon[devs[N]]['V'] = value * 11.0 * 2.56 / 65536.0

        if self.octopus_add_on:

            #convert to dict and print
            mon['0V85_VCCINT_VUP']={'T':[]}

            for i in range(0,12,2):
                w = data[i] | (data[i+1] << 8)
                w = ((r & 0xFF) << 8) | ((r >> 8) & 0xFF)
                mon['0V85_VCCINT_VUP']['T'].append(linear11(w))

            devs=['1V2_MGTAVTT_VUP_S','1V2_MGTAVTT_VUP_S','KINTEX7','0V9_MGTAVCC_VUP_S','0V9_MGTAVCC_VUP_S','2V7_INTERMEDIATE','1V2_MGTAVTT_VUP_N','1V2_MGTAVTT_VUP_N','VIRTEXUPLUS','0V9_MGTAVCC_VUP_S','0V9_MGTAVCC_VUP_S']
            for i in range(12,56,4):
                N=int((i-12)/4)
                if not devs[N] in mon.keys():
                    mon[devs[N]]={'T':[]}
                l = (data[i+3] << 4) | (data[i+2] >> 4)
                mon[devs[N]]['T'].append(twos_comp(l,12)*0.0625)
                r = (data[i+1] << 4) | (data[i+0] >> 4)
                mon[devs[N]]['T'].append(twos_comp(r,12)*0.0625)

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
                mon[devs[N]]['I'] = twos_comp(data[i]|(data[i+1]<<8),16)*0.0000025/dividers[N]
                mon[devs[N]]['P'] = twos_comp(data[i+2]|(data[i+3]<<8),16)*0.00125*mon[devs[N]]['I']
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
            mon['slot'] = {'P':board_power}


        if 'optics' in self.devices.keys() and len(self.devices['optics'].keys())>0:
            semaphore.lock(self.optics_sem)
            mon['optics']={}
            for cage,pluggable in self.devices['optics'].items():
                pluggable.select()
                mon['optics'][cage]={'type':pluggable.identifier(),'V':pluggable.voltage(),'T':pluggable.temperature(),'tx_enabled':pluggable.tx_enabled(),'rx_enabled':pluggable.rx_enabled(),'rx_cdr':pluggable.rx_cdr_enabled(),'tx_cdr':pluggable.tx_cdr_enabled(),'rx_power':[]}
                po = pluggable.rx_power()
                for p in po:
                    mon['optics'][cage]['rx_power'].append(str(p)+ " dBm")
            semaphore.unlock(self.optics_sem)
        if verbose:
            st="X2O Monitoring\t"
            if self.octopus_add_on:
                st=st+'Octopus Healthy = {}\t'.format(self.octopus_alerts()==0xff)
            if self.optical_add_on and self.optical_add_on_ver == 0:
                st=st+'Optical Module Healthy = {}'.format(self.optical_alerts()==0xff)
            st=st+'\n'
            st=st+'--------------------------------------------------------------------------------------------------------------\n'
            st=st+"{0:20}".format("Device")+'\tV\t\t'+"I\t\t"+'P\t\t'+'T\n'
            for i in range(len(list(mon.keys()))-1,0,-1):
                device = list(mon.keys())[i]
                if device in ['KINTEX7','VIRTEXUPLUS','slot','optics']:
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
                    st=st+'\t'+'          '

                if 'P' in mon[device].keys():
                    st=st+'\t'+'{:+3.2f} W'.format(mon[device]['P'])
                else:
                    st=st+'\t'+'          '

                if 'T' in mon[device].keys():
                    tstr=[]
                    for t in mon[device]['T']:
                        tstr.append("{:3.1f} C".format(t))
                    st=st+'\t'+','.join(tstr)
                st=st+'\n'

            st=st+'--------------------------------------------------------------------------------------------------------------\n'
            #OPTICS"
            if 'optics' in self.devices.keys() and len(self.devices['optics'].keys())>0:
                st=st+'----------------------------------------------OPTICS----------------------------------------------------------\n'
                st =st+ " cage {0:45}\t ".format("Type")+"{0:8}  ".format("V")+"{0:7} ".format("T")+" {0:4} ".format("RX")+" {0:4} ".format("TX")+" {0:5} ".format("RXCDR")+" {0:5} ".format("TXCDR")+" {0:12} ".format("RX Optical Power")+"\n"
                for cage,info in mon['optics'].items():
                    st =st+"{0:3}: ".format(str(cage))+ "{0:45}\t ".format(info['type'])+" {:2.3f} V".format(info['V'])+" {:+2.1f} C ".format(info['T'])+" {0:4} ".format(hex(info['rx_enabled']))+" {0:4} ".format(hex(info['tx_enabled']))+" {0:5} ".format(hex(info['rx_cdr']))+" {0:5} ".format(hex(info['tx_cdr']))+"  "','.join(info['rx_power'])+'\n'
                st=st+'--------------------------------------------------------------------------------------------------------------\n'

            print(st)

        return mon




class manager(object):
    def __init__(self,octopus_add_on=True,optical_add_on=True,optical_add_on_ver=0,raspberry_pi = False,board_id =0x4f434e):
        self.board_id = board_id
        self.peripheral  = peripheraltree(0.000, octopus_add_on, optical_add_on, optical_add_on_ver)
        if not raspberry_pi:
            self.jtag = bscan(0x43c10000)
        else:
            self.jtag = bscan('pi')


    def power_up(self):
        self.peripheral.power_up()
    def power_down(self):
        self.peripheral.power_down()

    def start_xvc(self):
        os.system("systemctl start xvc.service")

    def stop_xvc(self):
        os.system("systemctl stop xvc.service")


    def detect_fpgas(self):
        self.stop_xvc()
        fpgas=[]
        self.peripheral.jtag_chain(0)
        fpgas.append(self.jtag.fpga_id())
        self.peripheral.jtag_chain(1)
        fpgas.append(self.jtag.fpga_id())
        return fpgas

    def load_firmware_k7(self,firmware):
        if not os.path.exists(firmware):
            print('File not found')
            return -1
        self.stop_xvc()
        self.peripheral.jtag_chain(0)
        return self.jtag.program_xilinx(firmware)

    def load_firmware_vup(self,firmware):
        if not os.path.exists(firmware):
            print('File not found')
            return -1
        self.stop_xvc()
        self.peripheral.jtag_chain(1)
        return self.jtag.program_xilinx(firmware)

    def reset_c2c_bridge(self, port=1):
        return self.peripheral.reset_c2c_bridge(port)

    def load_clock_file(self,script,lock=True):
        if lock:
            semaphore.lock(self.peripheral.OCTOPUS_BUS)
        synth =si539x(self.peripheral.clock_bus,0x68)
        synth.load_config(script)
        if lock:
            semaphore.unlock(self.peripheral.OCTOPUS_BUS)



class blobfish_manager(manager):
    def __init__(self,board_type='X2O_VU13P_QSFPDD'):
        super().__init__(1, 1,0,0x4f434e)
        self.DMA_ADDR=0x60000000
        self.DMA_KB=512
        dma.map(self.DMA_ADDR,5*self.DMA_KB)
        self.slr = {0:slr(dma,0x0,self.DMA_KB,False),
                    1:slr(dma,0x80000,self.DMA_KB,False),
                    2:slr(dma,0x100000,self.DMA_KB,False),
                    3:slr(dma,0x180000,self.DMA_KB,False)}
        self.tcds2 = tcds2(dma,0x200000,self.DMA_KB,False)
        self.map_fpga_arf = map_fpga_arf



    def configure_physical_layer(self):
        self.peripheral.autodetect_optics()
        #reset all optical transceivers
        self.peripheral.optics_command('all','reset')

        #disable all channels
        self.peripheral.optics_command('all','enable_tx',0x0)
        self.peripheral.optics_command('all','enable_rx',0x0)

        optics_rx_enabled =self.peripheral.optics_command('all','rx_enabled')
        optics_tx_enabled =self.peripheral.optics_command('all','tx_enabled')


        for slr_n,slr in self.slr.items():
            #Boot GTs
            slr.gt_power_up('all')
            slr.gt_site_reset('all')
            #Enable LPM
            slr.gt_channel_lpm_enable('all')
            gtinfo = slr.config['gt']
            #fix polarity
            for site,sitedata in self.map_fpga_arf[slr_n].items():
                if not (site in gtinfo['active']):
                    continue
                txpolarity = sitedata['txpolarity']
                rxpolarity = sitedata['rxpolarity']
                for txchannel in range(0,gtinfo[site]['txch']):
                    reverse = txpolarity & (1<<txchannel) !=0
                    if reverse:
                        slr.gt_channel_reverse_tx_polarity(site,txchannel)
                    else:
                        slr.gt_channel_standard_tx_polarity(site,txchannel)
                for rxchannel in range(0,gtinfo[site]['rxch']):
                    reverse = rxpolarity & (1<<rxchannel) !=0
                    if reverse:
                        slr.gt_channel_reverse_rx_polarity(site,rxchannel)
                    else:
                        slr.gt_channel_standard_rx_polarity(site,rxchannel)

                #set channel enable masks
                for channel,connection in sitedata['rx'].items():
                    cage  = connection[0]
                    fiber = connection[1]

                    if ((site in gtinfo['active']) and  (channel<gtinfo[site]['rxch'])):
                        optics_rx_enabled[cage] = optics_rx_enabled[cage]|(1<<fiber)
                    else:
                        if optics_rx_enabled[cage] & (1<<fiber) !=0:
                            optics_rx_enabled[cage] = optics_rx_enabled[cage]^(1<<fiber)
                for channel,connection in sitedata['tx'].items():
                    cage  = connection[0]
                    fiber = connection[1]

                    if ((site in gtinfo['active']) and  (channel<gtinfo[site]['txch'])):
                        optics_tx_enabled[cage] = optics_tx_enabled[cage]|(1<<fiber)
                    else:
                        if optics_tx_enabled[cage] & (1<<fiber) !=0:
                            optics_tx_enabled[cage] = optics_tx_enabled[cage]^(1<<fiber)
        #apply settings to hardware
        for c,mask in optics_rx_enabled.items():
            self.peripheral.optics_command([c],'enable_rx',mask)
        for c,mask in optics_tx_enabled.items():
            self.peripheral.optics_command([c],'enable_tx',mask)


    def connect(self):
        for slrno,slr in self.slr.items():
            slr.read_config()



    def setup_tcds2(self,simulation=0,verbose=1):
        #first load the sync file
        self.load_clock_file('/root/bitstreams/Si5395_AllSynchronous320M.csv')
        if verbose:
            print("Loaded Clock file with all clocks synchronous at 320 MHz")
        #then setup the retimer
        self.peripheral.setup_power_module_retimer()
        if verbose:
            print("Configured Retimer")
        self.tcds2.reset()
        if verbose:
            print("TCDS2 reset")
        self.tcds2.simulation(simulation)

    def load_firmware_vup(self,firmware,verbose=True):
        time=super().load_firmware_vup(firmware)
        if time<0:
            return -1
        rst = super().reset_c2c_bridge()
        if rst==0:
            print('Failed to initialize C2C bridge')
        self.connect()
        print('SLR config reading done')
        self.configure_physical_layer()
        if verbose:
            print('Firmware loaded in {} seconds'.format(time))



    def align_links(self,orbit_tag = True):
        pass


    def strobe(self):
        self.slr[1].soft_reset()
