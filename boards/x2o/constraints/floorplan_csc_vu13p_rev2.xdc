####################### SMALL VERSION -- everything in SLR1 #######################

set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {g_slrs[0]*}]]

# set_property USER_SLR_ASSIGNMENT SLR0 [get_cells -quiet [list {i_slink_rocket/g_channels[0]*}]]
# set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_slink_rocket/g_channels[1]*}]]
# set_property USER_SLR_ASSIGNMENT SLR2 [get_cells -quiet [list {i_slink_rocket/g_channels[2]*}]]
# set_property USER_SLR_ASSIGNMENT SLR3 [get_cells -quiet [list {i_slink_rocket/g_channels[3]*}]]

set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_x2o_framework*}]]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_axi_ipbus_bridge*}]]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_tcds2*}]]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_mgts*}]]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_board_system*}]]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_promless_cfeb*}]]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_promless_alct*}]]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_ttc_tx*}]]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {g_eth_switch*}]]

####################### NORMAL VERSION #######################

# TODO