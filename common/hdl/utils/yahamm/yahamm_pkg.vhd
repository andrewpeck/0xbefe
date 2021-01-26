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

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;

library work;
use work.matrix_pkg.all;

package yahamm_pkg is

  component yahamm_dec is
    generic (
      MESSAGE_LENGTH   : natural;
      CORRECT          : boolean;
      EXTRA_PARITY_BIT : natural range 0 to 1;
      ONE_PARITY_BIT   : boolean;
      ERROR_LEN        : natural;
      NPARITY_BITS     : natural;
      BLOCK_LENGTH     : natural);
    port (
      clk, rst                                  : in  std_logic;
      en                                        : in  std_logic;
      din                                       : in  std_logic_vector(MESSAGE_LENGTH - 1 downto 0);
      parity                                    : in  std_logic_vector(NPARITY_BITS + EXTRA_PARITY_BIT - 1 downto 0);
      dout                                      : out std_logic_vector(MESSAGE_LENGTH - 1 downto 0);
      cnt_errors_corrected, cnt_errors_detected : out std_logic_vector(ERROR_LEN - 1 downto 0));
  end component yahamm_dec;

  component yahamm_enc is
    generic (
      MESSAGE_LENGTH   : natural;
      EXTRA_PARITY_BIT : natural range 0 to 1;
      ONE_PARITY_BIT   : boolean;
      NPARITY_BITS     : natural;
      BLOCK_LENGTH     : natural);
    port (
      clk, rst : in  std_logic;
      en       : in  std_logic := '1';
      din      : in  std_logic_vector(MESSAGE_LENGTH - 1 downto 0);
      dout     : out std_logic_vector(MESSAGE_LENGTH - 1 downto 0);
      parity   : out std_logic_vector(NPARITY_BITS + EXTRA_PARITY_BIT - 1 downto 0));
  end component yahamm_enc;
  
  function get_parity_check_matrix (
    MESSAGE_LENGTH : natural;
    EXTRA_PARITY : natural range 0 to 1  := 1;
    ONE_PARITY_BIT : boolean := false)
    return matrix_t;

  function get_code_generator_matrix (
    MESSAGE_LENGTH : natural;
    EXTRA_PARITY : natural range 0 to 1 := 1;       -- number of data (non parity) bits
    ONE_PARITY_BIT : boolean := false)
    return matrix_t;

  function calc_nparity_bits (
    k : natural;
    ONE_PARITY_BIT : boolean := false)
    return natural;
  
  function calc_block_length (
    k : natural;
    ONE_PARITY_BIT : boolean := false)
    return natural;

  procedure check_parameters (
    constant BLOCK_LENGTH     : in natural;
    constant NPARITY_BITS     : in natural;
    constant MESSAGE_LENGTH   : in natural;
    constant EXTRA_PARITY_BIT : in natural;
    constant ONE_PARITY_BIT : in boolean;
    constant CORRECT : in boolean := false
    );

  function xor_multiply (
    A : matrix_t;
    B : matrix_t)
    return matrix_t;
  
  function xor_multiply_vec (
    A : matrix_t;
    x : bit_vector)
    return bit_vector;

  function get_form_swap_matrix (
    MESSAGE_LENGTH : natural;
    EXTRA_PARITY : natural;
    ONE_PARITY_BIT : boolean := false)
    return matrix_t;
  
end package yahamm_pkg;

package body yahamm_pkg is
  
  -- purpose: Return a matrix S that can be used to tranform a parity
  -- check matrix or a code generator matrix M from non-systematic
  -- form to systematic form MS and viceversa (because S = S
  -- transposed = S^-1).  Use as as MS = M x S.
  -- Also works for M with extra parity bit: set EXTRA_PARITY to 1 and
  -- the swap matrix increases of one extra column and one extra row
  -- (as the parity check matrix) and the extra column is not swapped.
  function get_form_swap_matrix (
    MESSAGE_LENGTH : natural;
    EXTRA_PARITY : natural;
    ONE_PARITY_BIT : boolean := false)
    return matrix_t is
    
    constant BLOCK_LENGTH : natural := calc_block_length(MESSAGE_LENGTH, ONE_PARITY_BIT);
    constant NPARITY_BITS : natural := calc_nparity_bits(MESSAGE_LENGTH, ONE_PARITY_BIT);    
    
    variable idmatrix : matrix_t(0 to BLOCK_LENGTH + EXTRA_PARITY - 1, 0 to BLOCK_LENGTH + EXTRA_PARITY - 1) := (others => (others => '0'));
    variable swap_matrix : matrix_t(0 to BLOCK_LENGTH + EXTRA_PARITY - 1, 0 to BLOCK_LENGTH + EXTRA_PARITY - 1); -- output
    
  begin  -- function get_systematic_swap_matrix

    -- Fill up the identity matrix idmatrix.  It's initialized to zeros, so
    -- just write ones on the diagonal.
    for irow in idmatrix'range(1) loop    
      for icol in idmatrix'range(2) loop
        if irow = icol then
          idmatrix(irow, icol) := '1';
        end if;
      end loop;
    end loop;

    -- Swap columns corresponding to parity bits position in the
    -- parity check matrix (0, 1, 3, 7 etc...) with the right-most
    -- columns (starting with inner possibile rightmost).  E.g. let's
    -- say that, with the given message length, BLOCK_LENGTH is 7 and
    -- the parity bits are in positions 0, 1 and 3.  The swap will be:
    -- 0 <-> 5
    -- 1 <-> 6
    -- 3 <-> 7
    --
    -- Note: if EXTRA_PARITY is set, last colum is ignored because is not to be
    -- swapped.
    swap_matrix := idmatrix;
    for np in 0 to NPARITY_BITS-1 loop
      swap_cols(swap_matrix, 2**np - 1, BLOCK_LENGTH - NPARITY_BITS + np);
    end loop;  -- np

    return swap_matrix;
    
  end function get_form_swap_matrix;
  
  -- purpose: Return the result of the matrix M x vector v product.  Internal sums are
  -- replaced by xor operations.  E.g.:
  -- [1 1; 0 1] * [a; b] = [a xor b; b]
  -- [1 1; 0 1] * [1 1; 1 0] = [0 1; 1 0]
  function xor_multiply (
    A : matrix_t;
    B : matrix_t)
    return matrix_t is

    --variable y : bit_vector(A'reverse_range(1));
    variable y : matrix_t(A'range(1), B'range(2));
    variable element : bit;
    
  begin  -- function matrix_multiply
    
    --report "xor_multiply: Matrix A sized "
    --  & integer'image(A'length(1)) & "x" & integer'image(A'length(2))
    --  & ". Matrix B sized "
    --  & integer'image(B'length(1)) & "x" & integer'image(B'length(2)) & "."
    --  severity note;

    assert A'length(2) = B'length(1)
      report "Cannot multiply matrix A sized "
      & integer'image(A'length(1)) & "x" & integer'image(A'length(2))
      & " with matrix B sized "
      & integer'image(B'length(1)) & "x" & integer'image(B'length(2)) & "."
      severity error;
    
    for Arow in A'range(1) loop
      for Bcol in B'range(2) loop
        
        element := '0';
        for Acol in A'range(2) loop
          element := element xor (A(Arow, Acol) and B(Acol, Bcol));
        end loop;  -- i
        
        y(Arow, Bcol) := element;
        
        --report
        --  "(" & integer'image(Arow) & ", " & integer'image(Bcol) & "): " &
        --  "y(Arow, Bcol) :=  " & bit'image(element)
        --  severity note;
        
      end loop;  -- Bcol

      --assert false report "y(" & integer'image(y'length-Arow-1) & ") := " & bit'image(y(y'length-Arow-1)) severity note;
    end loop;

    --pretty_print_matrix(A);
    --pretty_print_matrix(B);    
    --pretty_print_matrix(y);
    
    return y;
    
  end function xor_multiply;


  -- purpose: Return the result of the matrix operation y = A*x using
  -- xor_multiply function.  See xor_multiply comment for details.
  function xor_multiply_vec (
    A : matrix_t;
    x : bit_vector)
    return bit_vector is

    variable B : matrix_t(x'range, 0 to 0);
    variable C : matrix_t(A'range(1), 0 to 0);
    
    variable y : bit_vector(A'reverse_range(1)); -- output
    
  begin  -- function matrix_multiply

    assert A'length(2) = x'length
      report "Cannot multiply matrix A sized "
      & integer'image(A'length(1)) & "x" & integer'image(A'length(2))
      & " with vector x of length "
      & integer'image(x'length) & "."
      severity error;
    
    -- Transform bit_vector x into a 1-column matrix_t.
    for i in x'range loop
      B(i, 0) := x(i);
    end loop;  -- i
    
    C := xor_multiply(A, B);

    -- Transform the 1-column matrix_t C into a bit_vector.
    for i in C'range(1) loop
      y(i) := C(i, 0);      
    end loop;  -- i

    --report "xor_multiply_vec: Matrix A sized "
    --  & integer'image(A'length(1)) & "x" & integer'image(A'length(2))
    --  & ". Matrix B sized "
    --  & integer'image(B'length(1)) & "x" & integer'image(B'length(2)) & "."
    --  severity note;

    --pretty_print_matrix(A);
    --pretty_print_matrix(B);
    --pretty_print_matrix(C);
    --pretty_print_vector(y);
    
    return y;
    
  end function xor_multiply_vec;
  
  -- purpose: Generate the parity check matrix for a given message length.  The
  -- matrix is in non-systematic form.
  function get_parity_check_matrix (
    MESSAGE_LENGTH : natural;
    EXTRA_PARITY : natural range 0 to 1  := 1; -- increase hamming distance to 4
    ONE_PARITY_BIT : boolean := false)
    return matrix_t is

    constant NPARITY_BITS : natural := calc_nparity_bits(MESSAGE_LENGTH, ONE_PARITY_BIT);    
    constant BLOCK_LENGTH : natural := calc_block_length(MESSAGE_LENGTH, ONE_PARITY_BIT);

    variable m     : matrix_t(0 to NPARITY_BITS-1, 0 to BLOCK_LENGTH-1);
    variable parity, bit_pos : natural;
    variable ubit_pos : unsigned(BLOCK_LENGTH - 1 downto 0);

    -- add 1 row and 1 column respect to m to build a parity check
    -- matrix with extra parity bit.
    variable m_extra     : matrix_t(0 to m'length(1), 0 to m'length(2));
    variable hecol : bit_vector(m_extra'range(1));

  begin  -- function get_parity_check_matrix

    if ONE_PARITY_BIT then
      m := (0 => (others => '1'));
      return m;
    end if;

    for iparity in m'range(1) loop
      parity := 2**iparity;

      if parity >= 2 then
        for bit_pos in 0 to parity-2 loop
          m(iparity, bit_pos) := '0';
        end loop;
      end if;
      
      for bit_pos in parity-1 to m'length(2)-1 loop
        ubit_pos := to_unsigned(bit_pos+1, BLOCK_LENGTH);
        
        m(iparity, bit_pos) := to_bit(ubit_pos(iparity));

      end loop;  -- bit_pos
    end loop;  -- iparity

    if EXTRA_PARITY = 0 then
          return m;
    else
      -- m_extra is the parity check matrix with extra parity bits.
      -- It is constructed from m in 2 steps.  m_extra has an extra
      -- row and extra column respect to m.

      -- 1. copy m in m_extra.
      for irow in m'range(1) loop
        for icol in m'range(2) loop
          m_extra(irow, icol) := m(irow, icol);
        end loop;
      end loop;      
      
      -- 2. Add extra row with '1'.
      for icol in m_extra'range(2) loop
        m_extra(m_extra'high(1), icol) := '1';
      end loop;

      return m_extra;
    end if;
    
  end function get_parity_check_matrix;

  -- purpose: Create the code generator matrix in systematic form.
  function get_code_generator_matrix (
    MESSAGE_LENGTH : natural;
    EXTRA_PARITY : natural range 0 to 1  := 1;  -- increase hamming ndistance to 4
    ONE_PARITY_BIT : boolean := false)

    return matrix_t is

    constant BLOCK_LENGTH : natural := calc_block_length(MESSAGE_LENGTH, ONE_PARITY_BIT);    
    constant NPARITY_BITS : natural := calc_nparity_bits(MESSAGE_LENGTH, ONE_PARITY_BIT);    

    -- The only reason the code generator matrix is systematic is because H
    -- returned from get_code_generator_matrix is systematic (see
    -- make_systematic in code_generator_matrix).
    variable H    : matrix_t(0 to NPARITY_BITS + EXTRA_PARITY - 1,
                             0 to BLOCK_LENGTH + EXTRA_PARITY - 1) := get_parity_check_matrix(MESSAGE_LENGTH,
                                                                                              EXTRA_PARITY,
                                                                                              ONE_PARITY_BIT);

    -- G is the code generator matrix.
    variable G : matrix_t(0 to BLOCK_LENGTH - NPARITY_BITS - 1, 0 to BLOCK_LENGTH + EXTRA_PARITY - 1);
    -- GT is G transposed.
    variable GT : matrix_t(G'range(2), G'range(1));
    
    variable gcol : bit_vector(H'range(2)); -- G matrix column
    variable hcol : bit_vector(H'range(1)); -- H matrix column

    variable swap_matrix : matrix_t(0 to BLOCK_LENGTH + EXTRA_PARITY - 1, 0 to BLOCK_LENGTH + EXTRA_PARITY - 1);
    
  begin  -- function get_code_generator_matrix

    -- Identity submatrix on the left (I_k)
    for col in 0 to BLOCK_LENGTH - NPARITY_BITS - 1 loop
      gcol := (others => '0');
      gcol(col) := '1';
      set_col(G, col, gcol);
    end loop;  -- col

    -- transform H in systematic form
    swap_matrix := get_form_swap_matrix(MESSAGE_LENGTH, EXTRA_PARITY, ONE_PARITY_BIT);
    H := xor_multiply(H, swap_matrix);

    if EXTRA_PARITY = 1 then
      -- This is a trick that avoids a very tedious row reduction.
      
      for icol in H'range(2) loop
        hcol := get_col(H, icol);
        if xor_reduce(hcol) = '0' then
          H(H'high(1), icol) := '0';
        end if;
      end loop;  -- icol
      
    end if;

    --pretty_print_matrix(H);
    --pretty_print_matrix(xor_multiply(H, swap_matrix));
    
    -- Submatrix A transposed.
    for col in BLOCK_LENGTH - NPARITY_BITS to BLOCK_LENGTH + EXTRA_PARITY - 1 loop
      for row in 0 to BLOCK_LENGTH - NPARITY_BITS - 1 loop
        G(row, col) := H(col-(BLOCK_LENGTH-NPARITY_BITS), row);
      end loop;
    end loop;
    
    -- transpose G
    for irow in G'range(1) loop
      for icol in G'range(2) loop
        GT(icol, irow) := G(irow, icol);
      end loop;
    end loop;

    return GT;
    
  end function get_code_generator_matrix;

  -- purpose: Calculate the number of parity bits (r) needed for the
  -- specified message length (k).  The code has k = 2^r - r - 1 for r >= 2.
  function calc_nparity_bits (
    k : natural;
    ONE_PARITY_BIT : boolean := false)
    return natural is
    variable r : natural := 0;
  begin  -- function calc_nparity_bits

--    assert k > 0 report "Code construction not implement for message length 0." severity failure;

    if ONE_PARITY_BIT then
      return 1;
    end if;
    
    r := 0;
    while true loop
      if 2**r - r - 1 >= k then
        return r;
      end if;

      r := r + 1;
    end loop;

    report "This should never happen." severity failure;
    return 0;
    
  end function calc_nparity_bits;
  
  -- purpose: Calculate the code block length n for the specified
  -- message length (k).  The code has n = 2^r - 1 for r >= 2.
  function calc_block_length (
    k : natural;
    ONE_PARITY_BIT : boolean := false)
    return natural is
    variable r : natural := 0;
  begin  -- function calc_nparity_bits

--    assert k > 0 report "Code construction not implement for message length 0." severity failure;

    if ONE_PARITY_BIT then
      return k + 1;
    end if;
    
    r := calc_nparity_bits(k);

    return 2**r - 1;
    
  end function calc_block_length;

  procedure check_parameters (
    constant BLOCK_LENGTH     : in natural;
    constant NPARITY_BITS     : in natural;
    constant MESSAGE_LENGTH   : in natural;
    constant EXTRA_PARITY_BIT : in natural;
    constant ONE_PARITY_BIT : in boolean;
    constant CORRECT : in boolean := false) is
    begin
      assert BLOCK_LENGTH = calc_block_length(MESSAGE_LENGTH, ONE_PARITY_BIT) report "Invalid parameter value BLOCK_LENGTH := " & natural'image(BLOCK_LENGTH) severity failure;
      assert NPARITY_BITS = calc_nparity_bits(MESSAGE_LENGTH, ONE_PARITY_BIT) report "Invalid parameter value NPARITY_BITS := " & natural'image(NPARITY_BITS) severity failure;

      if ONE_PARITY_BIT then
        assert EXTRA_PARITY_BIT = 0 report "EXTRA_PARITY_BIT 1 is not compatible with ONE_PARITY_BIT true." severity failure;
        assert CORRECT = false report "CORRECT true is not compatible with ONE_PARITY_BIT true." severity failure;
      end if;
      
    end procedure check_parameters;

end package body yahamm_pkg;
