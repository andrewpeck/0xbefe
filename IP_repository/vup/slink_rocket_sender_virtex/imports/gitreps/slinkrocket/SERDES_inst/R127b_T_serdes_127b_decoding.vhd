--
-- Dominique Gigi
-- 2018
--
-- Swap byte and bits
--
--
--
--
--
--
LIBRARY ieee;

USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
 
--ENTITY-----------------------------------------------------------
entity R127b_T_Serdes_127b_decoding is
	generic(constant	swap_bit	: boolean := true);
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
end R127b_T_Serdes_127b_decoding;

--ARCHITECTURE------------------------------------------------------
architecture behavioral of R127b_T_Serdes_127b_decoding is

signal SD_DATA_cell			: std_logic_vector(127 downto 0);
 
signal data_reg				: std_logic_vector(127 downto 0);
signal data_tmp_A			: std_logic_vector(127 downto 0); 
signal data_tmp_B			: std_logic_vector(127 downto 0); 
signal data_tmp_C			: std_logic_vector(127 downto 0); 


signal HD_tmp_A				: std_logic_vector(5 downto 0); 
  
signal start_reg			: std_logic_vector(2 downto 0);
signal End_reg				: std_logic_vector(1 downto 0);
 
signal swap_word			: std_logic;
signal swap_word_GTH		: std_logic;
--this signal is used to memorize the Start for the first WR_ena
signal Start_memory			: std_logic;
signal End_for_GTH_Swap		: std_logic_vector(1 downto 0);

--Signals used to out
signal Start_cell			: std_logic;
signal End_cell				: std_logic;
signal wr_cell				: std_logic;
  

--attribute mark_debug : string; 
--attribute mark_debug of SD_DATA_cell		: signal is "true";  
--attribute mark_debug of SerDes_Header_I		: signal is "true";  
--attribute mark_debug of Start_cell			: signal is "true";  
--attribute mark_debug of End_cell			: signal is "true";  
--attribute mark_debug of wr_cell				: signal is "true";  
--attribute mark_debug of data_reg			: signal is "true";  
  
--***************************************************************** 
--*************<     CODE START HERE    >**************************
--***************************************************************** 
 begin 
 

G1:if (swap_bit) generate
	process(SerDes_DATA_I)
	begin
		FOR j in 0 to 63 loop
			SD_DATA_cell(j) 		<= SerDes_DATA_I(63-j);
			SD_DATA_cell(j+64) 		<= SerDes_DATA_I(127-j); 
		end loop;  
	end process;
end generate;
	
G2:if not(swap_bit) generate
		SD_DATA_cell  				<= SerDes_DATA_I ; 
end generate;	
 
 
 process(reset_n,clock)
 begin
	if reset_n = '0' then
		start_reg			<= (others => '0');
		End_reg				<= (others => '0');
		End_for_GTH_Swap	<= (others => '0');
		Start_memory		<= '0';
		swap_word			<= '0';
		swap_word_GTH		<= '0';
	elsif rising_edge(clock) then
		start_reg(2 downto 1)		<= start_reg(1 downto 0);
		End_for_GTH_Swap(1)			<= End_for_GTH_Swap(0);
		
		start_reg(0)		<= '0';
		End_reg(0)			<= '0';
		End_reg(1)			<= '0';	
		End_for_GTH_Swap(0)	<= '0'; 
		
		-- swap only seen on GTH
		if 		(SerDes_Header_I(2 downto 0) = "010" and SD_DATA_cell(63 downto 56)   = x"78")  and (HD_tmp_A(5 downto 3) /= "010" or data_tmp_A(127 downto 120)   /= x"1E") then
			start_reg(0)	<= '1';
			Start_memory	<= '1'; 
			swap_word		<= '0';
			swap_word_GTH	<= '1';
			if SerDes_Header_I(5 downto 3) = "010" and SD_DATA_cell(127 downto 120) = x"B4" then
				End_for_GTH_Swap(0)	<= '1';
			end if;
		-- looking for a START packet Header = 10 Data(63..56) 0x78  		==>  Swap word
		elsif 	SerDes_Header_I(2 downto 0) = "010" and SD_DATA_cell(63 downto 56)   = x"78" then
			start_reg(0)	<= '1';
			Start_memory	<= '1'; 
			swap_word		<= '1';
			swap_word_GTH	<= '0';
		-- looking for a START packet Header = 10 Data(127 downto 120) 0x78	
		elsif 	SerDes_Header_I(5 downto 3) = "010" and SD_DATA_cell(127 downto 120) = x"78" then
			start_reg(0)	<= '1';
			Start_memory	<= '1'; 
			swap_word		<= '0';
			swap_word_GTH	<= '0';
			
		-- looking for the end of the packet
		elsif 	SerDes_Header_I(5 downto 3) = "010" and SD_DATA_cell(127 downto 120) = x"B4" and swap_word_GTH = '1' then 
			End_for_GTH_Swap(0)	<= '1';
		elsif End_for_GTH_Swap(1) = '1' then 
			Start_memory	<= '0';
			End_reg(0)		<= '1';
		elsif 	SerDes_Header_I(5 downto 3) = "010" and SD_DATA_cell(127 downto 120) = x"B4" then 
			Start_memory	<= '0';
			End_reg(0)		<= '1';
		elsif	SerDes_Header_I(2 downto 0) = "010" and SD_DATA_cell(63 downto 56)   = x"B4" then 
			Start_memory	<= '0';
			End_reg(0)		<= '1';
		end if;		
	end if;
end process;

 
process(clock)
begin
	if rising_edge(clock) then 
		data_tmp_A		<= SD_DATA_cell;
		data_tmp_B		<= data_tmp_A; 
		data_tmp_C		<= data_tmp_B; 
		
		HD_tmp_A		<= SerDes_Header_I;
	end if;
end process;

		
process(clock)
begin		
	if rising_edge(clock) then
		wr_cell												<= '0';
		Start_cell											<= '0';
		End_cell											<= '0';
			--****************************************************************************************************************************************
			-- 									      x".....data....1E................"
			-- the 2 64-bit words arrive unaligned    x"B4...........78................"
			-- the 2 64-bit words arrive unaligned    x"1E..................data......."
			if		swap_word_GTH = '1' then
				-- mange the first word
				if 		start_reg(1) = '1' then
						
					for I in 0 to 6 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_B( 7+((6-I)*8) downto ((6-I)*8) );
					end loop;

					--transfert    127..56 from next word
					for I in 7 to 14 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_C((7+((22-I)*8)) downto ((22-I)*8));
					end loop;
					
						data_reg(127 downto 120)				<= data_tmp_A(63 downto 56);
					
					Start_cell				<= '1'; 
					wr_cell					<= '1';
				
				-- mange the last word			
				elsif 	End_reg(0) = '1' then
				
					for I in 0 to 6 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_B( 7+((6-I)*8) downto ((6-I)*8) );
					end loop;
					
					--transfert  111..56 from 64..120 --remove the B4 (end of packet) 
					for I in 0 to 6 loop
						data_reg((63+(I*8)) downto 56+(I*8)) 	<= data_tmp_C(71+((6-I)*8) downto 64+((6-I)*8) );
					end loop;
					
					data_reg(127 downto 112) 					<=	(others => '0');

					End_cell									<= '1';
					wr_cell										<= '1';
				
				-- mange the Payload	
				elsif Start_memory = '1' and start_reg(0) = '0' then

					for I in 0 to 6 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_B( 7+((6-I)*8) downto ((6-I)*8) );
					end loop;

					--transfert    127..56 from next word
					for I in 7 to 14 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_C((7+((22-I)*8)) downto ((22-I)*8));
					end loop;
					
						data_reg(127 downto 120)				<= data_tmp_A(63 downto 56);
					wr_cell					<= '1';
				end if;
				
			--****************************************************************************************************************************************	
			-- 									      x"1E...........78................"
			-- the 2 64-bit words arrive unaligned    x"....data............data  ....."
			-- 										  x"B4...........1E................"
	 		elsif 	swap_word = '1' then
				-- mange the first word
				if 		start_reg(1) = '1' then
					--transfert  55..00 from 00..55 Byte swap
					for I in 0 to 6 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_B( 7+((6-I)*8) downto ((6-I)*8) );
					end loop;

					--transfert    127..56 from next word
					for I in 7 to 15 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_A((7+((22-I)*8)) downto ((22-I)*8));
					end loop;
					
					Start_cell				<= '1'; 
					wr_cell					<= '1';
				
				-- mange the last word			
				elsif 	End_reg(0) = '1' then
				
					--transfert  55..0 from 00..55 
					for I in 0 to 6 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_B( 7+((6-I)*8) downto ((6-I)*8) );
					end loop;
					
					--transfert  111..56 from 64..120 --remove the B4 (end of packet) 
					for I in 0 to 6 loop
						data_reg((63+(I*8)) downto 56+(I*8)) 	<= data_tmp_A(71+((6-I)*8) downto 64+((6-I)*8) );
					end loop;
					
					data_reg(127 downto 112) 					<=	(others => '0');

					End_cell									<= '1';
					wr_cell										<= '1';
				
				-- mange the Payload	
				elsif Start_memory = '1' and start_reg(0) = '0' then
					--transfert  55..00 from 00..55 Byte swap
					for I in 0 to 6 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_B( 7+((6-I)*8) downto ((6-I)*8) );
					end loop;

					--transfert    127..56 from next word
					for I in 7 to 15 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_A((7+((22-I)*8)) downto ((22-I)*8));
					end loop;
				
					wr_cell					<= '1';
				end if;

			--****************************************************************************************************************************************
			-- the 2 64-bit words arrive aligned    x"78....................data......."			
			-- 									    x"......data......B4..............."			
			-- 									    x"1E..............1E..............." 
			else	
				-- mange the first word
				if 		start_reg(0) = '1' then
					--transfert  119..00 from 00..119 Byte swap
					for I in 0 to 14 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_A( 7+((14-I)*8) downto ((14-I)*8) );
					end loop;

					--transfert    127..120 from next word
					data_reg(127 downto 120) 					<= SD_DATA_cell(127 downto 120);
					
					Start_cell				<= '1'; 
					wr_cell					<= '1';
				
				-- mange the last word			
				elsif 	End_reg(0) = '1' then
				
					--transfert  55..0 from 64..119 
					for I in 0 to 6 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_A( 71+ ((6-I)*8) downto 64+((6-I)*8) );
					end loop;
					
					--transfert  111..56 from 00..55 --remove the B4 (end of packet) 
					for I in 0 to 6 loop
						data_reg((63+(I*8)) downto 56+(I*8)) 	<= data_tmp_A( 7+((6-I)*8) downto ((6-I)*8) );
					end loop;
					
					data_reg(127 downto 112) 					<=	(others => '0');

					End_cell									<= '1';
					wr_cell										<= '1';
				
				-- mange the Payload	
				elsif Start_memory = '1' then
					--transfert  119..0 from 00..119 
					for I in 0 to 14 loop
						data_reg((7+(I*8)) downto (I*8)) 		<= data_tmp_A( 7+((14-I)*8) downto ((14-I)*8) );
					end loop;

					--transfert    127..120 from next word
					data_reg(127 downto 120) 					<= SD_DATA_cell(127 downto 120);
				
					wr_cell					<= '1';
				end if;
				
			end if;
			
	end if;
 end process;
 
 
SD_DATA_O			<= data_reg;
SD_Start_PktO		<= Start_cell;
SD_End_PktO			<= End_cell;
SD_Wen_PktO			<= wr_cell; 
 
end behavioral;