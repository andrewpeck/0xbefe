----------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date: 2023-02-27
-- Module Name: DRP MUX
-- Project Name:
-- Description: DRP bus multiplexer
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

entity drp_mux is
    generic(
        g_NUM_DRP_SEL_BITS      : integer; -- number of DRP interface selection bits
        g_NUM_DRP_BUSES         : integer  -- number of DRP interfaces
    );
    port(
        drp_clk_i               : in  std_logic;
        drp_bus_select_i        : in  std_logic_vector(g_NUM_DRP_SEL_BITS - 1 downto 0);

        drp_mosi_i              : in  t_drp_mosi;
        drp_miso_o              : out t_drp_miso;
        
        drp_mosi_arr_o          : out t_drp_mosi_arr(g_NUM_DRP_BUSES - 1 downto 0);
        drp_miso_arr_i          : in  t_drp_miso_arr(g_NUM_DRP_BUSES - 1 downto 0)
    );
end drp_mux;

architecture Behavioral of drp_mux is

    signal bus_select       : std_logic_vector(g_NUM_DRP_SEL_BITS - 1 downto 0);
    signal mosi             : t_drp_mosi;
    signal miso             : t_drp_miso;
    signal mosi_arr         : t_drp_mosi_arr(g_NUM_DRP_BUSES - 1 downto 0) := (others => DRP_MOSI_NULL);
    signal miso_arr         : t_drp_miso_arr(g_NUM_DRP_BUSES - 1 downto 0) := (others => DRP_MISO_NULL);
        
begin

    -- register the main bus
    process(drp_clk_i)
    begin
        if rising_edge(drp_clk_i) then
            bus_select <= drp_bus_select_i;
            mosi <= drp_mosi_i;
            drp_miso_o <= miso;
        end if;
    end process;

    -- MUX
    process(drp_clk_i)
    begin
        if rising_edge(drp_clk_i) then

            -- MOSI: only mux en, we, rst, and just fan out the addr and data
            for i in 0 to g_NUM_DRP_BUSES - 1 loop
                mosi_arr(i).addr <= mosi.addr;
                mosi_arr(i).di <= mosi.di;
                if i = to_integer(unsigned(bus_select)) then
                    mosi_arr(i).en  <= mosi.en;
                    mosi_arr(i).we  <= mosi.we;
                    mosi_arr(i).rst <= mosi.rst;
                else
                    mosi_arr(i).en <= '0';
                    mosi_arr(i).we <= '0';
                    mosi_arr(i).rst <= '0';
                end if;
            end loop;

            -- MISO MUX
            if to_integer(unsigned(bus_select)) < g_NUM_DRP_BUSES then
                miso <= miso_arr(to_integer(unsigned(bus_select)));
            else
                miso <= DRP_MISO_NULL;
            end if;
                        
        end if;
    end process;
    
    -- register the muxed buses
    process(drp_clk_i)
    begin
        if rising_edge(drp_clk_i) then
            drp_mosi_arr_o <= mosi_arr;
            miso_arr <= drp_miso_arr_i;
        end if;
    end process;
    
end Behavioral;
