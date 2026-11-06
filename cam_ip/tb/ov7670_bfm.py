"""OV7670 camera bus functional model for cocotb."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


def rgb565(r5: int, g6: int, b5: int) -> int:
    return ((r5 & 0x1F) << 11) | ((g6 & 0x3F) << 5) | (b5 & 0x1F)


def pixel_at(x: int, y: int) -> int:
    """Deterministic RGB565 test pattern from (x, y)."""
    r = x & 0x1F
    g = y & 0x3F
    b = (x ^ y) & 0x1F
    return rgb565(r, g, b)


class Ov7670Bfm:
    """Drives pclk/vsync/href/data like an OV7670 in RGB565 mode."""

    def __init__(
        self,
        dut,
        *,
        width: int = 320,
        height: int = 240,
        pclk_period_ns: float = 40.0,
        pclk=None,
        vsync=None,
        href=None,
        data=None,
        rst_n=None,
    ):
        self.dut = dut
        self.width = width
        self.height = height
        self.pclk_period_ns = pclk_period_ns
        self.pclk = pclk if pclk is not None else dut.pclk
        self.vsync = vsync if vsync is not None else dut.vsync
        self.href = href if href is not None else dut.href
        self.data = data if data is not None else dut.data
        self.rst_n = rst_n if rst_n is not None else getattr(dut, "rst_n", None)

    async def reset(self, cycles: int = 5):
        self.vsync.value = 0
        self.href.value = 0
        self.data.value = 0
        if hasattr(self.dut, "enable"):
            self.dut.enable.value = 0
        if self.rst_n is not None:
            self.rst_n.value = 0
            for _ in range(cycles):
                await RisingEdge(self.pclk)
            self.rst_n.value = 1
            for _ in range(cycles):
                await RisingEdge(self.pclk)

    async def start_clock(self):
        cocotb.start_soon(Clock(self.pclk, self.pclk_period_ns, units="ns").start())

    async def idle(self, cycles: int = 4):
        self.vsync.value = 0
        self.href.value = 0
        self.data.value = 0
        for _ in range(cycles):
            await RisingEdge(self.pclk)

    async def send_frame(self):
        """Emit one frame: VSYNC high blank, then height lines of href+data."""
        self.vsync.value = 1
        self.href.value = 0
        self.data.value = 0
        for _ in range(8):
            await RisingEdge(self.pclk)

        self.vsync.value = 0
        for _ in range(2):
            await RisingEdge(self.pclk)

        for y in range(self.height):
            self.href.value = 0
            for _ in range(2):
                await RisingEdge(self.pclk)

            self.href.value = 1
            for x in range(self.width):
                pix = pixel_at(x, y)
                high = (pix >> 8) & 0xFF
                low = pix & 0xFF

                self.data.value = high
                await RisingEdge(self.pclk)
                self.data.value = low
                await RisingEdge(self.pclk)

            self.href.value = 0
            for _ in range(2):
                await RisingEdge(self.pclk)

        self.vsync.value = 1
        for _ in range(4):
            await RisingEdge(self.pclk)
