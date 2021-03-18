----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.03.2019 16:03:38
-- Design Name: 
-- Module Name: GLB_send_rec_sr - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity SR_sender_GLB is
  generic ( txpolarity_in					        : std_logic := '0';
			rxpolarity_in					        : std_logic := '0'; 
            Clock_source							: string := "Master";
				--possible choices are Slave or Master
			throughput								: string := "15.66";
				--possible choices are  15.66 or 25.78125
		    ref_clock								: string := "156.25";
				--possible choices are  156.25  or   322.265625  
			technology								: string := "GTY" 
			 );
 Port (
  		aresetn						: in std_logic;
		txdiffctrl_in 				: in std_logic_vector(4 downto 0) := "11000";  -- async
		txpostcursor_in 			: in std_logic_vector(4 downto 0) := "10100";  -- async
		txprecursor_in				: in std_logic_vector(4 downto 0) := "00000";  -- async
		Srds_loopback_in			: in std_logic;
		Core_status_addr			: in std_logic_vector(15 downto 0); 
		Core_status_data_out		: out std_logic_vector(63 downto 0);

		user_100MHz_clk				: in std_logic;
		
		FED_CLOCK					: in std_logic;
		event_data_word				: in std_logic_vector(127 downto 0);
		event_ctrl					: in std_logic; 
		event_data_wen				: in std_logic;
		backpressure				: out std_logic; 
		Link_DOWN_n					: out std_logic;
		ext_trigger					: in std_logic;
		ext_veto_out				: out std_logic;
		
		qpll_lock_in				: IN STD_LOGIC;
		qpll_reset_out				: OUT STD_LOGIC;
		qpll_clkin					: IN STD_LOGIC;
		qpll_ref_clkin				: IN STD_LOGIC;
		
		--  Clock source and destination
		--Clock control to/from  SLAVE SERDES
		-- These signals are to/from the SLAVE serdes to be used to generate the master clock
		gtS_Reset_TX_clock_out							: out std_logic;                 				-- this signals are displayed for the Slave SERDES 
		gtS_userclk_tx_active_in						: in std_logic := '0';                  		-- this signals are displayed for the Slave SERDES 
		gtS_userclk_tx_usrclk_in						: in std_logic := '0';                  		-- this signals are displayed for the Slave SERDES
		gtS_userclk_tx_usrclk2_in						: in std_logic := '0';                  		-- this signals are displayed for the Slave SERDES
		gtS_userclk_tx_usrclk4_in						: in std_logic := '0';                  		-- this signals are displayed for the Slave SERDES 
		
		--Clock Control to/from MASTER CLOCK LOGIC 
		-- these signals are source to generate the master clock of the serdes 
		gtM_Reset_TX_clock_in_0			: in std_logic := '0';--active HIGH -- this signals is displayed for the Master SERDES 
		gtM_Reset_TX_clock_in_1			: in std_logic := '0';--active HIGH -- this signals is displayed for the Master SERDES 
		gtM_Reset_TX_clock_in_2			: in std_logic := '0';--active HIGH -- this signals is displayed for the Master SERDES 
		gtM_userclk_tx_active_out						: out std_logic := '0';                         -- this signals is displayed for the Master SERDES 
		gtM_userclk_tx_usrclk_out						: out std_logic := '0';                         -- this signals is displayed for the Master SERDES
		gtM_userclk_tx_usrclk2_out						: out std_logic := '0';                         -- this signals is displayed for the Master SERDES
		gtM_userclk_tx_usrclk4_out						: out std_logic := '0';                         -- this signals is displayed for the Master SERDES 
				
		Snd_gt_rxn_in	 			: in std_logic;  	
        Snd_gt_rxp_in	 			: in std_logic;  	
        Snd_gt_txn_out	 			: out std_logic; 
        Snd_gt_txp_out	 			: out std_logic;
		
		Rst_hrd_sim					: in std_logic
 );
end SR_sender_GLB;
--*///////////////////////////////////////////////////////////////////////////////
--*////////////////////////   Behavioral        //////////////////////////////////
--*///////////////////////////////////////////////////////////////////////////////
architecture Behavioral of SR_sender_GLB is

 
signal clock_trans_serdes_FED				: std_logic;
signal clock_rcv_serdes_FED					: std_logic;

component Serdes_wrapper_snd_inst is
  Generic (txpolarity_in					        : std_logic := '0';
	        rxpolarity_in					        : std_logic := '0'; 
		    Clock_source							: string := "Master";
				--possible choices are Slave or Master
            throughput								: string := "15.66";
				--possible choices are  15.66 or 25.78125
		ref_clock								: string := "156.25";
				--possible choices are  156.25  or   322.265625 
			technology								: string := "GTY" 
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

		SERDES_READY									: out std_logic;
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
  
		gt_rxn_in                          	            : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);		-- SERDES connection 
		gt_rxp_in                          	            : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);	
		gt_txn_out                         	            : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
		gt_txp_out                         	            : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
		 
		Rst_hrd_sim										: in std_logic
  );
end component;

signal gtM_userclk_rx_active                        : std_logic;

signal gtM_Clock_Src_TX 							: std_logic; 
signal gtM_Reset_TX_clock 							: std_logic; 
signal gtM_userclk_tx_active 						: std_logic; 
signal gtM_userclk_tx_usrclk 						: std_logic;
signal gtM_userclk_tx_usrclk2 						: std_logic;
signal gtM_userclk_tx_usrclk4 						: std_logic; 

signal Resetp_TX_clock									: std_logic;
signal Resetp_RX_clock									: std_logic;
signal SERDES_status									: std_logic_vector(63 downto 0);
	 
signal FED_serdes_RX_hd  	                		    : std_logic_vector(5 downto 0);		 
signal FED_serdes_RX                				    : std_logic_vector(127 downto 0);
signal FED_serdes_TX_hd                  			    : std_logic_vector(5 downto 0);	
signal FED_serdes_TX                     			    : std_logic_vector(127 downto 0);
signal SERDES_READY                     			    : std_logic;

component SLINKRocket_sender is
generic (throughput								: string := "15.66");
port (
	RESETp						: IN STD_LOGIC;
	-- FED INTERFACE
	SYS_CLK					    : IN STD_LOGIC;
	LINKWE					    : IN STD_LOGIC; 
	LINKUCTRL					: IN STD_LOGIC; 
	LINKDATA					: IN STD_LOGIC_VECTOR(127 DOWNTO 0);
	LINKDOWN_n					: OUT STD_LOGIC;
	LINK_LFF					: OUT STD_LOGIC;	
	
	INJECT_ERR				    : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
	READ_CE					    : IN STD_LOGIC;
	ADDR						: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
	STATUS_DATA 			    : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
	-- INTERFACE SERDES
	Resetp_TX_clock             : in STD_LOGIC;
	clock_serdes_T				: IN STD_LOGIC;
	SERDES_READY				: IN STD_LOGIC;
	SERDES_BackPressure	        : IN STD_LOGIC;
	FED_serdes_TX				: OUT STD_LOGIC_VECTOR(127 DOWNTO 0); 
	FED_serdes_TX_hd			: OUT std_logic_VECTOR(5 DOWNTO 0);
	
	Resetp_RX_clock              : in STD_LOGIC;
	clock_serdes_R			    : IN STD_LOGIC;	
	FED_serdes_RX				: IN STD_LOGIC_VECTOR(127 DOWNTO 0);
	FED_serdes_RX_hd			: IN STD_LOGIC_VECTOR(5 DOWNTO 0); 
	SERDES_STATUS			    : IN STD_LOGIC_VECTOR(63 DOWNTO 0) 

	);
end component;
  
signal Core_SR_status						: std_logic_vector(63 downto 0);

signal reset_p								: std_logic;

signal gtM_Reset_TX_clock_in : std_logic_vector(2 downto 0);
signal gtM_Reset_RX_clock_in : std_logic_vector(2 downto 0);

--#############################################################################
-- Code start here
--#############################################################################
begin

  gtM_Reset_TX_clock_in <= (gtM_Reset_TX_clock_in_0,gtM_Reset_TX_clock_in_1,gtM_Reset_TX_clock_in_2); 
  

--#############################
-- Sender part FED
 
reset_p		<= not(aresetn);
 
Sender_core_i1:SLINKRocket_sender 
generic map (throughput		=> throughput) 
port map(
	RESETp						=>	reset_p		      		  , 
	-- FED INTERFACE            =>					          , 
	SYS_CLK					    =>	FED_CLOCK			      , 
	LINKWE					    =>	event_data_wen		      , 
	LINKUCTRL					=>	event_ctrl			      ,   
	LINKDATA					=>	event_data_word		      , 
	LINKDOWN_n					=>	Link_DOWN_n			      , 
	LINK_LFF					=>	backpressure		      , 
															
	INJECT_ERR				    =>	(others => '0')		      , 
	READ_CE					    =>	'1'				          , 
	ADDR						=>	Core_status_addr		      , 
	STATUS_DATA 			    =>	Core_SR_status	          , 
	-- INTERFACE SERDES         =>					          , 
	Resetp_TX_clock				=>	Resetp_TX_clock        	  , 
	clock_serdes_T				=>	clock_trans_serdes_FED	  , 
	SERDES_READY				=>  SERDES_READY              ,           
	SERDES_BackPressure	        =>	'0'				          , 
	FED_serdes_TX				=>	FED_serdes_TX  			  ,
	FED_serdes_TX_hd			=>	FED_serdes_TX_hd		  ,
	
	Resetp_RX_clock             =>  Resetp_RX_clock            ,
	clock_serdes_R			    =>	clock_rcv_serdes_FED	  , 
	FED_serdes_RX				=>	FED_serdes_RX			  ,
	FED_serdes_RX_hd			=>	FED_serdes_RX_hd		  ,
	SERDES_STATUS			    =>	SERDES_status		 

	);
     
 
Clock_master_SERDES:if Clock_source = "Master" generate
	-- instantiation of the serdes for the sender MASTER MODE
	serdes_sender_i1:Serdes_wrapper_snd_inst  
	  generic map( 	
					txpolarity_in		=> txpolarity_in	,
					rxpolarity_in		=> rxpolarity_in	, 
					Clock_source		=> "Master"			,
					throughput			=> throughput,
					 ref_clock			=> ref_clock,
					 technology			=> technology		
				)
	  Port map(
			txdiffctrl_in 					=> txdiffctrl_in	,
			txpostcursor_in 				=> txpostcursor_in	,
			txprecursor_in					=> txprecursor_in	,
			SERDES_status					=> SERDES_status	,
			Srds_loopback_in                => Srds_loopback_in  ,           
											
	  -- data bus                          
			userclk_tx_srcclk_out			=> clock_trans_serdes_FED             ,	-- FRAME to send over SERDES
			tx_header						=> FED_serdes_TX_hd                   ,	-- bit control of the 64/66 encoding
			tx_data							=> FED_serdes_TX                      ,	-- data word
											
			userclk_rx_srcclk_out			=> clock_rcv_serdes_FED               ,	-- FRAME received over SERDES
			-- rx_data_valid					=>                                ,	-- valid data word
			rx_header						=> FED_serdes_RX_hd                   ,	-- header bit (64/66 encoding)
			-- rx_header_valid					=>                                ,	-- valid header bits
			rx_data							=> FED_serdes_RX                      ,	-- data words (2 x 64 bit)
			-- rx_SOS							=>                                ,	-- Start Of Sequence
											
			SERDES_READY					=> SERDES_READY                       ,	
	  --   Gb serdes interface              
			clk_freerun_in					=> user_100MHz_clk                    ,	-- reference clocks QPLL signals
											
			qpll_lock_in					=> qpll_lock_in	                      ,
			qpll_reset_out					=> qpll_reset_out	                  ,
			qpll_clk_in						=> qpll_clkin		                  ,
			qpll_refclk_in					=> qpll_ref_clkin                     ,
	 --  Clock source and destination
			--Clock control to/from  SERDES/logic
			-- These signals are from the serdes to be used to generate the master clock
			gtM_Clock_Src_TX_out			=> gtM_Clock_Src_TX 		          , 
			gtx_Reset_TX_clock_out			=> gtM_Reset_TX_clock 	              ,  
			gtx_userclk_tx_active_in		=> gtM_userclk_tx_active              , 
			gtx_userclk_tx_usrclk_in		=> gtM_userclk_tx_usrclk              ,
			gtx_userclk_tx_usrclk2_in		=> gtM_userclk_tx_usrclk2              ,
			gtx_userclk_tx_usrclk4_in		=> gtM_userclk_tx_usrclk4              , 
			
			--Clock Control to/from MASTER 
			-- these signals are source to generate the master clock of the serdes
			gtM_Clock_Src_TX_in				=> gtM_Clock_Src_TX 	              , 
			gtM_Reset_TX_clock_in(0)		=> gtM_Reset_TX_clock                 ,
			gtM_Reset_TX_clock_in(3 downto 1)=> gtM_Reset_TX_clock_in, 
			gtM_userclk_tx_active_out		=> gtM_userclk_tx_active              , 
		    gtM_userclk_rx_active_out		=> gtM_userclk_rx_active                 , 
			gtM_userclk_tx_usrclk_out		=> gtM_userclk_tx_usrclk              ,
			gtM_userclk_tx_usrclk2_out		=> gtM_userclk_tx_usrclk2             ,
			gtM_userclk_tx_usrclk4_out		=> gtM_userclk_tx_usrclk4             , 
			
			gt_rxn_in(0)                    => Snd_gt_rxn_in                      ,--	-- SERDES connection 
			gt_rxp_in(0)                    => Snd_gt_rxp_in                      ,--
			gt_txn_out(0)                   => Snd_gt_txn_out                     ,--
			gt_txp_out(0)                   => Snd_gt_txp_out       	          , 
			
			Rst_hrd_sim						=> Rst_hrd_sim
	  );
	   
	gtM_userclk_tx_active_out				<= gtM_userclk_tx_active	;  
	gtM_userclk_tx_usrclk_out				<= gtM_userclk_tx_usrclk	; 
	gtM_userclk_tx_usrclk2_out				<= gtM_userclk_tx_usrclk2	; 
	gtM_userclk_tx_usrclk4_out				<= gtM_userclk_tx_usrclk4	;  
	  
	Resetp_TX_clock             			<= not(gtM_userclk_tx_active); 
	Resetp_RX_clock                         <= not(gtM_userclk_rx_active);    
end generate;

Clock_slave_SERDES:if Clock_source = "Slave" generate
	-- instantiation of the serdes for the sender SLAVE MODE
	serdes_sender_i1:Serdes_wrapper_snd_inst  
	  generic map( 	
					txpolarity_in		=> txpolarity_in	,
					rxpolarity_in		=> rxpolarity_in	, 
					Clock_source		=> "Slave"			,
					throughput			=> throughput,
					 ref_clock			=> ref_clock,
					 technology			=> technology		
				)
	  Port map(
			txdiffctrl_in 					=> txdiffctrl_in	,
			txpostcursor_in 				=> txpostcursor_in	,
			txprecursor_in					=> txprecursor_in	,
			SERDES_status					=> SERDES_status	,
			Srds_loopback_in                => Srds_loopback_in ,
											
	  -- data bus                          
			userclk_tx_srcclk_out			=> clock_trans_serdes_FED           ,	-- FRAME to send over SERDES
			tx_header						=> FED_serdes_TX_hd                 ,	-- bit control of the 64/66 encoding
			tx_data							=> FED_serdes_TX                    ,	-- data word
											
			userclk_rx_srcclk_out			=> clock_rcv_serdes_FED             ,	-- FRAME received over SERDES
			-- rx_data_valid					=>                              ,	-- valid data word
			rx_header						=> FED_serdes_RX_hd                 ,	-- header bit (64/66 encoding)
			-- rx_header_valid					=>                              ,	-- valid header bits
			rx_data							=> FED_serdes_RX                    ,	-- data words (2 x 64 bit)
			-- rx_SOS							=>                              ,	-- Start Of Sequence
											
			SERDES_READY					=> SERDES_READY                     ,	
	  --   Gb serdes interface              
			clk_freerun_in					=> user_100MHz_clk                  ,	-- reference clocks QPLL signals
											
			qpll_lock_in					=> qpll_lock_in	                    ,
			qpll_reset_out					=> qpll_reset_out	                ,
			qpll_clk_in						=> qpll_clkin		                ,
			qpll_refclk_in					=> qpll_ref_clkin                   ,
	 --  Clock source and destination
			--Clock control to/from  SERDES/logic
			-- These signals are from the serdes to be used to generate the master clock 
			gtx_Reset_TX_clock_out			=> gtS_Reset_TX_clock_out 	        ,  
			gtx_userclk_tx_active_in		=> gtS_userclk_tx_active_in         , 
			gtx_userclk_tx_usrclk_in		=> gtS_userclk_tx_usrclk_in         ,
			gtx_userclk_tx_usrclk2_in		=> gtS_userclk_tx_usrclk2_in        ,
			gtx_userclk_tx_usrclk4_in		=> gtS_userclk_tx_usrclk4_in        , 
			
			
			--Clock Control to/from MASTER 
			-- these signals are source to generate the master clock of the serdes
			gtM_Clock_Src_TX_in				=> '0' 	                            , 
			gtM_Reset_TX_clock_in => "0000"                           , 
		    gtM_userclk_rx_active_out		=> gtM_userclk_rx_active                   , 
		    
			gt_rxn_in(0)                    => Snd_gt_rxn_in                    ,--	-- SERDES connection 
			gt_rxp_in(0)                    => Snd_gt_rxp_in                    ,--
			gt_txn_out(0)                   => Snd_gt_txn_out                   ,--
			gt_txp_out(0)                   => Snd_gt_txp_out       	        , 
			
			Rst_hrd_sim						=> Rst_hrd_sim
	  );
	  
 	  
	Resetp_TX_clock             			<= not(gtS_userclk_tx_active_in); 
	Resetp_RX_clock                         <= not(gtM_userclk_rx_active);    
	   
end generate;
  
Core_status_data_out	<= Core_SR_status; 

end Behavioral;
