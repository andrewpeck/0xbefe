library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.vcomponents.all;
library work;
use work.sixbit_eightbit_pkg.all;

entity eightbit_sixbit is
port(

  clock          : in  std_logic;

  eightbit       : in  std_logic_vector (7 downto 0);
  sixbit         : out std_logic_vector (5 downto 0);
  not_in_table   : out std_logic;
  char_is_data   : out std_logic;
  char_is_ttc    : out std_logic;
  char_is_header : out std_logic;
  l1a            : out std_logic;
  bc0            : out std_logic;
  resync         : out std_logic;
  idle           : out std_logic
);
end eightbit_sixbit;

architecture Behavioral of eightbit_sixbit is

signal l1a_rx            : std_logic;
signal bc0_rx            : std_logic;
signal resync_rx         : std_logic;
signal idle_rx           : std_logic;
signal char_is_header_rx : std_logic;
signal char_is_ttc_rx    : std_logic;

begin

  l1a_rx            <= '1' when (eightbit=L1A_CHAR)    else '0';
  bc0_rx            <= '1' when (eightbit=BC0_CHAR)    else '0';
  resync_rx         <= '1' when (eightbit=RESYNC_CHAR) else '0';
  idle_rx           <= '1' when (eightbit=IDLE_CHAR)   else '0';
  char_is_header_rx <= '1' when (eightbit=HEADER_CHAR) else '0';
  char_is_ttc_rx    <= '1' when (l1a_rx='1' or bc0_rx='1' or resync_rx='1') else '0';

  process (clock) begin
  if (rising_edge(clock)) then

    l1a            <= l1a_rx;
    bc0            <= bc0_rx;
    resync         <= resync_rx;
    idle           <= idle_rx;
    char_is_header <= char_is_header_rx;
    char_is_ttc    <= char_is_ttc_rx;

    case eightbit is

      -- fast commands
      when L1A_CHAR    => sixbit <= "000000"; not_in_table <= '0'; char_is_data <= '0';
      when BC0_CHAR    => sixbit <= "000000"; not_in_table <= '0'; char_is_data <= '0';
      when RESYNC_CHAR => sixbit <= "000000"; not_in_table <= '0'; char_is_data <= '0';
      when IDLE_CHAR   => sixbit <= "000000"; not_in_table <= '0'; char_is_data <= '0';
      when HEADER_CHAR => sixbit <= "000000"; not_in_table <= '0'; char_is_data <= '0';

      -- data words
      when "01011001" => sixbit <= "000000"; not_in_table <= '0'; char_is_data <= '1';
      when "01110001" => sixbit <= "000001"; not_in_table <= '0'; char_is_data <= '1';
      when "01110010" => sixbit <= "000010"; not_in_table <= '0'; char_is_data <= '1';
      when "11000011" => sixbit <= "000011"; not_in_table <= '0'; char_is_data <= '1';
      when "01100101" => sixbit <= "000100"; not_in_table <= '0'; char_is_data <= '1';
      when "11000101" => sixbit <= "000101"; not_in_table <= '0'; char_is_data <= '1';
      when "11000110" => sixbit <= "000110"; not_in_table <= '0'; char_is_data <= '1';
      when "10000111" => sixbit <= "000111"; not_in_table <= '0'; char_is_data <= '1';
      when "01101001" => sixbit <= "001000"; not_in_table <= '0'; char_is_data <= '1';
      when "11001001" => sixbit <= "001001"; not_in_table <= '0'; char_is_data <= '1';
      when "11001010" => sixbit <= "001010"; not_in_table <= '0'; char_is_data <= '1';
      when "10001011" => sixbit <= "001011"; not_in_table <= '0'; char_is_data <= '1';
      when "11001100" => sixbit <= "001100"; not_in_table <= '0'; char_is_data <= '1';
      when "10001101" => sixbit <= "001101"; not_in_table <= '0'; char_is_data <= '1';
      when "10001110" => sixbit <= "001110"; not_in_table <= '0'; char_is_data <= '1';
      when "01001011" => sixbit <= "001111"; not_in_table <= '0'; char_is_data <= '1';
      when "01010011" => sixbit <= "010000"; not_in_table <= '0'; char_is_data <= '1';
      when "11010001" => sixbit <= "010001"; not_in_table <= '0'; char_is_data <= '1';
      when "11010010" => sixbit <= "010010"; not_in_table <= '0'; char_is_data <= '1';
      when "10010011" => sixbit <= "010011"; not_in_table <= '0'; char_is_data <= '1';
      when "11010100" => sixbit <= "010100"; not_in_table <= '0'; char_is_data <= '1';
      when "10010101" => sixbit <= "010101"; not_in_table <= '0'; char_is_data <= '1';
      when "10010110" => sixbit <= "010110"; not_in_table <= '0'; char_is_data <= '1';
      when "00010111" => sixbit <= "010111"; not_in_table <= '0'; char_is_data <= '1';
      when "11011000" => sixbit <= "011000"; not_in_table <= '0'; char_is_data <= '1';
      when "10011001" => sixbit <= "011001"; not_in_table <= '0'; char_is_data <= '1';
      when "10011010" => sixbit <= "011010"; not_in_table <= '0'; char_is_data <= '1';
      when "00011011" => sixbit <= "011011"; not_in_table <= '0'; char_is_data <= '1';
      when "10011100" => sixbit <= "011100"; not_in_table <= '0'; char_is_data <= '1';
      when "00011101" => sixbit <= "011101"; not_in_table <= '0'; char_is_data <= '1';
      when "00011110" => sixbit <= "011110"; not_in_table <= '0'; char_is_data <= '1';
      when "01011100" => sixbit <= "011111"; not_in_table <= '0'; char_is_data <= '1';
      when "01100011" => sixbit <= "100000"; not_in_table <= '0'; char_is_data <= '1';
      when "11100001" => sixbit <= "100001"; not_in_table <= '0'; char_is_data <= '1';
      when "11100010" => sixbit <= "100010"; not_in_table <= '0'; char_is_data <= '1';
      when "10100011" => sixbit <= "100011"; not_in_table <= '0'; char_is_data <= '1';
      when "11100100" => sixbit <= "100100"; not_in_table <= '0'; char_is_data <= '1';
      when "10100101" => sixbit <= "100101"; not_in_table <= '0'; char_is_data <= '1';
      when "10100110" => sixbit <= "100110"; not_in_table <= '0'; char_is_data <= '1';
      when "00100111" => sixbit <= "100111"; not_in_table <= '0'; char_is_data <= '1';
      when "11101000" => sixbit <= "101000"; not_in_table <= '0'; char_is_data <= '1';
      when "10101001" => sixbit <= "101001"; not_in_table <= '0'; char_is_data <= '1';
      when "10101010" => sixbit <= "101010"; not_in_table <= '0'; char_is_data <= '1';
      when "00101011" => sixbit <= "101011"; not_in_table <= '0'; char_is_data <= '1';
      when "10101100" => sixbit <= "101100"; not_in_table <= '0'; char_is_data <= '1';
      when "00101101" => sixbit <= "101101"; not_in_table <= '0'; char_is_data <= '1';
      when "00101110" => sixbit <= "101110"; not_in_table <= '0'; char_is_data <= '1';
      when "01101100" => sixbit <= "101111"; not_in_table <= '0'; char_is_data <= '1';
      when "01110100" => sixbit <= "110000"; not_in_table <= '0'; char_is_data <= '1';
      when "10110001" => sixbit <= "110001"; not_in_table <= '0'; char_is_data <= '1';
      when "10110010" => sixbit <= "110010"; not_in_table <= '0'; char_is_data <= '1';
      when "00110011" => sixbit <= "110011"; not_in_table <= '0'; char_is_data <= '1';
      when "10110100" => sixbit <= "110100"; not_in_table <= '0'; char_is_data <= '1';
      when "00110101" => sixbit <= "110101"; not_in_table <= '0'; char_is_data <= '1';
      when "00110110" => sixbit <= "110110"; not_in_table <= '0'; char_is_data <= '1';
      when "01010110" => sixbit <= "110111"; not_in_table <= '0'; char_is_data <= '1';
      when "10111000" => sixbit <= "111000"; not_in_table <= '0'; char_is_data <= '1';
      when "00111001" => sixbit <= "111001"; not_in_table <= '0'; char_is_data <= '1';
      when "00111010" => sixbit <= "111010"; not_in_table <= '0'; char_is_data <= '1';
      when "01011010" => sixbit <= "111011"; not_in_table <= '0'; char_is_data <= '1';
      when "00111100" => sixbit <= "111100"; not_in_table <= '0'; char_is_data <= '1';
      when "01001101" => sixbit <= "111101"; not_in_table <= '0'; char_is_data <= '1';
      when "01001110" => sixbit <= "111110"; not_in_table <= '0'; char_is_data <= '1';
      when "01100110" => sixbit <= "111111"; not_in_table <= '0'; char_is_data <= '1';
      -- default = not-in-table
      when others     => sixbit <= "111111"; not_in_table <= '1'; char_is_data <= '0';
    end case;

  end if;
  end process;


end Behavioral;

