library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     std.textio.all;

entity  TEST_BENCH_PRBS is
end     TEST_BENCH_PRBS;

architecture MODEL of TEST_BENCH_PRBS is

    constant CLOCK_PERIOD   : time    := 10 ns;

    signal reset            : std_logic;
    signal clk              : std_logic;
                        
    signal prbs_gen_data    : std_logic;
    signal prbs_gen_data_d1 : std_logic;
    
    signal max_ones_length  : integer;
    signal max_zeros_length : integer;
    
begin

    -------------------------------------------------------------------------------
    -- DUT 
    -------------------------------------------------------------------------------
    i_prbs : entity work.PRBS_ANY
        generic map(
            CHK_MODE    => false,
            INV_PATTERN => false,
            POLY_LENGHT => 11,
            POLY_TAP    => 9,
            NBITS       => 1
        )
        port map(
            RST         => reset,
            CLK         => clk,
            DATA_IN     => (others => '0'),
            EN          => '1',
            DATA_OUT(0) => prbs_gen_data
        );
    
    process(clk)
    begin
        if rising_edge(clk) then
            prbs_gen_data_d1 <= prbs_gen_data;
        end if;
    end process;
    
    -- count ones
    process(clk)
        variable length : integer;
    begin
        if rising_edge(clk) then
            if prbs_gen_data = '1' then
                length := length + 1;
            else
                if length > max_ones_length then
                    max_ones_length <= length;
                end if;
                length := 0;
            end if;
        end if;
    end process;

    -- count zeros
    process(clk)
        variable length : integer;
    begin
        if rising_edge(clk) then
            if prbs_gen_data = '0' then
                length := length + 1;
            else
                if length > max_zeros_length then
                    max_zeros_length <= length;
                end if;
                length := 0;
            end if;
        end if;
    end process;
    
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    process begin
        clk <= '1';
        wait for CLOCK_PERIOD / 2;
        clk <= '0';
        wait for CLOCK_PERIOD / 2;
    end process;
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    process
        ---------------------------------------------------------------------------
        --
        ---------------------------------------------------------------------------
        procedure wait_clk(cnt: in integer) is
        begin
            for i in 1 to cnt loop 
                wait until (clk'event and clk = '1'); 
            end loop;
        end wait_clk;
--        ---------------------------------------------------------------------------
--        --
--        ---------------------------------------------------------------------------
--        procedure test(prbs_data : std_logic_vector(NBITS - 1 downto 0); cycles_to_test: integer) is
--            
--            variable ones_length        : integer := 0;
--            variable max_ones_length    : integer := 0;
--            variable zeros_length       : integer := 0;
--            variable max_zeros_length   : integer := 0;
--            
--            variable 
--            
--        begin
--
--            wait_loop: for i in 1 to cycles_to_test loop
--                wait until (clk'event and clk = '1');
--
--                    
--                    
----                   exit wait_loop;
--                   
--            end loop;
--
--        end procedure;
    begin
        ---------------------------------------------------------------------------
        --
        ---------------------------------------------------------------------------
        assert false report "Run Start..." severity NOTE;
        
        reset <= '1';
        wait_clk(10);
        reset <= '0';
        wait_clk(2_000_000);

        assert false report "Max number of ones: " & integer'image(max_ones_length) severity NOTE;
        assert false report "Max number of zeros: " & integer'image(max_zeros_length) severity NOTE;

        reset <= '1';
        
        assert false report "DONE" severity failure;
        wait;
    end process;
end MODEL;