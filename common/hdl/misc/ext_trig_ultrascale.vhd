--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company:
-- Engineer: Laurent Pétré (laurent.petre@cern.ch)
--
-- Create Date: 16/05/2022
-- Module Name: ext_trig
-- Project Name:
-- Description: This module oversamples an external input trigger signal, finds the rising edges,
--    and selects the phases w.r.t. the 40 MHz LHC clock for which the trigger are accepted.
--    Its typical usage is to simulate a synchronous source even for an asynchronous source
--    (beam, cosmics,...)
--
--------------------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

use work.ttc_pkg.all;

--============================================================================
--                                                          Entity declaration
--============================================================================
entity ext_trig is
    generic (
        g_DEBUG         : boolean := false
    );
    port (
        clocks_i        : in  t_ttc_clks;
        reset_i         : in  std_logic := '0';
        async_trigger_i : in  std_logic;
        phase_mask_i    : in  std_logic_vector(15 downto 0) := x"ffff";
        ext_trigger_o   : out std_logic
    );

end ext_trig;

--============================================================================
--                                                        Architecture section
--============================================================================
architecture ext_trig_arch of ext_trig is

    component ila_ext_trig
        port (
            clk    : in std_logic;
            probe0 : in std_logic_vector(15 downto 0);
            probe1 : in std_logic_vector(15 downto 0);
            probe2 : in std_logic
        );
    end component;

    --============================================================================
    --                                                         Signal declarations
    --============================================================================
    signal reset320        : std_logic;
    signal phase_mask40    : std_logic_vector(15 downto 0);

    signal q1, q2          : std_logic;

    signal toggle40        : std_logic;
    signal toggle320       : std_logic;
    signal fill_counter    : unsigned(2 downto 0);
    signal sample320       : std_logic_vector(15 downto 0);
    signal sample40        : std_logic_vector(15 downto 0);

    signal sample40_prev   : std_logic_vector(15 downto 0);
    signal sample40_rising : std_logic_vector(15 downto 0);
    signal ext_trigger     : std_logic;

--============================================================================
--                                                          Architecture begin
--============================================================================
begin

    -- Wiring
    reset320     <= reset_i when rising_edge(clocks_i.clk_320);
    phase_mask40 <= phase_mask_i when rising_edge(clocks_i.clk_40);

    -- Sampling
    i_iddre1 : IDDRE1
    generic map (
        DDR_CLK_EDGE => "SAME_EDGE",
        IS_C_INVERTED => '0'
    )
    port map (
        Q1 => q1,
        Q2 => q2,
        C  => clocks_i.clk_320,
        CB => not clocks_i.clk_320,
        D  => async_trigger_i,
        R  => reset320
    );

    -- CDC
    toggle40  <= not toggle40 when rising_edge(clocks_i.clk_40);

    process (clocks_i.clk_320)
    begin
        if rising_edge(clocks_i.clk_320) then
            sample320(to_integer(fill_counter)*2 + 1 downto to_integer(fill_counter)*2) <= q2 & q1;

            -- Reset the fill counter based on the 40 MHz rising edge
            toggle320 <= toggle40;
            if (toggle40 = '1'and toggle320 = '0') then
                -- Starting at 7 (last bits to be filled) - 2 (toggle signal delay)
                fill_counter <= to_unsigned(5, 3);
            else
                fill_counter <= fill_counter - 1;
            end if;
        end if;
    end process;

    sample40 <= sample320 when rising_edge(clocks_i.clk_40);

    -- Output
    sample40_prev   <= sample40 when rising_edge(clocks_i.clk_40);
    sample40_rising <= sample40 and not (sample40_prev(0 downto 0) & sample40(15 downto 1));
    ext_trigger     <= or_reduce(sample40_rising and phase_mask40) when rising_edge(clocks_i.clk_40);
    ext_trigger_o   <= ext_trigger;

    -- Debug
    ila_enable : if g_DEBUG generate
        i_ila_ext_trig : ila_ext_trig
            port map (
                clk    => clocks_i.clk_40,
                probe0 => sample40,
                probe1 => sample40_rising,
                probe2 => ext_trigger
            );
    end generate;

end ext_trig_arch;
--============================================================================
--                                                            Architecture end
--============================================================================
