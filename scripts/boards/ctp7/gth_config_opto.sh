#!/bin/sh

gth_rst_ch0_base_addr=0x69000004
gth_ctrl_ch0_base_addr=0x69000008

gth_ctrl_addr=$gth_ctrl_ch0_base_addr
gth_rst_addr=$gth_rst_ch0_base_addr

# Regular GTH config/ctrl value:
# Bit 0: = 1, TX_PD: Transmitter powered down
# Bit 1: = 0, RX_PD: Receiver active
# Bit 2: = 0, TX_POLARITY: not inverted
# Bit 3: = 0, RX_POLARITY: not inverted
# Bit 4: = 0, LOOPBACK: not active
# Bit 5: = 1, TX_INHIBIT: TX laser deactived
# Bit 6: = 1, LPMEN: RX equalizer low power mode enabled!!

data_reg_ch=0x40

# Special, Ch#11 config/ctrl value:
# The same as above, with Bit 3 = 1 (RX polarity inverted)

data_ch_inverted=0x48

#configure all GTH channels
for i in $(seq 0 1 63)
do

	# Apply special inverted RX config for Ch#11, Ch#36, Ch#37
	if [ $i -eq 11 -o $i -eq 36 -o $i -eq 37 ]
	then

		printf "Applying special inverted RX channel config for GTH CH#$i...\n"
		mpoke $gth_ctrl_addr $data_ch_inverted
	else
		#printf "Normal config for $i\n"
		#Apply standard, regular channel config
		mpoke $gth_ctrl_addr $data_reg_ch
	fi

	#Move on to the next channel
	gth_ctrl_addr=$(($gth_ctrl_addr+256))

done

printf "Done with GTH channel configuration.\n"
