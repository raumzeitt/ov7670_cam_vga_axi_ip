# Goal

Create a OV7670 IP that configures the camera and then streams the data via AXI.
This should run FPGA agnostic but will be tried first on Basys3 board.

## References
https://www.fpga4student.com/2018/08/basys-3-fpga-ov7670-camera.html

https://github.com/krzyslov/FPGA-Basys3-OV7670-ImageProcessing

## Implementation
In a previous attempt I created a cam to vga vivado project ("OLD_PROJECT_cam_to_vga_DOES_NOT_WORK")
Somehow the vga output had weird black horizontal lines every row of the image and also the image was drifting across the screen. 
I could never fix this.

We should use cocotb here with a python camera model to see if the camera receives, reacts to config changes and that we handle the image data correctly.

We should learn from the different implementations.
After this we will also write an axi_lite vga subordinate device to receive the image data to display it on the screen. This will then be another project.

## Pinout
see contraints file in top-level basys3.xdc

## Summary of design choices

- Default resolution: QVGA 320×240 RGB565 (COM7 with QVGA+RGB) for Basys3 BRAM; VGA optional via param/reg
- Host interface: AXI-Stream out now; AXI-Lite config when needed
- Language: SystemVerilog, sync resets preferred for ASIC (`rst_n`)
- XCLK: supplied by board/wrapper — not generated inside the IP
- Verification: Cocotb camera model before any bitstream

## RTL layout

| File | Role |
|------|------|
| `rtl/ov7670_pkg.sv` | Shared params / ROM sentinels |
| `rtl/ov7670_capture.sv` | pclk RGB565 capture + SOF/EOL |
| `rtl/ov7670_sccb_master.sv` | Open-drain SCCB write master |
| `rtl/ov7670_cfg_rom.sv` | QVGA RGB565 register program |
| `rtl/ov7670_cfg_sequencer.sv` | Walks ROM, drives SCCB |
| `rtl/axis_async_fifo.sv` | Shallow pclk→axis_aclk CDC FIFO |
| `rtl/ov7670_cam_axis.sv` | IP top (AXIS master out) |

## Run tests

```bash
cd cam_ip/tb
./run_capture.sh      # Phase 1: pixel capture
./run_sccb_cfg.sh     # Phase 2: SCCB config sequence
./run_cam_axis.sh     # Phase 3: full IP → AXI-Stream
```

Requires `iverilog`/`vvp` on `PATH` (e.g. oss-cad-suite).

**Do not run bare `make` inside an activated `.venv`** after sourcing oss-cad-suite —
that mixes `PYTHONHOME` and breaks cocotb (`No module named 'pygpi'`). Use the
`./run_*.sh` scripts instead; they pick the suite toolchain and unset a conflicting venv.

`test_sccb_cfg` checks:
- every ROM entry is written as SCCB `{0x42, reg, val}`
- first write is soft-reset (`0x12,0x80`)
- COM7 is QVGA+RGB (`0x12,0x14`)
- `done` asserts after the program completes

`test_cam_axis` checks (via **cocotbext-axi** `AxiStreamSink`):
- config completes, then a frame streams out on AXI-Stream
- `recv()` returns one line per `TLAST` (EOL)
- `TUSER` = SOF on first pixel of the frame
- pixel values match the BFM pattern
- backpressure via `set_pause_generator` still delivers a full correct frame
