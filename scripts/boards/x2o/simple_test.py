from board.manager import *
import sys
import re
import time
from datetime import datetime


# Constants (to be moved to config file later)
STABILIZE_SENSITIVITY = 0.01

# End of constants


def printRed(st):
    print("\033[91m"+st+"\033[0m",end="")

def printGreen(st):
    print("\033[92m"+st+"\033[0m",end="")

m=manager(optical_add_on_ver=2)
m.peripheral.autodetect_optics()
now = datetime.now()
c_time = now.strftime("%Y-%m-%d-%H-%M-%S")
f=open("./data/phys_data/pd_"+c_time+".csv","w")
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
        if(v>p_data[v_names[i]]['V']*(1+STABILIZE_SENSITIVITY) or v<p_data[v_names[i]]['V']*(1-STABILIZE_SENSITIVITY)):
            diff_flag=True
        print(v_names[i],end=": ")
        if(v>v_expected[i]*1.05 or v<v_expected[i]*0.95):
            err_cnt+=1
            printRed(str(v))
            print("")
        else:
            printGreen(str(v))
            print("")
        o_str+=v_names[i]+","+str(v)+"\n"

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
            printRed(str(t))
        else:
            printGreen(str(t))
        o_str+=str(t)+","
    o_str+="\n"
    print("")

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
            printRed(str(tl))
        else:
            printGreen(str(tl))
        print(", right: ",end="")
        if(tr>45):
            err_cnt+=1
            printRed(str(tr))
        else:
            printGreen(str(tr))
        print("")
        o_str+=t_names[i]+","+str(tl)+","+str(tr)+"\n"

    #final outputs for read cycle
    o_str+="Total Errors,"+str(err_cnt)+"\n"
    if(err_cnt>0):
        printRed("Total Errors: "+str(err_cnt))
    else:
        printGreen("Total Errors: "+str(err_cnt))
    print("")
    f.write(o_str)
    p_data = data
    time.sleep(2)
f.close()
sum_f=open("./data/summary/s_"+c_time+".csv","w")
sum_f.write(o_str)
sum_f.close()

