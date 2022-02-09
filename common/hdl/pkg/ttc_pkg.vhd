-------------------------------------------------------------------------------
--                                                                            
--       Unit Name: ttc_pkg                                            
--                                                                            
--     Description: 
--
--                                                                            
-------------------------------------------------------------------------------
--                                                                            
--           Notes:                                                           
--                                                                            
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

--============================================================================
--                                                         Package declaration
--============================================================================
package ttc_pkg is

    constant C_TTC_CLK_FREQUENCY        : integer := 40_079_000;
    constant C_TTC_CLK_FREQUENCY_SLV    : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(C_TTC_CLK_FREQUENCY, 32));
    constant C_TTC_NUM_BXs              : std_logic_vector(11 downto 0) := x"dec";

    type t_ttc_clks is record
        clk_40              : std_logic;
        clk_80              : std_logic;
        clk_120             : std_logic;
        clk_200             : std_logic;
        clk_160             : std_logic;
        clk_320             : std_logic;
    end record;

    type t_ttc_cmds is record
        l1a        : std_logic;
        bc0        : std_logic;
        ec0        : std_logic;
        oc0        : std_logic;
        resync     : std_logic;
        hard_reset : std_logic;
        start      : std_logic;
        stop       : std_logic;
        calpulse   : std_logic;
        test_sync  : std_logic;
    end record;

    type t_ttc_cmds_arr is array(integer range <>) of t_ttc_cmds;

    type t_ttc_conf is record
        cmd_bc0        : std_logic_vector(7 downto 0);
        cmd_ec0        : std_logic_vector(7 downto 0);
        cmd_oc0        : std_logic_vector(7 downto 0);
        cmd_resync     : std_logic_vector(7 downto 0);
        cmd_start      : std_logic_vector(7 downto 0);
        cmd_stop       : std_logic_vector(7 downto 0);
        cmd_hard_reset : std_logic_vector(7 downto 0);
        cmd_test_sync  : std_logic_vector(7 downto 0);
        cmd_calpulse   : std_logic_vector(7 downto 0);
    end record;

    type t_ttc_clk_ctrl is record
        reset_cnt               : std_logic; -- reset the counters
        reset_sync_fsm          : std_logic; -- reset the sync FSM, this will restart the phase alignment procedure
        reset_mmcm              : std_logic; -- reset the MMCM, this will reset the MMCM and also restart the phase alignment procedure
        reset_phase_mon_mmcm    : std_logic; -- reset the phase monitor MMCMs
        phase_align_disable     : std_logic; -- disable the phase alignment and force the sync_done signal high -- this may be useful in setups where backplane clock does not exist (no AMC13), and only the jitter cleaned clock is available
        pa_no_init_shift_out    : std_logic; -- if this is set to 0 (default), then when the phase alignment FSM is reset, it will first shift the phase out of lock if it is currently locked, and then start searching for lock as usual
        pa_manual_shift_en      : std_logic; -- positive edge of this signal will do one shift in the selected direction
        pa_manual_shift_dir     : std_logic; -- direction of the manual shifting
        pa_manual_shift_ovrd    : std_logic; -- if this is set to 1, then shift direction is overriden
        phase_mon_log2_navg     : std_logic_vector(3 downto 0); -- Number of samples to average in the phase monitor. The setting is in units of log2(n), meaning that e.g. a setting of 4 will result in averaging 16 samples, a setting of 5 will average 32 samples, etc
        phase_mon_jump_thresh   : std_logic_vector(15 downto 0); -- The threshold on the difference of the two consecutive phase samples that is considered a "phase jump"
        lock_mon_log2_navg      : std_logic_vector(3 downto 0); -- Phase lock monitor (used in phase alignment): Number of phase samples to average. The setting is in units of log2(n), meaning that e.g. a setting of 4 will result in averaging 16 samples, a setting of 5 will average 32 samples, etc. The higher the number, the better the accuracy, but it will also take longer to complete the phase alignment.
        lock_mon_target_phase   : std_logic_vector(15 downto 0); -- Phase lock monitor (used in phase alignment): the target phase between the TTC clock and the fabric clocks that is considered locked. The units are the same as in the phase monitor. NOTE: do not set this at or close to 0 or the maximum phase -- this could result in unreliable phase alignment, it should be placed at least 1ns away from the 0/max rollover point.
        lock_mon_tollerance     : std_logic_vector(15 downto 0); -- Phase lock monitor (used in phase alignment): this is the half-size of the lock window, or the number of phase units plus/minus the target (LOCKMON_TARGET_PHASE) where the phase is considered locked
    end record;    

    type t_ttc_clk_ctrl_arr is array(integer range<>) of t_ttc_clk_ctrl;

    type t_ttc_ctrl is record
        clk_ctrl         : t_ttc_clk_ctrl;
        reset_local      : std_logic;
        cnt_reset        : std_logic;        
        l1a_enable       : std_logic;
        cmd_enable       : std_logic;
        calib_mode       : std_logic;
        l1a_delay        : std_logic_vector(9 downto 0);
    end record;

    type t_phase_monitor_status is record
        phase               : std_logic_vector(15 downto 0); -- phase difference between the rising edges of the jitter cleaned 40MHz and backplane TTC 40MHz clocks
        sample_counter      : std_logic_vector(15 downto 0); -- simple wrapping counter of samples - this can be used by fast reading applications to check if the phase value has been updated since the last reading
        phase_min           : std_logic_vector(15 downto 0); -- the minimum measured phase value since last reset
        phase_max           : std_logic_vector(15 downto 0); -- the maximum measured phase value since last reset
        phase_jump_cnt      : std_logic_vector(15 downto 0); -- number of times a phase jump has been detected
    end record;
    
    type t_ttc_clk_status is record
        sync_done               : std_logic; -- Jitter cleaned clock is locked and phase alignment procedure is finished (use this to start the GTH startup FSM)
        mmcm_locked             : std_logic; -- MMCM is locked (input is jitter cleaned 160MHz clock)
        phase_locked            : std_logic; -- Jitter cleaned 40MHz clock is in phase with the backplane 40MHz TTC clock
        phasemon_mmcm_locked    : std_logic; -- The phase measurement MMCM is locked (DMTD clock)
        ttc_clk_present         : std_logic; -- The backplane 40MHz TTC clock is present 
        mmcm_unlock_cnt         : std_logic_vector(15 downto 0); -- number of times the MMCM lock signal has gone low
        phase_unlock_cnt        : std_logic_vector(15 downto 0); -- number of times the phase monitoring PLL lock signal has gone low
        ttc_clk_loss_cnt        : std_logic_vector(15 downto 0); -- number of times that the TTC clock was lost (the ttc_clk_present has gone low)
        sync_done_time          : std_logic_vector(15 downto 0); -- number of seconds since last sync was done
        phase_unlock_time       : std_logic_vector(15 downto 0); -- number of seconds since last phase unlock
        ttc_clk_loss_time       : std_logic_vector(15 downto 0); -- number of seconds since last TTC clock loss
        phase_monitor           : t_phase_monitor_status;
        clk40_freq              : std_logic_vector(31 downto 0); -- frequency of clk40
    end record;

    type t_bc0_status is record
        unlocked_cnt : std_logic_vector(15 downto 0);
        udf_cnt      : std_logic_vector(15 downto 0);
        ovf_cnt      : std_logic_vector(15 downto 0);
        locked       : std_logic;
        err          : std_logic;
    end record;

    type t_ttc_status is record
        clk_status  : t_ttc_clk_status;
        bc0_status  : t_bc0_status;
        single_err  : std_logic_vector(15 downto 0);
        double_err  : std_logic_vector(15 downto 0);
    end record;

    type t_ttc_cmd_cntrs is record
        l1a        : std_logic_vector(31 downto 0);
        bc0        : std_logic_vector(31 downto 0);
        ec0        : std_logic_vector(31 downto 0);
        oc0        : std_logic_vector(31 downto 0);
        resync     : std_logic_vector(31 downto 0);
        hard_reset : std_logic_vector(31 downto 0);
        start      : std_logic_vector(31 downto 0);
        stop       : std_logic_vector(31 downto 0);
        calpulse   : std_logic_vector(31 downto 0);
        test_sync  : std_logic_vector(31 downto 0);
    end record;

    type t_ttc_daq_cntrs is record
        l1id  : std_logic_vector(43 downto 0);
        orbit : std_logic_vector(31 downto 0);
        bx    : std_logic_vector(11 downto 0);
    end record;

end ttc_pkg;
--============================================================================
--                                                                 Package end 
--============================================================================
