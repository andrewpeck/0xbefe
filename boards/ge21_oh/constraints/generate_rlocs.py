#!/usr/bin/env python3
#
# unplace [get_cells trigger_inst/sbits/*trig_alignment/*_loop[*].*oversample/dru/*tmr_loop[*].dru/data_in_delay_reg[*]]
#
# ISERDES X1Y144 --> CLBLM_R_X103Y143 / 144
# ISERDES X0Y221  --> CLBLM_R_X2Y221 / 222

# create a tuple of 96 (x,y) locations for the Master M serdes
SBIT_LOCS = ((0, 214), (0, 206), (0, 204), (0, 210), (0, 208), (0, 212), (0, 162), (0, 160),
             (1, 162), (1, 156), (1, 160), (1, 158), (1, 144), (1, 148), (1, 152), (1, 146),
             (0, 220), (0, 224), (0, 218), (0, 216), (0, 228), (0, 226), (0, 232), (0, 230),
             (1, 196), (1, 192), (1, 194), (1, 188), (1, 190), (1, 184), (1, 186), (1, 182),
             (0, 164), (0, 170), (0, 168), (0, 172), (0, 152), (0, 156), (0, 158), (0, 154),
             (1, 178), (1, 180), (1, 174), (1, 172), (1, 170), (1, 164), (1, 168), (1, 166),
             (0, 112), (0, 106), (0, 102), (0, 110), (0, 108), (0, 198), (0, 194), (0, 196),
             (1, 126), (1, 142), (1, 140), (1, 136), (1, 132), (1, 134), (1, 128), (1, 130),
             (0, 122), (0, 124), (0, 128), (0, 134), (0, 130), (0, 132), (0, 136), (0, 138),
             (1, 106), (1, 102), (0, 94),  (0, 90),  (0,  92), (0, 98),  (0,  96), (0, 116),
             (0, 190), (0, 182), (0, 174), (0, 186), (0, 178), (0, 184), (0, 188), (0, 192),
             (1, 116), (1, 122), (1, 118), (1, 120), (1, 114), (1, 110), (1, 112), (1, 108),)

SOT_LOCS = ((0, 202), (1, 154), (0, 222), (1, 198),
            (0, 166), (1, 176), (0, 104), (1, 138),
            (0, 114), (1, 104), (0, 180), (1, 124),)

f = open("rlocs_xc7a200t.tcl", "w+")

for rx_type in ("sot", "sbit"):

    if (rx_type == "sot"):
        imax = 12
        LOCS = SOT_LOCS
    if (rx_type == "sbit"):
        imax = 96
        LOCS = SBIT_LOCS

    for i in range(imax):

        f.write("# LOCs for Input #%d\n" % i)

        x0 = LOCS[i][0]
        y0 = LOCS[i][1]

        for tmr_inst in range(3):

            f.write("# TMR Inst %d\n" % tmr_inst)

            for j in range(2):
                for k in range(4):

                    qq = j+k*2

                    x = x0
                    y = y0 - 1

                    if (x0==1):
                        x = 162

                    if (qq % 2 == 0):
                        # even
                        if (qq <= 2):
                            x = x
                        if (qq >  2):
                            x = x + 1
                    if (qq % 2 == 1):
                        # odd
                        y = y + 1
                        if (qq <= 3):
                            x = x + 1
                        if (qq >  3):
                            x = x


                    # if (tmr_inst==0):
                    #     x = x
                    # if (tmr_inst==1):
                    #     x = x
                    # if (tmr_inst == 2):
                    #     x = x + 1

                    f.write("place_cell trigger_inst/sbits/*trig_alignment/*_loop[%d].%s_oversample/dru/*tmr_loop[%d].dru/data_in_delay_reg[%d] SLICE_X%dY%d\n" % (i, rx_type, tmr_inst, qq, x, y))

        f.write("\n")

# LOCs for GBT Input Serdes
# /data_in_delay_1
for tmr_inst in range (3):
    for i in range (8):
        if tmr_inst == 0:
            x = 0
            y = 247
        if tmr_inst == 1:
            x = 1
            y = 247
        if tmr_inst == 2:
            x = 0
            y = 248
        f.write("place_cell gbt_inst/gbt_serdes/gbt_oversample/dru/*tmr_loop[%d].dru/data_in_delay_reg[%d] SLICE_X%dY%d;\n" % (tmr_inst, i, x, y))
