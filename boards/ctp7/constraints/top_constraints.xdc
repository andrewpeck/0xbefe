
#---------------
set_property PACKAGE_PIN H29 [get_ports clk_200_diff_in_clk_n]

set_property IOSTANDARD LVDS [get_ports clk_200_diff_in_clk_p]
set_property IOSTANDARD LVDS [get_ports clk_200_diff_in_clk_n]

create_clock -period 5.000 [get_ports clk_200_diff_in_clk_p]

#---------------
#green
set_property PACKAGE_PIN A20 [get_ports {LEDs[0]}]
#orange
set_property PACKAGE_PIN B20 [get_ports {LEDs[1]}]

set_property IOSTANDARD LVCMOS18 [get_ports {LEDs[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LEDs[1]}]


# ==========================================================================


set_property PACKAGE_PIN AV30 [get_ports clk_40_ttc_n_i]

set_property IOSTANDARD LVDS [get_ports clk_40_ttc_p_i]
set_property IOSTANDARD LVDS [get_ports clk_40_ttc_n_i]

## create_clock -period 24.950 -name clk_40_ttc_p_i [get_ports clk_40_ttc_p_i]

## ~40.5 MHz (over-constrained)
create_clock -period 24.691 -name clk_40_ttc_p_i [get_ports clk_40_ttc_p_i]


set_property PACKAGE_PIN J26 [get_ports ttc_data_n_i]

set_property IOSTANDARD LVDS [get_ports ttc_data_p_i]
set_property IOSTANDARD LVDS [get_ports ttc_data_n_i]


set_false_path -from [get_clocks clk_out4_v7_bd_clk_wiz_0_0] -to [get_clocks clk_out3_v7_bd_clk_wiz_0_0]
set_false_path -from [get_clocks clk_out3_v7_bd_clk_wiz_0_0] -to [get_clocks clk_out4_v7_bd_clk_wiz_0_0]

####################### GT reference clock constraints #########################

create_clock -period 6.250 [get_ports {refclk_F_0_p_i[0]}]
create_clock -period 6.250 [get_ports {refclk_F_0_p_i[1]}]
create_clock -period 6.250 [get_ports {refclk_F_0_p_i[2]}]
create_clock -period 6.250 [get_ports {refclk_F_0_p_i[3]}]

create_clock -period 3.125 [get_ports {refclk_F_1_p_i[0]}]
create_clock -period 3.125 [get_ports {refclk_F_1_p_i[1]}]
create_clock -period 3.125 [get_ports {refclk_F_1_p_i[2]}]
create_clock -period 3.125 [get_ports {refclk_F_1_p_i[3]}]

#create_clock -period 6.250 [get_ports {refclk_B_0_p_i[0]}]
create_clock -period 6.250 [get_ports {refclk_B_0_p_i[1]}]
create_clock -period 6.250 [get_ports {refclk_B_0_p_i[2]}]
create_clock -period 6.250 [get_ports {refclk_B_0_p_i[3]}]

#create_clock -period 3.125 [get_ports {refclk_B_1_p_i[0]}]
create_clock -period 3.125 [get_ports {refclk_B_1_p_i[1]}]
create_clock -period 3.125 [get_ports {refclk_B_1_p_i[2]}]
create_clock -period 3.125 [get_ports {refclk_B_1_p_i[3]}]

################################ RefClk Location constraints #####################

set_property PACKAGE_PIN E10 [get_ports {refclk_F_0_p_i[0]}]
set_property PACKAGE_PIN N10 [get_ports {refclk_F_0_p_i[1]}]
set_property PACKAGE_PIN AF8 [get_ports {refclk_F_0_p_i[2]}]
set_property PACKAGE_PIN AR10 [get_ports {refclk_F_0_p_i[3]}]

set_property PACKAGE_PIN G10 [get_ports {refclk_F_1_p_i[0]}]
set_property PACKAGE_PIN R10 [get_ports {refclk_F_1_p_i[1]}]
set_property PACKAGE_PIN AH8 [get_ports {refclk_F_1_p_i[2]}]
set_property PACKAGE_PIN AT8 [get_ports {refclk_F_1_p_i[3]}]

#set_property PACKAGE_PIN AR35 [get_ports  {refclk_B_0_p_i[0]}]
set_property PACKAGE_PIN AF37 [get_ports {refclk_B_0_p_i[1]}]
set_property PACKAGE_PIN N35 [get_ports {refclk_B_0_p_i[2]}]
set_property PACKAGE_PIN E35 [get_ports {refclk_B_0_p_i[3]}]

#set_property PACKAGE_PIN AT37 [get_ports  {refclk_B_1_p_i[0]}]
set_property PACKAGE_PIN AH37 [get_ports {refclk_B_1_p_i[1]}]
set_property PACKAGE_PIN R35 [get_ports {refclk_B_1_p_i[2]}]
set_property PACKAGE_PIN G35 [get_ports {refclk_B_1_p_i[3]}]

################################ GTH2_CHANNEL Location constraints  #####################

################################################## CXPs ###################################################
set_property LOC GTHE2_CHANNEL_X1Y0 [get_cells {i_system/i_gth_wrapper/gen_gth_single[0].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y1 [get_cells {i_system/i_gth_wrapper/gen_gth_single[1].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y2 [get_cells {i_system/i_gth_wrapper/gen_gth_single[2].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y3 [get_cells {i_system/i_gth_wrapper/gen_gth_single[3].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y4 [get_cells {i_system/i_gth_wrapper/gen_gth_single[4].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y5 [get_cells {i_system/i_gth_wrapper/gen_gth_single[5].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y6 [get_cells {i_system/i_gth_wrapper/gen_gth_single[6].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y7 [get_cells {i_system/i_gth_wrapper/gen_gth_single[7].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y8 [get_cells {i_system/i_gth_wrapper/gen_gth_single[8].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y9 [get_cells {i_system/i_gth_wrapper/gen_gth_single[9].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y10 [get_cells {i_system/i_gth_wrapper/gen_gth_single[10].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y11 [get_cells {i_system/i_gth_wrapper/gen_gth_single[11].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y12 [get_cells {i_system/i_gth_wrapper/gen_gth_single[12].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y13 [get_cells {i_system/i_gth_wrapper/gen_gth_single[13].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y14 [get_cells {i_system/i_gth_wrapper/gen_gth_single[14].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y15 [get_cells {i_system/i_gth_wrapper/gen_gth_single[15].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y16 [get_cells {i_system/i_gth_wrapper/gen_gth_single[16].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y17 [get_cells {i_system/i_gth_wrapper/gen_gth_single[17].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y18 [get_cells {i_system/i_gth_wrapper/gen_gth_single[18].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y19 [get_cells {i_system/i_gth_wrapper/gen_gth_single[19].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y20 [get_cells {i_system/i_gth_wrapper/gen_gth_single[20].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y21 [get_cells {i_system/i_gth_wrapper/gen_gth_single[21].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y22 [get_cells {i_system/i_gth_wrapper/gen_gth_single[22].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y23 [get_cells {i_system/i_gth_wrapper/gen_gth_single[23].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y24 [get_cells {i_system/i_gth_wrapper/gen_gth_single[24].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y25 [get_cells {i_system/i_gth_wrapper/gen_gth_single[25].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y26 [get_cells {i_system/i_gth_wrapper/gen_gth_single[26].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y27 [get_cells {i_system/i_gth_wrapper/gen_gth_single[27].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y28 [get_cells {i_system/i_gth_wrapper/gen_gth_single[28].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y29 [get_cells {i_system/i_gth_wrapper/gen_gth_single[29].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y30 [get_cells {i_system/i_gth_wrapper/gen_gth_single[30].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y31 [get_cells {i_system/i_gth_wrapper/gen_gth_single[31].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y32 [get_cells {i_system/i_gth_wrapper/gen_gth_single[32].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y33 [get_cells {i_system/i_gth_wrapper/gen_gth_single[33].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y34 [get_cells {i_system/i_gth_wrapper/gen_gth_single[34].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y35 [get_cells {i_system/i_gth_wrapper/gen_gth_single[35].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y35 [get_cells {i_system/i_gth_wrapper/gen_gth_single[35].gen_gth_*/i_gthe2}]

################################################# MiniPODs ##################################################
set_property LOC GTHE2_CHANNEL_X1Y36 [get_cells {i_system/i_gth_wrapper/gen_gth_single[36].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y37 [get_cells {i_system/i_gth_wrapper/gen_gth_single[37].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y38 [get_cells {i_system/i_gth_wrapper/gen_gth_single[38].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X1Y39 [get_cells {i_system/i_gth_wrapper/gen_gth_single[39].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y39 [get_cells {i_system/i_gth_wrapper/gen_gth_single[40].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y38 [get_cells {i_system/i_gth_wrapper/gen_gth_single[41].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y37 [get_cells {i_system/i_gth_wrapper/gen_gth_single[42].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y36 [get_cells {i_system/i_gth_wrapper/gen_gth_single[43].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y35 [get_cells {i_system/i_gth_wrapper/gen_gth_single[44].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y34 [get_cells {i_system/i_gth_wrapper/gen_gth_single[45].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y33 [get_cells {i_system/i_gth_wrapper/gen_gth_single[46].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y32 [get_cells {i_system/i_gth_wrapper/gen_gth_single[47].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y31 [get_cells {i_system/i_gth_wrapper/gen_gth_single[48].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y30 [get_cells {i_system/i_gth_wrapper/gen_gth_single[49].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y29 [get_cells {i_system/i_gth_wrapper/gen_gth_single[50].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y28 [get_cells {i_system/i_gth_wrapper/gen_gth_single[51].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y27 [get_cells {i_system/i_gth_wrapper/gen_gth_single[52].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y26 [get_cells {i_system/i_gth_wrapper/gen_gth_single[53].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y25 [get_cells {i_system/i_gth_wrapper/gen_gth_single[54].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y24 [get_cells {i_system/i_gth_wrapper/gen_gth_single[55].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y23 [get_cells {i_system/i_gth_wrapper/gen_gth_single[56].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y22 [get_cells {i_system/i_gth_wrapper/gen_gth_single[57].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y21 [get_cells {i_system/i_gth_wrapper/gen_gth_single[58].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y20 [get_cells {i_system/i_gth_wrapper/gen_gth_single[59].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y19 [get_cells {i_system/i_gth_wrapper/gen_gth_single[60].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y18 [get_cells {i_system/i_gth_wrapper/gen_gth_single[61].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y17 [get_cells {i_system/i_gth_wrapper/gen_gth_single[62].gen_gth_*/i_gthe2}]
set_property LOC GTHE2_CHANNEL_X0Y16 [get_cells {i_system/i_gth_wrapper/gen_gth_single[63].gen_gth_*/i_gthe2}]
#set_property LOC GTHE2_CHANNEL_X0Y15 [get_cells {i_system/i_gth_wrapper/gen_gth_single[64].gen_gth_*/i_gthe2}]
#set_property LOC GTHE2_CHANNEL_X0Y14 [get_cells {i_system/i_gth_wrapper/gen_gth_single[65].gen_gth_*/i_gthe2}]
#set_property LOC GTHE2_CHANNEL_X0Y13 [get_cells {i_system/i_gth_wrapper/gen_gth_single[66].gen_gth_*/i_gthe2}]
#set_property LOC GTHE2_CHANNEL_X0Y12 [get_cells {i_system/i_gth_wrapper/gen_gth_single[67].gen_gth_*/i_gthe2}]


set_property LOC XADC_X0Y0 [get_cells i_system/i_v7_bd/xadc_wiz_0/U0/AXI_XADC_CORE_I/XADC_INST]


set_false_path -to [get_cells -hierarchical -filter {NAME =~ *sync*/data_sync_reg1}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *sync*/data_sync_reg1}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *sync*/data_sync_reg1}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *sync*/data_sync_reg1}]


#set_false_path -from [get_clocks -include_generated_clocks -of_objects [get_ports SYSCLK_IN]] -to [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*gt0_gth_single_i*gthe2_i*TXOUTCLK}]]
#set_false_path -from [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*gt0_gth_single_i*gthe2_i*TXOUTCLK}]] -to [get_clocks -include_generated_clocks -of_objects [get_ports SYSCLK_IN]]

#set_false_path -from [get_clocks -include_generated_clocks -of_objects [get_ports SYSCLK_IN]] -to [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*gt0_gth_single_i*gthe2_i*RXOUTCLK}]]
#set_false_path -from [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*gt0_gth_single_i*gthe2_i*RXOUTCLK}]] -to [get_clocks -include_generated_clocks -of_objects [get_ports SYSCLK_IN]]

########################################################################################################
################################################ CXP 0 #################################################
########################################################################################################

############# Channel [0] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[0].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[0].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [1] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[1].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[1].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [2] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[2].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[2].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [3] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[3].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[3].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [4] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[4].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[4].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [5] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[5].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[5].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [6] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[6].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[6].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [7] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[7].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[7].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [8] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[8].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[8].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [9] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[9].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[9].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [10] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[10].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[10].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [11] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[11].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[11].gen_gth_*/i_gthe2*RXOUTCLK}]

########################################################################################################
################################################ CXP 1 #################################################
########################################################################################################

############# Channel [12] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[12].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[12].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [13] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[13].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[13].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [14] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[14].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[14].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [15] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[15].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[15].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [16] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[16].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[16].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [17] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[17].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[17].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [18] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[18].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[18].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [19] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[19].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[19].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [20] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[20].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[20].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [21] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[21].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[21].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [22] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[22].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[22].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [23] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[23].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[23].gen_gth_*/i_gthe2*RXOUTCLK}]

########################################################################################################
################################################ CXP 2 #################################################
########################################################################################################

# for GBT links on CXP2:
############# Channel [24] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[24].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[24].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [25] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[25].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[25].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [26] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[26].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[26].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [27] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[27].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[27].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [28] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[28].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[28].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [29] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[29].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[29].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [30] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[30].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[30].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [31] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[31].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[31].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [32] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[32].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[32].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [33] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[33].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[33].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [34] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[34].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[34].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [35] - 4.8 Gbps TX, 4.8 Gbps RX #############
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[35].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 8.333 [get_pins -hier -filter {name=~*gen_gth_single[35].gen_gth_*/i_gthe2*RXOUTCLK}]


# for trigger on CXP2 (3.2gbps) use this:
############## Channel [24] - 3.2 Gbps TX, 3.2 Gbps RX #############
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[24].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[24].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [25] - 3.2 Gbps TX, 3.2 Gbps RX #############
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[25].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[25].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [26] - 3.2 Gbps TX, 3.2 Gbps RX #############
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[26].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[26].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [27] - 3.2 Gbps TX, 3.2 Gbps RX #############
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[27].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[27].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [28] - 3.2 Gbps TX, 3.2 Gbps RX #############
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[28].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[28].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [29] - 3.2 Gbps TX, 3.2 Gbps RX #############
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[29].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[29].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [30] - 3.2 Gbps TX, 3.2 Gbps RX #############
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[30].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[30].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [31] - 3.2 Gbps TX, 3.2 Gbps RX #############
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[31].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[31].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [32] - 3.2 Gbps TX, 3.2 Gbps RX #############
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[32].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[32].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [33] - 3.2 Gbps TX, 3.2 Gbps RX #############
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[33].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[33].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [34] - 3.2 Gbps TX, 3.2 Gbps RX #############
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[34].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[34].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [35] - 3.2 Gbps TX, 3.2 Gbps RX #############
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[35].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[35].gen_gth_*/i_gthe2*RXOUTCLK}]

########################################################################################################
################################################# MP2 ##################################################
########################################################################################################

############# Channel [36] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[36].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[36].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [37] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[37].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[37].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [38] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[38].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[38].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [39] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[39].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[39].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [40] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[40].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[40].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [41] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[41].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[41].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [42] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[42].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[42].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [43] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[43].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[43].gen_gth_*/i_gthe2*RXOUTCLK}]

#########################################################################################################
############################################## MP1 / MP TX ##############################################
#########################################################################################################

############# Channel [44] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[44].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[44].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [45] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[45].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[45].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [46] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[46].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[46].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [47] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[47].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[47].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [48] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[48].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[48].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [49] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[49].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[49].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [50] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[50].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[50].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [51] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[51].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[51].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [52] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[52].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[52].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [53] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[53].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[53].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [54] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[54].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[54].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [55] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[55].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[55].gen_gth_*/i_gthe2*RXOUTCLK}]

#########################################################################################################
############################################## MP0 / MP TX ##############################################
#########################################################################################################

############# Channel [56] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[56].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[56].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [57] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[57].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[57].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [58] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[58].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[58].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [59] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[59].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[59].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [60] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[60].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[60].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [61] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[61].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[61].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [62] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[62].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[62].gen_gth_*/i_gthe2*RXOUTCLK}]

############# Channel [63] - 10.24 Gbps TX, 3.2 Gbps RX #############
create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[63].gen_gth_*/i_gthe2*TXOUTCLK}]
create_clock -period 6.250 [get_pins -hier -filter {name=~*gen_gth_single[63].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [64] - 10.24 Gbps TX, 10.24 Gbps RX #############
#create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[64].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[64].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [65] - 10.24 Gbps TX, 10.24 Gbps RX #############
#create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[65].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[65].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [66] - 10.24 Gbps TX, 10.24 Gbps RX #############
#create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[66].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[66].gen_gth_*/i_gthe2*RXOUTCLK}]

############## Channel [67] - 10.24 Gbps TX, 10.24 Gbps RX #############
#create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[67].gen_gth_*/i_gthe2*TXOUTCLK}]
#create_clock -period 3.125 [get_pins -hier -filter {name=~*gen_gth_single[67].gen_gth_*/i_gthe2*RXOUTCLK}]


############# ############# ############# ############# ############# ############# #############
############# ############# False Path Constraints ############# ############# #############

set_clock_groups -asynchronous -group [get_clocks clk_40] -group [get_clocks clk_out2_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_80] -group [get_clocks clk_out2_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_160] -group [get_clocks clk_out2_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_320] -group [get_clocks clk_out2_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_120] -group [get_clocks clk_out2_v7_bd_clk_wiz_0_0]

set_clock_groups -asynchronous -group [get_clocks clk_40] -group [get_clocks clk_out3_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_80] -group [get_clocks clk_out3_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_160] -group [get_clocks clk_out3_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_320] -group [get_clocks clk_out3_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_120] -group [get_clocks clk_out3_v7_bd_clk_wiz_0_0]

set_clock_groups -asynchronous -group [get_clocks clk_40] -group [get_clocks clk_out1_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_80] -group [get_clocks clk_out1_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_160] -group [get_clocks clk_out1_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_320] -group [get_clocks clk_out1_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_120] -group [get_clocks clk_out1_v7_bd_clk_wiz_0_0]

set_clock_groups -asynchronous -group [get_clocks clk_40] -group [get_clocks clk_out4_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_80] -group [get_clocks clk_out4_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_160] -group [get_clocks clk_out4_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_320] -group [get_clocks clk_out4_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_120] -group [get_clocks clk_out4_v7_bd_clk_wiz_0_0]

set_clock_groups -asynchronous -group [get_clocks clk_40_ttc_p_i] -group [get_clocks clk_39p997]
set_clock_groups -asynchronous -group [get_clocks clk_40] -group [get_clocks clk_39p997]
set_clock_groups -asynchronous -group [get_clocks clk_80] -group [get_clocks clk_39p997]
set_clock_groups -asynchronous -group [get_clocks clk_160] -group [get_clocks clk_39p997]
set_clock_groups -asynchronous -group [get_clocks clk_320] -group [get_clocks clk_39p997]
set_clock_groups -asynchronous -group [get_clocks clk_120] -group [get_clocks clk_39p997]

#set_clock_groups -asynchronous -group [get_clocks i_gem/i_ttc/clk_40_ttc_p_i] -group [get_clocks clk_out2_v7_bd_clk_wiz_0_0]

set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].*/i_gthe2/?XOUTCLK}] -group [get_clocks clk_out4_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].*/i_gthe2/?XOUTCLK}] -group [get_clocks clk_out3_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].*/i_gthe2/?XOUTCLK}] -group [get_clocks clk_out2_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].*/i_gthe2/?XOUTCLK}] -group [get_clocks clk_39p997]
set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].*/i_gthe2/?XOUTCLK}] -group [get_clocks clk_160]
set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].*/i_gthe2/RXOUTCLK}] -group [get_clocks clk_40]
set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].*/i_gthe2/RXOUTCLK}] -group [get_clocks clk_320]
set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].*/i_gthe2/RXOUTCLK}] -group [get_clocks clk_120]
set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].*/i_gthe2/RXOUTCLK}] -group [get_clocks clkout0]

set_clock_groups -asynchronous -group [get_clocks clk_out2_v7_bd_clk_wiz_0_0] -group [get_clocks clkout0]
set_clock_groups -asynchronous -group [get_clocks clk_out3_v7_bd_clk_wiz_0_0] -group [get_clocks clkout0]
set_clock_groups -asynchronous -group [get_clocks clk_out4_v7_bd_clk_wiz_0_0] -group [get_clocks clkout0]

set_clock_groups -asynchronous -group [get_clocks clk_out1_v7_bd_clk_wiz_0_0] -group [get_clocks clk_out4_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_out2_v7_bd_clk_wiz_0_0] -group [get_clocks clk_out4_v7_bd_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_out3_v7_bd_clk_wiz_0_0] -group [get_clocks clk_out4_v7_bd_clk_wiz_0_0]

set_clock_groups -asynchronous -group [get_clocks {i_system/i_daqlink/gth_amc13_support_i/gth_amc13_init_i/U0/gth_amc13_1_i/gt0_gth_amc13_1_i/gthe2_i/?XOUTCLK}] -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].*/i_gthe2/?XOUTCLK}]
#set_clock_groups -asynchronous -group [get_clocks {i_system/i_daqlink/gth_amc13_support_i/gth_amc13_init_i/U0/gth_amc13_1_i/gt0_gth_amc13_1_i/gthe2_i/?XOUTCLK}] -group [get_clocks clk_160] 
set_clock_groups -asynchronous -group [get_clocks {i_system/i_daqlink/gth_amc13_support_i/gth_amc13_init_i/U0/gth_amc13_1_i/gt0_gth_amc13_1_i/gthe2_i/?XOUTCLK}] -group [get_clocks clk_40] 
set_clock_groups -asynchronous -group [get_clocks {i_system/i_daqlink/gth_amc13_support_i/gth_amc13_init_i/U0/gth_amc13_1_i/gt0_gth_amc13_1_i/gthe2_i/?XOUTCLK}] -group [get_clocks clk_out2_v7_bd_clk_wiz_0_0] 
set_clock_groups -asynchronous -group [get_clocks {i_system/i_daqlink/gth_amc13_support_i/gth_amc13_init_i/U0/gth_amc13_1_i/gt0_gth_amc13_1_i/gthe2_i/?XOUTCLK}] -group [get_clocks clk_out3_v7_bd_clk_wiz_0_0] 
set_clock_groups -asynchronous -group [get_clocks {i_system/i_daqlink/gth_amc13_support_i/gth_amc13_init_i/U0/gth_amc13_1_i/gt0_gth_amc13_1_i/gthe2_i/?XOUTCLK}] -group [get_clocks clk_out4_v7_bd_clk_wiz_0_0] 
set_clock_groups -asynchronous -group [get_clocks {i_system/i_daqlink/gth_amc13_support_i/gth_amc13_init_i/U0/gth_amc13_1_i/gt0_gth_amc13_1_i/gthe2_i/?XOUTCLK}] -group [get_clocks clkout0]

#mainly for GBT
#set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_3p2g*/i_gthe2*TXOUTCLK}] -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_4p8g*/i_gthe2*TXOUTCLK}]
#set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_3p2g*/i_gthe2*RXOUTCLK}] -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_4p8g*/i_gthe2*RXOUTCLK}]
set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_tx_10p24g_rx_3p2g*/i_gthe2*TXOUTCLK}] -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_4p8g*/i_gthe2*TXOUTCLK}]
set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_tx_10p24g_rx_3p2g*/i_gthe2*RXOUTCLK}] -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_4p8g*/i_gthe2*RXOUTCLK}]
set_clock_groups -asynchronous -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].*/i_gthe2*RXOUTCLK}] -group [get_clocks {i_system/i_gth_wrapper/gen_gth_single[*].*/i_gthe2*TXOUTCLK}]

set_max_delay 16 -from [get_pins -hier -filter {NAME =~ */*/*/scrambler/*/C}] -to [get_pins -hier -filter {NAME =~ */*/*/txGearbox/*/D}] -datapath_only
set_max_delay 16 -from [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].gbtTx/txPhaseMon/DONE*/C}] -to [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].i_sync_gearbox_align*FDE_INST/D}] -datapath_only
set_max_delay 16 -from [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].gbtTx/txPhaseMon/GOOD*/C}] -to [get_pins -hier -filter {NAME =~ */*/*gbtTx_gen[*].i_sync_gearbox_align*FDE_INST/D}] -datapath_only

#set_clock_groups -asynchronous -group [get_clocks clkout0] -group [get_clocks clk_40] #careful with this!
#set_false_path -from [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {i_system/i_gth_wrapper/gen_gth_single[*].gen_gth_4p8g*/i_gthe2*TXOUTCLK}]] -to [get_clocks clk_40]

############# ############# ############# ############# ############# ############# #############
############# ############# AMC13 GTH Constraints ############# ############# #############

set_property PACKAGE_PIN AL35 [get_ports amc13_gth_refclk_p]
create_clock -period 8.000 -name amc13_gth_refclk_p -waveform {0.000 4.000} [get_ports amc13_gth_refclk_p]
set_property LOC GTHE2_CHANNEL_X0Y9 [get_cells i_system/i_daqlink/gth_amc13_support_i/gth_amc13_init_i/U0/gth_amc13_1_i/gt0_gth_amc13_1_i/gthe2_i]

############# ############# ############# ############# ############# ############# #############
############# ############# ############# DEBUG CORES ############# ############# #############

