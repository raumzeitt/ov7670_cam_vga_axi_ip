# OV7670 camera + AXI VGA (Basys3 / ASIC-portable)

Portable SystemVerilog IPs that configure an OV7670, stream RGB565 over **AXI-Stream**,
and display frames via an **AXI-Lite / AXIS** VGA subordinate. Verified with **cocotb**
before any bitstream. First board target: Digilent **Basys3**.

```text
OV7670 ──► ov7670_cam_axis ──AXI-Stream──► vga_axis_fb ──► VGA monitor
              (SCCB cfg)                    (FB + timing)
                                            ▲
                                     AXI-Lite (CPU / GPU)
```

## Layout

| Path | Role |
|------|------|
| [`cam_ip/`](cam_ip/) | Camera IP: SCCB config, capture, AXIS master |
| [`vga_ip/`](vga_ip/) | VGA IP: AXIS + AXI-Lite → double-buffer FB → VGA |
| [`tb_end_to_end/`](tb_end_to_end/) | Cam BFM → cam IP → VGA IP cocotb test |
| [`constraints/basys3.xdc`](constraints/basys3.xdc) | Basys3 pinout / clocks |
| [`vivado/`](vivado/) | Board project / bitstream (TODO) |
| `ref/` | Old / reference designs (gitignored) |

## Design rules

- Sync active-low `rst_n`
- Clocks supplied **outside** the IPs (no PLL/MMCM inside `cam_ip` / `vga_ip`)
- No vendor BRAM / Video / interconnect IP — inferred dual-port RAM (swap for SRAM on ASIC)
- Default image: **QVGA 320×240 RGB565** (`TUSER`=SOF, `TLAST`=EOL)
- VGA: 640×480@60, active-low sync, image centered; `RGB_BITS=4` for Basys3

## Run simulations

Requires `iverilog` / `vvp` and cocotb (e.g. [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build)).

**Use the `./run_*.sh` scripts**, not bare `make` inside an activated `.venv` after
sourcing oss-cad-suite — that mixes `PYTHONHOME` and breaks cocotb.

```bash
# Camera IP
cd cam_ip/tb && ./run_capture.sh && ./run_sccb_cfg.sh && ./run_cam_axis.sh

# VGA IP
cd vga_ip/tb && ./run_vga_timing.sh && ./run_axis_to_vga.sh

# End-to-end
cd tb_end_to_end && ./run_cam_to_vga.sh
```

## Interfaces (summary)

**Camera (`ov7670_cam_axis`)** — AXIS master out; `cfg_start` / `cfg_done` / `stream_enable`;
OV7670 pads. `xclk` from the board wrapper.

**VGA (`vga_axis_fb`)** — AXIS slave + AXI-Lite (CTRL/STATUS + FB poke) → VGA pins.
See [`vga_ip/Readme.md`](vga_ip/Readme.md) for the register map.

## Hardware status

Simulation of both IPs and the end-to-end path is done. Still needed for Basys3:

1. Board top: clocks (100 MHz → ~25 MHz `vga_clk` / `xclk`), wire cam→VGA, match XDC names
2. **BRAM fit** — 2×QVGA RGB565 ≈ 2.46 Mbit; XC7A35T has ~1.8 Mbit → use **one bank**
   (or a smaller frame) for first bring-up
3. Vivado project under `vivado/`, program, bring-up with status LEDs

## References

- https://www.fpga4student.com/2018/08/basys-3-fpga-ov7670-camera.html
- https://github.com/krzyslov/FPGA-Basys3-OV7670-ImageProcessing
