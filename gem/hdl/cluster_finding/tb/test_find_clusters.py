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

async def latch_in(dut):
    while (True):
        await RisingEdge(dut.clock)  # Synchronize with the clock
        dut.latch_i = 0
        for i in range(3):
            await RisingEdge(dut.clock)  # Synchronize with the clock
        dut.latch_i = 1

class Cluster:
    adr = 0x1ff
    cnt = 0
    prt = 0
    vpf = 0

    def __str__(self):
        return "adr=%02x cnt=%x prt=%x vpf=%x" % (self.adr, self.cnt, self.prt, self.vpf)


def equal(a, b):
    return a.adr == b.adr and a.cnt == b.cnt and a.prt == b.prt and a.vpf == b.vpf

def find_clusters(partitions, cnts, width, nmax, encoder_size):

    MAX_CLUSTERS_PER_ENCODER = 4

    found = []
    encoder_counts = [0,0,0,0,0,0,0,0]

    for iprt in range(len(partitions)):
        print("PARTITION %d width=%d size=%d" % (iprt, width, encoder_size))

        for ichn in range(width):

            if (encoder_size > width):
                encoder = int(iprt // (encoder_size/width))

            if len(found) >= nmax:
                return found

            if ((partitions[iprt] >> ichn) & 0x1):

                partitions[iprt] = partitions[iprt] ^ (1 << ichn)

                if (encoder_size < width):
                    if (ichn >= encoder_size):
                        encoder = int(width/encoder_size) * iprt + 1
                    else:
                        encoder = int(width/encoder_size) * iprt

                encoder_counts[encoder] += 1

                if (encoder_counts[encoder] <= MAX_CLUSTERS_PER_ENCODER):
                    print("Found %d clusters in encoder %d, partition %d channel %d!" % (encoder_counts[encoder], encoder, iprt, ichn))
                    c = Cluster()
                    c.adr = ichn
                    c.cnt = (cnts[iprt] >> 3*ichn) & 0x7
                    c.prt = iprt
                    c.vpf = 1
                    found.append(c)
                else:
                    print("Rejected a cluster in encoder %d, partition %d channel %d!" % (encoder, iprt, ichn))

    return found

@cocotb.test()
async def random_clusters(dut):
    """Test for priority encoder with randomized data on all inputs"""

    nloops = 100
    nhits = 99

    cocotb.fork(Clock(dut.clock, 20, units="ns").start())  # Create a clock

    STATION = dut.STATION.value

    if STATION == 0 or STATION == 1:
        N_PARTITIONS = 8
    if STATION == 2:
        N_PARTITIONS = 2

    N_VFATS = dut.NUM_VFATS.value
    WIDTH = int((N_VFATS*64)/N_PARTITIONS)
    CNTB = 3

    dut.vpfs_i <= 0
    dut.cnts_i <= 0

    dut.latch_i = 0
    cocotb.fork(latch_in(dut))

    for i in range(nloops):

        partitions = [0 for i in range(N_PARTITIONS)]
        cnts = [0 for i in range(N_PARTITIONS)]

        # create fill a large number with some random bits
        for ibit in range(nhits):
            size = random.randint(0, 7)
            iprt = random.randint(0, N_PARTITIONS-1)
            channel = random.randint(0, WIDTH-1)
            partitions[iprt] |= 1 << channel
            cnts[iprt] |= size << (channel*CNTB)

        vpfs_i = 0
        cnts_i = 0
        for i in range(N_PARTITIONS):
            vpfs_i |= partitions[i] << int(WIDTH*i)
            cnts_i |= cnts[i] << int(WIDTH*CNTB*i)

        expect = find_clusters(partitions, cnts, WIDTH, dut.NUM_FOUND_CLUSTERS.value, dut.ENCODER_SIZE.value)
        for i in range(len(expect)):
            print("generate: i=%02d %s" % (i, str(expect[i])))

        dut.vpfs_i = vpfs_i
        dut.cnts_i = cnts_i

        for loop in range(32):
            await RisingEdge(dut.clock)  # Synchronize with the clock

        found = []
        await RisingEdge(dut.clock)  # Synchronize with the clock
        for iclst in range(16):

            cluster = Cluster()

            cluster.adr = dut.clusters_o[iclst].adr.value
            cluster.cnt = dut.clusters_o[iclst].cnt.value
            cluster.prt = dut.clusters_o[iclst].prt.value
            cluster.vpf = dut.clusters_o[iclst].vpf.value

            if (int(dut.clusters_o[iclst].adr.value) < 0x1ff):
                print("found: i=%02d %s" % (iclst, str(cluster)))
                found.append(cluster)

        for i in range(len(found)):
            cla = expect[i]
            found_a = False
            for j in range(len(found)):
                clb = found[j]
                if (equal(cla, clb)):
                    found_a = True
            assert found_a, "Failed to find cluster %s" % str(cla)

        assert len(found) == len(expect)

        await Timer(200, units='ns')

@pytest.mark.parametrize("station", [1,2])
@pytest.mark.parametrize("num_found_clusters", [16])
def test_find_clusters(station, num_found_clusters):

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', 'hdl'))
    module = os.path.splitext(os.path.basename(__file__))[0]

    vhdl_sources = [
        os.path.join(rtl_dir, f"truncate_lsb.vhd"),
        os.path.join(rtl_dir, f"cluster_pkg.vhd"),
        os.path.join(rtl_dir, f"poc_bitonic_sort_pkg.vhd"),
        os.path.join(rtl_dir, f"poc_bitonic_sort.vhd"),
        os.path.join(rtl_dir, f"bitonic_sort.vhd"),
        os.path.join(rtl_dir, f"find_clusters.vhd")
    ]

    verilog_sources = [
        os.path.join(rtl_dir, f"priority.v")
    ]

    parameters = {}
    parameters['STATION'] = station
    parameters['NUM_FOUND_CLUSTERS'] = num_found_clusters
    if (station==2):
        parameters['NUM_VFATS'] = 12
    else:
        parameters['NUM_VFATS'] = 24

    run(
        verilog_sources=verilog_sources,
        vhdl_sources=vhdl_sources,
        module=module,       # name of cocotb test module
        #compile_args=["-2008"],
        toplevel="find_clusters",            # top level HDL
        toplevel_lang="vhdl",
        parameters=parameters,
        gui=0
    )


if __name__ == "__main__":
    test_find_clusters(0,16)
