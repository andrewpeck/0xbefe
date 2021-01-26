library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity synchronizer is
  generic (
    N_STAGES : integer := 1
    );
  port (
    async_i : in  std_logic;
    clk_i   : in  std_logic;
    sync_o  : out std_logic
    );
end synchronizer;

architecture synchronizer_arch of synchronizer is

  signal s_resync : std_logic_vector(N_STAGES downto 0) := (others => '0');

  attribute ASYNC_REG                 : string;
  attribute ASYNC_REG of s_resync     : signal is "TRUE";
  attribute SHREG_EXTRACT             : string;
  attribute SHREG_EXTRACT of s_resync : signal is "NO";

begin

  s_resync(0) <= async_i;

  -- https://forums.xilinx.com/t5/Timing-Analysis/Setting-ASYNC-REG-in-VHDL-for-Two-Flop-Synchronizer/td-p/700175/page/2

  sync_gen : if (N_STAGES > 0) generate

    gen_ff : for i in 0 to N_STAGES-1 generate
    begin
      process (clk_i)
      begin
        if (rising_edge(clk_i)) then
          s_resync(i+1) <= s_resync(i);
        end if;
      end process;
    end generate gen_ff;

  end generate sync_gen;

  sync_o <= s_resync(N_STAGES);

end synchronizer_arch;
