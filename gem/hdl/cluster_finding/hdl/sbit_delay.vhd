library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.cluster_pkg.all;
use work.hardware_pkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity sbit_delay is
  generic (
    NUM_VFATS : integer := 0
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
    signal dly      : std_logic_vector (SBIT_BX_DELAY_NBITS-1 downto 0);
  begin

    sbit_i <= sbits_i(I / MXSBITS)(I mod MXSBITS);

    dly    <= sbit_bx_dlys_i(I / SBIT_BX_DELAY_GRP_SIZE);

    SRL16E_inst : SRL16E
      generic map (
        INIT            => X"0000",     -- Initial contents of shift register
        IS_CLK_INVERTED => '0'          -- Optional inversion for CLK
        )
      port map (
        Q   => sbit_dly,                -- 1-bit output: SRL Data
        CE  => '1',                     -- 1-bit input: Clock enable
        CLK => clock,                   -- 1-bit input: Clock
        D   => sbit_i,                  -- 1-bit input: SRL Data

        -- Depth Selection inputs: A0-A3 select SRL depth
        A0 => dly(0),
        A1 => dly(1),
        A2 => dly(2),
        A3 => '0'
        );

    sbits_o(I / MXSBITS)(I mod MXSBITS) <= sbit_i when dly_enable(I / SBIT_BX_DELAY_GRP_SIZE)='0' else sbit_dly;

  end generate;

end behavioral;
