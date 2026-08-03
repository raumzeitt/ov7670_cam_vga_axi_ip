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

Simulation of both IPs and the end-to-end path is done. Basys3 integration:

| Item | Status |
|------|--------|
| Board top (`vivado/fpga/basys3_top.sv`) | Cam → AXIS → VGA, 25 MHz clocks from 100 MHz |
| Bring-up FSM (`basys3_ctrl.sv`) | SCCB config then `stream_enable` |
| Constraints | `constraints/basys3.xdc` (Pmod JB/JC + VGA) |
| Vivado project | `vivado/viv_ov7670_basys3/` |
| BRAM | **Single bank** QVGA (`N_BANKS=1`) — fits XC7A35T; tearing possible |

### Build and program

```bash
cd vivado/viv_ov7670_basys3
vivado viv_ov7670_basys3.xpr
# Run Synthesis → Implementation → Generate Bitstream
```

### Bring-up

1. Connect OV7670 to Pmods **JB** + **JC** (see `constraints/basys3.xdc`).
2. VGA monitor on the board connector.
3. **SW0 up** (V16) to run; down holds reset.
4. **LEDs:** `[0]` reset ok, `[1]` SCCB done, `[2]` streaming, `[3]` running, `[4]` config timeout.
5. **JA (`dbg_gpio`):** cfg_done, stream_enable, axis valid/ready.

First image may take ~1 s (SCCB program). Single-bank FB may show tearing during live capture.

## References

- https://www.fpga4student.com/2018/08/basys-3-fpga-ov7670-camera.html
- https://github.com/krzyslov/FPGA-Basys3-OV7670-ImageProcessing
