# VGA AXI IP

FPGA/ASIC-portable VGA display IP: accepts pixels over **AXI-Stream** and/or **AXI-Lite**,
stores them in a double-buffered frame memory, and drives a VGA timing interface.

Designed to connect to `ov7670_cam_axis` (or any AXIS RGB565 source) and also to
CPU/GPU masters via AXI-Lite.

## ASIC / portability rules

- Sync active-low `rst_n` only
- `axi_aclk` and `vga_clk` supplied externally (no PLL/MMCM inside)
- Frame store is plain inferred dual-port RAM (`dp_ram`) — swap that module for an
  SRAM macro in an ASIC flow; no vendor BRAM primitives
- No FPGA interconnect / MIG / Video IP cores

## Interfaces

| Port | Role |
|------|------|
| `s_axis_*` | RGB565 video in (`TUSER`=SOF, `TLAST`=EOL) |
| `s_axil_*` | Control/status + FB poke (`FB_ADDR` / `FB_DATA`) |
| `vga_*` | Active-low HSYNC/VSYNC + `RGB_BITS`-wide RGB (4 for Basys3) |

## AXI-Lite registers

| Offset | Name | Bits |
|--------|------|------|
| 0x00 | CTRL | [0] display_en, [1] axis_en, [2] swap_req (pulse), [3] status_clear |
| 0x04 | STATUS | [0] frame_ready, [1] underrun, [8] wr_bank, [9] rd_bank, [10] swap_pending |
| 0x08 | IMG_SIZE | `{height[15:0], width[15:0]}` (RO from params) |
| 0x0C | VERSION | `0x0001_0000` |
| 0x10 | FB_ADDR | pixel index for Lite poke |
| 0x14 | FB_DATA | write low 16 bits → store RGB565 at `FB_ADDR` |

After an AXIS frame completes, `frame_ready` asserts and a bank swap is requested;
the VGA domain commits the new bank at `frame_start` (tear-free).

## Defaults

- Timing: 640×480@60 (clock ~25 MHz from the board)
- Framebuffer: 320×240 RGB565 × 2 banks, centered in the active area
- Override `IMG_W`/`IMG_H`/timing params for sim or other modes

## RTL

| File | Role |
|------|------|
| `vga_pkg.sv` | Timing constants + register map |
| `vga_timing.sv` | H/V counters, sync, active |
| `dp_ram.sv` | Dual-clock dual-port RAM |
| `frame_buffer.sv` | Double-bank wrapper |
| `axis_fb_writer.sv` | AXIS → FB address generator |
| `vga_axil_regs.sv` | AXI-Lite subordinate |
| `vga_axis_fb.sv` | IP top |

## Tests

```bash
cd vga_ip/tb
./run_vga_timing.sh
./run_axis_to_vga.sh
```

Use the `./run_*.sh` scripts (same oss-cad-suite rules as `cam_ip`).
