#vivado

set FPGA xcvu27p-fsga2577-1-e

set DESIGN    "[file rootname [file tail [info script]]]"
set PATH_REPO "[file normalize [file dirname [info script]]]/../../"

#https://www.xilinx.com/support/answers/72570.html
set PYTHONPATH $::env(PYTHONPATH)
set PYTHONHOME $::env(PYTHONHOME)
unset env(PYTHONPATH)
unset env(PYTHONHOME)
puts [exec bash -c {cd ../.. && make update_me0_x2o}]
set env(PYTHONPATH) $PYTHONPATH
set env(PYTHONHOME) $PYTHONHOME

source $PATH_REPO/Top/common.tcl

source $PATH_REPO/Hog/Tcl/create_project.tcl

set_property default_lib work [current_project]
set_property top gem_x2o [current_fileset]

set_property AUTO_INCREMENTAL_CHECKPOINT 1 [get_runs impl_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 1 [get_runs synth_1]
