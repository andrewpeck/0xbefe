library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity prbs7_8b_generator is
    generic(
        INIT_c                  : in std_logic_vector(7 downto 0)
    );
    port (
        reset_i          : in  std_logic;
        clk_i            : in  std_logic;
        clken_i          : in  std_logic;
                
        err_pattern_i    : in  std_logic_vector(7 downto 0);
        rep_delay_i      : in  std_logic_vector(23 downto 0);

        prbs_word_o      : out std_logic_vector(7 downto 0);
        rdy_o            : out std_logic
    );
end prbs7_8b_generator;

architecture rtl of prbs7_8b_generator is
    signal feedback_reg         : std_logic_vector(7 downto 0) := INIT_c;
    signal prbs_word_s          : std_logic_vector(7 downto 0) := INIT_c;
    signal err_pattern_s        : std_logic_vector(7 downto 0);
    signal err_cnter_s          : unsigned(24 downto 0);
    signal inject_error_s       : std_logic;
    signal onceinject_done_s    : std_logic;

begin

    -- PRBS7 equation: x^7 + x^6 + 1
    -- LSB first

    prbs7_proc: process(reset_i, clk_i)
    begin

        if reset_i = '1' then
            feedback_reg <= INIT_c;
            prbs_word_s  <= INIT_c;
            rdy_o        <= '0';
            err_cnter_s   <= (others => '0');
            err_pattern_s <= (others => '0');

        elsif rising_edge(clk_i) then

            if clken_i = '1' then

                prbs_word_s  <= feedback_reg;
                rdy_o        <= '1';

                feedback_reg(0) <= feedback_reg(6) xor feedback_reg(5) xor feedback_reg(5) xor feedback_reg(4);
                feedback_reg(1) <= feedback_reg(0) xor feedback_reg(6) xor feedback_reg(5);
                feedback_reg(2) <= feedback_reg(1) xor feedback_reg(0);
                feedback_reg(3) <= feedback_reg(2) xor feedback_reg(1);
                feedback_reg(4) <= feedback_reg(3) xor feedback_reg(2);
                feedback_reg(5) <= feedback_reg(4) xor feedback_reg(3);
                feedback_reg(6) <= feedback_reg(5) xor feedback_reg(4);
                feedback_reg(7) <= feedback_reg(6) xor feedback_reg(5);

                err_pattern_s <= x"00";
                
                if err_pattern_i /= x"00" then
                    if std_logic_vector(err_cnter_s) = rep_delay_i then
                        if rep_delay_i /= x"000000" or onceinject_done_s = '0' then
                            err_pattern_s     <= err_pattern_i;
                            onceinject_done_s <= '1';
                        end if;
                                            
                        err_cnter_s       <= (others => '0');                    
                        
                    else
                        err_cnter_s <= err_cnter_s + 1;
                    end if;
                else
                    err_cnter_s <= (others => '0');
                    onceinject_done_s <= '0';
                end if;
            end if;

        end if;

    end process;

    prbs_word_o   <= prbs_word_s xor err_pattern_s;

end rtl;