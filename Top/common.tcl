proc update_project_makefile {name} {

    upvar env env

    set PATH_REPO "[file normalize [file dirname [info script]]]/../../"

    # https://www.xilinx.com/support/answers/72570.html
    if { [info exist ::env(PYTHONPATH)] } {
        set _PYTHONPATH $::env(PYTHONPATH)
        unset ::env(PYTHONPATH)
    }
    if { [info exist ::env(PYTHONHOME)] } {
        set _PYTHONHOME $::env(PYTHONHOME)
        unset ::env(PYTHONHOME)
    }

    puts [exec bash -c "make -C $PATH_REPO $name"]

    if { [info exist _PYTHONPATH] } {
        set ::env(PYTHONPATH) $_PYTHONPATH
    }
    if { [info exist _PYTHONHOME] } {
        set ::env(PYTHONHOME) $_PYTHONHOME
    }

}
