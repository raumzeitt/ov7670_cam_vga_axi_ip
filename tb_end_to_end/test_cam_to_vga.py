"""End-to-end: OV7670 BFM → cam AXIS IP → VGA FB IP → RGB/sync out."""

from __future__ import annotations

import sys
from pathlib import Path

# Reuse camera BFM from cam_ip/tb
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "cam_ip" / "tb"))

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from ov7670_bfm import Ov7670Bfm, pixel_at

IMG_W = 8
IMG_H = 4
H_TOTAL = 40
V_TOTAL = 20

REG_CTRL = 0x00
REG_STATUS = 0x04
CTRL_DISPLAY = 1 << 0
CTRL_AXIS = 1 << 1


def rgb565_to_4b(pix: int) -> tuple[int, int, int]:
    r = (pix >> 12) & 0xF
    g = (pix >> 7) & 0xF
    b = (pix >> 1) & 0xF
    return r, g, b


def _u32(resp) -> int:
    data = resp.data if hasattr(resp, "data") else resp
    return int.from_bytes(bytes(data), "little")


async def _axil_write_u32(axil: AxiLiteMaster, addr: int, val: int):
    await axil.write(addr, int(val).to_bytes(4, "little"))


async def _axil_read_u32(axil: AxiLiteMaster, addr: int) -> int:
    return _u32(await axil.read(addr, 4))


async def _reset(dut):
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


async def _wait_frame_ready(dut, axil: AxiLiteMaster, timeout=50_000):
    for _ in range(timeout):
        if await _axil_read_u32(axil, REG_STATUS) & 1:
            return
        await RisingEdge(dut.axi_aclk)
    raise AssertionError("timeout waiting for VGA frame_ready")


async def _expect_vga_pixel(dut, x: int, y: int):
    expect_r, expect_g, expect_b = rgb565_to_4b(pixel_at(x, y))
    for _ in range(H_TOTAL * V_TOTAL * 4):
        await RisingEdge(dut.vga_clk)
        if (
            int(dut.vga_r.value) == expect_r
            and int(dut.vga_g.value) == expect_g
            and int(dut.vga_b.value) == expect_b
        ):
            return
    raise AssertionError(
        f"VGA never showed pixel({x},{y})=0x{pixel_at(x, y):04x} "
        f"as RGB4({expect_r},{expect_g},{expect_b})"
    )


@cocotb.test()
async def test_cam_to_vga_e2e(dut):
    """Configure camera, stream one BFM frame, display on VGA."""
    cocotb.start_soon(Clock(dut.cfg_clk, 100, unit="ns").start())    # 10 MHz
    cocotb.start_soon(Clock(dut.axi_aclk, 40, unit="ns").start())    # 25 MHz
    cocotb.start_soon(Clock(dut.vga_clk, 40, unit="ns").start())     # 25 MHz

    bfm = Ov7670Bfm(
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
    await bfm.start_clock()

    axil = AxiLiteMaster(
        AxiLiteBus.from_prefix(dut, "s_axil"),
        dut.axi_aclk,
        dut.rst_n,
        reset_active_level=False,
    )

    await _reset(dut)
    await _run_config(dut)

    # Enable VGA capture + display before the camera streams
    await _axil_write_u32(axil, REG_CTRL, CTRL_DISPLAY | CTRL_AXIS)

    dut.stream_enable.value = 1
    await bfm.idle(8)
    await bfm.send_frame()

    await _wait_frame_ready(dut, axil)

    # Wait for bank swap to commit
    for _ in range(H_TOTAL * V_TOTAL * 2):
        await RisingEdge(dut.vga_clk)

    for x, y in [(0, 0), (3, 1), (7, 3)]:
        await _expect_vga_pixel(dut, x, y)
