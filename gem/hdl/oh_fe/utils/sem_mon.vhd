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
    clk_i            : in  std_logic;
    inject_strobe    : in  std_logic;
    inject_address   : in  std_logic_vector(39 downto 0);
    heartbeat_o      : out std_logic;
    initialization_o : out std_logic;
    observation_o    : out std_logic;
    correction_o     : out std_logic;
    classification_o : out std_logic;
    injection_o      : out std_logic;
    essential_o      : out std_logic;
    uncorrectable_o  : out std_logic
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

  signal fecc_crcerr        : std_logic;
  signal fecc_eccerr        : std_logic;
  signal fecc_eccerrsingle  : std_logic;
  signal fecc_syndromevalid : std_logic;
  signal fecc_syndrome      : std_logic_vector(12 downto 0);
  signal fecc_far           : std_logic_vector(25 downto 0);
  signal fecc_synbit        : std_logic_vector(4 downto 0);
  signal fecc_synword       : std_logic_vector(6 downto 0);

  signal icap_o     : std_logic_vector(31 downto 0);
  signal icap_i     : std_logic_vector(31 downto 0);
  signal icap_busy  : std_logic;
  signal icap_csb   : std_logic;
  signal icap_rdwrb : std_logic;

begin

  --------------------------------------------------------------------------------------------------------------------
  -- Virtex-6
  --------------------------------------------------------------------------------------------------------------------

  sem_gen_v6 : if (FPGA_TYPE = "V6") generate
    sem_core_inst : sem
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
        fecc_crcerr           => fecc_crcerr,
        fecc_eccerr           => fecc_eccerr,
        fecc_eccerrsingle     => fecc_eccerrsingle,
        fecc_syndromevalid    => fecc_syndromevalid,
        fecc_syndrome         => fecc_syndrome,
        fecc_far              => fecc_far (23 downto 0),
        fecc_synbit           => fecc_synbit,
        fecc_synword          => fecc_synword,
        icap_o                => icap_o,
        icap_i                => icap_i,
        icap_busy             => icap_busy,
        icap_csb              => icap_csb,
        icap_rdwrb            => icap_rdwrb,
        icap_clk              => clk_i,
        icap_request          => open,
        icap_grant            => '1'
        );

    --==========--
    --== fecc ==--
    --==========--

    frame_ecc_inst : frame_ecc_virtex6
      generic map (
        frame_rbt_in_filename => "None",
        farsrc                => "EFAR"
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


    --==========--
    --== ICAP ==--
    --==========--

    icap_inst : icap_virtex6
      generic map (
        sim_cfg_file_name => "None",
        DEVICE_ID         => x"ffff_ffff",
        icap_width        => "x32"
        )
      port map (
        busy  => icap_busy,
        o     => icap_o,
        clk   => clk_i,
        csb   => icap_csb,
        i     => icap_i,
        rdwrb => icap_rdwrb
        );

  end generate sem_gen_v6;

  --------------------------------------------------------------------------------------------------------------------
  -- Artix-7
  --------------------------------------------------------------------------------------------------------------------

  sem_gen_a7 : if (FPGA_TYPE = "A7") generate

    sem_a7_inst : sem_a7

      port map (
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
        inject_strobe         => inject_strobe,
        inject_address        => inject_address,
        icap_o                => icap_o,
        icap_csib             => icap_csb,
        icap_rdwrb            => icap_rdwrb,
        icap_i                => icap_i,
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


    ICAPE2_inst : ICAPE2
      generic map (
        DEVICE_ID         => X"03651093",  -- Specifies the pre-programmed Device ID value to be used for simulation purposes.
        ICAP_WIDTH        => "X32",        -- Specifies the input and output data width.
        SIM_CFG_FILE_NAME => "NONE"        -- Specifies the Raw Bitstream (RBT) file to be parsed by the simulation model.
        )
      port map (
        o     => icap_o,                   -- 32-bit output: configuration data output bus
        clk   => clk_i,                    -- 1-bit input: clock input
        csib  => icap_csb,                 -- 1-bit input: active-low icap enable
        i     => icap_i,                   -- 32-bit input: configuration data input bus
        rdwrb => icap_rdwrb                -- 1-bit input: read/write select input
        );

    FRAME_ECCE2_inst : FRAME_ECCE2
      generic map (
        FARSRC                => "EFAR",       -- Determines if the output of FAR[25:0] configuration register points
        -- to the FAR or EFAR. Sets configuration option register bit CTL0[7].
        FRAME_RBT_IN_FILENAME => "None"        -- This file is output by the ICAP_E2 model and it contains Frame Data
       -- information for the Raw Bitstream (RBT) file. The FRAME_ECCE2 model
       -- will parse this file, calculate ECC and output any error conditions.
        )
      port map (
        crcerror       => fecc_crcerr,         -- 1-bit output: Output indicating a CRC error.
        eccerror       => fecc_eccerr,         -- 1-bit output: Output indicating an ECC error.
        eccerrorsingle => fecc_eccerrsingle,   -- 1-bit output: Output Indicating single-bit Frame ECC error detected.
        far            => fecc_far,            -- 26-bit output: Frame Address Register Value output.
        synbit         => fecc_synbit,         -- 5-bit output: Output bit address of error.
        syndrome       => fecc_syndrome,       -- 13-bit output: Output location of erroneous bit.
        syndromevalid  => fecc_syndromevalid,  -- 1-bit output: Frame ECC output indicating the SYNDROME output is valid.
        synword        => fecc_synword         -- 7-bit output: Word output in the frame where an ECC error has been detected.

        );

  end generate sem_gen_a7;

end behavioral;
