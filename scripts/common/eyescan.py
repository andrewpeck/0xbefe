from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from boards.cvp13.cvp13_utils import *
import time
import sys
import os

#based on https://support.xilinx.com/s/article/68785?language=en_US
# this one is the same but for ultrascale (not plus) https://support.xilinx.com/s/article/66517?language=en_US

EYESCAN_DRP_REGS = {"ES_HORZ_OFFSET": {"addr": 0x4f, "mask": 0xfff0},
                    "USE_PCS_CLK_PHASE_SEL": {"addr": 0x94, "mask": 0x0400},
                    "ES_CONTROL": {"addr": 0x3c, "mask": 0xfc00},
                    "ES_PRESCALE": {"addr": 0x3c, "mask": 0x001f},
                    "ES_EYE_SCAN_EN": {"addr": 0x3c, "mask": 0x100},
                    "ES_ERRDET_EN": {"addr": 0x3c, "mask": 0x200},
                    "ES_QUALIFIER0": {"addr": 0x3f, "mask": 0xffff},
                    "ES_QUALIFIER1": {"addr": 0x40, "mask": 0xffff},
                    "ES_QUALIFIER2": {"addr": 0x41, "mask": 0xffff},
                    "ES_QUALIFIER3": {"addr": 0x42, "mask": 0xffff},
                    "ES_QUALIFIER4": {"addr": 0x43, "mask": 0xffff},
                    "ES_QUALIFIER5": {"addr": 0xe7, "mask": 0xffff},
                    "ES_QUALIFIER6": {"addr": 0xe8, "mask": 0xffff},
                    "ES_QUALIFIER7": {"addr": 0xe9, "mask": 0xffff},
                    "ES_QUALIFIER8": {"addr": 0xea, "mask": 0xffff},
                    "ES_QUALIFIER9": {"addr": 0xeb, "mask": 0xffff},
                    "ES_QUAL_MASK0": {"addr": 0x44, "mask": 0xffff},
                    "ES_QUAL_MASK1": {"addr": 0x45, "mask": 0xffff},
                    "ES_QUAL_MASK2": {"addr": 0x46, "mask": 0xffff},
                    "ES_QUAL_MASK3": {"addr": 0x47, "mask": 0xffff},
                    "ES_QUAL_MASK4": {"addr": 0x48, "mask": 0xffff},
                    "ES_QUAL_MASK5": {"addr": 0xec, "mask": 0xffff},
                    "ES_QUAL_MASK6": {"addr": 0xed, "mask": 0xffff},
                    "ES_QUAL_MASK7": {"addr": 0xee, "mask": 0xffff},
                    "ES_QUAL_MASK8": {"addr": 0xef, "mask": 0xffff},
                    "ES_QUAL_MASK9": {"addr": 0xf0, "mask": 0xffff},
                    "ES_SDATA_MASK0": {"addr": 0x49, "mask": 0xffff},
                    "ES_SDATA_MASK1": {"addr": 0x4a, "mask": 0xffff},
                    "ES_SDATA_MASK2": {"addr": 0x4b, "mask": 0xffff},
                    "ES_SDATA_MASK3": {"addr": 0x4c, "mask": 0xffff},
                    "ES_SDATA_MASK4": {"addr": 0x4d, "mask": 0xffff},
                    "ES_SDATA_MASK5": {"addr": 0xf1, "mask": 0xffff},
                    "ES_SDATA_MASK6": {"addr": 0xf2, "mask": 0xffff},
                    "ES_SDATA_MASK7": {"addr": 0xf3, "mask": 0xffff},
                    "ES_SDATA_MASK8": {"addr": 0xf4, "mask": 0xffff},
                    "ES_SDATA_MASK9": {"addr": 0xf5, "mask": 0xffff},
                    "RX_EYESCAN_VS_NEG_DIR": {"addr": 0x97, "mask": 0x400},
                    "RX_EYESCAN_VS_UT_SIGN": {"addr": 0x97, "mask": 0x200},
                    "RX_EYESCAN_VS_CODE": {"addr": 0x97, "mask": 0x1fc},
                    "RX_EYESCAN_VS_RANGE": {"addr": 0x97, "mask": 0x3},
                    "ES_CONTROL_STATUS": {"addr": 0x253, "mask": 0xf},
                    "ES_ERROR_COUNT": {"addr": 0x251, "mask": 0xffff},
                    "ES_SAMPLE_COUNT": {"addr": 0x252, "mask": 0xffff},
                    "RX_DATA_WIDTH": {"addr": 0x3, "mask": 0x01e0},
                    "RX_INT_DATAWIDTH": {"addr": 0x66, "mask": 0x0003}
                    }

# map of bus_width -> ber_depth -> ES_PRESCALE
# table 4-18 from ug578
prescale_sel = {
    16:  {6:2, 7:5, 8:8, 9:12, 10:15, 11:18, 12:22, 13:25, 14:28, 15:32},
    20:  {6:1, 7:5, 8:8, 9:11, 10:15, 11:18, 12:21, 13:25, 14:28, 15:31},
    32:  {6:0, 7:4, 8:7, 9:11, 10:14, 11:17, 12:21, 13:24, 14:27, 15:31},
    40:  {6:0, 7:4, 8:7, 9:10, 10:14, 11:17, 12:20, 13:24, 14:27, 15:30},
    64:  {6:0, 7:3, 8:6, 9:10, 10:13, 11:16, 12:20, 13:23, 14:26, 15:30},
    80:  {6:0, 7:3, 8:6, 9:9,  10:13, 11:16, 12:19, 13:23, 14:26, 15:29},
    128: {6:0, 7:2, 8:5, 9:9,  10:12, 11:15, 12:19, 13:22, 14:25, 15:29},
    160: {6:0, 7:2, 8:5, 9:8,  10:12, 11:15, 12:18, 13:22, 14:25, 15:28}
}



def eyescan_read_reg(mgt, reg_name):
    reg = EYESCAN_DRP_REGS[reg_name]
    val = mgt.drp_read(reg["addr"])
    mask = reg["mask"]
    val = (val & mask) >> find_first_set_bit_pos(mask)

    return val

def eyescan_write_reg(mgt, reg_name, value):
    reg = EYESCAN_DRP_REGS[reg_name]
    addr = reg["addr"]
    val = mgt.drp_read(addr)
    mask = reg["mask"]
    first_bit_pos = find_first_set_bit_pos(mask)
    val = (val & ~mask) | ((value << first_bit_pos) & mask)
    mgt.drp_write(addr, val)

def get_int_datawidth(mgt):
    rx_dw = eyescan_read_reg(mgt, "RX_DATA_WIDTH")
    rx_int_dw = eyescan_read_reg(mgt, "RX_INT_DATAWIDTH")
    num_words = 2 if rx_int_dw == 0 else 4 if rx_int_dw == 1 else 8 if rx_int_dw == 2 else None
    word_size = 8 if rx_dw % 2 == 0 else 10
    return num_words * word_size

def eyescan_align(link):
    mgt = link.rx_mgt
    # save the prescale value to be reset later
    prescale = eyescan_read_reg(mgt, "ES_PRESCALE")
    # check if there are no errors in the middle of the eye, and if there are, try the realignment procedure up to MAX_REALIGN_RETRIES of times
    err = 1
    retries = 0
    MAX_REALIGN_RETRIES = 5
    while err > 0 and retries < MAX_REALIGN_RETRIES:
        # reset the position to the center (step 5)
        eyescan_write_reg(mgt, "RX_EYESCAN_VS_NEG_DIR", 0)
        eyescan_write_reg(mgt, "RX_EYESCAN_VS_UT_SIGN", 0)
        eyescan_write_reg(mgt, "RX_EYESCAN_VS_CODE", 0)
        eyescan_write_reg(mgt, "RX_EYESCAN_VS_RANGE", 3)
        eyescan_write_reg(mgt, "ES_HORZ_OFFSET", 0x800)

        # run the scan with a shallow BER floor
        eyescan_write_reg(mgt, "ES_PRESCALE", 4)
        eyescan_write_reg(mgt, "ES_CONTROL", 1)
        t0 = time.time()
        while ((eyescan_read_reg(mgt, "ES_CONTROL_STATUS") & 0xf) >> 1) != 2:
            time.sleep(0.001)
            if (time.time() - t0 > 1.0):
                print("ERROR: link %d stuck during realignment, ES_CONTROL_STATUS: %d" % (link.idx, eyescan_read_reg(mgt, "ES_CONTROL_STATUS")))
                err = 999
                break
        
        eyescan_write_reg(mgt, "ES_CONTROL", 0)
        if err != 999:
            err = eyescan_read_reg(mgt, "ES_ERROR_COUNT")

        if err > 0:
            # realign
            print("Link %d: realigning, num errors in the center is %d, this is try #%d" % (link.idx, err, retries))
            eyescan_write_reg(mgt, "ES_HORZ_OFFSET", 0x880)
            mgt.set_eyescan_reset(1)
            eyescan_write_reg(mgt, "ES_HORZ_OFFSET", 0x800)
            mgt.set_eyescan_reset(0)

        retries += 1

    # reset the prescale to what it was before
    eyescan_write_reg(mgt, "ES_PRESCALE", prescale)

    return True if err == 0 else False


# returns number of checked bits per sample count to use
def eyescan_setup(links, ber_depth):
    print("============= Setting up eye scan for BER < 1e-%d =============" % ber_depth)
    for link in links:
        mgt = link.rx_mgt

        width = get_int_datawidth(mgt)
        prescale = prescale_sel[width][ber_depth]
        print("Link %d: Resetting and setting up, internal data width is %d, using es_prescale of %d" % (link.idx, width, prescale))
        eyescan_write_reg(mgt, "ES_CONTROL", 0)
        eyescan_write_reg(mgt, "ES_EYE_SCAN_EN", 1)
        eyescan_write_reg(mgt, "ES_ERRDET_EN", 1)
        eyescan_write_reg(mgt, "ES_HORZ_OFFSET", 0x800)
        eyescan_write_reg(mgt, "ES_PRESCALE", prescale)
        #Step 3: Reset the GT. The reset is not necessary if ES_EYE_SCAN_EN = 1b1 is set in HDL.
        #TODO: try setting the ES_EYE_SCAN_EN to true in HDL
        mgt.reset()

    time.sleep(1)

    for link in links:
        mgt = link.rx_mgt

        eyescan_write_reg(mgt, "ES_CONTROL", 0)
        
        # setup the masks (step 4)
        # consider all patterns, so set all QUAL masks to 1
        eyescan_write_reg(mgt, "ES_QUAL_MASK0", 0xffff)
        eyescan_write_reg(mgt, "ES_QUAL_MASK1", 0xffff)
        eyescan_write_reg(mgt, "ES_QUAL_MASK2", 0xffff)
        eyescan_write_reg(mgt, "ES_QUAL_MASK3", 0xffff)
        eyescan_write_reg(mgt, "ES_QUAL_MASK4", 0xffff)
        eyescan_write_reg(mgt, "ES_QUAL_MASK5", 0xffff)
        eyescan_write_reg(mgt, "ES_QUAL_MASK6", 0xffff)
        eyescan_write_reg(mgt, "ES_QUAL_MASK7", 0xffff)
        eyescan_write_reg(mgt, "ES_QUAL_MASK8", 0xffff)
        eyescan_write_reg(mgt, "ES_QUAL_MASK9", 0xffff)

        # mask the top 80 bits in SDATA, these are only used if you want to count a single error on any number of mismatches per word
        eyescan_write_reg(mgt, "ES_SDATA_MASK5", 0xffff)
        eyescan_write_reg(mgt, "ES_SDATA_MASK6", 0xffff)
        eyescan_write_reg(mgt, "ES_SDATA_MASK7", 0xffff)
        eyescan_write_reg(mgt, "ES_SDATA_MASK8", 0xffff)
        eyescan_write_reg(mgt, "ES_SDATA_MASK9", 0xffff)

        # unmask the number of bits that there are in our bus width starting at bit 79 and going down the number of width bits, and then set the rest of the lowest bits to 1
        eyescan_write_reg(mgt, "ES_SDATA_MASK4", 0x0)
        mask3 = 0x0fff if width == 20 else 0x0000 if width > 20 else 0xffff
        eyescan_write_reg(mgt, "ES_SDATA_MASK3", mask3)
        mask2 = 0x00ff if width == 40 else 0x0000 if width > 40 else 0xffff
        eyescan_write_reg(mgt, "ES_SDATA_MASK2", mask2)
        mask1 = 0x0000 if width >= 64 else 0xffff
        eyescan_write_reg(mgt, "ES_SDATA_MASK1", mask1)
        mask0 = 0x0000 if width == 80 else 0xffff
        eyescan_write_reg(mgt, "ES_SDATA_MASK0", mask0)

        eyescan_align(link)

        # this seems to only be needed for UltraScale and not for UltraScale+
        # is_above_10g = mgt.type in ["MGT_LPGBT", "MGT_ODMB57", "MGT_ODMB57_BIDIR", "MGT_10GBE", "MGT_TX_GBE_RX_LPGBT", "MGT_TX_10GBE_RX_LPGBT", "MGT_25GBE"]
        # if is_above_10g:
        #     print("link is faster than 10G")
        #     eyescan_write_reg("USE_PCS_CLK_PHASE_SEL", 0)
        # else:
        #     print("link is slower than 10G")
        #     eyescan_write_reg("USE_PCS_CLK_PHASE_SEL", 1)

    print("Setup done")

    return 2**(prescale + 1) * width

def stat_eyescan_go(links, num_steps, bits_per_sample_count, horz_range=1.5, extra_info_print="", verbose=True):

    print("Starting the scan")

    MAX_V_OFFSET = 2**7
    MAX_H_OFFSET = int(2**5 * horz_range) #2 * 2**5
    H_MAX_VAL = 2**11 - 1

    step_v = int(MAX_V_OFFSET / num_steps)
    step_h = int(MAX_H_OFFSET / num_steps)

    result = []
    v_range = range(MAX_V_OFFSET-1, (MAX_V_OFFSET * -1), step_v * -1)
    h_range = range(MAX_H_OFFSET * -1, MAX_H_OFFSET + 1, step_h)
    for link in links:
        eye = []
        for i in range(len(v_range)):
            eye.append([-1] * len(h_range))
        result.append(eye)

    vi = 0
    hi = 0
    for v in v_range:
        v_val = abs(v)
        v_neg = 1 if v < 0 else 0
        for h in h_range:
            h_val = abs(h)
            if h < 0: # two's complement
                h_val = (h_val^H_MAX_VAL) + 1
            if verbose:
                print("%s Offset: V=%d H=%d" % (extra_info_print, v, h))
            for link in links:
                mgt = link.rx_mgt
                # print("configuring link %d" % link.idx)
                eyescan_write_reg(mgt, "RX_EYESCAN_VS_NEG_DIR", v_neg)
                eyescan_write_reg(mgt, "RX_EYESCAN_VS_CODE", v_val)
                eyescan_write_reg(mgt, "ES_HORZ_OFFSET", 0x800 | h_val)
                # FSM -> RESET
                eyescan_write_reg(mgt, "ES_CONTROL", 1)

            li = 0
            for link in links:
                mgt = link.rx_mgt                    
                # print("counting for link %d" % link.idx)
                # wait for for FSM:END state
                t0 = time.time()
                while ((eyescan_read_reg(mgt, "ES_CONTROL_STATUS") & 0xf) >> 1) != 2:
                    time.sleep(0.001)
                    if (time.time() - t0 > 10.0):
                        print("link %d this measurement is taking more than 10s, the ES_CONTROL_STATUS is %d" % (link.idx, eyescan_read_reg(mgt, "ES_CONTROL_STATUS")))
                        t0 = time.time()

                # FSM -> WAIT
                eyescan_write_reg(mgt, "ES_CONTROL", 0)
                # read the counters
                bits_checked = eyescan_read_reg(mgt, "ES_SAMPLE_COUNT") * bits_per_sample_count
                errors = eyescan_read_reg(mgt, "ES_ERROR_COUNT")
                if bits_checked == 0:
                    bits_checked = 1
                ber = errors / bits_checked
                # print("link: errors %d, bits checked %d, prescale is %d, ES_SAMPLE_COUNT is %d" % (errors, bits_checked, eyescan_read_reg(mgt, "ES_PRESCALE"), eyescan_read_reg(mgt, "ES_SAMPLE_COUNT")))
                result[li][vi][hi] = ber
                li += 1
            hi += 1
        vi += 1
        hi = 0


    print("DONE!")

    return result

def print_stat_eye(links, result, ber_depth):

    # dump the ber data to the screen
    li = 0
    for link in links:
        eye = result[li]
        li += 1
        print("Link %d:" % (link.idx))
        for vi in range(len(eye)):
            line = ""
            for hi in range(len(eye[vi])):
                ber = eye[vi][hi]
                line += "%.2f | " % ber
            print(line)

    # #print with colored squares
    # li = 0
    # for link in links:
    #     eye = result[li]
    #     li += 1
    #     print("-----===== Link %d =====-----" % (link.idx))
    #     for vi in range(len(eye)):
    #         line = ""
    #         for hi in range(len(eye[vi])):
    #             ber = eye[vi][hi]
    #             ber = ber * 2 if ber <= 0.5 else 1.0
    #             r = 0 if ber < 0.5 else int(255 * ((ber - 0.5) * 2))
    #             g = int(255 * (ber * 2)) if ber < 0.5 else int(255 * (1.0 - ((ber - 0.5) * 2)))
    #             b = int(255 * (1.0 - (ber * 2))) if ber < 0.5 else 0
    #             char = "\33[38;2;%d;%d;%dm■ \033[0m" % (r, g, b)
    #             # char = "Z" if ber < 0.0 else "." if ber == 0.0 else "-" if ber < 0.1 else "x"
    #             line += char
    #         print(line)

    #print with colored squares, multiple links in one row
    terminal_width = os.get_terminal_size()[0]
    plot_width = len(result[0][0]) * 2 + 4
    group_size = int(terminal_width / plot_width)
    for li in range(0, len(links), group_size):
        # print titles
        line = "\033[1;96m"
        title_decoration_width = plot_width - 28
        for lii in range(group_size):
            if li + lii >= len(links):
                break
            line += "  "
            for iii in range(int(title_decoration_width/2)):
                line += "="
            line += " Link %03d (BER < 1e-%02d) " % (links[li + lii].idx, ber_depth)
            for iii in range(int(title_decoration_width/2)):
                line += "="
            line += "  "
        line += "\033[0m"
        print(line)

        # print eyes
        for vi in range(len(eye)):
            line = "  "
            for lii in range(group_size):
                if li + lii >= len(links):
                    break
                eye = result[li + lii]
                for hi in range(len(eye[vi])):
                    ber = eye[vi][hi]
                    ber = ber * 2 if ber <= 0.5 else 1.0
                    r = 0 if ber < 0.5 else int(255 * ((ber - 0.5) * 2))
                    g = int(255 * (ber * 2)) if ber < 0.5 else int(255 * (1.0 - ((ber - 0.5) * 2)))
                    b = int(255 * (1.0 - (ber * 2))) if ber < 0.5 else 0
                    char = "\33[38;2;%d;%d;%dm■ \033[0m" % (r, g, b)
                    # char = "Z" if ber < 0.0 else "." if ber == 0.0 else "-" if ber < 0.1 else "x"
                    line += char
                line += "    "
            print(line)
        print("")

def waveform_eyescan_go(links, num_steps, stats_multiplier, brightness, horz_range=1.5):

    patterns = [
                    0x6, # low-low-high
                    0x1, # high-high-low
                    0x4, # low-high-high
                    0x3, # high-low-low
                    0x2, # high-low-high
                    0x5, # low-high-low
                    0x0, # high-high-high
                    0x7 # low-low-low
               ]

    waveforms = [] # one result array per per link per pattern
    for link in links:
        waveforms.append([])

    for pi in range(len(patterns)):
        pattern = patterns[pi]

        for link in links:
            mgt = link.rx_mgt
            eyescan_write_reg(mgt, "ES_PRESCALE", 0)
            eyescan_write_reg(mgt, "ES_QUAL_MASK4", 0xfff8) # we'll use the bottom 3 bits in QUAL4 for the pattern definition since these bits are used by all data widths
            # mask all sdata except the one bit in the middle of our pattern
            for i in range(10):
                eyescan_write_reg(mgt, "ES_SDATA_MASK%d" % i, 0xffff)
            eyescan_write_reg(mgt, "ES_SDATA_MASK4", 0xfffd)

            # the qualifier bits we use correspond to:
            # bit 0: right side of the plot
            # bit 1: center of the plot
            # bit 2: left side of the plot
            # NOTE: the bits are inverted i.e. setting a qualifier bit high triggers on the signal trace going under the center sampler, and vice versa
            # eyescan_write_reg(mgt, "ES_QUALIFIER4", 0x6) # low-high-high
            eyescan_write_reg(mgt, "ES_QUALIFIER4", pattern)

        result = stat_eyescan_go(links, num_steps, 2, horz_range=horz_range, extra_info_print="Pattern %s" % bin(patterns[pi]))

        # post process the result like this: scroll through the whole map with a 2x2 square, and take the average (or maybe the max) difference between one corner of the square and all of its neighbors (higher difference will result in brighter trace)
        v_size = len(result[0])
        h_size = len(result[0][0])
        for li in range(len(links)):
            link = links[li]
            res = result[li]
            trace = []
            for i in range(v_size - 1):
                trace.append([-1] * (h_size - 1))
            
            for hi in range(1, h_size):
                for vi in range(1, v_size):
                    diff_vert = abs(res[vi-1][hi] - res[vi][hi])
                    diff_horz = abs(res[vi][hi-1] - res[vi][hi])
                    trace[vi-1][hi-1] = max(diff_vert, diff_horz)
                    # diff_diag = abs(res[vi-1][hi-1] - res[vi][hi])
                    # neighbor_avg = (res[vi-1][hi] + res[vi][hi-1]) / 2
                    # trace[vi-1][hi-1] = abs(neighbor_avg - res[vi][hi])
            waveforms[li].append(trace)

    # merge the waveforms
    res_merged = []
    h_size = h_size - 1
    v_size = v_size - 1
    num_patterns = len(patterns)
    for li in range(len(links)):
        res_merged.append([])
        for vi in range(v_size):
            res_merged[li].append([-1] * h_size)

        for vi in range(v_size):
            for hi in range(h_size):
                sum = 0.0
                for pi in range(num_patterns):
                    sum += waveforms[li][pi][vi][hi]
                res_merged[li][vi][hi] = sum * brightness / num_patterns



    return res_merged

        



if __name__ == '__main__':

    if len(sys.argv) < 4:
        print("Usage: eyescan.py <BER_DEPTH> <QUARTER_NUM_BINS> <LINKS> [waveform] [waveform_brightness]")
        print("    BER_DEPTH: e.g. if 8 is given, the scan will go down to BER < 1e-8, supported values are 6-15")
        print("    QUARTER_NUM_BINS: this defines the scan resolution as the number of bins in both X and Y of one quarter of the picture (num bins from center to the max horizontal or vertical value). Supported range is 2-48")
        print("                      Note that this is just an approximation of what you will get because the scan just uses the same step size throughout, which has to be an integer number obtained by dividing the range of the offset sampler by the number of given bins, so especially at higher bin values it may result in large discrepancies due to rounding (you can only get the exact or better resolution than what you asked)")
        print("                      Best to keep this divisible by 16 (or 8 or 4 for smaller values)")
        print("    LINKS: this is a python expression resulting in a range or list of link indexes e.g. range(0, 60), or e.g. [2, 5, 7]")
        print("")
        print('e.g.: python3 common/eyescan.py 7 16 "[40, 41]"')
        sys.exit(0)

    ber_depth = int(sys.argv[1])
    if ber_depth < 6 or ber_depth > 15:
        print("ERROR: unsupported BER depth: only values between 6 and 15 are supported")
        sys.exit(1)

    num_bins = int(sys.argv[2])
    if num_bins < 2 or num_bins > 48:
        print("ERROR: unuspported number of bins, should be between 2 and 48")
        sys.exit(1)

    link_indexes = list(eval(sys.argv[3]))
    if len(link_indexes) == 0:
        print("ERROR: no links given")
        sys.exit(1)

    parse_xml()
    links = befe_get_all_links()
    links2 = []
    for i in link_indexes:
        links2.append(links[i])
    links = links2
    # links = [links[24], links[25], links[26], links[27], links[28], links[29], links[30], links[31], links[40], links[41], links[42], links[43], links[44]]
    # links = [links[40], links[41], links[42], links[43]]
    # linkss = []
    # for i in range(50):
    #     linkss.append(links[i])
    # links = linkss
    # ber_depth = 7
    bits_per_sample_count = eyescan_setup(links, ber_depth)
    result = None
    if len(sys.argv) > 4 and sys.argv[4] == "waveform":
        brightness = 2.5
        if len(sys.argv) > 5:
            brightness = int(sys.argv[5])
        result = waveform_eyescan_go(links, num_bins, 0, brightness, horz_range=2.0)
    else:
        result = stat_eyescan_go(links, num_bins, bits_per_sample_count)
    
    print_stat_eye(links, result, ber_depth)

