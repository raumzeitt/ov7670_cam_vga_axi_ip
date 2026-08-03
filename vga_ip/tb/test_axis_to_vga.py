"""Phase 2: AXIS (+ optional AXI-Lite) into vga_axis_fb, check VGA pixels."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import (
    AxiLiteBus,
    AxiLiteMaster,
    AxiStreamBus,
    AxiStreamFrame,
    AxiStreamSource,
)

IMG_W = 8
IMG_H = 4
H_TOTAL = 32 + 2 + 4 + 2  # 40
V_TOTAL = 16 + 1 + 2 + 1  # 20

REG_CTRL = 0x00
REG_STATUS = 0x04
REG_IMG_SIZE = 0x08
REG_FB_ADDR = 0x10
REG_FB_DATA = 0x14

CTRL_DISPLAY = 1 << 0
CTRL_AXIS = 1 << 1
CTRL_SWAP = 1 << 2


def pixel_at(x: int, y: int) -> int:
    """Deterministic RGB565 pattern."""
    return ((x & 0x1F) << 11) | ((y & 0x3F) << 5) | ((x + y) & 0x1F)


def rgb565_to_4b(pix: int) -> tuple[int, int, int]:
    r = (pix >> 12) & 0xF  # [15-:4] = [15:12]
    g = (pix >> 7) & 0xF   # [10-:4] = [10:7]
    b = (pix >> 1) & 0xF   # [4-:4] = [4:1]
    return r, g, b


def _as_bytes(resp) -> bytes:
    data = resp.data if hasattr(resp, "data") else resp
    return bytes(data)


def _u32(resp) -> int:
    return int.from_bytes(_as_bytes(resp), "little")


async def _axil_write_u32(axil: AxiLiteMaster, addr: int, val: int):
    await axil.write(addr, int(val).to_bytes(4, "little"))


async def _axil_read_u32(axil: AxiLiteMaster, addr: int) -> int:
    return _u32(await axil.read(addr, 4))


async def _reset(dut):
    dut.rst_n.value = 0
    for _ in range(10):
        await RisingEdge(dut.axi_aclk)
    dut.rst_n.value = 1
    for _ in range(5):
        await RisingEdge(dut.axi_aclk)


def _make_axil(dut) -> AxiLiteMaster:
    return AxiLiteMaster(
        AxiLiteBus.from_prefix(dut, "s_axil"),
        dut.axi_aclk,
        dut.rst_n,
        reset_active_level=False,
    )


def _make_axis(dut) -> AxiStreamSource:
    return AxiStreamSource(
        AxiStreamBus.from_prefix(dut, "s_axis"),
        dut.axi_aclk,
        dut.rst_n,
        reset_active_level=False,
        byte_size=16,
    )


async def _send_frame(source: AxiStreamSource):
    for y in range(IMG_H):
        data = [pixel_at(x, y) for x in range(IMG_W)]
        tuser = [1] + [0] * (IMG_W - 1) if y == 0 else [0] * IMG_W
        await source.send(AxiStreamFrame(tdata=data, tuser=tuser))


async def _wait_frame_ready(dut, axil: AxiLiteMaster, timeout=10_000):
    for _ in range(timeout):
        st = await _axil_read_u32(axil, REG_STATUS)
        if st & 1:
            return st
        await RisingEdge(dut.axi_aclk)
    raise AssertionError("timeout waiting for frame_ready")


async def _sample_window_pixel(dut, img_x: int, img_y: int) -> tuple[int, int, int]:
    """Wait until VGA outputs the RGB4 expansion of framebuffer (img_x, img_y)."""
    expect_r, expect_g, expect_b = rgb565_to_4b(pixel_at(img_x, img_y))

    for _ in range(H_TOTAL * V_TOTAL * 3):
        await RisingEdge(dut.vga_clk)
        if (
            int(dut.vga_r.value) == expect_r
            and int(dut.vga_g.value) == expect_g
            and int(dut.vga_b.value) == expect_b
        ):
            return expect_r, expect_g, expect_b

    raise AssertionError(
        f"never saw pixel ({img_x},{img_y}) = RGB565 0x{pixel_at(img_x, img_y):04x} "
        f"as RGB4 ({expect_r},{expect_g},{expect_b})"
    )


@cocotb.test()
async def test_axis_frame_to_vga(dut):
    cocotb.start_soon(Clock(dut.axi_aclk, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.vga_clk, 40, unit="ns").start())

    axil = _make_axil(dut)
    axis = _make_axis(dut)

    await _reset(dut)

    size = await _axil_read_u32(axil, REG_IMG_SIZE)
    assert (size & 0xFFFF) == IMG_W
    assert ((size >> 16) & 0xFFFF) == IMG_H

    await _axil_write_u32(axil, REG_CTRL, CTRL_DISPLAY | CTRL_AXIS)

    await _send_frame(axis)
    await _wait_frame_ready(dut, axil)

    # Allow bank swap to commit on a VGA frame boundary
    for _ in range(H_TOTAL * V_TOTAL * 2):
        await RisingEdge(dut.vga_clk)

    for x, y in [(0, 0), (3, 1), (7, 3)]:
        await _sample_window_pixel(dut, x, y)


@cocotb.test()
async def test_axil_poke_to_vga(dut):
    """CPU-style path: write FB via Lite, force swap, check VGA."""
    cocotb.start_soon(Clock(dut.axi_aclk, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.vga_clk, 40, unit="ns").start())

    axil = _make_axil(dut)
    await _reset(dut)

    await _axil_write_u32(axil, REG_CTRL, CTRL_DISPLAY)

    for y in range(IMG_H):
        for x in range(IMG_W):
            idx = y * IMG_W + x
            await _axil_write_u32(axil, REG_FB_ADDR, idx)
            await _axil_write_u32(axil, REG_FB_DATA, pixel_at(x, y))

    await _axil_write_u32(axil, REG_CTRL, CTRL_DISPLAY | CTRL_SWAP)

    for _ in range(H_TOTAL * V_TOTAL * 2):
        await RisingEdge(dut.vga_clk)

    await _sample_window_pixel(dut, 1, 2)
    await _sample_window_pixel(dut, 5, 0)
