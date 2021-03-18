library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.hardware_pkg.all;

-- Declare module entity. Declare module inputs, inouts, and outputs.
entity top_cluster_packer_tb is
end top_cluster_packer_tb;

-- Begin module architecture/code.
architecture behave of top_cluster_packer_tb is

-- UUT Port Signals.
  signal prt_sel : integer := 0;
  signal adr_sel : integer := 0;

  signal prt_sel_dly : integer := 0;
  signal adr_sel_dly : integer := 0;

  signal partitions : partition_array_t (NUM_PARTITIONS-1 downto 0);

-- Instantiate Constants
  constant clk_PERIOD    : time := 25.0 ns;
  constant clk160_PERIOD : time := 6.25 ns;

  signal clocks          : clocks_t;
  signal reset           : std_logic                              := '0';
  signal trig_stop_i     : std_logic                              := '0';
  signal cluster_count_o : std_logic_vector (10 downto 0);
  signal sbits_i         : sbits_array_t (NUM_VFATS-1 downto 0) := (others => (others => '0'));
  signal clusters_o      : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
  signal clusters_ena_o  : std_logic;
  signal overflow_o      : std_logic;

  signal run     : std_logic;
  signal special : std_logic;
  signal adr_err : std_logic;
  signal prt_err : std_logic;

begin

  adr_err <= '1' when adr_sel_dly /= to_integer(unsigned(clusters_o(0).adr)) else '0';
  prt_err <= '1' when prt_sel_dly /= to_integer(unsigned(clusters_o(0).prt)) else '0';

  adr_sel_dly <= transport adr_sel after 75 ns;
  prt_sel_dly <= transport prt_sel after 75 ns;

  cluster_packer_inst : entity work.cluster_packer
    generic map (
      DEADTIME         => 0,
      ONESHOT          => false,
      g_SPLIT_CLUSTERS => 0
      )
    port map (
      clocks          => clocks,
      reset           => reset,
      cluster_count_o => cluster_count_o,
      trig_stop_i     => trig_stop_i,
      sbits_i         => sbits_i,
      clusters_o      => clusters_o,
      clusters_ena_o  => clusters_ena_o,
      overflow_o      => overflow_o);

  assign_partitions : for iprt in 0 to NUM_PARTITIONS-1 generate
    initial : process (clocks.clk40)
    begin
      if (rising_edge(clocks.clk40)) then
        if (reset = '1') then
          partitions(iprt)      <= (others => '0');
        elsif (special = '1') then
          partitions(iprt)      <= (others => '0');
          partitions(iprt)(0)   <= '1';
          partitions(iprt)(32)  <= '1';
          partitions(iprt)(64)  <= '1';
          partitions(iprt)(96)  <= '1';
          partitions(iprt)(128) <= '1';
          partitions(iprt)(160) <= '1';
          partitions(iprt)(192) <= '1';
          partitions(iprt)(224) <= '1';
          partitions(iprt)(256) <= '1';
          partitions(iprt)(288) <= '1';
          partitions(iprt)(320) <= '1';
        elsif (run = '1' and prt_sel = iprt) then
          partitions(iprt)          <= (others => '0');
          partitions(iprt)(adr_sel) <= '1';
        else
          partitions(iprt) <= (others => '0');
        end if;
      end if;
    end process;
  end generate;

  ge21_partition_map_gen : if (GE21 = 1) generate
    function partition_to_sbits (prt : std_logic_vector; index : integer) return std_logic_vector is
    --variable sbits : std_logic_vector (63 downto 0);
    begin
      return prt((index+1)*64-1 downto index*64);
    end function;
  begin
    invert_gen : if (INVERT_PARTITIONS) generate
      flatten_partitions : for I in 0 to 5 generate
        sbits_i(I)   <= partition_to_sbits(partitions(0), I);
        sbits_i(I+6) <= partition_to_sbits(partitions(1), I);
      end generate;
    end generate;
    noninvert_gen : if (not INVERT_PARTITIONS) generate
      flatten_partitions : for I in 0 to 5 generate
        sbits_i(I)   <= partition_to_sbits(partitions(1), I);
        sbits_i(I+6) <= partition_to_sbits(partitions(0), I);
      end generate;
    end generate;
  end generate;

  --ge11_partition_map_gen : if (GE11 = 1) generate
  --  invert_gen : if (INVERT_PARTITIONS) generate
  --    sbits_i(23) & sbits_i(15) & sbits_i(7)<= partitions(0) ;
  --    sbits_i(22) & sbits_i(14) & sbits_i(6)<= partitions(1) ;
  --    sbits_i(21) & sbits_i(13) & sbits_i(5)<= partitions(2) ;
  --    sbits_i(20) & sbits_i(12) & sbits_i(4)<= partitions(3) ;
  --    sbits_i(19) & sbits_i(11) & sbits_i(3)<= partitions(4) ;
  --    sbits_i(18) & sbits_i(10) & sbits_i(2)<= partitions(5) ;
  --    sbits_i(17) & sbits_i(9)  & sbits_i(1)<= partitions(6) ;
  --    sbits_i(16) & sbits_i(8)  & sbits_i(0)<= partitions(7) ;
  --  end generate;
  --  noninvert_gen : if (not INVERT_PARTITIONS) generate
  --    sbits_i(16) & sbits_i(8)  & sbits_i(0) <= partitions(0) ;
  --    sbits_i(17) & sbits_i(9)  & sbits_i(1) <= partitions(1) ;
  --    sbits_i(18) & sbits_i(10) & sbits_i(2) <= partitions(2) ;
  --    sbits_i(19) & sbits_i(11) & sbits_i(3) <= partitions(3) ;
  --    sbits_i(20) & sbits_i(12) & sbits_i(4) <= partitions(4) ;
  --    sbits_i(21) & sbits_i(13) & sbits_i(5) <= partitions(5) ;
  --    sbits_i(22) & sbits_i(14) & sbits_i(6) <= partitions(6) ;
  --    sbits_i(23) & sbits_i(15) & sbits_i(7) <= partitions(7) ;
  --  end generate;
  --end generate;

-- Toggle the resets.
  adrsel : process
  begin
    wait for 25 ns;
    if (reset = '1') then
        adr_sel <= 0;
        prt_sel <= 0;
    else
      if (prt_sel = NUM_PARTITIONS-1 and adr_sel = PARTITION_SIZE*MXSBITS) then
        wait;                           -- done
      elsif (adr_sel < PARTITION_SIZE*MXSBITS-1) then
        adr_sel <= adr_sel + 1;
      else
        adr_sel <= 0;
        prt_sel <= prt_sel + 1;
      end if;
    end if;
  end process;

-- Toggle the resets.
  resetproc : process
  begin
    run <= '0';
    special <= '0';
    reset   <= '1';
    wait for 400 ns;
    special <= '1';
    reset   <= '0';
    wait for 25 ns;
    special <= '0';
    wait for 100 ns;
    run   <= '1';
    wait;                               -- process hangs forever.
  end process;

-- Generate necessary clocks.
  clkgen : process
  begin
    clocks.clk40 <= '1';
    wait for clk_PERIOD / 2;
    clocks.clk40 <= '0';
    wait for clk_PERIOD / 2;
  end process;

-- Generate necessary clocks.
  clkgen2 : process
  begin
    clocks.clk160_0 <= '1';
    wait for clk160_PERIOD / 2;
    clocks.clk160_0 <= '0';
    wait for clk160_PERIOD / 2;
  end process;

-- Insert Processes and code here.

end behave;  -- architecture
