####################### NORMAL VERSION -- PBLOCK BASED #######################
# # create per-SLR Pblocks for hard SLR floorplan constraints
# create_pblock PBLOCK_SLR0
# resize_pblock PBLOCK_SLR0 -add SLR0
# create_pblock PBLOCK_SLR1
# resize_pblock PBLOCK_SLR1 -add SLR1
# create_pblock PBLOCK_SLR2
# resize_pblock PBLOCK_SLR2 -add SLR2
# create_pblock PBLOCK_SLR3
# resize_pblock PBLOCK_SLR3 -add SLR3
# 
# # GEM user blocks
# # use for GE21
# #set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet g_slrs[0]*]
# #add_cells_to_pblock -quiet PBLOCK_SLR1 [get_cells -quiet g_slrs[0]*]
# 
# #set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet g_slrs[1]*]
# #add_cells_to_pblock -quiet PBLOCK_SLR3 [get_cells -quiet g_slrs[1]*]
# 
# # GEM user blocks
# # use for ME0
# set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet g_slrs[0]*]
# add_cells_to_pblock -quiet PBLOCK_SLR0 [get_cells -quiet g_slrs[0]*]
# 
# #set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet g_slrs[1]*]
# #add_cells_to_pblock -quiet PBLOCK_SLR3 [get_cells -quiet g_slrs[1]*]
# 
# # GEM user blocks
# # use for GE11
# #set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet g_slrs[0]*]
# #add_cells_to_pblock -quiet PBLOCK_SLR0 [get_cells -quiet g_slrs[0]*]
# #set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet g_slrs[1]*]
# #add_cells_to_pblock -quiet PBLOCK_SLR0 [get_cells -quiet g_slrs[1]*]
# #set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet g_slrs[2]*]
# #add_cells_to_pblock -quiet PBLOCK_SLR0 [get_cells -quiet g_slrs[2]*]
# #set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet g_slrs[3]*]
# #add_cells_to_pblock -quiet PBLOCK_SLR0 [get_cells -quiet g_slrs[3]*]
# 
# # System blocks
# set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet i_x2o_framework]
# add_cells_to_pblock -quiet PBLOCK_SLR1 [get_cells -quiet i_x2o_framework]
# 
# set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet i_axi_ipbus_bridge]
# add_cells_to_pblock -quiet PBLOCK_SLR1 [get_cells -quiet i_axi_ipbus_bridge]
# 
# set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet *i_tcds2]
# add_cells_to_pblock -quiet PBLOCK_SLR1 [get_cells -quiet *i_tcds2]
# 
# set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet i_board_system]
# add_cells_to_pblock -quiet PBLOCK_SLR1 [get_cells -quiet i_board_system]
# 
# set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet *i_promless]
# add_cells_to_pblock -quiet PBLOCK_SLR1 [get_cells -quiet *i_promless]
# 
# #set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet i_mgts/i_slow_control]
# #add_cells_to_pblock -quiet PBLOCK_SLR1 [get_cells -quiet i_mgts/i_slow_control]

####################### NORMAL VERSION #######################
 
#set_property USER_SLR_ASSIGNMENT SLR0 [get_cells -quiet [list {g_slrs[0]*}]]
#set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {g_slrs[1]*}]]
#set_property USER_SLR_ASSIGNMENT SLR2 [get_cells -quiet [list {g_slrs[2]*}]]
#set_property USER_SLR_ASSIGNMENT SLR3 [get_cells -quiet [list {g_slrs[3]*}]]

set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {g_slrs[0]*}]]
set_property USER_SLR_ASSIGNMENT SLR3 [get_cells -quiet [list {g_slrs[1]*}]]

#set_property USER_SLR_ASSIGNMENT SLR2 [get_cells -quiet [list {i_slink_rocket/g_channels[0]*}]]
#set_property USER_SLR_ASSIGNMENT SLR2 [get_cells -quiet [list {i_slink_rocket/g_channels[1]*}]]
# set_property USER_SLR_ASSIGNMENT SLR2 [get_cells -quiet [list {i_slink_rocket/g_channels[2]*}]]
# set_property USER_SLR_ASSIGNMENT SLR2 [get_cells -quiet [list {i_slink_rocket/g_channels[3]*}]]

set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_x2o_framework*}]]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_axi_ipbus_bridge*}]]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_tcds2*}]]
# set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_mgts*}]]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_board_system*}]]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {g_promless*}]]
#set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_ttc_tx*}]]
