library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.ipbus_pkg.all;

entity ttc_tmr is
  port (
    clock        : in  std_logic;
    reset        : in  std_logic;
    ttc_bx0      : in  std_logic;
    ttc_resync   : in  std_logic;
    bxn_offset   : in  std_logic_vector (11 downto 0);
    bx0_local    : out std_logic;
    bxn_counter  : out std_logic_vector (11 downto 0);
    bx0_sync_err : out std_logic;
    bxn_sync_err : out std_logic;
    tmr_err_o    : out std_logic := '0'
    );
end entity ttc_tmr;

architecture behavioral of ttc_tmr is
  component ttc
    port (
      clock : in std_logic;
      reset : in std_logic;

      ttc_bx0    : in std_logic;
      ttc_resync : in std_logic;
      bxn_offset : in std_logic_vector (11 downto 0);

      bx0_local    : out std_logic;
      bxn_counter  : out std_logic_vector (11 downto 0);
      bx0_sync_err : out std_logic;
      bxn_sync_err : out std_logic
      );
  end component;

  signal bxn_counter_tmr  : t_std12_array (2 downto 0);
  signal bx0_local_tmr    : std_logic_vector (2 downto 0);
  signal bx0_sync_err_tmr : std_logic_vector (2 downto 0);
  signal bxn_sync_err_tmr : std_logic_vector (2 downto 0);

  attribute DONT_TOUCH : string;

  attribute DONT_TOUCH of bx0_local_tmr    : signal is "true";
  attribute DONT_TOUCH of bxn_counter_tmr  : signal is "true";
  attribute DONT_TOUCH of bx0_sync_err_tmr : signal is "true";
  attribute DONT_TOUCH of bxn_sync_err_tmr : signal is "true";

  signal tmr_err : std_logic_vector (3 downto 0) := (others => '0');


begin

  tmr_loop : for I in 0 to 2 generate
  begin
    ttc_inst : ttc
      port map (

        -- clock & reset
        clock => clock,
        reset => reset,

        -- ttc commands
        ttc_bx0    => ttc_bx0,
        ttc_resync => ttc_resync,

        -- control
        bxn_offset => bxn_offset,

        -- output
        bx0_local    => bx0_local_tmr (I),
        bxn_counter  => bxn_counter_tmr(I),
        bx0_sync_err => bx0_sync_err_tmr(I),
        bxn_sync_err => bxn_sync_err_tmr(I)
        );

  end generate;

  majority_err (bx0_local,    tmr_err(0), bx0_local_tmr (0), bx0_local_tmr (1), bx0_local_tmr (2));
  majority_err (bxn_counter,  tmr_err(1), bxn_counter_tmr (0), bxn_counter_tmr (1), bxn_counter_tmr (2));
  majority_err (bx0_sync_err, tmr_err(2), bx0_sync_err_tmr(0), bx0_sync_err_tmr(1), bx0_sync_err_tmr(2));
  majority_err (bxn_sync_err, tmr_err(3), bxn_sync_err_tmr(0), bxn_sync_err_tmr(1), bxn_sync_err_tmr(2));

  process (clock) is
  begin
    if (rising_edge(clock)) then
      tmr_err_o <= or_reduce(tmr_err);
    end if;
  end process;

end behavioral;
