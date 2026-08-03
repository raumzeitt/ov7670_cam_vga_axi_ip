"""Phase-1 test: ov7670_capture assembles RGB565 with SOF/EOL."""

import cocotb
from cocotb.triggers import RisingEdge

from ov7670_bfm import Ov7670Bfm, pixel_at


@cocotb.test()
async def test_capture_one_frame(dut):
    width = 32
    height = 24

    bfm = Ov7670Bfm(dut, width=width, height=height, pclk_period_ns=40.0)
    await bfm.start_clock()
    await bfm.reset()

    dut.enable.value = 1
    await RisingEdge(dut.pclk)

    expected_n = width * height
    pixels = []

    async def collect():
        while len(pixels) < expected_n:
            await RisingEdge(dut.pclk)
            if int(dut.pixel_valid.value):
                pixels.append(
                    (
                        int(dut.pixel.value),
                        int(dut.sof.value),
                        int(dut.eol.value),
                    )
                )

    collector = cocotb.start_soon(collect())
    await bfm.send_frame()

    for _ in range(20):
        await RisingEdge(dut.pclk)
        if len(pixels) >= expected_n:
            break

    await collector

    assert len(pixels) == expected_n, f"got {len(pixels)} pixels, expected {expected_n}"

    sof_count = sum(1 for _, sof, _ in pixels if sof)
    eol_count = sum(1 for _, _, eol in pixels if eol)
    assert sof_count == 1, f"SOF count={sof_count}"
    assert eol_count == height, f"EOL count={eol_count}"
    assert pixels[0][1] == 1, "first pixel must have SOF"

    for y in range(height):
        idx = (y + 1) * width - 1
        assert pixels[idx][2] == 1, f"missing EOL at line {y}"

    for i, (pix, _, _) in enumerate(pixels):
        x = i % width
        y = i // width
        expected = pixel_at(x, y)
        assert pix == expected, f"pixel({x},{y})=0x{pix:04x} expected 0x{expected:04x}"
