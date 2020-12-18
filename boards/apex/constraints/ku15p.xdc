#general
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

##
## GTH refclks
##

# 226 (SCLKP2 / ACLKP2)
set_property PACKAGE_PIN AG12 [get_ports {gth_refclk0_p_i[0]}]
set_property PACKAGE_PIN AF10 [get_ports {gth_refclk1_p_i[0]}]
# 229 (SCLKP1 / ACLKP1)
set_property PACKAGE_PIN AA12 [get_ports {gth_refclk0_p_i[1]}]
set_property PACKAGE_PIN Y10 [get_ports {gth_refclk1_p_i[1]}]
# 232 (SCLKP0 / ACLKP0)
set_property PACKAGE_PIN R12 [get_ports {gth_refclk0_p_i[2]}]
set_property PACKAGE_PIN P10 [get_ports {gth_refclk1_p_i[2]}]

##
## GTY refclks
##

# 128 (SCLKP0 / ACLKP0)
set_property PACKAGE_PIN AD32 [get_ports {gty_refclk0_p_i[0]}]
set_property PACKAGE_PIN AC30 [get_ports {gty_refclk1_p_i[0]}]
# 131 (SCLKP1 / ACLKP1)
set_property PACKAGE_PIN V32 [get_ports {gty_refclk0_p_i[1]}]
set_property PACKAGE_PIN U30 [get_ports {gty_refclk1_p_i[1]}]
# 134 (SCLKP2 / ACLKP2)
set_property PACKAGE_PIN M32 [get_ports {gty_refclk0_p_i[2]}]
set_property PACKAGE_PIN L30 [get_ports {gty_refclk1_p_i[2]}]

######## C2C ########
set_property PACKAGE_PIN AN4  [get_ports c2c_rx_rxp]; # Q226 rx2
set_property PACKAGE_PIN AM10 [get_ports c2c_tx_txp]; # Q226 tx2

create_clock -name clk_250 -period 4 [get_ports gth_refclk1_p_i[0]]

set_false_path -from [get_clocks -of_objects [get_pins i_apex_c2c/clk_wiz/inst/mmcme4_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins {i_apex_c2c/axi_chip2chip_0_aurora8/inst/apex_blk_axi_chip2chip_0_aurora8_1_core_i/gt_wrapper_i/apex_blk_axi_chip2chip_0_aurora8_1_gt_i/inst/gen_gtwizard_gthe4_top.apex_blk_axi_chip2chip_0_aurora8_1_gt_gtwizard_gthe4_inst/gen_gtwizard_gthe4.gen_channel_container[3].gen_enabled_channel.gthe4_channel_wrapper_inst/channel_inst/gthe4_channel_gen.gen_gthe4_channel_inst[0].GTHE4_CHANNEL_PRIM_INST/TXOUTCLK}]]

############### timing ################
set_clock_groups -asynchronous -group [get_clocks {dbg_hub/*}]
set_clock_groups -asynchronous -group [get_clocks {clk_out2_apex_blk_clk_wiz_0}]
set_clock_groups -asynchronous -group [get_clocks {clk_out1_apex_blk_clk_wiz_0}]
set_clock_groups -asynchronous -group [get_clocks {clk_250}]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins -hier -filter {name=~*i_apex_c2c/*TXOUTCLK}]]
