----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.11.2017 10:42:34
-- Design Name: 
-- Module Name: Serdes_wrapper_inst - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 		This file is used to setup the SERDES
-- 		contains the logic to bitslip the word to align it 
-- 		it swaps the 2 64b word (SERDES has a128 b word interface)
--		Has soon as the word is aligned and detects that the other side of the link is on the same behaviour , it send  INPUT DATA (which is idle or pakcet)
--		The link is keep in LINKUP state if at least an Idle word is seen each 512 words ( which is the double of a max packet size
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all; 
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;




entity Serdes_wrapper_snd_inst is
 Generic (  txpolarity_in					        : std_logic := '0';
	        rxpolarity_in					        : std_logic := '0'; 
		    Clock_source							: string := "Master";
				--possible choices are Slave or Master
            throughput								: string := "15.66";
				--possible choices are  15.66 or 25.78125
		    ref_clock								: string := "156.25";
				--possible choices are  156.25  or   322.265625 
			technology								: string := "GTY"
				-- possible choices are GTY or GTH
				); 
  Port (
 		txdiffctrl_in 									: in std_logic_vector(4 downto 0) := "11000";
		txpostcursor_in 								: in std_logic_vector(4 downto 0) := "10100";
		txprecursor_in									: in std_logic_vector(4 downto 0) := "00000";
		Srds_loopback_in								: in std_logic;
        SERDES_status									: out std_logic_vector(63 downto 0);
  -- data bus
		userclk_tx_srcclk_out					        : out std_logic;						-- FRAME to send over SERDES
		tx_header									    : in std_logic_vector(5 downto 0);		-- bit control of the 64/66 encoding
		tx_data										    : in std_logic_vector(127 downto 0);	-- data word
		
		userclk_rx_srcclk_out					        : out std_logic;						-- FRAME received over SERDES
		rx_data_valid								    : out std_logic_vector(1 downto 0);		-- valid data word
		rx_header									    : out std_logic_vector(5 downto 0);		-- header bit (64/66 encoding)
		rx_header_valid							        : out std_logic_vector(1 downto 0);		-- valid header bits
		rx_data										    : out std_logic_vector(127 downto 0);	-- data words (2 x 64 bit)
		rx_SOS										    : out std_logic_vector(1 downto 0);		-- Start Of Sequence

		SERDES_ready									: out std_logic;
  --   Gb serdes interface
  		clk_freerun_in								    : in std_logic;							-- reference clocks QPLL signals
		
  --  Clock source and destination
		--Clock control to/from  SERDES/logic
		-- These signals are from the serdes to be used to generate the master clock
		gtM_Clock_Src_TX_out							: out std_logic; 
		gtx_Reset_TX_clock_out							: out std_logic;  
		gtx_userclk_tx_active_in						: in std_logic; 
		gtx_userclk_tx_usrclk_in						: in std_logic;
		gtx_userclk_tx_usrclk2_in						: in std_logic;
		gtx_userclk_tx_usrclk4_in						: in std_logic; 
		
		--Clock Control to/from MASTER 
		-- these signals are source to generate the master clock of the serdes
		gtM_Clock_Src_TX_in								: in std_logic; 
		gtM_Reset_TX_clock_in							: in std_logic_vector(3 downto 0);--active HIGH  
		gtM_userclk_tx_active_out						: out std_logic; 
		gtM_userclk_rx_active_out						: out std_logic; 
		gtM_userclk_tx_usrclk_out						: out std_logic;
		gtM_userclk_tx_usrclk2_out						: out std_logic;
		gtM_userclk_tx_usrclk4_out						: out std_logic; 
		
  -- QPLL 		 
		qpll_lock_in									: IN STD_LOGIC;
		qpll_reset_out									: OUT STD_LOGIC;
		qpll_clk_in										: IN STD_LOGIC;
		qpll_refclk_in									: IN STD_LOGIC;
  -- High speed link	
		gt_rxn_in                          	            : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);		-- SERDES connection 
		gt_rxp_in                          	            : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);	
		gt_txn_out                         	            : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
		gt_txp_out                         	            : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
		 
		Rst_hrd_sim										: in std_logic
  );
end Serdes_wrapper_snd_inst;

--*///////////////////////////////////////////////////////////////////////////////
--*////////////////////////   Behavioral        //////////////////////////////////
--*///////////////////////////////////////////////////////////////////////////////
architecture Behavioral of Serdes_wrapper_snd_inst is

signal counter_slip_done								            : std_logic_vector(15 downto 0) := x"0026";
signal Shift_counter_max											: std_logic_vector(6 downto 0) := "1000000";--64
signal Shift_inv_counter_max										: std_logic_vector(4 downto 0) := "10000";--16

COMPONENT Serdes_wrapper_select  
 Generic ( throughput								: string := "15.66";
				--possible choices are  15.66 or 25.78125
		    ref_clock								: string := "156.25";
				--possible choices are  156.25  or   322.265625 
			technology								: string := "GTY"
				-- possible choices are GTY or GTH
		);
  PORT (
 	gtwiz_userclk_tx_active_in 			: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
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
END COMPONENT;

signal gtx_Clock_Src_RX								: std_logic;
signal gtx_Reset_RX_clock							: std_logic;
signal gtx_userclk_rx_usrclk						: std_logic;
signal gtx_userclk_rx_usrclk2						: std_logic;
signal gtx_userclk_rx_usrclk4						: std_logic;
signal gtx_userclk_rx_active						: std_logic;

signal loopback_in									: std_logic_vector(2 downto 0);
signal rxoutclksel_in								: STD_LOGIC_VECTOR(2 DOWNTO 0);
signal rxcdrhold_in									: STD_LOGIC;

COMPONENT SERDES_GTx_userclk_tx is
	 generic(
		P_CONTENTS                     		: integer:= 0;
		P_FREQ_RATIO_SOURCE_TO_USRCLK  		: integer:= 1;
		P_FREQ_RATIO_USRCLK_TO_USRCLK2 		: integer:= 2
	 );
	 Port ( 
		gtwiz_userclk_tx_srcclk_in  		: in  std_logic;	
		gtwiz_userclk_tx_reset_in   		: in  std_logic;	
		gtwiz_userclk_tx_usrclk_out 		: out std_logic;	
		gtwiz_userclk_tx_usrclk2_out		: out std_logic;	
		gtwiz_userclk_tx_usrclk4_out		: out std_logic;	
		gtwiz_userclk_tx_active_out			: out std_logic 
 );
end COMPONENT;
  
COMPONENT SERDES_GTx_userclk_rx is
	 generic(
		P_CONTENTS                     		: integer:= 0;
		P_FREQ_RATIO_SOURCE_TO_USRCLK  		: integer:= 1;
		P_FREQ_RATIO_USRCLK_TO_USRCLK2 		: integer:= 2
	 );
	 Port ( 
		gtwiz_userclk_rx_srcclk_in  		: in  std_logic;	
		gtwiz_userclk_rx_reset_in   		: in  std_logic;	
		gtwiz_userclk_rx_usrclk_out 		: out std_logic;	
		gtwiz_userclk_rx_usrclk2_out		: out std_logic;	
		gtwiz_userclk_rx_usrclk4_out		: out std_logic;	
		gtwiz_userclk_rx_active_out			: out std_logic 
	 );
end COMPONENT;
 
signal qpll_reset_cell					: std_logic;

COMPONENT resync_v4 is
port (
	aresetn				: in std_logic;
	clocki				: in std_logic;	
	input				: in std_logic;
	clocko				: in std_logic;
	output				: out std_logic
	);
end COMPONENT; 

COMPONENT resetn_resync is
port (
	aresetn				: in std_logic;
	clock				: in std_logic; 
	Resetn_sync			: out std_logic;
	Resetp_sync			: out std_logic
	);
end COMPONENT;

component resetp_resync is
port (
	aresetp				: in std_logic;
	clock				: in std_logic; 
	Resetp_sync			: out std_logic
	);
end component;
 

component resync_sig_gen is 
port ( 
	clocko				: in std_logic;
	input				: in std_logic;
	output				: out std_logic
	);
end component;

type Align_serdes_state is (	ST_Start,
								ST_Reset_counters,
								ST_Check_pattern,
								ST_Check_valid,
								ST_Check_unvalid,
								ST_slip_state,
								ST_wait_slip_done,
								ST_send_idle, 
								ST_wait_Idle_from_other_side,
								ST_link_up 
							);
signal Align_serdes:Align_serdes_state;
attribute fsm_encoding : string;
attribute fsm_encoding of Align_serdes : signal is "one_hot";
 
component  reset_serdes is
 Generic (
       P_FREERUN_FREQUENCY                : integer := 100;
       P_TX_TIMER_DURATION_US             : integer := 30000;
       P_RX_TIMER_DURATION_US             : integer := 130000
 );
 Port ( 
       reset_free_run                     : in std_logic;
       clock_free_run                     : in std_logic;
         
       tx_init_done                    	  : in std_logic;
       rx_init_done                    	  : in std_logic;
       rx_data_good                       : in std_logic;
       
       reset_all_out                      : out std_logic;
       reset_rx_out                       : out std_logic;
       init_done_out                      : out std_logic;
       retry_cntr                         : out std_logic_vector(3 downto 0)
       
         );
end component;
   
signal TX_userclk_cell			 				                    : std_logic;
signal RX_userclk_cell			 				                    : std_logic;
				 
signal gtpowergood_out								                : std_logic;
		   
signal data_path_rx_reset					 	              	    : std_logic := '0';
signal data_path_rx_reset_cell				 	              	    : std_logic := '0'; 
  
signal rxcdrphdone_out 												: std_logic_vector(0 DOWNTO 0);
 
signal gtwiz_reset_tx_done_out              	                    : std_logic := '0'; 
signal gtwiz_reset_rx_cdr_stable_out        	                    : std_logic := '0'; 

		
signal test_shift													: std_logic;				               				  	
signal Shift_counter												: std_logic_vector(6 downto 0);
signal Shift_inv_counter											: std_logic_vector(4 downto 0);
 
signal slip_done													: std_logic; 
signal Init_done													: std_logic;  
signal send_idle                                                    : std_logic;
signal send_idle_sec                                                : std_logic;
signal send_idle_cell                                               : std_logic;

signal send_idle_sync                                               : std_logic;
signal Idle_present        											: std_logic; 
signal Link_locked 													: std_logic; 
signal Link_locked_sync   											: std_logic; 

signal STATE_link													: std_logic; 
signal LINK_UP														: std_logic := '1'; 
signal LINK_DOWN													: std_logic := '0';  
signal retry_init													: std_logic_vector(3 downto 0); 

signal pattern_found												: std_logic; 

signal rxgearboxslip									            : std_logic := '0';
signal rxgearboxslip_sync								            : std_logic;
signal wait_counter 									            : std_logic_vector(15 downto 0) := x"0000";
signal time_wait_counter 								            : std_logic_vector(15 downto 0) := x"0000";
signal flip_words													: std_logic := '0'; 
 
signal status											            : std_logic_vector(63 downto 0) := x"0000000000000000";

-- status RX and TX  reset
signal reset_rx_done								           		: std_logic; 
signal reset_rx_done_resync									        : std_logic; 
signal reset_tx_done									            : std_logic;  
signal rx_init_done_reg									            : std_logic; 
   
signal txpolarity_sync												: std_logic;
signal rxpolarity_sync												: std_logic;
   
signal DRP_clock	  											    : std_logic;
   
signal txpmaresetdone 												: std_logic;
signal txprgdivresetdone 											: std_logic;
signal rxpmaresetdone 												: std_logic;
signal rxprgdivresetdone 											: std_logic; 
signal Reset_TX_clock_cell 											: std_logic;  
signal Reset_RX_clock_cell 											: std_logic;  

signal tx_clock_ready												: std_logic;
signal rx_clock_ready												: std_logic; 
signal rx_clock_ready_sync  										: std_logic; 
  
--TX data path to SERDES  
signal tx_data_reg													: std_logic_vector(127 downto 0);
signal tx_hd_reg													: std_logic_vector(5 downto 0);
  
signal Reset_sync_logic											    : std_logic;
signal rx_usrclk2_not_readyp										: std_logic := '0';
signal rx_usrclk2_not_readyp_resync									: std_logic := '0'; 
 
signal gtwiz_reset_all_cell 										: std_logic := '0'; 
signal reset_all_logic												: std_logic := '0'; 
  
signal rx_src_data						               				: std_logic_vector(127 downto 0); 
signal rx_scr_data_valid_cell										: std_logic_vector(1 DOWNTO 0);
signal rx_scr_header_cell											: std_logic_vector(5 DOWNTO 0);
signal rx_scr_header_valid_cell										: std_logic_vector(1 DOWNTO 0); 
signal rx_scr_SOS													: std_logic_vector(1 DOWNTO 0);

signal rx_data_valid_rg								                : std_logic_vector(1 downto 0);
signal rx_header_rg									                : std_logic_vector(5 downto 0);
signal rx_header_valid_rg							                : std_logic_vector(1 downto 0);	
signal rx_data_reg										            : std_logic_vector(127 downto 0);		

signal check_link_counter											: std_logic_vector(15 downto 0); 
signal reset_check_link_counter										: std_logic; 
signal check_pattern_counter										: std_logic_vector(1 downto 0); 
signal check_code_counter											: std_logic_vector(15 downto 0); 
signal Incr_check_code_counter										: std_logic;
signal link_lost													: std_logic;
  
attribute mark_debug : string;

-- attribute mark_debug of Link_locked		     : signal is "true"; 
-- attribute mark_debug of rx_data_reg 		 : signal is "true"; 
-- attribute mark_debug of tx_data_reg 		 : signal is "true"; 
-- attribute mark_debug of Align_serdes		 : signal is "true"; 
-- attribute mark_debug of link_lost		     : signal is "true"; 
-- attribute mark_debug of Shift_counter		 : signal is "true"; 
-- attribute mark_debug of Shift_inv_counter    : signal is "true"; 
  

--#############################################################################
-- Code start here
--#############################################################################
begin
 
 -- DRP clock use a 100 MHz free runing clock from pll
DRP_clock 			<= clk_freerun_in;
qpll_reset_out		<= qpll_reset_cell;

resync_sig_i14:resync_sig_gen                                          
    port map(                  
        clocko               => TX_userclk_cell      , 
        input                => Link_locked            , 
        output               => Link_locked_sync         
        );  
 
-- send 2 idle to end the sync
-- Because at the reception (when GTH is used) it is received on 2 x 64 bit which can 
-- be seen on 2 following 127 bit word . With 2 Idles of 127 bit we are sure that we receive
-- at least a 127bit idle word at reception
send_idle_cell  <= send_idle or send_idle_sec;
 
resync_pulse_i15:resync_v4  
    port map(
        aresetn               => '1',
        clocki               => RX_userclk_cell,  
        input                => send_idle_cell,
        clocko               => TX_userclk_cell,
        output               => Send_Idle_sync
        ); 
        
--/////////////////////////////////////////////////////////////////////////////////////////              
-- Here is a mux used to send a predefined pattern (over teh SERDES) to help the other side of the link to sync
-- When sync is done, this mux will send the data from SR                              		 	    		 
process(TX_userclk_cell)
begin
	if rising_edge(TX_userclk_cell) then
	
		if Link_locked_sync = '0' and Send_Idle_sync = '0' then
			 tx_data_reg 		<= x"07aa55aa55aa55aa07aa55aa55aa55aa";
			 tx_hd_reg			<= "001001";
		else
			tx_data_reg 		<= tx_data;
			tx_hd_reg			<= tx_header;
		end if;
	end if;
end process;   	
  
--/////////////////////////////////////////////////////////////////////////////////
-- Clock managment

Master_clock:if Clock_source = "Master"  generate
	
	Reset_TX_clock_cell					<= '0' when gtM_Reset_TX_clock_in = "0000"  else '1';
          	

    gtwiz_userclk_tx_inst:SERDES_GTx_userclk_tx 
        generic map(
            P_CONTENTS                     		=> 0,
            P_FREQ_RATIO_SOURCE_TO_USRCLK  		=> 1,
            P_FREQ_RATIO_USRCLK_TO_USRCLK2 		=> 2
         )
         Port Map( 
            gtwiz_userclk_tx_srcclk_in  		=> gtM_Clock_Src_TX_in,	
            gtwiz_userclk_tx_reset_in   		=> Reset_TX_clock_cell,	
            gtwiz_userclk_tx_usrclk_out 		=> gtM_userclk_tx_usrclk_out,	
            gtwiz_userclk_tx_usrclk2_out		=> gtM_userclk_tx_usrclk2_out,	
            gtwiz_userclk_tx_usrclk4_out		=> gtM_userclk_tx_usrclk4_out,	
            gtwiz_userclk_tx_active_out			=> gtM_userclk_tx_active_out 
     );

end generate;

Reset_RX_clock_cell					<= '0' when gtx_Reset_RX_clock  = '0' else '1';
 
gtwiz_userclk_rx_inst:SERDES_GTx_userclk_rx  
    generic map(
        P_CONTENTS                     		=> 0,
        P_FREQ_RATIO_SOURCE_TO_USRCLK  		=> 1,
        P_FREQ_RATIO_USRCLK_TO_USRCLK2 		=> 2
     )
    Port Map( 
        gtwiz_userclk_rx_srcclk_in  		=> gtx_Clock_Src_RX,
        gtwiz_userclk_rx_reset_in   		=> Reset_RX_clock_cell,
        gtwiz_userclk_rx_usrclk_out 		=> gtx_userclk_rx_usrclk,
        gtwiz_userclk_rx_usrclk2_out		=> gtx_userclk_rx_usrclk2,
        gtwiz_userclk_rx_usrclk4_out		=> gtx_userclk_rx_usrclk4,
        gtwiz_userclk_rx_active_out			=> gtx_userclk_rx_active 
     );

gtM_userclk_rx_active_out   <= gtx_userclk_rx_active;

--///////////////////////////////////////////////////////////////////////////////// 
--		 SERDES  reset

gtx_Reset_TX_clock_out 					<= '0' when txpmaresetdone = '1' and txprgdivresetdone = '1' else '1';
gtx_Reset_RX_clock  					<= '0' when rxpmaresetdone = '1' and rxprgdivresetdone = '1' else '1';
 
userclk_tx_srcclk_out					<= TX_userclk_cell;-- these clocks are half(usrclk2_in) for GTH and usrclk2_in for the GTY
userclk_rx_srcclk_out					<= RX_userclk_cell;
	
gtwiz_reset_all_cell    				<= reset_all_logic or  Rst_hrd_sim ; 
 
--****************************
-- Settings signals to do a loopback Near-PCS when a SlinkRcoket is not used
--							Normal									loopback Near-end_PCS
loopback_in						<=  "000" when Srds_loopback_in = '0' else "001";
--							RXOUTCLKSEL= PROGDIVCLK											
rxoutclksel_in					<=  "101" ;--when Srds_loopback_in = '0' else "001";
--																	 RXCDRHOLD = 1
rxcdrhold_in					<=  '0' when Srds_loopback_in = '0' else '1';

--/////////////////////////////////////////////////////////////////////////////////
-- resync signals
txpolarity_i1:resync_sig_gen   
port map( 
	clocko			=> TX_userclk_cell,
	input			=> txpolarity_in,
	output			=> txpolarity_sync 
	);
	
rxpolarity_i1:resync_sig_gen   
port map( 
	clocko			=> RX_userclk_cell,
	input			=> rxpolarity_in,
	output			=> rxpolarity_sync 
	);
	
rxgearboxslip_sync	<= rxgearboxslip;
	
--///////////////////////////////////////////////////////////////////////////////// 
--		 SERDES  instantiation

serdes_i1:Serdes_wrapper_select
Generic map( 	
				throughput								=> throughput,
				ref_clock								=> ref_clock,
				technology								=> technology
		) 
  PORT MAP(
	gtwiz_userclk_tx_active_in(0)			=> gtx_userclk_tx_active_in     ,      
	gtwiz_userclk_rx_active_in(0)			=> gtx_userclk_rx_active     ,      
	rxusrclk_in(0)            				=> gtx_userclk_rx_usrclk     	,   
	rxusrclk2_in(0)           				=> gtx_userclk_rx_usrclk2    	,  
	rxusrclk4_in(0)           				=> gtx_userclk_rx_usrclk4	    ,  
	txusrclk_in(0)            				=> gtx_userclk_tx_usrclk_in     ,      
	txusrclk2_in(0)            				=> gtx_userclk_tx_usrclk2_in    ,     
	txusrclk4_in(0)            				=> gtx_userclk_tx_usrclk4_in    ,     
	rxoutclk_out(0)             			=> gtx_Clock_Src_RX         ,          
	txoutclk_out(0)            				=> gtM_Clock_Src_TX_out         ,          
	TX_userclk_out	                 		=> TX_userclk_cell              ,                       
    RX_userclk_out	                 		=> RX_userclk_cell              ,              
	 
	gtwiz_reset_clk_freerun_in(0)      		=> clk_freerun_in               , 
	gtwiz_reset_all_in(0)               	=> gtwiz_reset_all_cell         , 
	gtwiz_reset_tx_pll_and_datapath_in(0)	=> '0'                          , 
	gtwiz_reset_tx_datapath_in(0)       	=> '0'                          , 
	gtwiz_reset_rx_pll_and_datapath_in(0)	=> '0'                          , 
	gtwiz_reset_rx_datapath_in(0)       	=> data_path_rx_reset           , 
	gtwiz_reset_rx_cdr_stable_out(0)   		=> gtwiz_reset_rx_cdr_stable_out, 
	gtwiz_reset_tx_done_out(0)         		=> reset_tx_done                , 
	gtwiz_reset_rx_done_out(0)         		=> reset_rx_done                , 
	
	gtwiz_userdata_tx_in               		=> tx_data_reg            , 
	txheader_in                        		=> tx_hd_reg                  , 
	gtwiz_userdata_rx_out              		=> rx_src_data          , 
	rxstartofseq_out                   		=> rx_scr_SOS                   , 
	rxdatavalid_out                    		=> rx_scr_data_valid_cell       , 
	rxheader_out                       		=> rx_scr_header_cell           , 
	rxheadervalid_out                  		=> rx_scr_header_valid_cell     , 
	
	drpaddr_in                         		=> "0000000000"	                , 
	drpclk_in(0)                       		=> DRP_clock               , 
	drpdi_in                           		=> x"0000"                      , 
	drpen_in(0)                        		=> '0'                          , 
	drpwe_in(0)                        		=> '0'                          , 
	-- drpdo_out                          		=>                          , 
	-- drprdy_out(0)                    		=>                          , 
	
	gt_rxn_in                          		=> gt_rxn_in                    , 
	gt_rxp_in                          		=> gt_rxp_in                    , 
	gt_txn_out                         		=> gt_txn_out                   , 
	gt_txp_out                         		=> gt_txp_out                   , 
	
	loopback_in                        		=> loopback_in                  , 
    rxoutclksel_in                          => rxoutclksel_in               ,
    rxcdrhold_in(0)                         => rxcdrhold_in                 ,
	gtwiz_reset_qpll0reset_out(0)      		=> qpll_reset_cell              , 
	gtwiz_reset_qpll0lock_in(0)        		=> qpll_lock_in                 , 
	qpll0clk_in(0)                     		=> qpll_clk_in                  , 
	qpll0refclk_in(0)                  		=> qpll_refclk_in               , 
	qpll1clk_in(0)                    		=> '0'	                        , 
	qpll1refclk_in                     		=> "0"	                        , 
	
	rxcdrphdone_out 				   		=> rxcdrphdone_out              , 
	rxgearboxslip_in(0)                		=> rxgearboxslip_sync                , 
	txdiffctrl_in                      		=> txdiffctrl_in                , 
	txpolarity_in(0)                  		=> txpolarity_sync                , 
	rxpolarity_in(0)                  		=> rxpolarity_sync                , 
	txpostcursor_in                    		=> txpostcursor_in              , 
	txprecursor_in                     		=> txprecursor_in               , 
	txsequence_in                      		=> "0000000"                    , 
	gtpowergood_out(0)                 		=> gtpowergood_out              , 
	rxpmaresetdone_out(0)              		=> rxpmaresetdone               , 
	rxprgdivresetdone_out(0)           		=> rxprgdivresetdone            , 
	txpmaresetdone_out(0)              		=> txpmaresetdone               , 
	txprgdivresetdone_out(0)           		=> txprgdivresetdone  
       			  
  );                                                                                          

tx_clock_ready      <= gtx_userclk_tx_active_in;                                                                                    
  
status(31)		<= '1' when Align_serdes = ST_link_up else '0';
status(30)		<= '1' when Align_serdes = ST_wait_Idle_from_other_side else '0';  
status(29)		<= '1' when Align_serdes = ST_send_idle else '0';  
status(28)		<= '0' ;--when Align_serdes =  else '0';  
status(27)		<= '1' when Align_serdes = ST_wait_slip_done else '0';  
status(26)		<= '1' when Align_serdes = ST_slip_state else '0';  
status(25)		<= '1' when Align_serdes = ST_check_pattern  else '0';  
status(24)		<= '1' when Align_serdes = ST_START else '0';  
 
status(22)		<= Link_locked;
status(21)		<= STATE_link;
status(20)		<= qpll_lock_in;

status(19)		<= tx_clock_ready;
status(18)		<= rx_clock_ready;
status(17)		<= reset_tx_done;
status(16)		<= reset_rx_done;

status(15)		<= gtpowergood_out;
status(14)		<= qpll_reset_cell; 

status(3)		<= txprgdivresetdone;
status(2)		<= txpmaresetdone;
status(1)		<= rxprgdivresetdone; 
status(0)		<= rxpmaresetdone;

--///////////////////////////////////////////////////////////////////////////////// 
-- 
 
descramble_reset_i1:resetn_resync  
port map(
	aresetn				=> reset_rx_done,
	clock				=> RX_userclk_cell,
	Resetn_sync			=> reset_rx_done_resync 
	);
	
--///////////////////////////////////////////////////////////////////////////////// 
-- Initialiae the link
-- logic from Xilinx example design
 	  	 
Reset_sync_logic	<= '1' when reset_all_logic = '1'   else  '0'; 
rx_init_done_reg	<= '1' when reset_rx_done = '1' else '0';
	
serdes_init_i2:reset_serdes 
 Port map( 
        reset_free_run         => Reset_sync_logic,
        clock_free_run         => clk_freerun_in,
        tx_init_done           => reset_tx_done,
        rx_init_done           => rx_init_done_reg,
        rx_data_good           => STATE_link,
        reset_all_out          => reset_all_logic,
        reset_rx_out           => data_path_rx_reset_cell,
        init_done_out          => Init_done,
        retry_cntr             => retry_init
  	);  
  	
 --///////////////////////////////////////////////////////////////////////////////// 
-- data received path
-- data are piped 
 
data_path_rx_reset	<= data_path_rx_reset_cell;
 		 
process(RX_userclk_cell)
begin
	if rising_edge(RX_userclk_cell) then
 
		rx_data_valid_rg			<= rx_scr_data_valid_cell;
		rx_header_valid_rg			<= rx_scr_header_valid_cell;
		
		rx_data_reg 				<= rx_src_data;
		rx_header_rg				<= rx_scr_header_cell;
	
	end if;
end process;

rx_data_valid						<= rx_data_valid_rg;
rx_header							<= rx_header_rg;
rx_header_valid						<= rx_header_valid_rg;
rx_data								<= rx_data_reg;
SERDES_ready						<= '1' when Align_serdes = ST_link_up else '0';

--///////////////////////////////////////////////////////////////////////////////// 
 -- looking for Idle
-- The maximum block transfer is 4096 bytes  (128b x 256 clocks)
-- This counter (check_link_counter) is free running , if it reachs the max without found a Idle
-- the link is lost and should be reset
-- IF LATER I FOUND A SIGNAL WHICH DETECT A FIBER DISCONNECTION I WILL USE IT

process(reset_rx_done_resync,RX_userclk_cell)
begin
	if reset_rx_done_resync = '0'  then
		check_link_counter				<= (others => '0');
		check_pattern_counter			<= (others => '0');
		check_code_counter				<= (others => '0');
		link_lost						<= '0';
		Incr_check_code_counter			<= '0';
		reset_check_link_counter		<= '0';  
	elsif rising_edge(RX_userclk_cell) then
		--THE COUNTER IS RESET WHEN WE SEE AN IDLE OR A PREDEFINED PATTERN ON THE LINK (SEE BELOW)
		-- OR
		-- IF THE STATE LINK UP IS NOT REACHED
		if reset_check_link_counter = '1' or 
			(Align_serdes /= ST_link_up and	Align_serdes /= ST_wait_Idle_from_other_side) then
			check_link_counter	<= (others => '0');
		
		--THE COUNTER IS ENABLE ONLY IN THOSE TWO STATES (WHERE THE LINK IS SYNCKRONIZED)
		elsif (Align_serdes = ST_link_up or Align_serdes = ST_wait_Idle_from_other_side) then
			check_link_counter <= check_link_counter + '1';
		end if;
		
		link_lost	<= check_link_counter(15) or check_code_counter(15);
		
		--THE COUNTER IS RESET WHEN WE SEE AN IDLE OR A PREDEFINED PATTERN ON THE LINK
		reset_check_link_counter		<= '0';
		if check_pattern_counter = "11" then
			reset_check_link_counter	<= '1';
		end if;
		
		if (rx_data_reg(63 downto 0) = x"1e00000000000000" and rx_data_valid_rg(0) = '1' and Align_serdes = ST_link_up) or
		   (rx_data_reg(63 downto 0) = x"0755aa55aa55aa55" and rx_data_valid_rg(0) = '1' and Align_serdes = ST_wait_Idle_from_other_side) then
			check_pattern_counter	<= check_pattern_counter + '1';
		else 
			check_pattern_counter	<= (others => '0');
		end if;
	
	
		--Check if we see a code not allow

		if Incr_check_code_counter = '1' then
			check_code_counter <= check_code_counter + '1';
		end if;
		 
		
		--THE COUNTER IS RESET WHEN WE SEE AN IDLE OR A PREDEFINED PATTERN ON THE LINK
		Incr_check_code_counter		<= '0';
		if 	(Align_serdes = ST_link_up  and rx_header_rg(4 downto 3) = "10" and rx_data_reg(127 downto 120) /= x"1e" and rx_data_reg(127 downto 120) /= x"78" and rx_data_reg(127 downto 120) /= x"b4") or
			(Align_serdes = ST_link_up  and rx_header_rg(1 downto 0) = "10" and rx_data_reg(63 downto 56)   /= x"1e" and rx_data_reg(63 downto 56)   /= x"78" and rx_data_reg(63 downto 56)   /= x"b4")  then
			Incr_check_code_counter	<= '1';
		end if;
		
	end if;
end process;
 
--///////////////////////////////////////////////////////////////////////////////// 
-- RX aligmenent  control the slip signal
 

rx_usrclk2_not_readyp	<=  reset_all_logic  or not(reset_rx_done ) ; 

rx_clock_ready_sync		<= gtx_userclk_rx_active;
 
resync_rst_i12:resetp_resync  
port map(
	aresetp				=> rx_usrclk2_not_readyp,
	clock				=> RX_userclk_cell, 
	Resetp_sync			=> rx_usrclk2_not_readyp_resync
	);
 
-- define some bits information/control (like IDLE_present; rxgearboxslip; Send_Idle; ..)
process(rx_usrclk2_not_readyp_resync,RX_userclk_cell)
begin
	if rx_usrclk2_not_readyp_resync = '1' then
 			rxgearboxslip				<= '0';				 
			wait_counter				<= x"0000";	 
			Idle_present	            <= '0';
			send_idle                  	<= '0';
			send_idle_sec              	<= '0';
			pattern_found				<= '0'; 
			shift_counter				<= (others => '0');
			shift_inv_counter			<= (others => '0');
			time_wait_counter			<= (others => '0');
			test_shift					<= '0';
	elsif rising_edge(RX_userclk_cell) then
			--reset counters
			if 		Align_serdes = ST_Reset_counters then
				shift_counter		<= (others => '0');
				shift_inv_counter	<= (others => '0');
			-- increment Shift Counter is pattern valid
			elsif 	Align_serdes = ST_check_pattern and pattern_found = '1' then
				Shift_counter		<= Shift_counter + '1';
			elsif 	Align_serdes = ST_check_pattern and pattern_found = '0'  then
			-- increment Shift Counter &
			-- increment Shift counter invalid is pattern invalid
				Shift_counter		<= Shift_counter + '1';
				Shift_inv_counter	<= Shift_inv_counter + '1';
			end if;
			
			-- indicates when  to test_shift
			if 		Align_serdes = ST_Reset_counters then
				test_shift	<= '1';
			elsif 	Align_serdes = ST_START then
				test_shift	<= '0';
			end if;
			
			--When in STATE SL_Slip_state
			-- bit shift   if the pattern received is not correct
			-- we execute a bitslip maximum each xFF clock cycles  (wait time in STATE ST_wait_slip_done)
			rxgearboxslip				<= '0';
			if Align_serdes = ST_slip_state then 
				rxgearboxslip		<= '1';
			end if;
			
			--each 32768 clock we send an Idle when we are sync to informed the other side , and both will be able to switch to Idle and word
            send_idle   <= '0';
            if Align_serdes	= ST_send_idle then
                send_idle   <= '1';
            end if;
            
            send_idle_sec   <= send_idle;
            				
			-- Counter time for bitslip
			if 		Align_serdes = ST_wait_slip_done then  
				wait_counter	<= wait_counter + '1';
			elsif   Align_serdes = ST_slip_state then  
				wait_counter	<= x"0000";	
			end if;
			
			if Align_serdes = ST_Reset_counters then
				slip_done			<= '0'; 
			elsif wait_counter = counter_slip_done then
				slip_done			<= '1';			
			end if;
			
			if  Align_serdes = ST_wait_Idle_from_other_side   then
				time_wait_counter <= time_wait_counter + '1';
			elsif time_wait_counter = x"4000"  then
				time_wait_counter <= (others => '0');
			end if;
			
	--- check pattern found			
		-- At least 16 consecutive pattern
			--- 
			pattern_found			<= '0';
			if (rx_data_reg(127 downto 0) = x"07aa55aa55aa55aa07aa55aa55aa55aa"  and  rx_header_rg(1 downto 0) = "01" and rx_header_rg(4 downto 3) = "01") --  			 
			  or (rx_data_reg(127 downto 0) = x"1e000000000000001e00000000000000" and  rx_header_rg(1 downto 0) = "10" and rx_header_rg(4 downto 3) = "10" ) then --			 
				pattern_found		<='1';
			end if;
	
	-- check when we detect the idle (both side are syncked and we can move to idle word and start to work
			Idle_present   	<= '0';
			if rx_data_reg(127 downto 0) = x"1e000000000000001e00000000000000" and  rx_header_rg(1 downto 0) = "10" and rx_header_rg(4 downto 3) = "10"  then --
                Idle_present    <= '1';
            end if;			
 
	end if;
end process; 
 
--//////////////////////////////////////////////////////////////////////////////////
-- state to control/ reach  LINKUP // LINKDOWN


Sync_SM:process(rx_usrclk2_not_readyp_resync,RX_userclk_cell)
begin 
	if rx_usrclk2_not_readyp_resync = '1' then
	 
		Align_serdes 	<= ST_START;
	elsif rising_edge(RX_userclk_cell) then
		Case Align_serdes is
		
			-- We wait the RX reset done before any check on the data received
			-- 
			when ST_START =>
				if reset_rx_done_resync = '1' and rx_clock_ready_sync = '1' then
					Align_serdes 	<= ST_Reset_counters;
				end if;
		
			when ST_Reset_counters =>
				Align_serdes 	<= ST_check_pattern;
			--  
			--  We check if pattern was found
			-- If NO we have to slip the word in the gearbox
			-- if YES the alignemnt is done
			when ST_check_pattern => 

			-- increment counters valid and check
				if 	    pattern_found = '1' and Shift_counter = Shift_counter_max and Shift_inv_counter = "00000" then 
					Align_serdes 	<= ST_send_idle;
				elsif  pattern_found = '1' and Shift_counter = Shift_counter_max and Shift_inv_counter > "00000" then
					--some pattern(s) are not correct
					Align_serdes 	<= ST_Reset_counters;
		
			-- increment counters unvalid and check
				elsif pattern_found = '0' and (Shift_inv_counter = Shift_inv_counter_max or STATE_link = LINK_DOWN) then 
					-- need a bit shift
					Align_serdes 	<= ST_slip_state;
				elsif pattern_found = '0' and Shift_counter = Shift_counter_max and Shift_inv_counter < Shift_inv_counter_max and STATE_link = LINK_UP  then
					-- lost the link reset counters
					Align_serdes 	<= ST_Reset_counters;
				end if;				
			
			
			-- we do a slip on the gearbox
			when ST_slip_state => 
				 Align_serdes       <= ST_wait_slip_done;
				
			-- wait 48 clock (min32 need after a bitslip) to check is pattern is align
			when ST_wait_slip_done =>
				if slip_done = '1' then
					Align_serdes 	<= ST_Reset_counters;
				end if;
	 
			-- send a Idle word (each 32768 words)to inform the other side of the link that we are ready to lock the link
			when ST_send_idle => 
					Align_serdes	<= ST_wait_Idle_from_other_side;
				
			-- wait for Idle from other side or send an Idle to other side
			when ST_wait_Idle_from_other_side =>
				if 		Idle_present = '1' then
					Align_serdes 	<= ST_link_up;
				elsif 	time_wait_counter(15 downto 0) = x"4000" then
					Align_serdes 	<= ST_send_idle;
				elsif link_lost = '1' then	
					Align_serdes 	<= ST_START;
				end if;
 
			--  Idle found we can lock the link
			-- If a Idle is not found at least each 256 clock , we reset the link 
			when ST_link_up =>
				if link_lost = '1' then
					Align_serdes 	<= ST_START;
				end if;
			when others => 
				Align_serdes 		<= ST_START;
				
		end case;
	end if;
end process;


process(rx_usrclk2_not_readyp_resync,RX_userclk_cell)
begin
    if rx_usrclk2_not_readyp_resync = '1' then
        STATE_link 			<= LINK_DOWN;
		Link_locked			<= '0';
    elsif rising_edge(RX_userclk_cell) then
		STATE_link 			<= LINK_DOWN;
		-- In this 3 states the link is synckronized  
		if Align_serdes = ST_send_idle or 
			Align_serdes = ST_wait_Idle_from_other_side or 
		 	Align_serdes = ST_link_up then
				STATE_link 		<= LINK_UP;
		end if;
		
		--When locked we send only IDLE or data
		--OTHERWISE we send a predefined pattern to help the other side of the link to Synchronize
		Link_locked			<= '0';
		if Align_serdes = ST_link_up then
			Link_locked		<= '1';
		end if;
	end if;
end process;

 
--///////////////////////////////////////////////////////////////////////////////// 
--Status interface read
 

SERDES_status	<= status;


end Behavioral;
