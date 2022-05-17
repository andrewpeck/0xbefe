----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.11.2017 10:42:34
-- Design Name: 
-- Module Name: Serdes_wrapper_selection
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: This file select the serder in function of GTY GTH  and reference clok
-- 		
-- 		
-- 		
-- 		
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
  
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;
 
entity SlinkRocket_SERDES_25G78125_GTY_wrapper is
  Port (
    gtwiz_userclk_tx_active_in         	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_active_in         	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_clk_freerun_in         	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_all_in                 	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_pll_and_datapath_in 	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_datapath_in         	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_pll_and_datapath_in 	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_datapath_in         	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_qpll0lock_in           	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_cdr_stable_out      	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_done_out            	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_done_out            	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_qpll0reset_out         	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userdata_tx_in               	: IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    gtwiz_userdata_rx_out              	: OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    TX_userclk_out	                 	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
	RX_userclk_out	                 	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpaddr_in                         	: IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    drpclk_in                          	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpdi_in                           	: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    drpen_in                           	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpwe_in                           	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtyrxn_in                          	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtyrxp_in                          	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    loopback_in                        	: IN STD_LOGIC_VECTOR(2 DOWNTO 0);
	rxoutclksel_in                      : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    rxcdrhold_in                        : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll0clk_in                        	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll0refclk_in                     	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1clk_in                        	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1refclk_in                     	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxgearboxslip_in                   	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxpolarity_in                      	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxusrclk_in                        	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxusrclk2_in                       	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txdiffctrl_in                      	: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txheader_in                        	: IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    txpolarity_in                      	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpostcursor_in                    	: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txprecursor_in                     	: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txsequence_in                      	: IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    txusrclk_in                        	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txusrclk2_in                       	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpdo_out                          	: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    drprdy_out                         	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtpowergood_out                    	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtytxn_out                         	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtytxp_out                         	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxcdrphdone_out                    	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxdatavalid_out                    	: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxheader_out                       	: OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    rxheadervalid_out                  	: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxoutclk_out                       	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxpmaresetdone_out                 	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxprgdivresetdone_out              	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxstartofseq_out                   	: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    txoutclk_out                       	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpmaresetdone_out                 	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    txprgdivresetdone_out              	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
	);
end SlinkRocket_SERDES_25G78125_GTY_wrapper;

--*///////////////////////////////////////////////////////////////////////////////
--*////////////////////////   Behavioral        //////////////////////////////////
--*///////////////////////////////////////////////////////////////////////////////
architecture Behavioral of SlinkRocket_SERDES_25G78125_GTY_wrapper is

COMPONENT SlinkRocket_SERDES_25G78125_GTY
  PORT (
    gtwiz_userclk_tx_active_in         : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_active_in         : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_clk_freerun_in         : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_all_in                 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_datapath_in         : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_datapath_in         : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_qpll0lock_in           : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_cdr_stable_out      : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_done_out            : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_done_out            : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_qpll0reset_out         : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userdata_tx_in               : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    gtwiz_userdata_rx_out              : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    drpaddr_in                         : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    drpclk_in                          : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpdi_in                           : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    drpen_in                           : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpwe_in                           : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtyrxn_in                          : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtyrxp_in                          : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    loopback_in                        : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    qpll0clk_in                        : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll0refclk_in                     : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1clk_in                        : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1refclk_in                     : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxcdrhold_in                       : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxgearboxslip_in                   : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxoutclksel_in                     : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    rxpolarity_in                      : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxusrclk_in                        : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxusrclk2_in                       : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txdiffctrl_in                      : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txheader_in                        : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    txpolarity_in                      : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpostcursor_in                    : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txprecursor_in                     : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txsequence_in                      : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    txusrclk_in                        : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txusrclk2_in                       : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpdo_out                          : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    drprdy_out                         : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtpowergood_out                    : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtytxn_out                         : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtytxp_out                         : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxcdrphdone_out                    : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxdatavalid_out                    : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxheader_out                       : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    rxheadervalid_out                  : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxoutclk_out                       : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxpmaresetdone_out                 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxprgdivresetdone_out              : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxstartofseq_out                   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    txoutclk_out                       : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpmaresetdone_out                 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    txprgdivresetdone_out              : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;

component SR_SCRAMBLER is
	generic
	( 
		TX_DATA_WIDTH            : integer := 128
	);
	port
	(
		-- User Interface
		UNSCRAMBLED_DATA_IN      : in  std_logic_vector((TX_DATA_WIDTH-1) downto 0); 
		SCRAMBLED_DATA_OUT       : out std_logic_vector((TX_DATA_WIDTH-1) downto 0); 
		DATA_VALID_IN            : in  std_logic;
	
		-- System Interface
		USER_CLK                 : in  std_logic;      
		SYSTEM_RESET             : in  std_logic
	);
end component;

component SR_DESCRAMBLER is
	generic
	( 
		RX_DATA_WIDTH            : integer := 128
	);
	port
	(
		-- User Interface
		SCRAMBLED_DATA_IN        : in  std_logic_vector((RX_DATA_WIDTH-1) downto 0); 
		UNSCRAMBLED_DATA_OUT     : out std_logic_vector((RX_DATA_WIDTH-1) downto 0); 
		DATA_VALID_IN            : in  std_logic;
	
		-- System Interface
		USER_CLK                 : in  std_logic;      
		SYSTEM_RESET             : in  std_logic
	);
end component;

signal tx_data_scrambled						               		: std_logic_vector(127 downto 0);
signal scrambler_start												: std_logic := '0';
signal scrambler_reset												: std_logic := '1'; 

signal tx_header_reg												: std_logic_vector(5 downto 0);

signal rx_data_scrambled				               				: std_logic_vector(127 downto 0);
signal rx_data_descrambled		 		               				: std_logic_vector(127 downto 0);
signal descrambler_start											: std_logic	:= '0';
signal descrambler_reset											: std_logic	:= '1'; 

signal rx_header_rg									                : std_logic_vector(5 downto 0); 
signal rxdatavalid_rg								                : std_logic_vector(1 downto 0); 
signal rxheadervalid_rg								                : std_logic_vector(1 downto 0); 
      
signal cell_rxheader_out              								: STD_LOGIC_VECTOR(5 DOWNTO 0);
signal cell_rxdatavalid              								: STD_LOGIC_vector(1 downto 0); 
signal cell_rxheadervalid_out           							: STD_LOGIC_vector(1 downto 0);
 
signal gtwiz_reset_tx_done_cell										: std_logic_vector(0 downto 0);
signal gtwiz_reset_rx_done_cell										: std_logic_vector(0 downto 0);

--#############################################################################
-- Code start here
--#############################################################################
begin


--***********************************************************************************************
--
--			GTH  25.78125 Gb/s    
--
i:SlinkRocket_SERDES_25G78125_GTY
  PORT map (
    gtwiz_userclk_tx_active_in         =>	gtwiz_userclk_tx_active_in,         
    gtwiz_userclk_rx_active_in         =>	gtwiz_userclk_rx_active_in,         
    gtwiz_reset_clk_freerun_in         =>	gtwiz_reset_clk_freerun_in,         
    gtwiz_reset_all_in                 =>	gtwiz_reset_all_in,                 
    gtwiz_reset_tx_pll_and_datapath_in =>	gtwiz_reset_tx_pll_and_datapath_in, 
    gtwiz_reset_tx_datapath_in         =>	gtwiz_reset_tx_datapath_in,         
    gtwiz_reset_rx_pll_and_datapath_in =>	gtwiz_reset_rx_pll_and_datapath_in, 
    gtwiz_reset_rx_datapath_in         =>	gtwiz_reset_rx_datapath_in,         
    gtwiz_reset_qpll0lock_in           =>	gtwiz_reset_qpll0lock_in,           
    gtwiz_reset_rx_cdr_stable_out      =>	gtwiz_reset_rx_cdr_stable_out,      
    gtwiz_reset_tx_done_out            =>	gtwiz_reset_tx_done_cell,            
    gtwiz_reset_rx_done_out            =>	gtwiz_reset_rx_done_cell,            
    gtwiz_reset_qpll0reset_out         =>	gtwiz_reset_qpll0reset_out,         
    gtwiz_userdata_tx_in               =>	tx_data_scrambled,                 
    gtwiz_userdata_rx_out              =>	rx_data_scrambled,               
    drpaddr_in                         =>	drpaddr_in,                        
    drpclk_in                          =>	drpclk_in  ,                        
    drpdi_in                           =>	drpdi_in   ,                        
    drpen_in                           =>	drpen_in   ,                        
    drpwe_in                           =>	drpwe_in   ,                        
    gtyrxn_in                          =>	gtyrxn_in,                          
    gtyrxp_in                          =>	gtyrxp_in,                          
    loopback_in                        =>	loopback_in,   
	rxoutclksel_in                     => 	rxoutclksel_in,
    rxcdrhold_in                       => 	rxcdrhold_in,                     
    qpll0clk_in                        =>	qpll0clk_in,                        
    qpll0refclk_in                     =>	qpll0refclk_in,                     
    qpll1clk_in                        =>	qpll1clk_in,                        
    qpll1refclk_in                     =>	qpll1refclk_in,                     
    rxgearboxslip_in                   =>	rxgearboxslip_in,                   
    rxpolarity_in                      =>	rxpolarity_in,                      
    rxusrclk_in                        =>	rxusrclk_in  ,                      
    rxusrclk2_in                       =>	rxusrclk2_in ,                      
    txdiffctrl_in                      =>	txdiffctrl_in,                      
    txheader_in                        =>	tx_header_reg,                    
    txpolarity_in                      =>	txpolarity_in,                      
    txpostcursor_in                    =>	txpostcursor_in,                    
    txprecursor_in                     =>	txprecursor_in,                     
    txsequence_in                      =>	txsequence_in,                      
    txusrclk_in                        =>	txusrclk_in,                        
    txusrclk2_in                       =>	txusrclk2_in,                       
    drpdo_out                          =>	drpdo_out,                          
    drprdy_out                         =>	drprdy_out,                         
    gtytxn_out                         =>	gtytxn_out,                         
    gtytxp_out                         =>	gtytxp_out,                         
    gtpowergood_out                    =>	gtpowergood_out,                    
    rxcdrphdone_out                    =>	rxcdrphdone_out,                    
    rxdatavalid_out                    =>	cell_rxdatavalid,                   
    rxheader_out                       =>	cell_rxheader_out,                  
    rxheadervalid_out                  =>	cell_rxheadervalid_out,             
    rxoutclk_out                       =>	rxoutclk_out,                       
    rxpmaresetdone_out                 =>	rxpmaresetdone_out,                 
    rxprgdivresetdone_out              =>	rxprgdivresetdone_out,              
    rxstartofseq_out                   =>	rxstartofseq_out,                   
    txoutclk_out                       =>	txoutclk_out,                       
    txpmaresetdone_out                 =>	txpmaresetdone_out,                 
    txprgdivresetdone_out              =>	txprgdivresetdone_out                   
	);
	

TX_userclk_out	                <= txusrclk2_in;
RX_userclk_out	                <= rxusrclk2_in;	

gtwiz_reset_tx_done_out			<= gtwiz_reset_tx_done_cell;		
gtwiz_reset_rx_done_out			<= gtwiz_reset_rx_done_cell;

--*****************************************************
Scamble:SR_SCRAMBLER   
	port map
	(
		-- User Interface
		UNSCRAMBLED_DATA_IN      => gtwiz_userdata_tx_in,
		SCRAMBLED_DATA_OUT       => tx_data_scrambled,
		DATA_VALID_IN            => scrambler_start,
	
		-- System Interface
		USER_CLK                 => txusrclk2_in(0),     
		SYSTEM_RESET             => scrambler_reset 
	); 
	
-- add a delay of 1 clock (Scramble delay)
process(txusrclk2_in(0))
begin
	if rising_edge(txusrclk2_in(0)) then
		tx_header_reg			<= txheader_in;
				
		scrambler_start			<= gtwiz_reset_tx_done_cell(0); 
		scrambler_reset			<= not(gtwiz_reset_tx_done_cell(0));
	end if;
end process;

--******************************************************************************
DeScramble:SR_DESCRAMBLER   
	port map
	(
		-- User Interface
		SCRAMBLED_DATA_IN        => rx_data_scrambled,
		UNSCRAMBLED_DATA_OUT     => rx_data_descrambled,
		DATA_VALID_IN            => descrambler_start,
	
		-- System Interface
		USER_CLK                 => rxusrclk2_in(0),      
		SYSTEM_RESET             => descrambler_reset
	);
 
process(rxusrclk2_in(0))
begin
	if rising_edge(rxusrclk2_in(0)) then
		rx_header_rg			<= cell_rxheader_out;
		rxdatavalid_rg			<= cell_rxdatavalid;                                    
		rxheadervalid_rg		<= cell_rxheadervalid_out;
			
		descrambler_start		<= gtwiz_reset_rx_done_cell(0);  
		descrambler_reset		<= not(gtwiz_reset_rx_done_cell(0));
	end if;
end process;
   
gtwiz_userdata_rx_out			<= rx_data_descrambled;
rxdatavalid_out	        		<= rxdatavalid_rg;
rxheader_out	        		<= rx_header_rg;
rxheadervalid_out	    		<= rxheadervalid_rg;
	
end Behavioral;