library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;
use work.registers.all;
use work.cluster_pkg.all;

entity rate_counter32_multi is
    --- Rate Counter for multiple inputs. Counter Width is fixed to 32 ---
    generic(
        g_CLK_FREQUENCY   : std_logic_vector(31 downto 0) := C_TTC_CLK_FREQUENCY_SLV;
        g_NUM_COUNTERS    : integer := 24
    );
    port(
        clk_i   : in  std_logic;
        reset_i : in  std_logic;
        en_i    : in  std_logic_vector(g_NUM_COUNTERS - 1 downto 0);
        rate_o  : out t_std32_array(g_NUM_COUNTERS - 1 downto 0)
    );
end entity rate_counter32_multi;

architecture RTL of rate_counter32_multi is

    constant max_rate_count : unsigned(31 downto 0) := (others => '1');
    signal rate_timer       : unsigned(31 downto 0);
    signal rate_count_arr   : t_std32_array(g_NUM_COUNTERS - 1 downto 0);

begin
    i_vfat_trigger_rate : process(clk_i) is
    begin
        if rising_edge(clk_i) then
            for i in 0 to g_NUM_COUNTERS-1  loop
                if reset_i = '1' then
                    rate_count_arr(i) <= (others => '0');
                    rate_timer <= (others => '0');
                else
                    if rate_timer < unsigned(g_CLK_FREQUENCY) then
                        rate_timer <= rate_timer + 1;

                        if en_i(i) = '1' and unsigned(rate_count_arr(i)) < max_rate_count then
                            rate_count_arr(i) <= std_logic_vector(unsigned(rate_count_arr(i)) + 1);
                        end if;
                    else
                        rate_timer <= (others => '0');
                        rate_count_arr(i) <= (others => '0');
                        rate_o(i) <= std_logic_vector(rate_count_arr(i));
                    end if;
                end if;
            end loop;
        end if;
    end process;
end architecture RTL;
