library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.cluster_pkg.all;

entity sort_clusters is
  generic(
    SORTER_TYPE        : integer := 2;
    ENCODER_SIZE       : integer := 0;
    NUM_FOUND_CLUSTERS : integer := 0
    );
  port(

    clock      : in  std_logic;
    latch_i    : in  std_logic;
    latch_o    : out std_logic;
    clusters_i : in  sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
    clusters_o : out sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0)

    );
end sort_clusters;

architecture behavioral of sort_clusters is

begin

  -- we get up to 16 clusters / bx but only get to send a few so we put them in order of priority
  -- (should choose lowest addr first--- highest addr is invalid)

  bitonic_sorter : if (SORTER_TYPE=0) generate

    constant size : integer := 1+MXADRB+MXCNTB+MXPRTB;

    signal data_i, data_o : std_logic_vector (NUM_FOUND_CLUSTERS*SIZE-1 downto 0) := (others => '0');

  begin

    wrapup : for I in 0 to NUM_FOUND_CLUSTERS-1 generate
      constant hi : integer := size*(I+1)-1;
      constant lo : integer := size*(I);
    begin
      data_i (hi downto lo) <= clusters_i(I).cnt & clusters_i(I).adr & clusters_i(I).vpf & clusters_i(I).prt;
    end generate;

    unwrap : for I in 0 to NUM_FOUND_CLUSTERS-1 generate

      constant hi : integer := size*(I+1)-1;
      constant lo : integer := size*(I);

      constant prt_lo : integer := lo;
      constant prt_hi : integer := lo+MXPRTB-1;
      constant vpf_lo : integer := lo+MXPRTB;
      constant vpf_hi : integer := lo+MXPRTB;
      constant adr_lo : integer := lo+1+MXPRTB;
      constant adr_hi : integer := lo+1+MXPRTB+MXADRB-1;
      constant cnt_lo : integer := lo+1+MXPRTB+MXADRB;
      constant cnt_hi : integer := lo+1+MXPRTB+MXADRB+MXCNTB-1;
    begin

      clusters_o(I).cnt <= data_o (cnt_hi downto cnt_lo);
      clusters_o(I).adr <= data_o (adr_hi downto adr_lo);
      clusters_o(I).prt <= data_o (prt_hi downto prt_lo);
      clusters_o(I).vpf <= data_o (vpf_lo);

    end generate;

    bitonic_sort_inst : entity work.Bitonic_Sorter
      generic map (
        REGSTAGES => 2,
        WORDS     => NUM_FOUND_CLUSTERS,
        WORD_BITS => 1 + MXADRB + MXCNTB + MXPRTB,
        -- sort on {Partition, VPF}
        COMP_HIGH => 1 + MXPRTB-1,      -- This is used directly as a COMP_HIGH downto 0, so you must factor in the -1
        COMP_LOW  => 0,
        INFO_BITS => 1
        )
      port map (
        CLK       => clock,
        RST       => '0',
        CLR       => '0',
        I_SORT    => '1',               -- set to 0 and the module won't sort
        I_UP      => '0',               -- set to 0 to prefer the highest number on the lowest input
        I_DATA    => data_i,
        O_DATA    => data_o,
        O_SORT    => open,
        O_UP      => open,
        I_INFO(0) => latch_i,
        O_INFO(0) => latch_o
        );

  end generate;

  fast_sorter : if (SORTER_TYPE=1) generate

    component sorter16
      generic (
        MXADRB : integer;
        MXCNTB : integer;
        MXVPFB : integer;
        MXPRTB : integer;
        SKIPB  : integer
        );
      port (
        adr_in0 : in std_logic_vector;
        adr_in1 : in std_logic_vector;
        adr_in2 : in std_logic_vector;
        adr_in3 : in std_logic_vector;
        adr_in4 : in std_logic_vector;
        adr_in5 : in std_logic_vector;
        adr_in6 : in std_logic_vector;
        adr_in7 : in std_logic_vector;
        adr_in8 : in std_logic_vector;
        adr_in9 : in std_logic_vector;
        adr_in10 : in std_logic_vector;
        adr_in11 : in std_logic_vector;
        adr_in12 : in std_logic_vector;
        adr_in13 : in std_logic_vector;
        adr_in14 : in std_logic_vector;
        adr_in15 : in std_logic_vector;

        prt_in0 : in std_logic_vector;
        prt_in1 : in std_logic_vector;
        prt_in2 : in std_logic_vector;
        prt_in3 : in std_logic_vector;
        prt_in4 : in std_logic_vector;
        prt_in5 : in std_logic_vector;
        prt_in6 : in std_logic_vector;
        prt_in7 : in std_logic_vector;
        prt_in8 : in std_logic_vector;
        prt_in9 : in std_logic_vector;
        prt_in10 : in std_logic_vector;
        prt_in11 : in std_logic_vector;
        prt_in12 : in std_logic_vector;
        prt_in13 : in std_logic_vector;
        prt_in14 : in std_logic_vector;
        prt_in15 : in std_logic_vector;

        vpf_in0 : in std_logic_vector;
        vpf_in1 : in std_logic_vector;
        vpf_in2 : in std_logic_vector;
        vpf_in3 : in std_logic_vector;
        vpf_in4 : in std_logic_vector;
        vpf_in5 : in std_logic_vector;
        vpf_in6 : in std_logic_vector;
        vpf_in7 : in std_logic_vector;
        vpf_in8 : in std_logic_vector;
        vpf_in9 : in std_logic_vector;
        vpf_in10 : in std_logic_vector;
        vpf_in11 : in std_logic_vector;
        vpf_in12 : in std_logic_vector;
        vpf_in13 : in std_logic_vector;
        vpf_in14 : in std_logic_vector;
        vpf_in15 : in std_logic_vector;

        cnt_in0 : in std_logic_vector;
        cnt_in1 : in std_logic_vector;
        cnt_in2 : in std_logic_vector;
        cnt_in3 : in std_logic_vector;
        cnt_in4 : in std_logic_vector;
        cnt_in5 : in std_logic_vector;
        cnt_in6 : in std_logic_vector;
        cnt_in7 : in std_logic_vector;
        cnt_in8 : in std_logic_vector;
        cnt_in9 : in std_logic_vector;
        cnt_in10 : in std_logic_vector;
        cnt_in11 : in std_logic_vector;
        cnt_in12 : in std_logic_vector;
        cnt_in13 : in std_logic_vector;
        cnt_in14 : in std_logic_vector;
        cnt_in15 : in std_logic_vector;

        adr_out0 : out std_logic_vector;
        adr_out1 : out std_logic_vector;
        adr_out2 : out std_logic_vector;
        adr_out3 : out std_logic_vector;
        adr_out4 : out std_logic_vector;
        adr_out5 : out std_logic_vector;
        adr_out6 : out std_logic_vector;
        adr_out7 : out std_logic_vector;
        adr_out8 : out std_logic_vector;
        adr_out9 : out std_logic_vector;
        adr_out10 : out std_logic_vector;
        adr_out11 : out std_logic_vector;
        adr_out12 : out std_logic_vector;
        adr_out13 : out std_logic_vector;
        adr_out14 : out std_logic_vector;
        adr_out15 : out std_logic_vector;

        prt_out0 : out std_logic_vector;
        prt_out1 : out std_logic_vector;
        prt_out2 : out std_logic_vector;
        prt_out3 : out std_logic_vector;
        prt_out4 : out std_logic_vector;
        prt_out5 : out std_logic_vector;
        prt_out6 : out std_logic_vector;
        prt_out7 : out std_logic_vector;
        prt_out8 : out std_logic_vector;
        prt_out9 : out std_logic_vector;
        prt_out10 : out std_logic_vector;
        prt_out11 : out std_logic_vector;
        prt_out12 : out std_logic_vector;
        prt_out13 : out std_logic_vector;
        prt_out14 : out std_logic_vector;
        prt_out15 : out std_logic_vector;

        vpf_out0 : out std_logic_vector;
        vpf_out1 : out std_logic_vector;
        vpf_out2 : out std_logic_vector;
        vpf_out3 : out std_logic_vector;
        vpf_out4 : out std_logic_vector;
        vpf_out5 : out std_logic_vector;
        vpf_out6 : out std_logic_vector;
        vpf_out7 : out std_logic_vector;
        vpf_out8 : out std_logic_vector;
        vpf_out9 : out std_logic_vector;
        vpf_out10 : out std_logic_vector;
        vpf_out11 : out std_logic_vector;
        vpf_out12 : out std_logic_vector;
        vpf_out13 : out std_logic_vector;
        vpf_out14 : out std_logic_vector;
        vpf_out15 : out std_logic_vector;

        cnt_out0 : out std_logic_vector;
        cnt_out1 : out std_logic_vector;
        cnt_out2 : out std_logic_vector;
        cnt_out3 : out std_logic_vector;
        cnt_out4 : out std_logic_vector;
        cnt_out5 : out std_logic_vector;
        cnt_out6 : out std_logic_vector;
        cnt_out7 : out std_logic_vector;
        cnt_out8 : out std_logic_vector;
        cnt_out9 : out std_logic_vector;
        cnt_out10 : out std_logic_vector;
        cnt_out11 : out std_logic_vector;
        cnt_out12 : out std_logic_vector;
        cnt_out13 : out std_logic_vector;
        cnt_out14 : out std_logic_vector;
        cnt_out15 : out std_logic_vector;

        pulse_in : in std_logic;
        pulse_out : out std_logic;

        clock : in std_logic

        );
    end component;

  begin

    sorter16_inst : sorter16
      generic map (
        MXADRB => clusters_i(0).adr'length,
        MXCNTB => clusters_i(0).cnt'length,
        MXPRTB => clusters_i(0).prt'length,
        MXVPFB => 1,
        SKIPB  => clusters_i(0).cnt'length -- don't sort on the count bits
        )
      port map (
        clock => clock,

        pulse_in  => latch_i,
        pulse_out => latch_o,

        adr_in0  => clusters_i(0).adr,
        adr_in1  => clusters_i(1).adr,
        adr_in2  => clusters_i(2).adr,
        adr_in3  => clusters_i(3).adr,
        adr_in4  => clusters_i(4).adr,
        adr_in5  => clusters_i(5).adr,
        adr_in6  => clusters_i(6).adr,
        adr_in7  => clusters_i(7).adr,
        adr_in8  => clusters_i(8).adr,
        adr_in9  => clusters_i(9).adr,
        adr_in10 => clusters_i(10).adr,
        adr_in11 => clusters_i(11).adr,
        adr_in12 => clusters_i(12).adr,
        adr_in13 => clusters_i(13).adr,
        adr_in14 => clusters_i(14).adr,
        adr_in15 => clusters_i(15).adr,

        vpf_in0(0)  => clusters_i(0).vpf,
        vpf_in1(0)  => clusters_i(1).vpf,
        vpf_in2(0)  => clusters_i(2).vpf,
        vpf_in3(0)  => clusters_i(3).vpf,
        vpf_in4(0)  => clusters_i(4).vpf,
        vpf_in5(0)  => clusters_i(5).vpf,
        vpf_in6(0)  => clusters_i(6).vpf,
        vpf_in7(0)  => clusters_i(7).vpf,
        vpf_in8(0)  => clusters_i(8).vpf,
        vpf_in9(0)  => clusters_i(9).vpf,
        vpf_in10(0) => clusters_i(10).vpf,
        vpf_in11(0) => clusters_i(11).vpf,
        vpf_in12(0) => clusters_i(12).vpf,
        vpf_in13(0) => clusters_i(13).vpf,
        vpf_in14(0) => clusters_i(14).vpf,
        vpf_in15(0) => clusters_i(15).vpf,

        cnt_in0  => clusters_i(0).cnt,
        cnt_in1  => clusters_i(1).cnt,
        cnt_in2  => clusters_i(2).cnt,
        cnt_in3  => clusters_i(3).cnt,
        cnt_in4  => clusters_i(4).cnt,
        cnt_in5  => clusters_i(5).cnt,
        cnt_in6  => clusters_i(6).cnt,
        cnt_in7  => clusters_i(7).cnt,
        cnt_in8  => clusters_i(8).cnt,
        cnt_in9  => clusters_i(9).cnt,
        cnt_in10 => clusters_i(10).cnt,
        cnt_in11 => clusters_i(11).cnt,
        cnt_in12 => clusters_i(12).cnt,
        cnt_in13 => clusters_i(13).cnt,
        cnt_in14 => clusters_i(14).cnt,
        cnt_in15 => clusters_i(15).cnt,

        prt_in0  => clusters_i(0).prt,
        prt_in1  => clusters_i(1).prt,
        prt_in2  => clusters_i(2).prt,
        prt_in3  => clusters_i(3).prt,
        prt_in4  => clusters_i(4).prt,
        prt_in5  => clusters_i(5).prt,
        prt_in6  => clusters_i(6).prt,
        prt_in7  => clusters_i(7).prt,
        prt_in8  => clusters_i(8).prt,
        prt_in9  => clusters_i(9).prt,
        prt_in10 => clusters_i(10).prt,
        prt_in11 => clusters_i(11).prt,
        prt_in12 => clusters_i(12).prt,
        prt_in13 => clusters_i(13).prt,
        prt_in14 => clusters_i(14).prt,
        prt_in15 => clusters_i(15).prt,

        adr_out0  => clusters_o(0).adr,
        adr_out1  => clusters_o(1).adr,
        adr_out2  => clusters_o(2).adr,
        adr_out3  => clusters_o(3).adr,
        adr_out4  => clusters_o(4).adr,
        adr_out5  => clusters_o(5).adr,
        adr_out6  => clusters_o(6).adr,
        adr_out7  => clusters_o(7).adr,
        adr_out8  => clusters_o(8).adr,
        adr_out9  => clusters_o(9).adr,
        adr_out10 => clusters_o(10).adr,
        adr_out11 => clusters_o(11).adr,
        adr_out12 => clusters_o(12).adr,
        adr_out13 => clusters_o(13).adr,
        adr_out14 => clusters_o(14).adr,
        adr_out15 => clusters_o(15).adr,

        vpf_out0(0)  => clusters_o(0).vpf,
        vpf_out1(0)  => clusters_o(1).vpf,
        vpf_out2(0)  => clusters_o(2).vpf,
        vpf_out3(0)  => clusters_o(3).vpf,
        vpf_out4(0)  => clusters_o(4).vpf,
        vpf_out5(0)  => clusters_o(5).vpf,
        vpf_out6(0)  => clusters_o(6).vpf,
        vpf_out7(0)  => clusters_o(7).vpf,
        vpf_out8(0)  => clusters_o(8).vpf,
        vpf_out9(0)  => clusters_o(9).vpf,
        vpf_out10(0) => clusters_o(10).vpf,
        vpf_out11(0) => clusters_o(11).vpf,
        vpf_out12(0) => clusters_o(12).vpf,
        vpf_out13(0) => clusters_o(13).vpf,
        vpf_out14(0) => clusters_o(14).vpf,
        vpf_out15(0) => clusters_o(15).vpf,

        cnt_out0  => clusters_o(0).cnt,
        cnt_out1  => clusters_o(1).cnt,
        cnt_out2  => clusters_o(2).cnt,
        cnt_out3  => clusters_o(3).cnt,
        cnt_out4  => clusters_o(4).cnt,
        cnt_out5  => clusters_o(5).cnt,
        cnt_out6  => clusters_o(6).cnt,
        cnt_out7  => clusters_o(7).cnt,
        cnt_out8  => clusters_o(8).cnt,
        cnt_out9  => clusters_o(9).cnt,
        cnt_out10 => clusters_o(10).cnt,
        cnt_out11 => clusters_o(11).cnt,
        cnt_out12 => clusters_o(12).cnt,
        cnt_out13 => clusters_o(13).cnt,
        cnt_out14 => clusters_o(14).cnt,
        cnt_out15 => clusters_o(15).cnt,

        prt_out0  => clusters_o(0).prt,
        prt_out1  => clusters_o(1).prt,
        prt_out2  => clusters_o(2).prt,
        prt_out3  => clusters_o(3).prt,
        prt_out4  => clusters_o(4).prt,
        prt_out5  => clusters_o(5).prt,
        prt_out6  => clusters_o(6).prt,
        prt_out7  => clusters_o(7).prt,
        prt_out8  => clusters_o(8).prt,
        prt_out9  => clusters_o(9).prt,
        prt_out10 => clusters_o(10).prt,
        prt_out11 => clusters_o(11).prt,
        prt_out12 => clusters_o(12).prt,
        prt_out13 => clusters_o(13).prt,
        prt_out14 => clusters_o(14).prt,
        prt_out15 => clusters_o(15).prt
        );

  end generate;

  priority_sort : if (SORTER_TYPE = 2) generate

    function count_ones(slv : std_logic_vector) return natural is
      variable n_ones : natural := 0;
    begin
      for i in slv'range loop
        if slv(i) = '1' then
          n_ones := n_ones + 1;
        end if;
      end loop;
      return n_ones;
    end function count_ones;

    function count_preceeding_ones(slv : std_logic_vector; index : integer) return integer is
    begin
      if (index=0) then
        return 0;
      elsif (index=1) then
        if (slv(0)='1') then
          return 1;
        else
          return 0;
        end if;
      else
        return count_ones(slv(index-1 downto 0));
      end if;
    end function;

    function is_nth (ibit    : integer;
                     iclst   : integer;
                     cnt     : integer;
                     hitmask : std_logic_vector)
      return std_logic is
    begin
      if (iclst=0 and ibit=0 and hitmask(0)='1') then
        return '1';
      elsif (ibit > 0) then
        if (hitmask(ibit)='1' and cnt=iclst) then
          -- assert false report "iclst=" & integer'image(iclst)
          --   & " ibit=" & integer'image(ibit)
          --   & " icnt=" & integer'image(cnt)
          --   --& " data=" & vec2str(hitmask)
          --   severity note;
          return '1';
        else
          return '0';
        end if;
      end if;
      return '0';
    end;

    function get_lsb(hitmask : std_logic_vector)
      return integer is
    begin
      for I in 0 to hitmask'length-1 loop
        if (hitmask(I) = '1') then
          return I;
        end if;
      end loop;
      return 16;
    end;

    signal hitmask, hitmask_s1 : std_logic_vector (clusters_i'length-1 downto 0) := (others => '0');

    type onehot_array_t is array (integer range <>) of std_logic_vector(clusters_i'length-1 downto 0);
    signal onehots : onehot_array_t (clusters_i'length-1 downto 0);

    type int_array_t is array (integer range <>) of integer;
    signal cluster_sel : int_array_t (clusters_o'length-1 downto 0) := (others => 0);

    type cnt_array_t is array (integer range <>) of integer range 0 to 15;
    signal counts : cnt_array_t (clusters_o'length-1 downto 0) := (others => 0);

    signal clusters_s1, clusters_s2, clusters_s3 :
      sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
    signal latch_s1, latch_s2, latch_s3 :
      std_logic := '0';

  begin

    assert '0' = is_nth(0,  0, 0, "0000000000000000") report "is_nth failure 0" severity error;
    assert '1' = is_nth(0,  0, 0, "1000000000000000") report "is_nth failure 1" severity error;
    assert '1' = is_nth(1,  0, 0, "0100000000000000") report "is_nth failure 2" severity error;
    assert '1' = is_nth(1,  1, 1, "1100000000000000") report "is_nth failure 3" severity error;
    assert '1' = is_nth(2,  0, 0, "0010000000000000") report "is_nth failure 4" severity error;
    assert '1' = is_nth(2,  1, 1, "1010000000000000") report "is_nth failure 5" severity error;
    assert '1' = is_nth(15, 0, 0, "0000000000000001") report "is_nth failure 6" severity error;

    assert '0' = is_nth(1,  0, 1, "1100000000000000") report "is_nth failure 7" severity error;
    assert '0' = is_nth(15, 0, 1, "1000000000000001") report "is_nth failure 8" severity error;

    assert '1' = is_nth(4, 0, 0, "0000100010000000") report "is_nth failure 9" severity error;
    assert '0' = is_nth(8, 0, 1, "0000100010000000") report "is_nth failure 10" severity error;
    assert '0' = is_nth(4, 1, 0, "0000100010000000") report "is_nth failure 11" severity error;
    assert '1' = is_nth(8, 1, 1, "0000100010000000") report "is_nth failure 12" severity error;

    -- pack all the vpfs into a single vector
    hitmask_gen : for I in 0 to clusters_i'length-1 generate
      hitmask(I)    <= clusters_i(I).vpf;
      hitmask_s1(I) <= clusters_s1(I).vpf;
    end generate;

    cnts_gen : for I in 1 to clusters_i'length-1 generate
      process (clock) is
      begin
        if (rising_edge(clock)) then
          counts(I) <= count_preceeding_ones(hitmask, I);
        end if;
      end process;
    end generate;

    onehots_gen_i : for iclst in 0 to clusters_i'length-1 generate
      onehots_gen_j : for ibit in 0 to clusters_i'length-1 generate
        process (clock) is
        begin
          if (rising_edge(clock)) then
            onehots(iclst)(ibit) <= is_nth(ibit, iclst, counts(ibit), hitmask_s1);
          end if;
        end process;
      end generate;
    end generate;

    sel_gen : for I in 0 to clusters_i'length-1 generate
      process (clock) is
      begin
        if (rising_edge(clock)) then
          cluster_sel(I) <= get_lsb(onehots(I));
        end if;
      end process;
    end generate;

    process (clock) is
    begin
      if (rising_edge(clock)) then

        --
        clusters_s1  <= clusters_i;
        clusters_s2  <= clusters_s1;
        clusters_s3  <= clusters_s2;

        --
        latch_s1 <= latch_i;
        latch_s2 <= latch_s1;
        latch_s3 <= latch_s2;
        latch_o  <= latch_s3;

      end if;
    end process;

    -- mux together the outputs
    cluster_out_gen : for I in 0 to clusters_o'length-1 generate
      process (clock) is
      begin
        if (rising_edge(clock)) then
          if (cluster_sel(I)=16)  then -- fixme: only need to check the msb
            clusters_o(I) <= NULL_CLUSTER;
          else
            clusters_o(I) <= clusters_s3(cluster_sel(I));
          end if;
        end if;
      end process;
    end generate;

  end generate;

end behavioral;
