set NumericStdNoWarnings 1

onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider Inputs
add wave -noupdate /cluster_packer/clk_40
add wave -noupdate /cluster_packer/clk_fast
add wave -noupdate /cluster_packer/partitions_i
add wave -noupdate /cluster_packer/reset
add wave -noupdate -divider Outputs
add wave -noupdate /cluster_packer/cluster_count_o
add wave -noupdate /cluster_packer/clusters_o
add wave -noupdate /cluster_packer/clusters_ena_o
add wave -noupdate /cluster_packer/overflow_o
add wave -noupdate -divider {Input S-bit Processing}
add wave -noupdate /cluster_packer/sbits_i
add wave -noupdate /cluster_packer/sbits_s0
add wave -noupdate /cluster_packer/partitions_os
add wave -noupdate /cluster_packer/vpfs
add wave -noupdate /cluster_packer/cnts
add wave -noupdate -divider Latch
add wave -noupdate /cluster_packer/latch_pulse_s0
add wave -noupdate /cluster_packer/latch_pulse_s1
add wave -noupdate /cluster_packer/cluster_latch
add wave -noupdate -divider Clusters
add wave -noupdate /cluster_packer/cluster_count
add wave -noupdate /cluster_packer/clusters
add wave -noupdate /cluster_packer/overflow
add wave -noupdate -divider Generics
add wave -noupdate /cluster_packer/DEADTIME
add wave -noupdate /cluster_packer/INVERT_PARTITIONS
add wave -noupdate /cluster_packer/NUM_PARTITIONS
add wave -noupdate /cluster_packer/NUM_VFATS
add wave -noupdate /cluster_packer/ONESHOT
add wave -noupdate /cluster_packer/SPLIT_CLUSTERS
add wave -noupdate /cluster_packer/STATION
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1718 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 383
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {1525 ns} {1940 ns}
