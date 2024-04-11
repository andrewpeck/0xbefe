### DMB CLKS ###
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_dmb*XOUTCLK}]]

### ODMB57 CLKS ###
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_odmb57*RXOUTCLK}]]

### ETH CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_gbe.*XOUTCLK}]]  
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_10gbe.*XOUTCLK}]]  
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_25gbe.*XOUTCLK}]]  
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_gbe_tx_*TXOUTCLK}]]  
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_10gbe_tx_*TXOUTCLK}]]  

### GBT TX CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_odmb57*TXOUTCLK}]]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan*gbt*TXOUTCLK}]]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_tcds2/i_ttc_clks*CLKIN1}]]

### GBT RX CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan*gbt*RXOUTCLK}]]  

### SLINK CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_slink_rocket/*QPLL0OUT*}]] 

### DAQ CLKS ### 
set_clock_groups -asynchronous -group [get_clocks clk_100_framework_bd_clocks_0]  

### DEBUG CLK ###
set_clock_groups -asynchronous -group [get_clocks {dbg_hub/*}]

### IPB CLKS ### 
set_clock_groups -asynchronous -group [get_clocks clk_125_framework_bd_clocks_0]
set_clock_groups -asynchronous -group [get_clocks clk_100_framework_bd_clocks_0]
set_clock_groups -asynchronous -group [get_clocks clk_50_framework_bd_clocks_0]  
