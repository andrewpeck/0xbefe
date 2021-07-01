library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.ipbus_pkg.all;
use work.types_pkg.all;

entity ipbus_slave_tmr is
  generic(
    g_ENABLE_TMR           : integer := 1;
    g_N_SYNC_STAGES        : integer := 1;  --
    g_NUM_REGS             : integer := 2;  -- number of 32bit registers in this slave (use them wisely, don't allocate 100 times more than you need). If there are big gaps in the register addresses, please use individual address mapping.
    g_ADDR_HIGH_BIT        : integer := 5;  -- MSB of the IPbus address that will be mapped to registers
    g_ADDR_LOW_BIT         : integer := 0;  -- LSB of the IPbus address that will be mapped to registers
    g_USE_INDIVIDUAL_ADDRS : boolean := false;  -- when true, we will map the registers to the individual addresses provided in individual_addrs_arr_i(g_ADDR_HIGH_BIT downto g_ADDR_LOW_BIT)
    g_IPB_CLK_PERIOD_NS    : integer            -- ipb_clk_i period, this is used to set the timeout
    );
  port(
    ipb_reset_i : in  std_logic;        -- IPbus reset (will reset the register values to the provided defaults)
    ipb_clk_i   : in  std_logic;        -- IPbus clock
    ipb_mosi_i  : in  ipb_wbus;         -- master to slave IPbus interface
    ipb_miso_o  : out ipb_rbus;         -- slave to master IPbus interface

    usr_clk_i             : in  std_logic;                                  -- user clock used to read and write regs_write_arr_o and regs_read_arr_i
    regs_read_arr_i       : in  t_std32_array(g_NUM_REGS - 1 downto 0);     -- read registers
    regs_write_arr_o      : out t_std32_array(g_NUM_REGS - 1 downto 0);     -- write registers
    read_pulse_arr_o      : out std_logic_vector(g_NUM_REGS - 1 downto 0);  -- asserted when reading the given register
    write_pulse_arr_o     : out std_logic_vector(g_NUM_REGS - 1 downto 0);  -- asserted when writing the given register
    regs_read_ready_arr_i : in  std_logic_vector(g_NUM_REGS - 1 downto 0);  -- read operations will wait for this bit to be 1 before latching in the data and completing the read operation
    regs_write_done_arr_i : in  std_logic_vector(g_NUM_REGS - 1 downto 0);  -- write operations will wait for this bit to be 1 before finishing the transaction

    regs_defaults_arr_i    : in t_std32_array(g_NUM_REGS - 1 downto 0);     -- register default values - set when ipb_reset_i = '1'
    writable_regs_i        : in std_logic_vector(g_NUM_REGS - 1 downto 0);  -- bitmask indicating which registers are writable and need defaults to be loaded (this helps to save resources)
    individual_addrs_arr_i : in t_std32_array(g_NUM_REGS - 1 downto 0);     -- individual register addresses - only used when g_USE_INDIVIDUAL_ADDRS = "TRUE"

    sump : out std_logic;

    tmr_err_o : out std_logic
    );
end ipbus_slave_tmr;

architecture Behavioral of ipbus_slave_tmr is

  signal tmr_err : std_logic_vector (3*(g_NUM_REGS+1) downto 0) := (others => '0');

begin

  NO_TMR : if (g_ENABLE_TMR = 0) generate

    ipbus_slave_inst : entity work.ipbus_slave
      generic map(
        g_TMR_INSTANCE         => 0,
        g_NUM_REGS             => g_NUM_REGS,
        g_ADDR_HIGH_BIT        => g_ADDR_HIGH_BIT,
        g_ADDR_LOW_BIT         => g_ADDR_LOW_BIT,
        g_USE_INDIVIDUAL_ADDRS => g_USE_INDIVIDUAL_ADDRS,
        g_N_SYNC_STAGES        => g_N_SYNC_STAGES,
        g_IPB_CLK_PERIOD_NS    => g_IPB_CLK_PERIOD_NS
        )
      port map(
        -- inputs
        ipb_reset_i            => ipb_reset_i,
        ipb_clk_i              => ipb_clk_i,
        ipb_mosi_i             => ipb_mosi_i,
        usr_clk_i              => usr_clk_i,
        regs_read_arr_i        => regs_read_arr_i,
        regs_read_ready_arr_i  => regs_read_ready_arr_i,
        regs_write_done_arr_i  => regs_write_done_arr_i,
        individual_addrs_arr_i => individual_addrs_arr_i,
        regs_defaults_arr_i    => regs_defaults_arr_i,
        writable_regs_i        => writable_regs_i,

        -- outputs
        ipb_miso_o        => ipb_miso_o,
        regs_write_arr_o  => regs_write_arr_o,
        read_pulse_arr_o  => read_pulse_arr_o,
        write_pulse_arr_o => write_pulse_arr_o
        );

  end generate NO_TMR;

  TMR : if (g_ENABLE_TMR = 1) generate

    attribute DONT_TOUCH : string;

    type t_regs_write_arr_tmr is array(2 downto 0) of t_std32_array (g_NUM_REGS-1 downto 0);
    type t_rw_pulse_arr_tmr is array(2 downto 0) of std_logic_vector(g_NUM_REGS-1 downto 0);

    signal ipb_miso_tmr        : ipb_rbus_array(2 downto 0);  -- slave to master IPbus interface
    signal regs_write_arr_tmr  : t_regs_write_arr_tmr;        -- write registers
    signal read_pulse_arr_tmr  : t_rw_pulse_arr_tmr;
    signal write_pulse_arr_tmr : t_rw_pulse_arr_tmr;

    attribute DONT_TOUCH of ipb_miso_tmr        : signal is "true";
    attribute DONT_TOUCH of regs_write_arr_tmr  : signal is "true";
    attribute DONT_TOUCH of read_pulse_arr_tmr  : signal is "true";
    attribute DONT_TOUCH of write_pulse_arr_tmr : signal is "true";

  begin

    tmr_loop : for I in 0 to 2 generate
    begin

      ipbus_slave_inst_tmr : entity work.ipbus_slave
        generic map(
          g_TMR_INSTANCE         => I,
          g_NUM_REGS             => g_NUM_REGS,
          g_ADDR_HIGH_BIT        => g_ADDR_HIGH_BIT,
          g_ADDR_LOW_BIT         => g_ADDR_LOW_BIT,
          g_USE_INDIVIDUAL_ADDRS => g_USE_INDIVIDUAL_ADDRS,
          g_N_SYNC_STAGES        => g_N_SYNC_STAGES,
          g_IPB_CLK_PERIOD_NS    => g_IPB_CLK_PERIOD_NS
          )
        port map(
          -- inputs
          ipb_reset_i            => ipb_reset_i,
          ipb_clk_i              => ipb_clk_i,
          ipb_mosi_i             => ipb_mosi_i,
          usr_clk_i              => usr_clk_i,
          regs_read_arr_i        => regs_read_arr_i,
          regs_read_ready_arr_i  => regs_read_ready_arr_i,
          regs_write_done_arr_i  => regs_write_done_arr_i,
          individual_addrs_arr_i => individual_addrs_arr_i,
          regs_defaults_arr_i    => regs_defaults_arr_i,
          writable_regs_i        => writable_regs_i,

          -- outputs
          ipb_miso_o        => ipb_miso_tmr(I),
          regs_write_arr_o  => regs_write_arr_tmr(I),
          read_pulse_arr_o  => read_pulse_arr_tmr(I),
          write_pulse_arr_o => write_pulse_arr_tmr(I)
          );

    end generate;

    regloop : for I in 0 to g_NUM_REGS-1 generate
      majority_err (write_pulse_arr_o(I), tmr_err(3*I+0), write_pulse_arr_tmr(0)(I), write_pulse_arr_tmr(1)(I), write_pulse_arr_tmr(2)(I));
      majority_err (read_pulse_arr_o(I), tmr_err(3*I+1), read_pulse_arr_tmr (0)(I), read_pulse_arr_tmr (1)(I), read_pulse_arr_tmr (2)(I));
      majority_err (regs_write_arr_o(I), tmr_err(3*I+2), regs_write_arr_tmr (0)(I), regs_write_arr_tmr (1)(I), regs_write_arr_tmr (2)(I));
    end generate;

    majority_err(ipb_miso_o.ipb_rdata, tmr_err(3*g_NUM_REGS+0), ipb_miso_tmr(0).ipb_rdata, ipb_miso_tmr(1).ipb_rdata, ipb_miso_tmr(2).ipb_rdata);
    majority_err(ipb_miso_o.ipb_ack, tmr_err(3*g_NUM_REGS+1), ipb_miso_tmr(0).ipb_ack, ipb_miso_tmr(1).ipb_ack, ipb_miso_tmr(2).ipb_ack);
    majority_err(ipb_miso_o.ipb_err, tmr_err(3*g_NUM_REGS+2), ipb_miso_tmr(0).ipb_err, ipb_miso_tmr(1).ipb_err, ipb_miso_tmr(2).ipb_err);

  end generate;

  process (ipb_clk_i) is
  begin
    if (rising_edge(ipb_clk_i)) then
      tmr_err_o <= or_reduce(tmr_err);
    end if;
  end process;

end Behavioral;
