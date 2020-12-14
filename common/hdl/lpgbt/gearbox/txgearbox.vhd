-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 1.0
--! @brief Tx gearbox
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief txGearbox - Tx Gearbox
--! @details
--! The txGearbox module implements a register based clock domain crossing system to
--! pass from the serial clock domain to the MGT clock domain. It manages oversampling
--! meaning that the bit are multiplicated if the word ratio is lower than the clock
--! ratio.
entity txGearbox is
    generic (
        c_clockRatio                  : integer;                                                --! Clock ratio is clock_out / clock_in (shall be an integer)
        c_inputWidth                  : integer;                                                --! Bus size of the input word
        c_outputWidth                 : integer;                                                 --! Bus size of the output word (Warning: c_clockRatio/(c_inputWidth/c_outputWidth) shall be an integer)
        c_reset_dly                   : integer := 0
    );
    port (
        -- Clock and reset
        clk_inClk_i                   : in  std_logic;                                          --! Input clock (frame clock)
        clk_clkEn_i                   : in  std_logic;                                          --! Input clock enable when multicycle path or '1'
        clk_outClk_i                  : in  std_logic;                                          --! Output clock (from the MGT)

        rst_gearbox_i                 : in  std_logic;                                          --! Reset signal

        -- Data
        dat_inFrame_i                 : in  std_logic_vector((c_inputWidth-1) downto 0);        --! Input data
        dat_outFrame_o                : out std_logic_vector((c_outputWidth-1) downto 0);       --! Output data

        -- Status
        sta_gbRdy_o                   : out std_logic                                           --! Ready signal
    );
end txGearbox;

--! @brief txGearbox architecture- Tx Gearbox
--! @details
--! The txGearbox implements a register based clock domain crossing system. Using different clock
--! for the input and output require a special attention on the phase relation between these two
--! signals.
architecture behavioral of txGearbox is

    --================================ Signal Declarations ================================--
    constant c_oversampling                      : integer := c_clockRatio/(c_inputWidth/c_outputWidth);

    signal gearboxSyncReset                      : std_logic;
    signal rst_gearbox_s                         : std_logic;
    signal rst_gearbox_dly_s                     : integer := c_reset_dly;

    signal txFrame_from_frameInverter_s          : std_logic_vector (c_inputWidth-1 downto 0);
    signal txFrame_from_frameInverter_pipe0_s    : std_logic_vector (c_inputWidth-1 downto 0);
    signal txFrame_from_frameInverter_pipe_s     : std_logic_vector (c_inputWidth-1 downto 0);
    signal in_txFrame_from_frameInverter_s       : std_logic_vector (c_inputWidth-1 downto 0);
    signal txFrame_from_frameInverter_reg_s      : std_logic_vector (c_inputWidth-1 downto 0);
    signal txWord_beforeOversampling_s           : std_logic_vector((c_inputWidth/c_clockRatio)-1 downto 0);

    signal debug                                 : integer;
    signal clk_clkEn_s                           : std_logic;
    signal clk_clkEn_pipe_s                      : std_logic;
    signal dat_outFrame_s                        : std_logic_vector((c_outputWidth-1) downto 0);

   --=====================================================================================--

--=================================================================================================--
begin                 --========####   Architecture Body   ####========--
--=================================================================================================--

   --==================================== User Logic =====================================--

    -- Comment: Bits are inverted to transmit the MSB first on the MGT.
    frameInverter: for i in (c_inputWidth-1) downto 0 generate
        in_txFrame_from_frameInverter_s(i)             <= dat_inFrame_i((c_inputWidth-1)-i);
    end generate;

    -- Comment: Note!! The reset of the gearbox is synchronous to TX_FRAMECLK in order to align the address 0
    --                 of the gearbox with the rising edge of TX_FRAMECLK after reset.
    sta_gbRdy_o    <= not(gearboxSyncReset);

    -- Sync reset
    rst_pipeline_proc: process(rst_gearbox_i, clk_inClk_i)
    begin
        if rst_gearbox_i = '1' then
            rst_gearbox_s <= '1';
            rst_gearbox_dly_s <= rst_gearbox_dly_s;

        elsif rising_edge(clk_inClk_i) then
            if clk_clkEn_i = '1' and rst_gearbox_dly_s = 0 then
                rst_gearbox_s <= '0';
                rst_gearbox_dly_s <= 0;
            elsif clk_clkEn_i = '1' then
                rst_gearbox_dly_s <= rst_gearbox_dly_s - 1;
            end if;
        end if;
    end process;

    gbRstSynch_proc: process(rst_gearbox_s, clk_outClk_i)
    begin
        if rst_gearbox_s = '1' then
            gearboxSyncReset  <= '1';

        elsif rising_edge(clk_outClk_i) then
            gearboxSyncReset <= '0';
        end if;
    end process;

    pipeline_proc: process(clk_outClk_i)
    begin
        if rising_edge(clk_outClk_i) then
            txFrame_from_frameInverter_pipe0_s <= in_txFrame_from_frameInverter_s;
            txFrame_from_frameInverter_pipe_s  <= txFrame_from_frameInverter_pipe0_s;
        end if;
    end process;

    gb_proc: process(gearboxSyncReset, clk_outClk_i)
        variable address                       : integer range 0 to (c_clockRatio-1);
    begin

        if gearboxSyncReset = '1' then
            txWord_beforeOversampling_s         <= (others => '0');
            address                             := 0;
            debug <= address;

        elsif rising_edge(clk_outClk_i) then

            debug <= address;
            if address = 0 then
                txWord_beforeOversampling_s         <= txFrame_from_frameInverter_pipe_s((c_inputWidth/c_clockRatio)-1 downto 0);
                txFrame_from_frameInverter_reg_s    <= txFrame_from_frameInverter_pipe_s;
            else
                txWord_beforeOversampling_s         <= txFrame_from_frameInverter_reg_s(((c_inputWidth/c_clockRatio)*(address+1))-1 downto ((c_inputWidth/c_clockRatio)*(address)));
            end if;

            if address = (c_clockRatio-1) then
                address := 0;
            else
                address  := address + 1;
            end if;

        end if;
    end process;

    -- Comment: Oversampling generator loop.
    oversamplerMultPh: for i in 0 to (c_inputWidth/c_clockRatio)-1 generate
        oversamplerPhN: for j in 0 to (c_oversampling-1) generate
            dat_outFrame_s((i*c_oversampling)+j)   <= txWord_beforeOversampling_s(i);
        end generate;
    end generate;

    process(clk_outClk_i)
    begin
        if rising_edge(clk_outClk_i) then
            dat_outFrame_o <= dat_outFrame_s;
        end if;
    end process;
    --=====================================================================================--
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--
