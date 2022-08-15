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
 
entity Serdes_wrapper_select is
 Generic (  throughput								: string := "15.66";
				--possible choices are  15.66 or 25.78125
			ref_clock								: string := "156.25";
				--possible choices are  156.25  or   322.265625
			technology								: string := "GTY"
				-- possible choices are GTY or GTH or GTH_KU
		);
  Port ( 	gtwiz_userclk_tx_active_in 			: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			gtwiz_userclk_rx_active_in 			: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxusrclk_in                			: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxusrclk2_in               			: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxusrclk4_in               			: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			txusrclk_in                			: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			txusrclk2_in               			: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			txusrclk4_in               			: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxoutclk_out               			: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			txoutclk_out               			: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			TX_userclk_out	                 	: OUT STD_LOGIC;                                 
			RX_userclk_out	                 	: OUT STD_LOGIC;  
	
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
			drpaddr_in                         	: IN STD_LOGIC_VECTOR(9 DOWNTO 0);
			drpclk_in                          	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			drpdi_in                           	: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			drpen_in                           	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			drpwe_in                           	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			gt_rxn_in                          	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			gt_rxp_in                          	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
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
			gt_txn_out                         	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			gt_txp_out                         	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxdatavalid_out                    	: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			rxheader_out                       	: OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
			rxheadervalid_out                  	: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			rxpmaresetdone_out                 	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			rxprgdivresetdone_out              	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0); 
			rxstartofseq_out                   	: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			txpmaresetdone_out                 	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
			txprgdivresetdone_out              	: OUT STD_LOGIC_VECTOR(0 DOWNTO 0) 
	);
end Serdes_wrapper_select;

--*///////////////////////////////////////////////////////////////////////////////
--*////////////////////////   Behavioral        //////////////////////////////////
--*///////////////////////////////////////////////////////////////////////////////
architecture Behavioral of Serdes_wrapper_select is

COMPONENT SlinkRocket_SERDES_15G66_GTH_KU_wrapper 
	port (
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
END COMPONENT;

COMPONENT SlinkRocket_SERDES_15G66_GTH_wrapper
  PORT (
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
END COMPONENT;
 
	
COMPONENT SlinkRocket_SERDES_15G66_GTY_wrapper
  PORT (
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
    rxusrclk4_in                       	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txdiffctrl_in                      	: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txheader_in                        	: IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    txpolarity_in                      	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpostcursor_in                    	: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txprecursor_in                     	: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txsequence_in                      	: IN STD_LOGIC_VECTOR(6 DOWNTO 0); 
    txusrclk_in                        	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txusrclk2_in                       	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txusrclk4_in                       	: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
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
END COMPONENT;	
 
COMPONENT SlinkRocket_SERDES_25G78125_GTY_wrapper
  PORT (
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
END COMPONENT;
 
--#############################################################################
-- Code start here
--#############################################################################
begin


--***********************************************************************************************
--
--			GTH Kintex Ultrascale  15.66 Gb/s    
--
SERDES_16G_GTH_KU:if throughput = "15.66"  and technology = "GTH_KU" generate
	i1:SlinkRocket_SERDES_15G66_GTH_KU_wrapper
	  PORT MAP (
	gtwiz_userclk_tx_active_in         		=> gtwiz_userclk_tx_active_in ,                                   
	gtwiz_userclk_rx_active_in         		=> gtwiz_userclk_rx_active_in ,                                   
	txusrclk_in								=> txusrclk_in                ,                                   
	txusrclk2_in							=> txusrclk2_in               ,                                   
	txusrclk4_in							=> txusrclk4_in               ,                                   
	rxusrclk_in  							=> rxusrclk_in                ,                                   
	rxusrclk2_in 							=> rxusrclk2_in               ,                                   
	rxusrclk4_in 							=> rxusrclk4_in               ,                                   
	rxoutclk_out							=> rxoutclk_out               ,                                   
	txoutclk_out							=> txoutclk_out               ,                   
	TX_userclk_out(0)                 		=> TX_userclk_out            ,                                   
	RX_userclk_out(0)                 		=> RX_userclk_out            ,   
	
	gtwiz_reset_clk_freerun_in         		=> gtwiz_reset_clk_freerun_in,         
	gtwiz_reset_all_in                 		=> gtwiz_reset_all_in,                 
	gtwiz_reset_tx_pll_and_datapath_in 		=> gtwiz_reset_tx_pll_and_datapath_in, 
	gtwiz_reset_tx_datapath_in         		=> gtwiz_reset_tx_datapath_in,         
	gtwiz_reset_rx_pll_and_datapath_in 		=> gtwiz_reset_rx_pll_and_datapath_in, 
	gtwiz_reset_rx_datapath_in         		=> gtwiz_reset_rx_datapath_in,         
	gtwiz_reset_qpll0lock_in           		=> gtwiz_reset_qpll0lock_in,           
	gtwiz_reset_rx_cdr_stable_out      		=> gtwiz_reset_rx_cdr_stable_out,      
	gtwiz_reset_tx_done_out            		=> gtwiz_reset_tx_done_out,            
	gtwiz_reset_rx_done_out            		=> gtwiz_reset_rx_done_out,            
	gtwiz_reset_qpll0reset_out         		=> gtwiz_reset_qpll0reset_out,         
	gtwiz_userdata_tx_in               		=> gtwiz_userdata_tx_in,               
	gtwiz_userdata_rx_out              		=> gtwiz_userdata_rx_out,              
	drpaddr_in                         		=> drpaddr_in,                         
	drpclk_in                          		=> drpclk_in ,                         
	drpdi_in                           		=> drpdi_in  ,                         
	drpen_in                           		=> drpen_in  ,                         
	drpwe_in                           		=> drpwe_in  ,                         
	gthrxn_in                          		=> gt_rxn_in ,                         
	gthrxp_in                          		=> gt_rxp_in ,                         
	loopback_in                        		=> loopback_in,    
	rxoutclksel_in                          => rxoutclksel_in,
	rxcdrhold_in                            => rxcdrhold_in,                 
	qpll0clk_in                        		=> qpll0clk_in     ,                   
	qpll0refclk_in                     		=> qpll0refclk_in  ,                   
	qpll1clk_in                        		=> qpll1clk_in     ,                   
	qpll1refclk_in                     		=> qpll1refclk_in  ,                   
	rxcdrphdone_out 				   		=> rxcdrphdone_out,                    
	rxgearboxslip_in                   		=> rxgearboxslip_in,                   
	txdiffctrl_in                      		=> txdiffctrl_in,                      
	txheader_in                        		=> txheader_in,                        
	txpolarity_in                      		=> txpolarity_in,                      
	rxpolarity_in                      		=> rxpolarity_in,                      
	txpostcursor_in                    		=> txpostcursor_in,                    
	txprecursor_in                     		=> txprecursor_in,                     
	txsequence_in                      		=> txsequence_in,                      
	drpdo_out                          		=> drpdo_out,                          
	drprdy_out                         		=> drprdy_out,                         
	gtpowergood_out                    		=> gtpowergood_out,                    
	gthtxn_out                         		=> gt_txn_out ,                        
	gthtxp_out                         		=> gt_txp_out ,                        
	rxdatavalid_out                    		=> rxdatavalid_out,                    
	rxheader_out                       		=> rxheader_out,                       
	rxheadervalid_out                  		=> rxheadervalid_out,                  
	rxpmaresetdone_out                 		=> rxpmaresetdone_out,                 
	rxprgdivresetdone_out              		=> rxprgdivresetdone_out,              
	rxstartofseq_out                   		=> rxstartofseq_out,                   
	txpmaresetdone_out                 		=> txpmaresetdone_out,                 
	txprgdivresetdone_out              		=> txprgdivresetdone_out         
	      
	  );
end generate;


--***********************************************************************************************
--
--			GTH Ultrascale+ 15.66 Gb/s    
--
SERDES_16G_GTH:if throughput = "15.66"  and technology = "GTH" generate
	i1:SlinkRocket_SERDES_15G66_GTH_wrapper
	  PORT MAP (
	gtwiz_userclk_tx_active_in         		=> gtwiz_userclk_tx_active_in ,                                   
	gtwiz_userclk_rx_active_in         		=> gtwiz_userclk_rx_active_in ,                                   
	txusrclk_in								=> txusrclk_in                ,                                   
	txusrclk2_in							=> txusrclk2_in               ,                                   
	txusrclk4_in							=> txusrclk4_in               ,                                   
	rxusrclk_in  							=> rxusrclk_in                ,                                   
	rxusrclk2_in 							=> rxusrclk2_in               ,                                   
	rxusrclk4_in 							=> rxusrclk4_in               ,                                   
	rxoutclk_out							=> rxoutclk_out               ,                                   
	txoutclk_out							=> txoutclk_out               ,                   
	TX_userclk_out(0)                 		=> TX_userclk_out            ,                                   
	RX_userclk_out(0)                 		=> RX_userclk_out            ,   
	
	gtwiz_reset_clk_freerun_in         		=> gtwiz_reset_clk_freerun_in,         
	gtwiz_reset_all_in                 		=> gtwiz_reset_all_in,                 
	gtwiz_reset_tx_pll_and_datapath_in 		=> gtwiz_reset_tx_pll_and_datapath_in, 
	gtwiz_reset_tx_datapath_in         		=> gtwiz_reset_tx_datapath_in,         
	gtwiz_reset_rx_pll_and_datapath_in 		=> gtwiz_reset_rx_pll_and_datapath_in, 
	gtwiz_reset_rx_datapath_in         		=> gtwiz_reset_rx_datapath_in,         
	gtwiz_reset_qpll0lock_in           		=> gtwiz_reset_qpll0lock_in,           
	gtwiz_reset_rx_cdr_stable_out      		=> gtwiz_reset_rx_cdr_stable_out,      
	gtwiz_reset_tx_done_out            		=> gtwiz_reset_tx_done_out,            
	gtwiz_reset_rx_done_out            		=> gtwiz_reset_rx_done_out,            
	gtwiz_reset_qpll0reset_out         		=> gtwiz_reset_qpll0reset_out,         
	gtwiz_userdata_tx_in               		=> gtwiz_userdata_tx_in,               
	gtwiz_userdata_rx_out              		=> gtwiz_userdata_rx_out,              
	drpaddr_in                         		=> drpaddr_in,                         
	drpclk_in                          		=> drpclk_in ,                         
	drpdi_in                           		=> drpdi_in  ,                         
	drpen_in                           		=> drpen_in  ,                         
	drpwe_in                           		=> drpwe_in  ,                         
	gthrxn_in                          		=> gt_rxn_in ,                         
	gthrxp_in                          		=> gt_rxp_in ,                         
	loopback_in                        		=> loopback_in,    
	rxoutclksel_in                          => rxoutclksel_in,
    rxcdrhold_in                            => rxcdrhold_in,                 
	qpll0clk_in                        		=> qpll0clk_in     ,                   
	qpll0refclk_in                     		=> qpll0refclk_in  ,                   
	qpll1clk_in                        		=> qpll1clk_in     ,                   
	qpll1refclk_in                     		=> qpll1refclk_in  ,                   
	rxcdrphdone_out 				   		=> rxcdrphdone_out,                    
	rxgearboxslip_in                   		=> rxgearboxslip_in,                   
	txdiffctrl_in                      		=> txdiffctrl_in,                      
	txheader_in                        		=> txheader_in,                        
	txpolarity_in                      		=> txpolarity_in,                      
	rxpolarity_in                      		=> rxpolarity_in,                      
	txpostcursor_in                    		=> txpostcursor_in,                    
	txprecursor_in                     		=> txprecursor_in,                     
	txsequence_in                      		=> txsequence_in,                      
	drpdo_out                          		=> drpdo_out,                          
	drprdy_out                         		=> drprdy_out,                         
	gtpowergood_out                    		=> gtpowergood_out,                    
	gthtxn_out                         		=> gt_txn_out ,                        
	gthtxp_out                         		=> gt_txp_out ,                        
	rxdatavalid_out                    		=> rxdatavalid_out,                    
	rxheader_out                       		=> rxheader_out,                       
	rxheadervalid_out                  		=> rxheadervalid_out,                  
	rxpmaresetdone_out                 		=> rxpmaresetdone_out,                 
	rxprgdivresetdone_out              		=> rxprgdivresetdone_out,              
	rxstartofseq_out                   		=> rxstartofseq_out,                   
	txpmaresetdone_out                 		=> txpmaresetdone_out,                 
	txprgdivresetdone_out              		=> txprgdivresetdone_out   
	  );
end generate;


--***********************************************************************************************
--
--			GTY Ultrascale+ 15.66 Gb/s    
--
SERDES_16G_GTY:if throughput = "15.66" and technology = "GTY" generate
	i1:SlinkRocket_SERDES_15G66_GTY_wrapper
	  PORT MAP (
    gtwiz_userclk_tx_active_in         		=> gtwiz_userclk_tx_active_in ,                                   
    gtwiz_userclk_rx_active_in         		=> gtwiz_userclk_rx_active_in ,                                   
    rxusrclk_in                        		=> rxusrclk_in                ,                                   
    rxusrclk2_in                       		=> rxusrclk2_in               ,                                   
    rxusrclk4_in                       		=> rxusrclk4_in               ,                                   
    txusrclk_in                        		=> txusrclk_in                ,                                   
    txusrclk2_in                       		=> txusrclk2_in               ,                                   
    txusrclk4_in                       		=> txusrclk4_in               ,                                   
    rxoutclk_out                       		=> rxoutclk_out               ,                                   
    txoutclk_out                       		=> txoutclk_out               ,                                   
	TX_userclk_out(0)                       => TX_userclk_out              ,
	RX_userclk_out(0)                       => RX_userclk_out              ,																			   
    gtwiz_reset_clk_freerun_in         		=> gtwiz_reset_clk_freerun_in,         
    gtwiz_reset_all_in                 		=> gtwiz_reset_all_in,                 
    gtwiz_reset_tx_pll_and_datapath_in 		=> gtwiz_reset_tx_pll_and_datapath_in, 
    gtwiz_reset_tx_datapath_in         		=> gtwiz_reset_tx_datapath_in,         
    gtwiz_reset_rx_pll_and_datapath_in 		=> gtwiz_reset_rx_pll_and_datapath_in, 
    gtwiz_reset_rx_datapath_in         		=> gtwiz_reset_rx_datapath_in,         
    gtwiz_reset_qpll0lock_in           		=> gtwiz_reset_qpll0lock_in,           
    gtwiz_reset_rx_cdr_stable_out      		=> gtwiz_reset_rx_cdr_stable_out,      
    gtwiz_reset_tx_done_out            		=> gtwiz_reset_tx_done_out,            
    gtwiz_reset_rx_done_out            		=> gtwiz_reset_rx_done_out,            
    gtwiz_reset_qpll0reset_out         		=> gtwiz_reset_qpll0reset_out,         
    gtwiz_userdata_tx_in               		=> gtwiz_userdata_tx_in,               
    gtwiz_userdata_rx_out              		=> gtwiz_userdata_rx_out,              
    drpaddr_in                         		=> drpaddr_in,                         
    drpclk_in                          		=> drpclk_in ,                         
    drpdi_in                           		=> drpdi_in  ,                         
    drpen_in                           		=> drpen_in  ,                         
    drpwe_in                           		=> drpwe_in  ,                         
    gtyrxn_in                          		=> gt_rxn_in,                          
    gtyrxp_in                          		=> gt_rxp_in,                          
    loopback_in                        		=> loopback_in,  
	rxoutclksel_in                          => rxoutclksel_in,
    rxcdrhold_in                            => rxcdrhold_in,                          
    qpll0clk_in                        		=> qpll0clk_in    ,                    
    qpll0refclk_in                     		=> qpll0refclk_in ,                    
    qpll1clk_in                        		=> qpll1clk_in    ,                    
    qpll1refclk_in                     		=> qpll1refclk_in ,                    
    rxgearboxslip_in                   		=> rxgearboxslip_in,                   
    rxpolarity_in                      		=> rxpolarity_in,                      
    txdiffctrl_in                      		=> txdiffctrl_in,                      
    txheader_in                        		=> txheader_in,                        
    txpolarity_in                      		=> txpolarity_in,                      
    txpostcursor_in                    		=> txpostcursor_in,                    
    txprecursor_in                     		=> txprecursor_in,                     
    txsequence_in                      		=> txsequence_in,                      
    drpdo_out                          		=> drpdo_out,                          
    drprdy_out                         		=> drprdy_out,                         
    gtpowergood_out                    		=> gtpowergood_out,                    
    gtytxn_out                         		=> gt_txn_out,                         
    gtytxp_out                         		=> gt_txp_out,                         
    rxcdrphdone_out                    		=> rxcdrphdone_out,                    
    rxdatavalid_out                    		=> rxdatavalid_out,                    
    rxheader_out                       		=> rxheader_out,                       
    rxheadervalid_out                  		=> rxheadervalid_out,                  
    rxpmaresetdone_out                 		=> rxpmaresetdone_out,                 
    rxprgdivresetdone_out              		=> rxprgdivresetdone_out,              
    rxstartofseq_out                   		=> rxstartofseq_out,                   
    txpmaresetdone_out                 		=> txpmaresetdone_out,                 
    txprgdivresetdone_out              		=> txprgdivresetdone_out               
	  );
end generate;

--***********************************************************************************************
--
--			GTY Ultrascale+ 25.78125 Gb/s   
--
SERDES_25G_GTY:if throughput = "25.78125"  and technology = "GTY" generate
	i1:SlinkRocket_SERDES_25G78125_GTY_wrapper
	  PORT MAP (
	gtwiz_userclk_tx_active_in         		=> gtwiz_userclk_tx_active_in  ,                                   
    gtwiz_userclk_rx_active_in         		=> gtwiz_userclk_rx_active_in  ,                                   
    rxusrclk_in                        		=> rxusrclk_in                 ,                                   
    rxusrclk2_in                       		=> rxusrclk2_in                ,                                   
    txusrclk_in                        		=> txusrclk_in                 ,                                   
    txusrclk2_in                       		=> txusrclk2_in                ,                                   
    rxoutclk_out                       		=> rxoutclk_out                ,                                   
    txoutclk_out                       		=> txoutclk_out                ,                                   
	TX_userclk_out(0)						=> TX_userclk_out 				,
	RX_userclk_out(0)                       => RX_userclk_out 				,
    gtwiz_reset_clk_freerun_in         		=> gtwiz_reset_clk_freerun_in,         
    gtwiz_reset_all_in                 		=> gtwiz_reset_all_in,                 
    gtwiz_reset_tx_pll_and_datapath_in 		=> gtwiz_reset_tx_pll_and_datapath_in, 
    gtwiz_reset_tx_datapath_in         		=> gtwiz_reset_tx_datapath_in,         
    gtwiz_reset_rx_pll_and_datapath_in 		=> gtwiz_reset_rx_pll_and_datapath_in, 
    gtwiz_reset_rx_datapath_in         		=> gtwiz_reset_rx_datapath_in ,        
    gtwiz_reset_qpll0lock_in           		=> gtwiz_reset_qpll0lock_in,           
    gtwiz_reset_rx_cdr_stable_out      		=> gtwiz_reset_rx_cdr_stable_out,      
    gtwiz_reset_tx_done_out            		=> gtwiz_reset_tx_done_out,            
    gtwiz_reset_rx_done_out            		=> gtwiz_reset_rx_done_out,            
    gtwiz_reset_qpll0reset_out         		=> gtwiz_reset_qpll0reset_out,         
    gtwiz_userdata_tx_in               		=> gtwiz_userdata_tx_in,               
    gtwiz_userdata_rx_out              		=> gtwiz_userdata_rx_out,              
    drpaddr_in                         		=> drpaddr_in ,                        
    drpclk_in                          		=> drpclk_in  ,                        
    drpdi_in                           		=> drpdi_in   ,                        
    drpen_in                           		=> drpen_in   ,                        
    drpwe_in                           		=> drpwe_in   ,                        
    gtyrxn_in                          		=> gt_rxn_in ,                         
    gtyrxp_in                          		=> gt_rxp_in ,                         
    loopback_in                        		=> loopback_in,  
	rxoutclksel_in                          => rxoutclksel_in,
    rxcdrhold_in                            => rxcdrhold_in,                          
    qpll0clk_in                        		=> qpll0clk_in     ,                   
    qpll0refclk_in                     		=> qpll0refclk_in  ,                   
    qpll1clk_in                        		=> qpll1clk_in     ,                   
    qpll1refclk_in                     		=> qpll1refclk_in  ,                   
    rxgearboxslip_in                   		=> rxgearboxslip_in,                   
    rxpolarity_in                      		=> rxpolarity_in,                      
    txdiffctrl_in                      		=> txdiffctrl_in,                      
    txheader_in                        		=> txheader_in,                        
    txpolarity_in                      		=> txpolarity_in,                      
    txpostcursor_in                    		=> txpostcursor_in,                    
    txprecursor_in                     		=> txprecursor_in,                     
    txsequence_in                      		=> txsequence_in,                      
    drpdo_out                          		=> drpdo_out,                          
    drprdy_out                         		=> drprdy_out,                         
    gtpowergood_out                    		=> gtpowergood_out,                    
    gtytxn_out                         		=> gt_txn_out ,                        
    gtytxp_out                         		=> gt_txp_out ,                        
    rxcdrphdone_out                    		=> rxcdrphdone_out,                    
    rxdatavalid_out                    		=> rxdatavalid_out,                    
    rxheader_out                       		=> rxheader_out,                       
    rxheadervalid_out                  		=> rxheadervalid_out,                  
    rxpmaresetdone_out                 		=> rxpmaresetdone_out,                 
    rxprgdivresetdone_out              		=> rxprgdivresetdone_out,              
    rxstartofseq_out                   		=> rxstartofseq_out,                   
    txpmaresetdone_out                 		=> txpmaresetdone_out,                 
    txprgdivresetdone_out              		=> txprgdivresetdone_out               
	  );
end generate;

end Behavioral;