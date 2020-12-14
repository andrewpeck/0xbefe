-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 1.0
--! @brief N15K13 Reed-Solomon decoder
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;

--! Include the LpGBT-FPGA specific package
use work.lpgbtfpga_package.all;

--! @brief rs_decoder_N15K13 - N15K13 Reed-Solomon decoder
ENTITY rs_decoder_N15K13 IS
   GENERIC (
		N								: integer := 15;
		K 								: integer := 13;
		SYMB_BITWIDTH					: integer := 4
   );
   PORT (
        payloadData_i                   : in  std_logic_vector((K*SYMB_BITWIDTH)-1 downto 0);       --! Message to be decoded
        fecData_i                       : in  std_logic_vector(((N-K)*SYMB_BITWIDTH)-1 downto 0);   --! FEC used to decode
        
        data_o                          : out std_logic_vector((K*SYMB_BITWIDTH)-1 downto 0)        --! Decoded / corrected data
   );
END rs_decoder_N15K13;

--! @brief rs_decoder_N15K13 architecture - N15K13 Reed-Solomon encoder
ARCHITECTURE behabioral of rs_decoder_N15K13 IS

    -- Functions
    function gf_multBy2_4 (
        op : in std_logic_vector(3 downto 0)
    )
    return std_logic_vector is        
        variable tmp: std_logic_vector(3 downto 0);        
    begin
        tmp(0) := op(3);
        tmp(1) := op(0) xor op(3);
        tmp(2) := op(1);
        tmp(3) := op(2);
        
        return tmp;
    end;

    function gf_mult_4 (
        op1 : in std_logic_vector(3 downto 0);
        op2 : in std_logic_vector(3 downto 0)
    )
    return std_logic_vector is        
        variable tmp: std_logic_vector(3 downto 0);        
    begin
        tmp(0) := (op1(1) and op2(3)) xor (op1(2) and op2(2)) xor (op1(3) and op2(1)) xor (op1(0) and op2(0));
        tmp(1) := (op1(1) and op2(0)) xor (op1(0) and op2(1)) xor (op1(3) and op2(1)) xor (op1(2) and op2(2)) xor (op1(3) and op2(2)) xor (op1(1) and op2(3)) xor (op1(2) and op2(3));
        tmp(2) := (op1(2) and op2(0)) xor (op1(1) and op2(1)) xor (op1(0) and op2(2)) xor (op1(3) and op2(2)) xor (op1(2) and op2(3)) xor (op1(3) and op2(3));
        tmp(3) := (op1(3) and op2(0)) xor (op1(2) and op2(1)) xor (op1(1) and op2(2)) xor (op1(0) and op2(3)) xor (op1(3) and op2(3));
        return tmp;
    end;

    function gf_inv_4 (
        op : in std_logic_vector(3 downto 0)
    )
    return std_logic_vector is        
        variable tmp: std_logic_vector(3 downto 0);        
    begin
   
        case op is        
            when "0000"  => tmp := "0000"; -- 0
            when "0001"  => tmp := "0001"; -- 1
            when "0010"  => tmp := "1001"; -- 9
            when "0011"  => tmp := "1110"; -- 14
            when "0100"  => tmp := "1101"; -- 13
            when "0101"  => tmp := "1011"; -- 11
            when "0110"  => tmp := "0111"; -- 7
            when "0111"  => tmp := "0110"; -- 6
            when "1000"  => tmp := "1111"; -- 15
            when "1001"  => tmp := "0010"; -- 2
            when "1010"  => tmp := "1100"; -- 12
            when "1011"  => tmp := "0101"; -- 5
            when "1100"  => tmp := "1010"; -- 10
            when "1101"  => tmp := "0100"; -- 4
            when "1110"  => tmp := "0011"; -- 3
            when "1111"  => tmp := "1000"; -- 8
            when others  => tmp := "0000"; -- 0
        end case;
        
        return tmp;
    end;

    function gf_log_4 (
        op : in std_logic_vector(3 downto 0)
    )
    return std_logic_vector is        
        variable tmp: std_logic_vector(3 downto 0);        
    begin

        case op is
        
            when "0000"  => tmp := "0000"; -- 0
            when "0001"  => tmp := "0000"; -- 0
            when "0010"  => tmp := "0001"; -- 1
            when "0011"  => tmp := "0100"; -- 4
            when "0100"  => tmp := "0010"; -- 2
            when "0101"  => tmp := "1000"; -- 8
            when "0110"  => tmp := "0101"; -- 5
            when "0111"  => tmp := "1010"; -- 10
            when "1000"  => tmp := "0011"; -- 3
            when "1001"  => tmp := "1110"; -- 14
            when "1010"  => tmp := "1001"; -- 9
            when "1011"  => tmp := "0111"; -- 7
            when "1100"  => tmp := "0110"; -- 6
            when "1101"  => tmp := "1101"; -- 13
            when "1110"  => tmp := "1011"; -- 11
            when "1111"  => tmp := "1100"; -- 12 
            when others  => tmp := "0000"; -- 0 
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
	outSt2  <=  msg(((SYMB_BITWIDTH + 2*SYMB_BITWIDTH)-1) downto (2*SYMB_BITWIDTH)) xor outSt1;
	outSt3  <=  msg(((SYMB_BITWIDTH + 3*SYMB_BITWIDTH)-1) downto (3*SYMB_BITWIDTH)) xor outSt2;
	outSt4  <=  msg(((SYMB_BITWIDTH + 4*SYMB_BITWIDTH)-1) downto (4*SYMB_BITWIDTH)) xor outSt3;
	outSt5  <=  msg(((SYMB_BITWIDTH + 5*SYMB_BITWIDTH)-1) downto (5*SYMB_BITWIDTH)) xor outSt4;
	outSt6  <=  msg(((SYMB_BITWIDTH + 6*SYMB_BITWIDTH)-1) downto (6*SYMB_BITWIDTH)) xor outSt5;
	outSt7  <=  msg(((SYMB_BITWIDTH + 7*SYMB_BITWIDTH)-1) downto (7*SYMB_BITWIDTH)) xor outSt6;
	outSt8  <=  msg(((SYMB_BITWIDTH + 8*SYMB_BITWIDTH)-1) downto (8*SYMB_BITWIDTH)) xor outSt7;
	outSt9  <=  msg(((SYMB_BITWIDTH + 9*SYMB_BITWIDTH)-1) downto (9*SYMB_BITWIDTH)) xor outSt8;
	outSt10 <=  msg(((SYMB_BITWIDTH + 10*SYMB_BITWIDTH)-1) downto (10*SYMB_BITWIDTH)) xor outSt9;
	outSt11 <=  msg(((SYMB_BITWIDTH + 11*SYMB_BITWIDTH)-1) downto (11*SYMB_BITWIDTH)) xor outSt10;
	outSt12 <=  msg(((SYMB_BITWIDTH + 12*SYMB_BITWIDTH)-1) downto (12*SYMB_BITWIDTH)) xor outSt11;
	outSt13 <=  msg(((SYMB_BITWIDTH + 13*SYMB_BITWIDTH)-1) downto (13*SYMB_BITWIDTH)) xor outSt12;
	syndr0  <=  msg(((SYMB_BITWIDTH + 14*SYMB_BITWIDTH)-1) downto (14*SYMB_BITWIDTH)) xor outSt13;
    
    -- Evaluates the second syndrom
    outMult0   <= gf_multBy2_4(msg(SYMB_BITWIDTH-1 downto 0));
	outMult1   <= gf_multBy2_4(outAdd0);
	outMult2   <= gf_multBy2_4(outAdd1);
	outMult3   <= gf_multBy2_4(outAdd2);
	outMult4   <= gf_multBy2_4(outAdd3);
	outMult5   <= gf_multBy2_4(outAdd4);
	outMult6   <= gf_multBy2_4(outAdd5);
	outMult7   <= gf_multBy2_4(outAdd6);
	outMult8   <= gf_multBy2_4(outAdd7);
	outMult9   <= gf_multBy2_4(outAdd8);
	outMult10  <= gf_multBy2_4(outAdd9);
	outMult11  <= gf_multBy2_4(outAdd10);
	outMult12  <= gf_multBy2_4(outAdd11);
	outMult13  <= gf_multBy2_4(outAdd12);
    
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
	syndr1     <= outMult13 xor msg(((SYMB_BITWIDTH+14*SYMB_BITWIDTH)-1) downto (14*SYMB_BITWIDTH));	
    
	-- Evaluates position of error
    syndr0_inv   <= gf_inv_4(syndr0);
    syndrProd    <= gf_mult_4(syndr0_inv, syndr1);
    errorPos     <= gf_log_4(syndrProd);
    
    -- Correct message.. Correction on parity bits is ignored!
    decMsg(((SYMB_BITWIDTH+12*SYMB_BITWIDTH)-1) downto (12*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+12*SYMB_BITWIDTH)-1) downto (12*SYMB_BITWIDTH)) xor syndr0 when errorPos = "0010" else
                                                                              msg(((SYMB_BITWIDTH+12*SYMB_BITWIDTH)-1) downto (12*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+11*SYMB_BITWIDTH)-1) downto (11*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+11*SYMB_BITWIDTH)-1) downto (11*SYMB_BITWIDTH)) xor syndr0 when errorPos = "0011" else
                                                                              msg(((SYMB_BITWIDTH+11*SYMB_BITWIDTH)-1) downto (11*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+10*SYMB_BITWIDTH)-1) downto (10*SYMB_BITWIDTH)) <= msg(((SYMB_BITWIDTH+10*SYMB_BITWIDTH)-1) downto (10*SYMB_BITWIDTH)) xor syndr0 when errorPos = "0100" else
                                                                              msg(((SYMB_BITWIDTH+10*SYMB_BITWIDTH)-1) downto (10*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+9*SYMB_BITWIDTH)-1) downto (9*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+9*SYMB_BITWIDTH)-1) downto (9*SYMB_BITWIDTH)) xor syndr0 when errorPos = "0101" else
                                                                              msg(((SYMB_BITWIDTH+9*SYMB_BITWIDTH)-1) downto (9*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+8*SYMB_BITWIDTH)-1) downto (8*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+8*SYMB_BITWIDTH)-1) downto (8*SYMB_BITWIDTH)) xor syndr0 when errorPos = "0110" else
                                                                              msg(((SYMB_BITWIDTH+8*SYMB_BITWIDTH)-1) downto (8*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+7*SYMB_BITWIDTH)-1) downto (7*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+7*SYMB_BITWIDTH)-1) downto (7*SYMB_BITWIDTH)) xor syndr0 when errorPos = "0111" else
                                                                              msg(((SYMB_BITWIDTH+7*SYMB_BITWIDTH)-1) downto (7*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+6*SYMB_BITWIDTH)-1) downto (6*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+6*SYMB_BITWIDTH)-1) downto (6*SYMB_BITWIDTH)) xor syndr0 when errorPos = "1000" else
                                                                              msg(((SYMB_BITWIDTH+6*SYMB_BITWIDTH)-1) downto (6*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+5*SYMB_BITWIDTH)-1) downto (5*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+5*SYMB_BITWIDTH)-1) downto (5*SYMB_BITWIDTH)) xor syndr0 when errorPos = "1001" else
                                                                              msg(((SYMB_BITWIDTH+5*SYMB_BITWIDTH)-1) downto (5*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+4*SYMB_BITWIDTH)-1) downto (4*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+4*SYMB_BITWIDTH)-1) downto (4*SYMB_BITWIDTH)) xor syndr0 when errorPos = "1010" else
                                                                              msg(((SYMB_BITWIDTH+4*SYMB_BITWIDTH)-1) downto (4*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+3*SYMB_BITWIDTH)-1) downto (3*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+3*SYMB_BITWIDTH)-1) downto (3*SYMB_BITWIDTH)) xor syndr0 when errorPos = "1011" else
                                                                              msg(((SYMB_BITWIDTH+3*SYMB_BITWIDTH)-1) downto (3*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+2*SYMB_BITWIDTH)-1) downto (2*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+2*SYMB_BITWIDTH)-1) downto (2*SYMB_BITWIDTH)) xor syndr0 when errorPos = "1100" else
                                                                              msg(((SYMB_BITWIDTH+2*SYMB_BITWIDTH)-1) downto (2*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+1*SYMB_BITWIDTH)-1) downto (1*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+1*SYMB_BITWIDTH)-1) downto (1*SYMB_BITWIDTH)) xor syndr0 when errorPos = "1101" else
                                                                              msg(((SYMB_BITWIDTH+1*SYMB_BITWIDTH)-1) downto (1*SYMB_BITWIDTH));
                                          
    decMsg(((SYMB_BITWIDTH+0*SYMB_BITWIDTH)-1) downto (0*SYMB_BITWIDTH))   <= msg(((SYMB_BITWIDTH+0*SYMB_BITWIDTH)-1) downto (0*SYMB_BITWIDTH)) xor syndr0 when errorPos = "1110" else
                                                                              msg(((SYMB_BITWIDTH+0*SYMB_BITWIDTH)-1) downto (0*SYMB_BITWIDTH));
                                                                              
    data_o <= decMsg;
    
END behabioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--