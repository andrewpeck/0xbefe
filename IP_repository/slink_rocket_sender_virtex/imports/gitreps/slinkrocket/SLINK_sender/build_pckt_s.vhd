------------------------------------------------------
-- encapsulate the data/ack/init for Opt Link
--
--  Ver 2.00
--
-- Dominique Gigi May 2015
------------------------------------------------------
--  Move the logic to 10Gb interface (XGMII) & 
--  !!!! ATTENTION la data event arrive 1 clock plus tard ... a tester!!!!!!!!!!!
-- 
--  
------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.mydefs.all;
 
entity build_pckt_s is

port (
	resetn_ClkT				    : in std_logic;
	Gresetn_ClkT				: in std_logic;
	Clock_serdes_T				: in std_logic;
				
	start_pckt				    : in std_logic; 						-- trigger the packet send
	init_pckt				    : in std_logic; 						-- indicates that the packet is a INIT packet
	ack_pckt					: in std_logic; 						-- indicates that the packet is a acknowledge packet
	data_pckt				    : in std_logic; 						-- indicates that the packet is a data packet
	data_evt					: in std_logic_vector(127 downto 0);	--data for data packet
	read_bck					: in std_logic_vector(63 downto 0); 	--data back for acknowledge packet
	Pckt_CMD				    : in std_logic_vector(15 downto 0); 	-- Command in the pcket
	Seq_nb					    : in std_logic_vector(30 downto 0); 	-- sequence number
	len_pckt					: in std_logic_vector(15 downto 0); 	-- length of the packet (for data packet only) other 0
	error_gen				    : in std_logic_vector(3 downto 0);
	rd_dt						: out std_logic;						-- request data for data packet only
	end_pckt					: out std_logic;
					
	Serdes_data_o				: out std_logic_vector(127 downto 0); 	--- data send to SERDES
	Serdes_Start_o				: out std_logic;
	Serdes_Stop_o				: out std_logic;
	Serdes_Val_Dwrd_o			: out std_logic;
	
	serdes_ready				: in std_logic;
	ST_START_state				: out std_logic;
	status_state			    : out std_logic_vector(31 downto 0);
	cnt_pckt_snd			    : out std_logic_vector(31 downto 0)
	);
	
end build_pckt_s;

architecture behavioral of build_pckt_s is

 type packet_type is (	ST_START,
						read_advc	  ,
						start_of_frame,
						data          ,
						last_bits	  ,
						CRC_end_frame , 
						gap0             
						);
signal packet:packet_type;
 
component Slink_packet_CRC16_D128b is
  -- polynomial: x^16 + x^15 + x^2 + 1
  -- data width: 128
  -- convention: the first serial bit is Data[127]
 port (
		clock      	: IN  STD_LOGIC; 
		resetp     	: IN  STD_LOGIC; 
		data       	: IN  STD_LOGIC_VECTOR(127 DOWNTO 0); 
		data_valid 	: IN  STD_LOGIC; 
		eoc        	: IN  STD_LOGIC; 
	
		crc        	: OUT STD_LOGIC_VECTOR(15 DOWNTO 0); 
		crc_valid  	: OUT STD_LOGIC 
		);
end component;

signal cmp_crc					: std_logic;
signal val_crc					: std_logic_vector(15 downto 0);
signal crc_valid				: std_logic;
signal end_crc					: std_logic;
signal pckt_type				: std_logic_vector(2 downto 0);
signal seqnb_mem				: std_logic_vector(31 downto 0);
signal len_mem					: std_logic_vector(15 downto 0); 
 
signal del_crc					: std_logic_vector(2 downto 0);
signal tmp_dt_crc				: std_logic_vector(127 downto 0);
signal pipe_dta		    		: std_logic_vector(127 downto 0);
signal pipe_dtb		    		: std_logic_vector(127 downto 0);
signal pipe_dtc		    		: std_logic_vector(127 downto 0);
  
signal pipe_vdwa				: std_logic;
signal pipe_vdwb				: std_logic;
signal pipe_vdwc				: std_logic;

signal pipe_start_a				: std_logic;
signal pipe_start_b				: std_logic;
signal pipe_start_c				: std_logic;

signal pipe_stop_a				: std_logic;
signal pipe_stop_b				: std_logic;
signal pipe_stop_c				: std_logic;

signal nxt_dt					: std_logic;
signal wc_val					: std_logic_vector(15 downto 0);

signal mem_error				:std_logic_vector(3 downto 0);
signal mem_error_gen			:std_logic_vector(3 downto 0);

signal cnt_pck					: std_logic_vector(31 downto 0);
signal status_state_cell		: std_logic_vector(31 downto 0);

signal data_tempo				: std_logic_vector(127 downto 0);

signal end_pckt_rg				: std_logic;
signal end_pckt_delay			: std_logic;
signal end_pckt_cell			: std_logic;

attribute mark_debug             		: string;
--attribute mark_debug of packet 			: signal is "true";
--attribute mark_debug of pipe_dta 		: signal is "true";
--attribute mark_debug of pipe_start_a 	: signal is "true";
--attribute mark_debug of pipe_stop_a 	: signal is "true";
--attribute mark_debug of pipe_vdwa		: signal is "true";

--*******************************************************
--**************  BEGIN  ********************************
--*******************************************************
begin 

--***************** error gen ****************
-- Error generator
-- the signal coming IN (pulse) is latched (mem_error)
-- this signal is used at the start of a packet build (reset mem_error at the same time) 
-- to create signal (mem_error_gen) which is set all over the packet build (and reset at the end)
-- 0 error on wc
-- 1 error on crc
-- 2 error on seq number
-- 3 error on frame 

process(Gresetn_ClkT,Clock_serdes_T)
begin
if Gresetn_ClkT = '0' then
	mem_error 		<= (others => '0');
	mem_error_gen 	<= (others => '0');
elsif rising_edge(Clock_serdes_T) then
	if error_gen /= "0000" then
		mem_error	<= error_gen;
	elsif start_pckt = '1' and data_pckt = '1' then
		mem_error	<= (others => '0');
	end if;
	
	if start_pckt = '1' and data_pckt = '1' then
		mem_error_gen	<= mem_error ;
	elsif del_crc(1) = '1'  then--and data_pckt = '1'
		mem_error_gen	<= (others => '0');
	end if;
end if;
end process;
--********************************************

--Initialize some values
	 --Packet type 	(001) INIT packet
	--				(010) data packet
	--				(100) ack packet
	-- Sequence number insert in the packet
	-- length of the packet
	
process(resetn_ClkT,Clock_serdes_T)
begin
	if resetn_ClkT = '0' then
		pckt_type <= (others => '0');
	elsif rising_edge(Clock_serdes_T) then
		if start_pckt = '1' then
			pckt_type 					<= "000";

			if init_pckt = '1' then
				pckt_type(0)			<= '1';
			elsif ack_pckt = '1' then
				pckt_type(2)			<= '1';
			elsif data_pckt = '1' then
				pckt_type(1)			<= '1';
			end if;
		end if;
	end if;
end process;

process(Clock_serdes_T)
begin
	if rising_edge(Clock_serdes_T) then
		if start_pckt = '1' then
			seqnb_mem(30 downto 0)		<= Seq_nb;
			seqnb_mem(31)	 			<= '0';
			len_mem						<= len_pckt;
			---create a packet to re-initialize the sequence number 
			if init_pckt = '1' then
				-- reinitialize the seq number to 0
				seqnb_mem 				<= (others => '0');
				-- in ack pack  len = 0
				len_mem					<= (others => '0');
				
			-- create an acknowledge packet
			elsif ack_pckt = '1' then
				--bit 31 of the seq_num indicates an acknowledge packet
				seqnb_mem(31)			<= '1';
				-- in ack pack  len = 0
				len_mem					<= (others => '0');
			end if;
		end if;
	end if;
end process;

-- state machine

state_M:process(Clock_serdes_T,resetn_ClkT)
begin
	if resetn_ClkT = '0' then
		packet 								<= ST_START;
		status_state_cell(10 downto 1)		<= (others => '0');
		status_state_cell(0)				<= ('1');
	elsif rising_edge(Clock_serdes_T) then
		 
			status_state_cell 				<= (others => '0');
			Case packet is
				-- wait for a packet to send
					
				when ST_START =>
					status_state_cell(0)	<= '1';
					-- start to build a packet when serdes is initialize
					-- and START_PCKT  initiates a packet build
					if start_pckt = '1' and serdes_ready = '1' then
						if data_pckt = '1' then 		-- data
							-- in a case of data packet (memory is registered) 
							-- we initiate the first read by this state M "read_advc"
							packet 			<= read_advc;
						else
							packet 			<= start_of_frame;
						end if;
					end if;
			 
				when read_advc => 
					if serdes_ready = '1' then
						packet 				<= start_of_frame;-- we register Memory to improve the timing
					end if;
					
				-- start the frame with a "START FRAME" + the SEQUENCE number +LSC/LDC_ID + LENGTH
				when start_of_frame =>  -- and seq_number
					status_state_cell(1)	<= '1';
					if serdes_ready = '1' then
						if 	pckt_type(0) = '1' then			-- INIT (short packet NXT last_bits)
							packet 			<= last_bits;
						elsif pckt_type(1) = '1' then 		-- DATA
							packet 			<= data;
						elsif pckt_type(2) = '1' then 		-- ACK (short packet NXT last_bits)
							packet 			<= last_bits;
						end if;
					end if;
					
				--	In case of a DATA packet we include datas until the end
				when data =>
					status_state_cell(4)	<= '1';
					if wc_val = x"0000" and serdes_ready = '1' then	 
						packet 				<= last_bits;
					end if;
				
				-- used to compute the last bits of the packet in the CRC
				when last_bits	=>
					if serdes_ready = '1' then
						packet 				<= CRC_end_frame;
					end if;
				-- conclude by the CRC	
				
				when CRC_end_frame =>
					status_state_cell(5)	<= '1';
					if serdes_ready = '1' then
						packet 				<= gap0;
					end if;

				-- include some gap between packet like in ETHERNET 	
				when gap0 =>
					status_state_cell(7)	<= '1';
					if end_pckt_cell = '1' then 
						packet 				<= ST_START;
					end if;
					 
				when others =>
					packet 					<= ST_START;
			 end case;
	end if;
end process;

ST_START_state				<= '1' when packet = ST_START else '0';

status_state				<= status_state_cell;
status_state(31 downto 11)	<= (others => '0');

--generate the pulse to read data to build the packet
	-- STATE in START   and START_PCKT  and DATA_PCKT (if a data packet)
	-- STATE in READ_ADVC
	-- STATE in START_OF_FRAME	(is a data packet)
	-- STATE in DATA
	
process(resetn_ClkT,Clock_serdes_T)
begin
if resetn_ClkT = '0' then	
	nxt_dt <= '0';
elsif rising_edge(Clock_serdes_T) then
	nxt_dt <= '0';
	if	((packet = ST_START and data_pckt = '1' and  start_pckt = '1')   or 
		  packet = read_advc  or  
		 (packet = start_of_frame and pckt_type(1) = '1') or 
		  packet = data												) then
		nxt_dt <= '1';
	end if;	
end if;
end process;

rd_dt 			<= '1' when nxt_dt = '1' and serdes_ready = '1'  else '0';


process(resetn_ClkT,Clock_serdes_T)
begin
if resetn_ClkT = '0'  then
	wc_val <= (others => '0');
elsif rising_edge(Clock_serdes_T) then
	-- count down to transfer the length need
	if nxt_dt = '1'  and serdes_ready = '1' then	
		wc_val <=  wc_val - '1';
	-- load the packet size
	elsif start_pckt = '1' then
		wc_val <= len_pckt;
	end if;
end if;
end process;

-- generate a pulse for end of packet
process(Clock_serdes_T)
begin
	if rising_edge(Clock_serdes_T) then
		end_crc			<= '0';
		if pckt_type(1) = '1' then 		-- data
			if packet = last_bits then
				end_crc		<= '1';
			end if;
		else
			if packet = start_of_frame then
				end_crc		<= '1';
			end if;		 
		end if;
	end if;
end process;


-- generate data packet value  
process(Clock_serdes_T)
variable status_wrd			: std_logic_vector(63 downto 0);
variable local_v			: std_logic_vector(127 downto 0);
begin
	if rising_edge(Clock_serdes_T) then
		--pipe_dta 							<= (others => '0'); --ST_START STATE
		status_wrd 								:= read_bck; --status word; this value may change in futur

		cmp_crc									<= '0';
		if serdes_ready = '1' then	
			pipe_start_a						<= '0';
			pipe_stop_a							<= '0';
			
			if packet = start_of_frame then --start packet
				--indicates the start of the packet
				pipe_start_a					<= '1';
				-- tempo is used to transfer 64 bit data fragment on next data packet value 
				data_tempo						<= data_evt(127 downto 0);
				
				-- value build
				if    pckt_type(0) = '1' then --INIT Packet
					local_v(127 downto 64) 		:= (others => '0');
					local_v(31 downto 16) 		:= x"0000";
					local_v(15 downto  0) 		:= x"0000";
				elsif pckt_type(1) = '1' then --DATA Packet
					local_v(127 downto 64) 		:= data_evt(63 downto 0);
					local_v(31 downto 16) 		:= Pckt_CMD;
					local_v(15 downto  0) 		:= len_mem;
				elsif pckt_type(2) = '1' then --ACK Packet
					local_v(127 downto  64) 	:= status_wrd;
					local_v(31 downto 16) 		:= x"0000";
					local_v(15 downto  0) 		:= x"0000";
				end if;
			
				local_v(63 downto 32)			:= Seqnb_mem;
				
							 
				-- used to compute the CRC
				tmp_dt_crc						<= local_v;
				cmp_crc							<= '1';
				
				-- data packet value
				pipe_dta						<= local_v;
				
			elsif packet = data then
				data_tempo						<= data_evt(127 downto 0);
				
				tmp_dt_crc(127 downto 64)		<= data_evt(63 downto 0);
				tmp_dt_crc( 63 downto 0)		<= data_tempo(127 downto 64);
				cmp_crc							<= '1';
							
				pipe_dta(127 downto 64)			<= data_evt(63 downto 0);
				pipe_dta( 63 downto 0)			<= data_tempo(127 downto 64);
				
			elsif packet = last_bits then
				--indicates end of packet
				pipe_stop_a						<= '1';
			
				tmp_dt_crc(127 downto 0)		<= (others => '0');
				pipe_dta(127 downto 0)			<= (others => '0'); 
				if pckt_type(1) = '1' then 							 
					tmp_dt_crc(63 downto 0)		<= data_tempo(127 downto 64);
					pipe_dta( 63 downto 00)		<= data_tempo(127 downto 64);
				
				end if;
                cmp_crc							<= '1';
			end if;
		end if;
	end if;
end process;
 
-- compute the CRC on fly (64 bit data => result in 32 bit)
CRC_engine:Slink_packet_CRC16_D128b   
PORT MAP(          
		clock      	=> Clock_serdes_T, 
		resetp     	=> start_pckt, 
		data       	=> tmp_dt_crc, 
		data_valid 	=> cmp_crc, 
		eoc        	=> end_crc, 
		crc        	=> val_crc, 
		crc_valid  	=> crc_valid 
       );	

-- create a delay to introduce the CRC result in the packet 
process(Clock_serdes_T)
begin
	if rising_edge(Clock_serdes_T) then
		if serdes_ready = '1' then
			del_crc(2 downto 1) <= del_crc(1 downto 0);
			
			del_crc(0)		 	<= '0';
			if packet = CRC_end_frame then
				del_crc(0) 		<= '1';
			end if;
		end if;
	end if;
end process;

--pipe data packet until the CRC is ready 
process(resetn_ClkT,Clock_serdes_T)
begin
	if resetn_ClkT = '0' then 
		pipe_vdwc      <= '0';
		pipe_vdwb      <= '0';
		pipe_vdwa      <= '0';
		pipe_start_c   <= '0';
		pipe_start_b   <= '0';
		pipe_stop_c    <= '0';
		pipe_stop_b    <= '0';
		pipe_dtc	   <= (others => '0');
		pipe_dtb	   <= (others => '0');
	elsif rising_edge(Clock_serdes_T) then

		if serdes_ready = '1' then
			-- START and STOP of the packet
			pipe_start_c		<= pipe_start_b;
			pipe_start_b		<= pipe_start_a;
		
			pipe_stop_c			<= pipe_stop_b;
			pipe_stop_b			<= pipe_stop_a; 			
		
			-- data packet valid
			pipe_vdwc 			<= pipe_vdwb;
			pipe_vdwb 			<= pipe_vdwa;
			if pckt_type(1) = '1' then  
				pipe_vdwa 		<= nxt_dt;
			else	
				pipe_vdwa		<= '0';
				if packet = start_of_frame or packet = last_bits then
					pipe_vdwa	<= '1';
				end if;
			end if;
			 
			-- data packet
			pipe_dtc			<= pipe_dtb;
			pipe_dtb			<= pipe_dta;
			if del_crc(0) = '1' then
				pipe_dtc(79 downto 64)	<= val_crc;
			end if;
		end if;
	end if;
end process;

-- generate the end of packet create
process(resetn_ClkT,Clock_serdes_T)
begin
	if resetn_ClkT = '0' then
		end_pckt_rg 	<= '0';
		end_pckt_cell 	<= '0';
		end_pckt_delay 	<= '0';
	elsif rising_edge(Clock_serdes_T) then
	
		end_pckt_cell		<= '0';
		if end_pckt_rg = '0' and end_pckt_delay = '1' then
			end_pckt_cell	<= '1';
		end if;
		
		end_pckt_delay		<= end_pckt_rg;
		end_pckt_rg			<= '0';
		if  del_crc(0) = '1' then
			end_pckt_rg		<= '1';
		end if;
	end if;
end process;

end_pckt	<= end_pckt_cell;

--- statistic counter for number of packet sent
process(Gresetn_ClkT,Clock_serdes_T)
begin
	if Gresetn_ClkT = '0' then
		cnt_pck		<= (others => '0');
	elsif rising_edge(Clock_serdes_T) then
		if  end_crc = '1' and pckt_type(1) = '1' then
			cnt_pck	<= cnt_pck + '1';
		end if;
	end if;
end process;
cnt_pckt_snd						<= cnt_pck;

-- output to SERDES (not yet done structure the 64/66 encoding)
Serdes_data_o						<= pipe_dtc; 
Serdes_Val_Dwrd_o					<= '1' when pipe_vdwc = '1' and  serdes_ready = '1' else '0';
Serdes_Start_o						<= pipe_start_c;
Serdes_Stop_o						<= pipe_stop_c;
 
end behavioral;