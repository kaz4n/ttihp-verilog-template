import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


async def reset_dut(dut):
    dut.ena.value = 1
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1


@cocotb.test()
async def test_mode0_mirror(dut):
    cocotb.start_soon(Clock(dut.clk, 100, unit="us").start())

    # MODE=0, TEST=0, input nibble = 0xA
    dut.ui_in.value = 0x0A

    await reset_dut(dut)
    await ClockCycles(dut.clk, 3)

    uo = int(dut.uo_out.value)
    assert (uo & 0xF) == 0xA, f"PORT_OUT expected 0xA, got 0x{uo & 0xF:X}"
    assert ((uo >> 4) & 0xF) == 0xA, f"ACC expected 0xA, got 0x{(uo >> 4) & 0xF:X}"
    assert int(dut.uio_oe.value) == 0xFF, f"uio_oe expected 0xFF, got 0x{int(dut.uio_oe.value):02X}"


@cocotb.test()
async def test_mode1_counter(dut):
    cocotb.start_soon(Clock(dut.clk, 100, unit="us").start())

    # MODE=1, TEST=0
    dut.ui_in.value = 0x20

    await reset_dut(dut)

    # Let the ROM run into the counting loop
    await ClockCycles(dut.clk, 4)
    first = int(dut.uo_out.value) & 0xF

    await ClockCycles(dut.clk, 4)
    second = int(dut.uo_out.value) & 0xF

    assert second == ((first + 1) & 0xF), (
        f"counter did not increment: first={first}, second={second}"
    )
