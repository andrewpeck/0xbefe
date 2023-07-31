# create_pblock pcie
# add_cells_to_pblock [get_pblocks pcie] [get_cells -quiet [list {i_pcie*}]]
# resize_pblock [get_pblocks pcie] -add {CLOCKREGION_X3Y4:CLOCKREGION_X7Y7}

# create_pblock gem
# add_cells_to_pblock [get_pblocks gem] [get_cells -quiet [list {i_gem*}]]
# resize_pblock [get_pblocks gem] -add {CLOCKREGION_X3Y8:CLOCKREGION_X7Y11}

set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet [list {i_pcie*}]]

#set_property USER_SLR_ASSIGNMENT SLR2 [get_cells -quiet [list {g_slrs[0]*}]]
#set_property USER_SLR_ASSIGNMENT SLR3 [get_cells -quiet [list {g_slrs[1]*}]]

create_pblock gem
add_cells_to_pblock [get_pblocks gem] [get_cells -quiet [list {g_slrs[0]*}]]
resize_pblock [get_pblocks gem] -add {CLOCKREGION_X0Y8:CLOCKREGION_X7Y11}

# create pblocks 1/2/3/4
#for {set i 0} {$i < $num_slrs} {incr i} {
#    set pblock PBLOCK_SLR_$i
#    delete_pblock -quiet [get_pblocks $pblock]
#    create_pblock $pblock
#    resize_pblock -add [get_slrs SLR$i] $pblock
#}

#set SLR_INN PBLOCK_SLR_1
#set SLR_MID PBLOCK_SLR_2
#set SLR_OUT PBLOCK_SLR_3
#set SLR_EXT PBLOCK_SLR_0
