#!/usr/bin/env python3
""
import os
import random
import pytest

from cocotb_test.simulator import run

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


async def pulse_l1a(dut):
    dut.l1a_i.value = 1
    await RisingEdge(dut.clock)
    dut.l1a_i.value = 0
    await RisingEdge(dut.clock)

async def pulse_sbit_trig(dut):
    dut.sbit_trigger_i.value = 1
    await RisingEdge(dut.clock)
    dut.sbit_trigger_i.value = 0
    await RisingEdge(dut.clock)

def fifo_state(dut):
    return ("FILLING", "RUNNING", "TRIGGERED", "EMPTY")[dut.gen_fifo.readout_state.value]

def print_fifo_state(dut):
    print("  FIFO_STATE = %s" % fifo_state(dut))

async def generate_inputs(dut):
    while (True):
        for i in range(dut.gen_fifo.xpm_fifo_sync_inst.FIFO_WRITE_DEPTH.value):
            for j in range(8):
                dut.sbit_clusters_i[0][j].address.value = (i * 8 + j) % 2048
                dut.sbit_clusters_i[0][j].size.value = 1 if ((i*8+j) >= 2048) else 0
            await RisingEdge(dut.clock)

@cocotb.test()
async def sbit_monitor_test(dut):
    "Test the bitslip module"

    random.seed(20)

    cocotb.fork(Clock(dut.clock, 40, units="ns").start())  # Create a clock

    TRIG_LATENCY = 32

    dut.fifo_en_l1a_trigger_i.value = 0
    dut.fifo_en_sbit_trigger_i.value = 1

    dut.l1a_i.value = 0
    dut.sbit_trigger_i.value = 0
    dut.link_select_i.value = 0
    dut.fifo_trigger_delay_i.value = TRIG_LATENCY
    dut.fifo_rd_en_i.value = 0
    await RisingEdge(dut.clock)
    dut.reset_i.value = 0
    for j in range(8):
        dut.sbit_clusters_i[0][j].size.value = 0

    cocotb.fork(generate_inputs(dut))

    print("Filling buffer:")
    while (True):
        await RisingEdge(dut.clock)
        if (dut.gen_fifo.full_next.value == 1):
            break

    print_fifo_state(dut)
    assert fifo_state(dut)=="FILLING"

    await RisingEdge(dut.clock)

    print_fifo_state(dut)
    assert fifo_state(dut)=="RUNNING"

    for _ in range(2000):
        await RisingEdge(dut.clock)

    print_fifo_state(dut)
    assert fifo_state(dut)=="RUNNING"

    print("Pulsing trigger:")
    if (dut.fifo_en_l1a_trigger_i.value):
        await pulse_l1a(dut)
    if (dut.fifo_en_sbit_trigger_i.value):
        await pulse_sbit_trig(dut)

    # wait for the l1a delay
    for _ in range(TRIG_LATENCY+1):
        await RisingEdge(dut.clock)
    print_fifo_state(dut)
    assert fifo_state(dut)=="TRIGGERED"

    print("Draining buffer:")

    last = None

    icnt = 0

    # fifo should not be empty
    assert dut.fifo_empty_o.value == 0

    while True:

        await RisingEdge(dut.clock)
        await RisingEdge(dut.clock)
        await RisingEdge(dut.clock)

        # read one word from the fifo
        dut.fifo_rd_en_i.value = 1
        await RisingEdge(dut.clock)
        dut.fifo_rd_en_i.value = 0

        while dut.fifo_valid_o.value == 0:
            await RisingEdge(dut.clock)
            continue

        data = dut.fifo_data_o.value

        (addrs, sizes, l1a) = parse_32b_word(data)

        print("%4d  %d %4d %4d %s %s %s" % (icnt, sizes[0], addrs[0],
                               addrs[1],
                               "l1a" if l1a > 0 else "",
                               "empty_next" if dut.gen_fifo.empty_next.value else "",
                               "empty_now" if dut.gen_fifo.empty_now.value else ""))

        if last is None:
            last = addrs
        else:
            assert addrs[1] == (addrs[0] + 1) % 2048
            assert addrs[0] == (last[0] + 2) % 2048
            assert addrs[1] == (last[1] + 2) % 2048
            last = addrs


        await RisingEdge(dut.clock)
        if (dut.fifo_empty_o.value == 1):
            break
        icnt += 1

    # should be empty now
    assert dut.fifo_empty_o.value == 1

def parse_32b_word(word):
    addrs = (word & 0x07ff, (word >> 16) & 0x07ff)
    sizes = (0x7 & (word >> 12), (word >> 28) & 0x7)
    l1a = (word >> 31) & 1 or (word >> 15) & 1
    return (addrs, sizes, l1a)

@pytest.mark.parametrize()
def test_sbit_monitor():
    ""

    tests_dir = os.path.abspath(os.path.dirname(__file__))
    tests_top = os.path.join(tests_dir, "../../../")
    module = os.path.splitext(os.path.basename(__file__))[0]

    vhdl_sources = [
                    os.path.join(tests_top, "common/hdl/utils/shift_reg.vhd"),
                    # os.path.join(tests_dir, "xpm_cdc_sync_rst.vhd"),
                    # os.path.join(tests_dir, "xpm_reg_pipe_bit.vhd"),
                    # os.path.join(tests_dir, "xpm_counter_updn.vhd"),
                    # os.path.join(tests_dir, "xpm_fifo_reg_bit.vhd"),
                    # os.path.join(tests_dir, "xpm_fifo_reg_vec.vhd"),
                    # os.path.join(tests_dir, "xpm_fifo_rst.vhd"),
                    # os.path.join(tests_dir, "xpm_cdc_gray.vhd"),
                    # os.path.join(tests_dir, "xpm_fifo_base.vhd"),
                    # os.path.join(tests_dir, "xpm_memory_base.vhd"),
                    # os.path.join(tests_dir, "xpm_fifo_sync.vhd"),
                    os.path.join(tests_dir, "sbit_monitor.vhd"),
                    ]

    parameters = {}
    parameters['g_NUM_OF_OHs'] = 1
    parameters['g_USE_FIFO'] = True

    os.environ["SIM"] = "questa"

    run(
        verilog_sources=[],
        vhdl_sources=vhdl_sources,
        module=module,
        compile_args=["-2008"],
        toplevel="sbit_monitor",
        toplevel_lang="vhdl",
        parameters=parameters,
        # sim_args = ["do cluster_packer_wave.do"],
        # extra_env = {"SIM": "questa"},
        gui=0
    )


if __name__ == "__main__":
    test_sbit_monitor()
