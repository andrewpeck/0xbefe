create_clock -period 24.8 -name clock   [get_ports clock_p]

set_property MAX_FANOUT 128 [get_nets -hierarchical -filter {name =~ "*i_ipb_reset_sync_usr_clk/s_resync[0]"}]

set_false_path -from [get_clocks] -to [get_ports elink_o_p]

set_false_path -from [get_ports {vfat_sot_*}] -to [get_pins -hierarchical -filter { NAME =~  "*trig_alignment/*oversample*/*ise1*/DDLY" }]
set_false_path -from [get_ports {vfat_sbits_*}] -to [get_pins -hierarchical -filter { NAME =~  "*trig_alignment/*oversample*/*ise1*/DDLY" }]
set_false_path -from [get_ports {elink_i_*}] -to [get_pins -hierarchical -filter { NAME =~  "*/*ise1*/DDLY" }]
set_false_path -from [get_ports {elink_i_*}] -to [get_pins -hierarchical -filter { NAME =~  "*/*ise1*/DDLY" }]

set_false_path -from [get_clocks] -to [get_pins -hierarchical -filter { NAME =~ "*/data_sync_reg1/D"}]

# The active clock pin of the launching sequential cell is called the path startpoint.
# The data input pin of the capturing sequential cell is called the path endpoint.
# For an input port path, the data path starts at the input port. The input port is the path startpoint.
# For an output port path, the data path ends at the output port. The output port is the path endpoint.

set_max_delay -from [get_pins -hierarchical -filter { NAME =~  "*iserdes_a7.iserdes/CLK" }] -to [get_pins -hierarchical -filter { NAME =~  "*dru/data_in_delay_reg*/D" }] 1.500
set_false_path -from [get_pins -hierarchical -filter { NAME =~  "*iserdes_a7.iserdes/CLK" }] -to [get_pins -hierarchical -filter { NAME =~  "*dru/data_in_delay_reg*/D" }]

# nothing important comes from the CFGMCLK
create_clock -period 24.0 -name CFGMCLK [get_pins control_inst/led_control_inst/startup/startup_gen_a7.startupe2_inst/CFGMCLK]
set_false_path -from [get_clocks CFGMCLK] -to [get_clocks *]
set_false_path -from [get_clocks  *     ] -to [get_clocks CFGMCLK]

create_clock -period 12.5 -name MGTREFCLK [get_ports {mgt_clk_p_i[0]}]

set_max_delay -datapath_only \
    -from [get_clocks *] \
    -to [get_pins -hierarchical -filter {NAME =~ *s_resync_reg*/D}] 2.5
