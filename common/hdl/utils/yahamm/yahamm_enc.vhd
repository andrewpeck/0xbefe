-------------------------------------------------------------------------------
-- Yahamm IP core
--
-- This file is part of the Yahamm project
-- http://www.opencores.org/cores/yahamm
--
-- Description
-- A hamming encoder and decoder with single-error correcting and
-- double-error detecting capability. The message length can be configured
-- through a generic. Both the code generator matrix and the parity-check
-- matrix are computed in the VHDL itself.
--
-- Author:
-- - Nicola De Simone, ndesimone@opencores.org
--
-------------------------------------------------------------------------------
--
-- Copyright (C) 2017 Authors and OPENCORES.ORG
--
-- This source file may be used and distributed without
-- restriction provided that this copyright statement is not
-- removed from the file and that any derivative work contains
-- the original copyright notice and the associated disclaimer.
--
-- This source file is free software; you can redistribute it
-- and/or modify it under the terms of the GNU Lesser General
-- Public License as published by the Free Software Foundation;
-- either version 2.1 of the License, or (at your option) any
-- later version.
--
-- This source is distributed in the hope that it will be
-- useful, but WITHOUT ANY WARRANTY; without even the implied
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
-- PURPOSE. See the GNU Lesser General Public License for more
-- details.
--
--- You should have received a copy of the GNU Lesser General
-- Public License along with this source; if not, download it
-- from http://www.opencores.org/lgpl.shtml
--
-------------------------------------------------------------------------------

-- CORRECT: set to true to correct errors at the cost of decreasing error
-- detection (see table).
--
-- SEC = single bit error corrected
-- SED = single bit error detected
-- DED = double bit error detected
-- TED = triple bit error detected
--
-- EXTRA_PARITY_BIT | CORRECT       FALSE           TRUE
-------------------------------------------------------------------------------
--      FALSE       |               SED-DED         SEC
--                  -----------------------------------------------------------
--      TRUE        |               SED-DED-TED     SEC-DED
-------------------------------------------------------------------------------
--
-- Note that, for example, SEC-DED (EXTRA_PARITY_BIT = true, CORRECT =
-- true) means that triple bit errors are not detected and messages
-- will be wrongly corrected because the correction corrects toward
-- the code word within the smaller hamming distance.  Practically you
-- usually know that something is very wrong with your communication
-- channel because you will also see double bit errors.  Then you
-- should not trust corrected data at all.

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.matrix_pkg.all;
use work.yahamm_pkg.all;

entity yahamm_enc is
  generic (
    MESSAGE_LENGTH       : natural := 5;
    EXTRA_PARITY_BIT : natural range 0 to 1 := 1;
    ONE_PARITY_BIT : boolean := false
    );
  port(
    clk_i, rst_i : in  std_logic;
    en_i       : in  std_logic := '1';          -- Synchronous output enable .
    data_i        : in  std_logic_vector(MESSAGE_LENGTH - 1 downto 0);  -- Input data.
    data_o        : out std_logic_vector(MESSAGE_LENGTH - 1 downto 0);  -- Out data.
    data_valid_o : out std_logic;        -- High when data_o is valid.
    parity_o   : out std_logic_vector(calc_nparity_bits(MESSAGE_LENGTH, ONE_PARITY_BIT) + EXTRA_PARITY_BIT - 1 downto 0)    -- Parity bits.
    );

end yahamm_enc;

architecture std of yahamm_enc is

  constant NPARITY_BITS : natural := calc_nparity_bits(MESSAGE_LENGTH, ONE_PARITY_BIT);
  constant BLOCK_LENGTH : natural := calc_block_length(MESSAGE_LENGTH, ONE_PARITY_BIT);
  
  constant G : matrix_t(0 to BLOCK_LENGTH + EXTRA_PARITY_BIT - 1,
                        0 to BLOCK_LENGTH - NPARITY_BITS - 1) :=
    get_code_generator_matrix(MESSAGE_LENGTH, EXTRA_PARITY_BIT, ONE_PARITY_BIT);

  -- G'reverse_range(1) doesn't work in ghdl 0.34
  --signal code_sys : std_ulogic_vector(G'reverse_range(1)); -- systematic code
  signal code_sys : std_ulogic_vector(BLOCK_LENGTH + EXTRA_PARITY_BIT -1 downto 0); -- systematic code
  
  signal data_i_padded : bit_vector(BLOCK_LENGTH - NPARITY_BITS - 1 downto 0);
  
  
begin

  check_parameters(BLOCK_LENGTH, NPARITY_BITS, MESSAGE_LENGTH, EXTRA_PARITY_BIT, ONE_PARITY_BIT);

  data_i_padded(MESSAGE_LENGTH - 1 downto 0) <= to_bitvector(data_i);
  pad_gen: if MESSAGE_LENGTH < BLOCK_LENGTH - NPARITY_BITS generate
    -- Pad data_i with zeros on the left, so that data_i_padded'length = BLOCK_LENGTH.
    -- This allow the user to reduce data_i width.
    data_i_padded(BLOCK_LENGTH - NPARITY_BITS - 1 downto MESSAGE_LENGTH) <= (others => '0');
  end generate pad_gen;
  
  -- Wire systematic code signal code_sys on data_o and parity_o output ports.
  -- Because of the form of the code generator matrix G, data are the LSB part
  -- of code and parity the MSB part.
  parity_o <= To_StdLogicVector(code_sys(code_sys'high downto code_sys'high - (EXTRA_PARITY_BIT + NPARITY_BITS) + 1));
  data_o <= To_StdLogicVector(code_sys(MESSAGE_LENGTH - 1 downto 0));
  
  -- purpose: Sequentially encode input with output enable.
  -- type   : sequential
  -- inputs : clk_i, rst_i, d_sig
  -- outputs: msg_sys
  encode_proc: process (clk_i, rst_i) is
  begin  -- process encode_proc
    if rst_i = '1' then                   -- asynchronous reset (active high)
      code_sys <= (others => '0');
      data_valid_o <= '0';
    elsif rising_edge(clk_i) then         -- rising clock edge

      if en_i = '0' then                  -- syncronous output enable
        code_sys <= (others => '0');
        data_valid_o <= '0';
      else
        code_sys <= To_StdULogicVector(xor_multiply_vec(G, data_i_padded));
        data_valid_o <= '1';        
      end if;
      
    end if;
  end process encode_proc;

end architecture std;
