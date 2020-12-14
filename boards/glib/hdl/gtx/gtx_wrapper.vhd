----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Thomas Lenzi (thomas.lenzi@cern.ch)
-- 
-- Create Date:    08:37:33 07/07/2015 
-- Design Name:    GLIB v2
-- Module Name:    gtx_wrapper - Behavioral 
-- Project Name:   GLIB v2
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
-- Description: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

use work.gem_pkg.all;

entity gtx_wrapper is
port(

    mgt_refclk_n_i  : in  std_logic;
    mgt_refclk_p_i  : in  std_logic;
    ref_clk_i       : in  std_logic;
    
    reset_i         : in  std_logic;
    
    tx_data_i       : in  t_gt_8b10b_tx_data_arr(3 downto 0);
    rx_data_o       : out t_gt_8b10b_rx_data_arr(3 downto 0);
     
    usr_clk_o       : out std_logic;
   
    rx_n_i          : in  std_logic_vector(3 downto 0);
    rx_p_i          : in  std_logic_vector(3 downto 0);
    tx_n_o          : out std_logic_vector(3 downto 0);
    tx_p_o          : out std_logic_vector(3 downto 0);
    
    rx_polarity_i   : in  std_logic_vector(3 downto 0);
    tx_polarity_i   : in  std_logic_vector(3 downto 0)
);
end gtx_wrapper;

architecture Behavioral of gtx_wrapper is

    signal mgt_refclk       : std_logic;
    signal mgt_reset        : std_logic;
    signal mgt_rst_cnt      : integer range 0 to 67_108_863;
   
    signal rx_disperr       : std_logic_vector(7 downto 0); 
    signal rx_notintable    : std_logic_vector(7 downto 0);
    
    signal usr_clk          : std_logic;
    signal usr_clk2         : std_logic;
    
begin    
    
    i_ibufds_gtxe1 : ibufds_gtxe1
    port map(
        o       => mgt_refclk,
        odiv2   => open,
        ceb     => '0',
        i       => mgt_refclk_p_i,
        ib      => mgt_refclk_n_i
    );


    usr_clk_bufg : bufg 
    port map(
        i   => usr_clk, 
        o   => usr_clk2
    );
    
    usr_clk_o <= usr_clk2;
    
    i_sfp_gtx : entity work.sfp_gtx
    port map(
        GTX0_RXCHARISK_OUT          => rx_data_o(0).rxcharisk(1 downto 0),
        GTX0_RXDISPERR_OUT          => rx_data_o(0).rxdisperr(1 downto 0),
        GTX0_RXNOTINTABLE_OUT       => rx_data_o(0).rxnotintable(1 downto 0),
        GTX0_RXBYTEISALIGNED_OUT    => open,
        GTX0_RXCOMMADET_OUT         => open,
        GTX0_RXENMCOMMAALIGN_IN     => '1',
        GTX0_RXENPCOMMAALIGN_IN     => '1',
        GTX0_RXDATA_OUT             => rx_data_o(0).rxdata(15 downto 0),
        GTX0_RXUSRCLK2_IN           => usr_clk2,
        GTX0_RXN_IN                 => rx_n_i(0),
        GTX0_RXP_IN                 => rx_p_i(0),
        GTX0_GTXRXRESET_IN          => (mgt_reset or reset_i),
        GTX0_MGTREFCLKRX_IN         => mgt_refclk,
        GTX0_PLLRXRESET_IN          => reset_i,
        GTX0_RXPLLLKDET_OUT         => open,
        GTX0_RXRESETDONE_OUT        => open,
        GTX0_RXPOLARITY_IN          => rx_polarity_i(0),
        GTX0_TXCHARISK_IN           => tx_data_i(0).txcharisk(1 downto 0),
        GTX0_TXDATA_IN              => tx_data_i(0).txdata(15 downto 0),
        GTX0_TXOUTCLK_OUT           => usr_clk,
        GTX0_TXUSRCLK2_IN           => usr_clk2,
        GTX0_TXN_OUT                => tx_n_o(0),
        GTX0_TXP_OUT                => tx_p_o(0),
        GTX0_GTXTXRESET_IN          => (mgt_reset or reset_i),
        GTX0_TXRESETDONE_OUT        => open,
        GTX0_TXPOLARITY_IN          => tx_polarity_i(0),
        --        
        GTX1_RXCHARISK_OUT          => rx_data_o(1).rxcharisk(1 downto 0),
        GTX1_RXDISPERR_OUT          => rx_data_o(1).rxdisperr(1 downto 0),
        GTX1_RXNOTINTABLE_OUT       => rx_data_o(1).rxnotintable(1 downto 0),
        GTX1_RXBYTEISALIGNED_OUT    => open,
        GTX1_RXCOMMADET_OUT         => open,
        GTX1_RXENMCOMMAALIGN_IN     => '1',
        GTX1_RXENPCOMMAALIGN_IN     => '1',
        GTX1_RXDATA_OUT             => rx_data_o(1).rxdata(15 downto 0),
        GTX1_RXUSRCLK2_IN           => usr_clk2,
        GTX1_RXN_IN                 => rx_n_i(1),
        GTX1_RXP_IN                 => rx_p_i(1),
        GTX1_GTXRXRESET_IN          => (mgt_reset or reset_i),
        GTX1_MGTREFCLKRX_IN         => mgt_refclk,
        GTX1_PLLRXRESET_IN          => reset_i,
        GTX1_RXPLLLKDET_OUT         => open,
        GTX1_RXRESETDONE_OUT        => open,
        GTX1_RXPOLARITY_IN          => rx_polarity_i(1),        
        GTX1_TXCHARISK_IN           => tx_data_i(1).txcharisk(1 downto 0),
        GTX1_TXDATA_IN              => tx_data_i(1).txdata(15 downto 0),
        GTX1_TXOUTCLK_OUT           => open,
        GTX1_TXUSRCLK2_IN           => usr_clk2,
        GTX1_TXN_OUT                => tx_n_o(1),
        GTX1_TXP_OUT                => tx_p_o(1),
        GTX1_GTXTXRESET_IN          => (mgt_reset or reset_i),
        GTX1_TXRESETDONE_OUT        => open,
        GTX1_TXPOLARITY_IN          => tx_polarity_i(1),
        --        
        GTX2_RXCHARISK_OUT          => rx_data_o(2).rxcharisk(1 downto 0),
        GTX2_RXDISPERR_OUT          => rx_data_o(2).rxdisperr(1 downto 0),
        GTX2_RXNOTINTABLE_OUT       => rx_data_o(2).rxnotintable(1 downto 0),
        GTX2_RXBYTEISALIGNED_OUT    => open,
        GTX2_RXCOMMADET_OUT         => open,
        GTX2_RXENMCOMMAALIGN_IN     => '1',
        GTX2_RXENPCOMMAALIGN_IN     => '1',
        GTX2_RXDATA_OUT             => rx_data_o(2).rxdata(15 downto 0),
        GTX2_RXUSRCLK2_IN           => usr_clk2,
        GTX2_RXN_IN                 => rx_n_i(2),
        GTX2_RXP_IN                 => rx_p_i(2),
        GTX2_GTXRXRESET_IN          => (mgt_reset or reset_i),
        GTX2_MGTREFCLKRX_IN         => mgt_refclk,
        GTX2_PLLRXRESET_IN          => reset_i,
        GTX2_RXPLLLKDET_OUT         => open,
        GTX2_RXRESETDONE_OUT        => open,
        GTX2_RXPOLARITY_IN          => rx_polarity_i(2),        
        GTX2_TXCHARISK_IN           => tx_data_i(2).txcharisk(1 downto 0),
        GTX2_TXDATA_IN              => tx_data_i(2).txdata(15 downto 0),
        GTX2_TXOUTCLK_OUT           => open,
        GTX2_TXUSRCLK2_IN           => usr_clk2,
        GTX2_TXN_OUT                => tx_n_o(2),
        GTX2_TXP_OUT                => tx_p_o(2),
        GTX2_GTXTXRESET_IN          => (mgt_reset or reset_i),
        GTX2_TXRESETDONE_OUT        => open,
        GTX2_TXPOLARITY_IN          => tx_polarity_i(2),
        --       
        GTX3_RXCHARISK_OUT          => rx_data_o(3).rxcharisk(1 downto 0),
        GTX3_RXDISPERR_OUT          => rx_data_o(3).rxdisperr(1 downto 0),
        GTX3_RXNOTINTABLE_OUT       => rx_data_o(3).rxnotintable(1 downto 0),
        GTX3_RXBYTEISALIGNED_OUT    => open,
        GTX3_RXCOMMADET_OUT         => open,
        GTX3_RXENMCOMMAALIGN_IN     => '1',
        GTX3_RXENPCOMMAALIGN_IN     => '1',
        GTX3_RXDATA_OUT             => rx_data_o(3).rxdata(15 downto 0),
        GTX3_RXUSRCLK2_IN           => usr_clk2,
        GTX3_RXN_IN                 => rx_n_i(3),
        GTX3_RXP_IN                 => rx_p_i(3),
        GTX3_GTXRXRESET_IN          => (mgt_reset or reset_i),
        GTX3_MGTREFCLKRX_IN         => mgt_refclk,
        GTX3_PLLRXRESET_IN          => reset_i,
        GTX3_RXPLLLKDET_OUT         => open,
        GTX3_RXRESETDONE_OUT        => open,
        GTX3_RXPOLARITY_IN          => rx_polarity_i(3),        
        GTX3_TXCHARISK_IN           => tx_data_i(3).txcharisk(1 downto 0),
        GTX3_TXDATA_IN              => tx_data_i(3).txdata(15 downto 0),
        GTX3_TXOUTCLK_OUT           => open,
        GTX3_TXUSRCLK2_IN           => usr_clk2,
        GTX3_TXN_OUT                => tx_n_o(3),
        GTX3_TXP_OUT                => tx_p_o(3),
        GTX3_GTXTXRESET_IN          => (mgt_reset or reset_i),
        GTX3_TXRESETDONE_OUT        => open,
        GTX3_TXPOLARITY_IN          => tx_polarity_i(3)
    );
    
    --== Control Reset signal ==--
    
    process(ref_clk_i)
    begin
        if (rising_edge(ref_clk_i)) then
            if (mgt_rst_cnt = 30_000_000) then
              mgt_reset <= '0';
              mgt_rst_cnt <= 30_000_000;
            else
              mgt_reset <= '1';
              mgt_rst_cnt <= mgt_rst_cnt + 1;
            end if;
        end if;
    end process;
    
end Behavioral;
