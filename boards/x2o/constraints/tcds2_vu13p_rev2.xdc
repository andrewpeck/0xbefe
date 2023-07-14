################# MGT data signals #######################

# quad 124 ch0

set_property PACKAGE_PIN BA45 [get_ports tcds2_mgt_tx_p]
set_property PACKAGE_PIN BA46 [get_ports tcds2_mgt_rx_p]


# quad 125

#set_property PACKAGE_PIN AP43 [get_ports tcds2_mgt_tx_p]
#set_property PACKAGE_PIN AP48 [get_ports tcds2_mgt_rx_p]


# quad 126 HACK FOR TCDS IBERT 
#set_property PACKAGE_PIN AN45 [get_ports tcds2_mgt_tx_p]
#set_property PACKAGE_PIN AN50 [get_ports tcds2_mgt_rx_p]

############### clocks #################################

#### backplane LHC clock from DTH connected to quad 126 refclk1 ######

set_property PACKAGE_PIN AL41 [get_ports {tcds2_backplane_clk_p}]
create_clock -period 25.000 -name lhc_backplane_clk [get_ports {tcds2_backplane_clk_p}]
set_clock_groups -group [get_clocks lhc_backplane_clk] -asynchronous

#### output clocks to the LMK chip ########

set_property PACKAGE_PIN BB17 [get_ports {lmk_refclk_0_p}]
set_property PACKAGE_PIN BC17 [get_ports {lmk_refclk_0_n}]
set_property IOSTANDARD LVDS [get_ports {lmk_refclk_0_p}]
set_property IOSTANDARD LVDS [get_ports {lmk_refclk_0_n}]

set_property PACKAGE_PIN AY15 [get_ports {lmk_refclk_1_p}]
set_property PACKAGE_PIN BA15 [get_ports {lmk_refclk_1_n}]
set_property IOSTANDARD LVDS [get_ports {lmk_refclk_1_p}]
set_property IOSTANDARD LVDS [get_ports {lmk_refclk_1_n}]