library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.pat_pkg.all;
use work.patterns.all;

entity segment_selector is
  generic(
    PARTITION_WIDTH : natural := 192;
    NUM_SORTERS     : natural := 1
    );
  port(

    clock : in std_logic;

    pat_candidates : in candidate_list_t (PARTITION_WIDTH-1 downto 0);

    sump : out std_logic

    );
end segment_selector;

architecture behavioral of segment_selector is
  constant SORTER_SIZE : natural := PARTITION_WIDTH / NUM_SORTERS;
begin

  assert (PARTITION_WIDTH mod NUM_SORTERS = 0)
    report "for now can't handle a number width mod sorters != 0"
    severity error;

  --type    T_SLM                 is array(natural range <>, natural range <>) of std_logic;
  sorter_gen : for I in 0 to NUM_SORTERS generate
  begin
    sortnet_OddEvenMergeSort_1 : entity work.sortnet_OddEvenMergeSort
      generic map (
        INPUTS               => SORTER_SIZE,  --  input count
        KEY_BITS             => KEY_BITS,     -- the first KEY_BITS of In_Data are used as a sorting critera (key)
        DATA_BITS            => DATA_BITS,    -- inclusive KEY_BITS
        META_BITS            => 0,            -- additional bits, not sorted but delayed as long as In_Data
        PIPELINE_STAGE_AFTER => 2,            -- add a pipline stage after n sorting stages
        ADD_INPUT_REGISTERS  => false,        --
        ADD_OUTPUT_REGISTERS => true)         --
      port map (
        clock     => clock,
        reset     => '0',
        inverse   => '0',                     -- sl
        in_valid  => in_valid,                -- sl
        in_iskey  => in_iskey,                -- sl
        in_data   => in_data,                 -- slm (inputs x databits)
        in_meta   => in_meta,                 -- slv (meta bits)
        out_valid => out_valid,               -- sl
        out_iskey => out_iskey,               -- sl
        out_data  => out_data,                -- slm (inputs x databits)
        out_meta  => out_meta                 -- slv (meta bits)
        );
  end generate;


  -- need sorting on the pattern outputs
  -- steal from the OH, priority 192
  --
  --
  -- Sort 1 of N --> LUT
  -- Sort NLUT --> N Outputs
  --
  -- what if we want multiple neighbors... need masking logic and run through multiple times ??

end behavioral;
