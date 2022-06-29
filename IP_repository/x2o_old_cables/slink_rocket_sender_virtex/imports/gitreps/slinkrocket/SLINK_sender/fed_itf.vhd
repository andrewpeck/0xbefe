------------------------------------------------------
-- data IN from FED
--
--  Ver 1.00
--
-- Dominique Gigi May 2015
------------------------------------------------------
--   This is the TOP level of the core for the sender part
--  
------------------------------------------------------
LIBRARY ieee;
library work;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.mydefs.all;


entity fed_itf is
generic (generator 			: boolean := true;
		throughput			: string := "15.66");
port ( 
	Gresetn_sysCLK				    : in std_logic;
	sys_clk						    : in std_logic;
	
-- link data write enable 						ACTIVE HIGH
   LinkWe 						    : in  STD_LOGIC; 
-- link data header/trailer marker when '1'
	LinkCtrl 					    : in  STD_LOGIC;
-- link data
	LinkData 					    : in  STD_LOGIC_VECTOR (127 downto 0);
-- link data buffer almost full  			ACTIVE High
	LinkAlmostFull 			        : out  STD_LOGIC;
-- link down   									ACTIVE LOW
	LinkDown_n 					    : out  STD_LOGIC;
--  
-- enables error injection to test error recovery
	inject_err 					    : in  STD_LOGIC_VECTOR (17 downto 0);
-- Link status data read out
	read_ce 						: in  STD_LOGIC;
	addr 							: in  STD_LOGIC_VECTOR (15 downto 0);
	status_data 				    : out  STD_LOGIC_VECTOR (63 downto 0);
	
--  Interface for internal logic	
	Resetp_serdes_clock				: in std_logic;
	Greset_CLK					    : in std_logic;	
	Clock_serdes_T					: in std_logic; -- clock from internal logic
	block_free					    : in std_logic;	-- almost one block is free
				
	FED_Evt_data					: out std_logic_vector(127 downto 0);
	FED_Evt_block_sz				: out std_logic_vector(15 downto 0);
	FED_Evt_wr_ena					: out std_logic;
	FED_Evt_start					: out std_logic; -- this block is the first for the current event
	FED_Evt_stop					: out std_logic; -- this block is the last for the current event  -- both can be set
	FED_Evt_end_blk					: out std_logic;  -- indicate end of the packet (max 4KBytes)
		-- interface slave to read and write
	Command_wr						: in std_logic;  
	Command_num						: in std_logic_vector(31 downto 0);
	Command_data_wr					: in std_logic_vector(63 downto 0);
	Command_data_rd					: out std_logic_vector(63 downto 0);
	cnt_evt						    : out std_logic;			-- pulse for each event (on sys_clk);
	cnt_pckt_rcv				    : in std_logic_vector(31 downto 0);
	cnt_pckt_snd				    : in std_logic_vector(31 downto 0);
		-- status
	retransmit_ena				    : in std_logic;
	status_state_build_p		    : in std_logic_vector(31 downto 0);
	status_state_core			    : in std_logic_vector(31 downto 0);
	Serdes_status				    : in std_logic_vector(63 downto 0)
 	);
	
end fed_itf;

architecture behavioral of fed_itf is

signal Gresetp_sysCLK			: std_logic;

type fill_blk_type is (	ST_START,
								read_fifo,
								update_para,
								dummy_a,
								dummy_b,
								dummy_c	-- dummy state implement du to the CRC check , which take 2 clock cylces more
							);
signal fill_blk :fill_blk_type;

component FIFO_sync 
	port(
		resetp					: in std_logic; -- active low
		clk_w					: in std_logic;
		wen						: in std_logic;
		dataw					: in std_logic_vector(129 downto 0);
		almost_f				: out std_logic;	-- active low
		clk_r					: in std_logic;
		datar					: out std_logic_vector(129 downto 0);
		ren						: in std_logic;
		empty					: out std_logic  -- active low
		);
end component;

signal resetp_IP_FIFO			: std_logic;
 
component Event_generator_lite is 
	port
	(
		usr_clk								: in std_logic;
		usr_rst_n							: in std_logic;
		usr_func_wr							: in std_logic_vector(31 downto 0); 
		usr_wen								: in std_logic;
		usr_data_wr							: in std_logic_vector(63 downto 0); 
			
		usr_func_rd					      	: in std_logic_vector(31 downto 0);  
		usr_data_rd					      	: out std_logic_vector(63 downto 0);
			
		dt_clock							: in std_logic;	-- max 190 Mhz for 25 Gb/s
		
		event_data_word						: out std_logic_vector(127 downto 0);
		event_ctrl							: out std_logic;		--  '1' when control word  ---- '0' when data word (Payload)
		event_data_wen						: out std_logic;		-- '1'  to validate a word (Header/ Trailer / Payload 
		backpressure						: in std_logic 			-- backpressured when '1'
		 
	 );
end component;

signal Event_generator_read							: std_logic_vector(63 downto 0);

component FED_fragment_CRC16_D128b is
  -- polynomial: x^16 + x^15 + x^2 + 1
  -- data width: 128
  -- convention: the first serial bit is Data[127]
 port (
		Data			: in std_logic_vector(127 downto 0);
		CRC_out 		: out std_logic_vector(15 downto 0);
		clk 			: in std_logic;
		clear_p			: in std_logic;
		enable 			: in std_logic
		);
end component;


component freq_measure 
generic (throughput			: string := "15.66");
port (
	resetn						: in std_logic;
	sysclk						: in std_logic;-- clock used by the FED to send data and to measure the backpressure
	base_clk					: in std_logic;-- clock base used to measure the sysclk
	frequency					: out std_logic_vector(31 downto 0)-- measure of the frequency)
);
end component;

signal G_rst_rd				    : std_logic; 
signal data_rd_C				: std_logic_vector(129 downto 0);
signal data_rd_out			    : std_logic_vector(127 downto 0);
signal data_rd_A				: std_logic_vector(129 downto 0);
signal data_rd_B				: std_logic_vector(129 downto 0);
signal start_evt_B				: std_logic;
signal stop_evt_B			    : std_logic;
signal end_frag				    : std_logic;
 

signal start_evt_C	   	 		: std_logic;
signal stop_evt_C	        	: std_logic;
signal End_pckt_C	        	: std_logic;
 
signal start_evt_out	    	: std_logic;
signal stop_evt_out	        	: std_logic;
signal End_pckt_out	        	: std_logic;

signal finish_blk				: std_logic;
signal empt_ff					: std_logic;
 
signal rd_ff_reg				: std_logic;
signal del_rd_ff				: std_logic_vector(2 downto 0);
signal blk_size				    : std_logic_vector(15 downto 0);
signal blk_full				    : std_logic;
signal blk_full_anti			: std_logic;
		
signal End_pckt_B			    : std_logic;
signal last_word				: std_logic;
signal sel_test_mode			: std_logic;
signal wen_tm					: std_logic;
signal data_tm					: std_logic_vector(127 downto 0);
signal uctrl_tm				    : std_logic;
signal backpressure_mux		    : std_logic;
signal wen_mux					: std_logic;
signal uctrl_mux				: std_logic;
signal data_mux				    : std_logic_vector(127 downto 0); 
signal int_status_reg				: std_logic_vector(31 downto 0);
signal LINKDOWN_cell			: std_logic;

-- use to pipe frgament during the CRC check
signal data_r_crc				: std_logic_vector(127 downto 0);
signal data_r_ena_crc			: std_logic_vector(3 downto 0);
signal wen_ra					: std_logic;

signal CRC_Rst					: std_logic;
signal CRC_Check				: std_logic;
signal ena_CRC					: std_logic;
signal ena_CRC_reg			    : std_logic;
signal CRC_frag				    : std_logic_vector(15 downto 0);
signal CRC_cmp					: std_logic_vector(15 downto 0); 
signal backpressure			    : std_logic;

-- statistic values
signal block_counter			: std_logic_vector(31 downto 0);
signal event_counter			: std_logic_vector(31 downto 0);
signal data_counter			    : std_logic_vector(63 downto 0);
signal Retransmit_counter	    : std_logic_vector(31 downto 0);
signal cnt_back_p				: std_logic_vector(31 downto 0);
signal FED_CRC_error_cnt	    : std_logic_vector(31 downto 0);
signal state_machine_status     : std_logic_vector(2 downto 0);


signal blk_size_reg			    : std_logic_vector(15 downto 0);


signal freq_measure_reg		    : std_logic_vector(31 downto 0);
signal rsyc_test_mode		    : std_logic_vector(1 downto 0);
signal rsyc_DAQON				: std_logic_vector(1 downto 0);

signal evt_ongoing			    : std_logic;
signal HD_dup					: std_logic;
signal TR_dup					: std_logic;

signal track_evt_num            : std_logic_vector(43 downto 0);
signal found_dup                : std_logic;

attribute mark_debug : string;
--attribute mark_debug of crc_cmp			: signal is "true";	
--attribute mark_debug of crc_frag			: signal is "true";
--attribute mark_debug of ena_CRC_reg			: signal is "true";
 
--***********************************************************
--**********************  BEGIN  ****************************
--***********************************************************
begin
  
Gresetp_sysCLK	<= not(Gresetn_sysCLK);  
  
-- Set the TEST mode and DAQ_ON with function (6)
-- this function will come from optical link send by DAQ side
process(Greset_CLK,Clock_serdes_T)
begin
	if Greset_CLK = '0' then
		sel_test_mode 		<= '0';
		LINKDOWN_cell		<= '0';
	elsif rising_edge(Clock_serdes_T) then
		if Command_num(6) = '1' and Command_wr = '1' then
			sel_test_mode 	<= Command_data_wr(31);
			LINKDOWN_cell	<= Command_data_wr(30);
		end if;
	end if;
end process;

-- resync the sel_test_mode // LinkDown_n to sys_clk
process(sys_clk)
begin
	if rising_edge(sys_clk) then
		rsyc_test_mode(1) <= rsyc_test_mode(0);
		rsyc_test_mode(0) <= sel_test_mode;
		
		rsyc_DAQON(1) 	<= rsyc_DAQON(0);
		rsyc_DAQON(0)	<= LINKDOWN_cell;
		
	END IF;
end process;

LinkDown_n 					<= rsyc_DAQON(1);

--multiplex data local and Event_gen status/data for read command coming from optical link send by DAQ side
process(Clock_serdes_T)
begin
	if rising_edge(Clock_serdes_T) then
		Command_data_rd(63 downto 32) 		<= (others => '0');
		if 		Command_num(6)  = '1' then
			Command_data_rd(31 downto 0)		<= int_status_reg;
		elsif 	Command_num(7)  = '1' then
			Command_data_rd						<= data_counter;
		elsif 	Command_num(8)  = '1' then
			Command_data_rd(31 downto 0)		<= event_counter;
		elsif 	Command_num(9)  = '1' then
			Command_data_rd(31 downto 0)		<= block_counter;
		elsif 	Command_num(10) = '1' then
			Command_data_rd(31 downto 0)		<= cnt_pckt_rcv;
		elsif 	Command_num(11) = '1' then
			Command_data_rd(31 downto 0)		<= status_state_core;
		elsif 	Command_num(12) = '1' then
			Command_data_rd(31 downto 0)		<= cnt_pckt_snd;
		elsif 	Command_num(13) = '1' then
			Command_data_rd(31 downto 0)		<= status_state_build_p;
		elsif 	Command_num(14) = '1' then
			Command_data_rd(31 downto 0)		<= cnt_back_p;
		elsif 	Command_num(15) = '1' then
			Command_data_rd(31 downto 0)		<= version;
		elsif 	Command_num(16) = '1' then
			Command_data_rd						<= Serdes_status;	
		elsif 	Command_num(17) = '1' then
			Command_data_rd(31 downto 0)		<= Retransmit_counter;	
		elsif 	Command_num(18) = '1' then
			Command_data_rd(31 downto 0)		<= freq_measure_reg;			
		else
			Command_data_rd(31 downto 0)		<= Event_generator_read(31 downto 0);
		end if;
	end if;
end process;

-- status going back to FED side
process(sys_clk)
begin
	if rising_edge(sys_clk) then
		status_data(63 downto 00)			<= (others => '0');
		if 		addr = x"0001" then
			status_data(31 downto 0) 		<= int_status_reg;
		elsif 	addr = x"0002" then
			status_data						<= data_counter;
		elsif 	addr = x"0003" then
			status_data(31 downto 0)		<= event_counter;
		elsif 	addr = x"0004" then
			status_data(31 downto 0)		<= block_counter;
		elsif 	addr = x"0005" then
			status_data(31 downto 0)		<= cnt_pckt_rcv;
		elsif 	addr = x"0006" then
			status_data(31 downto 0)		<= status_state_core;
		elsif 	addr = x"0007" then
			status_data(31 downto 0)		<= cnt_pckt_snd;
		elsif 	addr = x"0008" then
			status_data(31 downto 0)		<= status_state_build_p;
		elsif 	addr = x"0009" then
			status_data(31 downto 0)		<= cnt_back_p;
		elsif 	addr = x"000A" then
			status_data(31 downto 0)		<= version;
		elsif 	addr = x"000B" then	
			status_data 					<= Serdes_status;
		elsif 	addr = x"000C" then	
			status_data(31 downto 0)		<= Retransmit_counter;
		elsif    addr = x"000D" then
			status_data(31 downto 0)		<= FED_CRC_error_cnt;
		elsif		addr = x"000E" then
			status_data(31 downto 0)		<= freq_measure_reg;
		end if;
	end if;
end process;

--////////////////////////////////////////////////////////////////////////////////////////
--\\\\\			status   and 	statistic 	values						\\\\\\\\\\\\\\\\\\

-- status of internal signal 
int_status_reg(31) 				<= sel_test_mode;
int_status_reg(30) 				<= LINKDOWN_cell;
int_status_reg(29)				<= Backpressure;
int_status_reg(28)				<= '1' when block_free = '1' else '0';
int_status_reg(27 downto 7) 	<= (others => '0');
int_status_reg(6)				<= found_dup;
int_status_reg(5)				<= TR_dup;
int_status_reg(4)				<= HD_dup;
int_status_reg(3)				<= evt_ongoing;
int_status_reg(2 downto 0)		<= state_machine_status(2 downto 0);
 
-- measure the frequency used by the fed to send data
freq_measure_i1:freq_measure 
generic map (throughput 	=> throughput)
port map(
	resetn					=> Gresetn_sysCLK, 
	sysclk					=> sys_clk, -- clock used by the FED to send data and to measure the backpressure
	base_clk				=> Clock_serdes_T, 
	frequency				=> freq_measure_reg-- measure of the frequency)
);

--statistic counter for backpressure given to FED
process(Gresetn_sysCLK,sys_clk)
begin
	if Gresetn_sysCLK = '0'  then
		cnt_back_p			<= (others => '0');
	elsif rising_edge(sys_clk) then
		if backpressure_mux = '1' then
			cnt_back_p <= cnt_back_p + '1'; 
		end if;
	end if;
end process;

-- statistic retransmit counter
process(Greset_CLK,Clock_serdes_T)
begin
	 if Greset_CLK = '0' then
		Retransmit_counter <= (others => '0');
	 elsif rising_edge(Clock_serdes_T) then
		if retransmit_ena = '1' then
			Retransmit_counter	<= Retransmit_counter + '1';
		end if;
	 end if;
end process;	

-- statistic word received by FED/emulator counter
process(Gresetn_sysCLK,sys_clk)
begin
	 if Gresetn_sysCLK = '0' then
		data_counter	<= (others => '0');
	 elsif rising_edge(sys_clk) then
		if wen_mux = '1' then
			data_counter	<= data_counter + '1';
		end if;
	 end if;
end process;	

-- pulse to count for statistic
process(Gresetn_sysCLK,sys_clk)
begin
	if Gresetn_sysCLK = '0' then
		cnt_evt 	<= '0';
	elsif rising_edge(sys_clk) then
		cnt_evt 	<= '0';
		if end_frag = '1' then
			cnt_evt <= '1';
		end if;
	end if;
end process;	

-- statistic counter of FED crc error				
process(Greset_CLK,Clock_serdes_T)
begin
	if Greset_CLK = '0'  then
		FED_CRC_error_cnt		<= (others => '0');
	elsif rising_edge(Clock_serdes_T) then
		if ena_CRC_reg = '1' and crc_check = '1' then
			FED_CRC_error_cnt <= FED_CRC_error_cnt + '1'; 
		end if;
	end if;
end process;

--statistic  counter of the number of block used
process(Greset_CLK,Clock_serdes_T)
begin
	if Greset_CLK = '0' then
		block_counter	<= (others => '0');
	elsif rising_edge(Clock_serdes_T) then
		if blk_full = '1' or last_word = '1' then
			block_counter <= block_counter + '1';
		end if;
	end if;
end process;

--////////////////////////////////////////////////////////////////////////////////////////

--local Event generator used to test the link
generator_inst:if generator generate
	Event_generator_lite_i1:Event_generator_lite   
	port map
	(
		usr_clk								=> Clock_serdes_T      , 
		usr_rst_n							=> Greset_CLK          , 
		usr_func_wr							=> Command_num         , 
		usr_wen								=> Command_wr          , 
		usr_data_wr							=> Command_data_wr     , 
																	 
		usr_func_rd					      	=> Command_num         , 
		usr_data_rd					      	=> Event_generator_read, 
										 
		dt_clock							=> sys_clk             , -- max 190 Mhz for 25 Gb/s
											 
		event_data_word						=> data_tm             , 
		event_ctrl							=> uctrl_tm            , -- '1' when control word  ---- '0' when data word (Payload)
		event_data_wen						=> wen_tm              , -- '1'  to validate a word (Header/ Trailer / Payload 
		backpressure						=> backpressure_mux      -- backpressured when '1'
		 
	 );
end generate;

--******************************************************************************
-- multiplexer for event DATA
-- mux external (FED) and local data path (Event generator) ********************

wen_mux				<= 	  wen_tm		when rsyc_test_mode(1) = '1' and generator 	else 	LinkWe;
data_mux			<=    data_tm		when rsyc_test_mode(1) = '1' and generator	else 	LinkData;	 
uctrl_mux			<=    uctrl_tm		when rsyc_test_mode(1) = '1' and generator 	else    LinkCtrl; 

--******************************************************************************

--indicate the last word of the EVENT
end_frag	<= '1' when data_mux(127 downto 124) = x"A" and uctrl_mux = '1' else '0';

-- reset until SERDES RX clock is ready (reset realised) or by user
resetp_IP_FIFO	<= Gresetp_sysCLK or Resetp_serdes_clock;

-- internal FIFO used to change the DATA clock domain
internal_FIFO:FIFO_sync --Show A Head ON
port map
	(
		resetp					=> resetp_IP_FIFO,
		clk_w					=> sys_clk,
		wen						=> wen_mux,
		dataw(127 downto 0)		=> data_mux,
		dataw(128)				=> uctrl_mux,
		dataw(129)				=> end_frag,
		almost_f				=> backpressure_mux,
		
		clk_r					=> Clock_serdes_T,
		datar					=> data_rd_A,
		ren						=> rd_ff_reg,
		empty					=> empt_ff
	);

-- LinkAlmostFull LFF is valid only in no TEST mode otherwise ALLTIME active	(low)
Backpressure	<= '1' when rsyc_test_mode(1) = '1' else backpressure_mux;
LinkAlmostFull 	<= Backpressure;

--******************************************************************************
-- -******* This state machine is used to read the FIFO and fill the blocks in the CORE_LOGIC.VHD file
--state machine clock
FED_itf_state:process(Greset_CLK,Clock_serdes_T)
begin
	if Greset_CLK = '0' then
		fill_blk 							<= ST_START;
		state_machine_status				<= (others => '0');
	elsif rising_edge(Clock_serdes_T) then
		state_machine_status				<= (others => '0');
		
		Case fill_blk is
			-- wait data and free block from CORE_LOGIC.VHD
			
			when ST_START =>
				state_machine_status(0)		<='1';
				if empt_ff = '0' and block_free = '1' then	
					fill_blk 				<= read_fifo;
				end if;
			
			-- continue until the last word of the EVENT or until no free BLOCK
			when read_fifo =>
				state_machine_status(1)		<='1';
				if blk_full = '1' or last_word = '1' then  
					fill_blk 				<= update_para;
				end if;
				
			-- update flags and indicate end of block (block full or end_of_event)
			when update_para =>
				state_machine_status(2)		<='1';
				fill_blk 					<= dummy_a;
				
			when dummy_a =>
				fill_blk 					<= dummy_b;

			when dummy_b =>
				fill_blk 					<= dummy_c; -- take 3 clock to finish to close the buffer

			when dummy_c =>
				fill_blk 					<= ST_START;		
				 
			when others =>
				fill_blk 					<= ST_START;
		 end case;
	end if;
end process;
--******************************************************************************

last_word 		<= '1' when rd_ff_reg = '1' and  data_rd_A(129) = '1' else '0';	
	
G_rst_rd		<= '0' when Greset_CLK = '0' or empt_ff = '1' or blk_full = '1' else '1';

-- automatic read FIFO until the the last word of the EVENT or end of block (change state FILL_BLK)
process(G_rst_rd,Clock_serdes_T)
begin
	if G_rst_rd = '0' then
		rd_ff_reg <= '0';
	elsif rising_edge(Clock_serdes_T) then
		rd_ff_reg <= '0';
		if fill_blk = read_fifo and last_word = '0' then	
			rd_ff_reg <= '1';
		end if;
	end if;
end process;

 
--///////////////////////////////////////////////////////////////////////////
-- CRC check
process(Greset_CLK,Clock_serdes_T)
begin
	if Greset_CLK = '0' then
		CRC_Rst									<= '1';
		ena_crc									<= '0';
		event_counter							<= (others => '0');
		evt_ongoing								<= '0';
		TR_dup									<= '0';
		HD_dup									<= '0';		
		found_dup               				<= '0';		
		track_evt_num							<= (others => '0');		
	elsif rising_edge(Clock_serdes_T) then
		-- create the envelop of the event  + counter status
		if    data_rd_A(128) = '1' and data_rd_A(127 downto 120) = x"55" and rd_ff_reg = '1'  then
			event_counter						<= event_counter + '1';
			evt_ongoing							<= '1';
			if evt_ongoing	= '1' then
				HD_dup	<= '1';
			end if;
			if track_evt_num = data_rd_A(107 downto 64) then
			     found_dup <= '1';
			 end if;
			track_evt_num                  		<= data_rd_A(107 downto 64);
		end if;

		ena_crc									<= '0';
		if 	data_rd_A(129) = '1'  and rd_ff_reg = '1' then
			ena_crc								<= '1';
			evt_ongoing							<= '0';
			if evt_ongoing	= '0' then
				TR_dup	<= '1';
			end if;
		end if;
		
		-- reset the CRC machine between 2 fragments
		if ena_crc = '1' then			-- execute a reset when a Trailer appears
			CRC_Rst								<= '1';
		elsif data_rd_A(128) = '1' and data_rd_A(127 downto 120) = x"55" and rd_ff_reg = '1'  then
			CRC_Rst 							<= '0';
		end if;
		
	end if;
end process;

process(Clock_serdes_T)
begin
	if rising_edge(Clock_serdes_T) then
		
		data_r_crc 									<= data_rd_A(127 downto 0);	
		if   data_rd_A(129) = '1' and rd_ff_reg = '1' then 	--  End of fragment 
															--  remove the CRC and the DAQ status word in the trailer to compute the CRC							
			data_r_crc(31 downto 16) 				<= (others => '0');
			data_r_crc(15 downto 0)                 <= (others => '0');
			crc_frag								<= data_rd_A(31 downto 16);-- store the CRC to compare
		end if;			
		 
		wen_ra										<= rd_ff_reg;
		data_rd_B									<= data_rd_A;

		-- specify the place of the Trailer
		ena_CRC_reg									<= ena_CRC;

	end if;
end process;

--//////////////////////////////////////////////////////////////////////////////
-- calculate the CRC
i_crc_check:FED_fragment_CRC16_D128b 
    Port map(   
		clear_p			=> CRC_Rst,
		clk 			=> Clock_serdes_T,
		Data			=> data_r_crc,
		enable 			=> wen_ra,
		CRC_out 		=> crc_cmp
		);

-- compare the CRC received and the CRC calculated		
crc_check						<= '0' when crc_cmp = crc_frag else '1';
				
				
-- generate FLAG to indicate the beginning and the end of the event for each BLOCK
process(Greset_CLK,Clock_serdes_T)
begin
	if Greset_CLK = '0' then
		start_evt_B 		<= '0';
		stop_evt_B 			<= '0';
	elsif rising_edge(Clock_serdes_T) then
		if    data_rd_A(128) = '1' and data_rd_A(127 downto 120) = x"55" and rd_ff_reg = '1' then
			start_evt_B 	<= '1';
		elsif last_word = '1' then
			stop_evt_B 		<= '1';
		elsif fill_blk = update_para then --finish_blk = '1' then
			start_evt_B 	<= '0';
			stop_evt_B 		<= '0';
		end if;
	end if;
end process;	

-- compute the size of valid data in the BLOCK
process(Greset_CLK,Clock_serdes_T)
begin
	if Greset_CLK = '0' then
		blk_size 			<= (others => '0');
	elsif rising_edge(Clock_serdes_T) then
		if fill_blk = ST_START then	
			blk_size 		<= (others => '0');
		elsif rd_ff_reg = '1' and blk_full = '0' then
			blk_size 		<= blk_size + '1';
		end if;
	end if;
end process;


--flag when the BLOCK is full
-- the word is 4 by 4 128b-word
process(Greset_CLK,Clock_serdes_T)
begin
	if Greset_CLK = '0' then
		blk_full 				<= '0';
	elsif rising_edge(Clock_serdes_T) then
		if blk_size = x"00FF"  and rd_ff_reg = '1' then --blk_size = 0x200  
			blk_full 			<= '1';
		elsif End_pckt_B = '1' then	
			blk_full 			<= '0';
		end if;
	end if;
end process;

End_pckt_B					<= '1' when fill_blk = update_para else '0';

--Pipe data for the CRC check
process(Clock_serdes_T)
begin
	if rising_edge(Clock_serdes_T) then
		data_rd_C					<= data_rd_B;
		blk_size_reg				<= blk_size;
		start_evt_C					<= start_evt_B;
		stop_evt_C					<= stop_evt_B;
		End_pckt_C					<= End_pckt_B;
	end if;
end process;


-- exchange the CRC in the packet and set the CRC_Error bit (0 "OK" or 1 "ERROR")
process(Clock_serdes_T)
begin
	if rising_edge(Clock_serdes_T) then
		data_rd_out						<= data_rd_C(127 downto 0);
		
		if ena_CRC_reg = '1' then
			data_rd_out(31 downto 16) 	<= crc_cmp;				-- the CRC is all time exchange even when correct
			data_rd_out(0)	 			<= crc_check;           -- Flag to indicate if there is a error in the CRC
		end if;
		
		start_evt_out					<=	start_evt_C	;
		stop_evt_out					<=	stop_evt_C	; 
		End_pckt_out					<=	End_pckt_C	;  
		
	end if;
end process;

process(Clock_serdes_T)
begin	
	if rising_edge(Clock_serdes_T) then
		del_rd_ff(2 downto 1) 		<= del_rd_ff(1 downto 0);
		del_rd_ff(0)				<= rd_ff_reg;
	end if;
end process;

--Output value to Optical interface 
FED_Evt_block_sz						<= blk_size_reg;			-- number of data in the block ready to send
FED_Evt_data							<= data_rd_out;
FED_Evt_wr_ena							<= del_rd_ff(2);
FED_Evt_start							<= start_evt_out; 	-- flag is set if this block is the first of the event
FED_Evt_stop							<= stop_evt_out; 	-- flag is set if this block is the last of the event
FED_Evt_end_blk							<= End_pckt_out; 	-- flag is set at the end of the event 

end behavioral;