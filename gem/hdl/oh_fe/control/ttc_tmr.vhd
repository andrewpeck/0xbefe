library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.ipbus_pkg.all;

entity ttc_tmr is
  generic (
    MXBXN : integer := 12
    );
  port (
    clock             : in  std_logic;
    reset             : in  std_logic;
    ttc_bx0           : in  std_logic;
    ttc_resync        : in  std_logic;
    bxn_offset_i      : in  std_logic_vector (MXBXN-1 downto 0);
    bxn_read_offset_o : out std_logic_vector (MXBXN-1 downto 0) := (others => '0');
    bx0_local_o       : out std_logic                           := '0';
    bxn_counter_o     : out std_logic_vector (MXBXN-1 downto 0) := (others => '0');
    bx0_sync_err_o    : out std_logic                           := '0';
    bxn_sync_err_o    : out std_logic                           := '0';
    tmr_err_inj_i     : in  std_logic                           := '0';
    tmr_err_o         : out std_logic                           := '0'
    );
end entity ttc_tmr;

architecture behavioral of ttc_tmr is

  signal bxn_read_offset_tmr : t_std12_array (2 downto 0);
  signal bxn_counter_tmr     : t_std12_array (2 downto 0);
  signal bx0_local_tmr       : std_logic_vector (2 downto 0);
  signal bx0_sync_err_tmr    : std_logic_vector (2 downto 0);
  signal bxn_sync_err_tmr    : std_logic_vector (2 downto 0);

  attribute DONT_TOUCH : string;

  attribute DONT_TOUCH of bx0_local_tmr    : signal is "true";
  attribute DONT_TOUCH of bxn_counter_tmr  : signal is "true";
  attribute DONT_TOUCH of bx0_sync_err_tmr : signal is "true";
  attribute DONT_TOUCH of bxn_sync_err_tmr : signal is "true";

  signal tmr_err : std_logic_vector (4 downto 0) := (others => '0');

begin

  tmr_loop : for I in 0 to 2 generate
    signal tmr_err_inj : std_logic := '0';
  begin

    -- inject an error into one of the copies
    errgen : if (I = 1) generate
      tmr_err_inj <= tmr_err_inj_i;
    end generate;

    ttc_inst : entity work.ttc
      port map (

        -- clock & reset
        clock => clock,
        reset => reset,

        -- ttc commands
        ttc_bx0    => ttc_bx0 xor tmr_err_inj,
        ttc_resync => ttc_resync xor tmr_err_inj,

        -- control
        bxn_offset_i => bxn_offset_i,

        -- output
        bxn_read_offset_o => bxn_read_offset_tmr(I),
        bx0_local_o       => bx0_local_tmr (I),
        bxn_counter_o     => bxn_counter_tmr(I),
        bx0_sync_err_o    => bx0_sync_err_tmr(I),
        bxn_sync_err_o    => bxn_sync_err_tmr(I)
        );

  end generate;

  majority_err (bx0_local_o, tmr_err(0), bx0_local_tmr (0), bx0_local_tmr (1), bx0_local_tmr (2));
  majority_err (bxn_counter_o, tmr_err(1), bxn_counter_tmr (0), bxn_counter_tmr (1), bxn_counter_tmr (2));
  majority_err (bx0_sync_err_o, tmr_err(2), bx0_sync_err_tmr(0), bx0_sync_err_tmr(1), bx0_sync_err_tmr(2));
  majority_err (bxn_sync_err_o, tmr_err(3), bxn_sync_err_tmr(0), bxn_sync_err_tmr(1), bxn_sync_err_tmr(2));
  majority_err (bxn_read_offset_o, tmr_err(4), bxn_read_offset_tmr(0), bxn_read_offset_tmr(1), bxn_read_offset_tmr(2));

  process (clock) is
  begin
    if (rising_edge(clock)) then
      tmr_err_o <= or_reduce(tmr_err);
    end if;
  end process;

end behavioral;
