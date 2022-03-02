#!/bin/bash

if [ -z "$1" ]
  then
    echo "Usage: dd_daq.sh <output_filename>"
    exit
fi

sudo dd if=/dev/xdma0_c2h_0 of=$1 ibs=1M obs=1M status=progress
