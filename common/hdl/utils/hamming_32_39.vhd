library ieee;
use ieee.std_logic_1164.all;
    
entity hamming_32_39 is
port 
(
      frame_i : in std_logic_vector (31 downto 0); -- aaaaaaaaaaaaaae1ssssssssdddddddd
	  frame_o : out std_logic_vector(38 downto 0)  -- aaaaaaaaaaaaaae1ssssssssddddddddhhhhhhh
);
end hamming_32_39; 

architecture behavioral of hamming_32_39 is
     
   signal d : std_logic_vector(31 downto 0); 
   signal h : std_logic_vector( 6 downto 0); 

begin
   
d <= frame_i;

hamming: process(d, h) 
begin
h(0) <= d(0) xor d(1) xor d(2) xor d(3) xor d(4)  xor d(5); 
h(1) <= d(6) xor d(7) xor d(8) xor d(9) xor d(10) xor d(11) xor d(12) xor d(13) xor d(14) xor d(15) xor d(16) xor d(17) xor d(18) xor d(19) xor d(20);
h(2) <= d(6) xor d(7) xor d(8) xor d(9) xor d(10) xor d(11) xor d(12) xor d(13) xor d(21) xor d(22) xor d(23) xor d(24) xor d(25) xor d(26) xor d(27);
h(3) <= d(0) xor d(1) xor d(2) xor d(6) xor d(7)  xor d(8)  xor d(9)  xor d(14) xor d(15) xor d(16) xor d(17) xor d(21) xor d(22) xor d(23) xor d(24) xor d(28) xor d(29) xor d(30);
h(4) <= d(0) xor d(3) xor d(4) xor d(6) xor d(7)  xor d(10) xor d(11) xor d(14) xor d(15) xor d(18) xor d(19) xor d(21) xor d(22) xor d(25) xor d(26) xor d(28) xor d(29) xor d(31);
h(5) <= d(1) xor d(3) xor d(5) xor d(6) xor d(8)  xor d(10) xor d(12) xor d(14) xor d(16) xor d(18) xor d(20) xor d(21) xor d(23) xor d(25) xor d(27) xor d(28) xor d(30) xor d(31);
h(6) <= h(0) xor h(1) xor h(2) xor h(3) xor h(4)  xor h(5)  xor d(0)  xor d(1)  xor d(2)  xor d(3)  xor d(4)  xor d(5)  xor d(6)  xor d(7)  xor d(8)  xor d(9)  xor d(10) xor d(11) xor d(12) xor d(13) xor d(14) xor d(15) xor d(16) xor d(17) xor d(18) xor d(19) xor d(20) xor d(21) xor d(22) xor d(23) xor d(24) xor d(25) xor d(26) xor d(27) xor d(28) xor d(29) xor d(30) xor d(31);
end process;

frame_o <= d & h; -- PV (I guess so)
   
end behavioral;