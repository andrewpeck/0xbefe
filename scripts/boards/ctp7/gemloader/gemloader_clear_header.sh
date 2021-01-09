#!/bin/sh

base_addr=0x1f000000
current_addr=$base_addr

for i in $(seq 0 1 23)
do
	current_addr=$((base_addr+$i*4))
	printf "clearing address 0x%x\n" $current_addr
	poke $current_addr 0xffffffff
done
