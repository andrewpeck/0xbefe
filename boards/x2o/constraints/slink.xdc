# MGT location
set_property LOC GTYE4_CHANNEL_X1Y45 [get_cells -hierarchical -filter name=~i_slink_rocket/i_slink_sender/*GTYE4_CHANNEL_PRIM_INST]

set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ */Sender_core_i1*/resync_pulse*/reg_1st_stage*/C}] -to [get_pins -hierarchical -filter {NAME =~ */Sender_core_i1*/resync_pulse*/reg_2nd_stage_async*/D}] 2.000
set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ */*serdes_sender*/resync_pulse*/reg_1st_stage*/C}] -to [get_pins -hierarchical -filter {NAME =~ */*serdes_sender*/resync_pulse*/reg_2nd_stage_async*/D}] 2.000

set_false_path -to [get_pins -hier -filter {NAME=~ */Sender_core_i1/*resync*/reg_reg[*]/CLR}]
set_false_path -to [get_pins -hier -filter {NAME=~ */Sender_core_i1/*resync*/reg_reg[*]/PRE}]


set_false_path -to [get_pins -hier -filter {NAME=~ */*serdes_sender*/*resync*/reg_reg[*]/CLR}]
set_false_path -to [get_pins -hier -filter {NAME=~ */*serdes_sender*/*resync*/reg_reg[*]/PRE}]
set_false_path -to [get_pins -hier -filter {NAME=~ */*serdes_sender*/*resync*/reg_async_reg/D}]

#SERDES

set_false_path -from [get_pins -hierarchical -filter {NAME =~ */*serdes_sender_i1/*Align_serdes*/C}] -to [get_pins -hierarchical -filter {NAME =~ */Sender_core_i1/i1/Command_data_rd*[*]/D}]
set_false_path -from [get_pins -hierarchical -filter {NAME =~ */*serdes_sender_i1/Link_locked*/C}] -to [get_pins -hierarchical -filter {NAME =~ */Sender_core_i1/i1/Command_data_rd*[*]/D}]
set_false_path -from [get_pins -hierarchical -filter {NAME =~ */*serdes_sender_i1/STATE_link*/C}] -to [get_pins -hierarchical -filter {NAME =~ */Sender_core_i1/i1/Command_data_rd*[*]/D}]



#SlinkRocket logic

set_false_path -to [get_pins -hierarchical -filter {NAME =~ */Sender_core_i1/i1/status_data*[*]/R}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */Sender_core_i1/i1/status_data*[*]/D}]
set_false_path -from [get_pins -hierarchical -filter {NAME =~ */Sender_core_i1/i1/status_data*[*]/C}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */Sender_core_i1/i1/Command_data_rd*[*]/D}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */Sender_core_i1/i1/Command_data_rd*[*]/D}]


set_false_path -from [get_pins -hier -filter {NAME=~ */Sender_core_i1/i1/sel_test_mode_reg/C}]
set_false_path -from [get_pins -hier -filter {NAME=~ */Sender_core_i1/i1/LINKDOWN_cell_reg/C}]
set_false_path -from [get_pins -hier -filter {NAME=~ */Sender_core_i1/i1/freq_measure_i1/counter_measure_reg[*]/C}]


set_false_path -to [get_pins -hier -filter {NAME=~ */Sender_core_i1/i1/Command_data_rd_reg[*]/D}]
set_false_path -to [get_pins -hier -filter {NAME=~ */Sender_core_i1/i1/status_data_reg[*]/D}]