#vivado

set FPGA xcku15p-ffva1760-2-e

set DESIGN    "[file rootname [file tail [info script]]]"
set PATH_REPO "[file normalize [file dirname [info script]]]/../../"

#https://www.xilinx.com/support/answers/72570.html
set PYTHONPATH $::env(PYTHONPATH)
set PYTHONHOME $::env(PYTHONHOME)
unset env(PYTHONPATH)
unset env(PYTHONHOME)
puts [exec bash -c {cd ../.. && make update_ge21_apex}]
set env(PYTHONPATH) $PYTHONPATH
set env(PYTHONHOME) $PYTHONHOME

source $PATH_REPO/Top/common.tcl

source $PATH_REPO/Hog/Tcl/create_project.tcl

set_property default_lib work [current_project]
set_property top gem_apex [current_fileset]
# required for APEX KU15P rev1
set_property verilog_define {C2C_R1_UEC3 C2C_3P125G} [current_fileset]
set_property file_type {Verilog Header} [get_files $PATH_REPO/boards/apex/hdl/c2c/mgt/c2c_gth_example_wrapper_functions.v]

set_property AUTO_INCREMENTAL_CHECKPOINT 1 [get_runs impl_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 1 [get_runs synth_1]

