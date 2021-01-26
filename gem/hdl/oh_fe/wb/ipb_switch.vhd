----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration (A. Peck)
-- Optohybrid v3 Firmware -- IpBus Switch
----------------------------------------------------------------------------------
-- Wrapper between IPBUS naming conventions and Wishbone switch
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.ipbus_pkg.all;

entity ipb_switch is
  generic (
    g_TMR_INSTANCE         : integer := 0
    );
  port(

    clock_i : in std_logic;
    reset_i : in std_logic;

    -- Master
    mosi_masters : in  ipb_wbus_array (WB_MASTERS-1 downto 0);
    miso_masters : out ipb_rbus_array (WB_MASTERS-1 downto 0);

    -- Slaves
    mosi_slaves : out ipb_wbus_array (WB_SLAVES-1 downto 0);
    miso_slaves : in  ipb_rbus_array (WB_SLAVES-1 downto 0)

    );
end ipb_switch;

architecture Behavioral of ipb_switch is

  -- Master
  signal wb_req_i : wb_req_array_t((WB_MASTERS - 1) downto 0);  -- From masters requests
  signal wb_res_o : wb_res_array_t((WB_MASTERS - 1) downto 0);  -- To masters responses

  -- Slaves
  signal wb_res_i : wb_res_array_t((WB_SLAVES - 1) downto 0);  -- From slaves responses
  signal wb_req_o : wb_req_array_t((WB_SLAVES - 1) downto 0);  -- To slaves requests

begin

  GEN_MOSI_MASTERS :
  for I in 0 to (WB_MASTERS - 1) generate
    wb_req_i(I).stb  <= mosi_masters(I).ipb_strobe;
    wb_req_i(I).we   <= mosi_masters(I).ipb_write;
    wb_req_i(I).addr <= mosi_masters(I).ipb_addr;
    wb_req_i(I).data <= mosi_masters(I).ipb_wdata;
  end generate GEN_MOSI_MASTERS;

  GEN_MISO_MASTERS :
  for I in 0 to (WB_MASTERS - 1) generate
    miso_masters(I).ipb_err   <= wb_res_o(I).stat(0);
    miso_masters(I).ipb_ack   <= wb_res_o(I).ack;
    miso_masters(I).ipb_rdata <= wb_res_o(I).data;
  end generate GEN_MISO_MASTERS;

  GEN_MOSI_SLAVES :
  for I in 0 to (WB_SLAVES - 1) generate
    mosi_slaves(I).ipb_strobe <= wb_req_o(I).stb;
    mosi_slaves(I).ipb_write  <= wb_req_o(I).we;
    mosi_slaves(I).ipb_addr   <= wb_req_o(I).addr;
    mosi_slaves(I).ipb_wdata  <= wb_req_o(I).data;
  end generate GEN_MOSI_SLAVES;

  GEN_MISO_SLAVES :
  for I in 0 to (WB_SLAVES - 1) generate
    wb_res_i(I).stat <= "000" & miso_slaves(I).ipb_err;
    wb_res_i(I).ack  <= miso_slaves(I).ipb_ack;
    wb_res_i(I).data <= miso_slaves(I).ipb_rdata;
  end generate GEN_MISO_SLAVES;

  -- This module is the Wishbone switch which redirects requests from the masters to the slaves.

  wb_switch_inst : entity work.wb_switch
    port map(
      ref_clk_i => clock_i,
      reset_i   => reset_i,

      -- connect to master
      wb_req_i => wb_req_i,
      wb_res_o => wb_res_o,

      -- connect to slaves
      wb_req_o => wb_req_o,
      wb_res_i => wb_res_i
      );

end Behavioral;

