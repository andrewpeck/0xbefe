-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 1.0
--! @brief N7K5 Reed-Solomon encoder
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;

--! Include the LpGBT-FPGA specific package
use work.lpgbtfpga_package.all;

--! @brief rs_encoder_N7K5 - N7K5 Reed-Solomon encoder
ENTITY rs_encoder_N7K5 IS
   GENERIC (
		N								: integer := 7;
		K 								: integer := 5;
		SYMB_BITWIDTH					: integer := 3
   );
   PORT (
		msg								: in  std_logic_vector((K*SYMB_BITWIDTH)-1 downto 0);       --! Message to be encoded
		parity							: out std_logic_vector(((N-K)*SYMB_BITWIDTH)-1 downto 0)    --! FEC output    
   );
END rs_encoder_N7K5;

--! @brief rs_encoder_N7K5 architecture - N7K5 Reed-Solomon encoder
ARCHITECTURE behabioral of rs_encoder_N7K5 IS

	-- Dependant parameters
	constant P			: integer 	:= N-K;
	constant INP_BW		: integer	:= SYMB_BITWIDTH*K;
	constant OUT_BW		: integer	:= SYMB_BITWIDTH*N;
	constant POL_BW		: integer	:= SYMB_BITWIDTH*P;
	constant STG_BW		: integer	:= SYMB_BITWIDTH*(P+1);
	
	type reg_arr is array(integer range <>) of std_logic_vector((STG_BW-1) downto 0);	
	signal stageOut				: reg_arr((K-1) downto 0);
	signal multOut				: reg_arr((K-1) downto 0);

	
BEGIN                 --========####   Architecture Body   ####========-- 
		
	-- ---------------- The Parallel LFSR HDL description  ---------------- --
  
	-- In the first layer, the rightmost node is an addition to zero, so
	-- we route it directly to the stage output	
	stageOut(0)(((SYMB_BITWIDTH+POL_BW)-1) downto POL_BW) 	<= msg((SYMB_BITWIDTH-1) downto 0);

	-- Since in the first layer there are no adders, the stageOut is
	-- connected to the multiplier output. Hence, the multOut is set to zero.
	multOut(0)(((SYMB_BITWIDTH*P)-1) downto 0) 				<= (others => '0');

	-- The rightmost multOut is never used (we only add the input codeword
	-- with the previous node), so it is set to zero. On the other hand,
	-- the leftmost node only performs multiplication, so multOut is
	-- routed to stageOut.
	multOut(0)(((SYMB_BITWIDTH+POL_BW)-1) downto POL_BW) 	<= (others => '0');
	
	multAndStage_gen:	for i in 1 to (K-1) generate	
		multOut(i)(((SYMB_BITWIDTH+POL_BW)-1) downto POL_BW) 	<= (others => '0');
		stageOut(i)((SYMB_BITWIDTH-1) downto 0) 				<= multOut(i)((SYMB_BITWIDTH-1) downto 0);	
	end generate;
	
	-- Generates the instances of the GF(2^m) of the LFSR parallel network
	-- The first line is a particular case...

	-- The GF multiplications units in the first stage
	stageOut(0)(2)	<= 	msg(1);
	stageOut(0)(1)	<= 	msg(0) xor msg(2);
	stageOut(0)(0)	<= 	msg(2);	
	stageOut(0)(3)  <= 	msg(2) xor msg(0);
	stageOut(0)(4)  <= 	msg(1) xor msg(0) xor msg(2);
	stageOut(0)(5)  <= 	msg(2) xor msg(1);
	
	-- The remaining stages..
	GF_gen:	for i in 1 to (K-1) generate	
	
		-- The GF add units
		stageOut(i)((POL_BW+SYMB_BITWIDTH-1) downto POL_BW)	<= msg(((1+i)*SYMB_BITWIDTH)-1 downto i*SYMB_BITWIDTH) xor stageOut(i-1)((SYMB_BITWIDTH*(P-1)+SYMB_BITWIDTH)-1 downto SYMB_BITWIDTH*(P-1));
	
		-- The GF multiplication units		
		multOut(i)(2)	<= 	stageOut(i)(POL_BW+1);
		multOut(i)(1)	<= 	stageOut(i)(POL_BW) xor stageOut(i)(POL_BW+2);
		multOut(i)(0)	<= 	stageOut(i)(POL_BW+2);	
		
		multOut(i)(3)  <= 	stageOut(i)(POL_BW+2) xor stageOut(i)(POL_BW+0);
		multOut(i)(4)  <= 	stageOut(i)(POL_BW+1) xor stageOut(i)(POL_BW+0) xor stageOut(i)(POL_BW+2);
		multOut(i)(5)  <= 	stageOut(i)(POL_BW+2) xor stageOut(i)(POL_BW+1);
	
		GF_internal_gen:	for j in 1 to (P-1) generate
		
			stageOut(i)(((j+1)*SYMB_BITWIDTH)-1 downto SYMB_BITWIDTH*j)		<= multOut(i)(((j+1)*SYMB_BITWIDTH)-1 downto SYMB_BITWIDTH*j) xor stageOut(i-1)((j*SYMB_BITWIDTH)-1 downto SYMB_BITWIDTH*(j-1));
			
		end generate;
		
	end generate;
	
	-- Parity computing..
	Parity_gen:	for l in 0 to (P-1) generate
		parity(((l+1)*SYMB_BITWIDTH)-1 downto l*SYMB_BITWIDTH) 				<= stageOut(K-1)((STG_BW-(l+1)*SYMB_BITWIDTH)-1 downto STG_BW-(l+2)*SYMB_BITWIDTH);
	end generate;
	
END behabioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--