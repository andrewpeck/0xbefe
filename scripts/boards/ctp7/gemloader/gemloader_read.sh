#!/bin/sh

base_addr=0x1f000000
current_addr=$base_addr

for i in $(seq 0 1 40)
do
	current_addr=$((base_addr+$i*4))
	printf "reading address 0x%x\n" $current_addr
	peek $current_addr
done
