----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- S-Bits Remapping
--

-- A. Peck, L. Petre, J. Jaramillo
--
----------------------------------------------------------------------------------
-- Description:
--
--   This module remaps S-bits according to the Channel-to-Strip mapping,
--   determined by the Hybrid and the readout board
--
--   For the GE11 Optohybrid, there are different
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.hardware_pkg.all;
use work.cluster_pkg.all;

entity channel_to_strip is
  generic (
    USE_DYNAMIC_MAPPING : boolean              := false;
    STATIC_MAPPING      : natural range 0 to 2 := 0;
    REGISTER_OUTPUT     : boolean              := true
    );
  port(
    clock       : in  std_logic;
    mapping     : in  natural range 0 to 2;
    channels_in : in  sbits_array_t(NUM_VFATS-1 downto 0);
    strips_out  : out sbits_array_t(NUM_VFATS-1 downto 0)
    );
end channel_to_strip;

architecture Behavioral of channel_to_strip is

  signal identity_map : sbits_array_t(NUM_VFATS-1 downto 0) := (others => (others => '0'));
  signal strips       : sbits_array_t(NUM_VFATS-1 downto 0) := (others => (others => '0'));

begin

  remap_ge21 : if (GE21 = 1) generate
    strips <= identity_map;
  end generate;

  remap_ge11 : if (GE11 = 1) generate

    signal long_map  : sbits_array_t(NUM_VFATS-1 downto 0) := (others => (others => '0'));
    signal short_map : sbits_array_t(NUM_VFATS-1 downto 0) := (others => (others => '0'));

    function select_mapping_ge11 (
      sel      : integer;
      identity : sbits_array_t(NUM_VFATS-1 downto 0);
      short    : sbits_array_t(NUM_VFATS-1 downto 0);
      long     : sbits_array_t(NUM_VFATS-1 downto 0)
      )
      return sbits_array_t is
    begin

      if sel = 0 then
        return identity;
      elsif (sel = 1) then
        return short;
      elsif (sel = 2) then
        return long;
      else
        return identity;
      end if;

    end;

  begin


    --------------------------------------------------------------------------------
    -- Choose between static (compile-time) and dynamic (run-time) mapping selection
    --------------------------------------------------------------------------------

    static_gen : if (not USE_DYNAMIC_MAPPING) generate
      strips <= select_mapping_ge11 (STATIC_MAPPING, identity_map, short_map, long_map);
    end generate;

    dynamic_gen : if (USE_DYNAMIC_MAPPING) generate
      strips <= select_mapping_ge11 (mapping, identity_map, short_map, long_map);
    end generate;

    --------------------------------------------------------------------------------
    -- GE11 Mapping
    --------------------------------------------------------------------------------

    vfat_short_loop : for I in 0 to (NUM_VFATS-1) generate
    begin
      map_a : if (I = 2 or I = 3 or I = 5 or I = 7 or I = 8 or  I = 9 or I = 10 or I = 11 or I = 13 or I = 15) generate
        short_map(I)(0)  <= channels_in(I)(1);
        short_map(I)(1)  <= channels_in(I)(3);
        short_map(I)(2)  <= channels_in(I)(5);
        short_map(I)(3)  <= channels_in(I)(7);
        short_map(I)(4)  <= channels_in(I)(9);
        short_map(I)(5)  <= channels_in(I)(11);
        short_map(I)(6)  <= channels_in(I)(13);
        short_map(I)(7)  <= channels_in(I)(15);
        short_map(I)(8)  <= channels_in(I)(17);
        short_map(I)(9)  <= channels_in(I)(19);
        short_map(I)(10) <= channels_in(I)(21);
        short_map(I)(11) <= channels_in(I)(23);
        short_map(I)(12) <= channels_in(I)(25);
        short_map(I)(13) <= channels_in(I)(27);
        short_map(I)(14) <= channels_in(I)(29);
        short_map(I)(15) <= channels_in(I)(31);
        short_map(I)(16) <= channels_in(I)(33);
        short_map(I)(17) <= channels_in(I)(35);
        short_map(I)(18) <= channels_in(I)(37);
        short_map(I)(19) <= channels_in(I)(39);
        short_map(I)(20) <= channels_in(I)(41);
        short_map(I)(21) <= channels_in(I)(43);
        short_map(I)(22) <= channels_in(I)(45);
        short_map(I)(23) <= channels_in(I)(47);
        short_map(I)(24) <= channels_in(I)(49);
        short_map(I)(25) <= channels_in(I)(51);
        short_map(I)(26) <= channels_in(I)(53);
        short_map(I)(27) <= channels_in(I)(55);
        short_map(I)(28) <= channels_in(I)(57);
        short_map(I)(29) <= channels_in(I)(59);
        short_map(I)(30) <= channels_in(I)(61);
        short_map(I)(31) <= channels_in(I)(63);
        short_map(I)(32) <= channels_in(I)(62);
        short_map(I)(33) <= channels_in(I)(60);
        short_map(I)(34) <= channels_in(I)(58);
        short_map(I)(35) <= channels_in(I)(56);
        short_map(I)(36) <= channels_in(I)(54);
        short_map(I)(37) <= channels_in(I)(52);
        short_map(I)(38) <= channels_in(I)(50);
        short_map(I)(39) <= channels_in(I)(48);
        short_map(I)(40) <= channels_in(I)(46);
        short_map(I)(41) <= channels_in(I)(44);
        short_map(I)(42) <= channels_in(I)(42);
        short_map(I)(43) <= channels_in(I)(40);
        short_map(I)(44) <= channels_in(I)(38);
        short_map(I)(45) <= channels_in(I)(36);
        short_map(I)(46) <= channels_in(I)(34);
        short_map(I)(47) <= channels_in(I)(32);
        short_map(I)(48) <= channels_in(I)(30);
        short_map(I)(49) <= channels_in(I)(28);
        short_map(I)(50) <= channels_in(I)(26);
        short_map(I)(51) <= channels_in(I)(24);
        short_map(I)(52) <= channels_in(I)(22);
        short_map(I)(53) <= channels_in(I)(20);
        short_map(I)(54) <= channels_in(I)(18);
        short_map(I)(55) <= channels_in(I)(16);
        short_map(I)(56) <= channels_in(I)(14);
        short_map(I)(57) <= channels_in(I)(12);
        short_map(I)(58) <= channels_in(I)(10);
        short_map(I)(59) <= channels_in(I)(8);
        short_map(I)(60) <= channels_in(I)(6);
        short_map(I)(61) <= channels_in(I)(4);
        short_map(I)(62) <= channels_in(I)(2);
        short_map(I)(63) <= channels_in(I)(0);
      end generate;

      map_b : if (I = 0 or I = 1 or I = 4 or I = 6 or I = 12 or I = 14) generate
        short_map(I)(0)  <= channels_in(I)(63);
        short_map(I)(1)  <= channels_in(I)(61);
        short_map(I)(2)  <= channels_in(I)(59);
        short_map(I)(3)  <= channels_in(I)(57);
        short_map(I)(4)  <= channels_in(I)(55);
        short_map(I)(5)  <= channels_in(I)(53);
        short_map(I)(6)  <= channels_in(I)(51);
        short_map(I)(7)  <= channels_in(I)(49);
        short_map(I)(8)  <= channels_in(I)(47);
        short_map(I)(9)  <= channels_in(I)(45);
        short_map(I)(10) <= channels_in(I)(43);
        short_map(I)(11) <= channels_in(I)(41);
        short_map(I)(12) <= channels_in(I)(39);
        short_map(I)(13) <= channels_in(I)(37);
        short_map(I)(14) <= channels_in(I)(35);
        short_map(I)(15) <= channels_in(I)(33);
        short_map(I)(16) <= channels_in(I)(31);
        short_map(I)(17) <= channels_in(I)(29);
        short_map(I)(18) <= channels_in(I)(27);
        short_map(I)(19) <= channels_in(I)(25);
        short_map(I)(20) <= channels_in(I)(23);
        short_map(I)(21) <= channels_in(I)(21);
        short_map(I)(22) <= channels_in(I)(19);
        short_map(I)(23) <= channels_in(I)(17);
        short_map(I)(24) <= channels_in(I)(15);
        short_map(I)(25) <= channels_in(I)(13);
        short_map(I)(26) <= channels_in(I)(11);
        short_map(I)(27) <= channels_in(I)(9);
        short_map(I)(28) <= channels_in(I)(7);
        short_map(I)(29) <= channels_in(I)(5);
        short_map(I)(30) <= channels_in(I)(3);
        short_map(I)(31) <= channels_in(I)(1);
        short_map(I)(32) <= channels_in(I)(0);
        short_map(I)(33) <= channels_in(I)(2);
        short_map(I)(34) <= channels_in(I)(4);
        short_map(I)(35) <= channels_in(I)(6);
        short_map(I)(36) <= channels_in(I)(8);
        short_map(I)(37) <= channels_in(I)(10);
        short_map(I)(38) <= channels_in(I)(12);
        short_map(I)(39) <= channels_in(I)(14);
        short_map(I)(40) <= channels_in(I)(16);
        short_map(I)(41) <= channels_in(I)(18);
        short_map(I)(42) <= channels_in(I)(20);
        short_map(I)(43) <= channels_in(I)(22);
        short_map(I)(44) <= channels_in(I)(24);
        short_map(I)(45) <= channels_in(I)(26);
        short_map(I)(46) <= channels_in(I)(28);
        short_map(I)(47) <= channels_in(I)(30);
        short_map(I)(48) <= channels_in(I)(32);
        short_map(I)(49) <= channels_in(I)(34);
        short_map(I)(50) <= channels_in(I)(36);
        short_map(I)(51) <= channels_in(I)(38);
        short_map(I)(52) <= channels_in(I)(40);
        short_map(I)(53) <= channels_in(I)(42);
        short_map(I)(54) <= channels_in(I)(44);
        short_map(I)(55) <= channels_in(I)(46);
        short_map(I)(56) <= channels_in(I)(48);
        short_map(I)(57) <= channels_in(I)(50);
        short_map(I)(58) <= channels_in(I)(52);
        short_map(I)(59) <= channels_in(I)(54);
        short_map(I)(60) <= channels_in(I)(56);
        short_map(I)(61) <= channels_in(I)(58);
        short_map(I)(62) <= channels_in(I)(60);
        short_map(I)(63) <= channels_in(I)(62);
      end generate;

      map_c : if (I = 16 or I = 17 or I = 20 or I = 22) generate
        short_map(I)(0)  <= channels_in(I)(0);
        short_map(I)(1)  <= channels_in(I)(2);
        short_map(I)(2)  <= channels_in(I)(4);
        short_map(I)(3)  <= channels_in(I)(6);
        short_map(I)(4)  <= channels_in(I)(8);
        short_map(I)(5)  <= channels_in(I)(10);
        short_map(I)(6)  <= channels_in(I)(12);
        short_map(I)(7)  <= channels_in(I)(14);
        short_map(I)(8)  <= channels_in(I)(16);
        short_map(I)(9)  <= channels_in(I)(18);
        short_map(I)(10) <= channels_in(I)(20);
        short_map(I)(11) <= channels_in(I)(22);
        short_map(I)(12) <= channels_in(I)(24);
        short_map(I)(13) <= channels_in(I)(26);
        short_map(I)(14) <= channels_in(I)(28);
        short_map(I)(15) <= channels_in(I)(30);
        short_map(I)(16) <= channels_in(I)(32);
        short_map(I)(17) <= channels_in(I)(34);
        short_map(I)(18) <= channels_in(I)(36);
        short_map(I)(19) <= channels_in(I)(38);
        short_map(I)(20) <= channels_in(I)(40);
        short_map(I)(21) <= channels_in(I)(42);
        short_map(I)(22) <= channels_in(I)(44);
        short_map(I)(23) <= channels_in(I)(46);
        short_map(I)(24) <= channels_in(I)(48);
        short_map(I)(25) <= channels_in(I)(50);
        short_map(I)(26) <= channels_in(I)(52);
        short_map(I)(27) <= channels_in(I)(54);
        short_map(I)(28) <= channels_in(I)(56);
        short_map(I)(29) <= channels_in(I)(58);
        short_map(I)(30) <= channels_in(I)(60);
        short_map(I)(31) <= channels_in(I)(62);
        short_map(I)(32) <= channels_in(I)(63);
        short_map(I)(33) <= channels_in(I)(61);
        short_map(I)(34) <= channels_in(I)(59);
        short_map(I)(35) <= channels_in(I)(57);
        short_map(I)(36) <= channels_in(I)(55);
        short_map(I)(37) <= channels_in(I)(53);
        short_map(I)(38) <= channels_in(I)(51);
        short_map(I)(39) <= channels_in(I)(49);
        short_map(I)(40) <= channels_in(I)(47);
        short_map(I)(41) <= channels_in(I)(45);
        short_map(I)(42) <= channels_in(I)(43);
        short_map(I)(43) <= channels_in(I)(41);
        short_map(I)(44) <= channels_in(I)(39);
        short_map(I)(45) <= channels_in(I)(37);
        short_map(I)(46) <= channels_in(I)(35);
        short_map(I)(47) <= channels_in(I)(33);
        short_map(I)(48) <= channels_in(I)(31);
        short_map(I)(49) <= channels_in(I)(29);
        short_map(I)(50) <= channels_in(I)(27);
        short_map(I)(51) <= channels_in(I)(25);
        short_map(I)(52) <= channels_in(I)(23);
        short_map(I)(53) <= channels_in(I)(21);
        short_map(I)(54) <= channels_in(I)(19);
        short_map(I)(55) <= channels_in(I)(17);
        short_map(I)(56) <= channels_in(I)(15);
        short_map(I)(57) <= channels_in(I)(13);
        short_map(I)(58) <= channels_in(I)(11);
        short_map(I)(59) <= channels_in(I)(9);
        short_map(I)(60) <= channels_in(I)(7);
        short_map(I)(61) <= channels_in(I)(5);
        short_map(I)(62) <= channels_in(I)(3);
        short_map(I)(63) <= channels_in(I)(1);
      end generate;

      map_d : if (I = 18 or I = 19 or I = 21 or I = 23) generate
        short_map(I)(0)  <= channels_in(I)(62);
        short_map(I)(1)  <= channels_in(I)(60);
        short_map(I)(2)  <= channels_in(I)(58);
        short_map(I)(3)  <= channels_in(I)(56);
        short_map(I)(4)  <= channels_in(I)(54);
        short_map(I)(5)  <= channels_in(I)(52);
        short_map(I)(6)  <= channels_in(I)(50);
        short_map(I)(7)  <= channels_in(I)(48);
        short_map(I)(8)  <= channels_in(I)(46);
        short_map(I)(9)  <= channels_in(I)(44);
        short_map(I)(10) <= channels_in(I)(42);
        short_map(I)(11) <= channels_in(I)(40);
        short_map(I)(12) <= channels_in(I)(38);
        short_map(I)(13) <= channels_in(I)(36);
        short_map(I)(14) <= channels_in(I)(34);
        short_map(I)(15) <= channels_in(I)(32);
        short_map(I)(16) <= channels_in(I)(30);
        short_map(I)(17) <= channels_in(I)(28);
        short_map(I)(18) <= channels_in(I)(26);
        short_map(I)(19) <= channels_in(I)(24);
        short_map(I)(20) <= channels_in(I)(22);
        short_map(I)(21) <= channels_in(I)(20);
        short_map(I)(22) <= channels_in(I)(18);
        short_map(I)(23) <= channels_in(I)(16);
        short_map(I)(24) <= channels_in(I)(14);
        short_map(I)(25) <= channels_in(I)(12);
        short_map(I)(26) <= channels_in(I)(10);
        short_map(I)(27) <= channels_in(I)(8);
        short_map(I)(28) <= channels_in(I)(6);
        short_map(I)(29) <= channels_in(I)(4);
        short_map(I)(30) <= channels_in(I)(2);
        short_map(I)(31) <= channels_in(I)(0);
        short_map(I)(32) <= channels_in(I)(1);
        short_map(I)(33) <= channels_in(I)(3);
        short_map(I)(34) <= channels_in(I)(5);
        short_map(I)(35) <= channels_in(I)(7);
        short_map(I)(36) <= channels_in(I)(9);
        short_map(I)(37) <= channels_in(I)(11);
        short_map(I)(38) <= channels_in(I)(13);
        short_map(I)(39) <= channels_in(I)(15);
        short_map(I)(40) <= channels_in(I)(17);
        short_map(I)(41) <= channels_in(I)(19);
        short_map(I)(42) <= channels_in(I)(21);
        short_map(I)(43) <= channels_in(I)(23);
        short_map(I)(44) <= channels_in(I)(25);
        short_map(I)(45) <= channels_in(I)(27);
        short_map(I)(46) <= channels_in(I)(29);
        short_map(I)(47) <= channels_in(I)(31);
        short_map(I)(48) <= channels_in(I)(33);
        short_map(I)(49) <= channels_in(I)(35);
        short_map(I)(50) <= channels_in(I)(37);
        short_map(I)(51) <= channels_in(I)(39);
        short_map(I)(52) <= channels_in(I)(41);
        short_map(I)(53) <= channels_in(I)(43);
        short_map(I)(54) <= channels_in(I)(45);
        short_map(I)(55) <= channels_in(I)(47);
        short_map(I)(56) <= channels_in(I)(49);
        short_map(I)(57) <= channels_in(I)(51);
        short_map(I)(58) <= channels_in(I)(53);
        short_map(I)(59) <= channels_in(I)(55);
        short_map(I)(60) <= channels_in(I)(57);
        short_map(I)(61) <= channels_in(I)(59);
        short_map(I)(62) <= channels_in(I)(61);
        short_map(I)(63) <= channels_in(I)(63);
      end generate;

    end generate;

    vfat_long_loop : for I in 0 to (NUM_VFATS-1) generate
    begin

      map_a : if (I >= 2 and I <= 15) generate
        long_map(I)(0)  <= channels_in(I)(1);
        long_map(I)(1)  <= channels_in(I)(3);
        long_map(I)(2)  <= channels_in(I)(5);
        long_map(I)(3)  <= channels_in(I)(7);
        long_map(I)(4)  <= channels_in(I)(9);
        long_map(I)(5)  <= channels_in(I)(11);
        long_map(I)(6)  <= channels_in(I)(13);
        long_map(I)(7)  <= channels_in(I)(15);
        long_map(I)(8)  <= channels_in(I)(17);
        long_map(I)(9)  <= channels_in(I)(19);
        long_map(I)(10) <= channels_in(I)(21);
        long_map(I)(11) <= channels_in(I)(23);
        long_map(I)(12) <= channels_in(I)(25);
        long_map(I)(13) <= channels_in(I)(27);
        long_map(I)(14) <= channels_in(I)(29);
        long_map(I)(15) <= channels_in(I)(31);
        long_map(I)(16) <= channels_in(I)(33);
        long_map(I)(17) <= channels_in(I)(35);
        long_map(I)(18) <= channels_in(I)(37);
        long_map(I)(19) <= channels_in(I)(39);
        long_map(I)(20) <= channels_in(I)(41);
        long_map(I)(21) <= channels_in(I)(43);
        long_map(I)(22) <= channels_in(I)(45);
        long_map(I)(23) <= channels_in(I)(47);
        long_map(I)(24) <= channels_in(I)(49);
        long_map(I)(25) <= channels_in(I)(51);
        long_map(I)(26) <= channels_in(I)(53);
        long_map(I)(27) <= channels_in(I)(55);
        long_map(I)(28) <= channels_in(I)(57);
        long_map(I)(29) <= channels_in(I)(59);
        long_map(I)(30) <= channels_in(I)(61);
        long_map(I)(31) <= channels_in(I)(63);
        long_map(I)(32) <= channels_in(I)(62);
        long_map(I)(33) <= channels_in(I)(60);
        long_map(I)(34) <= channels_in(I)(58);
        long_map(I)(35) <= channels_in(I)(56);
        long_map(I)(36) <= channels_in(I)(54);
        long_map(I)(37) <= channels_in(I)(52);
        long_map(I)(38) <= channels_in(I)(50);
        long_map(I)(39) <= channels_in(I)(48);
        long_map(I)(40) <= channels_in(I)(46);
        long_map(I)(41) <= channels_in(I)(44);
        long_map(I)(42) <= channels_in(I)(42);
        long_map(I)(43) <= channels_in(I)(40);
        long_map(I)(44) <= channels_in(I)(38);
        long_map(I)(45) <= channels_in(I)(36);
        long_map(I)(46) <= channels_in(I)(34);
        long_map(I)(47) <= channels_in(I)(32);
        long_map(I)(48) <= channels_in(I)(30);
        long_map(I)(49) <= channels_in(I)(28);
        long_map(I)(50) <= channels_in(I)(26);
        long_map(I)(51) <= channels_in(I)(24);
        long_map(I)(52) <= channels_in(I)(22);
        long_map(I)(53) <= channels_in(I)(20);
        long_map(I)(54) <= channels_in(I)(18);
        long_map(I)(55) <= channels_in(I)(16);
        long_map(I)(56) <= channels_in(I)(14);
        long_map(I)(57) <= channels_in(I)(12);
        long_map(I)(58) <= channels_in(I)(10);
        long_map(I)(59) <= channels_in(I)(8);
        long_map(I)(60) <= channels_in(I)(6);
        long_map(I)(61) <= channels_in(I)(4);
        long_map(I)(62) <= channels_in(I)(2);
        long_map(I)(63) <= channels_in(I)(0);
      end generate;

      map_b : if (I = 0 or I = 1) generate
        long_map(I)(0)  <= channels_in(I)(63);
        long_map(I)(1)  <= channels_in(I)(61);
        long_map(I)(2)  <= channels_in(I)(59);
        long_map(I)(3)  <= channels_in(I)(57);
        long_map(I)(4)  <= channels_in(I)(55);
        long_map(I)(5)  <= channels_in(I)(53);
        long_map(I)(6)  <= channels_in(I)(51);
        long_map(I)(7)  <= channels_in(I)(49);
        long_map(I)(8)  <= channels_in(I)(47);
        long_map(I)(9)  <= channels_in(I)(45);
        long_map(I)(10) <= channels_in(I)(43);
        long_map(I)(11) <= channels_in(I)(41);
        long_map(I)(12) <= channels_in(I)(39);
        long_map(I)(13) <= channels_in(I)(37);
        long_map(I)(14) <= channels_in(I)(35);
        long_map(I)(15) <= channels_in(I)(33);
        long_map(I)(16) <= channels_in(I)(31);
        long_map(I)(17) <= channels_in(I)(29);
        long_map(I)(18) <= channels_in(I)(27);
        long_map(I)(19) <= channels_in(I)(25);
        long_map(I)(20) <= channels_in(I)(23);
        long_map(I)(21) <= channels_in(I)(21);
        long_map(I)(22) <= channels_in(I)(19);
        long_map(I)(23) <= channels_in(I)(17);
        long_map(I)(24) <= channels_in(I)(15);
        long_map(I)(25) <= channels_in(I)(13);
        long_map(I)(26) <= channels_in(I)(11);
        long_map(I)(27) <= channels_in(I)(9);
        long_map(I)(28) <= channels_in(I)(7);
        long_map(I)(29) <= channels_in(I)(5);
        long_map(I)(30) <= channels_in(I)(3);
        long_map(I)(31) <= channels_in(I)(1);
        long_map(I)(32) <= channels_in(I)(0);
        long_map(I)(33) <= channels_in(I)(2);
        long_map(I)(34) <= channels_in(I)(4);
        long_map(I)(35) <= channels_in(I)(6);
        long_map(I)(36) <= channels_in(I)(8);
        long_map(I)(37) <= channels_in(I)(10);
        long_map(I)(38) <= channels_in(I)(12);
        long_map(I)(39) <= channels_in(I)(14);
        long_map(I)(40) <= channels_in(I)(16);
        long_map(I)(41) <= channels_in(I)(18);
        long_map(I)(42) <= channels_in(I)(20);
        long_map(I)(43) <= channels_in(I)(22);
        long_map(I)(44) <= channels_in(I)(24);
        long_map(I)(45) <= channels_in(I)(26);
        long_map(I)(46) <= channels_in(I)(28);
        long_map(I)(47) <= channels_in(I)(30);
        long_map(I)(48) <= channels_in(I)(32);
        long_map(I)(49) <= channels_in(I)(34);
        long_map(I)(50) <= channels_in(I)(36);
        long_map(I)(51) <= channels_in(I)(38);
        long_map(I)(52) <= channels_in(I)(40);
        long_map(I)(53) <= channels_in(I)(42);
        long_map(I)(54) <= channels_in(I)(44);
        long_map(I)(55) <= channels_in(I)(46);
        long_map(I)(56) <= channels_in(I)(48);
        long_map(I)(57) <= channels_in(I)(50);
        long_map(I)(58) <= channels_in(I)(52);
        long_map(I)(59) <= channels_in(I)(54);
        long_map(I)(60) <= channels_in(I)(56);
        long_map(I)(61) <= channels_in(I)(58);
        long_map(I)(62) <= channels_in(I)(60);
        long_map(I)(63) <= channels_in(I)(62);
      end generate;

      map_c : if (I = 16 or I = 17) generate
        long_map(I)(0)  <= channels_in(I)(0);
        long_map(I)(1)  <= channels_in(I)(2);
        long_map(I)(2)  <= channels_in(I)(4);
        long_map(I)(3)  <= channels_in(I)(6);
        long_map(I)(4)  <= channels_in(I)(8);
        long_map(I)(5)  <= channels_in(I)(10);
        long_map(I)(6)  <= channels_in(I)(12);
        long_map(I)(7)  <= channels_in(I)(14);
        long_map(I)(8)  <= channels_in(I)(16);
        long_map(I)(9)  <= channels_in(I)(18);
        long_map(I)(10) <= channels_in(I)(20);
        long_map(I)(11) <= channels_in(I)(22);
        long_map(I)(12) <= channels_in(I)(24);
        long_map(I)(13) <= channels_in(I)(26);
        long_map(I)(14) <= channels_in(I)(28);
        long_map(I)(15) <= channels_in(I)(30);
        long_map(I)(16) <= channels_in(I)(32);
        long_map(I)(17) <= channels_in(I)(34);
        long_map(I)(18) <= channels_in(I)(36);
        long_map(I)(19) <= channels_in(I)(38);
        long_map(I)(20) <= channels_in(I)(40);
        long_map(I)(21) <= channels_in(I)(42);
        long_map(I)(22) <= channels_in(I)(44);
        long_map(I)(23) <= channels_in(I)(46);
        long_map(I)(24) <= channels_in(I)(48);
        long_map(I)(25) <= channels_in(I)(50);
        long_map(I)(26) <= channels_in(I)(52);
        long_map(I)(27) <= channels_in(I)(54);
        long_map(I)(28) <= channels_in(I)(56);
        long_map(I)(29) <= channels_in(I)(58);
        long_map(I)(30) <= channels_in(I)(60);
        long_map(I)(31) <= channels_in(I)(62);
        long_map(I)(32) <= channels_in(I)(63);
        long_map(I)(33) <= channels_in(I)(61);
        long_map(I)(34) <= channels_in(I)(59);
        long_map(I)(35) <= channels_in(I)(57);
        long_map(I)(36) <= channels_in(I)(55);
        long_map(I)(37) <= channels_in(I)(53);
        long_map(I)(38) <= channels_in(I)(51);
        long_map(I)(39) <= channels_in(I)(49);
        long_map(I)(40) <= channels_in(I)(47);
        long_map(I)(41) <= channels_in(I)(45);
        long_map(I)(42) <= channels_in(I)(43);
        long_map(I)(43) <= channels_in(I)(41);
        long_map(I)(44) <= channels_in(I)(39);
        long_map(I)(45) <= channels_in(I)(37);
        long_map(I)(46) <= channels_in(I)(35);
        long_map(I)(47) <= channels_in(I)(33);
        long_map(I)(48) <= channels_in(I)(31);
        long_map(I)(49) <= channels_in(I)(29);
        long_map(I)(50) <= channels_in(I)(27);
        long_map(I)(51) <= channels_in(I)(25);
        long_map(I)(52) <= channels_in(I)(23);
        long_map(I)(53) <= channels_in(I)(21);
        long_map(I)(54) <= channels_in(I)(19);
        long_map(I)(55) <= channels_in(I)(17);
        long_map(I)(56) <= channels_in(I)(15);
        long_map(I)(57) <= channels_in(I)(13);
        long_map(I)(58) <= channels_in(I)(11);
        long_map(I)(59) <= channels_in(I)(9);
        long_map(I)(60) <= channels_in(I)(7);
        long_map(I)(61) <= channels_in(I)(5);
        long_map(I)(62) <= channels_in(I)(3);
        long_map(I)(63) <= channels_in(I)(1);
      end generate;

      map_d : if (I >= 18 and I <= 23) generate
        long_map(I)(0)  <= channels_in(I)(62);
        long_map(I)(1)  <= channels_in(I)(60);
        long_map(I)(2)  <= channels_in(I)(58);
        long_map(I)(3)  <= channels_in(I)(56);
        long_map(I)(4)  <= channels_in(I)(54);
        long_map(I)(5)  <= channels_in(I)(52);
        long_map(I)(6)  <= channels_in(I)(50);
        long_map(I)(7)  <= channels_in(I)(48);
        long_map(I)(8)  <= channels_in(I)(46);
        long_map(I)(9)  <= channels_in(I)(44);
        long_map(I)(10) <= channels_in(I)(42);
        long_map(I)(11) <= channels_in(I)(40);
        long_map(I)(12) <= channels_in(I)(38);
        long_map(I)(13) <= channels_in(I)(36);
        long_map(I)(14) <= channels_in(I)(34);
        long_map(I)(15) <= channels_in(I)(32);
        long_map(I)(16) <= channels_in(I)(30);
        long_map(I)(17) <= channels_in(I)(28);
        long_map(I)(18) <= channels_in(I)(26);
        long_map(I)(19) <= channels_in(I)(24);
        long_map(I)(20) <= channels_in(I)(22);
        long_map(I)(21) <= channels_in(I)(20);
        long_map(I)(22) <= channels_in(I)(18);
        long_map(I)(23) <= channels_in(I)(16);
        long_map(I)(24) <= channels_in(I)(14);
        long_map(I)(25) <= channels_in(I)(12);
        long_map(I)(26) <= channels_in(I)(10);
        long_map(I)(27) <= channels_in(I)(8);
        long_map(I)(28) <= channels_in(I)(6);
        long_map(I)(29) <= channels_in(I)(4);
        long_map(I)(30) <= channels_in(I)(2);
        long_map(I)(31) <= channels_in(I)(0);
        long_map(I)(32) <= channels_in(I)(1);
        long_map(I)(33) <= channels_in(I)(3);
        long_map(I)(34) <= channels_in(I)(5);
        long_map(I)(35) <= channels_in(I)(7);
        long_map(I)(36) <= channels_in(I)(9);
        long_map(I)(37) <= channels_in(I)(11);
        long_map(I)(38) <= channels_in(I)(13);
        long_map(I)(39) <= channels_in(I)(15);
        long_map(I)(40) <= channels_in(I)(17);
        long_map(I)(41) <= channels_in(I)(19);
        long_map(I)(42) <= channels_in(I)(21);
        long_map(I)(43) <= channels_in(I)(23);
        long_map(I)(44) <= channels_in(I)(25);
        long_map(I)(45) <= channels_in(I)(27);
        long_map(I)(46) <= channels_in(I)(29);
        long_map(I)(47) <= channels_in(I)(31);
        long_map(I)(48) <= channels_in(I)(33);
        long_map(I)(49) <= channels_in(I)(35);
        long_map(I)(50) <= channels_in(I)(37);
        long_map(I)(51) <= channels_in(I)(39);
        long_map(I)(52) <= channels_in(I)(41);
        long_map(I)(53) <= channels_in(I)(43);
        long_map(I)(54) <= channels_in(I)(45);
        long_map(I)(55) <= channels_in(I)(47);
        long_map(I)(56) <= channels_in(I)(49);
        long_map(I)(57) <= channels_in(I)(51);
        long_map(I)(58) <= channels_in(I)(53);
        long_map(I)(59) <= channels_in(I)(55);
        long_map(I)(60) <= channels_in(I)(57);
        long_map(I)(61) <= channels_in(I)(59);
        long_map(I)(62) <= channels_in(I)(61);
        long_map(I)(63) <= channels_in(I)(63);
      end generate;

    end generate;  -- VFAT loop

  end generate;  -- if GE11

  --------------------------------------------------------------------------------
  -- Identity mapping (channels==strips)
  --------------------------------------------------------------------------------

  identity_map <= channels_in;

  --------------------------------------------------------------------------------
  -- Choose whether to register outputs or not
  --------------------------------------------------------------------------------

  clkout : if (REGISTER_OUTPUT) generate
    process (clock) is
    begin
      if (rising_edge(clock)) then
        strips_out <= strips;
      end if;
    end process;
  end generate;

  noclkout : if (not REGISTER_OUTPUT) generate
    strips_out <= strips;
  end generate;

end Behavioral;
