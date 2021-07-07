
##############################################
################  Ref clocks  ################
##############################################

create_clock -period 6.250 -name gty_0_refclk0 [get_ports {gty_refclk0_p_i[0]}]
create_clock -period 6.250 -name gty_1_refclk0 [get_ports {gty_refclk0_p_i[1]}]
create_clock -period 6.250 -name gty_2_refclk0 [get_ports {gty_refclk0_p_i[2]}]

create_clock -period 5.000 -name gty_0_refclk1 [get_ports {gty_refclk1_p_i[0]}]
create_clock -period 3.103 -name gty_1_refclk1 [get_ports {gty_refclk1_p_i[1]}]
create_clock -period 5.000 -name gty_2_refclk1 [get_ports {gty_refclk1_p_i[2]}]

set_clock_groups -group [get_clocks gty_0_refclk0] -asynchronous
set_clock_groups -group [get_clocks gty_1_refclk0] -asynchronous
set_clock_groups -group [get_clocks gty_2_refclk0] -asynchronous

set_clock_groups -group [get_clocks gty_0_refclk1] -asynchronous
set_clock_groups -group [get_clocks gty_1_refclk1] -asynchronous
set_clock_groups -group [get_clocks gty_2_refclk1] -asynchronous

##############################################
################  Location  ##################
##############################################

set_property LOC GTYE4_CHANNEL_X0Y4 [get_cells {i_mgts/g_channels[0].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y5 [get_cells {i_mgts/g_channels[1].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y6 [get_cells {i_mgts/g_channels[2].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y7 [get_cells {i_mgts/g_channels[3].g_chan_*/i_gty_channel}]

set_property LOC GTYE4_CHANNEL_X0Y8 [get_cells {i_mgts/g_channels[4].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y9 [get_cells {i_mgts/g_channels[5].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y10 [get_cells {i_mgts/g_channels[6].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y11 [get_cells {i_mgts/g_channels[7].g_chan_*/i_gty_channel}]

set_property LOC GTYE4_CHANNEL_X0Y16 [get_cells {i_mgts/g_channels[8].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y17 [get_cells {i_mgts/g_channels[9].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y18 [get_cells {i_mgts/g_channels[10].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y19 [get_cells {i_mgts/g_channels[11].g_chan_*/i_gty_channel}]

#set_property LOC GTYE4_CHANNEL_X0Y8 [get_cells {i_mgts/g_channels[0].g_chan_*/i_gty_channel}]
#set_property LOC GTYE4_CHANNEL_X0Y9 [get_cells {i_mgts/g_channels[1].g_chan_*/i_gty_channel}]
#set_property LOC GTYE4_CHANNEL_X0Y10 [get_cells {i_mgts/g_channels[2].g_chan_*/i_gty_channel}]
#set_property LOC GTYE4_CHANNEL_X0Y11 [get_cells {i_mgts/g_channels[3].g_chan_*/i_gty_channel}]
#
#set_property LOC GTYE4_CHANNEL_X0Y12 [get_cells {i_mgts/g_channels[4].g_chan_*/i_gty_channel}]
#set_property LOC GTYE4_CHANNEL_X0Y13 [get_cells {i_mgts/g_channels[5].g_chan_*/i_gty_channel}]
#set_property LOC GTYE4_CHANNEL_X0Y14 [get_cells {i_mgts/g_channels[6].g_chan_*/i_gty_channel}]
#set_property LOC GTYE4_CHANNEL_X0Y15 [get_cells {i_mgts/g_channels[7].g_chan_*/i_gty_channel}]
#
#set_property LOC GTYE4_CHANNEL_X0Y16 [get_cells {i_mgts/g_channels[8].g_chan_*/i_gty_channel}]
#set_property LOC GTYE4_CHANNEL_X0Y17 [get_cells {i_mgts/g_channels[9].g_chan_*/i_gty_channel}]
#set_property LOC GTYE4_CHANNEL_X0Y18 [get_cells {i_mgts/g_channels[10].g_chan_*/i_gty_channel}]
#set_property LOC GTYE4_CHANNEL_X0Y19 [get_cells {i_mgts/g_channels[11].g_chan_*/i_gty_channel}]
#
#set_property LOC GTYE4_CHANNEL_X0Y20 [get_cells {i_mgts/g_channels[12].g_chan_*/i_gty_channel}]
#set_property LOC GTYE4_CHANNEL_X0Y21 [get_cells {i_mgts/g_channels[13].g_chan_*/i_gty_channel}]
#set_property LOC GTYE4_CHANNEL_X0Y22 [get_cells {i_mgts/g_channels[14].g_chan_*/i_gty_channel}]
#set_property LOC GTYE4_CHANNEL_X0Y23 [get_cells {i_mgts/g_channels[15].g_chan_*/i_gty_channel}]

##############################################
################   outclk   ##################
##############################################

# QSFP0 (GBE)
create_clock -period 16.000 [get_pins -hier -filter {name=~*i_mgts/g_channels[0].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 16.000 [get_pins -hier -filter {name=~*i_mgts/g_channels[0].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 16.000 [get_pins -hier -filter {name=~*i_mgts/g_channels[1].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 16.000 [get_pins -hier -filter {name=~*i_mgts/g_channels[1].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 16.000 [get_pins -hier -filter {name=~*i_mgts/g_channels[2].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 16.000 [get_pins -hier -filter {name=~*i_mgts/g_channels[2].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 16.000 [get_pins -hier -filter {name=~*i_mgts/g_channels[3].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 16.000 [get_pins -hier -filter {name=~*i_mgts/g_channels[3].g_chan_*/i_gty_channel*RXOUTCLK}]

# QSFP1 (GBTX)
create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[4].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[4].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[5].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[5].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[6].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[6].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[7].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[7].g_chan_*/i_gty_channel*RXOUTCLK}]

# QSFP2 (GBTX)
create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[8].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[8].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[9].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[9].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[10].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[10].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[11].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[11].g_chan_*/i_gty_channel*RXOUTCLK}]

## QSFP2 (GBTX)
#create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[8].g_chan_*/i_gty_channel*TXOUTCLK}]
#create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[8].g_chan_*/i_gty_channel*RXOUTCLK}]
#
#create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[9].g_chan_*/i_gty_channel*TXOUTCLK}]
#create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[9].g_chan_*/i_gty_channel*RXOUTCLK}]
#
#create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[10].g_chan_*/i_gty_channel*TXOUTCLK}]
#create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[10].g_chan_*/i_gty_channel*RXOUTCLK}]
#
#create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[11].g_chan_*/i_gty_channel*TXOUTCLK}]
#create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[11].g_chan_*/i_gty_channel*RXOUTCLK}]
#
## QSFP3 (GBTX)
#create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[12].g_chan_*/i_gty_channel*TXOUTCLK}]
#create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[12].g_chan_*/i_gty_channel*RXOUTCLK}]
#
#create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[13].g_chan_*/i_gty_channel*TXOUTCLK}]
#create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[13].g_chan_*/i_gty_channel*RXOUTCLK}]
#
#create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[14].g_chan_*/i_gty_channel*TXOUTCLK}]
#create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[14].g_chan_*/i_gty_channel*RXOUTCLK}]
#
#create_clock -period 6.250 [get_pins -hier -filter {name=~*i_mgts/g_channels[15].g_chan_*/i_gty_channel*TXOUTCLK}]
#create_clock -period 8.333 [get_pins -hier -filter {name=~*i_mgts/g_channels[15].g_chan_*/i_gty_channel*RXOUTCLK}]


##############################################
################ False path ##################
##############################################

#set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_3p2g*/i_gthe2*TXOUTCLK}] -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_4p8g*/i_gthe2*TXOUTCLK}]
#set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_3p2g*/i_gthe2*RXOUTCLK}] -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_4p8g*/i_gthe2*RXOUTCLK}]
#set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_tx_10p24g_rx_3p2g*/i_gthe2*TXOUTCLK}] -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_4p8g*/i_gthe2*TXOUTCLK}]
#set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_tx_10p24g_rx_3p2g*/i_gthe2*RXOUTCLK}] -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_4p8g*/i_gthe2*RXOUTCLK}]

##############################################
################   GBTX   ##################
##############################################

set_max_delay 16 -from [get_pins -hier -filter {NAME =~ */*/*/scrambler/*/C}] -to [get_pins -hier -filter {NAME =~ */*/*/txGearbox/*/D}] -datapath_only
set_max_delay 16 -from [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].gbtTx/txPhaseMon/DONE*/C}] -to [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].i_sync_gearbox_align*FDE_INST/D}] -datapath_only
set_max_delay 16 -from [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].gbtTx/txPhaseMon/GOOD*/C}] -to [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].i_sync_gearbox_align*FDE_INST/D}] -datapath_only
