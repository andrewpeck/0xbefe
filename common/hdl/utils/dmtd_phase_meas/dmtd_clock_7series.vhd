----------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date: 06.04.2020
-- Module Name: dmtd_clock
-- Project Name: GEM_AMC
-- Description: Generates a 39.997MHz clock from 40.00MHz, 160.00MHz, or 320MHz input, which can be used for DMTD phase measurement. This file implements the xilinx 7 series version.
-- 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity dmtd_clock is
    generic(
        G_INPUT_CLK_PERIOD : real := 25.000 -- note that the only supported values for now are: 25.000, 6.25, 3.125 (you have to ignore the 40.08MHz nature of the LHC clock, and assume it's 40.00MHz)
    );
    port(
        reset_i         : in  std_logic;
        clk_i           : in  std_logic;
        clk_39_997_o    : out std_logic;
        locked_o        : out std_logic
    );
end dmtd_clock;

architecture dmtd_clock_7_series_arch of dmtd_clock is

    function get_clkfbout_mult_mmcm1(clk_in_period : real) return real is
    begin
        if (clk_in_period = 25.000) or (clk_in_period = 6.25) or (clk_in_period = 3.125) then
            return 62.625;
        else -- otherwise try to make it fail to synthesize
            return 0.0;  
        end if;
    end function get_clkfbout_mult_mmcm1;    

    function get_divclk_divide_mmcm1(clk_in_period : real) return integer is
    begin
        if clk_in_period = 25.000 then
            return 2;
        elsif clk_in_period = 6.25 then
            return 10;
        elsif clk_in_period = 3.125 then
            return 20;
        else -- otherwise try to make it fail to synthesize
            return 0;  
        end if;
    end function get_divclk_divide_mmcm1;    
    
    function get_clkout_divide_mmcm1(clk_in_period : real) return real is
    begin
        if clk_in_period = 25.000 then
            return 31.250;
        elsif clk_in_period = 6.25 then
            return 25.000;
        elsif clk_in_period = 3.125 then
            return 25.000;
        else -- otherwise try to make it fail to synthesize
            return 0.0;  
        end if;
    end function get_clkout_divide_mmcm1;    

    constant MMCM1_CLKFBOUT_MULT    : real := get_clkfbout_mult_mmcm1(G_INPUT_CLK_PERIOD);
    constant MMCM1_DIVCLK_DIVIDE    : integer := get_divclk_divide_mmcm1(G_INPUT_CLK_PERIOD);
    constant MMCM1_CLKOUT_DIVIDE    : real := get_clkout_divide_mmcm1(G_INPUT_CLK_PERIOD);

    signal mmcm1_clkfb      : std_logic;
    signal clk_40p08        : std_logic;
    signal clk_40p08_bufg   : std_logic;
    signal mmcm1_locked     : std_logic;
    
    signal mmcm2_clkfb      : std_logic;
    signal clk_39p997       : std_logic;
    signal clk_39p997_bufg  : std_logic;
    signal mmcm2_locked     : std_logic;
    
begin

    locked_o <= mmcm1_locked and mmcm2_locked;
    clk_39_997_o <= clk_39p997_bufg;

    -- first stage MMCM producing producing 40.08MHz
    i_mmcm1 : MMCME2_ADV
        generic map(BANDWIDTH            => "OPTIMIZED",
                    CLKOUT4_CASCADE      => FALSE,
                    COMPENSATION         => "ZHOLD",
                    STARTUP_WAIT         => FALSE,
                    DIVCLK_DIVIDE        => MMCM1_DIVCLK_DIVIDE,
                    CLKFBOUT_MULT_F      => MMCM1_CLKFBOUT_MULT,
                    CLKFBOUT_PHASE       => 0.000,
                    CLKFBOUT_USE_FINE_PS => FALSE,
                    CLKOUT0_DIVIDE_F     => MMCM1_CLKOUT_DIVIDE,
                    CLKOUT0_PHASE        => 0.000,
                    CLKOUT0_DUTY_CYCLE   => 0.500,
                    CLKOUT0_USE_FINE_PS  => FALSE,
                    CLKIN1_PERIOD        => G_INPUT_CLK_PERIOD)
        port map(
            CLKFBOUT     => mmcm1_clkfb,
            CLKFBOUTB    => open,
            CLKOUT0      => clk_40p08,
            CLKOUT0B     => open,
            CLKOUT1      => open,
            CLKOUT1B     => open,
            CLKOUT2      => open,
            CLKOUT2B     => open,
            CLKOUT3      => open,
            CLKOUT3B     => open,
            CLKOUT4      => open,
            CLKOUT5      => open,
            CLKOUT6      => open,
            -- Input clock control
            CLKFBIN      => mmcm1_clkfb,
            CLKIN1       => clk_i,
            CLKIN2       => '0',
            -- Tied to always select the primary input clock
            CLKINSEL     => '1',
            -- Ports for dynamic reconfiguration
            DADDR        => (others => '0'),
            DCLK         => '0',
            DEN          => '0',
            DI           => (others => '0'),
            DO           => open,
            DRDY         => open,
            DWE          => '0',
            -- Ports for dynamic phase shift
            PSCLK        => '0',
            PSEN         => '0',
            PSINCDEC     => '0',
            PSDONE       => open,
            -- Other control and status signals
            LOCKED       => mmcm1_locked,
            CLKINSTOPPED => open,
            CLKFBSTOPPED => open,
            PWRDWN       => '0',
            RST          => reset_i
        );

    i_clk_40p08_bufg : BUFG
        port map(O => clk_40p08_bufg,
                 I => clk_40p08
        );

    -- second stage MMCM producing producing 39.997MHz out of the 40.08MHz
    i_mmcm2 : MMCME2_ADV
        generic map(BANDWIDTH            => "OPTIMIZED",
                    CLKOUT4_CASCADE      => FALSE,
                    COMPENSATION         => "ZHOLD",
                    STARTUP_WAIT         => FALSE,
                    DIVCLK_DIVIDE        => 3,
                    CLKFBOUT_MULT_F      => 60.250,
                    CLKFBOUT_PHASE       => 0.000,
                    CLKFBOUT_USE_FINE_PS => FALSE,
                    CLKOUT0_DIVIDE_F     => 20.125,
                    CLKOUT0_PHASE        => 0.000,
                    CLKOUT0_DUTY_CYCLE   => 0.500,
                    CLKOUT0_USE_FINE_PS  => FALSE,
                    CLKIN1_PERIOD        => 24.95)
        port map(
            CLKFBOUT     => mmcm2_clkfb,
            CLKFBOUTB    => open,
            CLKOUT0      => clk_39p997,
            CLKOUT0B     => open,
            CLKOUT1      => open,
            CLKOUT1B     => open,
            CLKOUT2      => open,
            CLKOUT2B     => open,
            CLKOUT3      => open,
            CLKOUT3B     => open,
            CLKOUT4      => open,
            CLKOUT5      => open,
            CLKOUT6      => open,
            -- Input clock control
            CLKFBIN      => mmcm2_clkfb,
            CLKIN1       => clk_40p08_bufg,
            CLKIN2       => '0',
            -- Tied to always select the primary input clock
            CLKINSEL     => '1',
            -- Ports for dynamic reconfiguration
            DADDR        => (others => '0'),
            DCLK         => '0',
            DEN          => '0',
            DI           => (others => '0'),
            DO           => open,
            DRDY         => open,
            DWE          => '0',
            -- Ports for dynamic phase shift
            PSCLK        => '0',
            PSEN         => '0',
            PSINCDEC     => '0',
            PSDONE       => open,
            -- Other control and status signals
            LOCKED       => mmcm2_locked,
            CLKINSTOPPED => open,
            CLKFBSTOPPED => open,
            PWRDWN       => '0',
            RST          => reset_i
        );

    i_clk_39p997_bufg : BUFG
        port map(O => clk_39p997_bufg,
                 I => clk_39p997
        );

end dmtd_clock_7_series_arch;
