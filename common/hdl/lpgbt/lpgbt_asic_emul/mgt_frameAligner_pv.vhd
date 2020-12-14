-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 1.0
--! @brief MGT word aligner (Pattern search)
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Include the LpGBT-FPGA specific package
--use work.lpgbtfpga_package.all;

--! @brief mgt_framealigner - MGT word aligner (Pattern search)
--! @details
--! The mgt_framealigner module ask for clock shift to align the
--! frame header.
entity mgt_framealigner is
    generic (
        c_wordRatio                      : integer;             --! Word ration: frameclock / mgt_wordclock
        c_headerPattern                  : std_logic_vector;    --! Header pattern specified by the standard
        c_wordSize                       : integer;             --! Size of the MGT word
        c_allowedFalseHeader             : integer;             --! Number of false header allowed to avoid unlock on frame error
        c_allowedFalseHeaderOverN        : integer;             --! Number of header checked to know wether the lock is lost or not
        c_requiredTrueHeader             : integer;             --! Number of true header required to go in locked state

        c_resetOnEven                    : integer := 0;        --! Reset on even bitslip (1: Enabled/ 0: disabled)
        c_resetDuration                  : integer := 10;       --! Reset duration (in clk_freeRunningClk_i periods)
        c_bitslip_pulse_duration         : integer := 2;        -- [PV]
        c_bitslip_mindly                 : integer := 40        --! Number of clock cycle required when asserting the bitslip signal
    );
    port (
        -- Clock(s)
        clk_pcsRx_i                      : in  std_logic;       --! MGT Wordclock
        clk_freeRunningClk_i             : in  std_logic;       --! Free running clock for MGT reset (reset on even feature)

        -- Reset(s)
        rst_pattsearch_i                 : in  std_logic;       --! Rst the pattern search state machines
        rst_mgtctrler_i                  : in  std_logic;       --! Rst the "reset on even" controller
        rst_rstoneven_o                  : out std_logic;       --! Output reset asserted when reset is even or odd depending on cmd_rstonevenoroddsel_i

        -- Control
        cmd_bitslipCtrl_o                : out std_logic;       --! Bitslip signal to shift the parrallel word
        cmd_rstonevenoroddsel_i          : in  std_logic;       --! Select how to reset the MGT (even or odd bitslip)

        -- Status
        sta_headerLocked_o               : out std_logic;       --! Status: header is locked
        sta_headerFlag_o                 : out std_logic;       --! Status: header flag (1 pulse over c_wordRatio)

        -- Data
        dat_word_i                       : in  std_logic_vector(c_headerPattern'length-1 downto 0)  --! Header bits from the MGT word (compared with c_headerPattern)
   );
end mgt_framealigner;

--! @brief mgt_framealigner - MGT word aligner (Pattern search)
--! @details
--! Check if the header set on dat_word_i is equal to the c_headerPattern everytime a full
--! loop has been executed (c_wordRatio clock cycles). Manage the bitslip signal to shift
--! the mgt parallel word until the header is aligned.
architecture behavioral of mgt_framealigner is

   --================================ Signal Declarations ================================--
    type machine is (UNLOCKED, GOING_LOCK, LOCKED, GOING_UNLOCK);
    signal state               : machine;

    signal psAddress           : integer range 0 to c_wordRatio;
    signal shiftPsAddr         : std_logic;
    signal bitSlipCmd_s        : std_logic;
    signal headerFlag_s        : std_logic;
    signal sta_headerLocked_s  : std_logic;


    signal bitSlitRst            : std_logic;
    signal bitSlitRst_sync       : std_logic;

    signal cmd_bitslipDone_s     : std_logic;

    signal sta_bitSlipEven_s     : std_logic;

    signal resetDurationCnter_s  : integer range 0 to c_resetDuration;
    signal rst_rstoneven_s       : std_logic;

    type rxBitSlipCtrlStateLatOpt_T is (e0_idle, e4_doBitslip, e5_waitNcycles);
    signal stateBitSlip          : rxBitSlipCtrlStateLatOpt_T;

    signal dat_word_s            :  std_logic_vector(c_headerPattern'length-1 downto 0);
--=================================================================================================--
begin                 --========####   Architecture Body   ####========--
--=================================================================================================--

   --==================================== User Logic =====================================--
   rxWordPipeline_proc: process(rst_pattsearch_i, clk_pcsRx_i)
     begin
       if rst_pattsearch_i = '1' then
           dat_word_s <= (others => '0');
       elsif rising_edge(clk_pcsRx_i) then
           dat_word_s <= dat_word_i;
       end if;
   end process;

   --! MGT: Bitslip controller
   clkSlipProcess: process(rst_pattsearch_i, clk_pcsRx_i)
        variable timer                            : integer range 0 to c_bitslip_mindly;
   begin

        if rst_pattsearch_i = '1' then
            stateBitSlip        <= e0_idle;
            cmd_bitslipCtrl_o   <= '0';
            cmd_bitslipDone_s   <= '0';

        elsif rising_edge(clk_pcsRx_i) then
            case stateBitSlip is
                when e0_idle =>         cmd_bitslipDone_s <= '1';

                                        if bitSlipCmd_s = '1' then
                                            stateBitSlip       <= e4_doBitslip;
                                            timer              := 0;
                                            cmd_bitslipDone_s  <= '0';
                                        end if;

                when e4_doBitslip =>    cmd_bitslipCtrl_o <= '1';
                                        if timer >= c_bitslip_pulse_duration-1 then
                                          stateBitSlip <= e5_waitNcycles;
                                          timer := 0;
                                        else
                                          timer := timer + 1;
                                        end if;

                when e5_waitNcycles =>  cmd_bitslipCtrl_o <= '0';
                                        if timer >= c_bitslip_mindly-1 then
                                            stateBitSlip <= e0_idle;
                                        else
                                            timer := timer + 1;
                                        end if;
            end case;
        end if;

   end process;

   --! MGT: Reset on even controller
   resetOnEven_gen: if c_resetOnEven = 1 generate

       rstOnBitSlip_process: process(rst_mgtctrler_i, clk_freeRunningClk_i)
        begin

            if rst_mgtctrler_i = '1' then
                rst_rstoneven_o      <= '0';
                sta_headerLocked_o   <= '0';
                resetDurationCnter_s <= 0;
                rst_rstoneven_s      <= '0'; -- [PV]
            elsif rising_edge(clk_freeRunningClk_i) then

                if sta_bitSlipEven_s = cmd_rstonevenoroddsel_i and sta_headerLocked_s = '1' then
                    sta_headerLocked_o   <= '0';
                    rst_rstoneven_s      <= '1';
                    resetDurationCnter_s <= 0;

                elsif sta_bitSlipEven_s /= cmd_rstonevenoroddsel_i and sta_headerLocked_s = '1'  then
                    sta_headerLocked_o <= '1';

                else
                    sta_headerLocked_o <= sta_headerLocked_s;

                end if;

                if rst_rstoneven_s = '1' then

                    if resetDurationCnter_s < c_resetDuration then
                        rst_rstoneven_o <= '1';
                        resetDurationCnter_s <= resetDurationCnter_s + 1;
                    else
                        rst_rstoneven_o <= '0';
                        resetDurationCnter_s <= 0;
                        rst_rstoneven_s <= '0';
                    end if;

                end if;

            end if;
        end process;

   end generate;

   noRstOnEven_gen: if c_resetOnEven /= 1 generate
        sta_headerLocked_o <= sta_headerLocked_s;
   end generate;

   --! Pattern searcher: check the header and ask for bitslip
   patternSearch_proc: process(rst_pattsearch_i, clk_pcsRx_i)
    begin

        if rst_pattsearch_i = '1' then
            bitSlipCmd_s       <= '0';
            sta_bitSlipEven_s  <= '1';

        elsif rising_edge(clk_pcsRx_i) then
            bitSlipCmd_s <= '0';

            if state = UNLOCKED and psAddress = 0 and cmd_bitslipDone_s = '1' then

                if (dat_word_s(c_headerPattern'length-1 downto 0) /= c_headerPattern) then
                    sta_bitSlipEven_s  <= not(sta_bitSlipEven_s);
                    bitSlipCmd_s       <= '1';
                end if;

            end if;
        end if;
    end process;

    --! Pattern search address controller
    patternSearchAddr_proc: process(rst_pattsearch_i, clk_pcsRx_i)
    begin

        if rst_pattsearch_i = '1' then
            psAddress         <= 0;
            headerFlag_s      <= '0';

        elsif rising_edge(clk_pcsRx_i) then
            headerFlag_s     <= '0';

            if psAddress = 0 then
                headerFlag_s <= '1';
            end if;

            --if shiftPsAddr = '0' then
                psAddress <= psAddress + 1;

                if psAddress = c_wordRatio-1 then
                    psAddress <= 0;
                end if;

            --end if;
        end if;
    end process;

    --! Header locked state machine
    lockFSM_proc: process(rst_pattsearch_i, clk_pcsRx_i)
        variable consecFalseHeaders        : integer range 0 to c_allowedFalseHeader;
        variable consecCorrectHeaders      : integer range 0 to c_requiredTrueHeader;
        variable nbCheckedHeaders          : integer range 0 to c_allowedFalseHeaderOverN;

    begin
        if rst_pattsearch_i = '1' then
            state        <= UNLOCKED;

        elsif rising_edge(clk_pcsRx_i) then

            if psAddress = 0 and cmd_bitslipDone_s = '1' then
                case state is

                    when UNLOCKED         => if (dat_word_s(c_headerPattern'length-1 downto 0) = c_headerPattern) then
                                                    state <= GOING_LOCK;
                                                    consecCorrectHeaders := 0;
                                                end if;

                    when GOING_LOCK    => if (dat_word_s(c_headerPattern'length-1 downto 0) /= c_headerPattern) then
                                                    state <= UNLOCKED;

                                                else
                                                    consecCorrectHeaders := consecCorrectHeaders + 1;

                                                    if consecCorrectHeaders >= c_requiredTrueHeader then
                                                        state <= LOCKED;
                                                    end if;
                                                end if;

                    when LOCKED            =>    if (dat_word_s(c_headerPattern'length-1 downto 0) /= c_headerPattern) then
                                                    consecFalseHeaders := 0;
                                                    nbCheckedHeaders   := 0;
                                                    state <= GOING_UNLOCK;
                                                end if;

                    when GOING_UNLOCK    =>  if (dat_word_s(c_headerPattern'length-1 downto 0) = c_headerPattern) then

                                                if nbCheckedHeaders = c_allowedFalseHeaderOverN then
                                                   state <= LOCKED;
                                                else
                                                    nbCheckedHeaders := nbCheckedHeaders + 1;
                                                end if;

                                            else

                                                consecFalseHeaders := consecFalseHeaders + 1;

                                                if consecFalseHeaders >= c_allowedFalseHeader then
                                                    state <= UNLOCKED;
                                                end if;
                                            end if;

                end case;
            end if;
        end if;
    end process;

    headerLocked_sync: process(rst_pattsearch_i, clk_pcsRx_i)
    begin
        if rst_pattsearch_i = '1' then
            sta_headerLocked_s <= '0';
        elsif rising_edge(clk_pcsRx_i) then
            if psAddress = 0 then
                if state = LOCKED or state = GOING_UNLOCK then
                    sta_headerLocked_s <= '1';
                else
                    sta_headerLocked_s <= '0';
                end if;
            end if;
        end if;
    end process;

    sta_headerFlag_o        <= headerFlag_s when (state = LOCKED or state = GOING_UNLOCK) else '0';
   --=====================================================================================--
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--