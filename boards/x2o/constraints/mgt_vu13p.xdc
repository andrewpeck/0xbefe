###############################################################
####################### REFCLK0 (async) #######################
###############################################################

# --------- Quad 120: SI545_CLK+_0 (156.25MHz) ---------
set_property PACKAGE_PIN BD39 [get_ports {refclk0_p_i[0]}]
create_clock -period 6.400 -name mgt_refclk0_0 [get_ports {refclk0_p_i[0]}]
set_clock_groups -group [get_clocks mgt_refclk0_0] -asynchronous

# --------- Quad 121: SI545_CLK+_1 (156.25MHz) ---------
set_property PACKAGE_PIN BB39 [get_ports {refclk0_p_i[1]}]
create_clock -period 6.400 -name mgt_refclk0_1 [get_ports {refclk0_p_i[1]}]
set_clock_groups -group [get_clocks mgt_refclk0_1] -asynchronous

# --------- Quad 122: SI545_CLK+_2 (156.25MHz) ---------
set_property PACKAGE_PIN AY39 [get_ports {refclk0_p_i[2]}]
create_clock -period 6.400 -name mgt_refclk0_2 [get_ports {refclk0_p_i[2]}]
set_clock_groups -group [get_clocks mgt_refclk0_2] -asynchronous

# --------- Quad 123: SI545_CLK+_3 (156.25MHz) ---------
set_property PACKAGE_PIN AV39 [get_ports {refclk0_p_i[3]}]
create_clock -period 6.400 -name mgt_refclk0_3 [get_ports {refclk0_p_i[3]}]
set_clock_groups -group [get_clocks mgt_refclk0_3] -asynchronous

# --------- Quad 128: SI545_CLK+_8 (156.25MHz) ---------
set_property PACKAGE_PIN AE41 [get_ports {refclk0_p_i[4]}]
create_clock -period 6.400 -name mgt_refclk0_4 [get_ports {refclk0_p_i[4]}]
set_clock_groups -group [get_clocks mgt_refclk0_4] -asynchronous

# --------- Quad 129: SI545_CLK+_9 (156.25MHz) ---------
set_property PACKAGE_PIN AA41 [get_ports {refclk0_p_i[5]}]
create_clock -period 6.400 -name mgt_refclk0_5 [get_ports {refclk0_p_i[5]}]
set_clock_groups -group [get_clocks mgt_refclk0_5] -asynchronous

# --------- Quad 130: SI545_CLK+_10 (156.25MHz) ---------
set_property PACKAGE_PIN W41 [get_ports {refclk0_p_i[6]}]
create_clock -period 6.400 -name mgt_refclk0_6 [get_ports {refclk0_p_i[6]}]
set_clock_groups -group [get_clocks mgt_refclk0_6] -asynchronous

# --------- Quad 131: SI545_CLK+_11 (156.25MHz) ---------
set_property PACKAGE_PIN U41 [get_ports {refclk0_p_i[7]}]
create_clock -period 6.400 -name mgt_refclk0_7 [get_ports {refclk0_p_i[7]}]
set_clock_groups -group [get_clocks mgt_refclk0_7] -asynchronous

# --------- Quad 132: SI545_CLK+_12 (156.25MHz) ---------
set_property PACKAGE_PIN R41 [get_ports {refclk0_p_i[8]}]
create_clock -period 6.400 -name mgt_refclk0_8 [get_ports {refclk0_p_i[8]}]
set_clock_groups -group [get_clocks mgt_refclk0_8] -asynchronous

# --------- Quad 133: SI545_CLK+_13 (156.25MHz) ---------
set_property PACKAGE_PIN N41 [get_ports {refclk0_p_i[9]}]
create_clock -period 6.400 -name mgt_refclk0_9 [get_ports {refclk0_p_i[9]}]
set_clock_groups -group [get_clocks mgt_refclk0_9] -asynchronous

# --------- Quad 134: SI545_CLK+_14 (156.25MHz) ---------
set_property PACKAGE_PIN L41 [get_ports {refclk0_p_i[10]}]
create_clock -period 6.400 -name mgt_refclk0_10 [get_ports {refclk0_p_i[10]}]
set_clock_groups -group [get_clocks mgt_refclk0_10] -asynchronous

# --------- Quad 135: SI545_CLK+_15 (156.25MHz) ---------
set_property PACKAGE_PIN J41 [get_ports {refclk0_p_i[11]}]
create_clock -period 6.400 -name mgt_refclk0_11 [get_ports {refclk0_p_i[11]}]
set_clock_groups -group [get_clocks mgt_refclk0_11] -asynchronous

# --------- Quad 220: SI545_CLK+_16 (156.25MHz) ---------
set_property PACKAGE_PIN BD13 [get_ports {refclk0_p_i[12]}]
create_clock -period 6.400 -name mgt_refclk0_12 [get_ports {refclk0_p_i[12]}]
set_clock_groups -group [get_clocks mgt_refclk0_12] -asynchronous

# --------- Quad 221: SI545_CLK+_17 (156.25MHz) ---------
set_property PACKAGE_PIN BB13 [get_ports {refclk0_p_i[13]}]
create_clock -period 6.400 -name mgt_refclk0_13 [get_ports {refclk0_p_i[13]}]
set_clock_groups -group [get_clocks mgt_refclk0_13] -asynchronous

# --------- Quad 222: SI545_CLK+_18 (156.25MHz) ---------
set_property PACKAGE_PIN AY13 [get_ports {refclk0_p_i[14]}]
create_clock -period 6.400 -name mgt_refclk0_14 [get_ports {refclk0_p_i[14]}]
set_clock_groups -group [get_clocks mgt_refclk0_14] -asynchronous

# --------- Quad 223: SI545_CLK+_19 (156.25MHz) ---------
set_property PACKAGE_PIN AV13 [get_ports {refclk0_p_i[15]}]
create_clock -period 6.400 -name mgt_refclk0_15 [get_ports {refclk0_p_i[15]}]
set_clock_groups -group [get_clocks mgt_refclk0_15] -asynchronous

# --------- Quad 224: SI545_CLK+_20 (156.25MHz) ---------
set_property PACKAGE_PIN AT13 [get_ports {refclk0_p_i[16]}]
create_clock -period 6.400 -name mgt_refclk0_16 [get_ports {refclk0_p_i[16]}]
set_clock_groups -group [get_clocks mgt_refclk0_16] -asynchronous

# --------- Quad 225: SI545_CLK+_21 (156.25MHz) ---------
set_property PACKAGE_PIN AP13 [get_ports {refclk0_p_i[17]}]
create_clock -period 6.400 -name mgt_refclk0_17 [get_ports {refclk0_p_i[17]}]
set_clock_groups -group [get_clocks mgt_refclk0_17] -asynchronous

# --------- Quad 226: SI545_CLK+_22 (156.25MHz) ---------
set_property PACKAGE_PIN AM13 [get_ports {refclk0_p_i[18]}]
create_clock -period 6.400 -name mgt_refclk0_18 [get_ports {refclk0_p_i[18]}]
set_clock_groups -group [get_clocks mgt_refclk0_18] -asynchronous

# --------- Quad 227: SI545_CLK+_23 (156.25MHz) ---------
set_property PACKAGE_PIN AJ11 [get_ports {refclk0_p_i[19]}]
create_clock -period 6.400 -name mgt_refclk0_19 [get_ports {refclk0_p_i[19]}]
set_clock_groups -group [get_clocks mgt_refclk0_19] -asynchronous

# --------- Quad 228: SI545_CLK+_24 (156.25MHz) ---------
set_property PACKAGE_PIN AE11 [get_ports {refclk0_p_i[20]}]
create_clock -period 6.400 -name mgt_refclk0_20 [get_ports {refclk0_p_i[20]}]
set_clock_groups -group [get_clocks mgt_refclk0_20] -asynchronous

# --------- Quad 229: SI545_CLK+_25 (156.25MHz) ---------
set_property PACKAGE_PIN AA11 [get_ports {refclk0_p_i[21]}]
create_clock -period 6.400 -name mgt_refclk0_21 [get_ports {refclk0_p_i[21]}]
set_clock_groups -group [get_clocks mgt_refclk0_21] -asynchronous

# --------- Quad 230: SI545_CLK+_26 (156.25MHz) ---------
set_property PACKAGE_PIN W11 [get_ports {refclk0_p_i[22]}]
create_clock -period 6.400 -name mgt_refclk0_22 [get_ports {refclk0_p_i[22]}]
set_clock_groups -group [get_clocks mgt_refclk0_22] -asynchronous

# --------- Quad 231: SI545_CLK+_27 (156.25MHz) ---------
set_property PACKAGE_PIN U11 [get_ports {refclk0_p_i[23]}]
create_clock -period 6.400 -name mgt_refclk0_23 [get_ports {refclk0_p_i[23]}]
set_clock_groups -group [get_clocks mgt_refclk0_23] -asynchronous

# --------- Quad 232: SI545_CLK+_28 (156.25MHz) ---------
set_property PACKAGE_PIN R11 [get_ports {refclk0_p_i[24]}]
create_clock -period 6.400 -name mgt_refclk0_24 [get_ports {refclk0_p_i[24]}]
set_clock_groups -group [get_clocks mgt_refclk0_24] -asynchronous

# --------- Quad 233: SI545_CLK+_29 (156.25MHz) ---------
set_property PACKAGE_PIN N11 [get_ports {refclk0_p_i[25]}]
create_clock -period 6.400 -name mgt_refclk0_25 [get_ports {refclk0_p_i[25]}]
set_clock_groups -group [get_clocks mgt_refclk0_25] -asynchronous

# --------- Quad 234: SI545_CLK+_30 (156.25MHz) ---------
set_property PACKAGE_PIN L11 [get_ports {refclk0_p_i[26]}]
create_clock -period 6.400 -name mgt_refclk0_26 [get_ports {refclk0_p_i[26]}]
set_clock_groups -group [get_clocks mgt_refclk0_26] -asynchronous

# --------- Quad 235: SI545_CLK+_31 (156.25MHz) ---------
set_property PACKAGE_PIN J11 [get_ports {refclk0_p_i[27]}]
create_clock -period 6.400 -name mgt_refclk0_27 [get_ports {refclk0_p_i[27]}]
set_clock_groups -group [get_clocks mgt_refclk0_27] -asynchronous

###############################################################
####################### REFCLK1 (sync)  #######################
###############################################################

# --------- Quad 121: SI5395J_VU+_CLK+_0 (Si5395J out4, 160.00MHz) ---------
set_property PACKAGE_PIN BA41 [get_ports {refclk1_p_i[0]}]
create_clock -period 6.250 -name mgt_refclk1_0 [get_ports {refclk1_p_i[0]}]
set_clock_groups -group [get_clocks mgt_refclk1_0] -asynchronous

# --------- Quad 129: SI5395J_VU+_CLK+_2 (Si5395J out7, 160.00MHz) ---------
set_property PACKAGE_PIN Y39 [get_ports {refclk1_p_i[1]}]
create_clock -period 6.250 -name mgt_refclk1_1 [get_ports {refclk1_p_i[1]}]
set_clock_groups -group [get_clocks mgt_refclk1_1] -asynchronous

# --------- Quad 133: SI5395J_VU+_CLK+_3 (Si5395J out6, 160.00MHz) ---------
set_property PACKAGE_PIN M39 [get_ports {refclk1_p_i[2]}]
create_clock -period 6.250 -name mgt_refclk1_2 [get_ports {refclk1_p_i[2]}]
set_clock_groups -group [get_clocks mgt_refclk1_2] -asynchronous

# --------- Quad 221: SI5395J_VU+_CLK+_4 (Si5395J out0, 160.00MHz) ---------
set_property PACKAGE_PIN BA11 [get_ports {refclk1_p_i[3]}]
create_clock -period 6.250 -name mgt_refclk1_3 [get_ports {refclk1_p_i[3]}]
set_clock_groups -group [get_clocks mgt_refclk1_3] -asynchronous

# --------- Quad 225: SI5395J_VU+_CLK+_5 (Si5395J out1, 160.00MHz) ---------
set_property PACKAGE_PIN AN11 [get_ports {refclk1_p_i[4]}]
create_clock -period 6.250 -name mgt_refclk1_4 [get_ports {refclk1_p_i[4]}]
set_clock_groups -group [get_clocks mgt_refclk1_4] -asynchronous

# --------- Quad 229: SI5395J_VU+_CLK+_6 (Si5395J out2, 160.00MHz) ---------
set_property PACKAGE_PIN Y13 [get_ports {refclk1_p_i[5]}]
create_clock -period 6.250 -name mgt_refclk1_5 [get_ports {refclk1_p_i[5]}]
set_clock_groups -group [get_clocks mgt_refclk1_5] -asynchronous

# --------- Quad 233: SI5395J_VU+_CLK+_7 (Si5395J out3, 160.00MHz) ---------
set_property PACKAGE_PIN M13 [get_ports {refclk1_p_i[6]}]
create_clock -period 6.250 -name mgt_refclk1_6 [get_ports {refclk1_p_i[6]}]
set_clock_groups -group [get_clocks mgt_refclk1_6] -asynchronous

###############################################################
########################### MGT LOC ###########################
###############################################################

set_property LOC GTYE4_CHANNEL_X0Y0 [get_cells {i_mgts/g_channels[0].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y1 [get_cells {i_mgts/g_channels[1].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y2 [get_cells {i_mgts/g_channels[2].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y3 [get_cells {i_mgts/g_channels[3].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y4 [get_cells {i_mgts/g_channels[4].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y5 [get_cells {i_mgts/g_channels[5].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y6 [get_cells {i_mgts/g_channels[6].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y7 [get_cells {i_mgts/g_channels[7].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y8 [get_cells {i_mgts/g_channels[8].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y9 [get_cells {i_mgts/g_channels[9].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y10 [get_cells {i_mgts/g_channels[10].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y11 [get_cells {i_mgts/g_channels[11].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y12 [get_cells {i_mgts/g_channels[12].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y13 [get_cells {i_mgts/g_channels[13].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y14 [get_cells {i_mgts/g_channels[14].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y15 [get_cells {i_mgts/g_channels[15].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y32 [get_cells {i_mgts/g_channels[16].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y33 [get_cells {i_mgts/g_channels[17].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y34 [get_cells {i_mgts/g_channels[18].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y35 [get_cells {i_mgts/g_channels[19].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y36 [get_cells {i_mgts/g_channels[20].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y37 [get_cells {i_mgts/g_channels[21].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y38 [get_cells {i_mgts/g_channels[22].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y39 [get_cells {i_mgts/g_channels[23].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y40 [get_cells {i_mgts/g_channels[24].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y41 [get_cells {i_mgts/g_channels[25].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y42 [get_cells {i_mgts/g_channels[26].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y43 [get_cells {i_mgts/g_channels[27].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y44 [get_cells {i_mgts/g_channels[28].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y45 [get_cells {i_mgts/g_channels[29].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y46 [get_cells {i_mgts/g_channels[30].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y47 [get_cells {i_mgts/g_channels[31].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y48 [get_cells {i_mgts/g_channels[32].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y49 [get_cells {i_mgts/g_channels[33].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y50 [get_cells {i_mgts/g_channels[34].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y51 [get_cells {i_mgts/g_channels[35].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y52 [get_cells {i_mgts/g_channels[36].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y53 [get_cells {i_mgts/g_channels[37].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y54 [get_cells {i_mgts/g_channels[38].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y55 [get_cells {i_mgts/g_channels[39].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y56 [get_cells {i_mgts/g_channels[40].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y57 [get_cells {i_mgts/g_channels[41].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y58 [get_cells {i_mgts/g_channels[42].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y59 [get_cells {i_mgts/g_channels[43].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y60 [get_cells {i_mgts/g_channels[44].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y61 [get_cells {i_mgts/g_channels[45].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y62 [get_cells {i_mgts/g_channels[46].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X0Y63 [get_cells {i_mgts/g_channels[47].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y0 [get_cells {i_mgts/g_channels[48].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y1 [get_cells {i_mgts/g_channels[49].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y2 [get_cells {i_mgts/g_channels[50].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y3 [get_cells {i_mgts/g_channels[51].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y4 [get_cells {i_mgts/g_channels[52].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y5 [get_cells {i_mgts/g_channels[53].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y6 [get_cells {i_mgts/g_channels[54].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y7 [get_cells {i_mgts/g_channels[55].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y8 [get_cells {i_mgts/g_channels[56].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y9 [get_cells {i_mgts/g_channels[57].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y10 [get_cells {i_mgts/g_channels[58].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y11 [get_cells {i_mgts/g_channels[59].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y12 [get_cells {i_mgts/g_channels[60].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y13 [get_cells {i_mgts/g_channels[61].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y14 [get_cells {i_mgts/g_channels[62].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y15 [get_cells {i_mgts/g_channels[63].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y16 [get_cells {i_mgts/g_channels[64].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y17 [get_cells {i_mgts/g_channels[65].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y18 [get_cells {i_mgts/g_channels[66].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y19 [get_cells {i_mgts/g_channels[67].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y20 [get_cells {i_mgts/g_channels[68].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y21 [get_cells {i_mgts/g_channels[69].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y22 [get_cells {i_mgts/g_channels[70].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y23 [get_cells {i_mgts/g_channels[71].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y24 [get_cells {i_mgts/g_channels[72].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y25 [get_cells {i_mgts/g_channels[73].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y26 [get_cells {i_mgts/g_channels[74].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y27 [get_cells {i_mgts/g_channels[75].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y28 [get_cells {i_mgts/g_channels[76].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y29 [get_cells {i_mgts/g_channels[77].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y30 [get_cells {i_mgts/g_channels[78].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y31 [get_cells {i_mgts/g_channels[79].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y32 [get_cells {i_mgts/g_channels[80].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y33 [get_cells {i_mgts/g_channels[81].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y34 [get_cells {i_mgts/g_channels[82].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y35 [get_cells {i_mgts/g_channels[83].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y36 [get_cells {i_mgts/g_channels[84].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y37 [get_cells {i_mgts/g_channels[85].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y38 [get_cells {i_mgts/g_channels[86].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y39 [get_cells {i_mgts/g_channels[87].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y40 [get_cells {i_mgts/g_channels[88].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y41 [get_cells {i_mgts/g_channels[89].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y42 [get_cells {i_mgts/g_channels[90].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y43 [get_cells {i_mgts/g_channels[91].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y44 [get_cells {i_mgts/g_channels[92].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y45 [get_cells {i_mgts/g_channels[93].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y46 [get_cells {i_mgts/g_channels[94].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y47 [get_cells {i_mgts/g_channels[95].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y48 [get_cells {i_mgts/g_channels[96].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y49 [get_cells {i_mgts/g_channels[97].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y50 [get_cells {i_mgts/g_channels[98].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y51 [get_cells {i_mgts/g_channels[99].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y52 [get_cells {i_mgts/g_channels[100].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y53 [get_cells {i_mgts/g_channels[101].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y54 [get_cells {i_mgts/g_channels[102].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y55 [get_cells {i_mgts/g_channels[103].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y56 [get_cells {i_mgts/g_channels[104].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y57 [get_cells {i_mgts/g_channels[105].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y58 [get_cells {i_mgts/g_channels[106].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y59 [get_cells {i_mgts/g_channels[107].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y60 [get_cells {i_mgts/g_channels[108].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y61 [get_cells {i_mgts/g_channels[109].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y62 [get_cells {i_mgts/g_channels[110].g_chan_*/i_gty_channel}]
set_property LOC GTYE4_CHANNEL_X1Y63 [get_cells {i_mgts/g_channels[111].g_chan_*/i_gty_channel}]

###############################################################
########################## IBERT LOC ##########################
###############################################################

#set_property -dict [list C_GTS_USED X0Y0 C_QUAD_NUMBER_0 16'd120] [get_cells {i_mgts/g_channels[0].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y1 C_QUAD_NUMBER_0 16'd120] [get_cells {i_mgts/g_channels[1].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y2 C_QUAD_NUMBER_0 16'd120] [get_cells {i_mgts/g_channels[2].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y3 C_QUAD_NUMBER_0 16'd120] [get_cells {i_mgts/g_channels[3].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y4 C_QUAD_NUMBER_0 16'd121] [get_cells {i_mgts/g_channels[4].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y5 C_QUAD_NUMBER_0 16'd121] [get_cells {i_mgts/g_channels[5].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y6 C_QUAD_NUMBER_0 16'd121] [get_cells {i_mgts/g_channels[6].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y7 C_QUAD_NUMBER_0 16'd121] [get_cells {i_mgts/g_channels[7].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y8 C_QUAD_NUMBER_0 16'd122] [get_cells {i_mgts/g_channels[8].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y9 C_QUAD_NUMBER_0 16'd122] [get_cells {i_mgts/g_channels[9].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y10 C_QUAD_NUMBER_0 16'd122] [get_cells {i_mgts/g_channels[10].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y11 C_QUAD_NUMBER_0 16'd122] [get_cells {i_mgts/g_channels[11].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y12 C_QUAD_NUMBER_0 16'd123] [get_cells {i_mgts/g_channels[12].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y13 C_QUAD_NUMBER_0 16'd123] [get_cells {i_mgts/g_channels[13].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y14 C_QUAD_NUMBER_0 16'd123] [get_cells {i_mgts/g_channels[14].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y15 C_QUAD_NUMBER_0 16'd123] [get_cells {i_mgts/g_channels[15].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y32 C_QUAD_NUMBER_0 16'd128] [get_cells {i_mgts/g_channels[16].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y33 C_QUAD_NUMBER_0 16'd128] [get_cells {i_mgts/g_channels[17].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y34 C_QUAD_NUMBER_0 16'd128] [get_cells {i_mgts/g_channels[18].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y35 C_QUAD_NUMBER_0 16'd128] [get_cells {i_mgts/g_channels[19].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y36 C_QUAD_NUMBER_0 16'd129] [get_cells {i_mgts/g_channels[20].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y37 C_QUAD_NUMBER_0 16'd129] [get_cells {i_mgts/g_channels[21].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y38 C_QUAD_NUMBER_0 16'd129] [get_cells {i_mgts/g_channels[22].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y39 C_QUAD_NUMBER_0 16'd129] [get_cells {i_mgts/g_channels[23].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y40 C_QUAD_NUMBER_0 16'd130] [get_cells {i_mgts/g_channels[24].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y41 C_QUAD_NUMBER_0 16'd130] [get_cells {i_mgts/g_channels[25].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y42 C_QUAD_NUMBER_0 16'd130] [get_cells {i_mgts/g_channels[26].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y43 C_QUAD_NUMBER_0 16'd130] [get_cells {i_mgts/g_channels[27].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y44 C_QUAD_NUMBER_0 16'd131] [get_cells {i_mgts/g_channels[28].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y45 C_QUAD_NUMBER_0 16'd131] [get_cells {i_mgts/g_channels[29].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y46 C_QUAD_NUMBER_0 16'd131] [get_cells {i_mgts/g_channels[30].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y47 C_QUAD_NUMBER_0 16'd131] [get_cells {i_mgts/g_channels[31].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y48 C_QUAD_NUMBER_0 16'd132] [get_cells {i_mgts/g_channels[32].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y49 C_QUAD_NUMBER_0 16'd132] [get_cells {i_mgts/g_channels[33].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y50 C_QUAD_NUMBER_0 16'd132] [get_cells {i_mgts/g_channels[34].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y51 C_QUAD_NUMBER_0 16'd132] [get_cells {i_mgts/g_channels[35].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y52 C_QUAD_NUMBER_0 16'd133] [get_cells {i_mgts/g_channels[36].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y53 C_QUAD_NUMBER_0 16'd133] [get_cells {i_mgts/g_channels[37].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y54 C_QUAD_NUMBER_0 16'd133] [get_cells {i_mgts/g_channels[38].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y55 C_QUAD_NUMBER_0 16'd133] [get_cells {i_mgts/g_channels[39].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y56 C_QUAD_NUMBER_0 16'd134] [get_cells {i_mgts/g_channels[40].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y57 C_QUAD_NUMBER_0 16'd134] [get_cells {i_mgts/g_channels[41].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y58 C_QUAD_NUMBER_0 16'd134] [get_cells {i_mgts/g_channels[42].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y59 C_QUAD_NUMBER_0 16'd134] [get_cells {i_mgts/g_channels[43].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y60 C_QUAD_NUMBER_0 16'd135] [get_cells {i_mgts/g_channels[44].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y61 C_QUAD_NUMBER_0 16'd135] [get_cells {i_mgts/g_channels[45].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y62 C_QUAD_NUMBER_0 16'd135] [get_cells {i_mgts/g_channels[46].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X0Y63 C_QUAD_NUMBER_0 16'd135] [get_cells {i_mgts/g_channels[47].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y0 C_QUAD_NUMBER_0 16'd220] [get_cells {i_mgts/g_channels[48].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y1 C_QUAD_NUMBER_0 16'd220] [get_cells {i_mgts/g_channels[49].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y2 C_QUAD_NUMBER_0 16'd220] [get_cells {i_mgts/g_channels[50].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y3 C_QUAD_NUMBER_0 16'd220] [get_cells {i_mgts/g_channels[51].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y4 C_QUAD_NUMBER_0 16'd221] [get_cells {i_mgts/g_channels[52].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y5 C_QUAD_NUMBER_0 16'd221] [get_cells {i_mgts/g_channels[53].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y6 C_QUAD_NUMBER_0 16'd221] [get_cells {i_mgts/g_channels[54].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y7 C_QUAD_NUMBER_0 16'd221] [get_cells {i_mgts/g_channels[55].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y8 C_QUAD_NUMBER_0 16'd222] [get_cells {i_mgts/g_channels[56].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y9 C_QUAD_NUMBER_0 16'd222] [get_cells {i_mgts/g_channels[57].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y10 C_QUAD_NUMBER_0 16'd222] [get_cells {i_mgts/g_channels[58].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y11 C_QUAD_NUMBER_0 16'd222] [get_cells {i_mgts/g_channels[59].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y12 C_QUAD_NUMBER_0 16'd223] [get_cells {i_mgts/g_channels[60].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y13 C_QUAD_NUMBER_0 16'd223] [get_cells {i_mgts/g_channels[61].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y14 C_QUAD_NUMBER_0 16'd223] [get_cells {i_mgts/g_channels[62].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y15 C_QUAD_NUMBER_0 16'd223] [get_cells {i_mgts/g_channels[63].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y16 C_QUAD_NUMBER_0 16'd224] [get_cells {i_mgts/g_channels[64].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y17 C_QUAD_NUMBER_0 16'd224] [get_cells {i_mgts/g_channels[65].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y18 C_QUAD_NUMBER_0 16'd224] [get_cells {i_mgts/g_channels[66].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y19 C_QUAD_NUMBER_0 16'd224] [get_cells {i_mgts/g_channels[67].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y20 C_QUAD_NUMBER_0 16'd225] [get_cells {i_mgts/g_channels[68].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y21 C_QUAD_NUMBER_0 16'd225] [get_cells {i_mgts/g_channels[69].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y22 C_QUAD_NUMBER_0 16'd225] [get_cells {i_mgts/g_channels[70].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y23 C_QUAD_NUMBER_0 16'd225] [get_cells {i_mgts/g_channels[71].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y24 C_QUAD_NUMBER_0 16'd226] [get_cells {i_mgts/g_channels[72].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y25 C_QUAD_NUMBER_0 16'd226] [get_cells {i_mgts/g_channels[73].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y26 C_QUAD_NUMBER_0 16'd226] [get_cells {i_mgts/g_channels[74].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y27 C_QUAD_NUMBER_0 16'd226] [get_cells {i_mgts/g_channels[75].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y28 C_QUAD_NUMBER_0 16'd227] [get_cells {i_mgts/g_channels[76].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y29 C_QUAD_NUMBER_0 16'd227] [get_cells {i_mgts/g_channels[77].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y30 C_QUAD_NUMBER_0 16'd227] [get_cells {i_mgts/g_channels[78].g_insys_ibert.i_ibert/inst}]
set_property -dict [list C_GTS_USED X1Y31 C_QUAD_NUMBER_0 16'd227] [get_cells {i_mgts/g_channels[79].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y32 C_QUAD_NUMBER_0 16'd228] [get_cells {i_mgts/g_channels[80].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y33 C_QUAD_NUMBER_0 16'd228] [get_cells {i_mgts/g_channels[81].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y34 C_QUAD_NUMBER_0 16'd228] [get_cells {i_mgts/g_channels[82].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y35 C_QUAD_NUMBER_0 16'd228] [get_cells {i_mgts/g_channels[83].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y36 C_QUAD_NUMBER_0 16'd229] [get_cells {i_mgts/g_channels[84].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y37 C_QUAD_NUMBER_0 16'd229] [get_cells {i_mgts/g_channels[85].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y38 C_QUAD_NUMBER_0 16'd229] [get_cells {i_mgts/g_channels[86].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y39 C_QUAD_NUMBER_0 16'd229] [get_cells {i_mgts/g_channels[87].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y40 C_QUAD_NUMBER_0 16'd230] [get_cells {i_mgts/g_channels[88].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y41 C_QUAD_NUMBER_0 16'd230] [get_cells {i_mgts/g_channels[89].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y42 C_QUAD_NUMBER_0 16'd230] [get_cells {i_mgts/g_channels[90].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y43 C_QUAD_NUMBER_0 16'd230] [get_cells {i_mgts/g_channels[91].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y44 C_QUAD_NUMBER_0 16'd231] [get_cells {i_mgts/g_channels[92].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y45 C_QUAD_NUMBER_0 16'd231] [get_cells {i_mgts/g_channels[93].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y46 C_QUAD_NUMBER_0 16'd231] [get_cells {i_mgts/g_channels[94].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y47 C_QUAD_NUMBER_0 16'd231] [get_cells {i_mgts/g_channels[95].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y48 C_QUAD_NUMBER_0 16'd232] [get_cells {i_mgts/g_channels[96].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y49 C_QUAD_NUMBER_0 16'd232] [get_cells {i_mgts/g_channels[97].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y50 C_QUAD_NUMBER_0 16'd232] [get_cells {i_mgts/g_channels[98].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y51 C_QUAD_NUMBER_0 16'd232] [get_cells {i_mgts/g_channels[99].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y52 C_QUAD_NUMBER_0 16'd233] [get_cells {i_mgts/g_channels[100].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y53 C_QUAD_NUMBER_0 16'd233] [get_cells {i_mgts/g_channels[101].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y54 C_QUAD_NUMBER_0 16'd233] [get_cells {i_mgts/g_channels[102].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y55 C_QUAD_NUMBER_0 16'd233] [get_cells {i_mgts/g_channels[103].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y56 C_QUAD_NUMBER_0 16'd234] [get_cells {i_mgts/g_channels[104].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y57 C_QUAD_NUMBER_0 16'd234] [get_cells {i_mgts/g_channels[105].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y58 C_QUAD_NUMBER_0 16'd234] [get_cells {i_mgts/g_channels[106].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y59 C_QUAD_NUMBER_0 16'd234] [get_cells {i_mgts/g_channels[107].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y60 C_QUAD_NUMBER_0 16'd235] [get_cells {i_mgts/g_channels[108].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y61 C_QUAD_NUMBER_0 16'd235] [get_cells {i_mgts/g_channels[109].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y62 C_QUAD_NUMBER_0 16'd235] [get_cells {i_mgts/g_channels[110].g_insys_ibert.i_ibert/inst}]
#set_property -dict [list C_GTS_USED X1Y63 C_QUAD_NUMBER_0 16'd235] [get_cells {i_mgts/g_channels[111].g_insys_ibert.i_ibert/inst}]
