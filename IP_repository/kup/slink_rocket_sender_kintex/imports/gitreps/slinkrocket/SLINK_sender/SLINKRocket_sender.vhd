------------------------------------------------------
-- SLINK Optical interface sender
--
--  Ver 1.00
--
-- Dominique Gigi May 2015
------------------------------------------------------
--   INstatiate the differents components for sender optical SLINK
--   Bit 31 of the "cmd" specifies if it is a write '1' or a read '0'
--   Command DAQON/DAQOFF	cmd = 0x10006 	Command_num(6)  	DT30 = 1 DAQ OFF	=0 DAQON  
--														DT31 = 1 TEST mode 	=0 No TEST mode
--  
------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
 

entity SLINKRocket_sender is
generic (throughput								: string := "15.66");
port (
	RESETp						: IN STD_LOGIC;
	-- FED INTERFACE
	SYS_CLK					    : IN STD_LOGIC;
	LINKWE					    : IN STD_LOGIC; 					--ACTIVE High
	LINKUCTRL					: IN STD_LOGIC; 					--ACTIVE High
	LINKDATA					: IN STD_LOGIC_VECTOR(127 DOWNTO 0);
	LINKDOWN_n					: OUT STD_LOGIC;					--ACTIVE Low
	LINK_LFF					: OUT STD_LOGIC;					--ACTIVE High
	
	INJECT_ERR				    : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
	READ_CE					    : IN STD_LOGIC;
	ADDR						: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
	STATUS_DATA 			    : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
	-- INTERFACE SERDES 
	Resetp_TX_clock				: IN STD_LOGIC;
	Clock_serdes_T				: IN STD_LOGIC;
	SERDES_READY				: IN STD_LOGIC;
	SERDES_BackPressure	        : IN STD_LOGIC;
	FED_serdes_TX				: OUT STD_LOGIC_VECTOR(127 DOWNTO 0); 
	FED_serdes_TX_hd			: OUT std_logic_VECTOR(5 DOWNTO 0);
	 
	Resetp_RX_clock			    : IN STD_LOGIC;	
	Clock_serdes_R				: IN STD_LOGIC;	
	FED_serdes_RX				: IN STD_LOGIC_VECTOR(127 DOWNTO 0);
	FED_serdes_RX_hd			: IN STD_LOGIC_VECTOR(5 DOWNTO 0); 
	SERDES_STATUS			    : IN STD_LOGIC_VECTOR(63 DOWNTO 0) 

	);
end SLINKRocket_sender;


--#####################################################################################
--Architecture
architecture behavioral of SLINKRocket_sender is

component fed_itf
generic (generator 			: boolean := true;
		throughput			: string := "15.66");
port (
	Gresetn_sysCLK				: in std_logic;
	sys_clk					    : in std_logic;
	LinkWe 					    : in STD_LOGIC;
	LinkCtrl 				    : in STD_LOGIC; 
	LinkData 				    : in STD_LOGIC_VECTOR (127 downto 0);
	LinkAlmostFull 		        : out STD_LOGIC;
	LinkDown_n 				    : out STD_LOGIC;
	inject_err 				    : in STD_LOGIC_VECTOR (17 downto 0);
	read_ce 					: in STD_LOGIC;
	addr 						: in STD_LOGIC_VECTOR (15 downto 0);
	status_data 			    : out STD_LOGIC_VECTOR (63 downto 0);
	Resetp_serdes_clock		    : in std_logic;
	Greset_CLK				    : in std_logic;	
	Clock_serdes_T				: in std_logic; -- clock from internal logic
	block_free				    : in std_logic;	-- almost one block is free
	FED_Evt_data				: out std_logic_vector(127 downto 0);
	FED_Evt_block_sz			: out std_logic_vector(15 downto 0);
	FED_Evt_wr_ena				: out std_logic;
	FED_Evt_start				: out std_logic; -- this block is the first for the current event
	FED_Evt_stop				: out std_logic; -- this block is the last for the current event  -- both can be set
	FED_Evt_end_blk				: out std_logic;  -- indicate end of the packet (max 4KBytes)
		-- interface slave to read and write
	Command_wr					: in std_logic;  
	Command_num					: in std_logic_vector(31 downto 0);
	Command_data_wr				: in std_logic_vector(63 downto 0);
	Command_data_rd				: out std_logic_vector(63 downto 0);
	cnt_evt						: out std_logic;			-- pulse for each event (on sys_clk);
	cnt_pckt_rcv				: in std_logic_vector(31 downto 0);
	cnt_pckt_snd				: in std_logic_vector(31 downto 0);
			-- status
	retransmit_ena			    : in std_logic;
	status_state_build_p	    : in std_logic_vector(31 downto 0);
	status_state_core		    : in std_logic_vector(31 downto 0);
	Serdes_status			    : in std_logic_vector(63 downto 0)
	);
end component;

signal Resetp_serdes_clock			: std_logic;

component Core_logic  
port (
	resetn_clk				    : in std_logic;
	Gresetn_clk				    : in std_logic;
	Clock_serdes_T				: in std_logic;
		-- interface from the FED block	
	FED_Evt_data				: in std_logic_vector(127 downto 0);
	FED_Evt_wr_ena			    : in std_logic;
	FED_Evt_start				: in std_logic;
	FED_Evt_stop				: in std_logic;
	FED_Evt_block_sz			: in std_logic_vector(15 downto 0);
	FED_Evt_end_blk				: in std_logic;
	block_free				    : out std_logic;
	req_reset_resync		    : out	std_logic;
		-- interface to the SERDES OUT (send part)
	SERDES_BackPressure 	    : in std_Logic;
	start_pckt				    : out std_logic;                        -- trigger the packet send
	init_pckt				    : out std_logic;                        -- indicates that the packet is a Init packet
	ack_pckt					: out std_logic;                        -- indicates that the packet is a acknoldge packet
	data_pckt				    : out std_logic;                        -- indicates that the packet is a data packet
	data_evt					: out std_logic_vector(127 downto 0);	--data for data packet
	status					    : out std_logic_vector(63 downto 0);    --read_bck for acknowledge packet
	Pckt_CMD				    : out std_logic_vector(15 downto 0);    -- Command in the pcket
	Seq_nb					    : out std_logic_vector(30 downto 0);    -- sequence number
	len_pckt					: out std_logic_vector(15 downto 0);    -- length of the packet (for data packet only) other 0
	rd_dt						: in std_logic;
	end_snd_pckt			    : in std_logic;
	ST_START_state				: in std_logic;
	serdes_init				    : in std_logic;
		                                                                -- interface to the SERDES IN (receiver part)
	rcv_cmd_num					: in std_logic_vector(63 downto 0);	    -- command from MOL
	rcv_cmd_data				: in std_logic_vector(63 downto 0);	    -- data from MOL
	rcv_cmd_ena					: in std_logic;                         -- validate command
	ena_ack					    : in std_logic;		
	seqnb_rcv 				    : in std_logic_vector(30 downto 0);	    -- seq numb from cmd (need an ack)
	retransmit				    : out std_logic;
	Command_wr					    : out std_logic;  
	Command_num						: out std_logic_vector(31 downto 0);
	Command_data_wr					    : out std_logic_vector(63 downto 0);
	Command_data_rd					    : in std_logic_vector(63 downto 0);
	status_state			    : out std_logic_vector(31 downto 0)
	);
end component;

component build_pckt_s  
port (
	resetn_ClkT				    : in std_logic;
	Gresetn_CLKt			    : in std_logic;
	Clock_serdes_T				: in std_logic;
	start_pckt				    : in std_logic;	                        -- trigger the packet send
	init_pckt				    : in std_logic;                         -- indicates that the packet is a Init packet
	ack_pckt					: in std_logic;                         -- indicates that the packet is a acknoldge packet
	data_pckt				    : in std_logic;                         -- indicates that the packet is a data packet
	data_evt					: in std_logic_vector(127 downto 0);	--data for data packet
	read_bck					: in std_logic_vector(63 downto 0);     --data back for acknowledge packet
	Pckt_CMD				    : in std_logic_vector(15 downto 0);     -- Command in the pcket
	Seq_nb					    : in std_logic_vector(30 downto 0);     -- sequence number
	len_pckt					: in std_logic_vector(15 downto 0);     -- length of the packet (for data packet only) other 0
	error_gen				    : in std_logic_vector(3 downto 0);
	rd_dt						: out std_logic;					    -- request data for data packet only
	end_pckt					: out std_logic;
	Serdes_data_o				: out std_logic_vector(127 downto 0); 	--- data send to SERDES
	Serdes_Start_o				: out std_logic;
	Serdes_Stop_o				: out std_logic;
	Serdes_Val_Dwrd_o			: out std_logic;
	serdes_ready				: in std_logic;
	ST_START_state				    : out std_logic;
	cnt_pckt_snd			    : out std_logic_vector(31 downto 0);
	status_state			    : out std_logic_vector(31 downto 0)  	);
end component;

 

component rcv_pckt_s 
port (
	resetn_clkR				    : in std_logic                       ;
	resetn_clkT				    : in std_logic                       ;
	Greset_clkR				    : in std_logic                       ;
	Greset_clkT				    : in std_logic                       ;
	clock_serdes_R				: in std_logic                       ;
	Clock_serdes_T			    : in std_logic                       ;
	datai						: in std_logic_vector(127 downto 0)   ; --- data and K bit send from SERDES
	val_wrd					    : in std_logic                       ;
	sop						    : in std_logic                       ;							 -- indicates the start of a packet
	eop						    : in std_logic                       ;							 -- indicates the end of a packet
	error_gen				    : in std_logic                       ;
	rcv_cmd_num					: out std_logic_vector(63 downto 0);	-- command from DAQ
	rcv_cmd_data				: out std_logic_vector(63 downto 0);	-- data from  DAQ
	rcv_cmd_ena					: out std_logic; 						-- validate command
	seqnb 					    : out std_logic_vector(30 downto 0)  ;	-- seq numb from cmd (need an ack)
	ena_ack					    : out std_logic                      ;		
	info_packt				    : out std_logic_vector(15 downto 0)  ;
	cnt_pckt_rcv			    : out std_logic_vector(31 downto 0) 	
	);
end component;

-- component to/from 64/66bit encoding
component R127b_T_Serdes_127b_decoding is
	generic(constant	swap_bit	: boolean := false);
	port
	(
		reset_n						: in std_logic;
		clock						: in  std_logic;
		SerDes_DATA_I				: in std_logic_vector(127 DOWNTO 0);
		SerDes_Header_I				: in std_logic_vector(5 downto 0);
				
		SD_DATA_O					: out  std_logic_vector(127 downto 0); --- data from SERDES
		SD_Start_PktO				: out  std_logic;
		SD_End_PktO					: out  std_logic; 
		SD_Wen_PktO					: out  std_logic
	 );
end component;

signal SD_DATA_I				    : STD_LOGIC_VECTOR(127 DOWNTO 0);
signal SD_VAL_I						: STD_LOGIC;
signal SD_SOP_I						: STD_LOGIC;
signal SD_EOP_I						: STD_LOGIC;

component T127_R_serdes_127b_encoding is
	generic(constant	swap_bit	: boolean := false);
	port
	(
		reset_n						: in  std_logic;
		clock						: in  std_logic;
		SD_DATA_I					: in std_logic_vector(127 DOWNTO 0);
		SD_Start_I					: in std_logic;
		SD_Stop_I					: in std_logic;
		SD_Val_dwrd_I				: in std_logic; 
				
		Serdes_word					: out  std_logic_vector(127 downto 0); 
		Serdes_Header				: out std_logic_vector(5 downto 0)
	 );
end component;

signal SD_DATA_O					: std_logic_vector(127 DOWNTO 0);
signal SD_Start_O					: std_logic;
signal SD_Stop_O					: std_logic;
signal SD_valid_Dwrd_o				: std_logic;
		
component   resetn_resync is
port (
	aresetn				: in std_logic;
	clock				: in std_logic; 
	Resetn_sync			: out std_logic;
	Resetp_sync			: out std_logic
	);
end component;

SIGNAL	rcv_cmd_data					:std_logic_vector(63 downto 0);
SIGNAL	rcv_cmd_ena					    :std_logic;
SIGNAL	ena_ack					    :std_logic;
SIGNAL	seqnb_rcv				    :std_logic_vector(30 downto 0);
SIGNAL	ST_START_state				    :std_logic;
SIGNAL	end_snd_pckt			    :std_logic;
SIGNAL	rd_dt						:std_logic;
SIGNAL	rcv_cmd_num					    :std_logic_vector(63 downto 0);
SIGNAL	len_pckt					:std_logic_vector(15 downto 0);
SIGNAL	Seq_nb					    :std_logic_vector(30 downto 0);
SIGNAL	Pckt_CMD				    :std_logic_vector(15 downto 0);
SIGNAL	INFO_packt				    :std_logic_vector(15 downto 0);
SIGNAL	card_ID_snd				    :std_logic_vector(15 downto 0);
SIGNAL	read_bck					:std_logic_vector(63 downto 0);
SIGNAL	data_evt					:std_logic_vector(127 downto 0);
SIGNAL	data_pckt				    :std_logic;
SIGNAL	ack_pckt					:std_logic;
SIGNAL	init_pckt				    :std_logic;
SIGNAL	start_pckt				    :std_logic;
SIGNAL	FED_Evt_end_blk				    :std_logic;
SIGNAL	FED_Evt_stop					:std_logic;
SIGNAL	FED_Evt_start				    :std_logic; 
SIGNAL	FED_Evt_wr_ena					    :std_logic;
SIGNAL	FED_Evt_block_sz			    :std_logic_vector(15 downto 0);
SIGNAL  FED_Evt_data					:std_logic_vector(127 downto 0);
SIGNAL  block_free				    :std_logic;
		-- interface slave to read and write
SIGNAL  Command_wr						: std_logic;  
SIGNAL  Command_num						: std_logic_vector(31 downto 0);
SIGNAL  Command_data_wr					    : std_logic_vector(63 downto 0);
SIGNAL  Command_data_rd					    : std_logic_vector(63 downto 0);

SIGNAL cnt_pckt_rcv				    : std_logic_vector(31 downto 0);
SIGNAL cnt_pckt_snd				    : std_logic_vector(31 downto 0);
SIGNAL status_state_build_p	        : std_logic_vector(31 downto 0);
SIGNAL status_state_core		    : std_logic_vector(31 downto 0);
 
SIGNAL DATAo_unswapped			    : std_logic_vector(31 downto 0);
SIGNAL CTRLo_unswapped			    : std_logic_vector( 3 downto 0);
SIGNAL DATAi_unswapped			    : std_logic_vector(31 downto 0);
SIGNAL CTRLi_unswapped			    : std_logic_vector( 3 downto 0);
SIGNAL req_reset_resync			    : std_logic;
SIGNAL retransmit					: std_logic;
--
SIGNAL reg_datai					: std_logic_vector(127 downto 0); 
SIGNAL reg_uctrli					: std_logic; 
SIGNAL reg_weni					    : std_logic;

SIGNAL G_reset						: std_logic;


SIGNAL GRstn_sysckl				    : std_logic;
SIGNAL GRstn_T_ckl					: std_logic;
SIGNAL GRst_R_ckl					: std_logic;
SIGNAL Rst_sysckl					: std_logic;
SIGNAL Rstn_T_ckl					: std_logic;
SIGNAL Rstn_R_ckl					: std_logic;
SIGNAL LINKDown_cell				: std_logic;

signal Reset						: std_logic;

attribute mark_debug : string;
--attribute mark_debug of Command_wr		    : signal is "true"; 

--******************************************************************
--*******************  BEGIN  **************************************
--******************************************************************
begin

reset <= not(RESETp);

--#################################################
-- reset resync
--#################################################
-- reset coming form FED
resync_rst_i1:resetn_resync 
port map(
	aresetn			=> reset,
	clock			=> SYS_CLK,
	Resetn_sync		=> Rst_sysckl
	);

resync_rst_i2:resetn_resync 
port map(
	aresetn			=> reset,
	clock			=> Clock_serdes_T,
	Resetn_sync		=> Rstn_T_ckl
	);
	
resync_rst_i3:resetn_resync
port map(
	aresetn			=> reset,
	clock			=> Clock_serdes_R,
	Resetn_sync		=> Rstn_R_ckl
	);	
-- reset coming form FED or from DAQ
G_reset		<= '0' when	reset = '0' or req_reset_resync = '0' else '1';	
	
resync_rst_i4:resetn_resync 
port map(
	aresetn			=> G_reset,
	clock			=> SYS_CLK,
	Resetn_sync		=> GRstn_sysckl
	);

resync_rst_i5:resetn_resync 
port map(
	aresetn			=> G_reset,
	clock			=> Clock_serdes_T,
	Resetn_sync		=> GRstn_T_ckl
	);
	
resync_rst_i6:resetn_resync 
port map(
	aresetn			=> G_reset,
	clock			=> Clock_serdes_R,
	Resetn_sync		=> GRst_R_ckl
	);	
--#################################################
-- registers FED interface 
--#################################################
process(LINKDown_cell,SYS_CLK)
begin
	if LINKDown_cell = '0' then
		reg_weni			<= '0';
	elsif rising_edge(SYS_CLK) then
		reg_weni			<= LINKWe;
	end if;
end process;

process(SYS_CLK)
begin
	if rising_edge(SYS_CLK) then
		reg_datai			<= LINKData; 
		reg_uctrli			<= LINKUCTRL; 
	end if;
end process;

Resetp_serdes_clock <= Resetp_TX_clock or Resetp_RX_clock; 
 
 -- block used to interface the SR_core and the FED (clock Domain) it include also a FEDemulator
i1:fed_itf
generic map (throughput     	=> throughput)
port map(
	Gresetn_sysCLK			    => GRstn_sysckl,
	sys_clk					    => SYS_CLK,
	LinkWe 					    => reg_weni,
	LinkCtrl 				    => reg_uctrli, 
	LinkData 				    => reg_datai, 
	LinkAlmostFull			    => LINK_LFF,
	LinkDown_n 				    => LINKDown_cell,
	
	inject_err 				    => inject_err,
	read_ce 					=> read_CE,
	addr 						=> Addr,
	status_data 			    => status_data,
	
	Resetp_serdes_clock		    => Resetp_serdes_clock,
	Greset_CLK				    => GRstn_T_ckl,
	Clock_serdes_T				=> Clock_serdes_T,
	block_free				    => block_free,
	FED_Evt_data				=> FED_Evt_data,
	FED_Evt_block_sz		    => FED_Evt_block_sz,
	FED_Evt_wr_ena			    => FED_Evt_wr_ena, 
	FED_Evt_start			    => FED_Evt_start,
	FED_Evt_stop				=> FED_Evt_stop,
	FED_Evt_end_blk			    => FED_Evt_end_blk,
	
	Command_wr				    => Command_wr,  
	Command_num					=> Command_num,
	Command_data_wr			    => Command_data_wr,
	Command_data_rd			    => Command_data_rd,
	--cnt_evt					=> cnt_evt,
	cnt_pckt_rcv			    => cnt_pckt_rcv,
	cnt_pckt_snd			    => cnt_pckt_snd,
	retransmit_ena			    => retransmit,
	status_state_build_p	    => status_state_build_p,
	status_state_core		    => status_state_core,
	Serdes_status			    => Serdes_status
	);

LinkDown_n 					<= LINKDown_cell;	
	
-- block used to split fragment in block(s); 4 of 8192 bytes blocks maximum in the design	
i2:Core_logic  
port map(
	resetn_clk				    => Rstn_T_ckl,
	Gresetn_clk				    => GRstn_T_ckl,
	Clock_serdes_T				=> Clock_serdes_T,
		-- interface from the FED block	
	FED_Evt_data				=> FED_Evt_data,
	FED_Evt_wr_ena			    => FED_Evt_wr_ena, 
	FED_Evt_start				=> FED_Evt_start,
	FED_Evt_stop				=> FED_Evt_stop,
	FED_Evt_block_sz			=> FED_Evt_block_sz,
	FED_Evt_end_blk				=> FED_Evt_end_blk,
	block_free				    => block_free,
	req_reset_resync		    => req_reset_resync,
		-- interface to the SERDES OUT (send part)
	SERDES_BackPressure         => SERDES_BackPressure,
	start_pckt				    => start_pckt,
	init_pckt				    => init_pckt,
	ack_pckt					=> ack_pckt,
	data_pckt				    => data_pckt,
	data_evt					=> data_evt,
	status					    => read_bck,
	Pckt_CMD				 	=> Pckt_CMD,
	Seq_nb					    => Seq_nb,
	len_pckt					=> len_pckt,
	rd_dt						=> rd_dt,
	end_snd_pckt			    => end_snd_pckt,
	ST_START_state				=> ST_START_state,
	serdes_init				    => SERDES_READY,
		-- interface to the SERDES IN (receiver part)
	rcv_cmd_num					=> rcv_cmd_num,
	rcv_cmd_data				=> rcv_cmd_data,
	rcv_cmd_ena					=> rcv_cmd_ena,
	ena_ack					    => ena_ack,
	seqnb_rcv 				    => seqnb_rcv,
	retransmit				    => retransmit,
	Command_wr				 	=> Command_wr,  
	Command_num					=> Command_num,
	Command_data_wr				=> Command_data_wr,
	Command_data_rd				=> Command_data_rd,
	status_state			    => status_state_core	); 

--blcok used to generate the packet to send over the optical link	
i3:build_pckt_s  
port map(
	resetn_ClkT			   		=> Rstn_T_ckl,
	Gresetn_ClkT			 	=> GRstn_T_ckl,
	Clock_serdes_T				=> Clock_serdes_T,	
	start_pckt				    => start_pckt,
	init_pckt				    => init_pckt,
	ack_pckt					=> ack_pckt,
	data_pckt				    => data_pckt,
	data_evt					=> data_evt,
	read_bck					=> read_bck,
	Pckt_CMD				    => Pckt_CMD,
	Seq_nb					    => Seq_nb,
	len_pckt					=> len_pckt,
	error_gen				    => inject_err(4 downto 1),
	rd_dt						=> rd_dt,
	end_pckt					=> end_snd_pckt,

	Serdes_data_o				=> SD_Data_o, 
	Serdes_Start_o				=> SD_start_o	,
	Serdes_Stop_o				=> SD_stop_o	,
	Serdes_Val_Dwrd_o			=> SD_valid_Dwrd_o	,
	serdes_ready				=> SERDES_READY,
	ST_START_state				=> ST_START_state,
	status_state			    => status_state_build_p,
	cnt_pckt_snd			    => cnt_pckt_snd	);

 
-- block used to manage the packet received from the optical link	
i4:rcv_pckt_s
port map(
	resetn_clkR				    => Rstn_R_ckl,
	resetn_clkT				    => Rstn_T_ckl,
	Greset_clkR				    => GRst_R_ckl,
	Greset_clkT				    => GRstn_T_ckl,
	clock_serdes_R				=> Clock_serdes_R,
	Clock_serdes_T				=> Clock_serdes_T,
	datai						=> SD_DATA_I,
	val_wrd					    => SD_VAL_I ,
	sop						    => SD_SOP_I	,
	eop						    => SD_EOP_I	,
	error_gen				    => inject_err(5),
	rcv_cmd_num				    => rcv_cmd_num,	-- receive a command (require to send an Ack)
	rcv_cmd_data				=> rcv_cmd_data,
	rcv_cmd_ena				    => rcv_cmd_ena,
	ena_ack					    => ena_ack,	-- receive an acknowledge
	seqnb 					    => seqnb_rcv,
	INFO_packt				    => INFO_packt,
	cnt_pckt_rcv			    => cnt_pckt_rcv	);
	
-- packaging 64-64 bit eoncoding

T_to_Serdes_send:T127_R_serdes_127b_encoding  
	port map	(
		reset_n					=>	Rstn_T_ckl			, 
		clock					=>	Clock_serdes_T			, 
		SD_DATA_I				=>	SD_DATA_O		 				, 
		SD_Start_I				=>	SD_START_O	 				, 
		SD_Stop_I				=>	SD_STOP_O		 				, 
		SD_Val_dwrd_I			=>	SD_valid_Dwrd_o				,  
				               
		Serdes_word				=>	FED_serdes_TX					, 
		Serdes_Header			=>	FED_serdes_TX_hd				 
	 ); 	
	 
Serdes_to_R_Send:R127b_T_Serdes_127b_decoding  
	port map
	(
		reset_n					=>	Rstn_R_ckl			,
		clock					=>	Clock_serdes_R			,
		SerDes_DATA_I			=>	FED_serdes_RX					,
		SerDes_Header_I			=>	FED_serdes_RX_hd				,
								
		SD_DATA_O				=>	SD_DATA_I						,--- data from SERDES
		SD_Start_PktO			=>	SD_SOP_I						,
		SD_End_PktO				=>	SD_EOP_I						,
		SD_Wen_PktO				=>	SD_VAL_I						 
	 );
	
end behavioral;


