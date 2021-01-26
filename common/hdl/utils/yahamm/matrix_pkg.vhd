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

use std.textio.all;

--library ieee_proposed;
--use ieee_proposed.std_logic_1164_additions.all;
--use ieee_proposed.standard_additions.all;
---- pragma synthesis_off
--use ieee_proposed.standard_textio_additions.all;
---- pragma synthesis_on

package matrix_pkg is

  -----------------------------------------------------------------------------
  -- Here 2D arrays are used to implement matrices.  There are various
  -- limitations to the use of 2D arrays (e.g. limited easy slicing)
  -- that would maybe suggest an implementation with 1Dx1D matrices.
  -- But anyway this would make easy slicing either rows or columns
  -- but not both.  The approach used here is implementing functions
  -- to handle various matrix operations.  Having a 2D type allows to
  -- use one type definition for any matrix.
  -----------------------------------------------------------------------------

  type matrix_t is array (integer range <>, integer range<>) of bit;

  function get_row (
    constant matrix : matrix_t;
    constant row    : natural)
    return bit_vector;

  function get_col (
    constant matrix : matrix_t;
    constant col    : natural)
    return bit_vector;

  procedure set_col (
    variable M : inout matrix_t;
    constant icol    : natural;
    constant col : bit_vector);

-- pragma synthesis_off
  procedure pretty_print_matrix (
    constant matrix : in matrix_t);

  procedure pretty_print_vector (
    constant vin : in bit_vector);
-- pragma synthesis_on

  function find_col (
    constant M   : matrix_t;
    constant col : bit_vector)
    return integer;

  procedure swap_cols (
    variable M       : inout matrix_t;
    constant icol1, icol2 : in natural);

  function and_reduce (L  : BIT_VECTOR) return BIT;
  function or_reduce (L  : BIT_VECTOR) return BIT;
  function xor_reduce (L  : BIT_VECTOR) return BIT;

end package matrix_pkg;

package body matrix_pkg is

  -- purpose: Return matrix M with columns at positions col1 and col2
  -- swapped.
  procedure swap_cols (
    variable M          : inout matrix_t;
    constant icol1, icol2 : in natural) is
    
    variable col1, col2 : bit_vector(M'range(1));
    variable Mout : matrix_t(M'range(1), M'range(2));
    
  begin
    
    col1 := get_col(M, icol1);
    col2 := get_col(M, icol2);
    
    set_col(M, icol1, col2);
    set_col(M, icol2, col1);
    
  end procedure swap_cols;
  
  -- purpose: Return the matrix row.
  function get_row (
    constant matrix : matrix_t;
    constant row    : natural)
    return bit_vector is
    variable y : bit_vector(matrix'range(2));
  begin  -- function get_row

    for col in matrix'range(2) loop
      y(col) := matrix(row, col);
    end loop;  -- irow

    return y;
  end function get_row;

  -- purpose: Return the matrix col.
  function get_col (
    constant matrix : matrix_t;
    constant col    : natural)
    return bit_vector is
    variable y : bit_vector(matrix'range(1));
  begin  -- function get_col

    for row in matrix'range(1) loop
      y(row) := matrix(row, col);
    end loop;  -- irow

    return y;
  end function get_col;

  -- purpose: Set the matrix column icol to col.
  procedure set_col (
    variable M : inout matrix_t;
    constant icol    : natural;
    constant col : bit_vector) is
  begin  -- function get_col
    
    for row in M'range(1) loop
      M(row, icol) := col(row);
    end loop;  -- irow

  end procedure set_col;

-- pragma synthesis_off
  
  -- purpose: Print out matrix for debugging.
  procedure pretty_print_matrix (
    constant matrix : in matrix_t) is
    variable l : line;

  begin  -- procedure pretty_print_matrix

    for row in matrix'range(1) loop

      for col in matrix'range(2) loop
        write(l, matrix(row, col));
        --swrite(l, " ");
      end loop;  -- col

      writeline(output, l);
    end loop;  -- row

    writeline(output, l);               -- blank line

  end procedure pretty_print_matrix;

  -- purpose: Print out vector for debugging.
  procedure pretty_print_vector (
    constant vin : in bit_vector) is
    variable l : line;

  begin  -- procedure pretty_print_matrix

    --swrite(l, integer'image(vin'left));
    --swrite(l, " to/downto ");
    --swrite(l, integer'image(vin'right));
    --swrite(l, ": ");
    for i in vin'range loop
      write(l, vin(i));
      --swrite(l, " ");
    end loop;  -- i

    writeline(output, l);
    writeline(output, l);               -- blank line

  end procedure pretty_print_vector;

-- pragma synthesis_on
  
  -- purpose: Return the position of col in M or -1 if not found.
  function find_col (
    constant M   : matrix_t;                -- Any matrix
    constant col : bit_vector)  -- The column to find
    return integer is
    variable match : boolean;
  begin  -- function find_col
    for icol in M'range(2) loop
      
      match := true;
      for j in col'range loop
        if col(j) /= M(j, icol) then
          match := false;
        end if;
      end loop;

      if match then
        return icol;
      end if;
      
    end loop;

    -- not found
    return -1;
  end function find_col;
  
  function and_reduce (L : BIT_VECTOR) return BIT is
    variable result : BIT := '1';
  begin
    for i in l'reverse_range loop
      result := l(i) and result;
    end loop;
    return result;
  end function and_reduce;

  function or_reduce (L : BIT_VECTOR) return BIT is
    variable result : BIT := '0';
  begin
    for i in l'reverse_range loop
      result := l(i) or result;
    end loop;
    return result;
  end function or_reduce;
  
  function xor_reduce (L : BIT_VECTOR) return BIT is
    variable result : BIT := '0';
  begin
    for i in l'reverse_range loop
      result := l(i) xor result;
    end loop;
    return result;
  end function xor_reduce;

end package body matrix_pkg;
