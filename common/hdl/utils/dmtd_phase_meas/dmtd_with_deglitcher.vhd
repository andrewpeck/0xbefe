-------------------------------------------------------------------------------
-- Title      : Digital DMTD Edge Tagger
-- Project    : White Rabbit
-------------------------------------------------------------------------------
-- File       : dmtd_with_deglitcher.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-02-25
-- Last update: 2013-07-29
-- Platform   : FPGA-generic
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Description: Single-channel DDMTD phase tagger with integrated bit-median
-- deglitcher. Contains a DDMTD detector, which output signal is deglitched and
-- tagged with a counter running in DMTD offset clock domain. Phase tags are
-- generated for each rising edge in DDMTD output with an internal counter
-------------------------------------------------------------------------------
--
-- Copyright (c) 2009 - 2011 CERN
--
-- This source file is free software; you can redistribute it   
-- and/or modify it under the terms of the GNU Lesser General   
-- Public License as published by the Free Software Foundation; 
-- either version 2.1 of the License, or (at your option) any   
-- later version.                                               
--
-- This source is distributed in the hope that it will be       
-- useful, but WITHOUT ANY WARRANTY; without even the implied   
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
-- PURPOSE.  See the GNU Lesser General Public License for more 
-- details.                                                     
--
-- You should have received a copy of the GNU Lesser General    
-- Public License along with this source; if not, download it   
-- from http://www.gnu.org/licenses/lgpl-2.1.html
--
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2009-01-24  1.0      twlostow        Created
-- 2011-18-04  1.1      twlostow        Bit-median type deglitcher, comments
-- 2020-04-09  1.2      Evaldas Juska   synchronize the clock input; cross to sys clk domain for tag_stb_p1_o; removed the not needed options of reverse and divide by 2; removed the unused rst_n_sysclk_i
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.NUMERIC_STD.all;

-- [PV 2015.08.17] library work;
-- [PV 2015.08.17] use work.gencores_pkg.all;

entity dmtd_with_deglitcher is
    generic(
        -- Size of the phase tag counter. Must be big enough to cover at least one
        -- full period of the DDMTD detector output. Given the frequencies of clk_in_i
        -- and clk_dmtd_i are respectively f_in an f_dmtd, it can be calculated with
        -- the following formula:
        -- g_counter_bits = log2(f_in / abs(f_in - f_dmtd)) + 1
        g_counter_bits      : natural := 17
    );
    port(
        -- resets for different clock domains
        rst_n_dmtdclk_i      : in  std_logic;

        -- input clock
        clk_in_i             : in  std_logic;

        -- DMTD sampling clock
        clk_dmtd_i           : in  std_logic;

        -- system clock
        clk_sys_i            : in  std_logic;

        -- [clk_dmtd_i] phase shifter enable, HI level shifts the internal counter
        -- forward/backward by 1 clk_dmtd_i cycle, effectively shifting the tag
        -- value by +-1.
        shift_en_i           : in  std_logic := '0';

        -- [clk_dmtd_i] phase shift direction: 1 - forward, 0 - backward
        shift_dir_i          : in  std_logic := '0';

        -- DMTD clock enable, active high. Can be used to reduce the DMTD sampling
        -- frequency - for example, two 10 MHz signals cannot be sampled directly
        -- with a 125 MHz clock, but it's possible with a 5 MHz reference, obtained
        -- by asserting clk_dmtd_en_i every 25 clk_dmtd_i cycles.

        clk_dmtd_en_i        : in  std_logic := '1';

        -- [clk_dmtd_i] deglitcher threshold
        deglitch_threshold_i : in  std_logic_vector(15 downto 0);

        -- [clk_sys_i] deglitched edge tag value
        tag_o                : out std_logic_vector(g_counter_bits - 1 downto 0);

        -- [clk_sys_i] pulse indicates new phase tag on tag_o
        tag_stb_p1_o         : out std_logic
    );

end dmtd_with_deglitcher;

architecture rtl of dmtd_with_deglitcher is
    type t_state is (WAIT_STABLE_0, WAIT_EDGE, GOT_EDGE);

    signal state            : t_state;

    signal stab_cntr        : unsigned(15 downto 0);
    signal free_cntr        : unsigned(g_counter_bits - 1 downto 0);

    signal clk_in           : std_logic;

    signal new_edge_sreg    : std_logic_vector(5 downto 0);
    signal new_edge_p       : std_logic;

    signal tag_int          : unsigned(g_counter_bits - 1 downto 0);

begin                                   -- rtl

    i_sync_clk_in : entity work.synch
        generic map(
            N_STAGES => 4
        )
        port map(
            async_i => clk_in_i,
            clk_i   => clk_dmtd_i,
            sync_o  => clk_in
        );

    -- glitchproof DMTD output edge detection
    p_deglitch : process(clk_dmtd_i)
    begin                               -- process deglitch

        if rising_edge(clk_dmtd_i) then -- rising clock edge

            if (rst_n_dmtdclk_i = '0') then -- synchronous reset (active low)
                stab_cntr     <= (others => '0');
                state         <= WAIT_STABLE_0;
                free_cntr     <= (others => '0');
                new_edge_sreg <= (others => '0');
            elsif (clk_dmtd_en_i = '1') then
                if (shift_en_i = '0') then -- phase shifter
                    free_cntr <= free_cntr + 1;
                elsif (shift_dir_i = '1') then
                    free_cntr <= free_cntr + 2;
                end if;

                case state is
                    when WAIT_STABLE_0 => -- out-of-sync
                        new_edge_sreg <= '0' & new_edge_sreg(new_edge_sreg'length - 1 downto 1);

                        if clk_in /= '0' then
                            stab_cntr <= (others => '0');
                        else
                            stab_cntr <= stab_cntr + 1;
                        end if;

                        -- DMTD output stable counter hit the LOW level threshold?
                        if stab_cntr = unsigned(deglitch_threshold_i) then
                            state <= WAIT_EDGE;
                        end if;

                    when WAIT_EDGE =>
                        if (clk_in /= '0') then -- got a glitch?
                            state     <= GOT_EDGE;
                            tag_int   <= free_cntr;
                            stab_cntr <= (others => '0');
                        end if;

                    when GOT_EDGE =>
                        if (clk_in = '0') then
                            tag_int <= tag_int + 1; --free_cntr;--tag_int + 1; -- why not assign the free counter here????
                        end if;

                        if stab_cntr = unsigned(deglitch_threshold_i) then
                            state         <= WAIT_STABLE_0;
                            tag_o         <= std_logic_vector(tag_int);
                            new_edge_sreg <= (others => '1');
                            stab_cntr     <= (others => '0');
                        elsif (clk_in = '0') then
                            stab_cntr <= (others => '0');
                        else
                            stab_cntr <= stab_cntr + 1;
                        end if;

                end case;
            end if;
        end if;
    end process p_deglitch;

    U_sync_tag_strobe : entity work.oneshot_cross_domain
        port map(
            reset_i       => '0',
            input_clk_i   => clk_dmtd_i,
            oneshot_clk_i => clk_sys_i,
            input_i       => new_edge_sreg(0),
            oneshot_o     => new_edge_p
        );

    tag_stb_p1_o <= new_edge_p;

end rtl;
