SIM ?= icarus
TOPLEVEL_LANG = verilog
TEST ?= capture

PWD := $(shell pwd)
RTL := $(PWD)/../rtl

# Separate build dir per TEST so switching capture ↔ cam_axis never reuses a stale .vvp
SIM_BUILD := sim_build/$(TEST)

ifeq ($(TEST),capture)
  VERILOG_SOURCES = \
	$(RTL)/ov7670_capture.sv \
	$(PWD)/ov7670_capture_tb.sv
  TOPLEVEL = ov7670_capture_tb
  COCOTB_TEST_MODULES = test_capture
else ifeq ($(TEST),sccb_cfg)
  VERILOG_SOURCES = \
	$(RTL)/ov7670_pkg.sv \
	$(RTL)/ov7670_cfg_rom.sv \
	$(RTL)/ov7670_cfg_sequencer.sv \
	$(RTL)/ov7670_sccb_master.sv \
	$(PWD)/ov7670_sccb_cfg_tb.sv
  TOPLEVEL = ov7670_sccb_cfg_tb
  COCOTB_TEST_MODULES = test_sccb_cfg
else ifeq ($(TEST),cam_axis)
  VERILOG_SOURCES = \
	$(RTL)/ov7670_pkg.sv \
	$(RTL)/ov7670_cfg_rom.sv \
	$(RTL)/ov7670_cfg_sequencer.sv \
	$(RTL)/ov7670_sccb_master.sv \
	$(RTL)/ov7670_capture.sv \
	$(RTL)/axis_async_fifo.sv \
	$(RTL)/ov7670_cam_axis.sv \
	$(PWD)/ov7670_cam_axis_tb.sv
  TOPLEVEL = ov7670_cam_axis_tb
  COCOTB_TEST_MODULES = test_cam_axis
else
  $(error Unknown TEST='$(TEST)'. Use TEST=capture, sccb_cfg, or cam_axis)
endif

COMPILE_ARGS += -g2012

# Never inherit oss-cad-suite PYTHONHOME into a venv interpreter
unexport PYTHONHOME
export PYTHONPATH := $(PWD)$(if $(PYTHONPATH),:$(PYTHONPATH),)

include $(shell cocotb-config --makefiles)/Makefile.sim
