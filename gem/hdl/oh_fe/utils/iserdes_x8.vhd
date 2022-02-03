----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid Firmware -- iserdes_x8
-- A. Peck
----------------------------------------------------------------------------------
--
-- Description:
--
--  This is a wrapper around Artix-7 and Virtex-6 primitives for performing 1:8
--  deserialization of S-bits
--
--  It assumes that the input clocks are on global clock buffers,  and that the
--  input data is connected to IDELAY elements
--
--  If IDELAY elements are to be removed, the data_i input should be connected to
--  d instead of ddly
--
-- Reset:
--
--     When asserted, the reset input causes the outputs of all data flip-flops
--     in the CLK and CLKDIV domains to be driven low asynchronously. When
--     deasserted synchronously with CLKDIV, internal logic re-times this
--     deassertion to the first rising edge of CLK. Every OSERDESE2 in a
--     multiple bit output structure should therefore be driven by the same
--     reset signal, asserted asynchronously, and deasserted synchronously to
--     CLKDIV to ensure that all OSERDESE2 elements come out of reset in
--     synchronization. The reset signal should only be deasserted when it is
--     known that CLK and CLKDIV are stable and present.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity iserdes_x8 is
  generic (
    g_FPGA_TYPE : string := "A7"
    );
  port(
    clk_i     : in  std_logic;
    clk_div_i : in  std_logic;
    bitslip_i : in  std_logic;
    io_reset  : in  std_logic;
    data_i    : in  std_logic;
    data_o    : out std_logic_vector (7 downto 0)
    );
end iserdes_x8;

architecture behavioral of iserdes_x8 is

  constant NUM_SERIAL_BITS : integer := 8;

  signal iserdes_q : std_logic_vector (7 downto 0);  -- fills in starting with 0

begin

  slice_map : for I in 0 to NUM_SERIAL_BITS-1 generate
  begin
    -- This places the first data in time on the right
    data_o(I) <= iserdes_q(NUM_SERIAL_BITS-I-1);
  -- To place the first data in time on the left, use the
  --   following code, instead
  -- data_o(I) <= iserdes_q(I);
  end generate;

  ----------------------------------------------------------------------------------------------------------------------
  -- iserdes_x8
  ----------------------------------------------------------------------------------------------------------------------

  iserdes_x8_v6 : if (g_FPGA_TYPE = "V6") generate
    signal icascade1 : std_logic;
    signal icascade2 : std_logic;
  begin

    -- declare the iserdes
    iserdese1_master : iserdese1
      generic map (
        data_rate         => "ddr",
        data_width        => 8,
        interface_type    => "networking",
        dyn_clkdiv_inv_en => false,
        dyn_clk_inv_en    => false,
        num_ce            => 2,

        ofb_used    => false,
        iobdelay    => "none",          -- use input at d to output the data on q1-q6
        serdes_mode => "master")
      port map (
        q1           => iserdes_q(0),
        q2           => iserdes_q(1),
        q3           => iserdes_q(2),
        q4           => iserdes_q(3),
        q5           => iserdes_q(4),
        q6           => iserdes_q(5),
        shiftout1    => icascade1,      -- cascade connection to slave iserdes
        shiftout2    => icascade2,      -- cascade connection to slave iserdes
        bitslip      => bitslip_i,      -- 1-bit invoke bitslip. this can be used with any
        -- data_width, cascaded or not.
        ce1          => '1',            -- 1-bit clock enable input
        ce2          => '1',            -- 1-bit clock enable input
        clk          => clk_i,          -- fast clock driven by mmcm
        clkb         => not clk_i,      -- locally inverted clock
        clkdiv       => clk_div_i,      -- slow clock driven by mmcm
        d            => '0',            -- 1-bit input signal from iob.
        ddly         => data_i,
        rst          => io_reset,       -- 1-bit asynchronous reset only.
        shiftin1     => '0',
        shiftin2     => '0',
        -- unused connections
        dynclkdivsel => '0',
        dynclksel    => '0',
        ofb          => '0',
        oclk         => '0',
        o            => open);          -- unregistered output of iserdese1

    iserdese1_slave : iserdese1
      generic map (
        data_rate         => "ddr",
        data_width        => 8,
        interface_type    => "networking",
        dyn_clkdiv_inv_en => false,
        dyn_clk_inv_en    => false,
        num_ce            => 2,

        ofb_used    => false,
        iobdelay    => "none",          -- use input at d to output the data on q1-q6
        serdes_mode => "slave")
      port map (
        q1           => open,
        q2           => open,
        q3           => iserdes_q(6),
        q4           => iserdes_q(7),
        q5           => open,           -- used for 1:10
        q6           => open,           -- used for 1:10
        shiftout1    => open,
        shiftout2    => open,
        shiftin1     => icascade1,      -- cascade connections from master iserdes
        shiftin2     => icascade2,      -- cascade connections from master iserdes
        bitslip      => bitslip_i,      -- 1-bit invoke bitslip. this can be used with any
        -- data_width, cascaded or not.
        ce1          => '1',            -- 1-bit clock enable input
        ce2          => '1',            -- 1-bit clock enable input
        clk          => clk_i,          -- fast clock driven by mmcm
        clkb         => not clk_i,      -- locally inverted clock
        clkdiv       => clk_div_i,      -- slow clock driven by mmcm
        d            => '0',            -- slave iserdes module. no need to connect d, ddly
        ddly         => '0',
        rst          => io_reset,       -- 1-bit asynchronous reset only.
        -- unused connections
        dynclkdivsel => '0',
        dynclksel    => '0',
        ofb          => '0',
        oclk         => '0',
        o            => open);          -- unregistered output of iserdese1

  end generate iserdes_x8_v6;


  iserdes_x8_a7 : if (g_FPGA_TYPE = "A7") generate

    -- declare the iserdes
    iserdese2_inst : ISERDESE2
      generic map(
        DATA_RATE         => "DDR",
        DATA_WIDTH        => 8,
        INTERFACE_TYPE    => "NETWORKING",
        DYN_CLKDIV_INV_EN => "FALSE",
        DYN_CLK_INV_EN    => "FALSE",
        NUM_CE            => 2,
        OFB_USED          => "FALSE",
        IOBDELAY          => "NONE",    -- Use input at D to output the data on Q
        SERDES_MODE       => "MASTER"
        )
      port map (

        Q1           => iserdes_q(0),
        Q2           => iserdes_q(1),
        Q3           => iserdes_q(2),
        Q4           => iserdes_q(3),
        Q5           => iserdes_q(4),
        Q6           => iserdes_q(5),
        Q7           => iserdes_q(6),
        Q8           => iserdes_q(7),
        SHIFTOUT1    => open,
        SHIFTOUT2    => open,
        BITSLIP      => bitslip_i,      -- 1-bit Invoke Bitslip. This can be used with any DATA_WIDTH, cascaded or not.
        CE1          => '1',            -- 1-bit Clock enable input
        CE2          => '1',            -- 1-bit Clock enable input
        CLK          => clk_i,          -- Fast clock driven by MMCM
        CLKB         => not clk_i,      -- Locally inverted fast
        CLKDIV       => clk_div_i,      -- Slow clock from MMCM
        CLKDIVP      => '0',
        D            => '0',            -- 1-bit Input signal from IOB
        DDLY         => data_i,         -- 1-bit Input from Input Delay component
        RST          => io_reset,       -- 1-bit Asynchronous reset only.
        SHIFTIN1     => '0',
        SHIFTIN2     => '0',
        -- unused connections
        DYNCLKDIVSEL => '0',
        DYNCLKSEL    => '0',
        OFB          => '0',
        OCLK         => '0',
        OCLKB        => '0',
        O            => open            -- unregistered output of ISERDESE1
        );

  end generate iserdes_x8_a7;

end behavioral;
