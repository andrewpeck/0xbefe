set DESIGN "[file tail [file dirname [info script]]]"
puts [exec bash -c "cd .. && make update_oh_ge11"]
