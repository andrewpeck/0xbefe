----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- Clocking
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library xil_defaultlib;

library work;
use work.types_pkg.all;
use work.hardware_pkg.all;
use work.ipbus_pkg.all;
use work.registers.all;

entity clocking is
  port(

    clock_p : in std_logic;
    clock_n : in std_logic;

    clocks_o : out clocks_t;

    -- mmcm locked status monitors
    mmcm_locked_o : out std_logic

    );
end clocking;

architecture Behavioral of clocking is

  component clocks
    port (
      reset       : in  std_logic;
      clk_in1     : in  std_logic;
      clk40_o     : out std_logic;
      clk80_o     : out std_logic;
      clk160_o    : out std_logic;
      clk160_90_o : out std_logic;
      clk200_o    : out std_logic;
      locked_o    : out std_logic
      );
  end component;

  signal sysclk      : std_logic;
  signal mmcm_locked : std_logic;
  signal clock_i     : std_logic;

begin

  -- Input buffering
  --------------------------------------
  clkin1_buf : IBUFGDS
    port map (
      O  => clock_i,
      I  => clock_p,
      IB => clock_n
      );

  sysclk_bufg : BUFG
    port map (
      I => clock_i,
      O => sysclk
      );

  clocks_inst : clocks
    port map(

      reset => '0',

      clk_in1 => clock_i,

      clk40_o     => clocks_o.clk40,
      clk160_o    => clocks_o.clk160_0,
      clk160_90_o => clocks_o.clk160_90,
      clk200_o    => clocks_o.clk200,
      clk80_o     => clocks_o.clk80,

      locked_o => mmcm_locked
      );

  clocks_o.sysclk <= sysclk;
  clocks_o.locked <= mmcm_locked;

  mmcm_locked_o <= mmcm_locked;

end Behavioral;
