library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library work;
use work.types_pkg.all;
use work.hardware_pkg.all;

entity iserdes is
  generic (
    g_SERDES_MODE : string := "MASTER"
    );
  port(
    clk_i    : in  std_logic;
    clk_90_i : in  std_logic;
    reset_i  : in  std_logic;
    data_i   : in  std_logic;
    data_o   : out std_logic_vector (3 downto 0)
    );
end iserdes;

architecture behavioral of iserdes is

  signal clk     : std_logic;
  signal clk_90  : std_logic;
  signal clk_180 : std_logic;
  signal clk_270 : std_logic;

begin

  -- Clocks MUST come from only two BFUG/BUFIO; see UG471
  clk     <= clk_i;
  clk_90  <= clk_90_i;
  clk_180 <= not clk_i;
  clk_270 <= not clk_90_i;

  ----------------------------------------------------------------------------------------------------------------------
  -- iserdes
  ----------------------------------------------------------------------------------------------------------------------

  iserdes_v6 : if (FPGA_TYPE = "V6") generate

    iserdes : iserdese1
      generic map(
        INTERFACE_TYPE => "OVERSAMPLE",
        DATA_RATE      => "DDR",        -- SPECIFY DATA RATE OF "DDR" OR "SDR"
        DATA_WIDTH     => 4,  -- SPECIFY DATA WIDTH: NETWORKING SDR: 2, 3, 4, 5, 6, 7, 8 : DDR 4, 6, 8, 10
        OFB_USED       => false,        --
        NUM_CE         => 2,  -- DEFINE NUMBER OR CLOCK ENABLES TO AN INTEGER OF 1 OR 2
        SERDES_MODE    => g_SERDES_MODE,
        IOBDELAY       => "IFD")
      port map(
        clk          => clk,
        clkb         => clk_180,
        oclk         => clk_90,
        d            => '0',
        bitslip      => '0',
        ce1          => '1',
        ce2          => '1',
        clkdiv       => '0',
        ddly         => data_i,
        dynclkdivsel => '0',
        dynclksel    => '0',
        ofb          => '0',
        rst          => reset_i,
        shiftin1     => '0',
        shiftin2     => '0',
        o            => open,
        q1           => data_o(0),
        q2           => data_o(1),
        q3           => data_o(2),
        q4           => data_o(3),
        q5           => open,
        q6           => open,
        shiftout1    => open,
        shiftout2    => open
        );

  end generate iserdes_v6;


  iserdes_a7 : if (FPGA_TYPE = "A7") generate

    iserdes : iserdese2
      generic map (
        data_rate         => "DDR",     -- ddr, sdr
        data_width        => 4,         -- parallel data width  2-8,10,14)
        dyn_clkdiv_inv_en => "FALSE",  -- enable dynclkdivinvsel inversion false, true)
        dyn_clk_inv_en    => "FALSE",  -- enable dynclkinvsel inversion  false, true)
        init_q1           => '0',  -- init_q1 - init_q4: initial value on the q outputs   => 0/1
        init_q2           => '0',  -- init_q1 - init_q4: initial value on the q outputs   => 0/1
        init_q3           => '0',  -- init_q1 - init_q4: initial value on the q outputs   => 0/1
        init_q4           => '0',  -- init_q1 - init_q4: initial value on the q outputs   => 0/1
        interface_type    => "OVERSAMPLE",  -- memory, memory_ddr3, memory_qdr, networking, oversample
        iobdelay          => "IFD",     -- none, both, ibuf, ifd
        num_ce            => 1,         -- number of clock enables 1,2)
        ofb_used          => "FALSE",   -- select ofb path false, true)
        serdes_mode       => "MASTER",  -- master, slave
        srval_q1          => '0',  -- srval_q1 - srval_q4: q output values when sr is used => 0/1
        srval_q2          => '0',  -- srval_q1 - srval_q4: q output values when sr is used => 0/1
        srval_q3          => '0',  -- srval_q1 - srval_q4: q output values when sr is used => 0/1
        srval_q4          => '0'  -- srval_q1 - srval_q4: q output values when sr is used => 0/1
        )
      port map (
        o         => open,              -- 1-bit output: combinatorial output
        q1        => data_o(0),  -- q1 - q8: 1-bit each output: registered data outputs
        q2        => data_o(1),  -- q1 - q8: 1-bit each output: registered data outputs
        q3        => data_o(2),  -- q1 - q8: 1-bit each output: registered data outputs
        q4        => data_o(3),  -- q1 - q8: 1-bit each output: registered data outputs
        q5        => open,  -- q1 - q8: 1-bit each output: registered data outputs
        q6        => open,  -- q1 - q8: 1-bit each output: registered data outputs
        q7        => open,  -- q1 - q8: 1-bit each output: registered data outputs
        q8        => open,  -- q1 - q8: 1-bit each output: registered data outputs
        shiftout1 => open,  -- shiftout1, shiftout2: 1-bit each output: data width expansion output ports
        shiftout2 => open,  -- shiftout1, shiftout2: 1-bit each output: data width expansion output ports
        bitslip   => '0',  -- 1-bit input: the bitslip pin performs a bitslip operation synchronous to
        ce1       => '1',  -- ce1, ce2: 1-bit each input: data register clock enable inputs
        ce2       => '1',  -- ce1, ce2: 1-bit each input: data register clock enable inputs

        -- clocks
        clkdivp => '0',                 -- 1-bit input: tbd
        clk     => clk,                 -- 1-bit input: high-speed clock
        clkb    => clk_180,  -- 1-bit input: high-speed secondary clock
        oclk    => clk_90,  -- 1-bit input: high speed output clock used when interface_type="memory"
        oclkb   => clk_270,  -- 1-bit input: high speed negative edge output clock
        clkdiv  => '0',                 -- 1-bit input: divided clock

        -- dynamic clock inversions: 1-bit each input: dynamic clock inversion pins to switch clock polarity
        dynclkdivsel => '0',  -- 1-bit input: dynamic clkdiv inversion
        dynclksel    => '0',  -- 1-bit input: dynamic clk/clkb inversion

        -- input data: 1-bit each input: iserdese2 data input ports
        d    => '0',                    -- 1-bit input: data input
        ddly => data_i,   -- 1-bit input: serial data from idelaye2
        ofb  => '0',      -- 1-bit input: data feedback from oserdese2
        rst  => reset_i,  -- 1-bit input: active high asynchronous reset

        -- shiftin1, shiftin2: 1-bit each input: data width expansion input ports
        shiftin1 => '0',
        shiftin2 => '0'
        );

  end generate iserdes_a7;

end behavioral;
