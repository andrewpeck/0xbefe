library IEEE;
library WORK;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;

package mydefs is
	constant version : std_logic_vector(31 downto 0) := x"5E100300";
	constant	FPGA_Brand: string	:= "XILINX";
end package mydefs;

-- version .......
--*****************************************************************
-- version "5E100300"	14/07/2020
-- Add support on Ultrascale
-- add clock 4 generated by GT
--*****************************************************************
-- version "5E100203"	14/07/2020
-- Fixe the problem of 64 bit swapped
-- transceiver link sync problem fixed
--*****************************************************************
-- version "5E100202"	25/04/2020
-- Bug in loopback Only  CDRHold = '1'and select PCS near loopback
-- Do not reset the loopback register
-- set to 0x0 the txpostcursor_in by default
--*****************************************************************
-- version "5E100201"	19/02/2020
-- Introduce the Clocks RX TX sharing between SERDES of a same QUAD
-- Clock_source							: string := "Master";  --or "Slave"
-- move the place of freq_used in the freq_measure.vhd file to be changed by the throughput parameter
--*****************************************************************
-- version "5E100101"	25/10/2019
-- Change the reset of the FIFO_resync in FED_itf
--*****************************************************************
--*****************************************************************
