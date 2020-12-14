set_property C_CLK_INPUT_FREQ_HZ 322265625 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER true [get_debug_cores dbg_hub]

set_clock_groups -group [get_clocks qsfp0_refclk0 -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks qsfp1_refclk0 -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks qsfp2_refclk0 -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks qsfp3_refclk0 -include_generated_clocks] -asynchronous

set_clock_groups -group [get_clocks qsfp0_refclk1 -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks qsfp1_refclk1 -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks qsfp2_refclk1 -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks qsfp3_refclk1 -include_generated_clocks] -asynchronous

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[0].u_q/CH[0].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[0].u_q/CH[0].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[0].u_q/CH[1].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[0].u_q/CH[1].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[0].u_q/CH[2].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[0].u_q/CH[2].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[0].u_q/CH[3].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[0].u_q/CH[3].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[1].u_q/CH[0].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[1].u_q/CH[0].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[1].u_q/CH[1].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[1].u_q/CH[1].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[1].u_q/CH[2].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[1].u_q/CH[2].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[1].u_q/CH[3].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[1].u_q/CH[3].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[2].u_q/CH[0].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[2].u_q/CH[0].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[2].u_q/CH[1].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[2].u_q/CH[1].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[2].u_q/CH[2].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[2].u_q/CH[2].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[2].u_q/CH[3].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[2].u_q/CH[3].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[3].u_q/CH[0].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[3].u_q/CH[0].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[3].u_q/CH[1].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[3].u_q/CH[1].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[3].u_q/CH[2].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[3].u_q/CH[2].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[3].u_q/CH[3].u_ch/u_gtye4_channel/RXOUTCLK}] -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {i_ibert/inst/QUAD[3].u_q/CH[3].u_ch/u_gtye4_channel/TXOUTCLK}] -include_generated_clocks]

set_property LOC GTYE4_CHANNEL_X1Y32 [get_cells i_ibert/inst/QUAD[0].u_q/CH[0].u_ch/u_gtye4_channel]
set_property LOC GTYE4_CHANNEL_X1Y33 [get_cells i_ibert/inst/QUAD[0].u_q/CH[1].u_ch/u_gtye4_channel]
set_property LOC GTYE4_CHANNEL_X1Y34 [get_cells i_ibert/inst/QUAD[0].u_q/CH[2].u_ch/u_gtye4_channel]
set_property LOC GTYE4_CHANNEL_X1Y35 [get_cells i_ibert/inst/QUAD[0].u_q/CH[3].u_ch/u_gtye4_channel]
set_property LOC GTYE4_COMMON_X1Y8 [get_cells i_ibert/inst/QUAD[0].u_q/u_common/u_gtye4_common]
set_property LOC GTYE4_CHANNEL_X1Y36 [get_cells i_ibert/inst/QUAD[1].u_q/CH[0].u_ch/u_gtye4_channel]
set_property LOC GTYE4_CHANNEL_X1Y37 [get_cells i_ibert/inst/QUAD[1].u_q/CH[1].u_ch/u_gtye4_channel]
set_property LOC GTYE4_CHANNEL_X1Y38 [get_cells i_ibert/inst/QUAD[1].u_q/CH[2].u_ch/u_gtye4_channel]
set_property LOC GTYE4_CHANNEL_X1Y39 [get_cells i_ibert/inst/QUAD[1].u_q/CH[3].u_ch/u_gtye4_channel]
set_property LOC GTYE4_COMMON_X1Y9 [get_cells i_ibert/inst/QUAD[1].u_q/u_common/u_gtye4_common]
set_property LOC GTYE4_CHANNEL_X1Y48 [get_cells i_ibert/inst/QUAD[2].u_q/CH[0].u_ch/u_gtye4_channel]
set_property LOC GTYE4_CHANNEL_X1Y49 [get_cells i_ibert/inst/QUAD[2].u_q/CH[1].u_ch/u_gtye4_channel]
set_property LOC GTYE4_CHANNEL_X1Y50 [get_cells i_ibert/inst/QUAD[2].u_q/CH[2].u_ch/u_gtye4_channel]
set_property LOC GTYE4_CHANNEL_X1Y51 [get_cells i_ibert/inst/QUAD[2].u_q/CH[3].u_ch/u_gtye4_channel]
set_property LOC GTYE4_COMMON_X1Y12 [get_cells i_ibert/inst/QUAD[2].u_q/u_common/u_gtye4_common]
set_property LOC GTYE4_CHANNEL_X1Y52 [get_cells i_ibert/inst/QUAD[3].u_q/CH[0].u_ch/u_gtye4_channel]
set_property LOC GTYE4_CHANNEL_X1Y53 [get_cells i_ibert/inst/QUAD[3].u_q/CH[1].u_ch/u_gtye4_channel]
set_property LOC GTYE4_CHANNEL_X1Y54 [get_cells i_ibert/inst/QUAD[3].u_q/CH[2].u_ch/u_gtye4_channel]
set_property LOC GTYE4_CHANNEL_X1Y55 [get_cells i_ibert/inst/QUAD[3].u_q/CH[3].u_ch/u_gtye4_channel]
set_property LOC GTYE4_COMMON_X1Y13 [get_cells i_ibert/inst/QUAD[3].u_q/u_common/u_gtye4_common]
