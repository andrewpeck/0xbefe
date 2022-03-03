library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.cluster_pkg.all;

entity find_clusters is
  generic (
    SORTER_TYPE        : integer := 1;
    MXSBITS            : integer := 64;
    NUM_VFATS          : integer := 24;
    NUM_FOUND_CLUSTERS : integer := 0;
    STATION            : integer := 0
    );
  port (
    clock : in std_logic;

    latch_i : in std_logic;             -- this should go high when new vpfs are ready and stay high for just 1 clock

    vpfs_i : in std_logic_vector (MXSBITS*NUM_VFATS -1 downto 0);
    cnts_i : in std_logic_vector (MXSBITS*NUM_VFATS*3-1 downto 0);

    clusters_o : out sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

    latch_o : out std_logic := '0'      -- this should go high when new vpfs are ready and stay high for just 1 clock
    );
end find_clusters;

architecture behavioral of find_clusters is

  function if_then_else (bool : boolean; a : integer; b : integer) return integer is
  begin
    if (bool) then
      return a;
    else
      return b;
    end if;
  end if_then_else;

  constant ENCODER_SIZE : integer := if_then_else(station = 0 or station = 1, 384, 192);

  -- std_logic_vector to integer
  function int (vec : std_logic_vector) return integer is
  begin
    return to_integer(unsigned(vec));
  end int;

  function to_cnt (cnt : std_logic_vector; vpf : std_logic)
    return std_logic_vector is
  begin
    if (vpf = '1') then
      return cnt;
    else
      return "111";
    end if;
  end to_cnt;

  function to_address (station : integer; encoder : integer; adr : std_logic_vector; vpf : std_logic)
    return std_logic_vector is
  begin

    -- ME0 + GE11
    if (station = 1 or station = 0) then
      if (vpf = '0') then
        return '1' & x"FF";             -- FIXME: this should only be 8 bits for GE11
      elsif (int(adr) > 191) then
        return std_logic_vector(to_unsigned(int(adr)-192, adr'length));
      else
        return adr;
      end if;

    -- GE21
    elsif (station = 2) then
      if (vpf = '0') then
        return '1' & x"FF";
      else
        if (ENCODER_SIZE = 384) then
          return adr;
        elsif (ENCODER_SIZE = 192) then
          if (encoder = 1 or encoder = 3) then
            return std_logic_vector(to_unsigned(int(adr)+192, adr'length));
          else
            return adr;
          end if;
        else
          assert false report "Invalid encoder size selected for GE21" severity error;
          return adr;
        end if;
      end if;
    else
      return '1' & x"FF";
    end if;

  end to_address;

  function to_partition (station : integer; encoder : integer; adr : std_logic_vector; vpf : std_logic) return std_logic_vector is
    variable odd : integer;
    variable prt : integer;
  begin
    if (vpf = '0') then
      prt := 7;
    else
      if (station = 2) then
        if (ENCODER_SIZE = 384) then
          prt := encoder;
        elsif (ENCODER_SIZE = 192) then
          if (encoder = 0 or encoder = 1) then
            prt := 0;
          else
            prt := 1;
          end if;
        else
          assert false report "Invalid encoder size selected for GE21" severity error;
        end if;
      else
        if (int(adr) > 191) then
          odd := 1;
        else
          odd := 0;
        end if;
        prt := odd + encoder*2;
      end if;
    end if;
    return std_logic_vector(to_unsigned(prt, MXPRTB));
  end to_partition;


  --------------------------------------------------------------------------------
  -- Signals
  --------------------------------------------------------------------------------

  signal clusters_s1  : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0) := (others => NULL_CLUSTER);
  signal latch_out_s1 : std_logic_vector (NUM_ENCODERS-1 downto 0)           := (others => '0');

begin

  -- GE2/1 uses 1 384 bit encoder per partition
  -- 2 partitions total, returning 4 or 5 clusters / clock from each partition
  -- 2 encoders total
  -- 8 or 10 clusters total, depending on 160MHz or 200MHz clock (200M not supported right now but is possible)
  --
  -- GE1/1 uses 1 384 bit encoder per TWO partitions
  -- 8 partitions total, returning 4 or 5 clusters / clock from each di-partition
  -- 4 encoders total
  -- 16 clusters total

  --                _____   _____   _____   _____   _____   _____   _____   _____
  -- clk_in      ___|   |___|   |___|   |___|   |___|   |___|   |___|   |___|   |
  --                 _______________________________
  -- data_in     ___/                               \____________________________
  --                _________
  -- valid_in    ___|       |____________________________________________________
  --                         _______________________________
  -- data_trunc  ___________/                               \____________________
  --                        _________
  -- valid_trunc ___________|       |____________________________________________
  --
  -- cycle_trunc            |  Zero | One   | Two   | Three |
  --                                                              _________
  -- valid_prior            ----priority encoder pipline stages-->|       |_______
  --
  -- cycle_prior                                                  |  Zero | One

  encoder_gen : for I in 0 to (NUM_ENCODERS-1) generate

    signal truncator_cycle : std_logic_vector (2 downto 0)                := (others => '0');
    signal encoder_cycle   : std_logic_vector (2 downto 0)                := (others => '0');
    signal clusters_buf    : sbit_cluster_array_t (NUM_CYCLES-1 downto 0) := (others => NULL_CLUSTER);

    signal adr_enc : std_logic_vector(MXADRB-1 downto 0) := (others => '0');
    signal cnt_enc : std_logic_vector(MXCNTB-1 downto 0) := (others => '0');
    signal vpf_enc : std_logic                           := '0';

    signal vpfs_truncated : std_logic_vector (ENCODER_SIZE-1 downto 0) := (others => '0');

    signal cnts_dly : std_logic_vector (ENCODER_SIZE*3-1 downto 0) := (others => '0');

    component priority_n
      generic (
        MXKEYBITS : integer;
        MXKEYS    : integer;
        MXCNTB    : integer
        );
      port (
        clock  : in  std_logic;
        pass_i : in  std_logic_vector;
        vpfs_i : in  std_logic_vector;
        cnts_i : in  std_logic_vector;
        pass_o : out std_logic_vector;
        cnt_o  : out std_logic_vector;
        adr_o  : out std_logic_vector;
        vpf_o  : out std_logic
        );
    end component;

  begin

    process (clock)
    begin
      if (rising_edge(clock)) then
        cnts_dly <= cnts_i (ENCODER_SIZE*MXCNTB*(I+1)-1 downto ENCODER_SIZE*MXCNTB*I);
      end if;
    end process;

    -- parameterizable width truncator
    ----------------------------
    truncate_lsb_inst : entity work.truncate_lsb
      generic map (
        WIDTH    => ENCODER_SIZE,
        SEGMENTS => 12
        )
      port map (
        clock   => clock,
        latch   => latch_i,
        cycle_o => truncator_cycle,
        data_i  => vpfs_i (ENCODER_SIZE*(I+1)-1 downto ENCODER_SIZE*I),
        data_o  => vpfs_truncated (ENCODER_SIZE-1 downto 0)
        );

    -- n-bit priority encoder
    ----------------------------
    priority_inst : priority_n
      generic map (
        MXKEYS    => ENCODER_SIZE,
        MXCNTB    => MXCNTB,
        MXKEYBITS => MXADRB
        )
      port map (
        clock  => clock,
        pass_i => truncator_cycle,
        pass_o => encoder_cycle,
        vpfs_i => vpfs_truncated,
        cnts_i => cnts_dly,
        cnt_o  => cnt_enc,
        adr_o  => adr_enc,
        vpf_o  => vpf_enc
        );

    process (clock)
    begin
      -- GE1/1 handles 2 partitions per encoder, need to subtract 192 and add +1 to ienc
      -- if (adr>191) adr = adr-192
      -- if (adr>191) prt = prt + 1
      if (rising_edge(clock)) then
        clusters_buf(int(encoder_cycle)).adr <= to_address(station, I, adr_enc, vpf_enc);
        clusters_buf(int(encoder_cycle)).cnt <= to_cnt (cnt_enc, vpf_enc);
        clusters_buf(int(encoder_cycle)).prt <= to_partition (station, I, adr_enc, vpf_enc);
        clusters_buf(int(encoder_cycle)).vpf <= vpf_enc;
      end if;

      -- latch outputs of priority encoder when it produces its results, stable for sorter
      if (rising_edge(clock)) then
        if (int(encoder_cycle) = 0) then
          latch_out_s1(I)                                      <= '1';
          clusters_s1 ((I+1)*NUM_CYCLES-1 downto NUM_CYCLES*I) <= clusters_buf(NUM_CYCLES-1 downto 0);
        else
          latch_out_s1(I) <= '0';
        end if;
      end if;
    end process;

  end generate;

  ---------------------------------------------------------------------------------------------------------------------
  -- Cluster Sorter
  --------------------------------------------------------------------------------------------------------------------

  -- we get up to 16 clusters / bx but only get to send a few so we put them in order of priority
  -- (should choose lowest addr first--- highest addr is invalid)

  bitonic_sorter : if (sorter_type=0) generate

    constant size : integer := 1+MXADRB+MXCNTB+MXPRTB;

    signal data_i, data_o : std_logic_vector (NUM_FOUND_CLUSTERS*SIZE-1 downto 0) := (others => '0');

  begin

    checker : for I in 0 to NUM_FOUND_CLUSTERS generate
      -- just some simple sanity checking for the simulator

      -- make sure that every higher numbered cluster is worse or equal quality
      worseloop : for J in I+1 to NUM_FOUND_CLUSTERS-1 generate

        -- pragma translate_off
        -- check vpf sorting
        assert clusters_o(I).vpf >= clusters_o(J).vpf report
          "vpf(" & integer'image(I) & ") = " & std_logic'image(clusters_o(I).vpf) & ";  " &
          "vpf(" & integer'image(J) & ") = " & std_logic'image(clusters_o(J).vpf)
          severity error;

        -- for equal vpf, use the greater partition (lower eta)
        prt_sort_check : if (clusters_o(I).vpf = '1' and (clusters_o(I).vpf = clusters_o(J).vpf)) generate
          assert clusters_o(I).prt >= clusters_o(J).prt report
            "vpf(" & integer'image(I) & ") = " & std_logic'image(clusters_o(I).vpf) & " " &
            "prt(" & integer'image(I) & ") = " & integer'image(to_integer(unsigned(clusters_o(I).prt))) & ";  " &
            "prt(" & integer'image(J) & ") = " & integer'image(to_integer(unsigned(clusters_o(J).prt))) & " " &
            "vpf(" & integer'image(J) & ") = " & std_logic'image(clusters_o(J).vpf)
            severity error;
        end generate;
        -- pragma translate_on

      end generate;

    end generate;

    wrapup : for I in 0 to NUM_FOUND_CLUSTERS-1 generate
      constant hi : integer := size*(I+1)-1;
      constant lo : integer := size*(I);
    begin
      data_i (hi downto lo) <= clusters_s1(I).cnt & clusters_s1(I).adr & clusters_s1(I).vpf & clusters_s1(I).prt;
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
        I_INFO(0) => latch_out_s1(0),
        O_INFO(0) => latch_o
        );

  end generate;

  fast_sorter : if (sorter_type=1) generate

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
        MXADRB => clusters_s1(0).adr'length,
        MXCNTB => clusters_s1(0).cnt'length,
        MXPRTB => clusters_s1(0).prt'length,
        MXVPFB => 1,
        SKIPB  => clusters_s1(0).cnt'length -- don't sort on the count bits
        )
      port map (
        clock => clock,

        pulse_in  => latch_out_s1(0),
        pulse_out => latch_o,

        adr_in0  => clusters_s1(0).adr,
        adr_in1  => clusters_s1(1).adr,
        adr_in2  => clusters_s1(2).adr,
        adr_in3  => clusters_s1(3).adr,
        adr_in4  => clusters_s1(4).adr,
        adr_in5  => clusters_s1(5).adr,
        adr_in6  => clusters_s1(6).adr,
        adr_in7  => clusters_s1(7).adr,
        adr_in8  => clusters_s1(8).adr,
        adr_in9  => clusters_s1(9).adr,
        adr_in10 => clusters_s1(10).adr,
        adr_in11 => clusters_s1(11).adr,
        adr_in12 => clusters_s1(12).adr,
        adr_in13 => clusters_s1(13).adr,
        adr_in14 => clusters_s1(14).adr,
        adr_in15 => clusters_s1(15).adr,

        vpf_in0(0)  => clusters_s1(0).vpf,
        vpf_in1(0)  => clusters_s1(1).vpf,
        vpf_in2(0)  => clusters_s1(2).vpf,
        vpf_in3(0)  => clusters_s1(3).vpf,
        vpf_in4(0)  => clusters_s1(4).vpf,
        vpf_in5(0)  => clusters_s1(5).vpf,
        vpf_in6(0)  => clusters_s1(6).vpf,
        vpf_in7(0)  => clusters_s1(7).vpf,
        vpf_in8(0)  => clusters_s1(8).vpf,
        vpf_in9(0)  => clusters_s1(9).vpf,
        vpf_in10(0) => clusters_s1(10).vpf,
        vpf_in11(0) => clusters_s1(11).vpf,
        vpf_in12(0) => clusters_s1(12).vpf,
        vpf_in13(0) => clusters_s1(13).vpf,
        vpf_in14(0) => clusters_s1(14).vpf,
        vpf_in15(0) => clusters_s1(15).vpf,

        cnt_in0  => clusters_s1(0).cnt,
        cnt_in1  => clusters_s1(1).cnt,
        cnt_in2  => clusters_s1(2).cnt,
        cnt_in3  => clusters_s1(3).cnt,
        cnt_in4  => clusters_s1(4).cnt,
        cnt_in5  => clusters_s1(5).cnt,
        cnt_in6  => clusters_s1(6).cnt,
        cnt_in7  => clusters_s1(7).cnt,
        cnt_in8  => clusters_s1(8).cnt,
        cnt_in9  => clusters_s1(9).cnt,
        cnt_in10 => clusters_s1(10).cnt,
        cnt_in11 => clusters_s1(11).cnt,
        cnt_in12 => clusters_s1(12).cnt,
        cnt_in13 => clusters_s1(13).cnt,
        cnt_in14 => clusters_s1(14).cnt,
        cnt_in15 => clusters_s1(15).cnt,

        prt_in0  => clusters_s1(0).prt,
        prt_in1  => clusters_s1(1).prt,
        prt_in2  => clusters_s1(2).prt,
        prt_in3  => clusters_s1(3).prt,
        prt_in4  => clusters_s1(4).prt,
        prt_in5  => clusters_s1(5).prt,
        prt_in6  => clusters_s1(6).prt,
        prt_in7  => clusters_s1(7).prt,
        prt_in8  => clusters_s1(8).prt,
        prt_in9  => clusters_s1(9).prt,
        prt_in10 => clusters_s1(10).prt,
        prt_in11 => clusters_s1(11).prt,
        prt_in12 => clusters_s1(12).prt,
        prt_in13 => clusters_s1(13).prt,
        prt_in14 => clusters_s1(14).prt,
        prt_in15 => clusters_s1(15).prt,

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

end behavioral;
