------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-06-04
-- Module Name:    PCIe
-- Description:    Wrapper for PCIe core, provides slow control and DAQ interfaces to the user logic
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library xpm;
use xpm.vcomponents.all;

library unisim;
use unisim.vcomponents.all;

use work.axi_pkg.all;
use work.ipbus.all;
use work.ipb_addr_decode.all;
use work.ipb_sys_addr_decode.all;
use work.common_pkg.all;

entity pcie is
    generic(
        g_USE_QDMA              : boolean; -- QDMA will be used if set to true (does not support DAQ), if set to false XDMA with DAQ support will be used
        g_NUM_USR_BLOCKS        : integer; -- number of user blocks (more than one can be used e.g. where we have multiple GEM or CSC modules instantiated, used on devices with multiple SLRs)
        g_USR_BLOCK_SEL_BIT_TOP : integer; -- top address bit used for user block selection
        g_USR_BLOCK_SEL_BIT_BOT : integer; -- bottom address bit used for user block selection
        g_IS_SLINK_ROCKET       : boolean  -- set to true if daqlink is in SLink Rocket format (128bits), and false if it't in the AMC13 format (64bits)
    );
    port (
        reset_i                 : in  std_logic;
        
        -- PCIe reset and clocks
        pcie_reset_b_i          : in  std_logic;
        pcie_refclk_i           : in  std_logic;
        pcie_sysclk_i           : in  std_logic; -- should be connected to the odiv2 of the refclk buffer
                                
        -- PCIe status          
        pcie_phy_ready_o        : out std_logic;
        pcie_link_up_o          : out std_logic;
                                
        status_leds_o           : out std_logic_vector(3 downto 0);
        led_i                   : in  std_logic;

        -- DAQlink interface        
        daq_to_daqlink_i        : in  t_daq_to_daqlink;
        daqlink_to_daq_o        : out t_daqlink_to_daq;
        
        -- PCIe DAQ control and status
        axi_clk_o               : out std_logic;
        axi_reset_b_o           : out std_logic;
        pcie_daq_control_i      : in  t_pcie_daq_control;
        pcie_daq_status_o       : out t_pcie_daq_status;
        
        -- H2C stream
        h2c_stream_o            : out t_axi_h2c_stream;
        h2c_stream_ready_i      : in  std_logic := '0';
        h2c_tst_link_clk_i      : in  std_logic := '0';
        h2c_tst_link_data_o     : out t_mgt_64b_tx_data;        
        
        -- IPbus
        ipb_reset_o             : out std_logic;
        ipb_clk_i               : in  std_logic;
        ipb_usr_miso_arr_i      : in  ipb_rbus_array(C_NUM_IPB_SLAVES * g_NUM_USR_BLOCKS - 1 downto 0);
        ipb_usr_mosi_arr_o      : out ipb_wbus_array(C_NUM_IPB_SLAVES * g_NUM_USR_BLOCKS - 1 downto 0);
        ipb_sys_miso_arr_i      : in  ipb_rbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);
        ipb_sys_mosi_arr_o      : out ipb_wbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0)
    );
end pcie;

architecture pcie_arch of pcie is

    -- XDMA: 4x pcie gen2 with axi stream
    component pcie_xdma
        port(
            sys_clk                 : in  std_logic;
            sys_clk_gt              : in  std_logic;
            sys_rst_n               : in  std_logic;
            user_lnk_up             : out std_logic;
            pci_exp_txp             : out std_logic_vector(3 downto 0);
            pci_exp_txn             : out std_logic_vector(3 downto 0);
            pci_exp_rxp             : in  std_logic_vector(3 downto 0);
            pci_exp_rxn             : in  std_logic_vector(3 downto 0);
            axi_aclk                : out std_logic;
            axi_aresetn             : out std_logic;
            usr_irq_req             : in  std_logic;
            usr_irq_ack             : out std_logic;
            msi_enable              : out std_logic;
            msi_vector_width        : out std_logic_vector(2 downto 0);
            m_axil_awaddr           : out std_logic_vector(31 downto 0);
            m_axil_awprot           : out std_logic_vector(2 downto 0);
            m_axil_awvalid          : out std_logic;
            m_axil_awready          : in  std_logic;
            m_axil_wdata            : out std_logic_vector(31 downto 0);
            m_axil_wstrb            : out std_logic_vector(3 downto 0);
            m_axil_wvalid           : out std_logic;
            m_axil_wready           : in  std_logic;
            m_axil_bvalid           : in  std_logic;
            m_axil_bresp            : in  std_logic_vector(1 downto 0);
            m_axil_bready           : out std_logic;
            m_axil_araddr           : out std_logic_vector(31 downto 0);
            m_axil_arprot           : out std_logic_vector(2 downto 0);
            m_axil_arvalid          : out std_logic;
            m_axil_arready          : in  std_logic;
            m_axil_rdata            : in  std_logic_vector(31 downto 0);
            m_axil_rresp            : in  std_logic_vector(1 downto 0);
            m_axil_rvalid           : in  std_logic;
            m_axil_rready           : out std_logic;
            s_axis_c2h_tdata_0      : in  std_logic_vector(127 downto 0);
            s_axis_c2h_tlast_0      : in  std_logic;
            s_axis_c2h_tvalid_0     : in  std_logic;
            s_axis_c2h_tready_0     : out std_logic;
            s_axis_c2h_tkeep_0      : in  std_logic_vector(15 downto 0);
            m_axis_h2c_tdata_0      : out std_logic_vector(127 downto 0);
            m_axis_h2c_tlast_0      : out std_logic;
            m_axis_h2c_tvalid_0     : out std_logic;
            m_axis_h2c_tready_0     : in  std_logic;
            m_axis_h2c_tkeep_0      : out std_logic_vector(15 downto 0);
            c2h_sts_0               : out std_logic_vector(7 downto 0);
            h2c_sts_0               : out std_logic_vector(7 downto 0);
            cfg_negotiated_width_o  : out std_logic_vector(3 downto 0);
            cfg_current_speed_o     : out std_logic_vector(2 downto 0);
            cfg_ltssm_state_o       : out std_logic_vector(5 downto 0);
            cfg_err_cor_o           : out std_logic;
            cfg_err_fatal_o         : out std_logic;
            cfg_err_nonfatal_o      : out std_logic;
            cfg_local_error_o       : out std_logic_vector(4 downto 0);
            cfg_local_error_valid_o : out std_logic
        );
    end component;
    
    -- QDMA: 4x pcie gen2 with AXI stream
    component pcie_qdma
        port(
            sys_clk                              : in  std_logic;
            sys_clk_gt                           : in  std_logic;
            sys_rst_n                            : in  std_logic;
            user_lnk_up                          : out std_logic;
            pci_exp_txp                          : out std_logic_vector(3 downto 0);
            pci_exp_txn                          : out std_logic_vector(3 downto 0);
            pci_exp_rxp                          : in  std_logic_vector(3 downto 0);
            pci_exp_rxn                          : in  std_logic_vector(3 downto 0);
            axi_aclk                             : out std_logic;
            axi_aresetn                          : out std_logic;
            usr_irq_in_vld                       : in  std_logic;
            usr_irq_in_vec                       : in  std_logic_vector(10 downto 0);
            usr_irq_in_fnc                       : in  std_logic_vector(7 downto 0);
            usr_irq_out_ack                      : out std_logic;
            usr_irq_out_fail                     : out std_logic;
            tm_dsc_sts_vld                       : out std_logic;
            tm_dsc_sts_port_id                   : out std_logic_vector(2 downto 0);
            tm_dsc_sts_qen                       : out std_logic;
            tm_dsc_sts_byp                       : out std_logic;
            tm_dsc_sts_dir                       : out std_logic;
            tm_dsc_sts_mm                        : out std_logic;
            tm_dsc_sts_error                     : out std_logic;
            tm_dsc_sts_qid                       : out std_logic_vector(10 downto 0);
            tm_dsc_sts_avl                       : out std_logic_vector(15 downto 0);
            tm_dsc_sts_qinv                      : out std_logic;
            tm_dsc_sts_irq_arm                   : out std_logic;
            tm_dsc_sts_rdy                       : in  std_logic;
            tm_dsc_sts_pidx                      : out std_logic_vector(15 downto 0);
            dsc_crdt_in_crdt                     : in  std_logic_vector(15 downto 0);
            dsc_crdt_in_qid                      : in  std_logic_vector(10 downto 0);
            dsc_crdt_in_dir                      : in  std_logic;
            dsc_crdt_in_fence                    : in  std_logic;
            dsc_crdt_in_vld                      : in  std_logic;
            dsc_crdt_in_rdy                      : out std_logic;
            m_axil_awaddr                        : out std_logic_vector(31 downto 0);
            m_axil_awuser                        : out std_logic_vector(54 downto 0);
            m_axil_awprot                        : out std_logic_vector(2 downto 0);
            m_axil_awvalid                       : out std_logic;
            m_axil_awready                       : in  std_logic;
            m_axil_wdata                         : out std_logic_vector(31 downto 0);
            m_axil_wstrb                         : out std_logic_vector(3 downto 0);
            m_axil_wvalid                        : out std_logic;
            m_axil_wready                        : in  std_logic;
            m_axil_bvalid                        : in  std_logic;
            m_axil_bresp                         : in  std_logic_vector(1 downto 0);
            m_axil_bready                        : out std_logic;
            m_axil_araddr                        : out std_logic_vector(31 downto 0);
            m_axil_aruser                        : out std_logic_vector(54 downto 0);
            m_axil_arprot                        : out std_logic_vector(2 downto 0);
            m_axil_arvalid                       : out std_logic;
            m_axil_arready                       : in  std_logic;
            m_axil_rdata                         : in  std_logic_vector(31 downto 0);
            m_axil_rresp                         : in  std_logic_vector(1 downto 0);
            m_axil_rvalid                        : in  std_logic;
            m_axil_rready                        : out std_logic;
            m_axis_h2c_tdata                     : out std_logic_vector(63 downto 0);
            m_axis_h2c_tcrc                      : out std_logic_vector(31 downto 0);
            m_axis_h2c_tuser_qid                 : out std_logic_vector(10 downto 0);
            m_axis_h2c_tuser_port_id             : out std_logic_vector(2 downto 0);
            m_axis_h2c_tuser_err                 : out std_logic;
            m_axis_h2c_tuser_mdata               : out std_logic_vector(31 downto 0);
            m_axis_h2c_tuser_mty                 : out std_logic_vector(5 downto 0);
            m_axis_h2c_tuser_zero_byte           : out std_logic;
            m_axis_h2c_tvalid                    : out std_logic;
            m_axis_h2c_tlast                     : out std_logic;
            m_axis_h2c_tready                    : in  std_logic;
            s_axis_c2h_tdata                     : in  std_logic_vector(63 downto 0);
            s_axis_c2h_tcrc                      : in  std_logic_vector(31 downto 0);
            s_axis_c2h_ctrl_marker               : in  std_logic;
            s_axis_c2h_ctrl_port_id              : in  std_logic_vector(2 downto 0);
            s_axis_c2h_ctrl_ecc                  : in  std_logic_vector(6 downto 0);
            s_axis_c2h_ctrl_len                  : in  std_logic_vector(15 downto 0);
            s_axis_c2h_ctrl_qid                  : in  std_logic_vector(10 downto 0);
            s_axis_c2h_ctrl_has_cmpt             : in  std_logic;
            s_axis_c2h_mty                       : in  std_logic_vector(5 downto 0);
            s_axis_c2h_tvalid                    : in  std_logic;
            s_axis_c2h_tlast                     : in  std_logic;
            s_axis_c2h_tready                    : out std_logic;
            s_axis_c2h_cmpt_tdata                : in  std_logic_vector(511 downto 0);
            s_axis_c2h_cmpt_size                 : in  std_logic_vector(1 downto 0);
            s_axis_c2h_cmpt_dpar                 : in  std_logic_vector(15 downto 0);
            s_axis_c2h_cmpt_tvalid               : in  std_logic;
            s_axis_c2h_cmpt_ctrl_qid             : in  std_logic_vector(10 downto 0);
            s_axis_c2h_cmpt_ctrl_cmpt_type       : in  std_logic_vector(1 downto 0);
            s_axis_c2h_cmpt_ctrl_wait_pld_pkt_id : in  std_logic_vector(15 downto 0);
            s_axis_c2h_cmpt_ctrl_port_id         : in  std_logic_vector(2 downto 0);
            s_axis_c2h_cmpt_ctrl_marker          : in  std_logic;
            s_axis_c2h_cmpt_ctrl_user_trig       : in  std_logic;
            s_axis_c2h_cmpt_ctrl_col_idx         : in  std_logic_vector(2 downto 0);
            s_axis_c2h_cmpt_ctrl_err_idx         : in  std_logic_vector(2 downto 0);
            s_axis_c2h_cmpt_tready               : out std_logic;
            s_axis_c2h_cmpt_ctrl_no_wrb_marker   : in  std_logic;
            axis_c2h_status_drop                 : out std_logic;
            axis_c2h_status_valid                : out std_logic;
            axis_c2h_status_cmp                  : out std_logic;
            axis_c2h_status_error                : out std_logic;
            axis_c2h_status_last                 : out std_logic;
            axis_c2h_status_qid                  : out std_logic_vector(10 downto 0);
            axis_c2h_dmawr_cmp                   : out std_logic;
            cfg_negotiated_width_o               : out std_logic_vector(3 downto 0);
            cfg_current_speed_o                  : out std_logic_vector(2 downto 0);
            cfg_ltssm_state_o                    : out std_logic_vector(5 downto 0);
            soft_reset_n                         : in  std_logic;
            phy_ready                            : out std_logic;
            qsts_out_op                          : out std_logic_vector(7 downto 0);
            qsts_out_data                        : out std_logic_vector(63 downto 0);
            qsts_out_port_id                     : out std_logic_vector(2 downto 0);
            qsts_out_qid                         : out std_logic_vector(12 downto 0);
            qsts_out_vld                         : out std_logic;
            qsts_out_rdy                         : in  std_logic
        );
    end component;    
    
    component vio_pcie
        port(
            clk       : in std_logic;
            probe_in0 : in std_logic;
            probe_in1 : in std_logic_vector(3 downto 0);
            probe_in2 : in std_logic_vector(2 downto 0);
            probe_in3 : in std_logic_vector(5 downto 0);
            probe_in4 : in std_logic;
            probe_in5 : in std_logic;
            probe_in6 : in std_logic;
            probe_in7 : in std_logic_vector(4 downto 0);
            probe_in8 : in std_logic
        );
    end component;    
    
    component ila_pcie_daq
        port(
            clk     : in std_logic;
            probe0  : in std_logic;
            probe1  : in std_logic;
            probe2  : in std_logic_vector(127 downto 0);
            probe3  : in std_logic;
            probe4  : in std_logic;
            probe5  : in std_logic;
            probe6  : in std_logic;
            probe7  : in std_logic_vector(19 downto 0);
            probe8  : in std_logic_vector(19 downto 0);
            probe9  : in std_logic;
            probe10 : in std_logic_vector(127 downto 0);
            probe11 : in std_logic;
            probe12 : in std_logic_vector(15 downto 0);
            probe13 : in std_logic
        );
    end component;    
    
    -- pcie
    signal reset_sync_axi       : std_logic;
    signal qdma_soft_reset      : std_logic;
    signal qdma_reset_cntdown   : integer range 0 to 150 := 0;

    signal pcie_serial_txp      : std_logic_vector(15 downto 0);
    signal pcie_serial_txn      : std_logic_vector(15 downto 0);

    -- pcie status
    signal pcie_link_up         : std_logic;
    signal pcie_phy_ready       : std_logic;
    signal pcie_width           : std_logic_vector(3 downto 0);
    signal pcie_speed           : std_logic_vector(2 downto 0);
    signal pcie_train_state     : std_logic_vector(5 downto 0);
    signal pcie_err_cor         : std_logic;
    signal pcie_err_fatal       : std_logic;
    signal pcie_err_nonfatal    : std_logic;
    signal pcie_local_err       : std_logic_vector(4 downto 0);
    signal pcie_local_err_valid : std_logic;
    
    signal status_leds          : std_logic_vector(3 downto 0);
    signal pcie_link_led_seq    : std_logic_vector(151 downto 0) := (others => '1');
    signal pcie_link_led_seq_idx: integer range 0 to 151 := 0;
    
    constant PCIE_LINK_LED_SEQ_SEPARATOR    : std_logic_vector(15 downto 0) := x"5500";
    constant PCIE_LINK_LED_SEQ_HIGH         : std_logic_vector(7 downto 0) := x"7e";
    constant PCIE_LINK_LED_SEQ_LOW          : std_logic_vector(7 downto 0) := x"18";
        
    -- axi common
    signal axi_clk              : std_logic;
    signal axi_reset_b          : std_logic;

    -- axi stream / DAQ

    function get_daqlink_width(is_slink_rocket : boolean) return integer is
    begin
        if is_slink_rocket then
            return 128;
        else
            return 64;
        end if;
    end function get_daqlink_width; 

    constant AXIS_WIDTH         : integer := 64;
    constant DAQLINK_WIDTH      : integer := get_daqlink_width(g_IS_SLINK_ROCKET);
    
    signal axis_h2c_tdata                       : std_logic_vector(63 downto 0);
    signal axis_h2c_tcrc                        : std_logic_vector(31 downto 0);
    signal axis_h2c_tuser_qid                   : std_logic_vector(10 downto 0);
    signal axis_h2c_tuser_port_id               : std_logic_vector(2 downto 0);
    signal axis_h2c_tuser_err                   : std_logic;
    signal axis_h2c_tuser_mdata                 : std_logic_vector(31 downto 0);
    signal axis_h2c_tuser_mty                   : std_logic_vector(5 downto 0);
    signal axis_h2c_tuser_zero_byte             : std_logic;
    signal axis_h2c_tvalid                      : std_logic;
    signal axis_h2c_tlast                       : std_logic;
    signal axis_h2c_tready                      : std_logic;
                                                
    signal axis_c2h_tdata                       : std_logic_vector(63 downto 0);
    signal axis_c2h_tcrc                        : std_logic_vector(31 downto 0);
    signal axis_c2h_ctrl_marker                 : std_logic;
    signal axis_c2h_ctrl_port_id                : std_logic_vector(2 downto 0);
    signal axis_c2h_ctrl_ecc                    : std_logic_vector(6 downto 0);
    signal axis_c2h_ctrl_len                    : std_logic_vector(15 downto 0);
    signal axis_c2h_ctrl_qid                    : std_logic_vector(10 downto 0);
    signal axis_c2h_ctrl_has_cmpt               : std_logic;
    signal axis_c2h_mty                         : std_logic_vector(5 downto 0);
    signal axis_c2h_tvalid                      : std_logic;
    signal axis_c2h_tlast                       : std_logic;
    signal axis_c2h_tready                      : std_logic;
    signal axis_c2h_cmpt_tdata                  : std_logic_vector(511 downto 0);
    signal axis_c2h_cmpt_size                   : std_logic_vector(1 downto 0);
    signal axis_c2h_cmpt_dpar                   : std_logic_vector(15 downto 0);
    signal axis_c2h_cmpt_tvalid                 : std_logic;
    signal axis_c2h_cmpt_ctrl_qid               : std_logic_vector(10 downto 0);
    signal axis_c2h_cmpt_ctrl_cmpt_type         : std_logic_vector(1 downto 0);
    signal axis_c2h_cmpt_ctrl_wait_pld_pkt_id   : std_logic_vector(15 downto 0);
    signal axis_c2h_cmpt_ctrl_port_id           : std_logic_vector(2 downto 0);
    signal axis_c2h_cmpt_ctrl_marker            : std_logic;
    signal axis_c2h_cmpt_ctrl_user_trig         : std_logic;
    signal axis_c2h_cmpt_ctrl_col_idx           : std_logic_vector(2 downto 0);
    signal axis_c2h_cmpt_ctrl_err_idx           : std_logic_vector(2 downto 0);
    signal axis_c2h_cmpt_tready                 : std_logic;
    signal axis_c2h_cmpt_ctrl_no_wrb_marker     : std_logic;
    signal axis_c2h_status_drop                 : std_logic;
    signal axis_c2h_status_valid                : std_logic;
    signal axis_c2h_status_cmp                  : std_logic;
    signal axis_c2h_status_error                : std_logic;
    signal axis_c2h_status_last                 : std_logic;
    signal axis_c2h_status_qid                  : std_logic_vector(10 downto 0);
    signal axis_c2h_dmawr_cmp                   : std_logic;
    
    
    -- axi stream / DAQ (old with XDMA)

    signal axis_c2h             : t_axi_stream_128;
    signal axis_c2h_ready       : std_logic;
    signal axis_h2c             : t_axi_stream_128;
    signal axis_h2c_ready       : std_logic;
    
    signal c2h_status           : std_logic_vector(7 downto 0);
    signal h2c_status           : std_logic_vector(7 downto 0);
    
    signal c2h_write_err        : std_logic;
    
    signal fed_clk              : std_logic;
    signal fed_data             : std_logic_vector(127 downto 0);
    signal fed_data_head        : std_logic;
    signal fed_data_trail       : std_logic;
    signal fed_data_we          : std_logic;
                                
    signal fed_data_d           : std_logic_vector(127 downto 0);
    signal fed_data_head_d      : std_logic;
    signal fed_data_trail_d     : std_logic;
    signal fed_data_we_d        : std_logic;
                                
    signal crc                  : std_logic_vector(15 downto 0);
    signal crc_data_in          : std_logic_vector(127 downto 0);
    signal crc_clear            : std_logic;
    signal crc_en               : std_logic;        
    
    signal daq_cdc_empty        : std_logic;
    signal daq_cdc_valid        : std_logic;
    signal daq_cdc_ovf          : std_logic;
    signal daq_cdc_ovf_axi_clk  : std_logic;
    signal daq_cdc_ovf_latch    : std_logic;
    signal daq_cdc_data         : std_logic_vector(127 downto 0);
    signal daq_cdc_rd_en        : std_logic;

    signal daq_reset            : std_logic;
    signal daqlink_reset_axi_clk: std_logic;
    signal daqlink_valid_axi_clk: std_logic;
    signal daq_enabled_axi_clk  : std_logic;
    signal daq_flush            : std_logic;
    
    signal c2h_backpressure     : std_logic;
    signal c2h_packet_size_words: unsigned(19 downto 0);
    signal c2h_words_cntdown    : unsigned(19 downto 0);

    -- axi lite    
    signal axil_m2s             : t_axi_lite_m2s;
    signal axil_s2m             : t_axi_lite_s2m;

    signal ipb_mmcm_fbclk       : std_logic;

    signal ipb_read_active      : std_logic;
    signal ipb_write_active     : std_logic;

    -- axi full (for test only)
    signal axi_m2s              : t_axi_full_64_m2s;
    signal axi_s2m              : t_axi_full_64_s2m := AXI_FULL_64_MISO_NULL;
    
begin

    --================================--
    -- Wiring
    --================================--
    
    pcie_link_up_o <= pcie_link_up;
    pcie_phy_ready_o <= pcie_phy_ready;
    axi_clk_o <= axi_clk;
    axi_reset_b_o <= axi_reset_b;
    
    --================================--
    -- PCIe XDMA module
    --================================--

    g_xdma : if not g_USE_QDMA generate

        i_pcie_dma : pcie_xdma
            port map(
                sys_clk                 => pcie_sysclk_i,
                sys_clk_gt              => pcie_refclk_i,
                sys_rst_n               => pcie_reset_b_i,
                user_lnk_up             => pcie_link_up,
                pci_exp_txp             => pcie_serial_txp(3 downto 0),
                pci_exp_txn             => pcie_serial_txn(3 downto 0),
                pci_exp_rxp             => (others => '1'),
                pci_exp_rxn             => (others => '0'),
                                        
                axi_aclk                => axi_clk,
                axi_aresetn             => axi_reset_b,
                usr_irq_req             => '0',
                usr_irq_ack             => open,
                msi_enable              => open,
                msi_vector_width        => open,
                                        
                -- axi lite             
                m_axil_awaddr           => axil_m2s.awaddr,
                m_axil_awprot           => axil_m2s.awprot,
                m_axil_awvalid          => axil_m2s.awvalid,
                m_axil_awready          => axil_s2m.awready,
                m_axil_wdata            => axil_m2s.wdata, 
                m_axil_wstrb            => axil_m2s.wstrb, 
                m_axil_wvalid           => axil_m2s.wvalid,
                m_axil_wready           => axil_s2m.wready,
                m_axil_bvalid           => axil_s2m.bvalid,
                m_axil_bresp            => axil_s2m.bresp, 
                m_axil_bready           => axil_m2s.bready,
                m_axil_araddr           => axil_m2s.araddr,
                m_axil_arprot           => axil_m2s.arprot, 
                m_axil_arvalid          => axil_m2s.arvalid,
                m_axil_arready          => axil_s2m.arready,
                m_axil_rdata            => axil_s2m.rdata,  
                m_axil_rresp            => axil_s2m.rresp,  
                m_axil_rvalid           => axil_s2m.rvalid, 
                m_axil_rready           => axil_m2s.rready, 
                                        
                s_axis_c2h_tdata_0      => axis_c2h.tdata,
                s_axis_c2h_tlast_0      => axis_c2h.tlast,
                s_axis_c2h_tvalid_0     => axis_c2h.tvalid,
                s_axis_c2h_tready_0     => axis_c2h_ready,
                s_axis_c2h_tkeep_0      => axis_c2h.tkeep,
                m_axis_h2c_tdata_0      => axis_h2c.tdata,
                m_axis_h2c_tlast_0      => axis_h2c.tlast,
                m_axis_h2c_tvalid_0     => axis_h2c.tvalid,
                m_axis_h2c_tready_0     => axis_h2c_ready,
                m_axis_h2c_tkeep_0      => axis_h2c.tkeep,
                c2h_sts_0               => c2h_status,
                h2c_sts_0               => h2c_status,
    
                cfg_negotiated_width_o  => pcie_width,
                cfg_current_speed_o     => pcie_speed,
                cfg_ltssm_state_o       => pcie_train_state,
                cfg_err_cor_o           => pcie_err_cor,
                cfg_err_fatal_o         => pcie_err_fatal,
                cfg_err_nonfatal_o      => pcie_err_nonfatal,
                cfg_local_error_o       => pcie_local_err,
                cfg_local_error_valid_o => pcie_local_err_valid
            );
    
        --================================--
        -- AXI stream
        --================================--  
      
        axis_h2c_ready <= '1';
        fed_clk <= daq_to_daqlink_i.event_clk;
        
        ---------- Calculate CRC ----------
    
        daq_reset <= daqlink_reset_axi_clk or pcie_daq_control_i.reset;        
            
        process(fed_clk)
        begin
            if rising_edge(fed_clk) then
                fed_data_d       <= daq_to_daqlink_i.event_data;
                fed_data_head_d  <= daq_to_daqlink_i.event_header;
                fed_data_trail_d <= daq_to_daqlink_i.event_trailer;
                fed_data_we_d    <= daq_to_daqlink_i.event_valid;
                crc_clear      <= daq_to_daqlink_i.event_trailer or daq_reset;
                
                -- substitute the CRC
                if fed_data_trail_d = '1' then
                    fed_data(31 downto 16) <= crc;
                else
                    fed_data(31 downto 16) <= fed_data_d(31 downto 16);
                end if;
                fed_data(127 downto 32) <= fed_data_d(127 downto 32);
                fed_data(15 downto 0) <= fed_data_d(15 downto 0);
                fed_data_head    <= fed_data_head_d;
                fed_data_trail   <= fed_data_trail_d;
                fed_data_we      <= fed_data_we_d;            
            end if;
        end process;
        
        crc_en <= daq_to_daqlink_i.event_valid;
        crc_data_in <= daq_to_daqlink_i.event_data;
        
        i_crc : entity work.FED_fragment_CRC16_D128b
            port map ( 
                clear_p  => crc_clear,
                clk      => fed_clk,
                enable   => crc_en,
                Data     => crc_data_in,
                CRC_out  => crc
            );
        
        -- CDC fifo between the DAQ clk and the AXI clk
        i_daq_cdc_fifo : xpm_fifo_async
            generic map(
                FIFO_MEMORY_TYPE    => "block",
                FIFO_WRITE_DEPTH    => 128,
                RELATED_CLOCKS      => 0,
                WRITE_DATA_WIDTH    => 128,
                READ_MODE           => "std",
                FIFO_READ_LATENCY   => 1,
                FULL_RESET_VALUE    => 0,
                USE_ADV_FEATURES    => "1001", -- VALID(12) = 1 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 0; UNDERFLOW(8) = 0; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 0; OVERFLOW(0) = 1
                READ_DATA_WIDTH     => 128,
                CDC_SYNC_STAGES     => 2,
                DOUT_RESET_VALUE    => "0",
                ECC_MODE            => "no_ecc"
            )
            port map(
                sleep         => '0',
                rst           => daq_to_daqlink_i.reset,
                wr_clk        => fed_clk,
                wr_en         => fed_data_we,
                din           => fed_data,
                full          => open,
                prog_full     => open,
                wr_data_count => open,
                overflow      => daq_cdc_ovf,
                wr_rst_busy   => open,
                almost_full   => open,
                wr_ack        => open,
                rd_clk        => axi_clk,
                rd_en         => daq_cdc_rd_en,
                dout          => daq_cdc_data,
                empty         => daq_cdc_empty,
                prog_empty    => open,
                rd_data_count => open,
                underflow     => open,
                rd_rst_busy   => open,
                almost_empty  => open,
                data_valid    => daq_cdc_valid,
                injectsbiterr => '0',
                injectdbiterr => '0',
                sbiterr       => open,
                dbiterr       => open
            );    
    
        i_daq_cdc_ovf_sync    : entity work.synch generic map(N_STAGES => 4, IS_RESET => false) port map(async_i => daq_cdc_ovf, clk_i => axi_clk, sync_o => daq_cdc_ovf_axi_clk);
        i_daqlink_reset_sync  : entity work.synch generic map(N_STAGES => 4, IS_RESET => true) port map(async_i => daq_to_daqlink_i.reset, clk_i => axi_clk, sync_o => daqlink_reset_axi_clk);
        i_daqlink_valid_sync  : entity work.synch generic map(N_STAGES => 4, IS_RESET => true) port map(async_i => daq_to_daqlink_i.event_valid, clk_i => axi_clk, sync_o => daqlink_valid_axi_clk);
        i_daqlink_enable_sync : entity work.synch generic map(N_STAGES => 4, IS_RESET => true) port map(async_i => daq_to_daqlink_i.daq_enabled, clk_i => axi_clk, sync_o => daq_enabled_axi_clk);
    
        i_daqlink_ready_sync : entity work.synch generic map(N_STAGES => 4, IS_RESET => false) port map(async_i => pcie_link_up, clk_i => daq_to_daqlink_i.event_clk, sync_o => daqlink_to_daq_o.ready);
        i_daqlink_bp_sync    : entity work.synch generic map(N_STAGES => 4, IS_RESET => false) port map(async_i => c2h_backpressure, clk_i => daq_to_daqlink_i.event_clk, sync_o => daqlink_to_daq_o.backpressure);
        daqlink_to_daq_o.disperr_cnt <= (others => '0');
        daqlink_to_daq_o.notintable_cnt <= (others => '0');
    
        c2h_backpressure <= not axis_c2h_ready and not daq_cdc_empty;
        daq_cdc_rd_en <= not daq_cdc_empty and axis_c2h_ready;
        axis_c2h.tdata <= daq_cdc_data(127 downto 0);
        axis_c2h.tlast <= daq_cdc_valid and not or_reduce(std_logic_vector(c2h_words_cntdown));
        axis_c2h.tvalid <= daq_cdc_valid;
        axis_c2h.tkeep <= (others => daq_cdc_valid);
        
        c2h_packet_size_words <= unsigned(pcie_daq_control_i.packet_size_bytes(23 downto 4)); -- divide by 16 to get 128 bit words
        
        process(axi_clk)
        begin
            if rising_edge(axi_clk) then
                if daq_reset = '1' then
                    c2h_words_cntdown <= c2h_packet_size_words - 1;
                else
                    if daq_cdc_valid = '1' then
                        if c2h_words_cntdown = x"00000" then
                            c2h_words_cntdown <= c2h_packet_size_words - 1;
                        else
                            c2h_words_cntdown <= c2h_words_cntdown - 1;
                        end if;
                    end if;
                end if;
            end if;
        end process;
    
        i_daq_cdc_ovf_latch : entity work.latch
            port map(
                reset_i => daq_reset,
                clk_i   => axi_clk,
                input_i => daq_cdc_ovf_axi_clk,
                latch_o => daq_cdc_ovf_latch
            );
    
        i_words_sent_cnt : entity work.counter
            generic map(
                g_COUNTER_WIDTH  => 44,
                g_ALLOW_ROLLOVER => false
            )
            port map(
                ref_clk_i => axi_clk,
                reset_i   => daq_reset,
                en_i      => axis_c2h.tvalid,
                count_o   => pcie_daq_status_o.words_sent
            );
    
        i_word_rate : entity work.rate_counter
            generic map(
                g_CLK_FREQUENCY => std_logic_vector(to_unsigned(125_000_000, 32)),
                g_COUNTER_WIDTH => 28
            )
            port map(
                clk_i   => axi_clk,
                reset_i => daq_reset,
                en_i    => axis_c2h.tvalid,
                rate_o  => pcie_daq_status_o.word_rate
            );

    end generate;

    --================================--
    -- PCIe QDMA module
    --================================--

    g_qdma : if g_USE_QDMA generate

        i_pcie_qdma : pcie_qdma
            port map(
                sys_clk                              => pcie_sysclk_i,
                sys_clk_gt                           => pcie_refclk_i,
                sys_rst_n                            => pcie_reset_b_i,
                user_lnk_up                          => pcie_link_up,
                pci_exp_txp                          => pcie_serial_txp(3 downto 0),
                pci_exp_txn                          => pcie_serial_txn(3 downto 0),
                pci_exp_rxp                          => (others => '1'),
                pci_exp_rxn                          => (others => '0'),
                axi_aclk                             => axi_clk,
                axi_aresetn                          => axi_reset_b,
                usr_irq_in_vld                       => '0',
                usr_irq_in_vec                       => (others => '0'),
                usr_irq_in_fnc                       => (others => '0'),
                usr_irq_out_ack                      => open,
                usr_irq_out_fail                     => open,
                tm_dsc_sts_vld                       => open,
                tm_dsc_sts_port_id                   => open,
                tm_dsc_sts_qen                       => open,
                tm_dsc_sts_byp                       => open,
                tm_dsc_sts_dir                       => open,
                tm_dsc_sts_mm                        => open,
                tm_dsc_sts_error                     => open,
                tm_dsc_sts_qid                       => open,
                tm_dsc_sts_avl                       => open,
                tm_dsc_sts_qinv                      => open,
                tm_dsc_sts_irq_arm                   => open,
                tm_dsc_sts_rdy                       => '1',
                tm_dsc_sts_pidx                      => open,
                dsc_crdt_in_crdt                     => (others => '0'),
                dsc_crdt_in_qid                      => (others => '0'),
                dsc_crdt_in_dir                      => '0',
                dsc_crdt_in_fence                    => '0',
                dsc_crdt_in_vld                      => '0',
                dsc_crdt_in_rdy                      => open,
                m_axil_awaddr                        => axil_m2s.awaddr,
                m_axil_awuser                        => open,
                m_axil_awprot                        => axil_m2s.awprot,
                m_axil_awvalid                       => axil_m2s.awvalid,
                m_axil_awready                       => axil_s2m.awready,
                m_axil_wdata                         => axil_m2s.wdata,
                m_axil_wstrb                         => axil_m2s.wstrb,
                m_axil_wvalid                        => axil_m2s.wvalid,
                m_axil_wready                        => axil_s2m.wready,
                m_axil_bvalid                        => axil_s2m.bvalid,
                m_axil_bresp                         => axil_s2m.bresp,
                m_axil_bready                        => axil_m2s.bready,
                m_axil_araddr                        => axil_m2s.araddr,
                m_axil_aruser                        => open,
                m_axil_arprot                        => axil_m2s.arprot,
                m_axil_arvalid                       => axil_m2s.arvalid,
                m_axil_arready                       => axil_s2m.arready,
                m_axil_rdata                         => axil_s2m.rdata,
                m_axil_rresp                         => axil_s2m.rresp,
                m_axil_rvalid                        => axil_s2m.rvalid,
                m_axil_rready                        => axil_m2s.rready,
                m_axis_h2c_tdata                     => axis_h2c_tdata,
                m_axis_h2c_tcrc                      => axis_h2c_tcrc,
                m_axis_h2c_tuser_qid                 => axis_h2c_tuser_qid,
                m_axis_h2c_tuser_port_id             => axis_h2c_tuser_port_id,
                m_axis_h2c_tuser_err                 => axis_h2c_tuser_err,
                m_axis_h2c_tuser_mdata               => axis_h2c_tuser_mdata,
                m_axis_h2c_tuser_mty                 => axis_h2c_tuser_mty,
                m_axis_h2c_tuser_zero_byte           => axis_h2c_tuser_zero_byte,
                m_axis_h2c_tvalid                    => axis_h2c_tvalid,
                m_axis_h2c_tlast                     => axis_h2c_tlast,
                m_axis_h2c_tready                    => axis_h2c_tready,
                s_axis_c2h_tdata                     => axis_c2h_tdata,
                s_axis_c2h_tcrc                      => axis_c2h_tcrc,
                s_axis_c2h_ctrl_marker               => axis_c2h_ctrl_marker,
                s_axis_c2h_ctrl_port_id              => axis_c2h_ctrl_port_id,
                s_axis_c2h_ctrl_ecc                  => axis_c2h_ctrl_ecc,
                s_axis_c2h_ctrl_len                  => axis_c2h_ctrl_len,
                s_axis_c2h_ctrl_qid                  => axis_c2h_ctrl_qid,
                s_axis_c2h_ctrl_has_cmpt             => axis_c2h_ctrl_has_cmpt,
                s_axis_c2h_mty                       => axis_c2h_mty,
                s_axis_c2h_tvalid                    => axis_c2h_tvalid,
                s_axis_c2h_tlast                     => axis_c2h_tlast,
                s_axis_c2h_tready                    => axis_c2h_tready,
                s_axis_c2h_cmpt_tdata                => axis_c2h_cmpt_tdata,
                s_axis_c2h_cmpt_size                 => axis_c2h_cmpt_size,
                s_axis_c2h_cmpt_dpar                 => axis_c2h_cmpt_dpar,
                s_axis_c2h_cmpt_tvalid               => axis_c2h_cmpt_tvalid,
                s_axis_c2h_cmpt_ctrl_qid             => axis_c2h_cmpt_ctrl_qid,
                s_axis_c2h_cmpt_ctrl_cmpt_type       => axis_c2h_cmpt_ctrl_cmpt_type,
                s_axis_c2h_cmpt_ctrl_wait_pld_pkt_id => axis_c2h_cmpt_ctrl_wait_pld_pkt_id,
                s_axis_c2h_cmpt_ctrl_port_id         => axis_c2h_cmpt_ctrl_port_id,
                s_axis_c2h_cmpt_ctrl_marker          => axis_c2h_cmpt_ctrl_marker,
                s_axis_c2h_cmpt_ctrl_user_trig       => axis_c2h_cmpt_ctrl_user_trig,
                s_axis_c2h_cmpt_ctrl_col_idx         => axis_c2h_cmpt_ctrl_col_idx,
                s_axis_c2h_cmpt_ctrl_err_idx         => axis_c2h_cmpt_ctrl_err_idx,
                s_axis_c2h_cmpt_tready               => axis_c2h_cmpt_tready,
                s_axis_c2h_cmpt_ctrl_no_wrb_marker   => axis_c2h_cmpt_ctrl_no_wrb_marker,
                axis_c2h_status_drop                 => axis_c2h_status_drop,
                axis_c2h_status_valid                => axis_c2h_status_valid,
                axis_c2h_status_cmp                  => axis_c2h_status_cmp,
                axis_c2h_status_error                => axis_c2h_status_error,
                axis_c2h_status_last                 => axis_c2h_status_last,
                axis_c2h_status_qid                  => axis_c2h_status_qid,
                axis_c2h_dmawr_cmp                   => axis_c2h_dmawr_cmp,
                cfg_negotiated_width_o               => pcie_width,
                cfg_current_speed_o                  => pcie_speed,
                cfg_ltssm_state_o                    => pcie_train_state,
                soft_reset_n                         => '1', --qdma_soft_reset,
                phy_ready                            => pcie_phy_ready,
                qsts_out_op                          => open,
                qsts_out_data                        => open,
                qsts_out_port_id                     => open,
                qsts_out_qid                         => open,
                qsts_out_vld                         => open,
                qsts_out_rdy                         => '1'
            );
        
        daqlink_to_daq_o    <= DAQLINK_TO_DAQ_NULL;
        pcie_daq_status_o   <= PCIE_DAQ_STATUS_NULL;
        
        -- terminate C2H signals
        axis_c2h_tdata                     <= (others => '0');
        axis_c2h_tcrc                      <= (others => '0');
        axis_c2h_ctrl_marker               <= '0';
        axis_c2h_ctrl_port_id              <= (others => '0');
        axis_c2h_ctrl_ecc                  <= (others => '0');
        axis_c2h_ctrl_len                  <= (others => '0');
        axis_c2h_ctrl_qid                  <= (others => '0');
        axis_c2h_ctrl_has_cmpt             <= '0';
        axis_c2h_mty                       <= (others => '0');
        axis_c2h_tvalid                    <= '0';
        axis_c2h_tlast                     <= '0';
        axis_c2h_cmpt_tdata                <= (others => '0');
        axis_c2h_cmpt_size                 <= (others => '0');
        axis_c2h_cmpt_dpar                 <= (others => '0');
        axis_c2h_cmpt_tvalid               <= '0';
        axis_c2h_cmpt_ctrl_qid             <= (others => '0');
        axis_c2h_cmpt_ctrl_cmpt_type       <= (others => '0');
        axis_c2h_cmpt_ctrl_wait_pld_pkt_id <= (others => '0');
        axis_c2h_cmpt_ctrl_port_id         <= (others => '0');
        axis_c2h_cmpt_ctrl_marker          <= '0';
        axis_c2h_cmpt_ctrl_user_trig       <= '0';
        axis_c2h_cmpt_ctrl_col_idx         <= (others => '0');
        axis_c2h_cmpt_ctrl_err_idx         <= (others => '0');
        axis_c2h_cmpt_ctrl_no_wrb_marker   <= '0';
        
    end generate;
        
    --================================--
    -- H2C test
    --================================--
    
    g_h2c_test : if true generate
        component ila_qdma_h2c
            port(
                clk     : in std_logic;
                probe0  : in std_logic_vector(63 downto 0);
                probe1  : in std_logic_vector(31 downto 0);
                probe2  : in std_logic_vector(10 downto 0);
                probe3  : in std_logic_vector(2 downto 0);
                probe4  : in std_logic;
                probe5  : in std_logic_vector(31 downto 0);
                probe6  : in std_logic_vector(5 downto 0);
                probe7  : in std_logic;
                probe8  : in std_logic;
                probe9  : in std_logic;
                probe10 : in std_logic
            );
        end component;
        
        signal spy_fifo_dout    : std_logic_vector(16 downto 0);
        signal spy_fifo_rd_en   : std_logic;
        signal spy_fifo_empty   : std_logic;
        signal spy_fifo_aempty  : std_logic;
        signal spy_fifo_full    : std_logic;
        
        signal spy_link         : t_mgt_16b_tx_data;
        
    begin
        
            i_spy_fifo : xpm_fifo_async
                generic map(
                    FIFO_MEMORY_TYPE    => "block",
                    FIFO_WRITE_DEPTH    => 4096,
                    RELATED_CLOCKS      => 0,
                    WRITE_DATA_WIDTH    => 68,
                    READ_MODE           => "fwft",
                    FIFO_READ_LATENCY   => 0,
                    FULL_RESET_VALUE    => 1,
                    USE_ADV_FEATURES    => "0A03", -- VALID(12) = 0 ; AEMPTY(11) = 1; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 1; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 1; OVERFLOW(0) = 1
                    READ_DATA_WIDTH     => 17,
                    CDC_SYNC_STAGES     => 2,
                    PROG_FULL_THRESH    => 3072,
                    PROG_EMPTY_THRESH   => 2048,
                    DOUT_RESET_VALUE    => "0",
                    ECC_MODE            => "no_ecc"
                )
                port map(
                    sleep         => '0',
                    rst           => not axi_reset_b,
                    wr_clk        => axi_clk,
                    wr_en         => axis_h2c_tready and axis_h2c_tvalid,
                    din           => axis_h2c_tlast & axis_h2c_tdata(63 downto 48) & "0" & axis_h2c_tdata(47 downto 32) & "0" & axis_h2c_tdata(31 downto 16) & "0" & axis_h2c_tdata(15 downto 0),
                    full          => spy_fifo_full,
                    prog_full     => open,
                    wr_data_count => open,
                    overflow      => open,
                    wr_rst_busy   => open,
                    almost_full   => open,
                    wr_ack        => open,
                    rd_clk        => h2c_tst_link_clk_i,
                    rd_en         => spy_fifo_rd_en,
                    dout          => spy_fifo_dout,
                    empty         => spy_fifo_empty,
                    prog_empty    => open,
                    rd_data_count => open,
                    underflow     => open,
                    rd_rst_busy   => open,
                    almost_empty  => spy_fifo_aempty,
                    data_valid    => open,
                    injectsbiterr => '0',
                    injectdbiterr => '0',
                    sbiterr       => open,
                    dbiterr       => open
                );
    
            i_spy_gbe_tx_driver : entity work.gbe_tx_driver
                generic map(
                    g_MAX_EVT_WORDS        => 50000,
                    g_NUM_IDLES_SMALL_EVT  => 2,
                    g_NUM_IDLES_BIG_EVT    => 7,
                    g_SMALL_EVT_MAX_WORDS  => 24,
                    g_USE_TRAILER_FLAG_EOE => true,
                    g_USE_GEM_FORMAT       => true
                )
                port map(
                    reset_i             => not axi_reset_b,
                    gbe_clk_i           => h2c_tst_link_clk_i,
                    gbe_tx_data_o       => spy_link,
                    skip_eth_header_i   => '0',
                    dest_mac_i          => x"d52ad312e8eb",
                    source_mac_i        => x"0123456789ab",
                    ether_type_i        => x"7088",
                    min_payload_words_i => "00" & x"015",
                    max_payload_words_i => "00" & x"fff",
                    data_empty_i        => spy_fifo_empty,
                    data_i              => spy_fifo_dout(15 downto 0),
                    data_trailer_i      => spy_fifo_dout(16),
                    data_rd_en          => spy_fifo_rd_en,
                    last_valid_word_i   => spy_fifo_aempty,
                    err_event_too_big_o => open,
                    err_eoe_not_found_o => open,
                    word_rate_o         => open,
                    evt_cnt_o           => open
                );
    
                h2c_tst_link_data_o.txdata(15 downto 0) <= spy_link.txdata;
                h2c_tst_link_data_o.txcharisk(1 downto 0) <= spy_link.txcharisk;
                h2c_tst_link_data_o.txchardispval(1 downto 0) <= spy_link.txchardispval;
                h2c_tst_link_data_o.txchardispmode(1 downto 0) <= spy_link.txchardispmode;
        
        axis_h2c_tready <= h2c_stream_ready_i;
        h2c_stream_o.tdata <= axis_h2c_tdata;
        h2c_stream_o.tvalid <= axis_h2c_tvalid;
        h2c_stream_o.tlast <= axis_h2c_tlast;
        h2c_stream_o.qid <= axis_h2c_tuser_qid;
        h2c_stream_o.mty <= axis_h2c_tuser_mty;
        h2c_stream_o.zero_byte <= axis_h2c_tuser_zero_byte;
        
        i_ila_h2c : ila_qdma_h2c
            port map(
                clk     => axi_clk,
                probe0  => axis_h2c_tdata,          
                probe1  => axis_h2c_tcrc,           
                probe2  => axis_h2c_tuser_qid,      
                probe3  => axis_h2c_tuser_port_id,  
                probe4  => axis_h2c_tuser_err,      
                probe5  => axis_h2c_tuser_mdata,    
                probe6  => axis_h2c_tuser_mty,      
                probe7  => axis_h2c_tuser_zero_byte,
                probe8  => axis_h2c_tvalid,         
                probe9  => axis_h2c_tlast,          
                probe10 => axis_h2c_tready
            );
        
    end generate;

    --================================--
    -- IPbus / wishbone bridge
    --================================--

    i_axi_ipbus_bridge : entity work.axi_ipbus_bridge
        generic map(
            g_NUM_USR_BLOCKS => g_NUM_USR_BLOCKS,
            g_USR_BLOCK_SEL_BIT_TOP => g_USR_BLOCK_SEL_BIT_TOP,
            g_USR_BLOCK_SEL_BIT_BOT => g_USR_BLOCK_SEL_BIT_BOT,
            g_DEBUG => true,
            g_IPB_CLK_ASYNC => true,
            g_IPB_TIMEOUT => 15000
        )
        port map(
            axi_aclk_i     => axi_clk,
            axi_aresetn_i  => axi_reset_b,
            axil_m2s_i     => axil_m2s,
            axil_s2m_o     => axil_s2m,
            ipb_reset_o    => ipb_reset_o,
            ipb_clk_i      => ipb_clk_i,
            ipb_sys_miso_i => ipb_sys_miso_arr_i,
            ipb_sys_mosi_o => ipb_sys_mosi_arr_o,
            ipb_usr_miso_i => ipb_usr_miso_arr_i,
            ipb_usr_mosi_o => ipb_usr_mosi_arr_o,
            read_active_o  => ipb_read_active,
            write_active_o => ipb_write_active
        );

    --================================--
    -- Status LEDs
    --================================--

    status_leds_o <= not status_leds;

    -- LED[0] shows the status of phy_ready and link_up
    -- if both are high, the LED is solid ON
    -- if phy_ready is low, the LED is blinking fast (5 times per second)
    -- if phy_ready is high, but link_up is low, the LED is blinking slowly (once per second)
    process(axi_clk)
        variable cntdown : integer range 0 to 250_000_000;
    begin
        if rising_edge(axi_clk) then
            if cntdown = 0 then
                if pcie_phy_ready = '0' then
                    cntdown := 50_000_000;
                    status_leds(0) <= not status_leds(0);
                elsif pcie_link_up = '0' then
                    cntdown := 250_000_000;
                    status_leds(0) <= not status_leds(0);
                else
                    cntdown := 0;
                    status_leds(0) <= '1';
                end if;
            else
                cntdown := cntdown - 1;
            end if;
        end if;
    end process;

    -- LED[1] shows detailed info about the PCIe status: link width, link speed, and link training status
    -- this is done by pushing one bit per second to the LED, delimiting the words by blinking the LED rapidly for 1 second, followed by 1 second off period
    -- high bits are represented by a long blink (0.75 seconds long), while low bits are represented by a short blink (0.25 seconds long)
    process(axi_clk)
        variable cntdown : integer range 0 to 31_250_000;
    begin
        if rising_edge(axi_clk) then
            if cntdown = 0 then
                cntdown := 31_250_000;

                if pcie_link_led_seq_idx = 0 then
                    pcie_link_led_seq_idx <= 151;

                    -- pcie width                    
                    pcie_link_led_seq(151 downto 136) <= PCIE_LINK_LED_SEQ_SEPARATOR;
                    for i in 3 downto 0 loop
                        if pcie_width(i) = '1' then
                            pcie_link_led_seq(111 + (i*8) downto 104 + (i*8)) <= PCIE_LINK_LED_SEQ_HIGH;
                        else
                            pcie_link_led_seq(111 + (i*8) downto 104 + (i*8)) <= PCIE_LINK_LED_SEQ_LOW;
                        end if;
                    end loop;
                     
                    -- pcie speed                    
                    pcie_link_led_seq(103 downto 88) <= PCIE_LINK_LED_SEQ_SEPARATOR;
                    for i in 2 downto 0 loop
                        if pcie_speed(i) = '1' then
                            pcie_link_led_seq(71 + (i*8) downto 64 + (i*8)) <= PCIE_LINK_LED_SEQ_HIGH;
                        else
                            pcie_link_led_seq(71 + (i*8) downto 64 + (i*8)) <= PCIE_LINK_LED_SEQ_LOW;
                        end if;
                    end loop;
                     
                    -- pcie link training status                     
                    pcie_link_led_seq(63 downto 48) <= PCIE_LINK_LED_SEQ_SEPARATOR;
                    for i in 5 downto 0 loop
                        if pcie_train_state(i) = '1' then
                            pcie_link_led_seq(7 + (i*8) downto 0 + (i*8)) <= PCIE_LINK_LED_SEQ_HIGH;
                        else
                            pcie_link_led_seq(7 + (i*8) downto 0 + (i*8)) <= PCIE_LINK_LED_SEQ_LOW;
                        end if;
                    end loop;
                     
                else
                    pcie_link_led_seq_idx <= pcie_link_led_seq_idx - 1;
                end if;
            else
                cntdown := cntdown - 1;
            end if;
            
            status_leds(1) <= pcie_link_led_seq(pcie_link_led_seq_idx);
            
        end if;
    end process;
    
    -- LED[2] shows activity on the AXI MM bus (just blinks when either a read or a write request is received)
    process(axi_clk)
        variable cntdown : integer range 0 to 62_500_000;
    begin
        if rising_edge(axi_clk) then
            if cntdown = 0 then
                status_leds(2) <= '0';
                if ipb_read_active = '1' or ipb_write_active = '1' then
                    cntdown := 62_500_000;
                end if;
            else
                cntdown := cntdown - 1;
                status_leds(2) <= '1';
            end if;
        end if;
    end process;
    
    -- optional LED input from outside
    status_leds(3) <= led_i;

    -- DEBUG
    i_vio_pcie : vio_pcie
        port map(
            clk       => axi_clk,
            probe_in0 => pcie_link_up,
            probe_in1 => pcie_width,
            probe_in2 => pcie_speed,
            probe_in3 => pcie_train_state,
            probe_in4 => pcie_err_cor,
            probe_in5 => pcie_err_fatal,
            probe_in6 => pcie_err_nonfatal,
            probe_in7 => pcie_local_err,
            probe_in8 => pcie_local_err_valid
        );

--    signal daq_cdc_valid        : std_logic;
--    signal daq_cdc_rd_en        : std_logic;


    i_ila_daq : ila_pcie_daq
        port map(
            clk     => axi_clk,
            probe0  => daq_cdc_ovf_axi_clk,
            probe1  => daqlink_valid_axi_clk,     
            probe2  => daq_cdc_data,          
            probe3  => daq_cdc_empty,         
            probe4  => daq_cdc_valid,         
            probe5  => daqlink_reset_axi_clk,     
            probe6  => daq_cdc_rd_en,          
            probe7  => std_logic_vector(c2h_packet_size_words), 
            probe8  => std_logic_vector(c2h_words_cntdown),     
            probe9  => axis_c2h.tlast,        
            probe10 => axis_c2h.tdata,        
            probe11 => axis_c2h.tvalid,       
            probe12 => axis_c2h.tkeep,
            probe13 => axis_c2h_ready     
        );

end pcie_arch;
