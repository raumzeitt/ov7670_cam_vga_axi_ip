"""Phase-3 test: full ov7670_cam_axis IP using cocotbext-axi AxiStreamSink."""

from __future__ import annotations

import itertools

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiStreamBus, AxiStreamSink

from ov7670_bfm import Ov7670Bfm, pixel_at

IMG_W = 32
IMG_H = 24


def _pause_2_of_3():
    """Backpressure: ready, ready, pause, ... (~2/3 duty)."""
    return itertools.cycle((False, False, True))


async def _reset_dut(dut):
    dut.cfg_start.value = 0
    dut.stream_enable.value = 0
    dut.ov7670_vsync.value = 0
    dut.ov7670_href.value = 0
    dut.ov7670_data.value = 0

    dut.rst_n.value = 0
    for _ in range(10):
        await RisingEdge(dut.cfg_clk)
    dut.rst_n.value = 1
    for _ in range(10):
        await RisingEdge(dut.cfg_clk)


async def _run_config(dut):
    dut.cfg_start.value = 1
    await RisingEdge(dut.cfg_clk)
    dut.cfg_start.value = 0

    timeout = 0
    while int(dut.cfg_done.value) == 0:
        await RisingEdge(dut.cfg_clk)
        timeout += 1
        assert timeout < 2_000_000, "timeout waiting for cfg_done"


def _make_sink(dut) -> AxiStreamSink:
    # byte_size=16 => one RGB565 beat per AXIS cycle (not split into 8-bit lanes)
    return AxiStreamSink(
        AxiStreamBus.from_prefix(dut, "m_axis"),
        dut.axis_aclk,
        dut.rst_n,
        reset_active_level=False,
        byte_size=16,
    )


def _make_bfm(dut) -> Ov7670Bfm:
    return Ov7670Bfm(
        dut,
        width=IMG_W,
        height=IMG_H,
        pclk_period_ns=40.0,
        pclk=dut.ov7670_pclk,
        vsync=dut.ov7670_vsync,
        href=dut.ov7670_href,
        data=dut.ov7670_data,
        rst_n=None,
    )


def _assert_frame_lines(lines: list):
    assert len(lines) == IMG_H, f"got {len(lines)} lines, expected {IMG_H}"

    for y, frame in enumerate(lines):
        assert len(frame.tdata) == IMG_W, (
            f"line {y}: got {len(frame.tdata)} pixels, expected {IMG_W}"
        )
        for x, pix in enumerate(frame.tdata):
            expected = pixel_at(x, y)
            assert int(pix) == expected, (
                f"pixel({x},{y})=0x{int(pix):04x} expected 0x{expected:04x}"
            )

        # TUSER = SOF only on first pixel of first line
        tuser = frame.tuser
        if y == 0:
            if isinstance(tuser, list):
                assert int(tuser[0]) == 1, "first beat of frame must have TUSER/SOF"
                assert all(int(u) == 0 for u in tuser[1:]), "SOF only on first pixel"
            else:
                # compact() may collapse if somehow all equal — first line must not
                assert int(tuser) == 1 and IMG_W == 1
        else:
            if isinstance(tuser, list):
                assert all(int(u) == 0 for u in tuser), f"line {y}: unexpected SOF"
            else:
                assert int(tuser or 0) == 0, f"line {y}: unexpected SOF"


@cocotb.test()
async def test_cam_axis_stream_frame(dut):
    cocotb.start_soon(Clock(dut.cfg_clk, 100, unit="ns").start())
    cocotb.start_soon(Clock(dut.axis_aclk, 40, unit="ns").start())

    bfm = _make_bfm(dut)
    await bfm.start_clock()
    sink = _make_sink(dut)

    await _reset_dut(dut)
    assert int(dut.ov7670_pwdn.value) == 0
    assert int(dut.ov7670_reset_n.value) == 1

    await _run_config(dut)

    dut.stream_enable.value = 1
    await bfm.idle(8)
    await bfm.send_frame()

    lines = []
    for _ in range(IMG_H):
        lines.append(await sink.recv())

    # No extra trailing frames
    await Timer(200, unit="ns")
    assert sink.empty(), "unexpected extra AXIS frames after one image"

    _assert_frame_lines(lines)


@cocotb.test()
async def test_cam_axis_backpressure(dut):
    """Same path with AxiStreamSink pause generator exercising the FIFO."""
    cocotb.start_soon(Clock(dut.cfg_clk, 100, unit="ns").start())
    cocotb.start_soon(Clock(dut.axis_aclk, 40, unit="ns").start())

    bfm = _make_bfm(dut)
    await bfm.start_clock()
    sink = _make_sink(dut)
    sink.set_pause_generator(_pause_2_of_3())

    await _reset_dut(dut)
    await _run_config(dut)

    dut.stream_enable.value = 1
    await bfm.idle(8)
    await bfm.send_frame()

    lines = []
    for _ in range(IMG_H):
        lines.append(await sink.recv())

    sink.clear_pause_generator()
    await Timer(200, unit="ns")
    assert sink.empty(), "unexpected extra AXIS frames after backpressured image"

    _assert_frame_lines(lines)
