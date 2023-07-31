### ETH CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_gbe.*XOUTCLK}]]  
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_10gbe.*XOUTCLK}]]  
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_gbe_tx_*TXOUTCLK}]]  
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan_10gbe_tx_*TXOUTCLK}]]  

### GBT TX / LHC CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan*gbt*TXOUTCLK}]]  

### GBT RX CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_mgts/*g_chan*gbt*RXOUTCLK}]]  

### SLINK CLKS ### 
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_slink_rocket/*QPLL0OUT*}]]  

### DAQ CLKS ### 
set_clock_groups -asynchronous -group [get_clocks clk_out1_apex_blk_clk_wiz_0]  

### IPB CLKS ### 
set_clock_groups -asynchronous -group [get_clocks clk_out2_apex_blk_clk_wiz_0]  

### C2C clocks ###
create_clock -period 5 -name c2c_txclk0 [get_pins -filter {REF_PIN_NAME=~*TXOUTCLK} -of_objects [get_cells -hierarchical -filter {NAME =~ *i_apex_c2c_mgt*gen_gthe4_channel_inst[0]*GTHE4_CHANNEL_PRIM_INST*}]];
create_clock -period 5 -name c2c_txclk1 [get_pins -filter {REF_PIN_NAME=~*TXOUTCLK} -of_objects [get_cells -hierarchical -filter {NAME =~ *i_apex_c2c_mgt*gen_gthe4_channel_inst[1]*GTHE4_CHANNEL_PRIM_INST*}]];

create_clock -period 5 -name c2c_rxclk0 [get_pins -filter {REF_PIN_NAME=~*RXOUTCLK} -of_objects [get_cells -hierarchical -filter {NAME =~ *i_apex_c2c_mgt*gen_gthe4_channel_inst[0]*GTHE4_CHANNEL_PRIM_INST*}]];
create_clock -period 5 -name c2c_rxclk1 [get_pins -filter {REF_PIN_NAME=~*RXOUTCLK} -of_objects [get_cells -hierarchical -filter {NAME =~ *i_apex_c2c_mgt*gen_gthe4_channel_inst[1]*GTHE4_CHANNEL_PRIM_INST*}]];

set_clock_groups -group [get_clocks -include_generated_clocks c2c_txclk0 ] -asynchronous
set_clock_groups -group [get_clocks -include_generated_clocks c2c_txclk1 ] -asynchronous

set_clock_groups -group [get_clocks -include_generated_clocks c2c_rxclk0 ] -asynchronous
set_clock_groups -group [get_clocks -include_generated_clocks c2c_rxclk1 ] -asynchronous


#set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter name=~*i_apex_c2c/*XOUTCLK]] -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter name=~*i_mgts/*TXOUTCLK]] -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter name=~*i_slink_rocket/*QPLL0OUT*]] -group [get_clocks clk_out1_apex_blk_clk_wiz_0] -group [get_clocks clk_out2_apex_blk_clk_wiz_0]

### DEBUG CLK ###
set_clock_groups -asynchronous -group [get_clocks {dbg_hub/*}]
