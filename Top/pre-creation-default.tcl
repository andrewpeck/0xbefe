set DESIGN "[file tail [file dirname [info script]]]"
set PRJ_PATH "[file normalize [file dirname [info script]]]"
source $PRJ_PATH/../common.tcl

update_project_makefile update_${DESIGN}
