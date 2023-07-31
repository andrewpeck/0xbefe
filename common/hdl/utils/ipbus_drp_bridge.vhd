----------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date: 2023-02-27
-- Module Name: ipbus_drp_bridge
-- Project Name:
-- Description: A bridge between IPBus and multiple DRP interfaces. Note: there is no CDC, so ipbus and drp clocks must be the same.
--              IPbus address bits [g_NUM_DRP_ADDR_BITS - 1 : 0] are used as DRP address, and ipbus addr bits [g_NUM_DRP_SEL_BITS + g_NUM_DRP_ADDR_BITS - 1 : g_NUM_DRP_ADDR_BITS] select the DRP interface.
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

library xpm;
use xpm.vcomponents.all;

use work.ipbus.all;
use work.common_pkg.all;
use work.mgt_pkg.all;

entity ipbus_drp_bridge is
    generic(
        g_NUM_DRP_ADDR_BITS     : integer; -- number of DRP address bits (ipbus addr bits [g_NUM_DRP_ADDR_BITS - 1 : 0] are used for this)
        g_NUM_DRP_SEL_BITS      : integer; -- number of DRP interface selection bits (ipbus addr bits [g_NUM_DRP_SEL_BITS + g_NUM_DRP_ADDR_BITS - 1 : g_NUM_DRP_ADDR_BITS] are used for this)
        g_NUM_DRP_BUSES         : integer; -- number of DRP interfaces
        g_TOP_ADDR_DRP_RESET    : boolean  -- if this is set to true, then a write to the highest DRP address will drive DRPRST high for one clock cycle
    );
    port(
        ipb_reset_i            : in  std_logic;                              -- IPbus reset (will reset the register values to the provided defaults)
        ipb_clk_i              : in  std_logic;                              -- IPbus clock
        ipb_mosi_i             : in  ipb_wbus;                               -- master to slave IPbus interface
        ipb_miso_o             : out ipb_rbus;                               -- slave to master IPbus interface
        
        drp_mosi_arr_o         : out t_drp_mosi_arr(g_NUM_DRP_BUSES - 1 downto 0);
        drp_miso_arr_i         : in  t_drp_miso_arr(g_NUM_DRP_BUSES - 1 downto 0)
    );
end ipbus_drp_bridge;

architecture Behavioral of ipbus_drp_bridge is
    
    constant DRP_TOP_ADDR   : std_logic_vector(g_NUM_DRP_ADDR_BITS - 1 downto 0) := (others => '1');
    
    signal drp_reg_addr     : std_logic_vector(g_NUM_DRP_ADDR_BITS - 1 downto 0) := (others => '0');
    signal drp_sel_addr     : std_logic_vector(g_NUM_DRP_SEL_BITS - 1 downto 0) := (others => '0');
    signal wdata            : std_logic_vector(15 downto 0);
    signal strobe_oneshot   : std_logic := '0';
    signal write_oneshot    : std_logic := '0';
    
begin

    -- register the IPB MOSI, and add oneshots to the strobe and write signals as required by DRP    
    process(ipb_clk_i)
    begin
        if rising_edge(ipb_clk_i) then
            if ipb_reset_i = '1' then
                strobe_oneshot <= '0';
                write_oneshot <= '0';
            else
                drp_reg_addr <= ipb_mosi_i.ipb_addr(g_NUM_DRP_ADDR_BITS - 1 downto 0);
                drp_sel_addr <= ipb_mosi_i.ipb_addr(g_NUM_DRP_ADDR_BITS + g_NUM_DRP_SEL_BITS - 1 downto g_NUM_DRP_ADDR_BITS);
                wdata <= ipb_mosi_i.ipb_wdata(15 downto 0);
                -- drp requires that the strobe and write signals be high for only one cycle
                if strobe_oneshot = '0' and ipb_mosi_i.ipb_strobe = '1' then
                    strobe_oneshot <= '1';
                else
                    strobe_oneshot <= '0';
                end if;
                if write_oneshot = '0' and ipb_mosi_i.ipb_write = '1' then
                    write_oneshot <= '1';
                else
                    write_oneshot <= '0';
                end if;
            end if;
        end if;
    end process;

    -- MUX MOSI
    process(ipb_clk_i)
    begin
        if rising_edge(ipb_clk_i) then
            for i in 0 to g_NUM_DRP_BUSES - 1 loop
                
                -- address and data buses can all just be replicated, we only MUX the strobe and write signals
                drp_mosi_arr_o(i).addr(g_NUM_DRP_ADDR_BITS - 1 downto 0) <= drp_reg_addr;
                if g_NUM_DRP_ADDR_BITS < 16 then
                    drp_mosi_arr_o(i).addr(15 downto g_NUM_DRP_ADDR_BITS) <= (others => '0');
                end if;
                drp_mosi_arr_o(i).di <= wdata;
            
                -- MUX
                if to_integer(unsigned(drp_sel_addr)) = i then
                    if g_TOP_ADDR_DRP_RESET and drp_reg_addr = DRP_TOP_ADDR then
                        drp_mosi_arr_o(i).rst <= write_oneshot;
                        drp_mosi_arr_o(i).en <= '0';
                        drp_mosi_arr_o(i).we <= '0';
                    else
                        drp_mosi_arr_o(i).en <= strobe_oneshot;
                        drp_mosi_arr_o(i).we <= write_oneshot;
                        drp_mosi_arr_o(i).rst <= '0';
                    end if;
                else
                    drp_mosi_arr_o(i).en <= '0';
                    drp_mosi_arr_o(i).we <= '0';
                    drp_mosi_arr_o(i).rst <= '0';
                end if;
            end loop;
        end if;
    end process;

    -- MUX MISO
    process(ipb_clk_i)
    begin
        if rising_edge(ipb_clk_i) then
            if to_integer(unsigned(drp_sel_addr)) < g_NUM_DRP_BUSES then
                ipb_miso_o.ipb_ack <= drp_miso_arr_i(to_integer(unsigned(drp_sel_addr))).rdy;
                ipb_miso_o.ipb_rdata(15 downto 0) <= drp_miso_arr_i(to_integer(unsigned(drp_sel_addr))).do; 
            else
                ipb_miso_o.ipb_ack <= '0';
                ipb_miso_o.ipb_rdata(15 downto 0) <= (others => '0'); 
            end if;            
        end if;
    end process;

    ipb_miso_o.ipb_rdata(31 downto 16) <= (others => '0');
    ipb_miso_o.ipb_err <= '0';
    
end Behavioral;
