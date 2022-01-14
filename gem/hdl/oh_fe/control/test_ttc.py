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

BXN_MAX = 3564

async def inj_bx0_err(dut):
    await RisingEdge(dut.clock)
    dut.ttc_bx0.value = not dut.ttc_bx0.value
    await RisingEdge(dut.clock)
    dut.ttc_bx0.value = not dut.ttc_bx0.value

async def bxn_generator(dut):
    await RisingEdge(dut.clock)
    bxn_counter = 0
    while (True):
        if (bxn_counter == BXN_MAX - 1):
            dut.ttc_bx0.value = 1
            bxn_counter = 0
        else:
            dut.ttc_bx0.value = 0
            bxn_counter += 1
        await RisingEdge(dut.clock)

def setup(dut):
    cocotb.fork(Clock(dut.clock, 24, units="ns").start())  # Create a clock

    dut.ttc_bx0.value = 0
    dut.ttc_resync.value = 0
    dut.reset.value = 1
    dut.bxn_offset_i.value = 0

    cocotb.fork(bxn_generator(dut))

async def resync(dut):
    # send a resync
    dut.ttc_resync.value = 0
    await RisingEdge(dut.clock)  # Synchronize with the clock
    dut.ttc_resync.value = 0
    await RisingEdge(dut.ttc_bx0)
    await RisingEdge(dut.ttc_bx0)
    await RisingEdge(dut.ttc_bx0)
    await Timer(1, units='ns')


def status(dut):
    print(f'  > {dut.bx0_local_o.value.integer=}')
    print(f'  > {dut.ttc_bx0.value.integer=}')
    print(f'  > {dut.bx0_sync_err_o.value.integer=}')
    print(f'  > {dut.bxn_sync_err_o.value.integer=}')
    print(f'  > {dut.bxn_counter_o.value.integer=}')
    print(f'  > {dut.bxn_read_offset_o.value.integer=}')

async def check_for_bx0_sync_errs(dut):
    for _ in range(4000):
        await RisingEdge(dut.clock)
        assert dut.bx0_sync_err_o.value.integer == 0

@cocotb.test()
async def test_status(dut):

    setup(dut)

    for _ in range(4):
        await RisingEdge(dut.clock)  # Synchronize with the clock

    dut.reset.value = 0

    ################################################################################
    # Test a resync with offset set to 0 (synchronized)
    ################################################################################

    dut.bxn_offset_i.value = 0
    await resync(dut)
    print("Testing resync with offset = %d" % dut.bxn_offset_i.value.integer)

    await RisingEdge(dut.ttc_bx0)
    await Timer(1, units='ns')
    status(dut)
    assert dut.bx0_local_o.value.integer == 1
    assert dut.bx0_local_o.value.integer == 1
    assert dut.bx0_sync_err_o.value.integer == 0
    assert dut.bxn_counter_o.value.integer == 0
    assert dut.bxn_sync_err_o.value.integer == 0
    assert dut.ttc_bx0 == 1
    assert dut.ttc_bx0.value.integer == 1
    await check_for_bx0_sync_errs(dut)
    print("----------------------------------------------------------------------")

    ################################################################################
    # Test a resync with offset set to 100 (offset)
    ################################################################################

    await RisingEdge(dut.clock)
    dut.bxn_offset_i.value = 100
    print("Testing resync with offset = %d" % dut.bxn_offset_i.value.integer)
    await resync(dut)

    status(dut)
    # check bc0
    assert dut.bx0_local_o.value.integer == 0 # should NOT expect a BC0 since it is now offset
    assert dut.ttc_bx0 == 1
    # check bxn
    assert dut.bxn_counter_o.value.integer == dut.bxn_offset_i.value
    assert dut.ttc_bx0.value.integer == 1
    assert dut.bx0_sync_err_o.value.integer == 0
    assert dut.bxn_sync_err_o.value.integer == 0
    await check_for_bx0_sync_errs(dut)
    print("----------------------------------------------------------------------")

    await inj_bx0_err(dut)
    assert dut.bx0_sync_err_o.value.integer == 1
    await RisingEdge(dut.clock)
    assert dut.bxn_sync_err_o.value.integer == 1
    await RisingEdge(dut.clock)
    assert dut.bxn_sync_err_o.value.integer == 1
    await RisingEdge(dut.clock)

def test_ttc():

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    rtl_dir = os.path.abspath(os.path.join(tests_dir))
    module = os.path.splitext(os.path.basename(__file__))[0]

    vhdl_sources = [
        os.path.join(rtl_dir, f"ttc.vhd"),
    ]

    os.environ["SIM"] = "ghdl"

    run(
        vhdl_sources=vhdl_sources,
        module=module,       # name of cocotb test module
        toplevel="ttc",            # top level HDL
        toplevel_lang="vhdl",
        gui=1
    )

if __name__ == "__main__":
    test_ttc()
