set BITFILE [lindex $argv 0]

open_hw_manager
connect_hw_server -url [lindex $argv 1]
#current_hw_target
open_hw_target
current_hw_device [lindex [get_hw_devices] 0]
#refresh_hw_device -update_hw_probes false [lindex [get_hw_devices] 0]
set_property PROGRAM.FILE [lindex $argv 0] [lindex [get_hw_devices] 0]
#set_property PROBES.FILE $PROBESFILE [lindex [get_hw_devices] 0]

program_hw_devices [lindex [get_hw_devices] 0]
#refresh_hw_device [lindex [get_hw_devices] 0]
