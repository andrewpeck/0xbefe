#!/bin/sh

gth_prbs_sel_ch0_base_addr=0x6900000c

gth_prbs_sel_addr=$gth_prbs_sel_ch0_base_addr

for i in $(seq 0 1 63)
do
	# Reset both RX and TX GTH 
	mpoke $gth_prbs_sel_addr $1
	gth_prbs_sel_addr=$(($gth_prbs_sel_addr+256))
done

