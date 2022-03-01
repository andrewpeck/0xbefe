------------------------------------------------------
-- Component Memory Dual port
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


entity Memory is
port 	(
		clock	: in std_logic;
		
		addr_w	: in std_logic_vector(9 downto 0);
		data_w	: in std_logic_vector(127 downto 0);
		wen		: in std_logic;
		
		addr_r	: in std_logic_vector(9 downto 0);
		ren		: in std_logic;
		data_r	: out std_logic_vector(127 downto 0)
	);
end Memory;

architecture behavioral of Memory is

 
--***********************************************************
--**********************  XILIXN DC FIFO  *******************
--***********************************************************
 --Block Memory Generator
 --		Native
 --		Simple Dual Port RAM    Common clock
 --		No ECC
 --		Width   128 bits
--		Depth 	2048
--		Write First Use ENA pin
 
 
COMPONENT SR_DP_memory_core_IP
  PORT (
    clka  : IN STD_LOGIC;
    ena   : IN STD_LOGIC;
    wea   : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    dina  : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    clkb  : IN STD_LOGIC;
    enb   : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(127 DOWNTO 0)
  );
END COMPONENT;
 
--***********************************************************
--**********************  BEGIN  ****************************
--***********************************************************
begin
 
 
mem_dp:SR_DP_memory_core_IP
    PORT MAP(
      clka      => clock        , 
      ena       => wen          , 
      wea(0)    => wen          , 
      addra     => addr_w       , 
      dina      => data_w       , 
      clkb      => clock        , 
      enb       => ren          , 
      addrb     => addr_r       , 
      doutb     => data_r         
    ); 
 
 
end behavioral;