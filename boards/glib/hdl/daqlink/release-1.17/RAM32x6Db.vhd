----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:46:13 11/18/2013 
-- Design Name: 
-- Module Name:    RAM32x6D - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity RAM32x6Db is
    Port ( wclk : in  STD_LOGIC;
           di : in  STD_LOGIC_VECTOR (5 downto 0);
           we : in  STD_LOGIC;
           wa : in  STD_LOGIC_VECTOR (4 downto 0);
           ra : in  STD_LOGIC_VECTOR (4 downto 0);
           do : out  STD_LOGIC_VECTOR (5 downto 0));
end RAM32x6Db;

architecture Behavioral of RAM32x6Db is

begin
RAM32M_inst : RAM32M
   generic map (
      INIT_A => X"0000000000000000",   -- Initial contents of A port
      INIT_B => X"0000000000000000",   -- Initial contents of B port
      INIT_C => X"0000000000000000",   -- Initial contents of C port
      INIT_D => X"0000000000000000")    -- Initial contents of D port
   port map (
      DOA => do(1 downto 0), -- Read port A 2-bit output
      DOB => do(3 downto 2), -- Read port B 2-bit output
      DOC => do(5 downto 4), -- Read port C 2-bit output
      DOD => open, -- Read/Write port D 2-bit output
      ADDRA => ra,   -- Read port A 5-bit address input
      ADDRB => ra,   -- Read port B 5-bit address input
      ADDRC => ra,   -- Read port C 5-bit address input
      ADDRD => wa,   -- Read/Write port D 5-bit address input
      DIA => di(1 downto 0), -- RAM 2-bit data write input addressed by ADDRD,
                  -- read addressed by ADDRA
      DIB => di(3 downto 2), -- RAM 2-bit data write input addressed by ADDRD,
                  -- read addressed by ADDRB
      DIC => di(5 downto 4), -- RAM 2-bit data write input addressed by ADDRD,
                  -- read addressed by ADDRC
      DID => "00", -- RAM 2-bit data write input addressed by ADDRD,
                  -- read addressed by ADDRD
      WCLK => wclk,  -- Write clock input
      WE => we       -- Write enable input
   );


end Behavioral;

