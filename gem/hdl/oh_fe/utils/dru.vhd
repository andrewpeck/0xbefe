-- TODO: add reset for bitskip

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dru is

  generic (
    g_TMR_INSTANCE       : integer := 0;
    g_PHASE_SEL_EXTERNAL : boolean := false
    );
  port(

    clk1x : in std_logic;               -- 40 MHz clock
    clk4x : in std_logic;               -- 160 MHz clock

    i : in  std_logic_vector(7 downto 0);  -- 8-bit input, the even bits are inverted!
    o : out std_logic_vector(7 downto 0);  -- 8-bit recovered output

    e4_in         : in  std_logic_vector (3 downto 0);
    e4_out        : out std_logic_vector (3 downto 0);
    phase_sel_in  : in  std_logic_vector (1 downto 0);
    phase_sel_out : out std_logic_vector (1 downto 0);

    invalid_bitskip_o : out std_logic

    );

end dru;

architecture behavioral of dru is

  signal data_in_delay            : std_logic_vector(7 downto 0) := (others => '0');
  signal data_in_delay_uninverted : std_logic_vector(7 downto 0) := (others => '0');
  signal data7_delay_delay        : std_logic                    := '0';

  signal e4              : std_logic_vector(3 downto 0) := (others => '0');
  signal phase_sel_state : std_logic_vector(1 downto 0) := "00";

  signal positive_bitskip_next : std_logic;
  signal negative_bitskip_next : std_logic;
  signal positive_bitskip      : std_logic;
  signal negative_bitskip      : std_logic;

  signal fifo_s1  : std_logic_vector(2 downto 0)  := "000";
  signal fifo_s2  : std_logic_vector(11 downto 0) := x"000";
  signal fifo_cdc : std_logic_vector(11 downto 0) := x"000";

  signal bitskip_cnt     : unsigned(2 downto 0) := "010";
  signal bitskip_cnt_cdc : unsigned(2 downto 0) := "010";

  signal invalid_bitskip : std_logic := '0';

  signal rxdata : std_logic_vector(7 downto 0) := (others => '0');

  attribute use_clock_enable            : string;
  attribute use_clock_enable of fifo_s2 : signal is "no";

begin

  ----------------------------------------------------------------------------------------------------------------------
  -- Buffer data
  ----------------------------------------------------------------------------------------------------------------------
  process(clk4x)
  begin
    if rising_edge(clk4x) then

      data_in_delay <= i;

      data_in_delay_uninverted <= data_in_delay xor x"55";

      data7_delay_delay <= data_in_delay_uninverted(7);

    end if;
  end process;

  ----------------------------------------------------------------------------------------------------------------------
  -- Self Phase alignment
  ----------------------------------------------------------------------------------------------------------------------

  e4_out        <= e4;
  phase_sel_out <= phase_sel_state;

  --==============--
  --== Internal ==--
  --==============--

  INTERNAL : if (not g_PHASE_SEL_EXTERNAL) generate

    process(clk4x)
    begin
      if rising_edge(clk4x) then

        e4(0) <= (data_in_delay(0) xnor data_in_delay(1)) or (data_in_delay(4) xnor data_in_delay(5));
        e4(1) <= (data_in_delay(1) xnor data_in_delay(2)) or (data_in_delay(5) xnor data_in_delay(6));
        e4(2) <= (data_in_delay(2) xnor data_in_delay(3)) or (data_in_delay(6) xnor data_in_delay(7));
        e4(3) <= (data_in_delay(3) xnor data_in_delay(4)) or (data_in_delay_uninverted(7) xnor data_in_delay(0));

        case phase_sel_state is

          when "00"=>
            if e4(0) = '1' then
              phase_sel_state <= "10";
            elsif e4(3) = '1' then
              phase_sel_state <= "01";
            end if;
          when "01"=>
            if e4(1) = '1' then
              phase_sel_state <= "00";
            elsif e4(0) = '1' then
              phase_sel_state <= "11";
            end if;
          when "11"=>
            if e4(2) = '1' then
              phase_sel_state <= "01";
            elsif e4(1) = '1' then
              phase_sel_state <= "10";
            end if;
          when "10"=>
            if e4(3) = '1' then
              phase_sel_state <= "11";
            elsif e4(2) = '1' then
              phase_sel_state <= "00";
            end if;
          when others => null;

        end case;

      end if;
    end process;

  end generate INTERNAL;

  --==============--
  --== External ==--
  --==============--

  EXTERNAL : if (g_PHASE_SEL_EXTERNAL) generate

    e4              <= e4_in;
    phase_sel_state <= phase_sel_in;

  end generate EXTERNAL;

  ----------------------------------------------------------------------------------------------------------------------
  -- Bitskip
  ----------------------------------------------------------------------------------------------------------------------

  -- Sample the right phases
  process(clk4x)
  begin
    if rising_edge(clk4x) then

      case phase_sel_state is
        when "00"   => fifo_s1 <= data7_delay_delay & data_in_delay_uninverted(0) & data_in_delay_uninverted(4);
        when "01"   => fifo_s1 <= data7_delay_delay & data_in_delay_uninverted(1) & data_in_delay_uninverted(5);
        when "11"   => fifo_s1 <= data7_delay_delay & data_in_delay_uninverted(2) & data_in_delay_uninverted(6);
        when "10"   => fifo_s1 <= data7_delay_delay & data_in_delay_uninverted(3) & data_in_delay_uninverted(7);
        when others => null;
      end case;

    end if;
  end process;

  -- Compute the bitskip
  process(clk4x)
  begin
    if rising_edge(clk4x) then

      if (phase_sel_state = "10" and e4(3) = '0' and e4(2) = '1') then  -- transition from 10 to 00
        negative_bitskip_next <= '1';
      else
        negative_bitskip_next <= '0';
      end if;

      if (phase_sel_state = "00" and e4(3) = '0' and e4(0) = '1') then  -- transition from 00 to 10
        positive_bitskip_next <= '1';
      else
        positive_bitskip_next <= '0';
      end if;

      positive_bitskip <= positive_bitskip_next;
      negative_bitskip <= negative_bitskip_next;

    end if;
  end process;

  -- Process the bitskip
  process(clk4x)
  begin
    if rising_edge(clk4x) then

      if (negative_bitskip = '1') then     -- negative bitskip
        bitskip_cnt <= bitskip_cnt - 1;
        fifo_s2     <= fifo_s2(11-1 downto 0) & fifo_s1(0);
      elsif (positive_bitskip = '1') then  -- positive bitskip
        bitskip_cnt <= bitskip_cnt + 1;
        fifo_s2     <= fifo_s2(11-3 downto 0) & fifo_s1(2 downto 0);
      else                                 -- no bitskip
        bitskip_cnt <= bitskip_cnt;
        fifo_s2     <= fifo_s2(11-2 downto 0) & fifo_s1(1 downto 0);
      end if;

    end if;

  end process;

  ----------------------------------------------------------------------------------------------------------------------
  -- Output deserialization
  ----------------------------------------------------------------------------------------------------------------------

  process(clk1x)
  begin
    if rising_edge(clk1x) then

      fifo_cdc        <= fifo_s2;
      bitskip_cnt_cdc <= bitskip_cnt;

      if bitskip_cnt_cdc = 0 then
        rxdata <= fifo_cdc(7 downto 0);
      elsif bitskip_cnt_cdc = 1 then
        rxdata <= fifo_cdc(8 downto 1);
      elsif bitskip_cnt_cdc = 2 then
        rxdata <= fifo_cdc(9 downto 2);
      elsif bitskip_cnt_cdc = 3 then
        rxdata <= fifo_cdc(10 downto 3);
      elsif bitskip_cnt_cdc = 4 then
        rxdata <= fifo_cdc(11 downto 4);
      else
        rxdata <= (others => '0');
      end if;

      if (bitskip_cnt_cdc >= 5) then
        invalid_bitskip <= '1';
      else
        invalid_bitskip <= invalid_bitskip;
      end if;

    end if;
  end process;

  o                 <= rxdata;
  invalid_bitskip_o <= invalid_bitskip;

end behavioral;
