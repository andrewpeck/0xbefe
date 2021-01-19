#!/bin/sh

echo "CTP7 Virtex-7 cold boot in progress..."

echo "Configuring reference clocks..."

# First initialize ref clocks before loading the V7 firmware (160 MHz refclk)
#clockinit 320_160 320_160 B1 A1 A1 B1
clockinit clkA_ttc_in_160p32_320p64_out_BW_HIGH.txt 320_160 A0 A0 A0 A0
#use for UCLA test stand (with no amc13)
#clockinit    clkA_125in_40p08_160p32_out.txt 320_160 A1 B1 B1 A1 

sleep 1

false
RETVAL=$?

while [ $RETVAL -ne 0 ]
do
    v7load gem_ctp7.bit
    RETVAL=$?
done

# Disable Opto TX Lasers
/bin/txpower enable

# Configure GTHs in loopback mode
sh gth_config_opto.sh

# GTH channel reset procedure
sh gth_reset.sh

#Print gth status register
sh gth_status.sh

