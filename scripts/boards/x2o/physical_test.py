from board.manager import *
import sys
import re
import os
import time
from datetime import datetime


# Constants (to be moved to config file later)
STABILIZE_SENSITIVITY = 0.01
MAX_TEMP=70.0
MIN_ITERS=30
CYCLE_TIME=3
TOLERANCE=0.05
HEADERS = ["12V0_V","3V3_STANDBY_V","3V3_SI5395J_V","1V8_SI5395J_XO2_V","2V5_OSC_NE_V","1V8_MGTVCCAUX_VUP_N_V","2V5_OSC_NW_V","2V5_OSC_K7_V","1V2_MGTAVTT_K7_V","1V0_MGTAVCC_K7_V","0V675_DDRVTT_V","1V35_DDR_V","1V8_VCCAUX_K7_V","2V5_OSC_SE_V","1V8_MGTVCCAUX_VUP_S_V","2V5_OSC_SW_V",
            "0V85_VCCINT_VUP_T0","0V85_VCCINT_VUP_T1","0V85_VCCINT_VUP_T2","0V85_VCCINT_VUP_T3","0V85_VCCINT_VUP_T4","0V85_VCCINT_VUP_T5",'1V2_MGTAVTT_VUP_S_TL','1V2_MGTAVTT_VUP_S_TR','1V2_MGTAVTT_VUP_S_TL','1V2_MGTAVTT_VUP_S_TR','KINTEX7_TL','KINTEX7_TR','0V9_MGTAVCC_VUP_S_TL','0V9_MGTAVCC_VUP_S_TR','0V9_MGTAVCC_VUP_S_TL','0V9_MGTAVCC_VUP_S_TR','2V7_INTERMEDIATE_TL','2V7_INTERMEDIATE_TR','1V2_MGTAVTT_VUP_N_TL','1V2_MGTAVTT_VUP_N_TR','VIRTEXUPLUS_TL','VIRTEXUPLUS_TR','0V9_MGTAVCC_VUP_S_TL','0V9_MGTAVCC_VUP_S_TR','TOTAL_ERRORS']
V_EXPECT={'12V0':12,'3V3_STANDBY':3.3,'3V3_SI5395J':3.3,'1V8_SI5395J_XO2':1.8,'2V5_OSC_NE':2.5,'1V8_MGTVCCAUX_VUP_N':1.8,'2V5_OSC_NW':2.5,'2V5_OSC_K7':2.5,'1V2_MGTAVTT_K7':1.2,'1V0_MGTAVCC_K7':1.0,'0V675_DDRVTT':0.675,'1V35_DDR':1.35,'1V8_VCCAUX_K7':1.8,'2V5_OSC_SE':2.5,'1V8_MGTVCCAUX_VUP_S':1.8,'2V5_OSC_SW':2.5,'0V9_MGTAVCC_VUP_N':0.9,'1V8_VCCAUX_VUP':1.8,'1V0_VCCINT_K7':1.0,'1V2_MGTAVTT_VUP_N':1.2,'2V7_INTERMEDIATE':2.7,'0V9_MGTAVCC_VUP_S':0.9,'1V2_MGTAVTT_VUP_S':1.2}
# End of constants

DATA_DICT = {}
run_type = sys.argv[1]
def printRed(st):
    return "\033[91m"+st+"\033[0m"

def printGreen(st):
    return "\033[92m"+st+"\033[0m"

m=manager(optical_add_on_ver=2)
m.peripheral.autodetect_optics()
now = datetime.now()
d_time = now.strftime("%Y-%m-%d")
isExist = os.path.exists("./data/phys_data/"+d_time)
if not isExist:
   os.makedirs("./data/phys_data/"+d_time)
c_time = now.strftime("%Y-%m-%d-%H-%M-%S")
filename="/root/jessica/0xbefe/scripts/boards/x2o/data/phys_data/"+d_time+"/"+run_type+"_"+c_time+".csv"
f=open(filename,"w")
o_str=""
for i in HEADERS:
    o_str+=i+","
f.write(o_str+"\n")
diff_flag = True
n_iters=0
p_data = m.peripheral.monitor(verbose=False)

while(diff_flag):
    data = m.peripheral.monitor(verbose=False)
    diff_flag=False
    n_iters+=1

    o_str=""
    err_cnt=0


    st=""
    st=st+"{0:20}".format("Device")+'\tV\t\t'+"I\t\t"+'P\t\t'+'T\n'
    for i in range(len(list(data.keys()))-1,0,-1):
        device = list(data.keys())[i]
        DATA_DICT[device]={}
        if device in ['optics']:
            continue
        st =st+ "{0:20}".format(device)
        if 'V' in data[device].keys():
            DATA_DICT[device]['V']=0
            o_str+=str(data[device]['V'])+","
            if(data[device]['V']>p_data[device]['V']*(1+STABILIZE_SENSITIVITY)or data[device]['V']<p_data[device]['V']*(1-STABILIZE_SENSITIVITY)):
                diff_flag=True
            if (data[device]['V']>V_EXPECT[device]*(1+TOLERANCE) or data[device]['V']<V_EXPECT[device]*(1-TOLERANCE)):
                err_cnt+=1
                st+='\t'+printRed(str(round(data[device]['V'],3)))+" V"
            else:
                st+='\t'+printGreen(str(round(data[device]['V'],3)))+" V"
        else:
            st+='\t'

        if 'I' in data[device].keys():
            if(data[device]['I']>p_data[device]['I']*(1+STABILIZE_SENSITIVITY)or data[device]['I']<p_data[device]['I']*(1-STABILIZE_SENSITIVITY)):
                diff_flag=True
            o_str+=str(data[device]['I'])+","
            DATA_DICT[device]['I']=0
            st=st+'\t\t'+'{:+3.2f} A'.format(data[device]['I'])
        else:
            st=st+'\t'+'          '

        if 'P' in data[device].keys():
            DATA_DICT[device]['P']=0
            if(data[device]['P']>p_data[device]['P']*(1+STABILIZE_SENSITIVITY)or data[device]['P']<p_data[device]['P']*(1-STABILIZE_SENSITIVITY)):
                diff_flag=True
            o_str+=str(data[device]['P'])+","
            st=st+'\t\t'+'{:+3.2f} W'.format(data[device]['P'])
        else:
            st=st+'\t\t'+'          '

        if 'T' in data[device].keys():
            tstr="\t"
            DATA_DICT[device]['T']=[]
            for i in range(len(data[device]['T'])):
                t=data[device]['T'][i]
                DATA_DICT[device]['T'].append(0)
                o_str+=str(t)+","
                if(t>p_data[device]['T'][i]*(1+STABILIZE_SENSITIVITY)or t<p_data[device]['T'][i]*(1-STABILIZE_SENSITIVITY)):
                    diff_flag=True
                if t>MAX_TEMP:
                    err_cnt+=1
                    tstr+=printRed(str(t))+" C,"
                    print("Temperature too high, aborting run")
                    sys.exit(1)
                else:
                    tstr+=printGreen(str(t))+" C,"

            st+=tstr
        st=st+'\n'

    st=st+'--------------------------------------------------------------------------------------------------------------\n'
    #OPTICS"
    if 'optics' in data.keys() and len(data['optics'].keys())>0:
        st=st+'----------------------------------------------OPTICS----------------------------------------------------------\n'
        st =st+ " cage {0:45}\t ".format("Type")+"{0:8}  ".format("V")+"{0:7} ".format("T")+" {0:4} ".format("RX")+" {0:4} ".format("TX")+" {0:5} ".format("RXCDR")+" {0:5} ".format("TXCDR")+"\n"
        for cage,info in data['optics'].items():
            o_str+=str(cage)+","+info['type']+","+str(info['V'])+","
            o_str+=str(info['T'])+","
            o_str+=hex(info['rx_enabled'])+","
            o_str+=hex(info['tx_enabled'])+","+hex(info['rx_cdr'])+","+hex(info['tx_cdr'])+","
            st =st+"{0:3}: ".format(str(cage))+ "{0:45}\t ".format(info['type'])
            if(info['V']>3.3*(1+TOLERANCE) or info['V']<3.3*(1-TOLERANCE)):
                err_cnt+=1
                st+= printRed(str(round(info['V'],3)))+" V"
            else:
                st+=printGreen(str(round(info['V'],3)))+" V"
            if(info['T']>MAX_TEMP):
                err_cnt+=1
                st+= printRed(str(round(info['T'],3)))+" C    "
                print("Temperature too high, aborting run")
                sys.exit(1)
            else:
                st+=printGreen(str(round(info['T'],3)))+" C    "
            st+=" {0:4} ".format(hex(info['rx_enabled']))+" {0:4} ".format(hex(info['tx_enabled']))+" {0:5} ".format(hex(info['rx_cdr']))+" {0:5} ".format(hex(info['tx_cdr']))+'\n'
        st=st+'--------------------------------------------------------------------------------------------------------------\n'

    #final outputs for read cycle
    o_str+=str(err_cnt)+"\n"
    if(err_cnt>0):
        st+=printRed("Total Errors: "+str(err_cnt))+"\n"
    else:
        st+=printGreen("Total Errors: "+str(err_cnt))+"\n"
    print("")
    print(st)
    f.write(o_str)
    p_data = data
    time.sleep(CYCLE_TIME)

print("Physical data stable, generating statistics")
stable_iters=0
DATA_DICT['TOTAL_ERRORS']=0
while(stable_iters<MIN_ITERS):
    data = m.peripheral.monitor(verbose=False)
    stable_iters+=1
    n_iters+=1

    o_str=""
    err_cnt=0


    st=""
    st=st+"{0:20}".format("Device")+'\tV\t\t'+"I\t\t"+'P\t\t'+'T\n'
    for i in range(len(list(data.keys()))-1,0,-1):
        device = list(data.keys())[i]
        
        if device in ['optics']:
            continue
        st =st+ "{0:20}".format(device)
        if 'V' in data[device].keys():
            o_str+=str(data[device]['V'])+","
            DATA_DICT[device]['V']+=data[device]['V']
            if (data[device]['V']>V_EXPECT[device]*(1+TOLERANCE) or data[device]['V']<V_EXPECT[device]*(1-TOLERANCE)):
                err_cnt+=1
                st+='\t'+printRed(str(round(data[device]['V'],3)))+" V"
            else:
                st+='\t'+printGreen(str(round(data[device]['V'],3)))+" V"
        else:
            st+='\t'

        if 'I' in data[device].keys():
            DATA_DICT[device]['I']+=data[device]['I']
            o_str+=str(data[device]['I'])+","
            st=st+'\t\t'+'{:+3.2f} A'.format(data[device]['I'])
        else:
            st=st+'\t'+'          '

        if 'P' in data[device].keys():
            DATA_DICT[device]['P']+=data[device]['P']
            o_str+=str(data[device]['P'])+","
            st=st+'\t\t'+'{:+3.2f} W'.format(data[device]['P'])
        else:
            st=st+'\t\t'+'          '

        if 'T' in data[device].keys():
            tstr="\t"
            for i in range(len(data[device]['T'])):
                t=data[device]['T'][i]
                DATA_DICT[device]['T'][i]+=data[device]['T'][i]
                o_str+=str(t)+","
                if t>MAX_TEMP:
                    err_cnt+=1
                    tstr+=printRed(str(t))+" C,"
                    print("Temperature too high, aborting run")
                    sys.exit(1)
                else:
                    tstr+=printGreen(str(t))+" C,"

            st+=tstr
        st=st+'\n'

    st=st+'--------------------------------------------------------------------------------------------------------------\n'
    #OPTICS"
    if 'optics' in data.keys() and len(data['optics'].keys())>0:
        st=st+'----------------------------------------------OPTICS----------------------------------------------------------\n'
        st =st+ " cage {0:45}\t ".format("Type")+"{0:8}  ".format("V")+"{0:7} ".format("T")+" {0:4} ".format("RX")+" {0:4} ".format("TX")+" {0:5} ".format("RXCDR")+" {0:5} ".format("TXCDR")+"\n"
        for cage,info in data['optics'].items():
            o_str+=str(cage)+","+info['type']+","+str(info['V'])+","
            o_str+=str(info['T'])+","
            o_str+=hex(info['rx_enabled'])+","
            o_str+=hex(info['tx_enabled'])+","+hex(info['rx_cdr'])+","+hex(info['tx_cdr'])+","
            st =st+"{0:3}: ".format(str(cage))+ "{0:45}\t ".format(info['type'])
            if(info['V']>3.3*(1+TOLERANCE) or info['V']<3.3*(1-TOLERANCE)):
                err_cnt+=1
                st+= printRed(str(round(info['V'],3)))+" V"
            else:
                st+=printGreen(str(round(info['V'],3)))+" V"
            if(info['T']>MAX_TEMP):
                err_cnt+=1
                st+= printRed(str(round(info['T'],3)))+" C    "
                print("Temperature too high, aborting run")
                sys.exit(1)
            else:
                st+=printGreen(str(round(info['T'],3)))+" C    "
            st+=" {0:4} ".format(hex(info['rx_enabled']))+" {0:4} ".format(hex(info['tx_enabled']))+" {0:5} ".format(hex(info['rx_cdr']))+" {0:5} ".format(hex(info['tx_cdr']))+'\n'
        st=st+'--------------------------------------------------------------------------------------------------------------\n'

    #final outputs for read cycle
    o_str+=str(err_cnt)+"\n"
    DATA_DICT['TOTAL_ERRORS']+=err_cnt
    if(err_cnt>0):
        st+=printRed("Total Errors: "+str(err_cnt))+"\n"
    else:
        st+=printGreen("Total Errors: "+str(err_cnt))+"\n"
    print("")
    print(st)
    f.write(o_str)
    
    time.sleep(CYCLE_TIME)

#Calculate means
summary_header_str="TOTAL_ERRORS,STABLE_ITERS,TIME_TO_STABILIZE,"
data_str=""

data_str+=str(DATA_DICT['TOTAL_ERRORS']/stable_iters)+","
data_str+=str(stable_iters)+","
data_str+=str((n_iters-stable_iters)*CYCLE_TIME)+","

for i in range(len(list(DATA_DICT.keys()))-1,0,-1):
    device = list(DATA_DICT.keys())[i]
    if device in ['optics']:
        continue
    if device in ['STABLE_ITERS','TOTAL_ERRORS','TIME_TO_STABILIZE']:
        continue
    if 'V' in DATA_DICT[device].keys():
        summary_header_str+=device+"_V,"
        DATA_DICT[device]['V']=DATA_DICT[device]['V']/stable_iters
        data_str+=str(DATA_DICT[device]['V'])+","

    if 'I' in DATA_DICT[device].keys():
        DATA_DICT[device]['I']=DATA_DICT[device]['I']/stable_iters
        summary_header_str+=device+"_I,"
        data_str+=str(DATA_DICT[device]['I'])+","
    
    if 'P' in DATA_DICT[device].keys():
        DATA_DICT[device]['P']=DATA_DICT[device]['P']/stable_iters
        summary_header_str+=device+"_P,"
        data_str+=str(DATA_DICT[device]['P'])+","

    if 'T' in DATA_DICT[device].keys():
        for i in range(len(data[device]['T'])):
            DATA_DICT[device]['T'][i]=DATA_DICT[device]['T'][i]/stable_iters
            summary_header_str+=device+"_T"+str(i)+","
            data_str+=str(DATA_DICT[device]['T'][i])+","          



DATA_DICT['STABLE_ITERS']=stable_iters
DATA_DICT['TOTAL_ERRORS']=DATA_DICT['TOTAL_ERRORS']/stable_iters
DATA_DICT['TIME_TO_STABILIZE']=(n_iters-stable_iters)*CYCLE_TIME
f.close()
filename="/root/jessica/0xbefe/scripts/boards/x2o/data/summary/"+d_time+"/"+run_type+"_"+c_time+".csv"
isExist = os.path.exists("./data/summary/"+d_time)
if not isExist:
   os.makedirs("./data/summary/"+d_time)
sum_f=open(filename,"w")
sum_f.write(summary_header_str+"\n")
sum_f.write(data_str)
sum_f.close()

