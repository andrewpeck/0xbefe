#vivado

set BIN_FILE 1
set USE_QUESTA_SIMULATOR 0

set FPGA xc7a200tfbg484-3

set DESIGN    "[file rootname [file tail [info script]]]"
set PATH_REPO "[file normalize [file dirname [info script]]]/../../"

#https://www.xilinx.com/support/answers/72570.html
set PYTHONPATH $::env(PYTHONPATH)
set PYTHONHOME $::env(PYTHONHOME)
unset env(PYTHONPATH)
unset env(PYTHONHOME)
puts [exec bash -c {cd ../.. && make update_oh_ge21}]
set env(PYTHONPATH) $PYTHONPATH
set env(PYTHONHOME) $PYTHONHOME

source $PATH_REPO/Top/common.tcl

set PROPERTIES [dict create \
synth_1 [dict create \
    STEPS.SYNTH_DESIGN.ARGS.ASSERT true \
    STEPS.SYNTH_DESIGN.ARGS.RETIMING true \
  ] \
impl_1 [dict create \
  STEPS.OPT_DESIGN.ARGS.DIRECTIVE Default \
  STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore \
  ]\
]

source $PATH_REPO/Hog/Tcl/create_project.tcl

set_property default_lib work [current_project]

set_property AUTO_INCREMENTAL_CHECKPOINT 1 [get_runs impl_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 1 [get_runs synth_1]
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]
