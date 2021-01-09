#!/bin/sh

base_addr=0x1f000000
current_addr=$base_addr

SIZE_BIT_FILE=$(stat -c %s $(readlink -f /mnt/persistent/gemdaq/oh_fw/optohybrid_top.bit) )

for i in $(seq 0 1 $SIZE_BIT_FILE)
do
	current_addr=$((base_addr+$i*4))
	printf "clearing address 0x%x\n" $current_addr
	poke $current_addr 0xffffffff
done
