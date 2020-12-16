#vivado

set FPGA xcvu13p-figd2104-2-e

set DESIGN    "[file rootname [file tail [info script]]]"
set PATH_REPO "[file normalize [file dirname [info script]]]/../../"
source $PATH_REPO/Top/common.tcl

source $PATH_REPO/Hog/Tcl/create_project.tcl

set_property default_lib work [current_project]
set_property top gem_cvp13 [current_fileset]

set_property AUTO_INCREMENTAL_CHECKPOINT 1 [get_runs impl_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 1 [get_runs synth_1]

