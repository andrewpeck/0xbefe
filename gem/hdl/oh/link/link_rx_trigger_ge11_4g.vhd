------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    00:01 2016-05-10
-- Module Name:    link_rx_trigger_ge11_4g
-- Description:    This module takes two GTX/GTH trigger RX links and outputs sbit cluster data synchronous to the TTC clk. It works with GE1/1 OHs and early prototypes of GE2/1 OH which use dedicated 8b10b trigger links.
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library xpm;
use xpm.vcomponents.all;

use work.common_pkg.all;
use work.gem_pkg.all;

entity link_rx_trigger_ge11_4g is
    generic(
        g_REG_INPUT     : boolean := true;
        g_REG_OUTPUT    : boolean := true;
        g_DEBUG         : boolean := false -- if this is set to true, some chipscope cores will be inserted
    );
    port(
        reset_i             : in  std_logic;

        ttc_clk_40_i        : in  std_logic;
        
        rx_usrclk_i         : in  std_logic; -- 200MHz
        rx_data_i           : in  t_mgt_16b_rx_data; 
        
        sbit_cluster0_o     : out t_sbit_cluster;
        sbit_cluster1_o     : out t_sbit_cluster;
        sbit_cluster2_o     : out t_sbit_cluster;
        sbit_cluster3_o     : out t_sbit_cluster;
        sbit_overflow_o     : out std_logic;
        bc0_marker_o        : out std_logic;
        
        missed_comma_err_o  : out std_logic;
        not_in_table_err_o  : out std_logic;
        fifo_ovf_o          : out std_logic;
        fifo_unf_o          : out std_logic
    );
end link_rx_trigger_ge11_4g;

architecture Behavioral of link_rx_trigger_ge11_4g is    

    -- trigger links will send a K-char every 4 clocks to mark a BX start, and every BX it will cycle through 4 different K-chars: 0x1C, 0xF7, 0xFB, 0xFD
    -- in case there is an overflow in that particular BX, the K-char for this BX will be 0xFE

    -- in order of priority
    constant BC0_FRAME_MARKER       : std_logic_vector(7 downto 0) := x"bc"; -- K.28.5
    constant RESYNC_FRAME_MARKER    : std_logic_vector(7 downto 0) := x"3c"; -- K.28.1
    constant OVERFLOW_FRAME_MARKER  : std_logic_vector(7 downto 0) := x"fe"; -- K.30.7
    constant FRAME_MARKERS          : t_std8_array(0 to 3) := (x"1c", x"f7", x"fb", x"fd"); -- K.28.0, K.23.7, K.27.7, K.29.7

    type state_t is (COMMA, DATA_0, DATA_1, DATA_2, DATA_3);    
    
    -- frame construction and CDC
    
    constant ERR_DELAY_AFTER_RESET : integer := 100;
    
    signal reset_200            : std_logic := '1';
    signal reset_40             : std_logic := '1';
    signal reset_cntdown        : integer range 0 to ERR_DELAY_AFTER_RESET := ERR_DELAY_AFTER_RESET;
    signal check_errors_200     : std_logic := '0';
    signal check_errors_40      : std_logic := '0';
    
    signal rx_data              : t_mgt_16b_rx_data; 
    
    signal state                : state_t := DATA_0;
    signal frame_200            : std_logic_vector(84 downto 0); -- 80 data bits + 1 bit for error (not in table) + 2 bits for charisk + 2 bits for chariscomma (from the comma state only)
    signal frame_40             : std_logic_vector(84 downto 0); -- 80 data bits + 1 bit for error (not in table) + 2 bits for charisk + 2 bits for chariscomma (from the comma state only)
    
    signal fifo_wr_en           : std_logic;
    signal fifo_empty           : std_logic;
    signal fifo_valid           : std_logic;
    signal fifo_ovf_200         : std_logic;
    signal fifo_ovf             : std_logic;
    signal fifo_unf             : std_logic;

    -- frame decoding
    signal frame_counter        : integer range 0 to FRAME_MARKERS'length - 1;
    signal frame_counter_valid  : std_logic := '0'; -- this is set on reset, and deasserted when the first frame marker comes and a valid initial value is assigned to the frame_counter
    signal missed_comma_err     : std_logic := '0'; -- asserted if a comma character is not found when FSM is in COMMA state
    signal sbit_overflow        : std_logic := '0'; -- asserted when an overflow K-char is detected at the BX boundary (0xFC)
    signal bc0_marker           : std_logic := '0';
    signal not_in_table_err     : std_logic := '0';  

    signal sbit_cluster0        : t_sbit_cluster;
    signal sbit_cluster1        : t_sbit_cluster;
    signal sbit_cluster2        : t_sbit_cluster;
    signal sbit_cluster3        : t_sbit_cluster;

begin  

--    sbit_cluster0_o     <= NULL_SBIT_CLUSTER;
--    sbit_cluster1_o     <= NULL_SBIT_CLUSTER;
--    sbit_cluster2_o     <= NULL_SBIT_CLUSTER;
--    sbit_cluster3_o     <= NULL_SBIT_CLUSTER;
--    sbit_overflow_o     <= '0';
--    missed_comma_err_o  <= '1';
--    not_in_table_err_o  <= '0';
--    fifo_ovf_o <= '0';
--    fifo_unf_o <= '0';

    --== Input and output registers ==--

    g_register_input : if g_REG_INPUT generate
        
        process(rx_usrclk_i)
        begin
            if rising_edge(rx_usrclk_i) then
                rx_data <= rx_data_i;
            end if;
        end process;
        
    end generate;

    g_noreg_input : if not g_REG_INPUT generate
        rx_data <= rx_data_i;
    end generate;

    g_register_output : if g_REG_OUTPUT generate

        process(ttc_clk_40_i)
        begin
            if rising_edge(ttc_clk_40_i) then
                sbit_cluster0_o    <= sbit_cluster0;
                sbit_cluster1_o    <= sbit_cluster1;
                sbit_cluster2_o    <= sbit_cluster2;
                sbit_cluster3_o    <= sbit_cluster3;
                sbit_overflow_o    <= sbit_overflow;
                bc0_marker_o       <= bc0_marker;
                missed_comma_err_o <= missed_comma_err;
                not_in_table_err_o <= not_in_table_err;           
            end if;
        end process;

    end generate;

    g_noreg_output : if not g_REG_OUTPUT generate
        sbit_cluster0_o    <= sbit_cluster0;
        sbit_cluster1_o    <= sbit_cluster1;
        sbit_cluster2_o    <= sbit_cluster2;
        sbit_cluster3_o    <= sbit_cluster3;
        sbit_overflow_o    <= sbit_overflow;
        bc0_marker_o       <= bc0_marker;
        missed_comma_err_o <= missed_comma_err;
        not_in_table_err_o <= not_in_table_err;           
    end generate;

    --== Glue the words from a single BX together ==--
    
    -- lift the internal reset when we see the first K char
    process(rx_usrclk_i)
    begin
        if rising_edge(rx_usrclk_i) then
            if reset_i = '1' then
                reset_200 <= '1';
                reset_cntdown <= ERR_DELAY_AFTER_RESET;
                check_errors_200 <= '0';
            else
                if rx_data.rxcharisk = "01" then
                    reset_200 <= '0';
                else
                    reset_200 <= reset_200;
                end if;
                
                if reset_cntdown = 0 then
                    reset_cntdown <= 0;
                    check_errors_200 <= '1';
                else
                    reset_cntdown <= reset_cntdown - 1;
                    check_errors_200 <= '0';
                end if;
            end if;
        end if;
    end process;

    i_sync_reset_40 : entity work.synch generic map(N_STAGES => 3, IS_RESET => true) port map(async_i => reset_200, clk_i => ttc_clk_40_i, sync_o => reset_40);
    i_sync_count_errors_40 : entity work.synch generic map(N_STAGES => 3) port map(async_i => check_errors_200, clk_i => ttc_clk_40_i, sync_o => check_errors_40);

    -- cycle through the states
    process(rx_usrclk_i)
    begin
        if rising_edge(rx_usrclk_i) then
            if reset_200 = '1' then
                state <= DATA_0;
            else
                case state is
                    when COMMA =>
                        state <= DATA_0;
                    when DATA_0 =>
                        state <= DATA_1;
                    when DATA_1 =>
                        state <= DATA_2;
                    when DATA_2 =>
                        state <= DATA_3;
                    when DATA_3 =>
                        state <= COMMA;
                    when others =>
                        state <= COMMA;
                end case;
            end if;
        end if;
    end process;
    
    -- glue the words
    -- this implementation just spells out each word, could use an index, but this is probably easier to synthesize (to be checked)
    process(rx_usrclk_i)
    begin
        if rising_edge(rx_usrclk_i) then
            if reset_200 = '1' then
                frame_200(15 downto 0) <= rx_data.rxdata;
                frame_200(84 downto 16) <= (others => '0');
                fifo_wr_en <= '0';
            else
                case state is
                    when COMMA =>
                        frame_200(15 downto 0) <= rx_data.rxdata;
                        frame_200(81 downto 80) <= rx_data.rxcharisk;
                        frame_200(83 downto 82) <= rx_data.rxchariscomma;
                        frame_200(84) <= '0';
                        fifo_wr_en <= '0';
                    when DATA_0 =>
                        frame_200(31 downto 16) <= rx_data.rxdata;
                        fifo_wr_en <= '0';
                    when DATA_1 =>
                        frame_200(47 downto 32) <= rx_data.rxdata;
                        fifo_wr_en <= '0';
                    when DATA_2 =>
                        frame_200(63 downto 48) <= rx_data.rxdata;
                        fifo_wr_en <= '0';
                    when DATA_3 =>
                        frame_200(79 downto 64) <= rx_data.rxdata;
                        fifo_wr_en <= '1';
                    when others =>
                        frame_200(15 downto 0) <= rx_data.rxdata;
                        fifo_wr_en <= '0';
                end case;
                
                if rx_data.rxnotintable /= "00" then
                    frame_200(84) <= '1';
                end if;
                
            end if;
        end if;
    end process;

    -- CDC to clk40
    -- for now just use a FIFO for this
    i_cdc_fifo : xpm_fifo_async
        generic map(
            FIFO_MEMORY_TYPE    => "auto",
            FIFO_WRITE_DEPTH    => 16,
            WRITE_DATA_WIDTH    => 85,
            READ_MODE           => "fwft",
            FIFO_READ_LATENCY   => 0,
            FULL_RESET_VALUE    => 0,
            USE_ADV_FEATURES    => "0101", -- VALID(12) = 1 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 0; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 0; OVERFLOW(0) = 1
            READ_DATA_WIDTH     => 85,
            CDC_SYNC_STAGES     => 2,
            DOUT_RESET_VALUE    => "0"
        )
        port map(
            sleep         => '0',
            rst           => reset_200,
            wr_clk        => rx_usrclk_i,
            wr_en         => fifo_wr_en,
            din           => frame_200,
            overflow      => fifo_ovf_200,
            rd_clk        => ttc_clk_40_i,
            rd_en         => '1',
            dout          => frame_40,
            underflow     => fifo_unf,
            empty         => fifo_empty,
            injectsbiterr => '0',
            injectdbiterr => '0'
        );    
    
    fifo_valid <= not fifo_empty;
    
    i_sync_fifo_ovf : entity work.synch generic map(N_STAGES => 3) port map(async_i => fifo_ovf_200, clk_i => ttc_clk_40_i, sync_o => fifo_ovf);
    
    fifo_ovf_o <= fifo_ovf;
    fifo_unf_o <= fifo_unf;
    
    --== Decode the frame ==--
    
    -- manage frame counter
    process(ttc_clk_40_i)
    begin
        if rising_edge(ttc_clk_40_i) then
            if reset_40 = '1' then
                frame_counter <= 0;
                frame_counter_valid <= '0';
            else
                if frame_counter_valid = '0' then
                    if frame_40(7 downto 0) = BC0_FRAME_MARKER and frame_40(81 downto 80) = "01" and frame_40(83 downto 82) = "01" then
                        frame_counter <= 1;
                        frame_counter_valid <= '1';
                    end if;
                else
                    if frame_counter = FRAME_MARKERS'length - 1 then
                        frame_counter <= 0;
                    else
                        frame_counter <= frame_counter + 1;
                    end if;
                    frame_counter_valid <= '1';
                end if;
            end if;
        end if;
    end process;
    
    -- check errors
    process(ttc_clk_40_i)
    begin
        if rising_edge(ttc_clk_40_i) then
            if check_errors_40 = '0' then
                missed_comma_err <= '0'; 
                sbit_overflow <= '0';
                not_in_table_err <= '0';
                bc0_marker <= '0';                   
            else
                not_in_table_err <= frame_40(84);
                
                if frame_40(7 downto 0) = OVERFLOW_FRAME_MARKER then
                    sbit_overflow <= '1';
                else
                    sbit_overflow <= '0';
                end if;

                if frame_40(7 downto 0) = BC0_FRAME_MARKER then
                    bc0_marker <= '1';
                else
                    bc0_marker <= '0';
                end if;

                if (frame_40(7 downto 0) /= FRAME_MARKERS(frame_counter)) and (frame_40(7 downto 0) /= OVERFLOW_FRAME_MARKER) and (frame_40(7 downto 0) /= BC0_FRAME_MARKER) and (frame_40(7 downto 0) /= RESYNC_FRAME_MARKER) then
                    missed_comma_err <= '1';
                else
                    missed_comma_err <= '0';
                end if;
                
            end if;
        end if;
    end process;
    
    -- decode clusters
    process(ttc_clk_40_i)
    begin
        if rising_edge(ttc_clk_40_i) then
            if reset_40 = '1' or fifo_valid = '0' then
                sbit_cluster0 <= NULL_SBIT_CLUSTER;
                sbit_cluster1 <= NULL_SBIT_CLUSTER;
                sbit_cluster2 <= NULL_SBIT_CLUSTER;
                sbit_cluster3 <= NULL_SBIT_CLUSTER;                
            else
                sbit_cluster0.address <= frame_40(18 downto 8);
                sbit_cluster0.size    <= frame_40(21 downto 19);
                sbit_cluster1.address <= frame_40(32 downto 22);
                sbit_cluster1.size    <= frame_40(35 downto 33);
                sbit_cluster2.address <= frame_40(46 downto 36);
                sbit_cluster2.size    <= frame_40(49 downto 47);
                sbit_cluster3.address <= frame_40(60 downto 50);
                sbit_cluster3.size    <= frame_40(63 downto 61);                
            end if;
        end if;
    end process;
    
    -- DEBUG
    gen_debug : if g_DEBUG generate
        component ila_trig_4g_decoder
            port(
                clk    : in std_logic;
                probe0 : in std_logic;
                probe1 : in std_logic_vector(84 downto 0);
                probe2 : in std_logic;
                probe3 : in std_logic;
                probe4 : in std_logic;
                probe5 : in std_logic;
                probe6 : in std_logic;
                probe7 : in std_logic
            );
        end component;
    begin
        i_ila : ila_trig_4g_decoder
            port map(
                clk    => ttc_clk_40_i,
                probe0 => reset_40,
                probe1 => frame_40,
                probe2 => fifo_unf,
                probe3 => fifo_empty,
                probe4 => check_errors_40,
                probe5 => missed_comma_err,
                probe6 => not_in_table_err,
                probe7 => bc0_marker
            );
    end generate;
    
end Behavioral;
