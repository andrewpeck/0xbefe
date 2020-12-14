------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-06-30
-- Module Name:    i2c_ipbus_bridge 
-- Description:    This module is acting as an I2C slave and translates the read and write requests to an IPBus protocol effectively 
--                 acting as IPbus master which can drive multiple IPbus slaves. 
--                 It's expected that the master does this:
--                    * WRITE TRANSACTION: writes 8 bytes, the first 4 are address (LSB first), and the last 4 are data (LSB first)
--                    * READ TRANSACTION: writes 4 bytes of address (LSB first), and reads 4 bytes of data (LSB first), any repeated reads would just read the same data
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ipbus.all;
use work.ipb_addr_decode.all;

entity i2c_ipbus_bridge is
    generic (
        g_I2C_ADDR              : std_logic_vector(6 downto 0);
        g_NUM_IPB_SLAVES        : integer := 64;
        g_STABLE_CLK_PERIOD_NS  : integer := 10        
    );
    port (
        reset_i         : in  std_logic;
        stable_clk_i    : in  std_logic;
        i2c_scl_i       : in  std_logic;
        i2c_sda_io      : inout std_logic;

        ipb_reset_o     : out std_logic; -- IPbus reset (active high)
        ipb_clk_o       : out std_logic; -- IPbus clock        
        ipb_miso_i      : in  ipb_rbus_array(C_NUM_IPB_SLAVES-1 downto 0); -- slave to master IPbus
        ipb_mosi_o      : out ipb_wbus_array(C_NUM_IPB_SLAVES-1 downto 0); -- master to slave IPbus  
    
        read_active_o   : out std_logic;
        write_active_o  : out std_logic
    );
end i2c_ipbus_bridge;

architecture i2c_ipbus_bridge_arch of i2c_ipbus_bridge is
    
    type t_state is (IDLE, SET_ADDRESS, SET_WRITE_DATA, IPB_WRITE, IPB_WAIT_WRITE_ACK, IPB_READ, IPB_WAIT_READ_ACK);
    
    signal state            : t_state := IDLE;
    
    signal address          : std_logic_vector(31 downto 0) := (others => '0');
    signal address_byte_idx : integer range 0 to 3 := 0;
    
    signal write_buf        : std_logic_vector(31 downto 0) := (others => '0');
    signal write_byte_idx   : integer range 0 to 3 := 0;
    
    signal read_buf         : std_logic_vector(31 downto 0) := (others => '0');
    signal read_byte_idx    : integer range 0 to 3 := 0;
    signal read_buf_written : std_logic := '0';
    signal read_err         : std_logic := '0';
    
    signal i2c_read_req     : std_logic;
    signal i2c_miso_data    : std_logic_vector(7 downto 0);
    signal i2c_mosi_valid   : std_logic;
    signal i2c_mosi_data    : std_logic_vector(7 downto 0);
    signal i2c_write_active : std_logic;

    constant I2C_TIMEOUT    : integer := 120000 / g_STABLE_CLK_PERIOD_NS; -- for 100kHz i2c use 120us (sending 1 byte is about 90us) -- for 400kHz use 30us (sending 1 byte takes about 20us)    
    constant IPB_TIMEOUT    : integer := 15000 / g_STABLE_CLK_PERIOD_NS; -- 15us, which is enough to timeout while the master is sending the read request (in case of 400kHz i2c)

    signal i2c_timer        : integer range 0 to I2C_TIMEOUT := 0;
    signal ipb_timer        : integer range 0 to IPB_TIMEOUT := 0;
        
    signal ipb_clk          : std_logic;
    signal ipb_mosi         : ipb_wbus_array(C_NUM_IPB_SLAVES-1 downto 0);-- := (others => (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0'));
    signal ipb_slv_select   : integer range 0 to C_NUM_IPB_SLAVES-1 := 0; -- ipbus slave select

    attribute MARK_DEBUG : string;
    attribute MARK_DEBUG of state           : signal is "TRUE";
    attribute MARK_DEBUG of address           : signal is "TRUE";
    attribute MARK_DEBUG of address_byte_idx           : signal is "TRUE";
    attribute MARK_DEBUG of write_buf           : signal is "TRUE";
    attribute MARK_DEBUG of write_byte_idx           : signal is "TRUE";
    attribute MARK_DEBUG of read_buf           : signal is "TRUE";
    attribute MARK_DEBUG of read_byte_idx           : signal is "TRUE";
    attribute MARK_DEBUG of read_buf_written           : signal is "TRUE";
    attribute MARK_DEBUG of ipb_slv_select           : signal is "TRUE";

begin

    --================================--
    -- Port wiring
    --================================--

    ipb_reset_o <= reset_i;
    ipb_clk_o <= stable_clk_i;
    ipb_mosi_o <= ipb_mosi;

    --================================--
    -- Main FSM
    --================================--

    process(stable_clk_i)
    begin
        if rising_edge(stable_clk_i) then
            if reset_i = '1' then
                state <= IDLE;
                read_buf <= (others => '0');
                address <= (others => '0');
                write_buf <= (others => '0');
                address_byte_idx <= 0;
                write_byte_idx <= 0;
                i2c_timer <= 0;
                ipb_timer <= 0;
                read_err <= '0';
                read_buf_written <= '0';
                read_active_o <= '0';
                write_active_o <= '0';
            else
                
                if i2c_timer /= I2C_TIMEOUT then
                    i2c_timer <= i2c_timer + 1;
                end if;
                
                if ipb_timer /= IPB_TIMEOUT then
                    ipb_timer <= ipb_timer + 1;
                end if;
                
                read_buf_written <= '0';
                read_active_o <= '0';
                write_active_o <= '0';
                
                case state is
                    
                    when IDLE =>
                        if i2c_mosi_valid = '1' then
                            state <= SET_ADDRESS;
                            address(7 downto 0) <= i2c_mosi_data;
                            address_byte_idx <= 1;
                            read_err <= '0';
                        end if;
                        i2c_timer <= 0;
                        ipb_timer <= 0;

                    when SET_ADDRESS =>
                        if i2c_mosi_valid = '1' then
                            address(address_byte_idx * 8 + 7 downto address_byte_idx * 8) <= i2c_mosi_data;
                            address_byte_idx <= address_byte_idx + 1;
                            i2c_timer <= 0;
                            
                            if address_byte_idx = 3 then
                                state <= SET_WRITE_DATA;
                                write_byte_idx <= 0;
                                i2c_timer <= 0;
                            end if;
                        end if;
                        
                        if i2c_timer = I2C_TIMEOUT then
                            state <= IDLE;
                        end if;

                    when SET_WRITE_DATA =>
                        if i2c_mosi_valid = '1' then
                            write_buf(write_byte_idx * 8 + 7 downto write_byte_idx * 8) <= i2c_mosi_data;
                            write_byte_idx <= write_byte_idx + 1;
                            i2c_timer <= 0;
                            
                            if write_byte_idx = 3 then
                                state <= IPB_WRITE;
                                ipb_timer <= 0;
                            end if;
                        end if;

                        ipb_slv_select <= ipb_addr_sel(address); --ipb_addr_sel(address(31 downto 2));
                        
                        -- if there's no more write data coming in, this is a read, so go and read from IPB to be ready for the upcoming read request from i2c
                        if (i2c_write_active = '0') or (i2c_timer = I2C_TIMEOUT) then
                            state <= IPB_READ;
                            ipb_timer <= 0;
                        end if;

                    when IPB_WRITE =>
                        ipb_mosi(ipb_slv_select).ipb_addr <= address; --"00" & address(31 downto 2);
                        ipb_mosi(ipb_slv_select).ipb_wdata <= write_buf;
                        ipb_mosi(ipb_slv_select).ipb_strobe <= '1';
                        ipb_mosi(ipb_slv_select).ipb_write <= '1';
                        write_active_o <= '1';
                        state <= IPB_WAIT_WRITE_ACK;
                    
                    when IPB_WAIT_WRITE_ACK =>
                        if ipb_miso_i(ipb_slv_select).ipb_ack = '1' then
                            ipb_mosi(ipb_slv_select) <= (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0'); 
                            state <= IDLE;
                            --TODO: handle error somehow
                        end if;
                        
                        if ipb_timer = IPB_TIMEOUT then
                            state <= IDLE;
                        end if;

                    when IPB_READ =>
                        ipb_mosi(ipb_slv_select).ipb_addr <= address; --"00" & address(31 downto 2);
                        ipb_mosi(ipb_slv_select).ipb_strobe <= '1';
                        ipb_mosi(ipb_slv_select).ipb_write <= '0';
                        read_active_o <= '1';
                        state <= IPB_WAIT_READ_ACK;

                    when IPB_WAIT_READ_ACK =>
                        if ipb_miso_i(ipb_slv_select).ipb_ack = '1' then
                            ipb_mosi(ipb_slv_select) <= (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0');
                            read_buf <= ipb_miso_i(ipb_slv_select).ipb_rdata;
                            read_err <= ipb_miso_i(ipb_slv_select).ipb_err;
                            read_buf_written <= '1';
                            state <= IDLE;
                        end if;
                        
                        if ipb_timer = IPB_TIMEOUT then
                            state <= IDLE;
                            read_err <= '1';
                        end if;
                    
                    when others =>
                        state <= IDLE;
                end case;
                
            end if;
        end if;
    end process;

    --================================--
    -- I2C read
    --================================--

    process(stable_clk_i)
    begin
        if rising_edge(stable_clk_i) then
            if reset_i = '1' then
                read_byte_idx <= 0;
            else
                if read_buf_written = '1' then
                    read_byte_idx <= 1;
                    i2c_miso_data <= read_buf(7 downto 0);
                elsif i2c_read_req = '1' then
                    read_byte_idx <= read_byte_idx + 1;
                    i2c_miso_data <= read_buf(read_byte_idx * 8 + 7 downto read_byte_idx * 8);
                end if;
            end if;
        end if;
    end process;
    
    --================================--
    -- I2C slave
    --================================--
        
    i_i2c_slave : entity work.i2c_slave
        generic map(
            SLAVE_ADDR => g_I2C_ADDR,
            SCL_FILTER_LENGTH => 400/g_STABLE_CLK_PERIOD_NS,
            G_DEBUG => true
        )
        port map(
            scl              => i2c_scl_i,
            sda_io           => i2c_sda_io,
            clk              => stable_clk_i,
            rst              => reset_i,
            read_req         => i2c_read_req,
            data_to_master   => i2c_miso_data,
            data_valid       => i2c_mosi_valid,
            data_from_master => i2c_mosi_data,
            write_active_o   => i2c_write_active
        );    
    
end i2c_ipbus_bridge_arch;
