------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    00:01 2016-05-10
-- Module Name:    link_rx_trigger_ge11_3p2g
-- Description:    This module takes two GTX/GTH trigger RX links and outputs sbit cluster data synchronous to the TTC clk. It works with GE1/1 OHs and early prototypes of GE2/1 OH which use dedicated 8b10b trigger links.
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.common_pkg.all;
use work.gem_pkg.all;

entity link_rx_trigger_ge11_3p2g is
    generic(
        g_DEBUG         : boolean := false -- if this is set to true, some chipscope cores will be inserted
    );
    port(
        reset_i             : in  std_logic;

        ttc_clk_40_i        : in  std_logic;
        ttc_clk_160_i       : in  std_logic;
        
        rx_data_i           : in t_mgt_16b_rx_data; -- data expected to be on the ttc_clk_160_i domain
        
        sbit_cluster0_o     : out t_sbit_cluster;
        sbit_cluster1_o     : out t_sbit_cluster;
        sbit_cluster2_o     : out t_sbit_cluster;
        sbit_cluster3_o     : out t_sbit_cluster;
        sbit_overflow_o     : out std_logic;
        bc0_marker_o        : out std_logic;
        
        missed_comma_err_o  : out std_logic
    );
end link_rx_trigger_ge11_3p2g;

architecture Behavioral of link_rx_trigger_ge11_3p2g is    

    -- trigger links will send a K-char every 4 clocks to mark a BX start, and every BX it will cycle through 4 different K-chars: 0xBC, 0xF7, 0xFB, 0xFD
    -- in case there is an overflow in that particular BX, the K-char for this BX will be 0xFE

    -- in order of priority
    constant BC0_FRAME_MARKER       : std_logic_vector(7 downto 0) := x"1c"; -- K.28.0
    constant RESYNC_FRAME_MARKER    : std_logic_vector(7 downto 0) := x"3c"; -- K.28.1
    constant OVERFLOW_FRAME_MARKER  : std_logic_vector(7 downto 0) := x"fe"; -- K.30.7
    constant FRAME_MARKERS          : t_std8_array(0 to 3) := (x"bc", x"f7", x"fb", x"fd"); -- K.28.5, K.23.7, K.27.7, K.29.7

    type state_t is (COMMA, DATA_0, DATA_1, DATA_2);    
    
    signal state                : state_t := COMMA;
    signal state_prev           : state_t := COMMA;
    signal frame_counter        : integer range 0 to 3;
    signal reset_cntdown        : unsigned(7 downto 0) := x"ff"; -- after a reset this is count down every clock cycle and errors are counted only after this reaches 0 
    signal missed_comma_err     : std_logic := '0'; -- asserted if a comma character is not found when FSM is in COMMA state
    signal sbit_overflow        : std_logic := '0'; -- asserted when an overflow K-char is detected at the BX boundary (0xFC)
    signal bc0_marker           : std_logic := '0';

    signal frame_buf            : std_logic_vector(39 downto 0);

begin  

    --== FSM STATE ==--

    process(ttc_clk_160_i)
    begin
        if (rising_edge(ttc_clk_160_i)) then
            if (reset_i = '1') then
                state <= COMMA;
                frame_counter <= 0;
            else
                state_prev <= state;
                case state is
                    when COMMA =>
                        if (rx_data_i.rxcharisk(1 downto 0) = "01" and ((rx_data_i.rxdata(7 downto 0) = FRAME_MARKERS(frame_counter)) or (rx_data_i.rxdata(7 downto 0) = OVERFLOW_FRAME_MARKER) or (rx_data_i.rxdata(7 downto 0) = BC0_FRAME_MARKER) or (rx_data_i.rxdata(7 downto 0) = RESYNC_FRAME_MARKER))) then
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

    process(ttc_clk_160_i)
    begin
        if (rising_edge(ttc_clk_160_i)) then
            if (reset_i = '1') then
                reset_cntdown <= x"ff";
                missed_comma_err <= '0';
                sbit_overflow <= '0';
                bc0_marker <= '0';
            else
                
                if (reset_cntdown /= x"00") then
                    reset_cntdown <= reset_cntdown - 1;
                end if;
                
                case state is
                    when COMMA =>
                        if (rx_data_i.rxcharisk(1 downto 0) = "01" and ((rx_data_i.rxdata(7 downto 0) = FRAME_MARKERS(frame_counter)) or (rx_data_i.rxdata(7 downto 0) = OVERFLOW_FRAME_MARKER) or (rx_data_i.rxdata(7 downto 0) = BC0_FRAME_MARKER) or (rx_data_i.rxdata(7 downto 0) = RESYNC_FRAME_MARKER))) then
                            if (state_prev = DATA_2) then
                                missed_comma_err <= '0'; -- deassert it only if it's the first clock we're in the COMMA state
                            end if;
                            if (rx_data_i.rxdata(7 downto 0) = OVERFLOW_FRAME_MARKER) then
                                sbit_overflow <= '1';
                            else
                                sbit_overflow <= '0';
                            end if;
                            if (rx_data_i.rxdata(7 downto 0) = BC0_FRAME_MARKER) then
                                bc0_marker <= '1';
                            else
                                bc0_marker <= '0';
                            end if;
                            frame_buf(7 downto 0) <= rx_data_i.rxdata(15 downto 8);
                        elsif (reset_cntdown = x"00") then
                            missed_comma_err <= '1';
                        end if;
                    when DATA_0 =>
                        frame_buf(23 downto 8) <= rx_data_i.rxdata(15 downto 0);
                    when DATA_1 =>
                        frame_buf(39 downto 24) <= rx_data_i.rxdata(15 downto 0);
                    when DATA_2 =>                        
                        sbit_cluster0_o.address  <= frame_buf(10 downto  0);
                        sbit_cluster0_o.size     <= frame_buf(13 downto 11);
                        sbit_cluster1_o.address  <= frame_buf(24 downto 14);
                        sbit_cluster1_o.size     <= frame_buf(27 downto 25);
                        sbit_cluster2_o.address  <= frame_buf(38 downto 28);
                        sbit_cluster2_o.size     <= rx_data_i.rxdata(1 downto 0) & frame_buf(39);
                        sbit_cluster3_o.address  <= rx_data_i.rxdata(12 downto 2);                        
                        sbit_cluster3_o.size     <= rx_data_i.rxdata(15 downto 13);                        
                        sbit_overflow_o <= sbit_overflow;
                        bc0_marker_o <= bc0_marker;
                end case;
            end if;
        end if;
    end process;
    
    i_sync_missed_comma : entity work.synch generic map(N_STAGES => 3) port map(async_i => missed_comma_err, clk_i => ttc_clk_40_i, sync_o  => missed_comma_err_o);
    
end Behavioral;
