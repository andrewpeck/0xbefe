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

entity lpgbt_10g_tx is
    generic(
      g_MGT_TX_BUS_WIDTH        : integer range 0 to 64 := 32; -- select the TX bus width, valid options are 32 and 64 
      g_TXUSRCLK_TO_TTC40_RATIO : integer range 0 to 8 := 8    -- select the TXUSRCLK / TTC_CLK40 ratio (if TXUSRCLK is 320MHz, set this to 8, and if it's 160MHz set it to 4)
    );
    port(
        -- reset
        reset_i                 : in  std_logic;

        -- clocks
        clk40_i                 : in  std_logic; -- expect 40MHz
        mgt_tx_usrclk_i         : in  std_logic; -- expect 320MHz
        
        -- MGT signals
        mgt_tx_ready_i          : in  std_logic; -- low during MGT reset, high when TX PLL is locked and MGT reset has been completed
        mgt_tx_data_o           : out std_logic_vector(g_MGT_TX_BUS_WIDTH - 1 downto 0); -- clocked on mgt_tx_usrclk_i (to MGT)
        
        -- GBT data
        tx_data_i               : in  std_logic_vector(233 downto 0); -- clocked on clk40_i
        
        -- status
        tx_ready_o              : out std_logic; -- LpGBT TX is ready (includes tx_gearbox_ready_o)
        tx_had_not_ready_o      : out std_logic -- latched high if tx_ready has ever transitioned from high to low after reset
    );
end lpgbt_10g_tx;

architecture lpgbt_10g_tx_arch of lpgbt_10g_tx is

    component upLinkTxDataPath 
    port (
        clk               : in  std_logic;
        dataEnable        : in  std_logic;  
        txDataHigh        : in  std_logic_vector(111 downto 0);
        txDataLow         : in  std_logic_vector(111 downto 0);
        txIC              : in  std_logic_vector(  1 downto 0);
        txEC              : in  std_logic_vector(  1 downto 0);
        txDummyFec5       : in  std_logic_vector(  5 downto 0);
        txDummyFec12      : in  std_logic_vector(  9 downto 0);
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
    signal tx_dp_frame_reg  : std_logic_vector(255 downto 0);
    signal tx_data          : std_logic_vector(233 downto 0);
    
    --------- TX gearbox ---------
    signal tx_gb_reset      : std_logic;
    signal tx_gb_ready      : std_logic;
    signal tx_gb_out_data   : std_logic_vector(g_MGT_TX_BUS_WIDTH - 1 downto 0);
    
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
            txDataHigh            => tx_data(223 downto 112),
            txDataLow             => tx_data(111 downto 0),
            txIC                  => tx_data(233 downto 232),
            txEC                  => tx_data(231 downto 230),
            txDummyFec5           => tx_data(229 downto 224),
            txDummyFec12          => "1001110011",
            scramblerBypass       => '0',
            interleaverBypass     => '0',
            fecMode               => '0',
            txDataRate            => '1',
            fecDisable            => '0',
            scramblerReset        => tx_dp_reset,
            upLinkFrame           => tx_dp_frame
        );
    
    tx_data <= tx_data_i;
    
    -- register the frame on the way from upLinkTxDataPath to the txGearbox to ease timing
    process(clk40_i)
    begin
        if rising_edge(clk40_i) then
            tx_dp_frame_reg <= tx_dp_frame;
        end if;
    end process;
    
    --------- TX gearbox ---------
    
    i_tx_gearbox: entity work.txGearbox
        generic map (
            c_clockRatio                  => g_TXUSRCLK_TO_TTC40_RATIO,
            c_inputWidth                  => 256,
            c_outputWidth                 => g_MGT_TX_BUS_WIDTH,
            c_reset_dly                   => 4
        )
        port map (
            -- Clock and reset
            clk_inClk_i                   => clk40_i,
            clk_clkEn_i                   => '1',
            clk_outClk_i                  => mgt_tx_usrclk_i,
            rst_gearbox_i                 => tx_gb_reset,
            dat_inFrame_i                 => tx_dp_frame_reg,
            dat_outFrame_o                => tx_gb_out_data,
            sta_gbRdy_o                   => tx_gb_ready
        );
        
    mgt_tx_data_o <= tx_gb_out_data;
    
end lpgbt_10g_tx_arch;
