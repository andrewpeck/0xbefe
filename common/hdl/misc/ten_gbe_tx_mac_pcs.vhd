------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company:
-- Engineer: Laurent Pétré (laurent.petre@cern.ch)
--
-- Create Date: 2022-08-03
-- Module Name: ten_gbe_tx_mac_pcs
-- Description:
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.common_pkg.all;
use work.board_config_package.all;

entity ten_gbe_tx_mac_pcs is
    port (
        reset_i        : in  std_logic;

        -- GbE link
        clk_i          : in  std_logic;
        tx_data_o      : out t_mgt_64b_tx_data;

        -- Packet input
        packet_valid_i : in  std_logic;
        packet_data_i  : in  std_logic_vector(63 downto 0);
        packet_end_i   : in  std_logic;
        packet_rden_o  : out std_logic;

        -- Config
        generator_en   : in  std_logic;

        -- Status
        word_rate_o    : out std_logic_vector(31 downto 0)
    );
end ten_gbe_tx_mac_pcs;

architecture ten_gbe_tx_mac_pcs_arch of ten_gbe_tx_mac_pcs is

    -- components
    component lfsr is
        generic (
            LFSR_WIDTH        : integer := 31;
            LFSR_POLY         : unsigned(LFSR_WIDTH-1 downto 0) := "00" & x"10000001";
            LFSR_CONFIG       : string  := "FIBONACCI";
            LFSR_FEED_FORWARD : integer := 0;
            REVERSE           : integer := 0;
            DATA_WIDTH        : integer := 8;
            STYLE             : string  := "AUTO"
        );
        port (
            data_in   : in std_logic_vector(DATA_WIDTH-1 downto 0);
            state_in  : in std_logic_vector(LFSR_WIDTH-1 downto 0);
            data_out  : out std_logic_vector(DATA_WIDTH-1 downto 0);
            state_out : out std_logic_vector(LFSR_WIDTH-1 downto 0)
        );
    end component;

    component ila_ten_gbe_tx_mac_pcs is
        port (
            clk    : in std_logic;
            probe0 : in std_logic_vector(63 downto 0);
            probe1 : in std_logic_vector(0 downto 0);
            probe2 : in std_logic_vector(0 downto 0);
            probe3 : in std_logic_vector(0 downto 0);
            probe4 : in std_logic_vector(1 downto 0);
            probe5 : in std_logic_vector(63 downto 0);
            probe6 : in std_logic_vector(5 downto 0);
            probe7 : in std_logic_vector(0 downto 0)
        );
    end component;

    -- 64b66b constants
    constant HEADER_DATA        : std_logic_vector(1 downto 0) := "01";
    constant HEADER_CTRL        : std_logic_vector(1 downto 0) := "10";

    constant CTRL_BLOCK_CTRL    : std_logic_vector(7 downto 0) := x"1e";
    constant CTRL_BLOCK_START   : std_logic_vector(7 downto 0) := x"78";
    constant CTRL_BLOCK_TERM4   : std_logic_vector(7 downto 0) := x"cc";

    constant CTRL_WORD_IDLE     : std_logic_vector(6 downto 0) := "0000000";
    constant CTRL_WORD_ERROR    : std_logic_vector(6 downto 0) := "0011110";

    -- Ethernet constants
    constant ETH_PREAMBLE       : std_logic_vector(47 downto 0) := x"555555555555";
    constant ETH_SFD            : std_logic_vector( 7 downto 0) := x"d5";

    -- wiring
    signal reset                : std_logic;

    -- 64b66b gearbox
    signal gearbox_sequence     : unsigned(5 downto 0) := (others => '0');
    signal gearbox_ready        : std_logic := '1';

    -- input selection
    signal packet_valid         : std_logic;
    signal packet_data          : std_logic_vector(63 downto 0);
    signal packet_end           : std_logic;
    signal packet_rden          : std_logic := '0';

    -- FSM
    type t_fsm_state is (IDLE, PAYLOAD, FCS, IPG);

    signal fsm_state            : t_fsm_state := IDLE;

    signal encoded_header       : std_logic_vector(1 downto 0);
    signal encoded_data         : std_logic_vector(63 downto 0);

    -- CRC
    signal crc_reg              : std_logic_vector(31 downto 0) := (others => '1');
    signal crc                  : std_logic_vector(31 downto 0);

    -- 64b66b scrambler
    signal scrambler_state      : std_logic_vector(57 downto 0);
    signal scrambler_state_reg  : std_logic_vector(57 downto 0) := (others => '1');
    signal scrambled_header_reg : std_logic_vector(1 downto 0) := (others => '0');
    signal scrambled_data       : std_logic_vector(63 downto 0) := (others => '0');
    signal scrambled_data_reg   : std_logic_vector(63 downto 0);

    -- packet generator
    signal generator_valid      : std_logic;
    signal generator_data       : std_logic_vector(63 downto 0);
    signal generator_end        : std_logic;
    signal generator_rden       : std_logic;

    signal generator_words      : t_std64_array(0 to 7);
    signal generator_words_idx  : integer range 0 to 7 := 0;
    signal generator_timer      : unsigned(11 downto 0) := (others => '0'); -- rate of generated packets ~160MHz/4096

    -- status
    signal sending_word         : std_logic;
    signal word_rate            : std_logic_vector(29 downto 0);

begin

    -- wiring
    i_reset_sync : entity work.synch
        generic  map(
            N_STAGES => 4,
            IS_RESET => true
        )
        port map(
            async_i => reset_i,
            clk_i   => clk_i,
            sync_o  => reset
        );

    -- 64b66b TX MGT gearbox handling
    process (clk_i)
    begin
        if (rising_edge(clk_i)) then
            if (reset = '1') then
                gearbox_sequence <= (others => '0');
                gearbox_ready    <= '1';
            else
                if (gearbox_sequence = "100000") then
                    gearbox_sequence <= "000000";
                else
                    gearbox_sequence <= gearbox_sequence + 1;
                end if;

                if (gearbox_sequence = "011111") then
                    gearbox_ready <= '0';
                else
                    gearbox_ready <= '1';
                end if;
            end if;
        end if;
    end process;

    -- input selection
    packet_valid <= generator_valid when generator_en = '1' else packet_valid_i;
    packet_data  <= generator_data  when generator_en = '1' else packet_data_i;
    packet_end   <= generator_end   when generator_en = '1' else packet_end_i;

    packet_rden_o  <= (packet_rden and gearbox_ready) when generator_en = '0' else '0';
    generator_rden <= (packet_rden and gearbox_ready) when generator_en = '1' else '0';

    -- send FSM
    process(clk_i)
    begin
        if (rising_edge(clk_i)) then
            if (reset = '1') then
                encoded_header <= HEADER_CTRL;
                encoded_data   <= CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_BLOCK_CTRL;
                crc_reg        <= (others => '1');
                packet_rden    <= '0';
                fsm_state      <= IDLE;
            elsif (gearbox_ready = '1') then
                packet_rden <= '0';

                case fsm_state is
                    when IDLE =>

                        encoded_header <= HEADER_CTRL;
                        encoded_data   <= CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_BLOCK_CTRL;
                        crc_reg        <= (others => '1');

                        if (packet_valid = '1') then
                            encoded_header <= HEADER_CTRL;
                            encoded_data   <= ETH_SFD & ETH_PREAMBLE & CTRL_BLOCK_START;
                            packet_rden    <= '1'; -- pre-fetch data
                            fsm_state      <= PAYLOAD;
                        end if;

                    when PAYLOAD =>

                        -- TODO: Ensure that packet_valid does not go low

                        encoded_header <= HEADER_DATA;
                        encoded_data   <= packet_data;
                        crc_reg        <= crc;
                        packet_rden    <= '1'; -- pre-fetch data

                        if (packet_end = '1') then
                            packet_rden <= '0'; -- the last element has already been pulled out
                            fsm_state   <= FCS;
                        end if;

                    when FCS =>

                        encoded_header <= HEADER_CTRL;
                        encoded_data   <= CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & "000" & (not crc_reg) & CTRL_BLOCK_TERM4;
                        fsm_state      <= IPG;

                    when IPG =>

                        encoded_header <= HEADER_CTRL;
                        encoded_data   <= CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_WORD_IDLE & CTRL_BLOCK_CTRL;
                        fsm_state      <= IDLE;

                    when others =>

                        encoded_header <= HEADER_CTRL;
                        encoded_data   <= CTRL_WORD_ERROR & CTRL_WORD_ERROR & CTRL_WORD_ERROR & CTRL_WORD_ERROR & CTRL_WORD_ERROR & CTRL_WORD_ERROR & CTRL_WORD_ERROR & CTRL_WORD_ERROR & CTRL_BLOCK_CTRL;
                        fsm_state      <= IDLE;

                end case;
            end if;
        end if;
    end process;

    -- Ethernet CRC-32
    i_crc: lfsr
        generic map (
            LFSR_WIDTH => 32,
            LFSR_POLY  => x"04c11db7",
            LFSR_CONFIG => "GALOIS",
            REVERSE    => 1,
            DATA_WIDTH => 64
        )
        port map(
            state_in  => crc_reg,
            data_in   => packet_data,
            state_out => crc,
            data_out  => open
        );

    -- 64b66b data scrambler
    i_scramber: lfsr
        generic map (
            LFSR_WIDTH => 58,
            LFSR_POLY  => "00" & x"00008000000001",
            REVERSE    => 1,
            DATA_WIDTH => 64
        )
        port map (
            state_in  => scrambler_state_reg,
            data_in   => encoded_data,
            state_out => scrambler_state,
            data_out  => scrambled_data
        );

    process(clk_i)
    begin
        if (rising_edge(clk_i)) then
            if (reset = '1') then
                scrambler_state_reg  <= (others => '1');
                scrambled_header_reg <= (others => '0');
                scrambled_data_reg   <= (others => '0');
            elsif (gearbox_ready = '1') then
                scrambler_state_reg  <= scrambler_state;
                scrambled_header_reg <= encoded_header;
                scrambled_data_reg   <= scrambled_data;
            end if;
        end if;
    end process;

    -- push data to MGT
    tx_data_o.txsequence(6) <= '0';
    tx_data_o.txsequence(5 downto 0) <= std_logic_vector(gearbox_sequence);

    tx_data_o.txheader(2) <= '0';
    tx_data_o.txheader(1 downto 0) <= scrambled_header_reg;

    g_reverse_data: for i in scrambled_data_reg'range generate
        -- Xilinx MGT sends MSB first while our convention sends LSB first
        tx_data_o.txdata(scrambled_data_reg'left - i) <= scrambled_data_reg(i);
    end generate;

    -- packet generator
    generator_words(0) <= x"febe" & x"00000000febe";
    generator_words(1) <= x"0000" & x"be88" & x"ffffffff";
    generator_words(2) <= (others => '0');
    generator_words(3) <= (others => '1');
    generator_words(4) <= (others => '0');
    generator_words(5) <= (others => '1');
    generator_words(6) <= (others => '0');
    generator_words(7) <= (others => '1');

    generator_valid <= '1' when (to_integer(generator_timer) = 0) else '0';
    generator_data  <= generator_words(generator_words_idx);
    generator_end   <= '1' when (to_integer(generator_timer) = 0 and generator_words_idx = 7) else '0';

    process(clk_i)
    begin
        if (rising_edge(clk_i)) then
            if (reset = '1')  then
                generator_words_idx <= 0;
                generator_timer     <= (others => '0');
            elsif (to_integer(generator_timer) = 0) then
                if (generator_rden = '1') then
                    if (generator_words_idx >= 7) then
                        generator_words_idx <= 0;
                        generator_timer     <= generator_timer + 1;
                    else
                        generator_words_idx <= generator_words_idx + 1;
                    end if;
                end if;
            else
                generator_timer <= generator_timer + 1;
            end if;
        end if;
    end process;

    -- word rate
    sending_word <= '0' when (gearbox_ready = '0' or (fsm_state = IDLE and packet_valid = '0')) else '1';

    i_word_rate : entity work.rate_counter
        generic map(
            g_CLK_FREQUENCY => x"099ab10d", -- 161.132813 MHz
            g_COUNTER_WIDTH => 30
        )
        port map(
            clk_i   => clk_i,
            reset_i => reset,
            en_i    => sending_word,
            rate_o  => word_rate
        );

    word_rate_o <= word_rate & "00"; -- 16 bits words

    -- debug
    g_debug: if CFG_DEBUG_10GBE_MAC_PCS = true generate
        i_ila: component ila_ten_gbe_tx_mac_pcs
            port map (
                clk       => clk_i,
                probe0    => packet_data,
                probe1(0) => packet_valid,
                probe2(0) => packet_end,
                probe3(0) => packet_rden,
                probe4    => encoded_header,
                probe5    => encoded_data,
                probe6    => std_logic_vector(gearbox_sequence),
                probe7(0) => gearbox_ready
            );
    end generate;

end ten_gbe_tx_mac_pcs_arch;
