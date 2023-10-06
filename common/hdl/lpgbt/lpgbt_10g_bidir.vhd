------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    20:38:00 2016-08-30
-- Module Name:    lpgbt_loopback_test
-- Description:    This module implements LpGBT line encoder/decoder for a bidirectional 10.24Gb/s link (MGT instantiation is not included).
--                 The RX side is using the LpGBT-FPGA module, while TX side is implemented using the LpGBT ASIC model.
--                 MGT configuration should use 10.24Gb/s line rate without encoding, with 32bit external interface running at 320MHz user clock.
--                 SHOW_REALIGN_COMMA should be set to FALSE, and RXSLIDE_MODE should be set to PMA, and mgt_rx_slide_o should be connected to MGT RXSLIDE port.
--                 The MGT ref clocks on both the transmitter and receiver should be synchronous (derived from the TTC clock). Note: clk40 should be derived from the same source as ref clk.
--                 The RX doesn't need elastic buffers (in any case, there's no clock correction capability), and RXUSRCLK can be either on BUFH or BUFG.
--                 TODO: make it compatible with 64bit wide MGT interface, this will ease timing  
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.lpgbtfpga_package.all;

entity lpgbt_10g_bidir is
    port(
        -- reset
        reset_i                 : in  std_logic;

        -- clocks
        clk40_i                 : in  std_logic; -- expect 40MHz
        mgt_tx_usrclk_i         : in  std_logic; -- expect 320MHz
        mgt_rx_usrclk_i         : in  std_logic; -- expect 320MHz
        
        -- MGT signals
        mgt_tx_ready_i          : in  std_logic; -- low during MGT reset, high when TX PLL is locked and MGT reset has been completed
        mgt_rx_ready_i          : in  std_logic; -- low during MGT reset, high when RX PLL is locked and MGT reset has been completed
        mgt_rx_slide_o          : out std_logic; -- MGT RX slide control. Should be connected to RXSLIDE of the GTHE2_CHANNEL primitive. Note: SHOW_REALIGN_COMMA should be set to FALSE, and RXSLIDE_MODE should be set to PMA
        mgt_tx_data_o           : out std_logic_vector(31 downto 0); -- clocked on mgt_tx_usrclk_i (to MGT)
        mgt_rx_data_i           : in  std_logic_vector(31 downto 0); -- clocked on mgt_rx_usrclk_i (from MGT)
        
        -- GBT data
        tx_data_i               : in  std_logic_vector(233 downto 0); -- clocked on clk40_i
        rx_data_o               : out std_logic_vector(233 downto 0); -- clocked on clk40_i
        
        -- status
        tx_ready_o              : out std_logic; -- LpGBT TX is ready (includes tx_gearbox_ready_o)
        tx_had_not_ready_o      : out std_logic; -- latched high if tx_ready has ever transitioned from high to low after reset
        rx_ready_o              : out std_logic; -- LpGBT RX is ready (includes rx_header_locked_o and rx_gearbox_ready_o)
        rx_had_not_ready_o      : out std_logic; -- latched high if rx_ready has ever transitioned from high to low after reset
        rx_header_locked_o      : out std_logic; -- LpGBT header is locked
        rx_header_had_unlock_o  : out std_logic; -- latched high if rx_header_locked_o has ever transitioned from high to low after reset
        rx_gearbox_ready_o      : out std_logic; -- LpGBT RX gearbox is ready
        rx_correction_cnt_o     : out std_logic_vector(15 downto 0); -- count of FEC error corrections on the receiver (counts the number of clocks of rx_correction_flag_o being high)
        rx_correction_flag_o    : out std_logic  -- set high when an error correction has been performed on the current word
    );
end lpgbt_10g_bidir;

architecture lpgbt_10g_bidir_arch of lpgbt_10g_bidir is

    component upLinkTxDataPath 
    port (
        clk               : in  std_logic;
        dataEnable        : in  std_logic;  
        txDataFrame       : in  std_logic_vector(229 downto 0);
        txIC              : in  std_logic_vector(  1 downto 0);
        txEC              : in  std_logic_vector(  1 downto 0);
        scramblerBypass   : in  std_logic;
        interleaverBypass : in  std_logic;
        fecMode           : in  std_logic;
        txDataRate        : in  std_logic;
        fecDisable        : in  std_logic;
        scramblerReset    : in  std_logic;
        upLinkFrame       : out std_logic_vector(255 downto 0)
    );
    end component;

    --------- general ---------
    signal reset_sync       : std_logic;
    signal reset_cnt        : std_logic;
    
    --------- TX datapath ---------
    signal tx_dp_reset      : std_logic;
    signal tx_dp_frame      : std_logic_vector(255 downto 0);
    signal tx_data          : std_logic_vector(233 downto 0);
    
    --------- TX gearbox ---------
    signal tx_gb_reset      : std_logic;
    signal tx_gb_ready      : std_logic;
    signal tx_gb_out_data   : std_logic_vector(31 downto 0);
    
    --------- RX gearbox ---------
    signal rx_gb_reset      : std_logic;
    signal rx_gb_ready      : std_logic;
    signal rx_gb_out_data   : std_logic_vector(255 downto 0);

    --------- RX datapath ---------
    signal rx_dp_reset      : std_logic;
    signal rx_dp_ready      : std_logic;
    signal rx_data          : std_logic_vector(233 downto 0);
    signal rx_corr_flags    : std_logic_vector(233 downto 0);
    signal rx_corr_flags_or : std_logic;
    signal rx_corr_cnt      : std_logic_vector(15 downto 0);

    --------- RX frame aligner ---------
    signal rx_fa_reset      : std_logic;
    signal rx_header_locked : std_logic;
    signal rx_header_flag   : std_logic;

begin

    --============================================================--
    --            LpGBT TX @ 10.24Gb/s (ASIC emulation)           --
    --============================================================--
    
    --------- Resets ---------
    
    i_tx_gb_reset_sync : entity work.synch
        generic map(
            N_STAGES => 3
        )
        port map(
            async_i => reset_i,
            clk_i   => clk40_i,
            sync_o  => reset_sync
        );

    tx_dp_reset <= reset_sync;
    tx_gb_reset <= reset_sync or not mgt_tx_ready_i;

    -- extend the counter reset by 50us to give time for the coders to come up before counting errors and such
    i_reset_cnt_extend : entity work.pulse_extend
        generic map(
            DELAY_CNT_LENGTH => 12
        )
        port map(
            clk_i          => clk40_i,
            rst_i          => '0',
            pulse_length_i => x"7d0", -- 2000 clocks = 50us
            pulse_i        => reset_sync,
            pulse_o        => reset_cnt
        );

    --------- Status ---------
    
    tx_ready_o <= tx_gb_ready;
    
    i_tx_not_ready_latch : entity work.latch
        port map(
            reset_i => reset_cnt,
            clk_i   => clk40_i,
            input_i => not tx_gb_ready,
            latch_o => tx_had_not_ready_o
        );    
    
    --------- TX datapath ---------
    
    txdatapath_inst : upLinkTxDataPath
        port map (
            clk                   => clk40_i,
            dataEnable            => '1',
            txDataFrame           => tx_data(229 downto 0),
            txIC                  => tx_data(233 downto 232),
            txEC                  => tx_data(231 downto 230),
            scramblerBypass       => '0',
            interleaverBypass     => '0',
            fecMode               => '0',
            txDataRate            => '1',
            fecDisable            => '0',
            scramblerReset        => tx_dp_reset,
            upLinkFrame           => tx_dp_frame
        );
    
    tx_data <= tx_data_i;
    
    --------- TX gearbox ---------
    
    i_tx_gearbox: entity work.txGearbox
        generic map (
            c_clockRatio                  => 8,
            c_inputWidth                  => 256,
            c_outputWidth                 => 32,
            c_reset_dly                   => 4
        )
        port map (
            -- Clock and reset
            clk_inClk_i                   => clk40_i,
            clk_clkEn_i                   => '1',
            clk_outClk_i                  => mgt_tx_usrclk_i,
            rst_gearbox_i                 => tx_gb_reset,
            dat_inFrame_i                 => tx_dp_frame,
            dat_outFrame_o                => tx_gb_out_data,
            sta_gbRdy_o                   => tx_gb_ready
        );
        
    mgt_tx_data_o <= tx_gb_out_data;
    
    --============================================================--
    --                         LpGBT RX                           --
    --============================================================--
    
    --------- Resets ---------
    rx_fa_reset <= (not mgt_rx_ready_i) or reset_i;
    rx_gb_reset <= not rx_header_locked;
    rx_dp_reset <= not rx_gb_ready;

    --------- Status ---------
    rx_ready_o <= rx_gb_ready and rx_dp_ready;
    rx_gearbox_ready_o <= rx_gb_ready;
    rx_header_locked_o <= rx_header_locked;
    rx_correction_flag_o <= rx_corr_flags_or;
    rx_correction_cnt_o <= rx_corr_cnt;
    
    i_rx_not_ready_latch : entity work.latch
        port map(
            reset_i => reset_cnt,
            clk_i   => clk40_i,
            input_i => not (rx_gb_ready and rx_dp_ready),
            latch_o => rx_had_not_ready_o
        );

    i_rx_header_unlock_latch : entity work.latch
        port map(
            reset_i => reset_cnt,
            clk_i   => clk40_i,
            input_i => not rx_header_locked,
            latch_o => rx_header_had_unlock_o
        );
                     
    --------- RX gearbox ---------
    
    i_rx_gearbox : entity work.rxGearbox
        generic map(
            c_clockRatio       => 8,
            c_inputWidth       => 32,
            c_outputWidth      => 256,
            c_counterInitValue => 2
        )
        port map(
            clk_inClk_i    => mgt_rx_usrclk_i,
            clk_outClk_i   => clk40_i,
            clk_clkEn_i    => rx_header_flag,
            clk_dataFlag_o => open,
            
            rst_gearbox_i  => rx_gb_reset,
            
            dat_inFrame_i  => mgt_rx_data_i,
            dat_outFrame_o => rx_gb_out_data,
            
            sta_gbRdy_o    => rx_gb_ready
        );

    --------- RX datapath ---------
    
    i_rx_datapath : entity work.LpGBT_FPGA_Uplink_datapath
        generic map(
            DATARATE         => DATARATE_10G24,
            FEC              => FEC5,
            MULTICYCLE_DELAY => 0
        )
        port map(
            uplinkClk_i                     => clk40_i,
            uplinkClkInEn_i                 => '1',
            uplinkClkOutEn_o                => open,
            uplinkRst_i                     => rx_dp_reset,
            
            uplinkFrame_i                   => rx_gb_out_data,
            
            uplinkUserData_o                => rx_data(229 downto 0),
            uplinkEcData_o                  => rx_data(231 downto 230),
            uplinkIcData_o                  => rx_data(233 downto 232),

            uplinkSelectDataRate_i          => '1',
            uplinkSelectFEC_i               => '0',
            uplinkBypassInterleaver_i       => '0',
            uplinkBypassFECEncoder_i        => '0',
            uplinkBypassScrambler_i         => '0',
            
            uplinkDataCorrected_o           => rx_corr_flags(229 downto 0),
            uplinkIcCorrected_o             => rx_corr_flags(233 downto 232),
            uplinkEcCorrected_o             => rx_corr_flags(231 downto 230),
            uplinkReady_o                   => rx_dp_ready
        );

    rx_data_o <= rx_data;

    --------- Bit correction counter ---------
            
    i_corr_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => clk40_i,
            reset_i   => reset_cnt,
            en_i      => rx_corr_flags_or,
            count_o   => rx_corr_cnt
        );

    rx_corr_flags_or <= or_reduce(rx_corr_flags);

    --------- Frame aligner ---------
    
    i_frame_aligner : entity work.mgt_framealigner
        generic map(
            c_wordRatio               => 8,
            c_headerPattern           => "01",
            c_wordSize                => 32,
            c_allowedFalseHeader      => 32,
            c_allowedFalseHeaderOverN => 40,
            c_requiredTrueHeader      => 30,
            c_resetOnEven             => 0,
            c_resetDuration           => 10,
            c_bitslip_mindly          => 40
        )
        port map(
            clk_pcsRx_i             => mgt_rx_usrclk_i,
            clk_freeRunningClk_i    => clk40_i,
            
            rst_pattsearch_i        => rx_fa_reset,
            rst_mgtctrler_i         => rx_fa_reset,
            rst_rstoneven_o         => open,
            
            cmd_bitslipCtrl_o       => mgt_rx_slide_o,
            cmd_rstonevenoroddsel_i => '0',
            
            sta_headerLocked_o      => rx_header_locked,
            sta_headerFlag_o        => rx_header_flag,
            
            dat_word_i              => mgt_rx_data_i(1 downto 0)
        );

end lpgbt_10g_bidir_arch;
