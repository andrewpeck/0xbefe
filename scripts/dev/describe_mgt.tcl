# given an MGT channel cell (e.g. one from a synthesized IP example design), this script outputs two files describing port connections and properties
# the two output files then can be used by a script to generate an MGT instantiation with correct constants

set MGT_NAME example_wrapper_inst/gtwizard_ultrascale_1p6_test_inst/inst/gen_gtwizard_gtye4_top.gtwizard_ultrascale_1p6_test_gtwizard_gtye4_inst/gen_gtwizard_gtye4.gen_channel_container[0].gen_enabled_channel.gtye4_channel_wrapper_inst/channel_inst/gtye4_channel_gen.gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST
set PORT_FNAME /home/evka/code/fw/0xBEFE/scripts/dev/mgt_configs/ports.txt
set PROP_FNAME /home/evka/code/fw/0xBEFE/scripts/dev/mgt_configs/props.txt

set mgt_cell [get_cells $MGT_NAME]

set fp [open $PORT_FNAME w]
foreach p [get_pins -of $mgt_cell] {
    catch {
        set t [get_property TYPE [get_nets -of $p]]
        set p_split [split $p "/"]
        set p_short [lindex $p_split end]
        puts $fp "$p_short $t"
    }
}
close $fp

report_property -file $PROP_FNAME $mgt_cell

