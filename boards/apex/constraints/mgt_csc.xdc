
##############################################
################  Ref clocks  ################
##############################################

create_clock -period 6.250 -name gty_0_refclk0 [get_ports {gty_refclk0_p_i[0]}]
create_clock -period 6.250 -name gty_1_refclk0 [get_ports {gty_refclk0_p_i[1]}]
create_clock -period 6.250 -name gty_2_refclk0 [get_ports {gty_refclk0_p_i[2]}]

create_clock -period 6.400 -name gty_0_refclk1 [get_ports {gty_refclk1_p_i[0]}]
create_clock -period 6.400 -name gty_1_refclk1 [get_ports {gty_refclk1_p_i[1]}]
create_clock -period 6.400 -name gty_2_refclk1 [get_ports {gty_refclk1_p_i[2]}]

set_clock_groups -group [get_clocks gty_0_refclk0] -asynchronous
set_clock_groups -group [get_clocks gty_1_refclk0] -asynchronous
set_clock_groups -group [get_clocks gty_2_refclk0] -asynchronous

set_clock_groups -group [get_clocks gty_0_refclk1] -asynchronous
set_clock_groups -group [get_clocks gty_1_refclk1] -asynchronous
set_clock_groups -group [get_clocks gty_2_refclk1] -asynchronous

##############################################
################  Location  ##################
##############################################

### 127 ###
set_property LOC GTYE4_CHANNEL_X0Y0 [get_cells {i_mgts/g_channels[0].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y1 [get_cells {i_mgts/g_channels[1].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y2 [get_cells {i_mgts/g_channels[2].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y3 [get_cells {i_mgts/g_channels[3].g_chan_*/i_gty_channel}]

set_property -dict [list C_GTS_USED X0Y0 C_QUAD_NUMBER_0 16'd127] [get_cells {i_mgts/g_channels[0].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X0Y1 C_QUAD_NUMBER_0 16'd127] [get_cells {i_mgts/g_channels[1].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X0Y2 C_QUAD_NUMBER_0 16'd127] [get_cells {i_mgts/g_channels[2].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X0Y3 C_QUAD_NUMBER_0 16'd127] [get_cells {i_mgts/g_channels[3].g_insys_ibert.i_ibert/inst}]

### 131 ###
set_property LOC GTYE4_CHANNEL_X0Y16 [get_cells {i_mgts/g_channels[4].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y17 [get_cells {i_mgts/g_channels[5].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y18 [get_cells {i_mgts/g_channels[6].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y19 [get_cells {i_mgts/g_channels[7].g_chan_*/i_gty_channel}]

set_property -dict [list C_GTS_USED X0Y16 C_QUAD_NUMBER_0 16'd131] [get_cells {i_mgts/g_channels[4].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X0Y17 C_QUAD_NUMBER_0 16'd131] [get_cells {i_mgts/g_channels[5].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X0Y18 C_QUAD_NUMBER_0 16'd131] [get_cells {i_mgts/g_channels[6].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X0Y19 C_QUAD_NUMBER_0 16'd131] [get_cells {i_mgts/g_channels[7].g_insys_ibert.i_ibert/inst}]

### 130 ###
set_property LOC GTYE4_CHANNEL_X0Y12 [get_cells {i_mgts/g_channels[8].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y13 [get_cells {i_mgts/g_channels[9].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y14 [get_cells {i_mgts/g_channels[10].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y15 [get_cells {i_mgts/g_channels[11].g_chan_*/i_gty_channel}]

set_property -dict [list C_GTS_USED X0Y12 C_QUAD_NUMBER_0 16'd130] [get_cells {i_mgts/g_channels[8].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X0Y13 C_QUAD_NUMBER_0 16'd130] [get_cells {i_mgts/g_channels[9].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X0Y14 C_QUAD_NUMBER_0 16'd130] [get_cells {i_mgts/g_channels[10].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X0Y15 C_QUAD_NUMBER_0 16'd130] [get_cells {i_mgts/g_channels[11].g_insys_ibert.i_ibert/inst}]


### 128 ###
# set_property LOC GTYE4_CHANNEL_X0Y4 [get_cells {i_mgts/g_channels[0].g_chan_*/i_gty_channel}]
# set_property LOC GTYE4_CHANNEL_X0Y5 [get_cells {i_mgts/g_channels[1].g_chan_*/i_gty_channel}]
# set_property LOC GTYE4_CHANNEL_X0Y6 [get_cells {i_mgts/g_channels[2].g_chan_*/i_gty_channel}]
# set_property LOC GTYE4_CHANNEL_X0Y7 [get_cells {i_mgts/g_channels[3].g_chan_*/i_gty_channel}]

### 129 ###
# set_property LOC GTYE4_CHANNEL_X0Y8 [get_cells {i_mgts/g_channels[0].g_chan_*/i_gty_channel}]
# set_property LOC GTYE4_CHANNEL_X0Y9 [get_cells {i_mgts/g_channels[1].g_chan_*/i_gty_channel}]
# set_property LOC GTYE4_CHANNEL_X0Y10 [get_cells {i_mgts/g_channels[2].g_chan_*/i_gty_channel}]
# set_property LOC GTYE4_CHANNEL_X0Y11 [get_cells {i_mgts/g_channels[3].g_chan_*/i_gty_channel}]
# 
# set_property -dict [list C_GTS_USED X0Y8 C_QUAD_NUMBER_0 16'd129] [get_cells {i_mgts/g_channels[0].g_insys_ibert.i_ibert/inst}]
# set_property -dict [list C_GTS_USED X0Y9 C_QUAD_NUMBER_0 16'd129] [get_cells {i_mgts/g_channels[1].g_insys_ibert.i_ibert/inst}]
# set_property -dict [list C_GTS_USED X0Y10 C_QUAD_NUMBER_0 16'd129] [get_cells {i_mgts/g_channels[2].g_insys_ibert.i_ibert/inst}]
# set_property -dict [list C_GTS_USED X0Y11 C_QUAD_NUMBER_0 16'd129] [get_cells {i_mgts/g_channels[3].g_insys_ibert.i_ibert/inst}]


##############################################
################ False path ##################
##############################################

##############################################
################   GBTX   ##################
##############################################

set_max_delay 16 -from [get_pins -hier -filter {NAME =~ */*/*/scrambler/*/C}] -to [get_pins -hier -filter {NAME =~ */*/*/txGearbox/*/D}] -datapath_only
set_max_delay 16 -from [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].gbtTx/txPhaseMon/DONE*/C}] -to [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].i_sync_gearbox_align*FDE_INST/D}] -datapath_only
set_max_delay 16 -from [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].gbtTx/txPhaseMon/GOOD*/C}] -to [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].i_sync_gearbox_align*FDE_INST/D}] -datapath_only
