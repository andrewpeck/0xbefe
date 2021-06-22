#!/usr/bin/env python3
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


async def bc0_generator(dut):
    while (True):
        await RisingEdge(dut.clocks.clk40)
        if (dut.bxn_counter_i.value == 0):
            dut.ttc_i.bc0 = 1
        else:
            dut.ttc_i.bc0 = 0

def random_cluster(dut, index):
    dut.clusters_i[index].vpf = 1
    dut.clusters_i[index].adr = random.randint(0,ADR_MAX)
    dut.clusters_i[index].prt = random.randint(0,PRT_MAX)
    dut.clusters_i[index].cnt = random.randint(0,CNT_MAX)

async def bxn_generator(dut):
    while (True):
        await RisingEdge(dut.clocks.clk40)
        if (dut.bxn_counter_i.value == BXN_MAX-1):
            dut.bxn_counter_i = 0
        else:
            dut.bxn_counter_i = dut.bxn_counter_i.value + 1

def clear_cluster(dut, index):
    dut.clusters_i[index].adr = 511
    dut.clusters_i[index].prt = 0
    dut.clusters_i[index].cnt = 0
    dut.clusters_i[index].vpf = 0

@cocotb.test()
async def test_data_formatter(dut):
    """Test trigger data formatter"""

    cocotb.fork(Clock(dut.clocks.clk40,    40, units="ns").start())  # Create a clock
    cocotb.fork(Clock(dut.clocks.clk80,    20, units="ns").start())  # Create a clock
    cocotb.fork(Clock(dut.clocks.clk160_0, 10, units="ns").start())  # Create a clock

    dut.ttc_i.bc0 = 0
    dut.bxn_counter_i = 0
    dut.error_i = 0
    dut.reset_i = 0
    dut.prbs_en_i = 0

    for i in range (16):
        clear_cluster(dut, i)

    #cocotb.fork(bc0_generator(dut))
    cocotb.fork(bxn_generator(dut))


    for loop in range(4):
         await RisingEdge(dut.clocks.clk40)  # Synchronize with the clock

    random_cluster(dut,0)
    random_cluster(dut,1)
    random_cluster(dut,2)
    random_cluster(dut,3)
    random_cluster(dut,4)
    random_cluster(dut,5)
    random_cluster(dut,6)
    random_cluster(dut,7)
    random_cluster(dut,8)
    random_cluster(dut,9)
    random_cluster(dut,10)
    random_cluster(dut,11)
    random_cluster(dut,12)
    random_cluster(dut,13)
    random_cluster(dut,14)
    random_cluster(dut,15)

    await RisingEdge(dut.clocks.clk40)  # Synchronize with the clock

    for i in range (16):
        clear_cluster(dut, i)

    for loop in range(4000):
        await RisingEdge(dut.clocks.clk40)  # Synchronize with the clock

        clst_raw = [0,0,0,0,0,0,0,0,0,0]
        for i in range(2):
            pkt = dut.fiber_packets_o[i].value
            for j in range (5):
                clst_raw[5*i+j] = (pkt >> 16*j) & 0xFFFF

        status = (get_bit(clst_raw[3],14) << 2) | (get_bit(clst_raw[2],14) << 1) | (get_bit(clst_raw[1],14) << 0)
        bc0    = (get_bit(clst_raw[0],14))

        clst_o = [{},{},{},{},{},{},{},{},{},{}]

        for i in range (10):

            # ignore comma characters in the 4th word
            if (i==4 or i==9) and (dut.fiber_kchars_o[i // 5].value == 0x200):
                continue

            overflow = get_bit(clst_raw[i],15)

            if (STATION==1):
                clst_o[i]["adr"] = (clst_raw[i] >> 0  ) & 0xff
                clst_o[i]["prt"] = (clst_raw[i] >> 8  ) & 0x7
                clst_o[i]["cnt"] = (clst_raw[i] >> 11 ) & 0x7
            if (STATION==2):
                clst_o[i]["adr"] = (clst_raw[i] >> 0  ) & 0x1ff
                clst_o[i]["prt"] = (clst_raw[i] >> 9  ) & 0x1
                clst_o[i]["cnt"] = (clst_raw[i] >> 10 ) & 0x7

            if (clst_o[i]["adr"] < ADR_MAX):
                print("Cluster %d, BXN=%d, OVF=%d" % (i, dut.bxn_counter_i.value, overflow))
                print(clst_o[i])

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
