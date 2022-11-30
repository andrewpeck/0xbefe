onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /gbt_link_tb/clock
add wave -noupdate /gbt_link_tb/reset
add wave -noupdate /gbt_link_tb/oh_rx_ready
add wave -noupdate /gbt_link_tb/oh_rx_err
add wave -noupdate /gbt_link_tb/be_rx_err
add wave -noupdate /gbt_link_tb/busy_o
add wave -noupdate -divider {Backend to OH}
add wave -noupdate -color {Medium Spring Green} /gbt_link_tb/l1a_i
add wave -noupdate -color {Medium Spring Green} /gbt_link_tb/bc0_i
add wave -noupdate -color {Medium Spring Green} /gbt_link_tb/resync_i
add wave -noupdate -color {Medium Spring Green} /gbt_link_tb/backend_to_oh_elink
add wave -noupdate -color {Medium Spring Green} /gbt_link_tb/request_valid_i
add wave -noupdate -color {Medium Spring Green} /gbt_link_tb/request_write_i
add wave -noupdate -color {Medium Spring Green} /gbt_link_tb/request_addr_i
add wave -noupdate -color {Medium Spring Green} /gbt_link_tb/request_data_i
add wave -noupdate -divider {OH RX}
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/backend_to_oh_elink
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/l1a_o
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/resync_o
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/bc0_o
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/req_en_o
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/req_data_o
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/ipb_strobe
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/ipb_wdata
add wave -noupdate -divider {OH TX}
add wave -noupdate /gbt_link_tb/oh_to_backend_elink
add wave -noupdate -divider {Backend RX}
add wave -noupdate /gbt_link_tb/reg_data_valid_o
add wave -noupdate /gbt_link_tb/reg_data_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {7200 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 222
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
WaveRestoreZoom {0 ns} {19029 ns}