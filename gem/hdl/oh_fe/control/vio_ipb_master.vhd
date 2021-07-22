library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.ipbus_pkg.all;

entity vio_ipb_master is
  generic(
    GE11 : integer := 0;
    GE21 : integer := 0
    );
  port(
    clock : in std_logic;

    -- wishbone master
    ipb_mosi_o : out ipb_wbus;
    ipb_miso_i : in  ipb_rbus
    );
end vio_ipb_master;

architecture behavioral of vio_ipb_master is

  signal strobe, strobe_r, wr, ack, err : std_logic := '0';

  component ipb_vio
    port (
      clk        : in  std_logic;
      probe_in0  : in  std_logic_vector(31 downto 0);
      probe_out0 : out std_logic_vector(15 downto 0);
      probe_out1 : out std_logic_vector(31 downto 0);
      probe_out2 : out std_logic_vector(0 downto 0);
      probe_out3 : out std_logic_vector(0 downto 0)
      );
  end component;

begin

  ge11_gen : if (GE11 = 1) generate
    strobe               <= '0';
    ipb_mosi_o.ipb_addr  <= (others => '0');
    ipb_mosi_o.ipb_wdata <= (others => '0');
    ipb_mosi_o.ipb_write <= '0';
  end generate;

  ge21_gen : if (GE21 = 1) generate
    ipb_vio_inst : ipb_vio
      port map (
        clk           => clock,
        probe_in0     => ipb_miso_i.ipb_rdata,
        probe_out0    => ipb_mosi_o.ipb_addr,
        probe_out1    => ipb_mosi_o.ipb_wdata,
        probe_out2(0) => ipb_mosi_o.ipb_write,
        probe_out3(0) => strobe
        );
  end generate;

  process (clock) is
  begin
    if (rising_edge(clock)) then
      strobe_r <= strobe;
    end if;
  end process;

  ipb_mosi_o.ipb_strobe <= '1' when strobe_r = '0' and strobe = '1' else '0';

  ack <= ipb_miso_i.ipb_ack;
  err <= ipb_miso_i.ipb_err;

end behavioral;
