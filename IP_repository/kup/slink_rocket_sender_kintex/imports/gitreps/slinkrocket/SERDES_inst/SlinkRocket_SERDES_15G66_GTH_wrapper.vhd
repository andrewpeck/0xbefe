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
 
entity SlinkRocket_SERDES_15G66_GTH_wrapper is
  Port (
			gtwiz_userclk_tx_active_in         	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			gtwiz_userclk_rx_active_in         	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			txusrclk_in							: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			txusrclk2_in						: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			txusrclk4_in						: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxusrclk_in  						: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxusrclk2_in 						: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxusrclk4_in 						: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxoutclk_out						: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			txoutclk_out						: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
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
			gthrxn_in                          	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			gthrxp_in                          	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			loopback_in                        	: IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			rxoutclksel_in                      : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			rxcdrhold_in                        : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			qpll0clk_in                        	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			qpll0refclk_in                     	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			qpll1clk_in                        	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			qpll1refclk_in                     	: IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
			rxcdrphdone_out 				   	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxgearboxslip_in                   	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			txdiffctrl_in                      	: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			txheader_in                        	: IN STD_LOGIC_VECTOR(5 DOWNTO 0);
			txpolarity_in                      	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxpolarity_in                      	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			txpostcursor_in                    	: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			txprecursor_in                     	: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			txsequence_in                      	: IN STD_LOGIC_VECTOR(6 DOWNTO 0);
			drpdo_out                          	: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			drprdy_out                         	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			gtpowergood_out                    	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			gthtxn_out                         	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			gthtxp_out                         	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxdatavalid_out                    	: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			rxheader_out                       	: OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
			rxheadervalid_out                  	: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			rxpmaresetdone_out                 	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxprgdivresetdone_out              	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0); 
			rxstartofseq_out                   	: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			txpmaresetdone_out                 	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			txprgdivresetdone_out              	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0)  
	);
end SlinkRocket_SERDES_15G66_GTH_wrapper;

--*///////////////////////////////////////////////////////////////////////////////
--*////////////////////////   Behavioral        //////////////////////////////////
--*///////////////////////////////////////////////////////////////////////////////
architecture Behavioral of SlinkRocket_SERDES_15G66_GTH_wrapper is

COMPONENT SlinkRocket_SERDES_15G66_GTH
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
    gtwiz_userdata_tx_in               : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    gtwiz_userdata_rx_out              : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    drpaddr_in                         : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    drpclk_in                          : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpdi_in                           : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    drpen_in                           : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpwe_in                           : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthrxn_in                          : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthrxp_in                          : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    loopback_in                        : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
	rxoutclksel_in                     : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    rxcdrhold_in                       : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll0clk_in                        : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll0refclk_in                     : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1clk_in                        : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1refclk_in                     : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxgearboxslip_in                   : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
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
    gthtxn_out                         : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthtxp_out                         : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtpowergood_out                    : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
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

COMPONENT resetn_resync is
port (
	aresetn				: in std_logic;
	clock				: in std_logic; 

	Resetn_sync		: out std_logic;
	Resetp_sync		: out std_logic
	);
end COMPONENT;
 
signal Clock_tx_enable_buffer			: std_logic := '0'; 
signal Clock_rx_enable_buffer			: std_logic := '0'; 

   
signal reg_userdata_tx_in               : STD_LOGIC_VECTOR(63 DOWNTO 0);
signal reg_userdata_rx_out              : STD_LOGIC_VECTOR(127 DOWNTO 0);  
 
signal reg_rxdatavalid              	: STD_LOGIC_vector(1 downto 0); 
signal cell_rxdatavalid              	: STD_LOGIC_vector(1 downto 0);

signal reg_txheader_in               	: STD_LOGIC_VECTOR(5 DOWNTO 0);
signal reg_rxheader_out              	: STD_LOGIC_VECTOR(5 DOWNTO 0); 
signal cell_rxheader_out              	: STD_LOGIC_VECTOR(5 DOWNTO 0);
  
signal reg_rxheadervalid_out            : STD_LOGIC_vector(1 downto 0); 
signal cell_rxheadervalid_out           : STD_LOGIC_vector(1 downto 0);

component SR_SCRAMBLER is
	generic
	( 
		TX_DATA_WIDTH            : integer := 64
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
		RX_DATA_WIDTH            : integer := 64
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

signal tx_data_scrambled						               		: std_logic_vector(63 downto 0);
signal scrambler_start												: std_logic := '0';
signal scrambler_reset												: std_logic := '1'; 
signal tx_header_reg												: std_logic_vector(5 downto 0);

signal rx_data_scrambled				               				: std_logic_vector(63 downto 0);
signal rx_data_descrambled				               				: std_logic_vector(63 downto 0);  
signal descrambler_start											: std_logic	:= '0';
signal descrambler_reset											: std_logic	:= '1'; 
signal rx_header_rg									                : std_logic_vector(5 downto 0);  

signal gtwiz_reset_tx_done_cell										: std_logic_vector(0 downto 0);
signal gtwiz_reset_rx_done_cell										: std_logic_vector(0 downto 0);

signal ena_clock_RX                                                 : std_logic;  
signal ena_clock_TX                                                 : std_logic;  

signal ena_split_c4                                                 : std_logic;
signal ena_split_c2                                                 : std_logic;
signal ena_merge_c4                                                 : std_logic;
signal ena_merge_c2                                                 : std_logic; 

--#############################################################################
-- Code start here
--#############################################################################
begin


--***********************************************************************************************
--
--			GTH  15.66 Gb/s    
--
i:SlinkRocket_SERDES_15G66_GTH
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
    gthrxn_in                          =>	gthrxn_in,                          
    gthrxp_in                          =>	gthrxp_in,                          
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
    gthtxn_out                         =>	gthtxn_out,                         
    gthtxp_out                         =>	gthtxp_out,                         
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

gtwiz_reset_tx_done_out	<= gtwiz_reset_tx_done_cell;	
gtwiz_reset_rx_done_out	<= gtwiz_reset_rx_done_cell;	

Scamble:SR_SCRAMBLER   
	port map
	(
		-- User Interface
		UNSCRAMBLED_DATA_IN      => reg_userdata_tx_in,
		SCRAMBLED_DATA_OUT       => tx_data_scrambled,
		DATA_VALID_IN            => scrambler_start,
	
		-- System Interface
		USER_CLK                 => txusrclk2_in(0),     
		SYSTEM_RESET             => scrambler_reset 
	); 
 
process(txusrclk2_in(0))
begin
	if rising_edge(txusrclk2_in(0)) then
		tx_header_reg	<= reg_txheader_in;
		
		scrambler_start	<= gtwiz_reset_tx_done_cell(0); 
		scrambler_reset	<= not(gtwiz_reset_tx_done_cell(0));
	end if;
end process;


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
		rx_header_rg		<= cell_rxheader_out;
		
		descrambler_start	<= gtwiz_reset_rx_done_cell(0);  
		descrambler_reset	<= not(gtwiz_reset_rx_done_cell(0));
	end if;
end process;	

--******************************************************************************	
-- Clock div by 2 for TX clock	

resync_reset_TX_active:resetn_resync  
port map(
	aresetn			=> gtwiz_userclk_tx_active_in(0),
	clock			=> txusrclk2_in(0),

	Resetn_sync		=> ena_clock_TX
	);

process(ena_clock_TX,txusrclk2_in)
begin
    if ena_clock_TX = '0' then
        Clock_tx_enable_buffer  <= '0';
        ena_split_c2            <= '0';
	elsif rising_edge(txusrclk2_in(0)) then
	    if ena_split_c2 = '1' then
		  Clock_tx_enable_buffer	<= not(Clock_tx_enable_buffer);
		end if;
		ena_split_c2          <= ena_split_c4;
	end if;
end process;

process(ena_clock_TX,txusrclk4_in)
begin
    if ena_clock_TX = '0' then 
        ena_split_c4    <= '0';
	elsif rising_edge(txusrclk4_in(0)) then
		ena_split_c4	<= '1';
	end if;
end process;
 
 	 
TX_userclk_out(0)	<= txusrclk4_in(0);
--******************************************************************************	
-- Clock div by 2 for RX clock	

resync_reset_RX_active:resetn_resync  
port map(
	aresetn			=> gtwiz_userclk_rx_active_in(0),
	clock			=> rxusrclk2_in(0),

	Resetn_sync		=> ena_clock_RX
	);


process(ena_clock_RX,rxusrclk2_in(0))
begin
    if ena_clock_RX = '0' then    
        Clock_rx_enable_buffer  <= '0';
        ena_merge_c2            <= '0';
	elsif rising_edge(rxusrclk2_in(0)) then 
	    if ena_merge_c2 = '1' then
            Clock_rx_enable_buffer <= not(Clock_rx_enable_buffer);
        end if;
        
        ena_merge_c2    <= ena_merge_c4;      
	end if;
end process;
  
process(ena_clock_RX,rxusrclk4_in)
begin
    if ena_clock_RX = '0' then 
        ena_merge_c4    <= '0';
	elsif rising_edge(rxusrclk4_in(0)) then
		ena_merge_c4	<= '1';
	end if;
end process;
  
RX_userclk_out(0)	<= rxusrclk4_in(0);
--******************************************************************************	
-- Merge the INPUT data

process(txusrclk2_in)
begin
	if rising_edge(txusrclk2_in(0)) then
		if Clock_tx_enable_buffer = '1' then
			reg_userdata_tx_in			<= gtwiz_userdata_tx_in(127 downto 64);
			reg_txheader_in(5 downto 2)	<= "0000";
			reg_txheader_in(1 downto 0)	<= txheader_in(4 downto 3);
		else
			reg_userdata_tx_in			<= gtwiz_userdata_tx_in(063 downto 00);
			reg_txheader_in(5 downto 2)	<= "0000";
			reg_txheader_in(1 downto 0)	<= txheader_in(1 downto 0);
		end if;
	end if;
end process;

--******************************************************************************	
-- Split the OUTPUT data

process(rxusrclk2_in(0))
begin
	if rising_edge(rxusrclk2_in(0)) then
		if  Clock_rx_enable_buffer = '0' then
			reg_userdata_rx_out(127 downto 64)	<= rx_data_descrambled;
			reg_rxdatavalid(1)					<= '1';
			reg_rxheader_out(5)					<= '0';
			reg_rxheader_out(4 downto 3)		<= rx_header_rg(1 downto 0);
			reg_rxheadervalid_out(1)			<= '1';
		else
			reg_userdata_rx_out(63 downto 0)	<= rx_data_descrambled;
			reg_rxdatavalid(0)					<= '1';
			reg_rxheader_out(2)					<= '0';
			reg_rxheader_out(1 downto 0)		<= rx_header_rg(1 downto 0);
			reg_rxheadervalid_out(0)			<= '1';			
		end if;
	end if;
end process;
	
gtwiz_userdata_rx_out	<= reg_userdata_rx_out;
rxdatavalid_out	        <= reg_rxdatavalid;
rxheader_out	        <= reg_rxheader_out;
rxheadervalid_out	    <= reg_rxheadervalid_out;
	
end Behavioral;