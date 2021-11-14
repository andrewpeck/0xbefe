----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware
-- A. Peck
----------------------------------------------------------------------------------
-- Description:
--   This module slips bits to accomodate different tx frame alignments
--   this is the "fast" version of the module that minimizes latency by 1 clock
--   using an unregistered combinatorial path from din --> dout
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity bitslip_fast is
  generic (
    g_WORD_SIZE : integer := 8
    );
  port(
    clock       : in  std_logic;
    reset       : in  std_logic;
    bitslip_cnt : in  std_logic_vector(integer(ceil(log2(real(g_WORD_SIZE))))-1 downto 0) := (others => '0');
    din         : in  std_logic_vector(g_WORD_SIZE-1 downto 0) := (others => '0');
    dout        : out std_logic_vector(g_WORD_SIZE-1 downto 0)
    );
end bitslip_fast;

architecture rtl of bitslip_fast is

  signal dbuf : std_logic_vector (g_WORD_SIZE-1 downto 0) := (others => '0');

  signal cnt : natural range 0 to g_WORD_SIZE-1;

  function get_bitslip (data, buf : std_logic_vector; width : natural; slip : natural)
    return std_logic_vector is
    variable result : std_logic_vector(width-1 downto 0);
  begin
    result := std_logic_vector(shift_right(unsigned(data), slip)) or
              std_logic_vector(shift_left(unsigned(buf), width-slip));
    return result;
  end;

begin

  cnt <= to_integer(unsigned(bitslip_cnt));

  process(clock)
  begin
    if (rising_edge(clock)) then
      dbuf <= din;
    end if;
  end process;

  dout <= (others => '0') when reset = '1' else
          get_bitslip(din, dbuf, g_WORD_SIZE, cnt);

end rtl;
