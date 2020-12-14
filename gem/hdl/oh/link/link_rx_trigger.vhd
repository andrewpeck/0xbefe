------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    00:01 2016-05-10
-- Module Name:    link_rx_trigger
-- Description:    This module takes two GTX/GTH trigger RX links and outputs sbit cluster data synchronous to the TTC clk  
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.gem_pkg.all;

entity link_rx_trigger is
    generic(
        g_DEBUG         : boolean := false -- if this is set to true, some chipscope cores will be inserted
    );
    port(
        ttc_clk_i           : in  std_logic;
        reset_i             : in  std_logic;
        
        gt_rx_trig_usrclk_i : in  std_logic;
        rx_kchar_i          : in std_logic_vector(1 downto 0);
        rx_data_i           : in std_logic_vector(15 downto 0);
        
        sbit_cluster0_o     : out t_sbit_cluster;
        sbit_cluster1_o     : out t_sbit_cluster;
        sbit_cluster2_o     : out t_sbit_cluster;
        sbit_cluster3_o     : out t_sbit_cluster;
        link_status_o       : out t_sbit_link_status
    );
end link_rx_trigger;

architecture Behavioral of link_rx_trigger is    

    COMPONENT ila_trig_rx_link
        PORT(
            clk     : IN STD_LOGIC;
            probe0  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            probe1  : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            probe2  : IN STD_LOGIC_VECTOR(58 DOWNTO 0);
            probe3  : IN STD_LOGIC_VECTOR(58 DOWNTO 0);
            probe4  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            probe5  : IN STD_LOGIC;
            probe6  : IN STD_LOGIC;
            probe7  : IN STD_LOGIC;
            probe8  : IN STD_LOGIC;
            probe9  : IN STD_LOGIC;
            probe10 : IN STD_LOGIC;
            probe11 : IN STD_LOGIC;
            probe12 : IN STD_LOGIC
        );
    END COMPONENT;

    component sbit_cluster_fifo is
        port(
            rst         : IN  STD_LOGIC;
            wr_clk      : IN  STD_LOGIC;
            rd_clk      : IN  STD_LOGIC;
            din         : IN  STD_LOGIC_VECTOR(58 DOWNTO 0);
            wr_en       : IN  STD_LOGIC;
            rd_en       : IN  STD_LOGIC;
            dout        : OUT STD_LOGIC_VECTOR(58 DOWNTO 0);
            full        : OUT STD_LOGIC;
            almost_full : OUT STD_LOGIC;
            empty       : OUT STD_LOGIC;
            valid       : OUT STD_LOGIC;
            underflow   : OUT STD_LOGIC
        );
    end component sbit_cluster_fifo;

    -- trigger links will send a K-char every 4 clocks to mark a BX start, and every BX it will cycle through 4 different K-chars: 0xBC, 0xF7, 0xFB, 0xFD
    -- in case there is an overflow in that particular BX, the K-char for this BX will be 0xFC

    constant FRAME_MARKERS          : t_std8_array(0 to 3) := (x"bc", x"f7", x"fb", x"fd");
    constant OVERFLOW_FRAME_MARKER  : std_logic_vector(7 downto 0) := x"fc";
    constant BC0_FRAME_MARKER       : std_logic_vector(7 downto 0) := x"1c";
    constant RESYNC_FRAME_MARKER    : std_logic_vector(7 downto 0) := x"3c";

    type state_t is (COMMA, DATA_0, DATA_1, DATA_2);    
    
    signal state                : state_t := COMMA;
    signal frame_counter        : integer range 0 to 3;
    signal reset_cntdown        : unsigned(7 downto 0) := x"ff"; -- after a reset this is count down every clock cycle and errors are counted only after this reaches 0 
    signal missed_comma_err     : std_logic := '0'; -- asserted if a comma character is not found when FSM is in COMMA state
    signal sbit_overflow        : std_logic := '0'; -- asserted when an overflow K-char is detected at the BX boundary (0xFC)

    signal fifo_we              : std_logic := '0';
    signal fifo_re              : std_logic := '0';
    signal fifo_din             : std_logic_vector(58 downto 0) := (others => '0');
    signal fifo_dout            : std_logic_vector(58 downto 0);
    signal fifo_almost_full     : std_logic;
    signal fifo_underflow       : std_logic;

begin  

    --== FSM STATE ==--

    process(gt_rx_trig_usrclk_i)
    begin
        if (rising_edge(gt_rx_trig_usrclk_i)) then
            if (reset_i = '1') then
                state <= COMMA;
                frame_counter <= 0;
            else
                case state is
                    when COMMA =>
                        if (rx_kchar_i(1 downto 0) = "01" and ((rx_data_i(7 downto 0) = FRAME_MARKERS(frame_counter)) or (rx_data_i(7 downto 0) = OVERFLOW_FRAME_MARKER) or (rx_data_i(7 downto 0) = BC0_FRAME_MARKER) or (rx_data_i(7 downto 0) = RESYNC_FRAME_MARKER))) then
                            state <= DATA_0;
                            if (frame_counter = 3) then
                                frame_counter <= 0;
                            else
                                frame_counter <= frame_counter + 1;
                            end if;
                        end if;
                    when DATA_0 => state <= DATA_1;
                    when DATA_1 => state <= DATA_2;
                    when DATA_2 => state <= COMMA;
                    when others => state <= COMMA;
                end case;
            end if;
        end if;
    end process;
    
    --== FSM LOGIC ==--

    process(gt_rx_trig_usrclk_i)
    begin
        if (rising_edge(gt_rx_trig_usrclk_i)) then
            if (reset_i = '1') then
                reset_cntdown <= x"ff";
                missed_comma_err <= '0';
                fifo_we <= '0';
                fifo_re <= '0';
                sbit_overflow <= '0';
            else
                
                if (reset_cntdown /= x"00") then
                    reset_cntdown <= reset_cntdown - 1;
                end if;
                
                case state is
                    when COMMA =>
                        fifo_we <= '0';
                        if (rx_kchar_i(1 downto 0) = "01" and ((rx_data_i(7 downto 0) = FRAME_MARKERS(frame_counter)) or (rx_data_i(7 downto 0) = OVERFLOW_FRAME_MARKER) or (rx_data_i(7 downto 0) = BC0_FRAME_MARKER) or (rx_data_i(7 downto 0) = RESYNC_FRAME_MARKER))) then
                            if (fifo_we = '1') then
                                missed_comma_err <= '0'; -- deassert it only if it's the first clock we're in the COMMA state
                            end if;
                            if (rx_data_i(7 downto 0) = OVERFLOW_FRAME_MARKER) then
                                sbit_overflow <= '1';
                            else
                                sbit_overflow <= '0';
                            end if;
                            fifo_din(7 downto 0) <= rx_data_i(15 downto 8);
                        elsif (reset_cntdown = x"00") then
                            missed_comma_err <= '1';
                        end if;
                    when DATA_0 =>
                        fifo_din(23 downto 8) <= rx_data_i(15 downto 0);
                    when DATA_1 =>
                        fifo_din(39 downto 24) <= rx_data_i(15 downto 0);
                    when DATA_2 =>
                        fifo_we <= '1';
                        fifo_re <= '1';
                        fifo_din(55 downto 40) <= rx_data_i(15 downto 0);
                        fifo_din(56) <= missed_comma_err;
                        fifo_din(57) <= fifo_almost_full;
                        fifo_din(58) <= sbit_overflow;
                    when others =>
                        fifo_we <= '0';
                end case;
            end if;
        end if;
    end process;

    --== Sync FIFO ==--
    
    i_sync_fifo : component sbit_cluster_fifo
        port map(
            rst         => reset_i,
            wr_clk      => gt_rx_trig_usrclk_i,
            rd_clk      => ttc_clk_i,
            din         => fifo_din,
            wr_en       => fifo_we,
            rd_en       => fifo_re,
            dout        => fifo_dout,
            full        => open,
            almost_full => fifo_almost_full,
            empty       => open,
            valid       => open,
            underflow   => fifo_underflow
        );
    
    link_status_o.missed_comma  <= fifo_dout(56);
    link_status_o.overflow      <= fifo_dout(57);
    link_status_o.sbit_overflow <= fifo_dout(58);
    link_status_o.sync_word     <= '0';
    link_status_o.underflow     <= fifo_underflow;
    
    sbit_cluster0_o.size     <= fifo_dout(13 downto 11);
    sbit_cluster0_o.address  <= fifo_dout(10 downto  0);
    sbit_cluster1_o.size     <= fifo_dout(27 downto 25);
    sbit_cluster1_o.address  <= fifo_dout(24 downto 14);
    sbit_cluster2_o.size     <= fifo_dout(41 downto 39);
    sbit_cluster2_o.address  <= fifo_dout(38 downto 28);
    sbit_cluster3_o.size     <= fifo_dout(55 downto 53);
    sbit_cluster3_o.address  <= fifo_dout(52 downto 42);
    
    gen_debug:
    if g_DEBUG generate
        i_dbg_ila : component ila_trig_rx_link
            port map(
                clk     => gt_rx_trig_usrclk_i,
                probe0  => std_logic_vector(to_unsigned(frame_counter, 2)),
                probe1  => rx_data_i,
                probe2  => fifo_din,
                probe3  => fifo_dout,
                probe4  => std_logic_vector(to_unsigned(state_t'pos(state), 2)),
                probe5  => '1',
                probe6  => missed_comma_err,
                probe7  => fifo_we,
                probe8  => fifo_re,
                probe9  => sbit_overflow,
                probe10 => reset_i,
                probe11 => ttc_clk_i,
                probe12 => fifo_almost_full
            );
    end generate;
    
end Behavioral;
