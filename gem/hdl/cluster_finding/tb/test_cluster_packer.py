#!/usr/bin/env python3
import os
import random
import pytest

import cocotb
from cocotb_test.simulator import run
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from cluster_finding import Cluster, find_clusters, equal, find_cluster_primaries


def print_clusters(clusters):
    for i in range(len(clusters)):
        print(
            f" > %2d adr=%3d cnt=%X prt=%X vpf=%X"
            % (
                i,
                clusters[i].adr.value,
                clusters[i].cnt.value,
                clusters[i].prt.value,
                clusters[i].vpf.value,
            )
        )

@cocotb.test()
async def random_data(dut, nloops=1000, nhits=128):
    await run_test(dut, "RANDOM", nloops, nhits)

@cocotb.test()
async def walking1(dut):
    await run_test(dut, "WALKING1")

@cocotb.test()
async def colliding1(dut):
    await run_test(dut, "COLLIDING1")

# @cocotb.test()
# async def specific(dut):
#     await run_test(dut, "SPECIFIC")

@cocotb.test()
async def edges(dut, nloops=1000, nhits=32):
    await run_test(dut, "EDGES", nloops, nhits)


async def run_test(dut, test, nloops=1000, nhits=128, verbose=True):
    """Test for priority encoder with randomized data on all inputs"""

    # extract detector parameters

    NVFATS = dut.NUM_VFATS.value
    STATION = dut.STATION.value

    if STATION in [0, 1]:
        NPARTITIONS = 8
        WIDTH = 192
        NSTRIPS = 1536
    elif STATION == 2:
        NPARTITIONS = 2
        WIDTH = 384
        NSTRIPS = 768
    else:
        NPARTITIONS = 0
        WIDTH = 0
        NSTRIPS = 0

    if test in ("WALKING1", "COLLIDING1"):
        nloops = NSTRIPS

    # set inputs

    dut.mask_output_i.value = 0
    dut.reset.value = 0

    # setup clocks
    cocotb.fork(Clock(dut.clk_40, 40, units="ns").start())  # Create a clock
    cocotb.fork(Clock(dut.clk_fast, 10, units="ns").start())  # Create a clock

    ngood = 0

    SORTER_TYPE = dut.find_clusters_inst.SORTER_TYPE

    if SORTER_TYPE == 0:
        LATENCY = 4
    elif SORTER_TYPE == 1:
        LATENCY = 4
    elif SORTER_TYPE == 2:
        LATENCY = 3

    print("Running test: %s" % test)

    vfat_pipeline = []

    for _ in range(LATENCY):
        vfat_pipeline.append([0] * NVFATS)

    # zero the inputs
    vfats = [0] * NVFATS
    dut.sbits_i.value = vfats

    # flush the pipeline with zeroes
    for _ in range(8):
        await RisingEdge(dut.clk_40)

    bit_mask_64 = 2 ** 64 - 1

    # event loop
    for loop in range(nloops):

        if verbose or loop % (nloops / 100) == 0:
            print(" > loop %d of %d" % (loop, nloops))

        # Drive the inputs

        vfats = [0] * NVFATS

        if test == "SPECIFIC":
            for (prt, adr, cnt) in [
                (7, 63, 1),
                (6, 69, 0),
                (6, 66, 0),
                (6, 124, 0),
                (5, 0, 0),
                (4, 191, 0),
                (3, 69, 0),
            ]:

                channel = adr % 64
                size = 2 ** (cnt + 1) - 1
                if (STATION == 2):
                    ivfat = prt + 2 * (adr // 64)
                else:
                    ivfat = prt + 8 * (adr // 64)

                val = (size << channel) & bit_mask_64
                vfats[ivfat] |= val

        if test == "WALKING1":
            # walking 1s
            strip = loop
            ivfat = strip // 64
            channel = strip % 64
            size = 1
            vfats[ivfat] |= (size << channel) & bit_mask_64

        if test == "COLLIDING1":
            # colliding walking 1s
            for i in range(2):

                if i == 0:
                    strip = loop
                else:
                    strip = NSTRIPS - 1 - loop

                ivfat = strip // 64
                channel = strip % 64
                size = 1
                vfats[ivfat] |= (size << channel) & bit_mask_64

        if test == "EDGES":
            # focus on the edges
            for _ in range(random.randint(0, nhits)):
                ivfat = random.randint(0, NVFATS - 1)
                channel = random.choice((0, 63, 64, 127, 128, 191))
                size = random.choice((1, 3))
                vfats[ivfat] |= (size << channel) & bit_mask_64

        if test == "RANDOM":
            # create fill a large number with some random bits
            for _ in range(random.randint(0, nhits)):
                ivfat = random.randint(0, NVFATS - 1)
                channel = random.randint(0, 63)
                size = 2 ** (random.randint(0, 15)) - 1
                vfats[ivfat] |= (size << channel) & bit_mask_64

        # set the dut input, and copy the input to a latency pipeline for later
        for i in range(NVFATS):
            dut.sbits_i[i].value = vfats[i]
        vfat_pipeline.append(vfats)

        await RisingEdge(dut.clk_40)

        nclusters = 0
        clusters = dut.clusters_o

        # -------------------------------------------------------------------------------
        # emulate the cluster finding algorithm
        # -------------------------------------------------------------------------------

        vfats_xpipeline = vfat_pipeline.pop(0)

        (vpfs, cnts, total) = find_cluster_primaries(
            vfats_xpipeline, WIDTH, INVERT=dut.INVERT_PARTITIONS.value
        )

        expected_clusters = find_clusters(
            vpfs,  # partition vpfs
            cnts,  # partition counts
            WIDTH,  # width of a partition
            dut.find_clusters_inst.NUM_FOUND_CLUSTERS.value,
            dut.find_clusters_inst.ENCODER_SIZE.value,
        )

        # -------------------------------------------------------------------------------
        # extract the outputs from the dut
        # -------------------------------------------------------------------------------

        found_clusters = [None] * 16
        for iclst in range(16):
            cluster = Cluster()
            cluster.adr = dut.clusters_o[iclst].adr.value
            cluster.cnt = dut.clusters_o[iclst].cnt.value
            cluster.prt = dut.clusters_o[iclst].prt.value
            cluster.vpf = dut.clusters_o[iclst].vpf.value
            found_clusters[iclst] = cluster

        # TODO: check the cluster latency

        # TODO: check the overflows

        # TODO: check the cluster masking

        # -------------------------------------------------------------------------------
        # check the cluster count
        # -------------------------------------------------------------------------------

        total_tb = int(dut.cluster_count_o.value)
        assert total == total_tb, print(
            " > cluster primary counts: emu=%d vs simu=%d (loop=%d)"
            % (total, total_tb, loop)
        )

        # -------------------------------------------------------------------------------
        # check the number of found (valid) clusters
        # -------------------------------------------------------------------------------

        num_found_emu = 0
        for i in range(16):
            if expected_clusters[i].vpf == 1:
                num_found_emu += 1

        num_found_simu = 0
        for i in range(16):
            if expected_clusters[i].vpf == 1:
                num_found_simu += 1

        assert num_found_emu == num_found_simu, print(
            " > cluster finder counts: emu=%d vs simu=%d (loop=%d)"
            % (num_found_emu, num_found_simu, loop)
        )

        # -------------------------------------------------------------------------------
        # check the actual clusters against the emulator
        # -------------------------------------------------------------------------------

        if verbose:
            for i in range(16):
                if found_clusters[i].vpf == 1 or expected_clusters[i].vpf == 1:
                    print(
                        " > #%2d Found  %s, \n       expect %s"
                        % (i, str(found_clusters[i]), str(expected_clusters[i]))
                    )


        # sorter type 1 & 2 are ordered
        # sorter type 0 is less predictable...
        if SORTER_TYPE != 0:

            for i in range(16):
                assert equal(found_clusters[i], expected_clusters[i]), print(
                    " > #%2d Found  %s, \n       expect %s (Test=%s loop=%d)"
                    % (i, str(found_clusters[i]), str(expected_clusters[i]), test, loop)
                )

        # -------------------------------------------------------------------------------
        # check that all clusters w/ vpf = 0 have an invalid address, and all valid
        # addresses are marked with vpf = 1
        # -------------------------------------------------------------------------------

        for i in range(len(clusters)):
            if int(clusters[i].vpf.value) == 0:
                assert int(clusters[i].adr.value) == 0x1FF
            if int(clusters[i].vpf.value) == 1:
                assert int(clusters[i].adr.value) < WIDTH
            if int(clusters[i].adr.value) < WIDTH:
                assert int(clusters[i].vpf.value) == 1
            if int(clusters[i].adr.value) >= WIDTH:
                assert int(clusters[i].vpf.value) == 0
                assert int(clusters[i].adr.value) == 0x1FF

        # -------------------------------------------------------------------------------
        # check the uniqueness of the clusters, don't allow duplicates
        # -------------------------------------------------------------------------------

        for i in range(len(clusters)):

            if int(clusters[i].vpf.value) == 1:
                nclusters += 1

            for j in range(len(clusters)):

                if (
                    i != j
                    and int(clusters[i].vpf.value) == 1
                    and int(clusters[j].vpf.value) == 1
                ):

                    assert not equal(clusters[i], clusters[j]), print_clusters(clusters)
                    assert not (
                        clusters[i].adr.value == clusters[j].adr.value
                        and clusters[i].cnt.value == clusters[j].cnt.value
                        and clusters[i].prt.value == clusters[j].prt.value
                    ), print_clusters(clusters)

                    ngood = ngood + 1


# @pytest.mark.parametrize("oneshot", [False])
# @pytest.mark.parametrize("deadtime", [0, 1])
@pytest.mark.parametrize("station", [1, 2])
def test_cluster_packer(station, oneshot=False, deadtime=0):

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    rtl_dir = os.path.abspath(os.path.join(tests_dir, "..", "hdl"))
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
        os.path.join(rtl_dir, f"sort_clusters.vhd"),
        os.path.join(rtl_dir, f"find_clusters.vhd"),
        os.path.join(rtl_dir, f"top_cluster_packer.vhd"),
    ]

    verilog_sources = [
        os.path.join(rtl_dir, f"find_cluster_primaries.v"),
        os.path.join(rtl_dir, f"count.v"),
        os.path.join(rtl_dir, f"consecutive_count.v"),
        os.path.join(rtl_dir, f"sorter16.v"),
        os.path.join(rtl_dir, f"priority.v")
    ]

    parameters = {}
    parameters["STATION"] = station
    parameters["DEADTIME"] = deadtime
    parameters["ONESHOT"] = oneshot

    if station == 2:
        parameters["NUM_VFATS"] = 12
    else:
        parameters["NUM_VFATS"] = 24

    if station == 2:
        parameters["NUM_PARTITIONS"] = 2
    else:
        parameters["NUM_PARTITIONS"] = 8

    os.environ["SIM"] = "questa"

    run(
        verilog_sources=verilog_sources,
        vhdl_sources=vhdl_sources,
        module=module,
        toplevel="cluster_packer",
        toplevel_lang="vhdl",
        parameters=parameters,
        vhdl_compile_args=["-2008"],
        # sim_args = ["do cluster_packer_wave.do"],
        sim_args=["-do", '"set NumericStdNoWarnings 1;"'],
        gui=0,
    )


if __name__ == "__main__":
    # testing the oneshot is complicated here, since the emulator doesn't take
    # into account the past :(
    test_cluster_packer(1, False, 0)
    test_cluster_packer(2, False, 0)
