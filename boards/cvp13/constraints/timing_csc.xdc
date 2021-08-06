### DMB CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_dmb*XOUTCLK}]]
 
### ODMB57 CLKS ###
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_odmb57*RXOUTCLK}]]

### GBT TX CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_odmb57*TXOUTCLK}]]
#set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan*gbt*TXOUTCLK}]]
 
### ETH CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_gbe*XOUTCLK}]]
 
### Slow Control & DAQ CLKS ### 
set_clock_groups -asynchronous -group [get_clocks {sysclk100 pcie_refclk_100 i_pcie/*TXOUTCLK}]
 
### DEBUG CLK ### 
set_clock_groups -asynchronous -group [get_clocks {dbg_hub/*}] 
