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

@cocotb.test()
async def test_sc(dut):

    # setup clocks
    cocotb.fork(Clock(dut.clock, 40, units="ns").start())  # Create a clock

    #-------------------------------------------------------------------------------
    # initialize
    #-------------------------------------------------------------------------------

    dut.reset.value = 1;
    dut.l1a_i.value = 0;
    dut.bc0_i.value = 0;
    dut.resync_i.value = 0;

    dut.request_valid_i.value = 0;
    dut.request_write_i.value = 1;
    dut.request_addr_i.value = 0;
    dut.request_data_i.value = 0;

    for i in range(10):
        await RisingEdge(dut.clock)

    dut.reset.value = 0;

    #-------------------------------------------------------------------------------
    # wait some time for rx to lock and go ready
    #-------------------------------------------------------------------------------

    print("Waiting for link to lock...")
    await RisingEdge(dut.oh_rx_ready)
    print(" > Link Locked")

    #-------------------------------------------------------------------------------
    # write data loop
    #-------------------------------------------------------------------------------

    for i in range(100):

        wr_data = random.randint(0,2**32-1);

        await RisingEdge(dut.clock)

        dut.request_valid_i.value = 1
        dut.request_write_i.value = 1
        dut.request_addr_i.value = i
        dut.request_data_i.value = wr_data

        await RisingEdge(dut.clock)

        dut.request_valid_i.value = 0

        await RisingEdge(dut.reg_data_valid_o)
        print(f"wr=%08X, rd=%08X" % (wr_data, int(dut.reg_data_o)))
        assert dut.reg_data_o.value == wr_data
        assert dut.oh_precrc_err.value == 0
        assert dut.be_precrc_err.value == 0
        assert dut.oh_crc_err.value == 0
        assert dut.be_crc_err.value == 0
        assert dut.be_rx_err.value == 0
        assert dut.oh_rx_ready.value == 1

    #-------------------------------------------------------------------------------
    # ttc tests
    #-------------------------------------------------------------------------------

    for _ in range(10):
        await RisingEdge(dut.clock)

    dut.l1a_i.value = 1;
    await RisingEdge(dut.l1a_o);
    dut.l1a_i.value = 0;
    assert dut.l1a_o.value==1

    dut.bc0_i.value = 1;
    await RisingEdge(dut.bc0_o);
    dut.bc0_i.value = 0;
    assert dut.bc0_o.value==1

    dut.resync_i.value = 1;
    await RisingEdge(dut.resync_o);
    dut.resync_i.value = 0;
    assert dut.resync_o.value==1

def test_oh_sc():

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    module = os.path.splitext(os.path.basename(__file__))[0]

    vhdl_sources = [
        os.path.join(tests_dir, "../../../../common/hdl/utils/bitslip.vhd"),
        os.path.join(tests_dir, "./link_oh_fpga_crc.vhd"),
        os.path.join(tests_dir, "./link_oh_fpga_tx.vhd"),
        os.path.join(tests_dir, "./link_oh_fpga_rx.vhd"),
        os.path.join(tests_dir, "./link_oh_fpga_tb.vhd"),
    ]

    os.environ["SIM"] = "questa"

    run(
        verilog_sources=None,
        vhdl_sources=vhdl_sources,
        module=module,
        toplevel="gbt_link_tb",
        toplevel_lang="vhdl",
        parameters=None,
         #sim_args=["-do", "set NumericStdNoWarnings 1;"],
        gui=0,
    )


if __name__ == "__main__":
    test_oh_sc()
