LIBRARY ieee;

USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


--  Dominique Gigi EP/CMD
--	2017
--
--
--Interface to SERDES (64/66b)
--
--only one lane
 
--ENTITY-----------------------------------------------------------
entity T127_R_serdes_127b_encoding is
	generic(constant	swap_bit	: boolean := true);
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
end T127_R_serdes_127b_encoding;

--ARCHITECTURE------------------------------------------------------
architecture behavioral of T127_R_serdes_127b_encoding is

 
 type encoding_64_66b_type is (	
						ST_START			,
						Start_code	  	,
						Data_word		,
						End_code       
						);
signal encoding_64_66b:encoding_64_66b_type;  
  
signal tmp_data_b					: std_logic_vector(127 downto 0);
signal tmp_data_a					: std_logic_vector(127 downto 0);
signal tmp_end_wrd					: std_logic;

--registers data and control bits
signal Serdes_word_reg				: std_logic_vector(127 downto 0); 
signal Serdes_Header_reg			: std_logic_vector(5 downto 0);
--swap bits  
signal Serdes_word_cell				: std_logic_vector(127 downto 0); 
signal Serdes_Header_cell			: std_logic_vector(5 downto 0);

--attribute mark_debug : string;
--attribute mark_debug of Serdes_word_reg		: signal is "true";  
--attribute mark_debug of Serdes_Header_reg	: signal is "true";   
--attribute mark_debug of Serdes_Header_cell	: signal is "true";   
--attribute mark_debug of Serdes_word_cell	: signal is "true";   

--***************************************************************** 
--*************<     CODE START HERE    >**************************
--***************************************************************** 
 begin 
 
 
 
process(clock)
begin
	if rising_edge(clock) then
	
		tmp_data_b					<= tmp_data_a;
		tmp_data_a					<= SD_DATA_I; 
	end if;
end process; 
 
 
-- state machine to send data over the 64-66 bit oncoding
 process(reset_n,clock)
 begin	
	if reset_n = '0' then
		encoding_64_66b <= ST_START;
	elsif rising_edge(clock) then
		
		Case encoding_64_66b is
			when ST_START	=>
				if SD_Val_dwrd_I = '1' and SD_Start_I = '1' then
					encoding_64_66b	<= Start_code;
				end if;
				
			when Start_code	 =>
				if SD_Stop_I = '1' then
					encoding_64_66b	<= End_code;
				else
					encoding_64_66b	<= Data_word;
				end if;
				
			when Data_word	=>
				if SD_Stop_I = '1' then
					encoding_64_66b	<= End_code;
				end if;
						
			when End_code    =>
				encoding_64_66b		<= ST_START;
			
			when others =>
				encoding_64_66b		<= ST_START;
				
		end case;	
	end if;
end process;
 

 -- Merge data on the serdes (with the 64 66 bit encoding)
 process(clock)
 begin
	if rising_edge(clock) then
			Serdes_Header_reg									<=  "010010";	
			Serdes_word_reg										<= x"1E000000000000001E00000000000000";
		
		-- start 0x78 ...... (127..64) are sent first
		if 		encoding_64_66b = Start_code then
		
			Serdes_Header_reg									<=  "010001";
			--  
			Serdes_word_reg(127 downto 120) 					<= x"78";
			--00 ..119  from 119..00
			FOR i in 14 downto 0 LOOP
				Serdes_word_reg( (7+(i*8)) downto (i*8) )		<= tmp_data_a( (7+((14-i)*8)) downto ((14-i)*8) );
			end LOOP;

		
		--	DATA
		elsif	encoding_64_66b = Data_word then 
		
			Serdes_Header_reg									<=  "001001";
			--  
			--127..120  from 127..120
			Serdes_word_reg(127 downto 120) 					<= tmp_data_b(127 downto 120);
			--119 .. 64  from 55..0
			
			FOR i in 14 downto 0 LOOP
				Serdes_word_reg( (7+(i*8)) downto (i*8) )		<= tmp_data_a( (7+((14-i)*8)) downto ((14-i)*8) );
			end LOOP;

			
		-- end  D2 (5 bytes)
		elsif encoding_64_66b = End_code then
			Serdes_Header_reg									<=  "001010";	 
			--
			--127..120  from 127..120
			Serdes_word_reg(127 downto 120) 					<= tmp_data_b(127 downto 120);
			--119 .. 64  from 55..0
			FOR i in 6 downto 0 LOOP
				Serdes_word_reg( (71+(i*8)) downto 64+(i*8) )	<= tmp_data_a( (7+((6-i)*8)) downto ((6-i)*8) );
			end LOOP;
			--63..56
--			Serdes_word_reg(63 downto 56)	 					<= x"D2";	-- CRC 32 bit
			Serdes_word_reg(63 downto 56)	 					<= x"B4";  -- CRC 16 bit
			--55..48 from 63..56
			Serdes_word_reg(55 downto 48)						<= tmp_data_a(63 downto 56); 
			--47..32 from 79..64
			FOR i in 1 downto 0 LOOP
				Serdes_word_reg( 39+(i*8) downto 32+(i*8) )		<= tmp_data_a( (71+((1-i)*8)) downto  64+((1-i)*8) );
			end LOOP;
			
			Serdes_word_reg(15 downto 00)						<= (others => '0');

		
		end if;
	end if;
end process;
 

G1:if swap_bit generate
	process(Serdes_word_reg)
	begin
		i1:FOR j in 0 to 63 loop
			Serdes_word_cell(j) 	<=  Serdes_word_reg(63-j);
			Serdes_word_cell(64+j) 	<=  Serdes_word_reg(127-j);
		end loop;
	end process;  
end generate;
	

G2:if not(swap_bit) generate
	Serdes_word_cell  				<=  Serdes_word_reg; 
end generate;	

Serdes_Header_cell 					<= Serdes_Header_reg;

Serdes_word			<= Serdes_word_cell;
Serdes_Header		<= Serdes_Header_cell;
 

end behavioral;