#!/usr/bin/env python3

# X0Y131 -> X0Y31
# X1Y125 -> X26Y125
# X2Y37 -> X63Y37

# create a tuple of 192 (x,y) locations for the Master M serdes
SBIT_LOCS = ((1, 125), (0, 199), (0, 19 ), (0, 33 ), (0, 37 ), (0, 57 ), (0, 53 ), (0, 77 ),
             (0, 65 ), (0, 89 ), (0, 97 ), (0, 109), (0, 117), (0, 133), (0, 121), (0, 141),
             (0, 153), (0, 145), (0, 137), (0, 185), (0, 169), (1, 121), (0, 161), (0, 171),
             (0, 179), (0, 175), (0, 195), (0, 183), (0, 187), (0, 191), (1, 133), (1, 141),
             (1, 197), (1, 193), (1, 189), (1, 185), (1, 181), (1, 169), (1, 165), (2, 189),
             (1, 139), (1, 131), (1, 151), (1, 155), (1, 159), (1, 157), (1, 143), (1, 187),
             (1, 161), (1, 175), (1, 199), (1, 173), (2, 197), (2, 173), (2, 167), (2, 149),
             (1, 171), (1, 103), (0, 157), (1, 137), (2, 127), (2, 155), (2, 125), (2, 129),
             (1, 63 ), (1, 17 ), (1, 39 ), (0, 39 ), (0, 41 ), (0, 49 ), (0, 45 ), (0, 67 ),
             (1, 45 ), (1, 55 ), (1, 61 ), (1, 59 ), (1, 67 ), (1, 73 ), (0, 3  ), (1, 77 ),
             (0, 113), (0, 131), (0, 151), (0, 143), (0, 125), (0, 159), (0, 155), (0, 173),
             (0, 61 ), (0, 55 ), (0, 73 ), (0, 93 ), (0, 87 ), (0, 101), (0, 105), (0, 103),
             (1, 195), (1, 179), (1, 183), (2, 183), (2, 199), (2, 175), (1, 117), (1, 167),
             (1, 191), (1, 177), (2, 187), (2, 195), (2, 181), (2, 165), (2, 123), (2, 141),
             (2, 69 ), (2, 57 ), (2, 53 ), (2, 49 ), (2, 41 ), (2, 25 ), (2, 9  ), (2, 13 ),
             (1, 37 ), (1, 33 ), (2, 77 ), (2, 47 ), (2, 43 ), (2, 37 ), (2, 35 ), (2, 27 ),
             (1, 127), (0, 177), (0, 193), (0, 165), (0, 189), (0, 29 ), (0, 21 ), (1, 71 ),
             (1, 53 ), (1, 49 ), (1, 65 ), (1, 69 ), (0, 23 ), (0, 5  ), (0, 7  ), (0, 27 ),
             (0, 11 ), (0, 31 ), (0, 35 ), (0, 47 ), (0, 63 ), (0, 51 ), (0, 75 ), (0, 71 ),
             (0, 79 ), (0, 91 ), (0, 99 ), (0, 95 ), (0, 25 ), (0, 43 ), (0, 59 ), (0, 69 ),
             (2, 23 ), (2, 3  ), (2, 15 ), (1, 23 ), (2, 59 ), (2, 79 ), (2, 65 ), (2, 73 ),
             (2, 45 ), (2, 33 ), (2, 29 ), (2, 1  ), (2, 5  ), (2, 11 ), (1, 19 ), (1, 25 ),
             (2, 21 ), (2, 19 ), (2, 7  ), (2, 17 ), (1, 11 ), (1, 27 ), (1, 3  ), (1, 57 ),
             (1, 15 ), (1, 7  ), (1, 35 ), (1, 51 ), (1, 47 ), (1, 75 ), (0, 17 ), (1, 79 ),)

SOT_LOCS = ((0, 127), (0, 162), (26, 149), (26, 154), (40, 155), (63, 163), (22, 178), (24, 140),
            (5, 113), (11, 14), (1, 122), (1, 102), (73, 160), (73, 160), (72, 40), (64, 50),
            (0, 122), (1, 17), (0, 86), (1, 94), (33, 3), (37, 4), (71, 25), (64, 10),)

f = open("rlocs.ucf", "w+")

for rx_type in ("sot", "sbit"):

    if (rx_type == "sot"):
        imax = 24
        LOCS = SOT_LOCS
    if (rx_type == "sbit"):
        imax = 192
        LOCS = SBIT_LOCS

    for i in range(imax):

        f.write("# LOCs for Input #%d\n" % i)

        x0 = LOCS[i][0]
        y0 = LOCS[i][1]

        for j in range(2):
            for k in range(4):

                qq = j+k*2

                if (qq % 2 == 0): # even case
                    y = y0-1
                    if (x0 == 0):
                        x = 0
                    elif (x0 == 1):
                        x = 36
                    elif (x0 == 2):
                        x = 62
                else: # odd case
                    y = y0 - 1
                    if (x0 == 0):
                        x = 1
                    elif (x0 == 1):
                        x = 37
                    elif (x0 == 2):
                        x = 63


                f.write("INST \"trigger_inst/sbits/notstandalone_gen.trig_alignment/*loop[%d].%s_oversample/dru/NO_TMR.dru/*data_in_delay_%d*\" LOC=SLICE_X%dY%d;\n" % (i,rx_type,qq,x,y))

        f.write("\n")

f.write("# LOCs for GBT Input Serdes\n")
f.write("INST \"gbt_inst/gbt_serdes/gbt_oversample/dru/*dru/*data_in_delay_0*\" LOC=SLICE_X36Y96;\n")
f.write("INST \"gbt_inst/gbt_serdes/gbt_oversample/dru/*dru/*data_in_delay_2*\" LOC=SLICE_X36Y96;\n")
f.write("INST \"gbt_inst/gbt_serdes/gbt_oversample/dru/*dru/*data_in_delay_4*\" LOC=SLICE_X36Y96;\n")
f.write("INST \"gbt_inst/gbt_serdes/gbt_oversample/dru/*dru/*data_in_delay_6*\" LOC=SLICE_X36Y96;\n")
f.write("INST \"gbt_inst/gbt_serdes/gbt_oversample/dru/*dru/*data_in_delay_1*\" LOC=SLICE_X37Y96;\n")
f.write("INST \"gbt_inst/gbt_serdes/gbt_oversample/dru/*dru/*data_in_delay_3*\" LOC=SLICE_X37Y96;\n")
f.write("INST \"gbt_inst/gbt_serdes/gbt_oversample/dru/*dru/*data_in_delay_5*\" LOC=SLICE_X37Y96;\n")
f.write("INST \"gbt_inst/gbt_serdes/gbt_oversample/dru/*dru/*data_in_delay_7*\" LOC=SLICE_X37Y96;\n")
