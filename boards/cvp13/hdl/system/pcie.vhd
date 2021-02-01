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

library unisim;
use unisim.vcomponents.all;

use work.axi_pkg.all;
use work.ipbus.all;
use work.ipb_addr_decode.all;
use work.ipb_sys_addr_decode.all;
use work.common_pkg.all;
use work.gem_pkg.all;

entity pcie is
    port (
        reset_i             : in  std_logic;
        
        -- PCIe reset and clocks
        pcie_reset_b_i      : in  std_logic;
        pcie_refclk_i       : in  std_logic;
        pcie_sysclk_i       : in  std_logic; -- should be connected to the odiv2 of the refclk buffer
        
        -- PCIe status
        pcie_phy_ready_o    : out std_logic;
        pcie_link_up_o      : out std_logic;
        
        status_leds_o       : out std_logic_vector(3 downto 0);
        
        -- IPbus
        ipb_reset_o         : out std_logic;
        ipb_clk_o           : out std_logic;
        ipb_usr_miso_arr_i  : in  ipb_rbus_array(C_NUM_IPB_SLAVES - 1 downto 0);
        ipb_usr_mosi_arr_o  : out ipb_wbus_array(C_NUM_IPB_SLAVES - 1 downto 0);
        ipb_sys_miso_arr_i  : in  ipb_rbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);
        ipb_sys_mosi_arr_o  : out ipb_wbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0)
    );
end pcie;

architecture pcie_arch of pcie is

    -- 512 wide
--    COMPONENT axi_bram_ctrl_test
--        PORT(
--            s_axi_aclk    : IN  STD_LOGIC;
--            s_axi_aresetn : IN  STD_LOGIC;
--            s_axi_awaddr  : IN  STD_LOGIC_VECTOR(18 DOWNTO 0);
--            s_axi_awlen   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
--            s_axi_awsize  : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
--            s_axi_awburst : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
--            s_axi_awlock  : IN  STD_LOGIC;
--            s_axi_awcache : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
--            s_axi_awprot  : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
--            s_axi_awvalid : IN  STD_LOGIC;
--            s_axi_awready : OUT STD_LOGIC;
--            s_axi_wdata   : IN  STD_LOGIC_VECTOR(511 DOWNTO 0);
--            s_axi_wstrb   : IN  STD_LOGIC_VECTOR(63 DOWNTO 0);
--            s_axi_wlast   : IN  STD_LOGIC;
--            s_axi_wvalid  : IN  STD_LOGIC;
--            s_axi_wready  : OUT STD_LOGIC;
--            s_axi_bresp   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
--            s_axi_bvalid  : OUT STD_LOGIC;
--            s_axi_bready  : IN  STD_LOGIC;
--            s_axi_araddr  : IN  STD_LOGIC_VECTOR(18 DOWNTO 0);
--            s_axi_arlen   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
--            s_axi_arsize  : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
--            s_axi_arburst : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
--            s_axi_arlock  : IN  STD_LOGIC;
--            s_axi_arcache : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
--            s_axi_arprot  : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
--            s_axi_arvalid : IN  STD_LOGIC;
--            s_axi_arready : OUT STD_LOGIC;
--            s_axi_rdata   : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
--            s_axi_rresp   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
--            s_axi_rlast   : OUT STD_LOGIC;
--            s_axi_rvalid  : OUT STD_LOGIC;
--            s_axi_rready  : IN  STD_LOGIC;
--            bram_rst_a    : OUT STD_LOGIC;
--            bram_clk_a    : OUT STD_LOGIC;
--            bram_en_a     : OUT STD_LOGIC;
--            bram_we_a     : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
--            bram_addr_a   : OUT STD_LOGIC_VECTOR(18 DOWNTO 0);
--            bram_wrdata_a : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
--            bram_rddata_a : IN  STD_LOGIC_VECTOR(511 DOWNTO 0)
--        );
--    END COMPONENT;

    -- 64 wide
    COMPONENT axi_bram_ctrl_test
        PORT(
            s_axi_aclk    : IN  STD_LOGIC;
            s_axi_aresetn : IN  STD_LOGIC;
            s_axi_awaddr  : IN  STD_LOGIC_VECTOR(18 DOWNTO 0);
            s_axi_awlen   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            s_axi_awsize  : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
            s_axi_awburst : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
            s_axi_awlock  : IN  STD_LOGIC;
            s_axi_awcache : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
            s_axi_awprot  : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
            s_axi_awvalid : IN  STD_LOGIC;
            s_axi_awready : OUT STD_LOGIC;
            s_axi_wdata   : IN  STD_LOGIC_VECTOR(63 DOWNTO 0);
            s_axi_wstrb   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            s_axi_wlast   : IN  STD_LOGIC;
            s_axi_wvalid  : IN  STD_LOGIC;
            s_axi_wready  : OUT STD_LOGIC;
            s_axi_bresp   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            s_axi_bvalid  : OUT STD_LOGIC;
            s_axi_bready  : IN  STD_LOGIC;
            s_axi_araddr  : IN  STD_LOGIC_VECTOR(18 DOWNTO 0);
            s_axi_arlen   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            s_axi_arsize  : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
            s_axi_arburst : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
            s_axi_arlock  : IN  STD_LOGIC;
            s_axi_arcache : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
            s_axi_arprot  : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
            s_axi_arvalid : IN  STD_LOGIC;
            s_axi_arready : OUT STD_LOGIC;
            s_axi_rdata   : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
            s_axi_rresp   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            s_axi_rlast   : OUT STD_LOGIC;
            s_axi_rvalid  : OUT STD_LOGIC;
            s_axi_rready  : IN  STD_LOGIC;
            bram_rst_a    : OUT STD_LOGIC;
            bram_clk_a    : OUT STD_LOGIC;
            bram_en_a     : OUT STD_LOGIC;
            bram_we_a     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            bram_addr_a   : OUT STD_LOGIC_VECTOR(18 DOWNTO 0);
            bram_wrdata_a : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
            bram_rddata_a : IN  STD_LOGIC_VECTOR(63 DOWNTO 0)
        );
    END COMPONENT;

    -- NOTE: disabled the axi stream interface for now, but we'll actually need it for DAQ
    -- 16x
--    COMPONENT pcie_qdma
--        PORT(
--            sys_clk                : IN  STD_LOGIC;
--            sys_clk_gt             : IN  STD_LOGIC;
--            sys_rst_n              : IN  STD_LOGIC;
--            user_lnk_up            : OUT STD_LOGIC;
--            pci_exp_txp            : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
--            pci_exp_txn            : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
--            pci_exp_rxp            : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
--            pci_exp_rxn            : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
--            axi_aclk               : OUT STD_LOGIC;
--            axi_aresetn            : OUT STD_LOGIC;
--            usr_irq_in_vld         : IN  STD_LOGIC;
--            usr_irq_in_vec         : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
--            usr_irq_in_fnc         : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
--            usr_irq_out_ack        : OUT STD_LOGIC;
--            usr_irq_out_fail       : OUT STD_LOGIC;
--            st_rx_msg_rdy          : IN  STD_LOGIC;
--            st_rx_msg_valid        : OUT STD_LOGIC;
--            st_rx_msg_last         : OUT STD_LOGIC;
--            st_rx_msg_data         : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
--            tm_dsc_sts_vld         : OUT STD_LOGIC;
--            tm_dsc_sts_port_id     : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
--            tm_dsc_sts_qen         : OUT STD_LOGIC;
--            tm_dsc_sts_byp         : OUT STD_LOGIC;
--            tm_dsc_sts_dir         : OUT STD_LOGIC;
--            tm_dsc_sts_mm          : OUT STD_LOGIC;
--            tm_dsc_sts_error       : OUT STD_LOGIC;
--            tm_dsc_sts_qid         : OUT STD_LOGIC_VECTOR(10 DOWNTO 0);
--            tm_dsc_sts_avl         : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
--            tm_dsc_sts_qinv        : OUT STD_LOGIC;
--            tm_dsc_sts_irq_arm     : OUT STD_LOGIC;
--            tm_dsc_sts_rdy         : IN  STD_LOGIC;
--            dsc_crdt_in_crdt       : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
--            dsc_crdt_in_qid        : IN  STD_LOGIC_VECTOR(10 DOWNTO 0);
--            dsc_crdt_in_dir        : IN  STD_LOGIC;
--            dsc_crdt_in_fence      : IN  STD_LOGIC;
--            dsc_crdt_in_vld        : IN  STD_LOGIC;
--            dsc_crdt_in_rdy        : OUT STD_LOGIC;
--            m_axi_awready          : IN  STD_LOGIC;
--            m_axi_wready           : IN  STD_LOGIC;
--            m_axi_bid              : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
--            m_axi_bresp            : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
--            m_axi_bvalid           : IN  STD_LOGIC;
--            m_axi_arready          : IN  STD_LOGIC;
--            m_axi_rid              : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
--            m_axi_rdata            : IN  STD_LOGIC_VECTOR(511 DOWNTO 0);
--            m_axi_rresp            : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
--            m_axi_rlast            : IN  STD_LOGIC;
--            m_axi_rvalid           : IN  STD_LOGIC;
--            m_axi_awid             : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
--            m_axi_awaddr           : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
--            m_axi_awuser           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
--            m_axi_awlen            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
--            m_axi_awsize           : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
--            m_axi_awburst          : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
--            m_axi_awprot           : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
--            m_axi_awvalid          : OUT STD_LOGIC;
--            m_axi_awlock           : OUT STD_LOGIC;
--            m_axi_awcache          : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
--            m_axi_wdata            : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
--            m_axi_wuser            : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
--            m_axi_wstrb            : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
--            m_axi_wlast            : OUT STD_LOGIC;
--            m_axi_wvalid           : OUT STD_LOGIC;
--            m_axi_bready           : OUT STD_LOGIC;
--            m_axi_arid             : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
--            m_axi_araddr           : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
--            m_axi_aruser           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
--            m_axi_arlen            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
--            m_axi_arsize           : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
--            m_axi_arburst          : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
--            m_axi_arprot           : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
--            m_axi_arvalid          : OUT STD_LOGIC;
--            m_axi_arlock           : OUT STD_LOGIC;
--            m_axi_arcache          : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
--            m_axi_rready           : OUT STD_LOGIC;
--            m_axil_awaddr          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
--            m_axil_awuser          : OUT STD_LOGIC_VECTOR(28 DOWNTO 0);
--            m_axil_awprot          : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
--            m_axil_awvalid         : OUT STD_LOGIC;
--            m_axil_awready         : IN  STD_LOGIC;
--            m_axil_wdata           : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
--            m_axil_wstrb           : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
--            m_axil_wvalid          : OUT STD_LOGIC;
--            m_axil_wready          : IN  STD_LOGIC;
--            m_axil_bvalid          : IN  STD_LOGIC;
--            m_axil_bresp           : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
--            m_axil_bready          : OUT STD_LOGIC;
--            m_axil_araddr          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
--            m_axil_aruser          : OUT STD_LOGIC_VECTOR(28 DOWNTO 0);
--            m_axil_arprot          : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
--            m_axil_arvalid         : OUT STD_LOGIC;
--            m_axil_arready         : IN  STD_LOGIC;
--            m_axil_rdata           : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
--            m_axil_rresp           : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
--            m_axil_rvalid          : IN  STD_LOGIC;
--            m_axil_rready          : OUT STD_LOGIC;
--            cfg_negotiated_width_o : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
--            cfg_current_speed_o    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
--            cfg_ltssm_state_o      : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
--            cfg_function_status    : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
--            cfg_max_read_req       : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
--            cfg_max_payload        : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
--            cfg_flr_in_process     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
--            cfg_vf_flr_in_process  : OUT STD_LOGIC_VECTOR(251 DOWNTO 0);
--            soft_reset_n           : IN  STD_LOGIC;
--            phy_ready              : OUT STD_LOGIC
--        );
--    END COMPONENT;

    -- 4x
    COMPONENT pcie_qdma
        PORT(
            sys_clk                : IN  STD_LOGIC;
            sys_clk_gt             : IN  STD_LOGIC;
            sys_rst_n              : IN  STD_LOGIC;
            user_lnk_up            : OUT STD_LOGIC;
            pci_exp_txp            : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            pci_exp_txn            : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            pci_exp_rxp            : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
            pci_exp_rxn            : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
            axi_aclk               : OUT STD_LOGIC;
            axi_aresetn            : OUT STD_LOGIC;
            usr_irq_in_vld         : IN  STD_LOGIC;
            usr_irq_in_vec         : IN  STD_LOGIC_VECTOR(10 DOWNTO 0);
            usr_irq_in_fnc         : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            usr_irq_out_ack        : OUT STD_LOGIC;
            usr_irq_out_fail       : OUT STD_LOGIC;
            tm_dsc_sts_vld         : OUT STD_LOGIC;
            tm_dsc_sts_port_id     : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            tm_dsc_sts_qen         : OUT STD_LOGIC;
            tm_dsc_sts_byp         : OUT STD_LOGIC;
            tm_dsc_sts_dir         : OUT STD_LOGIC;
            tm_dsc_sts_mm          : OUT STD_LOGIC;
            tm_dsc_sts_error       : OUT STD_LOGIC;
            tm_dsc_sts_qid         : OUT STD_LOGIC_VECTOR(10 DOWNTO 0);
            tm_dsc_sts_avl         : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            tm_dsc_sts_qinv        : OUT STD_LOGIC;
            tm_dsc_sts_irq_arm     : OUT STD_LOGIC;
            tm_dsc_sts_rdy         : IN  STD_LOGIC;
            tm_dsc_sts_pidx        : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            dsc_crdt_in_crdt       : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
            dsc_crdt_in_qid        : IN  STD_LOGIC_VECTOR(10 DOWNTO 0);
            dsc_crdt_in_dir        : IN  STD_LOGIC;
            dsc_crdt_in_fence      : IN  STD_LOGIC;
            dsc_crdt_in_vld        : IN  STD_LOGIC;
            dsc_crdt_in_rdy        : OUT STD_LOGIC;
            m_axi_awready          : IN  STD_LOGIC;
            m_axi_wready           : IN  STD_LOGIC;
            m_axi_bid              : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
            m_axi_bresp            : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
            m_axi_bvalid           : IN  STD_LOGIC;
            m_axi_arready          : IN  STD_LOGIC;
            m_axi_rid              : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
            m_axi_rdata            : IN  STD_LOGIC_VECTOR(63 DOWNTO 0);
            m_axi_rresp            : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
            m_axi_rlast            : IN  STD_LOGIC;
            m_axi_rvalid           : IN  STD_LOGIC;
            m_axi_awid             : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            m_axi_awaddr           : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
            m_axi_awuser           : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axi_awlen            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            m_axi_awsize           : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            m_axi_awburst          : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            m_axi_awprot           : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            m_axi_awvalid          : OUT STD_LOGIC;
            m_axi_awlock           : OUT STD_LOGIC;
            m_axi_awcache          : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            m_axi_wdata            : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
            m_axi_wuser            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            m_axi_wstrb            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            m_axi_wlast            : OUT STD_LOGIC;
            m_axi_wvalid           : OUT STD_LOGIC;
            m_axi_bready           : OUT STD_LOGIC;
            m_axi_arid             : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            m_axi_araddr           : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
            m_axi_aruser           : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axi_arlen            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            m_axi_arsize           : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            m_axi_arburst          : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            m_axi_arprot           : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            m_axi_arvalid          : OUT STD_LOGIC;
            m_axi_arlock           : OUT STD_LOGIC;
            m_axi_arcache          : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            m_axi_rready           : OUT STD_LOGIC;
            m_axil_awaddr          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axil_awuser          : OUT STD_LOGIC_VECTOR(54 DOWNTO 0);
            m_axil_awprot          : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            m_axil_awvalid         : OUT STD_LOGIC;
            m_axil_awready         : IN  STD_LOGIC;
            m_axil_wdata           : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axil_wstrb           : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            m_axil_wvalid          : OUT STD_LOGIC;
            m_axil_wready          : IN  STD_LOGIC;
            m_axil_bvalid          : IN  STD_LOGIC;
            m_axil_bresp           : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
            m_axil_bready          : OUT STD_LOGIC;
            m_axil_araddr          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axil_aruser          : OUT STD_LOGIC_VECTOR(54 DOWNTO 0);
            m_axil_arprot          : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            m_axil_arvalid         : OUT STD_LOGIC;
            m_axil_arready         : IN  STD_LOGIC;
            m_axil_rdata           : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axil_rresp           : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
            m_axil_rvalid          : IN  STD_LOGIC;
            m_axil_rready          : OUT STD_LOGIC;
            cfg_negotiated_width_o : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            cfg_current_speed_o    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            cfg_ltssm_state_o      : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
            soft_reset_n           : IN  STD_LOGIC;
            phy_ready              : OUT STD_LOGIC;
            qsts_out_op            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            qsts_out_data          : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
            qsts_out_port_id       : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            qsts_out_qid           : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
            qsts_out_vld           : OUT STD_LOGIC;
            qsts_out_rdy           : IN STD_LOGIC
        );
    END COMPONENT;

    -- pcie
    signal reset_sync_axi       : std_logic;
    signal qdma_soft_reset      : std_logic;
    signal qdma_reset_cntdown   : integer range 0 to 150 := 0;

--    signal pcie_serial_txp      : std_logic_vector(15 downto 0);
--    signal pcie_serial_txn      : std_logic_vector(15 downto 0);
    signal pcie_serial_txp      : std_logic_vector(3 downto 0);
    signal pcie_serial_txn      : std_logic_vector(3 downto 0);

    -- pcie status
    signal pcie_link_up         : std_logic;
    signal pcie_phy_ready       : std_logic;
    signal pcie_width           : std_logic_vector(3 downto 0);
    signal pcie_speed           : std_logic_vector(2 downto 0);
    signal pcie_train_state     : std_logic_vector(5 downto 0);
    
    signal status_leds          : std_logic_vector(3 downto 0);
    signal pcie_link_led_seq    : std_logic_vector(151 downto 0) := (others => '1');
    signal pcie_link_led_seq_idx: integer range 0 to 151 := 0;
    
    constant PCIE_LINK_LED_SEQ_SEPARATOR    : std_logic_vector(15 downto 0) := x"5500";
    constant PCIE_LINK_LED_SEQ_HIGH         : std_logic_vector(7 downto 0) := x"7e";
    constant PCIE_LINK_LED_SEQ_LOW          : std_logic_vector(7 downto 0) := x"18";
        
    -- axi
    signal axi_clk              : std_logic;
    signal axi_reset_b          : std_logic;

--    signal axi_m2s              : t_axi_full_512_m2s;
--    signal axi_s2m              : t_axi_full_512_s2m := AXI_FULL_512_MISO_NULL;
    signal axi_m2s              : t_axi_full_64_m2s;
    signal axi_s2m              : t_axi_full_64_s2m := AXI_FULL_64_MISO_NULL;
    
    signal axil_m2s             : t_axi_lite_m2s;
    signal axil_s2m             : t_axi_lite_s2m;

    signal ipb_read_active      : std_logic;
    signal ipb_write_active     : std_logic;
    
begin

    --================================--
    -- Wiring
    --================================--
    
    pcie_link_up_o <= pcie_link_up;
    pcie_phy_ready_o <= pcie_phy_ready;

    --================================--
    -- Reset
    --================================--
    
    i_reset_sync_axi : entity work.synch
        generic map(
            N_STAGES => 3
        )
        port map(
            async_i => reset_i,
            clk_i   => axi_clk,
            sync_o  => reset_sync_axi
        );
    
    process(axi_clk)
    begin
        if (rising_edge(axi_clk)) then
            if reset_sync_axi = '1' then
                qdma_reset_cntdown <= 150;
            end if;
            
            if qdma_reset_cntdown = 0 then
                qdma_reset_cntdown <= 0;
                qdma_soft_reset <= '0';
            else
                qdma_reset_cntdown <= qdma_reset_cntdown - 1;
                qdma_soft_reset <= '1';
            end if;
            
        end if;
    end process;
    
    --================================--
    -- PCIe QDMA module
    --================================--

    i_pcie_qdma : pcie_qdma
        port map(
            sys_clk                              => pcie_sysclk_i,
            sys_clk_gt                           => pcie_refclk_i,
            sys_rst_n                            => pcie_reset_b_i,
            user_lnk_up                          => pcie_link_up,
            pci_exp_txp                          => pcie_serial_txp,
            pci_exp_txn                          => pcie_serial_txn,
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

    --================================--
    -- IPbus / wishbone
    --================================--

    i_axi_ipbus_bridge : entity work.axi_ipbus_bridge
        generic map(
            C_DEBUG => true
        )
        port map(
            axi_aclk_i     => axi_clk,
            axi_aresetn_i  => axi_reset_b,
            axil_m2s_i     => axil_m2s,
            axil_s2m_o     => axil_s2m,
            ipb_reset_o    => ipb_reset_o,
            ipb_clk_o      => ipb_clk_o,
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
    
    -- LED[3] shows activity on the AXI stream bus (just blinks when either a read or a write request is received)
    -- not yet implemented
    status_leds(3) <= '0';


end pcie_arch;