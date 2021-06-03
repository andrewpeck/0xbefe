-------------------------------------------------------------------------------
-- Copyright (C) 2009 OutputLogic.com 
-- This source file may be used and distributed without restriction 
-- provided that this copyright statement is not removed from the file 
-- and that any derivative work contains the original copyright notice 
-- and the associated disclaimer. 
-- 
-- THIS SOURCE FILE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS 
-- OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED    
-- WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE. 
-------------------------------------------------------------------------------
-- CRC module for data(63:0)
--   lfsr(15:0)=1+x^2+x^15+x^16;
-------------------------------------------------------------------------------
library ieee; 
use ieee.std_logic_1164.all;

entity crc16_usb is 
  port ( data_in : in std_logic_vector (63 downto 0);
    crc_en , rst, clk : in std_logic;
    crc_reg : out std_logic_vector (15 downto 0);
    crc_current : out std_logic_vector (15 downto 0));
end crc16_usb;

architecture crc16_usb_arch of crc16_usb is  
  signal lfsr_q: std_logic_vector (15 downto 0);    
  signal lfsr_c: std_logic_vector (15 downto 0);    
begin   
    crc_reg <= lfsr_q;
    crc_current <= lfsr_c;

    lfsr_c(0) <= lfsr_q(0) xor lfsr_q(1) xor lfsr_q(2) xor lfsr_q(3) xor lfsr_q(4) xor lfsr_q(5) xor lfsr_q(6) xor lfsr_q(7) xor lfsr_q(12) xor lfsr_q(13) xor lfsr_q(14) xor lfsr_q(15) xor data_in(0) xor data_in(1) xor data_in(2) xor data_in(3) xor data_in(4) xor data_in(5) xor data_in(6) xor data_in(7) xor data_in(8) xor data_in(9) xor data_in(10) xor data_in(11) xor data_in(12) xor data_in(13) xor data_in(15) xor data_in(16) xor data_in(17) xor data_in(18) xor data_in(19) xor data_in(20) xor data_in(21) xor data_in(22) xor data_in(23) xor data_in(24) xor data_in(25) xor data_in(26) xor data_in(27) xor data_in(30) xor data_in(31) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(37) xor data_in(38) xor data_in(39) xor data_in(40) xor data_in(41) xor data_in(43) xor data_in(45) xor data_in(46) xor data_in(47) xor data_in(48) xor data_in(49) xor data_in(50) xor data_in(51) xor data_in(52) xor data_in(53) xor data_in(54) xor data_in(55) xor data_in(60) xor data_in(61) xor data_in(62) xor data_in(63);
    lfsr_c(1) <= lfsr_q(0) xor lfsr_q(1) xor lfsr_q(2) xor lfsr_q(3) xor lfsr_q(4) xor lfsr_q(5) xor lfsr_q(6) xor lfsr_q(7) xor lfsr_q(8) xor lfsr_q(13) xor lfsr_q(14) xor lfsr_q(15) xor data_in(1) xor data_in(2) xor data_in(3) xor data_in(4) xor data_in(5) xor data_in(6) xor data_in(7) xor data_in(8) xor data_in(9) xor data_in(10) xor data_in(11) xor data_in(12) xor data_in(13) xor data_in(14) xor data_in(16) xor data_in(17) xor data_in(18) xor data_in(19) xor data_in(20) xor data_in(21) xor data_in(22) xor data_in(23) xor data_in(24) xor data_in(25) xor data_in(26) xor data_in(27) xor data_in(28) xor data_in(31) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(37) xor data_in(38) xor data_in(39) xor data_in(40) xor data_in(41) xor data_in(42) xor data_in(44) xor data_in(46) xor data_in(47) xor data_in(48) xor data_in(49) xor data_in(50) xor data_in(51) xor data_in(52) xor data_in(53) xor data_in(54) xor data_in(55) xor data_in(56) xor data_in(61) xor data_in(62) xor data_in(63);
    lfsr_c(2) <= lfsr_q(8) xor lfsr_q(9) xor lfsr_q(12) xor lfsr_q(13) xor data_in(0) xor data_in(1) xor data_in(14) xor data_in(16) xor data_in(28) xor data_in(29) xor data_in(30) xor data_in(31) xor data_in(42) xor data_in(46) xor data_in(56) xor data_in(57) xor data_in(60) xor data_in(61);
    lfsr_c(3) <= lfsr_q(9) xor lfsr_q(10) xor lfsr_q(13) xor lfsr_q(14) xor data_in(1) xor data_in(2) xor data_in(15) xor data_in(17) xor data_in(29) xor data_in(30) xor data_in(31) xor data_in(32) xor data_in(43) xor data_in(47) xor data_in(57) xor data_in(58) xor data_in(61) xor data_in(62);
    lfsr_c(4) <= lfsr_q(0) xor lfsr_q(10) xor lfsr_q(11) xor lfsr_q(14) xor lfsr_q(15) xor data_in(2) xor data_in(3) xor data_in(16) xor data_in(18) xor data_in(30) xor data_in(31) xor data_in(32) xor data_in(33) xor data_in(44) xor data_in(48) xor data_in(58) xor data_in(59) xor data_in(62) xor data_in(63);
    lfsr_c(5) <= lfsr_q(1) xor lfsr_q(11) xor lfsr_q(12) xor lfsr_q(15) xor data_in(3) xor data_in(4) xor data_in(17) xor data_in(19) xor data_in(31) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(45) xor data_in(49) xor data_in(59) xor data_in(60) xor data_in(63);
    lfsr_c(6) <= lfsr_q(2) xor lfsr_q(12) xor lfsr_q(13) xor data_in(4) xor data_in(5) xor data_in(18) xor data_in(20) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(46) xor data_in(50) xor data_in(60) xor data_in(61);
    lfsr_c(7) <= lfsr_q(3) xor lfsr_q(13) xor lfsr_q(14) xor data_in(5) xor data_in(6) xor data_in(19) xor data_in(21) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(47) xor data_in(51) xor data_in(61) xor data_in(62);
    lfsr_c(8) <= lfsr_q(0) xor lfsr_q(4) xor lfsr_q(14) xor lfsr_q(15) xor data_in(6) xor data_in(7) xor data_in(20) xor data_in(22) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(37) xor data_in(48) xor data_in(52) xor data_in(62) xor data_in(63);
    lfsr_c(9) <= lfsr_q(1) xor lfsr_q(5) xor lfsr_q(15) xor data_in(7) xor data_in(8) xor data_in(21) xor data_in(23) xor data_in(35) xor data_in(36) xor data_in(37) xor data_in(38) xor data_in(49) xor data_in(53) xor data_in(63);
    lfsr_c(10) <= lfsr_q(2) xor lfsr_q(6) xor data_in(8) xor data_in(9) xor data_in(22) xor data_in(24) xor data_in(36) xor data_in(37) xor data_in(38) xor data_in(39) xor data_in(50) xor data_in(54);
    lfsr_c(11) <= lfsr_q(3) xor lfsr_q(7) xor data_in(9) xor data_in(10) xor data_in(23) xor data_in(25) xor data_in(37) xor data_in(38) xor data_in(39) xor data_in(40) xor data_in(51) xor data_in(55);
    lfsr_c(12) <= lfsr_q(4) xor lfsr_q(8) xor data_in(10) xor data_in(11) xor data_in(24) xor data_in(26) xor data_in(38) xor data_in(39) xor data_in(40) xor data_in(41) xor data_in(52) xor data_in(56);
    lfsr_c(13) <= lfsr_q(5) xor lfsr_q(9) xor data_in(11) xor data_in(12) xor data_in(25) xor data_in(27) xor data_in(39) xor data_in(40) xor data_in(41) xor data_in(42) xor data_in(53) xor data_in(57);
    lfsr_c(14) <= lfsr_q(6) xor lfsr_q(10) xor data_in(12) xor data_in(13) xor data_in(26) xor data_in(28) xor data_in(40) xor data_in(41) xor data_in(42) xor data_in(43) xor data_in(54) xor data_in(58);
    lfsr_c(15) <= lfsr_q(0) xor lfsr_q(1) xor lfsr_q(2) xor lfsr_q(3) xor lfsr_q(4) xor lfsr_q(5) xor lfsr_q(6) xor lfsr_q(11) xor lfsr_q(12) xor lfsr_q(13) xor lfsr_q(14) xor lfsr_q(15) xor data_in(0) xor data_in(1) xor data_in(2) xor data_in(3) xor data_in(4) xor data_in(5) xor data_in(6) xor data_in(7) xor data_in(8) xor data_in(9) xor data_in(10) xor data_in(11) xor data_in(12) xor data_in(14) xor data_in(15) xor data_in(16) xor data_in(17) xor data_in(18) xor data_in(19) xor data_in(20) xor data_in(21) xor data_in(22) xor data_in(23) xor data_in(24) xor data_in(25) xor data_in(26) xor data_in(29) xor data_in(30) xor data_in(31) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(37) xor data_in(38) xor data_in(39) xor data_in(40) xor data_in(42) xor data_in(44) xor data_in(45) xor data_in(46) xor data_in(47) xor data_in(48) xor data_in(49) xor data_in(50) xor data_in(51) xor data_in(52) xor data_in(53) xor data_in(54) xor data_in(59) xor data_in(60) xor data_in(61) xor data_in(62) xor data_in(63);


    process (clk,rst) begin 
      if (rst = '1') then 
        lfsr_q <= b"1111111111111111";
      elsif (clk'EVENT and clk = '1') then 
        if (crc_en = '1') then 
          lfsr_q <= lfsr_c; 
        end if; 
      end if; 
    end process; 
end architecture crc16_usb_arch; 