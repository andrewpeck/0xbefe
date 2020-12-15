------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-07-16
-- Module Name:    GEM_LOADER
-- Description:    This module implements the so called gemloader module which stores the frontend firmware, and streams it to the gem logic on request.
--                 This version uses the FPGA BRAM for storing the bitfile  
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.ttc_pkg.all;
use work.common_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;

entity gem_loader is
    generic(
        g_MAX_SIZE_BYTES    : integer; -- NOTE: must be a multiple of 32KB (kilobytes) if g_MEMORY_PRIMITIVE is set to "ultra" (using UltraRAM)
        g_MEMORY_PRIMITIVE  : string := "ultra"
    );
    port (
        reset_i             : in  std_logic;
        
        to_gem_loader_i     : in  t_to_gem_loader;
        from_gem_loader_o   : out t_from_gem_loader;        
        
        -- IPbus
        ipb_reset_i         : in  std_logic;
        ipb_clk_i           : in  std_logic;
        ipb_miso_o          : out ipb_rbus;
        ipb_mosi_i          : in  ipb_wbus                
    );
end gem_loader;

architecture gem_loader_arch of gem_loader is

    ----==== IPbus slave stuff ====----
    
    type t_ipb_state is (IDLE, WAIT_READ);
    
    signal ipb_state                : t_ipb_state := IDLE;
    signal ipb_read_countdown       : unsigned(1 downto 0) := "10"; 

    ----==== RAM signals ====----
    
    -- port A is used by the IPbus slave (write and read), and port B is used by the loader (read-only)
    
    -- Common RAM port A signals 
    signal rama_addr                : std_logic_vector(21 downto 0) := (others => '0');
    signal rama_din                 : std_logic_vector(31 downto 0) := (others => '0');
    signal rama_we                  : std_logic  := '0';
    signal rama_dout                : std_logic_vector(31 downto 0);

    -- port B signals
    signal ramb_addr                : std_logic_vector(23 downto 0) := (others => '0');
    signal ramb_dout                : std_logic_vector(7 downto 0);

begin

    ----==== RAM instantiation ====----    

    i_gbtx_config_ram : xpm_memory_tdpram
        generic map(
            MEMORY_SIZE        => g_MAX_SIZE_BYTES,
            MEMORY_PRIMITIVE   => g_MEMORY_PRIMITIVE,
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
            ADDR_WIDTH_A       => 22,
            READ_RESET_VALUE_A => "0",
            READ_LATENCY_A     => 2,
            WRITE_MODE_A       => "no_change",
            WRITE_DATA_WIDTH_B => 8,
            READ_DATA_WIDTH_B  => 8,
            BYTE_WRITE_WIDTH_B => 8,
            ADDR_WIDTH_B       => 24,
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
            wea            => (others => rama_we),
            addra          => rama_addr,
            dina           => rama_din,
            injectsbiterra => '0',
            injectdbiterra => '0',
            douta          => rama_dout,
            sbiterra       => open,
            dbiterra       => open,
            clkb           => to_gem_loader_i.clk,
            rstb           => '0',
            enb            => '1',
            regceb         => '1',
            web            => (others => '0'),
            addrb          => ramb_addr,
            dinb           => (others => '0'),
            injectsbiterrb => '0',
            injectdbiterrb => '0',
            doutb          => ramb_dout,
            sbiterrb       => open,
            dbiterrb       => open
        );
        
    ----==== IPbus slave ====----    

    process(ipb_clk_i)
    begin    
        if (rising_edge(ipb_clk_i)) then      
            if (reset_i = '1' or ipb_reset_i = '1') then    
                ipb_miso_o <= (ipb_err => '0', ipb_ack => '0', ipb_rdata => (others => '0'));
                rama_we <= '0';
                rama_addr <= ipb_mosi_i.ipb_addr(21 downto 0);
                rama_din <= ipb_mosi_i.ipb_wdata;
                ipb_read_countdown <= "10";
            else         

                rama_addr <= ipb_mosi_i.ipb_addr(21 downto 0);
                rama_din <= ipb_mosi_i.ipb_wdata;

                case ipb_state is
                    when IDLE =>
                        
                        ipb_read_countdown <= "10";
                                                                
                        if (ipb_mosi_i.ipb_strobe = '1') then
                            -- if it's a write transaction, just do a write and respond immediately and stay in IDLE (this will write the value twice, but who cares)
                            -- if it's a read transaction, then go to WAIT_READ to wait for 2 clocks for the RAM to return the value
                            if (ipb_mosi_i.ipb_write = '1') then
                                rama_we <= '1';
                                ipb_state <= IDLE;
                                ipb_miso_o <= (ipb_err => '0', ipb_ack => '1', ipb_rdata => (others => '0'));
                            else
                                ipb_state <= WAIT_READ;
                                ipb_miso_o <= (ipb_err => '0', ipb_ack => '0', ipb_rdata => (others => '0'));
                            end if;
                            
                        else            
                            ipb_miso_o <= (ipb_err => '0', ipb_ack => '0', ipb_rdata => (others => '0'));                                    
                            ipb_state <= IDLE;
                            rama_we <= '0';
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
                            ipb_miso_o <= (ipb_ack => '1', ipb_err => '0', ipb_rdata => rama_dout);
                        else
                            ipb_state <= WAIT_READ;
                            ipb_read_countdown <= ipb_read_countdown - 1;
                            ipb_miso_o <= (ipb_err => '0', ipb_ack => '0', ipb_rdata => (others => '0'));
                        end if;
                        
                    when others =>
                        
                        ipb_miso_o <= (ipb_err => '0', ipb_ack => '0', ipb_rdata => (others => '0'));                                    
                        ipb_state <= IDLE;
                        rama_we <= '0';
                        
                end case;                      
            end if;        
        end if;        
    end process;

end gem_loader_arch;
