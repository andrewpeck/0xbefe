import prbs
import optics
from board.manager import *
import tableformatter as tf
from common.utils import *
import time
import argparse
from common.rw_reg import *
from os import path
import struct
from common.fw_utils import *
import csv

DATA_DIR="/root/gem/0xbefe_test_10g/scripts/boards/x2o/data"
BITS=1000000000000
BITRATE=10000000000


now = datetime.now()
d_time = now.strftime("%Y-%m-%d")
isExist = os.path.exists(DATA_DIR+"/optics/"+d_time)
if not isExist:
   os.makedirs(DATA_DIR+"/optics/"+d_time)
isExist = os.path.exists(DATA_DIR+"/summary/"+d_time)
if not isExist:
   os.makedirs(DATA_DIR+"/summary/"+d_time)
run_num=1
filename=DATA_DIR+"/summary/"+d_time+"/"+d_time+"_"+str(run_num)+".csv"
full_f=DATA_DIR+"/optics/"+d_time+"/"+d_time+"_"+str(run_num)+".csv"
out_f=open(full_f,"w")
sum_f=open(filename,"a")


parse_xml()
qsfps = optics.x2o_get_qsfps()
links = befe_get_all_links(skip_usage_data=False)

for qsfp in qsfps:
    optics.x2o_disable_tx(qsfps[qsfp])

out_f.write("qsfp,chan mask, link, error\n")
err=0
for qsfp in qsfps:
    for mask in [0x1,0x2,0x4,0x8]:
        optics.x2o_enable_tx(qsfps[qsfp],mask)
        time.sleep(1)
        prbs.prbs_control(links,5)
        time.sleep(1)
        data=prbs.prbs_status(links)
        out=""
        out+=str(qsfp)+","+str(mask)+","
        link=False
        for row in data:
            if row[6]==0:
                out+=str(row[0])+","
                link=True
        if not link:
            err+=1
        out+="\n"
        print(out)
        out_f.write(out)
        optics.x2o_disable_tx(qsfps[qsfp])

for qsfp in qsfps:
    optics.x2o_enable_tx(qsfps[qsfp])

prbs.prbs_control(links,5)
time.sleep(BITS/BITRATE)
data=prbs.prbs_status(links)
prbs_err=0
for row in data:
    if row[6]!=0:
        prbs_err+=1
        print(row)
if prbs_err==0:
    print("PRBS test passed")
else:
    print("PRBS test failed")

sum_f.write("link error count:"+str(err)+"\n")
sum_f.write("prbs error count:"+str(prbs_err)+"\n")
sum_f.close()
