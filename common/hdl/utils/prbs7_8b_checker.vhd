library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

entity prbs7_8b_checker is
    port (
        reset_i          : in  std_logic;
        clk_i            : in  std_logic;
        clken_i          : in  std_logic;
        prbs_word_i      : in  std_logic_vector(7 downto 0);
        err_o            : out std_logic_vector(7 downto 0);
        err_flag_o       : out std_logic;
        rdy_o            : out std_logic
    );
end prbs7_8b_checker;

architecture rtl of prbs7_8b_checker is
    signal feedback_reg         : std_logic_vector(7 downto 0);
    signal err_s                : std_logic_vector(7 downto 0);
    
    type checker_state_T is (waitForLock, Locked);
    signal status : checker_state_T;
                                
    constant STATS_CONFIG_c     : integer := 10;
    signal cnt_stats            : integer range 0 to STATS_CONFIG_c;

begin

    checker_fsm_proc: process(reset_i, clk_i)
    begin
        if reset_i = '1' then
            status <= waitForLock;
            cnt_stats <= 0;
            
        elsif rising_edge(clk_i) then
            case status is
                when waitForLock =>                                
                    if cnt_stats= STATS_CONFIG_c then
                        status <= Locked;
                    else
                        if err_s = x"00" and feedback_reg /= x"00" then
                            cnt_stats <= cnt_stats + 1;
                        else
                            cnt_stats <= 0;
                        end if;
                    end if;
                
                when Locked => null;
            end case;
        end if;
    end process;
    
    -- PRBS7 equation: x^7 + x^6 + 1
    -- LSB first
    prbs7_proc: process(reset_i, clk_i)
        variable cnter : integer range 0 to 1;
    begin

        if reset_i = '1' then
            feedback_reg <= (others => '0');
            err_s        <= x"00";

        elsif rising_edge(clk_i) then

            if clken_i = '1' then
                
                err_s(0) <= prbs_word_i(0) xor (feedback_reg(6) xor feedback_reg(5) xor feedback_reg(5) xor feedback_reg(4));
                err_s(1) <= prbs_word_i(1) xor (feedback_reg(0) xor feedback_reg(6) xor feedback_reg(5));
                err_s(2) <= prbs_word_i(2) xor (feedback_reg(1) xor feedback_reg(0));
                err_s(3) <= prbs_word_i(3) xor (feedback_reg(2) xor feedback_reg(1));
                err_s(4) <= prbs_word_i(4) xor (feedback_reg(3) xor feedback_reg(2));
                err_s(5) <= prbs_word_i(5) xor (feedback_reg(4) xor feedback_reg(3));
                err_s(6) <= prbs_word_i(6) xor (feedback_reg(5) xor feedback_reg(4));
                err_s(7) <= prbs_word_i(7) xor (feedback_reg(6) xor feedback_reg(5));
                
                if status /= Locked then                    
                    feedback_reg <= prbs_word_i;
                else
                    feedback_reg(0) <= (feedback_reg(6) xor feedback_reg(5) xor feedback_reg(5) xor feedback_reg(4));
                    feedback_reg(1) <= (feedback_reg(0) xor feedback_reg(6) xor feedback_reg(5));
                    feedback_reg(2) <= (feedback_reg(1) xor feedback_reg(0));
                    feedback_reg(3) <= (feedback_reg(2) xor feedback_reg(1));
                    feedback_reg(4) <= (feedback_reg(3) xor feedback_reg(2));
                    feedback_reg(5) <= (feedback_reg(4) xor feedback_reg(3));
                    feedback_reg(6) <= (feedback_reg(5) xor feedback_reg(4));
                    feedback_reg(7) <= (feedback_reg(6) xor feedback_reg(5));
                end if;

                
            end if;
            
        end if;

    end process;
    
    err_o <= err_s;
    err_flag_o <= or_reduce(err_s);
    rdy_o <= '1' when status = Locked else '0';
    
end rtl;