--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company:
-- Engineer: Laurent Pétré (laurent.petre@cern.ch)
--
-- Create Date: 01/09/2022 14:37:30
-- Module Name: ten_gbe_clocks
-- Project Name:
-- Description: This module is meant to create the TXUSRCLK and TXUSRCLK2 clocks, based on the 
--              TXOUTCLK clock, for the 64 bits 10 GbE MGT.
--
--------------------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library xpm;
use xpm.vcomponents.all;

library UNISIM;
use UNISIM.VComponents.all;

--============================================================================
--                                                          Entity declaration
--============================================================================
entity ten_gbe_clocks is
    port (
        mmcm_reset_i  : in  std_logic;
        mmcm_locked_o : out std_logic;
        txoutclk_i    : in  std_logic;
        txusrclk_o    : out std_logic;
        txusrclk2_o   : out std_logic
    );

end ten_gbe_clocks;

--============================================================================
--                                                        Architecture section
--============================================================================
architecture ten_gbe_clocks_arch of ten_gbe_clocks is

    signal clkfbout  : std_logic;
    signal txusrclk2 : std_logic;
    signal txusrclk : std_logic;

--============================================================================
--                                                          Architecture begin
--============================================================================
begin

    -- MMCM
    i_mmcm : MMCME2_ADV
        generic map(
            BANDWIDTH            => "OPTIMIZED",
            CLKOUT4_CASCADE      => false,
            COMPENSATION         => "ZHOLD",
            STARTUP_WAIT         => false,
            DIVCLK_DIVIDE        => 1,
            CLKFBOUT_MULT_F      => 2.000,
            CLKFBOUT_PHASE       => 0.000,
            CLKFBOUT_USE_FINE_PS => false,
            CLKOUT0_DIVIDE_F     => 4.000,
            CLKOUT0_PHASE        => 0.000,
            CLKOUT0_DUTY_CYCLE   => 0.500,
            CLKOUT0_USE_FINE_PS  => false,
            CLKOUT1_DIVIDE       => 2,
            CLKOUT1_PHASE        => 0.000,
            CLKOUT1_DUTY_CYCLE   => 0.500,
            CLKOUT1_USE_FINE_PS  => false,
            CLKOUT2_DIVIDE       => 1,
            CLKOUT2_PHASE        => 0.000,
            CLKOUT2_DUTY_CYCLE   => 0.500,
            CLKOUT2_USE_FINE_PS  => false,
            CLKOUT3_DIVIDE       => 1,
            CLKOUT3_PHASE        => 0.000,
            CLKOUT3_DUTY_CYCLE   => 0.500,
            CLKOUT3_USE_FINE_PS  => false,
            CLKOUT4_DIVIDE       => 1,
            CLKOUT4_PHASE        => 0.000,
            CLKOUT4_DUTY_CYCLE   => 0.500,
            CLKOUT4_USE_FINE_PS  => false,
            CLKIN1_PERIOD        => 3.103,
            REF_JITTER1          => 0.010)
        port map(
            -- Output clocks
            CLKFBOUT     => clkfbout,
            CLKFBOUTB    => open,
            CLKOUT0      => txusrclk2,
            CLKOUT0B     => open,
            CLKOUT1      => txusrclk,
            CLKOUT1B     => open,
            CLKOUT2      => open,
            CLKOUT2B     => open,
            CLKOUT3      => open,
            CLKOUT3B     => open,
            CLKOUT4      => open,
            CLKOUT5      => open,
            CLKOUT6      => open,
            -- Input clock control
            CLKFBIN      => clkfbout,
            CLKIN1       => txoutclk_i,
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
            LOCKED       => mmcm_locked_o,
            CLKINSTOPPED => open,
            CLKFBSTOPPED => open,
            PWRDWN       => '0',
            RST          => mmcm_reset_i
        );

    -- Output buffering
    i_bufg_txusclk : BUFG
        port map(
            I => txusrclk,
            O => txusrclk_o
        );

    i_bufg_txusclk2 : BUFG
        port map(
            I => txusrclk2,
            O => txusrclk2_o
        );

end ten_gbe_clocks_arch;
--============================================================================
--                                                            Architecture end
--============================================================================
