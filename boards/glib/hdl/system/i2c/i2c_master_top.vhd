library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;

entity i2c_master_top is
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
	-- io pins -----
	scl_io		:inout	std_logic_vector(nbr_of_busses-1 downto 0);					
	sda_io		:inout	std_logic_vector(nbr_of_busses-1 downto 0)
	
	
); 			
end i2c_master_top;

architecture iobufs of i2c_master_top is

	signal sda_i_master 	: std_logic_vector(nbr_of_busses-1 downto 0);
	signal sda_o_master 	: std_logic_vector(nbr_of_busses-1 downto 0);
	signal scl_i_master 	: std_logic_vector(nbr_of_busses-1 downto 0);
	signal scl_o_master 	: std_logic_vector(nbr_of_busses-1 downto 0);

begin

	--===========================================
	core: entity work.i2c_master_core
	--===========================================
	generic map (nbr_of_busses => nbr_of_busses)
	port map
	(
		clk			=> clk			 	,
		reset			=> reset				,
		--
		id_i			=> id_i				,
		id_o			=> id_o				,
		enable		=> enable			,
		bus_select	=> bus_select		,
		prescaler	=> prescaler		,
		command		=> command			,
		reply			=> reply				,
		------------
		scl_i			=> scl_i_master	, 				
		scl_o			=> scl_o_master	, 
		sda_i			=> sda_i_master	, 
		sda_o			=> sda_o_master	
	); 			
	--===========================================



	--===========================================
	bufgen: for i in 0 to nbr_of_busses-1 generate
	--===========================================
	begin
		scl_buf: iobuf port map (o => scl_i_master(i),  io => scl_io(i),    i => '0',  t => scl_o_master(i)); -- 3-state enable input, high=input, low=output 
		sda_buf: iobuf port map (o => sda_i_master(i),  io => sda_io(i),    i => '0',  t => sda_o_master(i)); -- 3-state enable input, high=input, low=output 
	end generate;
	--===========================================


end iobufs;
