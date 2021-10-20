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
        g_USR_BLOCK_SEL_BIT_BOT : integer  -- bottom address bit used for user block selection
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
        pcie_daq_control_i      : in  t_pcie_daq_control;
        pcie_daq_status_o       : out t_pcie_daq_status;
        
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
    
    -- QDMA: 4x pcie gen2
    component pcie_qdma
        port(
            sys_clk                : in  std_logic;
            sys_clk_gt             : in  std_logic;
            sys_rst_n              : in  std_logic;
            user_lnk_up            : out std_logic;
            pci_exp_txp            : out std_logic_vector(3 downto 0);
            pci_exp_txn            : out std_logic_vector(3 downto 0);
            pci_exp_rxp            : in  std_logic_vector(3 downto 0);
            pci_exp_rxn            : in  std_logic_vector(3 downto 0);
            axi_aclk               : out std_logic;
            axi_aresetn            : out std_logic;
            usr_irq_in_vld         : in  std_logic;
            usr_irq_in_vec         : in  std_logic_vector(10 downto 0);
            usr_irq_in_fnc         : in  std_logic_vector(7 downto 0);
            usr_irq_out_ack        : out std_logic;
            usr_irq_out_fail       : out std_logic;
            tm_dsc_sts_vld         : out std_logic;
            tm_dsc_sts_port_id     : out std_logic_vector(2 downto 0);
            tm_dsc_sts_qen         : out std_logic;
            tm_dsc_sts_byp         : out std_logic;
            tm_dsc_sts_dir         : out std_logic;
            tm_dsc_sts_mm          : out std_logic;
            tm_dsc_sts_error       : out std_logic;
            tm_dsc_sts_qid         : out std_logic_vector(10 downto 0);
            tm_dsc_sts_avl         : out std_logic_vector(15 downto 0);
            tm_dsc_sts_qinv        : out std_logic;
            tm_dsc_sts_irq_arm     : out std_logic;
            tm_dsc_sts_rdy         : in  std_logic;
            tm_dsc_sts_pidx        : out std_logic_vector(15 downto 0);
            dsc_crdt_in_crdt       : in  std_logic_vector(15 downto 0);
            dsc_crdt_in_qid        : in  std_logic_vector(10 downto 0);
            dsc_crdt_in_dir        : in  std_logic;
            dsc_crdt_in_fence      : in  std_logic;
            dsc_crdt_in_vld        : in  std_logic;
            dsc_crdt_in_rdy        : out std_logic;
            m_axi_awready          : in  std_logic;
            m_axi_wready           : in  std_logic;
            m_axi_bid              : in  std_logic_vector(3 downto 0);
            m_axi_bresp            : in  std_logic_vector(1 downto 0);
            m_axi_bvalid           : in  std_logic;
            m_axi_arready          : in  std_logic;
            m_axi_rid              : in  std_logic_vector(3 downto 0);
            m_axi_rdata            : in  std_logic_vector(63 downto 0);
            m_axi_rresp            : in  std_logic_vector(1 downto 0);
            m_axi_rlast            : in  std_logic;
            m_axi_rvalid           : in  std_logic;
            m_axi_awid             : out std_logic_vector(3 downto 0);
            m_axi_awaddr           : out std_logic_vector(63 downto 0);
            m_axi_awuser           : out std_logic_vector(31 downto 0);
            m_axi_awlen            : out std_logic_vector(7 downto 0);
            m_axi_awsize           : out std_logic_vector(2 downto 0);
            m_axi_awburst          : out std_logic_vector(1 downto 0);
            m_axi_awprot           : out std_logic_vector(2 downto 0);
            m_axi_awvalid          : out std_logic;
            m_axi_awlock           : out std_logic;
            m_axi_awcache          : out std_logic_vector(3 downto 0);
            m_axi_wdata            : out std_logic_vector(63 downto 0);
            m_axi_wuser            : out std_logic_vector(7 downto 0);
            m_axi_wstrb            : out std_logic_vector(7 downto 0);
            m_axi_wlast            : out std_logic;
            m_axi_wvalid           : out std_logic;
            m_axi_bready           : out std_logic;
            m_axi_arid             : out std_logic_vector(3 downto 0);
            m_axi_araddr           : out std_logic_vector(63 downto 0);
            m_axi_aruser           : out std_logic_vector(31 downto 0);
            m_axi_arlen            : out std_logic_vector(7 downto 0);
            m_axi_arsize           : out std_logic_vector(2 downto 0);
            m_axi_arburst          : out std_logic_vector(1 downto 0);
            m_axi_arprot           : out std_logic_vector(2 downto 0);
            m_axi_arvalid          : out std_logic;
            m_axi_arlock           : out std_logic;
            m_axi_arcache          : out std_logic_vector(3 downto 0);
            m_axi_rready           : out std_logic;
            m_axil_awaddr          : out std_logic_vector(31 downto 0);
            m_axil_awuser          : out std_logic_vector(54 downto 0);
            m_axil_awprot          : out std_logic_vector(2 downto 0);
            m_axil_awvalid         : out std_logic;
            m_axil_awready         : in  std_logic;
            m_axil_wdata           : out std_logic_vector(31 downto 0);
            m_axil_wstrb           : out std_logic_vector(3 downto 0);
            m_axil_wvalid          : out std_logic;
            m_axil_wready          : in  std_logic;
            m_axil_bvalid          : in  std_logic;
            m_axil_bresp           : in  std_logic_vector(1 downto 0);
            m_axil_bready          : out std_logic;
            m_axil_araddr          : out std_logic_vector(31 downto 0);
            m_axil_aruser          : out std_logic_vector(54 downto 0);
            m_axil_arprot          : out std_logic_vector(2 downto 0);
            m_axil_arvalid         : out std_logic;
            m_axil_arready         : in  std_logic;
            m_axil_rdata           : in  std_logic_vector(31 downto 0);
            m_axil_rresp           : in  std_logic_vector(1 downto 0);
            m_axil_rvalid          : in  std_logic;
            m_axil_rready          : out std_logic;
            cfg_negotiated_width_o : out std_logic_vector(3 downto 0);
            cfg_current_speed_o    : out std_logic_vector(2 downto 0);
            cfg_ltssm_state_o      : out std_logic_vector(5 downto 0);
            soft_reset_n           : in  std_logic;
            phy_ready              : out std_logic;
            qsts_out_op            : out std_logic_vector(7 downto 0);
            qsts_out_data          : out std_logic_vector(63 downto 0);
            qsts_out_port_id       : out std_logic_vector(2 downto 0);
            qsts_out_qid           : out std_logic_vector(12 downto 0);
            qsts_out_vld           : out std_logic;
            qsts_out_rdy           : in  std_logic
        );
    end component;    
    
    -- 64 wide AXI-full test BRAM
    component axi_bram_ctrl_test
        port(
            s_axi_aclk    : in  std_logic;
            s_axi_aresetn : in  std_logic;
            s_axi_awaddr  : in  std_logic_vector(18 downto 0);
            s_axi_awlen   : in  std_logic_vector(7 downto 0);
            s_axi_awsize  : in  std_logic_vector(2 downto 0);
            s_axi_awburst : in  std_logic_vector(1 downto 0);
            s_axi_awlock  : in  std_logic;
            s_axi_awcache : in  std_logic_vector(3 downto 0);
            s_axi_awprot  : in  std_logic_vector(2 downto 0);
            s_axi_awvalid : in  std_logic;
            s_axi_awready : out std_logic;
            s_axi_wdata   : in  std_logic_vector(63 downto 0);
            s_axi_wstrb   : in  std_logic_vector(7 downto 0);
            s_axi_wlast   : in  std_logic;
            s_axi_wvalid  : in  std_logic;
            s_axi_wready  : out std_logic;
            s_axi_bresp   : out std_logic_vector(1 downto 0);
            s_axi_bvalid  : out std_logic;
            s_axi_bready  : in  std_logic;
            s_axi_araddr  : in  std_logic_vector(18 downto 0);
            s_axi_arlen   : in  std_logic_vector(7 downto 0);
            s_axi_arsize  : in  std_logic_vector(2 downto 0);
            s_axi_arburst : in  std_logic_vector(1 downto 0);
            s_axi_arlock  : in  std_logic;
            s_axi_arcache : in  std_logic_vector(3 downto 0);
            s_axi_arprot  : in  std_logic_vector(2 downto 0);
            s_axi_arvalid : in  std_logic;
            s_axi_arready : out std_logic;
            s_axi_rdata   : out std_logic_vector(63 downto 0);
            s_axi_rresp   : out std_logic_vector(1 downto 0);
            s_axi_rlast   : out std_logic;
            s_axi_rvalid  : out std_logic;
            s_axi_rready  : in  std_logic;
            bram_rst_a    : out std_logic;
            bram_clk_a    : out std_logic;
            bram_en_a     : out std_logic;
            bram_we_a     : out std_logic_vector(7 downto 0);
            bram_addr_a   : out std_logic_vector(18 downto 0);
            bram_wrdata_a : out std_logic_vector(63 downto 0);
            bram_rddata_a : in  std_logic_vector(63 downto 0)
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
    
    --================================--
    -- PCIe XDMA module
    --================================--

--    g_xdma : if not g_USE_QDMA generate
--
--        i_pcie_dma : pcie_xdma
--            port map(
--                sys_clk                 => pcie_sysclk_i,
--                sys_clk_gt              => pcie_refclk_i,
--                sys_rst_n               => pcie_reset_b_i,
--                user_lnk_up             => pcie_link_up,
--                pci_exp_txp             => pcie_serial_txp(3 downto 0),
--                pci_exp_txn             => pcie_serial_txn(3 downto 0),
--                pci_exp_rxp             => (others => '1'),
--                pci_exp_rxn             => (others => '0'),
--                                        
--                axi_aclk                => axi_clk,
--                axi_aresetn             => axi_reset_b,
--                usr_irq_req             => '0',
--                usr_irq_ack             => open,
--                msi_enable              => open,
--                msi_vector_width        => open,
--                                        
--                -- axi lite             
--                m_axil_awaddr           => axil_m2s.awaddr,
--                m_axil_awprot           => axil_m2s.awprot,
--                m_axil_awvalid          => axil_m2s.awvalid,
--                m_axil_awready          => axil_s2m.awready,
--                m_axil_wdata            => axil_m2s.wdata, 
--                m_axil_wstrb            => axil_m2s.wstrb, 
--                m_axil_wvalid           => axil_m2s.wvalid,
--                m_axil_wready           => axil_s2m.wready,
--                m_axil_bvalid           => axil_s2m.bvalid,
--                m_axil_bresp            => axil_s2m.bresp, 
--                m_axil_bready           => axil_m2s.bready,
--                m_axil_araddr           => axil_m2s.araddr,
--                m_axil_arprot           => axil_m2s.arprot, 
--                m_axil_arvalid          => axil_m2s.arvalid,
--                m_axil_arready          => axil_s2m.arready,
--                m_axil_rdata            => axil_s2m.rdata,  
--                m_axil_rresp            => axil_s2m.rresp,  
--                m_axil_rvalid           => axil_s2m.rvalid, 
--                m_axil_rready           => axil_m2s.rready, 
--                                        
--                s_axis_c2h_tdata_0      => axis_c2h.tdata,
--                s_axis_c2h_tlast_0      => axis_c2h.tlast,
--                s_axis_c2h_tvalid_0     => axis_c2h.tvalid,
--                s_axis_c2h_tready_0     => axis_c2h_ready,
--                s_axis_c2h_tkeep_0      => axis_c2h.tkeep,
--                m_axis_h2c_tdata_0      => axis_h2c.tdata,
--                m_axis_h2c_tlast_0      => axis_h2c.tlast,
--                m_axis_h2c_tvalid_0     => axis_h2c.tvalid,
--                m_axis_h2c_tready_0     => axis_h2c_ready,
--                m_axis_h2c_tkeep_0      => axis_h2c.tkeep,
--                c2h_sts_0               => c2h_status,
--                h2c_sts_0               => h2c_status,
--    
--                cfg_negotiated_width_o  => pcie_width,
--                cfg_current_speed_o     => pcie_speed,
--                cfg_ltssm_state_o       => pcie_train_state,
--                cfg_err_cor_o           => pcie_err_cor,
--                cfg_err_fatal_o         => pcie_err_fatal,
--                cfg_err_nonfatal_o      => pcie_err_nonfatal,
--                cfg_local_error_o       => pcie_local_err,
--                cfg_local_error_valid_o => pcie_local_err_valid
--            );
--    
--        --================================--
--        -- AXI stream
--        --================================--  
--      
--        axis_h2c_ready <= '1';
--        fed_clk <= daq_to_daqlink_i.event_clk;
--        
--        ---------- Calculate CRC ----------
--    
--        daq_reset <= daqlink_reset_axi_clk or pcie_daq_control_i.reset;        
--            
--        process(fed_clk)
--        begin
--            if rising_edge(fed_clk) then
--                fed_data_d       <= daq_to_daqlink_i.event_data;
--                fed_data_head_d  <= daq_to_daqlink_i.event_header;
--                fed_data_trail_d <= daq_to_daqlink_i.event_trailer;
--                fed_data_we_d    <= daq_to_daqlink_i.event_valid;
--                crc_clear      <= daq_to_daqlink_i.event_trailer or daq_reset;
--                
--                -- substitute the CRC
--                if fed_data_trail_d = '1' then
--                    fed_data(31 downto 16) <= crc;
--                else
--                    fed_data(31 downto 16) <= fed_data_d(31 downto 16);
--                end if;
--                fed_data(127 downto 32) <= fed_data_d(127 downto 32);
--                fed_data(15 downto 0) <= fed_data_d(15 downto 0);
--                fed_data_head    <= fed_data_head_d;
--                fed_data_trail   <= fed_data_trail_d;
--                fed_data_we      <= fed_data_we_d;            
--            end if;
--        end process;
--        
--        crc_en <= daq_to_daqlink_i.event_valid;
--        crc_data_in <= daq_to_daqlink_i.event_data;
--        
--        i_crc : entity work.FED_fragment_CRC16_D128b
--            port map ( 
--                clear_p  => crc_clear,
--                clk      => fed_clk,
--                enable   => crc_en,
--                Data     => crc_data_in,
--                CRC_out  => crc
--            );
--        
--        -- CDC fifo between the DAQ clk and the AXI clk
--        i_daq_cdc_fifo : xpm_fifo_async
--            generic map(
--                FIFO_MEMORY_TYPE    => "block",
--                FIFO_WRITE_DEPTH    => 128,
--                RELATED_CLOCKS      => 0,
--                WRITE_DATA_WIDTH    => 128,
--                READ_MODE           => "std",
--                FIFO_READ_LATENCY   => 1,
--                FULL_RESET_VALUE    => 0,
--                USE_ADV_FEATURES    => "1001", -- VALID(12) = 1 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 0; UNDERFLOW(8) = 0; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 0; OVERFLOW(0) = 1
--                READ_DATA_WIDTH     => 128,
--                CDC_SYNC_STAGES     => 2,
--                DOUT_RESET_VALUE    => "0",
--                ECC_MODE            => "no_ecc"
--            )
--            port map(
--                sleep         => '0',
--                rst           => daq_to_daqlink_i.reset,
--                wr_clk        => fed_clk,
--                wr_en         => fed_data_we,
--                din           => fed_data,
--                full          => open,
--                prog_full     => open,
--                wr_data_count => open,
--                overflow      => daq_cdc_ovf,
--                wr_rst_busy   => open,
--                almost_full   => open,
--                wr_ack        => open,
--                rd_clk        => axi_clk,
--                rd_en         => daq_cdc_rd_en,
--                dout          => daq_cdc_data,
--                empty         => daq_cdc_empty,
--                prog_empty    => open,
--                rd_data_count => open,
--                underflow     => open,
--                rd_rst_busy   => open,
--                almost_empty  => open,
--                data_valid    => daq_cdc_valid,
--                injectsbiterr => '0',
--                injectdbiterr => '0',
--                sbiterr       => open,
--                dbiterr       => open
--            );    
--    
--        i_daq_cdc_ovf_sync    : entity work.synch generic map(N_STAGES => 4, IS_RESET => false) port map(async_i => daq_cdc_ovf, clk_i => axi_clk, sync_o => daq_cdc_ovf_axi_clk);
--        i_daqlink_reset_sync  : entity work.synch generic map(N_STAGES => 4, IS_RESET => true) port map(async_i => daq_to_daqlink_i.reset, clk_i => axi_clk, sync_o => daqlink_reset_axi_clk);
--        i_daqlink_valid_sync  : entity work.synch generic map(N_STAGES => 4, IS_RESET => true) port map(async_i => daq_to_daqlink_i.event_valid, clk_i => axi_clk, sync_o => daqlink_valid_axi_clk);
--        i_daqlink_enable_sync : entity work.synch generic map(N_STAGES => 4, IS_RESET => true) port map(async_i => daq_to_daqlink_i.daq_enabled, clk_i => axi_clk, sync_o => daq_enabled_axi_clk);
--    
--        i_daqlink_ready_sync : entity work.synch generic map(N_STAGES => 4, IS_RESET => false) port map(async_i => pcie_link_up, clk_i => daq_to_daqlink_i.event_clk, sync_o => daqlink_to_daq_o.ready);
--        i_daqlink_bp_sync    : entity work.synch generic map(N_STAGES => 4, IS_RESET => false) port map(async_i => c2h_backpressure, clk_i => daq_to_daqlink_i.event_clk, sync_o => daqlink_to_daq_o.backpressure);
--        daqlink_to_daq_o.disperr_cnt <= (others => '0');
--        daqlink_to_daq_o.notintable_cnt <= (others => '0');
--    
--        c2h_backpressure <= not axis_c2h_ready and not daq_cdc_empty;
--        daq_cdc_rd_en <= not daq_cdc_empty and axis_c2h_ready;
--        axis_c2h.tdata <= daq_cdc_data(127 downto 0);
--        axis_c2h.tlast <= daq_cdc_valid and not or_reduce(std_logic_vector(c2h_words_cntdown));
--        axis_c2h.tvalid <= daq_cdc_valid;
--        axis_c2h.tkeep <= (others => daq_cdc_valid);
--        
--        c2h_packet_size_words <= unsigned(pcie_daq_control_i.packet_size_bytes(23 downto 4)); -- divide by 16 to get 128 bit words
--        
--        process(axi_clk)
--        begin
--            if rising_edge(axi_clk) then
--                if daq_reset = '1' then
--                    c2h_words_cntdown <= c2h_packet_size_words - 1;
--                else
--                    if daq_cdc_valid = '1' then
--                        if c2h_words_cntdown = x"00000" then
--                            c2h_words_cntdown <= c2h_packet_size_words - 1;
--                        else
--                            c2h_words_cntdown <= c2h_words_cntdown - 1;
--                        end if;
--                    end if;
--                end if;
--            end if;
--        end process;
--    
--        i_daq_cdc_ovf_latch : entity work.latch
--            port map(
--                reset_i => daq_reset,
--                clk_i   => axi_clk,
--                input_i => daq_cdc_ovf_axi_clk,
--                latch_o => daq_cdc_ovf_latch
--            );
--    
--        i_words_sent_cnt : entity work.counter
--            generic map(
--                g_COUNTER_WIDTH  => 44,
--                g_ALLOW_ROLLOVER => false
--            )
--            port map(
--                ref_clk_i => axi_clk,
--                reset_i   => daq_reset,
--                en_i      => axis_c2h.tvalid,
--                count_o   => pcie_daq_status_o.words_sent
--            );
--    
--        i_word_rate : entity work.rate_counter
--            generic map(
--                g_CLK_FREQUENCY => std_logic_vector(to_unsigned(125_000_000, 32)),
--                g_COUNTER_WIDTH => 28
--            )
--            port map(
--                clk_i   => axi_clk,
--                reset_i => daq_reset,
--                en_i    => axis_c2h.tvalid,
--                rate_o  => pcie_daq_status_o.word_rate
--            );
--
--    end generate;

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
                m_axi_awready                        => axi_s2m.awready,
                m_axi_wready                         => axi_s2m.wready,
                m_axi_bid                            => axi_s2m.bid,
                m_axi_bresp                          => axi_s2m.bresp,
                m_axi_bvalid                         => axi_s2m.bvalid,
                m_axi_arready                        => axi_s2m.arready,
                m_axi_rid                            => axi_s2m.rid,
                m_axi_rdata                          => axi_s2m.rdata,
                m_axi_rresp                          => axi_s2m.rresp,
                m_axi_rlast                          => axi_s2m.rlast,
                m_axi_rvalid                         => axi_s2m.rvalid,
                m_axi_awid                           => axi_m2s.awid,
                m_axi_awaddr                         => axi_m2s.awaddr,
                m_axi_awuser                         => open,
                m_axi_awlen                          => axi_m2s.awlen,
                m_axi_awsize                         => axi_m2s.awsize,
                m_axi_awburst                        => axi_m2s.awburst,
                m_axi_awprot                         => axi_m2s.awprot,
                m_axi_awvalid                        => axi_m2s.awvalid,
                m_axi_awlock                         => axi_m2s.awlock,
                m_axi_awcache                        => axi_m2s.awcache,
                m_axi_wdata                          => axi_m2s.wdata,
                m_axi_wuser                          => open,
                m_axi_wstrb                          => axi_m2s.wstrb,
                m_axi_wlast                          => axi_m2s.wlast,
                m_axi_wvalid                         => axi_m2s.wvalid,
                m_axi_bready                         => axi_m2s.bready,
                m_axi_arid                           => axi_m2s.arid,
                m_axi_araddr                         => axi_m2s.araddr,
                m_axi_aruser                         => open,
                m_axi_arlen                          => axi_m2s.arlen,
                m_axi_arsize                         => axi_m2s.arsize,
                m_axi_arburst                        => axi_m2s.arburst,
                m_axi_arprot                         => axi_m2s.arprot,
                m_axi_arvalid                        => axi_m2s.arvalid,
                m_axi_arlock                         => axi_m2s.arlock,
                m_axi_arcache                        => axi_m2s.arcache,
                m_axi_rready                         => axi_m2s.rready,
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
    
        i_axi_full_load : axi_bram_ctrl_test
            port map(
                s_axi_aclk    => axi_clk,
                s_axi_aresetn => axi_reset_b,
                s_axi_awaddr  => axi_m2s.awaddr(18 downto 0),
                s_axi_awlen   => axi_m2s.awlen,
                s_axi_awsize  => axi_m2s.awsize,
                s_axi_awburst => axi_m2s.awburst,
                s_axi_awlock  => axi_m2s.awlock,
                s_axi_awcache => axi_m2s.awcache,
                s_axi_awprot  => axi_m2s.awprot,
                s_axi_awvalid => axi_m2s.awvalid,
                s_axi_awready => axi_s2m.awready,
                s_axi_wdata   => axi_m2s.wdata,
                s_axi_wstrb   => axi_m2s.wstrb,
                s_axi_wlast   => axi_m2s.wlast,
                s_axi_wvalid  => axi_m2s.wvalid,
                s_axi_wready  => axi_s2m.wready,
                s_axi_bresp   => axi_s2m.bresp,
                s_axi_bvalid  => axi_s2m.bvalid,
                s_axi_bready  => axi_m2s.bready,
                s_axi_araddr  => axi_m2s.araddr(18 downto 0),
                s_axi_arlen   => axi_m2s.arlen,
                s_axi_arsize  => axi_m2s.arsize,
                s_axi_arburst => axi_m2s.arburst,
                s_axi_arlock  => axi_m2s.arlock,
                s_axi_arcache => axi_m2s.arcache,
                s_axi_arprot  => axi_m2s.arprot,
                s_axi_arvalid => axi_m2s.arvalid,
                s_axi_arready => axi_s2m.arready,
                s_axi_rdata   => axi_s2m.rdata,
                s_axi_rresp   => axi_s2m.rresp,
                s_axi_rlast   => axi_s2m.rlast,
                s_axi_rvalid  => axi_s2m.rvalid,
                s_axi_rready  => axi_m2s.rready,
                bram_rst_a    => open,
                bram_clk_a    => open,
                bram_en_a     => open,
                bram_we_a     => open,
                bram_addr_a   => open,
                bram_wrdata_a => open,
                bram_rddata_a => x"cafecafecafecafe" --x"cafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafe"
            );
        
        daqlink_to_daq_o    <= DAQLINK_TO_DAQ_NULL;
        pcie_daq_status_o   <= PCIE_DAQ_STATUS_NULL;
        
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