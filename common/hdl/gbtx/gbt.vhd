------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    23:45:21 2016-04-20
-- Module Name:    GBT 
-- Description:    GBTX wrapper: this is a modified version of the original GBT-FPGA top level, but supports arbitrary number of GBT and is not tied to MGT quads.
--                 In fact MGT instantiation and related clocking code has been removed completely, and is instead done in the system layer as usual.  
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Xilinx devices library:
library unisim;
use unisim.vcomponents.all;

-- Custom libraries and packages:
use work.gbt_bank_package.all;
use work.vendor_specific_gbt_bank_package.all;
use work.common_pkg.all;
use work.gem_pkg.all;

--=================================================================================================--
--#######################################   Entity   ##############################################--
--=================================================================================================--

entity gbt is
    generic(
        NUM_LINKS       : integer              := 1;
        TX_OPTIMIZATION : integer range 0 to 1 := STANDARD;
        RX_OPTIMIZATION : integer range 0 to 1 := STANDARD;
        TX_ENCODING     : integer range 0 to 1 := GBT_FRAME;
        RX_ENCODING_ODD : integer range 0 to 1 := GBT_FRAME;
        RX_ENCODING_EVEN: integer range 0 to 1 := GBT_FRAME
    );
    port(
        reset_i                     : in  std_logic;
        cnt_reset_i                 : in  std_logic;

        --========--
        -- Clocks --     
        --========--

        tx_frame_clk_i              : in  std_logic;
        rx_frame_clk_i              : in  std_logic;
        tx_word_clk_arr_i           : in  std_logic_vector(NUM_LINKS - 1 downto 0);
        rx_word_clk_arr_i           : in  std_logic_vector(NUM_LINKS - 1 downto 0);
        rx_word_common_clk_i        : in  std_logic;

        --========--
        -- GBT TX --
        --========--

        tx_we_arr_i                 : in  std_logic_vector(NUM_LINKS - 1 downto 0);
        tx_data_arr_i               : in  t_gbt_frame_array(NUM_LINKS - 1 downto 0);
        tx_bitslip_cnt_i            : in  t_std7_array(NUM_LINKS - 1 downto 0);

        --========--              
        -- GBT RX --              
        --========-- 

        rx_data_valid_arr_o         : out std_logic_vector(NUM_LINKS - 1 downto 0);
        rx_data_arr_o               : out t_gbt_frame_array(NUM_LINKS - 1 downto 0);
        rx_data_widebus_arr_o       : out t_std32_array(NUM_LINKS - 1 downto 0); -- extra 32 bits of data if RX_ENCODING is set to WIDEBUS
        
        --========--              
        --   MGT  --              
        --========-- 
        
        mgt_status_arr_i            : in  t_mgt_status_arr(NUM_LINKS - 1 downto 0);
        mgt_ctrl_arr_o              : out t_mgt_ctrl_arr(NUM_LINKS - 1 downto 0);        
        mgt_tx_data_arr_o           : out t_std40_array(NUM_LINKS - 1 downto 0);
        mgt_rx_data_arr_i           : in  t_std40_array(NUM_LINKS - 1 downto 0);

        --===========--              
        --   Status  --              
        --===========-- 
        
        link_status_arr_o           : out t_gbt_link_status_arr(NUM_LINKS - 1 downto 0)
        
    );
end gbt;

--=================================================================================================--
--####################################   Architecture   ###########################################-- 
--=================================================================================================--

architecture gbt_arch of gbt is

    type t_int_array is array (integer range <>) of integer;
    constant RX_ENCODING_EVEN_ODD   : t_int_array(0 to 1) := (RX_ENCODING_EVEN, RX_ENCODING_ODD);
    
    --================================ Signal Declarations ================================--

    --========--
    -- GBT TX --
    --========--   

    -- Comment: TX word width is device dependent.

    signal tx_word_data_arr             : t_std40_array(NUM_LINKS - 1 downto 0);
    signal tx_phaligned                 : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal tx_phalign_done              : std_logic_vector(NUM_LINKS - 1 downto 0);

    signal tx_data_arr                  : t_gbt_frame_array(NUM_LINKS - 1 downto 0);
    signal tx_data_encoded_arr          : t_std120_array(NUM_LINKS - 1 downto 0);
    signal tx_data_encoded_slipped_arr  : t_std120_array(NUM_LINKS - 1 downto 0);

    signal tx_gearbox_aligned           : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal tx_gearbox_align_done        : std_logic_vector(NUM_LINKS - 1 downto 0);

    --========--              
    -- GBT RX --              
    --========--     

    signal rx_gearbox_clk_en            : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_gearbox_ready             : std_logic_vector(NUM_LINKS - 1 downto 0);
    
    signal rx_data_encoded_arr          : t_std120_array(NUM_LINKS - 1 downto 0);
    
    signal rx_word_data_arr             : t_std40_array(NUM_LINKS - 1 downto 0);

    signal rx_common_word_clk           : std_logic;
    signal mgt_sync_rx_data_arr         : t_std40_array(NUM_LINKS - 1 downto 0);
    signal mgt_sync_rx_valid_arr        : std_logic_vector(NUM_LINKS - 1 downto 0);
   
    signal mgt_rx_bitslip_cnt_arr       : t_std8_array(NUM_LINKS - 1 downto 0);
    signal mgt_rx_data_bitslipped_arr   : t_std40_array(NUM_LINKS - 1 downto 0);
   
    signal rx_data_arr                  : t_gbt_frame_array(NUM_LINKS - 1 downto 0);
    signal rx_data_widebus_arr          : t_std32_array(NUM_LINKS - 1 downto 0); -- extra 32 bits of data if RX_ENCODING is set to WIDEBUS
    
    signal rx_link_good_arr             : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_ready_arr                 : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_ovf_arr                   : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_ovf_sync_arr              : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_unf_arr                   : std_logic_vector(NUM_LINKS - 1 downto 0);

    signal rx_error_detect_flag         : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_error_cnt                 : t_std8_array(NUM_LINKS - 1 downto 0);

    signal rx_header_flag               : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_header_locked             : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_header_locked_sync        : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_bitslip_en                : std_logic_vector(NUM_LINKS - 1 downto 0);
        
--=====================================================================================--

--=================================================================================================--
begin                                   --========####   Architecture Body   ####========-- 
--=================================================================================================--

    mgt_ctrl_arr_o <= (others => (txreset => '0', rxreset => '0', rxslide => '0'));
    
   --===============--
   -- RX Sync FIFOs --
   --===============--

    -- put the data from all GBT MGT RXs through sync a FIFO immediately to get it out of the BUFH domain and put it on a common clock domain which is on BUFG
    -- This is to let the GBT cores to be placed more freely (not constrained to the area that the RX BUFHs are spanning)
   
    rx_common_word_clk <= rx_word_common_clk_i;
    
    g_rx_sync_fifos : for i in 0 to NUM_LINKS - 1 generate
        
        i_rx_sync_fifo : entity work.gearbox
            generic map(
                g_IMPL_TYPE         => "FIFO",
                g_INPUT_DATA_WIDTH  => 40,
                g_OUTPUT_DATA_WIDTH => 40
            )
            port map(
                reset_i     => reset_i or not mgt_status_arr_i(i).rx_reset_done,
                wr_clk_i    => rx_word_clk_arr_i(i),
                rd_clk_i    => rx_common_word_clk,
                din_i       => rx_word_data_arr(i),
                valid_i     => '1',
                dout_o      => mgt_sync_rx_data_arr(i),
                valid_o     => mgt_sync_rx_valid_arr(i),
                overflow_o  => rx_ovf_arr(i),
                underflow_o => rx_unf_arr(i)
            );
        
        rx_word_data_arr(i) <= mgt_rx_data_arr_i(i);
        
        i_sync_ovf : entity work.synch generic map(N_STAGES => 2) port map(async_i => rx_ovf_arr(i), clk_i   => rx_common_word_clk, sync_o  => rx_ovf_sync_arr(i));
        i_gbt_rx_sync_ovf_latch : entity work.latch
            port map(
                reset_i => reset_i or cnt_reset_i,
                clk_i   => rx_common_word_clk,
                input_i => rx_ovf_sync_arr(i),
                latch_o => link_status_arr_o(i).gbt_rx_sync_status.had_ovf
            );

        i_gbt_rx_sync_unf_latch : entity work.latch
            port map(
                reset_i => reset_i or cnt_reset_i,
                clk_i   => rx_common_word_clk,
                input_i => rx_unf_arr(i),
                latch_o => link_status_arr_o(i).gbt_rx_sync_status.had_unf
            );
                    
    end generate;
   
   --========--
   -- GBT TX --
   --========--
   
	gbtTx_gen: for i in 0 to NUM_LINKS -1 generate 
        gbt_txdatapath_inst: entity work.gbt_tx        
            generic map (            
                TX_ENCODING                        => TX_ENCODING
            )
            port map (                
                TX_RESET_I                         => reset_i,
                TX_FRAMECLK_I                      => tx_frame_clk_i,
                TX_CLKEN_i                         => '1',
                
                TX_ENCODING_SEL_i                  => '0', -- only used in dynamic encoding mode, which we don't use                  
                TX_ISDATA_SEL_I                    => tx_we_arr_i(i), 

                TX_DATA_I                          => tx_data_arr(i),
                TX_EXTRA_DATA_WIDEBUS_I            => (others => '0'), -- TX wide bus??
                
                TX_FRAME_o                         => tx_data_encoded_arr(i)
            );

        i_tx_bitslip: entity work.bitslip
            generic map(
                g_DATA_WIDTH           => 120,
                g_SLIP_CNT_WIDTH       => 7,
                g_TRANSMIT_LOW_TO_HIGH => false
            )
            port map(
                clk_i      => tx_frame_clk_i,
                slip_cnt_i => tx_bitslip_cnt_i(i),
                data_i     => tx_data_encoded_arr(i),
                data_o     => tx_data_encoded_slipped_arr(i)
            );
            
        gbt_txgearbox_inst : entity work.gbt_tx_gearbox
            generic map(
                TX_OPTIMIZATION => TX_OPTIMIZATION
            )
            port map(
                TX_RESET_I      => reset_i,
                TX_FRAMECLK_I   => tx_frame_clk_i,
                TX_CLKEN_i      => '1',
                TX_WORDCLK_I    => tx_word_clk_arr_i(i),
                ---------------------------------------
                TX_PHALIGNED_o  => tx_phaligned(i),
                TX_PHCOMPUTED_o => tx_phalign_done(i),
                TX_FRAME_I      => tx_data_encoded_slipped_arr(i),
                TX_WORD_O       => tx_word_data_arr(i)
            );
			
		i_sync_gearbox_aligned : entity work.synch
		    generic map(
		        N_STAGES => 2
		    )
		    port map(
		        async_i => tx_phaligned(i),
		        clk_i   => tx_frame_clk_i,
		        sync_o  => tx_gearbox_aligned(i)
		    );
		
		i_sync_gearbox_align_done : entity work.synch
		    generic map(
		        N_STAGES => 2
		    )
		    port map(
		        async_i => tx_phalign_done(i),
		        clk_i   => tx_frame_clk_i,
		        sync_o  => tx_gearbox_align_done(i)
		    );
		
		mgt_tx_data_arr_o(i) <= tx_word_data_arr(i);
		tx_data_arr(i)       <= tx_data_arr_i(i);
		
		link_status_arr_o(i).gbt_tx_gearbox_ready <= tx_gearbox_aligned(i) and tx_gearbox_align_done(i);
		link_status_arr_o(i).gbt_tx_ready <= tx_gearbox_aligned(i) and tx_gearbox_align_done(i);
        
        i_tx_gearbox_not_ready_latch: entity work.latch
            port map(
                reset_i => reset_i or cnt_reset_i,
                clk_i   => tx_frame_clk_i,
                input_i => not tx_gearbox_aligned(i) or not tx_gearbox_align_done(i),
                latch_o => link_status_arr_o(i).gbt_tx_had_not_ready
            );
        
	end generate;

   --========--              
   -- GBT RX --              
   --========--
   
	gbtRx_gen: for i in 0 to NUM_LINKS -1 generate    

        gbt_rxgearbox_inst : entity work.gbt_rx_gearbox
            generic map(
                RX_OPTIMIZATION => RX_OPTIMIZATION
            )
            port map(
                RX_RESET_I      => reset_i,
                RX_WORDCLK_I    => rx_common_word_clk, --rx_word_clk_arr_i(i), -- TODO: remove the sync fifos
                RX_FRAMECLK_I   => rx_frame_clk_i,
                RX_CLKEN_i      => '1',
                RX_CLKEN_o      => rx_gearbox_clk_en(i),
                ---------------------------------------
                RX_HEADERFLAG_i => rx_header_flag(i),
                READY_O         => rx_gearbox_ready(i),
                ---------------------------------------
                RX_WORD_I       => mgt_rx_data_bitslipped_arr(i),
                RX_FRAME_O      => rx_data_encoded_arr(i)
            ); 

        gbt_rxdatapath_inst: entity work.gbt_rx            
            generic map (
                RX_ENCODING                        => RX_ENCODING_EVEN_ODD(i mod 2)
            )         
            port map (    
                RX_RESET_I                         => not(rx_gearbox_ready(i)),
                RX_FRAMECLK_I                      => rx_frame_clk_i,
                RX_CLKEN_i                         => rx_gearbox_clk_en(i),
                
                RX_ENCODING_SEL_i                  => '0',   -- only used in dynamic encoding mode, which we don't use             
                RX_READY_O                         => rx_ready_arr(i),
                RX_ISDATA_FLAG_O                   => rx_data_valid_arr_o(i),
                RX_ERROR_DETECTED                  => rx_error_detect_flag(i),
                RX_BIT_MODIFIED_FLAG               => open,
                    
                GBT_RXFRAME_i                      => rx_data_encoded_arr(i),
                RX_DATA_O                          => rx_data_arr(i),
                RX_EXTRA_DATA_WIDEBUS_O            => rx_data_widebus_arr(i)
            );
            
        i_err_cnt: entity work.counter
            generic map(
                g_COUNTER_WIDTH  => 8,
                g_ALLOW_ROLLOVER => false
            )
            port map(
                ref_clk_i => rx_frame_clk_i,
                reset_i   => reset_i or cnt_reset_i,
                en_i      => rx_error_detect_flag(i),
                count_o   => rx_error_cnt(i)
            );
        
        rx_link_good_arr(i)                           <= rx_ready_arr(i) and rx_gearbox_ready(i) and rx_header_locked_sync(i);
        link_status_arr_o(i).gbt_rx_ready             <= rx_link_good_arr(i);
        link_status_arr_o(i).gbt_rx_correction_cnt    <= rx_error_cnt(i);
        link_status_arr_o(i).gbt_rx_correction_flag   <= rx_error_detect_flag(i);
        link_status_arr_o(i).gbt_rx_gearbox_ready     <= rx_gearbox_ready(i);
        link_status_arr_o(i).gbt_rx_header_locked     <= rx_header_locked_sync(i);
        link_status_arr_o(i).gbt_rx_num_bitslips      <= mgt_rx_bitslip_cnt_arr(i);
		rx_data_arr_o(i)                              <= rx_data_arr(i);
        rx_data_widebus_arr_o(i)                      <= rx_data_widebus_arr(i);
		 
        patternSearch : entity work.mgt_framealigner_pattsearch
            port map(
                RX_RESET_I         => not (mgt_status_arr_i(i).rx_reset_done),
                RX_WORDCLK_I       => rx_common_word_clk, --rx_word_clk_arr_i(i), -- TODO: remove the sync fifos
                RX_BITSLIP_CMD_O   => rx_bitslip_en(i),
                MGT_BITSLIPDONE_i  => '1',
                RX_HEADER_LOCKED_O => rx_header_locked(i),
                RX_HEADER_FLAG_O   => rx_header_flag(i),
                RX_BITSLIPISEVEN_o => open,
                RX_WORD_I          => mgt_rx_data_bitslipped_arr(i)
            );

        i_sync_header_locked: entity work.synch
            generic map(
                N_STAGES => 2
            )
            port map(
                clk_i   => rx_frame_clk_i,
                async_i => rx_header_locked(i),
                sync_o  => rx_header_locked_sync(i)
            );

        process(rx_common_word_clk) -- TODO: remove the sync fifos
        begin
            if rising_edge(rx_common_word_clk) then -- TODO: remove the sync fifos
                if (reset_i = '1') then
                    mgt_rx_bitslip_cnt_arr(i) <= (others => '0');
                else
                    if rx_bitslip_en(i) = '1' then
                        if mgt_rx_bitslip_cnt_arr(i) = x"27" then -- roll over at 40 bits
                            mgt_rx_bitslip_cnt_arr(i) <= (others => '0');
                        else
                            mgt_rx_bitslip_cnt_arr(i) <= std_logic_vector(unsigned(mgt_rx_bitslip_cnt_arr(i)) + x"01");
                        end if;
                    end if;
                end if;
            end if;
        end process;
        
        i_bitslip : entity work.bitslip
            generic map(
                g_DATA_WIDTH           => 40,
                g_SLIP_CNT_WIDTH       => 8,
                g_TRANSMIT_LOW_TO_HIGH => true
            )
            port map(
                clk_i      => rx_common_word_clk, -- TODO: remove the sync fifos
                slip_cnt_i => mgt_rx_bitslip_cnt_arr(i),
                data_i     => mgt_sync_rx_data_arr(i), --rx_wordNbit_from_mgt(i) -- TODO: remove the sync fifos
                data_o     => mgt_rx_data_bitslipped_arr(i)
            );

        i_gbt_rx_not_ready_latch : entity work.latch
            port map(
                reset_i => reset_i or cnt_reset_i,
                clk_i   => rx_frame_clk_i,
                input_i => not rx_link_good_arr(i),
                latch_o => link_status_arr_o(i).gbt_rx_had_not_ready
            );

        i_gbt_rx_header_unlock_latch : entity work.latch
            port map(
                reset_i => reset_i or cnt_reset_i,
                clk_i   => rx_frame_clk_i,
                input_i => not rx_header_locked_sync(i),
                latch_o => link_status_arr_o(i).gbt_rx_header_had_unlock
            );

	end generate;

   --=====================================================================================--
end gbt_arch;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--
