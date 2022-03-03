create_clock -period 6.400 -name c2c_mgt_clk -waveform {0.000 3.200} [get_ports c2c_mgt_clk_p]
set_property PACKAGE_PIN AM40 [get_ports c2c_mgt_clk_n]
set_property PACKAGE_PIN AM39 [get_ports c2c_mgt_clk_p]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_x2o_framework/ChipToChipPhy*XOUTCLK*}]]
set_clock_groups -asynchronous -group [get_clocks s_dclk]