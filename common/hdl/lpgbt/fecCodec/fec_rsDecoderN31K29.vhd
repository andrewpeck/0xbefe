-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 1.0
--! @brief N31K29 Reed-Solomon decoder
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;

--! Include the LpGBT-FPGA specific package
use work.lpgbtfpga_package.all;

--! @brief rs_decoder_N31K29 - N31K29 Reed-Solomon decoder
ENTITY rs_decoder_N31K29 IS
   GENERIC (
		N								: integer := 31;
		K 								: integer := 29;
		SYMB_BITWIDTH					: integer := 5
   );
   PORT (
        payloadData_i                   : in  std_logic_vector((K*SYMB_BITWIDTH)-1 downto 0);       --! Message to be decoded
        fecData_i                       : in  std_logic_vector(((N-K)*SYMB_BITWIDTH)-1 downto 0);   --! FEC used to decode

        data_o                          : out std_logic_vector((K*SYMB_BITWIDTH)-1 downto 0)        --! Decoded / corrected data
   );
END rs_decoder_N31K29;

--! @brief rs_decoder_N31K29 architecture - N31K29 Reed-Solomon encoder
ARCHITECTURE behabioral of rs_decoder_N31K29 IS

    -- Functions
    function gf_multBy2_5 (
        op : in std_logic_vector(4 downto 0)
    )
    return std_logic_vector is        
        variable tmp: std_logic_vector(4 downto 0);        
    begin
        tmp(0) := op(4);
        tmp(1) := op(0);
        tmp(2) := op(1) xor op(4);
        tmp(3) := op(2);
        tmp(4) := op(3);
        
        return tmp;
    end;

    function gf_mult_5 (
        op1 : in std_logic_vector(4 downto 0);
        op2 : in std_logic_vector(4 downto 0)
    )
    return std_logic_vector is        
        variable tmp: std_logic_vector(4 downto 0);        
    begin
        tmp(0) := (((((op1(4) and op2(4)) xor (op1(1) and op2(4))) xor (op1(2) and op2(3))) xor (op1(3) and op2(2))) xor (op1(4) and op2(1))) xor (op1(0) and op2(0));
        tmp(1) := ((((op1(1) and op2(0)) xor (op1(0) and op2(1))) xor (op1(4) and op2(2))) xor (op1(3) and op2(3))) xor (op1(2) and op2(4));
        tmp(2) := (((((((((op1(2) and op2(0)) xor (op1(1) and op2(1))) xor (op1(4) and op2(1))) xor (op1(0) and op2(2))) xor (op1(3) and op2(2))) xor (op1(2) and op2(3))) xor (op1(4) and op2(3))) xor (op1(1) and op2(4))) xor (op1(3) and op2(4))) xor (op1(4) and op2(4));
        tmp(3) := (((((((op1(3) and op2(0)) xor (op1(2) and op2(1))) xor (op1(1) and op2(2))) xor (op1(4) and op2(2))) xor (op1(0) and op2(3))) xor (op1(3) and op2(3))) xor (op1(2) and op2(4))) xor (op1(4) and op2(4));
        tmp(4) := ((((((op1(4) and op2(0)) xor (op1(3) and op2(1))) xor (op1(2) and op2(2))) xor (op1(1) and op2(3))) xor (op1(4) and op2(3))) xor (op1(0) and op2(4))) xor (op1(3) and op2(4));

        return tmp;
    end;

    function gf_inv_5 (
        op : in std_logic_vector(4 downto 0)
    )
    return std_logic_vector is        
        variable tmp: std_logic_vector(4 downto 0);        
    begin

        case op is
        
            when "00000"  => tmp := "00000";
            when "00001"  => tmp := "00001";
            when "00010"  => tmp := "10010";
            when "00011"  => tmp := "11100";
            when "00100"  => tmp := "01001";
            when "00101"  => tmp := "10111";
            when "00110"  => tmp := "01110";
            when "00111"  => tmp := "01100";
            when "01000"  => tmp := "10110";
            when "01001"  => tmp := "00100";
            when "01010"  => tmp := "11001";
            when "01011"  => tmp := "10000";
            when "01100"  => tmp := "00111";
            when "01101"  => tmp := "01111";
            when "01110"  => tmp := "00110";
            when "01111"  => tmp := "01101";
            when "10000"  => tmp := "01011";
            when "10001"  => tmp := "11000";
            when "10010"  => tmp := "00010";
            when "10011"  => tmp := "11101";
            when "10100"  => tmp := "11110";
            when "10101"  => tmp := "11010";
            when "10110"  => tmp := "01000";
            when "10111"  => tmp := "00101";
            when "11000"  => tmp := "10001";
            when "11001"  => tmp := "01010";
            when "11010"  => tmp := "10101";
            when "11011"  => tmp := "11111";
            when "11100"  => tmp := "00011";
            when "11101"  => tmp := "10011";
            when "11110"  => tmp := "10100";
            when "11111"  => tmp := "11011"; 
            when others   => tmp := "00000";       
        end case;
        
        return tmp;
    end;

    function gf_log_5 (
        op : in std_logic_vector(4 downto 0)
    )
    return std_logic_vector is        
        variable tmp: std_logic_vector(4 downto 0);        
    begin

        case op is
        
            when "00000"  => tmp := "00000"; -- 0
            when "00001"  => tmp := "00000"; -- 0
            when "00010"  => tmp := "00001"; -- 1
            when "00011"  => tmp := "10010"; -- 18
            when "00100"  => tmp := "00010"; -- 2
            when "00101"  => tmp := "00101"; -- 5
            when "00110"  => tmp := "10011"; -- 19
            when "00111"  => tmp := "01011"; -- 11
            when "01000"  => tmp := "00011"; -- 3
            when "01001"  => tmp := "11101"; -- 29
            when "01010"  => tmp := "00110"; -- 6
            when "01011"  => tmp := "11011"; -- 27
            when "01100"  => tmp := "10100"; -- 20
            when "01101"  => tmp := "01000"; -- 8
            when "01110"  => tmp := "01100"; -- 12
            when "01111"  => tmp := "10111"; -- 23
            when "10000"  => tmp := "00100"; -- 4
            when "10001"  => tmp := "01010"; -- 10
            when "10010"  => tmp := "11110"; -- 30
            when "10011"  => tmp := "10001"; -- 17
            when "10100"  => tmp := "00111"; -- 7
            when "10101"  => tmp := "10110"; -- 22
            when "10110"  => tmp := "11100"; -- 28
            when "10111"  => tmp := "11010"; -- 26
            when "11000"  => tmp := "10101"; -- 21
            when "11001"  => tmp := "11001"; -- 25
            when "11010"  => tmp := "01001"; -- 9
            when "11011"  => tmp := "10000"; -- 16
            when "11100"  => tmp := "01101"; -- 13
            when "11101"  => tmp := "01110"; -- 14
            when "11110"  => tmp := "11000"; -- 24
            when "11111"  => tmp := "01111"; -- 15  
            when others   => tmp := "00000";         
        end case;
        
        return tmp;
    end;
	
    -- Signals
    signal msg              : std_logic_vector((N*SYMB_BITWIDTH)-1 downto 0);
    signal decMsg           : std_logic_vector((K*SYMB_BITWIDTH)-1 downto 0);
    
    signal outSt1           : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt2           : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt3           : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt4           : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt5           : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt6           : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt7           : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt8           : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt9           : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt10          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt11          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt12          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt13          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt14          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt15          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt16          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt17          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt18          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt19          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt20          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt21          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt22          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt23          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt24          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt25          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt26          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt27          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt28          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outSt29          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd0          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd1          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd2          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd3          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd4          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd5          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd6          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd7          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd8          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd9          : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd10         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd11         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd12         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd13         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd14         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd15         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd16         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd17         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd18         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd19         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd20         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd21         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd22         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd23         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd24         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd25         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd26         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd27         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outAdd28         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult0         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult1         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult2         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult3         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult4         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult5         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult6         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult7         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult8         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult9         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult10        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult11        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult12        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult13        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult14        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult15        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult16        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult17        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult18        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult19        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult20        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult21        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult22        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult23        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult24        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult25        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult26        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult27        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult28        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal outMult29        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal syndr0           : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal syndr1           : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal syndr0_inv       : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal syndrProd        : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    signal errorPos         : std_logic_vector((SYMB_BITWIDTH-1) downto 0);
    
BEGIN                 --========####   Architecture Body   ####========-- 
		
	-- ---------------- The Parallel LFSR HDL description  ---------------- --
    
    -- MSG mapping
    msg     <=  fecData_i & payloadData_i;
    
	-- Evaluates the first syndrom
    outSt1  <=  msg(((SYMB_BITWIDTH + 0)-1) downto 0) xor msg(((2*SYMB_BITWIDTH)-1) downto SYMB_BITWIDTH);
	outSt2  <=  msg(((SYMB_BITWIDTH + (2*SYMB_BITWIDTH)-1)) downto (2*SYMB_BITWIDTH)) xor outSt1;
	outSt3  <=  msg(((SYMB_BITWIDTH + (3*SYMB_BITWIDTH)-1)) downto (3*SYMB_BITWIDTH)) xor outSt2;
	outSt4  <=  msg(((SYMB_BITWIDTH + (4*SYMB_BITWIDTH)-1)) downto (4*SYMB_BITWIDTH)) xor outSt3;
	outSt5  <=  msg(((SYMB_BITWIDTH + (5*SYMB_BITWIDTH)-1)) downto (5*SYMB_BITWIDTH)) xor outSt4;
	outSt6  <=  msg(((SYMB_BITWIDTH + (6*SYMB_BITWIDTH)-1)) downto (6*SYMB_BITWIDTH)) xor outSt5;
	outSt7  <=  msg(((SYMB_BITWIDTH + (7*SYMB_BITWIDTH)-1)) downto (7*SYMB_BITWIDTH)) xor outSt6;
	outSt8  <=  msg(((SYMB_BITWIDTH + (8*SYMB_BITWIDTH)-1)) downto (8*SYMB_BITWIDTH)) xor outSt7;
	outSt9  <=  msg(((SYMB_BITWIDTH + (9*SYMB_BITWIDTH)-1)) downto (9*SYMB_BITWIDTH)) xor outSt8;
	outSt10 <=  msg(((SYMB_BITWIDTH + (10*SYMB_BITWIDTH)-1)) downto (10*SYMB_BITWIDTH)) xor outSt9;
	outSt11 <=  msg(((SYMB_BITWIDTH + (11*SYMB_BITWIDTH)-1)) downto (11*SYMB_BITWIDTH)) xor outSt10;
	outSt12 <=  msg(((SYMB_BITWIDTH + (12*SYMB_BITWIDTH)-1)) downto (12*SYMB_BITWIDTH)) xor outSt11;
	outSt13 <=  msg(((SYMB_BITWIDTH + (13*SYMB_BITWIDTH)-1)) downto (13*SYMB_BITWIDTH)) xor outSt12;
	outSt14 <=  msg(((SYMB_BITWIDTH + (14*SYMB_BITWIDTH)-1)) downto (14*SYMB_BITWIDTH)) xor outSt13;
	outSt15 <=  msg(((SYMB_BITWIDTH + (15*SYMB_BITWIDTH)-1)) downto (15*SYMB_BITWIDTH)) xor outSt14;
	outSt16 <=  msg(((SYMB_BITWIDTH + (16*SYMB_BITWIDTH)-1)) downto (16*SYMB_BITWIDTH)) xor outSt15;
	outSt17 <=  msg(((SYMB_BITWIDTH + (17*SYMB_BITWIDTH)-1)) downto (17*SYMB_BITWIDTH)) xor outSt16;
	outSt18 <=  msg(((SYMB_BITWIDTH + (18*SYMB_BITWIDTH)-1)) downto (18*SYMB_BITWIDTH)) xor outSt17;
	outSt19 <=  msg(((SYMB_BITWIDTH + (19*SYMB_BITWIDTH)-1)) downto (19*SYMB_BITWIDTH)) xor outSt18;
	outSt20 <=  msg(((SYMB_BITWIDTH + (20*SYMB_BITWIDTH)-1)) downto (20*SYMB_BITWIDTH)) xor outSt19;
	outSt21 <=  msg(((SYMB_BITWIDTH + (21*SYMB_BITWIDTH)-1)) downto (21*SYMB_BITWIDTH)) xor outSt20;
	outSt22 <=  msg(((SYMB_BITWIDTH + (22*SYMB_BITWIDTH)-1)) downto (22*SYMB_BITWIDTH)) xor outSt21;
	outSt23 <=  msg(((SYMB_BITWIDTH + (23*SYMB_BITWIDTH)-1)) downto (23*SYMB_BITWIDTH)) xor outSt22;
	outSt24 <=  msg(((SYMB_BITWIDTH + (24*SYMB_BITWIDTH)-1)) downto (24*SYMB_BITWIDTH)) xor outSt23;
	outSt25 <=  msg(((SYMB_BITWIDTH + (25*SYMB_BITWIDTH)-1)) downto (25*SYMB_BITWIDTH)) xor outSt24;
	outSt26 <=  msg(((SYMB_BITWIDTH + (26*SYMB_BITWIDTH)-1)) downto (26*SYMB_BITWIDTH)) xor outSt25;
	outSt27 <=  msg(((SYMB_BITWIDTH + (27*SYMB_BITWIDTH)-1)) downto (27*SYMB_BITWIDTH)) xor outSt26;
	outSt28 <=  msg(((SYMB_BITWIDTH + (28*SYMB_BITWIDTH)-1)) downto (28*SYMB_BITWIDTH)) xor outSt27;
	outSt29 <=  msg(((SYMB_BITWIDTH + (29*SYMB_BITWIDTH)-1)) downto (29*SYMB_BITWIDTH)) xor outSt28;
	syndr0  <=  msg(((SYMB_BITWIDTH + (30*SYMB_BITWIDTH)-1)) downto (30*SYMB_BITWIDTH)) xor outSt29;
    
    -- Evaluates the second syndrom
    outMult0   <= gf_multBy2_5(msg(SYMB_BITWIDTH-1 downto 0));
	outMult1   <= gf_multBy2_5(outAdd0);
	outMult2   <= gf_multBy2_5(outAdd1);
	outMult3   <= gf_multBy2_5(outAdd2);
	outMult4   <= gf_multBy2_5(outAdd3);
	outMult5   <= gf_multBy2_5(outAdd4);
	outMult6   <= gf_multBy2_5(outAdd5);
	outMult7   <= gf_multBy2_5(outAdd6);
	outMult8   <= gf_multBy2_5(outAdd7);
	outMult9   <= gf_multBy2_5(outAdd8);
	outMult10  <= gf_multBy2_5(outAdd9);
	outMult11  <= gf_multBy2_5(outAdd10);
	outMult12  <= gf_multBy2_5(outAdd11);
	outMult13  <= gf_multBy2_5(outAdd12);
	outMult14  <= gf_multBy2_5(outAdd13);
	outMult15  <= gf_multBy2_5(outAdd14);
	outMult16  <= gf_multBy2_5(outAdd15);
	outMult17  <= gf_multBy2_5(outAdd16);
	outMult18  <= gf_multBy2_5(outAdd17);
	outMult19  <= gf_multBy2_5(outAdd18);
	outMult20  <= gf_multBy2_5(outAdd19);
	outMult21  <= gf_multBy2_5(outAdd20);
	outMult22  <= gf_multBy2_5(outAdd21);
	outMult23  <= gf_multBy2_5(outAdd22);
	outMult24  <= gf_multBy2_5(outAdd23);
	outMult25  <= gf_multBy2_5(outAdd24);
	outMult26  <= gf_multBy2_5(outAdd25);
	outMult27  <= gf_multBy2_5(outAdd26);
	outMult28  <= gf_multBy2_5(outAdd27);
	outMult29  <= gf_multBy2_5(outAdd28);
    
	outAdd0    <= outMult0 xor msg(((SYMB_BITWIDTH+SYMB_BITWIDTH)-1) downto SYMB_BITWIDTH);	
	outAdd1    <= outMult1 xor msg(((SYMB_BITWIDTH+2*SYMB_BITWIDTH)-1) downto (2*SYMB_BITWIDTH));
	outAdd2    <= outMult2 xor msg(((SYMB_BITWIDTH+3*SYMB_BITWIDTH)-1) downto (3*SYMB_BITWIDTH));
	outAdd3    <= outMult3 xor msg(((SYMB_BITWIDTH+4*SYMB_BITWIDTH)-1) downto (4*SYMB_BITWIDTH));
	outAdd4    <= outMult4 xor msg(((SYMB_BITWIDTH+5*SYMB_BITWIDTH)-1) downto (5*SYMB_BITWIDTH));
	outAdd5    <= outMult5 xor msg(((SYMB_BITWIDTH+6*SYMB_BITWIDTH)-1) downto (6*SYMB_BITWIDTH));
	outAdd6    <= outMult6 xor msg(((SYMB_BITWIDTH+7*SYMB_BITWIDTH)-1) downto (7*SYMB_BITWIDTH));
	outAdd7    <= outMult7 xor msg(((SYMB_BITWIDTH+8*SYMB_BITWIDTH)-1) downto (8*SYMB_BITWIDTH));
	outAdd8    <= outMult8 xor msg(((SYMB_BITWIDTH+9*SYMB_BITWIDTH)-1) downto (9*SYMB_BITWIDTH));
	outAdd9    <= outMult9 xor msg(((SYMB_BITWIDTH+10*SYMB_BITWIDTH)-1) downto (10*SYMB_BITWIDTH));
	outAdd10   <= outMult10 xor msg(((SYMB_BITWIDTH+11*SYMB_BITWIDTH)-1) downto (11*SYMB_BITWIDTH));
	outAdd11   <= outMult11 xor msg(((SYMB_BITWIDTH+12*SYMB_BITWIDTH)-1) downto (12*SYMB_BITWIDTH));
	outAdd12   <= outMult12 xor msg(((SYMB_BITWIDTH+13*SYMB_BITWIDTH)-1) downto (13*SYMB_BITWIDTH));
	outAdd13   <= outMult13 xor msg(((SYMB_BITWIDTH+14*SYMB_BITWIDTH)-1) downto (14*SYMB_BITWIDTH));
	outAdd14   <= outMult14 xor msg(((SYMB_BITWIDTH+15*SYMB_BITWIDTH)-1) downto (15*SYMB_BITWIDTH));
	outAdd15   <= outMult15 xor msg(((SYMB_BITWIDTH+16*SYMB_BITWIDTH)-1) downto (16*SYMB_BITWIDTH));
	outAdd16   <= outMult16 xor msg(((SYMB_BITWIDTH+17*SYMB_BITWIDTH)-1) downto (17*SYMB_BITWIDTH));
	outAdd17   <= outMult17 xor msg(((SYMB_BITWIDTH+18*SYMB_BITWIDTH)-1) downto (18*SYMB_BITWIDTH));
	outAdd18   <= outMult18 xor msg(((SYMB_BITWIDTH+19*SYMB_BITWIDTH)-1) downto (19*SYMB_BITWIDTH));
	outAdd19   <= outMult19 xor msg(((SYMB_BITWIDTH+20*SYMB_BITWIDTH)-1) downto (20*SYMB_BITWIDTH));
	outAdd20   <= outMult20 xor msg(((SYMB_BITWIDTH+21*SYMB_BITWIDTH)-1) downto (21*SYMB_BITWIDTH));
	outAdd21   <= outMult21 xor msg(((SYMB_BITWIDTH+22*SYMB_BITWIDTH)-1) downto (22*SYMB_BITWIDTH));
	outAdd22   <= outMult22 xor msg(((SYMB_BITWIDTH+23*SYMB_BITWIDTH)-1) downto (23*SYMB_BITWIDTH));
	outAdd23   <= outMult23 xor msg(((SYMB_BITWIDTH+24*SYMB_BITWIDTH)-1) downto (24*SYMB_BITWIDTH));
	outAdd24   <= outMult24 xor msg(((SYMB_BITWIDTH+25*SYMB_BITWIDTH)-1) downto (25*SYMB_BITWIDTH));
	outAdd25   <= outMult25 xor msg(((SYMB_BITWIDTH+26*SYMB_BITWIDTH)-1) downto (26*SYMB_BITWIDTH));
	outAdd26   <= outMult26 xor msg(((SYMB_BITWIDTH+27*SYMB_BITWIDTH)-1) downto (27*SYMB_BITWIDTH));
	outAdd27   <= outMult27 xor msg(((SYMB_BITWIDTH+28*SYMB_BITWIDTH)-1) downto (28*SYMB_BITWIDTH));
	outAdd28   <= outMult28 xor msg(((SYMB_BITWIDTH+29*SYMB_BITWIDTH)-1) downto (29*SYMB_BITWIDTH));
	syndr1     <= outMult29 xor msg(((SYMB_BITWIDTH+30*SYMB_BITWIDTH)-1) downto (30*SYMB_BITWIDTH));	
    
	-- Evaluates position of error
    syndr0_inv   <= gf_inv_5(syndr0);
    syndrProd    <= gf_mult_5(syndr0_inv, syndr1);
    errorPos     <= gf_log_5(syndrProd);
    
    -- Correct message.. Correction on parity bits is ignored!
    decMsg(((SYMB_BITWIDTH+28*SYMB_BITWIDTH)-1) downto (28*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+28*SYMB_BITWIDTH)-1) downto (28*SYMB_BITWIDTH)) xor syndr0 when errorPos = "00010" else
                                                                              msg(((SYMB_BITWIDTH+28*SYMB_BITWIDTH)-1) downto (28*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+27*SYMB_BITWIDTH)-1) downto (27*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+27*SYMB_BITWIDTH)-1) downto (27*SYMB_BITWIDTH)) xor syndr0 when errorPos = "00011" else
                                                                              msg(((SYMB_BITWIDTH+27*SYMB_BITWIDTH)-1) downto (27*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+26*SYMB_BITWIDTH)-1) downto (26*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+26*SYMB_BITWIDTH)-1) downto (26*SYMB_BITWIDTH)) xor syndr0 when errorPos = "00100" else
                                                                              msg(((SYMB_BITWIDTH+26*SYMB_BITWIDTH)-1) downto (26*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+25*SYMB_BITWIDTH)-1) downto (25*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+25*SYMB_BITWIDTH)-1) downto (25*SYMB_BITWIDTH)) xor syndr0 when errorPos = "00101" else
                                                                              msg(((SYMB_BITWIDTH+25*SYMB_BITWIDTH)-1) downto (25*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+24*SYMB_BITWIDTH)-1) downto (24*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+24*SYMB_BITWIDTH)-1) downto (24*SYMB_BITWIDTH)) xor syndr0 when errorPos = "00110" else
                                                                              msg(((SYMB_BITWIDTH+24*SYMB_BITWIDTH)-1) downto (24*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+23*SYMB_BITWIDTH)-1) downto (23*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+23*SYMB_BITWIDTH)-1) downto (23*SYMB_BITWIDTH)) xor syndr0 when errorPos = "00111" else
                                                                              msg(((SYMB_BITWIDTH+23*SYMB_BITWIDTH)-1) downto (23*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+22*SYMB_BITWIDTH)-1) downto (22*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+22*SYMB_BITWIDTH)-1) downto (22*SYMB_BITWIDTH)) xor syndr0 when errorPos = "01000" else
                                                                              msg(((SYMB_BITWIDTH+22*SYMB_BITWIDTH)-1) downto (22*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+21*SYMB_BITWIDTH)-1) downto (21*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+21*SYMB_BITWIDTH)-1) downto (21*SYMB_BITWIDTH)) xor syndr0 when errorPos = "01001" else
                                                                              msg(((SYMB_BITWIDTH+21*SYMB_BITWIDTH)-1) downto (21*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+20*SYMB_BITWIDTH)-1) downto (20*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+20*SYMB_BITWIDTH)-1) downto (20*SYMB_BITWIDTH)) xor syndr0 when errorPos = "01010" else
                                                                              msg(((SYMB_BITWIDTH+20*SYMB_BITWIDTH)-1) downto (20*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+19*SYMB_BITWIDTH)-1) downto (19*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+19*SYMB_BITWIDTH)-1) downto (19*SYMB_BITWIDTH)) xor syndr0 when errorPos = "01011" else
                                                                              msg(((SYMB_BITWIDTH+19*SYMB_BITWIDTH)-1) downto (19*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+18*SYMB_BITWIDTH)-1) downto (18*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+18*SYMB_BITWIDTH)-1) downto (18*SYMB_BITWIDTH)) xor syndr0 when errorPos = "01100" else
                                                                              msg(((SYMB_BITWIDTH+18*SYMB_BITWIDTH)-1) downto (18*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+17*SYMB_BITWIDTH)-1) downto (17*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+17*SYMB_BITWIDTH)-1) downto (17*SYMB_BITWIDTH)) xor syndr0 when errorPos = "01101" else
                                                                              msg(((SYMB_BITWIDTH+17*SYMB_BITWIDTH)-1) downto (17*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+16*SYMB_BITWIDTH)-1) downto (16*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+16*SYMB_BITWIDTH)-1) downto (16*SYMB_BITWIDTH)) xor syndr0 when errorPos = "01110" else
                                                                              msg(((SYMB_BITWIDTH+16*SYMB_BITWIDTH)-1) downto (16*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+15*SYMB_BITWIDTH)-1) downto (15*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+15*SYMB_BITWIDTH)-1) downto (15*SYMB_BITWIDTH)) xor syndr0 when errorPos = "01111" else
                                                                              msg(((SYMB_BITWIDTH+15*SYMB_BITWIDTH)-1) downto (15*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+14*SYMB_BITWIDTH)-1) downto (14*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+14*SYMB_BITWIDTH)-1) downto (14*SYMB_BITWIDTH)) xor syndr0 when errorPos = "10000" else
                                                                              msg(((SYMB_BITWIDTH+14*SYMB_BITWIDTH)-1) downto (14*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+13*SYMB_BITWIDTH)-1) downto (13*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+13*SYMB_BITWIDTH)-1) downto (13*SYMB_BITWIDTH)) xor syndr0 when errorPos = "10001" else
                                                                              msg(((SYMB_BITWIDTH+13*SYMB_BITWIDTH)-1) downto (13*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+12*SYMB_BITWIDTH)-1) downto (12*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+12*SYMB_BITWIDTH)-1) downto (12*SYMB_BITWIDTH)) xor syndr0 when errorPos = "10010" else
                                                                              msg(((SYMB_BITWIDTH+12*SYMB_BITWIDTH)-1) downto (12*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+11*SYMB_BITWIDTH)-1) downto (11*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+11*SYMB_BITWIDTH)-1) downto (11*SYMB_BITWIDTH)) xor syndr0 when errorPos = "10011" else
                                                                              msg(((SYMB_BITWIDTH+11*SYMB_BITWIDTH)-1) downto (11*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+10*SYMB_BITWIDTH)-1) downto (10*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+10*SYMB_BITWIDTH)-1) downto (10*SYMB_BITWIDTH)) xor syndr0 when errorPos = "10100" else
                                                                              msg(((SYMB_BITWIDTH+10*SYMB_BITWIDTH)-1) downto (10*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+9*SYMB_BITWIDTH)-1) downto (9*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+9*SYMB_BITWIDTH)-1) downto (9*SYMB_BITWIDTH)) xor syndr0 when errorPos = "10101" else
                                                                              msg(((SYMB_BITWIDTH+9*SYMB_BITWIDTH)-1) downto (9*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+8*SYMB_BITWIDTH)-1) downto (8*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+8*SYMB_BITWIDTH)-1) downto (8*SYMB_BITWIDTH)) xor syndr0 when errorPos = "10110" else
                                                                              msg(((SYMB_BITWIDTH+8*SYMB_BITWIDTH)-1) downto (8*SYMB_BITWIDTH));

    decMsg(((SYMB_BITWIDTH+7*SYMB_BITWIDTH)-1) downto (7*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+7*SYMB_BITWIDTH)-1) downto (7*SYMB_BITWIDTH)) xor syndr0 when errorPos = "10111" else
                                                                              msg(((SYMB_BITWIDTH+7*SYMB_BITWIDTH)-1) downto (7*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+6*SYMB_BITWIDTH)-1) downto (6*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+6*SYMB_BITWIDTH)-1) downto (6*SYMB_BITWIDTH)) xor syndr0 when errorPos = "11000" else
                                                                              msg(((SYMB_BITWIDTH+6*SYMB_BITWIDTH)-1) downto (6*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+5*SYMB_BITWIDTH)-1) downto (5*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+5*SYMB_BITWIDTH)-1) downto (5*SYMB_BITWIDTH)) xor syndr0 when errorPos = "11001" else
                                                                              msg(((SYMB_BITWIDTH+5*SYMB_BITWIDTH)-1) downto (5*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+4*SYMB_BITWIDTH)-1) downto (4*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+4*SYMB_BITWIDTH)-1) downto (4*SYMB_BITWIDTH)) xor syndr0 when errorPos = "11010" else
                                                                              msg(((SYMB_BITWIDTH+4*SYMB_BITWIDTH)-1) downto (4*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+3*SYMB_BITWIDTH)-1) downto (3*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+3*SYMB_BITWIDTH)-1) downto (3*SYMB_BITWIDTH)) xor syndr0 when errorPos = "11011" else
                                                                              msg(((SYMB_BITWIDTH+3*SYMB_BITWIDTH)-1) downto (3*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+2*SYMB_BITWIDTH)-1) downto (2*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+2*SYMB_BITWIDTH)-1) downto (2*SYMB_BITWIDTH)) xor syndr0 when errorPos = "11100" else
                                                                              msg(((SYMB_BITWIDTH+2*SYMB_BITWIDTH)-1) downto (2*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+1*SYMB_BITWIDTH)-1) downto (1*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+1*SYMB_BITWIDTH)-1) downto (1*SYMB_BITWIDTH)) xor syndr0 when errorPos = "11101" else
                                                                              msg(((SYMB_BITWIDTH+1*SYMB_BITWIDTH)-1) downto (1*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+0*SYMB_BITWIDTH)-1) downto (0*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+0*SYMB_BITWIDTH)-1) downto (0*SYMB_BITWIDTH)) xor syndr0 when errorPos = "11110" else
                                                                              msg(((SYMB_BITWIDTH+0*SYMB_BITWIDTH)-1) downto (0*SYMB_BITWIDTH));
                                                                              
    data_o <= decMsg;
    
END behabioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--