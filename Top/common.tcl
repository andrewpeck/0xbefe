proc update_project_makefile {name} {

    upvar env env

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
