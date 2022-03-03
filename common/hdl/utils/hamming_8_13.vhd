library ieee;
use ieee.std_logic_1164.all;
    
entity hamming_8_13 is
port 
(
      frame_i : in std_logic_vector ( 7 downto 0); -- ttddddeb
	  frame_o : out std_logic_vector(12 downto 0)  -- ttdddddebhhhhh
);
end hamming_8_13;

architecture behavioral of hamming_8_13 is
     
   signal d : std_logic_vector( 7 downto 0); 
   signal h : std_logic_vector( 4 downto 0); 

begin
   
d <= frame_i;

hamming: process(d, h) 
begin
h(0) <= d(0) xor d(1) xor d(2) xor d(3);
h(1) <= d(0) xor d(4) xor d(5) xor d(6);
h(2) <= d(1) xor d(2) xor d(4) xor d(5) xor d(7);
h(3) <= d(1) xor d(3) xor d(4) xor d(6) xor d(7);
h(4) <= h(0) xor h(1) xor h(2) xor h(3) xor d(0) xor d(1) xor d(2) xor d(3) xor d(4) xor d(5) xor d(6) xor d(7);
end process;

frame_o <= d & h; -- PV (I guess so)
   
end behavioral;