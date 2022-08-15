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


@cocotb.test()
async def fixed_delay_test(dut):
    "Test the bitslip module"

    random.seed(20)
    dut.data_i.value = 0
    data = 2**(dut.WIDTH.value) - 1

    cocotb.fork(Clock(dut.clock, 40, units="ns").start())  # Create a clock

    await RisingEdge(dut.clock)
    dut.data_i.value = data

    await RisingEdge(dut.clock)
    if (dut.DELAY.value == 0):
        assert dut.data_o.value == data
    else:
        for _ in range(dut.DELAY.value):
            dut.data_i.value = 0
            print("data_i=%d data_o=%d" % (dut.data_i.value, dut.data_o.value))
            await RisingEdge(dut.clock)

    print("data_i=%d data_o=%d" % (dut.data_i.value, dut.data_o.value))
    assert dut.data_o.value == data

@pytest.mark.parametrize("width", [2, 4, 6, 8, 16])
@pytest.mark.parametrize("delay", [0, 1, 2, 4, 8])
def test_fixed_delay(width, delay):
    ""

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    module = os.path.splitext(os.path.basename(__file__))[0]

    vhdl_sources = [os.path.join(tests_dir, "fixed_delay.vhd")]

    parameters = {}
    parameters['DELAY'] = delay
    parameters['WIDTH'] = width

    os.environ["SIM"] = "ghdl"

    run(
        verilog_sources=[],
        vhdl_sources=vhdl_sources,
        module=module,
        toplevel="fixed_delay",
        toplevel_lang="vhdl",
        parameters=parameters,
        gui=0
    )


if __name__ == "__main__":
    test_fixed_delay(16, 2)
