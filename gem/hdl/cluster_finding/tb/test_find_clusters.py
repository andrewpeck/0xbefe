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
        for _ in range(3):
            await RisingEdge(dut.clock)  # Synchronize with the clock
        dut.latch_i.value = 1


@cocotb.test()
async def random_clusters(dut):
    """Test for priority encoder with randomized data on all inputs"""

    NLOOPS = 10000
    NHITS = 14

    cocotb.fork(Clock(dut.clock, 40, units="ns").start())  # Create a clock

    STATION = dut.STATION.value

    if STATION in [0, 1]:
        NPARTITIONS = 8
    elif STATION == 2:
        NPARTITIONS = 2
    else:
        NPARTITIONS = 0

    n_vfats = dut.NUM_VFATS.value
    width = int((n_vfats * 64) / NPARTITIONS)
    cntb = 3

    dut.vpfs_i.value = 0
    dut.cnts_i.value = 0

    dut.latch_i.value = 0
    cocotb.fork(latch_in(dut))

    for _ in range(NLOOPS):

        partitions = [0]*NPARTITIONS
        cnts = [0]*NPARTITIONS

        # create fill a large number with some random bits
        for _ in range(NHITS):
            size = random.randint(0, 7)
            iprt = random.randint(0, NPARTITIONS - 1)
            channel = random.randint(0, width - 1)
            partitions[iprt] |= 1 << channel
            cnts[iprt] |= size << (channel * cntb)
            partitions[iprt] |= 1 << channel
            cnts[iprt] |= size << (channel * cntb)

        vpfs_i = 0
        cnts_i = 0

        for prt in range(NPARTITIONS):
            vpfs_i |= partitions[prt] << int(width * prt)
            cnts_i |= cnts[prt] << int(width * cntb * prt)

        expect = find_clusters(partitions, cnts, width,
                               dut.NUM_FOUND_CLUSTERS.value,
                               dut.ENCODER_SIZE.value)

        # sort the found keys by {valid , partition, adr}
        #expect = sorted(expect, key=lambda x: x.vpf << 12 | x.prt << 8 | x.adr, reverse=True)

        adr = -1
        prt = -1

        # for ioutput, _ in enumerate(expect):
        #   print("expected: i=%02d %s" % (ioutput, str(expect[ioutput])))

            # assert expect[ioutput].prt >= prt
            # if (expect[ioutput].prt == prt):
            #     assert expect[ioutput].adr >= adr
            # adr = expect[ioutput].adr
            # prt = expect[ioutput].prt

        dut.vpfs_i.value = vpfs_i
        dut.cnts_i.value = cnts_i

        for _ in range(32):
            await RisingEdge(dut.clock)  # Synchronize with the clock

        found = []
        await RisingEdge(dut.clock)  # Synchronize with the clock
        for iclst in range(16):

            cluster = Cluster()

            cluster.adr = dut.clusters_o[iclst].adr.value
            cluster.cnt = dut.clusters_o[iclst].cnt.value
            cluster.prt = dut.clusters_o[iclst].prt.value
            cluster.vpf = dut.clusters_o[iclst].vpf.value

            # if int(dut.clusters_o[iclst].adr.value) < 0x1ff:
            #print("found: i=%02d %s" % (iclst, str(cluster)))
            found.append(cluster)

        for j, _ in enumerate(found):
            cluster_a = expect[j]
            found_a = False
            for k, _ in enumerate(found):
                cluster_b = found[k]
                if equal(cluster_a, cluster_b):
                    found_a = True
            assert found_a, "Failed to find cluster %s" % str(cluster_a)

        assert len(found) == len(expect)

        await Timer(200, units='ns')


@pytest.mark.parametrize("station", [1, 2])
@pytest.mark.parametrize("num_found_clusters", [16])
def test_find_clusters(station, num_found_clusters):
    ""

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', 'hdl'))
    module = os.path.splitext(os.path.basename(__file__))[0]

    vhdl_sources = [
        os.path.join(rtl_dir, f"truncate_lsb.vhd"),
        os.path.join(rtl_dir, f"cluster_pkg.vhd"),
        os.path.join(rtl_dir, f"bitonic_exchange.vhd"),
        os.path.join(rtl_dir, f"bitonic_merge.vhd"),
        os.path.join(rtl_dir, f"bitonic_sorter.vhd"),
        os.path.join(rtl_dir, f"sort_clusters.vhd"),
        os.path.join(rtl_dir, f"find_clusters.vhd"),
    ]

    verilog_sources = [
        os.path.join(rtl_dir, f"priority.v"),
        os.path.join(rtl_dir, f"sorter16.v"),
    ]

    parameters = {}
    parameters['STATION'] = station
    parameters['NUM_FOUND_CLUSTERS'] = num_found_clusters
    if station == 2:
        parameters['NUM_VFATS'] = 12
    else:
        parameters['NUM_VFATS'] = 24

    os.environ["SIM"] = "questa"
    #os.environ["SIM"] = "ghdl"

    run(
        verilog_sources=verilog_sources,
        vhdl_sources=vhdl_sources,
        module=module,       # name of cocotb test module
        vhdl_compile_args=["-2008"],
        toplevel="find_clusters",            # top level HDL
        sim_args = ['-do "set NumericStdNoWarnings 1;"'],
        toplevel_lang="vhdl",
        parameters=parameters,
        gui=0
    )


if __name__ == "__main__":
    test_find_clusters(1, 16)
