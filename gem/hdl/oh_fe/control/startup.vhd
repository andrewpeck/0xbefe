----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- startup clock; generic wrapper around v6 and a7
-- a. peck
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.hardware_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity startup is
  port(
    clock_o : out std_logic
    );

  attribute clock_signal            : string;
  attribute clock_signal of clock_o : signal is "yes";

end startup;

architecture behavioral of startup is
begin

  startup_gen : if (FPGA_TYPE = "V6") generate


    startup_virtex6_inst : STARTUP_VIRTEX6
      generic map (
        PROG_USR => false               -- activate program event security feature. requires encrypted bitstreams.
        )

      port map (
        CFGCLK  => open,                -- 1-bit output: configuration main clock output
        CFGMCLK => clock_o,             -- 1-bit output: configuration internal oscillator clock output
        DINSPI  => open,                -- 1-bit output: din spi prom access output
        EOS     => open,                -- 1-bit output: active high output signal indicating the end of configuration.
        PREQ    => open,                -- 1-bit output: program request to fabric output
        TCKSPI  => open,                -- 1-bit output: tck configuration pin access output

        CLK       => '0',               -- 1-bit input: user start-up clock input
        GSR       => '0',               -- 1-bit input: global set/reset input (gsr cannot be used for the port name)
        GTS       => '0',               -- 1-bit input: global 3-state input   (gts cannot be used for the port name)
        KEYCLEARB => '0',               -- 1-bit input: clear aes decrypter key input from battery-backed ram (bbram)
        PACK      => '0',               -- 1-bit input: program acknowledge input
        USRCCLKO  => '0',               -- 1-bit input: user cclk input
        USRCCLKTS => '0',               -- 1-bit input: user cclk 3-state enable input
        USRDONEO  => '1',               -- 1-bit input: user done pin output control
        USRDONETS => '1'                -- 1-bit input: user done 3-state enable output
        );


  end generate startup_gen;

  startup_gen_a7 : if (FPGA_TYPE = "A7") generate

    startupe2_inst : STARTUPE2
      generic map (
        PROG_USR      => "FALSE",       -- activate program event security feature. requires encrypted bitstreams.
        SIM_CCLK_FREQ => 0.0            -- set the configuration clock frequency(ns) for simulation.
        )
      port map (
        CFGCLK    => open,              -- 1-bit output: configuration main clock output
        CFGMCLK   => clock_o,           -- 1-bit output: configuration internal oscillator clock output
        EOS       => open,              -- 1-bit output: active high output signal indicating the end of startup.
        PREQ      => open,              -- 1-bit output: program request to fabric output
        CLK       => '0',               -- 1-bit input: user start-up clock input
        GSR       => '0',               -- 1-bit input: global set/reset input (gsr cannot be used for the port name)
        GTS       => '0',               -- 1-bit input: global 3-state input (gts cannot be used for the port name)
        KEYCLEARB => '1',               -- 1-bit input: clear aes decrypter key input from battery-backed ram (bbram)
        PACK      => '0',               -- 1-bit input: program acknowledge input
        USRCCLKO  => '0',               -- 1-bit input: user cclk input for zynq-7000 devices, this input must be tied to gnd
        USRCCLKTS => '0',               -- 1-bit input: user cclk 3-state enable input for zynq-7000 devices, this input must be tied to vcc
        USRDONEO  => '1',               -- 1-bit input: user done pin output control
        USRDONETS => '1'                -- 1-bit input: user done 3-state enable output
        );

  end generate startup_gen_a7;


end behavioral;
