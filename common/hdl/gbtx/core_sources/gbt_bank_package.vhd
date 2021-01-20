-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Common package
-------------------------------------------------------

-- IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Custom libraries and packages:
use work.vendor_specific_gbt_bank_package.all;

--! @brief GBT_bank_package - Common package
--! @details 
--! The GBT_bank_package package defines the common constant for all of the supported devices
--! as well as functions used by the encoder/decoder.
package gbt_bank_package is  
  
   --=================================== GBT VERSION =====================================--
	
	-- Format: Major.MinorH.MinorL
	constant GBT_VERSION_MAJOR						  : std_logic_vector(7 downto 0) := x"06";		--! Release version: Major (7 downto 0)
	constant GBT_VERSION_MINOR						  : std_logic_vector(7 downto 0) := x"00";		--! Release version: MinorH (7 downto 4) / MinorL (3 downto 0)
	   
   --=============================== Constant Declarations ===============================--
	
   
   constant STANDARD                            : integer := 0;                              --! Standard latency mode (constant definition)
   constant LATENCY_OPTIMIZED                   : integer := 1;                              --! Latency-optimized mode (constant definition)

   constant GBT_FRAME                           : integer := 0;                              --! GBT-FRAME encoding (constant definition)
   constant WIDE_BUS                            : integer := 1;                              --! WideBus encoding (constant definition)
   constant GBT_DYNAMIC                         : integer := 2;                              --! GBT-FRAME or WideBus encoding can be changed dynamically (constant definition)
      
   constant DATA_HEADER_PATTERN                 : std_logic_vector(3 downto 0) := "0101";    --! Is Data header pattern (constant definition: defined by the GBTx spec.)
   constant IDLE_HEADER_PATTERN                 : std_logic_vector(3 downto 0) := "0110";    --! Idle header pattern (constant definition: defined by the GBTx spec.)
   
   constant NBR_CHECKED_HEADER                  : integer := 64;                             --! Number of header to cheked before going back in lock state when a false header has been detected
   constant NBR_ACCEPTED_FALSE_HEADER           : integer :=  4;                             --! Number of accepted false header over the NBR_CHECKED_HEADER checked before being unlocked
   constant DESIRED_CONSEC_CORRECT_HEADERS      : integer := 23;                             --! Number of true consecutive header before going in locked state
      
   --================================= Array Declarations ================================-- 
	
	-- 1D arrays
   type gbt_reg120_A                            is array (natural range <>) of std_logic_vector(119 downto 0);
   type gbt_reg116_A                            is array (natural range <>) of std_logic_vector(115 downto 0);
   type gbt_reg84_A                             is array (natural range <>) of std_logic_vector(83 downto 0);
	type gbt_reg60_A                             is array (natural range <>) of std_logic_vector(59 downto 0);
   type gbt_reg40_A                             is array (natural range <>) of std_logic_vector(39 downto 0);
	type gbt_reg32_A                             is array (natural range <>) of std_logic_vector(31 downto 0);
	type gbt_reg21_A                             is array (natural range <>) of std_logic_vector(20 downto 0);	
	type gbt_reg16_A                             is array (natural range <>) of std_logic_vector(15 downto 0);
	type gbt_reg8_A								      is array (natural range <>) of std_logic_vector(7 downto 0);
	type gbt_reg4_A								      is array (natural range <>) of std_logic_vector(3 downto 0);
	
	type gbt_bitVector15_A                       is array (natural range <>) of bit_vector(14 downto 0);
	
	-- 2D arrays
	type gbt_reg4_2dA								      is array (natural range <>, natural range <>) of std_logic_vector(3 downto 0);
	
	-- Generic arrays
	type integer_A                               is array (natural range <>) of integer;
	  
	-- Constant based arrays
   type word_mxnbit_A                           is array (natural range <>) of std_logic_vector(WORD_WIDTH-1 downto 0); 
	
   --======================== Function and Procedure Declarations ========================--
   
   -- GBT-Frame encoding/decoding:
   -------------------------------
   function gf16add  (signal   input1, input2   : in std_logic_vector( 3 downto 0)) return std_logic_vector;                                 
   ---------------------------------------------------------------------------------------------------------
   function gf16mult (signal   input1           : in std_logic_vector( 3 downto 0);
                      constant input2           : in std_logic_vector( 3 downto 0)) return std_logic_vector;
   ---------------------------------------------------------------------------------------------------------
   function gf16invr (signal   input            : in std_logic_vector( 3 downto 0)) return std_logic_vector;
   ---------------------------------------------------------------------------------------------------------
   function gf16loga (signal   input            : in std_logic_vector( 3 downto 0)) return std_logic_vector;
   ---------------------------------------------------------------------------------------------------------
   function gf16shift(signal   input            : in std_logic_vector(59 downto 0);
                      signal   shift            : in std_logic_vector( 3 downto 0)) return std_logic_vector;
   
   --=====================================================================================--   
end gbt_bank_package;

--=================================================================================================--
--#####################################   Package Body   ##########################################--
--=================================================================================================--

package body gbt_bank_package is

   --=========================== Function and Procedure Bodies ===========================--

   --========--
   -- Common --
   --========--
   
   -- GBT-Frame encoding:
   ----------------------
	
   function gf16add(signal input1, input2 : in std_logic_vector(3 downto 0)) return std_logic_vector is
      variable output                           : std_logic_vector(3 downto 0);
   begin
      output(0)                                 := input1(0) xor input2(0);
      output(1)                                 := input1(1) xor input2(1);
      output(2)                                 := input1(2) xor input2(2);
      output(3)                                 := input1(3) xor input2(3);
      return output;
   end function;

   function gf16mult(signal   input1 : in std_logic_vector(3 downto 0);
                     constant input2 : in std_logic_vector(3 downto 0)) return std_logic_vector is       
      variable output                           : std_logic_vector(3 downto 0);
   begin
      output(0) := (input1(0) and input2(0)) xor (input1(3) and input2(1)) xor (input1(2) and input2(2)) xor (input1(1) and input2(3));
      output(1) := (input1(1) and input2(0)) xor (input1(0) and input2(1)) xor (input1(3) and input2(1)) xor (input1(2) and input2(2)) xor (input1(3) and input2(2)) xor (input1(1) and input2(3)) xor (input1(2) and input2(3));
      output(2) := (input1(2) and input2(0)) xor (input1(1) and input2(1)) xor (input1(0) and input2(2)) xor (input1(3) and input2(2)) xor (input1(2) and input2(3)) xor (input1(3) and input2(3));
      output(3) := (input1(3) and input2(0)) xor (input1(2) and input2(1)) xor (input1(1) and input2(2)) xor (input1(0) and input2(3)) xor (input1(3) and input2(3));
      return output;
   end function;  

   function gf16invr(signal input : in std_logic_vector(3 downto 0)) return std_logic_vector is
      variable output                           : std_logic_vector(3 downto 0);
   begin
      case input is
         when "0000" => output := "0000";   
         when "0001" => output := "0001";   
         when "0010" => output := "1001";   
         when "0011" => output := "1110";   
         when "0100" => output := "1101";   
         when "0101" => output := "1011";   
         when "0110" => output := "0111";   
         when "0111" => output := "0110";   
         when "1000" => output := "1111";   
         when "1001" => output := "0010";   
         when "1010" => output := "1100";   
         when "1011" => output := "0101";   
         when "1100" => output := "1010";   
         when "1101" => output := "0100";   
         when "1110" => output := "0011";   
         when "1111" => output := "1000";   
         when others => output := "0000";   -- Comment: Value selected randomly.   
      end case;      
      return output;
   end function;

   function gf16loga(signal input : in std_logic_vector(3 downto 0)) return std_logic_vector is    
      variable output                           : std_logic_vector(3 downto 0);
   begin
      case input is
         when "0000" => output := "0000";   
         when "0001" => output := "0000";   
         when "0010" => output := "0001";   
         when "0011" => output := "0100";   
         when "0100" => output := "0010";   
         when "0101" => output := "1000";   
         when "0110" => output := "0101";   
         when "0111" => output := "1010";   
         when "1000" => output := "0011";   
         when "1001" => output := "1110";   
         when "1010" => output := "1001";   
         when "1011" => output := "0111";   
         when "1100" => output := "0110";   
         when "1101" => output := "1101";   
         when "1110" => output := "1011";   
         when "1111" => output := "1100";   
         when others => output := "0000";   -- Comment: Value selected randomly. 
      end case;
      return output;
   end function; 
   
   function gf16shift(signal input : in std_logic_vector(59 downto 0); 
                      signal shift : in std_logic_vector( 3 downto 0)) return std_logic_vector is    
      variable ing                              : gbt_bitVector15_A(0 to 3);
      variable outg                             : gbt_bitVector15_A(0 to 3);                      
      variable output                           : std_logic_vector(59 downto 0);
   begin
      ing_loop1: for i in 0 to 3 loop
         ing_loop2: for j in 0 to 14 loop
            ing(i)(j)                           := to_bitvector(input)(i + j*4);
         end loop;
      end loop;
      ------------------------------------------
      outg_loop: for i in 0 to 3 loop
         outg(i)                                := ing(i) sll to_integer(unsigned(shift));   -- Comment: The operator "sll" shall be used with the type "bit_vector".
      end loop;
      ------------------------------------------
      output_loop: for i in 0 to 14 loop
         output((i*4)+3 downto i*4)             := to_stdlogicvector(outg(3)(i) & outg(2)(i) & outg(1)(i) & outg(0)(i));
      end loop;
      ------------------------------------------
      return output;
   end function;  
   
   --=====================================================================================--   
end gbt_bank_package;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--