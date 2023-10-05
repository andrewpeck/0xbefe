#!/bin/bash

NUM_QUEUES=5

cd ~evka/cvp13/dma_ip_drivers/QDMA/linux-kernel/bin
sudo ./dma-ctl qdma05000 q stop list 0 $NUM_QUEUES dir h2c
sudo ./dma-ctl qdma05000 q del list 0 $NUM_QUEUES dir h2c
