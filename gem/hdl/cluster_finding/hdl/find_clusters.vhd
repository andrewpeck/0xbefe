library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.cluster_pkg.all;

entity find_clusters is
  generic (
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

  sorter : if (true) generate

    constant size : integer := 1+MXADRB+MXCNTB+MXPRTB;

    signal data_i, data_o : std_logic_vector (NUM_FOUND_CLUSTERS*SIZE-1 downto 0) := (others => '0');

  begin

    checker : for I in 0 to NUM_FOUND_CLUSTERS generate
      -- just some simple sanity checking for the simulator

      -- make sure that every higher numbered cluster is worse or equal quality
      worseloop : for J in I+1 to NUM_FOUND_CLUSTERS-1 generate

        -- pragma translate_off
        -- check vpf sorting
        assert clusters(I).vpf >= clusters(J).vpf report
          "vpf(" & integer'image(I) & ") = " & std_logic'image(clusters(I).vpf) & ";  " &
          "vpf(" & integer'image(J) & ") = " & std_logic'image(clusters(J).vpf)
          severity error;

        -- for equal vpf, use the greater partition (lower eta)
        prt_sort_check : if (clusters(I).vpf = '1' and (clusters(I).vpf = clusters(J).vpf)) generate
          assert clusters(I).prt >= clusters(J).prt report
            "vpf(" & integer'image(I) & ") = " & std_logic'image(clusters(I).vpf) & " " &
            "prt(" & integer'image(I) & ") = " & integer'image(to_integer(unsigned(clusters(I).prt))) & ";  " &
            "prt(" & integer'image(J) & ") = " & integer'image(to_integer(unsigned(clusters(J).prt))) & " " &
            "vpf(" & integer'image(J) & ") = " & std_logic'image(clusters(J).vpf)
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

end behavioral;
