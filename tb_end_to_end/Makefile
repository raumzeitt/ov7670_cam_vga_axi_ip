SIM ?= icarus
TOPLEVEL_LANG = verilog

PWD := $(shell pwd)
CAM_RTL := $(PWD)/../cam_ip/rtl
VGA_RTL := $(PWD)/../vga_ip/rtl

SIM_BUILD := sim_build/cam_to_vga

VERILOG_SOURCES = \
	$(CAM_RTL)/ov7670_pkg.sv \
	$(CAM_RTL)/ov7670_cfg_rom.sv \
	$(CAM_RTL)/ov7670_cfg_sequencer.sv \
	$(CAM_RTL)/ov7670_sccb_master.sv \
	$(CAM_RTL)/ov7670_capture.sv \
	$(CAM_RTL)/axis_async_fifo.sv \
	$(CAM_RTL)/ov7670_cam_axis.sv \
	$(VGA_RTL)/vga_pkg.sv \
	$(VGA_RTL)/vga_timing.sv \
	$(VGA_RTL)/dp_ram.sv \
	$(VGA_RTL)/frame_buffer.sv \
	$(VGA_RTL)/axis_fb_writer.sv \
	$(VGA_RTL)/vga_axil_regs.sv \
	$(VGA_RTL)/vga_axis_fb.sv \
	$(PWD)/cam_to_vga_tb.sv

TOPLEVEL = cam_to_vga_tb
COCOTB_TEST_MODULES = test_cam_to_vga

COMPILE_ARGS += -g2012

unexport PYTHONHOME
export PYTHONPATH := $(PWD)$(if $(PYTHONPATH),:$(PYTHONPATH),)

include $(shell cocotb-config --makefiles)/Makefile.sim
