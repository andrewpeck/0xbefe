------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2021-11-23
-- Module Name:    TTC_TX
-- Description:    This module provides a legacy TTC TX stream. The ttc_data_o should go to an MGT running at 640Mb/s line rate without encoding
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.mgt_pkg.all;
use work.board_config_package.all;
use work.ipbus.all;
use work.ttc_pkg.all;
use work.registers.all;

entity ttc_tx is
    generic(
        g_IPB_CLK_PERIOD_NS     : integer
    );
    port (
        reset_i                 : in  std_logic;
        
        ttc_clocks_i            : in  t_ttc_clks;
        ttc_cmds_i              : in  t_ttc_cmds;
        
        ttc_data_o              : out t_mgt_16b_tx_data;
                
        -- IPbus
        ipb_reset_i             : in  std_logic;
        ipb_clk_i               : in  std_logic;
        ipb_miso_o              : out ipb_rbus;
        ipb_mosi_i              : in  ipb_wbus                
    );
end ttc_tx;

architecture ttc_tx_arch of ttc_tx is

    constant RESET_TIME         : std_logic_vector(31 downto 0) := x"0000ffff";

    signal reset                : std_logic;
    signal reset_local          : std_logic;
    signal reset_cntdwn         : unsigned(31 downto 0) := x"0fffffff"; 
    
    -- ttc_out 4 bits mean: [0] A channel clk80 rising edge, [1] A channel clk80 falling edge, [2] B channel clk80 rising edge, [3] B channel clk80 falling edge
    -- bit [0] is = bit [3] of the previous cycle if channel A data is 0, and it is = NOT bit [3] of the previous cycle if channel A data is 1
    -- bit [2] is = bit [1] if channel B data is 0, and it is = NOT bit [1] if channel B data is 1
    -- bits [1] and [3] are always an inverted version of bits [0] and [2]
    signal ttc_out              : std_logic_vector(3 downto 0);
    signal ttc_out_reverse      : std_logic;
    signal ttc_out_test_en      : std_logic;
    signal ttc_out_test_pattern : std_logic_vector(15 downto 0);
    
    -- inputs
    signal req_l1a              : std_logic;
    signal req_l1a_manual       : std_logic;
    signal req_bcmd_enc         : std_logic_vector(15 downto 0); -- raw B channel data to send for a broadcast command (includes everything, including START, FMT, and STOP bits). It is transmitted high to low
    signal req_lcmd_enc         : std_logic_vector(41 downto 0); -- raw B channel data to send for a long command (includes everything, including START, FMT, and STOP bits). It is transmitted high to low
    signal req_bcmd_stb         : std_logic;
    signal req_lcmd_stb         : std_logic;
    
    -- regs
    signal ttc_rx_l1a_en        : std_logic;
    signal ttc_rx_bcmd_en       : std_logic;
    signal ttc_bgo_encoding     : t_ttc_conf;
    signal req_man_bcmd_data    : std_logic_vector(7 downto 0); -- manual broadcast command data
    signal req_man_lcmd_data    : std_logic_vector(31 downto 0); -- manual long command data
    signal req_man_bcmd_stb     : std_logic; -- manual broadcast command from registers
    signal req_man_lcmd_stb     : std_logic; -- manual long commnad from registers
    signal req_ttc_bcmd_stb     : std_logic; -- auto broadcast command from ttc input
    
    -- output encoding signals
    signal bcmd_data            : std_logic_vector(7 downto 0);
    signal lcmd_data            : std_logic_vector(31 downto 0);
    
    signal cmd_data             : std_logic_vector(41 downto 0);
    signal cmd_bit_idx          : integer range 0 to 41 := 0;
    signal cmd_active           : std_logic := '0';

    -- stats
    signal num_cancelled_cmd    : unsigned(15 downto 0) := (others => '0');

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------
        
begin

    req_l1a <= ttc_cmds_i.l1a when ttc_rx_l1a_en = '1' else req_l1a_manual;
    reset <= reset_local or reset_i;

    -- broadcast command encoding
    i_broadcast_cmd_enc : entity work.hamming_8_13
        port map(
            frame_i => bcmd_data,
            frame_o => req_bcmd_enc(13 downto 1)
        );
    
    req_bcmd_enc(15) <= '0'; -- START bit
    req_bcmd_enc(14) <= '0'; -- FMT bit
    req_bcmd_enc(0)  <= '1'; -- STOP bit
    
    process(ttc_clocks_i.clk_40)
    begin
        if rising_edge(ttc_clocks_i.clk_40) then
            if req_man_bcmd_stb = '1' then
                bcmd_data <= req_man_bcmd_data;
                req_bcmd_stb <= '1';
            elsif (ttc_cmds_i.bc0 and ttc_rx_bcmd_en) = '1' then
                bcmd_data <= ttc_bgo_encoding.cmd_bc0;
                req_bcmd_stb <= '1';
            elsif (ttc_cmds_i.oc0 and ttc_rx_bcmd_en) = '1' then
                bcmd_data <= ttc_bgo_encoding.cmd_oc0;
                req_bcmd_stb <= '1';
            elsif (ttc_cmds_i.ec0 and ttc_rx_bcmd_en) = '1' then
                bcmd_data <= ttc_bgo_encoding.cmd_ec0;
                req_bcmd_stb <= '1';
            elsif (ttc_cmds_i.calpulse and ttc_rx_bcmd_en) = '1' then
                bcmd_data <= ttc_bgo_encoding.cmd_calpulse;
                req_bcmd_stb <= '1';
            elsif (ttc_cmds_i.hard_reset and ttc_rx_bcmd_en) = '1' then
                bcmd_data <= ttc_bgo_encoding.cmd_hard_reset;
                req_bcmd_stb <= '1';
            elsif (ttc_cmds_i.resync and ttc_rx_bcmd_en) = '1' then
                bcmd_data <= ttc_bgo_encoding.cmd_resync;
                req_bcmd_stb <= '1';
            else
                bcmd_data <= (others => '0');
                req_bcmd_stb <= '0';
            end if;
        end if;
    end process;

    -- long command encoding
    i_long_cmd_enc : entity work.hamming_32_39
        port map(
            frame_i => lcmd_data,
            frame_o => req_lcmd_enc(39 downto 1)
        );

    req_lcmd_enc(41) <= '0'; -- START bit
    req_lcmd_enc(40) <= '1'; -- FMT bit
    req_lcmd_enc(0)  <= '1'; -- STOP bit
    
    process(ttc_clocks_i.clk_40)
    begin
        if rising_edge(ttc_clocks_i.clk_40) then
            if req_man_lcmd_stb = '1' then
                lcmd_data <= req_man_lcmd_data;
                req_lcmd_stb <= '1';
            else
                lcmd_data <= (others => '0');
                req_lcmd_stb <= '0';
            end if;
        end if;
    end process;

    -- ttc out encoding
    process(ttc_clocks_i.clk_40)
        variable ttc_out_tmp        : std_logic_vector(3 downto 0) := (others => '0');
        variable ttc_out_last_bit   : std_logic; -- last bit of the previous cycle
    begin
        if rising_edge(ttc_clocks_i.clk_40) then
            if reset = '1' then
                reset_cntdwn <= unsigned(RESET_TIME);
                ttc_out_last_bit := '0';
                ttc_out <= (others => '0');
                ttc_out_tmp := (others => '0');
                cmd_bit_idx <= 0;
                cmd_data <= (others => '0');
                num_cancelled_cmd <= (others => '0');
                cmd_active <= '0';
            else
                if reset_cntdwn = x"00000000" then
                    
--                    -- channel A encoding
--                    if req_l1a = '1' then
--                        ttc_out_tmp(0) := not ttc_out_last_bit; -- invert when L1A is high
--                        ttc_out_tmp(1) := ttc_out_last_bit;     -- invert always
--                    else
--                        ttc_out_tmp(0) := ttc_out_last_bit;     -- don't invert when L1A is low
--                        ttc_out_tmp(1) := not ttc_out_last_bit; -- invert always
--                    end if;
                    
                    -- channel B latch in the command
                    if cmd_bit_idx = 0 then
                        if req_bcmd_stb = '1' then
                            cmd_data(15 downto 0) <= req_bcmd_enc;
                            cmd_bit_idx <= 15;
                            cmd_active <= '1';
                        elsif req_lcmd_stb = '1' then
                            cmd_data <= req_lcmd_enc;
                            cmd_bit_idx <= 41;
                            cmd_active <= '1';
                        else
                            cmd_data <= (others => '0');
                            cmd_bit_idx <= 0;
                            cmd_active <= '0';
                        end if;
                    else
                        cmd_bit_idx <= cmd_bit_idx - 1;
                        cmd_active <= '1';
                        if ((req_bcmd_stb = '1') or (req_lcmd_stb = '1')) and num_cancelled_cmd /= (num_cancelled_cmd'range => '1') then
                            num_cancelled_cmd <= num_cancelled_cmd + 1;
                        end if;
                    end if;


                    -- last bit of the previous cycle
                    if ttc_out_reverse = '0' then
                        ttc_out_last_bit := ttc_out(3);
                    else
                        ttc_out_last_bit := ttc_out(0);
                    end if;

                    if req_l1a = '1' then
                        ttc_out_tmp(0) := not ttc_out_last_bit;     -- invert when L1A is high
                    else
                        ttc_out_tmp(0) := ttc_out_last_bit; -- do not invert when L1A is low
                    end if;

                    ttc_out_tmp(1) := not ttc_out_tmp(0); -- invert always

                    -- channel B encoding
                    if (cmd_data(cmd_bit_idx) = '1') or (cmd_active = '0') then
                        ttc_out_tmp(2) := not ttc_out_tmp(1); -- invert when B channel data is high or the B channel is idle
                    else
                        ttc_out_tmp(2) := ttc_out_tmp(1); -- invert when B channel data is high or the B channel is idle
                    end if;

                    ttc_out_tmp(3) := not ttc_out_tmp(2); -- invert always
                    
--                    -- channel B encoding
--                    if (cmd_data(cmd_bit_idx) = '1') or (cmd_active = '0') then
--                        ttc_out_tmp(2) := not ttc_out_tmp(1); -- invert when B channel data is high or the B channel is idle
--                        ttc_out_tmp(3) := ttc_out_tmp(1);     -- invert always
--                    else
--                        ttc_out_tmp(2) := ttc_out_tmp(1);     -- do not invert when B channel data is low and it is not idle
--                        ttc_out_tmp(3) := not ttc_out_tmp(1); -- invert always
--                    end if;
                    
                    ttc_out <= ttc_out_tmp;
--                        ttc_out <= x"3"; -- send clock without data
                    reset_cntdwn <= x"00000000";
                    
                -- RESET
                else
                    reset_cntdwn <= reset_cntdwn - 1;

                    ttc_out_last_bit := '0';
                    ttc_out <= (others => '0');
                    ttc_out_tmp := (others => '0');
                    cmd_bit_idx <= 0;
                    cmd_data <= (others => '0');
                end if;
            end if;
        end if;
    end process; 

    process(ttc_clocks_i.clk_40)
    begin
        if rising_edge(ttc_clocks_i.clk_40) then
            if ttc_out_test_en = '1' then
                ttc_data_o.txdata <= ttc_out_test_pattern;
            elsif ttc_out_reverse = '0' then
                -- map to MGT out (quadrouple each bit to get from 640Mb/s to 160Mb/s)
                ttc_data_o.txdata <= ttc_out(3) & ttc_out(3) & ttc_out(3) & ttc_out(3) &
                                     ttc_out(2) & ttc_out(2) & ttc_out(2) & ttc_out(2) &
                                     ttc_out(1) & ttc_out(1) & ttc_out(1) & ttc_out(1) &
                                     ttc_out(0) & ttc_out(0) & ttc_out(0) & ttc_out(0);
            else
                ttc_data_o.txdata <= ttc_out(0) & ttc_out(0) & ttc_out(0) & ttc_out(0) &
                                     ttc_out(1) & ttc_out(1) & ttc_out(1) & ttc_out(1) &
                                     ttc_out(2) & ttc_out(2) & ttc_out(2) & ttc_out(2) &
                                     ttc_out(3) & ttc_out(3) & ttc_out(3) & ttc_out(3);
            end if;
        end if;
    end process; 
    
    ttc_data_o.txchardispmode <= (others => '0');
    ttc_data_o.txchardispval <= (others => '0');
    ttc_data_o.txcharisk <= (others => '0');

    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================
    
end ttc_tx_arch;
