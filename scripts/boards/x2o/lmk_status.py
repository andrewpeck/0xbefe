import sys
from dumbo.i2c import *

i2cbus = bus(1)
octopus=octopus_rev2(i2cbus)

regs = [-1] * 1288


def get_reg(addr):
    if regs[addr] == -1:
        regs[addr] = octopus.lmk.read_reg(addr)
    return regs[addr]

def main():
    # if len(sys.argv) < 2:
    #     print("lmk_status.py [filename]")
    #     return

    print("This script can either interpret a register dump (if a filename is given), or read the status from the chip")

    if len(sys.argv) > 1:
        f = open(sys.argv[1], "r")
        lines = f.readlines()
        for line in lines:
            sep_idx = line.index('=')
            addr = int(line[1:sep_idx - 1])
            val = int(line[sep_idx + 3:])
            regs[addr] = val
            #print("reg %d: %d" % (addr, val))

    lol_pll1 = (get_reg(33) >> 3) & 1
    lol_pll2 = (get_reg(33) >> 2) & 1
    los_fdet_xo = (get_reg(33) >> 0) & 1

    print("Loss of lock PLL1 %d, PLL2 %d" % (lol_pll1, lol_pll2))
    print("Loss of frequency detect on the XO: %d" % los_fdet_xo)

    for pll in range(3):
        lopl_dpll = (get_reg(34 + pll) >> 7) & 1
        lofl_dpll = (get_reg(34 + pll) >> 6) & 1
        hist = (get_reg(34 + pll) >> 5) & 1
        hldovr = (get_reg(34 + pll) >> 4) & 1
        refswitch = (get_reg(34 + pll) >> 3) & 1
        lor_missclk = (get_reg(34 + pll) >> 2) & 1
        lor_freq = (get_reg(34 + pll) >> 1) & 1
        lor_ph = (get_reg(34 + pll) >> 0) & 1
        print("PLL%d: " % pll)
        print("    DPLL loss of phase lock: %d" % lopl_dpll)
        print("    DPLL loss of frequency lock: %d" % lofl_dpll)
        print("    Holdover event: %d" % hldovr)
        print("    Reference switchover: %d" % refswitch)
        print("    Loss of active reference: missing clock %d, frequency %d, phase %d" % (lor_missclk, lor_freq, lor_ph))


    for ref in range(2):
        valid = (get_reg(50) >> 0 + ref) & 1
        fdet = (get_reg(52) >> 0 + 3*ref) & 1
        missclk = (get_reg(52) >> 1 + 3*ref) & 1
        ph = (get_reg(52) >> 2 + 3*ref) & 1

        print("Reference %d:" % ref)
        print("    Valid: %d" % valid)
        print("    Frequency valid: %d" % fdet)
        print("    Missing clock validation: %d" % missclk)
        print("    Phase validation: %d" % ph)

    dpll2_refsel = (get_reg(377) >> 0) & 0x3f
    refsel_str = {0: "Holdover", 1: "REF0", 2: "REF1", 4: "Reserved", 8: "Reserved", 0x10: "APLL1", 0x20: "APLL3"}
    print("DPLL reference: %s" % refsel_str[dpll2_refsel])

if __name__ == "__main__":
    main()
