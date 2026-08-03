# End-to-end: camera IP → VGA IP

Connects `ov7670_cam_axis` to `vga_axis_fb` over AXI-Stream and checks that a
BFM camera frame appears on the VGA RGB outputs.

```bash
./run_cam_to_vga.sh
```

Same oss-cad-suite rules as `cam_ip` / `vga_ip` — use the run script, not bare
`make` inside an activated `.venv`.
