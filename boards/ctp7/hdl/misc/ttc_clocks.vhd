--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date: 12/13/2016 14:27:30
-- Module Name: TTC_CLOCKS
-- Project Name: GEM_AMC
-- Description: Given a jitter cleaned TTC clock (160MHz, coming from MGT ref) and a reference 40MHz TTC clock from the backplane, this module   
--              generates 40MHz, 80MHz, 120MHz, 160MHz TTC clocks that are phase aligned with the reference TTC clock from the backplane.
--              All clocks are generated from the jitter cleaned clock and then phase shifted to match the reference, using PLL to check for phase alignment.
--              Note that phase alignment might take quite some time. It's phase shifting the 40MHz clock in steps of ~19ps and each step can take up to ~30us. 
-- 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.ttc_pkg.all;
use work.gem_board_config_package.all;

--============================================================================
--                                                          Entity declaration
--============================================================================
entity ttc_clocks is
    generic (
        PLL_LOCK_WAIT_TIMEOUT     : unsigned(23 downto 0) := x"002710" -- way too long, will measure how low we can go here
    );
    port (
        clk_40_ttc_p_i          : in  std_logic; -- TTC backplane clock signals
        clk_40_ttc_n_i          : in  std_logic;
        clk_gbt_mgt_txout_i     : in  std_logic; -- TTC jitter cleaned 160MHz or 320MHz TTC clock, should come from MGT ref (160MHz in GBTX case, and 320MHz in LpGBT case)
        clocks_o                : out t_ttc_clks;
        ctrl_i                  : in  t_ttc_clk_ctrl; -- control signals
        status_o                : out t_ttc_clk_status -- status outputs
    );

end ttc_clocks;

--============================================================================
--                                                        Architecture section
--============================================================================
architecture ttc_clocks_arch of ttc_clocks is

COMPONENT vio_ttc_clocks
  PORT (
    clk : IN STD_LOGIC;
    probe_in0  : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    probe_in1  : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in2  : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in3  : IN STD_LOGIC_VECTOR(15 DOWNTO 0);   
    probe_in4  : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in5  : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in6  : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe_out0 : OUT STD_LOGIC;
    probe_out1 : OUT STD_LOGIC
  );
END COMPONENT;

COMPONENT ila_ttc_clocks
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(2 DOWNTO 0); 
        probe1 : IN STD_LOGIC; 
        probe2 : IN STD_LOGIC; 
        probe3 : IN STD_LOGIC; 
        probe4 : IN STD_LOGIC; 
        probe5 : IN STD_LOGIC;
        probe6 : IN STD_LOGIC
    );
END COMPONENT  ;

    --============================================================================
    --                                                         Signal declarations
    --============================================================================
    signal clk_40_ttc_ibufgds   : std_logic;
    signal clk_40_ttc_bufg      : std_logic;

    signal clkin                : std_logic;

    signal clkfbout             : std_logic;
    signal clkfbin              : std_logic;

    signal clk_40               : std_logic;
    signal clk_80               : std_logic;
    signal clk_120              : std_logic;
    signal clk_160              : std_logic;
    signal clk_320              : std_logic;

    signal ttc_clocks_bufg      : t_ttc_clks;
    
    -- this function determines the feedback clock multiplication factor based on whether the station is using LpGBT or GBTX
    function get_clkfbout_mult(gem_station : integer; is_lpgbt_loopback : boolean) return real is
    begin
        if is_lpgbt_loopback then
            return 3.0;
        elsif gem_station = 0 then
            return 3.0;
        elsif gem_station = 1 then
            return 6.0;
        elsif gem_station = 2 then
            return 6.0;
        else -- hmm whatever, lets say 6.0
            return 6.0;  
        end if;
    end function get_clkfbout_mult;    

    function get_clkin_period(gem_station : integer; is_lpgbt_loopback : boolean) return real is
    begin
        if is_lpgbt_loopback then
            return 3.125;
        elsif gem_station = 0 then
            return 3.125;
        elsif gem_station = 1 then
            return 6.25;
        elsif gem_station = 2 then
            return 6.25;
        else -- hmm whatever, lets say 6.25
            return 6.25;  
        end if;
    end function get_clkin_period;    

    function get_clkin_frequency_slv32(gem_station : integer; is_lpgbt_loopback : boolean) return std_logic_vector is
    begin
        if is_lpgbt_loopback then
            return x"131c74c0"; -- 320.632
        elsif gem_station = 0 then
            return x"131c74c0"; -- 320.632
        elsif gem_station = 1 then
            return x"098e3a60"; -- 160.316MHz
        elsif gem_station = 2 then
            return x"098e3a60"; -- 160.316MHz
        else -- hmm whatever, lets say 160
            return x"098e3a60";  -- 160.316MHz
        end if;
    end function get_clkin_frequency_slv32;    


    constant CFG_CLKFBOUT_MULT : real := get_clkfbout_mult(CFG_GEM_STATION, CFG_LPGBT_2P56G_LOOPBACK_TEST);
    constant CFG_CLKIN1_PERIOD : real := get_clkin_period(CFG_GEM_STATION, CFG_LPGBT_2P56G_LOOPBACK_TEST);
    constant CFG_CLKIN1_FREQ_SLV32 : std_logic_vector := get_clkin_frequency_slv32(CFG_GEM_STATION, CFG_LPGBT_2P56G_LOOPBACK_TEST);
    
    ----------------- phase alignment ------------------
    constant MMCM_PS_DONE_TIMEOUT : unsigned(7 downto 0) := x"9f"; -- datasheet says MMCM should complete a phase shift in 12 clocks, but we check it with some margin, just in case
    constant SHIFT_OUT_COUNT : unsigned(15 downto 0) := x"006b"; -- the number of MMCM shifts to do when wanting to shift out of lock or zero crossing region (currently set to 107 shifts, which corresponds to about 2ns)
    type pa_state_t is (IDLE, FIND_UNLOCK, FIND_LOCK, WAIT_SHIFT_DONE, SYNC_DONE, FAIL);

    signal mmcm_ps_clk              : std_logic;
    signal mmcm_ps_en               : std_logic;
    signal mmcm_ps_incdec           : std_logic;
    signal mmcm_ps_done             : std_logic;
    signal mmcm_locked_raw          : std_logic;
    signal mmcm_locked              : std_logic;
    signal mmcm_locked_clk40        : std_logic;
    signal mmcm_unlock_p_clk40      : std_logic;
    signal mmcm_reset_psclk_tmp     : std_logic;

    signal fsm_reset                : std_logic := '0';
    signal sync_done_flag           : std_logic;
    signal sync_done_flag_clk40     : std_logic;
    signal pa_state                 : pa_state_t := IDLE;
    signal searching_unlock         : std_logic := '0';
    signal lockmon_reset_clk40      : std_logic := '0';
    signal shift_cnt                : unsigned(15 downto 0) := (others => '0');
    signal mmcm_ps_done_timer       : unsigned(7 downto 0)  := (others => '0');
    signal phase_unlock_cnt         : std_logic_vector(15 downto 0) := (others => '0');
    signal mmcm_unlock_cnt          : std_logic_vector(15 downto 0) := (others => '0');
    
    signal mmcm_lock_stable_cnt     : integer range 0 to 127 := 0;

    constant LOCK_STABLE_TIMEOUT    : integer := 12;
    constant UNLOCK_STABLE_TIMEOUT  : integer := 12;
    
    -- time counters
    signal sync_done_time           : std_logic_vector(15 downto 0);
    signal phase_unlock_time        : std_logic_vector(15 downto 0);
    
    -- ttc phase monitoring
    signal ttc_phase                : std_logic_vector(15 downto 0) := (others => '0'); -- phase difference between the rising edges of the two clocks (each count is about 18.6012ps)
    signal ttc_phase_min            : std_logic_vector(15 downto 0) := (others => '0');
    signal ttc_phase_max            : std_logic_vector(15 downto 0) := (others => '0');
    signal ttc_phase_jump_cnt       : std_logic_vector(15 downto 0) := (others => '0');
    signal ttc_phasemon_dmtd_clk    : std_logic;
    signal ttc_phase_update         : std_logic;
    signal ttc_phase_meas_reset     : std_logic;
    signal ttc_clk_present          : std_logic;
    signal ttc_clk_present_psclk    : std_logic;
    signal ttc_clk_lost_pulse       : std_logic;
    signal ttc_clk_loss_cnt         : std_logic_vector(15 downto 0) := (others => '0');
    signal ttc_clk_loss_time        : std_logic_vector(15 downto 0) := (others => '0');
    signal dmtd_mmcm_locked         : std_logic;
    -- phase lock monitoring
    signal phase_locked             : std_logic;
    signal phase_unlock_pulse       : std_logic;
    signal phase_offset_pos         : std_logic_vector(15 downto 0) := (others => '0');
    signal phase_offset_neg         : std_logic_vector(15 downto 0) := (others => '0');
    signal phase_zero_cross         : std_logic;
    signal phase_zero_cross_psclk   : std_logic;
    signal phase_lock_update        : std_logic;
    signal phase_locked_psclk       : std_logic;
    signal phase_offset_pos_psclk   : std_logic_vector(15 downto 0) := (others => '0');
    signal phase_offset_neg_psclk   : std_logic_vector(15 downto 0) := (others => '0');
    signal phase_lock_update_psclk : std_logic;
    signal phase_lock_update1_psclk : std_logic;
   
    -- control signals moved to mmcm_ps_clk domain
    signal ctrl_psclk               : t_ttc_clk_ctrl;
    
--============================================================================
--                                                          Architecture begin
--============================================================================
begin

    mmcm_ps_clk <= clk_gbt_mgt_txout_i;

    -- CDC of the control signals to mmcm_ps_clk domain
    g_sync_reset_cnt :      entity work.synchronizer generic map(N_STAGES => 2) port map(async_i => ctrl_i.reset_cnt, clk_i   => mmcm_ps_clk, sync_o  => ctrl_psclk.reset_cnt);
    g_sync_reset_sync_fsm : entity work.synchronizer generic map(N_STAGES => 2) port map(async_i => ctrl_i.reset_sync_fsm, clk_i   => mmcm_ps_clk, sync_o  => ctrl_psclk.reset_sync_fsm);
    g_sync_reset_mmcm :     entity work.synchronizer generic map(N_STAGES => 2) port map(async_i => ctrl_i.reset_mmcm, clk_i   => mmcm_ps_clk, sync_o  => mmcm_reset_psclk_tmp);
    g_sync_pa_disable :     entity work.synchronizer generic map(N_STAGES => 2) port map(async_i => ctrl_i.phase_align_disable, clk_i   => mmcm_ps_clk, sync_o  => ctrl_psclk.phase_align_disable);
    g_sync_no_init_shift_o: entity work.synchronizer generic map(N_STAGES => 2) port map(async_i => ctrl_i.pa_no_init_shift_out, clk_i   => mmcm_ps_clk, sync_o  => ctrl_psclk.pa_no_init_shift_out);
    g_sync_man_shift_dir :  entity work.synchronizer generic map(N_STAGES => 2) port map(async_i => ctrl_i.pa_manual_shift_dir, clk_i   => mmcm_ps_clk, sync_o  => ctrl_psclk.pa_manual_shift_dir);
    g_sync_man_shift_ovrd : entity work.synchronizer generic map(N_STAGES => 2) port map(async_i => ctrl_i.pa_manual_shift_ovrd, clk_i   => mmcm_ps_clk, sync_o  => ctrl_psclk.pa_manual_shift_ovrd);

    i_mmcm_ps_en_manual_oneshot : entity work.oneshot_cross_domain
        port map(
            reset_i       => ctrl_i.reset_mmcm,
            input_clk_i   => ttc_clocks_bufg.clk_40,
            oneshot_clk_i => mmcm_ps_clk,
            input_i       => ctrl_i.pa_manual_shift_en,
            oneshot_o     => ctrl_psclk.pa_manual_shift_en
        );

    fsm_reset <= ctrl_psclk.reset_sync_fsm or ctrl_psclk.phase_align_disable;

    i_mmcm_reset_oneshot : entity work.oneshot
        port map(
            reset_i   => '0',
            clk_i     => mmcm_ps_clk,
            input_i   => mmcm_reset_psclk_tmp,
            oneshot_o => ctrl_psclk.reset_mmcm
        );

    -- Input buffering
    --------------------------------------
    i_ibufgds_clk_40_ttc : IBUFGDS
        port map(
            O  => clk_40_ttc_ibufgds,
            I  => clk_40_ttc_p_i,
            IB => clk_40_ttc_n_i
        );

    i_bufg_clk_40_ttc : BUFG
        port map(
            O => clk_40_ttc_bufg,
            I => clk_40_ttc_ibufgds
        );
        
    -- Main MMCM
    i_main_mmcm : MMCME2_ADV
        generic map(
            BANDWIDTH            => "OPTIMIZED",
            CLKOUT4_CASCADE      => false,
            COMPENSATION         => "ZHOLD",
            STARTUP_WAIT         => false,
            DIVCLK_DIVIDE        => 1,
            CLKFBOUT_MULT_F      => CFG_CLKFBOUT_MULT,
            CLKFBOUT_PHASE       => 0.000,
            CLKFBOUT_USE_FINE_PS => true,
            CLKOUT0_DIVIDE_F     => 24.000,
            CLKOUT0_PHASE        => 0.000,
            CLKOUT0_DUTY_CYCLE   => 0.500,
            CLKOUT0_USE_FINE_PS  => false,
            CLKOUT1_DIVIDE       => 12,
            CLKOUT1_PHASE        => 0.000,
            CLKOUT1_DUTY_CYCLE   => 0.500,
            CLKOUT1_USE_FINE_PS  => false,
            CLKOUT2_DIVIDE       => 8,
            CLKOUT2_PHASE        => 0.000,
            CLKOUT2_DUTY_CYCLE   => 0.500,
            CLKOUT2_USE_FINE_PS  => false,
            CLKOUT3_DIVIDE       => 6,
            CLKOUT3_PHASE        => 0.000,
            CLKOUT3_DUTY_CYCLE   => 0.500,
            CLKOUT3_USE_FINE_PS  => false,
            CLKOUT4_DIVIDE       => 3,
            CLKOUT4_PHASE        => 0.000,
            CLKOUT4_DUTY_CYCLE   => 0.500,
            CLKOUT4_USE_FINE_PS  => false,
            CLKIN1_PERIOD        => CFG_CLKIN1_PERIOD,
            REF_JITTER1          => 0.010)
        port map(
            -- Output clocks
            CLKFBOUT     => clkfbout,
            CLKFBOUTB    => open,
            CLKOUT0      => clk_40,
            CLKOUT0B     => open,
            CLKOUT1      => clk_80,
            CLKOUT1B     => open,
            CLKOUT2      => clk_120,
            CLKOUT2B     => open,
            CLKOUT3      => clk_160,
            CLKOUT3B     => open,
            CLKOUT4      => clk_320,
            CLKOUT5      => open,
            CLKOUT6      => open,
            -- Input clock control
            CLKFBIN      => clkfbin,
            CLKIN1       => clkin,
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
            PSEN         => (mmcm_ps_en and not ctrl_psclk.pa_manual_shift_ovrd) or (ctrl_psclk.pa_manual_shift_en and ctrl_psclk.pa_manual_shift_ovrd),
            PSINCDEC     => (mmcm_ps_incdec and not ctrl_psclk.pa_manual_shift_ovrd) or (ctrl_psclk.pa_manual_shift_dir and ctrl_psclk.pa_manual_shift_ovrd),
            PSDONE       => mmcm_ps_done,
            -- Other control and status signals
            LOCKED       => mmcm_locked_raw,
            CLKINSTOPPED => open,
            CLKFBSTOPPED => open,
            PWRDWN       => '0',
            RST          => ctrl_psclk.reset_mmcm
        );

    -- Output buffering
    -------------------------------------

    i_bufg_clk_40 : BUFG
        port map(
            O => ttc_clocks_bufg.clk_40,
            I => clk_40
        );

    i_bufg_clk_80 : BUFG
        port map(
            O => ttc_clocks_bufg.clk_80,
            I => clk_80
        );

    i_bufg_clk_120 : BUFG
        port map(
            O => ttc_clocks_bufg.clk_120,
            I => clk_120
        );

    i_bufg_clk_160 : BUFG
        port map(
            O => ttc_clocks_bufg.clk_160,
            I => clk_160
        );

    i_bufg_clk_320 : BUFG
        port map(
            O => ttc_clocks_bufg.clk_320,
            I => clk_320
        );

    clocks_o <= ttc_clocks_bufg;

    ------------------------------------------------------------------------------
    ------------------------ Use MGT refclk as the source ------------------------
    ------------------------------------------------------------------------------

    -- In case of the MGT refclk as the source, we have to align the MMCM 40MHz output to the backplane 40MHz clk manually. This has better clock performance, but the phase management can be tricky in CMS conditions

    clkin <= clk_gbt_mgt_txout_i;
    clkfbin <= clkfbout; -- use internal feedback for better performance, because we don't care about the skew

    ----------------------------------------------------------
    --------- Phase Alignment to TTC backplane clock ---------
    ----------------------------------------------------------
                          
    -- phase alignment FSM
    -- step 0) shifts the MMCM clock phase until the phase unlocks if it is locked
    -- step 1) if the current phase is in the zero-crossing region, shift out of that too
    -- step 2) measure the offset of the current phase from the target phase, and calculate how many shifts and in which direction are needed to get to the target phase
    -- step 3) do the number of phase shifts calculated in step 1
    -- NOTE: the units of the DMTD phase offset measurement is 25ns/13417 = 1.863307744ps, while the step of the MMCM shift using 960MHz VCO frequency is VCO_period / 56 = 18.601190476ps
    --       so each MMCM shift is very slightly less (~32fs) than 10 DMTD units. What we do is take the phase offset + 1/512th of the phase offset, and use that as the required shift count * 10.
    --       In this case even when shifting over half of the 25ns period (max we should ever need to do) the error is just 3ps
    
    process(mmcm_ps_clk)
    begin
        if (rising_edge(mmcm_ps_clk)) then
            if ((ctrl_psclk.reset_mmcm = '1') or (fsm_reset = '1')) then
                pa_state <= IDLE;
                sync_done_flag <= '0';
                mmcm_ps_en <= '0';
                mmcm_ps_done_timer <= (others => '0');
                searching_unlock <= '0';
                mmcm_ps_incdec <= '0';
                shift_cnt <= (others => '0');
            else
                sync_done_flag <= '0';
                mmcm_ps_en <= '0';
                mmcm_ps_done_timer <= (others => '0');
                
                case pa_state is
                    
                    -- wait for stable conditions to begin the phase alignment
                    when IDLE =>
                        -- wait for the MMCM to be locked, and TTC clk reported as present, and phase lock to be updated before moving forward
                        if (mmcm_locked = '1' and ttc_clk_present_psclk = '1' and phase_lock_update_psclk = '1') then
                            pa_state <= FIND_UNLOCK;
                        end if;
                        
                        searching_unlock <= '0';
                        mmcm_ps_incdec <= '0';
                        shift_cnt <= (others => '0');

                    -- find a good spot to start the phase alignment - if we are currently locked, then shift out of that (unless ctrl_psclk.pa_no_init_shift_out is set)
                    -- also if we are in zero-crossing region then shift out of that
                    -- the shift out is done by doing a constant number (SHIFT_OUT_COUNT) of shifts, and then coming back to IDLE to wait for a DMTD update (DMTD is held in reset while searching_unlock is high)
                    -- once we are in a good spot, then take the reading of how much we have to shift to get to the target
                    when FIND_UNLOCK =>
                        
                        -- if it's the last shift, then go to IDLE to wait for DMTD update
                        if (shift_cnt = to_unsigned(1, shift_cnt'length)) then
                            pa_state <= IDLE; 
                            shift_cnt <= (others => '0');
                            searching_unlock <= '0';
                            mmcm_ps_incdec <= '0';
                                                        
                        -- if we're already shifting, then keep doing that
                        elsif (shift_cnt /= to_unsigned(0, shift_cnt'length)) then
                            pa_state <= WAIT_SHIFT_DONE; 
                            mmcm_ps_en <= '1';
                            mmcm_ps_incdec <= '0';
                            shift_cnt <= shift_cnt - 1;
                            searching_unlock <= '1'; -- this also resets the DMTD
                            
                        -- if we just got here, then check if we're in a good spot, and if not then initiate the shift-out
                        elsif (phase_zero_cross_psclk = '1' or (phase_locked_psclk = '1' and ctrl_psclk.pa_no_init_shift_out = '0')) then
                            pa_state <= WAIT_SHIFT_DONE; 
                            mmcm_ps_en <= '1';
                            mmcm_ps_incdec <= '0';
                            shift_cnt <= SHIFT_OUT_COUNT;
                            searching_unlock <= '1'; -- this also resets the DMTD
                            
                        -- we are in a good spot - latch in the closest offset and direction from the target phase, and get them shifts going :)
                        else
                            pa_state <= FIND_LOCK;
                            searching_unlock <= '0';
                            if (phase_offset_pos_psclk > phase_offset_neg_psclk) then
                                shift_cnt <= unsigned(phase_offset_neg_psclk) + unsigned("000000000" & phase_offset_neg_psclk(15 downto 9)); -- offset + 1/512 * offset (see the main FSM description for details)
                                mmcm_ps_incdec <= '1';
                            else
                                shift_cnt <= unsigned(phase_offset_pos_psclk) + unsigned("000000000" & phase_offset_pos_psclk(15 downto 9)); -- offset + 1/512 * offset (see the main FSM description for details)
                                mmcm_ps_incdec <= '0';
                            end if;
                            
                        end if;
                        
                    -- we got here because a phase shift has been initiated, so now we just wait for mmcm_ps_done to go high, and come back to the original state (FIND_LOCK or FIND_UNLOCK)
                    when WAIT_SHIFT_DONE =>
                        if (mmcm_ps_done = '1') then
                            if (searching_unlock = '1') then
                                pa_state <= FIND_UNLOCK;
                            else
                                pa_state <= FIND_LOCK;
                            end if;
                        else
                            -- datasheet says MMCM should lock in 12 clock cycles and assert mmcm_ps_done for one clock period, but we have a timeout just in case
                            if (mmcm_ps_done_timer = MMCM_PS_DONE_TIMEOUT) then
                                pa_state <= IDLE; -- TODO: maybe go to FAIL?
                                mmcm_ps_done_timer <= (others => '0'); 
                            else
                                mmcm_ps_done_timer <= mmcm_ps_done_timer + 1;
                            end if;
                        end if;

                    -- shift the necessary amount to get to the lock target: every shift decrements the shift_cnt by 10, and we throw in an extra one every 292 shifts
                    -- once we get close to 0, then we're done (refer to the main description of the FSM above for details) 
                    when FIND_LOCK =>
                        
                        -- we have only up to 5 counts left, so we're done
                        if (shift_cnt < to_unsigned(6, shift_cnt'length)) then
                            pa_state <= SYNC_DONE; 
                            shift_cnt <= (others => '0');
                            
                        -- we have less than 10 counts, but more than 5, so we still want to do one more shift, but don't rollover the shift_cnt
                        elsif (shift_cnt < to_unsigned(10, shift_cnt'length)) then
                            pa_state <= WAIT_SHIFT_DONE; 
                            mmcm_ps_en <= '1';
                            shift_cnt <= (others => '0');

                        -- still shifting, and reducing by 10 counts on each shift (see main FSM description for details)
                        else
                            pa_state <= WAIT_SHIFT_DONE; 
                            mmcm_ps_en <= '1';
                            shift_cnt <= shift_cnt - 10;
                        end if;
                        
                        searching_unlock <= '0';

                    when SYNC_DONE =>
                        
                        sync_done_flag <= '1';
                        searching_unlock <= '0';
                        mmcm_ps_incdec <= '0';
                        shift_cnt <= (others => '0');
                        
                        if (mmcm_locked = '0' or ttc_clk_present_psclk = '0') then
                            pa_state <= FAIL;
                        else
                            pa_state <= SYNC_DONE;
                        end if;
                        
                    when FAIL =>
                        pa_state <= FAIL;
                        searching_unlock <= '0';
                        mmcm_ps_incdec <= '0';
                        shift_cnt <= (others => '0');
                        
                    when others =>
                        pa_state <= IDLE;
                        searching_unlock <= '0';
                        mmcm_ps_incdec <= '0';
                        shift_cnt <= (others => '0');
                    
                end case;
            end if;
        end if;
    end process;
    
    i_sync_lockmon_reset_clk40 : entity work.synchronizer generic map(N_STAGES => 3) port map(async_i => searching_unlock, clk_i   => ttc_clocks_bufg.clk_40, sync_o  => lockmon_reset_clk40);

    ------------ status monitoring ------------

    -- detect stable MMCM lock signal
    process(mmcm_ps_clk)
    begin
        if (rising_edge(mmcm_ps_clk)) then
            
            if ((mmcm_lock_stable_cnt = LOCK_STABLE_TIMEOUT) and (mmcm_locked_raw = '1') and (ctrl_psclk.reset_mmcm = '0')) then
                mmcm_locked <= '1';
            else
                mmcm_locked <= '0';
            end if;
            
            if ((mmcm_locked_raw = '0') or (ctrl_psclk.reset_mmcm = '1')) then
                mmcm_lock_stable_cnt <= 0;
            elsif (mmcm_lock_stable_cnt < LOCK_STABLE_TIMEOUT) then
                mmcm_lock_stable_cnt <= mmcm_lock_stable_cnt + 1;
            end if;
                        
        end if;
    end process;
    
    -- count MMCM unlocks
    
    i_mmcm_unlock_pulse : entity work.oneshot
        port map(
            reset_i   => '0',
            clk_i     => ttc_clocks_bufg.clk_40,
            input_i   => not mmcm_locked_clk40,
            oneshot_o => mmcm_unlock_p_clk40
        );
    
    i_cnt_mmcm_unlock : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => ttc_clocks_bufg.clk_40,
            reset_i   => ctrl_i.reset_cnt,
            en_i      => mmcm_unlock_p_clk40,
            count_o   => mmcm_unlock_cnt
        );

    -- count phase unlocks

    i_phase_unlock_pulse : entity work.oneshot
        port map(
            reset_i   => '0',
            clk_i     => ttc_clocks_bufg.clk_40,
            input_i   => not phase_locked,
            oneshot_o => phase_unlock_pulse
        );

    i_cnt_phase_unlock : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => ttc_clocks_bufg.clk_40,
            reset_i   => ctrl_i.reset_cnt,
            en_i      => phase_unlock_pulse,
            count_o   => phase_unlock_cnt
        );
    
    -- count the TTC clock loss
    
    i_ttc_clk_lost_pulse : entity work.oneshot
        port map(
            reset_i   => '0',
            clk_i     => ttc_clocks_bufg.clk_40,
            input_i   => not ttc_clk_present,
            oneshot_o => ttc_clk_lost_pulse
        );
    
    i_ttc_clk_lost_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => ttc_clocks_bufg.clk_40,
            reset_i   => ctrl_i.reset_cnt,
            en_i      => ttc_clk_lost_pulse,
            count_o   => ttc_clk_loss_cnt
        );
    
    -- time counters (number of seconds since certain events like phase unlock, ttc clk loss, sync done)

    i_ttc_clk_loss_time : entity work.seconds_counter
        generic map(
            g_CLK_FREQUENCY  => C_TTC_CLK_FREQUENCY_SLV,
            g_ALLOW_ROLLOVER => false,
            g_COUNTER_WIDTH  => 16
        )
        port map(
            clk_i     => ttc_clocks_bufg.clk_40,
            reset_i   => ttc_clk_lost_pulse or ctrl_i.reset_cnt,
            seconds_o => ttc_clk_loss_time
        );
    
    i_phase_unlock_time : entity work.seconds_counter
        generic map(
            g_CLK_FREQUENCY  => C_TTC_CLK_FREQUENCY_SLV,
            g_ALLOW_ROLLOVER => false,
            g_COUNTER_WIDTH  => 16
        )
        port map(
            clk_i     => ttc_clocks_bufg.clk_40,
            reset_i   => phase_unlock_pulse or ctrl_i.reset_cnt,
            seconds_o => phase_unlock_time
        );
            
    i_sync_done_time : entity work.seconds_counter
        generic map(
            g_CLK_FREQUENCY  => C_TTC_CLK_FREQUENCY_SLV,
            g_ALLOW_ROLLOVER => false,
            g_COUNTER_WIDTH  => 16
        )
        port map(
            clk_i     => ttc_clocks_bufg.clk_40,
            reset_i   => not sync_done_flag_clk40 or ctrl_i.reset_cnt,
            seconds_o => sync_done_time
        );   

        
    --- transfer status signals from psclk to clk40 domain    
    
    i_sync_sync_done_clk40 :        entity work.synchronizer generic map(N_STAGES => 2) port map(async_i => sync_done_flag, clk_i   => ttc_clocks_bufg.clk_40, sync_o  => sync_done_flag_clk40);
    i_sync_mmcm_locked_clk40 :      entity work.synchronizer generic map(N_STAGES => 2) port map(async_i => mmcm_locked, clk_i   => ttc_clocks_bufg.clk_40, sync_o  => mmcm_locked_clk40);
    
    -- status signal wiring    
    
    status_o.sync_done <= sync_done_flag_clk40 when ctrl_psclk.phase_align_disable = '0' else mmcm_locked_clk40;
    status_o.mmcm_locked <= mmcm_locked_clk40;
    status_o.phase_locked <= phase_locked;
    status_o.mmcm_unlock_cnt <= mmcm_unlock_cnt;
    status_o.phase_unlock_cnt <= phase_unlock_cnt;
    status_o.ttc_clk_loss_cnt <= ttc_clk_loss_cnt;
    status_o.sync_done_time <= sync_done_time;
    status_o.phase_unlock_time <= phase_unlock_time;
    status_o.ttc_clk_loss_time <= ttc_clk_loss_time;
        
        
    -------------- Phase monitoring of the 40MHz derived from TXOUTCLK vs TTC backplane -------------- 

    ---- DMTD phase monitor from TCDS / white rabbit ----    
    
    i_dmtd_clk : entity work.dmtd_clock
        generic map(
            G_INPUT_CLK_PERIOD => CFG_CLKIN1_PERIOD
        )
        port map(
            reset_i      => ctrl_i.reset_phase_mon_mmcm,
            clk_i        => clk_gbt_mgt_txout_i,
            clk_39_997_o => ttc_phasemon_dmtd_clk,
            locked_o     => dmtd_mmcm_locked
        );
       
    i_dmtd_phasemon : entity work.dmtd_phase_meas
        generic map(
            G_DEGLITCHER_THRESHOLD => 2000,
            G_COUNTER_BITS         => 14,
            G_MAX_VALID_PHASE      => 13417
        )
        port map(
            reset_i              => ttc_phase_meas_reset,
            -- clocks            
            clk_sys_i            => ttc_clocks_bufg.clk_40,
            clk_a_i              => ttc_clocks_bufg.clk_40,
            clk_b_i              => clk_40_ttc_bufg,
            clk_dmtd_i           => ttc_phasemon_dmtd_clk,
            -- clock present flags
            clk_a_present_o      => open,
            clk_b_present_o      => ttc_clk_present,
            -- average phase monitoring
            navg_log2_i          => ctrl_i.phase_mon_log2_navg,
            phase_avg_o          => ttc_phase(13 downto 0),
            phase_min_o          => ttc_phase_min(13 downto 0),
            phase_max_o          => ttc_phase_max(13 downto 0),
            phase_avg_p_o        => ttc_phase_update,
            dv_o                 => open,
            -- phase jump monitor
            phase_jump_thresh_i  => ctrl_i.phase_mon_jump_thresh(13 downto 0),
            phase_jump_cnt_o     => ttc_phase_jump_cnt,
            -- lock monitoring
            lockmon_navg_log2_i  => ctrl_i.lock_mon_log2_navg,
            lockmon_target_i     => ctrl_i.lock_mon_target_phase(13 downto 0),
            lockmon_tollerance_i => ctrl_i.lock_mon_tollerance(13 downto 0),
            lockmon_locked_o     => phase_locked,
            lockmon_offset_pos_o => phase_offset_pos(13 downto 0),
            lockmon_offset_neg_o => phase_offset_neg(13 downto 0),
            lockmon_zero_cross_o => phase_zero_cross,
            lockmon_update_o     => phase_lock_update
        );
    
    process(ttc_clocks_bufg.clk_40)
    begin
        if rising_edge(ttc_clocks_bufg.clk_40) then
            ttc_phase_meas_reset <= (not mmcm_locked_clk40) or ctrl_i.reset_cnt or lockmon_reset_clk40;
        end if;
    end process;
    
    i_phase_sample_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => true
        )
        port map(
            ref_clk_i => ttc_clocks_bufg.clk_40,
            reset_i   => ttc_phase_meas_reset,
            en_i      => ttc_phase_update,
            count_o   => status_o.phase_monitor.sample_counter
        );
    
    status_o.phase_monitor.phase <= ttc_phase;
    status_o.phase_monitor.phase_min <= ttc_phase_min;
    status_o.phase_monitor.phase_max <= ttc_phase_max;
    status_o.phase_monitor.phase_jump_cnt <= ttc_phase_jump_cnt;
    status_o.ttc_clk_present <= ttc_clk_present;
    status_o.phasemon_mmcm_locked <= dmtd_mmcm_locked;
    
    -- transfer the lockmon signals to psclk domain
    
    i_sync_phase_locked_psclk : entity work.synchronizer
        generic map(
            N_STAGES => 2
        )
        port map(
            async_i => phase_locked,
            clk_i   => mmcm_ps_clk,
            sync_o  => phase_locked_psclk
        );
    
    i_sync_ttc_clk_present_psclk : entity work.synchronizer
        generic map(
            N_STAGES => 2
        )
        port map(
            async_i => ttc_clk_present,
            clk_i   => mmcm_ps_clk,
            sync_o  => ttc_clk_present_psclk
        );

    i_sync_zero_cross_psclk : entity work.synchronizer
        generic map(
            N_STAGES => 2
        )
        port map(
            async_i => phase_zero_cross,
            clk_i   => mmcm_ps_clk,
            sync_o  => phase_zero_cross_psclk
        );
    
    i_sync_phase_lock_update : entity work.oneshot_cross_domain
        port map(
            reset_i       => ttc_phase_meas_reset,
            input_clk_i   => ttc_clocks_bufg.clk_40,
            oneshot_clk_i => mmcm_ps_clk,
            input_i       => phase_lock_update,
            oneshot_o     => phase_lock_update1_psclk
        );
    
    process (mmcm_ps_clk)
    begin
        if rising_edge(mmcm_ps_clk) then
            phase_lock_update_psclk <= phase_lock_update1_psclk;
            if (phase_lock_update1_psclk = '1') then
                phase_offset_pos_psclk <= phase_offset_pos;
                phase_offset_neg_psclk <= phase_offset_neg;
            end if;
        end if;
    end process;
    
    -------------- DEBUG -------------- 
    
--    i_clk_phase_check : entity work.clk_phase_check_v7
--        generic map(
--            FREQ_MHZ => 40.000
--        )
--        port map(
--            reset => mmcm_rst_i,
--            clk1  => clk_40_ttc_bufg,
--            clk2  => ttc_clocks_bufg.clk_40
--        );
--        
--    i_vio_ttc_clocks : component vio_ttc_clocks
--        port map(
--            clk        => mmcm_ps_clk,
--            probe_in0  => std_logic_vector(pll_lock_wait_timer),
--            probe_in1  => std_logic_vector(pll_lock_window),
--            probe_in2  => std_logic_vector(shift_back_fail_cnt),
--            probe_in3  => std_logic_vector(shift_cnt),
--            probe_in4  => std_logic_vector(unlock_cnt),
--            probe_in5  => std_logic_vector(mmcm_unlock_cnt),
--            probe_in6  => std_logic_vector(to_unsigned(pa_state_t'pos(pa_state), 3)),
--            probe_out0 => open,
--            probe_out1 => fsm_reset_debug
--        );

    
end ttc_clocks_arch;
--============================================================================
--                                                            Architecture end
--============================================================================
