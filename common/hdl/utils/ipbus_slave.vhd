----------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date: 04/24/2016 04:59:35 AM
-- Module Name: ipbus_slave
-- Project Name:
-- Description: A generic ipbus client for reading and writing 32bit arrays on an independent user clock (domain crossing is taken care of and data outputs are set synchronously with the user clock).
--              In addition to the read and write data arrays, it also outputs read and write pulses which can be used for various resets e.g. to clear the data on write or read 
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

library xpm;
use xpm.vcomponents.all;

use work.ipbus.all;
use work.common_pkg.all;

entity ipbus_slave is
    generic(
        g_NUM_REGS             : integer := 32;     -- number of 32bit registers in this slave (use them wisely, don't allocate 100 times more than you need). If there are big gaps in the register addresses, please use individual address mapping.
        g_ADDR_HIGH_BIT        : integer := 5;      -- MSB of the IPbus address that will be mapped to registers
        g_ADDR_LOW_BIT         : integer := 0;      -- LSB of the IPbus address that will be mapped to registers
        g_USE_INDIVIDUAL_ADDRS : boolean := false;  -- when true, we will map the registers to the individual addresses provided in individual_addrs_arr_i(g_ADDR_HIGH_BIT downto g_ADDR_LOW_BIT)
        g_IPB_CLK_PERIOD_NS    : integer;           -- ipb_clk_i period, this is used to set the timeout, which is 40us
        g_DEBUG                : boolean := false
    );
    port(
        ipb_reset_i            : in  std_logic;                              -- IPbus reset (will reset the register values to the provided defaults)
        ipb_clk_i              : in  std_logic;                              -- IPbus clock
        ipb_mosi_i             : in  ipb_wbus;                               -- master to slave IPbus interface
        ipb_miso_o             : out ipb_rbus;                               -- slave to master IPbus interface

        usr_clk_i              : in  std_logic;                              -- user clock used to read and write regs_write_arr_o and regs_read_arr_i 
        regs_read_arr_i        : in  t_std32_array(g_NUM_REGS - 1 downto 0); -- read registers
        regs_write_arr_o       : out t_std32_array(g_NUM_REGS - 1 downto 0); -- write registers 
        read_pulse_arr_o       : out std_logic_vector(g_NUM_REGS - 1 downto 0);  -- asserted when reading the given register
        write_pulse_arr_o      : out std_logic_vector(g_NUM_REGS - 1 downto 0);  -- asserted when writing the given register
        regs_read_ready_arr_i  : in  std_logic_vector(g_NUM_REGS - 1 downto 0); -- read operations will wait for this bit to be 1 before latching in the data and completing the read operation
        regs_write_done_arr_i  : in  std_logic_vector(g_NUM_REGS - 1 downto 0); -- write operations will wait for this bit to be 1 before finishing the transaction

        regs_defaults_arr_i    : in  t_std32_array(g_NUM_REGS - 1 downto 0);    -- register default values - set when ipb_reset_i = '1'
        writable_regs_i        : in  std_logic_vector(g_NUM_REGS - 1 downto 0); -- bitmask indicating which registers are writable and need defaults to be loaded (this helps to save resources)
        individual_addrs_arr_i : in  t_std32_array(g_NUM_REGS - 1 downto 0)     -- individual register addresses - only used when g_USE_INDIVIDUAL_ADDRS = "TRUE"
    );
end ipbus_slave;

architecture Behavioral of ipbus_slave is
    
    constant REG_SEL_WIDTH : integer := log2ceil(g_NUM_REGS - 1);
    
    type t_ipb_state is (IDLE, RSPD, SYNC_WRITE, SYNC_READ, RST);
    
    signal ipb_reset_usrclk         : std_logic := '0';
    signal ipb_state                : t_ipb_state := IDLE;
    signal ipb_addr_valid           : std_logic := '0';
    signal ipb_miso                 : ipb_rbus;
    signal ipb_mosi                 : ipb_wbus;

    -- addr
    signal ipb_reg_sel_ipbclk       : integer range 0 to g_NUM_REGS - 1 := 0;
    signal write_reg_sel_usrclk     : integer range 0 to g_NUM_REGS - 1 := 0;
    signal read_reg_sel_usrclk      : integer range 0 to g_NUM_REGS - 1 := 0;
    
    -- write data and CDC signals
    signal reg_write_data_ipbclk    : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_write_data_usrclk    : std_logic_vector(31 downto 0) := (others => '0');    
    signal cdc_write_data_ipbclk    : std_logic_vector(31 + REG_SEL_WIDTH downto 0) := (others => '0');
    signal cdc_write_data_usrclk    : std_logic_vector(31 + REG_SEL_WIDTH downto 0) := (others => '0');
    signal reg_write_strb_ipbclk    : std_logic := '0';
    signal reg_write_strb_usrclk    : std_logic := '0';
    signal reg_write_ack_ipbclk     : std_logic := '0';
    signal reg_write_ack_usrclk     : std_logic := '0';
    
    -- read data and CDC signals
    signal reg_read_data_ipbclk     : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_read_data_usrclk     : std_logic_vector(31 downto 0) := (others => '0');
    signal cdc_read_addr_ipbclk     : std_logic_vector(REG_SEL_WIDTH - 1 downto 0) := (others => '0');
    signal cdc_read_addr_usrclk     : std_logic_vector(REG_SEL_WIDTH - 1 downto 0) := (others => '0');    
    signal reg_read_strb_ipbclk     : std_logic := '0';
    signal reg_read_strb_usrclk     : std_logic := '0';
    signal reg_read_ack_ipbclk      : std_logic := '0';
    signal reg_read_ack_usrclk      : std_logic := '0';
    signal reg_read_data_strb_ipbclk: std_logic := '0';
    signal reg_read_data_strb_usrclk: std_logic := '0';
    signal reg_read_data_ack_ipbclk : std_logic := '0';
    signal reg_read_data_ack_usrclk : std_logic := '0';
    
    -- user side logic signals
    signal regs_write_pulse_done    : std_logic := '0'; 
    signal regs_read_pulse_done     : std_logic := '0'; 
    
    -- Timeout
    constant ipb_timeout      : unsigned(15 downto 0) := to_unsigned(40_000 / g_IPB_CLK_PERIOD_NS, 16); -- 40us
    signal ipb_timer          : unsigned(15 downto 0) := (others => '0');
        
begin
    
    --========================================--
    -- IPbus FSM
    --========================================--
    
    p_ipb_fsm:
    process(ipb_clk_i)
    begin
        if (rising_edge(ipb_clk_i)) then
            if (ipb_reset_i = '1') then
                ipb_miso <= (ipb_ack => '0', ipb_err => '0', ipb_rdata => (others => '0'));
                ipb_state <= IDLE;
                ipb_reg_sel_ipbclk <= 0;
                ipb_addr_valid <= '0';
                reg_write_strb_ipbclk <= '0';
                reg_read_strb_ipbclk <= '0';
                ipb_timer <= (others => '0');
                ipb_mosi <= (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0');
            else
                ipb_mosi <= ipb_mosi_i;
                ipb_miso_o <= ipb_miso;
                
                case ipb_state is
                    when IDLE =>
                        reg_write_strb_ipbclk <= '0';
                        reg_read_strb_ipbclk <= '0';
                        ipb_addr_valid <= '0';
                        if (g_USE_INDIVIDUAL_ADDRS) then
                            -- individual address matching (NOTE: maybe could be doen more efficiently..)
                            for i in 0 to g_NUM_REGS - 1 loop
                                if (ipb_mosi.ipb_addr(g_ADDR_HIGH_BIT downto g_ADDR_LOW_BIT) = individual_addrs_arr_i(i)(g_ADDR_HIGH_BIT downto g_ADDR_LOW_BIT)) then
                                    ipb_reg_sel_ipbclk <= i;
                                    ipb_addr_valid <= '1';
                                end if;
                            end loop;
                        else
                            -- sequential address matching
                            ipb_reg_sel_ipbclk <= to_integer(unsigned(ipb_mosi.ipb_addr(g_ADDR_HIGH_BIT downto g_ADDR_LOW_BIT)));
                            if (to_integer(unsigned(ipb_mosi.ipb_addr(g_ADDR_HIGH_BIT downto g_ADDR_LOW_BIT))) < g_NUM_REGS) then
                                ipb_addr_valid <= '1';
                            end if;
                        end if;
                        
                        if (ipb_mosi.ipb_strobe = '1') then
                            ipb_state <= RSPD;
                        end if;
                        
                        ipb_miso <= (ipb_ack => '0', ipb_err => '0', ipb_rdata => (others => '0'));
                        ipb_timer <= (others => '0');
                        
                    when RSPD =>
                        if (ipb_addr_valid = '1' and ipb_mosi.ipb_write = '1') then
                            --write
                            reg_write_data_ipbclk <= ipb_mosi.ipb_wdata;
                            reg_write_strb_ipbclk <= '1';
                            ipb_state <= SYNC_WRITE;
                        elsif (ipb_addr_valid = '1') then
                            --read
                            reg_read_strb_ipbclk <= '1';
                            ipb_state <= SYNC_READ;
                        else
                            --error
                            ipb_miso <= (ipb_ack => '1', ipb_err => '1', ipb_rdata => (others => '0'));
                            ipb_state <= RST;
                        end if;
                        ipb_timer <= (others => '0');
                    when SYNC_WRITE =>
                        if (reg_write_ack_ipbclk = '1') then
                            ipb_miso <= (ipb_ack => '1', ipb_err => '0', ipb_rdata => (others => '0'));
                            reg_write_strb_ipbclk <= '0';
                            ipb_state <= RST;
                        -- Timeout (useful if user clock is not available)
                        elsif (ipb_timer > ipb_timeout) then
                            ipb_miso <= (ipb_ack => '1', ipb_err => '1', ipb_rdata => (others => '0'));
                            reg_write_strb_ipbclk <= '0';
                            ipb_state <= RST;
                            ipb_timer <= (others => '0');
                        -- still waiting for IPbus
                        else
                            ipb_timer <= ipb_timer + 1;
                            reg_write_strb_ipbclk <= '1';
                        end if;                            
                    when SYNC_READ =>
                        -- latch in the data here
                        if (reg_read_data_strb_ipbclk = '1') then
                            ipb_miso.ipb_rdata <= reg_read_data_ipbclk;
                        end if;
                        
                        -- read transaction is done
                        if (reg_read_ack_ipbclk = '1') then
                            ipb_miso.ipb_ack <= '1';
                            ipb_miso.ipb_err <= '0';
                            reg_read_strb_ipbclk <= '0';
                            ipb_state <= RST;
                        -- Timeout (useful if user clock is not available)
                        elsif (ipb_timer > ipb_timeout) then
                            ipb_miso <= (ipb_ack => '1', ipb_err => '1', ipb_rdata => x"baadbaad");
                            reg_read_strb_ipbclk <= '0';
                            ipb_state <= RST;
                            ipb_timer <= (others => '0');
                        -- still waiting for IPbus
                        else
                            ipb_timer <= ipb_timer + 1;
                            reg_read_strb_ipbclk <= '1';
                        end if;                            
                    when RST =>
                        ipb_miso.ipb_ack <= '0';
                        ipb_miso.ipb_err <= '0';
                        -- wait for the strobe to go down before returning to idle
                        if (ipb_mosi.ipb_strobe = '0' and reg_write_ack_ipbclk = '0' and reg_read_ack_ipbclk = '0') or (ipb_timer > ipb_timeout) then
                            ipb_state <= IDLE;
                        else
                            ipb_timer <= ipb_timer + 1;
                        end if;
                    when others =>
                        ipb_miso  <= (ipb_ack => '0', ipb_err => '0', ipb_rdata => (others => '0'));
                        ipb_state   <= IDLE;
                        ipb_reg_sel_ipbclk <= 0;
                        reg_write_strb_ipbclk <= '0';
                        reg_read_strb_ipbclk <= '0';
                        ipb_timer <= (others => '0');
                end case;
            end if;
        end if;
    end process p_ipb_fsm;    

    i_ipb_reset_sync_usr_clk: 
    entity work.synch
        generic map(
            N_STAGES => 8
        )
        port map(
            async_i => ipb_reset_i,
            clk_i   => usr_clk_i,
            sync_o  => ipb_reset_usrclk
        );

    --========================================--
    -- CDC: ipbclk => usrclk for write logic
    --      addr and write data
    --========================================--

    i_cdc_write_addr_data : xpm_cdc_handshake
        generic map(
            DEST_EXT_HSK   => 1,
            DEST_SYNC_FF   => 4,
            SRC_SYNC_FF    => 4,
            WIDTH          => 32 + REG_SEL_WIDTH
        )
        port map(
            src_clk  => ipb_clk_i,
            src_in   => cdc_write_data_ipbclk,
            src_send => reg_write_strb_ipbclk,
            src_rcv  => reg_write_ack_ipbclk,
            dest_clk => usr_clk_i,
            dest_req => reg_write_strb_usrclk,
            dest_ack => reg_write_ack_usrclk,
            dest_out => cdc_write_data_usrclk
        );
    
    cdc_write_data_ipbclk(31 downto 0) <= reg_write_data_ipbclk;
    cdc_write_data_ipbclk(31 + REG_SEL_WIDTH downto 32) <= std_logic_vector(to_unsigned(ipb_reg_sel_ipbclk, REG_SEL_WIDTH));
    reg_write_data_usrclk <= cdc_write_data_usrclk(31 downto 0);
    write_reg_sel_usrclk <= to_integer(unsigned(cdc_write_data_usrclk(31 + REG_SEL_WIDTH downto 32))); 
                
    --========================================--
    -- Write logic 
    --========================================--
    
    p_usr_clk_write_sync:
    process (usr_clk_i) is
    begin
        if rising_edge(usr_clk_i) then
            if (ipb_reset_usrclk = '1') then
                defaults:
                for i in 0 to g_NUM_REGS - 1 loop
                    if (writable_regs_i(i) = '1') then
                        regs_write_arr_o(i) <= regs_defaults_arr_i(i);
                    end if;
                end loop;
                
                regs_write_pulse_done <= '0';
                write_pulse_arr_o <= (others => '0');
            else
                if (reg_write_strb_usrclk = '1' and reg_write_ack_usrclk = '0') then
                    regs_write_arr_o(write_reg_sel_usrclk) <= reg_write_data_usrclk;
                    
                    if (regs_write_done_arr_i(write_reg_sel_usrclk) = '1') then
                        reg_write_ack_usrclk <= '1';
                    end if;
                    
                    if (regs_write_pulse_done = '0') then
                        write_pulse_arr_o(write_reg_sel_usrclk) <= '1';
                        regs_write_pulse_done <= '1';
                    else
                        write_pulse_arr_o <= (others => '0');
                    end if;
                else
                    reg_write_ack_usrclk <= reg_write_strb_usrclk;
                    write_pulse_arr_o <= (others => '0');
                    regs_write_pulse_done <= '0';
                end if;
            end if;
        end if;
    end process p_usr_clk_write_sync;
    
    --========================================--
    -- CDC: for read logic 
    --      addr: ipbclk => usrclk
    --      read data: usrclk => ipbclk
    --========================================--

    i_cdc_read_addr : xpm_cdc_handshake
        generic map(
            DEST_EXT_HSK   => 1,
            DEST_SYNC_FF   => 4,
            SRC_SYNC_FF    => 4,
            WIDTH          => REG_SEL_WIDTH
        )
        port map(
            src_clk  => ipb_clk_i,
            src_in   => cdc_read_addr_ipbclk,
            src_send => reg_read_strb_ipbclk,
            src_rcv  => reg_read_ack_ipbclk,
            dest_clk => usr_clk_i,
            dest_req => reg_read_strb_usrclk,
            dest_ack => reg_read_ack_usrclk,
            dest_out => cdc_read_addr_usrclk
        );
    
    cdc_read_addr_ipbclk <= std_logic_vector(to_unsigned(ipb_reg_sel_ipbclk, REG_SEL_WIDTH));
    read_reg_sel_usrclk <= to_integer(unsigned(cdc_read_addr_usrclk));
    
    i_cdc_read_data : xpm_cdc_handshake
        generic map(
            DEST_EXT_HSK   => 0,
            DEST_SYNC_FF   => 4,
            SRC_SYNC_FF    => 4,
            WIDTH          => 32
        )
        port map(
            src_clk  => usr_clk_i,
            src_in   => reg_read_data_usrclk,
            src_send => reg_read_data_strb_usrclk,
            src_rcv  => reg_read_data_ack_usrclk,
            dest_clk => ipb_clk_i,
            dest_req => reg_read_data_strb_ipbclk,
            dest_ack => '1', -- not used since we are using internal handshake
            dest_out => reg_read_data_ipbclk
        );
    
    
    --========================================--
    -- Read logic 
    --========================================--
    
    p_usr_clk_read_sync:
    process (usr_clk_i) is
    begin
        if rising_edge(usr_clk_i) then            
            if (reg_read_strb_usrclk = '1' and reg_read_ack_usrclk = '0') then
                
                if (regs_read_ready_arr_i(read_reg_sel_usrclk) = '1') then
                    reg_read_data_usrclk <= regs_read_arr_i(read_reg_sel_usrclk);
                    reg_read_data_strb_usrclk <= '1';
                end if;
                
                if (reg_read_data_ack_usrclk = '1') then
                    reg_read_ack_usrclk <= '1';
                    reg_read_data_strb_usrclk <= '0';
                end if;
                
                if (regs_read_pulse_done = '0') then
                    read_pulse_arr_o(read_reg_sel_usrclk) <= '1';
                    regs_read_pulse_done <= '1';
                else
                    read_pulse_arr_o <= (others => '0');
                end if;
            else
                reg_read_ack_usrclk <= reg_read_strb_usrclk;
                reg_read_data_strb_usrclk <= '0';
                read_pulse_arr_o <= (others => '0');
                regs_read_pulse_done <= '0';
            end if;
        end if;
    end process p_usr_clk_read_sync;
    
    --========================================--
    -- Debug
    --========================================--
    
    gen_debug : if g_DEBUG generate --or g_NUM_REGS = 8 generate --hack to select only the PROMless module
        component ila_ipbus_slave
            port(
                clk     : in std_logic;
                probe0  : in std_logic_vector(11 downto 0);
                probe1  : in std_logic_vector(31 downto 0);
                probe2  : in std_logic;
                probe3  : in std_logic;
                probe4  : in std_logic;
                probe5  : in std_logic_vector(11 downto 0);
                probe6  : in std_logic_vector(31 downto 0);
                probe7  : in std_logic;
                probe8  : in std_logic;
                probe9  : in std_logic;
                probe10 : in std_logic;
                probe11 : in std_logic;
                probe12 : in std_logic
            );
        end component;        
    begin
        
        i_ila_ipbus_slave_usr : ila_ipbus_slave
            port map(
                clk     => usr_clk_i,
                probe0  => std_logic_vector(to_unsigned(write_reg_sel_usrclk, 12)),
                probe1  => reg_write_data_usrclk,
                probe2  => reg_write_strb_usrclk,
                probe3  => reg_write_ack_usrclk,
                probe4  => regs_write_pulse_done,
                probe5  => std_logic_vector(to_unsigned(read_reg_sel_usrclk, 12)),
                probe6  => reg_read_data_usrclk,
                probe7  => reg_read_strb_usrclk,
                probe8  => reg_read_ack_usrclk,
                probe9  => reg_read_data_strb_usrclk,
                probe10 => reg_read_data_ack_usrclk,
                probe11 => regs_read_pulse_done,
                probe12 => ipb_reset_usrclk
            );
        
    end generate;

end Behavioral;
