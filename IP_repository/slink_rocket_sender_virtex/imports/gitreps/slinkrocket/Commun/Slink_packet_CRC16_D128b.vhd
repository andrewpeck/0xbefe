--------------------------------------------------------------------------------
-- Copyright (C) 1999-2008 Easics NV.
-- This source file may be used and distributed without restriction
-- provided that this copyright statement is not removed from the file
-- and that any derivative work contains the original copyright notice
-- and the associated disclaimer.
--
-- THIS SOURCE FILE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS
-- OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
-- WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
--
-- Purpose : synthesizable CRC function
--   * polynomial: x^16 + x^15 + x^2 + 1
--   * data width: 128
--
-- Info : tools@easics.be
--        http://www.easics.com
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity Slink_packet_CRC16_D128b is
  -- polynomial: x^16 + x^15 + x^2 + 1
  -- data width: 128
  -- convention: the first serial bit is Data[127]
 port (
		clock      	: IN  STD_LOGIC; 
		resetp      : IN  STD_LOGIC; 
		data       	: IN  STD_LOGIC_VECTOR(127 DOWNTO 0); 
		data_valid 	: IN  STD_LOGIC; 
		eoc        	: IN  STD_LOGIC; 
	
		crc        	: OUT STD_LOGIC_VECTOR(15 DOWNTO 0); 
		crc_valid  	: OUT STD_LOGIC 
		);
end Slink_packet_CRC16_D128b;


ARCHITECTURE behave OF  Slink_packet_CRC16_D128b is

  -- polynomial: x^16 + x^15 + x^2 + 1
  -- data width: 128
  -- convention: the first serial bit is Data[127]
 SIGNAL crc_rT		  	: STD_LOGIC_VECTOR(15 DOWNTO 0); -- Total CRC (16 bit)
 SIGNAL crc_8T		   	: STD_LOGIC_VECTOR(15 DOWNTO 0);
 SIGNAL crc_i  		   	: STD_LOGIC_VECTOR(15 DOWNTO 0);
 SIGNAL End_of_crc		: STD_LOGIC;

  begin
	crc_i   	<= crc_rT;

    crc_8T(0)  <= data(127) xor data(125) xor data(124) xor data(123) xor data(122) xor data(121) xor data(120) xor data(111) xor data(110) xor data(109) xor data(108) xor data(107) xor data(106) xor data(105) xor data(103) xor data(101) xor data(99) xor data(97) xor data(96) xor data(95) xor data(94) xor data(93) xor data(92) xor data(91) xor data(90) xor data(87) xor data(86) xor data(83) xor data(82) xor data(81) xor data(80) xor data(79) xor data(78) xor data(77) xor data(76) xor data(75) xor data(73) xor data(72) xor data(71) xor data(69) xor data(68) xor data(67) xor data(66) xor data(65) xor data(64) xor data(63) xor data(62) xor data(61) xor data(60) xor data(55) xor data(54) xor data(53) xor data(52) xor data(51) xor data(50) xor data(49) xor data(48) xor data(47) xor data(46) xor data(45) xor data(43) xor data(41) xor data(40) xor data(39) xor data(38) xor data(37) xor data(36) xor data(35) xor data(34) xor data(33) xor data(32) xor data(31) xor data(30) xor data(27) xor data(26) xor data(25) xor data(24) xor data(23) xor data(22) xor data(21) xor data(20) xor data(19) xor data(18) xor data(17) xor data(16) xor data(15) xor data(13) xor data(12) xor data(11) xor data(10) xor data(9) xor data(8) xor data(7) xor data(6) xor data(5) xor data(4) xor data(3) xor data(2) xor data(1) xor data(0) xor crc_i(8) xor crc_i(9) xor crc_i(10) xor crc_i(11) xor crc_i(12) xor crc_i(13) xor crc_i(15);
    crc_8T(1)  <= data(126) xor data(125) xor data(124) xor data(123) xor data(122) xor data(121) xor data(112) xor data(111) xor data(110) xor data(109) xor data(108) xor data(107) xor data(106) xor data(104) xor data(102) xor data(100) xor data(98) xor data(97) xor data(96) xor data(95) xor data(94) xor data(93) xor data(92) xor data(91) xor data(88) xor data(87) xor data(84) xor data(83) xor data(82) xor data(81) xor data(80) xor data(79) xor data(78) xor data(77) xor data(76) xor data(74) xor data(73) xor data(72) xor data(70) xor data(69) xor data(68) xor data(67) xor data(66) xor data(65) xor data(64) xor data(63) xor data(62) xor data(61) xor data(56) xor data(55) xor data(54) xor data(53) xor data(52) xor data(51) xor data(50) xor data(49) xor data(48) xor data(47) xor data(46) xor data(44) xor data(42) xor data(41) xor data(40) xor data(39) xor data(38) xor data(37) xor data(36) xor data(35) xor data(34) xor data(33) xor data(32) xor data(31) xor data(28) xor data(27) xor data(26) xor data(25) xor data(24) xor data(23) xor data(22) xor data(21) xor data(20) xor data(19) xor data(18) xor data(17) xor data(16) xor data(14) xor data(13) xor data(12) xor data(11) xor data(10) xor data(9) xor data(8) xor data(7) xor data(6) xor data(5) xor data(4) xor data(3) xor data(2) xor data(1) xor crc_i(0) xor crc_i(9) xor crc_i(10) xor crc_i(11) xor crc_i(12) xor crc_i(13) xor crc_i(14);
    crc_8T(2)  <= data(126) xor data(121) xor data(120) xor data(113) xor data(112) xor data(106) xor data(98) xor data(91) xor data(90) xor data(89) xor data(88) xor data(87) xor data(86) xor data(85) xor data(84) xor data(76) xor data(74) xor data(72) xor data(70) xor data(61) xor data(60) xor data(57) xor data(56) xor data(46) xor data(42) xor data(31) xor data(30) xor data(29) xor data(28) xor data(16) xor data(14) xor data(1) xor data(0) xor crc_i(0) xor crc_i(1) xor crc_i(8) xor crc_i(9) xor crc_i(14);
    crc_8T(3)  <= data(127) xor data(122) xor data(121) xor data(114) xor data(113) xor data(107) xor data(99) xor data(92) xor data(91) xor data(90) xor data(89) xor data(88) xor data(87) xor data(86) xor data(85) xor data(77) xor data(75) xor data(73) xor data(71) xor data(62) xor data(61) xor data(58) xor data(57) xor data(47) xor data(43) xor data(32) xor data(31) xor data(30) xor data(29) xor data(17) xor data(15) xor data(2) xor data(1) xor crc_i(1) xor crc_i(2) xor crc_i(9) xor crc_i(10) xor crc_i(15);
    crc_8T(4)  <= data(123) xor data(122) xor data(115) xor data(114) xor data(108) xor data(100) xor data(93) xor data(92) xor data(91) xor data(90) xor data(89) xor data(88) xor data(87) xor data(86) xor data(78) xor data(76) xor data(74) xor data(72) xor data(63) xor data(62) xor data(59) xor data(58) xor data(48) xor data(44) xor data(33) xor data(32) xor data(31) xor data(30) xor data(18) xor data(16) xor data(3) xor data(2) xor crc_i(2) xor crc_i(3) xor crc_i(10) xor crc_i(11);
    crc_8T(5)  <= data(124) xor data(123) xor data(116) xor data(115) xor data(109) xor data(101) xor data(94) xor data(93) xor data(92) xor data(91) xor data(90) xor data(89) xor data(88) xor data(87) xor data(79) xor data(77) xor data(75) xor data(73) xor data(64) xor data(63) xor data(60) xor data(59) xor data(49) xor data(45) xor data(34) xor data(33) xor data(32) xor data(31) xor data(19) xor data(17) xor data(4) xor data(3) xor crc_i(3) xor crc_i(4) xor crc_i(11) xor crc_i(12);
    crc_8T(6)  <= data(125) xor data(124) xor data(117) xor data(116) xor data(110) xor data(102) xor data(95) xor data(94) xor data(93) xor data(92) xor data(91) xor data(90) xor data(89) xor data(88) xor data(80) xor data(78) xor data(76) xor data(74) xor data(65) xor data(64) xor data(61) xor data(60) xor data(50) xor data(46) xor data(35) xor data(34) xor data(33) xor data(32) xor data(20) xor data(18) xor data(5) xor data(4) xor crc_i(4) xor crc_i(5) xor crc_i(12) xor crc_i(13);
    crc_8T(7)  <= data(126) xor data(125) xor data(118) xor data(117) xor data(111) xor data(103) xor data(96) xor data(95) xor data(94) xor data(93) xor data(92) xor data(91) xor data(90) xor data(89) xor data(81) xor data(79) xor data(77) xor data(75) xor data(66) xor data(65) xor data(62) xor data(61) xor data(51) xor data(47) xor data(36) xor data(35) xor data(34) xor data(33) xor data(21) xor data(19) xor data(6) xor data(5) xor crc_i(5) xor crc_i(6) xor crc_i(13) xor crc_i(14);
    crc_8T(8)  <= data(127) xor data(126) xor data(119) xor data(118) xor data(112) xor data(104) xor data(97) xor data(96) xor data(95) xor data(94) xor data(93) xor data(92) xor data(91) xor data(90) xor data(82) xor data(80) xor data(78) xor data(76) xor data(67) xor data(66) xor data(63) xor data(62) xor data(52) xor data(48) xor data(37) xor data(36) xor data(35) xor data(34) xor data(22) xor data(20) xor data(7) xor data(6) xor crc_i(0) xor crc_i(6) xor crc_i(7) xor crc_i(14) xor crc_i(15);
    crc_8T(9)  <= data(127) xor data(120) xor data(119) xor data(113) xor data(105) xor data(98) xor data(97) xor data(96) xor data(95) xor data(94) xor data(93) xor data(92) xor data(91) xor data(83) xor data(81) xor data(79) xor data(77) xor data(68) xor data(67) xor data(64) xor data(63) xor data(53) xor data(49) xor data(38) xor data(37) xor data(36) xor data(35) xor data(23) xor data(21) xor data(8) xor data(7) xor crc_i(1) xor crc_i(7) xor crc_i(8) xor crc_i(15);
    crc_8T(10) <= data(121) xor data(120) xor data(114) xor data(106) xor data(99) xor data(98) xor data(97) xor data(96) xor data(95) xor data(94) xor data(93) xor data(92) xor data(84) xor data(82) xor data(80) xor data(78) xor data(69) xor data(68) xor data(65) xor data(64) xor data(54) xor data(50) xor data(39) xor data(38) xor data(37) xor data(36) xor data(24) xor data(22) xor data(9) xor data(8) xor crc_i(2) xor crc_i(8) xor crc_i(9);
    crc_8T(11) <= data(122) xor data(121) xor data(115) xor data(107) xor data(100) xor data(99) xor data(98) xor data(97) xor data(96) xor data(95) xor data(94) xor data(93) xor data(85) xor data(83) xor data(81) xor data(79) xor data(70) xor data(69) xor data(66) xor data(65) xor data(55) xor data(51) xor data(40) xor data(39) xor data(38) xor data(37) xor data(25) xor data(23) xor data(10) xor data(9) xor crc_i(3) xor crc_i(9) xor crc_i(10);
    crc_8T(12) <= data(123) xor data(122) xor data(116) xor data(108) xor data(101) xor data(100) xor data(99) xor data(98) xor data(97) xor data(96) xor data(95) xor data(94) xor data(86) xor data(84) xor data(82) xor data(80) xor data(71) xor data(70) xor data(67) xor data(66) xor data(56) xor data(52) xor data(41) xor data(40) xor data(39) xor data(38) xor data(26) xor data(24) xor data(11) xor data(10) xor crc_i(4) xor crc_i(10) xor crc_i(11);
    crc_8T(13) <= data(124) xor data(123) xor data(117) xor data(109) xor data(102) xor data(101) xor data(100) xor data(99) xor data(98) xor data(97) xor data(96) xor data(95) xor data(87) xor data(85) xor data(83) xor data(81) xor data(72) xor data(71) xor data(68) xor data(67) xor data(57) xor data(53) xor data(42) xor data(41) xor data(40) xor data(39) xor data(27) xor data(25) xor data(12) xor data(11) xor crc_i(5) xor crc_i(11) xor crc_i(12);
    crc_8T(14) <= data(125) xor data(124) xor data(118) xor data(110) xor data(103) xor data(102) xor data(101) xor data(100) xor data(99) xor data(98) xor data(97) xor data(96) xor data(88) xor data(86) xor data(84) xor data(82) xor data(73) xor data(72) xor data(69) xor data(68) xor data(58) xor data(54) xor data(43) xor data(42) xor data(41) xor data(40) xor data(28) xor data(26) xor data(13) xor data(12) xor crc_i(6) xor crc_i(12) xor crc_i(13);
    crc_8T(15) <= data(127) xor data(126) xor data(124) xor data(123) xor data(122) xor data(121) xor data(120) xor data(119) xor data(110) xor data(109) xor data(108) xor data(107) xor data(106) xor data(105) xor data(104) xor data(102) xor data(100) xor data(98) xor data(96) xor data(95) xor data(94) xor data(93) xor data(92) xor data(91) xor data(90) xor data(89) xor data(86) xor data(85) xor data(82) xor data(81) xor data(80) xor data(79) xor data(78) xor data(77) xor data(76) xor data(75) xor data(74) xor data(72) xor data(71) xor data(70) xor data(68) xor data(67) xor data(66) xor data(65) xor data(64) xor data(63) xor data(62) xor data(61) xor data(60) xor data(59) xor data(54) xor data(53) xor data(52) xor data(51) xor data(50) xor data(49) xor data(48) xor data(47) xor data(46) xor data(45) xor data(44) xor data(42) xor data(40) xor data(39) xor data(38) xor data(37) xor data(36) xor data(35) xor data(34) xor data(33) xor data(32) xor data(31) xor data(30) xor data(29) xor data(26) xor data(25) xor data(24) xor data(23) xor data(22) xor data(21) xor data(20) xor data(19) xor data(18) xor data(17) xor data(16) xor data(15) xor data(14) xor data(12) xor data(11) xor data(10) xor data(9) xor data(8) xor data(7) xor data(6) xor data(5) xor data(4) xor data(3) xor data(2) xor data(1) xor data(0) xor crc_i(7) xor crc_i(8) xor crc_i(9) xor crc_i(10) xor crc_i(11) xor crc_i(12) xor crc_i(14) xor crc_i(15);

	 
crc_gen_process : PROCESS(clock) 
BEGIN                                    
 IF rising_edge(clock) THEN 
	IF resetp = '1' then
		crc_rT 	<= (others => '1') ;
    ELSIF(data_valid = '1') THEN 
		crc_rT 	<= crc_8T;
    END IF; 
    End_of_crc <= eoc and data_valid;

 END IF;    
END PROCESS crc_gen_process;      
    
crc_valid		<= End_of_crc;
crc 			<= crc_rT;
 	
		

end behave;	 
