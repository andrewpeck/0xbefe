# Automatically re-target the IPs to the current part
Msg Info "Upgrading IPs..."
set ips [get_ips *]
if {$ips != ""} {
    upgrade_ip -quiet $ips
}

# Per-project customizations
set PRJ_PATH "[file normalize [file dirname [info script]]]"
foreach script [glob -nocomplain -dir "$PRJ_PATH/post-creation.d" *.tcl] {
    source $script
}
