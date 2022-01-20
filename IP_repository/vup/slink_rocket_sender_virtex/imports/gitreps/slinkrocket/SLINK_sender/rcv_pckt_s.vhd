
------------------------------------------------------
-- Receive packet
--
--  Ver 1.00
--
-- Dominique Gigi May 2015
------------------------------------------------------
--  Version 1.00
--  
-- 
--  
------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
 

entity rcv_pckt_s is

port (
	resetn_clkR				: in std_logic;
	resetn_clkT				: in std_logic;
	Greset_clkR				: in std_logic;
	Greset_clkT				: in std_logic;	
	Clock_serdes_R			: in std_logic;
	Clock_serdes_T			: in std_logic;
				
	datai					: in std_logic_vector(127 downto 0); 	--- data and K bit send from SERDES
	val_wrd					: in std_logic;
	sop						: in std_logic;							-- indicates the start of a packet
	eop						: in std_logic;							-- indicates the end of a packet
				
	error_gen				: in std_logic; 						-- 1 will emulate an error in one ack packet
				
	rcv_cmd_num				: out std_logic_vector(63 downto 0);	-- command from DAQ
	rcv_cmd_data			: out std_logic_vector(63 downto 0);	-- data from  DAQ
	rcv_cmd_ena				: out std_logic; 						-- validate command
				
	seqnb 					: out std_logic_vector(30 downto 0);	-- seq numb from ack (received an ack)	
	ena_ack					: out std_logic;		
			
	INFO_packt				: out std_logic_vector(15 downto 0);
	cnt_pckt_rcv			: out std_logic_vector(31 downto 0)
 	);
	
end rcv_pckt_s;

architecture behavioral of rcv_pckt_s is

component Slink_packet_CRC16_D128b IS 
   PORT(           
			clock      	: IN  STD_LOGIC; 
			resetp     	: IN  STD_LOGIC; 
			data       	: IN  STD_LOGIC_VECTOR(127 DOWNTO 0); 
			data_valid 	: IN  STD_LOGIC; 
			eoc        	: IN  STD_LOGIC; 
			crc        	: OUT STD_LOGIC_VECTOR(15 DOWNTO 0); 
			crc_valid  	: OUT STD_LOGIC 
       );
end component; 
 

component resync_v4  
port (
	aresetn			: in std_logic;
	clocki			: in std_logic;
	clocko			: in std_logic;
	input			: in std_logic;
	output			: out std_logic
	);
end component; 

signal pipe_a				       : std_logic_vector(127 downto 0);
signal pipe_b				       : std_logic_vector(127 downto 0); 
signal pipe_val				       : std_logic;
	
signal SOF					       : std_logic_vector(2 downto 0);
signal EOF					       : std_logic_vector(0 downto 0);
 
signal stage				       : std_logic_vector(2 downto 0);
	
signal cmd_reg				       : std_logic_vector(63 downto 0); 
signal data_reg			           : std_logic_vector(63 downto 0); 
signal ena_cmd_reg		           : std_logic;  

signal ena_ack_reg		           : std_logic;	
	

signal seqnb_reg			       : std_logic_vector(30 downto 0);	
signal INFO_packt_reg		       : std_logic_vector(15 downto 0); 
	
signal cmp_crc				       : std_logic; 	
	
signal eoc					       : std_logic; 	
signal crc_val				       : std_logic_vector(15 downto 0);
signal crc_valid			       : std_logic; 	
signal crc_valid_delay		       : std_logic_vector(1 downto 0); 	
signal crc_correct		           : std_logic;
signal crc_to_be_check	           : std_logic_vector(15 downto 0);
signal end_check			       : std_logic;
signal cmd_pckt			           : std_logic;
signal ack_pckt			           : std_logic;
signal mem_error_gen		       : std_logic_vector(1 downto 0);
signal pack_counter		           : std_logic_vector(31 downto 0);

--attribute mark_debug : string;
--attribute mark_debug of cmd_reg				: signal is "true";	
--attribute mark_debug of data_reg			: signal is "true";	
--attribute mark_debug of ena_cmd_reg			: signal is "true";	
--attribute mark_debug of cmd_pckt			: signal is "true";	
--attribute mark_debug of stage				: signal is "true";	
--*******************************************************
--**************  BEGIN  ********************************
--*******************************************************
begin

--****** error gen ********
-- Error generator
--   no error gen implemented yet
process(resetn_clkR,Clock_serdes_R)
begin
	if resetn_clkR = '0' then
		mem_error_gen <= (others => '0');
	elsif rising_edge(Clock_serdes_R) then
		if SOF(0) = '1' then
			mem_error_gen(1) <= mem_error_gen(0);
		elsif crc_valid = '1' then
			mem_error_gen(1) <= '0';
		end if;
	
		if error_gen = '1' then
			mem_error_gen(0) <= '1';
		elsif SOF(0) = '1' then
			mem_error_gen(0) <= '0';
		end if;
	end if;
end process;
--*************************

--Pipe the start of frame
process(resetn_clkR,Clock_serdes_R)  
begin
	if resetn_clkR = '0' then
		SOF <= (others => '0');
	elsif rising_edge(Clock_serdes_R)  then
		
		SOF(0)				<= '0';
		if sop = '1' then 		--start
			SOF(0) 			<= '1';
		end if;
	end if;
end process;


-- Pipe data  
--  -- to calculate and check the CRC of the packet ,....
process(Clock_serdes_R)
begin
	if rising_edge(Clock_serdes_R) then 
		--second pipe
		pipe_b 					<= pipe_a; 
		if EOF(0) = '1' then
			pipe_b(127 downto 64) <= (others => '0'); --remove the CRC to compute the CRC
		end if;
		-- delay by 1 clock the WEN to calculate the CRC
		cmp_crc					<= pipe_val;

		-- first pipe
		pipe_a 					<= datai;
		pipe_val				<= val_wrd;
	end if;
end process;	

-- create a shift register of the START 
process(Clock_serdes_R)
begin
	if rising_edge(Clock_serdes_R) then
		stage(2 downto 1) 	<= stage(1 downto 0);
		stage(0) 			<= SOF(0);
	end if;
end process;
 
-- latch the CRC received in the packet
process(Clock_serdes_R)
begin
	if rising_edge(Clock_serdes_R) then
		if 	EOF(0) = '1' then
			crc_to_be_check	 <= pipe_a(79 downto 64);
		end if;
	end if;
end process;

-- check where is the CRC in the packet 
-- according the alignment of the data
process(resetn_clkR,Clock_serdes_R)
begin
	if resetn_clkR = '0' then
		EOF <= (others => '0');
	elsif rising_edge(Clock_serdes_R) then
		EOF(0) 			<= '0';
		if eop  ='1' then --End of frame
			EOF(0) <= '1';
		end if;
	end if;
end process;

EOC <= eop;

--********************************************************
--  instantiation to Compute the CRC

CRC_generate:Slink_packet_CRC16_D128b  
PORT MAP(           
			clock      	=> Clock_serdes_R,
			resetp     	=> SOF(0),
			data       	=> pipe_b,
			data_valid 	=> cmp_crc,
			eoc        	=> EOF(0),
			crc        	=> crc_val,
			crc_valid  	=> crc_valid
       );	   
--********************************************************

-- recover the values from the packet
-- Ack , rcv_cmd_num  ,

process(resetn_clkR,Clock_serdes_R)
begin
	if resetn_clkR = '0' then
		cmd_pckt		<= '0';
		ack_pckt		<= '0';
	elsif rising_edge(Clock_serdes_R) then
		if stage(0) = '1' then
			ack_pckt 							<= pipe_b(63);
			cmd_pckt							<= not(pipe_b(63));
		elsif end_check = '1' then	
			cmd_pckt							<= '0';
			ack_pckt							<= '0';
		end if;
	end if;
end process;

--recover values from the packet
--	sequence number
-- 	INFO
-- 	length
--	command
-- 	data
process(Clock_serdes_R)
begin
	if rising_edge(Clock_serdes_R) then
		if stage(0) = '1' then
			seqnb_reg 							<= pipe_b(62 downto 32);					
			INFO_packt_reg						<= pipe_b(31 downto 16); 
			
			cmd_reg					 			<= pipe_b(127 downto 64);
		end if;
		
		if stage(1) = '1'  then
			data_reg				 			<= pipe_b(63 downto 0);
		end if;

	end if;
end process;

--  validate or unvalidate the packet according the CRC check
process(resetn_clkR,Clock_serdes_R)
begin
if resetn_clkR = '0' then
	ena_cmd_reg <= '0';
	ena_ack_reg <= '0';
	end_check <= '0';
elsif rising_edge(Clock_serdes_R) then
	ena_cmd_reg <= '0';
	ena_ack_reg <= '0';
	end_check <= '0';
	if crc_valid_delay(1) = '1' then
		end_check <= '1';
		if  crc_correct = '1' then
			if ack_pckt = '1' then			-- received an Ack Packet
				ena_ack_reg <= '1';
			elsif cmd_pckt = '1' then		-- received a Command Packet
				ena_cmd_reg <= '1';
			end if;
		end if;
	end if;
end if;
end process;

-- statistic of acknowledge packet received 
process(Greset_clkR,Clock_serdes_R)
begin
	if Greset_clkR = '0' then
		pack_counter				<= (others => '0');
		
	elsif rising_edge(Clock_serdes_R) then
		if crc_valid_delay(1) = '1' then
			if  crc_correct = '1' then
				if ack_pckt = '1' then
					pack_counter	<= pack_counter + '1';
				end if;
			end if;
		end if;
	end if;
end process;		
		
		
process(Clock_serdes_R)
begin
	if rising_edge(Clock_serdes_R) then
		-- delay the CRC valid (from engine) to take time to compare
		crc_valid_delay(1)			<= crc_valid_delay(0);
		crc_valid_delay(0)			<= crc_valid;
		
		crc_correct 				<= '0';
		if crc_val = crc_to_be_check then
			crc_correct 			<= '1';
		end if;
	end if;
end process;

-- resynchronization between Clock_serdes_R domains  
resync_pulse_ack:resync_v4  
port map(
	aresetn			=> resetn_clkR,
	clocki			=> Clock_serdes_R,
	input			=> ena_ack_reg,
	clocko			=> Clock_serdes_T,
	output			=> ena_ack
	);
	
resync_pulse_cmd:resync_v4  
port map(
	aresetn			=> resetn_clkR,
	clocki			=> Clock_serdes_R,
	input			=> ena_cmd_reg,
	clocko			=> Clock_serdes_T,
	output			=> rcv_cmd_ena
	);  
	

rcv_cmd_num					<= cmd_reg;
rcv_cmd_data				<= data_reg; 
seqnb 				<= seqnb_reg;
INFO_packt			<= INFO_packt_reg;

cnt_pckt_rcv		<= pack_counter; -- count only the ack (not the command received

end behavioral;

