#!/usr/bin/env python3
import os
import random
import pytest

import cocotb
from cocotb_test.simulator import run
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from cluster_finding import Cluster, find_clusters, equal


async def latch_in(dut):
    ""
    while (True):
        await RisingEdge(dut.clock)  # Synchronize with the clock
        dut.latch_i.value = 0
        for i in range(3):
            await RisingEdge(dut.clock)  # Synchronize with the clock
        dut.latch_i.value = 1

@cocotb.test()
async def random_clusters(dut):
    """Test for priority encoder with randomized data on all inputs"""

    nloops = 100
    nhits = 99

    cocotb.fork(Clock(dut.clk_40,  40, units="ns").start())  # Create a clock
    cocotb.fork(Clock(dut.clk_fast,10,  units="ns").start())  # Create a clock

    station = dut.STATION.value

    # if station in [0, 1]:
    #     n_partitions = 8
    # if station == 2:
    #     n_partitions = 2

    n_vfats = dut.NUM_VFATS.value
    #width = int((n_vfats * 64) / n_partitions)
    #cntb = 3

    dut.reset.value = 0

    for i in range(n_vfats):
        dut.sbits_i[i].value = 0

    for _ in range(nloops):

        vfats = [0 for _ in range(n_vfats)]

        # # create fill a large number with some random bits
        # for ibit in range(nhits):
        #     ivfat = random.randint(0, n_vfats-1)
        #     channel = random.randint(0, 63)
        #     vfats[ivfat] |= 1 << channel

        await RisingEdge(dut.clk_40)  # Synchronize with the clock

        dut.sbits_i[1].value = 0x8000000000000000
        dut.sbits_i[10].value = 0x8000000000000000
        dut.sbits_i[19].value = 0x8000000000000000

        # await RisingEdge(dut.clk_40)  # Synchronize with the clock
        # #dut.sbits_i.value = vfats
        # dut.sbits_i[17].value = 0x1f1f1f1f00000000
        # dut.sbits_i[2].value  = 0x1f1f1f1f00000000
        # await RisingEdge(dut.clk_40)  # Synchronize with the clock
        # dut.sbits_i[17].value = 0xe0e0e0e000000000
        # dut.sbits_i[2].value  = 0xe0e0e0e000000000

        await RisingEdge(dut.clk_40)  # Synchronize with the clock

        for i in range(n_vfats):
            dut.sbits_i[i].value = 0

        await RisingEdge(dut.clk_40)  # Synchronize with the clock
        dut.sbits_i.value = vfats
        await RisingEdge(dut.clk_40)  # Synchronize with the clock

        for i in range(n_vfats):
            dut.sbits_i[i].value = 0

        # expect = find_clusters(partitions, cnts, width, dut.NUM_FOUND_CLUSTERS.value, dut.ENCODER_SIZE.value)
        # for i in range(len(expect)):
        #     print("generate: i=%02d %s" % (i, str(expect[i])))

        for _ in range(8):
            await RisingEdge(dut.clk_40)  # Synchronize with the clock



        # found = []

        # await RisingEdge(dut.clock)  # Synchronize with the clock
        # for iclst in range(16):

        #     cluster = Cluster()

        #     cluster.adr = dut.clusters_o[iclst].adr.value
        #     cluster.cnt = dut.clusters_o[iclst].cnt.value
        #     cluster.prt = dut.clusters_o[iclst].prt.value
        #     cluster.vpf = dut.clusters_o[iclst].vpf.value

        #     if (int(dut.clusters_o[iclst].adr.value) < 0x1ff):
        #         print("found: i=%02d %s" % (iclst, str(cluster)))
        #         found.append(cluster)

        # for i in range(len(found)):
        #     cla = expect[i]
        #     found_a = False
        #     for j in range(len(found)):
        #         clb = found[j]
        #         if (equal(cla, clb)):
        #             found_a = True
        #     assert found_a, "Failed to find cluster %s" % str(cla)

        # assert len(found) == len(expect)

        # await Timer(200, units='ns')

@pytest.mark.parametrize("station", [1, 2])
@pytest.mark.parametrize("oneshot", [False, True])
@pytest.mark.parametrize("deadtime", [0, 1])
def test_cluster_packer(station, oneshot, deadtime):

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', 'hdl'))
    module = os.path.splitext(os.path.basename(__file__))[0]

    vhdl_sources = [
        os.path.join(rtl_dir, f"cluster_pkg.vhd"),
        os.path.join(rtl_dir, f"fixed_delay.vhd"),
        os.path.join(rtl_dir, f"sbit_oneshot.vhd"),
        os.path.join(rtl_dir, f"../../oh_fe/utils/clock_strobe.vhd"),
        os.path.join(rtl_dir, f"truncate_lsb.vhd"),
        os.path.join(rtl_dir, f"bitonic_exchange.vhd"),
        os.path.join(rtl_dir, f"bitonic_merge.vhd"),
        os.path.join(rtl_dir, f"bitonic_sorter.vhd"),
        os.path.join(rtl_dir, f"find_clusters.vhd"),
        os.path.join(rtl_dir, f"top_cluster_packer.vhd")
    ]

    verilog_sources = [
        os.path.join(rtl_dir, f"find_cluster_primaries.v"),
        os.path.join(rtl_dir, f"count.v"),
        os.path.join(rtl_dir, f"consecutive_count.v"),
        os.path.join(rtl_dir, f"priority.v")
    ]

    parameters = {}
    parameters['STATION'] = station
    parameters['DEADTIME'] = deadtime
    parameters['ONESHOT'] = oneshot

    if station == 2:
        parameters['NUM_VFATS'] = 12
    else:
        parameters['NUM_VFATS'] = 24

    if station == 2:
        parameters['NUM_PARTITIONS'] = 2
    else:
        parameters['NUM_PARTITIONS'] = 8

    os.environ["SIM"] = "questa"

    run(
        verilog_sources=verilog_sources,
        vhdl_sources=vhdl_sources,
        module=module,
        toplevel="cluster_packer",
        toplevel_lang="vhdl",
        parameters=parameters,
        # sim_args = ["do cluster_packer_wave.do"],
        # extra_env = {"SIM": "questa"},
        gui=0
    )


#RUN=vsim -batch -do "set NumericStdNoWarnings 1; run 500000; quit -f"


if __name__ == "__main__":
    test_cluster_packer(1, True, 0)
