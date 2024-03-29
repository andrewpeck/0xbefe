#!/usr/bin/env python3
import os
import random
import pytest

import cocotb
from cocotb_test.simulator import run
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.triggers import Edge

from cluster_finding import Cluster, find_clusters, equal, find_cluster_primaries

def print_clusters(clusters):
    for i in range(len(clusters)):
        print(f" > %2d adr=%3d cnt=%X prt=%X vpf=%X"
              % (i, clusters[i].adr.value,
                 clusters[i].cnt.value,
                 clusters[i].prt.value,
                 clusters[i].vpf.value,))

@cocotb.test()
async def phase_offset_test_0(dut, nloops=100, nhits=8):
    await run_test(dut, "RANDOM", nloops, nhits, phase=0)

@cocotb.test()
async def phase_offset_test_1(dut, nloops=100, nhits=8):
    await run_test(dut, "RANDOM", nloops, nhits, phase=1)

@cocotb.test()
async def phase_offset_test_2(dut, nloops=100, nhits=8):
    await run_test(dut, "RANDOM", nloops, nhits, phase=2)

@cocotb.test()
async def phase_offset_test_3(dut, nloops=100, nhits=8):
    await run_test(dut, "RANDOM", nloops, nhits, phase=3)

@cocotb.test()
async def phase_offset_test_4(dut, nloops=100, nhits=8):
    await run_test(dut, "RANDOM", nloops, nhits, phase=4)

@cocotb.test()
async def random_data(dut, nloops=1000, nhits=90):
    await run_test(dut, "RANDOM", nloops, nhits)

@cocotb.test()
async def walking1(dut):
    await run_test(dut, "WALKING1")

@cocotb.test()
async def colliding1(dut):
    await run_test(dut, "COLLIDING1")

@cocotb.test()
async def specific(dut):
    await run_test(dut, "SPECIFIC")

@cocotb.test()
async def edges(dut, nloops=1000, nhits=32):
    await run_test(dut, "EDGES", nloops, nhits)

async def measure_latency(dut) -> float:

    await RisingEdge(dut.clk_fast)

    cnt = 0

    while sum(dut.sbits_i.value) < 1:
        await RisingEdge(dut.clk_fast)

    while (dut.clusters_o[0].vpf.value == 0):
        await RisingEdge(dut.clk_fast)
        cnt += 1

    print("================================================================================")
    print("LATENCY=%f" % (cnt / 4))
    print("================================================================================")
    return (cnt/4.0)

async def monitor_latch_in_alignment(dut):

    for i in range(32):
        await RisingEdge(dut.clk_40)

    while True:
        await Edge(dut.vpfs)
        assert dut.strobe_s1.value==1, "Strobe input is out of time with vpfs"

async def monitor_latch_out_alignment(dut):

    for i in range(8):
        await RisingEdge(dut.clk_40)

    while True:
        await Edge(dut.clusters)
        assert dut.cluster_latch.value==1, "Clusters changed out of time with latch!"

async def monitor_overflow(dut):

    for i in range(16):
        await RisingEdge(dut.clk_40)

    overflow_last = 0
    while True:
        await RisingEdge(dut.clk_fast)
        if (overflow_last==0 and dut.overflow_o.value==1):
            assert dut.valid_o.value==1, "Overflow out of time with latch!"

        overflow_last = dut.overflow_o.value

async def run_test(dut, test, nloops=1000, nhits=128, verbose=False, noassert=False, phase=0):
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

    cocotb.fork(measure_latency(dut))
    cocotb.fork(monitor_latch_in_alignment(dut))
    cocotb.fork(monitor_latch_out_alignment(dut))
    cocotb.fork(monitor_overflow(dut))

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
    bit_mask_64 = 2 ** 64 - 1
    cluster_sizes = [[0] * 8]*16

    for _ in range(LATENCY):
        vfat_pipeline.append([0] * NVFATS)

    # zero the inputs
    vfats = [0] * NVFATS
    dut.sbits_i.value = vfats

    # flush the pipeline with zeroes
    for _ in range(8):
        await RisingEdge(dut.clk_40)

    # offset the input data relative to the 40MHz clock
    for i in range(phase):
        await RisingEdge(dut.clk_fast)

    # feed in a cluster to align the phase detector
    vfats = [1] * NVFATS
    dut.sbits_i.value = vfats
    for i in range(4):
        await RisingEdge(dut.clk_fast)

    # flush the pipeline with zeroes
    vfats = [0] * NVFATS
    dut.sbits_i.value = vfats
    for i in range(4*8):
        await RisingEdge(dut.clk_fast)

    # flush the pipeline with zeroes
    for _ in range(16):
        await RisingEdge(dut.clk_fast)

    # event loop
    for loop in range(nloops):

        if verbose:
            print(" > loop %d of %d" % (loop+1, nloops))

        # Drive the inputs

        vfats = [0] * NVFATS

        # only put data on every other clock cycle so that the one-shots can reset
        if (loop % 2 == 0):

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

        for _ in range(4):
            await RisingEdge(dut.clk_fast)

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

        # TODO: check the overflows

        # TODO: check the cluster masking

        # -------------------------------------------------------------------------------
        # check the cluster count
        # -------------------------------------------------------------------------------

        total_tb = int(dut.cluster_count_o.value)
        assert noassert or total == total_tb, print(
            " > cluster primary counts: emu=%d vs simu=%d (loop=%d)"
            % (total, total_tb, loop)
        )

        # -------------------------------------------------------------------------------
        # check the phase detector
        # -------------------------------------------------------------------------------

        # assert int(dut.phase_detect.value) == phase % 4, print(
        #     "Phase detect = %d" % int(dut.phase_detect.value))

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

        assert noassert or num_found_emu == num_found_simu, print(
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
                assert noassert or equal(found_clusters[i], expected_clusters[i]), print(
                    " > #%2d Found  %s, \n       expect %s (Test=%s loop=%d)"
                    % (i, str(found_clusters[i]), str(expected_clusters[i]), test, loop)
                )

        # -------------------------------------------------------------------------------
        # check that all clusters w/ vpf = 0 have an invalid address, and all valid
        # addresses are marked with vpf = 1
        # -------------------------------------------------------------------------------

        for i in range(len(clusters)):
            if int(clusters[i].vpf.value) == 0:
                assert noassert or int(clusters[i].adr.value) == 0x1FF
            if int(clusters[i].vpf.value) == 1:
                assert noassert or int(clusters[i].adr.value) < WIDTH
            if int(clusters[i].adr.value) < WIDTH:
                assert noassert or int(clusters[i].vpf.value) == 1
            if int(clusters[i].adr.value) >= WIDTH:
                assert noassert or int(clusters[i].vpf.value) == 0
                assert noassert or int(clusters[i].adr.value) == 0x1FF

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

                    assert noassert or not equal(clusters[i], clusters[j]), print_clusters(clusters)
                    assert noassert or not (
                        clusters[i].adr.value == clusters[j].adr.value
                        and clusters[i].cnt.value == clusters[j].cnt.value
                        and clusters[i].prt.value == clusters[j].prt.value
                    ), print_clusters(clusters)

                    ngood = ngood + 1


@pytest.mark.parametrize("oneshot", [True, False])
@pytest.mark.parametrize("station", [1, 2])
def test_cluster_packer(station, oneshot):

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    rtl_dir = os.path.abspath(os.path.join(tests_dir, "..", "hdl"))
    module = os.path.splitext(os.path.basename(__file__))[0]

    vhdl_sources = [
        os.path.join(rtl_dir, f"cluster_pkg.vhd"),
        os.path.join(rtl_dir, f"fixed_delay.vhd"),
        os.path.join(rtl_dir, f"sbit_oneshot.vhd"),
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
        # sim_args = ["do cluster_packer_wave.do"],
        sim_args=["-do", '"set NumericStdNoWarnings 1;"'],
        gui=0,
    )


if __name__ == "__main__":
    test_cluster_packer(station=1, oneshot=True)
    test_cluster_packer(station=2, oneshot=True)
    test_cluster_packer(station=1, oneshot=False)
    test_cluster_packer(station=2, oneshot=False)
