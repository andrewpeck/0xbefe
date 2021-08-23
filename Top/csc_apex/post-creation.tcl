# required for APEX KU15P rev1
set_property verilog_define C2C_3P125G [current_fileset]

# for some reason this is required in post-creation.tcl
# otherwise vivado crashes with mysterious errors such as
# error: [ip_flow 19-155] failed to convert to hdl value.
catch {generate_target all [get_files slink_rocket_sender.xci]}
