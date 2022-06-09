----------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date: 12/13/2016 14:27:30
-- Module Name: CLK_PHASE_CHECK_V7
-- Project Name:
-- Description: This module is a tool to inspect clock phase alignment of two clocks of the same frequency, using ILA.
--              It samples both clocks with a third clock that is phase shifted in steps of ~19ps and records the results in ILA.
--              Note that this module is using Virtex7 primitives, so it won't work on Virtex6
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.VComponents.all;

entity clk_phase_check_v7 is
    generic (
        ROUND_FREQ_MHZ                  : real := 40.000; -- please give a round number e.g. even if the TTC clock is not exactly 40MHz, you should still specify 40.000 here
        EXACT_FREQ_HZ                   : std_logic_vector(31 downto 0) := x"02638e98"; -- exact frequency in Herz, this is only used in counting seconds since last phase jump
        SAMPLING_TIME                   : unsigned(15 downto 0) := x"000a"; -- the number of clock cycles to sample each phase (accuracy should be better with higher number, but higher numbers also make the measurement slower) 
        PHASE_JUMP_THRESH               : unsigned(11 downto 0) := x"06c"; -- phase difference threshold between subsequent measurements to be considered a phase jump
        PHASE_MEAN_WINDOW_SIZE_POW_TWO  : integer := 11; -- the size of the window for phase mean calculation in units of power of 2 (e.g. a value of 11 means 2^11 = 2048)
        ILA_ENABLE                      : boolean := false -- if set to true, an ILA will be instantiated showing the relationship between the two clocks
    );
    port (
        reset_i             : in  std_logic;
        clk1_i              : in  std_logic;
        clk2_i              : in  std_logic;
        phase_o             : out std_logic_vector(11 downto 0); -- phase difference between the rising edges of the two clocks (each count is about 18.6012ps)
        phase_mean_o        : out std_logic_vector(11 downto 0); -- the mean of the phase in the last 2^PHASE_MEAN_WINDOW_SIZE_POW_TWO values
        phase_min_o         : out std_logic_vector(11 downto 0); -- the minimum measured phase value since last reset
        phase_max_o         : out std_logic_vector(11 downto 0); -- the maximum measured phase value since last reset
        phase_jump_o        : out std_logic;                     -- this signal goes high if a significant phase difference is observed compared to the previous measurement (see PHASE_JUMP_THRESH)
        phase_jump_cnt_o    : out std_logic_vector(15 downto 0); -- number of times a phase jump has been detected
        phase_jump_size_o   : out std_logic_vector(11 downto 0); -- the magnitude of the phase jump (difference between the subsequent measurements that triggered the last phase jump detection)
        phase_jump_time_o   : out std_logic_vector(15 downto 0)  -- number of seconds since last phase jump
    );

end clk_phase_check_v7;

architecture Behavioral of clk_phase_check_v7 is

    -------------- ILA --------------
    component ila_clk_phase_check
        port (
            clk : IN STD_LOGIC;
            probe0 : IN STD_LOGIC; 
            probe1 : IN STD_LOGIC;
            probe2 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            probe3 : IN STD_LOGIC
        );
    end component;

    ---------------- SIGNALS -----------------
    constant VCO_FREQ           : real := 960.000;
    
    type t_state is (WAIT_SAMPLE, SHIFT_PHASE, WAIT_SHIFT_DONE);
        
    signal clkfb                : std_logic;
    signal sampling_clk         : std_logic;
    signal sampling_clk_bufg    : std_logic;
    
    signal mmcm_ps_clk          : std_logic;
    signal mmcm_ps_en           : std_logic := '0';
    signal mmcm_ps_done         : std_logic;
    signal mmcm_locked          : std_logic;    

    signal state                : t_state := WAIT_SAMPLE;
    signal sample_timer         : unsigned(15 downto 0) := (others => '0');
    
    -- phase measurement signals
    type t_clk_state is (HIGH, LOW, UNDETERMINED);

    signal sample_ok            : std_logic;
    signal sample_ok_sync       : std_logic := '0';
    signal sample_ok_sync_prev  : std_logic := '0';
    signal first_ever_sample    : std_logic := '1';
    signal clk1_state           : t_clk_state := LOW;
    signal clk2_state           : t_clk_state := LOW;
    signal phase_cnt            : unsigned(11 downto 0) := (others => '0');
    signal phase                : unsigned(11 downto 0) := (others => '0');
    signal phase_update         : std_logic := '0'; 
    signal phase_min            : unsigned(11 downto 0) := (others => '1');
    signal phase_max            : unsigned(11 downto 0) := (others => '0');
    signal phase_mean           : std_logic_vector(11 downto 0) := (others => '0');
    signal phase_jump           : std_logic;
    signal phase_jump_cnt       : unsigned(15 downto 0) := (others => '0');
    signal phase_jump_size      : unsigned(11 downto 0) := (others => '0');
    signal phase_jump_time      : std_logic_vector(15 downto 0) := (others => '0');
    
begin

    mmcm_ps_clk <= clk1_i;
    phase_o <= std_logic_vector(phase);
    phase_mean_o <= phase_mean;
    phase_min_o <= std_logic_vector(phase_min);
    phase_max_o <= std_logic_vector(phase_max);
    phase_jump_o <= phase_jump;
    phase_jump_cnt_o <= std_logic_vector(phase_jump_cnt);
    phase_jump_size_o <= std_logic_vector(phase_jump_size);
    phase_jump_time_o <= phase_jump_time;

    mmcm_adv_inst : MMCME2_ADV
        generic map(
            BANDWIDTH            => "OPTIMIZED",
            CLKOUT4_CASCADE      => false,
            COMPENSATION         => "ZHOLD",
            STARTUP_WAIT         => false,
            DIVCLK_DIVIDE        => 1,
            CLKFBOUT_MULT_F      => VCO_FREQ / ROUND_FREQ_MHZ,
            CLKFBOUT_PHASE       => 0.000,
            CLKFBOUT_USE_FINE_PS => true,
            CLKOUT0_DIVIDE_F     => VCO_FREQ / ROUND_FREQ_MHZ,
            CLKOUT0_PHASE        => 0.000,
            CLKOUT0_DUTY_CYCLE   => 0.500,
            CLKOUT0_USE_FINE_PS  => false,
            CLKOUT1_DIVIDE       => integer(VCO_FREQ / ROUND_FREQ_MHZ),
            CLKOUT1_PHASE        => 0.000,
            CLKOUT1_DUTY_CYCLE   => 0.500,
            CLKOUT1_USE_FINE_PS  => false,
            CLKOUT2_DIVIDE       => integer(VCO_FREQ / ROUND_FREQ_MHZ),
            CLKOUT2_PHASE        => 0.000,
            CLKOUT2_DUTY_CYCLE   => 0.500,
            CLKOUT2_USE_FINE_PS  => false,
            CLKOUT3_DIVIDE       => integer(VCO_FREQ / ROUND_FREQ_MHZ),
            CLKOUT3_PHASE        => 0.000,
            CLKOUT3_DUTY_CYCLE   => 0.500,
            CLKOUT3_USE_FINE_PS  => false,
            CLKOUT4_DIVIDE       => integer(VCO_FREQ / ROUND_FREQ_MHZ),
            CLKOUT4_PHASE        => 0.000,
            CLKOUT4_DUTY_CYCLE   => 0.500,
            CLKOUT4_USE_FINE_PS  => false,
            CLKIN1_PERIOD        => 1000.000 / ROUND_FREQ_MHZ,
            REF_JITTER1          => 0.010)
        port map(
            -- Output clocks
            CLKFBOUT     => clkfb,
            CLKFBOUTB    => open,
            CLKOUT0      => sampling_clk,
            CLKOUT0B     => open,
            CLKOUT1      => open,
            CLKOUT1B     => open,
            CLKOUT2      => open,
            CLKOUT2B     => open,
            CLKOUT3      => open,
            CLKOUT3B     => open,
            CLKOUT4      => open,
            CLKOUT5      => open,
            CLKOUT6      => open,
            -- Input clock control
            CLKFBIN      => clkfb,
            CLKIN1       => clk1_i,
            CLKIN2       => '0',
            -- Tied to always select the primary input clock
            CLKINSEL     => '1',

            -- Ports for dynamic reconfiguration
            DADDR        => (others => '0'),
            DCLK         => '0',
            DEN          => '0',
            DI           => (others => '0'),
            DO           => open,
            DRDY         => open,
            DWE          => '0',
            -- Ports for dynamic phase shift
            PSCLK        => mmcm_ps_clk,
            PSEN         => mmcm_ps_en,
            PSINCDEC     => '1',
            PSDONE       => mmcm_ps_done,
            -- Other control and status signals
            LOCKED       => mmcm_locked,
            CLKINSTOPPED => open,
            CLKFBSTOPPED => open,
            PWRDWN       => '0',
            RST          => reset_i
        );

    i_bufg_clk_40 : BUFG
        port map(
            O => sampling_clk_bufg,
            I => sampling_clk
        );
        
    process(clk1_i)
    begin
        if (rising_edge(clk1_i)) then
            if ((reset_i = '1') or (mmcm_locked = '0')) then
                state <= WAIT_SAMPLE;
                mmcm_ps_en <= '0';
                sample_timer <= (others => '0');
                sample_ok <= '0';
            else
                case state is
                    when WAIT_SAMPLE =>
                        mmcm_ps_en <= '0';    
                        if (sample_timer = SAMPLING_TIME) then
                            state <= SHIFT_PHASE;
                            sample_timer <= (others => '0');
                            sample_ok <= '0';
                        else
                            state <= WAIT_SAMPLE;
                            sample_timer <= sample_timer + 1;
                            if (sample_timer < SAMPLING_TIME - 5) then
                                sample_ok <= '1';
                            else
                                sample_ok <= '0';
                            end if;
                        end if;
                        
                    when SHIFT_PHASE =>
                        mmcm_ps_en <= '1';
                        state <= WAIT_SHIFT_DONE;
                        sample_timer <= (others => '0');
                        sample_ok <= '0';
                        
                    when WAIT_SHIFT_DONE =>
                        mmcm_ps_en <= '0';
                        sample_timer <= (others => '0');
                        sample_ok <= '0';
                        if (mmcm_ps_done = '1') then
                            state <= WAIT_SAMPLE;
                        else
                            state <= WAIT_SHIFT_DONE;
                        end if;

                    when others =>
                        state <= WAIT_SAMPLE;
                        sample_timer <= (others => '0');
                        sample_ok <= '0';
                        mmcm_ps_en <= '0';
                        
                end case;
            end if;
        end if;
    end process;

    i_sample_ok_sync : entity work.synch
        generic map(
            N_STAGES => 3
        )
        port map(
            async_i => sample_ok,
            clk_i   => sampling_clk_bufg,
            sync_o  => sample_ok_sync
        );
    
    -- phase measurement process
    -- checks the status of both clocks between the phase shifts, and then
    -- counts the number of phase shifts done between the last time when
    -- both clocks consistently sampled low and the time when both clocks start to consistently sample high
    process(sampling_clk_bufg)
    begin
        if (rising_edge(sampling_clk_bufg)) then
            if (reset_i = '1') then
                first_ever_sample <= '1';
                clk1_state <= LOW;
                clk2_state <= LOW;
                phase_cnt <= (others => '0');
                phase <= (others => '0');
                phase_min <= (others => '1');
                phase_max <= (others => '0');
                phase_jump <= '0';
                phase_jump_cnt <= (others => '0');
                phase_jump_size <= (others => '0');
                phase_update <= '0';
            else
                sample_ok_sync_prev <= sample_ok_sync;
                phase_update <= '0';
                
                -- first sample
                if (sample_ok_sync_prev = '0' and sample_ok_sync = '1') then
                    if (clk1_i = '1') then
                        clk1_state <= HIGH;
                    else
                        clk1_state <= LOW;
                    end if;
                    if (clk2_i = '1') then
                        clk2_state <= HIGH;
                    else
                        clk2_state <= LOW;
                    end if;
                -- additional samples at the same phase
                elsif (sample_ok_sync_prev = '1' and sample_ok_sync = '1') then
                    if ((clk1_i /= '1' and clk1_state = HIGH) or (clk1_i /= '0' and clk1_state = LOW)) then
                        clk1_state <= UNDETERMINED;
                    end if;
                    if ((clk2_i /= '1' and clk2_state = HIGH) or (clk2_i /= '0' and clk2_state = LOW)) then
                        clk2_state <= UNDETERMINED;
                    end if;
                -- end of the current phase sampling
                elsif (sample_ok_sync_prev = '1' and sample_ok_sync = '0') then
                    -- reset the phase counter when both clocks sample low
                    if (clk1_state /= HIGH and clk2_state /= HIGH) then
                        phase_cnt <= (others => '0');
                    -- fix the phase measurement when both clocks sample high
                    elsif (clk1_state = HIGH and clk2_state = HIGH) then
                        phase <= phase_cnt;
                        phase_update <= '1';
                        if (phase_cnt < phase_min) then
                            phase_min <= phase_cnt;
                        end if;
                        if (phase_cnt > phase_max) then
                            phase_max <= phase_cnt;
                        end if;
                                                
                        first_ever_sample <= '0';
                        if (first_ever_sample = '0') then
                            if ((phase_cnt > phase) and ((phase_cnt - phase) > PHASE_JUMP_THRESH)) then
                                phase_jump <= '1';
                                phase_jump_cnt <= phase_jump_cnt + 1;
                                phase_jump_size <= phase_cnt - phase;
                            elsif ((phase_cnt < phase) and ((phase - phase_cnt) > PHASE_JUMP_THRESH)) then
                                phase_jump <= '1';
                                phase_jump_cnt <= phase_jump_cnt + 1;
                                phase_jump_size <= phase - phase_cnt;
                            else
                                phase_jump <= '0';
                            end if;
                        end if;
                        
                    -- increment the phase counter between both clocks sampling low and both clocks sampling high
                    -- this should approximate the distance between the rising edges of the two clocks
                    elsif (phase_cnt /= x"fff") then
                        phase_cnt <= phase_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    i_seconds_counter : entity work.seconds_counter
        generic map(
            g_CLK_FREQUENCY  => EXACT_FREQ_HZ,
            g_ALLOW_ROLLOVER => false,
            g_COUNTER_WIDTH  => 16
        )
        port map(
            clk_i     => sampling_clk_bufg,
            reset_i   => reset_i or phase_jump,
            seconds_o => phase_jump_time
        );

    i_phase_mean : entity work.running_mean
        generic map(
            g_INPUT_OUTPUT_WIDTH       => 12,
            g_WINDOW_SIZE_POWER_OF_TWO => PHASE_MEAN_WINDOW_SIZE_POW_TWO
        )
        port map(
            clk_i   => sampling_clk_bufg,
            reset_i => reset_i,
            value_i => std_logic_vector(phase),
            valid_i => phase_update,
            mean_o  => phase_mean
        );

    g_ila : if ILA_ENABLE generate
        i_ila : component ila_clk_phase_check
            port map(
                clk    => sampling_clk_bufg,
                probe0 => clk1_i,
                probe1 => clk2_i,
                probe2 => std_logic_vector(to_unsigned(t_state'pos(state), 2)),
                probe3 => phase_jump
            );
    end generate;

end Behavioral;
