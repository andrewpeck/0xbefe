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
add wave -noupdate /gbt_link_tb/link_oh_fpga_tx_inst/req_data
add wave -noupdate /gbt_link_tb/link_oh_fpga_tx_inst/state
add wave -noupdate /gbt_link_tb/link_oh_fpga_tx_inst/elink_data_o
add wave -noupdate /gbt_link_tb/link_oh_fpga_tx_inst/data_frame_cnt
add wave -noupdate -divider CRC
add wave -noupdate -color Thistle /gbt_link_tb/link_oh_fpga_tx_inst/elink_data_o
add wave -noupdate -color Thistle /gbt_link_tb/link_oh_fpga_tx_inst/crc_en
add wave -noupdate -color Thistle /gbt_link_tb/link_oh_fpga_tx_inst/crc_data
add wave -noupdate -color {Cadet Blue} /gbt_link_tb/gbt_rx_1/data_slip
add wave -noupdate -color {Cadet Blue} /gbt_link_tb/gbt_rx_1/crc_en
add wave -noupdate -color {Cadet Blue} /gbt_link_tb/gbt_rx_1/crc_calcd
add wave -noupdate -divider {OH RX}
add wave -noupdate /gbt_link_tb/gbt_rx_1/crc_rx
add wave -noupdate /gbt_link_tb/gbt_rx_1/crc_rst
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/backend_to_oh_elink
add wave -noupdate /gbt_link_tb/gbt_rx_1/data_slip
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/l1a_o
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/resync_o
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/bc0_o
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/req_en_o
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/req_data_o
add wave -noupdate /gbt_link_tb/gbt_rx_1/req_data
add wave -noupdate /gbt_link_tb/gbt_rx_1/data_frame_cnt
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/ipb_strobe
add wave -noupdate -color {Light Steel Blue} /gbt_link_tb/ipb_wdata
add wave -noupdate /gbt_link_tb/gbt_rx_1/crc_rx
add wave -noupdate /gbt_link_tb/gbt_rx_1/bitslip_cnt
add wave -noupdate /gbt_link_tb/gbt_rx_1/bitslip_err_cnt
add wave -noupdate -divider {OH TX}
add wave -noupdate /gbt_link_tb/ipb_write
add wave -noupdate /gbt_link_tb/req_valid
add wave -noupdate /gbt_link_tb/req_data
add wave -noupdate /gbt_link_tb/oh_to_backend_elink
add wave -noupdate -divider {Backend RX}
add wave -noupdate /gbt_link_tb/reg_data_valid_o
add wave -noupdate /gbt_link_tb/reg_data_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {44519 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 248
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
WaveRestoreZoom {43697 ns} {44620 ns}
