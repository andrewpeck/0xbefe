------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-06-04
-- Module Name:    LED_CONTROLLER
-- Description:    Controls the LEDs based on various inputs (by default when idle, it's runing them up and down)
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

entity led_controller is
    port (
        reset_i             : in  std_logic;
        
        clk100_i            : in  std_logic;
        idle_i              : in  std_logic;
        
        sc_clk_i            : in  std_logic;
        sc_active_i         : in  std_logic; -- slow control activity indicator
        
        override_en_i       : in  std_logic;
        override_data_i     : in  std_logic_vector(3 downto 0);
        
        leds_o              : out std_logic_vector(3 downto 0)
    );
end led_controller;

architecture led_controller_arch of led_controller is

    signal reset_cntdown    : integer := 0;
    signal reset            : std_logic;

    signal reset_leds       : std_logic_vector(3 downto 0);
    signal idle_leds        : std_logic_vector(3 downto 0);
    signal leds             : std_logic_vector(3 downto 0) := x"6";

begin

    leds_o <= override_data_i when override_en_i = '1' else reset_leds when reset = '1' else idle_leds when idle_i = '1' else leds;

    --================================--
    -- Reset
    --================================--

    process(clk100_i)
    begin
        if rising_edge(clk100_i) then
            if reset_i = '1' then
                reset_cntdown <= 100_000_000;
            end if;
            
            if reset_cntdown /= 0 then
                reset_cntdown <= reset_cntdown - 1;
                reset <= '1';
            else
                reset_cntdown <= 0;
                reset <= '0';
            end if;
        end if;
    end process;

    process(clk100_i)
        variable cnt    : integer := 20_000_000;
    begin
        if rising_edge(clk100_i) then
            if reset = '1' then
                if cnt = 0 then
                    cnt := 20_000_000;
                    reset_leds <= not reset_leds;
                else
                    cnt := cnt - 1;
                end if;
            else
                cnt := 20_000_000;
                reset_leds <= (others => '1');
            end if;
        end if;
    end process;
    
    --================================--
    -- Idle blinker
    --================================--
   
    process(clk100_i)
        variable cnt    : integer := 40_000_000;
        variable updown : std_logic := '0';
    begin
        if rising_edge(clk100_i) then
            
            if cnt = 0 then
                updown := '1';
            elsif cnt = 40_000_000 then
                updown := '0';
            else
                updown := updown;
            end if;
            
            if updown = '0' then
                cnt := cnt - 1;
            else
                cnt := cnt + 1;
            end if;
            
            for i in 0 to 3 loop
                if (cnt > i * 10_000_000) and (cnt < (i+1) * 10_000_000) then
                    idle_leds(i) <= '0';                  
                else
                    idle_leds(i) <= 'Z';
                end if; 
            end loop;
            
        end if;
    end process;

end led_controller_arch;
