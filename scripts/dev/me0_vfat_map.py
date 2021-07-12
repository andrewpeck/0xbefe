NUM_VFATS = 24
NUM_GBTS = 8

VFAT_GEB_TYPE = [0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1] # 0 is narrow, 1 is wide
VFAT_J_NUM = [4, 3, 10, 9, 1, 3, 7, 9, 1, 5, 7, 11, 4, 5, 10, 11, 2, 6, 8, 12, 2, 6, 8, 12]
J_NUM_HDLC_ADDR = [-1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] # there's no J number 0, so using a placeholder -1 value
# virtual ASIAGOs are ordered from 0 to 3, starting at the highest eta. The GBTs are ordered as ASIAGO# * 2 + GBT# within the ASIAGO (0=master, 1=slave)
# Thus the GBT order: 0 & 1 = high eta narrow, 2 & 3 = low eta narrow, 4 & 5 = high eta wide, 6 & 7 = low eta wide
VFAT_ASIAGO = [0, 0, 1, 1, 2, 2, 3, 3, 0, 0, 1, 1, 2, 2, 3, 3, 0, 0, 1, 1, 2, 2, 3, 3]
VFAT_ASIAGO_SLOT = [5, 4, 5, 4, 3, 4, 3, 4, 3, 2, 3, 2, 5, 2, 5, 2, 1, 0, 1, 0, 1, 0, 1, 0] # VFAT number within an ASIAGO
ASIAGO_SLOT_DAQ_GBT = [1, 1, 1, 0, 0, 0]
ASIAGO_SLOT_DAQ_ELINK = [6, 24, 11, 3, 27, 25]
ASIAGO_SLOT_SBIT_GBT = [1, 1, 1, 0, 0, 0]
ASIAGO_SLOT_SBIT_ELINK = [  [3, 13, 5, 1, 0, 2, 12, 4],
                            [18, 21, 20, 23, 22, 27, 26, 25],
                            [17, 19, 14, 7, 9, 10, 15, 8],
                            [6, 7, 9, 4, 5, 2, 0, 1],
                            [15, 14, 12, 10, 11, 13, 19, 17],
                            [16, 18, 20, 22, 24, 26, 21, 23] ]

ASIAGO_CONTROL_ELINK_TO_SLOTS = [ [2, 0], [3, 1], [4, 5], [-1, -1] ] # defines which local ASIAGO vfat slots each of the 4 control elinks is controlling (placeholder -1 is used for unconnected elink)

def main():

    print("    --inversions incorperated in ASIAGO config")
    print("")
    print("    gbt_ready_arr_o <= gbt_rx_ready_arr;")
    print("    gbt_tx_data_arr_o <= gbt_tx_data_arr;")
    print("")
    print("    g_ohs : for i in 0 to g_NUM_OF_OHs - 1 generate")
    print("")
    print("        --======================================================--")
    print("        --========================= RX =========================--")
    print("        --======================================================--")
    print("")
    print("        -- IC")
    for gbt in range(NUM_GBTS):
        print("        gbt_ic_rx_data_arr_o(i * 2 + %d) <= gbt_rx_data_arr_i(i * 2 + %d).rx_ic_data(0) & gbt_rx_data_arr_i(i * 2 + %d).rx_ic_data(1); -- GBT%d; bits reversed" % (gbt, gbt, gbt, gbt))
    print("")
    print("        -- GBT ready")
    for gbt in range(NUM_GBTS):
        print("        gbt_rx_ready_arr(i * 8 + %d) <= gbt_link_status_arr_i(i * 8 + %d).gbt_rx_ready; -- GBT%d" % (gbt, gbt, gbt))
    print("")
    print("        -- VFAT GBT ready")
    for vfat in range(NUM_VFATS):
        gbt = getGbt(vfat)
        print("        vfat3_gbt_ready_arr_o(i)(%02d) <= gbt_rx_ready_arr(i * 8 + %d); -- VFAT%02d (GBT%d)" % (vfat, gbt, vfat, gbt))
    print("")
    print("        -- DAQ")
    for vfat in range(NUM_VFATS):
        gbt = getGbt(vfat)
        elink = ASIAGO_SLOT_DAQ_ELINK[VFAT_ASIAGO_SLOT[vfat]]
        elinkBits = getElinkBits(elink, 3)
        print("        vfat3_rx_data_arr_o(i)(%02d) <= gbt_rx_data_arr_i(i * 8 + %d).rx_data(%s); -- VFAT%02d (GBT%d elink %02d)" % (vfat, gbt, elinkBits, vfat, gbt, elink))
    print("")
    print("        -- SBITS")
    for vfat in range(NUM_VFATS):
        for sbit in range(8):
            gbt = getGbt(vfat)
            sbitBits = "%02d downto %02d" % (sbit * 8 + 7, sbit * 8)
            elink = ASIAGO_SLOT_SBIT_ELINK[VFAT_ASIAGO_SLOT[vfat]][sbit]
            elinkBits = getElinkBits(elink, 3)
            print("        vfat3_sbits_arr_o(i)(%02d)(%s) <= gbt_rx_data_arr_i(i * 8 + %d).rx_data(%s); -- VFAT%02d pair %d (GBT%d elink %02d)" % (vfat, sbitBits, gbt, elinkBits, vfat, sbit, gbt, elink))

    print("")
    print("        --======================================================--")
    print("        --========================= TX =========================--")
    print("        --======================================================--")
    print("")
    print("        -- IC")
    for gbt in range(NUM_GBTS):
        isMaster = gbt % 2 == 0
        if isMaster:
            print("        gbt_tx_data_arr(i * 8 + %d).tx_ic_data <= gbt_ic_tx_data_arr_i(i * 8 + %d)(0) & gbt_ic_tx_data_arr_i(i * 8 + %d)(1); -- GBT%d (master); bits reversed" % (gbt, gbt, gbt, gbt))
        else:
            print("        gbt_tx_data_arr(i * 8 + %d).tx_ec_data <= gbt_ic_tx_data_arr_i(i * 8 + %d)(0) & gbt_ic_tx_data_arr_i(i * 8 + %d)(1); -- GBT%d (slave); bits reversed" % (gbt-1, gbt, gbt, gbt))
    print("")
    print("        -- VFAT control")
    for gbt in range(NUM_GBTS):
        if gbt % 2 == 0:
            for elink in range(4):
                elinkBits = getElinkBits(elink, 2)
                vfatSlots = ASIAGO_CONTROL_ELINK_TO_SLOTS[elink]
                if vfatSlots[0] < 0 and vfatSlots[1] < 0:
                    print("        gbt_tx_data_arr(i * 8 + %d).tx_data(%s) <= (others => '0'); -- GBT%d tx elink %02d is not connected" % (gbt, elinkBits, gbt, elink))
                elif vfatSlots[0] < 0 or vfatSlots[1] < 0:
                    print("================ ERROR: found that GBT%d tx elink %d is only connected to one VFAT, this is currently not supported by this script ================")
                else:
                    asiago = gbt / 2
                    vfats = [getVfatNumber(asiago, vfatSlots[0]), getVfatNumber(asiago, vfatSlots[1])]
                    print("        gbt_tx_data_arr(i * 8 + %d).tx_data(%s) <= vfat3_tx_data_arr_i(i)(%02d) when vfat3_tx_data_arr_i(i)(%02d) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(%02d) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(%02d); -- GBT%d tx elink %02d: VFAT%d & VFAT%02d" % (gbt, elinkBits, vfats[0], vfats[0], vfats[0], vfats[1], gbt, elink, vfats[0], vfats[1]))

    print("")
    print("        -- Repeat the same data on the second transmitter (unused)")
    for gbt in range(NUM_GBTS):
        if gbt % 2 != 0:
            print("        gbt_tx_data_arr(i * 8 + %d) <= gbt_tx_data_arr(i * 8 + %d); -- GBT%d" % (gbt, gbt-1, gbt))

    print("")
    print("    end generate;")

    # gbtMaps = [{}, {}, {}, {}, {}, {}, {}, {}]
    # for vfat in range(24):
    #     asiago = VFAT_ASIAGO[vfat]
    #     slot = VFAT_ASIAGO_SLOT[vfat]
    #     daqGbt = asiago * 2 + ASIAGO_SLOT_DAQ_GBT[slot]
    #     daqElink = ASIAGO_SLOT_DAQ_ELINK[slot]
    #     daqBits = getElinkBits(daqElink, 3)
    #     print("VFAT %d ASIAGO %d slot %d GBT %d elink %d bits %s" % (vfat, asiago, slot, daqGbt, daqElink, daqBits))
    #     gbtMaps[daqGbt][daqElink] = vfat
    # for gbt in range(8):
    #     map = gbtMaps[gbt]
    #     print("ME0_GEB_GBT%d_ELINK_TO_VFAT" % gbt)
    #     print(map)

def getVfatNumber(asiago, asiagoSlot):
    asiagoVfats = []
    for vfat in range(NUM_VFATS):
        if VFAT_ASIAGO[vfat] == asiago:
            asiagoVfats.append(vfat)
    for vfat in asiagoVfats:
        if VFAT_ASIAGO_SLOT[vfat] == asiagoSlot:
            return vfat

def getGbt(vfat):
    return VFAT_ASIAGO[vfat] * 2 + ASIAGO_SLOT_DAQ_GBT[VFAT_ASIAGO_SLOT[vfat]]

def getElinkBits(elink, fillDigits):
    return ("%0" + str(fillDigits) + "d downto %0" + str(fillDigits) + "d") % (elink * 8 + 7, elink * 8)

if __name__ == '__main__':
    main()
