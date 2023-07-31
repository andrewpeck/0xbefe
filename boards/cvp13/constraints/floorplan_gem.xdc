# create SLR Pblocks
create_pblock PBLOCK_SLR0
resize_pblock PBLOCK_SLR0 -add SLR0
create_pblock PBLOCK_SLR1
resize_pblock PBLOCK_SLR1 -add SLR1
create_pblock PBLOCK_SLR2
resize_pblock PBLOCK_SLR2 -add SLR2
create_pblock PBLOCK_SLR3
resize_pblock PBLOCK_SLR3 -add SLR3

# soft SLR floorplan constraint
set_property -quiet USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet i_pcie]

# hard SLR floorplan constraint
set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet g_slrs[0]*]
add_cells_to_pblock -quiet PBLOCK_SLR2 [get_cells -quiet g_slrs[0]*]
set_property -quiet KEEP_HIERARCHY TRUE [get_cells -quiet g_slrs[1]*]
add_cells_to_pblock -quiet PBLOCK_SLR3 [get_cells -quiet g_slrs[1]*]
