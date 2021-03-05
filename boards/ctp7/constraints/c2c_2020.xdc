# ==========================================================================
# V7 CTP7 AXI Chip2Chip

set_property INTERNAL_VREF 0.9 [get_iobanks 16]

# AXI Chip2Chip - RX section
set_property PACKAGE_PIN BB33 [get_ports axi_c2c_v7_to_zynq_clk]

set_property PACKAGE_PIN BA34 [get_ports {axi_c2c_v7_to_zynq_data[0]}]
set_property PACKAGE_PIN BA35 [get_ports {axi_c2c_v7_to_zynq_data[1]}]
set_property PACKAGE_PIN AV34 [get_ports {axi_c2c_v7_to_zynq_data[2]}]
set_property PACKAGE_PIN AV35 [get_ports {axi_c2c_v7_to_zynq_data[3]}]
set_property PACKAGE_PIN BD31 [get_ports {axi_c2c_v7_to_zynq_data[4]}]
set_property PACKAGE_PIN BD32 [get_ports {axi_c2c_v7_to_zynq_data[5]}]
set_property PACKAGE_PIN BC34 [get_ports {axi_c2c_v7_to_zynq_data[6]}]
set_property PACKAGE_PIN AY33 [get_ports {axi_c2c_v7_to_zynq_data[7]}]
set_property PACKAGE_PIN AY34 [get_ports {axi_c2c_v7_to_zynq_data[8]}]
set_property PACKAGE_PIN AW34 [get_ports {axi_c2c_v7_to_zynq_data[9]}]
set_property PACKAGE_PIN AW35 [get_ports {axi_c2c_v7_to_zynq_data[10]}]
set_property PACKAGE_PIN AR31 [get_ports {axi_c2c_v7_to_zynq_data[11]}]
set_property PACKAGE_PIN AR32 [get_ports {axi_c2c_v7_to_zynq_data[12]}]
set_property PACKAGE_PIN AJ32 [get_ports {axi_c2c_v7_to_zynq_data[13]}]
set_property PACKAGE_PIN AK32 [get_ports {axi_c2c_v7_to_zynq_data[14]}]
set_property PACKAGE_PIN BC32 [get_ports {axi_c2c_v7_to_zynq_data[15]}]
set_property PACKAGE_PIN BC33 [get_ports {axi_c2c_v7_to_zynq_data[16]}]

set_property IOSTANDARD HSTL_I_DCI_18 [get_ports axi_c2c_v7_to_zynq_clk]

set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[0]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[1]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[2]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[3]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[4]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[5]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[6]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[7]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[8]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[9]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[10]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[11]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[12]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[13]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[14]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[15]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_v7_to_zynq_data[16]}]

# AXI Chip2Chip - TX section
set_property PACKAGE_PIN AU33 [get_ports axi_c2c_zynq_to_v7_clk]

set_property PACKAGE_PIN BD34 [get_ports {axi_c2c_zynq_to_v7_data[0]}]
set_property PACKAGE_PIN BD35 [get_ports {axi_c2c_zynq_to_v7_data[1]}]
set_property PACKAGE_PIN BB35 [get_ports {axi_c2c_zynq_to_v7_data[2]}]
set_property PACKAGE_PIN BC35 [get_ports {axi_c2c_zynq_to_v7_data[3]}]
set_property PACKAGE_PIN BB31 [get_ports {axi_c2c_zynq_to_v7_data[4]}]
set_property PACKAGE_PIN BB32 [get_ports {axi_c2c_zynq_to_v7_data[5]}]
set_property PACKAGE_PIN AY32 [get_ports {axi_c2c_zynq_to_v7_data[6]}]
set_property PACKAGE_PIN BA33 [get_ports {axi_c2c_zynq_to_v7_data[7]}]
set_property PACKAGE_PIN AV32 [get_ports {axi_c2c_zynq_to_v7_data[8]}]
set_property PACKAGE_PIN AW32 [get_ports {axi_c2c_zynq_to_v7_data[9]}]
set_property PACKAGE_PIN AJ30 [get_ports {axi_c2c_zynq_to_v7_data[10]}]
set_property PACKAGE_PIN AJ31 [get_ports {axi_c2c_zynq_to_v7_data[11]}]
set_property PACKAGE_PIN AM32 [get_ports {axi_c2c_zynq_to_v7_data[12]}]
set_property PACKAGE_PIN AM33 [get_ports {axi_c2c_zynq_to_v7_data[13]}]
set_property PACKAGE_PIN AV33 [get_ports {axi_c2c_zynq_to_v7_data[14]}]
set_property PACKAGE_PIN AP32 [get_ports {axi_c2c_zynq_to_v7_data[15]}]
set_property PACKAGE_PIN AN32 [get_ports {axi_c2c_zynq_to_v7_data[16]}]

set_property IOSTANDARD HSTL_I_DCI_18 [get_ports axi_c2c_zynq_to_v7_clk]

set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[0]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[1]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[2]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[3]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[4]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[5]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[6]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[7]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[8]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[9]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[10]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[11]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[12]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[13]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[14]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[15]}]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports {axi_c2c_zynq_to_v7_data[16]}]

# AXI Chip2Chip - Status/Control section
set_property PACKAGE_PIN AR33 [get_ports axi_c2c_zynq_to_v7_reset]
set_property PACKAGE_PIN AT33 [get_ports axi_c2c_v7_to_zynq_link_status]

set_property IOSTANDARD HSTL_I_DCI_18 [get_ports axi_c2c_zynq_to_v7_reset]
set_property IOSTANDARD HSTL_I_DCI_18 [get_ports axi_c2c_v7_to_zynq_link_status]
# ==========================================================================

## This constraint is embedded in AXI C2C IP module
##create_clock -period 5.000 -name axi_c2c_zynq_to_v7_clk [get_ports axi_c2c_zynq_to_v7_clk]


create_generated_clock -name axi_c2c_v7_to_zynq_clk -source [get_pins i_system/i_v7_bd/axi_chip2chip_0/inst/slave_fpga_gen.axi_chip2chip_slave_phy_inst/slave_sio_phy.axi_chip2chip_sio_output_inst/gen_oddr.oddr_clk_out_inst/C] -divide_by 1 [get_ports axi_c2c_v7_to_zynq_clk]

set_property LOC MMCME2_ADV_X0Y6 [get_cells i_system/i_v7_bd/axi_chip2chip_0/inst/slave_fpga_gen.axi_chip2chip_slave_phy_inst/slave_sio_phy.axi_chip2chip_sio_input_inst/axi_chip2chip_clk_gen_inst/mmcm_adv_inst]
set_switching_activity -static_probability 0.667 [get_cells i_system/i_v7_bd/axi_chip2chip_0/inst/slave_fpga_gen.axi_chip2chip_slave_phy_inst/slave_sio_phy.axi_chip2chip_sio_input_inst/axi_chip2chip_clk_gen_inst/mmcm_adv_inst]
