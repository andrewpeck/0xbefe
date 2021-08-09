### ETH CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_gbe*XOUTCLK}]]  

### GBT TX / LHC CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan*gbt*TXOUTCLK}]]  

### GBT RX CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan*gbt*RXOUTCLK}]]  

### SLINK CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_slink_rocket/*QPLL0OUT*}]]  

### DAQ CLKS ### 
set_clock_groups -asynchronous -group [get_clocks clk_100_framework_clk_wiz_0_0]  

### IPB CLKS ### 
set_clock_groups -asynchronous -group [get_clocks clk_100_framework_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_50_framework_clk_wiz_0_0]  

### DEBUG CLK ###
set_clock_groups -asynchronous -group [get_clocks {dbg_hub/*}]
