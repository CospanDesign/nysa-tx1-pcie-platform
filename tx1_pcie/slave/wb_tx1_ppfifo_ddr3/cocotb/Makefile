
TOPLEVEL_LANG ?= verilog
PWD=$(shell pwd)
TOPDIR=$(PWD)/..
COCOTB 	:= $(shell $(python) nysa paths -c -s)
XILINX := $(shell $(python) nysa paths -x -s)
NYSA 	:= $(shell $(python) nysa paths -s -v nysa-verilog)
PYTHONPATH := ./model:$(PYTHONPATH)
export PYTHONPATH
export PYTHONHOME=$(shell python -c "from distutils.sysconfig import get_config_var; print(get_config_var('prefix'))")

EXTRA_ARGS+=-I$(TOPDIR)/rtl/ -I$(NYSA)/verilog/ -I$(NYSA)/verilog/wishbone/slave/wb_dma/rtl/

#Dependencies
VERILOG_SOURCES = $(NYSA)/verilog/wishbone/master/wishbone_master.v

VERILOG_SOURCES += $(NYSA)/verilog/wishbone/slave/wb_dma/rtl/wb_dma.v
VERILOG_SOURCES += $(NYSA)/verilog/wishbone/slave/wb_dma/rtl/dma.v
VERILOG_SOURCES += $(NYSA)/verilog/wishbone/slave/wb_dma/rtl/dma_prog_rom.v

VERILOG_SOURCES += $(NYSA)/verilog/wishbone/slave/wb_test_dma_mem/rtl/wb_test_dma_mem.v
VERILOG_SOURCES += $(NYSA)/verilog/wishbone/slave/wb_test_dma_mem/rtl/test_mem_dev.v

VERILOG_SOURCES += ${NYSA}/verilog/generic/bram.v
VERILOG_SOURCES += ${NYSA}/verilog/wishbone/slave/wb_bram/rtl/wb_bram.v
VERILOG_SOURCES += $(NYSA)/verilog/sim/wishbone/interconnect/example_2port_interconnect/wishbone_interconnect.v
VERILOG_SOURCES += ${TOPDIR}/sim/arbiter_2_masters.v
VERILOG_SOURCES += ${TOPDIR}/sim/wishbone_mem_interconnect.v

VERILOG_SOURCES += ${NYSA}/verilog/generic/ppfifo.v
VERILOG_SOURCES += ${NYSA}/verilog/generic/cross_clock_enable.v
VERILOG_SOURCES += ${NYSA}/verilog/generic/blk_mem.v
VERILOG_SOURCES += ${NYSA}/verilog/generic/dpb.v

VERILOG_SOURCES += ${XILINX}/ISE/verilog/src/glbl.v
VERILOG_SOURCES += ${XILINX}/ISE/verilog/src/unisims/BUFG.v
VERILOG_SOURCES += ${XILINX}/ISE/verilog/src/unisims/MMCME2_ADV.v
VERILOG_SOURCES += ${TOPDIR}/rtl/ddr3_pll.v
VERILOG_SOURCES += ${TOPDIR}/sim/sim_tx1_ddr3_if.v
VERILOG_SOURCES += ${TOPDIR}/rtl/ddr3_app_if.v
VERILOG_SOURCES += ${TOPDIR}/rtl/ddr3_ppfifo_controller.v


#Simulation Devices
VERILOG_SOURCES += ${TOPDIR}/rtl/wb_tx1_ppfifo_ddr3.v
#DUT
#Test Benches
VERILOG_SOURCES += $(TOPDIR)/cocotb/tb_cocotb.v

TOPLEVEL = tb_cocotb

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=test_dut

include $(COCOTB)/makefiles/Makefile.inc
include $(COCOTB)/makefiles/Makefile.sim

.PHONY: wave test
wave:
	gtkwave waveforms.gtkw &


