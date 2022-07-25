
LIBRARY ieee;

USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

 
-- generate data in function INPUT request.
-- It will generate data and check the almost full of the stream buffer
 
--ENTITY-----------------------------------------------------------
entity Event_generator_lite is 
	generic (
		Event_generator_lite_control				: integer := 0;
		Event_generator_lite_evt_num				: integer := 1;
		Event_generator_lite_BX_SOURCE				: integer := 2;
		Event_generator_lite_length					: integer := 3;
		Event_generator_lite_time_bwt_frag			: integer := 4; 
		Event_generator_lite_trigger_counter		: integer := 5 
	);
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
		event_ctrl							: out std_logic;		-- '1' when control word  ---- '0' when data word (Payload)
		event_data_wen						: out std_logic;		-- '1'  to validate a word (Header/ Trailer / Payload 
		backpressure						: in std_logic 			--  backpressured when '1'
		 
	 );
end Event_generator_lite;

--ARCHITECTURE------------------------------------------------------
architecture behavioral of Event_generator_lite is
 
COMPONENT FED_fragment_CRC16_D128b is
port (
		Data			: in std_logic_vector(127 downto 0);
		CRC_out 		: out std_logic_vector(15 downto 0);
		clk 			: in std_logic;
		clear_p			: in std_logic;
		enable 			: in std_logic
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
 

COMPONENT resync_v4 is
	port (
		aresetn			: in std_logic;
		clocki			: in std_logic;	
		input			: in std_logic;
		clocko			: in std_logic;
		output			: out std_logic
		);
end COMPONENT;

attribute mark_debug : string;
   
signal evt_size 													    : std_logic_vector(23 downto 0);
signal Event_size_mem													: std_logic_vector(23 downto 0);
signal evt_num	 													    : std_logic_vector(43 downto 0);
signal evt_num_cnt 													    : std_logic_vector(43 downto 0);
signal load_evt_num 												    : std_logic;
signal load_evt_num_resync											    : std_logic;
signal evt_BX	 													    : std_logic_vector(31 downto 0);
signal evt_Source 													    : std_logic_vector(31 downto 0);   
signal gen_run 													        : std_logic;
signal gen_run_async											        : std_logic;
signal gen_run_resync											        : std_logic_vector(3 downto 0) := "0000";
signal time_wait 													    : std_logic_vector(31 downto 0);
 
signal counter_wc												        : std_logic_vector(23 downto 0); 
signal counter_timer												    : std_logic_vector(31 downto 0);
signal Start_evt												        : std_logic;
signal Event_ongoing											        : std_logic;
signal end_evt														    : std_logic;
signal end_evt_delay												    : std_logic_vector(1 downto 0); 
signal trigger_pulse												    : std_logic;

signal event_run													    : std_logic; 
signal event_run_cell												    : std_logic; 

signal single_trigger												    : std_logic;
signal single_trigger_resync										    : std_logic; 
signal Generate_internal_trigger										: std_logic;  
 
signal data_o_rg			 										    : std_logic_vector(63 downto 0);
signal dt_rstn															: std_logic; 
  
signal data_gen_counter													: std_logic_vector(127 downto 0);
signal event_data_word_reg												: std_logic_vector(127 downto 0);
signal event_ctrl_reg													: std_logic;
signal event_data_wen_reg												: std_logic;
signal event_data_crc_ena												: std_logic;

signal event_data_crc_result											: std_logic_vector(15 downto 0);
signal reset_crc														: std_logic;
   
signal trigger_counter													: std_logic_vector(31 downto 0); 
 
signal Evt_Header														: std_logic_vector(127 downto 0);
signal Evt_Trailer														: std_logic_vector(127 downto 0);
 
attribute ASYNC_REG						: string;
attribute ASYNC_REG of gen_run_async : signal is  "TRUE"; 

--attribute mark_debug of event_data_word_reg			: signal is "true";	
--attribute mark_debug of event_data_wen_reg			: signal is "true";
 	
--***************************************************************** 
--      Code start HERE
--***************************************************************** 
 begin 
   
 --- control process to set parameters
 process(usr_rst_n,usr_clk)
 begin
	if usr_rst_n = '0' then
		evt_size						<= (others => '0');
		single_trigger					<= '0'; 
		load_evt_num					<= '0';  
		gen_run                         <= '0';
		time_wait                       <= (others => '0');
	elsif rising_edge(usr_clk) then  
		single_trigger					<= '0'; 
		load_evt_num					<= '0'; 
		
		if usr_wen = '1' then
			-- start the generator
					
			if usr_func_wr(Event_generator_lite_control ) =  '1'   then
				gen_run 						<= usr_data_wr(0);		-- generate data in loop
				single_trigger					<= usr_data_wr(1);		-- generate 1 trigger
 
			end if;
			
			if usr_func_wr(Event_generator_lite_evt_num 	) =  '1'    then 
				load_evt_num					<= '1';
			end if;
			
			--set the event fragment size (in bytes  aligned on 0x10 (16 bytes: event word size)
			if usr_func_wr(Event_generator_lite_length 	) =  '1'    then
				evt_size 						<= usr_data_wr(23 downto 0);			
			end if;
  
  			-- set the time between two fragment
			if usr_func_wr( Event_generator_lite_time_bwt_frag) =  '1'   then
				time_wait						<= usr_data_wr(31 downto 0);			
			end if;			
			
 
		end if;
	end if;
 end process;
 
  process(usr_rst_n,usr_clk)
 begin
	if rising_edge(usr_clk) then  
 
		if usr_wen = '1' then
 
			--set the event fragment size (in bytes  aligned on 0x10 (16 bytes: event word size)
			if usr_func_wr(Event_generator_lite_evt_num 	) =  '1'    then
				evt_num 						<= usr_data_wr(43 downto 0); 
			end if;
			
			--set the event BX and source#
			if usr_func_wr(Event_generator_lite_BX_SOURCE ) =  '1'    then
				evt_BX							<= usr_data_wr(31 downto 0);			
				evt_Source						<= usr_data_wr(63 downto 32);			
			end if;			
 
		end if;
	end if;
 end process;
 -- atstic value read back by conrtoller (PCIe)
 process(usr_clk)
 begin
	if rising_edge(usr_clk) then  
		data_o_rg								<= (others => '0');
		
		if 			usr_func_rd(Event_generator_lite_control ) =  '1' then
			data_o_rg(0)					<= gen_run;	
			data_o_rg(1)					<= single_trigger;	
			data_o_rg(2)					<= event_run_cell;	
			data_o_rg(3)					<= backpressure;	 
			
		elsif		usr_func_rd(Event_generator_lite_length ) =  '1' then
			data_o_rg(23 downto 0)			<= evt_size; 
		elsif 		usr_func_rd(Event_generator_lite_evt_num ) = '1'  then	
			data_o_rg(43 downto 0)			<= evt_num; 
		elsif 		usr_func_rd(Event_generator_lite_BX_SOURCE ) = '1'  then	
			data_o_rg(31 downto 0)			<= evt_BX;
			data_o_rg(63 downto 32)			<= evt_Source; 
		elsif 		usr_func_rd(Event_generator_lite_time_bwt_frag ) = '1'  then	
			data_o_rg(31 downto 0)			<= time_wait; 
		elsif 		usr_func_rd(Event_generator_lite_trigger_counter ) = '1'  then	
			data_o_rg(31 downto 0)			<= trigger_counter;  
		end if;

	end if;
 end process;
  
usr_data_rd			<= data_o_rg;
 
--***************************************************************
-- resync signals

resync_rst_i1:resetn_resync 
port map(
	aresetn				=> usr_rst_n,
	clock				=> dt_clock	,
	Resetn_sync			=> dt_rstn	 
	);
 
resync_pulse_trg:resync_v4  
		port map(
			aresetn		=> usr_rst_n, 
			clocki		=> usr_clk,	
			input		=> single_trigger,
			clocko		=> dt_clock,
			output		=> single_trigger_resync 
			);	
				
resync_pulse_ld:resync_v4  
		port map(
			aresetn		=> usr_rst_n,
			clocki		=> usr_clk,	
			input		=> load_evt_num,
			clocko		=> dt_clock,
			output		=> load_evt_num_resync 
			);	
 
process(dt_clock)
begin
	if rising_edge(dt_clock) then
		gen_run_resync(3 downto 1) 	<= gen_run_resync(2 downto 0);
		gen_run_resync(0)			<= gen_run_async;
		
		gen_run_async	 <= '0';
		if gen_run = '1' then
			gen_run_async <= '1';
		end if;
	end if;
end process;	
 
 --*****************************************************************
 -- generator of fragment

 process(dt_rstn, dt_clock)
 begin
	if dt_rstn = '0' then
		counter_wc			<= (others => '0');
		event_run_cell		<= '0';
		event_run			<= '0';
		end_evt 			<= '0';
		Start_evt			<= '0';
		Event_ongoing		<= '0';
		reset_crc			<= '0';
		evt_num_cnt			<= (others => '0');
		trigger_counter		<= (others => '0');
	elsif rising_edge(dt_clock) then
		end_evt 				<= '0';
		-- specify the end of event
		if	counter_wc <= x"00000010" and backpressure = '0' and event_run_cell = '1' then
			end_evt 			<= '1';
			event_run_cell		<= '0';
		elsif  Generate_internal_trigger = '1' then
			event_run_cell		<= '1';						-- start the gragment generator
		end if;		
	
	---
		event_run				<= '0';
		reset_crc				<= '0'; -- reset the CRC computing
		if counter_wc > x"00000010" and backpressure = '0' and event_run_cell = '1' then
			-- event ongoing state
			counter_wc			<= counter_wc - x"10";		-- event word is 128 bit	
			event_run			<= '1';			
			
			-- start the event
		elsif Generate_internal_trigger = '1' then
			reset_crc			<= '1';
			counter_wc		    <= evt_size;			-- load the size 
			Event_size_mem	    <= evt_size;			-- load the size 

		end if;
	---	
		-- increment the event number for each trigger
		if load_evt_num_resync = '1' then
			evt_num_cnt		<= evt_num;
		elsif end_evt = '1'  then
			evt_num_cnt		<= evt_num_cnt + '1';
		end if;
		
		--define the Event Header
		if 		Event_run = '1' then
			Start_evt		<= '1';
		elsif 	end_evt = '1' then
			Start_evt		<= '0';
		end if; 
		
		-- define a signal which stays ON during the Event "Envelop" 
		if Generate_internal_trigger = '1' then
			Event_ongoing	<= '1';
		elsif  end_evt = '1'  then
			Event_ongoing	<= '0';
		end if;
		
		-- Count and uncount the trigger  (trigger   and End of envent)
		if 		( trigger_pulse = '1' or single_trigger_resync = '1') and end_evt = '0'    then
			trigger_counter	<= trigger_counter + '1';
		elsif	( trigger_pulse = '0' and single_trigger_resync = '0') and end_evt = '1' then
			trigger_counter	<= trigger_counter - '1';
		end if;
		
	end if;
 end process;
 
 
 process(dt_clock)
 begin
 	if rising_edge(dt_clock) then 
 		Generate_internal_trigger		<= '0';
		if  trigger_counter /= x"00000000"  and Event_ongoing = '0' then
			Generate_internal_trigger	<= '1';
		end if;
 	end if; 
 end process;
 

 --********************************************************************
 --time wait between two fragments
  process(dt_rstn, dt_clock)
 begin
	if dt_rstn = '0' then
		counter_timer		<= (others => '0');
	elsif rising_edge(dt_clock) then
		-- at the end of a fragment (load the counter_timer
		if end_evt = '1' and gen_run_resync(3) = '1'then
			counter_timer	<= time_wait;
			
		-- timer_counter count down when not NULL
		elsif	counter_timer >= x"00000001" then
			counter_timer	<= counter_timer - '1';
		end if;
		
		trigger_pulse 		<= '0';
		-- in  loop mode generate a 1st trigger with the controller command + automatic trigger after counter_timerout
		if	(counter_timer = x"00000001" and gen_run_resync(3) = '1') or (gen_run_resync(2) = '1' and gen_run_resync(3) = '0') then
			trigger_pulse 	<= '1';
		end if;
	end if;
 end process; 
 --******************************************************************
--not a random data
process(dt_clock)
begin
    if rising_edge(dt_clock) then
        if event_run = '1' and Start_evt = '0'  then
            data_gen_counter    <= (others => '0');
         elsif event_run = '1' then
            data_gen_counter    <= data_gen_counter + '1';
         end if;
    end if;
end process;  
  	
--*****************************************************************
--   HEADER and TRAILER

Evt_Header(127 downto 120) 		<= x"55";
Evt_Header(119 downto 116)      <= x"1";
Evt_Header(115 downto 108) 		<= x"00";
Evt_Header(107 downto 064) 		<= evt_num_cnt;
Evt_Header(063 downto 057) 		<= "0000000";
Evt_Header(056) 		        <= '1';          -- Emulator Fragment
Evt_Header(055 downto 048) 		<= x"00";        -- Physics type
Evt_Header(047 downto 032) 		<= x"0000";      -- L1A type & content
Evt_Header(031 downto 000) 		<= evt_Source;
 			 
Evt_Trailer(127 downto 120) 	<= x"AA";
Evt_Trailer(119 downto 096) 	<= x"000000";
Evt_Trailer(095 downto 076) 	<= Event_size_mem(23 downto 4);
Evt_Trailer(075 downto 064) 	<= x"000";
Evt_Trailer(063 downto 032) 	<= x"00000000";
Evt_Trailer(031 downto 016) 	<= event_data_crc_result;
Evt_Trailer(015 downto 000) 	<= x"0000"; 
	
--*****************************************************************  	
 
 process(dt_rstn, dt_clock) 
 begin
	if dt_rstn = '0'then
		
	elsif rising_edge(dt_clock) then
		event_ctrl_reg		<= '0';
		event_data_wen_reg	<= '0';
		event_data_crc_ena	<= '0';
		if event_run = '1' and Start_evt = '0' then
			event_ctrl_reg 							<= '1';
			event_data_word_reg 				 	<= Evt_Header;
			event_data_wen_reg						<= '1';
			event_data_crc_ena						<= '1';

		elsif end_evt	 = '1' then
			event_data_word_reg(127 downto 032) 	<= Evt_Trailer(127 downto 032);
			event_data_word_reg(031 downto 016) 	<= x"0000";--event_data_crc_result;
			event_data_word_reg(015 downto 000) 	<= Evt_Trailer(015 downto 000);
			event_data_crc_ena						<= '1'; 
		
		elsif end_evt_delay(1)	 = '1' then
			event_ctrl_reg 							<= '1';
			event_data_word_reg					 	<= Evt_Trailer;
			event_data_wen_reg						<= '1'; 
			
		elsif event_run = '1' then

			event_data_word_reg(127 downto 96) 		<= evt_num_cnt(31 downto 0);
			event_data_word_reg(95 downto 000) 		<= data_gen_counter(95 downto 0);
			event_data_wen_reg						<= '1';
			event_data_crc_ena						<= '1';
		end if;		
	end if;
 end process;
 
 
 process(dt_clock)
 begin
	if rising_edge(dt_clock) then
		end_evt_delay(1) 			<= end_evt_delay(0);
		end_evt_delay(0)			<= end_evt;
	end if;
 end process;
 
 
 -- CRC compute
CRC_i1:FED_fragment_CRC16_D128b  
port map(
	clear_p		=> reset_crc,
	clk 		=> dt_clock,
	Data		=> event_data_word_reg,
	enable 		=>  event_data_crc_ena,
	CRC_out 	=> event_data_crc_result 
	);
 

 
 --**********************************************************************
 --output
 
 event_data_word	<= event_data_word_reg;	
 event_ctrl		    <= event_ctrl_reg;		
 event_data_wen	    <= event_data_wen_reg;	
 
 
 
end behavioral;