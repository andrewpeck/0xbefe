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
    clk_i            : in  std_logic; -- 80 MHz clock for the sem core
    sysclk_i         : in  std_logic; -- 40 MHz wishbone clock
    inject_strobe    : in  std_logic;
    inject_address   : in  std_logic_vector(39 downto 0);
    alive_o          : out std_logic;
    initialization_o : out std_logic;
    observation_o    : out std_logic;
    correction_o     : out std_logic;
    classification_o : out std_logic;
    injection_o      : out std_logic;
    essential_o      : out std_logic;
    uncorrectable_o  : out std_logic;

    correction_pulse_o    : out std_logic;
    uncorrectable_pulse_o : out std_logic;
    essential_pulse_o     : out std_logic;

    idle_o : out std_logic
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

  signal heartbeat, heartbeat_r : std_logic := '0';

  signal heartbeat_watchdog : integer range 0 to 1023 := 0;

begin

  process (clk_i) is
  begin
    if (rising_edge(clk_i)) then

      heartbeat_r <= heartbeat;

      if (heartbeat_r = '0' and heartbeat='1') then
        heartbeat_watchdog <= 0;
      elsif (heartbeat_watchdog < 1023) then
        heartbeat_watchdog <= heartbeat_watchdog + 1;
      end if;

      if (heartbeat_watchdog = 1023) then
        alive_o <= '0';
      else
        alive_o <= '1';
      end if;

    end if;
  end process;

  --------------------------------------------------------------------------------------------------------------------
  -- Virtex-6
  --------------------------------------------------------------------------------------------------------------------

  sem_gen_v6 : if (FPGA_TYPE = "V6") generate

    -- Virtex 6 SEM IP
    -- https://docs.xilinx.com/v/u/3.4-English/pg036_sem
    --
    -- per pg036, ICAP maximum = 100 MHz
    --

    sem_core_inst : sem
      port map(

        status_heartbeat      => heartbeat,        -- out: The heartbeat signal is active while status_observation is TRUE. This output issues a single-cycle high pulse at least once every 128 clock cycles for 7 series and Virtex-6 devices,
        status_initialization => initialization_o, -- out: The initialization signal is active during controller initialization, which occurs one time after the design begins operation.
        status_observation    => observation_o,    -- out: The observation signal is active during controller observation of error detection signals. This signal remains active after an error detection while the controller queries the hardware for information.
        status_correction     => correction_o,     -- out: The correction signal is active during controller correction of an error or during transition through this controller state if correction is disabled.
        status_classification => classification_o, -- out: The classification signal is active during controller classification of an error or during transition through this controller state if classification is disabled.
        status_injection      => injection_o,      -- out: The injection signal is active during controller injection of an error. When an error injection is complete, and the controller is ready to inject another error or return to observation, this signal returns inactive.
        status_essential      => essential_o,      -- out: The essential signal is an error classification status signal. Prior to exiting the classification state, the controller sets this signal to reflect whether the error occurred on an essential bit(s). Then, the controller exits classification state.
        status_uncorrectable  => uncorrectable_o,  -- out: The uncorrectable signal is an error correction status signal. Prior to exiting the correction state, the controller sets this signal to reflect the correctability of the error. Then, the controller exits correction state.

        monitor_txdata        => open,            -- out: Parallel transmit data from controller
        monitor_txwrite       => open,            -- out: Write strobe, qualifies validity of parallel transmit data.
        monitor_txfull        => '0',             -- in: This signal implements flow control on the transmit channel, from the shim (peripheral) to the controller.
        monitor_rxdata        => (others => '0'), -- in: Parallel receive data from the shim (peripheral).
        monitor_rxread        => open,            -- out: Read strobe, acknowledges receipt of parallel receive data.
        monitor_rxempty       => '1',             -- in: This signal implements flow control on the receive channel, from the shim (peripheral) to the controller.

        fecc_crcerr           => fecc_crcerr,            -- in: Receives CRCERROR output of FRAME_ECC
        fecc_eccerr           => fecc_eccerr,            -- in: Receives ECCERROR output of FRAME_ECC
        fecc_eccerrsingle     => fecc_eccerrsingle,      -- in: Receives ECCERRORSINGLE output of FRAME_ECC.
        fecc_syndromevalid    => fecc_syndromevalid,     -- in: Receives SYNDROMEVALID output of FRAME_ECC.
        fecc_syndrome         => fecc_syndrome,          -- in: Receives SYNDROME output of FRAME_ECC.
        fecc_far              => fecc_far (23 downto 0), -- in: Receives FAR output of FRAME_ECC.
        fecc_synbit           => fecc_synbit,            -- in: Receives SYNBIT output of FRAME_ECC
        fecc_synword          => fecc_synword,           -- in: Receives SYNWORD output of FRAME_ECC

        icap_o                => icap_o,     -- in:  Receives O output of ICAP
        icap_i                => icap_i,     -- out: Drives I input of ICAP.
        icap_busy             => icap_busy,  -- in:  Receives BUSY output of ICAP
        icap_csb              => icap_csb,   -- out: Drives CSB input of ICAP.
        icap_rdwrb            => icap_rdwrb, -- out: Drives RDWRB input of ICAP.
        icap_clk              => clk_i,      -- in:  Receives the clock for the design. This same clock also must be applied to the CLK input of ICAP.
        icap_request          => open,       -- out: This signal is reserved for future use. Leave this port OPEN.
        icap_grant            => '1'         -- in:  Tie this port to VCC.

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
        crcerror       => fecc_crcerr,            -- out: Output indicating a CRC error
        eccerror       => fecc_eccerr,            -- out: Output indicating a ECC error
        eccerrorsingle => fecc_eccerrsingle,      -- out: Indicates single-bit Frame ECC error detected
        far            => fecc_far (23 downto 0), -- out: Frame Address Register Value
        synbit         => fecc_synbit,            -- out: Bit address of error
        syndrome       => fecc_syndrome,          -- out: Output location of erroneous bit
        syndromevalid  => fecc_syndromevalid,     -- out: Frame ECC output indicating the SYNDROME output is valid
        synword        => fecc_synword            -- out: Word in the frame where an ECC error has been detected
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

    -- Artix-7 SEM IP Documentation
    -- https://docs.xilinx.com/v/u/en-US/ds796_sem

    signal status_initialization, status_observation, status_correction,
      status_classification, status_injection, status_essential,
      status_uncorrectable : std_logic;

    signal idle : std_logic;

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

    sem_a7_inst : sem_a7

      port map (
        status_heartbeat      => heartbeat,
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
