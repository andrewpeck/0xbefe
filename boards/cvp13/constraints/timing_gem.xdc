### ETH CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_gbe*XOUTCLK}]]  

### GBT TX / LHC CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan*gbt*TXOUTCLK}]]  

### GBT RX CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan*gbt*RXOUTCLK}]]  

### Slow Control & DAQ CLKS ### 
set_clock_groups -asynchronous -group [get_clocks {sysclk100 pcie_refclk_100 i_pcie/*TXOUTCLK}]

### DEBUG CLK ### 
set_clock_groups -asynchronous -group [get_clocks {dbg_hub/*}] 
