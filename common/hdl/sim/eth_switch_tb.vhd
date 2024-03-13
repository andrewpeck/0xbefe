library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     std.textio.all;

use work.common_pkg.all;
use work.ipbus.all;

entity  TEST_BENCH_ETH_SWITCH is
end     TEST_BENCH_ETH_SWITCH;

architecture MODEL of TEST_BENCH_ETH_SWITCH is

    constant CLOCK_PERIOD   : time    := 10 ns;
    
    constant NUM_PORTS  : integer := 4;
    constant PORT_ROUTES : t_int_array_2d(0 to NUM_PORTS - 1)(0 to NUM_PORTS - 1) :=
        (
            (2, 3, NUM_PORTS, NUM_PORTS),
            (2, 3, NUM_PORTS, NUM_PORTS),
            (0, 1, NUM_PORTS, NUM_PORTS),
            (0, 1, NUM_PORTS, NUM_PORTS)
        );    
                
    constant ETH_IDLE   : std_logic_vector(15 downto 0) := x"50BC";
    
    constant ETH_PACKET : t_std16_array(0 to 46) := (
            x"55FB", x"5555", x"5555", x"D555", -- preamble and SOF
            x"0000", x"1200", x"5634", -- dest mac
            x"0000", x"1200", x"5734", -- source mac
            x"1234", -- ether type
            x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", -- payload
            x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", -- payload
            x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", -- payload
            x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", -- payload
            x"ffff", x"ffff", -- CRC (just a placeholder for now)
            x"F7FD", x"C5BC" -- EOF
        );

    signal reset            : std_logic;
    signal clk              : std_logic;

    signal mgt_rx_arr       : t_mgt_16b_rx_data_arr(NUM_PORTS - 1 downto 0) := (others => MGT_16B_RX_DATA_NULL);
    signal mgt_tx_arr       : t_mgt_16b_tx_data_arr(NUM_PORTS - 1 downto 0) := (others => MGT_16B_TX_DATA_NULL);
    signal mgt_rx_64b_arr    : t_mgt_64b_rx_data_arr(NUM_PORTS - 1 downto 0) := (others => MGT_64B_RX_DATA_NULL);
    signal mgt_tx_64b_arr    : t_mgt_64b_tx_data_arr(NUM_PORTS - 1 downto 0) := (others => MGT_64B_TX_DATA_NULL);
    signal mgt_status_arr   : t_mgt_status_arr(NUM_PORTS - 1 downto 0);
    
begin

    -------------------------------------------------------------------------------
    -- Wiring
    -------------------------------------------------------------------------------

    mgt_rx_64b_arr <= mgt_rx_16b_to_64b_arr(mgt_rx_arr);
    mgt_tx_arr <= mgt_tx_64b_to_16b_arr(mgt_tx_64b_arr);

    -------------------------------------------------------------------------------
    -- DUT 
    -------------------------------------------------------------------------------

    i_eth_switch : entity work.eth_switch
        generic map(
            g_NUM_PORTS         => NUM_PORTS,
            g_PORT_LINKS        => (0, 0, 0, 0),
            g_ETH_PORT_ROUTES   => PORT_ROUTES,
            g_IPB_CLK_PERIOD_NS => 10
        )
        port map(
            reset_i       => reset,
            gbe_clk_i     => clk,
            mgt_rx_data_i => mgt_rx_64b_arr,
            mgt_tx_data_o => mgt_tx_64b_arr,
            mgt_status_i  => mgt_status_arr,
            ipb_reset_i   => '0',
            ipb_clk_i     => '0',
            ipb_mosi_i    => IPB_M2S_NULL,
            ipb_miso_o    => open
        );
    
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
        
        procedure send_idles(cnt: in integer) is
        begin
            for i in 1 to cnt loop
                for link in 0 to NUM_PORTS - 1 loop
                    mgt_rx_arr(link).rxdata <= ETH_IDLE;
                    mgt_rx_arr(link).rxcharisk <= "01";
                end loop;
                wait until (clk'event and clk = '1'); 
            end loop;
        end send_idles;
        
        procedure send_packet(port1, port2: in integer; dest_mac : in std_logic_vector(47 downto 0)) is
        begin
            
            for i in 0 to ETH_PACKET'length - 1 loop
                for link in 0 to NUM_PORTS - 1 loop
                    if link = port1 or link = port2 then
                        if i > 3 and i < 7 then -- insert our dest mac here
                            mgt_rx_arr(link).rxdata <= dest_mac(16 * (i - 4) + 7 downto 16 * (i - 4)) & dest_mac(16 * (i - 4) + 15 downto 16 * (i - 4) + 8);
                            mgt_rx_arr(link).rxcharisk <= "00";
                        else -- take the rest of the packet data from the constant
                            mgt_rx_arr(link).rxdata <= ETH_PACKET(i);
                            if i = 0 then
                                mgt_rx_arr(link).rxcharisk <= "01";
                            elsif i = ETH_PACKET'length - 1 then
                                mgt_rx_arr(link).rxcharisk <= "01";
                            elsif i = ETH_PACKET'length - 2 then
                                mgt_rx_arr(link).rxcharisk <= "11";
                            else
                                mgt_rx_arr(link).rxcharisk <= "00";
                            end if;
                        end if;
                    else
                        mgt_rx_arr(link).rxdata <= ETH_IDLE;
                        mgt_rx_arr(link).rxcharisk <= "01";                        
                    end if;
                end loop;
                
                wait until (clk'event and clk = '1');
            end loop;
            
        end send_packet;      
        
    begin
        assert false report "Run Start..." severity NOTE;
        
        reset <= '1';
        send_idles(10);
        reset <= '0';
        send_idles(10);
        send_packet(0, 0, x"000000123458");
        send_idles(30);
        send_packet(0, 0, x"ffffffffffff");
        send_idles(30);
        send_packet(3, 3, x"000000123456");
        send_idles(30);
        send_packet(2, 2, x"ffffffffffff");
        send_idles(30);
        send_packet(2, 2, x"123456789abc"); -- test unmatched MAC
        send_idles(100);

--        assert false report "Max number of ones: " & integer'image(max_ones_length) severity NOTE;
--        assert false report "Max number of zeros: " & integer'image(max_zeros_length) severity NOTE;

        reset <= '1';
        
        assert false report "DONE" severity failure;
        wait;
    end process;
end MODEL;