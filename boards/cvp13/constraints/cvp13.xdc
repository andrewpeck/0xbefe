##############################################
#################  General  ##################
##############################################
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CONFIG_MODE SPIx4  [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 85.0 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]

# Active Low Global Reset
set_property PACKAGE_PIN AW21 [get_ports reset_b_i]
set_property IOSTANDARD LVCMOS18 [get_ports reset_b_i]

# SI5341B out5, used as a free running system clock
set_property PACKAGE_PIN AV22 [get_ports synth_b_out_p_i[4]]
set_property PACKAGE_PIN AV21 [get_ports synth_b_out_n_i[4]]
set_property IOSTANDARD DIFF_SSTL18_I [get_ports {synth_b_out_p_i[4]}]

# SI5341B out1, can be used as a free running system clock
set_property PACKAGE_PIN G30  [get_ports synth_b_out_p_i[0]]
set_property PACKAGE_PIN F30  [get_ports synth_b_out_n_i[0]]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports synth_b_out_p_i[0]]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports synth_b_out_n_i[0]]
set_property ODT RTT_48 [get_ports synth_b_out_p_i[0]]

# SI5341B out2, can be used as a free running system clock
set_property PACKAGE_PIN G20  [get_ports synth_b_out_p_i[1]]
set_property PACKAGE_PIN F19  [get_ports synth_b_out_n_i[1]]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports synth_b_out_p_i[1]]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports synth_b_out_n_i[1]]
set_property ODT RTT_48 [get_ports synth_b_out_p_i[1]]

# SI5341B out3, can be used as DIMM0 clk
set_property PACKAGE_PIN AY18 [get_ports synth_b_out_p_i[2]]
set_property PACKAGE_PIN AY17 [get_ports synth_b_out_n_i[2]]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports synth_b_out_p_i[2]]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports synth_b_out_n_i[2]]
set_property ODT RTT_48 [get_ports synth_b_out_p_i[2]]

# SI5341B out4, can be used as DIMM1 clk
set_property PACKAGE_PIN BB31 [get_ports synth_b_out_p_i[3]]
set_property PACKAGE_PIN BB32 [get_ports synth_b_out_n_i[3]]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports synth_b_out_p_i[3]]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports synth_b_out_n_i[3]]
set_property ODT RTT_48 [get_ports synth_b_out_p_i[3]]

#sysclk
create_clock -period 10.000 -name sysclk100 [get_ports {synth_b_out_p_i[1]}]

##############################################
##################  LEDs  ####################
##############################################
set_property PACKAGE_PIN AL21 [get_ports leds_o[0]]
set_property PACKAGE_PIN AL20 [get_ports leds_o[1]]
set_property PACKAGE_PIN AP21 [get_ports leds_o[2]]
set_property PACKAGE_PIN AP20 [get_ports leds_o[3]]

set_property IOSTANDARD LVCMOS18 [get_ports leds_o[*]]

##############################################
##########  QSFP Status & Control   ##########
##############################################
# QSFP present and reset signals (both active low)
set_property PACKAGE_PIN BE20 [get_ports qsfp_present_b_i[3]]
set_property PACKAGE_PIN BE17 [get_ports qsfp_reset_b_o[3]]
set_property PACKAGE_PIN BE16 [get_ports qsfp_present_b_i[2]]
set_property PACKAGE_PIN BD21 [get_ports qsfp_reset_b_o[2]]
set_property PACKAGE_PIN BD20 [get_ports qsfp_present_b_i[1]]
set_property PACKAGE_PIN BE18 [get_ports qsfp_reset_b_o[1]]
set_property PACKAGE_PIN BF18 [get_ports qsfp_present_b_i[0]]
set_property PACKAGE_PIN BB20 [get_ports qsfp_reset_b_o[0]]

# QSFP low power mode (fanned out to all QSFPs)
set_property PACKAGE_PIN BE21 [get_ports qsfp_lp_o]
# QSFP interrupt (or'ed from all QSFPs)
set_property PACKAGE_PIN BD18 [get_ports qsfp_int_b_i]

# QSFP I2C Control Enable. 1 = Connect QSFP I2C/Status to FPGA
set_property PACKAGE_PIN BF20 [get_ports qsfp_ctrl_en_o]

set_property IOSTANDARD LVCMOS18 [get_ports {qsfp_present_b_i[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {qsfp_reset_b_o[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {qsfp_lp_o}]
set_property IOSTANDARD LVCMOS18 [get_ports {qsfp_int_b_i}]
set_property IOSTANDARD LVCMOS18 [get_ports {qsfp_ctrl_en_o}]

##############################################
##########        USB-C Misc.       ##########
##############################################
set_property IOSTANDARD LVCMOS18 [get_ports usbc_cc_i]
set_property PACKAGE_PIN AW20 [get_ports usbc_cc_i]
set_property IOSTANDARD LVCMOS18 [get_ports usbc_trig_i]
set_property PACKAGE_PIN AW19 [get_ports usbc_trig_i]
set_property IOSTANDARD LVCMOS18 [get_ports usbc_clk_i]
set_property PACKAGE_PIN AU19 [get_ports usbc_clk_i]

##############################################
##########          Others          ##########
##############################################
set_property IOSTANDARD LVCMOS18 [get_ports i2c_master_en_b_o]
set_property PACKAGE_PIN AY21 [get_ports i2c_master_en_b_o]

set_property IOSTANDARD        LVCMOS12        [get_ports "dimm2_dq5_trig_i"]
set_property PACKAGE_PIN       AR27            [get_ports "dimm2_dq5_trig_i"]

##############################################
##########           PCIe           ##########
##############################################
# PCIe active low reset
set_property PACKAGE_PIN AP26 [get_ports pcie_reset_b_i]
set_property IOSTANDARD LVCMOS12 [get_ports {pcie_reset_b_i}]
set_property PULLUP true [get_ports {pcie_reset_b_i}]
# PCIe ref clk 0
set_property PACKAGE_PIN AT10 [get_ports pcie_refclk0_n_i]
set_property PACKAGE_PIN AT11 [get_ports pcie_refclk0_p_i]
# PCIe ref clk 1
#set_property PACKAGE_PIN AH10 [get_ports pcie_sys_clk_n_i]
#set_property PACKAGE_PIN AH11 [get_ports pcie_sys_clk_p_i]
# PCIe Reference Clock Frequency (100 MHz)
create_clock -period 10.000 -name pcie_refclk_100 [get_ports {pcie_refclk0_p_i}]

# NOTE: All GTY pins are automatically assigned by Vivado. Shown here for reference only.
#GTH BANK 227 PCIE 3:0
#set_property PACKAGE_PIN AF2  [get_ports pcie_7x_mgt_rxp[0]] # PCIE_RX_P_0
#set_property PACKAGE_PIN AF1  [get_ports pcie_7x_mgt_rxn[0]] # PCIE_RX_N_0
#set_property PACKAGE_PIN AG4  [get_ports pcie_7x_mgt_rxp[1]] # PCIE_RX_P_1
#set_property PACKAGE_PIN AG3  [get_ports pcie_7x_mgt_rxn[1]] # PCIE_RX_N_1
#set_property PACKAGE_PIN AH2  [get_ports pcie_7x_mgt_rxp[2]] # PCIE_RX_P_2
#set_property PACKAGE_PIN AH1  [get_ports pcie_7x_mgt_rxn[2]] # PCIE_RX_N_2
#set_property PACKAGE_PIN AJ4  [get_ports pcie_7x_mgt_rxp[3]] # PCIE_RX_P_3
#set_property PACKAGE_PIN AJ3  [get_ports pcie_7x_mgt_rxn[3]] # PCIE_RX_N_3
#set_property PACKAGE_PIN AF7  [get_ports pcie_7x_mgt_txp[0]] # PCIE_TX_P_0
#set_property PACKAGE_PIN AF6  [get_ports pcie_7x_mgt_txn[0]] # PCIE_TX_N_0
#set_property PACKAGE_PIN AG9  [get_ports pcie_7x_mgt_txp[1]] # PCIE_TX_P_1
#set_property PACKAGE_PIN AG8  [get_ports pcie_7x_mgt_txn[1]] # PCIE_TX_N_1
#set_property PACKAGE_PIN AH7  [get_ports pcie_7x_mgt_txp[2]] # PCIE_TX_P_2
#set_property PACKAGE_PIN AH6  [get_ports pcie_7x_mgt_txn[2]] # PCIE_TX_N_2
#set_property PACKAGE_PIN AJ9  [get_ports pcie_7x_mgt_txp[3]] # PCIE_TX_P_3
#set_property PACKAGE_PIN AJ8  [get_ports pcie_7x_mgt_txn[3]] # PCIE_TX_N_3

#GTH BANK 226 PCIE 7:4
#set_property PACKAGE_PIN AK2  [get_ports pcie_7x_mgt_rxp[4]] # PCIE_RX_P_4
#set_property PACKAGE_PIN AK1  [get_ports pcie_7x_mgt_rxn[4]] # PCIE_RX_N_4
#set_property PACKAGE_PIN AL4  [get_ports pcie_7x_mgt_rxp[5]] # PCIE_RX_P_5
#set_property PACKAGE_PIN AL3  [get_ports pcie_7x_mgt_rxn[5]] # PCIE_RX_N_5
#set_property PACKAGE_PIN AM2  [get_ports pcie_7x_mgt_rxp[6]] # PCIE_RX_P_6
#set_property PACKAGE_PIN AM1  [get_ports pcie_7x_mgt_rxn[6]] # PCIE_RX_N_6
#set_property PACKAGE_PIN AN4  [get_ports pcie_7x_mgt_rxp[7]] # PCIE_RX_P_7
#set_property PACKAGE_PIN AN3  [get_ports pcie_7x_mgt_rxn[7]] # PCIE_RX_N_7
#set_property PACKAGE_PIN AK7  [get_ports pcie_7x_mgt_txp[4]] # PCIE_TX_P_4
#set_property PACKAGE_PIN AK6  [get_ports pcie_7x_mgt_txn[4]] # PCIE_TX_N_4
#set_property PACKAGE_PIN AL9  [get_ports pcie_7x_mgt_txp[5]] # PCIE_TX_P_5
#set_property PACKAGE_PIN AL8  [get_ports pcie_7x_mgt_txn[5]] # PCIE_TX_N_5
#set_property PACKAGE_PIN AM7  [get_ports pcie_7x_mgt_txp[6]] # PCIE_TX_P_6
#set_property PACKAGE_PIN AM6  [get_ports pcie_7x_mgt_txn[6]] # PCIE_TX_N_6
#set_property PACKAGE_PIN AN9  [get_ports pcie_7x_mgt_txp[7]] # PCIE_TX_P_7
#set_property PACKAGE_PIN AN8  [get_ports pcie_7x_mgt_txn[7]] # PCIE_TX_N_7

#GTH BANK 225 PCIE Lanes 11:8
#set_property PACKAGE_PIN AP2  [get_ports pcie_7x_mgt_rxp[8]]  # PCIE_RX_P_8
#set_property PACKAGE_PIN AP1  [get_ports pcie_7x_mgt_rxn[8]]  # PCIE_RX_N_8
#set_property PACKAGE_PIN AR4  [get_ports pcie_7x_mgt_rxp[9]]  # PCIE_RX_P_9
#set_property PACKAGE_PIN AR3  [get_ports pcie_7x_mgt_rxn[9]]  # PCIE_RX_N_9
#set_property PACKAGE_PIN AT2  [get_ports pcie_7x_mgt_rxp[10]] # PCIE_RX_P_10
#set_property PACKAGE_PIN AT1  [get_ports pcie_7x_mgt_rxn[10]] # PCIE_RX_N_10
#set_property PACKAGE_PIN AU4  [get_ports pcie_7x_mgt_rxp[11]] # PCIE_RX_P_11
#set_property PACKAGE_PIN AU3  [get_ports pcie_7x_mgt_rxn[11]] # PCIE_RX_N_11
#set_property PACKAGE_PIN AP7  [get_ports pcie_7x_mgt_txp[8]]  # PCIE_TX_P_8
#set_property PACKAGE_PIN AP6  [get_ports pcie_7x_mgt_txn[8]]  # PCIE_TX_N_8
#set_property PACKAGE_PIN AR9  [get_ports pcie_7x_mgt_txp[9]]  # PCIE_TX_P_9
#set_property PACKAGE_PIN AR8  [get_ports pcie_7x_mgt_txn[9]]  # PCIE_TX_N_9
#set_property PACKAGE_PIN AT7  [get_ports pcie_7x_mgt_txp[10]] # PCIE_TX_P_10
#set_property PACKAGE_PIN AT6  [get_ports pcie_7x_mgt_txn[10]] # PCIE_TX_N_10
#set_property PACKAGE_PIN AU9  [get_ports pcie_7x_mgt_txp[11]] # PCIE_TX_P_11
#set_property PACKAGE_PIN AU8  [get_ports pcie_7x_mgt_txn[11]] # PCIE_TX_N_11

#GTH BANK 224 PCIE Lanes 15:12
#set_property PACKAGE_PIN AV2  [get_ports pcie_7x_mgt_rxp[12]] # PCIE_RX_P_12
#set_property PACKAGE_PIN AV1  [get_ports pcie_7x_mgt_rxn[12]] # PCIE_RX_N_12
#set_property PACKAGE_PIN AW4  [get_ports pcie_7x_mgt_rxp[13]] # PCIE_RX_P_13
#set_property PACKAGE_PIN AW3  [get_ports pcie_7x_mgt_rxn[13]] # PCIE_RX_N_13
#set_property PACKAGE_PIN BA2  [get_ports pcie_7x_mgt_rxp[14]] # PCIE_RX_P_14
#set_property PACKAGE_PIN BA1  [get_ports pcie_7x_mgt_rxn[14]] # PCIE_RX_N_14
#set_property PACKAGE_PIN BC2  [get_ports pcie_7x_mgt_rxp[15]] # PCIE_RX_P_15
#set_property PACKAGE_PIN BC1  [get_ports pcie_7x_mgt_rxn[15]] # PCIE_RX_N_15
#set_property PACKAGE_PIN AV7  [get_ports pcie_7x_mgt_txp[12]] # PCIE_TX_P_12
#set_property PACKAGE_PIN AV6  [get_ports pcie_7x_mgt_txn[12]] # PCIE_TX_N_12
#set_property PACKAGE_PIN BB5  [get_ports pcie_7x_mgt_txp[13]] # PCIE_TX_P_13
#set_property PACKAGE_PIN BB4  [get_ports pcie_7x_mgt_txn[13]] # PCIE_TX_N_13
#set_property PACKAGE_PIN BD5  [get_ports pcie_7x_mgt_txp[14]] # PCIE_TX_P_14
#set_property PACKAGE_PIN BD4  [get_ports pcie_7x_mgt_txn[14]] # PCIE_TX_N_14
#set_property PACKAGE_PIN BF5  [get_ports pcie_7x_mgt_txp[15]] # PCIE_TX_P_15
#set_property PACKAGE_PIN BF4  [get_ports pcie_7x_mgt_txn[15]] # PCIE_TX_N_15

