proc update_project_makefile {name} {

    upvar env env

    set DESIGN    "[file rootname [file tail [info script]]]"
    set PATH_REPO "[file normalize [file dirname [info script]]]/../../"

    if { [string first PlanAhead [version]] != 0 } {
        #https://www.xilinx.com/support/answers/72570.html
        set PYTHONPATH $::env(PYTHONPATH)
        set PYTHONHOME $::env(PYTHONHOME)
        unset env(PYTHONPATH)
        unset env(PYTHONHOME)
    }

    puts [exec bash -c "make -C $PATH_REPO $name"]

    if { [string first PlanAhead [version]] != 0 } {
        set env(PYTHONPATH) $PYTHONPATH
        set env(PYTHONHOME) $PYTHONHOME
    }
}

proc update_top_file {name} {
    set_property default_lib work [current_project]
    set_property top $name [current_fileset]

    set_property AUTO_INCREMENTAL_CHECKPOINT 1 [get_runs impl_1]
    set_property AUTO_INCREMENTAL_CHECKPOINT 1 [get_runs synth_1]
}
