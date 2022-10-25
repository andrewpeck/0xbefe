from board.manager import *
import sys
import re
import time
from datetime import datetime


# Constants (to be moved to config file later)
STABILIZE_SENSITIVITY = 0.01
HEADERS = ["12V0_V","3V3_STANDBY_V","3V3_SI5395J_V","1V8_SI5395J_XO2_V","2V5_OSC_NE_V","1V8_MGTVCCAUX_VUP_N_V","2V5_OSC_NW_V","2V5_OSC_K7_V","1V2_MGTAVTT_K7_V","1V0_MGTAVCC_K7_V","0V675_DDRVTT_V","1V35_DDR_V","1V8_VCCAUX_K7_V","2V5_OSC_SE_V","1V8_MGTVCCAUX_VUP_S_V","2V5_OSC_SW_V",
            "0V85_VCCINT_VUP_T0","0V85_VCCINT_VUP_T1","0V85_VCCINT_VUP_T2","0V85_VCCINT_VUP_T3","0V85_VCCINT_VUP_T4","0V85_VCCINT_VUP_T5",'1V2_MGTAVTT_VUP_S_TL','1V2_MGTAVTT_VUP_S_TR','1V2_MGTAVTT_VUP_S_TL','1V2_MGTAVTT_VUP_S_TR','KINTEX7_TL','KINTEX7_TR','0V9_MGTAVCC_VUP_S_TL','0V9_MGTAVCC_VUP_S_TR','0V9_MGTAVCC_VUP_S_TL','0V9_MGTAVCC_VUP_S_TR','2V7_INTERMEDIATE_TL','2V7_INTERMEDIATE_TR','1V2_MGTAVTT_VUP_N_TL','1V2_MGTAVTT_VUP_N_TR','VIRTEXUPLUS_TL','VIRTEXUPLUS_TR','0V9_MGTAVCC_VUP_S_TL','0V9_MGTAVCC_VUP_S_TR','TOTAL_ERRORS']
V_EXPECT={'12V0':12,'3V3_STANDBY':3.3,'3V3_SI5395J':3.3,'1V8_SI5395J_XO2':1.8,'2V5_OSC_NE':2.5,'1V8_MGTVCCAUX_VUP_N':1.8,'2V5_OSC_NW':2.5,'2V5_OSC_K7':2.5,'1V2_MGTAVTT_K7':1.2,'1V0_MGTAVCC_K7':1.0,'0V675_DDRVTT':0.675,'1V35_DDR':1.35,'1V8_VCCAUX_K7':1.8,'2V5_OSC_SE':2.5,'1V8_MGTVCCAUX_VUP_S':1.8,'2V5_OSC_SW':2.5,'0V9_MGTAVCC_VUP_N':0.9,'1V8_VCCAUX_VUP':1.8,'1V0_VCCINT_K7':1.0,'1V2_MGTAVTT_VUP_N':1.2,'2V7_INTERMEDIATE':2.7,'0V9_MGTAVCC_VUP_S':0.9,'1V2_MGTAVTT_VUP_S':1.2}
# End of constants


def printRed(st):
    return "\033[91m"+st+"\033[0m"

def printGreen(st):
    return "\033[92m"+st+"\033[0m"

m=manager(optical_add_on_ver=2)
m.peripheral.autodetect_optics()
now = datetime.now()
c_time = now.strftime("%Y-%m-%d-%H-%M-%S")
f=open("./data/phys_data/pd_"+c_time+".csv","w")
o_str=""
for i in HEADERS:
    o_str+=i+","
f.write(o_str+"\n")
diff_flag = True
p_data = m.peripheral.monitor(verbose=False)

while(diff_flag):
    data = m.peripheral.monitor(verbose=False)
    diff_flag=False


    o_str=""
    err_cnt=0

    v_names=["12V0","3V3_STANDBY","3V3_SI5395J","1V8_SI5395J_XO2","2V5_OSC_NE","1V8_MGTVCCAUX_VUP_N","2V5_OSC_NW","2V5_OSC_K7","1V2_MGTAVTT_K7","1V0_MGTAVCC_K7","0V675_DDRVTT","1V35_DDR","1V8_VCCAUX_K7","2V5_OSC_SE","1V8_MGTVCCAUX_VUP_S","2V5_OSC_SW"]
    v_expected=[12,3.3,3.3,1.8,2.5,1.8,2.5,2.5,1.2,1.0,0.675,1.35,1.8,2.5,1.8,2.5]
    print("Voltages")
    for i in range(len(v_names)):
        v=data[v_names[i]]['V']
        if(v>p_data[v_names[i]]['V']*(1+STABILIZE_SENSITIVITY) or v<p_data[v_names[i]]['V']*(1-STABILIZE_SENSITIVITY)):
            diff_flag=True
        print(v_names[i],end=": ")
        if(v>v_expected[i]*1.05 or v<v_expected[i]*0.95):
            err_cnt+=1
            print(printRed(str(v)))
        else:
            print(printGreen(str(v)))
        o_str+=str(v)+","

    t_names=['1V2_MGTAVTT_VUP_S','1V2_MGTAVTT_VUP_S','KINTEX7','0V9_MGTAVCC_VUP_S','0V9_MGTAVCC_VUP_S','2V7_INTERMEDIATE','1V2_MGTAVTT_VUP_N','1V2_MGTAVTT_VUP_N','VIRTEXUPLUS','0V9_MGTAVCC_VUP_S','0V9_MGTAVCC_VUP_S']
    print("Temperatures")

    #write temp with 12
    print("0V85_VCCINT_VUP",end="")
    o_str+="0V85_VCCINT_VUP,"
    for i in range(6):
        t=data['0V85_VCCINT_VUP']['T'][i]
        print(", "+str(i)+": ",end="")
        if(t>p_data['0V85_VCCINT_VUP']['T'][i]*(1+STABILIZE_SENSITIVITY) or t<p_data['0V85_VCCINT_VUP']['T'][i]*(1-STABILIZE_SENSITIVITY)):
            diff_flag=True
        if(t>45):
            err_cnt+=1
            print(printRed(str(t)))
        else:
            print(printGreen(str(t)))
        o_str+=str(t)+","

    #write temp for rest
    for i in range(len(t_names)):
        tl=data[t_names[i]]['T'][0]
        tr=data[t_names[i]]['T'][1]
        if(tl>p_data[t_names[i]]['T'][0]*(1+STABILIZE_SENSITIVITY) or tl<p_data[t_names[i]]['T'][0]*(1-STABILIZE_SENSITIVITY)):
            diff_flag=True
        if(tr>p_data[t_names[i]]['T'][1]*(1+STABILIZE_SENSITIVITY) or tr<p_data[t_names[i]]['T'][1]*(1-STABILIZE_SENSITIVITY)):
            diff_flag=True
        print(t_names[i],end=", left: ")
        if(tl>45):
            err_cnt+=1
            print(printRed(str(tl)),end="")
        else:
            print(printGreen(str(tl)),end="")
        print(", right: ",end="")
        if(tr>45):
            err_cnt+=1
            print(printRed(str(tr)))
        else:
            print(printGreen(str(tr)))
        o_str+=str(tl)+","+str(tr)+","

    st=""
    st=st+"{0:20}".format("Device")+'\tV\t\t'+"I\t\t"+'P\t\t'+'T\n'
    for i in range(len(list(data.keys()))-1,0,-1):
        device = list(data.keys())[i]
        if device in ['optics']:
            continue
        st =st+ "{0:20}".format(device)
        if 'V' in data[device].keys():
            o_str+=str(data[device]['V'])+","
            if (data[device]['V']>V_EXPECT[device]*1.05 or data[device]['V']<V_EXPECT[device]*0.95):
                err_cnt+=1
                st+='\t'+printRed(str(round(data[device]['V'],3)))
            else:
                st+='\t'+printGreen(str(round(data[device]['V'],3)))
        else:
            st=st+'\t'+'         '

        if 'I' in data[device].keys():
            o_str+=str(data[device]['I'])+","
            st=st+'\t\t'+'{:+3.2f} A'.format(data[device]['I'])
        else:
            st=st+'\t\t'+'          '

        if 'P' in data[device].keys():
            o_str+=str(data[device]['P'])+","
            st=st+'\t\t'+'{:+3.2f} W'.format(data[device]['P'])
        else:
            st=st+'\t\t'+'          '

        if 'T' in data[device].keys():
            tstr=[]
            for t in data[device]['T']:
                o_str+=str(t)+","
                if t>45:
                    tstr+=printRed(str(t))+" C,"
                else:
                    tstr+=printGreen(str(t))+" C,"

            st=st+'\t\t'+','.join(tstr)
        st=st+'\n'

    st=st+'--------------------------------------------------------------------------------------------------------------\n'
    #OPTICS"
    if 'optics' in self.devices.keys() and len(self.devices['optics'].keys())>0:
        st=st+'----------------------------------------------OPTICS----------------------------------------------------------\n'
        st =st+ " cage {0:45}\t ".format("Type")+"{0:8}  ".format("V")+"{0:7} ".format("T")+" {0:4} ".format("RX")+" {0:4} ".format("TX")+" {0:5} ".format("RXCDR")+" {0:5} ".format("TXCDR")+" {0:12} ".format("RX Optical Power")+"\n"
        for cage,info in data['optics'].items():
            st =st+"{0:3}: ".format(str(cage))+ "{0:45}\t ".format(info['type'])+" {:2.3f} V".format(info['V'])+" {:+2.1f} C ".format(info['T'])+" {0:4} ".format(hex(info['rx_enabled']))+" {0:4} ".format(hex(info['tx_enabled']))+" {0:5} ".format(hex(info['rx_cdr']))+" {0:5} ".format(hex(info['tx_cdr']))+"  "','.join(info['rx_power'])+'\n'
        st=st+'--------------------------------------------------------------------------------------------------------------\n'

    #final outputs for read cycle
    o_str+=str(err_cnt)+"\n"
    if(err_cnt>0):
        printRed("Total Errors: "+str(err_cnt))
    else:
        printGreen("Total Errors: "+str(err_cnt))
    print("")
    print(st)
    f.write(o_str)
    p_data = data
    time.sleep(2)
f.close()
sum_f=open("./data/summary/s_"+c_time+".csv","w")
sum_f.write(o_str)
sum_f.close()

