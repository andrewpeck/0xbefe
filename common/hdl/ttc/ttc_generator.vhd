----------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date: 09/28/2017 13:50
-- Module Name: TTC GENERATOR
-- Project Name: GEM_AMC
-- Description: This module can be used to generate a fake TTC command stream (particularly for L1As and CalPulses), which is useful for calibration   
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.ttc_pkg.all;
use work.gem_pkg.all;

entity ttc_generator is
    port (
        -- reset
        reset_i                 : in  std_logic;

        -- TTC clocks
        ttc_clks_i              : in t_ttc_clks;

        -- Generated TTC commands
        ttc_cmds_o              : out t_ttc_cmds;
        
        -- control
        single_hard_reset_i     : in std_logic;
        single_resync_i         : in std_logic;
        single_ec0_i            : in std_logic;
        
        cyclic_l1a_gap_i        : in std_logic_vector(15 downto 0);
        cyclic_l1a_cnt_i        : in std_logic_vector(23 downto 0);
        cyclic_cal_l1a_gap_i    : in std_logic_vector(11 downto 0);
        cyclic_cal_prescale_i   : in std_logic_vector(11 downto 0);
        cyclic_l1a_start_i      : in std_logic;
        cyclic_l1a_running_o    : out std_logic
    );
end ttc_generator;

architecture Behavioral of ttc_generator is

    signal bx                   : unsigned(11 downto 0) := (others => '0');
    
    signal bc0                  : std_logic := '0';
    signal pre_bc0              : std_logic := '0';
    signal post_bc0             : std_logic := '0';
    
    signal single_hr_dly        : std_logic := '0';
    signal single_resync_dly    : std_logic := '0';
    signal single_ec_dly        : std_logic := '0';
    
    signal cyclic_cntdown       : unsigned(15 downto 0) := (others => '0');
    signal cyclic_l1a_fire      : std_logic := '0';
    signal cyclic_calpulse_fire : std_logic := '0';
    signal cyclic_l1a_veto      : std_logic := '0';
    signal cyclic_running       : std_logic := '0';
    signal cyclic_l1a_cntdown   : unsigned(23 downto 0);
    signal calpulse_prescale_cnt: unsigned(11 downto 0) := (others => '0');
       
begin

    -- bc0
    ttc_cmds_o.bc0 <= bc0;

    -- cyclic commands
    ttc_cmds_o.l1a <= cyclic_l1a_fire when cyclic_running = '1' else '0';
    ttc_cmds_o.calpulse <= cyclic_calpulse_fire when cyclic_running = '1' else '0';
    
    -- avoid sending out the single commands during a bc0 (if they come during bc0, delay them until the next bx)
    ttc_cmds_o.ec0 <= single_ec0_i when bc0 = '0' and post_bc0 = '0' else single_ec_dly or single_ec0_i when post_bc0 = '1' else '0';
    ttc_cmds_o.hard_reset <= single_hard_reset_i when bc0 = '0' and post_bc0 = '0' else single_hr_dly or single_hard_reset_i when post_bc0 = '1' else '0';
    ttc_cmds_o.resync <= single_resync_i when bc0 = '0' and post_bc0 = '0' else single_resync_dly or single_resync_i when post_bc0 = '1' else '0';
    
    -- unused commands
    ttc_cmds_o.start <= '0';
    ttc_cmds_o.stop <= '0';
    ttc_cmds_o.test_sync <= '0';
    
    -- other
    cyclic_l1a_running_o <= cyclic_running;
    
    --======== BC0 ========--
    
    process(ttc_clks_i.clk_40)
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset_i = '1') then
                bx <= (others => '0');
                bc0 <= '0';
                pre_bc0 <= '0';
                post_bc0 <= '0';
            else
                if (bx = unsigned(C_TTC_NUM_BXs) - 1) then
                    bx <= (others => '0');
                    bc0 <= '1';
                else
                    bx <= bx + 1;
                    bc0 <= '0';
                end if;
                
                if (bx = unsigned(C_TTC_NUM_BXs) - 2) then
                    pre_bc0 <= '1';
                else
                    pre_bc0 <= '0';
                end if;
                
                post_bc0 <= bc0;
                
            end if;
        end if;
    end process;

    --======== single commands ========--

    process(ttc_clks_i.clk_40)
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            single_hr_dly <= single_hard_reset_i;
            single_resync_dly <= single_resync_i;
            single_ec_dly <= single_ec0_i;
        end if;
    end process;

    --======== cyclic commands ========--

    -- cyclic countdown
    process(ttc_clks_i.clk_40)
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset_i = '1') then
                cyclic_cntdown <= unsigned(cyclic_l1a_gap_i);
            else
                if (cyclic_cntdown = x"0000") then
                    cyclic_cntdown <= unsigned(cyclic_l1a_gap_i);
                else
                    cyclic_cntdown <= cyclic_cntdown - 1;
                end if;
            end if;
        end if;
    end process;    

    -- firing the L1A and CalPulse
    -- if L1A coincides with BC0 then just don't send that L1A
    -- if CalPulse coincides with BC0 then don't send the calpulse and also veto the next L1A
    process(ttc_clks_i.clk_40)
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset_i = '1') then
                cyclic_l1a_fire <= '0';
                cyclic_calpulse_fire <= '0';
                cyclic_l1a_veto <= '0';
                calpulse_prescale_cnt <= (others => '0');
            else
                
                if (cyclic_cntdown = x"0000") then
                    if (cyclic_l1a_veto = '0') and (pre_bc0 = '0') then
                        cyclic_l1a_fire <= '1';
                    else
                        cyclic_l1a_fire <= '0';
                        cyclic_l1a_veto <= '0';
                    end if;
                else
                    cyclic_l1a_fire <= '0';
                end if;
                
                if (cyclic_cntdown = unsigned(cyclic_cal_l1a_gap_i)) and (cyclic_cal_l1a_gap_i /= x"000") then
                    if (pre_bc0 = '0' and cyclic_running = '1') then
                        if (std_logic_vector(calpulse_prescale_cnt) = cyclic_cal_prescale_i) then
                            cyclic_calpulse_fire <= '1';
                            calpulse_prescale_cnt <= (others => '0');
                        else
                            cyclic_calpulse_fire <= '0';
                            calpulse_prescale_cnt <= calpulse_prescale_cnt + 1;
                        end if;
                    else
                        cyclic_l1a_veto <= '1';
                        cyclic_calpulse_fire <= '0';
                    end if;
                else
                    cyclic_calpulse_fire <= '0';
                end if;
                
            end if;
        end if;
    end process;    

    -- cyclic run control
    process(ttc_clks_i.clk_40)
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset_i = '1') then
                cyclic_running <= '0';
                cyclic_l1a_cntdown <= (others => '0');
            else
                
                if (cyclic_running = '0') and (cyclic_l1a_start_i = '1') then
                    cyclic_l1a_cntdown <= unsigned(cyclic_l1a_cnt_i);
                    cyclic_running <= '1';
                end if;
                
                if (cyclic_running = '1') and (cyclic_l1a_cnt_i /= x"000000") and (cyclic_l1a_cntdown /= x"000000") and (cyclic_l1a_fire = '1') then
                    cyclic_l1a_cntdown <= cyclic_l1a_cntdown - 1;
                end if;
                
                if (cyclic_running = '1') and (cyclic_l1a_cnt_i /= x"000000") and (cyclic_l1a_cntdown = x"000000") then
                    cyclic_running <= '0';
                end if;
                
            end if;
        end if;
    end process;    

end Behavioral;
