----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:25:43 01/28/2012 
-- Design Name: 
-- Module Name:    miniCTR - Behavioral 
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.std_logic_misc.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;
Library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity TTS_TRIG_if is
--		Generic (
--					 USE_TRIGGER_PORT : boolean := true);
   Port ( 
           reset : in  STD_LOGIC; -- asynchronous reset, assert reset until GTX REFCLK stable
           UsrClk : in  STD_LOGIC;
					 USE_TRIGGER_PORT : boolean;
-- TRIGGER port
           TTCclk : in  STD_LOGIC;
           BcntRes : in  STD_LOGIC;
           trig : in  STD_LOGIC_VECTOR (7 downto 0);
-- TTS
           TTSclk : in  STD_LOGIC; -- clock source which clocks TTS signals
           TTS : in  STD_LOGIC_VECTOR (3 downto 0);
           RXCHARISK : in  STD_LOGIC_VECTOR (1 downto 0);
           RXDATA : in  STD_LOGIC_VECTOR (15 downto 0);
           sel_TTS_TRIG : out  STD_LOGIC;
           TTS_TRIG_data : out  STD_LOGIC_VECTOR (17 downto 0)
					 );
end TTS_TRIG_if;

architecture Behavioral of TTS_TRIG_if is
COMPONENT RAM32x6Db
	PORT(
		wclk : IN std_logic;
		di : IN std_logic_vector(5 downto 0);
		we : IN std_logic;
		wa : IN std_logic_vector(4 downto 0);
		ra : IN std_logic_vector(4 downto 0);          
		do : OUT std_logic_vector(5 downto 0)
		);
END COMPONENT;
COMPONENT Hamming
	PORT(
		clk : IN std_logic;
		sel_TTC : IN std_logic;
		din : IN std_logic_vector(17 downto 0);          
		dout : OUT std_logic_vector(17 downto 0)
		);
END COMPONENT;
constant N : integer := 7;
signal BC0 : std_logic := '0';
signal BC0_l : std_logic := '0';
signal BcntRes_l : std_logic := '0';
signal bcnt : std_logic_vector(11 downto 0) := (others => '0');
signal bcnt_err : std_logic := '0';
signal bcnt_err_cnt : std_logic_vector(3 downto 0) := (others => '0');
signal Hamming_din : std_logic_vector(17 downto 0) := (others => '0');
signal trig_data : std_logic_vector(17 downto 0) := (others => '0');
signal sel_TTC : std_logic_vector(1 downto 0) := (others => '0');
signal TTC_FIFO_do : std_logic_vector(17 downto 0) := (others => '0');
signal TTC_FIFO_di : std_logic_vector(17 downto 0) := (others => '0');
signal TTC_FIFO_wa : std_logic_vector(4 downto 0) := (others => '0');
signal TTC_FIFO_ra : std_logic_vector(4 downto 0) := (others => '0');
signal TTC_FIFO_wa_sync : std_logic_vector(1 downto 0) := (others => '0');
signal TTC_FIFO_wa_sync2 : std_logic_vector(1 downto 0) := (others => '0');
signal TTC_FIFO_wa_sync3 : std_logic_vector(1 downto 0) := (others => '0');
signal TTS_FIFO_do : std_logic_vector(5 downto 0) := (others => '0');
signal TTS_FIFO_di : std_logic_vector(5 downto 0) := (others => '0');
signal TTS_FIFO_wa : std_logic_vector(4 downto 0) := (others => '0');
signal TTS_FIFO_ra : std_logic_vector(4 downto 0) := (others => '0');
signal TTS_FIFO_wa_sync : std_logic_vector(2 downto 0) := (others => '0');
signal TTS_FIFO_wa_sync2 : std_logic_vector(2 downto 0) := (others => '0');
signal TTS_FIFO_wa_sync3 : std_logic_vector(2 downto 0) := (others => '0');
signal TTS_data : std_logic_vector(7 downto 0) := (others => '0');
signal SendTTS : std_logic := '0';
signal ReSendTTS : std_logic := '0';
signal checkTTS_ACK : std_logic := '0';
signal got_TTS_ACK : std_logic := '1';
signal LastTTS : std_logic_vector(3 downto 0) := (others => '0');
signal TTS_ACK : std_logic_vector(3 downto 0) := (others => '0');
signal timer : std_logic_vector(7 downto 0) := (others => '0');
signal timerb : std_logic_vector(8 downto 0) := (others => '0');
begin
TTS_TRIG_data <= trig_data when USE_TRIGGER_PORT else "01" & TTS_data & x"5c";--K28.2
sel_TTS_TRIG <= sel_TTC(0) when USE_TRIGGER_PORT else SendTTS;
process(TTCclk,reset)
begin
	if(reset = '1')then
		bcnt_err_cnt <= (others => '0');
		TTC_FIFO_wa <= (others => '0');
	elsif(TTCclk'event and TTCclk = '1')then
		if(bcnt_err = '1' and bcnt_err_cnt /= x"f")then
			bcnt_err_cnt <= bcnt_err_cnt + 1;
		end if;
		TTC_FIFO_wa(1) <= TTC_FIFO_wa(0);
		TTC_FIFO_wa(0) <= not TTC_FIFO_wa(1);
	end if;
end process;
process(TTCclk)
begin
	if(TTCclk'event and TTCclk = '1')then
		if(BcntRes = '1' or BcntRes_l = '1')then
			Bcnt <= (others => '0');
		else
			Bcnt <= Bcnt + 1;
		end if;
		if(Bcnt = x"dea")then
			BcntRes_l <= '1';
		else
			BcntRes_l <= '0';
		end if;
		BC0 <= BcntRes;
		BC0_l <= BcntRes_l;
		bcnt_err <= BC0 xor BC0_l;
	end if;
end process;
g_TTC_FIFO : for i in 0 to 2 generate
	i_TTC_FIFO: RAM32x6Db PORT MAP(
		wclk => TTCclk,
		di => TTC_FIFO_di(i*6+5 downto i*6),
		we => '1',
		wa => TTC_FIFO_wa,
		ra => TTC_FIFO_ra,
		do => TTC_FIFO_do(i*6+5 downto i*6)
	);
end generate;
TTC_FIFO_di(13 downto 0) <= BC0 & BC0_l & bcnt(3 downto 0) & trig;
process(TTSclk,reset)
begin
	if(reset = '1')then
		TTS_FIFO_wa <= (others => '0');
	elsif(TTSclk'event and TTSclk = '1')then
		case TTS_FIFO_wa(2 downto 0) is
			when "000" => TTS_FIFO_wa(2 downto 0) <= "001";
			when "001" => TTS_FIFO_wa(2 downto 0) <= "011";
			when "011" => TTS_FIFO_wa(2 downto 0) <= "010";
			when "010" => TTS_FIFO_wa(2 downto 0) <= "110";
			when "110" => TTS_FIFO_wa(2 downto 0) <= "111";
			when "111" => TTS_FIFO_wa(2 downto 0) <= "101";
			when "101" => TTS_FIFO_wa(2 downto 0) <= "100";
			when others => TTS_FIFO_wa(2 downto 0) <= "000";
		end case;
	end if;
end process;
i_TTS_FIFO: RAM32x6Db PORT MAP(
		wclk => TTSclk,
		di => TTS_FIFO_di,
		we => '1',
		wa => TTS_FIFO_wa,
		ra => TTS_FIFO_ra,
		do => TTS_FIFO_do
	);
TTS_FIFO_di(3 downto 0) <= TTS;
TTS_FIFO_ra <= "00" & TTS_FIFO_wa_sync3;
process(UsrClk,reset)
begin
	if(reset = '1')then
		TTC_FIFO_wa_sync <= (others => '0');
		TTC_FIFO_wa_sync2 <= (others => '0');
		TTC_FIFO_wa_sync3 <= (others => '0');
		TTS_FIFO_wa_sync <= (others => '0');
		TTS_FIFO_wa_sync2 <= (others => '0');
		TTS_FIFO_wa_sync3 <= (others => '0');
	elsif(UsrClk'event and UsrClk = '1')then
		TTC_FIFO_wa_sync <= TTC_FIFO_wa(1 downto 0);
		TTC_FIFO_wa_sync2 <= TTC_FIFO_wa_sync;
		TTC_FIFO_wa_sync3 <= TTC_FIFO_wa_sync2;
		TTS_FIFO_wa_sync <= TTS_FIFO_wa(2 downto 0);
		TTS_FIFO_wa_sync2 <= TTS_FIFO_wa_sync;
		TTS_FIFO_wa_sync3 <= TTS_FIFO_wa_sync2;
	end if;
end process;
process(UsrClk)
begin
	if(UsrClk'event and UsrClk = '1')then
		if(sel_TTC(1) = '1')then
			sel_TTC <= "00";
		elsif(TTC_FIFO_wa_sync3 /= TTC_FIFO_ra)then
			sel_TTC <= sel_TTC(0) & '1';
		end if;
		if(sel_TTC(1) = '1')then
			TTC_FIFO_ra(1) <= TTC_FIFO_ra(0);
			TTC_FIFO_ra(0) <= not TTC_FIFO_ra(1);
		end if;
		if(timer(N) = '1' and LastTTS /= TTS_FIFO_do(3 downto 0))then
			LastTTS <= TTS_FIFO_do(3 downto 0);
		end if;
		if(RXCHARISK = "01" and RXDATA(7 downto 0) = x"5c")then
			checkTTS_ACK <= '1';
		else
			checkTTS_ACK <= '0';
		end if;
		if((checkTTS_ACK = '1' and TTS_ACK /= LastTTS) or (timer(N) = '1' and got_TTS_ACK = '0'))then
			ReSendTTS <= '1';
		else
			ReSendTTS <= '0';
		end if;
		if((timer(N) = '1' and LastTTS /= TTS_FIFO_do(3 downto 0)) or ReSendTTS = '1' or timerb(8) = '1')then
			SendTTS <= not SendTTS;
		else
			SendTTS <= '0';
		end if;
		if(USE_TRIGGER_PORT or reset = '1' or checkTTS_ACK = '1')then
			got_TTS_ACK <= '1';
		elsif(SendTTS = '1')then
			got_TTS_ACK <= '0';
		end if;
		if(USE_TRIGGER_PORT or reset = '1' or SendTTS = '1' or (timer(N) = '1' and got_TTS_ACK = '0'))then
			timer <= x"30";
		elsif(timer(N) = '0')then
			timer <= timer + 1;
		end if;
		if(USE_TRIGGER_PORT or SendTTS = '1' or ReSendTTS = '1')then
			timerb <= (others => '0');
		else
			timerb <= timerb + 1;
		end if;
	end if;
end process;
i_Hamming: Hamming PORT MAP(
		clk => UsrClk,
		sel_TTC => sel_TTC(0),
		din => Hamming_din,
		dout => trig_data
	);
Hamming_din <= TTC_FIFO_do(13 downto 8) & TTS_FIFO_do(3 downto 0) & TTC_FIFO_do(7 downto 0);
--TTS_data(3 downto 0) <= LastTTS;
process(UsrClk)
variable c : std_logic_vector(3 downto 0);
begin
	c(0) := RXDATA(8) xor RXDATA(9) xor RXDATA(11) xor RXDATA(12);
	c(1) := RXDATA(8) xor RXDATA(10) xor RXDATA(11) xor RXDATA(13);
	c(2) := RXDATA(9) xor RXDATA(10) xor RXDATA(11) xor RXDATA(14);
	c(3) := not RXDATA(11) xor RXDATA(12) xor RXDATA(13) xor RXDATA(14) xor RXDATA(15);
	if(UsrClk'event and UsrClk = '1')then
		TTS_data(3 downto 0) <= TTS_FIFO_do(3 downto 0);
		TTS_data(4) <= TTS_FIFO_do(0) xor TTS_FIFO_do(1) xor TTS_FIFO_do(3);
		TTS_data(5) <= TTS_FIFO_do(0) xor TTS_FIFO_do(2) xor TTS_FIFO_do(3);
		TTS_data(6) <= TTS_FIFO_do(1) xor TTS_FIFO_do(2) xor TTS_FIFO_do(3);
		TTS_data(7) <= not TTS_FIFO_do(0) xor TTS_FIFO_do(1) xor TTS_FIFO_do(2);
		if(c = x"3")then
			TTS_ACK(0) <= not RXDATA(8);
		else
			TTS_ACK(0) <= RXDATA(8);
		end if;
		if(c = x"5")then
			TTS_ACK(1) <= not RXDATA(9);
		else
			TTS_ACK(1) <= RXDATA(9);
		end if;
		if(c = x"6")then
			TTS_ACK(2) <= not RXDATA(10);
		else
			TTS_ACK(2) <= RXDATA(10);
		end if;
		if(c = x"7")then
			TTS_ACK(3) <= not RXDATA(11);
		else
			TTS_ACK(3) <= RXDATA(11);
		end if;
	end if;
end process;
end Behavioral;
