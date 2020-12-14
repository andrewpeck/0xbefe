
##############################################
################  Ref clocks  ################
##############################################

set_property PACKAGE_PIN AD11 [get_ports {qsfp_refclk0_p_i[0]}]
set_property PACKAGE_PIN Y11 [get_ports {qsfp_refclk0_p_i[1]}]
set_property PACKAGE_PIN H11 [get_ports {qsfp_refclk0_p_i[2]}]
set_property PACKAGE_PIN D11 [get_ports {qsfp_refclk0_p_i[3]}]

set_property PACKAGE_PIN AB11 [get_ports {qsfp_refclk1_p_i[0]}]
set_property PACKAGE_PIN V11 [get_ports {qsfp_refclk1_p_i[1]}]
set_property PACKAGE_PIN F11 [get_ports {qsfp_refclk1_p_i[2]}]
set_property PACKAGE_PIN B11 [get_ports {qsfp_refclk1_p_i[3]}]

create_clock -name qsfp3_refclk0 -period 6.250 [get_ports {qsfp_refclk0_p_i[0]}]
create_clock -name qsfp2_refclk0 -period 6.250 [get_ports {qsfp_refclk0_p_i[1]}]
create_clock -name qsfp1_refclk0 -period 6.250 [get_ports {qsfp_refclk0_p_i[2]}]
create_clock -name qsfp0_refclk0 -period 6.250 [get_ports {qsfp_refclk0_p_i[3]}]

create_clock -name qsfp3_refclk1 -period 3.125 [get_ports {qsfp_refclk1_p_i[0]}]
create_clock -name qsfp2_refclk1 -period 3.125 [get_ports {qsfp_refclk1_p_i[1]}]
create_clock -name qsfp1_refclk1 -period 3.125 [get_ports {qsfp_refclk1_p_i[2]}]
create_clock -name qsfp0_refclk1 -period 3.125 [get_ports {qsfp_refclk1_p_i[3]}]

##############################################
################  Location  ##################
##############################################

set_property LOC GTYE4_CHANNEL_X1Y32 [get_cells {i_mgts/g_channels[0].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y33 [get_cells {i_mgts/g_channels[1].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y34 [get_cells {i_mgts/g_channels[2].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y35 [get_cells {i_mgts/g_channels[3].g_chan_*/i_gty_channel}]

set_property LOC GTYE4_CHANNEL_X1Y36 [get_cells {i_mgts/g_channels[4].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y37 [get_cells {i_mgts/g_channels[5].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y38 [get_cells {i_mgts/g_channels[6].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y39 [get_cells {i_mgts/g_channels[7].g_chan_*/i_gty_channel}]

set_property LOC GTYE4_CHANNEL_X1Y48 [get_cells {i_mgts/g_channels[8].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y49 [get_cells {i_mgts/g_channels[9].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y50 [get_cells {i_mgts/g_channels[10].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y51 [get_cells {i_mgts/g_channels[11].g_chan_*/i_gty_channel}]

set_property LOC GTYE4_CHANNEL_X1Y52 [get_cells {i_mgts/g_channels[12].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y53 [get_cells {i_mgts/g_channels[13].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y54 [get_cells {i_mgts/g_channels[14].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y55 [get_cells {i_mgts/g_channels[15].g_chan_*/i_gty_channel}]

##############################################
################   outclk   ##################
##############################################

# QSFP0 (GBTX)
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[0].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[0].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[1].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[1].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[2].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[2].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[3].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[3].g_chan_*/i_gty_channel*RXOUTCLK}]

# QSFP1 (GBTX)
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[4].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[4].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[5].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[5].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[6].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[6].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[7].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[7].g_chan_*/i_gty_channel*RXOUTCLK}]

# QSFP2 (GBTX)
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[8].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[8].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[9].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[9].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[10].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[10].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[11].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[11].g_chan_*/i_gty_channel*RXOUTCLK}]

# QSFP3 (GBTX)
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[12].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[12].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[13].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[13].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[14].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[14].g_chan_*/i_gty_channel*RXOUTCLK}]

create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[15].g_chan_*/i_gty_channel*TXOUTCLK}]
create_clock -period 3.125 [get_pins -hier -filter {name=~*i_mgts/g_channels[15].g_chan_*/i_gty_channel*RXOUTCLK}]


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

#set_max_delay 16 -from [get_pins -hier -filter {NAME =~ */*/*/scrambler/*/C}] -to [get_pins -hier -filter {NAME =~ */*/*/txGearbox/*/D}] -datapath_only
#set_max_delay 16 -from [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].gbtTx/txPhaseMon/DONE*/C}] -to [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].i_sync_gearbox_align*FDE_INST/D}] -datapath_only
#set_max_delay 16 -from [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].gbtTx/txPhaseMon/GOOD*/C}] -to [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].i_sync_gearbox_align*FDE_INST/D}] -datapath_only
