------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2022-12-20
-- Module Name:    shift_reg_multi
-- Description:    A logic vector shift register with a dynamic tap delay. Tap value of 0 results in a delay of 1 clock (if OUTPUT_REG is set to true, then 2 clocks)
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shift_reg_multi is
    generic(
        TAP_DELAY_WIDTH : integer := 8;
        DATA_WIDTH      : integer := 8;
        OUTPUT_REG      : boolean := false;
        SUPPORT_RESET   : boolean := false
    );
    port(
        clk_i       : in  std_logic;
        reset_i     : in  std_logic := '0'; -- (optional)
        tap_delay_i : in  std_logic_vector(TAP_DELAY_WIDTH - 1 downto 0);
        data_i      : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        data_o      : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
end shift_reg_multi;

architecture shift_reg_multi_arch of shift_reg_multi is

  constant DEPTH    : integer := 2**TAP_DELAY_WIDTH;
  
  type t_sr_arr is array (DEPTH -2 downto 0) of std_logic_vector(DATA_WIDTH - 1 downto 0);
      
  signal sr         : t_sr_arr;
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
            data_o <= sr(to_integer(unsigned(tap_delay_i))) when reset_cnt >= to_integer(unsigned(tap_delay_i)) else (others=>'0');
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
                    data_o <= (others=>'0');
                end if; 
            end if;
        end process;
    end generate;

end shift_reg_multi_arch;
