------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    20:10:11 2016-04-20
-- Module Name:    AXI_IPBUS_BRIDGE
-- Description:    This module is acting as an AXI4-lite slave and translates the read and write requests to an IPBus protocol effectively 
--                 acting as IPbus master which can drive multiple IPbus slaves. It only adds 2 clocks of latency.
--                 g_IPB_CLK_ASYNC param should be set to true if ipb_clk_i is not the same as axi_aclk_i (this will add a few clocks more latency)
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.axi_pkg.all;
use work.ipbus.all;
use work.ipb_addr_decode.all;
use work.ipb_sys_addr_decode.all;
use work.common_pkg.all;

entity axi_ipbus_bridge is
    generic (
        g_NUM_USR_BLOCKS        : integer := 1; -- number of user blocks (more than one can be used e.g. where we have multiple GEM or CSC modules instantiated, used on devices with multiple SLRs)
        g_USR_BLOCK_SEL_BIT_TOP : integer := 25; -- top address bit used for user block selection
        g_USR_BLOCK_SEL_BIT_BOT : integer := 24; -- bottom address bit used for user block selection
        g_DEBUG                 : boolean := false;
        g_IPB_CLK_ASYNC         : boolean := false;
        g_IPB_TIMEOUT           : integer -- number of axi_aclk_i cycles to wait for IPB response, should be set to approx 60us to cover the VFAT timeout, and maybe even better to above 800us to cover the SCA ADC read timeout
    );
    port (
        -- AXI4-Lite interface
        axi_aclk_i              : in  std_logic;
        axi_aresetn_i           : in  std_logic;
        axil_m2s_i              : in  t_axi_lite_m2s;
        axil_s2m_o              : out t_axi_lite_s2m;
        -- Wishbone / IPbus clock and reset (common to both system and user buses)
        ipb_reset_o             : out std_logic;
        ipb_clk_i               : in  std_logic;        
        -- Wishbone / IPbus SYSTEM interface
        ipb_sys_miso_i          : in  ipb_rbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);
        ipb_sys_mosi_o          : out ipb_wbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);  
        -- Wishbone / IPbus USER interface
        ipb_usr_miso_i          : in  ipb_rbus_array(C_NUM_IPB_SLAVES * g_NUM_USR_BLOCKS - 1 downto 0);
        ipb_usr_mosi_o          : out ipb_wbus_array(C_NUM_IPB_SLAVES * g_NUM_USR_BLOCKS - 1 downto 0);  
        -- Activity signals, can be used e.g. for LEDs to indicate slow control activity on the board
        read_active_o           : out std_logic;
        write_active_o          : out std_logic        
    );
end axi_ipbus_bridge;

architecture arch_imp of axi_ipbus_bridge is

    component vio_ipb_bus_debug_select
        port(
            clk        : in  std_logic;
            probe_out0 : out std_logic_vector(5 downto 0)
        );
    end component;    

    component ila_axi_ipbus_bridge is
        port(
            clk     : in std_logic;
            probe0  : in std_logic;
            probe1  : in std_logic_vector(31 downto 0);
            probe2  : in std_logic_vector(2 downto 0);
            probe3  : in std_logic;
            probe4  : in std_logic_vector(31 downto 0);
            probe5  : in std_logic_vector(3 downto 0);
            probe6  : in std_logic;
            probe7  : in std_logic;
            probe8  : in std_logic_vector(31 downto 0);
            probe9  : in std_logic_vector(2 downto 0);
            probe10 : in std_logic;
            probe11 : in std_logic;
            probe12 : in std_logic_vector(31 downto 0);
            probe13 : in std_logic;
            probe14 : in std_logic;
            probe15 : in std_logic_vector(1 downto 0);
            probe16 : in std_logic;
            probe17 : in std_logic_vector(31 downto 0);
            probe18 : in std_logic;
            probe19 : in std_logic_vector(31 downto 0);
            probe20 : in std_logic_vector(1 downto 0);
            probe21 : in std_logic;
            probe22 : in std_logic_vector(31 downto 0);
            probe23 : in std_logic_vector(31 downto 0);
            probe24 : in std_logic;
            probe25 : in std_logic;
            probe26 : in std_logic_vector(31 downto 0);
            probe27 : in std_logic;
            probe28 : in std_logic;
            probe29 : in std_logic_vector(7 downto 0)
        );
    end component ila_axi_ipbus_bridge;

    component ila_axi_ipbus_bridge_ipbclk
        port(
            clk    : in std_logic;
            probe0 : in std_logic_vector(31 downto 0);
            probe1 : in std_logic_vector(31 downto 0);
            probe2 : in std_logic;
            probe3 : in std_logic;
            probe4 : in std_logic_vector(31 downto 0);
            probe5 : in std_logic;
            probe6 : in std_logic
        );
    end component;

    signal transaction_cnt          : unsigned(15 downto 0) := (others => '0');

    signal axil_m2s                 : t_axi_lite_m2s;
    signal axil_s2m                 : t_axi_lite_s2m := AXI_LITE_S2M_NULL;
    signal axi_word_araddr          : std_logic_vector(31 downto 0); -- word address (as opposed to byte address), in other words, this is shifted right by 2 bits
    signal axi_word_awaddr          : std_logic_vector(31 downto 0); -- word address (as opposed to byte address), in other words, this is shifted right by 2 bits

    type t_axi_ipb_state is (IDLE, WRITE, READ, WAIT_FOR_WRITE_ACK, WAIT_FOR_READ_ACK, AXI_READ_HANDSHAKE, AXI_WRITE_HANDSHAKE);
    
    signal ipb_reset                : std_logic;
    signal ipb_state                : t_axi_ipb_state;
    signal ipb_sys_transact         : std_logic;
    signal ipb_timer                : unsigned(23 downto 0) := (others => '0');
    signal ipb_usr_mosi             : ipb_wbus_array(C_NUM_IPB_SLAVES * g_NUM_USR_BLOCKS - 1 downto 0);
    signal ipb_usr_miso             : ipb_rbus_array(C_NUM_IPB_SLAVES * g_NUM_USR_BLOCKS - 1 downto 0);
    signal ipb_usr_mosi_ipbclk      : ipb_wbus_array(C_NUM_IPB_SLAVES * g_NUM_USR_BLOCKS - 1 downto 0);
    signal ipb_usr_miso_ipbclk      : ipb_rbus_array(C_NUM_IPB_SLAVES * g_NUM_USR_BLOCKS - 1 downto 0);
    signal ipb_usr_slv_select       : integer range 0 to C_NUM_IPB_SLAVES * g_NUM_USR_BLOCKS := 0;
    signal ipb_sys_mosi             : ipb_wbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);
    signal ipb_sys_miso             : ipb_rbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);
    signal ipb_sys_mosi_ipbclk      : ipb_wbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);
    signal ipb_sys_miso_ipbclk      : ipb_rbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);
    signal ipb_sys_slv_select       : integer range 0 to C_NUM_IPB_SYS_SLAVES := 0;

    signal dbg_bus_select           : std_logic_vector(5 downto 0);
    signal dbg_bus_select_ipbclk    : std_logic_vector(5 downto 0);
    signal dbg_ipb_usr_mosi         : ipb_wbus;
    signal dbg_ipb_usr_miso         : ipb_rbus;
    signal dbg_ipb_usr_mosi_ipbclk  : ipb_wbus;
    signal dbg_ipb_usr_miso_ipbclk  : ipb_rbus;

    ---------- last transaction status registers ----------
    constant TRANS_STATUS_INIT          : std_logic_vector(31 downto 0) := x"BEFE0000";
    constant TRANS_STATUS_GOOD          : std_logic_vector(31 downto 0) := x"BEFE600D";
    constant TRANS_STATUS_IPB_ERR       : std_logic_vector(31 downto 0) := x"BEFEBAD0";
    constant TRANS_STATUS_AXI_TIMEOUT   : std_logic_vector(31 downto 0) := x"BEFEBAD1";
    constant TRANS_STATUS_AXI_ADDR_ERR  : std_logic_vector(31 downto 0) := x"BEFEBAD2";
    
    signal trans_status_arr             : t_std32_array(3 downto 0) := (others => TRANS_STATUS_INIT);
    signal usr_block_select             : unsigned(g_USR_BLOCK_SEL_BIT_TOP - g_USR_BLOCK_SEL_BIT_BOT downto 0) := (others => '0');
    signal trans_status_read            : std_logic := '0';

begin
    -- I/O Connections assignments
    
    i_reset_sync : entity work.synch generic map(N_STAGES => 3, IS_RESET => True) port map(async_i => not axi_aresetn_i, clk_i => ipb_clk_i, sync_o => ipb_reset);
    ipb_reset_o <= ipb_reset;
    
    axil_s2m_o <= axil_s2m;
    axil_m2s <= axil_m2s_i;

    axi_word_araddr <= "00" & axil_m2s.araddr(31 downto 2);
    axi_word_awaddr <= "00" & axil_m2s.awaddr(31 downto 2);

    read_active_o <= '1' when ipb_state = READ else '0';
    write_active_o <= '1' when ipb_state = WRITE else '0';

    ipb_usr_mosi_o <= ipb_usr_mosi_ipbclk;
    ipb_usr_miso_ipbclk <= ipb_usr_miso_i;  
    ipb_sys_mosi_o <= ipb_sys_mosi_ipbclk;
    ipb_sys_miso_ipbclk <= ipb_sys_miso_i;  

      -- main FSM
    process(axi_aclk_i)
        variable usr_slv_offset : integer range 0 to g_NUM_USR_BLOCKS * C_NUM_IPB_SLAVES := 0;
    begin
        if (rising_edge(axi_aclk_i)) then
            -- reset  
            if (axi_aresetn_i = '0') then
                ipb_usr_mosi         <= (others => IPB_M2S_NULL);
                ipb_sys_mosi         <= (others => IPB_M2S_NULL);
                ipb_state            <= IDLE;
                ipb_timer            <= (others => '0');
                axil_s2m             <= AXI_LITE_S2M_NULL;
                ipb_usr_slv_select   <= 0;
                ipb_sys_slv_select   <= 0;
                transaction_cnt      <= (others => '0');
                ipb_sys_transact     <= '0';
                usr_block_select     <= (others => '0');
                trans_status_arr     <= (others => TRANS_STATUS_INIT);
                trans_status_read    <= '0'; 
                usr_slv_offset       := 0;
            else
                -- main state machine     
                case ipb_state is
    
                    -- check for read and write requests
                    when IDLE =>
                        ipb_usr_mosi <= (others => IPB_M2S_NULL);
                        ipb_sys_mosi <= (others => IPB_M2S_NULL);
                        ipb_timer    <= (others => '0');
                        axil_s2m     <= AXI_LITE_S2M_NULL;
    
                        -- axi read request
                        if (axil_m2s.arvalid = '1') then
                            axil_s2m.arready   <= '1';
                            if g_NUM_USR_BLOCKS > 1 then
                                usr_slv_offset := (C_NUM_IPB_SLAVES * to_integer(unsigned(axi_word_araddr(g_USR_BLOCK_SEL_BIT_TOP downto g_USR_BLOCK_SEL_BIT_BOT))));
                                usr_block_select <= unsigned(axi_word_araddr(g_USR_BLOCK_SEL_BIT_TOP downto g_USR_BLOCK_SEL_BIT_BOT));
                            else
                                usr_slv_offset := 0;
                                usr_block_select <= (others => '0');
                            end if;
                            ipb_usr_slv_select <= ipb_addr_sel(axi_word_araddr) + usr_slv_offset;
                            ipb_sys_slv_select <= ipb_sys_addr_sel(axi_word_araddr);
                            ipb_state          <= READ;
                            transaction_cnt    <= transaction_cnt + 1;
                            trans_status_read  <= and_reduce(axi_word_araddr(g_USR_BLOCK_SEL_BIT_BOT - 1 downto 0)); -- read the transaction status if all address bits are high
    
                        -- axi write request
                        elsif (axil_m2s.awvalid = '1' and axil_m2s.wvalid = '1') then
                            axil_s2m.awready    <= '1';
                            axil_s2m.wready     <= '1';
                            if g_NUM_USR_BLOCKS > 1 then
                                usr_slv_offset := (C_NUM_IPB_SLAVES * to_integer(unsigned(axi_word_awaddr(g_USR_BLOCK_SEL_BIT_TOP downto g_USR_BLOCK_SEL_BIT_BOT))));
                            else
                                usr_slv_offset := 0;
                            end if;
                            ipb_usr_slv_select  <= ipb_addr_sel(axi_word_awaddr) + usr_slv_offset;
                            ipb_sys_slv_select  <= ipb_sys_addr_sel(axi_word_awaddr);
                            transaction_cnt     <= transaction_cnt + 1;
    
                            ipb_state <= WRITE;
                        end if;
    
                    -- initiate IPBus read request
                    when READ =>
                        
                        -- read last transaction status
                        if (trans_status_read = '1') then
                            axil_s2m  <= (awready => '0', wready => '0', bresp => "00", bvalid => '0', arready => '0', rdata => trans_status_arr(to_integer(usr_block_select)), rresp => "00", rvalid => '1'); -- OKAY response
                            ipb_state <= AXI_READ_HANDSHAKE;
                                                    
                        -- system address
                        elsif (ipb_sys_slv_select /= C_IPB_SYS_SLV.none) then
                            axil_s2m <= AXI_LITE_S2M_NULL;
                            ipb_sys_transact <= '1';
                            ipb_sys_mosi(ipb_sys_slv_select) <= (ipb_addr => axi_word_araddr, ipb_wdata => (others => '0'), ipb_strobe => '1', ipb_write => '0');
                            ipb_state <= WAIT_FOR_READ_ACK;
    
                        -- user address
                        elsif (ipb_usr_slv_select - usr_slv_offset /= C_IPB_SLV.none) then
                            axil_s2m <= AXI_LITE_S2M_NULL;
                            ipb_sys_transact <= '0';
                            ipb_usr_mosi(ipb_usr_slv_select) <= (ipb_addr => axi_word_araddr, ipb_wdata => (others => '0'), ipb_strobe => '1', ipb_write => '0');
                            ipb_state <= WAIT_FOR_READ_ACK;

                        -- addressing error - no IPBus slave at this address
                        else
                            ipb_usr_mosi    <= (others => IPB_M2S_NULL);
                            ipb_sys_mosi    <= (others => IPB_M2S_NULL);
                            ipb_state       <= AXI_READ_HANDSHAKE;
                            ipb_timer       <= (others => '0');
                            axil_s2m        <= (awready => '0', wready => '0', bresp => "00", bvalid => '0', arready => '0', rdata => (others => '0'), rresp => "11", rvalid => '1'); -- DECERR: decode error response
                            trans_status_arr(to_integer(usr_block_select)) <= TRANS_STATUS_AXI_ADDR_ERR;
                        end if;
    
                    -- wait for IPbus read ack
                    when WAIT_FOR_READ_ACK =>

                        -- got ack from system bus
                        if (ipb_sys_transact = '1' and ipb_sys_miso(ipb_sys_slv_select).ipb_ack = '1') then
                            ipb_sys_mosi(ipb_sys_slv_select) <= IPB_M2S_NULL;
                            ipb_state <= AXI_READ_HANDSHAKE;
                            ipb_timer <= (others => '0');
                            if (ipb_sys_miso(ipb_sys_slv_select).ipb_err = '0') then
                                axil_s2m  <= (awready => '0', wready => '0', bresp => "00", bvalid => '0', arready => '0', rdata => ipb_sys_miso(ipb_sys_slv_select).ipb_rdata, rresp => "00", rvalid => '1'); -- OKAY response
                                trans_status_arr(to_integer(usr_block_select)) <= TRANS_STATUS_GOOD;
                            else
                                axil_s2m  <= (awready => '0', wready => '0', bresp => "00", bvalid => '0', arready => '0', rdata => ipb_sys_miso(ipb_sys_slv_select).ipb_rdata, rresp => "10", rvalid => '1'); -- SLVERR: slave error response
                                trans_status_arr(to_integer(usr_block_select)) <= TRANS_STATUS_IPB_ERR;
                            end if;

                        -- got ack from user bus
                        elsif (ipb_sys_transact = '0' and ipb_usr_miso(ipb_usr_slv_select).ipb_ack = '1') then
                            ipb_usr_mosi(ipb_usr_slv_select) <= IPB_M2S_NULL;
                            ipb_state <= AXI_READ_HANDSHAKE;
                            ipb_timer <= (others => '0');
                            if (ipb_usr_miso(ipb_usr_slv_select).ipb_err = '0') then
                                axil_s2m  <= (awready => '0', wready => '0', bresp => "00", bvalid => '0', arready => '0', rdata => ipb_usr_miso(ipb_usr_slv_select).ipb_rdata, rresp => "00", rvalid => '1'); -- OKAY response
                                trans_status_arr(to_integer(usr_block_select)) <= TRANS_STATUS_GOOD;
                            else
                                axil_s2m  <= (awready => '0', wready => '0', bresp => "00", bvalid => '0', arready => '0', rdata => ipb_usr_miso(ipb_usr_slv_select).ipb_rdata, rresp => "10", rvalid => '1'); -- SLVERR: slave error response
                                trans_status_arr(to_integer(usr_block_select)) <= TRANS_STATUS_IPB_ERR;
                            end if;
    
                        -- IPbus timed out
                        elsif (ipb_timer > to_unsigned(g_IPB_TIMEOUT, 24)) then
                            ipb_state <= AXI_READ_HANDSHAKE;
                            ipb_timer <= (others => '0');
                            axil_s2m  <= (awready => '0', wready => '0', bresp => "00", bvalid => '0', arready => '0', rdata => (others => '0'), rresp => "10", rvalid => '1'); -- SLVERR: slave error response
                            ipb_usr_mosi <= (others => IPB_M2S_NULL);
                            ipb_sys_mosi <= (others => IPB_M2S_NULL);
                            trans_status_arr(to_integer(usr_block_select)) <= TRANS_STATUS_AXI_TIMEOUT;
                            
                        -- still waiting for IPbus
                        else
                            ipb_timer <= ipb_timer + 1;
                        end if;
    
                    -- IPBus read transaction finished and axi response is set, so lets finish the axi transaction here
                    when AXI_READ_HANDSHAKE =>
                        if (axil_m2s.rready = '1') then
                            ipb_state  <= IDLE;
                            axil_s2m <= AXI_LITE_S2M_NULL;
                        end if;
    
                    -- initiate IPBus write request
                    when WRITE =>

                        -- system address
                        if (ipb_sys_slv_select /= C_IPB_SYS_SLV.none) then
                            axil_s2m <= AXI_LITE_S2M_NULL;
                            ipb_sys_transact <= '1';
                            ipb_sys_mosi(ipb_sys_slv_select) <= (ipb_addr => axi_word_awaddr, ipb_wdata => axil_m2s.wdata, ipb_strobe => '1', ipb_write => '1');
                            ipb_state <= WAIT_FOR_WRITE_ACK;

                        -- user address
                        elsif (ipb_usr_slv_select /= C_IPB_SLV.none) then
                            axil_s2m <= AXI_LITE_S2M_NULL;
                            ipb_sys_transact <= '0';
                            ipb_usr_mosi(ipb_usr_slv_select) <= (ipb_addr => axi_word_awaddr, ipb_wdata => axil_m2s.wdata, ipb_strobe => '1', ipb_write => '1');
                            ipb_state <= WAIT_FOR_WRITE_ACK;
    
                        -- addressing error - no IPBus slave at this address              
                        else
                            ipb_usr_mosi    <= (others => IPB_M2S_NULL);
                            ipb_sys_mosi    <= (others => IPB_M2S_NULL);
                            ipb_state       <= AXI_WRITE_HANDSHAKE;
                            ipb_timer       <= (others => '0');
                            axil_s2m        <= (awready => '0', wready => '0', bresp => "11", bvalid => '1', arready => '0', rdata => (others => '0'), rresp => "00", rvalid => '0'); -- DECERR: decode error response
                        end if;
    
                    -- wait for IPBus write ack
                    when WAIT_FOR_WRITE_ACK =>

                        -- got ack from system bus
                        if (ipb_sys_transact = '1' and ipb_sys_miso(ipb_sys_slv_select).ipb_ack = '1') then
                            ipb_sys_mosi(ipb_sys_slv_select) <= IPB_M2S_NULL;
                            ipb_state <= AXI_WRITE_HANDSHAKE;
                            ipb_timer <= (others => '0');
                            if (ipb_sys_miso(ipb_sys_slv_select).ipb_err = '0') then
                                axil_s2m  <= (awready => '0', wready => '0', bresp => "00", bvalid => '1', arready => '0', rdata => (others => '0'), rresp => "00", rvalid => '0'); -- OKAY response
                                trans_status_arr(to_integer(usr_block_select)) <= TRANS_STATUS_GOOD;
                            else
                                axil_s2m  <= (awready => '0', wready => '0', bresp => "10", bvalid => '1', arready => '0', rdata => (others => '0'), rresp => "00", rvalid => '0'); -- SLVERR: slave error response
                                trans_status_arr(to_integer(usr_block_select)) <= TRANS_STATUS_IPB_ERR;
                            end if;
    
                        -- got ack from user bus
                        elsif (ipb_sys_transact = '0' and ipb_usr_miso(ipb_usr_slv_select).ipb_ack = '1') then
                            ipb_usr_mosi(ipb_usr_slv_select) <= IPB_M2S_NULL;
                            ipb_state <= AXI_WRITE_HANDSHAKE;
                            ipb_timer <= (others => '0');
                            if (ipb_usr_miso(ipb_usr_slv_select).ipb_err = '0') then
                                axil_s2m  <= (awready => '0', wready => '0', bresp => "00", bvalid => '1', arready => '0', rdata => (others => '0'), rresp => "00", rvalid => '0'); -- OKAY response
                                trans_status_arr(to_integer(usr_block_select)) <= TRANS_STATUS_GOOD;
                            else
                                axil_s2m  <= (awready => '0', wready => '0', bresp => "10", bvalid => '1', arready => '0', rdata => (others => '0'), rresp => "00", rvalid => '0'); -- SLVERR: slave error response
                                trans_status_arr(to_integer(usr_block_select)) <= TRANS_STATUS_IPB_ERR;
                            end if;
    
                        -- IPbus timed out
                        elsif (ipb_timer > to_unsigned(g_IPB_TIMEOUT, 24)) then
                            ipb_state <= AXI_WRITE_HANDSHAKE;
                            ipb_timer <= (others => '0');
                            axil_s2m  <= (awready => '0', wready => '0', bresp => "10", bvalid => '1', arready => '0', rdata => (others => '0'), rresp => "00", rvalid => '0'); -- SLVERR: slave error response
                            ipb_usr_mosi <= (others => IPB_M2S_NULL);
                            ipb_sys_mosi <= (others => IPB_M2S_NULL);
                            trans_status_arr(to_integer(usr_block_select)) <= TRANS_STATUS_AXI_TIMEOUT;
                            
                        -- still waiting for IPbus
                        else
                            ipb_timer <= ipb_timer + 1;
                        end if;
    
                    -- IPBus write transaction finished and axi response is set, so lets finish the axi transaction here
                    when AXI_WRITE_HANDSHAKE =>
                        if (axil_m2s.bready = '1') then
                            ipb_state  <= IDLE;
                            axil_s2m <= AXI_LITE_S2M_NULL;
                        end if;
    
                    -- hmm           
                    when others =>
                        ipb_usr_mosi       <= (others => IPB_M2S_NULL);
                        ipb_sys_mosi       <= (others => IPB_M2S_NULL);
                        ipb_state          <= IDLE;
                        ipb_timer          <= (others => '0');
                        axil_s2m           <= AXI_LITE_S2M_NULL;
                        ipb_usr_slv_select <= 0;
                        ipb_sys_slv_select <= 0;
                        ipb_sys_transact   <= '0'; 
                end case;
            end if;
        end if;
    end process;

    -- ================================= Domain crossing between axiclk and ipbclk ====================================
    
    -- CDC is not used
    gen_ipbclk_sync : if not g_IPB_CLK_ASYNC generate
        ipb_usr_mosi_ipbclk <= ipb_usr_mosi;
        ipb_sys_mosi_ipbclk <= ipb_sys_mosi;
        ipb_usr_miso <= ipb_usr_miso_ipbclk;
        ipb_sys_miso <= ipb_sys_miso_ipbclk;
    end generate;

    -- CDC is used
    gen_ipbclk_async : if g_IPB_CLK_ASYNC generate
        
        -- user bus
        gen_usr_bus : for i in 0 to C_NUM_IPB_SLAVES * g_NUM_USR_BLOCKS - 1 generate

            i_cdc_usr_mosi : xpm_cdc_handshake
                generic map(
                    DEST_EXT_HSK   => 1,
                    DEST_SYNC_FF   => 4,
                    SRC_SYNC_FF    => 4,
                    WIDTH          => 65
                )
                port map(
                    src_clk  => axi_aclk_i,
                    src_in   => ipb_usr_mosi(i).ipb_write & ipb_usr_mosi(i).ipb_addr & ipb_usr_mosi(i).ipb_wdata,
                    src_send => ipb_usr_mosi(i).ipb_strobe,
                    src_rcv  => open,
                    dest_clk => ipb_clk_i,
                    dest_req => ipb_usr_mosi_ipbclk(i).ipb_strobe,
                    dest_ack => ipb_usr_miso_ipbclk(i).ipb_ack,
                    dest_out(64) => ipb_usr_mosi_ipbclk(i).ipb_write,
                    dest_out(63 downto 32) => ipb_usr_mosi_ipbclk(i).ipb_addr,
                    dest_out(31 downto 0) => ipb_usr_mosi_ipbclk(i).ipb_wdata
                );
            
            i_cdc_usr_miso : xpm_cdc_handshake
                generic map(
                    DEST_EXT_HSK   => 0,
                    DEST_SYNC_FF   => 4,
                    SRC_SYNC_FF    => 4,
                    WIDTH          => 33
                )
                port map(
                    src_clk  => ipb_clk_i,
                    src_in   => ipb_usr_miso_ipbclk(i).ipb_err & ipb_usr_miso_ipbclk(i).ipb_rdata,
                    src_send => ipb_usr_miso_ipbclk(i).ipb_ack,
                    src_rcv  => open,
                    dest_clk => axi_aclk_i,
                    dest_req => ipb_usr_miso(i).ipb_ack,
                    dest_ack => '0',
                    dest_out(32) => ipb_usr_miso(i).ipb_err,
                    dest_out(31 downto 0) => ipb_usr_miso(i).ipb_rdata
                );
            
        end generate;

        -- system bus
        gen_sys_bus : for i in 0 to C_NUM_IPB_SYS_SLAVES - 1 generate

            i_cdc_sys_mosi : xpm_cdc_handshake
                generic map(
                    DEST_EXT_HSK   => 1,
                    DEST_SYNC_FF   => 4,
                    SRC_SYNC_FF    => 4,
                    WIDTH          => 65
                )
                port map(
                    src_clk  => axi_aclk_i,
                    src_in   => ipb_sys_mosi(i).ipb_write & ipb_sys_mosi(i).ipb_addr & ipb_sys_mosi(i).ipb_wdata,
                    src_send => ipb_sys_mosi(i).ipb_strobe,
                    src_rcv  => open,
                    dest_clk => ipb_clk_i,
                    dest_req => ipb_sys_mosi_ipbclk(i).ipb_strobe,
                    dest_ack => ipb_sys_miso_ipbclk(i).ipb_ack,
                    dest_out(64) => ipb_sys_mosi_ipbclk(i).ipb_write,
                    dest_out(63 downto 32) => ipb_sys_mosi_ipbclk(i).ipb_addr,
                    dest_out(31 downto 0) => ipb_sys_mosi_ipbclk(i).ipb_wdata
                );
            
            i_cdc_sys_miso : xpm_cdc_handshake
                generic map(
                    DEST_EXT_HSK   => 0,
                    DEST_SYNC_FF   => 4,
                    SRC_SYNC_FF    => 4,
                    WIDTH          => 33
                )
                port map(
                    src_clk  => ipb_clk_i,
                    src_in   => ipb_sys_miso_ipbclk(i).ipb_err & ipb_sys_miso_ipbclk(i).ipb_rdata,
                    src_send => ipb_sys_miso_ipbclk(i).ipb_ack,
                    src_rcv  => open,
                    dest_clk => axi_aclk_i,
                    dest_req => ipb_sys_miso(i).ipb_ack,
                    dest_ack => '0',
                    dest_out(32) => ipb_sys_miso(i).ipb_err,
                    dest_out(31 downto 0) => ipb_sys_miso(i).ipb_rdata
                );
            
        end generate;
        
    end generate;

    -- ================================= DEBUG ====================================
    
    gen_debug : if g_DEBUG generate
    
        i_vio_ipb_bus_debug_select : vio_ipb_bus_debug_select
            port map(
                clk        => axi_aclk_i,
                probe_out0 => dbg_bus_select
            );    
    
        dbg_ipb_usr_mosi <= ipb_usr_mosi(to_integer(unsigned(dbg_bus_select)));
        dbg_ipb_usr_miso <= ipb_usr_miso(to_integer(unsigned(dbg_bus_select)));
    
        ila_axi_ipbus_bridge_inst : ila_axi_ipbus_bridge
            port map(
                clk     => axi_aclk_i,
                probe0  => axi_aresetn_i,
                probe1  => axil_m2s.awaddr,
                probe2  => axil_m2s.awprot,
                probe3  => axil_m2s.awvalid,
                probe4  => axil_m2s.wdata,
                probe5  => axil_m2s.wstrb,
                probe6  => axil_m2s.wvalid,
                probe7  => axil_m2s.bready,
                probe8  => axil_m2s.araddr,
                probe9  => axil_m2s.arprot,
                probe10 => axil_m2s.arvalid,
                probe11 => axil_m2s.rready,
                probe12 => x"0000" & std_logic_vector(transaction_cnt),
                probe13 => axil_s2m.awready,
                probe14 => axil_s2m.wready,
                probe15 => axil_s2m.bresp,
                probe16 => axil_s2m.bvalid,
                probe17 => x"00000000",
                probe18 => axil_s2m.arready,
                probe19 => axil_s2m.rdata,
                probe20 => axil_s2m.rresp,
                probe21 => axil_s2m.rvalid,
                probe22 => dbg_ipb_usr_mosi.ipb_addr,
                probe23 => dbg_ipb_usr_mosi.ipb_wdata,
                probe24 => dbg_ipb_usr_mosi.ipb_strobe,
                probe25 => dbg_ipb_usr_mosi.ipb_write,
                probe26 => dbg_ipb_usr_miso.ipb_rdata,
                probe27 => dbg_ipb_usr_miso.ipb_ack,
                probe28 => dbg_ipb_usr_miso.ipb_err,
                probe29 => std_logic_vector(to_unsigned(ipb_usr_slv_select, 8))
            );
        
        i_dbg_slv_select_cdc : xpm_cdc_array_single
            generic map(
                DEST_SYNC_FF   => 4,
                SRC_INPUT_REG  => 1,
                WIDTH          => 6
            )
            port map(
                src_clk  => axi_aclk_i,
                src_in   => dbg_bus_select,
                dest_clk => ipb_clk_i,
                dest_out => dbg_bus_select_ipbclk
            );
        
        dbg_ipb_usr_mosi_ipbclk <= ipb_usr_mosi_ipbclk(to_integer(unsigned(dbg_bus_select_ipbclk)));
        dbg_ipb_usr_miso_ipbclk <= ipb_usr_miso_ipbclk(to_integer(unsigned(dbg_bus_select_ipbclk)));
            
        i_ila_axi_ipbus_bridge_ipbclk: ila_axi_ipbus_bridge_ipbclk
            port map(
                clk    => ipb_clk_i,
                probe0 => dbg_ipb_usr_mosi_ipbclk.ipb_addr,
                probe1 => dbg_ipb_usr_mosi_ipbclk.ipb_wdata,
                probe2 => dbg_ipb_usr_mosi_ipbclk.ipb_strobe,
                probe3 => dbg_ipb_usr_mosi_ipbclk.ipb_write,
                probe4 => dbg_ipb_usr_miso_ipbclk.ipb_rdata,
                probe5 => dbg_ipb_usr_miso_ipbclk.ipb_ack,
                probe6 => dbg_ipb_usr_miso_ipbclk.ipb_err
            );
            
    end generate;

end arch_imp;
