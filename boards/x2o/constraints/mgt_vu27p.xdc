###############################################################
####################### REFCLK0 (async) #######################
###############################################################

# --------- Quad 224: SI545_CLK+_20 (156.25MHz) ---------
set_property PACKAGE_PIN AT13 [get_ports {refclk0_p_i[0]}]
create_clock -period 6.400 -name mgt_refclk0_0 [get_ports {refclk0_p_i[0]}]
set_clock_groups -group [get_clocks mgt_refclk0_0] -asynchronous

# --------- Quad 225: SI545_CLK+_21 (156.25MHz) ---------
set_property PACKAGE_PIN AP13 [get_ports {refclk0_p_i[1]}]
create_clock -period 6.400 -name mgt_refclk0_1 [get_ports {refclk0_p_i[1]}]
set_clock_groups -group [get_clocks mgt_refclk0_1] -asynchronous

# --------- Quad 226: SI545_CLK+_22 (156.25MHz) ---------
set_property PACKAGE_PIN AM13 [get_ports {refclk0_p_i[2]}]
create_clock -period 6.400 -name mgt_refclk0_2 [get_ports {refclk0_p_i[2]}]
set_clock_groups -group [get_clocks mgt_refclk0_2] -asynchronous

# --------- Quad 227: SI545_CLK+_23 (156.25MHz) ---------
set_property PACKAGE_PIN AJ11 [get_ports {refclk0_p_i[3]}]
create_clock -period 6.400 -name mgt_refclk0_3 [get_ports {refclk0_p_i[3]}]
set_clock_groups -group [get_clocks mgt_refclk0_3] -asynchronous

###############################################################
####################### REFCLK1 (sync)  #######################
###############################################################

# --------- Quad 225: SI5395J_VU+_CLK+_5 (Si5395J out1, 160.00MHz) ---------
set_property PACKAGE_PIN AN11 [get_ports {refclk1_p_i[0]}]
create_clock -period 6.250 -name mgt_refclk1_0 [get_ports {refclk1_p_i[0]}]
set_clock_groups -group [get_clocks mgt_refclk1_0] -asynchronous

###############################################################
########################### MGT LOC ###########################
###############################################################

set_property LOC GTYE4_CHANNEL_X1Y0 [get_cells {i_mgts/g_channels[0].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y1 [get_cells {i_mgts/g_channels[1].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y2 [get_cells {i_mgts/g_channels[2].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y3 [get_cells {i_mgts/g_channels[3].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y4 [get_cells {i_mgts/g_channels[4].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y5 [get_cells {i_mgts/g_channels[5].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y6 [get_cells {i_mgts/g_channels[6].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y7 [get_cells {i_mgts/g_channels[7].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y8 [get_cells {i_mgts/g_channels[8].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y9 [get_cells {i_mgts/g_channels[9].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y10 [get_cells {i_mgts/g_channels[10].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y11 [get_cells {i_mgts/g_channels[11].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y12 [get_cells {i_mgts/g_channels[12].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y13 [get_cells {i_mgts/g_channels[13].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y14 [get_cells {i_mgts/g_channels[14].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y15 [get_cells {i_mgts/g_channels[15].g_chan_*/i_gty_channel}]

###############################################################
########################## IBERT LOC ##########################
###############################################################

set_property -dict [list C_GTS_USED X1Y0 C_QUAD_NUMBER_0 16'd224] [get_cells {i_mgts/g_channels[0].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y1 C_QUAD_NUMBER_0 16'd224] [get_cells {i_mgts/g_channels[1].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y2 C_QUAD_NUMBER_0 16'd224] [get_cells {i_mgts/g_channels[2].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y3 C_QUAD_NUMBER_0 16'd224] [get_cells {i_mgts/g_channels[3].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y4 C_QUAD_NUMBER_0 16'd225] [get_cells {i_mgts/g_channels[4].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y5 C_QUAD_NUMBER_0 16'd225] [get_cells {i_mgts/g_channels[5].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y6 C_QUAD_NUMBER_0 16'd225] [get_cells {i_mgts/g_channels[6].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y7 C_QUAD_NUMBER_0 16'd225] [get_cells {i_mgts/g_channels[7].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y8 C_QUAD_NUMBER_0 16'd226] [get_cells {i_mgts/g_channels[8].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y9 C_QUAD_NUMBER_0 16'd226] [get_cells {i_mgts/g_channels[9].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y10 C_QUAD_NUMBER_0 16'd226] [get_cells {i_mgts/g_channels[10].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y11 C_QUAD_NUMBER_0 16'd226] [get_cells {i_mgts/g_channels[11].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y12 C_QUAD_NUMBER_0 16'd227] [get_cells {i_mgts/g_channels[12].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y13 C_QUAD_NUMBER_0 16'd227] [get_cells {i_mgts/g_channels[13].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y14 C_QUAD_NUMBER_0 16'd227] [get_cells {i_mgts/g_channels[14].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y15 C_QUAD_NUMBER_0 16'd227] [get_cells {i_mgts/g_channels[15].g_insys_ibert.i_ibert/inst}]
