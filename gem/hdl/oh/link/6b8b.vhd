library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.vcomponents.all;
library work;
use work.sixbit_eightbit_pkg.all;

entity sixbit_eightbit is
port(
  clock        : in std_logic;
  l1a          : in std_logic;
  bc0          : in std_logic;
  resync       : in std_logic;
  idle         : in std_logic;
  header       : in std_logic;
  sixbit       : in  std_logic_vector (5 downto 0);
  eightbit     : out std_logic_vector (7 downto 0)
);

end sixbit_eightbit;

architecture Behavioral of sixbit_eightbit is
begin

    process (clock) begin
    if (rising_edge(clock)) then

      -- make sure ttc commands have priority
      if    (l1a='1')    then eightbit <= L1A_CHAR;
      elsif (bc0='1')    then eightbit <= BC0_CHAR;
      elsif (resync='1') then eightbit <= RESYNC_CHAR;
      elsif (idle='1')   then eightbit <= IDLE_CHAR;
      elsif (header='1') then eightbit <= HEADER_CHAR;
      else
        case sixbit is
            when "000000" => eightbit <= "01011001";
            when "000001" => eightbit <= "01110001";
            when "000010" => eightbit <= "01110010";
            when "000011" => eightbit <= "11000011";
            when "000100" => eightbit <= "01100101";
            when "000101" => eightbit <= "11000101";
            when "000110" => eightbit <= "11000110";
            when "000111" => eightbit <= "10000111";
            when "001000" => eightbit <= "01101001";
            when "001001" => eightbit <= "11001001";
            when "001010" => eightbit <= "11001010";
            when "001011" => eightbit <= "10001011";
            when "001100" => eightbit <= "11001100";
            when "001101" => eightbit <= "10001101";
            when "001110" => eightbit <= "10001110";
            when "001111" => eightbit <= "01001011";
            when "010000" => eightbit <= "01010011";
            when "010001" => eightbit <= "11010001";
            when "010010" => eightbit <= "11010010";
            when "010011" => eightbit <= "10010011";
            when "010100" => eightbit <= "11010100";
            when "010101" => eightbit <= "10010101";
            when "010110" => eightbit <= "10010110";
            when "010111" => eightbit <= "00010111";
            when "011000" => eightbit <= "11011000";
            when "011001" => eightbit <= "10011001";
            when "011010" => eightbit <= "10011010";
            when "011011" => eightbit <= "00011011";
            when "011100" => eightbit <= "10011100";
            when "011101" => eightbit <= "00011101";
            when "011110" => eightbit <= "00011110";
            when "011111" => eightbit <= "01011100";
            when "100000" => eightbit <= "01100011";
            when "100001" => eightbit <= "11100001";
            when "100010" => eightbit <= "11100010";
            when "100011" => eightbit <= "10100011";
            when "100100" => eightbit <= "11100100";
            when "100101" => eightbit <= "10100101";
            when "100110" => eightbit <= "10100110";
            when "100111" => eightbit <= "00100111";
            when "101000" => eightbit <= "11101000";
            when "101001" => eightbit <= "10101001";
            when "101010" => eightbit <= "10101010";
            when "101011" => eightbit <= "00101011";
            when "101100" => eightbit <= "10101100";
            when "101101" => eightbit <= "00101101";
            when "101110" => eightbit <= "00101110";
            when "101111" => eightbit <= "01101100";
            when "110000" => eightbit <= "01110100";
            when "110001" => eightbit <= "10110001";
            when "110010" => eightbit <= "10110010";
            when "110011" => eightbit <= "00110011";
            when "110100" => eightbit <= "10110100";
            when "110101" => eightbit <= "00110101";
            when "110110" => eightbit <= "00110110";
            when "110111" => eightbit <= "01010110";
            when "111000" => eightbit <= "10111000";
            when "111001" => eightbit <= "00111001";
            when "111010" => eightbit <= "00111010";
            when "111011" => eightbit <= "01011010";
            when "111100" => eightbit <= "00111100";
            when "111101" => eightbit <= "01001101";
            when "111110" => eightbit <= "01001110";
            when "111111" => eightbit <= "01100110";
            when others   => eightbit <= "00000000";
          end case;
      end if;

    end if;
  end process;

end Behavioral;

