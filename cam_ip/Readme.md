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

- Language: SystemVerilog, sync resets preferred for ASIC (rst_n)

XCLK: Input to IP or pass-through; don’t hide an MMCM inside

- Verification: Cocotb camera model before any bitstream