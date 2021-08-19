# required for APEX KU15P rev1
set PATH_REPO "[file normalize [file dirname [info script]]]/../../"
set_property verilog_define {C2C_R1_UEC3 C2C_3P125G} [current_fileset]

# for some reason this is required in post-creation.tcl
# otherwise vivado crashes with mysterious errors such as
# error: [ip_flow 19-155] failed to convert to hdl value.
catch {generate_target all [get_files slink_rocket_sender.xci]}

set_property file_type {Verilog Header} \
  [get_files c2c_gth_example_wrapper_functions.v]
