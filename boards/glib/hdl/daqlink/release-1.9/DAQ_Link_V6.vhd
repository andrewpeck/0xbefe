----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:25:43 01/28/2012 
-- Design Name: 
-- Module Name:    miniCTR - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.std_logic_misc.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;
Library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity DAQ_Link_V6 is
		Generic (
-- If you do not use the trigger port, set it to false
--					 USE_TRIGGER_PORT : boolean := true;
					 simulation : boolean := false);
    Port ( 
           reset : in  STD_LOGIC; -- asynchronous reset, assert reset until GTX REFCLK stable
					 USE_TRIGGER_PORT : in boolean;
-- MGT signals
           UsrClk : in  STD_LOGIC; -- it must have a frequency of 250MHz
           RXPLLLKDET : in  STD_LOGIC;
           RxResetDone : in  STD_LOGIC;
           TxResetDone : in  STD_LOGIC;
           RXCDRRESET : out  STD_LOGIC;
           RXENPCOMMAALIGN : out  STD_LOGIC;
           RXENMCOMMAALIGN : out  STD_LOGIC;
           RXLOSSOFSYNC : in  STD_LOGIC_VECTOR (1 downto 0);
           RXCHARISCOMMA : in  STD_LOGIC_VECTOR (1 downto 0);
           RXCHARISK : in  STD_LOGIC_VECTOR (1 downto 0);
           RXDATA : in  STD_LOGIC_VECTOR (15 downto 0);
           TXCHARISK : out  STD_LOGIC_VECTOR (1 downto 0);
           TXDATA : out  STD_LOGIC_VECTOR (15 downto 0);
-- TRIGGER port
           TTCclk : in  STD_LOGIC;
           BcntRes : in  STD_LOGIC;
           trig : in  STD_LOGIC_VECTOR (7 downto 0);
-- TTS port
           TTSclk : in  STD_LOGIC; -- clock source which clocks TTS signals
           TTS : in  STD_LOGIC_VECTOR (3 downto 0);
-- Data port
					 EventDataClk : in  STD_LOGIC;
           EventData_valid : in  STD_LOGIC; -- used as data write enable
           EventData_header : in  STD_LOGIC; -- first data word
           EventData_trailer : in  STD_LOGIC; -- last data word
           EventData : in  STD_LOGIC_VECTOR (63 downto 0);
           AlmostFull : out  STD_LOGIC; -- buffer almost full
           Ready : out  STD_LOGIC;
           sysclk : in  STD_LOGIC;
           L1A_DATA_we : out  STD_LOGIC; -- last data word
           L1A_DATA : out  STD_LOGIC_VECTOR (15 downto 0)
					 );
end DAQ_Link_V6;

architecture Behavioral of DAQ_Link_V6 is
COMPONENT crc16D16
	PORT(
		clk : IN std_logic;
		init_crc : IN std_logic;
		we_crc : IN std_logic;
		d : IN std_logic_vector(15 downto 0);          
		crc : OUT std_logic_vector(15 downto 0)
		);
END COMPONENT;
COMPONENT EthernetCRCD32
	PORT(
		clk : IN std_logic;
		init : IN std_logic;
		ce : IN std_logic;
		d : IN std_logic_vector(31 downto 0);          
		crc : OUT std_logic_vector(31 downto 0);
		bad_crc : OUT std_logic
		);
END COMPONENT;
COMPONENT TTS_TRIG_if
--	Generic (USE_TRIGGER_PORT : boolean := true);
	PORT(
		reset : IN std_logic;
		USE_TRIGGER_PORT : boolean;
		UsrClk : IN std_logic;
		TTCclk : IN std_logic;
		BcntRes : IN std_logic;
		trig : IN std_logic_vector(7 downto 0);
		TTSclk : IN std_logic;
		TTS : IN std_logic_vector(3 downto 0);
		RXCHARISK : IN std_logic_vector(1 downto 0);
		RXDATA : IN std_logic_vector(15 downto 0);          
		sel_TTS_TRIG : OUT std_logic;
		TTS_TRIG_data : OUT std_logic_vector(17 downto 0)
		);
END COMPONENT;
COMPONENT fifo66X512
		generic (ALMOST_FULL_OFFSET : STD_LOGIC_VECTOR (15 downto 0) := x"000a";
						 ALMOST_EMPTY_OFFSET : STD_LOGIC_VECTOR (15 downto 0) := x"0004");
	PORT(
		wclk : IN std_logic;
		rclk : IN std_logic;
		reset : IN std_logic;
		Di : IN std_logic_vector(65 downto 0);
		we : IN std_logic;
		re : IN std_logic;          
		Do : OUT std_logic_vector(65 downto 0);
		almostfull : OUT std_logic;
		almostempty : OUT std_logic;
		full : OUT std_logic;
		empty : OUT std_logic
		);
END COMPONENT;
constant N : integer := 8;
constant Acknowledge : std_logic_vector(7 downto 0) := x"12";
constant version : std_logic_vector(7 downto 0) := x"10";
constant data : std_logic_vector(7 downto 0) := x"34";
constant InitRqst : std_logic_vector(7 downto 0) := x"56";
constant Counter : std_logic_vector(7 downto 0) := x"78";
constant K_word : std_logic_vector(15 downto 0) := x"3cbc"; -- sequence K28.5 K28.1
constant R_word : std_logic_vector(15 downto 0) := x"dcfb"; -- sequence K27.7 K28.6
constant eof_word : std_logic_vector(15 downto 0) := x"5cf7"; -- sequence K23.7 K28.2
constant IDLE : std_logic_vector(3 downto 0) := x"0"; -- TxState
constant SendK : std_logic_vector(3 downto 0) := x"1"; -- TxState sending comma
constant SendType : std_logic_vector(3 downto 0) := x"2"; -- TxState sending event data words
constant SendSEQ : std_logic_vector(3 downto 0) := x"3"; -- TxState sending sequence number
constant SendWC : std_logic_vector(3 downto 0) := x"4"; -- TxState sending payload word count
constant WaitCRC : std_logic_vector(3 downto 0) := x"5"; -- TxState same as IDLE
constant WaitData : std_logic_vector(3 downto 0) := x"6"; -- TxState same as IDLE, used during sending packets
constant SendCRC : std_logic_vector(3 downto 0) := x"7"; -- TxState sending CRC
constant SendData : std_logic_vector(3 downto 0) := x"8"; -- TxState sending event data words
constant SendCntr : std_logic_vector(3 downto 0) := x"9"; -- TxState sending event data words
constant SendEOF : std_logic_vector(3 downto 0) := x"a"; -- TxState sending EOF
signal TxState: std_logic_vector(3 downto 0) := (others => '0');
signal w : positive := 16;
signal sel_TTS_TRIG : std_logic := '0';
signal bcnt_err_cnt : std_logic_vector(3 downto 0) := (others => '0');
signal reset_sync : std_logic_vector(3 downto 0) := (others => '0');
signal rst_cdr : std_logic := '0';
signal rst_wait : std_logic := '0';
signal wait_cntr : std_logic_vector(16 downto 0) := (others => '0');
signal UsrClkDiv : std_logic_vector(1 downto 0) := (others => '0');
signal TTS_TRIG_data : std_logic_vector(17 downto 0) := (others => '0');
signal ResetFIFO_sync : std_logic_vector(1 downto 0) := (others => '0');
signal AlmostFull_i : std_logic := '0';
signal AlmostFull_sync : std_logic_vector(2 downto 0) := (others => '0');
signal Init_EventCRC : std_logic := '0';
signal ce_EventCRC : std_logic := '0';
signal EventCRC_d : std_logic_vector(31 downto 0) := (others => '0');
signal EventCRC : std_logic_vector(31 downto 0) := (others => '0');
signal BoE : std_logic := '0';
signal EoE : std_logic := '0';
signal FillDataBuf : std_logic := '0';
signal dataBuf_WrEn : std_logic := '0';
signal DataBuf_wa : std_logic_vector(14 downto 0) := (others => '0');
signal DataBuf_ra : std_logic_vector(14 downto 0) := (others => '0');
signal DataBuf_start : std_logic_vector(14 downto 0) := (others => '0');
signal DataBuf_Din : std_logic_vector(16 downto 0) := (others => '0');
signal DataBuf_Dout : std_logic_vector(16 downto 0) := (others => '0');
signal ec_DataBuf_ra : std_logic := '0';
signal ec_DataBuf_ra_q : std_logic := '0';
signal DataBuf_full : std_logic := '0';
signal DataBuf_used : std_logic_vector(14 downto 0) := (others => '0');
signal DataBuf_wc : std_logic_vector(14 downto 0) := (others => '0');
signal ReSendQueOut_q : std_logic_vector(14 downto 0) := (others => '0');
signal ReSendQue_a : std_logic_vector(1 downto 0) := (others => '1');
signal ReSendQue_empty : std_logic := '1';
signal we_DataPipe : std_logic := '0';
signal DataPipeDo : std_logic_vector(16 downto 0) := (others => '0');
signal DataPipe_a : std_logic_vector(3 downto 0) := (others => '1');
signal DataPipe_empty : std_logic := '1';
signal EventStatus_empty : std_logic := '1';
signal DataPipe_full : std_logic := '0';
signal InitLink : std_logic := '0';
signal InitACK : std_logic := '0';
signal ReSend : std_logic := '0';
signal Ready_i : std_logic := '1';
signal FoundEOF : std_logic := '0';
signal ACK : std_logic := '0';
signal CntrACK : std_logic := '0';
signal L1Aabort : std_logic := '0';
signal timer : std_logic_vector(N downto 0) := (others => '0');
signal we_ReSendQue : std_logic := '0';
signal we_TxCRC : std_logic := '0';
signal Init_TxCRC : std_logic := '0';
signal R_word_cnt : std_logic_vector(11 downto 0) := (others => '0');
signal TxCRC : std_logic_vector(15 downto 0) := (others => '0');
signal R_word_sent : std_logic := '0';
signal sel_cntr : std_logic := '0';
signal we_TxFIFO : std_logic := '0';
signal TxFIFO_empty : std_logic := '1';
signal TxFIFO_full : std_logic := '0';
signal TxFIFO_a : std_logic_vector(3 downto 0) := (others => '1');
signal TxFIFO_Dip : std_logic_vector(15 downto 0) := (others => '0');
signal TxFIFO_Di : std_logic_vector(16 downto 0) := (others => '0');
signal TxFIFO_Do : std_logic_vector(16 downto 0) := (others => '0');
signal packet_wc : std_logic_vector(15 downto 0) := (others => '0');
signal ACKNUM_IN : std_logic_vector(7 downto 0) := x"00";
signal RxSEQNUM : std_logic_vector(7 downto 0) := x"00";
signal SEQNUM : std_logic_vector(7 downto 0) := x"00";
signal NextSEQNUM : std_logic_vector(7 downto 0) := x"00";
signal ACKNUM : std_logic_vector(7 downto 0) := (others => '0');
signal bad_K : std_logic := '0';
signal SEQ_OK : std_logic := '0';
signal IllegalSeq : std_logic := '0';
signal CRC_OK : std_logic := '0';
signal frame_OK : std_logic := '0';
signal TypeInit : std_logic := '0';
signal TypeACK : std_logic := '0';
signal TypeData : std_logic := '0';
signal TypeCntr : std_logic := '0';
signal Receiving : std_logic := '0';
signal Header2 : std_logic := '0';
signal TxType : std_logic_vector(7 downto 0) := (others => '0');
signal AMC_ID : std_logic_vector(7 downto 0) := (others => '0');
signal RxType : std_logic_vector(15 downto 0) := (others => '0');
signal RxWC : std_logic_vector(2 downto 0) := (others => '0');
signal check_packet : std_logic := '0';
signal WC_OKp : std_logic := '0';
signal WC_OK : std_logic := '0';
signal L1Ainfo : std_logic := '0';
signal ACK_OK : std_logic := '0';
signal we_ACKNUM : std_logic := '0';
signal accept : std_logic := '0';
signal IsACK : std_logic := '0';
signal IsCntr : std_logic := '0';
signal IsData : std_logic := '0';
signal CntrSent : std_logic := '0';
signal ReSendQueIn : std_logic_vector(27 downto 0) := (others => '0');
signal ReSendQueOut : std_logic_vector(27 downto 0) := (others => '0');
signal ACKNUM_full : std_logic := '0';
signal ACKNUM_empty : std_logic := '1';
signal AMC_info : std_logic_vector(7 downto 0) := (others => '0');
signal ACKNUM_l : std_logic_vector(7 downto 0) := (others => '0');
signal ACKNUM_a : std_logic_vector(1 downto 0) := (others => '1');
signal we_RxCRC : std_logic := '0';
signal Init_RxCRC : std_logic := '0';
signal RxCRC : std_logic_vector(15 downto 0) := (others => '0');
signal AMCinfo_WrEn : std_logic := '0';
signal AMCinfo_wa : std_logic_vector(9 downto 0) := (others => '0');
signal AMCinfo_sel : std_logic_vector(2 downto 0) := (others => '0');
signal AMCinfo_Di : std_logic_vector(15 downto 0) := (others => '0');
signal AMCinfo_Do : std_logic_vector(15 downto 0) := (others => '0');
signal evnLSB : std_logic_vector(7 downto 0) := (others => '0');
signal bad_ID : std_logic := '0';
signal AMC_header : std_logic := '0';
signal L1Ainfo_WrEn : std_logic := '0';
signal OldL1Ainfo_wa : std_logic_vector(7 downto 0) := (others => '0');
signal L1Ainfo_wa : std_logic_vector(9 downto 0) := (others => '0');
signal info_ra : std_logic_vector(9 downto 0) := (others => '0');
signal L1Ainfo_Di : std_logic_vector(15 downto 0) := (others => '0');
signal L1Ainfo_Do : std_logic_vector(15 downto 0) := (others => '0');
signal L1Ainfo_empty : std_logic := '1';
signal RxL1Ainfo : std_logic := '0';
signal AMCinfo_empty : std_logic := '1';
signal ce_info_ra : std_logic := '0';
signal check_L1Ainfo : std_logic := '0';
signal check_L1Ainfo_q : std_logic := '0';
signal L1AinfoMM : std_logic := '0';
signal info_ra_q : std_logic_vector(1 downto 0) := (others => '0');
signal info_ra_q2 : std_logic_vector(1 downto 0) := (others => '0');
signal we_EventStatus : std_logic := '0';
signal EventData2Send : std_logic := '0';
signal UnknownEventLength : std_logic := '1';
signal bad_EventLength : std_logic := '1';
signal EventLength : std_logic_vector(19 downto 0) := (others => '0');
signal EventWC : std_logic_vector(19 downto 0) := (others => '0');
signal EventCnt : std_logic_vector(4 downto 0) := (others => '0');
signal WrEventCnt : std_logic_vector(4 downto 0) := (others => '0');
signal RdEventCnt : std_logic_vector(4 downto 0) := (others => '0');
signal EventStatus : std_logic_vector(7 downto 0) := (others => '0');
signal EventStatus_Di : std_logic_vector(7 downto 0) := (others => '0');
signal EventStatusCnt : std_logic_vector(4 downto 0) := (others => '1');
signal EventStatus_wa : std_logic_vector(4 downto 0) := (others => '1');
signal EventStatus_ra : std_logic_vector(4 downto 0) := (others => '1');
signal idle_cntr : std_logic_vector(3 downto 0) := (others => '0');
signal CntrTimeout : std_logic := '0';
signal cntr_timer : std_logic_vector(15 downto 0) := (others => '0');
signal cntrs : std_logic_vector(15 downto 0) := (others => '0');
signal cntr0 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr1 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr2 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr3 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr4 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr5 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr6 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr7 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr8 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr9 : std_logic_vector(15 downto 0) := (others => '0');
signal cntra : std_logic_vector(15 downto 0) := (others => '0');
signal cntrb : std_logic_vector(15 downto 0) := (others => '0');
signal cntrc : std_logic_vector(15 downto 0) := (others => '0');
signal cntrd : std_logic_vector(15 downto 0) := (others => '0');
signal cntre : std_logic_vector(15 downto 0) := (others => '0');
signal cntrf : std_logic_vector(15 downto 0) := (others => '0');
signal cntr10 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr11 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr12 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr13 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr14 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr15 : std_logic_vector(15 downto 0) := (others => '0');
signal cntr16 : std_logic_vector(15 downto 0) := (others => '0');
signal short_event_cntr : std_logic_vector(15 downto 0) := (others => '0');
signal input_word_cntr : std_logic_vector(15 downto 0) := (others => '0');
signal input_header_cntr : std_logic_vector(15 downto 0) := (others => '0');
signal input_trailer_cntr : std_logic_vector(15 downto 0) := (others => '0');
signal input_evnErr_cntr : std_logic_vector(15 downto 0) := (others => '0');
signal input_evn : std_logic_vector(23 downto 0) := (others => '0');
signal sample_sync : std_logic_vector(3 downto 0) := (others => '0');
signal sample : std_logic := '0';
signal FIFO_ovf : std_logic := '0';
signal RXCHARISK_q : std_logic_vector(1 downto 0) := (others => '1');
signal RXCHARISCOMMA_q : std_logic_vector(1 downto 0) := (others => '1');
signal RXLOSSOFSYNC_q : std_logic_vector(1 downto 0) := (others => '1');
signal RXDATA_q : std_logic_vector(15 downto 0) := (others => '1');
signal FIFO_rst : std_logic := '0';
signal DataFIFO_EMPTY : std_logic := '1';
signal DataFIFO_WRERR : std_logic := '0';
signal DataFIFO_RdEn : std_logic := '0';
signal DataFIFO_RdEnp : std_logic := '0';
signal DataFIFO_di : std_logic_vector(65 downto 0) := (others => '0');
signal DataFIFO_do : std_logic_vector(65 downto 0) := (others => '0');
signal RDCOUNT : std_logic_vector(8 downto 0) := (others => '0');
signal WRCOUNT : std_logic_vector(8 downto 0) := (others => '0');
signal ChkEvtLen_in : std_logic_vector(1 downto 0) := (others => '1');
signal ChkEvtLen : std_logic_vector(1 downto 0) := (others => '1');
signal L1A_DATA_o : std_logic_vector(15 downto 0) := (others => '0');
signal L1A_DATA_ra : std_logic_vector(4 downto 0) := (others => '0');
signal L1A_DATA_wa : std_logic_vector(2 downto 0) := (others => '0');
signal OldL1Ainfo_wa0_SyncRegs : std_logic_vector(3 downto 0) := (others => '0');
signal ce_L1A_DATA_ra : std_logic := '0';
signal CriticalTTS : std_logic_vector(2 downto 0) := (others => '0');

--attribute MARK_DEBUG : string;
--attribute MARK_DEBUG of TypeInit : signal is "TRUE";
--attribute MARK_DEBUG of TypeACK : signal is "TRUE";
--attribute MARK_DEBUG of TypeData : signal is "TRUE";
--attribute MARK_DEBUG of TypeCntr : signal is "TRUE";
--attribute MARK_DEBUG of Receiving : signal is "TRUE";
--attribute MARK_DEBUG of RXDATA_q : signal is "TRUE";
--attribute MARK_DEBUG of InitLink : signal is "TRUE";
--attribute MARK_DEBUG of InitACK : signal is "TRUE";
--attribute MARK_DEBUG of ReSend : signal is "TRUE";
--attribute MARK_DEBUG of FoundEOF : signal is "TRUE";
--attribute MARK_DEBUG of ACK : signal is "TRUE";
--attribute MARK_DEBUG of CntrACK : signal is "TRUE";
--attribute MARK_DEBUG of L1Aabort : signal is "TRUE";
--attribute MARK_DEBUG of timer : signal is "TRUE";
--attribute MARK_DEBUG of Init_TxCRC : signal is "TRUE";
--attribute MARK_DEBUG of R_word_cnt : signal is "TRUE";
--attribute MARK_DEBUG of TxCRC : signal is "TRUE";
--attribute MARK_DEBUG of R_word_sent : signal is "TRUE";
--attribute MARK_DEBUG of packet_wc : signal is "TRUE";
--attribute MARK_DEBUG of ACKNUM_IN : signal is "TRUE";
--attribute MARK_DEBUG of RxSEQNUM : signal is "TRUE";
--attribute MARK_DEBUG of SEQNUM : signal is "TRUE";
--attribute MARK_DEBUG of ACKNUM : signal is "TRUE";
--attribute MARK_DEBUG of bad_K : signal is "TRUE";
--attribute MARK_DEBUG of SEQ_OK : signal is "TRUE";
--attribute MARK_DEBUG of IllegalSeq : signal is "TRUE";
--attribute MARK_DEBUG of CRC_OK : signal is "TRUE";
--attribute MARK_DEBUG of frame_OK : signal is "TRUE";
--attribute MARK_DEBUG of Header2 : signal is "TRUE";
--attribute MARK_DEBUG of AMC_ID : signal is "TRUE";
--attribute MARK_DEBUG of RxType : signal is "TRUE";
--attribute MARK_DEBUG of RxWC : signal is "TRUE";
--attribute MARK_DEBUG of WC_OK : signal is "TRUE";
--attribute MARK_DEBUG of L1Ainfo : signal is "TRUE";
--attribute MARK_DEBUG of ACK_OK : signal is "TRUE";
--attribute MARK_DEBUG of accept : signal is "TRUE";
--attribute MARK_DEBUG of IsACK : signal is "TRUE";
--attribute MARK_DEBUG of IsCntr : signal is "TRUE";
--attribute MARK_DEBUG of IsData : signal is "TRUE";
--attribute MARK_DEBUG of CntrSent : signal is "TRUE";
--attribute MARK_DEBUG of ACKNUM_full : signal is "TRUE";
--attribute MARK_DEBUG of ACKNUM_empty : signal is "TRUE";
--attribute MARK_DEBUG of Init_RxCRC : signal is "TRUE";
--attribute MARK_DEBUG of RxCRC : signal is "TRUE";
--attribute MARK_DEBUG of bad_ID : signal is "TRUE";
--attribute MARK_DEBUG of AMC_header : signal is "TRUE";
--attribute MARK_DEBUG of AMCinfo_empty : signal is "TRUE";
--attribute MARK_DEBUG of ce_info_ra : signal is "TRUE";
--attribute MARK_DEBUG of idle_cntr : signal is "TRUE";
--attribute MARK_DEBUG of CriticalTTS : signal is "TRUE";
--attribute MARK_DEBUG of reset_sync : signal is "TRUE";

-- chipscope
COMPONENT cs_delay
	PORT(
		clk : IN std_logic;
		reset : IN std_logic;
		cs_in : IN std_logic_vector(71 downto 0);          
		cs_out : OUT std_logic_vector(71 downto 0)
		);
END COMPONENT;
signal cs_in : std_logic_vector(143 downto 0) := (others => '0');
begin
-- chipscope
--i_cs_delay: cs_delay PORT MAP(
--		clk => UsrClk,
--		reset => reset,
--		cs_in => cs_in(71 downto 0),
--		cs_out => open
--	);
--i_cs_delay2: cs_delay PORT MAP(
--		clk => UsrClk,
--		reset => reset,
--		cs_in => cs_in(143 downto 72),
--		cs_out => open
--	);
cs_in(16 downto 0) <= DataBuf_Din;
cs_in(19 downto 18) <= UsrClkDiv;
--cs_in(19 downto 18) <= RXCHARISK;
cs_in(29 downto 20) <= info_ra;
cs_in(39 downto 30) <= l1Ainfo_wa;
cs_in(55 downto 40) <= l1Ainfo_di;
cs_in(71 downto 56) <= l1Ainfo_do;
cs_in(87 downto 72) <= AMCinfo_do;
cs_in(90 downto 88) <= EventStatus_Di(2 downto 0);
cs_in(92 downto 91) <= info_ra_q2;
cs_in(96 downto 93) <= TxState;
cs_in(97) <= we_EventStatus;
cs_in(98) <= L1AinfoMM;
cs_in(99) <= check_L1Ainfo_q;
cs_in(100) <= l1Ainfo_wren;
cs_in(101) <= L1Ainfo_empty;
cs_in(102) <= AMCinfo_empty;
cs_in(103) <= AMCinfo_WrEn;
cs_in(104) <= filldatabuf;
cs_in(105) <= Init_EventCRC;
cs_in(106) <= DataFIFO_EMPTY;
cs_in(109 downto 107) <= AMCinfo_sel;
--cs_in(107) <= frame_OK;
--cs_in(108) <= bad_k;
--cs_in(109) <= typeinit;
--cs_in(110) <= typedata;
--cs_in(111) <= accept;
--cs_in(112) <= check_packet;
--cs_in(113) <= receiving;
--cs_in(114) <= sel_tts_trig;
--cs_in(115) <= ReSend;
cs_in(131 downto 116) <= AMCinfo_di;
cs_in(141 downto 132) <= AMCinfo_wa;
cs_in(143 downto 142) <= "00";
-- start of code
Ready <= Ready_i;
AlmostFull <= AlmostFull_i;
i_DataFIFO: fifo66X512 PORT MAP(
		wclk => EventDataClk,
		rclk => UsrClk,
		reset => FIFO_rst,
		Di => DataFIFO_di,
		we => EventData_valid,
		re => DataFIFO_RdEn,
		Do => DataFIFO_do,
		almostfull => AlmostFull_i,
		almostempty => open,
		full => open,
		empty => DataFIFO_EMPTY
	);
FIFO_rst <= not Ready_i;
DataFIFO_di <= EventData_header & EventData_trailer & EventData;
process(UsrClk)
begin
	if(UsrClk'event and UsrClk = '1')then
		UsrClkDiv <= UsrClkDiv + 1;
		if(UsrClkDiv(1) = '0')then
			EventCRC_d <= DataFIFO_do(31 downto 0);
		elsif(DataFIFO_do(65) = '1')then
			EventCRC_d <= x"0" & AMC_ID(3 downto 0) & DataFIFO_do(55 downto 32);
		else
			EventCRC_d <= DataFIFO_do(63 downto 32);
		end if;
		if(DataFIFO_do(65) = '1' and DataFIFO_RdEnp = '1')then
			EventLength <= DataFIFO_do(19 downto 0);
		end if;
		if(Ready_i = '0' or InitLink ='1')then
			ChkEvtLen <= (others => '0');
		elsif(DataFIFO_RdEnp = '1')then
			if(DataFIFO_do(64) = '1' and ChkEvtLen(1) = '1')then
				ChkEvtLen <= (others => '0');
			else
				ChkEvtLen(0) <= not ChkEvtLen(0);
				ChkEvtLen(1) <= ChkEvtLen(1) or ChkEvtLen(0);
			end if;
		end if;
		if(DataFIFO_RdEnp = '1')then
			if(DataFIFO_do(65) = '1')then
				EventWC <= x"00002";
			else
				EventWC <= EventWC + 1;
			end if;
		end if;
		UnknownEventLength <= and_reduce(EventLength);
		if(DataFIFO_RdEnp = '1' and DataFIFO_do(64) = '1' and (EventWC /= DataFIFO_do(19 downto 0) or (UnknownEventLength = '0' and EventLength /= EventWC)))then
			bad_EventLength <= '1';
		else
			bad_EventLength <= '0';
		end if;
		Init_EventCRC <= not UsrClkDiv(1) and not UsrClkDiv(0) and DataFIFO_do(65) and not ChkEvtLen(1) and not ChkEvtLen(0) and not DataFIFO_EMPTY;
		if(Ready_i = '0' or InitLink = '1' or DataFIFO_EMPTY = '1')then
			FillDataBuf <= '0';
		elsif(UsrClkDiv = "00")then
			if(DataBuf_full = '1' or EventCnt(4 downto 3) = "11")then
				FillDataBuf <= '0';
			else
				FillDataBuf <= '1';
			end if;
		end if;
		ce_EventCRC <= UsrClkDiv(0) and FillDataBuf;
		DataFIFO_RdEn <= UsrClkDiv(1) and not UsrClkDiv(0) and FillDataBuf and (ChkEvtLen(1) or not DataFIFO_do(64));
		DataFIFO_RdEnp <= UsrClkDiv(1) and not UsrClkDiv(0) and FillDataBuf;
		DataBuf_wrEn <= FillDataBuf;
		BoE <= DataFIFO_do(65);
		EoE <= DataFIFO_do(64) and ChkEvtLen(1);
		if(BoE = '1' and ce_EventCRC = '1')then
			evnLSB <= EventCRC_d(7 downto 0);
		end if;
		if(EventCRC_d(31 downto 24) = evnLSB)then
			bad_ID <= '0';
		else
			bad_ID <= '1';
		end if;
		if(UsrClkDiv(0) = '1')then
			if(EoE = '1' and UsrClkDiv(1) = '1')then
				DataBuf_Din(15 downto 0) <= EventCRC(15 downto 0);
			else
				DataBuf_Din(15 downto 0) <= EventCRC_d(15 downto 0);
			end if;
		elsif(EoE = '1' and UsrClkDiv(1) = '0')then
			DataBuf_Din(15 downto 0) <= EventCRC(31 downto 16);
		else
			DataBuf_Din(15 downto 0) <= EventCRC_d(31 downto 16);
		end if;
		DataBuf_Din(16) <= not UsrClkDiv(1) and not UsrClkDiv(0) and EoE;
	end if;
end process;
i_EventCRC: EthernetCRCD32 PORT MAP(
		clk => UsrClk,
		init => Init_EventCRC,
		ce => ce_EventCRC,
		d => EventCRC_d,
		crc => EventCRC,
		bad_crc => open
	);
process(UsrClk,reset,RxResetDone,TxResetDone,rst_wait,RXPLLLKDET)
begin
	if(reset = '1' or (RxResetDone = '0' and rst_wait = '0') or TxResetDone = '0' or RXPLLLKDET = '0')then
		reset_sync <= (others => '1');
	elsif(UsrClk'event and UsrClk = '1')then
		reset_sync <= reset_sync(2 downto 0) & '0';
	end if;
end process;
-- following is used to reset CDR when sync get lost
w <= 8 when simulation = true else 16;
process(UsrClk)
begin
	if(UsrClk'event and UsrClk = '1')then
		RXCHARISCOMMA_q <= RXCHARISCOMMA;
		RXCHARISK_q <= RXCHARISK;
		RXDATA_q <= RXDATA;
		RXLOSSOFSYNC_q <= RXLOSSOFSYNC;
		RXENMCOMMAALIGN <= rst_wait;
		RXENPCOMMAALIGN <= rst_wait;
		if(wait_cntr(w) = '1')then
			rst_wait <= '0';
		elsif(RXLOSSOFSYNC_q(1) = '1')then
			rst_wait <= '1';
		end if;
		rst_cdr <= not rst_wait and RXLOSSOFSYNC_q(1);
		RXCDRRESET <= rst_cdr;
		if(wait_cntr(w) = '1' or rst_wait = '0')then
			wait_cntr <= (others => '0');
		else
			wait_cntr <= wait_cntr + 1;
		end if;
	end if;
end process;
process(EventDataClk,reset,InitLink)
begin
	if(reset = '1' or Ready_i = '0')then
		ChkEvtLen_in <= (others => '0');
		sample_sync <= (others => '0');
		FIFO_ovf <= '0';
		cntrc <= (others => '0');
		cntrd <= (others => '0');
		cntre <= (others => '0');
		cntrf <= (others => '0');
		cntr16 <= (others => '0');
		short_event_cntr <= (others => '0');
		input_word_cntr <= (others => '0');
		input_header_cntr <= (others => '0');
		input_trailer_cntr <= (others => '0');
		input_evnErr_cntr <= (others => '0');
		input_evn <= x"000001";
	elsif(EventDataClk'event and EventDataClk = '1')then
		sample_sync <= sample_sync(2 downto 0) & sample;
		if(DataFIFO_WRERR = '1')then
			FIFO_ovf <= '1';
		end if;
		if(EventData_valid = '1')then
			input_word_cntr <= input_word_cntr + 1;
			if(DataFIFO_di(65) = '1')then
				input_header_cntr <= input_header_cntr + 1;
				input_evn <= DataFIFO_di(55 downto 32);
				if(DataFIFO_di(55 downto 32) /= input_evn)then
					input_evnErr_cntr <= input_evnErr_cntr + 1;
				end if;
			end if;
			if(DataFIFO_di(64) = '1')then
				ChkEvtLen_in <= (others => '0');
			else
				ChkEvtLen_in(0) <= not ChkEvtLen_in(0);
				ChkEvtLen_in(1) <= ChkEvtLen_in(1) or ChkEvtLen_in(0);
			end if;
			if(DataFIFO_di(64) = '1')then
				input_trailer_cntr <= input_trailer_cntr + 1;
				input_evn <= input_evn + 1;
				if(ChkEvtLen_in(1) = '0')then
					short_event_cntr <= short_event_cntr + 1;
				end if;
			end if;
		end if;
		if(sample_sync(3) /= sample_sync(2))then -- update after Counters sent
			cntr16 <= short_event_cntr;
			cntrc <= input_word_cntr;
			cntrd <= input_header_cntr;
			cntre <= input_trailer_cntr;
			cntrf <= input_evnErr_cntr;
		end if;
	end if;
end process;
process(UsrClk)
begin
	if(UsrClk'event and UsrClk = '1')then
		if(Ready_i = '0' or InitLink = '1')then
			DataBuf_wa <= (others => '0');
			ReSendQueOut_q <= (others => '0');
			DataBuf_used <= (others => '0');
			DataBuf_wc <= (others => '0');
			ec_DataBuf_ra_q <= '0';
			ec_DataBuf_ra <= '0';
			DataBuf_full <= '0';
			we_DataPipe <= '0';
			DataPipe_a <= (others => '1');
			DataPipe_empty <= '1';
			DataPipe_full <= '0';
			RdEventCnt <= (others => '0');
			WrEventCnt <= (others => '0');
			EventData2Send <= '0';
			EventCnt <= (others => '0');
			ReSendQue_a <= (others => '1');
			we_ReSendQue <= '0';
			ReSendQue_empty <= '1';
			timer <= (others => '0');
			DataBuf_start <= (others => '0');
			DataBuf_ra <= (others => '0');
		else
			if(DataBuf_wrEn = '1')then
				DataBuf_wa <= DataBuf_wa + 1;
			end if;
			if(ReSendQue_a /= "11")then
				ReSendQueOut_q <= ReSendQueOut(14 downto 0);
			end if;
			DataBuf_used <= DataBuf_wa - ReSendQueOut_q;
			DataBuf_wc <= DataBuf_wa - DataBuf_ra;
			if(or_reduce(DataBuf_wc(14 downto 2)) = '0' and (DataBuf_wc(1 downto 0) = "00" or ec_DataBuf_ra = '1' or ec_DataBuf_ra_q = '1'))then
				ec_DataBuf_ra <= '0';
			else
				ec_DataBuf_ra <= not DataPipe_full and not Resend;
			end if;
			ec_DataBuf_ra_q <= ec_DataBuf_ra and not Resend;
			DataBuf_full <= and_reduce(DataBuf_used(14 downto 3));
			we_DataPipe <= ec_DataBuf_ra_q and not Resend;
			if(Resend = '1')then
				DataPipe_a <= (others => '1');
			elsif(we_DataPipe = '1' and (TxFIFO_full = '1' or TxState /= SendData))then
				DataPipe_a <= DataPipe_a + 1;
			elsif(we_DataPipe = '0' and TxFIFO_full = '0' and TxState = SendData)then
				DataPipe_a <= DataPipe_a - 1;
			end if;
			if(DataPipe_a = x"f" or Resend = '1' or (DataPipe_a = x"0" and TxFIFO_full = '0' and TxState = SendData))then
				DataPipe_empty <= '1';
			else
				DataPipe_empty <= '0';
			end if;
			case DataPipe_a is
				when x"e" | x"d" | x"c"  | x"b" | x"a"  | x"9" | x"8" => DataPipe_full <= '1';
				when others => DataPipe_full <= '0';
			end case;
			if(DataBuf_Din(16) = '1' and DataBuf_wrEn = '1')then
				WrEventCnt <= WrEventCnt + 1;
			end if;
			if(ReSend = '1')then
				RdEventCnt <= ReSendQueOut(27 downto 23);
			elsif(TxState = SendEOF and TxFIFO_full = '0')then
				RdEventCnt <= RdEventCnt + 1;
			end if;
			if(WrEventCnt = RdEventCnt and DataBuf_wc(14 downto 12) = "000")then
				EventData2Send <= '0';
			else
				EventData2Send <= '1';
			end if;
			EventCnt <= WrEventCnt - RdEventCnt;
			if(ReSend = '1')then
				ReSendQue_a <= (others => '1');
			elsif(we_ReSendQue = '1' and ACK = '0')then
				ReSendQue_a <= ReSendQue_a + 1;
			elsif(we_ReSendQue = '0' and ACK = '1' and ReSendQue_a /= "11")then
				ReSendQue_a <= ReSendQue_a - 1;
			end if;
			if(TxState = SendWC and TxFIFO_full = '0' and IsData = '1' and ReSend = '0')then
				we_ReSendQue <= '1';
			else
				we_ReSendQue <= '0';
			end if;
			if(ReSend = '1')then
				ReSendQue_empty <= '1';
			elsif(we_ReSendQue = '1')then
				ReSendQue_empty <= '0';
			elsif(ACK = '1' and ReSendQue_a = "00")then
				ReSendQue_empty <= '1';
			end if;
			if(timer(N) = '1' or ACK = '1' or ReSendQue_empty = '1')then
				timer <= (others => '0');
			else
				timer <= timer + 1;
			end if;
			if(Resend = '1')then
				DataBuf_start <= ReSendQueOut_q;
			elsif(we_ReSendQue = '1')then
				DataBuf_start <= DataBuf_start + packet_wc(14 downto 0);
			end if;
			if(ReSend = '1' and ReSendQue_empty = '0')then
				DataBuf_ra <= ReSendQueOut_q;
			elsif(ec_DataBuf_ra = '1')then
				DataBuf_ra <= DataBuf_ra + 1;
			end if;
		end if;
	end if;
end process;
-- ReSendQueue holds the starting address of the oldest unacknowledged packet
g_ReSendQueue : for i in 0 to 27 generate
   i_ReSendQueue : SRL16E
   port map (
      Q => ReSendQueOut(i),       -- SRL data output
      A0 => ReSendQue_a(0),     -- Select[0] input
      A1 => ReSendQue_a(1),     -- Select[1] input
      A2 => '0',     -- Select[2] input
      A3 => '0',     -- Select[3] input
      CE => we_ReSendQue,     -- Clock enable input
      CLK => UsrClk,   -- Clock input
      D => ReSendQueIn(i)        -- SRL data input
   );
end generate;
ReSendQueIn <= RdEventCnt & SEQNUM & DataBuf_start;
ReSend <= timer(N);
g_DataBufPipe: for i in 0 to 16 generate
   i_DataBuf : BRAM_SDP_MACRO
   generic map (
      BRAM_SIZE => "36Kb", -- Target BRAM, "18Kb" or "36Kb" 
      DEVICE => "VIRTEX6", -- Target device: "VIRTEX5", "VIRTEX6", "SPARTAN6" 
      WRITE_WIDTH => 1,    -- Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
      READ_WIDTH => 1,     -- Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
      DO_REG => 1) -- Optional output register (0 or 1)
    port map (
      DO => DataBuf_Dout(i downto i),         -- Output read data port, width defined by READ_WIDTH parameter
      DI => DataBuf_Din(i downto i),         -- Input write data port, width defined by WRITE_WIDTH parameter
      RDADDR => DataBuf_ra, -- Input read address, width defined by read port depth
      RDCLK => UsrClk,   -- 1-bit input read clock
      RDEN => '1',     -- 1-bit input read port enable
      REGCE => '1',   -- 1-bit input read output register enable
      RST => '0',       -- 1-bit input reset 
      WE => "1",         -- Input write enable, width defined by write port depth
      WRADDR => DataBuf_wa, -- Input write address, width defined by write port depth
      WRCLK => UsrClk,   -- 1-bit input write clock
      WREN => DataBuf_WrEn      -- 1-bit input write port enable
   );
   i_DataPipe : SRL16E
   port map (
      Q => DataPipeDo(i),       -- SRL data output
      A0 => DataPipe_a(0),     -- Select[0] input
      A1 => DataPipe_a(1),     -- Select[1] input
      A2 => DataPipe_a(2),     -- Select[2] input
      A3 => DataPipe_a(3),     -- Select[3] input
      CE => we_DataPipe,     -- Clock enable input
      CLK => UsrClk,   -- Clock input
      D => DataBuf_Dout(i)        -- SRL data input
   );
end generate;
g_TxFIFO : for i in 0 to 16 generate
   i_TxFIFO : SRL16E
   port map (
      Q => TxFIFO_Do(i),       -- SRL data output
      A0 => TxFIFO_a(0),     -- Select[0] input
      A1 => TxFIFO_a(1),     -- Select[1] input
      A2 => TxFIFO_a(2),     -- Select[2] input
      A3 => TxFIFO_a(3),     -- Select[3] input
      CE => we_TxFIFO,     -- Clock enable input
      CLK => UsrClk,   -- Clock input
      D => TxFIFO_Di(i)        -- SRL data input
   );
end generate;
TxFIFO_Di(15 downto 0) <= cntrs when sel_cntr = '1' else TxFIFO_Dip;
process(UsrClk)
begin
	if(UsrClk'event and UsrClk = '1')then
		if(InitLink = '1' or TxFIFO_a = x"f" or (TxFIFO_a = x"0" and sel_TTS_TRIG = '0' and we_TxFIFO = '0' and R_word_cnt(11) = '0'))then
			TxFIFO_empty <= '1';
		else
			TxFIFO_empty <= '0';
		end if;
		if(TxFIFO_empty = '0' or idle_cntr(3) = '1')then
			idle_cntr <= x"0";
		else
			idle_cntr <= idle_cntr + 1;
		end if;
		if(TxFIFO_a(3 downto 2) = "10")then
			TxFIFO_full <= '1';
		else
			TxFIFO_full <= '0';
		end if;
		if(InitLink = '1')then
			TxFIFO_a <= x"f";
		elsif((sel_TTS_TRIG = '1' or TxFIFO_empty = '1' or R_word_cnt(11) = '1') and we_TxFIFO = '1')then
			TxFIFO_a <= TxFIFO_a + 1;
		elsif(sel_TTS_TRIG = '0' and we_TxFIFO = '0' and TxFIFO_empty = '0' and R_word_cnt(11) = '0')then
			TxFIFO_a <= TxFIFO_a - 1;
		end if;
		if(sel_TTS_TRIG = '1')then
			TXCHARISK <= TTS_TRIG_data(17 downto 16);
			TXDATA <= TTS_TRIG_data(15 downto 0);
			R_word_sent <= '0';
		elsif(R_word_cnt(11) = '1' or TxFIFO_empty = '1')then
			TXCHARISK <= "11";
			TXDATA <= R_word;
			R_word_sent <= '1';
		else
			TXCHARISK <= TxFIFO_Do(16) & TxFIFO_Do(16);
			TXDATA <= TxFIFO_Do(15 downto 0);
			R_word_sent <= '0';
		end if;
		if(reset_sync(3) = '1')then
			InitLink <= '0';
		else
-- whenever a good initialization packet is received, (re)initializa miniCTR
			if(check_packet = '1' and CRC_OK = '1' and TypeInit = '1' and frame_OK = '1' and WC_OK = '1' and bad_K = '0')then
				InitLink <= '1';
			else
				InitLink <= '0';
			end if;
		end if;
		if(reset_sync(3) = '1' or rst_cdr = '1' or InitLink = '1')then
			Ready_i <= '0';
		elsif(InitACK = '1' and TxState = SendCRC and TxType = InitRqst)then
			Ready_i <= '1';
		end if;
		if(InitLink = '1')then
			SEQNUM <= x"00";
		elsif(ReSend = '1')then
			SEQNUM <= ReSendQueOut(22 downto 15);
		elsif(we_ReSendQue = '1')then
			SEQNUM <= SEQNUM(6 downto 0) & not(SEQNUM(7) xor SEQNUM(5) xor SEQNUM(4) xor SEQNUM(3));
		end if;
		if(InitLink = '1')then
			InitACK <= '1';
		elsif(TxState = SendCRC and TxType = InitRqst)then
			InitACK <= '0';
		end if;
		if(InitACK = '1')then
			AMC_info <= version;
		else
			AMC_info <= EventStatus;
		end if;
		if((rst_wait = '1' and TxState /= IDLE) or reset_sync(3) = '1' or InitLink = '1' or ReSend = '1')then
			TxState <= SendK;
		elsif(TxFIFO_full = '0')then
			case TxState is
				when IDLE => -- send R_word (idle)
					if((ReSendQue_a(1) = ReSendQue_a(0) and EventStatus_empty = '0' and EventData2Send = '1' and DataPipe_empty = '0') or ACKNUM_empty = '0' or CntrTimeout = '1')then
						TxState <= SendSEQ;
					elsif(idle_cntr(3) = '1')then
						TxState <= SendK;
					end if;
					if(InitACK = '1')then
						TxType <= InitRqst;
						IsData <= '0';
						IsCntr <= '0';
						IsACK <= '1';
					elsif(ACKNUM_empty = '0')then
						TxType <= Acknowledge;
						IsData <= '0';
						IsCntr <= '0';
						IsACK <= '1';
					elsif(CntrTimeout = '1')then
						IsData <= '0';
						IsCntr <= '1';
						IsACK <= '0';
						TxType <= Counter;
					else
						IsData <= '1';
						IsCntr <= '0';
						IsACK <= '0';
						TxType <= data;
					end if;
				when SendK => -- send K_word
					TxState <= IDLE;
				when SendSEQ => -- send packet_seq
					FoundEOF <= '0';
					TxState <= SendType;
				when SendType => -- send data type
					if(IsData = '1')then
						TxState <= SendData;
					elsif(IsCntr = '1')then
						TxState <= SendCntr;
					else
						TxState <= SendWC;
					end if;
				when SendWC => -- send packet_wc
					TxState <= WaitCRC;
				when WaitCRC => -- wait for CRC
					TxState <= SendCRC;
				when SendCntr => -- send counter data
					if(packet_wc(4 downto 0) = "11111")then -- 32 counters sent, it has to be multiple of 4, i.e. packet_wc(1 downto 0) must always be "11"
						TxState <= SendWC;
					end if;
				when SendData => -- send payload data
					if(and_reduce(packet_wc(10 downto 0)) = '1' or DataPipeDo(16) = '1')then -- 4K bytes limit or eof reached 
						TxState <= SendWC;
						FoundEOF <= DataPipeDo(16);
					elsif(DataPipe_a = x"0")then
						TxState <= WaitData;
					end if;
				when WaitData => -- wait for data
					if(DataPipe_empty = '0')then
						TxState <= SendData;
					end if;
				when SendCRC => -- send TxCRC
					if(FoundEOF = '1')then
						TxState <= SendEOF;
					else
						TxState <= SendK;
					end if;
				when SendEOF => -- send eof_word
					TxState <= SendK;
				when others => TxState <= x"0";
			end case;
		end if;
		case TxState is
			when SendK => TxFIFO_Dip <= K_word;
			when SendData => TxFIFO_Dip <= DataPipeDo(15 downto 0);
			when SendSEQ => TxFIFO_Dip <= SEQNUM & TxType;
			when SendType => TxFIFO_Dip <= ACKNUM_l & AMC_info;
			when SendWC => TxFIFO_Dip <= packet_wc;
			when SendCRC => TxFIFO_Dip <= TxCRC;
			when SendEOF => TxFIFO_Dip <= eof_word;
			when others => TxFIFO_Dip <= (others => '0');
		end case;
		if(InitLink = '1')then
			cntrs <= (others => '0');
		elsif(packet_wc(4) = '0')then
			case packet_wc(3 downto 0) is
				when x"0" => cntrs <= cntr0;
				when x"1" => cntrs <= cntr1;
				when x"2" => cntrs <= cntr2;
				when x"3" => cntrs <= cntr3;
				when x"4" => cntrs <= cntr4;
				when x"5" => cntrs <= cntr5;
				when x"6" => cntrs <= cntr6;
				when x"7" => cntrs <= cntr7;
				when x"8" => cntrs <= cntr8;
				when x"9" => cntrs <= cntr9;
				when x"a" => cntrs <= cntra;
				when x"b" => cntrs <= cntrb;
				when x"c" => cntrs <= cntrc;
				when x"d" => cntrs <= cntrd;
				when x"e" => cntrs <= cntre;
				when others => cntrs <= cntrf;
			end case;
		else
			case packet_wc(3 downto 0) is
				when x"0" => cntrs <= FIFO_ovf & "00" & EventStatus_ra & "000" & EventStatus_wa;
				when x"1" => cntrs <= '0' & DataBuf_wa;
				when x"2" => cntrs <= '0' & DataBuf_ra;
				when x"3" => cntrs <= "000000" & L1Ainfo_wa;
				when x"4" => cntrs <= "000000" & info_ra;
				when x"5" => cntrs <= "000000" & AMCinfo_wa;
				when x"6" => cntrs <= x"00" & version;
				when x"7" => cntrs <= '0' & EventStatus_empty & EventData2Send & DataPipe_empty & CriticalTTS & EventCnt & ReSendQue_a & AlmostFull_i & dataFIFO_Empty;
				when x"8" => cntrs <= cntr10;
				when x"9" => cntrs <= cntr11;
				when x"a" => cntrs <= cntr12;
				when x"b" => cntrs <= cntr13;
				when x"c" => cntrs <= cntr14;
				when x"d" => cntrs <= cntr15;
				when x"f" => cntrs <= cntr16; -- add more counter needs to update line if(packet_wc(4 downto 0) = "11110")then -- 16 counters and 15 status words sent
				when others => cntrs <= (others => '0');
			end case;
		end if;
		case TxState is
			when SendK | SendEOF | IDLE | WaitData | WaitCRC => TxFIFO_Di(16) <= '1';
			when others => TxFIFO_Di(16) <= '0';
		end case;
		if(InitLink = '1' or TxFIFO_full = '1')then
			we_TxFIFO <= '0';
		else
			case TxState is
				when IDLE | WaitData | WaitCRC => we_TxFIFO <= '0';
				when others => we_TxFIFO <= '1';
			end case;			
		end if;
		if(TxState = SendCntr)then
			sel_cntr <= '1';
		else
			sel_cntr <= '0';
		end if;
		if(TxState = SendK)then 
			packet_wc(11 downto 0) <= x"000";
		elsif(TxFIFO_full = '0' and (TxState = SendData or TxState = SendCntr))then
			packet_wc(11 downto 0) <= packet_wc(11 downto 0) + 1;
		end if;
		if(TxState = IDLE or TxState = SendK)then
			Init_TxCRC <= '1';
		else
			Init_TxCRC <= '0';
		end if;
		if(R_word_sent = '1')then
			R_word_cnt <= (others => '0');
		else
			R_word_cnt <= R_word_cnt + 1;
		end if;
	end if;
end process;
i_TxCRC: crc16D16 PORT MAP(
		clk => UsrClk,
		init_crc => Init_TxCRC,
		we_crc => we_TxCRC,
		d => TxFIFO_Di(15 downto 0),
		crc => TxCRC
	);
we_TxCRC <= not TxFIFO_Di(16) and we_TxFIFO;
-- received data processing starts here
process(UsrClk)
begin
	if(UsrClk'event and UsrClk = '1')then
-- Comma ends a packet and after that, any D-word marks the beginning of a packet
		if(RXCHARISCOMMA_q  = "11" or (L1Ainfo_wa(1 downto 0) = "11" and L1Ainfo_WrEn = '1'))then
			L1Ainfo <= '0';
		elsif(RXCHARISK_q = "00" and Header2 = '1' and Ready_i = '1' and TypeData = '1')then
			L1Ainfo <= '1';
		end if;
		if(RXCHARISCOMMA_q  = "11")then
			Receiving <= '0';
		elsif(RXCHARISK_q = "00")then
			Receiving <= '1';
		end if;
-- first word of a packet is the packet sequence number
		if(rst_wait = '1')then
			bad_K <= '1';
		elsif(RXCHARISK_q = "00")then
			if(Receiving = '0')then
				bad_K <= '0';
				RxSEQNUM <= RXDATA_q(15 downto 8);
				if(RXDATA_q(7 downto 0) = InitRqst)then
					TypeInit <= '1';
				else
					TypeInit <= '0';
				end if;
				if(RXDATA_q(7 downto 0) = Acknowledge)then
					TypeACK <= '1';
				else
					TypeACK <= '0';
				end if;
				if(RXDATA_q(7 downto 0) = data)then
					TypeData <= '1';
				else
					TypeData <= '0';
				end if;
				if(RXDATA_q(7 downto 0) = Counter)then
					TypeCntr <= '1';
				else
					TypeCntr <= '0';
				end if;
				Header2 <= '1';
			else
				Header2 <= '0';
			end if;
			if(Header2 = '1')then
				RxType <= RXDATA_q;
				RxWC <= "000";
			else
				RxWC <= RxWC + 1;
			end if;
			if(RxWC = RXDATA_q(2 downto 0))then
				WC_OKp <= '1';
			else
				WC_OKp <= '0';
			end if;
			WC_OK <= WC_OKp;
		elsif(RXDATA_q(7 downto 0) = x"5c" and RXCHARISK_q = "01")then
-- acknowledge of TTS data, this will be processed by TTS_TRIG_if
		elsif((RXDATA_q /= R_word and RXCHARISCOMMA_q /= "11") or RXCHARISK_q(1) /= RXCHARISK_q(0))then
			bad_K <= '1';
		end if;
		if(Receiving = '0')then
			ACKNUM_IN <= RxSEQNUM;
		end if;
		if(TypeACK = '1' and RXType(15 downto 8) = ReSendQueOut(22 downto 15) and ReSendQue_empty = '0')then -- incoming acknowledge number is what waited for
			ACK_OK <= '1';
		else
			ACK_OK <= '0';
		end if;
		if(InitLink = '1')then
			AMC_ID <= RxType(7 downto 0);
		end if;
		if((RxSEQNUM = NextSEQNUM and TypeInit = '0') or (RxSEQNUM = x"00" and TypeInit = '1'))then -- incoming sequence number is what waited for 
			SEQ_OK <= '1';
		else
			SEQ_OK <= '0';
		end if;
		if(WC_OK = '1' and (TypeInit = '1' or TypeCntr = '1' or TypeData = '1' or TypeACK = '1'))then
			frame_OK <= '1';
		else
			frame_OK <= '0';
		end if;
		if(or_reduce(RxCRC) = '0')then
			CRC_OK <= '1';
		else
			CRC_OK <= '0';
		end if;
		if(RXCHARISCOMMA_q = "11" and Receiving = '1')then
			check_packet <= '1';
		else
			check_packet <= '0';
		end if;
		accept <= check_packet and SEQ_OK and CRC_OK and frame_OK and not bad_K and not ACKNUM_full and (TypeInit or TypeData);
-- acknowledge even received packet is not the expected one
		we_ACKNUM <= check_packet and CRC_OK and frame_OK and not bad_K and not ACKNUM_full and (TypeInit or TypeData);
		ACK <= check_packet and SEQ_OK and ACK_OK and CRC_OK and frame_OK and not bad_K;
		CntrACK <= check_packet and TypeCntr and CRC_OK and frame_OK and not bad_K;
		L1Aabort <= check_packet and TypeData and not(SEQ_OK and CRC_OK and frame_OK and not bad_K and not ACKNUM_full);
		if(reset_sync(3) = '1')then
			ACKNUM_a <= (others => '1');
		elsif(InitLink = '1')then
			ACKNUM_a <= (others => '0');
		elsif(we_ACKNUM = '1' and (TxFIFO_full = '1' or TxState /= SendCRC or IsACK = '0'))then
			ACKNUM_a <= ACKNUM_a + 1;
		elsif(we_ACKNUM = '0' and TxFIFO_full = '0' and TxState = SendCRC and IsACK = '1')then
			ACKNUM_a <= ACKNUM_a - 1;
		end if;
		if(InitLink = '1')then
			NextSEQNUM <= x"01";
		elsif(accept = '1')then
			NextSEQNUM <= NextSEQNUM(6 downto 0) & not(NextSEQNUM(7) xor NextSEQNUM(5) xor NextSEQNUM(4) xor NextSEQNUM(3));
		end if;
		if(ACKNUM_a = "11")then
			ACKNUM_empty <= '1';
		else
			ACKNUM_empty <= '0';
		end if;
		if(ACKNUM_a = "10")then
			ACKNUM_full <= '1';
		else
			ACKNUM_full <= '0';
		end if;
		if(ACKNUM_a /= "11")then
			ACKNUM_l <= ACKNUM;
		end if;
		if(InitLink = '1')then
			cntr0 <= (others => '0');
		elsif(accept = '1')then
			cntr0 <= cntr0 + 1;
		end if;
		if(InitLink = '1')then
			cntr1 <= (others => '0');
		elsif(ACK = '1')then
			cntr1 <= cntr1 + 1;
		end if;
		if(InitLink = '1')then
			cntr2 <= (others => '0');
			cntr10 <= (others => '0');
			cntr11 <= (others => '0');
			cntr12 <= (others => '0');
			cntr13 <= (others => '0');
			cntr14 <= (others => '0');
		elsif(L1Aabort = '1')then
			cntr2 <= cntr2 + 1;
			if(SEQ_OK = '0')then
				cntr10 <= cntr10 + 1;
			end if;
			if(CRC_OK = '0')then
				cntr11 <= cntr11 + 1;
			end if;
			if(frame_OK = '0')then
				cntr12 <= cntr12 + 1;
			end if;
			if(bad_K = '1')then
				cntr13 <= cntr13 + 1;
			end if;
			if(ACKNUM_full = '1')then
				cntr14 <= cntr14 + 1;
			end if;
		end if;
		if(InitLink = '1')then
			cntr15 <= (others => '0');
		elsif(DataFIFO_RdEnp = '1' and DataFIFO_do(64) = '1' and ChkEvtLen(1) = '0')then
			cntr15 <= cntr15 + 1;
		end if;
		if(InitLink = '1')then
			cntr3 <= (others => '0');
			cntr4 <= (others => '0');
			cntr5 <= (others => '0');
			cntr6 <= (others => '0');
		elsif(we_EventStatus = '1')then
			if(EventStatus_Di(0) = '0')then
				cntr3 <= cntr3 + 1;
			end if;
			if(EventStatus_Di(1) = '0')then
				cntr4 <= cntr4 + 1;
			end if;
			if(EventStatus_Di(2) = '0')then
				cntr5 <= cntr5 + 1;
			end if;
			cntr6 <= cntr6 + 1;
		end if;
		if(InitLink = '1')then
			cntr7 <= (others => '0');
		elsif(CntrACK = '1')then
			cntr7 <= cntr7 + 1;
		end if;
		if(InitLink = '1')then
			cntr8 <= (others => '0');
		elsif(ReSend = '1')then
			cntr8 <= cntr8 + 1;
		end if;
		if(InitLink = '1')then
			cntr9 <= (others => '0');
		elsif(bad_EventLength = '1')then
			cntr9 <= cntr9 + 1;
		end if;
		if(InitLink = '1')then
			cntra <= (others => '0');
		elsif(EoE = '1' and UsrClkDiv(1) = '1' and bad_ID = '1')then
			cntra <= cntra + 1;
		end if;
		AlmostFull_sync <= AlmostFull_sync(1 downto 0) & AlmostFull_i;
		if(InitLink = '1')then
			cntrb <= (others => '0');
		elsif(AlmostFull_sync(2) = '1')then
			cntrb <= cntrb + 1;
		end if;
		if(ready_i = '0' or CntrACK = '1')then
			CntrSent <= '0';
		elsif(TxState = SendCRC and IsCntr = '1')then
			CntrSent <= '1';
		end if;
		if(ready_i = '0' or CntrACK = '1' or (TxState = SendCRC and IsCntr = '1'))then
			cntr_timer <= (others => '0');
		elsif(CntrTimeout = '0')then
			cntr_timer <= cntr_timer + 1;
		end if;
		if(CntrSent = '1')then
			CntrTimeout <= cntr_timer(8);
		elsif(simulation)then
			CntrTimeout <= cntr_timer(8);
		else
			CntrTimeout <= cntr_timer(15);
		end if;
		if(TxState = SendCRC and IsCntr = '1')then
			sample <= not sample;
		end if;
	end if;
end process;
i_RxCRC: crc16D16 PORT MAP(
		clk => UsrClk,
		init_crc => Init_RxCRC,
		we_crc => we_RxCRC,
		d => RXDATA_q,
		crc => RxCRC
	);
we_RxCRC <= '1' when RXCHARISK_q = "00" else '0';
Init_RxCRC <= '1' when RXCHARISCOMMA_q = "11" else '0';
g_ACKNUM : for i in 0 to 7 generate
   i_ACKNUM : SRL16E
   port map (
      Q => ACKNUM(i),       -- SRL data output
      A0 => ACKNUM_a(0),     -- Select[0] input
      A1 => ACKNUM_a(1),     -- Select[1] input
      A2 => '0',     -- Select[2] input
      A3 => '0',     -- Select[3] input
      CE => we_ACKNUM,     -- Clock enable input
      CLK => UsrClk,   -- Clock input
      D => ACKNUM_IN(i)        -- SRL data input
   );
end generate;
process(UsrClk)
begin
	if(UsrClk'event and UsrClk = '1')then
		if(Init_EventCRC = '1')then
			AMCinfo_sel <= "010";
		elsif(FillDataBuf = '1')then
			case AMCinfo_sel is
				when "010" => AMCinfo_sel <= "100";
				when "100" => AMCinfo_sel <= "101";
				when "101" => AMCinfo_sel <= "110";
				when "110" => AMCinfo_sel <= "011";
				when "011" => AMCinfo_sel <= "111";
				when others => AMCinfo_sel <= "000";
			end case;
--			end if;
		end if;
--		AMCinfo_WrEn <= FillDataBuf and AMCinfo_sel(2);
		AMCinfo_WrEn <= DataBuf_WrEn and AMCinfo_sel(2);
		case AMCinfo_sel(1 downto 0) is
			when "00" => AMCinfo_Di <= DataBuf_Din(15 downto 4) & x"0";-- BX
			when "01" => AMCinfo_Di <= DataBuf_Din(15 downto 0);--evn(15 downto 0)
			when "10" => AMCinfo_Di <= x"00" & DataBuf_Din(7 downto 0);--evn(23 downto 16)
			when others => AMCinfo_Di <= DataBuf_Din(15 downto 0);--OrN(15 downto 0)
		end case;
		if(InitLink = '1')then
			AMCinfo_wa <= (others => '0');
		elsif(AMCinfo_WrEn = '1')then
			AMCinfo_wa <= AMCinfo_wa + 1;
		end if;
	end if;
end process;
i_AMCinfo : BRAM_SDP_MACRO
   generic map (
      BRAM_SIZE => "18Kb", -- Target BRAM, "18Kb" or "36Kb" 
      DEVICE => "VIRTEX6", -- Target device: "VIRTEX5", "VIRTEX6", "SPARTAN6" 
      WRITE_WIDTH => 16,    -- Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
      READ_WIDTH => 16)     -- Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
    port map (
      DO => AMCinfo_Do,         -- Output read data port, width defined by READ_WIDTH parameter
      DI => AMCinfo_Di,         -- Input write data port, width defined by WRITE_WIDTH parameter
      RDADDR => info_ra, -- Input read address, width defined by read port depth
      RDCLK => UsrClk,   -- 1-bit input read clock
      RDEN => '1',     -- 1-bit input read port enable
      REGCE => '1',   -- 1-bit input read output register enable
      RST => '0',       -- 1-bit input reset 
      WE => "11",         -- Input write enable, width defined by write port depth
      WRADDR => AMCinfo_wa, -- Input write address, width defined by write port depth
      WRCLK => UsrClk,   -- 1-bit input write clock
      WREN => AMCinfo_WrEn      -- 1-bit input write port enable
   );
process(UsrClk)
begin
	if(UsrClk'event and UsrClk = '1')then
		L1Ainfo_Di <= RXDATA_q;
		if(InitLink = '1')then
			OldL1Ainfo_wa <= (others => '0');
		elsif(accept = '1')then
			OldL1Ainfo_wa <= L1Ainfo_wa(9 downto 2);
		end if;
		if(InitLink = '1')then
			L1Ainfo_wa <= (others => '0');
		elsif(L1Aabort = '1')then
			L1Ainfo_wa(9 downto 2) <= OldL1Ainfo_wa;
		elsif(Receiving = '0')then
			L1Ainfo_wa(1 downto 0) <= "00";
		elsif(L1Ainfo_WrEn = '1')then
			L1Ainfo_wa <= L1Ainfo_wa + 1;
		end if;
		if(L1Ainfo = '1' and RXCHARISK_q = "00" and (L1Ainfo_wa(1 downto 0) /= "11" or L1Ainfo_WrEn = '0'))then
			L1Ainfo_WrEn <= '1';
		else
			L1Ainfo_WrEn <= '0';
		end if;
	end if;
end process;
i_L1Ainfo : BRAM_SDP_MACRO
   generic map (
      BRAM_SIZE => "18Kb", -- Target BRAM, "18Kb" or "36Kb" 
      DEVICE => "VIRTEX6", -- Target device: "VIRTEX5", "VIRTEX6", "SPARTAN6" 
      WRITE_WIDTH => 16,    -- Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
      READ_WIDTH => 16)     -- Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
    port map (
      DO => L1Ainfo_Do,         -- Output read data port, width defined by READ_WIDTH parameter
      DI => L1Ainfo_Di,         -- Input write data port, width defined by WRITE_WIDTH parameter
      RDADDR => info_ra, -- Input read address, width defined by read port depth
      RDCLK => UsrClk,   -- 1-bit input read clock
      RDEN => '1',     -- 1-bit input read port enable
      REGCE => '1',   -- 1-bit input read output register enable
      RST => '0',       -- 1-bit input reset 
      WE => "11",         -- Input write enable, width defined by write port depth
      WRADDR => L1Ainfo_wa, -- Input write address, width defined by write port depth
      WRCLK => UsrClk,   -- 1-bit input write clock
      WREN => L1Ainfo_WrEn      -- 1-bit input write port enable
   );
process(TTSclk)
begin
	if(TTSclk'event and TTSclk = '1')then
		if(InitLink = '1')then
			CriticalTTS <= "000";
		else
			if(TTS = x"0" or TTS = x"f")then
				CriticalTTS(2) <= '1';
			end if;
			if(TTS = x"c")then
				CriticalTTS(1) <= '1';
			end if;
			if(TTS = x"2")then
				CriticalTTS(0) <= '1';
			end if;
		end if;
	end if;
end process;
i_TTS_TRIG_if: TTS_TRIG_if
	PORT MAP(
		reset => reset,
		USE_TRIGGER_PORT => USE_TRIGGER_PORT,
		UsrClk => UsrClk,
		TTCclk => TTCclk,
		BcntRes => BcntRes,
		trig => trig,
		TTSclk => TTSclk,
		TTS => TTS,
		RXCHARISK => RXCHARISK,
		RXDATA => RXDATA,
		sel_TTS_TRIG => sel_TTS_TRIG,
		TTS_TRIG_data => TTS_TRIG_data
	);
process(UsrClk)
begin
	if(UsrClk'event and UsrClk = '1')then
		if(info_ra(9 downto 2) = OldL1Ainfo_wa or check_L1Ainfo = '1')then
			L1Ainfo_empty <= '1';
		elsif(RxL1Ainfo = '0')then
			L1Ainfo_empty <= '0';
		end if;
		if(Header2 = '1' and TypeData = '1')then
			RxL1Ainfo <= '1';
		elsif(accept = '1' or L1Aabort = '1')then
			RxL1Ainfo <= '0';
		end if;
		if(info_ra(9 downto 2) = AMCinfo_wa(9 downto 2) or check_L1Ainfo = '1')then
			AMCinfo_empty <= '1';
		else
			AMCinfo_empty <= '0';
		end if;
		if(info_ra(1 downto 0) = "11")then
			ce_info_ra <= '0';
		elsif(EventStatusCnt(4 downto 3) /= "11" and L1Ainfo_empty = '0' and AMCinfo_empty = '0')then
			ce_info_ra <= '1';
		end if;
		if(InitLink = '1')then
			info_ra <= (others => '0');
		elsif(ce_info_ra = '1')then
			info_ra <= info_ra + 1;
		end if;
		check_L1Ainfo <= ce_info_ra;
		check_L1Ainfo_q <= check_L1Ainfo;
		if(L1Ainfo_Do = AMCinfo_Do(15 downto 0))then
			L1AinfoMM <= '0';
		else
			L1AinfoMM <= '1';
		end if;
		we_EventStatus <= check_L1Ainfo_q and not check_L1Ainfo;
		info_ra_q <= info_ra(1 downto 0);
		info_ra_q2 <= info_ra_q;
		if(check_L1Ainfo_q = '0')then
			EventStatus_Di(2 downto 0) <= "111";
		elsif(L1AinfoMM = '1')then
			case info_ra_q2 is
				when "00" => EventStatus_Di(2) <= '0'; -- BcN mismatch
				when "11" => EventStatus_Di(1) <= '0'; -- OrN mismatch
				when others => EventStatus_Di(0) <= '0'; -- EvN mismatch
			end case;
		end if;
		EventStatusCnt <= EventStatus_wa - EventStatus_ra;
		if(EventStatus_wa = EventStatus_ra)then
			EventStatus_empty <= '1';
		else
			EventStatus_empty <= '0';
		end if;
		if(Ready_i = '0' or InitLink = '1')then
			EventStatus_wa <= (others => '0');
		elsif(we_EventStatus = '1')then
			EventStatus_wa <= EventStatus_wa + 1;
		end if;
	end if;
end process;
g_EventStatus : for i in 0 to 2 generate
   i_EventStatus : RAM32X1D
   port map (
      DPO => EventStatus(i),     -- Read-only 1-bit data output
      SPO => open,     -- R/W 1-bit data output
      A0 => EventStatus_wa(0),       -- R/W address[0] input bit
      A1 => EventStatus_wa(1),       -- R/W address[1] input bit
      A2 => EventStatus_wa(2),       -- R/W address[2] input bit
      A3 => EventStatus_wa(3),       -- R/W address[3] input bit
      A4 => EventStatus_wa(4),       -- R/W address[4] input bit
      D => EventStatus_Di(i),         -- Write 1-bit data input
      DPRA0 => EventStatus_ra(0), -- Read-only address[0] input bit
      DPRA1 => EventStatus_ra(1), -- Read-only address[1] input bit
      DPRA2 => EventStatus_ra(2), -- Read-only address[2] input bit
      DPRA3 => EventStatus_ra(3), -- Read-only address[3] input bit
      DPRA4 => EventStatus_ra(4), -- Read-only address[4] input bit
      WCLK => UsrClk,   -- Write clock input
      WE => we_EventStatus       -- Write enable input
   );
end generate;
EventStatus(6 downto 3) <= (others => '0');
EventStatus_ra <= RdEventCnt;
g_L1A_DATA: for i in 0 to 15 generate
  i_L1Adata : RAM32X1D
   port map (
      DPO => L1A_DATA_o(i),     -- Read-only 1-bit data output
      SPO => open,     -- R/W 1-bit data output
      A0 => L1Ainfo_wa(0),       -- R/W address[0] input bit
      A1 => L1Ainfo_wa(1),       -- R/W address[1] input bit
      A2 => L1Ainfo_wa(2),       -- R/W address[2] input bit
      A3 => L1Ainfo_wa(3),       -- R/W address[3] input bit
      A4 => L1Ainfo_wa(4),       -- R/W address[4] input bit
      D => L1Ainfo_Di(i),         -- Write 1-bit data input
      DPRA0 => L1A_DATA_ra(0), -- Read-only address[0] input bit
      DPRA1 => L1A_DATA_ra(1), -- Read-only address[1] input bit
      DPRA2 => L1A_DATA_ra(2), -- Read-only address[2] input bit
      DPRA3 => L1A_DATA_ra(3), -- Read-only address[3] input bit
      DPRA4 => L1A_DATA_ra(4), -- Read-only address[4] input bit
      WCLK => UsrClk,   -- Write clock input
      WE => L1Ainfo_WrEn        -- Write enable input
   );
end generate;
process(sysclk, InitLink)
begin
	if(InitLink = '1')then
		L1A_DATA_ra <= (others => '0');
		L1A_DATA_wa <= (others => '0');
		OldL1Ainfo_wa0_SyncRegs <= (others => '0');
		L1A_DATA_we <= '0';
		L1A_DATA <= (others => '0');
	elsif(sysclk'event and sysclk = '1')then
		OldL1Ainfo_wa0_SyncRegs <= OldL1Ainfo_wa0_SyncRegs(2 downto 0) & OldL1Ainfo_wa(0);
		if(OldL1Ainfo_wa0_SyncRegs(3) /= OldL1Ainfo_wa0_SyncRegs(2))then
			L1A_DATA_wa <= L1A_DATA_wa + 1;
		end if;
		if(L1A_DATA_ra(1 downto 0) = "11")then
			ce_L1A_DATA_ra <= '0';
		elsif(L1A_DATA_wa /= L1A_DATA_ra(4 downto 2))then
			ce_L1A_DATA_ra <= '1';
		end if;
		if(ce_L1A_DATA_ra = '1')then
			L1A_DATA_ra <= L1A_DATA_ra + 1;
		end if;
		L1A_DATA_we <= ce_L1A_DATA_ra;
		L1A_DATA <= L1A_DATA_o;
	end if;
end process;
end Behavioral;
