#!/usr/bin/env python3
import math

disclaimer = ""
disclaimer += "//-------------------------------------------------------------------------------------\n"
disclaimer += "// ATTENTION:\n"
disclaimer += "// This file and all of its contents were automatically generated using a python script\n"
disclaimer += "// For the love of god DO NOT EDIT it directly but please edit the generator so that\n"
disclaimer += "// everything can stay in sync\n"
disclaimer += "//-------------------------------------------------------------------------------------\n"
disclaimer += "\n"

disclaimer += "// https://en.wikipedia.org/wiki/Pairwise_sorting_network\n"
disclaimer += "//\n"
disclaimer += "//      S1      S2       S3          S4         S5       S6         S7      S8      S9    S10 \n"
disclaimer += "// 0  ──o──────o────────o────────o────────────────────────────────────────────────────────────\n"
disclaimer += "//      │      │        │        │                                                            \n"
disclaimer += "// 1  ──o──────│─o──────│o───────│o────────────────────────────────────────o────────o──────o──\n"
disclaimer += "//             │ │      ││       ││                                        │        │      │  \n"
disclaimer += "// 2  ──o──────o─│──────││o──────││o─────────────────────o──────────o──────│────────│──────o──\n"
disclaimer += "//      │        │      │││      │││                     │          │      │        │         \n"
disclaimer += "// 3  ──o────────o──────│││o─────│││o────────────────────│o─────────│o─────│o───────│o─────o──\n"
disclaimer += "//                      ││││     ││││                    ││         ││     ││       ││     │  \n"
disclaimer += "// 4  ──o──────o────────o│││─────││││o─────────o─────────││─────────o│─────││───────o│─────o──\n"
disclaimer += "//      │      │         │││     │││││         │         ││          │     ││        │        \n"
disclaimer += "// 5  ──o──────│─o───────o││─────│││││o── ─────│o────────││──────────o─────││o──────o│─────o──\n"
disclaimer += "//             │ │        ││     ││││││        ││        ││                │││      ││     │  \n"
disclaimer += "// 6  ──o──────o─│────────o│─────││││││o───────││o───────││o────────o──────│││──────│o─────o──\n"
disclaimer += "//      │        │         │     │││││││       │││       │││        │      │││      │         \n"
disclaimer += "// 7  ──o────────o─────────o─────│││││││o──────│││o──────│││o───────│o─────│││o─────│o─────o──\n"
disclaimer += "//                               ││││││││      ││││      ││││       ││     ││││     ││     │  \n"
disclaimer += "// 8  ──o──────o────────o────────o│││││││──────o│││──────o│││───────o│─────o│││─────o│─────o──\n"
disclaimer += "//      │      │        │         │││││││       │││       │││        │      │││      │        \n"
disclaimer += "// 9  ──o──────│─o──────│o────────o││││││───────o││───────o││────────o──────│││─────o│─────o──\n"
disclaimer += "//             │ │      ││         ││││││        ││        ││               │││     ││     │  \n"
disclaimer += "// 10 ──o──────o─│──────││o────────o│││││────────o│────────││───────o───────o││─────│o─────o──\n"
disclaimer += "//      │        │      │││         │││││         │        ││       │        ││     │         \n"
disclaimer += "// 11 ──o────────o──────│││o────────o││││─────────o────────││───────│o───────││─────│o─────o──\n"
disclaimer += "//                      ││││         ││││                  ││       ││       ││     ││     │  \n"
disclaimer += "// 12 ──o──────o────────o│││─────────o│││──────────────────o│───────o│───────o│─────o│─────o──\n"
disclaimer += "//      │      │         │││          │││                   │        │        │      │        \n"
disclaimer += "// 13 ──o──────│─o───────o││──────────o││───────────────────o────────o────────│──────│─────o──\n"
disclaimer += "//             │ │        ││           ││                                     │      │     │  \n"
disclaimer += "// 14 ──o──────o─│────────o│───────────o│─────────────────────────────────────o──────o─────o──\n"
disclaimer += "//      │        │         │            │                                                     \n"
disclaimer += "// 15 ──o────────o─────────o────────────o─────────────────────────────────────────────────────\n"
disclaimer += "\n"

def sorter16 (list1, list2):

    def swap_pairs(alist, a, b):
        tmp = alist[a]
        alist[a] = alist[b]
        alist[b] = tmp

    alist = list1 + list2

    ################################################################################
    # s0
    ################################################################################

    if (alist[8] > alist[0]):
        swap_pairs(alist, 8, 0)

    if (alist[9] > alist[1]):
        swap_pairs(alist, 9, 1)

    if (alist[10] > alist[2]):
        swap_pairs(alist, 10, 2)

    if (alist[11] > alist[3]):
        swap_pairs(alist, 11, 3)

    if (alist[12] > alist[4]):
        swap_pairs(alist, 12, 4)

    if (alist[13] > alist[5]):
        swap_pairs(alist, 13, 5)

    if (alist[14] > alist[6]):
        swap_pairs(alist, 14, 6)

    if (alist[15] > alist[7]):
        swap_pairs(alist, 15, 7)

    ################################################################################
    # s1
    ################################################################################

    if (alist[8] > alist[4]):
        swap_pairs(alist, 4, 8)
    if (alist[9] > alist[5]):
        swap_pairs(alist, 5, 9)
    if (alist[10] > alist[6]):
        swap_pairs(alist, 6, 10)
    if (alist[11] > alist[7]):
        swap_pairs(alist, 7, 11)


    ################################################################################
    # s2
    ################################################################################

    if (alist[8] > alist[2]):
        swap_pairs(alist, 8, 2)

    if (alist[9] > alist[3]):
        swap_pairs(alist, 9, 3)

    if (alist[12] > alist[6]):
        swap_pairs(alist, 12, 6)

    if (alist[13] > alist[7]):
        swap_pairs(alist, 13, 7)

    ################################################################################
    # s3
    ################################################################################

    if (alist[4] > alist[2]):
        swap_pairs(alist, 4, 2)
    if (alist[5] > alist[3]):
        swap_pairs(alist, 5, 3)

    if (alist[8] > alist[6]):
        swap_pairs(alist, 8, 6)
    if (alist[9] > alist[7]):
        swap_pairs(alist, 9, 7)

    if (alist[12] > alist[10]):
        swap_pairs(alist, 12, 10)
    if (alist[13] > alist[11]):
        swap_pairs(alist, 13, 11)

    ################################################################################
    # s4
    ################################################################################

    if (alist[8] > alist[1]):
        swap_pairs(alist, 8, 1)

    if (alist[10] > alist[3]):
        swap_pairs(alist, 10, 3)

    if (alist[12] > alist[5]):
        swap_pairs(alist, 12, 5)

    if (alist[14] > alist[7]):
        swap_pairs(alist, 14, 7)


    ################################################################################
    # s5
    ################################################################################

    if (alist[4] > alist[1]):
        swap_pairs(alist, 4, 1)

    if (alist[6] > alist[3]):
        swap_pairs(alist, 6, 3)

    if (alist[8] > alist[5]):
        swap_pairs(alist, 8, 5)

    if (alist[10] > alist[7]):
        swap_pairs(alist, 10, 7)

    if (alist[12] > alist[9]):
        swap_pairs(alist, 12, 9)

    if (alist[14] > alist[11]):
        swap_pairs(alist, 14, 11)


    ################################################################################
    # s6
    ################################################################################

    if (alist[2] > alist[1]):
        swap_pairs(alist, 2, 1)

    if (alist[4] > alist[3]):
        swap_pairs(alist, 4, 3)

    if (alist[6] > alist[5]):
        swap_pairs(alist, 6, 5)

    if (alist[8] > alist[7]):
        swap_pairs(alist, 8, 7)

    if (alist[10] > alist[9]):
        swap_pairs(alist, 10, 9)

    if (alist[12] > alist[11]):
        swap_pairs(alist, 12, 11)

    if (alist[14] > alist[13]):
        swap_pairs(alist, 14, 13)

    return alist

def test_sorter_16 ():

    a=sorted([15,10,9,8,6,5,3,1],reverse=True)
    b=sorted([29,22,17,13,11,7,4,2], reverse=True)

    merged = sorter16(a,b)
    c = sorted(merged,True)
    if merged!=c:
        print("Merging failure")

# number of inputs MUST be a power of two
last_stage = 0
def generate_sorter (filename, number_of_inputs, number_of_outputs, sort_high, latch_list, disable_list):

    def reg_decl (stage):
        all_types = ""
        for type in types:
            all_types += "MX%sB" % type.upper()
            all_types += "+"
        s = ""
        s += "reg [%s0-1:0] data_s%d [%d:0];\n" % (all_types, stage, number_of_inputs-1)
        s += "reg pulse_s%d;\n"      % stage
        s += "\n"
        return s

    def latch_decl (stage, latch_list):
        if (stage in latch_list):
            return "always @(posedge clock) begin\n"
        else:
            return "always @(*) begin\n"

    def pass_decl (stage, stage_last, a):
        s  = ""
        s += "    data_s%d[%-2d] <= data_s%d[%-2d];\n" % (stage, a, stage_last, a)
        return s

    def swap_decl (stage, stage_last, a, b):

        sign = ">" if sort_high else "<"

        s  = ""
        s += "    {data_s%d[%-2d], data_s%-2d[%-2d]} <= " % (stage, a, stage,b)
        s += "(data_s%d[%-2d][DATB-1:SKIPB] %s data_s%d[%-2d][DATB-1:SKIPB]) ? " % (stage_last, b, sign, stage_last, a)
        s += "{data_s%d[%-2d], data_s%d[%-2d]} :" % (stage_last,b,stage_last,a)
        s += "{data_s%d[%-2d], data_s%d[%-2d]};\n" % (stage_last,a,stage_last,b)
        return s

    def pulse_decl(stage, stage_last):
        return "    pulse_s%d <= pulse_s%d;\n" % (stage, stage_last)

    s = disclaimer
    s += "module sorter%d \n" % number_of_inputs
    s += "#(\n"
    s += "   parameter MXADRB=8,\n"
    s += "   parameter MXCNTB=8,\n"
    s += "   parameter MXVPFB=8,\n"
    s += "   parameter SKIPB =8,\n"
    s += "   parameter MXPRTB=8\n"
    s += "   ) (\n"
    s += "    input clock,\n"
    s += "\n"

    types = ["adr", "cnt", "vpf", "prt"]

    for type in types:
        for i in range(number_of_inputs):
            s += "    input [MX%sB-1:0] %s_in%d,\n" % (type.upper(), type, i)
        s += "\n"

    s += "\n"

    for type in types:
        for i in range(number_of_outputs):
            s += "    output [MX%sB-1:0] %s_out%d,\n" % (type.upper(), type, i)
        s += "\n"

    s += "    input  pulse_in,\n"
    s += "    output pulse_out\n"

    s += ");\n"
    s += "\n"
    s += "parameter DATB = MXADRB+MXCNTB+MXVPFB+MXPRTB;\n"
    if (sort_high):
        s += "parameter INV = 0;\n"
    else:
        s += "parameter INV = 1<<DATB-1;\n"
    s += "\n"
    s += "//----------------------------------------------------------------------------------------------------------------------\n"
    s += "// vectorize inputs\n"
    s += "//----------------------------------------------------------------------------------------------------------------------\n"

    stage = 0

    s+=reg_decl(stage)

    s += latch_decl (stage, latch_list)

    invert = "" if sort_high else "~"

    for input in range(number_of_inputs):
        s += "    data_s0[%-2d]  <=  {%svpf_in%-2d, prt_in%-2d, adr_in%-2d, cnt_in%-2d};\n" % (input, invert, input, input, input, input)
    s += "\n"

    s += "    pulse_s0 <= pulse_in;\n"
    s += "end\n"
    s += "\n"

    #  https://en.wikipedia.org/wiki/Pairwise_sorting_network
    # implement a pairwise sorting network, but we already know that the 16 inputs are sorted into pre-sorted groups of 4 so we can skip the first 2 steps

    def sorter_stage (number_of_inputs, stage, swap_list, swap_offset):

        s = ""

        if (not stage in disable_list):

            global last_stage

            s += "\n"
            s += "//------------------------------------------------------------------------------------------------------------------\n"
            s += "// stage %d\n" % stage
            s += "\n"

            s += reg_decl(stage)

            s += latch_decl(stage, latch_list)

            for swapper in swap_list:
                s += swap_decl (stage, last_stage, swapper, swapper+swap_offset)

            swap_pair = [x+swap_offset for x in swap_list]
            pass_list = []
            for i in range (number_of_inputs):
                if (i not in swap_pair + swap_list):
                    #print("%d not in list" % i)
                    pass_list.append(i)


            for passer in pass_list:
                s += pass_decl (stage, last_stage, passer)

            s += pulse_decl(stage, last_stage)

            s += "end\n"

            last_stage = stage

        return s

    global last_stage
    if (number_of_inputs==16):
        last_stage=0
        #  https://en.wikipedia.org/wiki/Pairwise_sorting_network
        # implement a pairwise sorting network, but we already know that the 16 inputs are sorted into pre-sorted groups of 4 so we can skip the first 2 steps
        s += sorter_stage(16, 1,  [0, 2, 4, 6, 8, 10, 12, 14], 1) # Stage 1
        s += sorter_stage(16, 2,  [0, 1, 4, 5, 8, 9, 12, 13], 2)  # Stage 2
        s += sorter_stage(16, 3,  [0, 1, 2, 3, 8, 9, 10, 11], 4)  # Stage 3
        s += sorter_stage(16, 4,  [0, 1, 2, 3, 4, 5, 6, 7], 8)    # Stage 4
        s += sorter_stage(16, 5,  [4, 5, 6, 7], 4)                # Stage 5
        s += sorter_stage(16, 6,  [2, 3, 6, 7], 6)                # Stage 6
        s += sorter_stage(16, 7,  [2, 3, 6, 7, 10, 11], 2)        # Stage 7
        s += sorter_stage(16, 8,  [1, 3, 5, 7], 7)                # Stage 8
        s += sorter_stage(16, 9,  [1, 3, 5, 7, 9, 11], 3)         # Stage 9
        s += sorter_stage(16, 10, [1, 3, 5, 7, 9, 11, 13], 1)     # Stage 10

    if (number_of_inputs==8):
        last_stage=0
        #https://en.wikipedia.org/wiki/Batcher_odd%E2%80%93even_mergesort
        s += sorter_stage(8, 1, [0, 2, 4, 6], 1)  # Stage 1
        s += sorter_stage(8, 2, [1, 1, 4, 5], 2)  # Stage 2
        s += sorter_stage(8, 3, [1, 5], 1)        # Stage 3
        s += sorter_stage(8, 4, [0, 1, 2, 3], 4)  # Stage 4
        s += sorter_stage(8, 5, [2, 3], 2)        # Stage 5
        s += sorter_stage(8, 6, [1, 3, 5], 1)     # Stage 6


    s+="\n"
    s+="//----------------------------------------------------------------------------------------------------------------------\n"
    s+="// Latch Results for Output\n"
    s+="//----------------------------------------------------------------------------------------------------------------------\n"

    for ioutput in range (number_of_outputs):
        s+="    assign {vpf_out%d,prt_out%d,adr_out%d,cnt_out%d} = INV ^ data_s%d[%d];\n" % (4*(ioutput,)+ (last_stage, ioutput))

    s+="    assign pulse_out = pulse_s%s;\n" % last_stage

    s+="//----------------------------------------------------------------------------------------------------------------------\n"
    s+="endmodule\n"
    s+="//----------------------------------------------------------------------------------------------------------------------\n"

    print(s)
    f = open(filename, "w+")
    f.write(s)

# the first few stages can be disabled because the lists already come pre-sorted...
# but this needs to be done with care and understanding
generate_sorter(filename="sorter16.v",
                number_of_inputs=16,
                number_of_outputs=16,
                sort_high=False,
                latch_list=[2, 3, 4, 5, 6, 7, 8, 9, 10],
                disable_list=[0, 1])
