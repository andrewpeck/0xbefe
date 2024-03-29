library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.cluster_pkg.all;

entity me0_sbit_align is
    generic(
        g_NUM_OF_VFATs : integer := 24;
        g_NUM_ELINKs   : integer := 8;
        g_MAX_SLIP_CNT : integer;
        g_MAX_SR_DELAY : integer
    );
    port(
        clk_i               : in std_logic;
        rst_i               : in std_logic;

        vfat_mapping_arr_i  : in t_vfat_mapping_arr(g_NUM_OF_VFATs -1 downto 0); -- values to rotate each VFAT sbit array by
        vfat_delay_arr_i    : in t_vfat_mapping_arr(g_NUM_OF_VFATs -1 downto 0); -- values of how much to delay each VFAT by
        
        vfat_sbits_i        : in t_std64_array(g_NUM_OF_VFATs -1 downto 0);
        vfat_sbits_o        : out t_std64_array(g_NUM_OF_VFATs -1 downto 0)
    );
end entity me0_sbit_align;

architecture me0_sbit_align_arch of me0_sbit_align is

begin
    
    g_vfat : for VFAT in 0 to g_NUM_OF_VFATs - 1 generate

        signal vfat_sbits_unmapped : std_logic_vector(63 downto 0);
        signal vfat_sbits_mapped   : std_logic_vector(63 downto 0);
        signal vfat_sbits_delayed  : std_logic_vector(63 downto 0);

    begin

        vfat_sbits_unmapped <= vfat_sbits_i(VFAT);
        
        -- first run sbits of each elink through bitslip to rotate std_logic_vectors to correct mapping
        g_elink : for ELINK in 0 to 7 generate
            g_sbit_mapping : entity work.bitslip
                generic map(
                    g_DATA_WIDTH              => 8,
                    g_SLIP_CNT_WIDTH          => 4,
                    g_TRANSMIT_LOW_TO_HIGH    => TRUE
                )
                port map(
                    clk_i       => clk_i,
                    slip_cnt_i  => vfat_mapping_arr_i(VFAT)(ELINK),
                    data_i      => vfat_sbits_unmapped((ELINK+1)*8 - 1 downto ELINK*8),
                    data_o      => vfat_sbits_mapped((ELINK+1)*8 - 1 downto ELINK*8)
                );
        -- next run sbits through shift reg to delay all sbits of one VFAT by selected amount
            g_sbit_delay : entity work.shift_reg_multi
                generic map(
                    TAP_DELAY_WIDTH => 4,
                    DATA_WIDTH      => 8,
                    OUTPUT_REG      => FALSE,
                    SUPPORT_RESET   => FALSE
                )
                port map(
                    clk_i       => clk_i,
                    reset_i     => rst_i,
                    tap_delay_i => vfat_delay_arr_i(VFAT)(ELINK),
                    data_i      => vfat_sbits_mapped((ELINK+1)*8 - 1 downto ELINK*8),
                    data_o      => vfat_sbits_delayed((ELINK+1)*8 - 1 downto ELINK*8)
                );
        end generate;
        
        vfat_sbits_o(VFAT) <= vfat_sbits_delayed;

    end generate;



end architecture me0_sbit_align_arch;
