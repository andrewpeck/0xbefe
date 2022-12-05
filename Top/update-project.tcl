set DESIGN "[file tail [file dirname [info script]]]"
set PRJ_PATH "[file normalize [file dirname [info script]]]"
source $PRJ_PATH/../common.tcl

update_project_makefile update_${DESIGN}

# promote multi-driven nets to errors so they are caught
# at synthesis with a useful message instead of at the
# end of implementation
set_msg_config -id {Synth 8-6859} -new_severity {ERROR}
