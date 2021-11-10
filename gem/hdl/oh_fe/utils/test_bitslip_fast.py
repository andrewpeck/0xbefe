#!/usr/bin/env python3
""
import os
import random
import pytest

from cocotb_test.simulator import run

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.triggers import FallingEdge


def bitslip(din, buf, cnt, width=8):
    ""
    din = din >> cnt
    buf = buf << (width - cnt)
    return (din | buf) & (2**width - 1)


async def bitslip_test_single(dut, din, buf, cnt, width):
    ""
    dut.bitslip_cnt = cnt
    dut.din = buf
    await RisingEdge(dut.clock)
    dut.din = din

    await FallingEdge(dut.clock)
    print("bitslip(%X,  %X,  %X) = %X" % (din, buf, cnt, bitslip(din, buf, cnt, width)))
    assert dut.dout.value == bitslip(din, buf, cnt, width)

@cocotb.test()
async def bitslip_fast_test(dut):
    "Test the bitslip module"

    random.seed(20)

    cocotb.fork(Clock(dut.clock, 40, units="ns").start())  # Create a clock

    dut.din = 0
    await RisingEdge(dut.clock)
    await RisingEdge(dut.clock)
    await RisingEdge(dut.clock)

    width = dut.g_WORD_SIZE.value
    maxval = 2**width - 1
    for ibitslip in range(width):
        for _ in range(1000):
            a = random.randint(0, maxval)
            b = random.randint(0, maxval)
            await bitslip_test_single(dut, a, b, ibitslip, width)
    await RisingEdge(dut.clock)
    await RisingEdge(dut.clock)


@pytest.mark.parametrize("width", [2,4,6,8,16])
def test_bitslip_fast(width):
    ""

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    module = os.path.splitext(os.path.basename(__file__))[0]

    vhdl_sources = [os.path.join(tests_dir, "bitslip_fast.vhd")]

    parameters = {}
    parameters['g_WORD_SIZE'] = width

    os.environ["SIM"] = "ghdl"

    run(
        verilog_sources=[],
        vhdl_sources=vhdl_sources,
        module=module,
        toplevel="bitslip_fast",
        toplevel_lang="vhdl",
        parameters=parameters,
        # sim_args = ["do cluster_packer_wave.do"],
        # extra_env = {"SIM": "questa"},
        gui=0
    )


if __name__ == "__main__":
    test_bitslip_fast(8)
