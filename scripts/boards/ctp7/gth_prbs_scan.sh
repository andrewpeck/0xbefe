#!/bin/sh

#this is intended to find fiber mapping when connected in loopback

prbs_sel_ch0_base_addr=0x6900000c
prbs_cnt_ch0_base_addr=0x69000010
test_ch=$1

prbs_sel_addr=$(($prbs_sel_ch0_base_addr + $test_ch * 256))
prbs_cnt_addr=$(($prbs_cnt_ch0_base_addr + $test_ch * 256))

sh gth_prbs_sel.sh 0x0 #switch off all TX PRBS

#enable PRBS on test channel rx
mpoke $prbs_sel_addr 0x1

prbs_sel_addr=$prbs_sel_ch0_base_addr

for i in $(seq 0 1 11)
do
	# Enable PRBS TX on each channel one by one, reset and print the error counter on the test channel
	mpoke $prbs_sel_addr 0x11
        mpoke $prbs_cnt_addr 0x1
        #sleep 1
        echo "ch $i:"
        mpeek $prbs_cnt_addr
	prbs_sel_addr=$(($prbs_sel_ch0_base_addr + $i * 256))
done

