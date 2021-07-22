set c2c_clks [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_apex_c2c/*XOUTCLK}]]
set dmb_clks [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_dmb*XOUTCLK}]]
set eth_clks [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_gbe*XOUTCLK}]]
set gbt_clks [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan*gbt*XOUTCLK}]]
set slink_clks [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_slink_rocket/*QPLL0OUT*}]]
set daq_clks [get_clocks clk_out1_apex_blk_clk_wiz_0]
set slow_ctrl_clks [get_clocks clk_out2_apex_blk_clk_wiz_0]

set_clock_groups -asynchronous -group $c2c_clks -group $dmb_clks -group $eth_clks -group $gbt_clks -group $slink_clks -group $daq_clks -group $slow_ctrl_clks

set_clock_groups -asynchronous -group [get_clocks {dbg_hub/*}]

#set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter name=~*i_apex_c2c/*XOUTCLK]] -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter name=~*i_mgts/*TXOUTCLK]] -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter name=~*i_slink_rocket/*QPLL0OUT*]] -group [get_clocks clk_out1_apex_blk_clk_wiz_0] -group [get_clocks clk_out2_apex_blk_clk_wiz_0]