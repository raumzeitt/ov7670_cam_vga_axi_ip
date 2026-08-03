"""Phase 1: vga_timing counters, active region, active-low sync pulses."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

# Must match vga_timing_tb.sv parameters
H_VISIBLE = 16
H_FP = 2
H_SYNC = 4
H_BP = 2
H_TOTAL = H_VISIBLE + H_FP + H_SYNC + H_BP  # 24

V_VISIBLE = 8
V_FP = 1
V_SYNC = 2
V_BP = 1
V_TOTAL = V_VISIBLE + V_FP + V_SYNC + V_BP  # 12

H_SYNC_START = H_VISIBLE + H_FP  # 18
H_SYNC_END = H_SYNC_START + H_SYNC  # 22
V_SYNC_START = V_VISIBLE + V_FP  # 9
V_SYNC_END = V_SYNC_START + V_SYNC  # 11


async def _reset(dut):
    dut.rst_n.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)


@cocotb.test()
async def test_timing_one_frame(dut):
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())
    await _reset(dut)

    # Align to a clean frame start
    for _ in range(H_TOTAL * V_TOTAL + 4):
        await RisingEdge(dut.clk)
        if int(dut.frame_start.value):
            break
    else:
        raise AssertionError("never saw frame_start")

    active_pixels = 0
    hsync_low = 0
    vsync_low_lines = set()

    # Exactly one frame from (0,0)
    for _ in range(H_TOTAL * V_TOTAL):
        h = int(dut.h_count.value)
        v = int(dut.v_count.value)

        expect_active = (h < H_VISIBLE) and (v < V_VISIBLE)
        assert int(dut.video_active.value) == int(expect_active), (
            f"active mismatch at h={h} v={v}"
        )

        if expect_active:
            assert int(dut.pix_x.value) == h
            assert int(dut.pix_y.value) == v
            active_pixels += 1

        expect_hs_n = 0 if (H_SYNC_START <= h < H_SYNC_END) else 1
        assert int(dut.hsync_n.value) == expect_hs_n, f"hsync at h={h}"

        expect_vs_n = 0 if (V_SYNC_START <= v < V_SYNC_END) else 1
        assert int(dut.vsync_n.value) == expect_vs_n, f"vsync at v={v}"

        if expect_hs_n == 0:
            hsync_low += 1
        if expect_vs_n == 0:
            vsync_low_lines.add(v)

        await RisingEdge(dut.clk)

    assert active_pixels == H_VISIBLE * V_VISIBLE
    assert hsync_low == H_SYNC * V_TOTAL
    assert vsync_low_lines == set(range(V_SYNC_START, V_SYNC_END))
