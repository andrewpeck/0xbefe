----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- GBT Link Parser
-- A. Peck
----------------------------------------------------------------------------------
-- Description: TMR wrapper for gbt link module
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.ipbus_pkg.all;

entity gbt_link_tmr is
  generic (g_ENABLE_TMR : integer := 1);
  port(

    -- reset
    reset_i : in std_logic;

    -- clk inputs
    clock : in std_logic;

    -- parallel data to/from serdes
    data_i : in  std_logic_vector (7 downto 0);
    data_o : out std_logic_vector(7 downto 0);

    -- wishbone
    ipb_mosi_o : out ipb_wbus;
    ipb_miso_i : in  ipb_rbus;

    -- decoded ttc
    l1a_o    : out std_logic;
    bc0_o    : out std_logic;
    resync_o : out std_logic;

    -- status
    ready_o        : out std_logic;
    error_o        : out std_logic;
    crc_error_o    : out std_logic;
    precrc_error_o : out std_logic;
    unstable_o     : out std_logic;

    tmr_err_inj_i : in  std_logic := '0';
    tmr_err_o     : out std_logic := '0'
    );
end gbt_link_tmr;

architecture Behavioral of gbt_link_tmr is

begin

  NO_TMR : if (g_ENABLE_TMR = 0) generate
    gbt_link_inst : entity work.gbt_link
      generic map(
        g_TMR_INSTANCE => 0
        )
      port map(

        -- reset
        reset_i => reset_i,

        -- clock inputs
        clock => clock,

        -- parallel data
        data_i => data_i,
        data_o => data_o,

        -- wishbone master
        ipb_mosi_o => ipb_mosi_o,
        ipb_miso_i => ipb_miso_i,

        -- decoded TTC
        resync_o => resync_o,
        l1a_o    => l1a_o,
        bc0_o    => bc0_o,

        -- outputs
        unstable_o  => unstable_o,
        crc_error_o => crc_error_o,
        error_o     => error_o
        );
  end generate NO_TMR;

  TMR : if (g_ENABLE_TMR = 1) generate

    signal resync_tmr       : std_logic_vector(2 downto 0);
    signal l1a_tmr          : std_logic_vector(2 downto 0);
    signal bc0_tmr          : std_logic_vector(2 downto 0);
    signal unstable_tmr     : std_logic_vector(2 downto 0);
    signal rdy_tmr          : std_logic_vector(2 downto 0);
    signal error_tmr        : std_logic_vector(2 downto 0);
    signal crc_error_tmr    : std_logic_vector(2 downto 0);
    signal precrc_error_tmr : std_logic_vector(2 downto 0);
    signal ready_tmr        : std_logic_vector(2 downto 0);
    signal ipb_mosi_tmr     : ipb_wbus_array (2 downto 0);
    signal data_tmr         : t_std8_array (2 downto 0);

    signal tmr_err : std_logic_vector (12 downto 0) := (others => '0');


    attribute DONT_TOUCH                 : string;
    attribute DONT_TOUCH of resync_tmr   : signal is "true";
    attribute DONT_TOUCH of l1a_tmr      : signal is "true";
    attribute DONT_TOUCH of bc0_tmr      : signal is "true";
    attribute DONT_TOUCH of unstable_tmr : signal is "true";
    attribute DONT_TOUCH of rdy_tmr      : signal is "true";
    attribute DONT_TOUCH of error_tmr    : signal is "true";
    attribute DONT_TOUCH of ready_tmr    : signal is "true";
    attribute DONT_TOUCH of ipb_mosi_tmr : signal is "true";
    attribute DONT_TOUCH of data_tmr     : signal is "true";

  begin

    tmr_loop : for I in 0 to 2 generate
    begin

      gbt_link_inst : entity work.gbt_link
        generic map(g_TMR_INSTANCE => I)
        port map(

          -- reset
          reset_i => reset_i,

          -- clock inputs
          clock => clock,

          -- parallel data
          data_i => data_i,
          data_o => data_tmr(I),

          -- wishbone master
          ipb_mosi_o => ipb_mosi_tmr(I),
          ipb_miso_i => ipb_miso_i,

          -- decoded TTC
          resync_o => resync_tmr(I),
          l1a_o    => l1a_tmr(I),
          bc0_o    => bc0_tmr(I),

          -- outputs
          unstable_o     => unstable_tmr(I),
          crc_error_o    => crc_error_tmr(I),
          precrc_error_o => precrc_error_tmr(I),
          error_o        => error_tmr(I),
          ready_o        => ready_tmr(I)

          );

    end generate;

    majority_err (data_o, tmr_err(0), data_tmr(0), data_tmr(1), data_tmr(2));
    majority_err (ipb_mosi_o.ipb_wdata, tmr_err(1), ipb_mosi_tmr(0).ipb_wdata, ipb_mosi_tmr(1).ipb_wdata, ipb_mosi_tmr(2).ipb_wdata);
    majority_err (ipb_mosi_o.ipb_write, tmr_err(2), ipb_mosi_tmr(0).ipb_write, ipb_mosi_tmr(1).ipb_write, ipb_mosi_tmr(2).ipb_write);
    majority_err (ipb_mosi_o.ipb_strobe, tmr_err(3), ipb_mosi_tmr(0).ipb_strobe, ipb_mosi_tmr(1).ipb_strobe, ipb_mosi_tmr(2).ipb_strobe);
    majority_err (ipb_mosi_o.ipb_addr, tmr_err(4), ipb_mosi_tmr(0).ipb_addr, ipb_mosi_tmr(1).ipb_addr, ipb_mosi_tmr(2).ipb_addr);
    majority_err (resync_o, tmr_err(5), resync_tmr(0), resync_tmr(1), resync_tmr(2));
    majority_err (l1a_o, tmr_err(6), tmr_err_inj_i xor l1a_tmr(0), l1a_tmr(1), l1a_tmr(2));
    majority_err (bc0_o, tmr_err(7), bc0_tmr(0), bc0_tmr(1), bc0_tmr(2));
    majority_err (unstable_o, tmr_err(8), unstable_tmr(0), unstable_tmr(1), unstable_tmr(2));
    majority_err (error_o, tmr_err(9), error_tmr(0), error_tmr(1), error_tmr(2));
    majority_err (crc_error_o, tmr_err(10), crc_error_tmr(0), crc_error_tmr(1), crc_error_tmr(2));
    majority_err (precrc_error_o, tmr_err(11), precrc_error_tmr(0), precrc_error_tmr(1), precrc_error_tmr(2));
    majority_err (ready_o, tmr_err(12), ready_tmr(0), ready_tmr(1), ready_tmr(2));

    process (clock) is
    begin
      if (rising_edge(clock)) then
        tmr_err_o <= or_reduce(tmr_err);
      end if;
    end process;

  end generate TMR;

end Behavioral;
