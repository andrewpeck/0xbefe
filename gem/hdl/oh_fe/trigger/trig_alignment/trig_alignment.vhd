----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- Trigger Alignment
-- A. Peck
----------------------------------------------------------------------------------
-- Description:
--   This module takes in 192 s-bits and 24 start-of-frame signals and outputs
--   1536 aligned S-bits
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.vcomponents.all;

library work;
use work.types_pkg.all;
use work.hardware_pkg.all;

entity trig_alignment is
  generic (
    g_DDR_MODE : integer := 0
    );
  port(

    sbits_p : in std_logic_vector (NUM_VFATS*8-1 downto 0);
    sbits_n : in std_logic_vector (NUM_VFATS*8-1 downto 0);

    reset_i : in std_logic;

    sot_invert_i : in std_logic_vector (NUM_VFATS-1 downto 0);
    tu_invert_i  : in std_logic_vector (NUM_VFATS*8-1 downto 0);

    vfat_mask_i : in std_logic_vector (NUM_VFATS-1 downto 0);
    tu_mask_i   : in std_logic_vector (NUM_VFATS*8-1 downto 0);

    start_of_frame_p : in std_logic_vector (NUM_VFATS-1 downto 0);
    start_of_frame_n : in std_logic_vector (NUM_VFATS-1 downto 0);

    sot_tap_delay  : in t_std5_array (NUM_VFATS-1 downto 0);
    trig_tap_delay : in t_std5_array (NUM_VFATS*8-1 downto 0);

    sot_is_aligned      : out std_logic_vector (NUM_VFATS-1 downto 0);
    sot_unstable        : out std_logic_vector (NUM_VFATS-1 downto 0);
    sot_invalid_bitskip : out std_logic_vector (NUM_VFATS-1 downto 0);

    aligned_count_to_ready : in std_logic_vector (11 downto 0);

    clock     : in std_logic;
    clk80     : in std_logic := '0';
    clk160_0  : in std_logic := '0';
    clk160_90 : in std_logic := '0';
    clk320_0  : in std_logic := '0';
    clk320_90 : in std_logic := '0';

    sbits : out std_logic_vector (8*(g_DDR_MODE+1)*8*NUM_VFATS-1 downto 0);

    tmr_err_o : out std_logic := '0'
    );
end trig_alignment;

architecture Behavioral of trig_alignment is

  constant SBITS_PER_LINK : integer := 8*(g_DDR_MODE+1);  -- 8 in SDR, 16 in DDR
  constant SBITS_PER_BX   : integer := 8*SBITS_PER_LINK;  -- 64 in SDR, 128 in DDR

  signal reset : std_logic := '1';

  signal clk40_lac : std_logic := '0';

  signal frame_aligner_tmr_err : std_logic_vector (NUM_VFATS-1 downto 0);
  signal sot_tmr_err           : std_logic_vector (NUM_VFATS-1 downto 0);
  signal sbit_tmr_err          : std_logic_vector (NUM_VFATS*8-1 downto 0);

  type sbit_rx_array_t is array (integer range <>) of
    std_logic_vector(SBITS_PER_LINK-1 downto 0);

  signal start_of_frame_8b : sbit_rx_array_t (NUM_VFATS-1 downto 0);

  signal vfat_phase_sel : t_std2_array (NUM_VFATS-1 downto 0);
  signal vfat_e4        : t_std4_array (NUM_VFATS-1 downto 0);

  signal sbits_unaligned    : std_logic_vector (SBITS_PER_LINK * 8 * NUM_VFATS - 1 downto 0);
  signal sot_invert         : std_logic_vector (NUM_VFATS-1 downto 0);
  signal tu_invert          : std_logic_vector (NUM_VFATS*8-1 downto 0);
  signal vfat_mask          : std_logic_vector (NUM_VFATS-1 downto 0);
  signal tu_mask            : std_logic_vector (NUM_VFATS*8-1 downto 0);
  signal sot_is_aligned_int : std_logic_vector (NUM_VFATS-1 downto 0);

  -- fanout reset to help with timing
  signal sot_reset : std_logic_vector (NUM_VFATS-1 downto 0);
  signal tu_reset  : std_logic_vector (NUM_VFATS*8-1 downto 0);

  attribute MAX_FANOUT              : string;
  attribute MAX_FANOUT of clk40_lac : signal is "128";

  attribute EQUIVALENT_REGISTER_REMOVAL              : string;
  attribute EQUIVALENT_REGISTER_REMOVAL of sot_reset : signal is "NO";
  attribute EQUIVALENT_REGISTER_REMOVAL of tu_reset  : signal is "NO";

begin

  --------------------------------------------------------------------------------------------------------------------
  -- Reset
  --------------------------------------------------------------------------------------------------------------------

  process (clock) is
  begin
    if (rising_edge(clock)) then

      reset <= reset_i;

      sot_invert <= sot_invert_i;
      tu_invert  <= tu_invert_i;
      vfat_mask  <= vfat_mask_i;
      tu_mask    <= tu_mask_i;

      tmr_err_o <= or_reduce (frame_aligner_tmr_err) or or_reduce(sot_tmr_err) or or_reduce(sbit_tmr_err);

    end if;
  end process;

  --------------------------------------------------------------------------------------------------------------------
  -- SOT Oversampler
  --------------------------------------------------------------------------------------------------------------------

  sot_loop : for I in 0 to NUM_VFATS-1 generate
  begin

    process (clock) is
    begin
      if (rising_edge(clock)) then
        sot_reset(I) <= reset or reset_i or (vfat_mask(I));  -- make sure it is 2 clocks wide
      end if;
    end process;

    sot_oversample : entity work.oversample
      generic map (
        g_PHASE_SEL_EXTERNAL => false,
        g_ENABLE_TMR_DRU     => EN_TMR_SOT_DRU,
        g_DDR_MODE           => g_DDR_MODE
        )
      port map (
        -- clocks
        clk40     => clock,
        clk40_lac => clk40_lac,
        clk80     => clk80,
        clk160_0  => clk160_0,
        clk160_90 => clk160_90,
        clk320_0  => clk320_0,
        clk320_90 => clk320_90,

        -- reset
        reset_i => sot_reset(I),

        -- from vfat
        rxd_p => start_of_frame_p(I),
        rxd_n => start_of_frame_n(I),

        -- data out
        rxdata_o => start_of_frame_8b(I),

        -- control
        invert        => sot_invert (I),
        tap_delay_i   => sot_tap_delay(I),
        e4_in         => (others => '0'),
        e4_out        => vfat_e4(I),
        phase_sel_in  => (others => '0'),
        phase_sel_out => vfat_phase_sel(I),

        -- status
        invalid_bitskip_o => sot_invalid_bitskip(I),
        tmr_err_o         => sot_tmr_err(I)
        );

  end generate;

  --------------------------------------------------------------------------------------------------------------------
  -- S-bit Oversamplers
  --------------------------------------------------------------------------------------------------------------------

  trig_loop : for I in 0 to (NUM_VFATS*8-1) generate
  begin

    process (clock) is
    begin
      if (rising_edge(clock)) then
        -- make sure it is at least 2 clocks wide
        tu_reset(I) <= reset or reset_i or tu_mask(I) or (not sot_is_aligned_int (I/8)) or vfat_mask(I/8);
      end if;
    end process;

    sbit_oversample : entity work.oversample
      generic map (
        g_PHASE_SEL_EXTERNAL => true,
        g_ENABLE_TMR_DRU     => EN_TMR_SBIT_DRU,
        g_DDR_MODE           => g_DDR_MODE
        )
      port map (
        -- clocks
        clk40     => clock,
        clk40_lac => clk40_lac,
        clk80     => clk80,
        clk160_0  => clk160_0,
        clk160_90 => clk160_90,
        clk320_0  => clk320_0,
        clk320_90 => clk320_90,

        -- reset
        reset_i => tu_reset(I),

        -- data in
        rxd_p    => sbits_p(I),
        rxd_n    => sbits_n(I),
        rxdata_o => sbits_unaligned ((I+1)*SBITS_PER_LINK - 1 downto I*SBITS_PER_LINK),

        -- control
        invert        => tu_invert (I),
        tap_delay_i   => trig_tap_delay(I),
        e4_in         => vfat_e4(I/8),
        e4_out        => open,
        phase_sel_in  => vfat_phase_sel(I/8),
        phase_sel_out => open,

        -- status
        invalid_bitskip_o => open,
        tmr_err_o         => sbit_tmr_err(I)
        );

  end generate;

  --------------------------------------------------------------------------------------------------------------------
  -- Frame alignment
  --------------------------------------------------------------------------------------------------------------------

  aligner_loop : for I in 0 to NUM_VFATS-1 generate
  begin

    frame_aligner_inst : entity work.frame_aligner_tmr
      generic map (
        g_ENABLE_TMR => EN_TMR_FRAME_ALIGNER,
        g_WIDTH_I    => SBITS_PER_LINK,
        g_WIDTH_O    => SBITS_PER_BX
        )
      port map (
        clock   => clock,
        reset_i => reset_i,

        sbits_i                  => sbits_unaligned ((I+1)*SBITS_PER_BX - 1 downto I*SBITS_PER_BX),
        mask_i                   => vfat_mask(I),
        start_of_frame_i         => start_of_frame_8b(I),
        aligned_count_to_ready_i => aligned_count_to_ready,

        sbits_o          => sbits((I+1)*SBITS_PER_BX - 1 downto I*SBITS_PER_BX),
        sot_is_aligned_o => sot_is_aligned_int(I),
        sot_unstable_o   => sot_unstable(I),
        tmr_err_o        => frame_aligner_tmr_err(I)
        );

  end generate;

  sot_is_aligned <= sot_is_aligned_int;

  --------------------------------------------------------------------------------
  -- Logic Accessible Clock
  --------------------------------------------------------------------------------

  clock_strobe_inst : entity work.clock_strobe
    generic map (
      RATIO => 2
      )
    port map (
      fast_clk_i => clk80,
      slow_clk_i => clock,
      strobe_o   => clk40_lac
      );

end Behavioral;
