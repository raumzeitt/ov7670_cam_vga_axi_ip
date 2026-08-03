SIM ?= icarus
TOPLEVEL_LANG = verilog
TEST ?= vga_timing

PWD := $(shell pwd)
RTL := $(PWD)/../rtl

SIM_BUILD := sim_build/$(TEST)

ifeq ($(TEST),vga_timing)
  VERILOG_SOURCES = \
	$(RTL)/vga_timing.sv \
	$(PWD)/vga_timing_tb.sv
  TOPLEVEL = vga_timing_tb
  COCOTB_TEST_MODULES = test_vga_timing
else ifeq ($(TEST),axis_to_vga)
  VERILOG_SOURCES = \
	$(RTL)/vga_pkg.sv \
	$(RTL)/vga_timing.sv \
	$(RTL)/dp_ram.sv \
	$(RTL)/frame_buffer.sv \
	$(RTL)/axis_fb_writer.sv \
	$(RTL)/vga_axil_regs.sv \
	$(RTL)/vga_axis_fb.sv \
	$(PWD)/vga_axis_fb_tb.sv
  TOPLEVEL = vga_axis_fb_tb
  COCOTB_TEST_MODULES = test_axis_to_vga
else
  $(error Unknown TEST='$(TEST)'. Use TEST=vga_timing or axis_to_vga)
endif

COMPILE_ARGS += -g2012

unexport PYTHONHOME
export PYTHONPATH := $(PWD)$(if $(PYTHONPATH),:$(PYTHONPATH),)

include $(shell cocotb-config --makefiles)/Makefile.sim
