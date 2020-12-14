library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

--! system packages
use work.system_flash_sram_package.all;
use work.system_pcie_package.all;
use work.system_package.all;
use work.fmc_package.all;
use work.wb_package.all;
use work.ipbus.all;

--! user packages
use work.user_package.all;
use work.user_version_package.all;

--! GEM packages
use work.gem_pkg.all;
use work.gem_board_config_package.all;

entity user_logic is
port(
    --================================--
    -- USER MGT REFCLKs
    --================================--
    -- BANK_112(Q0):  
    clk125_1_p                  : in std_logic;              
    clk125_1_n                  : in std_logic;            
    cdce_out0_p                 : in std_logic;            
    cdce_out0_n                 : in std_logic;           
    -- BANK_113(Q1):                 
    fmc2_clk0_m2c_xpoint2_p     : in std_logic;
    fmc2_clk0_m2c_xpoint2_n     : in std_logic;
    cdce_out1_p                 : in std_logic;       
    cdce_out1_n                 : in std_logic;         
    -- BANK_114(Q2):                 
    pcie_clk_p                  : in std_logic;               
    pcie_clk_n                  : in std_logic;              
    cdce_out2_p                 : in std_logic;              
    cdce_out2_n                 : in std_logic;              
    -- BANK_115(Q3):                 
    clk125_2_i                  : in std_logic;              
    fmc1_gbtclk1_m2c_p          : in std_logic;     
    fmc1_gbtclk1_m2c_n          : in std_logic;     
    -- BANK_116(Q4):                 
    fmc1_gbtclk0_m2c_p          : in std_logic;      
    fmc1_gbtclk0_m2c_n          : in std_logic;      
    cdce_out3_p                 : in std_logic;          
    cdce_out3_n                 : in std_logic;            
    --================================--
    -- USER FABRIC CLOCKS
    --================================--
    xpoint1_clk3_p              : in std_logic;           
    xpoint1_clk3_n              : in std_logic;           
    ------------------------------------  
    cdce_out4_p                 : in std_logic;                
    cdce_out4_n                 : in std_logic;              
    ------------------------------------
    amc_tclkb_o                 : out std_logic;
    ------------------------------------      
    fmc1_clk0_m2c_xpoint2_p     : in std_logic;
    fmc1_clk0_m2c_xpoint2_n     : in std_logic;
    fmc1_clk1_m2c_p             : in std_logic;    
    fmc1_clk1_m2c_n             : in std_logic;    
    fmc1_clk2_bidir_p           : in std_logic;    
    fmc1_clk2_bidir_n           : in std_logic;    
    fmc1_clk3_bidir_p           : in std_logic;    
    fmc1_clk3_bidir_n           : in std_logic;    
    ------------------------------------
    fmc2_clk1_m2c_p             : in std_logic;        
    fmc2_clk1_m2c_n             : in std_logic;        
    --================================--
    -- GBT PHASE MONITORING MGT REFCLK
    --================================--
    cdce_out0_gtxe1_o           : out std_logic;            
    cdce_out3_gtxe1_o           : out std_logic;  
    --================================--
    -- AMC PORTS
    --================================--
    amc_port_tx_p               : out std_logic_vector(1 to 15);
    amc_port_tx_n               : out std_logic_vector(1 to 15);
    amc_port_rx_p               : in std_logic_vector(1 to 15);
    amc_port_rx_n               : in std_logic_vector(1 to 15);
    ------------------------------------
    amc_port_tx_out             : out std_logic_vector(17 to 20);    
    amc_port_tx_in              : in std_logic_vector(17 to 20);        
    amc_port_tx_de              : out std_logic_vector(17 to 20);    
    amc_port_rx_out             : out std_logic_vector(17 to 20);    
    amc_port_rx_in              : in std_logic_vector(17 to 20);    
    amc_port_rx_de              : out std_logic_vector(17 to 20);    
    --================================--
    -- SFP QUAD
    --================================--
    sfp_tx_p                    : out std_logic_vector(1 to 4);
    sfp_tx_n                    : out std_logic_vector(1 to 4);
    sfp_rx_p                    : in std_logic_vector(1 to 4);
    sfp_rx_n                    : in std_logic_vector(1 to 4);
    sfp_mod_abs                 : in std_logic_vector(1 to 4);        
    sfp_rxlos                   : in std_logic_vector(1 to 4);        
    sfp_txfault                 : in std_logic_vector(1 to 4);                
    --================================--
    -- FMC1
    --================================--
    fmc1_tx_p                   : out std_logic_vector(1 to 4);
    fmc1_tx_n                   : out std_logic_vector(1 to 4);
    fmc1_rx_p                   : in std_logic_vector(1 to 4);
    fmc1_rx_n                   : in std_logic_vector(1 to 4);
    ------------------------------------
    fmc1_io_pin                 : inout fmc_io_pin_type;
    ------------------------------------
    fmc1_clk_c2m_p              : out std_logic_vector(0 to 1);
    fmc1_clk_c2m_n              : out std_logic_vector(0 to 1);
    fmc1_present_l              : in std_logic;
    --================================--
    -- FMC2
    --================================--
    fmc2_io_pin                 : inout fmc_io_pin_type;
    ------------------------------------
    fmc2_clk_c2m_p              : out std_logic_vector(0 to 1);
    fmc2_clk_c2m_n              : out std_logic_vector(0 to 1);
    fmc2_present_l              : in std_logic;
    --================================--      
    -- SYSTEM GBE   
    --================================--      
    sys_eth_amc_p1_tx_p         : in std_logic;    
    sys_eth_amc_p1_tx_n         : in std_logic;    
    sys_eth_amc_p1_rx_p         : out std_logic;    
    sys_eth_amc_p1_rx_n         : out std_logic;    
    ------------------------------------
    user_mac_syncacqstatus_i    : in std_logic_vector(0 to 3);
    user_mac_serdes_locked_i    : in std_logic_vector(0 to 3);
    --================================--                                           
    -- SYSTEM PCIe                                                                   
    --================================--   
    sys_pcie_mgt_refclk_o       : out std_logic;      
    user_sys_pcie_dma_clk_i     : in std_logic;      
    ------------------------------------
    sys_pcie_amc_tx_p           : in std_logic_vector(0 to 3);    
    sys_pcie_amc_tx_n           : in std_logic_vector(0 to 3);    
    sys_pcie_amc_rx_p           : out std_logic_vector(0 to 3);    
    sys_pcie_amc_rx_n           : out std_logic_vector(0 to 3);    
    ------------------------------------
    user_sys_pcie_slv_o         : out R_slv_to_ezdma2;                                           
    user_sys_pcie_slv_i         : in R_slv_from_ezdma2;                                    
    user_sys_pcie_dma_o         : out R_userDma_to_ezdma2_array  (1 to 7);                               
    user_sys_pcie_dma_i         : in R_userDma_from_ezdma2_array(1 to 7);               
    user_sys_pcie_int_o         : out R_int_to_ezdma2;                                           
    user_sys_pcie_int_i         : in R_int_from_ezdma2;                                     
    user_sys_pcie_cfg_i         : in R_cfg_from_ezdma2;                                        
    --================================--
    -- SRAMs
    --================================--
    user_sram_control_o         : out userSramControlR_array(1 to 2);
    user_sram_addr_o            : out array_2x21bit;
    user_sram_wdata_o           : out array_2x36bit;
    user_sram_rdata_i           : in array_2x36bit;
    ------------------------------------
    sram1_bwa                   : out std_logic;  
    sram1_bwb                   : out std_logic;  
    sram1_bwc                   : out std_logic;  
    sram1_bwd                   : out std_logic;  
    sram2_bwa                   : out std_logic;  
    sram2_bwb                   : out std_logic;  
    sram2_bwc                   : out std_logic;  
    sram2_bwd                   : out std_logic;    
    --================================--               
    -- CLK CIRCUITRY              
    --================================--    
    fpga_clkout_o               : out std_logic;    
    ------------------------------------
    sec_clk_o                   : out std_logic;    
    ------------------------------------
    user_cdce_locked_i          : in std_logic;
    user_cdce_sync_done_i       : in std_logic;
    user_cdce_sel_o             : out std_logic;
    user_cdce_sync_o            : out std_logic;
    --================================--  
    -- USER BUS  
    --================================--       
    wb_miso_o                   : out wb_miso_bus_array(0 to number_of_wb_slaves - 1);
    wb_mosi_i                   : in wb_mosi_bus_array(0 to number_of_wb_slaves - 1);
    ------------------------------------
    ipb_clk_i                   : in std_logic;
    ipb_miso_o                  : out ipb_rbus_array(0 to number_of_ipb_slaves - 1);
    ipb_mosi_i                  : in ipb_wbus_array(0 to number_of_ipb_slaves - 1);   
    --================================--
    -- VARIOUS
    --================================--
    reset_i                     : in std_logic;        
    user_clk125_i               : in std_logic;       
    user_clk200_i               : in std_logic;       
    ------------------------------------   
    sn                          : in std_logic_vector(7 downto 0);       
    ------------------------------------   
    amc_slot_i                  : in std_logic_vector( 3 downto 0);
    mac_addr_o                  : out std_logic_vector(47 downto 0);
    ip_addr_o                   : out std_logic_vector(31 downto 0);
    ------------------------------------    
    user_v6_led_o               : out std_logic_vector(1 to 2)
);                             
end user_logic;
                            
architecture user_logic_arch of user_logic is        

    signal reset_pwrup          : std_logic;

    -------------------------- GTH ---------------------------------
    signal clk_gtx_tx_arr       : std_logic_vector(g_NUM_OF_GTX - 1 downto 0);
    signal clk_gtx_rx_arr       : std_logic_vector(g_NUM_OF_GTX - 1 downto 0);
    signal gtx_tx_data_arr      : t_gt_8b10b_tx_data_arr(g_NUM_OF_GTX - 1 downto 0);
    signal gtx_rx_data_arr      : t_gt_8b10b_rx_data_arr(g_NUM_OF_GTX - 1 downto 0);

    signal gtx_common_clk       : std_logic;

    -------------------- GTHs mapped to GEM links ---------------------------------
    
    -- 8b10b DAQ + Control GTX / GTH links (3.2Gbs, 16bit @ 160MHz w/ 8b10b encoding)
    signal gem_gt_8b10b_rx_clk_arr  : std_logic_vector(CFG_NUM_OF_OHs - 1 downto 0);
    signal gem_gt_8b10b_tx_clk_arr  : std_logic_vector(CFG_NUM_OF_OHs - 1 downto 0);
    signal gem_gt_8b10b_rx_data_arr : t_gt_8b10b_rx_data_arr(CFG_NUM_OF_OHs - 1 downto 0);
    signal gem_gt_8b10b_tx_data_arr : t_gt_8b10b_tx_data_arr(CFG_NUM_OF_OHs - 1 downto 0);

    -- Trigger RX GTX / GTH links (3.2Gbs, 16bit @ 160MHz w/ 8b10b encoding)
    signal gem_gt_trig0_rx_clk_arr  : std_logic_vector(CFG_NUM_OF_OHs - 1 downto 0);
    signal gem_gt_trig0_rx_data_arr : t_gt_8b10b_rx_data_arr(CFG_NUM_OF_OHs - 1 downto 0);
    signal gem_gt_trig1_rx_clk_arr  : std_logic_vector(CFG_NUM_OF_OHs - 1 downto 0);
    signal gem_gt_trig1_rx_data_arr : t_gt_8b10b_rx_data_arr(CFG_NUM_OF_OHs - 1 downto 0);
    
    -- GBT GTX/GTH links (4.8Gbs, 40bit @ 120MHz w/o 8b10b encoding)
    signal gem_gt_gbt_rx_links_arr  : t_gbt_mgt_rx_links_arr(CFG_NUM_OF_OHs - 1 downto 0);
    signal gem_gt_gbt_tx_links_arr  : t_gbt_mgt_tx_links_arr(CFG_NUM_OF_OHs - 1 downto 0);
    signal gth_gbt_common_rxusrclk  : std_logic;
    signal gt_gbt_tx0_clk_arr       : std_logic_vector(CFG_NUM_OF_OHs - 1 downto 0);
    signal gt_gbt_tx1_clk_arr       : std_logic_vector(CFG_NUM_OF_OHs - 1 downto 0);
    signal gt_gbt_tx2_clk_arr       : std_logic_vector(CFG_NUM_OF_OHs - 1 downto 0);
        
    -------------------------- DAQLink ---------------------------------
    signal daq_clk_bufg         : std_logic;
    signal daq_clk_locked       : std_logic;
    signal daq_to_daqlink       : t_daq_to_daqlink;
    signal daqlink_to_daq       : t_daqlink_to_daq;
            
    -------------------------- IPBus --------------------------    
    
    signal ipb_miso             : ipb_rbus_array(number_of_ipb_slaves - 1 downto 0);
    signal ipb_mosi             : ipb_wbus_array(number_of_ipb_slaves - 1 downto 0);
    
    -------------- DEBUG ----------------
    signal debug_ipb_mosi       : ipb_wbus;
    signal debug_ipb_miso       : ipb_rbus;
    
    -- Debug flags for ChipScope
    attribute MARK_DEBUG : string;
    attribute MARK_DEBUG of ipb_clk_i           : signal is "TRUE";
    attribute MARK_DEBUG of debug_ipb_mosi      : signal is "TRUE";
    attribute MARK_DEBUG of debug_ipb_miso      : signal is "TRUE";
    
begin
    
    debug_ipb_mosi <= ipb_mosi(8);
    debug_ipb_miso <= ipb_miso(8);
    
    --==================--
    -- IP & MAC address --
    --==================--

    ip_addr_o <= x"c0a800a" & amc_slot_i;  -- 192.168.0.[160:175]
    mac_addr_o <= x"080030F100a" & amc_slot_i;  -- 08:00:30:F1:00:0[A0:AF] 
    
    --=========--
    --== GTX ==--
    --=========--
    
    i_gtx : entity work.gtx_wrapper
        port map(
            mgt_refclk_n_i => cdce_out1_n,
            mgt_refclk_p_i => cdce_out1_p,
            ref_clk_i      => ipb_clk_i,
            reset_i        => reset_i,
            usr_clk_o      => gtx_common_clk,
            tx_data_i      => gtx_tx_data_arr(3 downto 0),
            rx_data_o      => gtx_rx_data_arr(3 downto 0),
            rx_n_i         => sfp_rx_n(1 to 4),
            rx_p_i         => sfp_rx_p(1 to 4),
            tx_n_o         => sfp_tx_n(1 to 4),
            tx_p_o         => sfp_tx_p(1 to 4),
            rx_polarity_i  => (others => '0'), --TODO: hook up RX polarity switch
            tx_polarity_i  => (others => '0')  --TODO: hook up TX polarity switch
        );

    -- TODO: remove this hack once we start using GTXs with no buffers
    g_gtx_common_clk : for i in 0 to g_NUM_OF_GTX - 1 generate
        clk_gtx_tx_arr(i) <= gtx_common_clk;
        clk_gtx_rx_arr(i) <= gtx_common_clk;
    end generate;

    --=============--
    --== DAQLink ==--
    --=============--
    
    i_daqlink : entity work.daqlink_wrapper
        port map(
            RESET_IN               => reset_pwrup,
            MGT_REF_CLK_IN         => clk125_2_i,
            GTX_TXN_OUT            => amc_port_tx_n(1),
            GTX_TXP_OUT            => amc_port_tx_p(1),
            GTX_RXN_IN             => amc_port_rx_n(1),
            GTX_RXP_IN             => amc_port_rx_p(1),
            DATA_CLK_IN            => daq_clk_bufg,
            EVENT_DATA_IN          => daq_to_daqlink.event_data,
            EVENT_DATA_HEADER_IN   => daq_to_daqlink.event_header,
            EVENT_DATA_TRAILER_IN  => daq_to_daqlink.event_trailer,
            DATA_WRITE_EN_IN       => daq_to_daqlink.event_valid,
            READY_OUT              => daqlink_to_daq.ready,
            ALMOST_FULL_OUT        => daqlink_to_daq.almost_full,
            TTS_CLK_IN             => daq_to_daqlink.tts_clk,
            TTS_STATE_IN           => daq_to_daqlink.tts_state,
            GTX_CLK_OUT            => open,
            ERR_DISPER_COUNT       => daqlink_to_daq.disperr_cnt,
            ERR_NOT_IN_TABLE_COUNT => daqlink_to_daq.notintable_cnt,
            BC0_IN                 => daq_to_daqlink.ttc_bc0,
            RESYNC_IN              => '0', -- TODO to be implemented
            CLK125_IN              => user_clk125_i
        );
    
    daq_clocks : entity work.daq_clocks
        port map
        (
            CLK_IN1            => user_clk125_i,
            CLK_OUT1           => daq_clk_bufg, -- 25MHz
            CLK_OUT2           => open, -- 250MHz, not used
            RESET              => reset_i,
            LOCKED             => daq_clk_locked
        );

    --===================--
    --== GEM AMC Logic ==--
    --===================--
          
    i_gem_amc : entity work.gem_amc
        generic map(
            g_NUM_OF_OHs     => CFG_NUM_OF_OHs,
            g_USE_GBT        => CFG_USE_GBT,
            g_USE_3x_GBTs    => CFG_USE_3x_GBTs,
            g_USE_TRIG_LINKS => CFG_USE_TRIG_LINKS,
            g_NUM_IPB_SLAVES => number_of_ipb_slaves,
            g_DAQ_CLK_FREQ   => 25_000_000
        )
        port map(
            -- Resets
            reset_i                => reset_i,
            reset_pwrup_o          => reset_pwrup,
            
            -- TTC
            clk_40_ttc_p_i         => xpoint1_clk3_p,
            clk_40_ttc_n_i         => xpoint1_clk3_n,
            ttc_data_p_i           => amc_port_rx_p(3),
            ttc_data_n_i           => amc_port_rx_n(3),
            ttc_clocks_o           => open,
            
            -- 8b10b links
            gt_8b10b_rx_clk_arr_i  => gem_gt_8b10b_rx_clk_arr,
            gt_8b10b_tx_clk_arr_i  => gem_gt_8b10b_tx_clk_arr,
            gt_8b10b_rx_data_arr_i => gem_gt_8b10b_rx_data_arr,
            gt_8b10b_tx_data_arr_o => gem_gt_8b10b_tx_data_arr,
            
            -- Trigger links
            gt_trig0_rx_clk_arr_i  => gem_gt_trig0_rx_clk_arr,
            gt_trig0_rx_data_arr_i => gem_gt_trig0_rx_data_arr,
            gt_trig1_rx_clk_arr_i  => gem_gt_trig1_rx_clk_arr,
            gt_trig1_rx_data_arr_i => gem_gt_trig1_rx_data_arr,
            
            -- GBT (not used right now, need GBT MGTs)
            gt_gbt_rx_common_clk_i => '0',
            gt_gbt_rx_links_arr_i  => gem_gt_gbt_rx_links_arr,
            gt_gbt_tx_links_arr_o  => gem_gt_gbt_tx_links_arr,
            gt_gbt_tx0_clk_arr_i   => gt_gbt_tx0_clk_arr,
            gt_gbt_tx1_clk_arr_i   => gt_gbt_tx1_clk_arr,
            gt_gbt_tx2_clk_arr_i   => gt_gbt_tx2_clk_arr,
            
            ipb_reset_i            => reset_i or reset_pwrup,
            ipb_clk_i              => ipb_clk_i,
            ipb_miso_arr_o         => ipb_miso,
            ipb_mosi_arr_i         => ipb_mosi,
            
            led_l1a_o              => user_v6_led_o(2),
            led_trigger_o          => user_v6_led_o(1),
            
            daq_data_clk_i         => daq_clk_bufg,
            daq_data_clk_locked_i  => daq_clk_locked,
            daq_to_daqlink_o       => daq_to_daqlink,
            daqlink_to_daq_i       => daqlink_to_daq,
            board_id_i             => x"00" & sn
        );
         
    -- GTH mapping to GEM links
    g_gem_links : for i in 0 to CFG_NUM_OF_OHs - 1 generate
        gem_gt_8b10b_rx_clk_arr(i)  <= clk_gtx_rx_arr(CFG_OH_LINK_CONFIG_ARR(i).track_8b10b_link);
        gem_gt_8b10b_tx_clk_arr(i)  <= clk_gtx_tx_arr(CFG_OH_LINK_CONFIG_ARR(i).track_8b10b_link);
        gem_gt_8b10b_rx_data_arr(i) <= gtx_rx_data_arr(CFG_OH_LINK_CONFIG_ARR(i).track_8b10b_link);
        gtx_tx_data_arr(CFG_OH_LINK_CONFIG_ARR(i).track_8b10b_link) <= gem_gt_8b10b_tx_data_arr(i);
        
        gem_gt_trig0_rx_clk_arr(i)  <= clk_gtx_rx_arr(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link);
        gem_gt_trig0_rx_data_arr(i) <= gtx_rx_data_arr(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link);
        gem_gt_trig1_rx_clk_arr(i)  <= clk_gtx_rx_arr(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link);
        gem_gt_trig1_rx_data_arr(i) <= gtx_rx_data_arr(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link);

        -- GBT links should be mapped here, using fake loads right now
        gem_gt_gbt_rx_links_arr(i).rx0clk <= '0';
        gem_gt_gbt_rx_links_arr(i).rx1clk <= '0';
        gem_gt_gbt_rx_links_arr(i).rx2clk <= '0';
        
        gem_gt_gbt_rx_links_arr(i).rx0data <= (others => '0');
        gem_gt_gbt_rx_links_arr(i).rx1data <= (others => '0');
        gem_gt_gbt_rx_links_arr(i).rx2data <= (others => '0');
    
        gt_gbt_tx0_clk_arr(i)    <= '0';
        gt_gbt_tx1_clk_arr(i)    <= '0';
        gt_gbt_tx2_clk_arr(i)    <= '0';

    end generate; 

    --===================--
    --== IPBus mapping ==--
    --===================--
    g_ipb_map : for i in 0 to number_of_ipb_slaves - 1 generate
        ipb_miso_o(i) <= ipb_miso(i);
        ipb_mosi(i)   <= ipb_mosi_i(i);
    end generate;

              
end user_logic_arch;
