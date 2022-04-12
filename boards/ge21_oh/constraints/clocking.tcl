################################################################################
# Main system clock
################################################################################

create_clock -period 24.8 -name clock   [get_ports clock_p]

# set_false_path -from [get_clocks] -to [get_ports elink_o_p]

# set_false_path -from [get_ports {vfat_sot_*}]   -to [get_pins -hierarchical -filter { NAME =~  "*trig_alignment/*oversample*/*ise1*/DDLY" }]
# set_false_path -from [get_ports {vfat_sbits_*}] -to [get_pins -hierarchical -filter { NAME =~  "*trig_alignment/*oversample*/*ise1*/DDLY" }]
# set_false_path -from [get_ports {elink_i_*}]    -to [get_pins -hierarchical -filter { NAME =~  "*/*ise1*/DDLY" }]
# set_false_path -from [get_ports {elink_i_*}]    -to [get_pins -hierarchical -filter { NAME =~  "*/*ise1*/DDLY" }]

################################################################################
# Iserdes constraints
################################################################################

# keep a short between iserdes and the ffs
set_max_delay 1.5 \
    -from [get_cells gbt_inst/gbt_serdes/gbt_oversample/*/iserdes_a7.iserdes]

set_max_delay 1.5 \
    -from [get_cells trigger_inst/sbits/*trig_alignment*/*oversample*/*ise*/iserdes_a7.iserdes]

# keep ISERDES resets synchronized for both gbt and sbits
set_max_delay -datapath_only 4.0 \
    -to   [get_pins gbt_inst/gbt_serdes/gbt_oversample/ise*/iserdes_a7.iserdes/RST] \
    -from [get_pins gbt_inst/gbt_serdes/gbt_oversample/reset_serdes_reg/C]

set_max_delay -datapath_only 4.0 \
    -to   [get_pins trigger_inst/sbits/*trig_alignment/*oversample/*/iserdes_a7.iserdes/RST] \
    -from [get_pins trigger_inst/sbits/*trig_alignment/*/reset_serdes_reg/C]

set part [get_property part [current_project]]
if {[regexp {xc7a200.*} $part]} {

    # create a pblock for the gbt serdes.. I don't know why it is necessary but
    # otherwise it places things on the opposite side of the chip
    delete_pblock -quiet [get_pblocks  gbt_serdes_pblock]
    create_pblock gbt_serdes_pblock
    resize_pblock gbt_serdes_pblock \
        -add CLOCKREGION_X0Y4:CLOCKREGION_X0Y4
    add_cells_to_pblock \
        gbt_serdes_pblock [get_cells -hierarchical -filter {NAME =~ gbt_inst*}] -clear_locs

    # manually placed this flip-flop... because its on this weird async timing path
    # the tools don't really optimize it well on its own so forcing the flip-flop
    # close to the serdes keeps timing consistent
    set cell [get_cells [list  gbt_inst/gbt_serdes/gbt_oversample/reset_serdes*]]
    place_cell $cell SLICE_X1Y248
    set_property is_bel_fixed true $cell
    set_property is_loc_fixed true $cell
}

################################################################################
# nothing important comes from the CFGMCLK
################################################################################

create_clock -period 24.0 -name CFGMCLK \
    [get_pins control_inst/led_control_inst/startup/*startupe*/CFGMCLK]
set_false_path -from [get_clocks CFGMCLK] -to [get_clocks *]
set_false_path -from [get_clocks  *     ] -to [get_clocks CFGMCLK]

################################################################################
# MGT REFCLK
################################################################################

create_clock -period 12.4 -name MGTREFCLK [get_ports {mgt_clk_p_i[*]}]

################################################################################
# Clock domain crossing
################################################################################

set_property MAX_FANOUT 128 \
    [get_nets -hierarchical -filter {name =~ "*i_ipb_reset_sync_usr_clk/s_resync[0]"}]

set_max_delay -datapath_only \
    -from [get_clocks *] \
    -to [get_pins -hierarchical -filter {NAME =~ *s_resync_reg*/D}] 2.5

################################################################################
# IOdelays
################################################################################

# these don't matter, just make something up
set_input_delay  -clock [get_clocks {clock}] 12  [get_ports gbt_*x*]
set_output_delay -clock [get_clocks {clock}] 0   [get_ports led_o*]

# -min - The minimal clock-to-output of the driving chip. If not given, choose zero
#        (maybe a future revision of the driving chip will be manufactured with a
#        really fast process)
## -max The maximal clock-to-output of the driving chip + board propagation delay
set diff_inputs [concat \
                     [get_ports vfat*] \
                     [get_ports elink_i_p]]

# https://support.xilinx.com/s/article/59893?language=en_US
# input     __________          _________
# clock   __|         |_________|        |______
#           |-->     min input delay
#           |------> max input delay
#       _______     _______________
# data  _______xxxxx______Data_____xxxxx
#
set_input_delay -clock [get_clocks clock] -min -1.0 $diff_inputs ; # hold
set_input_delay -clock [get_clocks clock] -max -0.2 $diff_inputs ; # setup

set diff_outputs [concat \
                     [get_ports gbt_trig_o*] \
                     [get_ports elink_o*]]

set_output_delay -clock [get_clocks clock] -min  -0.10 $diff_outputs ; # neg hold of the receiver
set_output_delay -clock [get_clocks clock] -max   4.90 $diff_outputs ; # pos setup of the receiver
