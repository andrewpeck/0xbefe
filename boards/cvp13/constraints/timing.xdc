set lhc_clks [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*XOUTCLK}]]
set slow_ctrl_clks [get_clocks {sysclk100 pcie_refclk_100 i_pcie/*TXOUTCLK}]

set_clock_groups -asynchronous -group $lhc_clks -group $slow_ctrl_clks

set_clock_groups -asynchronous -group [get_clocks {dbg_hub/*}]
