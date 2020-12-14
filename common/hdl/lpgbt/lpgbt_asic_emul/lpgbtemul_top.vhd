-- IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--use work.lpgbtfpga_package.all;
--=================================================================================================--
--#######################################   Entity   ##############################################--
--=================================================================================================--

entity lpgbtemul_top is
    generic(
    rxslide_pulse_duration : integer:= 2;
    rxslide_pulse_delay    : integer:= 128
    );
    port(    
        -- Resets
        rst_downlink_i                   : in  std_logic;
        rst_uplink_i                     : in  std_logic;
        
        -- DownLink
 --       downlinkClk_o                    : out std_logic;
        downlinkClkEn_o                  : out std_logic;
                
        downLinkDataGroup0               : out std_logic_vector(15 downto 0);
        downLinkDataGroup1               : out std_logic_vector(15 downto 0);
        downLinkDataEc                   : out std_logic_vector(1 downto 0);
        downLinkDataIc                   : out std_logic_vector(1 downto 0);
        
        downLinkBypassDeinterleaver      : in  std_logic;
        downLinkBypassFECDecoder         : in  std_logic;
        downLinkBypassDescsrambler       : in  std_logic; 
        
        enableFECErrCounter              : in  std_logic;
        fecCorrectionCount               : out std_logic_vector(15 downto 0);

        downlinkRdy_o                    : out std_logic;
        
        -- uplink data        
--        uplinkClk_o                      : out std_logic;
        uplinkClkEn_i                    : in  std_logic;
        
        upLinkData0                      : in  std_logic_vector(31 downto 0);
        upLinkData1                      : in  std_logic_vector(31 downto 0);
        upLinkData2                      : in  std_logic_vector(31 downto 0);
        upLinkData3                      : in  std_logic_vector(31 downto 0);
        upLinkData4                      : in  std_logic_vector(31 downto 0);
        upLinkData5                      : in  std_logic_vector(31 downto 0);
        upLinkData6                      : in  std_logic_vector(31 downto 0);
        upLinkDataIC                     : in  std_logic_vector(1 downto 0);
        upLinkDataEC                     : in  std_logic_vector(1 downto 0);

        uplinkRdy_o                      : out std_logic;
        
        -- MGT
--        clk_mgtrefclkp_i                 : in  std_logic;                       --! Transceiver serial clock
--        clk_mgtrefclkn_i                 : in  std_logic;                       --! Transceiver serial clock
--        clk_mgtfreedrpclk_i              : in  std_logic;
--        mgt_rxn_i                        : in  std_logic;
--        mgt_rxp_i                        : in  std_logic;
--        mgt_txn_o                        : out std_logic;
--        mgt_txp_o                        : out std_logic;
--        mgt_rdy_o                        : out std_logic;
          GT_RXUSRCLK_IN                 : in  std_logic;
          GT_TXUSRCLK_IN                 : in  std_logic;
          GT_RXSLIDE_OUT                 : out std_logic;    
          GT_TXREADY_IN                  : in  std_logic;
          GT_RXREADY_IN                  : in  std_logic;
          GT_TXDATA_OUT                  : out std_logic_vector(31 downto 0);
          GT_RXDATA_IN                   : in  std_logic_vector(31 downto 0);
        
        -- Uplink controll signals
        upLinkScramblerBypass            : in  std_logic;
        upLinkScramblerReset             : in  std_logic;
        upLinkFecBypass                  : in  std_logic;
        upLinkInterleaverBypass          : in  std_logic;
        fecMode                          : in  std_logic;
        txDataRate                       : in  std_logic
    ); 
end lpgbtemul_top;

--=================================================================================================--
--####################################   Architecture   ###########################################-- 
--=================================================================================================--

architecture behavioral of lpgbtemul_top is

--    signal clk_mgtTxUsrclkToEmul_s              : std_logic;
--    signal clk_mgtRxUsrclkToEmul_s              : std_logic;
    
    signal dat_downLinkWord_fromMgt_s           : std_logic_vector(31 downto 0);
    signal sta_mgtRxRdy_s                       : std_logic;
    
    signal rst_pattsearch_s                     : std_logic;
    signal ctr_clkSlip_s                        : std_logic;
    signal sta_headeLocked_s                    : std_logic;
    signal sta_headerFlag_s                     : std_logic;
    
    signal sta_rxgbxRdy_s                       : std_logic;
    
    signal rstn_datapath_s                      : std_logic;
    signal rst_datapath_s                       : std_logic;
    
    signal dat_downLinkWord_fromGb_s            : std_logic_vector(255 downto 0);
    signal dat_downLinkWord_fromGbInv_s         : std_logic_vector(63 downto 0);
    signal dat_downLinkWord_toPattSrch_s        : std_logic_vector(15 downto 0);
    
    signal clk_mgtTxUsrclk_s                    : std_logic;
    signal clk_mgtRxUsrclk_s                    : std_logic;
    
    signal downlinkRdy_s0                       : std_logic;
    signal downlinkRdy_s1                       : std_logic;
    signal sta_mgtTxRdy_s                       : std_logic;
    
--    signal uplinkClkEn_sh_s                     : std_logic;
    signal uplinkClkEn_shgb_s                   : std_logic;
    signal sta_txGbRdy_s                        : std_logic;
    
    signal dat_upLinkWord_fromLpGBT_s           : std_logic_vector(255 downto 0);
    signal dat_upLinkWord_fromLpGBT_pipeline_s  : std_logic_vector(255 downto 0);
    signal dat_upLinkWord_toGb_s                : std_logic_vector(255 downto 0);
    signal dat_upLinkWord_toGb_pipeline_s       : std_logic_vector(255 downto 0);
    signal dat_upLinkWord_fromGb_s              : std_logic_vector(31 downto 0);
    
    signal rst_uplinkGb_s                       : std_logic;
    signal rst_uplinkGb_synch_s                 : std_logic;
    signal rst_uplinkMgt_s                      : std_logic;
    signal rst_uplinkInitDone_s                 : std_logic;
    signal rst_downlinkInitDone_s               : std_logic;
    
    signal RX_CLKEn_s                           : std_logic;
    signal RX_CLK40_s                           : std_logic;
    
    signal downLinkDataIc_s                     : std_logic_vector(1 downto 0);
    signal downLinkDataEc_s                     : std_logic_vector(1 downto 0);
    signal downLinkDataGroup1_s                 : std_logic_vector(15 downto 0);
    signal downLinkDataGroup0_s                 : std_logic_vector(15 downto 0);
    
    signal clk_dataFlag_rxGb_s                  : std_logic;
    
    signal upLinkData0_s                        : std_logic_vector(31 downto 0);
    signal upLinkData1_s                        : std_logic_vector(31 downto 0);
    signal upLinkData2_s                        : std_logic_vector(31 downto 0);
    signal upLinkData3_s                        : std_logic_vector(31 downto 0);
    signal upLinkData4_s                        : std_logic_vector(31 downto 0);
    signal upLinkData5_s                        : std_logic_vector(31 downto 0);
    signal upLinkData6_s                        : std_logic_vector(31 downto 0);
    signal upLinkDataIC_s                       : std_logic_vector(1 downto 0);
    signal upLinkDataEC_s                       : std_logic_vector(1 downto 0);
    signal upLinkDataLo                         : std_logic_vector(111 downto 0);
    signal upLinkDataHi                         : std_logic_vector(111 downto 0);
 
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

component downLinkRxDataPath 
port (
    clk                 : in  std_logic;
	downLinkFrame       : in  std_logic_vector( 63 downto 0);                      
    dataStrobe          : out std_logic;
    dataOut             : out std_logic_vector( 31 downto 0);
    dataEC              : out std_logic_vector(  1 downto 0);
    dataIC              : out std_logic_vector(  1 downto 0);
    header              : out std_logic_vector(  3 downto 0);
    dataEnable          : in  std_logic;
    bypassDeinterleaver : in  std_logic;
    bypassFECDecoder    : in  std_logic;
    bypassDescrambler   : in  std_logic;
    fecCorrectionCount  : out std_logic_vector( 15 downto 0)
    );
end component;


--component upLinkTxGearBox 
--port (
--	clock               : in  std_logic;
--	reset               : in  std_logic;
--	dataStrobe          : in  std_logic;
--	txDataRate          : in  std_logic;
--	dataFrame           : in  std_logic_vector(255 downto 0);
--	errorFrame          : in  std_logic_vector(255 downto 0);
--	enableDataPath      : in  std_logic;
--	dataWord            : out std_logic_vector( 31 downto 0)
--    );
--end component;
	
     COMPONENT LpGBT_Model_dataPath
        PORT (
             -- Clock
             upClki                           : in  std_logic;
             downClki                         : in  std_logic;
             downLinkDataPathEnable           : in  std_logic;
             upLinkDataPathEnable             : in  std_logic;
            
             -- DownLink           
             downLinkFrame                    : in  std_logic_vector(63 downto 0);
            
             downLinkDataGroup0               : out std_logic_vector(15 downto 0);
             downLinkDataGroup1               : out std_logic_vector(15 downto 0);
             downLinkDataEc                   : out std_logic_vector(1 downto 0);
             downLinkDataIc                   : out std_logic_vector(1 downto 0);
             downLinkHeader                   : out std_logic_vector(3 downto 0);
            
             downLinkBypassDeinterleaver      : in  std_logic;
             downLinkBypassFECDecoder         : in  std_logic;
             downLinkBypassDescsrambler       : in  std_logic;
            
             enableFECErrCounter              : in  std_logic;
             fecCorrectionCount               : out std_logic_vector(15 downto 0);
            
             -- uplink data
             upLinkData0                      : in  std_logic_vector(31 downto 0);
             upLinkData1                      : in  std_logic_vector(31 downto 0);
             upLinkData2                      : in  std_logic_vector(31 downto 0);
             upLinkData3                      : in  std_logic_vector(31 downto 0);
             upLinkData4                      : in  std_logic_vector(31 downto 0);
             upLinkData5                      : in  std_logic_vector(31 downto 0);
             upLinkData6                      : in  std_logic_vector(31 downto 0);
             upLinkDataIC                     : in  std_logic_vector(1 downto 0);
             upLinkDataEC                     : in  std_logic_vector(1 downto 0);

             -- Uplink controll signals
             upLinkScramblerBypass            : in  std_logic;
             upLinkScramblerReset             : in  std_logic;
             upLinkFecBypass                  : in  std_logic;
             upLinkInterleaverBypass          : in  std_logic;
             fecMode                          : in  std_logic;
             txDataRate                       : in  std_logic;

             -- Uplink output data
             upLinkFrame                      : out std_logic_vector(255 downto 0)
        );   
     END COMPONENT;
                
begin                 --========####   Architecture Body   ####========-- 

    rst_pattsearch_s            <= not(sta_mgtRxRdy_s);
    rst_datapath_s              <= not(sta_headeLocked_s);
    
    rst_uplinkGb_s              <= rst_uplink_i or not(sta_mgtTxRdy_s) or not(sta_headeLocked_s);
    rst_uplinkMgt_s             <= not(sta_headeLocked_s);
    
    uplinkRdy_o                 <= sta_txGbRdy_s;
    
    --Rdy process (delay from 1 clock)
    process(sta_rxgbxRdy_s, clk_mgtRxUsrclk_s)
    begin
        if sta_rxgbxRdy_s = '0' then
            downlinkRdy_o <= '0';
            downlinkRdy_s0 <= '0';
            downlinkRdy_s1 <= '0';
        elsif rising_edge(clk_mgtRxUsrclk_s) then
            if RX_CLKEn_s = '1' then
                downlinkRdy_s0 <= '1';
                downlinkRdy_s1 <= downlinkRdy_s0;
                downlinkRdy_o  <= downlinkRdy_s1;
            end if;
        end if;    
    end process;
    
    -- MGT
--    mgt_inst: entity work.mgt
--       port map(
--            -- Clocks
--            REFCLKP_IN     => clk_mgtrefclkp_i,
--            REFCLKN_IN     => clk_mgtrefclkn_i,
--            SYSCLK_IN      => clk_mgtfreedrpclk_i,
                    
--            RXUSRCLK_OUT   => clk_mgtRxUsrclk_s,
--            TXUSRCLK_OUT   => clk_mgtTxUsrclk_s,
              
--            TXRESET_IN     => rst_downlink_i, -- rst_uplinkMgt_s, JM: issue - reseting the Tx side resets also the CPLL that is used by the Rx
--            RXRESET_IN     => rst_downlink_i,
              
--            -- Control & Status
--            RXSLIDE_IN     => ctr_clkSlip_s,    
--            TXREADY_OUT    => sta_mgtTxRdy_s,
--            RXREADY_OUT    => sta_mgtRxRdy_s,
            
--            -- Data
--            TXDATA_IN      => dat_upLinkWord_fromGb_s,
--            RXDATA_OUT     => dat_downLinkWord_fromMgt_s,
              
--            RXN_IN         => mgt_rxn_i,
--            RXP_IN         => mgt_rxp_i,       
--            TXN_OUT        => mgt_txn_o,
--            TXP_OUT        => mgt_txp_o
--       );
    
--    mgt_rdy_o <= sta_mgtTxRdy_s and sta_mgtRxRdy_s;


            clk_mgtRxUsrclk_s <= GT_RXUSRCLK_IN;
            clk_mgtTxUsrclk_s <= GT_TXUSRCLK_IN;
                                 GT_RXSLIDE_OUT  <= ctr_clkSlip_s;    
            sta_mgtTxRdy_s    <= GT_TXREADY_IN;    
            sta_mgtRxRdy_s    <= GT_RXREADY_IN;
                                 GT_TXDATA_OUT  <= dat_upLinkWord_fromGb_s;
   dat_downLinkWord_fromMgt_s <= GT_RXDATA_IN;
    

    
    -- Pattern aligner
    mgt_framealigner_inst: entity work.mgt_framealigner
        GENERIC map (
            c_wordRatio                      => 8,
            c_headerPattern                  => x"F00F",
            c_wordSize                       => 32,
            c_allowedFalseHeader             => 32,
            c_allowedFalseHeaderOverN        => 40,
            c_requiredTrueHeader             => 30,
            c_bitslip_pulse_duration         => rxslide_pulse_duration, -- [PV] UG576 Figure 4-30
            c_bitslip_mindly                 => rxslide_pulse_delay
        )
        PORT map (     
            -- Clock(s)
            clk_pcsRx_i                      => clk_mgtRxUsrclk_s,
            clk_freeRunningClk_i             => '0',                  -- Not used: rst on even is not enabled
            
            -- Reset(s)
            rst_pattsearch_i                 => rst_pattsearch_s,
            rst_mgtctrler_i                  => '0',                  -- Not used: rst on even is not enabled
            rst_rstoneven_o                  => open,                 -- Not used: rst on even is not enabled
            
            -- Control
            cmd_bitslipCtrl_o                => ctr_clkSlip_s,
            cmd_rstonevenoroddsel_i          => '0',                  -- Not used: rst on even is not enabled
            
            -- Status
            sta_headerLocked_o               => sta_headeLocked_s,
            sta_headerFlag_o                 => sta_headerFlag_s,

            -- Data
            dat_word_i                       => dat_downLinkWord_toPattSrch_s
       );
       
            
    dat_downLinkWord_toPattSrch_s <= dat_downLinkWord_fromMgt_s(24) & dat_downLinkWord_fromMgt_s(25) & dat_downLinkWord_fromMgt_s(26) & dat_downLinkWord_fromMgt_s(27) & 
                                     dat_downLinkWord_fromMgt_s(16) & dat_downLinkWord_fromMgt_s(17) & dat_downLinkWord_fromMgt_s(18) & dat_downLinkWord_fromMgt_s(19) & 
                                     dat_downLinkWord_fromMgt_s(8) & dat_downLinkWord_fromMgt_s(9) & dat_downLinkWord_fromMgt_s(10) & dat_downLinkWord_fromMgt_s(11) & 
                                     dat_downLinkWord_fromMgt_s(3) & dat_downLinkWord_fromMgt_s(2) & dat_downLinkWord_fromMgt_s(1) & dat_downLinkWord_fromMgt_s(0);
    
    -- Downlink gearbox
    rxGearbox_inst: entity work.rxGearbox
        generic map(
            c_clockRatio                  => 8,
            c_inputWidth                  => 32,
            c_outputWidth                 => 64,
            c_counterInitValue            => 2
        )
        port map(
            -- Clock and reset
            clk_inClk_i                   => clk_mgtRxUsrclk_s,
            clk_outClk_i                  => clk_mgtRxUsrclk_s,
            clk_clkEn_i                   => sta_headerFlag_s,
            clk_dataFlag_o                => clk_dataFlag_rxGb_s,
            rst_gearbox_i                 => rst_datapath_s,

            -- Data
            dat_inFrame_i                 => dat_downLinkWord_fromMgt_s,
            dat_outFrame_o                => dat_downLinkWord_fromGb_s,
            
            -- Status
            sta_gbRdy_o                   => sta_rxgbxRdy_s
        );
    
    --! Multicycle path configuration (downlink)
    syncShiftRegDown_proc: process(sta_rxgbxRdy_s, clk_mgtRxUsrclk_s)
        variable cnter  : integer range 0 to 7;
    begin
    
        if sta_rxgbxRdy_s = '0' then
              cnter              := 0;
              RX_CLKEn_s         <= '0';
              rst_downlinkInitDone_s <= '0';
              
        elsif rising_edge(clk_mgtRxUsrclk_s) then
            if clk_dataFlag_rxGb_s = '1' then
                cnter            := 0;
                rst_downlinkInitDone_s <= '1';
            elsif rst_downlinkInitDone_s = '1' then
                cnter            := cnter + 1;
            end if;
            
            RX_CLKEn_s           <= '0';
            if cnter = 4 then
                RX_CLKEn_s       <= rst_downlinkInitDone_s;
            end if;              
        end if;
    end process;
                                    
    -- Uplink gearbox
    txGearbox_inst: entity work.txGearbox
        generic map (
            c_clockRatio                  => 8,
            c_inputWidth                  => 256,
            c_outputWidth                 => 32
        )
        port map (
            -- Clock and reset
            clk_inClk_i                   => clk_mgtTxUsrclk_s, --RX_CLKEn_s,
            clk_clkEn_i                   => uplinkClkEn_shgb_s, --'1',
            clk_outClk_i                  => clk_mgtTxUsrclk_s,
            rst_gearbox_i                 => rst_uplinkGb_synch_s,
            dat_inFrame_i                 => dat_upLinkWord_toGb_pipeline_s,
            dat_outFrame_o                => dat_upLinkWord_fromGb_s,
            sta_gbRdy_o                   => sta_txGbRdy_s
        );
        
--    tx_gb_ila_inst: entity work.uplink_tx_gb_ila
--    port map
--    (
--	  clk                    => clk_mgtTxUsrclk_s,
--      probe0( 31 downto   0) => dat_upLinkWord_fromGb_s,
--      probe0(287 downto  32) => dat_upLinkWord_toGb_pipeline_s,
--      probe0(288)            => uplinkClkEn_shgb_s,
--      probe0(289)            => sta_txGbRdy_s
--    );
        
    --! Multicycle path configuration
    syncShiftRegUp_proc: process(rst_uplink_i, clk_mgtTxUsrclk_s)
        variable cnter  : integer range 0 to 7;
    begin
    
        if rst_uplink_i = '1' then
              cnter                := 0;
              uplinkClkEn_shgb_s   <= '0';
              rst_uplinkGb_synch_s <= '1';
              rst_uplinkInitDone_s <= '0';
                            
              upLinkData0_s       <= (others => '0');
              upLinkData1_s       <= (others => '0');
              upLinkData2_s       <= (others => '0');
              upLinkData3_s       <= (others => '0');
              upLinkData4_s       <= (others => '0');
              upLinkData5_s       <= (others => '0');
              upLinkData6_s       <= (others => '0');
              upLinkDataIC_s      <= (others => '0');
              upLinkDataEC_s      <= (others => '0');
              
        elsif rising_edge(clk_mgtTxUsrclk_s) then
            if uplinkClkEn_i = '1' then
                cnter            := 0;
                
                upLinkData0_s       <= upLinkData0;
                upLinkData1_s       <= upLinkData1;
                upLinkData2_s       <= upLinkData2;
                upLinkData3_s       <= upLinkData3;
                upLinkData4_s       <= upLinkData4;
                upLinkData5_s       <= upLinkData5;
                upLinkData6_s       <= upLinkData6;
                upLinkDataIC_s      <= upLinkDataIC;
                upLinkDataEC_s      <= upLinkDataEC;
                
                rst_uplinkInitDone_s <= '1';
                
            elsif rst_uplinkInitDone_s = '1' then
                cnter            := cnter + 1;
            end if;
                        
            uplinkClkEn_shgb_s           <= '0';
            if cnter = 4 then
                uplinkClkEn_shgb_s       <= '1';
                rst_uplinkGb_synch_s     <= rst_uplinkGb_s or not(rst_uplinkInitDone_s);
            end if;              
        end if;
    end process;
    

    
    
    
--	uplinkClkEn_sh_s <= uplinkClkEn_i;
--    uplinkClk_o      <= clk_mgtTxUsrclk_s; --RX_CLKEn_s;
--    downlinkClk_o    <= clk_mgtRxUsrclk_s;
    downlinkClkEn_o  <= RX_CLKEn_s; --RX_CLKEn_s;


--#########################################################################
--################ W T F ##################################################
--#########################################################################
    --! Clocks for emulator
--    down_clkToEmul_proc: process(sta_mgtRxRdy_s, clk_mgtRxUsrclk_s)
--    begin    
--        if sta_mgtRxRdy_s = '0' then
--            clk_mgtRxUsrclkToEmul_s <= '0';
--        elsif rising_edge(clk_mgtRxUsrclk_s) then                
--            clk_mgtRxUsrclkToEmul_s <= '0';
--            if RX_CLKEn_s = '1' then
--                clk_mgtRxUsrclkToEmul_s <= '1';
--            end if;            
--        end if;
--    end process;
    
--    up_clkToEmul_proc: process(rst_uplinkInitDone_s, clk_mgtTxUsrclk_s)
--    begin    
--        if rst_uplinkInitDone_s = '0' then
--            clk_mgtTxUsrclkToEmul_s <= '0';
--        elsif rising_edge(clk_mgtTxUsrclk_s) then                
--            clk_mgtTxUsrclkToEmul_s <= '0';
--            if uplinkClkEn_sh_s = '1' then
--                clk_mgtTxUsrclkToEmul_s <= '1';
--            end if;            
--        end if;
--    end process;
--#########################################################################
--#########################################################################
--#########################################################################

  uplinkDataLo  <= x"0000"
                 & upLinkData2_s
                 & upLinkData1_s
                 & upLinkData0_s;
                 
  uplinkDataHi  <= x"0000"
                 & upLinkData5_s
                 & upLinkData4_s
                 & upLinkData3_s;
                 
    txdatapath_inst : upLinkTxDataPath
        port map (
            clk                   => clk_mgtTxUsrclk_s,
            dataEnable            => uplinkClkEn_i, --uplinkClkEn_sh_s,
            txDataHigh            => uplinkDataHi,
            txDataLow             => uplinkDataLo,
            txIC                  => upLinkDataIC,
            txEC                  => upLinkDataEC,
            txDummyFec5           => "001100",
            txDummyFec12          => "1001110011",
            scramblerBypass       => '0',
            interleaverBypass     => '0',
            fecMode               => fecMode,
            txDataRate            => txDataRate,
            fecDisable            => '0',
            scramblerReset        => rst_uplink_i,
            upLinkFrame           => dat_upLinkWord_fromLpGBT_s
        );

    rxdatapath_inst : downLinkRxDataPath
        port map (
            clk                   => clk_mgtRxUsrclk_s,
            downLinkFrame         => dat_downLinkWord_fromGb_s(63 downto 0),
            dataStrobe            => open, --RX_CLKEn_s,
            dataOut(15 downto  0) => downLinkDataGroup0_s,
            dataOut(31 downto 16) => downLinkDataGroup1_s,
            dataEC                => downLinkDataEc_s,
            dataIC                => downLinkDataIc_s,
            header                => open,
            dataEnable            => RX_CLKEn_s,
            bypassDeinterleaver   => '0',
            bypassFECDecoder      => '0',
            bypassDescrambler     => '0',
            fecCorrectionCount    => open
        );



--     LpGBT_Model_dataPath_inst: LpGBT_Model_dataPath
--         port map (
--             -- Clock
--             upClki                          => clk_mgtTxUsrclkToEmul_s, --RX_CLK40_s,
--             downClki                        => clk_mgtRxUsrclkToEmul_s,
--             downLinkDataPathEnable          => '1',
--             upLinkDataPathEnable            => '1', --RX_CLKEn_s,
            
--             -- DownLink
--             downLinkFrame                   => dat_downLinkWord_fromGb_s(63 downto 0),
            
--             downLinkDataGroup0              => downLinkDataGroup0_s,
--             downLinkDataGroup1              => downLinkDataGroup1_s,
--             downLinkDataEc                  => downLinkDataEc_s,
--             downLinkDataIc                  => downLinkDataIc_s,
--             downLinkHeader                  => open,
            
--             downLinkBypassDeinterleaver     => downLinkBypassDeinterleaver,
--             downLinkBypassFECDecoder        => downLinkBypassFECDecoder,
--             downLinkBypassDescsrambler      => downLinkBypassDescsrambler,
            
--             enableFECErrCounter             => enableFECErrCounter,
--             fecCorrectionCount              => fecCorrectionCount,
            
--             upLinkData0                     => upLinkData0_s,
--             upLinkData1                     => upLinkData1_s,
--             upLinkData2                     => upLinkData2_s,
--             upLinkData3                     => upLinkData3_s,
--             upLinkData4                     => upLinkData4_s,
--             upLinkData5                     => upLinkData5_s,
--             upLinkData6                     => upLinkData6_s,
--             upLinkDataIC                    => upLinkDataIC, -- or _s??
--             upLinkDataEC                    => upLinkDataEC, -- or _s??

--             -- Uplink controll signals
--             upLinkScramblerBypass           => upLinkScramblerBypass,
--             upLinkScramblerReset            => rst_datapath_s,
--             upLinkFecBypass                 => upLinkFecBypass,
--             upLinkInterleaverBypass         => upLinkInterleaverBypass,
--             fecMode                         => fecMode,
--             txDataRate                      => txDataRate,

--             -- Uplink output data
--             upLinkFrame                     => dat_upLinkWord_fromLpGBT_s
--         );
    
    upLinkPipelineBeforeOversampling_proc: process(rst_uplink_i, clk_mgtTxUsrclk_s)
      begin
          if rst_uplink_i = '1' then
              dat_upLinkWord_fromLpGBT_pipeline_s <= (others => '0');
          elsif rising_edge(clk_mgtTxUsrclk_s) then
              if uplinkClkEn_i='1' then --if uplinkClkEn_shgb_s = '1' then
                dat_upLinkWord_fromLpGBT_pipeline_s <= dat_upLinkWord_fromLpGBT_s;
              end if;
          end if;      
      end process;  

                    
      upLinkPipelineAfterOversampling_proc: process(rst_uplink_i, clk_mgtTxUsrclk_s)
        begin
            if rst_uplink_i = '1' then
                dat_upLinkWord_toGb_pipeline_s <= (others => '0');
            elsif rising_edge(clk_mgtTxUsrclk_s) then
                if uplinkClkEn_shgb_s = '1' then
                  dat_upLinkWord_toGb_pipeline_s <= dat_upLinkWord_toGb_s;
                end if;
            end if;      
        end process; 

              
    
    -- Uplink oversampler
    oversampler_gen: for i in 0 to 127 generate
        oversampler_ph_gen: for j in 0 to 1 generate
            dat_upLinkWord_toGb_s((i*2)+j)  <= dat_upLinkWord_fromLpGBT_pipeline_s(i) when txDataRate = '0' else
                                               dat_upLinkWord_fromLpGBT_pipeline_s((i*2)+j);
        end generate;
    end generate;
   
    downLinkDataGroup0              <= downLinkDataGroup0_s;
    downLinkDataGroup1              <= downLinkDataGroup1_s;
    downLinkDataEc                  <= downLinkDataEc_s;
    downLinkDataIc                  <= downLinkDataIc_s;
     
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--