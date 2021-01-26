----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration (A. Peck)
-- Optohybrid v3 Firmware
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.hardware_pkg.all;

entity frame_aligner_tmr is
  generic (
    g_ENABLE_TMR : integer := 1
    );

  port (
    sbits_i                  : in  std_logic_vector (MXSBITS-1 downto 0);
    start_of_frame_i         : in  std_logic_vector (7 downto 0);
    reset_i                  : in  std_logic;
    clock                    : in  std_logic;
    mask_i                   : in  std_logic;
    aligned_count_to_ready_i : in  std_logic_vector (11 downto 0);
    sbits_o                  : out std_logic_vector (MXSBITS-1 downto 0);
    sot_unstable_o           : out std_logic;
    sot_is_aligned_o         : out std_logic);

end frame_aligner_tmr;

architecture Behavioral of frame_aligner_tmr is
  component frame_aligner
    generic (
      EN_BITSLIP_TMR : integer
      );
    port (

      sbits_i : in  std_logic_vector (MXSBITS-1 downto 0);
      sbits_o : out std_logic_vector (MXSBITS-1 downto 0);

      start_of_frame_i : in std_logic_vector (7 downto 0);

      reset_i : in std_logic;
      clock   : in std_logic;
      mask_i  : in std_logic;

      aligned_count_to_ready_i : in  std_logic_vector (11 downto 0);
      sot_unstable_o           : out std_logic;
      sot_is_aligned_o         : out std_logic
      );
  end component;

begin

  NO_TMR : if (g_ENABLE_TMR = 0) generate

    frame_aligner_inst : frame_aligner
      generic map (EN_BITSLIP_TMR => EN_TMR_FRAME_BITSLIP)
      port map (
        clock                    => clock,
        sbits_i                  => sbits_i,
        start_of_frame_i         => start_of_frame_i,
        reset_i                  => reset_i,
        mask_i                   => mask_i,
        aligned_count_to_ready_i => aligned_count_to_ready_i,
        sbits_o                  => sbits_o,
        sot_unstable_o           => sot_unstable_o,
        sot_is_aligned_o         => sot_is_aligned_o
        );

  end generate NO_TMR;

  TMR : if (g_ENABLE_TMR = 1) generate

    attribute DONT_TOUCH : string;

    type t_sbits_tmr is array(2 downto 0) of std_logic_vector (MXSBITS-1 downto 0);
    signal sbits_tmr          : t_sbits_tmr;
    signal sot_unstable_tmr   : std_logic_vector (2 downto 0);
    signal sot_is_aligned_tmr : std_logic_vector (2 downto 0);

    attribute DONT_TOUCH of sbits_tmr          : signal is "true";
    attribute DONT_TOUCH of sot_unstable_tmr   : signal is "true";
    attribute DONT_TOUCH of sot_is_aligned_tmr : signal is "true";
  begin

    tmr_loop : for I in 0 to 2 generate
    begin

      frame_aligner_inst : frame_aligner
        generic map (EN_BITSLIP_TMR => EN_TMR_FRAME_BITSLIP)
        port map (
          clock                    => clock,
          sbits_i                  => sbits_i,
          start_of_frame_i         => start_of_frame_i,
          reset_i                  => reset_i,
          mask_i                   => mask_i,
          aligned_count_to_ready_i => aligned_count_to_ready_i,
          sbits_o                  => sbits_tmr(I),
          sot_unstable_o           => sot_unstable_tmr(I),
          sot_is_aligned_o         => sot_is_aligned_tmr(I)
          );

    end generate;

    sbits_o          <= majority (sbits_tmr(0), sbits_tmr(1), sbits_tmr(2));
    sot_unstable_o   <= majority (sot_unstable_tmr(0), sot_unstable_tmr(1), sot_unstable_tmr(2));
    sot_is_aligned_o <= majority (sot_is_aligned_tmr(0), sot_is_aligned_tmr(1), sot_is_aligned_tmr(2));

  end generate TMR;


end Behavioral;
