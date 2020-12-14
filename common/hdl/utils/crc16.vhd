library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


--  Taken from SOL40_SCA IP
--  Default parameters produce a CRC16-CCITT output.
--  When checking, correct reception is signaled by a zero in the crc
--  output.
--
--  Parameters:
--
--  CRC_WIDTH	    bit width of the crc output;
--
--  DATA_WIDTH	    bit width of the data input (must be at least 2);
--  	    	    
--  INIT_VAL	    initialization value of the crc register,
--  	    	    suggested values are all-zeros and all-ones;
--
--  POLY    	    Polynomial (remeber to reverse it)
--  	    	    i.e. CCITT 1021h has POLY = 'h8408.
--
--------------------------------------------------------------------

entity crc16 is
	generic(
		CRC_WIDTH	:	natural := 16;
		DATA_WIDTH	:	natural	:= 80;--16
		INIT_VAL	:	std_logic_vector((2*8)-1 downto 0) := x"ffff";
		POLY		:	std_logic_vector((2*8)-1 downto 0) := x"8408"
	);
	port (
		d 			: 	in	std_logic_vector(DATA_WIDTH-1 downto 0);
		init		:	in	std_logic;
		d_valid		:	in	std_logic;
		clk			:	in	std_logic;
		reset_b		:	in	std_logic;
		crc_o		: 	out	std_logic_vector(CRC_WIDTH-1 downto 0)
	);
end entity crc16;


architecture RTL of crc16 is

	--! Internal Wires and Regs
	signal next_crc		:	std_logic_vector(CRC_WIDTH-1 downto 0);
	signal crc_int		:	std_logic_vector(CRC_WIDTH-1 downto 0);
	
	type crc_array_t is array (integer range<>) of std_logic_vector((CRC_WIDTH-1) downto 0);
	
	--
	
	function crc_atom (
		crc_in	:	std_logic_vector(CRC_WIDTH - 1 downto 0);
		d		:	std_logic
	)
		return  std_logic_vector is
		variable value	:	std_logic_vector(crc_in'high downto 0);
	begin
		if ((crc_in(0) xor d)='0') then
			value := std_logic_vector(unsigned(crc_in) srl 1);
			
		 else
			value := (std_logic_vector(unsigned(crc_in) srl 1)) xor POLY((CRC_WIDTH-1) downto 0);			
		end if;
		
		return value;
	end function crc_atom;
	
	
	
	function crc_calc (
		
		crc_i	:	std_logic_vector(CRC_WIDTH-1 downto 0);
		d		:	std_logic_vector(DATA_WIDTH-1 downto 0)
		)
		return std_logic_vector is
		
		variable p_crc	:	crc_array_t(0 to DATA_WIDTH-2);
		variable value 	:	std_logic_vector(CRC_WIDTH-1 downto 0);
	begin
		
		p_crc(0) := crc_atom(crc_i, d(0));
		for i in 1 to DATA_WIDTH-2 loop
			p_crc(i) := crc_atom(p_crc(i-1), d(i));
		end loop; 
		
		
		value := crc_atom(p_crc(DATA_WIDTH-2), d(DATA_WIDTH-1));
		
		return value;
	end function crc_calc;
	
	
	
begin
	
	
	
	d_or_crc_i_init : process(d,crc_int,init) is
	begin
		if (init = '1') then
			next_crc <= crc_calc(INIT_VAL, d);
		else
			next_crc <= crc_calc(crc_int,d);
		end if;
		--next_crc <= crc_calc(crc_i,d);
		
	end process d_or_crc_i_init;
	
	--! synopsys async_set_reset "reset_b"
	synopsys_async_set_reset : process (clk, reset_b) is
	begin
		if reset_b = '0' then
			crc_int <=  INIT_VAL;
		elsif rising_edge(clk) then
			
			if (init and (not d_valid))='1' then
				crc_int <=INIT_VAL;
			elsif (d_valid='1') then
				crc_int <= next_crc;
			else
				crc_int <= crc_int;
			end if;
			
		end if;
	end process synopsys_async_set_reset;
	
	crc_o <= crc_int;
	
	

end architecture RTL;
