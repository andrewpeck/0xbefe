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
set_property PACKAGE_PIN AN4 [get_ports c2c_rx_rxp]
set_property PACKAGE_PIN AM10 [get_ports c2c_tx_txp]

create_clock -period 4.000 -name clk_250 [get_ports {gth_refclk1_p_i[0]}]

