------------------------------------------------------
-- Core logic 
--
--  Ver 1.00
--
-- Dominique Gigi May 2015
------------------------------------------------------
--   
--  
-- 
--  
------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
 

entity Core_logic is
generic( time_out_val		        : std_logic_vector(15 downto 0) := x"0200";
		 interval_retrans 	    	: std_logic_vector(19 downto 0) := x"186A0");
port (
	resetn_clk					    : in std_logic;
	Gresetn_clk					    : in std_logic;
	Clock_serdes_T					: in std_logic; -- serdes clock 100 Mhz)
		-- interface from the FED block	
	FED_Evt_data						: in std_logic_vector(127 downto 0);
	FED_Evt_wr_ena							    : in std_logic; 
	FED_Evt_start					    : in std_logic;
	FED_Evt_stop						: in std_logic;
	
	FED_Evt_block_sz				    : in std_logic_vector(15 downto 0);
	FED_Evt_end_blk					    : in std_logic;
	block_free					    : out std_logic;
	req_reset_resync			    : out std_logic;
		-- interface to the SERDES OUT (send part)
	SERDES_BackPressure		        : in std_logic;							-- indicate that the packet is not yet send (BACKpressure) mainly the case when the output is less then 4 links
	start_pckt					    : out std_logic; 						-- trigger the packet send
	init_pckt					    : out std_logic; 						-- indicates that the packet is a INIT packet
	ack_pckt						: out std_logic; 						-- indicates that the packet is a acknowledge packet
	data_pckt					    : out std_logic; 						-- indicates that the packet is a data packet
	data_evt						: out std_logic_vector(127 downto 0);	--data for data packet
	status						    : out std_logic_vector(63 downto 0); 	--status data for acknowledge packet
	Pckt_CMD					    : out std_logic_vector(15 downto 0); 	-- Command in the pcket
	Seq_nb						    : out std_logic_vector(30 downto 0); 	-- sequence number
	len_pckt						: out std_logic_vector(15 downto 0); 	-- length of the packet (for data packet only) other 0
	rd_dt							: in std_logic;
	end_snd_pckt				    : in std_logic;
	ST_START_state					    : in std_logic;
	serdes_init					    : in std_logic;
		-- interface to the SERDES IN (receiver part)
	rcv_cmd_num						: in std_logic_vector(63 downto 0);		-- command from MOL
	rcv_cmd_data					: in std_logic_vector(63 downto 0);		-- data from MOL
	rcv_cmd_ena						: in std_logic; 						-- validate command
	ena_ack						    : in std_logic;		
	seqnb_rcv 					    : in std_logic_vector(30 downto 0);		-- seq numb from cmd (need an ack) / seq number for ack
	retransmit					    : out std_logic;
		-- interface slave to read and write
	Command_wr						: out std_logic;  
	Command_num						: out std_logic_vector(31 downto 0);
	Command_data_wr					: out std_logic_vector(63 downto 0);
	Command_data_rd					: in std_logic_vector(63 downto 0); 	-- from fed_itf block
	status_state				    : out std_logic_vector(31 downto 0)
	);
end Core_logic;

--#####################################################################################
--Architecture
architecture behavioral of Core_logic is

COMPONENT Memory is
port 	(
		clock	: in std_logic;
		
		addr_w	: in std_logic_vector(9 downto 0);
		data_w	: in std_logic_vector(127 downto 0);
		wen		: in std_logic;
		
		addr_r	: in std_logic_vector(9 downto 0);
		ren		: in std_logic;
		data_r	: out std_logic_vector(127 downto 0)
	); 
END COMPONENT;	
	
 

signal add_w_cnt				    : std_logic_vector(7 downto 0);
signal block_w_add			        : std_logic_vector(1 downto 0);
signal add_r_cnt				    : std_logic_vector(7 downto 0);
signal block_r_add			        : std_logic_vector(1 downto 0);
		
signal blk_wr					    : std_logic_vector(3 downto 0); -- indicate the block used to write data
signal blk_rd					    : std_logic_vector(3 downto 0); -- indicate the block used to read data
signal blk_time_out			        : std_logic_vector(3 downto 0); -- used to check the time out value
signal time_out_reach 		        : std_logic_vector(3 downto 0); -- check is timer is
	
signal reset_bar 				    : std_logic;
	
	
signal FULL_block				    : std_logic;

type  descript is
	record
		seq_num 					: std_logic_vector(30 downto 0);	--- sequence number of the block
		time_out					: std_logic_vector(15 downto 0); -- timer value to be reached to retransmit the block
		time_out_ON   			    : std_logic;							-- valid the timeOUT
		command 					: std_logic_vector(15 downto 0); --stpecify is the block is start block middle block or end block + reserved bits
																		-- bit 0 = '1' this block contains the begining of the fragment
																		-- bit 1 = '1' this block conatins the end of the fragment
																		--      a block can contains both
																		-- others bits are reserved for futur 
		lenght  					: std_logic_vector(15 downto 0); -- wc of valid data in the block
		blk_used					: std_logic;					-- specify if the block is used
		to_be_send				    : std_logic;					-- indicate that the block should be send (new receive or for retrsanmit)`
		mem_ACK					    : std_logic;
	end record;

signal a,b,c,d 				: descript;

--attribute mark_debug : string;
--attribute mark_debug of a,b,c,d : signal is "true";

		
signal timer 					      : std_logic_vector(15 downto 0);
--attribute mark_debug of timer       : signal is "true";
		
signal seq_number				      : std_logic_vector(31 downto 0);
			
signal cmd_mem					      : std_logic;
signal seq_nm_cmd				      : std_logic_vector(30 downto 0);
		
signal req_send_pckt			      : std_logic;
signal req_init_pckt			      : std_logic;
signal req_ack_pckt			          : std_logic;
signal req_data_pckt			      : std_logic;
signal init_done				      : std_logic;
signal pulse_gen_a			          : std_logic;
signal retransmit_ena		          : std_logic_vector(3 downto 0); -- this is used to compute number fo packet retransmit

signal retrans_sig			          : std_logic;
--attribute mark_debug of retrans_sig : signal is "true";

signal timer_sec				      : std_logic_vector(19 downto 0);
signal resync_timer			          : std_logic_vector(3 downto 0);
signal nb_retrans				      : std_logic_vector(7 downto 0);
signal low_buffer				      : std_logic;
		 
signal seq_cmd_mem			          : std_logic_vector(31 downto 0);
signal execute_CMD 			          : std_logic;
 
signal gen_reset				      : std_logic_vector(2 downto 0);
signal req_resync_slink		          : std_logic;

signal del_end_send			          : std_logic_vector(3 downto 0);

--************************************************************************************************
--***********************************<<  BEGIN  >>************************************************
--************************************************************************************************
begin 
 
reset_bar <= not Gresetn_clk;

---******************************************************
--*****************  retrans managment   ****************
-- 
-- in regular interval we set the nb retransmit to 20 , during this interval, if the number of retransmit is > to 20 , we decrease the number of buffer until the next interval.
--
process(resetn_clk,Clock_serdes_T)
begin
	if resetn_clk = '0' then 
		resync_timer(0) 	<= '0';
		timer_sec		<= interval_retrans(19 downto 0);
	elsif rising_edge(Clock_serdes_T) then
		resync_timer(0) 	<= '0';
		if timer_sec /= x"00000" then
			timer_sec 		<= timer_sec - "1";
		else
			timer_sec <= interval_retrans(19 downto 0);
			resync_timer(0) <= '1';
		end if;
	end if;
end process;

process(resetn_clk,Clock_serdes_T)
begin
	if resetn_clk = '0' then
		nb_retrans <= x"20";
		low_buffer <= '0';
		resync_timer(3 downto 1) <= (others => '0');
	elsif rising_edge(Clock_serdes_T) then
		-- decrease the number of buffer to 2 in cas eof too much retransmit
		if 		nb_retrans  = x"00" AND resync_timer(2) = '1' AND resync_timer(3) = '0' then
			low_buffer <= '1';
		elsif 	nb_retrans /= x"00" AND resync_timer(2) = '1' AND resync_timer(3) = '0' then
			low_buffer <= '0';
		end if;

		if resync_timer(2) = '1' AND resync_timer(3) = '0' then
			nb_retrans <= x"20";
		elsif retrans_sig = '1' AND nb_retrans /= x"00" then
			nb_retrans <= nb_retrans - "1";
		end if;
		
		resync_timer(3 downto 1) <= resync_timer(2 downto 0);
	end if;
end process;
---******************************************************

---******************************************************
-- Indicates if almost one BLOCK is free (only when the link is init)
block_free <= '1' when FULL_block = '0' AND init_done = '1' else '0';


---******************************************************
-- timer for time out check and init
process(resetn_clk,Clock_serdes_T)		
begin
	if resetn_clk = '0' then
		timer <= (others => '0');
	elsif rising_edge(Clock_serdes_T) then 
		timer <= timer + "1";
	end if;
end process;

---******************************************************
-- logic to write data in memory 
---******************************************************
-- loop on the four blocks to find a free block 
-- When it is full (no free block) wait that one is freed to used it 
-- 'blk_wr' specify the block using currently to record INPUT DATA (0, 1 ,2 or 3)
process(resetn_clk,Clock_serdes_T) 		
begin
	if resetn_clk = '0'  then
		blk_wr 		<= "0001";
		FULL_block 	<= '0';
	elsif rising_edge(Clock_serdes_T) then 
		if FED_Evt_end_blk = '1' then
			if    blk_wr(0) = '1' then
				blk_wr(0) <= '0';
				if  b.blk_used = '0' then
					blk_wr(1) <= '1';
				else
					FULL_block <= '1';
				end if;
			elsif blk_wr(1) = '1' then
				blk_wr(1) <= '0';
				if    c.blk_used = '0' AND low_buffer = '0' then
					blk_wr(2) <= '1';
				elsif a.blk_used = '0' AND low_buffer = '1' then-- loop on two buffers if too much retransmit
					blk_wr(0) <= '1';
				else
					FULL_block <= '1';
				end if;
			elsif blk_wr(2) = '1' then
				blk_wr(2) <= '0';
				if  d.blk_used = '0' then
					blk_wr(3) <= '1';
				else
					FULL_block <= '1';
				end if;		
			elsif blk_wr(3) = '1' then
				blk_wr(3) <= '0';
				if  a.blk_used = '0' then
					blk_wr(0) <= '1';
				else
					FULL_block <= '1';
				end if;		
			end if;
		elsif FULL_block = '1' then
			if    a.blk_used = '0'  then
				blk_wr(0) 	<= '1';
				FULL_block 	<= '0';
			elsif b.blk_used = '0' then
				blk_wr(1)	<= '1';
				FULL_block 	<= '0';
			elsif c.blk_used = '0' AND low_buffer = '0' then
				blk_wr(2)	<= '1';
				FULL_block 	<= '0';
			elsif d.blk_used = '0' AND low_buffer = '0'  then
				blk_wr(3)	<= '1';
				FULL_block 	<= '0';
			end if;
		end if;
	end if;
end process;

-- generator of seq number increment by one for each new block
process(resetn_clk,Clock_serdes_T)		
begin
	if resetn_clk = '0' then 
		seq_number <= x"00000001";
	elsif rising_edge(Clock_serdes_T) then
		if req_resync_slink = '1' then
			seq_number <= x"00000001";
		elsif FED_Evt_end_blk = '1' then
			if seq_number = x"7FFFFFFF" then
				seq_number <= x"00000001";
			else
				seq_number <= seq_number + "1";
			end if;
		end if;
	end if;	
end process;

-- address generator to write in the memory 
process(resetn_clk,Clock_serdes_T)		
begin
	if resetn_clk = '0' then
		add_w_cnt <= (others => '0');
	elsif rising_edge(Clock_serdes_T) then
		if FED_Evt_end_blk = '1' then
			add_w_cnt <= (others => '0');
		elsif FED_Evt_wr_ena ='1' then
			add_w_cnt <= add_w_cnt + "1";
		end if;
	end if;
end process;

-- select block (1 of 4) used to record the fragment or a part of it
block_w_add(0) <= '1' when blk_wr(1) = '1' or blk_wr(3) = '1' else '0'; 
block_w_add(1) <= '1' when blk_wr(2) = '1' or blk_wr(3) = '1' else '0';


--*********************************************************************************************************
--******************  MEMORY  share between write/read ****************************************************
--*********************************************************************************************************
 
mem_i1:Memory  
port map 	( 
		clock						=>	Clock_serdes_T		,
		addr_w(9 downto 8)		    =>	block_w_add ,
		addr_w(7 downto 0)			=>	add_w_cnt	,
		data_w						=>	FED_Evt_data	,
		wen							=>	FED_Evt_wr_ena			,
		addr_r(9 downto 8)		    =>	block_r_add	,
		addr_r(7 downto 0)			=>	add_r_cnt   ,
		ren							=>	rd_dt		,
		data_r						=>	data_evt		
	); 		
--**********************************************************************************************************
--********* signal used to monitor the block used , to be transmit, to retransmit ,..
--**********************************************************************************************************		

-- this register will be set if a timeout is reached (all blocks are independent
process(Gresetn_clk,Clock_serdes_T)
begin
	if Gresetn_clk = '0' then
		time_out_reach <= "0000";
	elsif rising_edge(Clock_serdes_T) then
		time_out_reach <= "0000";
		if a.time_out(15 downto 3) = timer(15 downto 3) and a.time_out_ON = '1' then
			time_out_reach(0) <= '1';                   
		end if;                                        
		if b.time_out(15 downto 3) = timer(15 downto 3) and b.time_out_ON = '1' then
			time_out_reach(1) <= '1';                   
		end if;                                        
		if c.time_out(15 downto 3) = timer(15 downto 3) and c.time_out_ON = '1' then
			time_out_reach(2) <= '1';                   
		end if;                                        
		if d.time_out(15 downto 3) = timer(15 downto 3) and d.time_out_ON = '1' then
			time_out_reach(3) <= '1';
		end if;	
	end if;
end process;		

-- registers used to store the description of each block (SEQ num, Size of the block, Start/Stop evt bit...)		
process(Gresetn_clk,Clock_serdes_T) 
variable interm_cmd :std_logic_vector(31 downto 0);
begin
	if Gresetn_clk = '0' then
		a.blk_used		<= '0';
		b.blk_used		<= '0';
		c.blk_used		<= '0';
		d.blk_used		<= '0';	
		a.mem_ACK		<= '0';
		b.mem_ACK		<= '0';
		c.mem_ACK		<= '0';
		d.mem_ACK		<= '0';	
	elsif rising_edge(Clock_serdes_T) then
	
		-- monitor block a.
		if FED_Evt_end_blk = '1' then		-- mark block used when is filled
			if blk_wr(0) = '1' then
				a.blk_used	<= '1';
			end if;
		end if;
		
		-- monitor block b.
		if FED_Evt_end_blk = '1' then
			if blk_wr(1) = '1' then
				b.blk_used	<= '1';
			end if;
		end if;
		
		-- monitor block c.
		if FED_Evt_end_blk = '1' then	
			if blk_wr(2) = '1' then
				c.blk_used	<= '1';
			end if;
		end if;
		
		-- monitor block d.
		if FED_Evt_end_blk = '1' then	
			if blk_wr(3) = '1' then
				d.blk_used	<= '1';
			end if;
		end if;
		
	-- block 0	
		if ena_ack = '1' then							-- free the block if the ack is received
			if a.seq_num = seqnb_rcv and a.blk_used = '1' then
				a.mem_ACK	<= '1';
			end if;
		elsif a.mem_ACK = '1' and a.to_be_send = '0' then
			a.mem_ACK 	<= '0';
		end if;
		
		if a.mem_ACK = '1' and a.to_be_send = '0' then
			a.blk_used 	<= '0';
		elsif  req_resync_slink = '1' then
			a.blk_used	<= '0';
		end if;
	-- block 1			
		if ena_ack = '1' then							-- free the block if the ack is recieved
			if b.seq_num = seqnb_rcv and b.blk_used = '1' then
				b.mem_ACK	<= '1';
			end if;
		elsif b.mem_ACK = '1' and b.to_be_send = '0' then
			b.mem_ACK 	<= '0';
		end if;
		
		if b.mem_ACK = '1' and b.to_be_send = '0' then
			b.blk_used 	<= '0';
		elsif  req_resync_slink = '1' then
			b.blk_used	<= '0';
		end if;
	-- block 2	
		if ena_ack = '1' then							-- free the block if the ack is recieved
			if c.seq_num = seqnb_rcv and c.blk_used = '1' then
				c.mem_ACK	<= '1';
			end if;
		elsif c.mem_ACK = '1' and c.to_be_send = '0' then
			c.mem_ACK 	<= '0';
		end if;
		
		if c.mem_ACK = '1' and c.to_be_send = '0' then
			c.blk_used 	<= '0';
		elsif  req_resync_slink = '1' then
			c.blk_used	<= '0';
		end if;
	-- block 3	
		if ena_ack = '1' then							-- free the block if the ack is recieved
			if d.seq_num = seqnb_rcv and d.blk_used = '1' then
				d.mem_ACK	<= '1';
			end if;
		elsif d.mem_ACK = '1' and d.to_be_send = '0' then
			d.mem_ACK 	<= '0';
		end if;
		
		if d.mem_ACK = '1' and d.to_be_send = '0' then
			d.blk_used 	<= '0';
		elsif  req_resync_slink = '1' then
			d.blk_used	<= '0';
		end if;		
	 
	end if;
end process;

process(Clock_serdes_T) 
variable interm_cmd :std_logic_vector(15 downto 0);
begin
	if rising_edge(Clock_serdes_T) then
	
		interm_cmd(0) 				:= FED_Evt_start;
		interm_cmd(1) 				:= FED_Evt_stop; 
		interm_cmd(15 downto 2) 	:= (others => '0');
		
		-- monitor block a.
		
		if FED_Evt_end_blk = '1' then		-- mark block used when is filled
			if blk_wr(0) = '1' then
				a.seq_num 	<= seq_number(30 downto 0);
				a.command	<= interm_cmd;
				a.lenght	<= FED_Evt_block_sz;
			end if;
		end if;
		
		-- monitor block b.
		
		if FED_Evt_end_blk = '1' then
			if blk_wr(1) = '1' then
				b.seq_num	<= seq_number(30 downto 0);
				b.command 	<= interm_cmd;
				b.lenght	<= FED_Evt_block_sz;
			end if;
		end if;
		
		-- monitor block c.
		
		if FED_Evt_end_blk = '1' then	
			if blk_wr(2) = '1' then
				c.seq_num	<= seq_number(30 downto 0);
				c.command 	<= interm_cmd;
				c.lenght	<= FED_Evt_block_sz;
			end if;
		end if;
		
		-- monitor block d.

		if FED_Evt_end_blk = '1' then	
			if blk_wr(3) = '1' then
				d.seq_num 	<= seq_number(30 downto 0);
				d.command 	<= interm_cmd;
				d.lenght 	<= FED_Evt_block_sz;
			end if;
		end if;
		
	end if;
end process;

process(Gresetn_clk,Clock_serdes_T)
begin
	if Gresetn_clk = '0' then
		a.to_be_send	<= '0';
		b.to_be_send	<= '0';
		c.to_be_send	<= '0';
		d.to_be_send	<= '0';				
	elsif rising_edge(Clock_serdes_T) then
	
		-- monitor block a.  --Should it be send or retransmit
		if (a.blk_used = '1' and time_out_reach(0) = '1' and a.mem_ACK = '0') or (FED_Evt_end_blk = '1' and blk_wr(0) = '1') then
			a.to_be_send         <= '1';
		end if;
		
		-- monitor block b.
		if (b.blk_used = '1' and time_out_reach(1) = '1' and b.mem_ACK = '0') or (FED_Evt_end_blk = '1' and blk_wr(1) = '1') then
			b.to_be_send 	<= '1';
		end if;
	
		-- monitor block c.
		if (c.blk_used = '1' and time_out_reach(2) = '1' and c.mem_ACK = '0') or (FED_Evt_end_blk = '1' and blk_wr(2) = '1') then
			c.to_be_send 	<= '1';
		end if;
	
		-- monitor block d.
		if (d.blk_used = '1' and time_out_reach(3) = '1' and d.mem_ACK = '0') or (FED_Evt_end_blk = '1' and blk_wr(3) = '1') then
			d.to_be_send 	<= '1';
		end if;

		if end_snd_pckt = '1' then					-- clear .to_be_send to specify that block is sent (the bit will be set if timeout is reached)								
			if blk_rd(0) = '1' then
				a.to_be_send	<= '0';
			elsif blk_rd(1) = '1' then
				b.to_be_send	<= '0';
			elsif blk_rd(2) = '1' then
				c.to_be_send	<= '0';
			elsif blk_rd(3) = '1' then
				d.to_be_send	<= '0';
			end if;
		end if;		
		
	end if;
end process;

process(Clock_serdes_T)
begin
	if rising_edge(Clock_serdes_T) then
		retransmit_ena    <= "0000";	
		--control the retransmit counter
		-- block A.
		if (a.blk_used = '1' and time_out_reach(0) = '1' and a.mem_ACK = '0') then
			retransmit_ena(0)    <= '1';
		end if;
		
		-- block B.
		if (b.blk_used = '1' and time_out_reach(1) = '1' and b.mem_ACK = '0') then
			retransmit_ena(1)    <= '1';
		end if;
	
		-- block C.
		if (c.blk_used = '1' and time_out_reach(2) = '1' and c.mem_ACK = '0')  then
			retransmit_ena(2)    <= '1';
		end if;
	
		-- block D.
		if (d.blk_used = '1' and time_out_reach(3) = '1' and d.mem_ACK = '0') then
			retransmit_ena(3)    <= '1';
		end if;		
		
	end if;
end process;
---******************************************************
-- this logic is used to compute the number of blocks retransmit
process(Clock_serdes_T)
begin
	if rising_edge(Clock_serdes_T) then 
		retrans_sig 					<= '0';						-- signal a retransmit block
		if 		retransmit_ena(0) = '1' then
			retrans_sig 				<= '1';
		elsif 	retransmit_ena(1) = '1' then
			retrans_sig					<= '1';
		elsif 	retransmit_ena(2) = '1' then
			retrans_sig 				<= '1';
		elsif 	retransmit_ena(3) = '1' then
			retrans_sig 				<= '1';
		end if;		 
 
	end if;
end process;	

retransmit <= retrans_sig;
--*********************************************************************************************************************************************************	

--**********************************************************
--************************** memory address low part control
process(Gresetn_clk,Clock_serdes_T)
begin
	if Gresetn_clk = '0' then
		add_r_cnt 		<= (others => '0');
	elsif rising_edge(Clock_serdes_T) then  
		if rd_dt = '1' then
			add_r_cnt 	<= add_r_cnt + "1";
		elsif req_data_pckt = '1' then
			add_r_cnt 	<= (others => '0');
		end if;
	end if;
end process;

-- select the block that will be read
block_r_add(0) <= '1' when blk_rd(1) = '1' or blk_rd(3) = '1' else '0'; 
block_r_add(1) <= '1' when blk_rd(2) = '1' or blk_rd(3) = '1' else '0';

process(Gresetn_clk,Clock_serdes_T)					-- initialize the timeout at the end of the block send
begin
	if Gresetn_clk = '0' then
		a.time_out	<= (others => '0');
		b.time_out	<= (others => '0');
		c.time_out	<= (others => '0');
		d.time_out	<= (others => '0');
		a.time_out_ON	<= '0';
		b.time_out_ON	<= '0';
		c.time_out_ON	<= '0';
		d.time_out_ON	<= '0';		
		del_end_send	<= (others => '0');
	elsif rising_edge(Clock_serdes_T) then
		--specify the block finished to be sent
		del_end_send	<= (others => '0');
		if end_snd_pckt = '1' then				
			if    blk_rd(0) = '1' then
				del_end_send(0)	<= '1';
			elsif blk_rd(1) = '1' then
				del_end_send(1)	<= '1';
			elsif blk_rd(2) = '1' then
				del_end_send(2)	<= '1';
			elsif blk_rd(3) = '1' then
				del_end_send(3)	<= '1';
			end if;
		end if;
		
		--we receive the acknowledge corresponding to this block => disable the timeout counter
		if (a.mem_ACK = '1' and a.to_be_send = '0') or time_out_reach(0) = '1' then
			a.time_out_ON	<= '0';
		-- when we finish to send a packet we start the timeout (initialize the timeout counter and set the bit timeout_ON
		elsif del_end_send(0) = '1' then
			a.time_out 		<= timer + time_out_val;
			a.time_out_ON	<= '1';
		end if;
 
		if (b.mem_ACK = '1' and b.to_be_send = '0') or time_out_reach(1) = '1' then
			b.time_out_ON	<= '0';
		elsif del_end_send(1) = '1' then
			b.time_out 		<= timer + time_out_val;
			b.time_out_ON	<= '1';
		end if;
		
		if (c.mem_ACK = '1' and c.to_be_send = '0') or time_out_reach(2) = '1' then
			c.time_out_ON	<= '0';
		elsif del_end_send(2) = '1' then
			c.time_out 		<= timer + time_out_val;
			c.time_out_ON	<= '1';
		end if;
		
		if (d.mem_ACK = '1' and d.to_be_send = '0') or time_out_reach(3) = '1' then
			d.time_out_ON	<= '0';
		elsif del_end_send(3) = '1' then
			d.time_out 		<= timer + time_out_val;
			d.time_out_ON	<= '1';
		end if;
	end if;
end process;

-- select the next block to read (roll is no time out -> go to the oldest block in case of timeout)
process(Gresetn_clk,Clock_serdes_T)
begin
	if Gresetn_clk = '0' then
		blk_rd				<= "0000";
	elsif rising_edge(Clock_serdes_T) then
		if end_snd_pckt = '1' then	
			if 	  blk_rd(0) = '1' then
				if    b.to_be_send = '1' then
					blk_rd	<= "0010";
				elsif c.to_be_send = '1' then
					blk_rd	<= "0100";
				elsif d.to_be_send = '1' then
					blk_rd	<= "1000";
				else
					blk_rd	<= "0000";
				end if;
			elsif blk_rd(1) = '1' then
				if    c.to_be_send = '1' then
					blk_rd	<= "0100";
				elsif d.to_be_send = '1' then
					blk_rd	<= "1000";
				elsif a.to_be_send = '1' then
					blk_rd	<= "0001";
				else
					blk_rd	<= "0000";
				end if;
			elsif blk_rd(2) = '1' then
				if    d.to_be_send = '1' then
					blk_rd	<= "1000";
				elsif a.to_be_send = '1' then
					blk_rd	<= "0001";
				elsif b.to_be_send = '1' then
					blk_rd	<= "0010";
				else
					blk_rd	<= "0000";
				end if;
			elsif blk_rd(3) = '1' then
				if    a.to_be_send = '1' then
					blk_rd	<= "0001";
				elsif b.to_be_send = '1' then
					blk_rd	<= "0010";
				elsif c.to_be_send = '1' then
					blk_rd	<= "0100";
				else
					blk_rd	<= "0000";
				end if;
			end if;
		elsif blk_rd = "0000" then
			if   a.to_be_send = '1' then
				blk_rd		<= "0001";
			elsif b.to_be_send = '1' then
				blk_rd		<= "0010";
			elsif c.to_be_send = '1' then
				blk_rd		<= "0100";
			elsif d.to_be_send = '1' then
				blk_rd		<= "1000";
			end if;
		end if;
	end if;
end process;
		
---******************************************************
-- request send packet (ACK,INIT,DATA)		 
process(resetn_clk,Clock_serdes_T)								
begin
	if resetn_clk = '0' then
		req_init_pckt 				<= '0';
		req_ack_pckt 				<= '0';
		req_data_pckt 				<= '0';
		pulse_gen_a					<= '0';  --generate a pulse
	elsif rising_edge(Clock_serdes_T) then 
		req_init_pckt 				<= '0';
		req_ack_pckt 				<= '0';
		req_data_pckt 				<= '0';
		pulse_gen_a 				<= '0';
		if 	ST_START_state = '1'   and SERDES_BackPressure = '0' then--and req_send_pckt = '0'
			-- SERDES initialization done => send an init packet (retransmit if timeout reached)
			if (init_done = '0' and timer(9 downto 8) = "11" and pulse_gen_a = '0' ) and serdes_init = '1' then  -- retry each 0x300 * 8ns =  6.144 us until init_done
				req_init_pckt 		<= '1';
			-- we received a command => we should send the ack with the data if it is a read 
			elsif cmd_mem = '1' then 
				req_ack_pckt 		<= '1';
			-- request to send a data packet
			elsif a.to_be_send = '1' or b.to_be_send = '1' or c.to_be_send = '1' or d.to_be_send = '1' then 
				req_data_pckt		<= '1';
			end if;
		end if;
		
		if timer(9 downto 8) = "11" then	
			pulse_gen_a 			<= '1';
		end if;
	end if;
end process;

---******************************************************
-- select the value used(seq number, lenght, command "startevt, stopevt,.." ) to send the block
process(req_ack_pckt,blk_rd,a,b,c,d,seq_nm_cmd)
begin
	Seq_nb 						<= seq_nm_cmd;
	len_pckt 					<= (others => '0');
	Pckt_CMD					<= (others => '0');
	if req_ack_pckt = '0' then
		if 	   blk_rd(0) = '1' then
			Seq_nb 				<= a.seq_num;
			len_pckt 			<= a.lenght;
			Pckt_CMD			<= a.command;
		elsif  blk_rd(1) = '1' then
			Seq_nb 				<= b.seq_num;
			len_pckt 			<= b.lenght;
			Pckt_CMD			<= b.command;
		elsif  blk_rd(2) = '1' then
			Seq_nb 				<= c.seq_num;
			len_pckt 			<= c.lenght;
			Pckt_CMD			<= c.command;
		--elsif  blk_rd(3) = '1' then
		else
			Seq_nb 				<= d.seq_num;
			len_pckt 			<= d.lenght;
			Pckt_CMD			<= d.command;
		end if;
	end if;
end process;

---******************************************************
--- enable the INIT DONE on receive ack for init
process(resetn_clk,Clock_serdes_T)	
begin
	if resetn_clk = '0'  then
		init_done 		<= '0';
	elsif rising_edge(Clock_serdes_T) then 
		if ena_ack = '1' and seqnb_rcv = "0000000000000000000000000000000" then
			init_done 	<= '1';
		elsif req_resync_slink = '1' then
			init_done 	<= '0';
		end if;
	end if;
end process;

---******************************************************
--*********************  Command execution
---******************************************************
-- the command function pulse (WEN_funct) should be enable only if seq_nm_cmd = seqnb_rcv (only one command is sent at the time)
process(resetn_clk,Clock_serdes_T)
begin
	if resetn_clk = '0' then 
		seq_cmd_mem 					<= x"00000000";
		execute_CMD						<= '0';
		Command_num							<= (others => '0');
		req_resync_slink 				<= '0';
	elsif rising_edge(Clock_serdes_T) then
	 
		-- will generate a reset of 3 pulse on request resync link
		if gen_reset(2) = '1' then
			req_resync_slink 			<= '0';
		elsif rcv_cmd_ena = '1' AND seqnb_rcv = "0000000000000000000000000000000" then
			req_resync_slink 			<= '1';
		end if;
		
		-- manage the sequence nuimber corresponding to the command (DAQ -> FED request)
		execute_CMD						<= '0';
		if 	rcv_cmd_ena = '1' AND seqnb_rcv = seq_cmd_mem(30 downto 0) then
			if seq_cmd_mem = x"7FFFFFFF" then
				seq_cmd_mem 			<= x"00000001";
			else
				seq_cmd_mem 			<= seq_cmd_mem + "1";
			end if;
			execute_CMD 				<= '1';
		elsif req_init_pckt = '1' then
			seq_cmd_mem 				<= x"00000001";
		end if;	
	
		-- decode the function to be executed (command received from the DAQ side)
		for I in 0 to 31 loop
			if rcv_cmd_num(16) = '1' and rcv_cmd_num(4 downto 0) = I then
				Command_num(i)					<= '1';
			else
				Command_num(i) 				<= '0';
			end if;
		end loop;
	end if;
end process;

process(Clock_serdes_T)
begin
	if rising_edge(Clock_serdes_T) then
		gen_reset(2 downto 1) 		<= gen_reset(1 downto 0); -- generate a reset pulse of 3 clocks cycle
		gen_reset(0)				<= req_resync_slink;
	end if;
end process;

req_reset_resync			<= '0' when req_resync_slink = '1' else '1';
Command_wr					<= '1' when execute_CMD = '1' and rcv_cmd_num(31) = '1' else '0';
Command_data_wr				<= rcv_cmd_data;
 

---******************************************************

---******************************************************
-- each command received should be acknowledge event if it is an old command
process(Clock_serdes_T)
begin
if rising_edge(Clock_serdes_T) then
	if rcv_cmd_ena = '1' then -- send the acknowledge
		cmd_mem 			<= '1' ;
		seq_nm_cmd 			<= seqnb_rcv;
		-- Status/DATA sent with the acknowledge
		status(63 downto 00) <= Command_data_rd;														
	elsif req_ack_pckt = '1' then 
		cmd_mem 			<= '0' ;
	end if;
end if;
end process;

req_send_pckt 					<= '1' when req_init_pckt = '1' or req_data_pckt = '1' or  req_ack_pckt = '1' else '0';
start_pckt						<= req_send_pckt;
init_pckt						<= req_init_pckt;
ack_pckt						<= req_ack_pckt;
data_pckt						<= req_data_pckt;

status_state(0)					<= a.blk_used;
status_state(1)					<= b.blk_used;
status_state(2)					<= c.blk_used;
status_state(3)					<= d.blk_used;
status_state(4)					<= a.to_be_send;
status_state(5)					<= b.to_be_send;
status_state(6)					<= c.to_be_send;
status_state(7)					<= d.to_be_send;
status_state(30 downto 8)		<= (others => '0');
status_state(31)				<= init_done;


end behavioral;