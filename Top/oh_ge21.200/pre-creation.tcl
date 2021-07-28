set DESIGN "[file tail [file dirname [info script]]]"
source common.tcl
update_project_makefile update_${DESIGN}
