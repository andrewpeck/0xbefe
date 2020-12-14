----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:04:40 06/08/2014 
-- Design Name: 
-- Module Name:    fifo66X512 - Behavioral 
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

entity fifo66X512 is
		generic (ALMOST_FULL_OFFSET : STD_LOGIC_VECTOR (15 downto 0) := x"0004";
						 ALMOST_EMPTY_OFFSET : STD_LOGIC_VECTOR (15 downto 0) := x"0004");
    Port ( wclk : in  STD_LOGIC;
           rclk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           Di : in  STD_LOGIC_VECTOR (65 downto 0);
           we : in  STD_LOGIC;
           re : in  STD_LOGIC;
           Do : out  STD_LOGIC_VECTOR (65 downto 0);
           almostfull : out  STD_LOGIC;
           almostempty : out  STD_LOGIC;
           full : out  STD_LOGIC;
           empty : out  STD_LOGIC);
end fifo66X512;

architecture Behavioral of fifo66X512 is
constant N : integer := 9;
signal ce_ra: std_logic := '0';
signal RDEN: std_logic := '0';
signal REGCE: std_logic := '0';
signal RAM_dav: std_logic := '0';
signal RAM_Do_vld: std_logic := '0';
signal Do_vld: std_logic := '0';
signal wa_g: std_logic_vector(3 downto 0) := (others => '0');
signal wa_g_sync: std_logic_vector(3 downto 0) := (others => '0');
signal wa_g_sync1: std_logic_vector(3 downto 0) := (others => '0');
signal wa_g_sync2: std_logic_vector(3 downto 0) := (others => '0');
signal wc_w: std_logic_vector(N downto 0) := (others => '0');
signal wc_r: std_logic_vector(N downto 0) := (others => '0');
signal wa: std_logic_vector(N downto 0) := (others => '0');
signal wap: std_logic_vector(N downto 0) := (others => '0');
signal ra_g: std_logic_vector(3 downto 0) := (others => '0');
signal ra_g_sync: std_logic_vector(3 downto 0) := (others => '0');
signal ra_g_sync1: std_logic_vector(3 downto 0) := (others => '0');
signal ra_g_sync2: std_logic_vector(3 downto 0) := (others => '0');
signal ra: std_logic_vector(N downto 0) := (others => '0');
signal rap: std_logic_vector(N downto 0) := (others => '0');
attribute ASYNC_REG                   : string;
attribute ASYNC_REG of wa_g_sync      : signal is "TRUE";
attribute ASYNC_REG of wa_g_sync1      : signal is "TRUE";
attribute ASYNC_REG of wa_g_sync2      : signal is "TRUE";
attribute ASYNC_REG of ra_g_sync      : signal is "TRUE";
attribute ASYNC_REG of ra_g_sync1      : signal is "TRUE";
attribute ASYNC_REG of ra_g_sync2      : signal is "TRUE";
attribute shreg_extract                   : string;
attribute shreg_extract of wa_g_sync      : signal is "TRUE";
attribute shreg_extract of wa_g_sync1      : signal is "TRUE";
attribute shreg_extract of wa_g_sync2      : signal is "TRUE";
attribute shreg_extract of ra_g_sync      : signal is "TRUE";
attribute shreg_extract of ra_g_sync1      : signal is "TRUE";
attribute shreg_extract of ra_g_sync2      : signal is "TRUE";

begin
empty <= not Do_vld;
process(wclk,reset)
variable full_th: std_logic_vector(N downto 0);
begin
	full_th := '0' & not ALMOST_FULL_OFFSET(N-1 downto 0);
	if(reset = '1')then
		wa_g <= (others => '0');
		wa <= (others => '0');
		ra_g_sync <= (others => '0');
		ra_g_sync1 <= (others => '0');
		ra_g_sync2 <= (others => '0');
		rap <= (others => '0');
		wc_w <= (others => '0');
		almostfull <= '0';
		full <= '0';
	elsif(wclk'event and wclk = '1')then
		if(we = '1')then
			case wa_g is
				when x"0" => wa_g <= x"1";
				when x"1" => wa_g <= x"3";
				when x"3" => wa_g <= x"2";
				when x"2" => wa_g <= x"6";
				when x"6" => wa_g <= x"7";
				when x"7" => wa_g <= x"5";
				when x"5" => wa_g <= x"4";
				when x"4" => wa_g <= x"c";
				when x"c" => wa_g <= x"d";
				when x"d" => wa_g <= x"f";
				when x"f" => wa_g <= x"e";
				when x"e" => wa_g <= x"a";
				when x"a" => wa_g <= x"b";
				when x"b" => wa_g <= x"9";
				when x"9" => wa_g <= x"8";
				when others => wa_g <= x"0";
			end case;
			wa <= wa + 1;
		end if;
		ra_g_sync <= ra_g;
		ra_g_sync1 <= ra_g_sync;
		ra_g_sync2 <= ra_g_sync1;
		rap(3) <= ra_g_sync2(3);
		rap(2) <= ra_g_sync2(3) xor ra_g_sync2(2);
		rap(1) <= ra_g_sync2(3) xor ra_g_sync2(2) xor ra_g_sync2(1);
		rap(0) <= ra_g_sync2(3) xor ra_g_sync2(2) xor ra_g_sync2(1) xor ra_g_sync2(0);
		if(rap(3) = '1' and ra_g_sync2(3) = '0')then
			rap(N downto 4) <= rap(N downto 4) + 1;
		end if;
		wc_w <= wa - rap + we;
		if(wc_w >= full_th)then
			almostfull <= '1';
		else
			almostfull <= '0';
		end if;
		if(wc_w(N) = '1' or (and_reduce(wc_w(N-1 downto 0)) = '1' and we = '1'))then
			full <= '1';
		else
			full <= '0';
		end if;
	end if;
end process;
process(rclk,reset)
begin
	if(reset = '1')then
		ra_g <= (others => '0');
		ra <= (others => '0');
		RAM_Do_vld <= '0';
		Do_vld <= '0';
		wa_g_sync <= (others => '0');
		wa_g_sync1 <= (others => '0');
		wa_g_sync2 <= (others => '0');
		wap <= (others => '0');
		wc_r <= (others => '0');
		almostempty <= '1';
	elsif(rclk'event and rclk = '1')then
		if(ce_ra = '1')then
			case ra_g is
				when x"0" => ra_g <= x"1";
				when x"1" => ra_g <= x"3";
				when x"3" => ra_g <= x"2";
				when x"2" => ra_g <= x"6";
				when x"6" => ra_g <= x"7";
				when x"7" => ra_g <= x"5";
				when x"5" => ra_g <= x"4";
				when x"4" => ra_g <= x"c";
				when x"c" => ra_g <= x"d";
				when x"d" => ra_g <= x"f";
				when x"f" => ra_g <= x"e";
				when x"e" => ra_g <= x"a";
				when x"a" => ra_g <= x"b";
				when x"b" => ra_g <= x"9";
				when x"9" => ra_g <= x"8";
				when others => ra_g <= x"0";
			end case;
			ra <= ra + 1;
		end if;
		wa_g_sync <= wa_g;
		wa_g_sync1 <= wa_g_sync;
		wa_g_sync2 <= wa_g_sync1;
		wap(3) <= wa_g_sync2(3);
		wap(2) <= wa_g_sync2(3) xor wa_g_sync2(2);
		wap(1) <= wa_g_sync2(3) xor wa_g_sync2(2) xor wa_g_sync2(1);
		wap(0) <= wa_g_sync2(3) xor wa_g_sync2(2) xor wa_g_sync2(1) xor wa_g_sync2(0);
		if(wap(3) = '1' and wa_g_sync2(3) = '0')then
			wap(N downto 4) <= wap(N downto 4) + 1;
		end if;
		if(ce_ra = '1')then
			wc_r <= wap - ra - 1;
		else
			wc_r <= wap - ra;
		end if;
		if(or_reduce(wc_r(N downto 1)) = '1' or (wc_r(0) = '1' and (RAM_dav = '0' or (re = '0' and RAM_Do_vld = '1' and Do_vld = '1'))))then
			RAM_dav <= '1';
		else
			RAM_dav <= '0';
		end if;
		if(RAM_dav = '1')then
			RAM_Do_vld <= '1';
		elsif(re = '1' or Do_vld = '0')then
			RAM_Do_vld <= '0';
		end if;
		if(RAM_Do_vld = '1')then
			Do_vld <= '1';
		elsif(re = '1')then
			Do_vld <= '0';
		end if;
		if(wc_r < ALMOST_EMPTY_OFFSET(N downto 0))then
			almostempty <= '1';
		else
			almostempty <= '0';
		end if;
	end if;
end process;
i_BRAM_SDP_MACRO : BRAM_SDP_MACRO
   generic map (
      BRAM_SIZE => "36Kb", -- Target BRAM, "18Kb" or "36Kb" 
      DEVICE => "VIRTEX6", -- Target device: "VIRTEX5", "VIRTEX6", "SPARTAN6" 
      WRITE_WIDTH => 66,    -- Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
      READ_WIDTH => 66,     -- Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
      DO_REG => 1, -- Optional output register (0 or 1)
      INIT_FILE => "NONE",
      SIM_COLLISION_CHECK => "ALL", -- Collision check enable "ALL", "WARNING_ONLY", 
                                    -- "GENERATE_X_ONLY" or "NONE"       
      SRVAL => X"000000000000000000", --  Set/Reset value for port output
      INIT => X"000000000000000000", --  Initial values on output port
      WRITE_MODE => "WRITE_FIRST")    -- Specify "READ_FIRST" for same clock or synchronous clocks
    port map (
      DO => Do,         -- Output read data port, width defined by READ_WIDTH parameter
      DI => Di,         -- Input write data port, width defined by WRITE_WIDTH parameter
      RDADDR => ra(N-1 downto 0), -- Input read address, width defined by read port depth
      RDCLK => rclk,   -- 1-bit input read clock
      RDEN => RDEN,     -- 1-bit input read port enable
      REGCE => REGCE,   -- 1-bit input read output register enable
      RST => '0',       -- 1-bit input reset 
      WE => x"ff",         -- Input write enable, width defined by write port depth
      WRADDR => wa(N-1 downto 0), -- Input write address, width defined by write port depth
      WRCLK => wclk,   -- 1-bit input write clock
      WREN => we      -- 1-bit input write port enable
   );
REGCE <= '1' when re = '1' or Do_vld = '0' else '0';
RDEN <= '1' when re = '1' or Do_vld = '0' or RAM_Do_vld = '0' else '0';
ce_ra <= '1' when RAM_dav = '1' and (re = '1' or Do_vld = '0' or RAM_Do_vld = '0') else '0';
end Behavioral;

