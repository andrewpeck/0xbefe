#set lhc_clks [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*XOUTCLK}]]
set eth_clks [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_gbe*XOUTCLK}]]
set gbt_clks [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan*gbt*TXOUTCLK}]]
set gbt_link_rx_clks [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan*gbt*RXOUTCLK}]]
set slow_ctrl_clks [get_clocks {sysclk100 pcie_refclk_100 i_pcie/*TXOUTCLK}]

set_clock_groups -asynchronous -group $gbt_clks -group $gbt_link_rx_clks -group $eth_clks -group $slow_ctrl_clks

set_clock_groups -asynchronous -group [get_clocks {dbg_hub/*}]
