------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    00:34:00 2018-11-13
-- Module Name:    CONFIG_BLASTER
-- Description:    This module stores frontend configuration (GBTXs, OHs, VFATs), and delivers that configuration to the frontend hardware after each hard-reset  
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.ttc_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;

entity config_blaster is
    generic(
        g_NUM_OF_OHs            : integer := 12;
        g_DEBUG                 : boolean := false -- if this is set to true, some chipscope cores will be inserted
    );
    port (
        reset_i             : in  std_logic;
        
        ttc_clks_i          : in t_ttc_clks;
        ttc_cmds_i          : in t_ttc_cmds;
        
        -- IPbus
        ipb_reset_i         : in  std_logic;
        ipb_clk_i           : in  std_logic;
        ipb_miso_o          : out ipb_rbus;
        ipb_mosi_i          : in  ipb_wbus                
    );
end config_blaster;

architecture Behavioral of config_blaster is

    ----==== Constants ====----

    constant C_NUM_GBTX_REGS_8      : integer := 366; -- number of 8bit registers in the GBTX chip
    constant C_NUM_GBTX_REGS_32     : integer := 92;  -- number of 32bit values we'll store for GBTX configuration
    constant C_GBTX_RAM_SIZE_32     : integer := C_NUM_GBTX_REGS_32 * g_NUM_OF_OHs * 3; -- each OH has 3 GBTXs in GE1/1
    
    constant C_NUM_VFAT_REGS_16     : integer := 147; -- number of 16bit registers in VFAT3 chip, including the currently undocumented reg 0x92
    constant C_NUM_VFAT_REGS_32     : integer := 74;  -- number of 32bit values we'll store for VFAT3 configuration
    constant C_VFAT_RAM_SIZE_32     : integer := C_NUM_VFAT_REGS_32 * g_NUM_OF_OHs * 24; -- each OH has 24 VFAT3s in GE1/1

    constant C_NUM_OH_REGS_32       : integer := 100; -- number of 32bit OH registers that we'll store (note that these are random access regs, so we'll store the address and the value for each register)
    constant C_OH_RAM_SIZE_32       : integer := C_NUM_OH_REGS_32 * g_NUM_OF_OHs * 2; -- for each reg we'll store the address and the value (both 32bits, even though we only need 16bits for the address)

    -- the top two bits of the IPbus address selects the RAM to use: one for GBTX, VFAT, and OH, and plus one for control of this module (which is not really a ram, but ok)
    constant C_CTRL_RAMSEL          : integer := 0;
    constant C_GBT_RAMSEL           : integer := 1;
    constant C_VFAT_RAMSEL          : integer := 2;
    constant C_OH_RAMSEL            : integer := 3;

    ----==== IPbus slave stuff ====----
    
    type t_ipb_state is (IDLE, WAIT_READ);
    
    signal ipb_state                : t_ipb_state := IDLE;
    signal ipb_read_countdown       : unsigned(1 downto 0) := "10"; 
    signal ramsel                   : integer range 0 to 3 := 0;

    ----==== Config RAM signals ====----
    
    -- port A is used by the IPbus slave (write and read), and port B is used by the loader (read-only)
    -- address and din of port A is shared accross all RAMs
    
    -- Common RAM port A signals 
    signal rama_addr                : std_logic_vector(15 downto 0) := (others => '0');
    signal rama_din                 : std_logic_vector(31 downto 0) := (others => '0');
    signal rama_we                  : std_logic_vector(3 downto 0)  := (others => '0');
    signal rama_dout                : t_std32_array(3 downto 0);

    -- GBTX RAM port B signals
    signal ramb_gbt_addr            : std_logic_vector(15 downto 0) := (others => '0');
    signal ramb_gbt_dout            : std_logic_vector(31 downto 0);

    -- VFAT RAM port B signals
    signal ramb_vfat_addr           : std_logic_vector(15 downto 0) := (others => '0');
    signal ramb_vfat_dout           : std_logic_vector(31 downto 0);

    -- OH RAM port B signals
    signal ramb_oh_addr             : std_logic_vector(15 downto 0) := (others => '0');
    signal ramb_oh_dout             : std_logic_vector(31 downto 0);

    ----==== Config Blaster signals ====----
    
    signal ctrl_blaster_enabled      : std_logic := '0'; 

begin

    ----==== Config RAM instantiations ====----    

    i_gbtx_config_ram : xpm_memory_tdpram
        generic map(
            MEMORY_SIZE        => C_GBTX_RAM_SIZE_32 * 32,
            MEMORY_PRIMITIVE   => "block",
            CLOCKING_MODE      => "independent_clock",
            ECC_MODE           => "no_ecc",
            MEMORY_INIT_FILE   => "none",
            MEMORY_INIT_PARAM  => "0",
            USE_MEM_INIT       => 0,
            WAKEUP_TIME        => "disable_sleep",
            AUTO_SLEEP_TIME    => 0,
            MESSAGE_CONTROL    => 0,
            WRITE_DATA_WIDTH_A => 32,
            READ_DATA_WIDTH_A  => 32,
            BYTE_WRITE_WIDTH_A => 32,
            ADDR_WIDTH_A       => 16,
            READ_RESET_VALUE_A => "0",
            READ_LATENCY_A     => 2,
            WRITE_MODE_A       => "no_change",
            WRITE_DATA_WIDTH_B => 32,
            READ_DATA_WIDTH_B  => 32,
            BYTE_WRITE_WIDTH_B => 32,
            ADDR_WIDTH_B       => 16,
            READ_RESET_VALUE_B => "0",
            READ_LATENCY_B     => 2,
            WRITE_MODE_B       => "no_change"
        )
        port map(
            sleep          => '0',
            clka           => ipb_clk_i,
            rsta           => '0',
            ena            => '1',
            regcea         => '1',
            wea            => (others => rama_we(C_GBT_RAMSEL)),
            addra          => rama_addr,
            dina           => rama_din,
            injectsbiterra => '0',
            injectdbiterra => '0',
            douta          => rama_dout(C_GBT_RAMSEL),
            sbiterra       => open,
            dbiterra       => open,
            clkb           => ttc_clks_i.clk_40,
            rstb           => '0',
            enb            => '1',
            regceb         => '1',
            web            => (others => '0'),
            addrb          => ramb_gbt_addr,
            dinb           => (others => '0'),
            injectsbiterrb => '0',
            injectdbiterrb => '0',
            doutb          => ramb_gbt_dout,
            sbiterrb       => open,
            dbiterrb       => open
        );

    i_vfat_config_ram : xpm_memory_tdpram
        generic map(
            MEMORY_SIZE        => C_VFAT_RAM_SIZE_32 * 32,
            MEMORY_PRIMITIVE   => "block",
            CLOCKING_MODE      => "independent_clock",
            ECC_MODE           => "no_ecc",
            MEMORY_INIT_FILE   => "none",
            MEMORY_INIT_PARAM  => "0",
            USE_MEM_INIT       => 0,
            WAKEUP_TIME        => "disable_sleep",
            AUTO_SLEEP_TIME    => 0,
            MESSAGE_CONTROL    => 0,
            WRITE_DATA_WIDTH_A => 32,
            READ_DATA_WIDTH_A  => 32,
            BYTE_WRITE_WIDTH_A => 32,
            ADDR_WIDTH_A       => 16,
            READ_RESET_VALUE_A => "0",
            READ_LATENCY_A     => 2,
            WRITE_MODE_A       => "no_change",
            WRITE_DATA_WIDTH_B => 32,
            READ_DATA_WIDTH_B  => 32,
            BYTE_WRITE_WIDTH_B => 32,
            ADDR_WIDTH_B       => 16,
            READ_RESET_VALUE_B => "0",
            READ_LATENCY_B     => 2,
            WRITE_MODE_B       => "no_change"
        )
        port map(
            sleep          => '0',
            clka           => ipb_clk_i,
            rsta           => '0',
            ena            => '1',
            regcea         => '1',
            wea            => (others => rama_we(C_VFAT_RAMSEL)),
            addra          => rama_addr,
            dina           => rama_din,
            injectsbiterra => '0',
            injectdbiterra => '0',
            douta          => rama_dout(C_VFAT_RAMSEL),
            sbiterra       => open,
            dbiterra       => open,
            clkb           => ttc_clks_i.clk_40,
            rstb           => '0',
            enb            => '1',
            regceb         => '1',
            web            => (others => '0'),
            addrb          => ramb_vfat_addr,
            dinb           => (others => '0'),
            injectsbiterrb => '0',
            injectdbiterrb => '0',
            doutb          => ramb_vfat_dout,
            sbiterrb       => open,
            dbiterrb       => open
        );

    i_oh_config_ram : xpm_memory_tdpram
        generic map(
            MEMORY_SIZE        => C_OH_RAM_SIZE_32 * 32,
            MEMORY_PRIMITIVE   => "block",
            CLOCKING_MODE      => "independent_clock",
            ECC_MODE           => "no_ecc",
            MEMORY_INIT_FILE   => "none",
            MEMORY_INIT_PARAM  => "0",
            USE_MEM_INIT       => 0,
            WAKEUP_TIME        => "disable_sleep",
            AUTO_SLEEP_TIME    => 0,
            MESSAGE_CONTROL    => 0,
            WRITE_DATA_WIDTH_A => 32,
            READ_DATA_WIDTH_A  => 32,
            BYTE_WRITE_WIDTH_A => 32,
            ADDR_WIDTH_A       => 16,
            READ_RESET_VALUE_A => "0",
            READ_LATENCY_A     => 2,
            WRITE_MODE_A       => "no_change",
            WRITE_DATA_WIDTH_B => 32,
            READ_DATA_WIDTH_B  => 32,
            BYTE_WRITE_WIDTH_B => 32,
            ADDR_WIDTH_B       => 16,
            READ_RESET_VALUE_B => "0",
            READ_LATENCY_B     => 2,
            WRITE_MODE_B       => "no_change"
        )
        port map(
            sleep          => '0',
            clka           => ipb_clk_i,
            rsta           => '0',
            ena            => '1',
            regcea         => '1',
            wea            => (others => rama_we(C_OH_RAMSEL)),
            addra          => rama_addr,
            dina           => rama_din,
            injectsbiterra => '0',
            injectdbiterra => '0',
            douta          => rama_dout(C_OH_RAMSEL),
            sbiterra       => open,
            dbiterra       => open,
            clkb           => ttc_clks_i.clk_40,
            rstb           => '0',
            enb            => '1',
            regceb         => '1',
            web            => (others => '0'),
            addrb          => ramb_oh_addr,
            dinb           => (others => '0'),
            injectsbiterrb => '0',
            injectdbiterrb => '0',
            doutb          => ramb_oh_dout,
            sbiterrb       => open,
            dbiterrb       => open
        );

    ----==== IPbus slave ====----    

    process(ipb_clk_i)
    begin    
        if (rising_edge(ipb_clk_i)) then      
            if (reset_i = '1' or ipb_reset_i = '1') then    
                ipb_miso_o <= (ipb_err => '0', ipb_ack => '0', ipb_rdata => (others => '0'));
                rama_we <= (others => '0');
                rama_addr <= ipb_mosi_i.ipb_addr(15 downto 0);
                rama_din <= ipb_mosi_i.ipb_wdata;
                ramsel <= 0;
                ipb_read_countdown <= "10";
            else         

                rama_addr <= ipb_mosi_i.ipb_addr(15 downto 0);
                rama_din <= ipb_mosi_i.ipb_wdata;

                case ipb_state is
                    when IDLE =>
                        
                        ipb_read_countdown <= "10";
                                                                
                        if (ipb_mosi_i.ipb_strobe = '1') then
                            -- top two bits of the IPbus address selects the RAM to use
                            ramsel <= to_integer(unsigned(ipb_mosi_i.ipb_addr(17 downto 16)));
                            
                            -- if it's a write transaction, just do a write and respond immediately and stay in IDLE (this will write the value twice, but who cares)
                            -- if it's a read transaction, then go to WAIT_READ to wait for 2 clocks for the RAM to return the value
                            if (ipb_mosi_i.ipb_write = '1') then
                                rama_we(to_integer(unsigned(ipb_mosi_i.ipb_addr(17 downto 16)))) <= '1';
                                ipb_state <= IDLE;
                                ipb_miso_o <= (ipb_err => '0', ipb_ack => '1', ipb_rdata => (others => '0'));
                            else
                                ipb_state <= WAIT_READ;
                                ipb_miso_o <= (ipb_err => '0', ipb_ack => '0', ipb_rdata => (others => '0'));
                            end if;
                            
                        else            
                            ipb_miso_o <= (ipb_err => '0', ipb_ack => '0', ipb_rdata => (others => '0'));                                    
                            ipb_state <= IDLE;
                            rama_we <= (others => '0');
                            ramsel <= ramsel;
                        end if;
                        
                    -- wait for 2 clocks for the RAM to return the value
                    when WAIT_READ =>
                        
                        if (ipb_mosi_i.ipb_strobe = '0') then
                            ipb_state <= IDLE;
                            ipb_read_countdown <= "10";
                            ipb_miso_o <= (ipb_err => '0', ipb_ack => '0', ipb_rdata => (others => '0'));
                        elsif (ipb_read_countdown = "00") then
                            ipb_state <= IDLE;
                            ipb_read_countdown <= "10";
                            ipb_miso_o <= (ipb_ack => '1', ipb_err => '0', ipb_rdata => rama_dout(ramsel));
                        else
                            ipb_state <= WAIT_READ;
                            ipb_read_countdown <= ipb_read_countdown - 1;
                            ipb_miso_o <= (ipb_err => '0', ipb_ack => '0', ipb_rdata => (others => '0'));
                        end if;
                        
                    when others =>
                        
                        ipb_miso_o <= (ipb_err => '0', ipb_ack => '0', ipb_rdata => (others => '0'));                                    
                        ipb_state <= IDLE;
                        rama_we <= (others => '0');
                        ramsel <= ramsel;
                        
                end case;                      
            end if;        
        end if;        
    end process;

    -- control register handling
    process(ipb_clk_i)
    begin    
        if (rising_edge(ipb_clk_i)) then
            if (reset_i = '1') then
                ctrl_blaster_enabled <= '0';
            else
                -- read handling
                case rama_addr is
                    when x"0000" =>
                        rama_dout(C_CTRL_RAMSEL) <= x"000" & "000" & ctrl_blaster_enabled;
                    when x"0100" =>
                        rama_dout(C_CTRL_RAMSEL) <= std_logic_vector(to_unsigned(C_GBTX_RAM_SIZE_32, 32));
                    when x"0101" =>
                        rama_dout(C_CTRL_RAMSEL) <= std_logic_vector(to_unsigned(C_VFAT_RAM_SIZE_32, 32));
                    when x"0102" =>
                        rama_dout(C_CTRL_RAMSEL) <= std_logic_vector(to_unsigned(C_OH_RAM_SIZE_32, 32));
                    when others =>
                        rama_dout(C_CTRL_RAMSEL) <= x"12345678"; -- placeholder
                end case;
                
                -- write handling
                if (rama_we(C_CTRL_RAMSEL) = '1') and (ramsel = C_CTRL_RAMSEL) then
                    case rama_addr is
                        when x"0000" =>
                            ctrl_blaster_enabled <= rama_din(0);
                        when others =>
                            ctrl_blaster_enabled <= ctrl_blaster_enabled;
                    end case;
                else
                    ctrl_blaster_enabled <= ctrl_blaster_enabled;
                end if;
                
            end if;
        end if;      
    end process;

end Behavioral;
