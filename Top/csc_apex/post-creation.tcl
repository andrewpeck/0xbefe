set_property default_lib work [current_project]

# required for APEX KU15P rev1
set PATH_REPO "[file normalize [file dirname [info script]]]/../../"
set_property verilog_define C2C_3P125G [current_fileset]
set_property file_type {Verilog Header} [get_files $PATH_REPO/boards/apex/hdl/c2c/mgt/c2c_gth_example_wrapper_functions.v]
