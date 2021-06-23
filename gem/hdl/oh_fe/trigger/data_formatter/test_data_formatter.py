#/usr/bin/env python3
#
# TODO: check for ge21
# TODO: force comma check
# TODO: startup sync check

import math
import os
import pytest

from cocotb_test.simulator import run

import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge
from cocotb.triggers import RisingEdge
from cocotb.triggers import Event
import random

BXN_MAX = 128
STATION = 1
ADR_MAX = 191
PRT_MAX = 7
CNT_MAX = 7

def get_bit(data, bit):
    return ((data >> bit) & 1)

def random_cluster(dut, index):

    adr = random.randint(0, ADR_MAX)
    prt = random.randint(0, PRT_MAX)
    cnt = random.randint(0, CNT_MAX)

    dut.clusters_i[index].vpf = 1
    dut.clusters_i[index].adr = adr
    dut.clusters_i[index].prt = prt
    dut.clusters_i[index].cnt = cnt

    return (adr,cnt,prt)

async def bxn_generator(dut):
    await RisingEdge(dut.clocks.clk40)
    while (True):
        if (dut.bxn_counter_i.value == BXN_MAX-1):
            dut.ttc_i.bc0 = 1
            dut.bxn_counter_i = 0
        else:
            dut.bxn_counter_i = dut.bxn_counter_i.value + 1
            dut.ttc_i.bc0 = 0
        await RisingEdge(dut.clocks.clk40)

def clear_cluster(dut, index):
    dut.clusters_i[index].adr = 511
    dut.clusters_i[index].prt = 0
    dut.clusters_i[index].cnt = 0
    dut.clusters_i[index].vpf = 0

def setup(dut):
    cocotb.fork(Clock(dut.clocks.clk40,    40, units="ns").start())  # Create a clock
    cocotb.fork(Clock(dut.clocks.clk80,    20, units="ns").start())  # Create a clock
    cocotb.fork(Clock(dut.clocks.clk160_0, 10, units="ns").start())  # Create a clock

    dut.ttc_i.bc0 = 0
    dut.ttc_i.resync = 0
    dut.ttc_i.l1a = 0
    dut.bxn_counter_i = 0
    dut.error_i = 0
    dut.reset_i = 0
    dut.prbs_en_i = 0
    dut.overflow_i = 0

    for i in range (16):
        clear_cluster(dut, i)

    cocotb.fork(bxn_generator(dut))

@cocotb.test()
async def test_status(dut):
    setup(dut)
    for loop in range(4):
         await RisingEdge(dut.clocks.clk40)  # Synchronize with the clock

    for loop in range(500):

        await RisingEdge(dut.clocks.clk40)

        bxn = dut.bxn_counter_i.value

        status = extract_status(extract_raw_clusters(dut))

        # there is some latency to propagate from input to the output data format
        # .. so we look at the bxn from the previous clock
        if (bxn+1==0):
            bc0 = extract_bc0(extract_raw_clusters(dut))
            assert bc0==1

        # print ("bxn=%x" % (dut.bxn_counter_i.value-1))
        # print ("status=%x" % status)

        if (dut.error_i==1):
            assert status ==7
        elif (dut.ttc_i.resync==1):
            assert status ==5
        elif (dut.overflow_i==1):
            assert status ==3
        else:
            # there is some latency to propagate from input to the output data format
            # .. so we look at the bxn from the previous clock
            bxn_lsbs = (dut.bxn_counter_i.value - 1) & 0x3
            assert status==bxn_lsbs


@cocotb.test()
async def test_bc0(dut):
    setup(dut)
    for loop in range(4):
         await RisingEdge(dut.clocks.clk40)  # Synchronize with the clock

    for loop in range(500):
        await RisingEdge(dut.clocks.clk40)
        bxn = dut.bxn_counter_i.value
        if (bxn==0):
            await RisingEdge(dut.clocks.clk160_0)
            await RisingEdge(dut.clocks.clk160_0)
            bc0 = extract_bc0(extract_raw_clusters(dut))
            assert bc0==1

def extract_raw_clusters(dut):
    clst_raw = [0,0,0,0,0,0,0,0,0,0]

    for i in range(2):
        pkt = dut.fiber_packets_o[i].value
        for j in range (5):
            clst_raw[5*i+j] = (pkt >> 16*j) & 0xFFFF

    return clst_raw

def extract_status(clst_raw):
    status = (get_bit(clst_raw[3],14) << 2) | (get_bit(clst_raw[2],14) << 1) | (get_bit(clst_raw[1],14) << 0)
    return status

def extract_bc0(clst_raw):
    bc0 = (get_bit(clst_raw[0],14))
    return bc0

@cocotb.test()
async def test_overflow(dut):
    """Test trigger data formatter"""

    setup(dut)

    for loop in range(4):
         await RisingEdge(dut.clocks.clk40)  # Synchronize with the clock

    addrs = []
    cnts  = []
    prts  = []

    ovf_addrs = []
    ovf_cnts  = []
    ovf_prts  = []

    for i in range (16):

        (adr,cnt,prt) = random_cluster(dut,i)

        if (i<10):
            addrs.append(adr)
            cnts.append(cnt)
            prts.append(prt)
        else:
            ovf_addrs.append(adr)
            ovf_cnts.append(cnt)
            ovf_prts.append(prt)

    await RisingEdge(dut.clocks.clk40)  # Synchronize with the clock

    for i in range (16):
        clear_cluster(dut, i)

    first_bx = True

    for loop in range(10):
        await RisingEdge(dut.clocks.clk40)  # Synchronize with the clock

        clst_raw = extract_raw_clusters(dut)

        clst_o = [{},{},{},{},{},{},{},{},{},{}]

        for i in range (10):

            # ignore comma characters in the 4th word
            if (i==4 or i==9) and (dut.fiber_kchars_o[i // 5].value == 0x200):
                continue

            overflow = get_bit(clst_raw[i], 15)

            if (STATION==1):
                clst_o[i]["adr"] = (clst_raw[i] >> 0 ) & 0xff
                clst_o[i]["prt"] = (clst_raw[i] >> 8 ) & 0x7
                clst_o[i]["cnt"] = (clst_raw[i] >> 11) & 0x7
            if (STATION==2):
                clst_o[i]["adr"] = (clst_raw[i] >> 0 ) & 0x1ff
                clst_o[i]["prt"] = (clst_raw[i] >> 9 ) & 0x1
                clst_o[i]["cnt"] = (clst_raw[i] >> 10) & 0x7

            if (clst_o[i]["adr"] < ADR_MAX):
                print("Cluster %d, BXN=%d, OVF=%d" % (i, dut.bxn_counter_i.value, overflow))
                print(clst_o[i])

                if (first_bx):
                    assert clst_o[i]["adr"] == addrs[i]
                    assert clst_o[i]["cnt"] == cnts[i]
                    assert clst_o[i]["prt"] == prts[i]
                else:
                    print (ovf_addrs)
                    print (ovf_prts)
                    print (ovf_cnts)
                    assert clst_o[i]["adr"] == ovf_addrs[i]
                    assert clst_o[i]["cnt"] == ovf_cnts[i]
                    assert clst_o[i]["prt"] == ovf_prts[i]

        if (clst_o[0]["adr"] < ADR_MAX):
            first_bx = False

def test_formatter():

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    rtl_dir = os.path.abspath(os.path.join(tests_dir))
    module = os.path.splitext(os.path.basename(__file__))[0]

    vhdl_sources = [
        os.path.join(rtl_dir, f"../../../../../common/hdl/utils/yahamm/matrix_pkg.vhd"),
        os.path.join(rtl_dir, f"../../../../../common/hdl/utils/yahamm/yahamm_pkg.vhd"),
        os.path.join(rtl_dir, f"../../../../../common/hdl/utils/yahamm/yahamm_enc.vhd"),
        os.path.join(rtl_dir, f"../../../../../common/hdl/utils/prbs_any.vhd"),
        os.path.join(rtl_dir, f"../../../oh_fe/pkg/tmr_dis_pkg.vhd"),
        os.path.join(rtl_dir, f"../../../oh_fe/pkg/hardware_pkg_ge11.vhd"),
        os.path.join(rtl_dir, f"../../../oh_fe/pkg/types_pkg.vhd"),
        os.path.join(rtl_dir, f"../../../cluster_finding/hdl/cluster_pkg.vhd"),
        os.path.join(rtl_dir, f"trigger_data_formatter.vhd"),
    ]

    run(
        vhdl_sources=vhdl_sources,
        module=module,       # name of cocotb test module
        toplevel="trigger_data_formatter",            # top level HDL
        toplevel_lang="vhdl",
        gui=0
    )


if __name__ == "__main__":
    test_formatter()
