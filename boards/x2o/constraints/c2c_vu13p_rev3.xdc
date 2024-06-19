create_clock -period 6.400 -name c2c_mgt_clk -waveform {0.000 3.200} [get_ports c2c_mgt_clk_p]

#quad 124 << this is used on rev2 with incorrect ARF6 cable connection
#NOTE: RX is inverted
#set_property PACKAGE_PIN AT39 [get_ports c2c_mgt_clk_p]

#quad 127 << this should be used on rev3 or rev2 with corrected ARF6 cable connection
# NOTE: no inversions
set_property PACKAGE_PIN AJ41 [get_ports c2c_mgt_clk_p]

#quad 126
#set_property PACKAGE_PIN AM39 [get_ports c2c_mgt_clk_p]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_x2o_framework/ChipToChipPhy*XOUTCLK*}]]
set_clock_groups -asynchronous -group [get_clocks s_dclk]