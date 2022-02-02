----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- GBT SerDes
-- T. Lenzi, E. Juska, A. Peck
----------------------------------------------------------------------------------
-- Description:
--   This module serializes and deserializes e-link data to and from the GBTx
----------------------------------------------------------------------------------
-- 2017/07/24 -- Conversion to 16 bit (2 elinks only)
-- 2017/07/24 -- Addition of flip-flop synchronization stages for X-domain transit
-- 2017/08/09 -- rework of module to cleanup and document source
-- 2017/08/26 -- Addition of actual CDC fifo
-- 2018/04/19 -- Addition of Artix-7 Support
-- 2018/09/27 -- Conversion to single elink communication
-- 2019/05/09 -- Conversion to unified clocking structure (removal of CDC)
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.hardware_pkg.all;

entity gbt_serdes is
  generic(
    BITSLIP_ERR_CNT_MAX : integer := 16;
    MXBITS              : integer := 8
    );
  port(

    rst_i : in std_logic;

    -- input clocks

    clk_1x    : in std_logic;           -- 40 MHz phase shiftable frame clock from GBT
    clk_4x    : in std_logic;           -- 160 MHz phase shiftable frame clock from GBT
    clk_4x_90 : in std_logic;           -- 160 MHz phase shiftable frame clock from GBT

    -- serial data to/from GBTx
    elink_o_p : out std_logic;
    elink_o_n : out std_logic;

    elink_i_p : in std_logic;
    elink_i_n : in std_logic;

    gbt_link_err_i : in std_logic;      -- err on gbt rx
    gbt_link_rdy_i : in std_logic;

    -- parallel data to/from FPGA logic
    data_i : in  std_logic_vector (MXBITS-1 downto 0);
    data_o : out std_logic_vector (MXBITS-1 downto 0);

    sump : out std_logic;

    tmr_err_o : out std_logic := '0'
    );
end gbt_serdes;

architecture Behavioral of gbt_serdes is

  signal oversample_tmr_err : std_logic;

  signal from_gbt_raw : std_logic_vector(MXBITS-1 downto 0) := (others => '0');

  signal to_gbt : std_logic_vector(MXBITS-1 downto 0) := (others => '0');

  signal to_gbt_inv : std_logic_vector(MXBITS-1 downto 0) := (others => '0');

  signal gbt_link_rdy : std_logic := '0';
  signal gbt_link_err : std_logic := '0';

  signal bitslip_err_cnt : integer range 0 to BITSLIP_ERR_CNT_MAX-1 := 0;

  signal rx_bitslip_cnt        : integer range 0 to MXBITS-1  := 0;
  signal rx_bitslip_cnt_stdlog : std_logic_vector(2 downto 0) := (others => '0');

  signal bitslip_increment : std_logic := '0';

  signal rst : std_logic := '0';

  signal rst_serdes : std_logic := '1';

  attribute MAX_FANOUT        : string;
  attribute MAX_FANOUT of rst : signal is "10";

  signal sump_vector : std_logic_vector (5 downto 0);

begin

  sump <= or_reduce (sump_vector);

  --------------------------------------------------------------------------------------------------------------------
  -- Reset
  --------------------------------------------------------------------------------------------------------------------
  -- power-on reset - this must be a clock synchronous pulse of a minimum of 2 and max 32 clock cycles (ISERDES spec)
  --  1)  Wait until all MMCM/PLL used in the design are locked.
  --  2)  Reset should only be deasserted when it is known that CLK and CLKDIV are stable and present.
  --  3)  Wait until all IDELAYCTRL components, when used, show RDY high.
  --  4)  Use on the reset net one flip-flop clocked by CLKDIV per ISERDESE1/OSERDESE1 pair.
  --      Put the flip-flop in the FPGA logic in front of the ISERDESE1/OSERDESE1 pair
  --      Put a timing constraint on the flip-flop to ISERDESE1/OSERDESE1 of one CLKDIV period or less.

  process (clk_1x)
  begin
    if (rising_edge(clk_1x)) then
      rst        <= rst_i;
      tmr_err_o  <= oversample_tmr_err;
      rst_serdes <= rst or rst_i;
    end if;
  end process;

  --------------------------------------------------------------------------------------------------------------------
  -- synchronize resets from logic clock to gbt clock domains
  --------------------------------------------------------------------------------------------------------------------

  gbt_link_err <= gbt_link_err_i;
  gbt_link_rdy <= gbt_link_rdy_i;

  --================--
  --== INPUT DATA ==--
  --================--

  gbt_oversample : entity work.oversample
    generic map (
      g_ENABLE_TMR_DRU     => EN_TMR_GBT_DRU,
      g_PHASE_SEL_EXTERNAL => false,
      g_DDR_MODE           => 0
      )
    port map (
      clk40             => clk_1x,
      clk160_0          => clk_1x,
      clk160_90         => clk_4x_90,
      reset_i           => rst_serdes,
      rxd_p             => elink_i_p,
      rxd_n             => elink_i_n,
      rxdata_o          => from_gbt_raw,
      invert            => '0',
      tap_delay_i       => (others => '0'),
      e4_in             => (others => '0'),
      e4_out            => sump_vector (3 downto 0),
      phase_sel_in      => (others => '0'),
      phase_sel_out     => sump_vector (5 downto 4),
      invalid_bitskip_o => open,
      tmr_err_o         => oversample_tmr_err
      );

  --------------------------------------------------------------------------------------------------------------------
  -- Bitslip
  --------------------------------------------------------------------------------------------------------------------

  -- TODO: add TMR

  process (clk_1x)
  begin
    if (rising_edge(clk_1x)) then

      if (gbt_link_rdy = '1') then
        bitslip_err_cnt <= 0;
      elsif (bitslip_err_cnt = BITSLIP_ERR_CNT_MAX-1) then
        bitslip_err_cnt <= 0;
      elsif (gbt_link_err = '1') then
        bitslip_err_cnt <= bitslip_err_cnt + 1;
      end if;
    end if;
  end process;

  bitslip_increment <= '1' when bitslip_err_cnt = BITSLIP_ERR_CNT_MAX-1 else '0';

  process (clk_1x)
  begin
    if (rising_edge(clk_1x)) then
      if (bitslip_increment = '1') then
        if (rx_bitslip_cnt = 7) then
          rx_bitslip_cnt <= 0;
        else
          rx_bitslip_cnt <= rx_bitslip_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  -- typecasting
  rx_bitslip_cnt_stdlog <= std_logic_vector(to_unsigned(rx_bitslip_cnt, rx_bitslip_cnt_stdlog'length));

  i_gbt_rx_bitslip : entity work.bitslip
    generic map(
      g_WORD_SIZE => MXBITS,
      g_EN_TMR    => 1

      )
    port map(
      fabric_clk  => clk_1x,
      reset       => rst,
      bitslip_cnt => rx_bitslip_cnt_stdlog,
      din         => from_gbt_raw,
      dout        => data_o
      );

  --------------------------------------------------------------------------------------------------------------------
  -- Output Data
  --------------------------------------------------------------------------------------------------------------------

  process(clk_1x)
  begin
    if (rising_edge(clk_1x)) then
      to_gbt <= data_i(0) & data_i(1) & data_i(2) & data_i(3) & data_i(4) & data_i(5) & data_i(6) & data_i(7);
    end if;
  end process;

  -- To ensure that data flows out of all OSERDESE1 blocks in a multiple bit output structure:
  --  1) Place a register in front of the OSERDESE1 inputs.
  --  2) Clock the register by the CLKDIV clock of the OSERDESE1.
  --  3) Use the same reset signal for the register as for the OSERDESE1.

  -- Output serializer
  -- we want to output the data on the falling edge of the clock so that the GBT can sample on the rising edge

  --------------------------------------------------------------------------------------------------------------------
  to_gbt_inv_v6 : if (FPGA_TYPE = "V6") generate
    to_gbt_inv <= "not"(to_gbt);
  end generate to_gbt_inv_v6;
  --------------------------------------------------------------------------------------------------------------------
  --------------------------------------------------------------------------------------------------------------------
  to_gbt_inv_a7 : if (FPGA_TYPE = "A7") generate
    to_gbt_inv <= to_gbt;
  end generate to_gbt_inv_a7;
  --------------------------------------------------------------------------------------------------------------------

  to_gbt_ser_inst : entity work.to_gbt_ser
    port map(
      data_out_from_device  => to_gbt_inv,
      data_out_to_pins_p(0) => elink_o_p,
      data_out_to_pins_n(0) => elink_o_n,
      clk_in                => clk_4x,
      clk_div_in            => clk_1x,
      io_reset              => rst
      );

end Behavioral;
