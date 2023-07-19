------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2021-07-12
-- Module Name:    ETH_SWITCH
-- Description:    This is a simple bare ethernet switch meant to be used for CSC VCC-computer communication, although should be generic enough to be used for other purposes
--                 The current implementation is not resource efficient, but quite simple and also fast: each RX port has a FIFO for each TX port where there is a valid route,
--                 and each RX has an associated processor which buffers a few words of data and when it detects the start of the packet and determines the destination MAC address,
--                 it starts writing the data to the TX FIFO(s) which have a matching MAC address (or all the TX FIFOs in case of broadcast).
--                 Each TX has an arbiter which monitors the FIFOs coming from all the associated RXs, and as soon as it detects a non-empty one, it drains it to the TX link,
--                 and continues monitoring.
--                 Using this scheme, the latency is minimal, the throughput is very high, and the chance of FIFO overflow is low, but it uses a lot of memory resources, and
--                 also CRC checks are not performed. Although in the future the CRC check could be easily implemented by adding another "packet metadata fifo"
--                 where the RX processor could insert one word for each packet indicating the CRC check result, and the TX arbiter could only start streaming the data when the
--                 metadata fifo has a word indicating that the CRC is good, or discard the main FIFO data if the metadata fifo says the CRC is bad.
--                 Note: in CSC we don't want routing between all ports, we just want to route from any computer to any VCC and vice versa, but not between VCCs or between computers
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.common_pkg.all;
use work.project_config.all;
use work.ipbus.all;
use work.registers.all;

entity eth_switch is
    generic(
        g_NUM_PORTS             : integer;
        g_PORT_LINKS            : t_int_array;
        g_ETH_PORT_ROUTES       : t_int_array_2d;
        g_IPB_CLK_PERIOD_NS     : integer
    );
    port (
        reset_i                 : in  std_logic;

        gbe_clk_i               : in std_logic;

        mgt_rx_data_i           : in  t_mgt_64b_rx_data_arr(g_NUM_PORTS - 1 downto 0);
        mgt_tx_data_o           : out t_mgt_64b_tx_data_arr(g_NUM_PORTS - 1 downto 0);
        mgt_status_i            : in  t_mgt_status_arr(g_NUM_PORTS - 1 downto 0);

        -- IPbus
        ipb_reset_i             : in  std_logic;
        ipb_clk_i               : in  std_logic;
        ipb_miso_o              : out ipb_rbus;
        ipb_mosi_i              : in  ipb_wbus
    );
end eth_switch;

architecture eth_switch_arch of eth_switch is

--    type t_eth_port_config is record
--        port_type       : t_eth_port_type;
--        routes          : t_int_array(0 to g_NUM_PORTS -1);
--    end record;
--
--    type t_eth_port_config_arr is array(integer range <>) of t_eth_port_config;

--    constant ETH_PORT_TYPES     : t_eth_port_type_arr(0 to g_NUM_PORTS - 1) := (others => ETH_PORT_GBE);
    
    -- test config with 4 ports
--    constant ETH_PORT_ROUTES    : t_int_array_2d(0 to g_NUM_PORTS - 1)(0 to g_NUM_PORTS - 1) :=
--        (
--            (2, 3, g_NUM_PORTS, g_NUM_PORTS),
--            (2, 3, g_NUM_PORTS, g_NUM_PORTS),
--            (0, 1, g_NUM_PORTS, g_NUM_PORTS),
--            (0, 1, g_NUM_PORTS, g_NUM_PORTS)
--        );
    
    function get_num_valid_routes(routes_1d : t_int_array) return integer is
        variable temp : natural := 0;
    begin
        for i in routes_1d'range loop
            if routes_1d(i) < g_NUM_PORTS then
                temp := temp + 1;
            end if;
        end loop;

        return temp;
    end function get_num_valid_routes; 
    
    function get_first_route_with_port(routes_2d : t_int_array_2d; port_num : integer) return integer is
    begin
        for i in routes_2d'left to routes_2d'right loop
            for j in routes_2d'range(1) loop
                if routes_2d(i)(j) = port_num then
                    return i;
                end if;
            end loop;
        end loop;

        return g_NUM_PORTS;
    end function get_first_route_with_port; 
        
    function get_last_route_with_port(routes_2d : t_int_array_2d; port_num : integer) return integer is
    begin
        for i in routes_2d'right downto routes_2d'left loop
            for j in routes_2d'range(1) loop
                if routes_2d(i)(j) = port_num then
                    return i;
                end if;
            end loop;
        end loop;

        return 0;
    end function get_last_route_with_port;         
    
    type t_slv_per_port_array is array(integer range <>) of std_logic_vector(g_NUM_PORTS - 1 downto 0);
    type t_slv18_per_port_array is array(integer range <>) of t_std18_array(g_NUM_PORTS - 1 downto 0);
    
    -------------------------------------------------------
    
    type t_rx_state is (IDLE, REG_MAC, SENDING);
    type t_tx_state is (IDLE, SENDING);
    
    constant ETH_PREAMBLE_SOF           : t_std16_array(0 to 3) := (x"55FB", x"5555", x"5555", x"D555");
    constant ETH_PREAMBLE_SOF_CHARISK   : t_std2_array(0 to 3) := ("01", "00", "00", "00");
    constant ETH_IDLE                   : std_logic_vector(15 downto 0) := x"50BC";
    constant ETH_IDLE_CHARISK           : std_logic_vector(1 downto 0) := "01";
    constant BROADCAST_MAC              : std_logic_vector(47 downto 0) := (others => '1');
    constant RX_DELAY_PIPE_DEPTH        : integer := 10;
    
    ------------- Resets ---------------------
    signal reset_local_gbe      : std_logic := '0';
    signal reset_i_sync_gbe     : std_logic := '0';
    signal reset_gbe            : std_logic := '0';
        
    ------------- Resized MGT signals ---------------------
    signal mgt_tx_data_gbe      : t_mgt_16b_tx_data_arr(g_NUM_PORTS - 1 downto 0) := (others => MGT_16B_TX_DATA_NULL);
        
    -------------- Registers ------------------
    signal port_mac_arr         : t_std48_array(g_NUM_PORTS - 1 downto 0) := (0 => x"000000123456", 1 => x"000000123457", 2 => x"000000123458", 3 => x"000000123459");--(others => (others => '0'));
    signal no_match_route       : std_logic_vector(7 downto 0) := (others => '0');
    signal learned_rx_mac_arr   : t_std48_array(g_NUM_PORTS - 1 downto 0) := (others => (others => '0'));
    signal rx_packet_cnt_arr    : t_std32_array(g_NUM_PORTS - 1 downto 0) := (others => (others => '0'));
    signal tx_packet_cnt_arr    : t_std32_array(g_NUM_PORTS - 1 downto 0) := (others => (others => '0'));
    signal rx_sof_error_arr     : std_logic_vector(g_NUM_PORTS - 1 downto 0) := (others => '0');
    signal rx_error_marker_arr  : std_logic_vector(g_NUM_PORTS - 1 downto 0) := (others => '0');
    signal tx_eof_err_arr       : std_logic_vector(g_NUM_PORTS - 1 downto 0) := (others => '0');
    signal fifo_ovf_arr         : std_logic_vector(g_NUM_PORTS - 1 downto 0) := (others => '0');
    signal fifo_unf_arr         : std_logic_vector(g_NUM_PORTS - 1 downto 0) := (others => '0');
    signal rx_not_in_tbl_cnt_arr: t_std16_array(g_NUM_PORTS - 1 downto 0) := (others => (others => '0'));
    signal rx_disperr_cnt_arr   : t_std16_array(g_NUM_PORTS - 1 downto 0) := (others => (others => '0'));
        
    -------------- FIFO signals ---------------
    -- NOTE: the fifo signal arrays are indexed [rx][tx] for the write signals and [tx][rx] for the read signals in order to avoid X in simulation
    signal fifo_wr_en_arr2d     : t_slv_per_port_array(g_NUM_PORTS - 1 downto 0) := (others => (others => '0'));
    signal fifo_full_arr2d      : t_slv_per_port_array(g_NUM_PORTS - 1 downto 0) := (others => (others => '0'));
    signal fifo_ovf_arr2d       : t_slv_per_port_array(g_NUM_PORTS - 1 downto 0) := (others => (others => '0'));
    signal fifo_unf_arr2d       : t_slv_per_port_array(g_NUM_PORTS - 1 downto 0) := (others => (others => '0'));
    signal fifo_rd_en_arr2d     : t_slv_per_port_array(g_NUM_PORTS - 1 downto 0) := (others => (others => '0'));
    signal fifo_empty_arr2d     : t_slv_per_port_array(g_NUM_PORTS - 1 downto 0) := (others => (others => '1'));
    signal fifo_valid_arr2d     : t_slv_per_port_array(g_NUM_PORTS - 1 downto 0) := (others => (others => '0'));
    signal fifo_dout_arr2d      : t_slv18_per_port_array(g_NUM_PORTS - 1 downto 0) := (others => (others => (others => '0')));
        
    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------

begin

    --================================--
    -- Resets, CDC, wiring
    --================================--    

    i_synch_reset_i : entity work.synch
        generic map(
            N_STAGES => 4,
            IS_RESET => true
        )
        port map(
            async_i => reset_i,
            clk_i   => gbe_clk_i,
            sync_o  => reset_i_sync_gbe
        );

    reset_gbe <= reset_i_sync_gbe or reset_local_gbe;

    mgt_tx_data_o <= mgt_tx_16b_to_64b_arr(mgt_tx_data_gbe);

    --================================--
    -- RX Ports Logic
    --================================--    


    g_rx_port : for rx in 0 to g_NUM_PORTS - 1 generate
        constant NUM_VALID_ROUTES   : integer := get_num_valid_routes(g_ETH_PORT_ROUTES(rx));
    
        signal rx_data              : std_logic_vector(15 downto 0);
        signal rx_charisk           : std_logic_vector(1 downto 0);
        signal word_cnt             : integer range 0 to 3 := 0;
        signal rx_data_dly          : std_logic_vector(17 downto 0) := (others => '0');
        signal rx_state             : t_rx_state := IDLE;
        signal dest_mac             : std_logic_vector(47 downto 0);
        signal eof                  : std_logic := '0';
    begin
    
        -- wiring
        rx_data <= mgt_rx_data_i(rx).rxdata(15 downto 0);
        rx_charisk <= mgt_rx_data_i(rx).rxcharisk(1 downto 0);
        
        -- overflow or_reduce and latch
        i_fifo_ovf_latch : entity work.latch
            port map(
                reset_i => reset_gbe,
                clk_i   => gbe_clk_i,
                input_i => or_reduce(fifo_ovf_arr2d(rx)),
                latch_o => fifo_ovf_arr(rx)
            );
    
        -- incoming data delay line to give time to check the incoming dest MAC address
        i_data_delay : entity work.pipe
            generic map(
                WIDTH => 18,
                DEPTH => RX_DELAY_PIPE_DEPTH
            )
            port map(
                clk_i  => gbe_clk_i,
                data_i => rx_charisk & rx_data,  
                data_o => rx_data_dly
            );
        
        -- not in table counter
        i_not_in_tbl_counter : entity work.counter
            generic map(
                g_COUNTER_WIDTH    => 16,
                g_ALLOW_ROLLOVER   => false
            )
            port map(
                ref_clk_i    => gbe_clk_i,
                reset_i      => reset_gbe,
                en_i         => or_reduce(mgt_rx_data_i(rx).rxnotintable(1 downto 0)),
                count_o      => rx_not_in_tbl_cnt_arr(rx)
            );

        -- disperr counter
        i_disperr_counter : entity work.counter
            generic map(
                g_COUNTER_WIDTH    => 16,
                g_ALLOW_ROLLOVER   => false
            )
            port map(
                ref_clk_i    => gbe_clk_i,
                reset_i      => reset_gbe,
                en_i         => or_reduce(mgt_rx_data_i(rx).rxdisperr(1 downto 0)),
                count_o      => rx_disperr_cnt_arr(rx)
            );
    
        -- RX data processor
        process (gbe_clk_i)
            variable mac_match : std_logic_vector(g_NUM_PORTS - 1 downto 0) := (others => '0');
        begin
            if rising_edge(gbe_clk_i) then
                if reset_gbe = '1' then
                    rx_state <= IDLE;
                    word_cnt <= 0;
                    rx_packet_cnt_arr(rx) <= (others => '0');
                    fifo_wr_en_arr2d(rx) <= (others => '0');
                    rx_sof_error_arr(rx) <= '0';
                    rx_error_marker_arr(rx) <= '0';
                    eof <= '0';
                    learned_rx_mac_arr(rx) <= (others => '0');
                    mac_match := (others => '0');
                else
                    
                    eof <= '0';
                    
                    case rx_state is
                        
                        -- look for the preamble and start of frame
                        when IDLE =>
                        
                            if rx_data = ETH_PREAMBLE_SOF(word_cnt) and rx_charisk = ETH_PREAMBLE_SOF_CHARISK(word_cnt) then
                                if word_cnt = 3 then
                                    rx_state <= REG_MAC;
                                    word_cnt <= 0;
                                    rx_packet_cnt_arr(rx) <= std_logic_vector(unsigned(rx_packet_cnt_arr(rx)) + 1);
                                else
                                    word_cnt <= word_cnt + 1;
                                end if;
                            else
                                if word_cnt /= 0 then
                                    rx_sof_error_arr(rx) <= '1';
                                end if;
                                word_cnt <= 0;
                            end if;
                            
                            if rx_data = x"D555" and rx_charisk = "00" and word_cnt /= 3 then
                                rx_sof_error_arr(rx) <= '1';
                            end if;
                            
                            mac_match := (others => '0');
                            
                        -- register the destination mac address
                        when REG_MAC =>
                            word_cnt <= word_cnt + 1;
                            dest_mac(16  * word_cnt + 7 downto 16  * word_cnt) <= rx_data(15 downto 8);
                            dest_mac(16  * word_cnt + 15 downto 16  * word_cnt + 8) <= rx_data(7 downto 0);
                            
                            if word_cnt = 2 then
                                rx_state <= SENDING;
                                word_cnt <= 0;
                            end if;
                            
                            mac_match := (others => '0');
                            
                        when SENDING =>
                            for i in 0 to NUM_VALID_ROUTES - 1 loop
                                if dest_mac = port_mac_arr(g_ETH_PORT_ROUTES(rx)(i)) or dest_mac = BROADCAST_MAC then
                                    fifo_wr_en_arr2d(rx)(g_ETH_PORT_ROUTES(rx)(i)) <= '1';
                                    mac_match(i) := '1';
                                else
                                    fifo_wr_en_arr2d(rx)(g_ETH_PORT_ROUTES(rx)(i)) <= '0';
                                end if;
                            end loop;
                            
                            if or_reduce(mac_match) = '0' and unsigned(no_match_route) < g_NUM_PORTS then
                                -- when no mac is matched, route it to a user defined default port (can be useful for inspection)
                                fifo_wr_en_arr2d(rx)(to_integer(unsigned(no_match_route))) <= '1';
                            end if;
                            
                            if word_cnt /= 3 then
                                word_cnt <= word_cnt + 1;
                                learned_rx_mac_arr(rx)(16  * word_cnt + 7 downto 16  * word_cnt) <= rx_data(15 downto 8);
                                learned_rx_mac_arr(rx)(16  * word_cnt + 15 downto 16  * word_cnt + 8) <= rx_data(7 downto 0);                                
                            end if;
                            
                            if rx_data(7 downto 0) = x"FD" and rx_charisk(0) = '1' then
                                eof <= '1';
                            elsif rx_data(7 downto 0) = x"FE" and rx_charisk(0) = '1' then
                                rx_error_marker_arr(rx) <= '1';
                                eof <= '1';
                            end if;
                            
                            if eof = '1' then
                                rx_state <= IDLE;
                                word_cnt <= 0;
                                fifo_wr_en_arr2d(rx) <= (others => '0');
                            end if;
                            
                    end case;
                end if;
            end if;
        end process;
    
        -- TX FIFOs for each route
        g_port_route : for route in 0 to NUM_VALID_ROUTES - 1 generate
            constant ROUTE_TX           : integer := g_ETH_PORT_ROUTES(rx)(route);
            signal fifo_wr_en_extended  : std_logic := '0';
        begin
                        
            assert ROUTE_TX < g_NUM_PORTS report "RX port #" & integer'image(rx) & " route #" & integer'image(ROUTE_TX) & " is invalid. Invalid ports must always be at the end of the array (valid routes must have no gaps in the array)." severity failure;
            
            i_wr_en_extend : entity work.pulse_extend
                generic map(
                    DELAY_CNT_LENGTH => 4
                )
                port map(
                    clk_i          => gbe_clk_i,
                    rst_i          => reset_gbe,
                    pulse_length_i => std_logic_vector(to_unsigned(RX_DELAY_PIPE_DEPTH - 1, 4)),
                    pulse_i        => fifo_wr_en_arr2d(rx)(ROUTE_TX),
                    pulse_o        => fifo_wr_en_extended
                );
            
            i_tx_fifo : xpm_fifo_sync
                generic map(
                    FIFO_MEMORY_TYPE    => "bram",
                    FIFO_WRITE_DEPTH    => 8192, --5120,
                    WRITE_DATA_WIDTH    => 18,
                    READ_MODE           => "std",
                    FIFO_READ_LATENCY   => 1,
                    FULL_RESET_VALUE    => 0,
                    USE_ADV_FEATURES    => "1101", -- VALID(12) = 1 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 0; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 0; OVERFLOW(0) = 1
                    READ_DATA_WIDTH     => 18,
                    WR_DATA_COUNT_WIDTH => 1,
                    RD_DATA_COUNT_WIDTH => 1,
                    DOUT_RESET_VALUE    => "0",
                    ECC_MODE            => "no_ecc", -- TODO: try enabling ECC
                    SIM_ASSERT_CHK      => 1
                )
                port map(
                    sleep         => '0',
                    rst           => reset_gbe,
                    wr_clk        => gbe_clk_i,
                    wr_en         => fifo_wr_en_extended,
                    din           => rx_data_dly,
                    full          => fifo_full_arr2d(rx)(ROUTE_TX),
                    overflow      => fifo_ovf_arr2d(rx)(ROUTE_TX),
                    wr_rst_busy   => open,
                    rd_en         => fifo_rd_en_arr2d(ROUTE_TX)(rx), -- NOTE: FIFO read signals are indexed as [TX][RX] while write signals are indexed as [RX][TX]
                    dout          => fifo_dout_arr2d(ROUTE_TX)(rx),  -- NOTE: FIFO read signals are indexed as [TX][RX] while write signals are indexed as [RX][TX]
                    empty         => fifo_empty_arr2d(ROUTE_TX)(rx), -- NOTE: FIFO read signals are indexed as [TX][RX] while write signals are indexed as [RX][TX]
                    underflow     => fifo_unf_arr2d(ROUTE_TX)(rx),   -- NOTE: FIFO read signals are indexed as [TX][RX] while write signals are indexed as [RX][TX]
                    rd_rst_busy   => open,
                    data_valid    => fifo_valid_arr2d(ROUTE_TX)(rx), -- NOTE: FIFO read signals are indexed as [TX][RX] while write signals are indexed as [RX][TX]
                    injectsbiterr => '0',
                    injectdbiterr => '0',
                    sbiterr       => open,
                    dbiterr       => open
                );        
        end generate;
    
    end generate;

    -- TX logic
    g_tx_port : for tx in 0 to g_NUM_PORTS - 1 generate
        constant FIRST_RX_PORT_IDX : integer := get_first_route_with_port(g_ETH_PORT_ROUTES, tx);
        constant LAST_RX_PORT_IDX : integer := get_last_route_with_port(g_ETH_PORT_ROUTES, tx);
        
        signal tx_state         : t_tx_state := IDLE;
        signal fifo_sel         : integer range 0 to g_NUM_PORTS - 1 := FIRST_RX_PORT_IDX;
        signal start_send       : std_logic := '0';
        signal eof              : std_logic := '0';
        signal eof_dly          : std_logic := '0';
    begin
        
        -- underflow or_reduce and latch
        i_fifo_ovf_latch : entity work.latch
            port map(
                reset_i => reset_gbe,
                clk_i   => gbe_clk_i,
                input_i => or_reduce(fifo_unf_arr2d(tx)),
                latch_o => fifo_unf_arr(tx)
            );        
        
        process (gbe_clk_i)
        begin
            if rising_edge(gbe_clk_i) then
                if reset_gbe = '1' then
                    tx_state <= IDLE;
                    fifo_sel <= FIRST_RX_PORT_IDX;
                    tx_packet_cnt_arr(tx) <= (others => '0');
                    eof <= '0';
                    eof_dly <= '0';
                    tx_eof_err_arr(tx) <= '0';
                    fifo_rd_en_arr2d(tx) <= (others => '0');
                    start_send <= '0';
                    mgt_tx_data_gbe(tx).txdata <= ETH_IDLE;
                    mgt_tx_data_gbe(tx).txcharisk <= ETH_IDLE_CHARISK;
                else
                    
                    eof_dly <= eof;
                    start_send <= '0';
                    
                    case tx_state is
                        when IDLE =>
                            if fifo_empty_arr2d(tx)(fifo_sel) = '0' then
                                fifo_rd_en_arr2d(tx)(fifo_sel) <= '1';
                                start_send <= '1'; -- go to sending state one clock later
                            elsif fifo_sel = LAST_RX_PORT_IDX then
                                fifo_sel <= FIRST_RX_PORT_IDX;
                            else
                                fifo_sel <= fifo_sel + 1;
                            end if;
                            
                            if start_send = '1' then
                                tx_state <= SENDING;
                            end if;
                            
                            mgt_tx_data_gbe(tx).txdata <= ETH_IDLE;
                            mgt_tx_data_gbe(tx).txcharisk <= ETH_IDLE_CHARISK;
                            eof <= '0';
                            
                        when SENDING =>
                            fifo_rd_en_arr2d(tx)(fifo_sel) <= (not eof) and (not fifo_empty_arr2d(tx)(fifo_sel));
                            
                            if fifo_valid_arr2d(tx)(fifo_sel) = '1' and eof_dly = '0' then
                                mgt_tx_data_gbe(tx).txdata <= fifo_dout_arr2d(tx)(fifo_sel)(15 downto 0);
                                mgt_tx_data_gbe(tx).txcharisk <= fifo_dout_arr2d(tx)(fifo_sel)(17 downto 16);
                            else
                                mgt_tx_data_gbe(tx).txdata <= ETH_IDLE;
                                mgt_tx_data_gbe(tx).txcharisk <= ETH_IDLE_CHARISK;
                                tx_packet_cnt_arr(tx) <= std_logic_vector(unsigned(tx_packet_cnt_arr(tx)) + 1);
                                tx_state <= IDLE;
                                fifo_rd_en_arr2d(tx)(fifo_sel) <= '0';
                                if eof_dly = '0' then
                                    tx_eof_err_arr(tx) <= '1';
                                end if;
                            end if;
                            
                            if fifo_dout_arr2d(tx)(fifo_sel)(7 downto 0) = x"FD" and fifo_dout_arr2d(tx)(fifo_sel)(16) = '1' then
                                fifo_rd_en_arr2d(tx)(fifo_sel) <= '0';
                                eof <= '1';
                            end if;  
                                                        
                    end case;
                    
                end if;
            end if;
        end process;
        
    end generate;

    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit)
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================

end eth_switch_arch;
