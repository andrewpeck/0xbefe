------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-11-20
-- Module Name:    shift_reg
-- Description:    A single bit shift register with a dynamic tap delay. Tap value of 0 results in a delay of 1 clock (if OUTPUT_REG is set to true, then 2 clocks)
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library xpm;
use xpm.vcomponents.all;

entity shift_reg is
    generic(
        DEPTH           : integer := 256;
        TAP_DELAY_WIDTH : integer := 8;
        OUTPUT_REG      : boolean := false;
        SUPPORT_RESET   : boolean := false
    );
    port(
        clk_i       : in  std_logic;
        reset_i     : in  std_logic := '0'; -- (optional)
        tap_delay_i : in  std_logic_vector(TAP_DELAY_WIDTH - 1 downto 0);
        data_i      : in  std_logic;
        data_o      : out std_logic
    );
end shift_reg;

architecture shift_reg_arch of shift_reg is

  signal sr         : std_logic_vector(DEPTH - 1 downto 0) := (others => '0');
  signal reset_cnt  : integer range 0 to DEPTH - 1 := 0;
  
begin

    -- shift reg
    process(clk_i)
    begin
        if rising_edge(clk_i) then
          sr <= sr(sr'high - 1 downto sr'low) & data_i;
        end if;
    end process;

    -- reset counter
    g_reset_cnt : if SUPPORT_RESET generate
        process(clk_i)
        begin
            if rising_edge(clk_i) then
                if reset_i = '1' then
                    reset_cnt <= 0;
                else
                    if reset_cnt = DEPTH - 1 then
                        reset_cnt <= DEPTH - 1;
                    else
                        reset_cnt <= reset_cnt + 1;
                    end if;
                end if;
            end if;
        end process;
    end generate;

    -- unregistered output
    g_out_no_reg : if not OUTPUT_REG generate
        g_reset_not_supported : if not SUPPORT_RESET generate
            data_o <= sr(to_integer(unsigned(tap_delay_i)));
        end generate;
        
        g_reset_supported : if SUPPORT_RESET generate
            data_o <= sr(to_integer(unsigned(tap_delay_i))) when reset_cnt >= to_integer(unsigned(tap_delay_i)) else '0';
        end generate;
    end generate;

    -- registered output
    g_out_reg : if OUTPUT_REG generate
        process(clk_i)
        begin
            if rising_edge(clk_i) then
                if (not SUPPORT_RESET) or (reset_cnt >= to_integer(unsigned(tap_delay_i))) then
                    data_o <= sr(to_integer(unsigned(tap_delay_i))); 
                else
                    data_o <= '0';
                end if; 
            end if;
        end process;
    end generate;

end shift_reg_arch;
