-------------------------------------------------------------------------------
-- Title      : Digital DMTD Phase Measurement Unit
-- Project    : White Rabbit
-------------------------------------------------------------------------------
-- File       : dmtd_phase_meas.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-02-25
-- Last update: 2011-05-11
-- Platform   : FPGA-generic
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Description: Module measures phase shift between the two input clocks
-- using a DDMTD phase detector. The raw measurement can be further averaged to
-- increase the accuracy.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2009 - 2010 CERN
--
-- This source file is free software; you can redistribute it   
-- and/or modify it under the terms of the GNU Lesser General   
-- Public License as published by the Free Software Foundation; 
-- either version 2.1 of the License, or (at your option) any   
-- later version.                                               
--
-- This source is distributed in the hope that it will be       
-- useful, but WITHOUT ANY WARRANTY; without even the implied   
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
-- PURPOSE.  See the GNU Lesser General Public License for more 
-- details.                                                     
--
-- You should have received a copy of the GNU Lesser General    
-- Public License along with this source; if not, download it   
-- from http://www.gnu.org/licenses/lgpl-2.1.html
--
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2010-02-25  1.0      twlostow        Created
-- 2011-04-18  1.1      twlostow        Added comments and header
-- 2020-03-27  1.2      Evaldas Juska   Adapted to GEM needs (phase_meas_o actually outputs the average and not sum, also provides min/max, and jump monitoring), and added a lot of documentation
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.NUMERIC_STD.all;

-- Evaldas Juska:
-- This module provides a measurement of the phase relationship between two input clocks (clk_a_i and clk_b_i).
-- It requires an asynchronous clock, called DMTD clock (clk_dmtd_i), that has slightly lower frequency than that of the measured clocks.
-- The closer the DMTD clock frequency is to the measured clock frequency, the better the measurement resolution will be (and the longer the measurement time)
-- the units of the measured phase can be calculated with the following formula: unit = meas_clk_period * (1 - meas_clk_period/dmtd_clk_period)
--     meas_clk_period - period of the measured clocks
--     dmtd_clk_period - period of the DMTD clock
-- e.g. when using the DMTD clock which has a frequency ratio of 0.999925466 to the measured clocks (39.997MHz measuring 40.00MHz), the units are 1.863354037ps
-- The resulting resolution also determines the number of bits that have to be used to tag the phase on each clock, which along with the maximum valid phase value, have to be supplied as paramters to this module.
-- In the above example of 1.863354037ps per point, measuring 25000ps period clocks would result in max valid phase value of 13417, and this requite 14bits
--
-- The measured phase can be averaged over N samples, which is configurable in steps of powers of two (user should set log2(N) through the navg_log2_i port).
-- Whenever a new averaged_phase output is available, the phase_avg_p_o port will be pulsed high for one clk_sys_i cycle.
-- In addition to the averaged phase (as well as min, max phase), the module also provides "phase jump monitoring" with a configurable threshold,
-- which counts (phase_jump_cnt_o) how many times subsequent averaged phase measurements have differed by more than the provided threshold (phase_jump_thresh_i)
--
-- When the two clocks are very close in phase, the measurement can fluctuate between values that are close to 0, and values that are close to max, which makes it kind of difficult
-- to average.. So instead of trying hard, a simple algorithm is used which just reports 0 if there were more low values than high ones, and max value if there were more high values than low ones.
-- This method has proven to be more reliable than other implementations, although sacrificing the precission around the zero crossing area.
--
-- This module also provides a "lock monitor", which can be used to help external logic to align the two clocks, as well as monitor their alignment with a simple "locked" flag.
-- The user can control the number of averaging samples used in the lock monitor in steps of powers of two through the lockmon_navg_log2_i port, as well as provide the desired
-- target lock phase value (lockmon_target_i), and tollerance around it (lockmon_tollerance_i) -- in this window the locked signal will be asserted high (lockmon_locked_o).
-- The lockmon_offset_o port provides the current distance to the lock value.
-- IMPORTANT: when the phase measurement is in the zero-crossing region, the lockmon_offset_o port is set to a special value of (others => '1'). If the external clock aligner sees this value, it should shift out of this region before attempting to go to the lock window. 
--
-- There's also a clock loss monitoring on clk_a_i and clk_b_i using the clk_sys_i. If either clk_a_i or clk_b_i are found to be lost (not present), the phase is reported as (others => '1'), and lock is reported as 0
--
entity dmtd_phase_meas is
    generic(
        G_DEGLITCHER_THRESHOLD  : integer := 2000;
        G_COUNTER_BITS          : integer := 14;
        G_CLK_LOST_SYS_CYCLES   : integer := 65535; -- this defines a time in clk_sys_i cycles during which if no edge has been detected on clk_a_i or clk_b_i then it is considered that the corresponding clock is not present
        G_MAX_VALID_PHASE       : integer -- maximum valid phase value - this depends on the frequency relationship of the DMTD clock and the clocks being measured, which determies the resolution
    );
    port(
        reset_i                 : in  std_logic;
        -- clocks
        clk_sys_i               : in  std_logic;
        clk_a_i                 : in  std_logic;
        clk_b_i                 : in  std_logic;
        clk_dmtd_i              : in  std_logic;
        -- clock present flags
        clk_a_present_o         : out std_logic;
        clk_b_present_o         : out std_logic;
        -- average phase monitoring
        navg_log2_i             : in  std_logic_vector(3 downto 0); -- number of samples to average in phase_avg_o output (units are log2(n))
        phase_avg_o             : out std_logic_vector(G_COUNTER_BITS - 1 downto 0);
        phase_min_o             : out std_logic_vector(G_COUNTER_BITS - 1 downto 0);
        phase_max_o             : out std_logic_vector(G_COUNTER_BITS - 1 downto 0);
        phase_avg_p_o           : out std_logic;
        dv_o                    : out std_logic;
        -- phase jump monitor
        phase_jump_thresh_i     : in  std_logic_vector(G_COUNTER_BITS - 1 downto 0);
        phase_jump_cnt_o        : out std_logic_vector(15 downto 0); -- number of times a phase jump has been detected
        -- lock monitoring
        lockmon_navg_log2_i     : in  std_logic_vector(3 downto 0); -- log2(number of samples to average) for lock monitoring purposes 
        lockmon_target_i        : in  std_logic_vector(G_COUNTER_BITS - 1 downto 0); -- lock target i.e. the phase that we want the clocks to have, which would be considered locked
        lockmon_tollerance_i    : in  std_logic_vector(G_COUNTER_BITS - 1 downto 0); -- the tollerance plus minus around the lock target that is still considered locked
        lockmon_locked_o        : out std_logic;
        lockmon_offset_pos_o    : out std_logic_vector(G_COUNTER_BITS - 1 downto 0); -- how far away from the lock target the clocks are at the moment in the positive direction. NOTE: a special value of (others => '1') is reported when the phase is in the zero crossing region
        lockmon_offset_neg_o    : out std_logic_vector(G_COUNTER_BITS - 1 downto 0); -- how far away from the lock target the clocks are at the moment in the negative direction. NOTE: a special value of (others => '1') is reported when the phase is in the zero crossing region
        lockmon_zero_cross_o    : out std_logic; -- this is asserted high if the phase is in the zero-crossing region where some of the readings in the average report close to 0, and others report close to max phase. In this case the offset values are set to (others => '1'), and cannot be used
        lockmon_update_o        : out std_logic -- pulsed high for 1 clk_sys_i cycle
    );

end dmtd_phase_meas;

architecture syn of dmtd_phase_meas is
    
    constant RANGE_OUTSIDE_VALID_PHASE  : integer := (2 ** G_COUNTER_BITS) - G_MAX_VALID_PHASE;
    
    type t_pd_state is (PD_WAIT_TAG, PD_WAIT_A, PD_WAIT_B);

    signal rst_n_dmtdclk    : std_logic;
    signal rst_n_sysclk     : std_logic;

    -- phase tags
    signal tag_a            : std_logic_vector(G_COUNTER_BITS - 1 downto 0);
    signal tag_b            : std_logic_vector(G_COUNTER_BITS - 1 downto 0);

    signal tag_a_p          : std_logic;
    signal tag_b_p          : std_logic;

    -- clock present monitoring
    signal clk_a_lost_cntdwn: unsigned(31 downto 0);
    signal clk_b_lost_cntdwn: unsigned(31 downto 0);
    signal clk_a_present    : std_logic;
    signal clk_b_present    : std_logic;

    -- phase calc signals
    signal phase_raw_p      : std_logic;
    signal phase_raw        : unsigned(G_COUNTER_BITS - 1 downto 0);
    signal phase_corr_p     : std_logic;
    signal phase_corr       : unsigned(G_COUNTER_BITS - 1 downto 0);
    signal pd_state         : t_pd_state;

    -- averaging signals
    signal acc              : unsigned(31 downto 0);
    signal avg_cnt          : unsigned(15 downto 0);
    signal log2_navg        : std_logic_vector(3 downto 0);
    signal navg             : unsigned(15 downto 0);
    signal avg_timeout      : unsigned(15 downto 0) := (others => '0'); -- timeout used when either clk_a or clk_b are lost

    signal phase_avg        : std_logic_vector(G_COUNTER_BITS - 1 downto 0);
    signal phase_avg_p      : std_logic;
    signal phase_lo         : std_logic;
    signal phase_hi         : std_logic;
    signal phase_lo_cnt     : unsigned(15 downto 0);
    signal phase_hi_cnt     : unsigned(15 downto 0);
    signal dv               : std_logic := '0';
    
    signal phase_min        : std_logic_vector(G_COUNTER_BITS - 1 downto 0) := (others => '1');
    signal phase_max        : std_logic_vector(G_COUNTER_BITS - 1 downto 0) := (others => '0');

    -- phase jump signals
    signal phase_jump_thresh: unsigned(G_COUNTER_BITS -1 downto 0);
    signal phase_jump_cnt   : unsigned(15 downto 0);
    signal phase_avg_prev   : std_logic_vector(G_COUNTER_BITS - 1 downto 0);
    signal dv_prev          : std_logic := '0';
    
    -- lockmon signals
    signal lm_acc           : unsigned(31 downto 0);
    signal lm_avg_cnt       : unsigned(15 downto 0);
    signal lm_log2_navg     : std_logic_vector(3 downto 0);
    signal lm_navg          : unsigned(15 downto 0);
    signal lm_target        : unsigned(G_COUNTER_BITS - 1 downto 0);
    signal lm_tollerance    : unsigned(G_COUNTER_BITS - 1 downto 0);
    signal lm_phase_lo_cnt  : unsigned(15 downto 0);
    signal lm_phase_hi_cnt  : unsigned(15 downto 0);
    signal lm_offset_pos    : unsigned(G_COUNTER_BITS - 1 downto 0);
    signal lm_offset_neg    : unsigned(G_COUNTER_BITS - 1 downto 0);
    signal lm_offset_p      : std_logic;
    signal lm_zero_crossing : std_logic;

begin                                   -- syn

    rst_n_sysclk <= not reset_i;
    dv_o         <= dv;

    -- reset sync for DMTD sampling clock
    sync_reset_dmtdclk : entity work.synch
        generic map(
            N_STAGES => 3
        )
        port map(
            async_i => rst_n_sysclk,
            clk_i   => clk_dmtd_i,
            sync_o  => rst_n_dmtdclk
        );

    --================ collect the phase tags ================--

    i_dmtd_a : entity work.dmtd_with_deglitcher
        generic map(
            g_counter_bits => G_COUNTER_BITS
        --            g_log2_replication => 2
        )
        port map(
            rst_n_dmtdclk_i      => rst_n_dmtdclk,
            clk_dmtd_i           => clk_dmtd_i,
            clk_sys_i            => clk_sys_i,
            clk_in_i             => clk_a_i,
            tag_o                => tag_a,
            tag_stb_p1_o         => tag_a_p,
            shift_en_i           => '0',
            shift_dir_i          => '0',
            deglitch_threshold_i => std_logic_vector(to_unsigned(G_DEGLITCHER_THRESHOLD, 16))
        );

    i_dmtd_b : entity work.dmtd_with_deglitcher
        generic map(
            g_counter_bits => G_COUNTER_BITS
        --            g_log2_replication => 2
        )
        port map(
            rst_n_dmtdclk_i      => rst_n_dmtdclk,
            clk_dmtd_i           => clk_dmtd_i,
            clk_sys_i            => clk_sys_i,
            clk_in_i             => clk_b_i,
            tag_o                => tag_b,
            tag_stb_p1_o         => tag_b_p,
            shift_en_i           => '0',
            shift_dir_i          => '0',
            deglitch_threshold_i => std_logic_vector(to_unsigned(G_DEGLITCHER_THRESHOLD, 16))
        );

    --================ clock presence monitoring ================--
    
    clk_a_present_o <= clk_a_present;
    clk_b_present_o <= clk_b_present;
    
    process(clk_sys_i)
    begin
        if rising_edge(clk_sys_i) then
            if (tag_a_p = '1') then
                clk_a_lost_cntdwn <= to_unsigned(G_CLK_LOST_SYS_CYCLES, clk_a_lost_cntdwn'length);
                clk_a_present <= '1';
            elsif (clk_a_lost_cntdwn /= to_unsigned(0, clk_a_lost_cntdwn'length)) then
                clk_a_lost_cntdwn <= clk_a_lost_cntdwn - 1;
                clk_a_present <= '1';
            else
                clk_a_lost_cntdwn <= (others => '0');
                clk_a_present <= '0';
            end if;
        end if;
    end process;

    process(clk_sys_i)
    begin
        if rising_edge(clk_sys_i) then
            if (tag_b_p = '1') then
                clk_b_lost_cntdwn <= to_unsigned(G_CLK_LOST_SYS_CYCLES, clk_b_lost_cntdwn'length);
                clk_b_present <= '1';
            elsif (clk_b_lost_cntdwn /= to_unsigned(0, clk_b_lost_cntdwn'length)) then
                clk_b_lost_cntdwn <= clk_b_lost_cntdwn - 1;
                clk_b_present <= '1';
            else
                clk_b_lost_cntdwn <= (others => '0');
                clk_b_present <= '0';
            end if;
        end if;
    end process;

    --================ calculate the phase relationship ================--

    collect_tags : process(clk_sys_i)
    begin                               -- process   
        if rising_edge(clk_sys_i) then
            if (reset_i = '1') then
                phase_raw   <= (others => '0');
                phase_raw_p <= '0';
                pd_state    <= PD_WAIT_TAG;
            else
                case pd_state is
                    when PD_WAIT_TAG =>
                        if (tag_a_p = '1' and tag_b_p = '1') then
                            phase_raw   <= unsigned(tag_a) - unsigned(tag_b);
                            phase_raw_p <= '1';
                        elsif (tag_a_p = '1') then
                            phase_raw   <= unsigned(tag_a);
                            phase_raw_p <= '0';
                            pd_state    <= PD_WAIT_B;
                        elsif (tag_b_p = '1') then
                            phase_raw   <= (not unsigned(tag_b)) + 1;
                            phase_raw_p <= '0';
                            pd_state    <= PD_WAIT_A;
                        else
                            phase_raw_p <= '0';
                        end if;

                    when PD_WAIT_A =>
                        if (tag_a_p = '1') then
                            phase_raw   <= phase_raw + unsigned(tag_a);
                            phase_raw_p <= '1';
                            pd_state    <= PD_WAIT_TAG;
                        end if;

                    when PD_WAIT_B =>
                        if (tag_b_p = '1') then
                            phase_raw   <= phase_raw - unsigned(tag_b);
                            phase_raw_p <= '1';
                            pd_state    <= PD_WAIT_TAG;
                        end if;

                    when others => null;
                end case;

            end if;
        end if;
    end process;

    -- correct the wraparound (restrict it to the valid range)
    correct_phase : process(clk_sys_i)
    begin
        if (rising_edge(clk_sys_i)) then
            phase_corr_p <= phase_raw_p;
            if (phase_raw > to_unsigned(G_MAX_VALID_PHASE, G_COUNTER_BITS)) then
                phase_corr <= phase_raw - to_unsigned(RANGE_OUTSIDE_VALID_PHASE, G_COUNTER_BITS);
            else
                phase_corr <= phase_raw;
            end if;
        end if;
    end process;

    --================ calculate the average ================--
    -- note, in the region of zero-crossing, a value of 0 is reported if there are more low values than high ones, and max value is reported when there are more high values than low ones

    phase_hi <= '1' when phase_corr(phase_corr'high downto phase_corr'high - 1) = "11" else '0';
    phase_lo <= '1' when phase_corr(phase_corr'high downto phase_corr'high - 1) = "00" else '0';

    phase_avg_o <= phase_avg;
    phase_avg_p_o <= phase_avg_p;
    
    -- register navg_log2
    process(clk_sys_i)
    begin
        if (rising_edge(clk_sys_i)) then
            log2_navg <= navg_log2_i;
        end if;
    end process;
    
    navg <= to_unsigned(2 ** to_integer(unsigned(log2_navg)), 16);

    calc_avg : process(clk_sys_i)
    begin
        if rising_edge(clk_sys_i) then
            if (reset_i = '1') then
                acc          <= (others => '0');
                avg_cnt      <= (others => '0');
                phase_avg    <= (others => '0');
                phase_avg_p  <= '0';
                phase_lo_cnt <= (others => '0');
                phase_hi_cnt <= (others => '0');
                dv           <= '0';
                avg_timeout  <= (others => '0'); 
            else
                
                -- we have a new measurement
                if (phase_corr_p = '1') then

                    avg_timeout  <= (others => '0'); 
                    
                    -- no averaging is used -- in this case just do the below in order to avoid the extra 1 sample delay
                    if (navg = to_unsigned(1, navg'length)) then
                        phase_avg    <= std_logic_vector(phase_corr);
                        phase_avg_p  <= '1';
                        phase_lo_cnt <= (others => '0');
                        phase_hi_cnt <= (others => '0');
                        dv           <= '1';
                        
                    -- we've reached the number of samples required for averaging
                    elsif (avg_cnt = unsigned(navg)) then

                        -- if the number of both the very high and very low values is non-zero, it means we are in zero-crossing region
                        if ((phase_lo_cnt /= to_unsigned(0, phase_lo_cnt'length)) and (phase_hi_cnt /= to_unsigned(0, phase_hi_cnt'length))) then
                            -- report max value in case there are more high values than low ones, and 0 otherwise
                            if (phase_hi_cnt > phase_lo_cnt) then
                                phase_avg <= std_logic_vector(to_unsigned(G_MAX_VALID_PHASE, G_COUNTER_BITS));
                            else
                                phase_avg <= (others => '0');
                            end if;
                        -- outside the zero-crossing region, divide the accumulated value by the number of samples by shifting the acc to the right by log2(N) bits
                        else
                            phase_avg <= std_logic_vector(acc(G_COUNTER_BITS - 1 + to_integer(unsigned(log2_navg)) downto to_integer(unsigned(log2_navg))));
                        end if;

                        acc <= resize(phase_corr, acc'length);                        
                        phase_lo_cnt <= (others => '0');
                        phase_hi_cnt <= (others => '0');
                        avg_cnt      <= to_unsigned(1, avg_cnt'length);
                        phase_avg_p  <= '1';
                        dv           <= '1';

                    else
                        avg_cnt        <= avg_cnt + 1;
                        phase_avg_p    <= '0';
                        acc <= acc + resize(phase_corr, acc'length);

                        -- count the very low and high values, used to detect zero-crossing area 
                        if (phase_hi = '1') then
                            phase_hi_cnt <= phase_hi_cnt + 1;  
                        end if;
                        
                        if (phase_lo = '1') then
                            phase_lo_cnt <= phase_lo_cnt + 1;  
                        end if;
                    end if;
                    
                -- if either clk_a or clk_b is lost, then report a special phase value of (others => '1'), and also make the pulse go high every now and then using the avg_timeout counter
                elsif (clk_a_present = '0' or clk_b_present = '0') then
                    phase_avg <= (others => '1');
                    avg_timeout <= avg_timeout + 1;
                    if (avg_timeout = to_unsigned(0, avg_timeout'length)) then
                        phase_avg_p <= '1';
                    else
                        phase_avg_p <= '0';
                    end if;
                
                -- waiting for measurement
                else
                    phase_avg_p <= '0';
                end if;
            end if;
        end if;
    end process;
    
    --================ update minimum and maximum phase values ================--

    phase_min_o <= phase_min;
    phase_max_o <= phase_max;

    calc_min_max : process(clk_sys_i)
    begin
        if rising_edge(clk_sys_i) then
            if (reset_i = '1') then
                phase_min <= (others => '1');
                phase_max <= (others => '0');
            else
                if (phase_avg_p = '1') then
                    
                    if (phase_avg > phase_max) then
                        phase_max <= phase_avg;
                    end if;
                    
                    if (phase_avg < phase_min) then
                        phase_min <= phase_avg;
                    end if;
                    
                end if;
            end if;
        end if;
    end process;

    phase_jump_cnt_o <= std_logic_vector(phase_jump_cnt);
    
    --================ monitor for phase jumps ================--
    
    jump_monitor : process(clk_sys_i)
        variable phase_higher    : unsigned(G_COUNTER_BITS - 1 downto 0);
        variable phase_lower     : unsigned(G_COUNTER_BITS - 1 downto 0);
        variable phase_diff      : unsigned(G_COUNTER_BITS - 1 downto 0);
        variable phase_diff_wrap : unsigned(G_COUNTER_BITS - 1 downto 0);
    begin
        if (rising_edge(clk_sys_i)) then
            if (reset_i = '1') then
                dv_prev <= '0';
                phase_jump_cnt <= (others => '0');
            else
                phase_jump_thresh <= unsigned(phase_jump_thresh_i);
                
                if (phase_avg_p = '1') then
                    dv_prev <= '1';
                    phase_avg_prev <= phase_avg;
                    
                    if (phase_avg > phase_avg_prev) then
                        phase_higher := unsigned(phase_avg);
                        phase_lower := unsigned(phase_avg_prev);
                    else
                        phase_higher := unsigned(phase_avg_prev);
                        phase_lower := unsigned(phase_avg);
                    end if;

                    phase_diff := phase_higher - phase_lower;
                    phase_diff_wrap := to_unsigned(G_MAX_VALID_PHASE, G_COUNTER_BITS) - phase_higher + phase_lower;

                    if (dv_prev = '1' and phase_diff > phase_jump_thresh and phase_diff_wrap > phase_jump_thresh) then
                        phase_jump_cnt <= phase_jump_cnt + 1;
                    end if;

                end if;
            end if;
        end if;
    end process;
    
    --================ lock monitoring ================--
    
    -- register control inputs
    process(clk_sys_i)
    begin
        if (rising_edge(clk_sys_i)) then
            lm_log2_navg <= lockmon_navg_log2_i;
            lm_target <= unsigned(lockmon_target_i);
            lm_tollerance <= unsigned(lockmon_tollerance_i);
        end if;
    end process;    
    
    lm_navg <= to_unsigned(2 ** to_integer(unsigned(lm_log2_navg)), 16);
    
    lockmon_avg : process(clk_sys_i)
        variable lm_phase_avg   : unsigned(G_COUNTER_BITS - 1 downto 0); 
    begin
        if rising_edge(clk_sys_i) then
            if (reset_i = '1') then
                lm_acc           <= (others => '0');
                lm_avg_cnt       <= (others => '0');
                lm_offset_pos    <= (others => '1');
                lm_offset_neg    <= (others => '1');
                lm_offset_p      <= '0';
                lm_phase_lo_cnt  <= (others => '0');
                lm_phase_hi_cnt  <= (others => '0');
                lm_zero_crossing <= '0';
            else
                if (phase_corr_p = '1') then
                    
                    -- no averaging is used -- in this case just do the below in order to avoid the extra 1 sample delay
--                    if (lm_navg = to_unsigned(1, lm_navg'length)) then
--                        if (phase_corr > lm_target) then
--                            lm_offset_neg <= phase_corr - lm_target;
--                            lm_offset_pos <= (to_unsigned(G_MAX_VALID_PHASE, G_COUNTER_BITS) - phase_corr) + lm_target + 1; 
--                        else
--                            lm_offset_pos <= lm_target - phase_corr;
--                            lm_offset_neg <= (to_unsigned(G_MAX_VALID_PHASE, G_COUNTER_BITS) - lm_target) + phase_corr + 1;
--                        end if;
--                        
--                        lm_offset_p <= '1';
--
--                        lm_acc          <= (others => '0');
--                        lm_avg_cnt      <= to_unsigned(1, avg_cnt'length);
--                        lm_phase_lo_cnt <= (others => '0');
--                        lm_phase_hi_cnt <= (others => '0');
--                        
--                    -- we've reached the number of samples required for averaging
--                    elsif (lm_avg_cnt = unsigned(lm_navg)) then

                    if (lm_avg_cnt = unsigned(lm_navg)) then

                        lm_phase_avg := lm_acc(G_COUNTER_BITS - 1 + to_integer(unsigned(lm_log2_navg)) downto to_integer(unsigned(lm_log2_navg)));
                        if (lm_phase_avg > lm_target) then
                            lm_offset_neg <= lm_phase_avg - lm_target;
                            lm_offset_pos <= (to_unsigned(G_MAX_VALID_PHASE, G_COUNTER_BITS) - lm_phase_avg) + lm_target + 1; 
                        else
                            lm_offset_pos <= lm_target - lm_phase_avg;
                            lm_offset_neg <= (to_unsigned(G_MAX_VALID_PHASE, G_COUNTER_BITS) - lm_target) + lm_phase_avg + 1;
                        end if;

                        -- if the number of both the very high and very low values is non-zero, it means we are in zero-crossing region
                        if ((lm_phase_lo_cnt /= to_unsigned(0, lm_phase_lo_cnt'length)) and (lm_phase_hi_cnt /= to_unsigned(0, lm_phase_hi_cnt'length))) then
                            lm_zero_crossing <= '1';
                        else
                            lm_zero_crossing <= '0';
                        end if;

                        lm_acc <= resize(phase_corr, lm_acc'length);                        
                        lm_phase_lo_cnt <= (others => '0');
                        lm_phase_hi_cnt <= (others => '0');
                        lm_avg_cnt        <= to_unsigned(1, avg_cnt'length);
                        lm_offset_p    <= '1';

                    else
                        lm_avg_cnt        <= lm_avg_cnt + 1;
                        lm_offset_p    <= '0';
                        lm_acc <= lm_acc + resize(phase_corr, lm_acc'length);

                        -- count the very low and high values, used to detect zero-crossing area 
                        if (phase_hi = '1') then
                            lm_phase_hi_cnt <= lm_phase_hi_cnt + 1;  
                        end if;
                        
                        if (phase_lo = '1') then
                            lm_phase_lo_cnt <= lm_phase_lo_cnt + 1;  
                        end if;
                    end if;
                else
                    lm_offset_p <= '0';
                end if;
            end if;
        end if;
    end process;    
    
    lockmon: process(clk_sys_i)
    begin
        if rising_edge(clk_sys_i) then
            if (reset_i = '1') then
                lockmon_update_o <= '0';
                lockmon_offset_pos_o <= (others => '1');
                lockmon_offset_neg_o <= (others => '1');
                lockmon_locked_o <= '0';
                lockmon_zero_cross_o <= '0';
            else
                lockmon_update_o <= lm_offset_p;
                
                if (lm_offset_p = '1') then
                    if (lm_zero_crossing = '1') then
                        lockmon_offset_pos_o <= (others => '1');
                        lockmon_offset_neg_o <= (others => '1');
                        lockmon_locked_o <= '0';
                        lockmon_zero_cross_o <= '1';
                    else
                        lockmon_offset_pos_o <= std_logic_vector(lm_offset_pos);
                        lockmon_offset_neg_o <= std_logic_vector(lm_offset_neg);
                        lockmon_zero_cross_o <= '0';
                        if (lm_offset_pos <= lm_tollerance) or (lm_offset_neg <= lm_tollerance) then
                            lockmon_locked_o <= '1';
                        else
                            lockmon_locked_o <= '0';
                        end if; 
                    end if;
                elsif (clk_a_present = '0' or clk_b_present = '0') then
                    lockmon_offset_pos_o <= (others => '1');
                    lockmon_offset_neg_o <= (others => '1');
                    lockmon_locked_o <= '0';
                end if;
            end if;
        end if;
    end process;
    
end syn;
