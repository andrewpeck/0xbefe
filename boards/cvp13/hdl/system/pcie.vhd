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
        led_i               : in  std_logic;

        -- DAQlink interface        
        daq_to_daqlink_i        : in  t_daq_to_daqlink;
        daqlink_to_daq_o        : out t_daqlink_to_daq;
        
        -- IPbus
        ipb_reset_o         : out std_logic;
        ipb_clk_i           : out std_logic;
        ipb_usr_miso_arr_i  : in  ipb_rbus_array(C_NUM_IPB_SLAVES - 1 downto 0);
        ipb_usr_mosi_arr_o  : out ipb_wbus_array(C_NUM_IPB_SLAVES - 1 downto 0);
        ipb_sys_miso_arr_i  : in  ipb_rbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);
        ipb_sys_mosi_arr_o  : out ipb_wbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0)
    );
end pcie;

architecture pcie_arch of pcie is

    -- 8x pcie gen2 with axi stream
    component pcie_xdma
        port(
            sys_clk             : in  std_logic;
            sys_clk_gt          : in  std_logic;
            sys_rst_n           : in  std_logic;
            user_lnk_up         : out std_logic;
            pci_exp_txp         : out std_logic_vector(7 downto 0);
            pci_exp_txn         : out std_logic_vector(7 downto 0);
            pci_exp_rxp         : in  std_logic_vector(7 downto 0);
            pci_exp_rxn         : in  std_logic_vector(7 downto 0);
            axi_aclk            : out std_logic;
            axi_aresetn         : out std_logic;
            usr_irq_req         : in  std_logic_vector(0 downto 0);
            usr_irq_ack         : out std_logic_vector(0 downto 0);
            msi_enable          : out std_logic;
            msi_vector_width    : out std_logic_vector(2 downto 0);
            m_axil_awaddr       : out std_logic_vector(31 downto 0);
            m_axil_awprot       : out std_logic_vector(2 downto 0);
            m_axil_awvalid      : out std_logic;
            m_axil_awready      : in  std_logic;
            m_axil_wdata        : out std_logic_vector(31 downto 0);
            m_axil_wstrb        : out std_logic_vector(3 downto 0);
            m_axil_wvalid       : out std_logic;
            m_axil_wready       : in  std_logic;
            m_axil_bvalid       : in  std_logic;
            m_axil_bresp        : in  std_logic_vector(1 downto 0);
            m_axil_bready       : out std_logic;
            m_axil_araddr       : out std_logic_vector(31 downto 0);
            m_axil_arprot       : out std_logic_vector(2 downto 0);
            m_axil_arvalid      : out std_logic;
            m_axil_arready      : in  std_logic;
            m_axil_rdata        : in  std_logic_vector(31 downto 0);
            m_axil_rresp        : in  std_logic_vector(1 downto 0);
            m_axil_rvalid       : in  std_logic;
            m_axil_rready       : out std_logic;
            s_axis_c2h_tdata_0  : in  std_logic_vector(127 downto 0);
            s_axis_c2h_tlast_0  : in  std_logic;
            s_axis_c2h_tvalid_0 : in  std_logic;
            s_axis_c2h_tready_0 : out std_logic;
            s_axis_c2h_tkeep_0  : in  std_logic_vector(15 downto 0);
            m_axis_h2c_tdata_0  : out std_logic_vector(127 downto 0);
            m_axis_h2c_tlast_0  : out std_logic;
            m_axis_h2c_tvalid_0 : out std_logic;
            m_axis_h2c_tready_0 : in  std_logic;
            m_axis_h2c_tkeep_0  : out std_logic_vector(15 downto 0);
            c2h_sts_0           : out std_logic_vector(7 downto 0);
            h2c_sts_0           : out std_logic_vector(7 downto 0)
        );
    end component;
    
    -- pcie
    signal reset_sync_axi       : std_logic;
    signal qdma_soft_reset      : std_logic;
    signal qdma_reset_cntdown   : integer range 0 to 150 := 0;

--    signal pcie_serial_txp      : std_logic_vector(15 downto 0);
--    signal pcie_serial_txn      : std_logic_vector(15 downto 0);
    signal pcie_serial_txp      : std_logic_vector(7 downto 0);
    signal pcie_serial_txn      : std_logic_vector(7 downto 0);

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
    
    signal daq_fifo_empty       : std_logic;
    signal daq_fifo_valid       : std_logic;
    signal daq_fifo_rd_en       : std_logic;
    signal daq_fifo_data        : std_logic_vector(128 downto 0);

    -- axi lite    
    signal axil_m2s             : t_axi_lite_m2s;
    signal axil_s2m             : t_axi_lite_s2m;

    signal ipb_mmcm_fbclk       : std_logic;

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
    -- PCIe DMA module
    --================================--

    i_pcie_dma : pcie_xdma
        port map(
            sys_clk             => pcie_sysclk_i,
            sys_clk_gt          => pcie_refclk_i,
            sys_rst_n           => pcie_reset_b_i,
            user_lnk_up         => pcie_link_up,
            pci_exp_txp         => pcie_serial_txp,
            pci_exp_txn         => pcie_serial_txn,
            pci_exp_rxp         => (others => '1'),
            pci_exp_rxn         => (others => '0'),
            
            axi_aclk            => axi_clk,
            axi_aresetn         => axi_reset_b,
            usr_irq_req         => "0",
            usr_irq_ack         => open,
            msi_enable          => open,
            msi_vector_width    => open,
            
            -- axi lite
            m_axil_awaddr       => axil_m2s.awaddr,
            m_axil_awprot       => axil_m2s.awprot,
            m_axil_awvalid      => axil_m2s.awvalid,
            m_axil_awready      => axil_s2m.awready,
            m_axil_wdata        => axil_m2s.wdata, 
            m_axil_wstrb        => axil_m2s.wstrb, 
            m_axil_wvalid       => axil_m2s.wvalid,
            m_axil_wready       => axil_s2m.wready,
            m_axil_bvalid       => axil_s2m.bvalid,
            m_axil_bresp        => axil_s2m.bresp, 
            m_axil_bready       => axil_m2s.bready,
            m_axil_araddr       => axil_m2s.araddr,
            m_axil_arprot       => axil_m2s.arprot, 
            m_axil_arvalid      => axil_m2s.arvalid,
            m_axil_arready      => axil_s2m.arready,
            m_axil_rdata        => axil_s2m.rdata,  
            m_axil_rresp        => axil_s2m.rresp,  
            m_axil_rvalid       => axil_s2m.rvalid, 
            m_axil_rready       => axil_m2s.rready, 
            
            s_axis_c2h_tdata_0  => axis_c2h.tdata,
            s_axis_c2h_tlast_0  => axis_c2h.tlast,
            s_axis_c2h_tvalid_0 => axis_c2h.tvalid,
            s_axis_c2h_tready_0 => axis_c2h_ready,
            s_axis_c2h_tkeep_0  => axis_c2h.tkeep,
            m_axis_h2c_tdata_0  => axis_h2c.tdata,
            m_axis_h2c_tlast_0  => axis_h2c.tlast,
            m_axis_h2c_tvalid_0 => axis_h2c.tvalid,
            m_axis_h2c_tready_0 => axis_h2c_ready,
            m_axis_h2c_tkeep_0  => axis_h2c.tkeep,
            c2h_sts_0           => c2h_status,
            h2c_sts_0           => h2c_status
        );

    --================================--
    -- AXI stream
    --================================--  
  
    axis_h2c_ready <= '1';
    
    -- CDC fifo between the DAQ clk and the AXI clk
    i_last_event_fifo : xpm_fifo_async
        generic map(
            FIFO_MEMORY_TYPE    => "block",
            FIFO_WRITE_DEPTH    => 128,
            RELATED_CLOCKS      => 0,
            WRITE_DATA_WIDTH    => 129,
            READ_MODE           => "std",
            FIFO_READ_LATENCY   => 1,
            FULL_RESET_VALUE    => 0,
            USE_ADV_FEATURES    => "1001", -- VALID(12) = 1 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 0; UNDERFLOW(8) = 0; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 0; OVERFLOW(0) = 1
            READ_DATA_WIDTH     => 129,
            CDC_SYNC_STAGES     => 2,
            DOUT_RESET_VALUE    => "0",
            ECC_MODE            => "no_ecc"
        )
        port map(
            sleep         => '0',
            rst           => daq_to_daqlink_i.reset,
            wr_clk        => daq_to_daqlink_i.event_clk,
            wr_en         => daq_to_daqlink_i.event_valid,
            din           => daq_to_daqlink_i.event_trailer & daq_to_daqlink_i.event_data,
            full          => open,
            prog_full     => open,
            wr_data_count => open,
            overflow      => open,
            wr_rst_busy   => open,
            almost_full   => open,
            wr_ack        => open,
            rd_clk        => axi_clk,
            rd_en         => daq_fifo_rd_en,
            dout          => daq_fifo_data,
            empty         => daq_fifo_empty,
            prog_empty    => open,
            rd_data_count => open,
            underflow     => open,
            rd_rst_busy   => open,
            almost_empty  => open,
            data_valid    => daq_fifo_valid,
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr       => open,
            dbiterr       => open
        );    
    
    daq_fifo_rd_en <= not daq_fifo_empty and axis_c2h_ready;
    axis_c2h.tdata <= daq_fifo_data(127 downto 0);
    axis_c2h.tlast <= daq_fifo_data(128) and axis_c2h.tvalid;
    axis_c2h.tvalid <= daq_fifo_valid;
    axis_c2h.tkeep <= (others => daq_fifo_valid);
    
    i_daqlink_ready_sync : entity work.synch generic map(N_STAGES => 4, IS_RESET => false) port map(async_i => pcie_link_up, clk_i => daq_to_daqlink_i.event_clk, sync_o => daqlink_to_daq_o.ready);
    i_daqlink_bp_sync    : entity work.synch generic map(N_STAGES => 4, IS_RESET => false) port map(async_i => not axis_c2h_ready, clk_i => daq_to_daqlink_i.event_clk, sync_o => daqlink_to_daq_o.backpressure);
    daqlink_to_daq_o.disperr_cnt <= (others => '0');
    daqlink_to_daq_o.notintable_cnt <= (others => '0');

    --================================--
    -- IPbus / wishbone bridge
    --================================--

    i_axi_ipbus_bridge : entity work.axi_ipbus_bridge
        generic map(
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


end pcie_arch;