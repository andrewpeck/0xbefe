from dumbo.i2c import *
i2cbus = bus(1)
octopus=octopus_rev2(i2cbus)
#octopus.lmk.load_config('/root/gem/clk_config/HexRegisterValues_322p265625.txt')
#octopus.lmk.load_config('/root/gem/clk_config/DPLLandAPLL2_Input_40p0786_Out0_40p0786_OutOthers_160p3144_ZDM.txt')
#octopus.lmk.load_config('/root/gem/clk_config/DPLLandAPLL2_Input_40p0786_Out0_40p0786_Out1_320p6288_OutOthers_160p3144_ZDM.txt')
octopus.lmk.readback()

