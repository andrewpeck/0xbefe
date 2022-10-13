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
async def sbit_delay_test(dut):
    "Test the bitslip module"

    NUM_VFATS = 24

    random.seed(20)
    dut.sbits_i.value = [0] * NUM_VFATS

    cocotb.fork(Clock(dut.clock, 40, units="ns").start())  # Create a clock

    for _ in range(4):
        await RisingEdge(dut.clock)

    for en in range(2):

        dut.dly_enable.value = en * (2**int(24*64/8)-1)

        for delay in range(7):

            dut.sbit_bx_dlys_i.value = [delay] * int(24*64/8)

            await RisingEdge(dut.clock)

            print(f"Delay {delay}")

            for i in range(100):

                if (i==0):
                    dut.sbits_i.value = [0xffffffffffffffff] * NUM_VFATS
                else:
                    dut.sbits_i.value = [0] * NUM_VFATS

                if int(dut.sbits_i[0].value) > 0:
                    print(f" > en={en}, dly={delay}, i={i}, sbit_i=%d" % int(dut.sbits_i[0].value))
                if int(dut.sbits_o[0].value) > 0:
                    print(f" > en={en}, dly={delay}, i={i}, sbit_o=%d" % int(dut.sbits_o[0].value))

                for _ in range(4):
                    await RisingEdge(dut.clock)
                    if en==1 and i==delay+1:
                        assert int(dut.sbits_o[0].value) > 0
                    if en==0:
                        assert int(dut.sbits_o[0].value)  == int(dut.sbits_i[0].value)

def test_sbit_delay(width, delay):
    ""

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    module = os.path.splitext(os.path.basename(__file__))[0]

    vhdl_sources = [os.path.join(tests_dir, "../../oh_fe/pkg/tmr_en_pkg.vhd"),
                    os.path.join(tests_dir, "../hdl/cluster_pkg.vhd"),
                    os.path.join(tests_dir, "../../oh_fe/pkg/hardware_pkg_ge11.vhd"),
                    os.path.join(tests_dir, "../hdl/sbit_delay.vhd"),]

    parameters = {}

    parameters['NUM_VFATS'] = 24

    os.environ["SIM"] = "questa"

    run(
        verilog_sources=[],
        vhdl_sources=vhdl_sources,
        module=module,
        toplevel="sbit_delay",
        toplevel_lang="vhdl",
        sim_args=["-do", '"set NumericStdNoWarnings 1;"'],
        parameters=parameters,
        gui=1
    )


if __name__ == "__main__":
    test_sbit_delay(16, 2)
