# required for APEX KU15P rev1 (bottom FPGA)
#set_property verilog_define {C2C_R1_UEC3 C2C_3P125G} [current_fileset]
# required for APEX KU15P rev2 (top FPGA)
set_property verilog_define C2C_3P125G [current_fileset]
