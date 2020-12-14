--------------------------------------------------
-- file:		i2cmaster_data.vhd
-- author:		p.vichoudis
--------------------------------------------------
-- description:	the data part of the i2c master
--------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity i2c_bitwise is
port
(
	clk					: in  	std_logic;
	reset					: in  	std_logic;
	enable				: in  	std_logic;
	------------------------------
	clkprescaler		: in  	std_logic_vector(9 downto 0);
	startclk_ext		: in  	std_logic;
	execstart_ext		: in  	std_logic;
	execstop_ext		: in  	std_logic;
	execwr_ext			: in  	std_logic;
	execgetack_ext		: in  	std_logic;
	execrd_ext			: in  	std_logic;
	execsendack_ext	: in  	std_logic;
	execsendnak_ext	: in  	std_logic;
	bytetowrite_ext	: in  	std_logic_vector(7 downto 0);
	byteread				: out 	std_logic_vector(7 downto 0);
	bytereaddv			: out 	std_logic;
	i2c_bus_select		: in		std_logic_vector(2 downto 0);					
	------------------------------
	completed			: out  	std_logic;
	failed				: out  	std_logic;
	------------------------------
	scl_i					:in		std_logic_vector(7 downto 0);					
	scl_o					:out		std_logic_vector(7 downto 0);					
	sda_i					:in		std_logic_vector(7 downto 0);					
	sda_o					:out		std_logic_vector(7 downto 0)
); 			

end i2c_bitwise;

architecture behave of i2c_bitwise is

signal exec				: std_logic;
signal addr				: std_logic_vector(7 downto 0);
signal datain			: std_logic_vector(7 downto 0);
signal wr				: std_logic;
signal prescaler		: std_logic_vector(9 downto 0);

signal en				: std_logic;
signal startclk		: std_logic;
signal execstart		: std_logic;
signal execstop 		: std_logic;
signal execwr			: std_logic;
signal execgetack		: std_logic;
signal execrd			: std_logic;
signal execsendack	: std_logic;
signal execsendnak	: std_logic;
signal bytetowrite	: std_logic_vector(7 downto 0);



signal wrbit			: std_logic;
signal rdbit			: std_logic;
signal sclbit			: std_logic;
signal dv				: std_logic;
	
type datafsm_type	is 
(idle, 
startcondition_1, startcondition_2,
stopcondition_1 , stopcondition_2,
writebyte,
getack,
readbyte,
sendack, sendnak
);
signal datafsm	: datafsm_type;

attribute keep: boolean;
attribute keep of rdbit				: signal is true;
attribute keep of sda_i				: signal is true;


begin
--========================--
reg_in:process(clk, reset)
--========================--
begin
if reset='1' then
	
	en				<= '0';
	prescaler	<= (others=>'0');

elsif clk'event and clk='1' then
	
	en				<= enable;
	prescaler	<= clkprescaler;

end if;		
end process;

	startclk		<= startclk_ext;
	execstart	<= execstart_ext;
	execstop		<= execstop_ext;
	execwr		<= execwr_ext;
	execgetack	<= execgetack_ext;
	execrd		<= execrd_ext;
	execsendack	<= execsendack_ext;
	execsendnak	<= execsendnak_ext;
	bytetowrite	<= bytetowrite_ext;


--========================--
i2cscl:process(clk, reset)
--========================--
	variable timer : std_logic_vector(9 downto 0);
	variable level : std_logic;
	variable clkhasstarted : std_logic;
begin
if reset='1' then
	sclbit	<= '1';
	level 	:= '1';
	clkhasstarted := '0';
	
elsif clk'event and clk='1' then
	if en='1' then
		if clkhasstarted='1' then
			if timer=1 then
				level := not level; sclbit <= level; 
				timer	:= '0' & prescaler(9 downto 1);
			else
				timer	:= timer-1;
			end if;
		elsif startclk='1' then		
			level 	:= '0'; sclbit <= level;
			timer	:= '0' & prescaler(9 downto 1);
			clkhasstarted :='1';
		end if;
	else
		sclbit  <= '1';
		level	:= '0';
		clkhasstarted := '0';
		timer:= '0' & prescaler(9 downto 1);
	end if;
end if;
end process;

--========================--
i2csda:process(clk, reset)
--========================--
	variable timer : std_logic_vector(9 downto 0);
	variable byte  : std_logic_vector(7 downto 0);
	variable cnt   : integer range 0 to 15;
	variable ack   : std_logic;	
	variable samplingtime : std_logic_vector(9 downto 0);	
begin
if reset='1' then

	dv			<= '0';
	wrbit		<= '1';  -- read
	datafsm 	<= idle;
	
elsif clk'event and clk='1' then
	
	
	bytereaddv 	<= dv;
	dv 			<='0';
		
	--=========--
	case datafsm is
	--=========--

		--=========--
		when idle =>
		--=========--
			completed 	<= '0';
			failed 		<= '0';
			ack	  		:= '1';
			if execstart='1' then
				datafsm <= startcondition_1;
				timer := "0" & prescaler(9 downto 1);
			elsif execstop='1' then
				datafsm <= stopcondition_1;
				timer := "0" & prescaler(9 downto 1);
			elsif execwr='1' then
				datafsm <= writebyte;
				timer := "00" & prescaler(9 downto 2); --x"01";
				byte  := bytetowrite;
				cnt	  := 8;		
			elsif execgetack='1' then
				datafsm <= getack;
				timer := prescaler;
--				samplingtime:= prescaler - prescaler(9 downto 2);
			elsif execrd='1' then
				datafsm <= readbyte;
				timer := prescaler;
--				samplingtime:= prescaler - prescaler(9 downto 2);
				byte  := (others=>'0');
				cnt	  := 7;		
			elsif execsendack='1' then
				datafsm <= sendack;
				timer := prescaler;
			else
				datafsm <= idle;
			end if;	
		
		--@@@@@@@@@@@@@@@@@@@@@@@@@@@@-
		--@@@@ start condition
		--@@@@@@@@@@@@@@@@@@@@@@@@@@@@

		--=========--
		when startcondition_1 =>
		--=========--
			wrbit	<='1';
			if timer=1 then
				datafsm <= startcondition_2;
				timer := "00" & prescaler(9 downto 2);
			else
				timer:=timer-1;
			end if;
		
		--=========--
		when startcondition_2 =>
		--=========--
			if timer=1 then
				wrbit	<='0';
				datafsm <= idle;
			else
				timer:=timer-1;
			end if;

		--@@@@@@@@@@@@@@@@@@@@@@@@@@@@-
		--@@@@ stop condition
		--@@@@@@@@@@@@@@@@@@@@@@@@@@@@
		
		--=========--
		when stopcondition_1 =>
		--=========--
			wrbit	<='0';
			if timer=1 then
				datafsm <= stopcondition_2;
				timer := "00" & prescaler(9 downto 2);
			else
				timer:=timer-1;
			end if;
		
		--=========--
		when stopcondition_2 =>
		--=========--
			if timer=1 then
				wrbit	<='1';
				datafsm <= idle;
			else
				timer:=timer-1;
			end if;	

		--@@@@@@@@@@@@@@@@@@@@@@@@@@@@-
		--@@@@ write byte
		--@@@@@@@@@@@@@@@@@@@@@@@@@@@@

		--=========--
		when writebyte =>
		--=========--
			if timer=(prescaler(9 downto 2)+2) and cnt=0 then
				datafsm <= idle;
			elsif timer=1 then
				timer := prescaler;
				wrbit <= byte(7); byte:=byte(6 downto 0) & '0';
				cnt:=cnt-1;
			else
				timer:=timer-1;
			end if;	

		--@@@@@@@@@@@@@@@@@@@@@@@@@@@@-
		--@@@@ get ack
		--@@@@@@@@@@@@@@@@@@@@@@@@@@@@

		--=========--
		when getack =>
		--=========--

			completed <= '0'; 
			failed <= '0';
			wrbit	<='1'; -- read
			if timer=2 then
				datafsm <= idle;
			else
				--if timer=samplingtime then 
				if timer=prescaler(9 downto 2) then -- rising when timer=presc/2, falling when timer=presc, sampling when timer=presc/4
					ack:=rdbit; 
					if ack='0' then 
						completed <= '1'; failed <= '0';
					else
						completed <= '0'; failed <= '1';
					end if;
				end if;
				timer:=timer-1;
			end if;	

		--=========--
		when readbyte =>
		--=========--
			wrbit	<='1'; -- read
			if timer=2 and cnt=0 then
				datafsm <= idle;
				byteread <= byte; dv <= '1';
			elsif timer=1 then
				timer := prescaler;
				cnt:=cnt-1;
			else
--				if timer=samplingtime then byte:=byte(6 downto 0) & rdbit; end if;
				if timer=prescaler(9 downto 2) then -- rising when timer=presc/2, falling when timer=presc, sampling when timer=presc/4
					byte:=byte(6 downto 0) & rdbit; 
				end if;
				timer:=timer-1;
			end if;	

		--=========--
		when sendack =>
		--=========--
			wrbit <= '0'; 
			if timer=2 then
				datafsm <= idle;
			else
				timer:=timer-1;
			end if;	

		--=========--
		when sendnak =>
		--=========--
			wrbit <= '1'; --'0'; 
			if timer=2 then
				datafsm <= idle;
			else
				timer:=timer-1;
			end if;	

		end case;

end if;
end process;








rdbit		<= sda_i(0) when (i2c_bus_select="000") 									else 
				sda_i(1) when (i2c_bus_select="001") 									else 
				sda_i(2) when (i2c_bus_select="010") 									else 
				sda_i(3) when (i2c_bus_select="011") 									else 
				sda_i(4) when (i2c_bus_select="100") 									else 
				sda_i(5) when (i2c_bus_select="101") 									else 
				sda_i(6) when (i2c_bus_select="110") 									else 
				sda_i(7) when (i2c_bus_select="111") 									else 
				'1';

sda_o(0) 	<= '0'	when (i2c_bus_select="000" and wrbit='0' and en='1') 	else 'Z';
sda_o(1) 	<= '0'	when (i2c_bus_select="001" and wrbit='0' and en='1') 	else 'Z';
sda_o(2) 	<= '0'	when (i2c_bus_select="010" and wrbit='0' and en='1') 	else 'Z';
sda_o(3) 	<= '0'	when (i2c_bus_select="011" and wrbit='0' and en='1') 	else 'Z';
sda_o(4) 	<= '0'	when (i2c_bus_select="100" and wrbit='0' and en='1') 	else 'Z';
sda_o(5) 	<= '0'	when (i2c_bus_select="101" and wrbit='0' and en='1') 	else 'Z';
sda_o(6) 	<= '0'	when (i2c_bus_select="110" and wrbit='0' and en='1') 	else 'Z';
sda_o(7) 	<= '0'	when (i2c_bus_select="111" and wrbit='0' and en='1') 	else 'Z';


-- scl_i
scl_o(0) 	<= '0'	when (i2c_bus_select="000" and sclbit='0' and en='1')	else 'Z';
scl_o(1) 	<= '0'	when (i2c_bus_select="001" and sclbit='0' and en='1')	else 'Z';
scl_o(2) 	<= '0'	when (i2c_bus_select="010" and sclbit='0' and en='1')	else 'Z';
scl_o(3) 	<= '0'	when (i2c_bus_select="011" and sclbit='0' and en='1')	else 'Z';
scl_o(4) 	<= '0'	when (i2c_bus_select="100" and sclbit='0' and en='1')	else 'Z';
scl_o(5) 	<= '0'	when (i2c_bus_select="101" and sclbit='0' and en='1')	else 'Z';
scl_o(6) 	<= '0'	when (i2c_bus_select="110" and sclbit='0' and en='1')	else 'Z';
scl_o(7) 	<= '0'	when (i2c_bus_select="111" and sclbit='0' and en='1')	else 'Z';


end behave;