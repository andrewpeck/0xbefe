library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package common_pkg is

    --======================--
    --==      General     ==--
    --======================-- 

    constant C_LED_PULSE_LENGTH_TTC_CLK : std_logic_vector(20 downto 0) := std_logic_vector(to_unsigned(1_600_000, 21));
        
    function count_ones(s : std_logic_vector) return integer;
    function bool_to_std_logic(L : BOOLEAN) return std_logic;
    function log2ceil(arg : positive) return natural; -- returns the number of bits needed to encode the given number
    function up_to_power_of_2(arg : positive) return natural; -- "rounds" the given number up to the closest power of 2 number (e.g. if you give 6, it will say 8, which is 2^3)
    function div_ceil(numerator, denominator : positive) return natural; -- poor man's division, rounding up to the closest integer

    --============--
    --== Common ==--
    --============--   
    
    type t_std_array is array(integer range <>) of std_logic;

    type t_std2_array is array(integer range <>) of std_logic_vector(1 downto 0);
    type t_std3_array is array(integer range <>) of std_logic_vector(2 downto 0);
    type t_std4_array is array(integer range <>) of std_logic_vector(3 downto 0);
    type t_std5_array is array(integer range <>) of std_logic_vector(4 downto 0);
    type t_std6_array is array(integer range <>) of std_logic_vector(5 downto 0);
    type t_std7_array is array(integer range <>) of std_logic_vector(6 downto 0);
    type t_std8_array is array(integer range <>) of std_logic_vector(7 downto 0);
    type t_std9_array is array(integer range <>) of std_logic_vector(8 downto 0);
    type t_std10_array is array(integer range <>) of std_logic_vector(9 downto 0);
    type t_std11_array is array(integer range <>) of std_logic_vector(10 downto 0);
    type t_std12_array is array(integer range <>) of std_logic_vector(11 downto 0);
    type t_std13_array is array(integer range <>) of std_logic_vector(12 downto 0);
    type t_std14_array is array(integer range <>) of std_logic_vector(13 downto 0);
    type t_std15_array is array(integer range <>) of std_logic_vector(14 downto 0);
    type t_std16_array is array(integer range <>) of std_logic_vector(15 downto 0);
    type t_std17_array is array(integer range <>) of std_logic_vector(16 downto 0);
    type t_std18_array is array(integer range <>) of std_logic_vector(17 downto 0);
    type t_std19_array is array(integer range <>) of std_logic_vector(18 downto 0);
    type t_std20_array is array(integer range <>) of std_logic_vector(19 downto 0);
    type t_std21_array is array(integer range <>) of std_logic_vector(20 downto 0);
    type t_std22_array is array(integer range <>) of std_logic_vector(21 downto 0);
    type t_std23_array is array(integer range <>) of std_logic_vector(22 downto 0);
    type t_std24_array is array(integer range <>) of std_logic_vector(23 downto 0);
    type t_std25_array is array(integer range <>) of std_logic_vector(24 downto 0);
    type t_std26_array is array(integer range <>) of std_logic_vector(25 downto 0);
    type t_std27_array is array(integer range <>) of std_logic_vector(26 downto 0);
    type t_std28_array is array(integer range <>) of std_logic_vector(27 downto 0);
    type t_std29_array is array(integer range <>) of std_logic_vector(28 downto 0);
    type t_std30_array is array(integer range <>) of std_logic_vector(29 downto 0);
    type t_std31_array is array(integer range <>) of std_logic_vector(30 downto 0);
    type t_std32_array is array(integer range <>) of std_logic_vector(31 downto 0);
    type t_std33_array is array(integer range <>) of std_logic_vector(32 downto 0);
    type t_std34_array is array(integer range <>) of std_logic_vector(33 downto 0);
    type t_std35_array is array(integer range <>) of std_logic_vector(34 downto 0);
    type t_std36_array is array(integer range <>) of std_logic_vector(35 downto 0);
    type t_std37_array is array(integer range <>) of std_logic_vector(36 downto 0);
    type t_std38_array is array(integer range <>) of std_logic_vector(37 downto 0);
    type t_std39_array is array(integer range <>) of std_logic_vector(38 downto 0);
    type t_std40_array is array(integer range <>) of std_logic_vector(39 downto 0);
    type t_std41_array is array(integer range <>) of std_logic_vector(40 downto 0);
    type t_std42_array is array(integer range <>) of std_logic_vector(41 downto 0);
    type t_std43_array is array(integer range <>) of std_logic_vector(42 downto 0);
    type t_std44_array is array(integer range <>) of std_logic_vector(43 downto 0);
    type t_std45_array is array(integer range <>) of std_logic_vector(44 downto 0);
    type t_std46_array is array(integer range <>) of std_logic_vector(45 downto 0);
    type t_std47_array is array(integer range <>) of std_logic_vector(46 downto 0);
    type t_std48_array is array(integer range <>) of std_logic_vector(47 downto 0);
    type t_std49_array is array(integer range <>) of std_logic_vector(48 downto 0);
    type t_std50_array is array(integer range <>) of std_logic_vector(49 downto 0);
    type t_std51_array is array(integer range <>) of std_logic_vector(50 downto 0);
    type t_std52_array is array(integer range <>) of std_logic_vector(51 downto 0);
    type t_std53_array is array(integer range <>) of std_logic_vector(52 downto 0);
    type t_std54_array is array(integer range <>) of std_logic_vector(53 downto 0);
    type t_std55_array is array(integer range <>) of std_logic_vector(54 downto 0);
    type t_std56_array is array(integer range <>) of std_logic_vector(55 downto 0);
    type t_std57_array is array(integer range <>) of std_logic_vector(56 downto 0);
    type t_std58_array is array(integer range <>) of std_logic_vector(57 downto 0);
    type t_std59_array is array(integer range <>) of std_logic_vector(58 downto 0);
    type t_std60_array is array(integer range <>) of std_logic_vector(59 downto 0);
    type t_std61_array is array(integer range <>) of std_logic_vector(60 downto 0);
    type t_std62_array is array(integer range <>) of std_logic_vector(61 downto 0);
    type t_std63_array is array(integer range <>) of std_logic_vector(62 downto 0);
    type t_std64_array is array(integer range <>) of std_logic_vector(63 downto 0);
    type t_std65_array is array(integer range <>) of std_logic_vector(64 downto 0);
    type t_std66_array is array(integer range <>) of std_logic_vector(65 downto 0);
    type t_std67_array is array(integer range <>) of std_logic_vector(66 downto 0);
    type t_std68_array is array(integer range <>) of std_logic_vector(67 downto 0);
    type t_std69_array is array(integer range <>) of std_logic_vector(68 downto 0);
    type t_std70_array is array(integer range <>) of std_logic_vector(69 downto 0);
    type t_std71_array is array(integer range <>) of std_logic_vector(70 downto 0);
    type t_std72_array is array(integer range <>) of std_logic_vector(71 downto 0);
    type t_std73_array is array(integer range <>) of std_logic_vector(72 downto 0);
    type t_std74_array is array(integer range <>) of std_logic_vector(73 downto 0);
    type t_std75_array is array(integer range <>) of std_logic_vector(74 downto 0);
    type t_std76_array is array(integer range <>) of std_logic_vector(75 downto 0);
    type t_std77_array is array(integer range <>) of std_logic_vector(76 downto 0);
    type t_std78_array is array(integer range <>) of std_logic_vector(77 downto 0);
    type t_std79_array is array(integer range <>) of std_logic_vector(78 downto 0);
    type t_std80_array is array(integer range <>) of std_logic_vector(79 downto 0);
    type t_std81_array is array(integer range <>) of std_logic_vector(80 downto 0);
    type t_std82_array is array(integer range <>) of std_logic_vector(81 downto 0);
    type t_std83_array is array(integer range <>) of std_logic_vector(82 downto 0);
    type t_std84_array is array(integer range <>) of std_logic_vector(83 downto 0);
    type t_std85_array is array(integer range <>) of std_logic_vector(84 downto 0);
    type t_std86_array is array(integer range <>) of std_logic_vector(85 downto 0);
    type t_std87_array is array(integer range <>) of std_logic_vector(86 downto 0);
    type t_std88_array is array(integer range <>) of std_logic_vector(87 downto 0);
    type t_std89_array is array(integer range <>) of std_logic_vector(88 downto 0);
    type t_std90_array is array(integer range <>) of std_logic_vector(89 downto 0);
    type t_std91_array is array(integer range <>) of std_logic_vector(90 downto 0);
    type t_std92_array is array(integer range <>) of std_logic_vector(91 downto 0);
    type t_std93_array is array(integer range <>) of std_logic_vector(92 downto 0);
    type t_std94_array is array(integer range <>) of std_logic_vector(93 downto 0);
    type t_std95_array is array(integer range <>) of std_logic_vector(94 downto 0);
    type t_std96_array is array(integer range <>) of std_logic_vector(95 downto 0);
    type t_std97_array is array(integer range <>) of std_logic_vector(96 downto 0);
    type t_std98_array is array(integer range <>) of std_logic_vector(97 downto 0);
    type t_std99_array is array(integer range <>) of std_logic_vector(98 downto 0);
    type t_std100_array is array(integer range <>) of std_logic_vector(99 downto 0);
    type t_std101_array is array(integer range <>) of std_logic_vector(100 downto 0);
    type t_std102_array is array(integer range <>) of std_logic_vector(101 downto 0);
    type t_std103_array is array(integer range <>) of std_logic_vector(102 downto 0);
    type t_std104_array is array(integer range <>) of std_logic_vector(103 downto 0);
    type t_std105_array is array(integer range <>) of std_logic_vector(104 downto 0);
    type t_std106_array is array(integer range <>) of std_logic_vector(105 downto 0);
    type t_std107_array is array(integer range <>) of std_logic_vector(106 downto 0);
    type t_std108_array is array(integer range <>) of std_logic_vector(107 downto 0);
    type t_std109_array is array(integer range <>) of std_logic_vector(108 downto 0);
    type t_std110_array is array(integer range <>) of std_logic_vector(109 downto 0);
    type t_std111_array is array(integer range <>) of std_logic_vector(110 downto 0);
    type t_std112_array is array(integer range <>) of std_logic_vector(111 downto 0);
    type t_std113_array is array(integer range <>) of std_logic_vector(112 downto 0);
    type t_std114_array is array(integer range <>) of std_logic_vector(113 downto 0);
    type t_std115_array is array(integer range <>) of std_logic_vector(114 downto 0);
    type t_std116_array is array(integer range <>) of std_logic_vector(115 downto 0);
    type t_std117_array is array(integer range <>) of std_logic_vector(116 downto 0);
    type t_std118_array is array(integer range <>) of std_logic_vector(117 downto 0);
    type t_std119_array is array(integer range <>) of std_logic_vector(118 downto 0);
    type t_std120_array is array(integer range <>) of std_logic_vector(119 downto 0);
    type t_std121_array is array(integer range <>) of std_logic_vector(120 downto 0);
    type t_std122_array is array(integer range <>) of std_logic_vector(121 downto 0);
    type t_std123_array is array(integer range <>) of std_logic_vector(122 downto 0);
    type t_std124_array is array(integer range <>) of std_logic_vector(123 downto 0);
    type t_std125_array is array(integer range <>) of std_logic_vector(124 downto 0);
    type t_std126_array is array(integer range <>) of std_logic_vector(125 downto 0);
    type t_std127_array is array(integer range <>) of std_logic_vector(126 downto 0);
    type t_std128_array is array(integer range <>) of std_logic_vector(127 downto 0);
    type t_std129_array is array(integer range <>) of std_logic_vector(128 downto 0);
    type t_std130_array is array(integer range <>) of std_logic_vector(129 downto 0);
    type t_std131_array is array(integer range <>) of std_logic_vector(130 downto 0);
    type t_std132_array is array(integer range <>) of std_logic_vector(131 downto 0);
    type t_std133_array is array(integer range <>) of std_logic_vector(132 downto 0);
    type t_std134_array is array(integer range <>) of std_logic_vector(133 downto 0);
    type t_std135_array is array(integer range <>) of std_logic_vector(134 downto 0);
    type t_std136_array is array(integer range <>) of std_logic_vector(135 downto 0);
    type t_std137_array is array(integer range <>) of std_logic_vector(136 downto 0);
    type t_std138_array is array(integer range <>) of std_logic_vector(137 downto 0);
    type t_std139_array is array(integer range <>) of std_logic_vector(138 downto 0);
    type t_std140_array is array(integer range <>) of std_logic_vector(139 downto 0);
    type t_std141_array is array(integer range <>) of std_logic_vector(140 downto 0);
    type t_std142_array is array(integer range <>) of std_logic_vector(141 downto 0);
    type t_std143_array is array(integer range <>) of std_logic_vector(142 downto 0);
    type t_std144_array is array(integer range <>) of std_logic_vector(143 downto 0);
    type t_std145_array is array(integer range <>) of std_logic_vector(144 downto 0);
    type t_std146_array is array(integer range <>) of std_logic_vector(145 downto 0);
    type t_std147_array is array(integer range <>) of std_logic_vector(146 downto 0);
    type t_std148_array is array(integer range <>) of std_logic_vector(147 downto 0);
    type t_std149_array is array(integer range <>) of std_logic_vector(148 downto 0);
    type t_std150_array is array(integer range <>) of std_logic_vector(149 downto 0);
    type t_std151_array is array(integer range <>) of std_logic_vector(150 downto 0);
    type t_std152_array is array(integer range <>) of std_logic_vector(151 downto 0);
    type t_std153_array is array(integer range <>) of std_logic_vector(152 downto 0);
    type t_std154_array is array(integer range <>) of std_logic_vector(153 downto 0);
    type t_std155_array is array(integer range <>) of std_logic_vector(154 downto 0);
    type t_std156_array is array(integer range <>) of std_logic_vector(155 downto 0);
    type t_std157_array is array(integer range <>) of std_logic_vector(156 downto 0);
    type t_std158_array is array(integer range <>) of std_logic_vector(157 downto 0);
    type t_std159_array is array(integer range <>) of std_logic_vector(158 downto 0);
    type t_std160_array is array(integer range <>) of std_logic_vector(159 downto 0);
    type t_std161_array is array(integer range <>) of std_logic_vector(160 downto 0);
    type t_std162_array is array(integer range <>) of std_logic_vector(161 downto 0);
    type t_std163_array is array(integer range <>) of std_logic_vector(162 downto 0);
    type t_std164_array is array(integer range <>) of std_logic_vector(163 downto 0);
    type t_std165_array is array(integer range <>) of std_logic_vector(164 downto 0);
    type t_std166_array is array(integer range <>) of std_logic_vector(165 downto 0);
    type t_std167_array is array(integer range <>) of std_logic_vector(166 downto 0);
    type t_std168_array is array(integer range <>) of std_logic_vector(167 downto 0);
    type t_std169_array is array(integer range <>) of std_logic_vector(168 downto 0);
    type t_std170_array is array(integer range <>) of std_logic_vector(169 downto 0);
    type t_std171_array is array(integer range <>) of std_logic_vector(170 downto 0);
    type t_std172_array is array(integer range <>) of std_logic_vector(171 downto 0);
    type t_std173_array is array(integer range <>) of std_logic_vector(172 downto 0);
    type t_std174_array is array(integer range <>) of std_logic_vector(173 downto 0);
    type t_std175_array is array(integer range <>) of std_logic_vector(174 downto 0);
    type t_std176_array is array(integer range <>) of std_logic_vector(175 downto 0);
    type t_std177_array is array(integer range <>) of std_logic_vector(176 downto 0);
    type t_std178_array is array(integer range <>) of std_logic_vector(177 downto 0);
    type t_std179_array is array(integer range <>) of std_logic_vector(178 downto 0);
    type t_std180_array is array(integer range <>) of std_logic_vector(179 downto 0);
    type t_std181_array is array(integer range <>) of std_logic_vector(180 downto 0);
    type t_std182_array is array(integer range <>) of std_logic_vector(181 downto 0);
    type t_std183_array is array(integer range <>) of std_logic_vector(182 downto 0);
    type t_std184_array is array(integer range <>) of std_logic_vector(183 downto 0);
    type t_std185_array is array(integer range <>) of std_logic_vector(184 downto 0);
    type t_std186_array is array(integer range <>) of std_logic_vector(185 downto 0);
    type t_std187_array is array(integer range <>) of std_logic_vector(186 downto 0);
    type t_std188_array is array(integer range <>) of std_logic_vector(187 downto 0);
    type t_std189_array is array(integer range <>) of std_logic_vector(188 downto 0);
    type t_std190_array is array(integer range <>) of std_logic_vector(189 downto 0);
    type t_std191_array is array(integer range <>) of std_logic_vector(190 downto 0);
    type t_std192_array is array(integer range <>) of std_logic_vector(191 downto 0);
    type t_std193_array is array(integer range <>) of std_logic_vector(192 downto 0);
    type t_std194_array is array(integer range <>) of std_logic_vector(193 downto 0);
    type t_std195_array is array(integer range <>) of std_logic_vector(194 downto 0);
    type t_std196_array is array(integer range <>) of std_logic_vector(195 downto 0);
    type t_std197_array is array(integer range <>) of std_logic_vector(196 downto 0);
    type t_std198_array is array(integer range <>) of std_logic_vector(197 downto 0);
    type t_std199_array is array(integer range <>) of std_logic_vector(198 downto 0);
    type t_std200_array is array(integer range <>) of std_logic_vector(199 downto 0);
    type t_std201_array is array(integer range <>) of std_logic_vector(200 downto 0);
    type t_std202_array is array(integer range <>) of std_logic_vector(201 downto 0);
    type t_std203_array is array(integer range <>) of std_logic_vector(202 downto 0);
    type t_std204_array is array(integer range <>) of std_logic_vector(203 downto 0);
    type t_std205_array is array(integer range <>) of std_logic_vector(204 downto 0);
    type t_std206_array is array(integer range <>) of std_logic_vector(205 downto 0);
    type t_std207_array is array(integer range <>) of std_logic_vector(206 downto 0);
    type t_std208_array is array(integer range <>) of std_logic_vector(207 downto 0);
    type t_std209_array is array(integer range <>) of std_logic_vector(208 downto 0);
    type t_std210_array is array(integer range <>) of std_logic_vector(209 downto 0);
    type t_std211_array is array(integer range <>) of std_logic_vector(210 downto 0);
    type t_std212_array is array(integer range <>) of std_logic_vector(211 downto 0);
    type t_std213_array is array(integer range <>) of std_logic_vector(212 downto 0);
    type t_std214_array is array(integer range <>) of std_logic_vector(213 downto 0);
    type t_std215_array is array(integer range <>) of std_logic_vector(214 downto 0);
    type t_std216_array is array(integer range <>) of std_logic_vector(215 downto 0);
    type t_std217_array is array(integer range <>) of std_logic_vector(216 downto 0);
    type t_std218_array is array(integer range <>) of std_logic_vector(217 downto 0);
    type t_std219_array is array(integer range <>) of std_logic_vector(218 downto 0);
    type t_std220_array is array(integer range <>) of std_logic_vector(219 downto 0);
    type t_std221_array is array(integer range <>) of std_logic_vector(220 downto 0);
    type t_std222_array is array(integer range <>) of std_logic_vector(221 downto 0);
    type t_std223_array is array(integer range <>) of std_logic_vector(222 downto 0);
    type t_std224_array is array(integer range <>) of std_logic_vector(223 downto 0);
    type t_std225_array is array(integer range <>) of std_logic_vector(224 downto 0);
    type t_std226_array is array(integer range <>) of std_logic_vector(225 downto 0);
    type t_std227_array is array(integer range <>) of std_logic_vector(226 downto 0);
    type t_std228_array is array(integer range <>) of std_logic_vector(227 downto 0);
    type t_std229_array is array(integer range <>) of std_logic_vector(228 downto 0);
    type t_std230_array is array(integer range <>) of std_logic_vector(229 downto 0);
    type t_std231_array is array(integer range <>) of std_logic_vector(230 downto 0);
    type t_std232_array is array(integer range <>) of std_logic_vector(231 downto 0);
    type t_std233_array is array(integer range <>) of std_logic_vector(232 downto 0);
    type t_std234_array is array(integer range <>) of std_logic_vector(233 downto 0);
    type t_std235_array is array(integer range <>) of std_logic_vector(234 downto 0);
    type t_std236_array is array(integer range <>) of std_logic_vector(235 downto 0);
    type t_std237_array is array(integer range <>) of std_logic_vector(236 downto 0);
    type t_std238_array is array(integer range <>) of std_logic_vector(237 downto 0);
    type t_std239_array is array(integer range <>) of std_logic_vector(238 downto 0);
    type t_std240_array is array(integer range <>) of std_logic_vector(239 downto 0);
    type t_std241_array is array(integer range <>) of std_logic_vector(240 downto 0);
    type t_std242_array is array(integer range <>) of std_logic_vector(241 downto 0);
    type t_std243_array is array(integer range <>) of std_logic_vector(242 downto 0);
    type t_std244_array is array(integer range <>) of std_logic_vector(243 downto 0);
    type t_std245_array is array(integer range <>) of std_logic_vector(244 downto 0);
    type t_std246_array is array(integer range <>) of std_logic_vector(245 downto 0);
    type t_std247_array is array(integer range <>) of std_logic_vector(246 downto 0);
    type t_std248_array is array(integer range <>) of std_logic_vector(247 downto 0);
    type t_std249_array is array(integer range <>) of std_logic_vector(248 downto 0);
    type t_std250_array is array(integer range <>) of std_logic_vector(249 downto 0);
    type t_std251_array is array(integer range <>) of std_logic_vector(250 downto 0);
    type t_std252_array is array(integer range <>) of std_logic_vector(251 downto 0);
    type t_std253_array is array(integer range <>) of std_logic_vector(252 downto 0);
    type t_std254_array is array(integer range <>) of std_logic_vector(253 downto 0);
    type t_std255_array is array(integer range <>) of std_logic_vector(254 downto 0);
    type t_std256_array is array(integer range <>) of std_logic_vector(255 downto 0);

    --============--
    --==   GBT  ==--
    --============--   

    type t_gbt_frame_array is array(integer range <>) of std_logic_vector(83 downto 0);
    type t_gbt_wide_frame_array is array(integer range <>) of std_logic_vector(115 downto 0);

    type t_sync_fifo_status is record
        had_ovf         : std_logic;
        had_unf         : std_logic;
    end record;

    type t_gbt_link_status is record
        gbt_tx_ready                : std_logic;
        gbt_tx_had_not_ready        : std_logic;
        gbt_tx_gearbox_ready        : std_logic;
        gbt_rx_sync_status          : t_sync_fifo_status;
        gbt_rx_ready                : std_logic;
        gbt_rx_had_not_ready        : std_logic;
        gbt_rx_header_locked        : std_logic;
        gbt_rx_header_had_unlock    : std_logic;
        gbt_rx_gearbox_ready        : std_logic;
        gbt_rx_correction_cnt       : std_logic_vector(7 downto 0);
        gbt_rx_correction_flag      : std_logic;
        gbt_rx_num_bitslips         : std_logic_vector(7 downto 0);
    end record;

    type t_gbt_link_status_arr is array(integer range <>) of t_gbt_link_status;    

    --============--
    --==   LpGBT  ==--
    --============--   

    type t_lpgbt_tx_frame is record
        tx_data         : std_logic_vector(31 downto 0);
        tx_ec_data      : std_logic_vector(1 downto 0);
        tx_ic_data      : std_logic_vector(1 downto 0);
    end record;

    type t_lpgbt_rx_frame is record
        rx_data         : std_logic_vector(223 downto 0);
        rx_ec_data      : std_logic_vector(1 downto 0);
        rx_ic_data      : std_logic_vector(1 downto 0);
    end record;

    type t_lpgbt_tx_frame_array is array(integer range <>) of t_lpgbt_tx_frame;
    type t_lpgbt_rx_frame_array is array(integer range <>) of t_lpgbt_rx_frame;

    --========================--
    --==== MGT link types ====--
    --========================--

    type t_mgt_64b_tx_data is record
        txdata         : std_logic_vector(63 downto 0);
        txcharisk      : std_logic_vector(7 downto 0);
        txchardispmode : std_logic_vector(7 downto 0);
        txchardispval  : std_logic_vector(7 downto 0);
    end record;

    constant MGT_64B_TX_DATA_NULL : t_mgt_64b_tx_data := (txdata => (others => '0'), txcharisk => (others => '0'), txchardispmode => (others => '0'), txchardispval => (others => '0')); 

    type t_mgt_64b_rx_data is record
        rxdata          : std_logic_vector(63 downto 0);
        rxbyteisaligned : std_logic;
        rxbyterealign   : std_logic;
        rxcommadet      : std_logic;
        rxdisperr       : std_logic_vector(7 downto 0);
        rxnotintable    : std_logic_vector(7 downto 0);
        rxchariscomma   : std_logic_vector(7 downto 0);
        rxcharisk       : std_logic_vector(7 downto 0);
    end record;

    type t_mgt_64b_tx_data_arr is array(integer range <>) of t_mgt_64b_tx_data;
    type t_mgt_64b_rx_data_arr is array(integer range <>) of t_mgt_64b_rx_data;

    type t_mgt_32b_tx_data is record
        txdata         : std_logic_vector(31 downto 0);
        txcharisk      : std_logic_vector(3 downto 0);
        txchardispmode : std_logic_vector(3 downto 0);
        txchardispval  : std_logic_vector(3 downto 0);
    end record;

    type t_mgt_32b_rx_data is record
        rxdata          : std_logic_vector(31 downto 0);
        rxbyteisaligned : std_logic;
        rxbyterealign   : std_logic;
        rxcommadet      : std_logic;
        rxdisperr       : std_logic_vector(3 downto 0);
        rxnotintable    : std_logic_vector(3 downto 0);
        rxchariscomma   : std_logic_vector(3 downto 0);
        rxcharisk       : std_logic_vector(3 downto 0);
    end record;

    type t_mgt_32b_tx_data_arr is array(integer range <>) of t_mgt_32b_tx_data;
    type t_mgt_32b_rx_data_arr is array(integer range <>) of t_mgt_32b_rx_data;

    type t_mgt_16b_tx_data is record
        txdata         : std_logic_vector(15 downto 0);
        txcharisk      : std_logic_vector(1 downto 0);
        txchardispmode : std_logic_vector(1 downto 0);
        txchardispval  : std_logic_vector(1 downto 0);
    end record;

    constant MGT_16B_TX_DATA_NULL : t_mgt_16b_tx_data := (txdata => (others => '0'), txcharisk => (others => '0'), txchardispmode => (others => '0'), txchardispval => (others => '0'));

    type t_mgt_16b_rx_data is record
        rxdata          : std_logic_vector(15 downto 0);
        rxbyteisaligned : std_logic;
        rxbyterealign   : std_logic;
        rxcommadet      : std_logic;
        rxdisperr       : std_logic_vector(1 downto 0);
        rxnotintable    : std_logic_vector(1 downto 0);
        rxchariscomma   : std_logic_vector(1 downto 0);
        rxcharisk       : std_logic_vector(1 downto 0);
    end record;

    constant MGT_16B_RX_DATA_NULL : t_mgt_16b_rx_data := (rxdata => (others => '0'), rxbyteisaligned => '0', rxbyterealign => '0', rxcommadet => '0', rxdisperr => (others => '0'), rxnotintable => (others => '0'), rxchariscomma => (others => '0'), rxcharisk => (others => '0'));

    type t_mgt_16b_tx_data_arr is array(integer range <>) of t_mgt_16b_tx_data;
    type t_mgt_16b_rx_data_arr is array(integer range <>) of t_mgt_16b_rx_data;

    type t_mgt_ctrl is record
        txreset     : std_logic;
        rxreset     : std_logic;
        rxslide     : std_logic;
    end record;

    type t_mgt_ctrl_arr is array(integer range <>) of t_mgt_ctrl;

    type t_mgt_status is record
        tx_reset_done   : std_logic;
        rx_reset_done   : std_logic;
        tx_pll_locked   : std_logic;
        rx_pll_locked   : std_logic;
        rxbufstatus     : std_logic_vector(2 downto 0);
        rxclkcorcnt     : std_logic_vector(1 downto 0);
    end record;

    constant MGT_STATUS_NULL : t_mgt_status := (tx_reset_done => '0', rx_reset_done => '0', tx_pll_locked => '0', rx_pll_locked => '0', rxbufstatus => "000", rxclkcorcnt => "00");

    type t_mgt_status_arr is array(integer range <>) of t_mgt_status;

    --====================--
    --==     DAQLink    ==--
    --====================--

    type t_daq_to_daqlink is record
        reset           : std_logic;
        ttc_clk         : std_logic;
        ttc_bc0         : std_logic;
        trig            : std_logic_vector(7 downto 0);
        tts_clk         : std_logic;
        tts_state       : std_logic_vector(3 downto 0);
        resync          : std_logic;
        event_clk       : std_logic;
        event_valid     : std_logic;
        event_header    : std_logic;
        event_trailer   : std_logic;
        event_data      : std_logic_vector(127 downto 0);
    end record;

    type t_daqlink_to_daq is record
        ready           : std_logic;
        backpressure    : std_logic;
        disperr_cnt     : std_logic_vector(15 downto 0);
        notintable_cnt  : std_logic_vector(15 downto 0);
    end record;

    --===============================--
    --== PROMless firmware loader ==--
    --===============================--
    
    type t_to_promless is record
        clk     : std_logic;
        en      : std_logic;
    end record;

    type t_from_promless is record
        ready   : std_logic;
        valid   : std_logic;
        data    : std_logic_vector(7 downto 0);
        first   : std_logic;
        last    : std_logic;
        error   : std_logic;
    end record;
   
    type t_promless_stats is record
        load_request_cnt    : std_logic_vector(15 downto 0);
        success_cnt         : std_logic_vector(15 downto 0);
        fail_cnt            : std_logic_vector(15 downto 0);
        gap_detect_cnt      : std_logic_vector(15 downto 0);
        loader_ovf_unf_cnt  : std_logic_vector(15 downto 0);
    end record;

    type t_promless_cfg is record
        firmware_size       : std_logic_vector(31 downto 0);
    end record;

end common_pkg;
   
package body common_pkg is

    function count_ones(s : std_logic_vector) return integer is
        variable temp : natural := 0;
    begin
        for i in s'range loop
            if s(i) = '1' then
                temp := temp + 1;
            end if;
        end loop;

        return temp;
    end function count_ones;

    function bool_to_std_logic(L : BOOLEAN) return std_logic is
    begin
        if L then
            return ('1');
        else
            return ('0');
        end if;
    end function bool_to_std_logic;
    
    function log2ceil(arg : positive) return natural is
        variable tmp : positive     := 1;
        variable log : natural      := 0;
    begin
        if arg = 1 then return 1; end if;
        while arg >= tmp loop
            tmp := tmp * 2;
            log := log + 1;
        end loop;
        return log;
    end function;   

    function up_to_power_of_2(arg : positive) return natural is
        variable tmp : positive     := 1;
    begin
        while arg > tmp loop
            tmp := tmp * 2;
        end loop;
        return tmp;
    end function;   

    function div_ceil(numerator, denominator : positive) return natural is
        variable tmp : positive     := denominator;
        variable ret : positive     := 1;
    begin
        if numerator = 0 then return 0; end if;
        while numerator > tmp loop
            tmp := tmp + denominator;
            ret := ret + 1;
        end loop;
        return ret;
    end function;  
        
end common_pkg;
