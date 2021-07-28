set DESIGN "[file tail [file dirname [info script]]]"
set PRJ_PATH "[file normalize [file dirname [info script]]]"
source $PRJ_PATH/../common.tcl

# split off the flavor number (e.g. oh_ge21.200 --> oh_ge21)
set name [lindex [split $DESIGN .] 0]

update_project_makefile update_${name}
