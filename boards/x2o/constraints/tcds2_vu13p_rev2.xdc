################# MGT data signals #######################

# quad 124 ch0

set_property PACKAGE_PIN BA45 [get_ports tcds2_mgt_tx_p]
set_property PACKAGE_PIN BA46 [get_ports tcds2_mgt_rx_p]


# quad 125

#set_property PACKAGE_PIN AP43 [get_ports tcds2_mgt_tx_p]
#set_property PACKAGE_PIN AP48 [get_ports tcds2_mgt_rx_p]


# quad 126 HACK FOR TCDS IBERT 
#set_property PACKAGE_PIN AN45 [get_ports tcds2_mgt_tx_p]
#set_property PACKAGE_PIN AN50 [get_ports tcds2_mgt_rx_p]

############### clocks #################################

#### backplane LHC clock from DTH connected to quad 126 refclk1 ######

set_property PACKAGE_PIN AL41 [get_ports {tcds2_backplane_clk_p}]
create_clock -period 3.125 -name lhc_backplane_clk [get_ports {tcds2_backplane_clk_p}]
#create_clock -period 25.000 -name lhc_backplane_clk [get_ports {tcds2_backplane_clk_p}]
set_clock_groups -asynchronous -group [get_clocks lhc_backplane_clk]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*i_tcds2/*RXOUTCLK}]]

#### output clocks to the LMK chip ########

set_property PACKAGE_PIN BB17 [get_ports {lmk_refclk_0_p}]
set_property PACKAGE_PIN BC17 [get_ports {lmk_refclk_0_n}]
set_property IOSTANDARD LVDS [get_ports {lmk_refclk_0_p}]
set_property IOSTANDARD LVDS [get_ports {lmk_refclk_0_n}]

set_property PACKAGE_PIN AY15 [get_ports {lmk_refclk_1_p}]
set_property PACKAGE_PIN BA15 [get_ports {lmk_refclk_1_n}]
set_property IOSTANDARD LVDS [get_ports {lmk_refclk_1_p}]
set_property IOSTANDARD LVDS [get_ports {lmk_refclk_1_n}]

############### LpGBT core timing #################################
#-----------------------------------------------------
# Bit synchronizer
#-----------------------------------------------------
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *bit_synchronizer/i_in_meta_reg}]

#-----------------------------------------------------
# Reset synchronizer
#-----------------------------------------------------
set_false_path -to [get_pins -filter REF_PIN_NAME=~*D -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_meta*}]]
set_false_path -to [get_pins -filter REF_PIN_NAME=~*PRE -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_meta*}]]
set_false_path -to [get_pins -filter REF_PIN_NAME=~*PRE -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_sync1*}]]
set_false_path -to [get_pins -filter REF_PIN_NAME=~*PRE -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_sync2*}]]
set_false_path -to [get_pins -filter REF_PIN_NAME=~*PRE -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_sync3*}]]
set_false_path -to [get_pins -filter REF_PIN_NAME=~*PRE -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_out*}]]
#-----------------------------------------------------
# MGT Tx/Rx active
#-----------------------------------------------------
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *gtwiz_userclk_tx_active*reg*}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *gtwiz_userclk_rx_active*reg*}]

#-----------------------------------------------------
# CDC TX and RX
#-----------------------------------------------------
set_max_delay -from  [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_tx/data_a_reg_reg*/C}]  -to [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_tx/data_b_reg_reg*/D}]  -datapath_only 6.25
set_max_delay -from  [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_tx/reset_a_strobe_sync_reg/C}]   -to [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_tx/reset_b_meta_reg/D}] -datapath_only 6.25
set_false_path -to   [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_tx/reset_freerun_meta_reg/D}] 
set_false_path -to   [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_tx/xormeas_meta_reg/D}] 
set_false_path -to   [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_tx/advance_toggle_meta_reg/D}] 
set_false_path -to   [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_tx/retard_toggle_meta_reg/D}] 

set_max_delay -from  [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_rx/data_a_reg_reg*/C}]  -to [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_rx/data_b_reg_reg*/D}] -datapath_only 6.25
set_max_delay -from  [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_rx/strobe_b_toggle_reg/C}] -to [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_rx/strobe_b_toggle_meta_reg/D}] -datapath_only 6.25
set_false_path -to   [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_rx/phase_calib_a_reg*/D}] 
set_false_path -to   [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_rx/phase_force_a_reg/D}] 
set_false_path -from [get_pins -hierarchical -filter {NAME =~ *cmp_cdc_rx/phase_o_reg*/C}] 

#-----------------------------------------------------
# lpGBT10G Rx - lpGBT-FPGA - MASTER + SLAVE
#-----------------------------------------------------
# Uplink constraints: Values depend on the c_multicyleDelay. Shall be the same one for setup time and -1 for the hold time
set_multicycle_path 3 -from [get_pins -hierarchical -filter {NAME =~ *cmp_lpgbtfpga_uplink_fixed/frame_pipelined_s_reg[*]/C}] -setup
set_multicycle_path 2 -from [get_pins -hierarchical -filter {NAME =~ *cmp_lpgbtfpga_uplink_fixed/frame_pipelined_s_reg[*]/C}] -hold
#set_multicycle_path 3 -from [get_pins -hierarchical -filter {NAME =~ *cmp_lpgbtfpga_uplink_fixed/*descrambledData_reg[*]/C}] -setup
#set_multicycle_path 2 -from [get_pins -hierarchical -filter {NAME =~ *cmp_lpgbtfpga_uplink_fixed/*descrambledData_reg[*]/C}] -hold

#-----------------------------------------------------
# lpGBT10G Tx - lpGBT-FE Tx - MASTER + SLAVE
#-----------------------------------------------------
set_multicycle_path 7  -to [get_pins -hierarchical -filter {NAME =~ *cmp_lpgbt_fe_tx/txgearbox_inst/dataWord_reg*/D}] -through [get_nets -hierarchical -filter {NAME =~ *cmp_lpgbt_fe_tx/txdatapath_inst/fec5*}] -setup
set_multicycle_path 6  -to [get_pins -hierarchical -filter {NAME =~ *cmp_lpgbt_fe_tx/txgearbox_inst/dataWord_reg*/D}] -through [get_nets -hierarchical -filter {NAME =~ *cmp_lpgbt_fe_tx/txdatapath_inst/fec5*}] -hold

#-----------------------------------------------------
# HPTD IP Core - MASTER + SLAVE
#-----------------------------------------------------
set_false_path -to [get_pins -hier -filter {NAME =~ *cmp_tx_phase_aligner/*meta*/D}]
set_false_path -to [get_pins -hier -filter {NAME =~ *cmp_tx_phase_aligner/cmp_fifo_fill_level_acc/phase_detector_o*/D}]
set_false_path -from [get_pins -hier -filter {NAME =~ *cmp_tx_phase_aligner/*cmp_tx_phase_aligner_fsm/*/C}] -to [get_pins -hier -filter {NAME =~ *cmp_tx_phase_aligner/cmp_fifo_fill_level_acc/phase_detector_acc_reg*/CE}]
set_false_path -from [get_pins -hier -filter {NAME =~ *cmp_tx_phase_aligner/*cmp_tx_phase_aligner_fsm/*/C}] -to [get_pins -hier -filter {NAME =~ *cmp_tx_phase_aligner/cmp_fifo_fill_level_acc/hits_acc_reg*/CE}]
set_false_path -from [get_pins -hier -filter {NAME =~ *cmp_tx_phase_aligner/*cmp_tx_phase_aligner_fsm/*/C}] -to [get_pins -hier -filter {NAME =~ *cmp_tx_phase_aligner/cmp_fifo_fill_level_acc/done_reg/D}]
