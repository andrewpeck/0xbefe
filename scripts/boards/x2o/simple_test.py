from board.manager import *
import sys
import re
import time

def printRed(st):
    print("\033[91m"+st+"\033[0m")

def printGreen(st):
    print("\033[92m"+st+"\033[0m")

m=manager(optical_add_on_ver=2)
m.peripheral.autodetect_optics()
f=open("log.csv","w")
diff_flag = True
p_data = m.peripheral.monitor()

while(diff_flag):
    data = m.peripheral.monitor()
    diff_flag=False


    o_str=""
    err_cnt=0

    v_names=["12V0","3V3_STANDBY","3V3_SI5395J","1V8_SI5395J_XO2","2V5_OSC_NE","1V8_MGTVCCAUX_VUP_N","2V5_OSC_NW","2V5_OSC_K7","1V2_MGTAVTT_K7","1V0_MGTAVCC_K7","0V675_DDRVTT","1V35_DDR","1V8_VCCAUX_K7","2V5_OSC_SE","1V8_MGTVCCAUX_VUP_S","2V5_OSC_SW"]
    v_expected=[12,3.3,3.3,1.8,2.5,1.8,2.5,2.5,1.2,1.0,0.675,1.35,1.8,2.5,1.8,2.5]
    print("Voltages")
    for i in range(len(v_names)):
        v=data[v_names[i]]['V']
        if(v>p_data[v_names[i]]['V']*1.05 or v<p_data[v_names[i]]['V']*0.95):
            diff_flag=True
        print(v_names[i],end=": ")
        if(v>v_expected[i]*1.05 or v<v_expected[i]*0.95):
            err_cnt+=1
            printRed(str(v))
        else:
            printGreen(str(v))
        o_str+=v_names[i]+","+str(v)+"\n"

    t_names=devs=['1V2_MGTAVTT_VUP_S','1V2_MGTAVTT_VUP_S','KINTEX7','0V9_MGTAVCC_VUP_S','0V9_MGTAVCC_VUP_S','2V7_INTERMEDIATE','1V2_MGTAVTT_VUP_N','1V2_MGTAVTT_VUP_N','VIRTEXUPLUS','0V9_MGTAVCC_VUP_S','0V9_MGTAVCC_VUP_S']
    print("Temperatures")
    for i in range(len(t_names)):
        t=data[t_names[i]]['T'][0]
        if(t>p_data[t_names[i]]['T']*1.05 or t<p_data[t_names[i]]['T']*0.95):
            diff_flag=True
        print(t_names[i],end=": ")
        if(t>45):
            err_cnt+=1
            printRed(str(t))
        else:
            printGreeen(str(t))
        o_str+=t_names[i]+","+str(t)+"\n"

    o_str+="Total Errors,"+str(err_cnt)+"\n"
    if(err_cnt>0):
        printRed("Total Errors: "+str(err_cnt))
    else:
        printGreen("Total Errors: "+str(err_cnt))
    f.write(o_str)
    p_data = data
    time.sleep(3)
f.close()
