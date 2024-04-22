----------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date: 2023-04-24
-- Module Name: TCDS2
-- Project Name:
-- Description: This is a wrapper for TCDS2   
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.ttc_pkg.all;
use work.common_pkg.all;

use work.tcds2_interface_pkg.all;
use work.tcds2_link_speed_pkg.all;
use work.tcds2_streams_pkg.all;

entity tcds2 is
    generic (
        -- set this to true if you want to use a cleaned 40MHz input to be used for ttc_clks, in this case you have to provide it on the clk40_cleaned_i port
        -- if this is set to false, then the fabric 40MHz coming from the tcds2 ip will be used for ttc_clks
        G_USE_40MHZ_CLEANED_IN  : boolean
    );
    port (
        -- reset
        reset_i             : in  std_logic;

        -- free running 125MHz clock
        clk_125_i           : in  std_logic;

        -- MGT data interface.
        mgt_tx_p_o          : out std_logic;
        mgt_tx_n_o          : out std_logic;
        mgt_rx_p_i          : in  std_logic;
        mgt_rx_n_i          : in  std_logic;
        
        -- mgt refclk from ibufds_gte
        mgt_refclk_320_i    : in  std_logic;
        
        -- LHC clock inputs
        clk40_cleaned_i     : in  std_logic; -- fabric clk coming from an MGT refclk buffer
        clk_backplane_p_i   : in  std_logic; -- expects this to be an MGT refclk
        clk_backplane_n_i   : in  std_logic; -- expects this to be an MGT refclk

        -- LHC clock primary and secondary outputs to be exported out of FPGA and into the synthesizer
        clk40_out_pri_p_o   : out std_logic;
        clk40_out_pri_n_o   : out std_logic;
        clk40_out_sec_p_o   : out std_logic;
        clk40_out_sec_n_o   : out std_logic;
        
        -- TTC clocks and commands
        ttc_clks_o          : out t_ttc_clks;
        ttc_cmds_o          : out t_ttc_cmds;

        -- Clock control and status
        clk_ctrl_i          : in  t_ttc_clk_ctrl;
        clk_status_o        : out t_ttc_clk_status       
    );
end tcds2;

architecture Behavioral of tcds2 is

    component vio_tcds2
        port(
            clk        : in  std_logic;
            probe_in0  : in  std_logic;
            probe_in1  : in  std_logic;
            probe_in2  : in  std_logic;
            probe_in3  : in  std_logic;
            probe_in4  : in  std_logic;
            probe_in5  : in  std_logic;
            probe_in6  : in  std_logic;
            probe_in7  : in  std_logic;
            probe_in8  : in  std_logic;
            probe_in9  : in  std_logic;
            probe_in10 : in  std_logic;
            probe_in11 : in  std_logic_vector(31 downto 0);
            probe_in12 : in  std_logic_vector(31 downto 0);
            probe_in13 : in  std_logic_vector(31 downto 0);
            probe_in14 : in  std_logic_vector(31 downto 0);
            probe_in15 : in  std_logic_vector(31 downto 0);
            probe_out0 : out std_logic;
            probe_out1 : out std_logic;
            probe_out2 : out std_logic;
            probe_out3 : out std_logic;
            probe_out4 : out std_logic;
            probe_out5 : out std_logic;
            probe_out6 : out std_logic
        );
    end component;

    component freq_meter is
        generic(
            REF_F       : std_logic_vector(31 downto 0);
            N           : integer
        );
        port(
            ref_clk     : in  std_logic;
            f           : in  std_logic_vector(N - 1 downto 0);
            freq        : out t_std32_array(N - 1 downto 0)
        );
    end component freq_meter;

    constant CLK_STABLE_FREQ    : integer := 125_000_000;

    signal reset_local          : std_logic;
    signal reset_local_sync40   : std_logic;

    signal ctrl                 : tcds2_interface_ctrl_t;
    signal stat                 : tcds2_interface_stat_t;
                                
    signal orbit                : std_logic;
                                
    signal ttc2_arr             : tcds2_ttc2_array(1 downto 0);
    signal tts2_arr             : tcds2_tts2_value_array(1 downto 0);
                                
    signal ttc_src_clk          : std_logic;
    signal clk40_fabric         : std_logic;
    signal ttc_clks             : t_ttc_clks;
                                
    signal clk_backplane        : std_logic;
    signal clk_bp_tmp           : std_logic;
    signal clk_bp_gt            : std_logic;
                                
    signal clk40_out_pri        : std_logic;
    signal clk40_out_sec        : std_logic;
                                
    signal clk_40_oddr_c        : std_logic;
    signal clk_40_oddr_d1       : std_logic;
    signal clk_40_oddr_d2       : std_logic;
                                
    signal freq_clk40_backplane : std_logic_vector(31 downto 0);
    signal freq_clk40_fabric    : std_logic_vector(31 downto 0);
    signal freq_clk40_cleaned   : std_logic_vector(31 downto 0);
    signal freq_oddr_c          : std_logic_vector(31 downto 0);
    signal freq_oddr_d          : std_logic_vector(31 downto 0);
        
begin

    i_sync_reset40 : entity work.synch
        generic map(
            N_STAGES => 8,
            IS_RESET => true
        )
        port map(
            async_i => reset_local,
            clk_i   => clk40_fabric,
            sync_o  => reset_local_sync40
        );

    --=================================================
    -- TCDS2 IP
    --=================================================
    
    i_tcds2_interface : entity work.tcds2_interface_with_mgt
        generic map(
            G_MGT_TYPE               => MGT_TYPE_GTYE4,
            G_LINK_SPEED             => TCDS2_LINK_SPEED_10G,
            G_INCLUDE_PRBS_LINK_TEST => true
        )
        port map(
            ctrl_i            => ctrl,
            stat_o            => stat,
            clk_sys_125mhz    => clk_125_i,
            mgt_tx_p_o        => mgt_tx_p_o,
            mgt_tx_n_o        => mgt_tx_n_o,
            mgt_rx_p_i        => mgt_rx_p_i,
            mgt_rx_n_i        => mgt_rx_n_i,
            clk_320_mgt_ref_i => clk_bp_gt, --mgt_refclk_320_i,
            clk_40_o          => clk40_fabric,
            clk_40_oddr_c_o   => clk_40_oddr_c,
            clk_40_oddr_d1_o  => clk_40_oddr_d1,
            clk_40_oddr_d2_o  => clk_40_oddr_d2,
            orbit_o           => orbit,
            channel0_ttc2_o   => ttc2_arr(0),
            channel0_tts2_i   => tts2_arr(0 downto 0),
            channel1_ttc2_o   => ttc2_arr(1),
            channel1_tts2_i   => tts2_arr(1 downto 1)
        );

    --===================================--
    -- Input and output buffers
    --===================================--

    -- backplane clk in

    i_clk40_backplane_ibufds_gte : IBUFDS_GTE4
        port map(
            O     => clk_bp_gt,
            ODIV2 => clk_bp_tmp,
            CEB   => '0',
            I     => clk_backplane_p_i,
            IB    => clk_backplane_n_i
        );

    i_refclk1_div2_bufg : BUFG_GT
        port map(
            O       => clk_backplane,
            CE      => '1',
            CEMASK  => '0',
            CLR     => '0',
            CLRMASK => '0',
            DIV     => "000",
            I       => clk_bp_tmp
        );        

    -- primary clk out

    i_clk40_out_pri_oddr : oddre1
        generic map(
            is_c_inverted  => '0',
            is_d1_inverted => '0',
            is_d2_inverted => '0',
            srval          => '0'
        )
        port map(
            sr => '0',
            c  => clk_40_oddr_c,
            d1 => clk_40_oddr_d1,
            d2 => clk_40_oddr_d2,
            q  => clk40_out_pri
        );

    i_clk40_out_pri_obufds : obufds
        port map(
            i  => clk40_out_pri,
            o  => clk40_out_pri_p_o,
            ob => clk40_out_pri_n_o
        );

--    i_clk40_out_pri_obufds : obufds
--        port map(
--            i  => clk40_fabric,
--            o  => clk40_out_pri_p_o,
--            ob => clk40_out_pri_n_o
--        );    
    
    -- secondary clk out
    
    clk40_out_sec <= clk_backplane;
    
    i_clk40_out_sec_obufds : obufds
        port map(
            i  => clk40_out_sec,
            o  => clk40_out_sec_p_o,
            ob => clk40_out_sec_n_o
        );

-- DEBUG: test different outputs
--    
--    i_clk40_out_pri_obufds : obufds
--        port map(
--            i  => clk40_fabric,
--            o  => clk40_out_sec_p_o,
--            ob => clk40_out_sec_n_o
--        );    
--
----    i_clk40_sec_oserdes : OSERDESE3
----        generic map(
----            SIM_DEVICE => "ULTRASCALE_PLUS",
----            DATA_WIDTH         => 8,
----            INIT               => '0',
----            IS_CLKDIV_INVERTED => '0',
----            IS_CLK_INVERTED    => '0',
----            IS_RST_INVERTED    => '0',
----            ODDR_MODE          => "TRUE" -- Xilinx says do not modify this hmm
----        )
----        port map(
----            OQ     => clk40_out_sec,
----            T_OUT  => open,
----            CLK    => clk_40_oddr_c, -- clk320
----            CLKDIV => clk40_fabric, -- clk40 sourced from 320 with bufgce_div
----            D      => x"f0",
----            RST    => reset_local_sync40,
----            T      => '0'
----        );
----
----    i_clk40_out_sec_obufds : obufds
----        port map(
----            i  => clk40_out_sec,
----            o  => clk40_out_pri_p_o,
----            ob => clk40_out_pri_n_o
----        );
--
--    i_clk40_out_sec_obufds : obufds
--        port map(
--            i  => clk40_fabric,
--            o  => clk40_out_pri_p_o,
--            ob => clk40_out_pri_n_o
--        );

    --================================--
    -- Freq counters
    --================================--

--    signal freq_clk40_backplane : std_logic_vector(31 downto 0);
--    signal freq_clk40_fabric    : std_logic_vector(31 downto 0);
--    signal freq_clk40_cleaned   : std_logic_vector(31 downto 0);

    i_clk40_backplane_freq_meter : freq_meter
        generic map(
            REF_F => std_logic_vector(to_unsigned(CLK_STABLE_FREQ, 32)),
            N     => 1
        )
        port map(
            ref_clk => clk_125_i,
            f       => (0 => clk_backplane),
            freq(0) => freq_clk40_backplane 
        );

    i_clk40_fabric_freq_meter : freq_meter
        generic map(
            REF_F => std_logic_vector(to_unsigned(CLK_STABLE_FREQ, 32)),
            N     => 1
        )
        port map(
            ref_clk => clk_125_i,
            f       => (0 => clk40_fabric),
            freq(0) => freq_clk40_fabric
        );
        
    i_clk40_cleaned_freq_meter : freq_meter
        generic map(
            REF_F => std_logic_vector(to_unsigned(CLK_STABLE_FREQ, 32)),
            N     => 1
        )
        port map(
            ref_clk => clk_125_i,
            f       => (0 => clk40_cleaned_i),
            freq(0) => freq_clk40_cleaned
        );
        
    --================================--
    -- Fabric clocks
    --================================--

    g_use_cleaned_40mhz : if G_USE_40MHZ_CLEANED_IN generate
        ttc_src_clk <= clk40_cleaned_i;
    else generate
        ttc_src_clk <= clk40_fabric;
    end generate;

    i_ttc_clks : entity work.ttc_clocks
        generic map(
            g_INPUT_IS_40MHZ            => TRUE,
            g_INST_BUFG_GT              => false,
            g_LPGBT_2P56G_LOOPBACK_TEST => false,
            g_CLK_STABLE_FREQ           => 125_000_000,
            g_GEM_STATION               => 0,
            g_TXPROGDIVCLK_USED         => false
        )
        port map(
            clk_stable_i        => clk_125_i,
            clk_gbt_mgt_txout_i => ttc_src_clk,
            clk_gbt_mgt_ready_i => '1',
            clocks_o            => ttc_clks,
            ctrl_i              => clk_ctrl_i,
            status_o            => clk_status_o
        );
        
    --=================================================
    -- Wiring
    --=================================================
    
    tts2_arr <= (others => C_TCDS2_TTS2_VALUE_READY);
    ttc_cmds_o <= TTC_CMDS_NULL;
    ttc_clks_o <= ttc_clks;

    --=================================================
    -- Debug
    --=================================================

    i_vio : vio_tcds2
        port map(
            clk        => clk_125_i,
            probe_in0  => stat.is_link_speed_10g,
            probe_in1  => stat.has_link_test_mode,
            probe_in2  => stat.has_spy_registers,
            probe_in3  => stat.mgt_powergood,
            probe_in4  => stat.mgt_txpll_lock,
            probe_in5  => stat.mgt_rxpll_lock,
            probe_in6  => stat.mgt_reset_tx_done,
            probe_in7  => stat.mgt_reset_rx_done,
            probe_in8  => stat.mgt_tx_ready,
            probe_in9  => stat.mgt_rx_ready,
            probe_in10 => stat.rx_frame_locked,
            probe_in11 => stat.rx_frame_unlock_count,
            probe_in12 => stat.prbschk_unlock_count,
            probe_in13 => freq_clk40_backplane,
            probe_in14 => freq_clk40_fabric,
            probe_in15 => freq_clk40_cleaned,
            probe_out0 => ctrl.mgt_reset_all, 
            probe_out1 => ctrl.mgt_reset_tx,  
            probe_out2 => ctrl.mgt_reset_rx,  
            probe_out3 => ctrl.link_test_mode,
            probe_out4 => ctrl.prbsgen_reset, 
            probe_out5 => ctrl.prbschk_reset,
            probe_out6 => reset_local
        );

end Behavioral;
