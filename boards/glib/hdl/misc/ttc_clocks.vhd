-------------------------------------------------------------------------------
--                                                                            
--       Unit Name: ttc_clocks                                            
--                                                                            
--     Description: 
--
--                                                                            
-------------------------------------------------------------------------------
--                                                                            
--           Notes:                                                           
--                                                                            
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.VComponents.all;

--============================================================================
--                                                          Entity declaration
--============================================================================
entity ttc_clocks is
  port(
    clk_40_ttc_p_i : in std_logic;      -- TTC backplane clock signals
    clk_40_ttc_n_i : in std_logic;

    mmcm_rst_i    : in  std_logic;
    mmcm_locked_o : out std_logic;

    ttc_mmcm_ps_clk_i    : in std_logic;
    ttc_mmcm_ps_clk_en_i : in std_logic;

    clk_40_bufg_o  : out std_logic;
    clk_80_bufg_o  : out std_logic;
    clk_160_bufg_o : out std_logic;
    clk_120_bufg_o : out std_logic;
    clk_320_bufg_o : out std_logic

    );

end ttc_clocks;

--============================================================================
--                                                        Architecture section
--============================================================================
architecture ttc_clocks_arch of ttc_clocks is

--============================================================================
--                                                         Signal declarations
--============================================================================
  signal s_clk_40_ttc_ibufds : std_logic;

  signal s_clk_40  : std_logic;
  signal s_clk_80  : std_logic;
  signal s_clk_160 : std_logic;
  signal s_clk_120 : std_logic;
  signal s_clk_320 : std_logic;

  signal s_clkfbout      : std_logic;
  signal s_clkfbout_bufg : std_logic;

--============================================================================
--                                                          Architecture begin
--============================================================================
begin

  -- Input buffering
  --------------------------------------
  i_ibufgds_clk_40_ttc : IBUFDS
    port map
    (
      O  => s_clk_40_ttc_ibufds,
      I  => clk_40_ttc_p_i,
      IB => clk_40_ttc_n_i
      );

  -- Clocking PRIMITIVE
  --------------------------------------
  -- Instantiation of the MMCM PRIMITIVE
  --    * Unused inputs are tied off
  --    * Unused outputs are left open
  mmcm_adv_inst : MMCM_ADV
    generic map
    (BANDWIDTH            => "OPTIMIZED",
     CLKOUT4_CASCADE      => false,
     COMPENSATION         => "ZHOLD",
     STARTUP_WAIT         => false,
     DIVCLK_DIVIDE        => 1,
     CLKFBOUT_MULT_F      => 24.000,
     CLKFBOUT_PHASE       => 180.000,
     CLKFBOUT_USE_FINE_PS => true,
     CLKOUT0_DIVIDE_F     => 24.000,
     CLKOUT0_PHASE        => 0.000,
     CLKOUT0_DUTY_CYCLE   => 0.500,
     CLKOUT0_USE_FINE_PS  => false,

     CLKOUT1_DIVIDE      => 12,
     CLKOUT1_PHASE       => 0.000,
     CLKOUT1_DUTY_CYCLE  => 0.500,
     CLKOUT1_USE_FINE_PS => false,

     CLKOUT2_DIVIDE      => 6,
     CLKOUT2_PHASE       => 0.000,
     CLKOUT2_DUTY_CYCLE  => 0.500,
     CLKOUT2_USE_FINE_PS => false,

     CLKOUT3_DIVIDE      => 8,
     CLKOUT3_PHASE       => 0.000,
     CLKOUT3_DUTY_CYCLE  => 0.500,
     CLKOUT3_USE_FINE_PS => false,

     CLKOUT4_DIVIDE      => 3,
     CLKOUT4_PHASE       => 0.000,
     CLKOUT4_DUTY_CYCLE  => 0.500,
     CLKOUT4_USE_FINE_PS => false,

     CLKIN1_PERIOD => 25.0,
     REF_JITTER1   => 0.010)
    port map
    -- Output clocks
    (
      CLKFBOUT  => s_clkfbout,
      CLKFBOUTB => open,
      CLKOUT0   => s_clk_40,
      CLKOUT0B  => open,
      CLKOUT1   => s_clk_80,
      CLKOUT1B  => open,
      CLKOUT2   => s_clk_160,
      CLKOUT2B  => open,
      CLKOUT3   => s_clk_120,
      CLKOUT3B  => open,
      CLKOUT4   => s_clk_320,
      CLKOUT5   => open,
      CLKOUT6   => open,
      -- Input clock control
      CLKFBIN   => s_clkfbout_bufg,
      CLKIN1    => s_clk_40_ttc_ibufds,
      CLKIN2    => '0',
      -- Tied to always select the primary input clock
      CLKINSEL  => '1',

      -- Ports for dynamic reconfiguration
      DADDR        => (others => '0'),
      DCLK         => '0',
      DEN          => '0',
      DI           => (others => '0'),
      DO           => open,
      DRDY         => open,
      DWE          => '0',
      -- Ports for dynamic phase shift
      PSCLK        => ttc_mmcm_ps_clk_i,
      PSEN         => ttc_mmcm_ps_clk_en_i,
      PSINCDEC     => '1',
      PSDONE       => open,
      -- Other control and status signals
      LOCKED       => mmcm_locked_o,
      CLKINSTOPPED => open,
      CLKFBSTOPPED => open,
      PWRDWN       => '0',
      RST          => mmcm_rst_i
      );

  -- Output buffering
  -------------------------------------

  i_bufg_clk_fb : BUFG
    port map
    (
      O => s_clkfbout_bufg,
      I => s_clkfbout
      );

  i_bufg_clk_40 : BUFG
    port map
    (
      O => clk_40_bufg_o,
      I => s_clk_40
      );

  i_bufg_clk_80 : BUFG
    port map
    (
      O => clk_80_bufg_o,
      I => s_clk_80
      );

  i_bufg_clk_160 : BUFG
    port map
    (
      O => clk_160_bufg_o,
      I => s_clk_160
      );

  i_bufg_clk_120 : BUFG
    port map
    (
      O => clk_120_bufg_o,
      I => s_clk_120
      );

  i_bufg_clk_320 : BUFG
    port map
    (
      O => clk_320_bufg_o,
      I => s_clk_320
      );

end ttc_clocks_arch;
--============================================================================
--                                                            Architecture end
--============================================================================
