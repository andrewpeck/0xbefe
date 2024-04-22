----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- SEM
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.hardware_pkg.all;

entity sem_mon is
  port(
    clk_i            : in  std_logic; -- 80 MHz clock for the SEM core
    sysclk_i         : in  std_logic; -- 40 MHz wishbone clock

    -- SEM state
    idle_o           : out std_logic;
    initialization_o : out std_logic;
    observation_o    : out std_logic;
    heartbeat_o      : out std_logic;
    correction_o     : out std_logic;
    uncorrectable_o  : out std_logic;
    classification_o : out std_logic;
    essential_o      : out std_logic;
    injection_o      : out std_logic;

    -- injection interface
    inject_strobe    : in  std_logic;
    inject_address   : in  std_logic_vector(39 downto 0);

    -- action events
    correction_pulse_o    : out std_logic;
    uncorrectable_pulse_o : out std_logic;
    essential_pulse_o     : out std_logic
    );
end sem_mon;

architecture behavioral of sem_mon is

  component sem
    port(
      status_heartbeat      : out std_logic;
      status_initialization : out std_logic;
      status_observation    : out std_logic;
      status_correction     : out std_logic;
      status_classification : out std_logic;
      status_injection      : out std_logic;
      status_essential      : out std_logic;
      status_uncorrectable  : out std_logic;
      monitor_txdata        : out std_logic_vector(7 downto 0);
      monitor_txwrite       : out std_logic;
      monitor_txfull        : in  std_logic;
      monitor_rxdata        : in  std_logic_vector(7 downto 0);
      monitor_rxread        : out std_logic;
      monitor_rxempty       : in  std_logic;
      icap_busy             : in  std_logic;
      icap_o                : in  std_logic_vector(31 downto 0);
      icap_csb              : out std_logic;
      icap_rdwrb            : out std_logic;
      icap_i                : out std_logic_vector(31 downto 0);
      icap_clk              : in  std_logic;
      icap_request          : out std_logic;
      icap_grant            : in  std_logic;
      fecc_crcerr           : in  std_logic;
      fecc_eccerr           : in  std_logic;
      fecc_eccerrsingle     : in  std_logic;
      fecc_syndromevalid    : in  std_logic;
      fecc_syndrome         : in  std_logic_vector(12 downto 0);
      fecc_far              : in  std_logic_vector(23 downto 0);
      fecc_synbit           : in  std_logic_vector(4 downto 0);
      fecc_synword          : in  std_logic_vector(6 downto 0)
      );
  end component;

  component sem_a7
    port (
      status_heartbeat      : out std_logic;
      status_initialization : out std_logic;
      status_observation    : out std_logic;
      status_correction     : out std_logic;
      status_classification : out std_logic;
      status_injection      : out std_logic;
      status_essential      : out std_logic;
      status_uncorrectable  : out std_logic;
      monitor_txdata        : out std_logic_vector(7 downto 0);
      monitor_txwrite       : out std_logic;
      monitor_txfull        : in  std_logic;
      monitor_rxdata        : in  std_logic_vector(7 downto 0);
      monitor_rxread        : out std_logic;
      monitor_rxempty       : in  std_logic;
      inject_strobe         : in  std_logic;
      inject_address        : in  std_logic_vector(39 downto 0);
      icap_o                : in  std_logic_vector(31 downto 0);
      icap_csib             : out std_logic;
      icap_rdwrb            : out std_logic;
      icap_i                : out std_logic_vector(31 downto 0);
      icap_clk              : in  std_logic;
      icap_request          : out std_logic;
      icap_grant            : in  std_logic;
      fecc_crcerr           : in  std_logic;
      fecc_eccerr           : in  std_logic;
      fecc_eccerrsingle     : in  std_logic;
      fecc_syndromevalid    : in  std_logic;
      fecc_syndrome         : in  std_logic_vector(12 downto 0);
      fecc_far              : in  std_logic_vector(25 downto 0);
      fecc_synbit           : in  std_logic_vector(4 downto 0);
      fecc_synword          : in  std_logic_vector(6 downto 0)
      );
  end component;

  signal icap_o     : std_logic_vector(31 downto 0);
  signal icap_i     : std_logic_vector(31 downto 0);
  signal icap_busy  : std_logic;
  signal icap_csb   : std_logic;
  signal icap_rdwrb : std_logic;

  signal fecc_crcerr        : std_logic;
  signal fecc_eccerr        : std_logic;
  signal fecc_eccerrsingle  : std_logic;
  signal fecc_syndromevalid : std_logic;
  signal fecc_syndrome      : std_logic_vector(12 downto 0);
  signal fecc_far           : std_logic_vector(25 downto 0);
  signal fecc_synbit        : std_logic_vector(4 downto 0);
  signal fecc_synword       : std_logic_vector(6 downto 0);

begin

  --------------------------------------------------------------------------------------------------------------------
  -- Virtex-6
  --------------------------------------------------------------------------------------------------------------------

  g_sem_v6 : if (FPGA_TYPE = "V6") generate

    -- SEM IP Core v3.1 Documentation
    -- https://docs.amd.com/v/u/en-US/ug764_sem
    i_sem_core_v6 : sem
      port map(
        status_heartbeat      => heartbeat_o,
        status_initialization => initialization_o,
        status_observation    => observation_o,
        status_correction     => correction_o,
        status_classification => classification_o,
        status_injection      => injection_o,
        status_essential      => essential_o,
        status_uncorrectable  => uncorrectable_o,

        monitor_txdata        => open,
        monitor_txwrite       => open,
        monitor_txfull        => '0',
        monitor_rxdata        => (others => '0'),
        monitor_rxread        => open,
        monitor_rxempty       => '1',

        icap_o                => icap_o,
        icap_i                => icap_i,
        icap_busy             => icap_busy,
        icap_csb              => icap_csb,
        icap_rdwrb            => icap_rdwrb,
        icap_clk              => clk_i,
        icap_request          => open,
        icap_grant            => '1',

        fecc_crcerr           => fecc_crcerr,
        fecc_eccerr           => fecc_eccerr,
        fecc_eccerrsingle     => fecc_eccerrsingle,
        fecc_syndromevalid    => fecc_syndromevalid,
        fecc_syndrome         => fecc_syndrome,
        fecc_far              => fecc_far (23 downto 0),
        fecc_synbit           => fecc_synbit,
        fecc_synword          => fecc_synword
        );

    --==========--
    --== ICAP ==--
    --==========--

    i_icap : ICAP_VIRTEX6
      generic map (
        DEVICE_ID         => x"ffff_ffff",
        ICAP_WIDTH        => "x32",
        SIM_CFG_FILE_NAME => "NONE"
        )
      port map (
        busy  => icap_busy,
        o     => icap_o,
        clk   => clk_i,
        csb   => icap_csb,
        i     => icap_i,
        rdwrb => icap_rdwrb
        );

    --===============--
    --== FRAME_ECC ==--
    --===============--

    i_frame_ecc : FRAME_ECC_VIRTEX6
      generic map (
        FARSRC                => "EFAR",
        FRAME_RBT_IN_FILENAME => "NONE"
        )
      port map (
        crcerror       => fecc_crcerr,
        eccerror       => fecc_eccerr,
        eccerrorsingle => fecc_eccerrsingle,
        far            => fecc_far (23 downto 0),
        synbit         => fecc_synbit,
        syndrome       => fecc_syndrome,
        syndromevalid  => fecc_syndromevalid,
        synword        => fecc_synword
        );

  end generate g_sem_v6;

  --------------------------------------------------------------------------------------------------------------------
  -- Artix-7
  --------------------------------------------------------------------------------------------------------------------

  g_sem_a7 : if (FPGA_TYPE = "A7") generate

    signal status_initialization, status_observation, status_correction,
      status_classification, status_injection, status_essential,
      status_uncorrectable  : std_logic;

    signal idle             : std_logic;

    signal correction_r     : std_logic;
    signal uncorrectable_r  : std_logic;
    signal essential_r      : std_logic;
    signal inject_strobe_r  : std_logic := '0';
    signal inject_strobe_os : std_logic := '0';

  begin

    -- The error injection control is used to indicate an error injection
    -- request. The inject_strobe signal should be pulsed high for one cycle,
    -- synchronous to icap_clk, concurrent with the application of a valid
    -- address to the inject_address input. The error injection control must
    -- only be used when the controller is idle

    idle <= not (status_initialization or status_observation or
                 status_correction or status_classification or status_injection);

    initialization_o <= status_initialization;
    observation_o    <= status_observation;
    correction_o     <= status_correction;
    classification_o <= status_classification;
    injection_o      <= status_injection;
    essential_o      <= status_essential;
    uncorrectable_o  <= status_uncorrectable;
    idle_o           <= idle;

    -- for counting, make rising edge sensitive versions of these signals
    process (sysclk_i) is
    begin
      if (rising_edge(sysclk_i)) then
        correction_r    <= status_correction;
        uncorrectable_r <= status_uncorrectable;
        essential_r     <= status_essential;
      end if;
    end process;

    process (clk_i) is
    begin
      if (rising_edge(clk_i)) then
        inject_strobe_r <= inject_strobe;
      end if;
    end process;

    inject_strobe_os <= '1' when inject_strobe_r = '0' and inject_strobe = '1' else '0';

    correction_pulse_o    <= '1' when correction_r = '0' and status_correction = '1'       else '0';
    uncorrectable_pulse_o <= '1' when uncorrectable_r = '0' and status_uncorrectable = '1' else '0';
    essential_pulse_o     <= '1' when essential_r = '0' and status_essential = '1'         else '0';

    -- SEM IP Core v4.1 Documentation
    -- https://docs.amd.com/r/en-US/pg036_sem
    i_sem_core_a7 : sem_a7
      port map (
        status_heartbeat      => heartbeat_o,
        status_initialization => status_initialization,
        status_observation    => status_observation,
        status_correction     => status_correction,
        status_classification => status_classification,
        status_injection      => status_injection,
        status_essential      => status_essential,
        status_uncorrectable  => status_uncorrectable,

        monitor_txdata        => open,
        monitor_txwrite       => open,
        monitor_txfull        => '0',
        monitor_rxdata        => (others => '0'),
        monitor_rxread        => open,
        monitor_rxempty       => '1',

        inject_strobe         => inject_strobe_os,
        inject_address        => inject_address,

        icap_o                => icap_o,
        icap_i                => icap_i,
        icap_csib             => icap_csb,
        icap_rdwrb            => icap_rdwrb,
        icap_clk              => clk_i,
        icap_request          => open,
        icap_grant            => '1',

        fecc_crcerr           => fecc_crcerr,
        fecc_eccerr           => fecc_eccerr,
        fecc_eccerrsingle     => fecc_eccerrsingle,
        fecc_syndromevalid    => fecc_syndromevalid,
        fecc_syndrome         => fecc_syndrome,
        fecc_far              => fecc_far (25 downto 0),
        fecc_synbit           => fecc_synbit,
        fecc_synword          => fecc_synword
        );

    --==========--
    --== ICAP ==--
    --==========--

    i_icap : ICAPE2
      generic map (
        DEVICE_ID         => x"03651093",
        ICAP_WIDTH        => "x32",
        SIM_CFG_FILE_NAME => "NONE"
        )
      port map (
        o     => icap_o,
        clk   => clk_i,
        csib  => icap_csb,
        i     => icap_i,
        rdwrb => icap_rdwrb
        );

    --===============--
    --== FRAME_ECC ==--
    --===============--

    i_frame_ecc : FRAME_ECCE2
      generic map (
        FARSRC                => "EFAR",
        FRAME_RBT_IN_FILENAME => "NONE"
        )
      port map (
        crcerror       => fecc_crcerr,
        eccerror       => fecc_eccerr,
        eccerrorsingle => fecc_eccerrsingle,
        far            => fecc_far,
        synbit         => fecc_synbit,
        syndrome       => fecc_syndrome,
        syndromevalid  => fecc_syndromevalid,
        synword        => fecc_synword
        );

  end generate g_sem_a7;

end behavioral;
