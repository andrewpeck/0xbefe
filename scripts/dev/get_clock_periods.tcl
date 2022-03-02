foreach c [get_clocks {*}] {
    puts $c
    puts [get_property PERIOD $c]
}
