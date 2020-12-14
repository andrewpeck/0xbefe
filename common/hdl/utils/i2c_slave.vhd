------------------------------------------------------------
-- File      : I2C_minion.vhd
------------------------------------------------------------
-- Author    : Peter Samarin <peter.samarin@gmail.com>
------------------------------------------------------------
-- Copyright (c) 2019 Peter Samarin
------------------------------------------------------------
--MIT License
--
--Copyright (c) 2014-2016 Peter Samarin
--
--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

------------------------------------------------------------
entity i2c_slave is
    generic(
        SLAVE_ADDR          : std_logic_vector(6 downto 0);
        SCL_FILTER_LENGTH   : integer := 100;
        G_DEBUG             : boolean := false
    );
    port(
        scl              : in    std_logic;
        sda_io           : inout std_logic;
        clk              : in    std_logic;
        rst              : in    std_logic;
        -- User interface
        read_req         : out   std_logic;
        data_to_master   : in    std_logic_vector(7 downto 0);
        data_valid       : out   std_logic;
        data_from_master : out   std_logic_vector(7 downto 0);
        write_active_o   : out   std_logic
    );
end entity i2c_slave;
------------------------------------------------------------
architecture arch of i2c_slave is

    COMPONENT ila_i2c
        PORT(
            clk     : IN STD_LOGIC;
            probe0  : IN STD_LOGIC;
            probe1  : IN STD_LOGIC;
            probe2  : IN STD_LOGIC;
            probe3  : IN STD_LOGIC;
            probe4  : IN STD_LOGIC;
            probe5  : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            probe6  : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            probe7  : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
            probe8  : IN STD_LOGIC;
            probe9  : IN STD_LOGIC;
            probe10 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
            probe11 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            probe12 : IN STD_LOGIC;
            probe13 : IN STD_LOGIC;
            probe14 : IN STD_LOGIC;
            probe15 : IN STD_LOGIC
        );
    END COMPONENT;    
    
    type state_t is (idle, get_address_and_cmd,
                     answer_ack_start, write,
                     read, read_ack_start,
                     read_ack_got_rising, read_stop);
    -- I2C state management
    signal state_reg          : state_t              := idle;
    signal cmd_reg            : std_logic            := '0';
    signal bits_processed_reg : integer range 0 to 8 := 0;
    signal continue_reg       : std_logic            := '0';

    signal sda_in          : std_logic;
    signal sda_drive_low_b : std_logic := '1';
    signal scl_low_cnt     : integer range 0 to SCL_FILTER_LENGTH := 0;
    signal scl_high_cnt    : integer range 0 to SCL_FILTER_LENGTH := 0;
    signal sda_low_cnt     : integer range 0 to SCL_FILTER_LENGTH := 0;
    signal sda_high_cnt    : integer range 0 to SCL_FILTER_LENGTH := 0;

    signal scl_pre_internal : std_logic := 'Z';
    signal scl_internal     : std_logic := '1';
    signal sda_pre_internal : std_logic := 'Z';
    signal sda_internal     : std_logic := '1';

    -- Helpers to figure out next state
    signal start_reg       : std_logic := '0';
    signal stop_reg        : std_logic := '0';
    signal scl_rising_reg  : std_logic := '0';
    signal scl_falling_reg : std_logic := '0';

    -- Address and data received from master
    signal addr_reg             : std_logic_vector(6 downto 0) := (others => '0');
    signal data_reg             : std_logic_vector(6 downto 0) := (others => '0');
    signal data_from_master_reg : std_logic_vector(7 downto 0) := (others => '0');

    signal scl_prev_reg : std_logic := 'Z';
    -- Minion writes on scl
    signal scl_wen_reg  : std_logic := '0';
    signal scl_o_reg    : std_logic := '0'; -- unused for now
    signal sda_prev_reg : std_logic := 'Z';

    -- User interface
    signal data_valid_reg     : std_logic                    := '0';
    signal read_req_reg       : std_logic                    := '0';
    signal data_to_master_reg : std_logic_vector(7 downto 0) := (others => '0');
begin
    
    process(clk) is
    begin
        if rising_edge(clk) then
            scl_pre_internal <= scl;
            sda_pre_internal <= sda_in;
        end if;
    end process;

    -- filter the scl a bit
    process(clk)
    begin
        if rising_edge(clk) then
            if scl_pre_internal = '0' and scl_low_cnt /= SCL_FILTER_LENGTH then
                scl_low_cnt <= scl_low_cnt + 1;
                scl_high_cnt <= 0;
            elsif scl_pre_internal = '1' and scl_high_cnt /= SCL_FILTER_LENGTH then
                scl_low_cnt <= 0;
                scl_high_cnt <= scl_high_cnt + 1;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if scl_low_cnt = SCL_FILTER_LENGTH then
                scl_internal <= '0';
            elsif scl_high_cnt = SCL_FILTER_LENGTH then
                scl_internal <= '1';
            else
                scl_internal <= scl_internal;
            end if;
        end if;
    end process;

    -- filter the sda a bit
    process(clk)
    begin
        if rising_edge(clk) then
            if sda_pre_internal = '0' and sda_low_cnt /= SCL_FILTER_LENGTH then
                sda_low_cnt <= sda_low_cnt + 1;
                sda_high_cnt <= 0;
            elsif sda_pre_internal = '1' and sda_high_cnt /= SCL_FILTER_LENGTH then
                sda_low_cnt <= 0;
                sda_high_cnt <= sda_high_cnt + 1;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if sda_low_cnt = SCL_FILTER_LENGTH then
                sda_internal <= '0';
            elsif sda_high_cnt = SCL_FILTER_LENGTH then
                sda_internal <= '1';
            else
                sda_internal <= sda_internal;
            end if;
        end if;
    end process;

--    sda_internal <= '0' when sda_pre_internal = '0' else '1';

    process(clk) is
    begin
        if rising_edge(clk) then
            -- Delay SCL and SDA by 1 clock cycle
            scl_prev_reg   <= scl_internal;
            sda_prev_reg   <= sda_internal;
            -- Detect rising and falling SCL
            scl_rising_reg <= '0';
            if scl_prev_reg = '0' and scl_internal = '1' then
                scl_rising_reg <= '1';
            end if;
            scl_falling_reg <= '0';
            if scl_prev_reg = '1' and scl_internal = '0' then
                scl_falling_reg <= '1';
            end if;

            -- Detect I2C START condition
            start_reg <= '0';
            stop_reg  <= '0';
            if scl_internal = '1' and scl_prev_reg = '1' and sda_prev_reg = '1' and sda_internal = '0' then
                start_reg <= '1';
                stop_reg  <= '0';
            end if;

            -- Detect I2C STOP condition
            if scl_prev_reg = '1' and scl_internal = '1' and sda_prev_reg = '0' and sda_internal = '1' then
                start_reg <= '0';
                stop_reg  <= '1';
            end if;

        end if;
    end process;

    ----------------------------------------------------------
    -- I2C state machine
    ----------------------------------------------------------
    process(clk) is
    begin
        if rising_edge(clk) then
            -- Default assignments
            sda_drive_low_b <= '1';
            -- User interface
            data_valid_reg <= '0';
            read_req_reg   <= '0';

            case state_reg is
                when idle =>
                    if start_reg = '1' then
                        state_reg          <= get_address_and_cmd;
                        bits_processed_reg <= 0;
                    end if;

                when get_address_and_cmd =>
                    if scl_rising_reg = '1' then
                        if bits_processed_reg < 7 then
                            bits_processed_reg               <= bits_processed_reg + 1;
                            addr_reg(6 - bits_processed_reg) <= sda_internal;
                        elsif bits_processed_reg = 7 then
                            bits_processed_reg <= bits_processed_reg + 1;
                            cmd_reg            <= sda_internal;
                        end if;
                    end if;

                    if bits_processed_reg = 8 and scl_falling_reg = '1' then
                        bits_processed_reg <= 0;
                        if addr_reg = SLAVE_ADDR then -- check req address
                            state_reg <= answer_ack_start;
                            if cmd_reg = '1' then -- issue read request 
                                read_req_reg       <= '1';
                                data_to_master_reg <= data_to_master;
                            end if;
                        else
                            assert false
                                report ("I2C: target/minion address mismatch (data is being sent to another minion).")
                                severity note;
                            state_reg <= idle;
                        end if;
                    end if;

                ----------------------------------------------------
                -- I2C acknowledge to master
                ----------------------------------------------------
                when answer_ack_start =>
                    sda_drive_low_b <= '0';
                    if scl_falling_reg = '1' then
                        if cmd_reg = '0' then
                            state_reg <= write;
                        else
                            state_reg <= read;
                        end if;
                    end if;

                ----------------------------------------------------
                -- WRITE
                ----------------------------------------------------
                when write =>
                    if scl_rising_reg = '1' then
                        bits_processed_reg <= bits_processed_reg + 1;
                        if bits_processed_reg < 7 then
                            data_reg(6 - bits_processed_reg) <= sda_internal;
                        else
                            data_from_master_reg <= data_reg & sda_internal;
                            data_valid_reg       <= '1';
                        end if;
                    end if;

                    if scl_falling_reg = '1' and bits_processed_reg = 8 then
                        state_reg          <= answer_ack_start;
                        bits_processed_reg <= 0;
                    end if;

                ----------------------------------------------------
                -- READ: send data to master
                ----------------------------------------------------
                when read =>
                    if data_to_master_reg(7 - bits_processed_reg) = '0' then
                        sda_drive_low_b <= '0';
                    end if;

                    if scl_falling_reg = '1' then
                        if bits_processed_reg < 7 then
                            bits_processed_reg <= bits_processed_reg + 1;
                        elsif bits_processed_reg = 7 then
                            state_reg          <= read_ack_start;
                            bits_processed_reg <= 0;
                        end if;
                    end if;

                ----------------------------------------------------
                -- I2C read master acknowledge
                ----------------------------------------------------
                when read_ack_start =>
                    if scl_rising_reg = '1' then
                        state_reg <= read_ack_got_rising;
                        if sda_internal = '1' then -- nack = stop read
                            continue_reg <= '0';
                        else            -- ack = continue read
                            continue_reg       <= '1';
                            read_req_reg       <= '1'; -- request reg byte
                            data_to_master_reg <= data_to_master;
                        end if;
                    end if;

                when read_ack_got_rising =>
                    if scl_falling_reg = '1' then
                        if continue_reg = '1' then
                            if cmd_reg = '0' then
                                state_reg <= write;
                            else
                                state_reg <= read;
                            end if;
                        else
                            state_reg <= read_stop;
                        end if;
                    end if;

                -- Wait for START or STOP to get out of this state
                when read_stop =>
                    null;

                -- Wait for START or STOP to get out of this state
                when others =>
                    assert false
                        report ("I2C: error: ended in an impossible state.")
                        severity error;
                    state_reg <= idle;
            end case;

            --------------------------------------------------------
            -- Reset counter and state on start/stop
            --------------------------------------------------------
            if start_reg = '1' then
                state_reg          <= get_address_and_cmd;
                bits_processed_reg <= 0;
            end if;

            if stop_reg = '1' then
                state_reg          <= idle;
                bits_processed_reg <= 0;
            end if;

            if rst = '1' then
                state_reg <= idle;
            end if;
        end if;
    end process;

    ----------------------------------------------------------
    -- I2C interface
    ----------------------------------------------------------
    
    i_sda_buf : IOBUF
        generic map(
            IOSTANDARD   => "LVCMOS18",
            SLEW         => "SLOW"
        )
        port map(
            O  => sda_in,
            IO => sda_io,
            I  => '0',
            T  => sda_drive_low_b
        );    
    
    ----------------------------------------------------------
    -- User interface
    ----------------------------------------------------------
    -- Master writes
    data_valid       <= data_valid_reg;
    data_from_master <= data_from_master_reg;
    -- Master reads
    read_req         <= read_req_reg;
    write_active_o   <= '1' when (state_reg = write) or (state_reg = answer_ack_start) else '0'; 
    
    gen_debug : if G_DEBUG generate
        
        i_ila : ila_i2c
            port map(
                clk     => clk,
                probe0  => scl_internal,
                probe1  => sda_internal,
                probe2  => start_reg,
                probe3  => stop_reg,
                probe4  => sda_drive_low_b,
                probe5  => std_logic_vector(to_unsigned(state_t'pos(state_reg), 3)),
                probe6  => std_logic_vector(to_unsigned(bits_processed_reg, 4)),
                probe7  => addr_reg,
                probe8  => cmd_reg,
                probe9  => read_req_reg,
                probe10 => data_reg,
                probe11 => data_from_master_reg,
                probe12 => continue_reg,
                probe13 => scl_falling_reg,
                probe14 => scl_rising_reg,
                probe15 => scl_pre_internal
            );
        
    end generate;
    
end architecture arch;
