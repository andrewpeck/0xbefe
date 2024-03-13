#!/bin/bash

NUM_QUEUES=5

cd /sys/bus/pci/devices/0000\:05\:00.0/qdma/
echo $NUM_QUEUES > qmax
cd ~evka/cvp13/dma_ip_drivers/QDMA/linux-kernel/bin
sudo ./dma-ctl qdma05000 q add list 0 $NUM_QUEUES mode st dir h2c
sudo ./dma-ctl qdma05000 q start list 0 $NUM_QUEUES dir h2c
