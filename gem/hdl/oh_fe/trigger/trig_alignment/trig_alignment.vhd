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
    clk160_0  : in std_logic;
    clk160_90 : in std_logic;

    sbits : out std_logic_vector ((MXSBITS_CHAMBER - 1) downto 0);

    tmr_err_o : out std_logic := '0'
    );
end trig_alignment;

architecture Behavioral of trig_alignment is

  signal frame_aligner_tmr_err : std_logic_vector (NUM_VFATS-1 downto 0);
  signal sot_tmr_err           : std_logic_vector (NUM_VFATS-1 downto 0);
  signal sbit_tmr_err          : std_logic_vector (NUM_VFATS*8-1 downto 0);

  signal start_of_frame_8b  : t_std8_array (NUM_VFATS-1 downto 0);
  signal vfat_phase_sel     : t_std2_array (NUM_VFATS-1 downto 0);
  signal vfat_e4            : t_std4_array (NUM_VFATS-1 downto 0);
  signal sbits_unaligned    : std_logic_vector ((MXSBITS_CHAMBER - 1) downto 0);
  signal sot_invert         : std_logic_vector (NUM_VFATS-1 downto 0);
  signal tu_invert          : std_logic_vector (NUM_VFATS*8-1 downto 0);
  signal vfat_mask          : std_logic_vector (NUM_VFATS-1 downto 0);
  signal tu_mask            : std_logic_vector (NUM_VFATS*8-1 downto 0);
  signal sot_is_aligned_int : std_logic_vector (NUM_VFATS-1 downto 0);

  -- fanout reset to help with timing
  signal sot_reset : std_logic_vector (NUM_VFATS-1 downto 0);
  signal tu_reset  : std_logic_vector (NUM_VFATS*8-1 downto 0);

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
        sot_reset(I) <= reset_i or (vfat_mask(I));
      end if;
    end process;

    sot_oversample : entity work.oversample
      generic map (
        g_PHASE_SEL_EXTERNAL => false,
        g_ENABLE_TMR_DRU     => EN_TMR_SOT_DRU
        )
      port map (
        clk1x_logic       => clock,
        clk1x             => clock,
        clk4x_0           => clk160_0,
        clk4x_90          => clk160_90,
        reset_i           => sot_reset(I),
        rxd_p             => start_of_frame_p(I),
        rxd_n             => start_of_frame_n(I),
        rxdata_o          => start_of_frame_8b(I),
        invert            => sot_invert (I),
        tap_delay_i       => sot_tap_delay(I),
        e4_in             => (others => '0'),
        e4_out            => vfat_e4(I),
        phase_sel_in      => (others => '0'),
        phase_sel_out     => vfat_phase_sel(I),
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
        tu_reset(I) <= reset_i or tu_mask(I) or (not sot_is_aligned_int (I/8)) or vfat_mask(I/8);
      end if;
    end process;

    sbit_oversample : entity work.oversample
      generic map (
        g_PHASE_SEL_EXTERNAL => true,
        g_ENABLE_TMR_DRU     => EN_TMR_SBIT_DRU
        )
      port map (
        clk1x_logic       => clock,
        clk1x             => clock,
        clk4x_0           => clk160_0,
        clk4x_90          => clk160_90,
        reset_i           => tu_reset(I),
        rxd_p             => sbits_p(I),
        rxd_n             => sbits_n(I),
        rxdata_o          => sbits_unaligned ((I+1)*8 - 1 downto I*8),
        invert            => tu_invert (I),
        tap_delay_i       => trig_tap_delay(I),
        e4_in             => vfat_e4(I/8),
        e4_out            => open,
        phase_sel_in      => vfat_phase_sel(I/8),
        phase_sel_out     => open,
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
        g_ENABLE_TMR => EN_TMR_FRAME_ALIGNER)
      port map (
        clock   => clock,
        reset_i => reset_i,

        sbits_i                  => sbits_unaligned ((I+1)*MXSBITS - 1 downto I*MXSBITS),
        mask_i                   => vfat_mask(I),
        start_of_frame_i         => start_of_frame_8b(I),
        aligned_count_to_ready_i => aligned_count_to_ready,

        sbits_o          => sbits((I+1)*MXSBITS - 1 downto I*MXSBITS),
        sot_is_aligned_o => sot_is_aligned_int(I),
        sot_unstable_o   => sot_unstable(I),
        tmr_err_o        => frame_aligner_tmr_err(I)
        );

  end generate;

  sot_is_aligned <= sot_is_aligned_int;

end Behavioral;
