library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.cluster_pkg.all;
use work.hardware_pkg.all;

entity sbit_delay is
  generic (
    NUM_VFATS : integer := 0;
    DEPTH     : integer := 4*(2**SBIT_BX_DELAY_NBITS)
    );
  port(
    clock          : in  std_logic;
    sbits_i        : in  sbits_array_t (NUM_VFATS-1 downto 0);
    sbits_o        : out sbits_array_t (NUM_VFATS-1 downto 0);
    dly_enable     : in  std_logic_vector (NUM_VFATS*MXSBITS/SBIT_BX_DELAY_GRP_SIZE-1 downto 0);
    sbit_bx_dlys_i : in  sbit_bx_dly_array_t (NUM_VFATS*MXSBITS/SBIT_BX_DELAY_GRP_SIZE-1 downto 0)
    );
end sbit_delay;

architecture behavioral of sbit_delay is
begin

  dly_gen : for I in 0 to NUM_VFATS*MXSBITS-1 generate
    signal sbit_dly : std_logic;
    signal sbit_i   : std_logic := '0';
    signal dly_line : std_logic_vector(DEPTH-1 downto 0) := (others => '0');
    signal dly      : integer range 0 to DEPTH-1;
  begin

    sbit_i <= sbits_i(I / MXSBITS)(I mod MXSBITS);

    dly <= 3 + 4*to_integer(unsigned(sbit_bx_dlys_i(I / SBIT_BX_DELAY_GRP_SIZE)));

    process (clock) is
    begin
      if (rising_edge(clock)) then
        dly_line(0) <= sbit_i;
        for J in 1 to dly_line'length-1 loop
          dly_line(J) <= dly_line(J-1);
        end loop;
      end if;
    end process;

    sbit_dly <= dly_line(dly);

    sbits_o(I / MXSBITS)(I mod MXSBITS) <= sbit_i when dly_enable(I / SBIT_BX_DELAY_GRP_SIZE)='0' else sbit_dly;

  end generate;

end behavioral;
