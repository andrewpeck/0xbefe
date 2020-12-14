-------------------------------------------------------------------------------
-- Company: EDF Boston University
-- Engineer: Shouxiang Wu
--
-- Create Date:    14:53:20 05/24/2010
-- Design Name:
-- Module Name:    TTC_decoder - Behavioral
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
-- TTC Hamming encoding
-- hmg[0] = d[0]^d[1]^d[2]^d[3];
-- hmg[1] = d[0]^d[4]^d[5]^d[6];
-- hmg[2] = d[1]^d[2]^d[4]^d[5]^d[7];
-- hmg[3] = d[1]^d[3]^d[4]^d[6]^d[7];
-- hmg[4] = d[0]^d[2]^d[3]^d[5]^d[6]^d[7];
--
-- As no detailed timing of TTCrx chip is available, L1A may need to add
-- several clocks of delay pending test results -- May 27 2010
-------------------------------------------------------------------------------
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

entity TTC_decoder is
	Port ( TTC_CLK_p : in  STD_LOGIC;
				 TTC_CLK_n : in  STD_LOGIC;
				 TTC_rst : in  STD_LOGIC;-- asynchronous reset after TTC_CLK_p/TTC_CLK_n frequency changed
				 TTC_data_p : in  STD_LOGIC;
				 TTC_data_n : in  STD_LOGIC;
				 TTC_CLK_out : out  STD_LOGIC;
				 TTCready : out  STD_LOGIC;
				 L1Accept : out  STD_LOGIC;
				 BCntRes : out  STD_LOGIC;
				 EvCntRes : out  STD_LOGIC;
				 SinErrStr : out  STD_LOGIC;
				 DbErrStr : out  STD_LOGIC;
				 BrcstStr : out  STD_LOGIC;
				 Brcst : out  STD_LOGIC_VECTOR (7 downto 2));
end TTC_decoder;

architecture Behavioral of TTC_decoder is
function DIST(A, B : std_logic_vector(3 downto 0)) return std_logic_vector is
begin
	if(A > B)then
		return A - B;
	else
		return B - A;
	end if;
end DIST;
constant Coarse_Delay: std_logic_vector(3 downto 0) := x"0";
signal resetSyncRegs : std_logic_vector(3 downto 0) := (others => '0');
signal edgeCntr : std_logic_vector(15 downto 0) := (others => '0');
signal CLKFB : std_logic := '0';
signal TTC_CLK_in : std_logic := '0';
signal TTC_CLK_delay : std_logic := '0';
signal TTC_CLK_dcm : std_logic := '0';
signal TTC_CLK : std_logic := '0';
signal TTC_CLK7x_dcm : std_logic := '0';
signal TTC_CLK7x : std_logic := '0';
signal TTC_lock : std_logic := '0';
signal TTC_CLK_toggle : std_logic := '0';
signal TTC_CLK_toggle_q : std_logic := '0';
signal phase : std_logic_vector(2 downto 0) := (others => '0');
signal PhaseCntr : std_logic_vector(2 downto 0) := (others => '0');
type array2x4 is array(0 to 1) of std_logic_vector(3 downto 0);
signal location : array2x4 := (x"0",x"0");
signal location_used : std_logic_vector(1 downto 0) := (others => '0');
signal location_sum : std_logic_vector(4 downto 0) := (others => '0');
signal distance : std_logic_vector(3 downto 0) := (others => '0');
signal PSshift : std_logic_vector(3 downto 0) := (others => '0');
signal offset : std_logic_vector(4 downto 0) := (others => '0');
signal TTC_data_in : std_logic := '0';
signal iddr_q : std_logic_vector(1 downto 0) := (others => '0');
signal TTC_data_pSyncRegs : std_logic_vector(3 downto 0) := (others => '0');
signal TTC_data_nSyncRegs : std_logic_vector(3 downto 0) := (others => '0');
signal TTC_data_p_dl : std_logic := '0';
signal TTC_data_n_dl : std_logic := '0';
signal sel_location : std_logic := '0';
signal got_edge : std_logic := '0';
signal new_location : std_logic_vector(3 downto 0) := (others => '0');
signal edge_p : std_logic_vector(2 downto 0) := (others => '0');
signal edge_n : std_logic_vector(2 downto 0) := (others => '0');
signal valid_edge_p : std_logic := '0';
signal valid_edge_n : std_logic := '0';
signal swap_channel : std_logic := '0';
signal last_data : std_logic := '0';
signal new_data : std_logic := '0';
signal use_default : std_logic := '0';
signal sampled_data : std_logic_vector(1 downto 0) := (others => '0');
signal TTCreadyCntr : std_logic_vector(7 downto 0) := (others => '0');
signal strng_length : std_logic_vector(3 downto 0) := (others => '0');
signal TTC_data : std_logic_vector(1 downto 0) := (others => '0');
signal L1A : std_logic := '0';
signal sr : std_logic_vector(12 downto 0) := (others => '0');
signal rec_cntr : std_logic_vector(5 downto 0) := (others => '0');
signal rec_cmd : std_logic := '0';
signal FMT : std_logic := '0';
signal brcst_str : std_logic_vector(3 downto 0) := (others => '0');
signal brcst_data : std_logic_vector(7 downto 0) := (others => '0');
signal brcst_syn : std_logic_vector(4 downto 0) := (others => '0');
signal brcst_i : std_logic_vector(7 downto 2) := (others => '0');
signal frame_err : std_logic := '0';
signal single_err : std_logic := '0';
signal double_err : std_logic := '0';
signal EvCntReset : std_logic := '0';
signal BCntReset : std_logic := '0';
signal startup : std_logic := '1';
signal check_location : std_logic := '0';
signal check_location_dl : std_logic := '0';
signal move_location : std_logic := '0';
signal PSDONE : std_logic := '0';
signal PSEN : std_logic := '0';
signal PSINCDEC : std_logic := '1';
signal PScntr : std_logic_vector(9 downto 0) := (others => '0');
begin
TTC_CLK_out <= TTC_CLK;
Brcst <= Brcst_i;
TTCready <= TTCreadyCntr(7);
i_TTC_CLK_in: ibufds generic map(DIFF_TERM => TRUE,IOSTANDARD => "LVDS_25") port map(i => TTC_CLK_p, ib => TTC_CLK_n, o => TTC_CLK_in);
i_TTC_CLK_buf: bufg port map(i => TTC_CLK_dcm, o => TTC_CLK);
i_TTC_CLK7x_buf: bufg port map(i => TTC_CLK7x_dcm, o => TTC_CLK7x);
process(TTC_CLK,TTC_lock)
begin
	if(TTC_lock = '0')then
		startup <= '1';
		move_location <= '0';
		check_location <= '0';
		PSEN <= '0';
		PSINCDEC <= '1';
		PSshift <= (others => '0');
		PScntr <= (others => '0');
		offset <= (others => '0');
		distance <= (others => '0');
		TTCreadyCntr <= (others => '0');
	elsif(TTC_CLK'event and TTC_CLK = '1')then
		if((check_location_dl = '1' and or_reduce(PSshift) = '1') or (or_reduce(PScntr) = '1' and PSDONE = '1'))then
			PSEN <= '1';
		else
			PSEN <= '0';
		end if;
		if(check_location_dl = '1' and or_reduce(PSshift) = '1')then
			move_location <= '1';
		elsif(or_reduce(PScntr) = '0' and PSDONE = '1')then
			move_location <= '0';
		end if;
		if(location_used = "11")then
			startup <= '0';
		end if;
		if(location_used = "11" and startup = '1')then
			check_location <= '1';
		else
			check_location <= '0';
		end if;
		location_sum <= ('0' & location(1)) + ('0' & location(0));
		offset <= location_sum - "01101";
		distance <= location(1) - location(0);
		if(distance > x"7")then
			if(offset(4) = '0')then
				PSshift <= x"e" - offset(3 downto 0);
				PSINCDEC <= '1';
			else
				PSshift <= x"e" + offset(3 downto 0);
				PSINCDEC <= '0';
			end if;
		else
			if(offset(4) = '0')then
				PSshift <= offset(3 downto 0);
				PSINCDEC <= '0';
			else
				PSshift <= x"0" - offset(3 downto 0);
				PSINCDEC <= '1';
			end if;
		end if;
		if(check_location_dl = '1' and or_reduce(PSshift) = '1')then
			PScntr <= PSshift & "000000";
		elsif(PSDONE = '1' and or_reduce(PScntr) = '1')then
			if(or_reduce(PScntr(5 downto 0)) = '0')then
				PScntr(5 downto 0) <= "101001";
				PScntr(9 downto 6) <= PScntr(9 downto 6) - 1;
			else
				PScntr(5 downto 0) <= PScntr(5 downto 0) - 1;
			end if;
		end if;
		if(location_used /= "11")then
			TTCreadyCntr <= (others => '0');
		elsif(TTCreadyCntr(7) = '0')then
			TTCreadyCntr <= TTCreadyCntr + 1;
		end if;
	end if;
end process;
i_check_location_dl : SRL16E
   port map (
      Q => check_location_dl,       -- SRL data output
      A0 => '1',     -- Select[0] input
      A1 => '0',     -- Select[1] input
      A2 => '0',     -- Select[2] input
      A3 => '0',     -- Select[3] input
      CE => '1',     -- Clock enable input
      CLK => TTC_CLK,   -- Clock input
      D => check_location        -- SRL data input
   );
i_MMCM_TTC_clk : MMCM_ADV
   generic map (
      BANDWIDTH => "OPTIMIZED",      -- Jitter programming (OPTIMIZED, HIGH, LOW)
      CLKFBOUT_MULT_F => 21.0,        -- Multiply value for all CLKOUT (2.000-64.000).
      -- CLKIN_PERIOD: Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
      CLKIN1_PERIOD => 24.948,
      -- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for CLKOUT (1-128)
      CLKOUT0_DIVIDE_F => 3.0,       -- Divide amount for CLKOUT0 (1.000-128.000).
      CLKOUT1_DIVIDE => 21,
      -- USE_FINE_PS: Fine phase shift enable (TRUE/FALSE)
      CLKFBOUT_USE_FINE_PS => TRUE
   )
   port map (
      -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
      CLKOUT0 => TTC_CLK7x_dcm,           -- 1-bit output: CLKOUT0
      CLKOUT1 => TTC_CLK_dcm,           -- 1-bit output: CLKOUT0
      -- Dynamic Phase Shift Ports: 1-bit (each) output: Ports used for dynamic phase shifting of the outputs
      PSDONE => PSDONE,             -- 1-bit output: Phase shift done
      -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
      CLKFBOUT => CLKFB,         -- 1-bit output: Feedback clock
      -- Status Ports: 1-bit (each) output: MMCM status ports
      CLKFBSTOPPED => open, -- 1-bit output: Feedback clock stopped
      CLKINSTOPPED => open, -- 1-bit output: Input clock stopped
      LOCKED => TTC_lock,             -- 1-bit output: LOCK
      -- Clock Inputs: 1-bit (each) input: Clock inputs
      CLKIN1 => TTC_CLK_in,             -- 1-bit input: Primary clock
      CLKIN2 => '0',             -- 1-bit input: Secondary clock
      -- Control Ports: 1-bit (each) input: MMCM control ports
      CLKINSEL => '1',         -- 1-bit input: Clock select, High=CLKIN1 Low=CLKIN2
      PWRDWN => '0',             -- 1-bit input: Power-down
      RST => TTC_rst,                   -- 1-bit input: Reset
      -- DRP Ports: 7-bit (each) input: Dynamic reconfiguration ports
      DADDR => (others => '0'),               -- 7-bit input: DRP address
      DCLK => '0',                 -- 1-bit input: DRP clock
      DEN => '0',                   -- 1-bit input: DRP enable
      DI => (others => '0'),                     -- 16-bit input: DRP data
      DWE => '0',                   -- 1-bit input: DRP write enable
      -- Dynamic Phase Shift Ports: 1-bit (each) input: Ports used for dynamic phase shifting of the outputs
      PSCLK => TTC_CLK,               -- 1-bit input: Phase shift clock
      PSEN => PSEN,                 -- 1-bit input: Phase shift enable
      PSINCDEC => PSINCDEC,         -- 1-bit input: Phase shift increment/decrement
      -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
      CLKFBIN => CLKFB            -- 1-bit input: Feedback clock
   );
i_TTC_data_in: ibufds generic map(DIFF_TERM => TRUE,IOSTANDARD => "LVDS_25") port map(i => TTC_data_p, ib => TTC_data_n, o => TTC_data_in);
i_TTC_data : IDDR
   generic map (
      DDR_CLK_EDGE => "SAME_EDGE_PIPELINED", -- "OPPOSITE_EDGE", "SAME_EDGE"
                                       -- or "SAME_EDGE_PIPELINED"
      INIT_Q1 => '0', -- Initial value of Q1: '0' or '1'
      INIT_Q2 => '0', -- Initial value of Q2: '0' or '1'
      SRTYPE => "SYNC") -- Set/Reset type: "SYNC" or "ASYNC"
   port map (
      Q1 => iddr_q(0), -- 1-bit output for positive edge of clock
      Q2 => iddr_q(1), -- 1-bit output for negative edge of clock
      C => TTC_CLK7x,   -- 1-bit clock input
      CE => '1', -- 1-bit clock enable input
      D => TTC_data_in,   -- 1-bit DDR data input
      R => '0',   -- 1-bit reset
      S => '0'    -- 1-bit set
      );
process(TTC_CLK7x, TTC_lock)
begin
	if(TTC_lock = '0')then
		resetSyncRegs <= x"f";
	elsif(TTC_CLK7x'event and TTC_CLK7x = '1')then
		resetSyncRegs <= resetSyncRegs(2 downto 0) & '0';
	end if;
end process;
process(TTC_CLK7x,edge_p,edge_n)
variable edges : std_logic_vector(5 downto 0);
begin
	for i in 0 to 2 loop
		edges(i*2) := edge_p(i);
		edges(i*2+1) := edge_n(i);
	end loop;
	if(TTC_CLK7x'event and TTC_CLK7x = '1')then
		TTC_data_pSyncRegs <= TTC_data_pSyncRegs(2 downto 0) & iddr_q(0);
		TTC_data_nSyncRegs <= TTC_data_nSyncRegs(2 downto 0) & iddr_q(1);
		if(TTC_data_pSyncRegs(3) = TTC_data_nSyncRegs(3) and TTC_data_pSyncRegs(3) = TTC_data_pSyncRegs(2) and TTC_data_nSyncRegs(3) /= TTC_data_nSyncRegs(2))then
			edge_n(0) <= '1';
		else
			edge_n(0) <= '0';
		end if;
		edge_n(2 downto 1) <= edge_n(1 downto 0);
		if(TTC_data_pSyncRegs(3 downto 2) = TTC_data_nSyncRegs(3 downto 2) and TTC_data_pSyncRegs(2) /= TTC_data_pSyncRegs(3))then
			edge_p(0) <= '1';
		else
			edge_p(0) <= '0';
		end if;
		edge_p(2 downto 1) <= edge_p(1 downto 0);
		if(edges(4 downto 0) = "00100")then
			valid_edge_p <= '1';
		else
			valid_edge_p <= '0';
		end if;
		if(edges(5 downto 1) = "00100")then
			valid_edge_n <= '1';
		else
			valid_edge_n <= '0';
		end if;
		if(resetSyncRegs(3) = '1')then
			edgeCntr <= (others => '0');
		elsif(edgeCntr(15) = '0' and (valid_edge_p = '1' or valid_edge_n = '1'))then
			edgeCntr <= edgeCntr + 1;
		end if;
		if(location_used = "01")then
			PhaseCntr <= PhaseCntr + 1;
		else
			PhaseCntr <= "000";
		end if;
		new_location <= phase & valid_edge_n;
		got_edge <= valid_edge_p or valid_edge_n;
		if(edgeCntr(15) = '0' or move_location = '1')then
			location_used <= "00";
		elsif(location_used = "11")then
			if(got_edge = '1')then
				if(sel_location = '0')then
					location(0) <= new_location;
				else
					location(1) <= new_location;
				end if;
			end if;
		elsif(got_edge = '1')then
			if(location_used(0) = '1')then
				location(1) <= new_location;
				location_used(1) <= '1';
			elsif(phase = "111")then
				location_used <= "00";
			else
				location(0) <= new_location;
				location_used(0) <= '1';
			end if;
		elsif(phase = "111")then
			location_used <= "00";
		end if;
		if(unsigned(DIST(location(0),(phase & valid_edge_n))) < unsigned(DIST(location(1),(phase & valid_edge_n))))then
			sel_location <= '0';
		else
			sel_location <= '1';
		end if;
		TTC_data_p_dl <= TTC_data_pSyncRegs(3);
		TTC_data_n_dl <= TTC_data_nSyncRegs(3);
		if(valid_edge_p = '1')then
			new_data <= TTC_data_p_dl;
		elsif(valid_edge_n = '1')then
			new_data <= TTC_data_n_dl;
		end if;
		if(location(1)(3 downto 1) = phase)then
			use_default <= '1';
		else
			use_default <= '0';
		end if;
		if(sel_location = '0')then
			last_data <= new_data;
		elsif(got_edge = '1')then
			sampled_data(0) <= last_data;
			sampled_data(1) <= new_data;
			last_data <= new_data;
		elsif(use_default = '1')then
			sampled_data(0) <= last_data;
			sampled_data(1) <= last_data;
		end if;
		TTC_CLK_toggle_q <= TTC_CLK_toggle;
		if(TTC_CLK_toggle_q /= TTC_CLK_toggle)then
			phase <= "001";
		elsif(phase = "110")then
			phase <= "000";
		else
			phase <= phase + 1;
		end if;
		if(phase = "010")then
			if(swap_channel = '0')then
				TTC_data <= sampled_data;
			else
				TTC_data <= sampled_data(0) & sampled_data(1);
			end if;
		end if;
	end if;
end process;
process(TTC_CLK)
begin
	if(TTC_CLK'event and TTC_CLK = '1')then
		TTC_CLK_toggle <= not TTC_CLK_toggle;
--	L1A = '1' and b_channel data = '0' can not repeat 11 times
		if(TTC_data /= "01")then
			strng_length <= (others => '0');
		else
			strng_length <= strng_length + 1;
		end if;
		if(strng_length = x"b")then
			swap_channel <= not swap_channel;
		end if;
		L1A <= TTC_data(0) and TTCreadyCntr(7);
		if(rec_cmd = '0')then
			rec_cntr <= (others => '0');
		else
			rec_cntr <= rec_cntr + 1;
		end if;
		if(TTCreadyCntr(7) = '0' or rec_cntr(5 downto 3) = "101" or (FMT = '0' and rec_cntr(3 downto 0) = x"d"))then
			rec_cmd <= '0';
		elsif(TTC_data(1) = '0')then
			rec_cmd <= '1';
		end if;
		if(or_reduce(rec_cntr) = '0')then
			FMT <= TTC_data(1);
		end if;
		sr <= sr(11 downto 0) & TTC_data(1);
		if(FMT = '0' and rec_cntr(3 downto 0) = x"e")then
			brcst_data <= sr(12 downto 5);
			brcst_syn(0) <= sr(0) xor sr(5) xor sr(6) xor sr(7) xor sr(8);
			brcst_syn(1) <= sr(1) xor sr(5) xor sr(9) xor sr(10) xor sr(11);
			brcst_syn(2) <= sr(2) xor sr(6) xor sr(7) xor sr(9) xor sr(10) xor sr(12);
			brcst_syn(3) <= sr(3) xor sr(6) xor sr(8) xor sr(9) xor sr(11) xor sr(12);
			brcst_syn(4) <= xor_reduce(sr);
			frame_err <= not TTC_data(1);
			brcst_str(0) <= '1';
		else
			brcst_str(0) <= '0';
		end if;
		single_err <= xor_reduce(brcst_syn) and not frame_err;
		if((or_reduce(brcst_syn) = '1' and xor_reduce(brcst_syn) = '0') or frame_err = '1')then
			double_err <= '1';
		else
			double_err <= '0';
		end if;
		SinErrStr <= single_err and brcst_str(1);
		DbErrStr <= double_err and brcst_str(1);
		brcst_str(2) <= brcst_str(1) and not double_err;
		if(brcst_syn(3 downto 0) = x"c")then
			Brcst_i(7) <= not brcst_data(7);
		else
			Brcst_i(7) <= brcst_data(7);
		end if;
		if(brcst_syn(3 downto 0) = x"a")then
			Brcst_i(6) <= not brcst_data(6);
		else
			Brcst_i(6) <= brcst_data(6);
		end if;
		if(brcst_syn(3 downto 0) = x"6")then
			Brcst_i(5) <= not brcst_data(5);
		else
			Brcst_i(5) <= brcst_data(5);
		end if;
		if(brcst_syn(3 downto 0) = x"e")then
			Brcst_i(4) <= not brcst_data(4);
		else
			Brcst_i(4) <= brcst_data(4);
		end if;
		if(brcst_syn(3 downto 0) = x"9")then
			Brcst_i(3) <= not brcst_data(3);
		else
			Brcst_i(3) <= brcst_data(3);
		end if;
		if(brcst_syn(3 downto 0) = x"5")then
			Brcst_i(2) <= not brcst_data(2);
		else
			Brcst_i(2) <= brcst_data(2);
		end if;
		if(brcst_syn(3 downto 0) = x"d")then
			EvCntReset <= not brcst_data(1);
		else
			EvCntReset <= brcst_data(1);
		end if;
		if(brcst_syn(3 downto 0) = x"3")then
			BCntReset <= not brcst_data(0);
		else
			BCntReset <= brcst_data(0);
		end if;
		BCntRes <= brcst_str(3) and BCntReset;
		EvCntRes <= brcst_str(3) and EvCntReset;
		BrcstStr <= brcst_str(3) and or_reduce(Brcst_i);
	end if;
end process;
i_L1Accept : SRL16E
   port map (
      Q => L1Accept,       -- SRL data output
      A0 => Coarse_Delay(0),     -- Select[0] input
      A1 => Coarse_Delay(1),     -- Select[1] input
      A2 => Coarse_Delay(2),     -- Select[2] input
      A3 => Coarse_Delay(3),     -- Select[3] input
      CE => '1',     -- Clock enable input
      CLK => TTC_CLK,   -- Clock input
      D => L1A        -- SRL data input
   );
i_brcst_str1 : SRL16E
   port map (
      Q => brcst_str(1),       -- SRL data output
      A0 => '0',     -- Select[0] input
      A1 => '1',     -- Select[1] input
      A2 => '0',     -- Select[2] input
      A3 => '0',     -- Select[3] input
      CE => '1',     -- Clock enable input
      CLK => TTC_CLK,   -- Clock input
      D => brcst_str(0)        -- SRL data input
   );
i_brcst_str3 : SRL16E
   port map (
      Q => brcst_str(3),       -- SRL data output
      A0 => Coarse_Delay(0),     -- Select[0] input
      A1 => Coarse_Delay(1),     -- Select[1] input
      A2 => Coarse_Delay(2),     -- Select[2] input
      A3 => Coarse_Delay(3),     -- Select[3] input
      CE => '1',     -- Clock enable input
      CLK => TTC_CLK,   -- Clock input
      D => brcst_str(2)        -- SRL data input
   );
end Behavioral;
