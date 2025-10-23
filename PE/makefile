# ============================================================
# Icarus Verilog Makefile for PE accelerator project
# - SystemVerilog 2012
# - Per-TB build/run targets + grouped shortcuts
# ============================================================

# Tools
IVERILOG ?= iverilog
VVP      ?= vvp

# Flags
STD   ?= -g2012
WARN  ?= -Wall -Wno-timescale
DEFINES ?=
INCS ?=

# Build output
BUILD_DIR := build

# RTL + TB sources
RTL      := pe_relu.sv pe_dmux.sv pe_core.sv pe_top.sv
TB_PKG   := tb_pkg.sv
TB_UNITS := tb_pe_relu.sv tb_pe_dmux.sv
TB_CORE  := tb_pe_core.sv
TB_TOP   := tb_pe_top.sv

# Default goal: run the top-level memory-like testbench
.DEFAULT_GOAL := tb_pe_top

# ------------------------------------------------------------
# Pattern rule: compile a given TB (%.sv) into a .vvp image
# ------------------------------------------------------------
$(BUILD_DIR)/%.vvp: $(TB_PKG) $(RTL) %.sv
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) $(STD) $(WARN) $(DEFINES) $(INCS) -o $@ $^

# ------------------------------------------------------------
# Convenience run targets
# ------------------------------------------------------------
run-%: $(BUILD_DIR)/%.vvp
	$(VVP) $<

tb_pe_relu: run-tb_pe_relu
tb_pe_dmux: run-tb_pe_dmux
tb_pe_core: run-tb_pe_core
tb_pe_top:  run-tb_pe_top

# ------------------------------------------------------------
# Grouped shortcuts
# ------------------------------------------------------------
unit: tb_pe_relu tb_pe_dmux
core: tb_pe_core
top:  tb_pe_top
all:  unit core top

# Run everything in sequence
regress: all

# ------------------------------------------------------------
# Cleaning
# ------------------------------------------------------------
clean:
	@rm -rf $(BUILD_DIR) *.vcd *.fsdb

# ------------------------------------------------------------
# Help
# ------------------------------------------------------------
help:
	@echo "Targets:"
	@echo "  tb_pe_relu    - build & run ReLU unit TB"
	@echo "  tb_pe_dmux    - build & run DMUX unit TB"
	@echo "  tb_pe_core    - build & run PE core TB"
	@echo "  tb_pe_top     - build & run top-level (memory-like) TB [default]"
	@echo "  unit          - run unit TBs (relu, dmux)"
	@echo "  core          - run core TB"
	@echo "  top           - run top TB"
	@echo "  all           - run unit + core + top"
	@echo "  regress       - alias of 'all'"
	@echo "  clean         - remove build products"
	@echo ""
	@echo "Variables you can override:"
	@echo "  IVERILOG, VVP, STD, WARN, DEFINES, INCS"
	@echo "Examples:"
	@echo "  make               # runs tb_pe_top"
	@echo "  make all           # runs all TBs"
	@echo "  make tb_pe_core    # run only core TB"
	@echo "  make clean"

.PHONY: run-% tb_pe_relu tb_pe_dmux tb_pe_core tb_pe_top unit core top all regress clean help
