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
    STATION            : integer := 0;
    SORTER_TYPE        : integer := 2
    -- use the new sorter for GE11, old sorter for GE21 / ME0 (for now at least..)
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

  constant ENCODER_SIZE : integer := if_then_else(STATION = 0 or STATION = 1, 384, 192);

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

  signal clusters_xencoder  : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0) := (others => NULL_CLUSTER);
  signal latch_out_xencoder : std_logic_vector (NUM_ENCODERS-1 downto 0)           := (others => '0');

begin

  -- GE2/1 uses 1 192 bit encoder per partition
  -- 2 partitions total, 4 / clock from each half-partition
  -- 4 encoders total
  -- 16 clusters total
  --
  -- GE1/1 uses 1 192 bit encoder per TWO partitions
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
          latch_out_xencoder(I)                                      <= '1';
          clusters_xencoder ((I+1)*NUM_CYCLES-1 downto NUM_CYCLES*I) <= clusters_buf(NUM_CYCLES-1 downto 0);
        else
          latch_out_xencoder(I) <= '0';
        end if;
      end if;
    end process;

  end generate;

  ---------------------------------------------------------------------------------------------------------------------
  -- Cluster Sorter
  --------------------------------------------------------------------------------------------------------------------

  -- we get up to 16 clusters / bx but only get to send a few so we put them in order of priority
  -- (should choose lowest addr first--- highest addr is invalid)

  sort_clusters_inst : entity work.sort_clusters
    generic map (
      SORTER_TYPE        => SORTER_TYPE,
      ENCODER_SIZE       => ENCODER_SIZE,
      NUM_FOUND_CLUSTERS => NUM_FOUND_CLUSTERS
      )
    port map (
      clock      => clock,
      latch_i    => latch_out_xencoder(0),
      clusters_i => clusters_xencoder,
      latch_o    => latch_o,
      clusters_o => clusters_o
      );

end behavioral;
