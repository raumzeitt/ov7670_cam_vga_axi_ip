"""Phase-2 test: config sequencer programs OV7670 over SCCB."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Timer

# Must match ov7670_cfg_rom.sv (excluding DELAY=0xFFF0 and END=0xFFFF)
EXPECTED_WRITES = [
    (0x12, 0x80),  # soft reset
    (0x12, 0x14),  # COM7 QVGA+RGB
    (0x11, 0x80),
    (0x0C, 0x00),
    (0x3E, 0x00),
    (0x04, 0x00),
    (0x40, 0xD0),
    (0x3A, 0x04),
    (0x14, 0x18),
    (0x4F, 0xB3),
    (0x50, 0xB3),
    (0x51, 0x00),
    (0x52, 0x3D),
    (0x53, 0xA7),
    (0x54, 0xE4),
    (0x58, 0x9E),
    (0x3D, 0xC0),
    (0x17, 0x14),
    (0x18, 0x02),
    (0x32, 0x80),
    (0x19, 0x03),
    (0x1A, 0x7B),
    (0x03, 0x0A),
    (0x0F, 0x41),
    (0x1E, 0x00),
    (0x33, 0x0B),
    (0x3C, 0x78),
    (0x69, 0x00),
    (0x74, 0x00),
    (0xB0, 0x84),
    (0xB1, 0x0C),
    (0xB2, 0x0E),
    (0xB3, 0x80),
    (0x70, 0x3A),
    (0x71, 0x35),
    (0x72, 0x11),
    (0x73, 0xF0),
    (0xA2, 0x02),
    (0x7A, 0x20),
    (0x7B, 0x10),
    (0x7C, 0x1E),
    (0x7D, 0x35),
    (0x7E, 0x5A),
    (0x7F, 0x69),
    (0x80, 0x76),
    (0x81, 0x80),
    (0x82, 0x88),
    (0x83, 0x8F),
    (0x84, 0x96),
    (0x85, 0xA3),
    (0x86, 0xAF),
    (0x87, 0xC4),
    (0x88, 0xD7),
    (0x89, 0xE8),
    (0x13, 0xE0),
    (0x00, 0x00),
    (0x10, 0x00),
    (0x0D, 0x40),
    (0x14, 0x18),
    (0xA5, 0x05),
    (0xAB, 0x07),
    (0x24, 0x95),
    (0x25, 0x33),
    (0x26, 0xE3),
    (0x9F, 0x78),
    (0xA0, 0x68),
    (0xA1, 0x03),
    (0xA6, 0xD8),
    (0xA7, 0xD8),
    (0xA8, 0xF0),
    (0xA9, 0x90),
    (0xAA, 0x94),
    (0x13, 0xE5),
]

SCCB_ID = 0x42


async def _read_byte(dut) -> int:
    """Sample 8 data bits + 1 ACK slot on rising SIOC."""
    value = 0
    for _ in range(8):
        await RisingEdge(dut.sioc)
        bit = int(dut.siod.value)
        value = ((value << 1) | bit) & 0xFF
    await RisingEdge(dut.sioc)  # ACK / don't-care
    return value


async def _monitor_sccb(dut, sink: list, stop_event: dict):
    """Decode SCCB write transactions: START + 3 bytes + STOP."""
    while not stop_event.get("stop"):
        # START: SIOD falling while SIOC high
        await FallingEdge(dut.siod)
        if stop_event.get("stop"):
            break
        if int(dut.sioc.value) != 1:
            continue

        try:
            slave_id = await _read_byte(dut)
            reg = await _read_byte(dut)
            val = await _read_byte(dut)
        except Exception:
            break

        sink.append((slave_id, reg, val))


@cocotb.test()
async def test_sccb_config_sequence(dut):
    # Fast cfg clock: 10 kHz claimed CLK_HZ in RTL → 100 us period is fine;
    # use 1 us period for quicker wall time.
    cocotb.start_soon(Clock(dut.clk, 1.0, unit="us").start())

    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    # Let synchronous ROM settle at addr 0
    for _ in range(4):
        await RisingEdge(dut.clk)

    writes: list[tuple[int, int, int]] = []
    stop_event = {"stop": False}
    monitor = cocotb.start_soon(_monitor_sccb(dut, writes, stop_event))

    # Pulse start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done (with timeout)
    timeout_us = 500_000  # generous
    elapsed = 0
    while int(dut.done.value) == 0:
        await RisingEdge(dut.clk)
        elapsed += 1
        assert elapsed < timeout_us, (
            f"timeout waiting for cfg done; got {len(writes)} SCCB writes so far"
        )

    # A few extra clocks for the last STOP / monitor catch-up
    for _ in range(50):
        await RisingEdge(dut.clk)

    stop_event["stop"] = True
    # Nudge SIOD so the monitor can exit if blocked on FallingEdge
    await Timer(10, unit="us")
    monitor.cancel()

    assert len(writes) == len(EXPECTED_WRITES), (
        f"write count {len(writes)} != expected {len(EXPECTED_WRITES)}"
    )

    for i, ((sid, reg, val), (ereg, eval_)) in enumerate(zip(writes, EXPECTED_WRITES)):
        assert sid == SCCB_ID, f"txn[{i}]: slave id 0x{sid:02x} != 0x{SCCB_ID:02x}"
        assert reg == ereg, f"txn[{i}]: reg 0x{reg:02x} != 0x{ereg:02x}"
        assert val == eval_, f"txn[{i}]: val 0x{val:02x} != 0x{eval_:02x}"

    # Key programming checks called out in the design notes
    assert writes[0] == (SCCB_ID, 0x12, 0x80), "first write must be soft-reset"
    assert writes[1] == (SCCB_ID, 0x12, 0x14), "COM7 must be QVGA+RGB (0x14)"
    assert any(r == 0x40 and v == 0xD0 for _, r, v in writes), "COM15 RGB565 missing"
    assert writes[-1] == (SCCB_ID, 0x13, 0xE5), "last write should re-enable AGC/AEC"
