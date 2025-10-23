# ============================================================
# Icarus Verilog Makefile for PE accelerator project
# - SystemVerilog 2012
# - Per-TB build/run targets + grouped shortcuts
# ============================================================

# Tools
IVERILOG ?= iverilog
VVP      ?= vvp

# Flags
STD     ?= -g2012
WARN    ?= -Wall -Wno-timescale
DEFINES ?=
# Add both src/ and test/ so `include` and file refs work
INCS    ?= -I src -I test

# Build output
BUILD_DIR := build

# RTL + TB sources
RTL      := src/pe_relu.sv src/pe_dmux.sv src/pe_core.sv src/pe_top.sv
TB_PKG   := test/tb_pkg.sv
TB_UNITS := test/tb_pe_relu.sv test/tb_pe_dmux.sv
TB_CORE  := test/tb_pe_core.sv
TB_TOP   := test/tb_pe_top.sv

# List of TB names (without path/suffix)
TB_NAMES := tb_pe_relu tb_pe_dmux tb_pe_core tb_pe_top

# Default goal: run the top-level memory-like testbench
.DEFAULT_GOAL := tb_pe_top

# ------------------------------------------------------------
# Pattern rule: compile a given TB (test/%.sv) into build/%.vvp
# - $* is the stem (e.g., tb_pe_relu), use it as the top module
# ------------------------------------------------------------
$(BUILD_DIR)/%.vvp: $(TB_PKG) $(RTL) test/%.sv
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) $(STD) $(WARN) $(DEFINES) $(INCS) -s $* -o $@ $^

# ------------------------------------------------------------
# Convenience run targets
#   e.g. `make run-tb_pe_relu`
# ------------------------------------------------------------
run-%: $(BUILD_DIR)/%.vvp
	$(VVP) $<

# Friendly aliases without 'run-'
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
	@echo "  make run-tb_pe_relu"
	@echo "  make all"
	@echo "  make clean"

.PHONY: run-% tb_pe_relu tb_pe_dmux tb_pe_core tb_pe_top unit core top all regress clean help
