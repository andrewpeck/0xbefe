library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;

entity i2c_master_core is
generic (nbr_of_busses :integer range 1 to 8 :=2);
port
(
	clk			: in  	std_logic;
	reset			: in  	std_logic;
	--- i2c registers ------------
	id_i			: in  	std_logic_vector( 7 downto 0):=x"00"; 
	id_o			: out  	std_logic_vector( 7 downto 0);
	enable		: in  	std_logic;
	bus_select	: in  	std_logic_vector( 2 downto 0):="000";
	prescaler	: in  	std_logic_vector( 9 downto 0);
	--	
	command		: in  	std_logic_vector(31 downto 0);
	reply			: out 	std_logic_vector(31 downto 0);
	------------------------------
	scl_i			:in		std_logic_vector(nbr_of_busses-1 downto 0);					
	scl_o			:out		std_logic_vector(nbr_of_busses-1 downto 0);					
	sda_i			:in		std_logic_vector(nbr_of_busses-1 downto 0);
	sda_o			:out		std_logic_vector(nbr_of_busses-1 downto 0)
); 			
end i2c_master_core;


--===========================================
-- note: the response is latched when ctrl_done=1
--===========================================
architecture hierarchy of i2c_master_core is

signal startclk				:std_logic;
signal execstart				:std_logic;
signal execstop				:std_logic;
signal execwr					:std_logic;
signal execgetack				:std_logic;
signal execrd					:std_logic;
signal execsendack			:std_logic;
signal execsendnak			:std_logic;
signal bytetowrite			:std_logic_vector(7 downto 0);
signal byteread				:std_logic_vector(7 downto 0);	
signal bytereaddv				:std_logic;	
signal completed				:std_logic;
signal failed					:std_logic;

signal scl_i_internal		:std_logic_vector(7 downto 0);					
signal scl_o_internal		:std_logic_vector(7 downto 0);					
signal sda_i_internal		:std_logic_vector(7 downto 0);
signal sda_o_internal		:std_logic_vector(7 downto 0);
 

 
begin




--===========================================
id: process(clk, reset)
--===========================================
	variable en: std_logic;
begin
if reset='1' then
	id_o 	<= x"00";
	en		:= '0';		
elsif rising_edge(clk) then
	if en='0' and enable='1' then -- rising edge detection
		id_o <= id_i;					-- identification of bus owner
	end if;	
	en := enable;
end if;
end process;
--===========================================



--===========================================
u1: entity work.i2c_bitwise
--===========================================
port map
(
	clk				=> clk,
	reset				=> reset,
	------------------------------
	--=== settings ==--
	------------------------------
	enable			=> enable,
	i2c_bus_select	=> bus_select,
	clkprescaler	=> prescaler,
	------------------------------
	--== interface w/ i2cdata ==--
	------------------------------
	startclk_ext	=> startclk,
	execstart_ext	=> execstart,
	execstop_ext	=> execstop,
	execwr_ext		=> execwr,
	execgetack_ext	=> execgetack,
	execrd_ext		=> execrd,
	execsendack_ext=> execsendack,
	execsendnak_ext=> execsendnak,
	bytetowrite_ext=> bytetowrite,
	completed		=> completed,
	failed			=> failed,
	byteread			=> byteread,
	bytereaddv		=> bytereaddv,
	------------------------------
	--== physical interface   ==--
	------------------------------
	scl_o				=> scl_o_internal,
	scl_i				=> scl_i_internal,
	sda_o				=> sda_o_internal,				
	sda_i				=> sda_i_internal				
); 			
--===========================================


--===========================================
map_8: if nbr_of_busses=8 generate
--===========================================
begin

	scl_o	<= scl_o_internal;
				scl_i_internal	<= scl_i;
	sda_o <= sda_o_internal;
				sda_i_internal <= sda_i;				

end generate;
--===========================================



--===========================================
map_less_than_8: if nbr_of_busses<8 generate
--===========================================
begin

	scl_o	<= scl_o_internal(nbr_of_busses-1 downto 0);
				scl_i_internal(nbr_of_busses-1 downto 0) <= scl_i;
				scl_i_internal(              7 downto nbr_of_busses) 	<= (others => 'Z');
	
	sda_o	<= sda_o_internal(nbr_of_busses-1 downto 0);
				sda_i_internal(nbr_of_busses-1 downto 0) <= sda_i;
				sda_i_internal(              7 downto nbr_of_busses) 	<= (others => 'Z');
							
				
end generate;
--===========================================


--===========================================
u2: entity work.i2c_ctrl
--===========================================
port map
(
	clk				=> clk,
	reset				=> reset,
	------------------------------
	--=== settings ==--
	------------------------------
	enable			=> enable,
	clkprescaler	=> prescaler,
	------------------------------
	--=== command  ==--
	------------------------------
	executestrobe	=> command(31),
	extmode			=> command(25), --16bit data
	ralmode			=> command(24),
	writetoslave	=> command(23),
	slaveaddress	=> '0'&  command(22 downto 16),
	slaveregister	=> command(15 downto 8 ),
	datatoslave		=> command( 7 downto 0 ),
	------------------------------
	--== interface w/ i2cdata ==--
	------------------------------
	startclk			=> startclk,
	execstart		=> execstart,
	execstop			=> execstop,
	execwr			=> execwr,
	execgetack		=> execgetack,
	execrd			=> execrd,
	execsendack		=> execsendack,
	execsendnak		=> execsendnak,
	bytetowrite		=> bytetowrite,
	byteread			=> byteread,
	bytereaddv		=> bytereaddv,
	completed		=> completed,
	failed			=> failed,
	------------------------------
	done_o			=> open,
	busy_o			=> open,
	reply_o			=> reply
); 
--===========================================





end hierarchy;
