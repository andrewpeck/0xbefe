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


def fill_bit(data, width):
    shift = random.randint(0, width-1)
    data |= (1 << shift)
    return data


def truncate_bit(data, width):
    # truncate the lsb
    for ibit in range(width):
        if (1 & (data >> ibit)):
            data = data ^ (1 << ibit)
            return data


@cocotb.test()
async def truncate_lsb_random_data(dut):
    """Test for priority encoder with randomized data on all inputs"""

    cocotb.fork(Clock(dut.clock, 20, units="ns").start())  # Create a clock

    width = dut.WIDTH.value

    for loop in range(4):
        await RisingEdge(dut.clock)  # Synchronize with the clock

    for loop in range(100):

        # create fill a large number with some random bits
        data = 0
        for ibit in range(100):
            data = fill_bit(data, width)

        truncated = truncate_bit(data, width)

        # turn off after 1 clock
        await RisingEdge(dut.clock)  # Synchronize with the clock
        dut.data_i <= data
        dut.latch <= 1
        await RisingEdge(dut.clock)  # Synchronize with the clock
        dut.latch <= 0

        for i in range(0, 3):

            await RisingEdge(dut.clock)  # Synchronize with the clock

            print("Cycle=" + str(i))
            print("  data_i=" + hex(int(data)))
            print("  data_o=" + hex(int(dut.data_o.value)))

            assert i == dut.cycle_o.value

            # first clock is just a copy of the data
            if i == 0:
                print("  data_e=" + hex(int(data)))
                assert data == dut.data_o.value
            else:
                print("  data_e=" + hex(int(truncated)))
                assert truncated == dut.data_o.value
                truncated = truncate_bit(truncated, width)


@pytest.mark.parametrize("width",    [192, 384])
@pytest.mark.parametrize("segments", [12, 16])
def test_truncate_lsb(width, segments):

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', 'hdl'))
    module = os.path.splitext(os.path.basename(__file__))[0]

    vhdl_sources = [
        os.path.join(rtl_dir, f"truncate_lsb.vhd"),
    ]

    parameters = {}
    parameters['WIDTH'] = width
    parameters['SEGMENTS'] = segments

    os.environ["SIM"] = "questa"

    run(
        vhdl_sources=vhdl_sources,
        module=module,       # name of cocotb test module
        compile_args=["-2008"],
        toplevel="truncate_lsb",            # top level HDL
        toplevel_lang="vhdl",
        parameters=parameters,
        gui=0
    )


if __name__ == "__main__":
    test_truncate_lsb()
