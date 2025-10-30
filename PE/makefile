# Simple Icarus Verilog build & run
# Usage:
#   make                 # build and run both sims, generate VCDs
#   make build           # only compile .vvp (all or TB=<name>)
#   make run             # run sims (all or TB=<name>)
#   make build-pe_mux    # only compile single testbench (shortcut)
#   make run-pe_mux      # only run single testbench (shortcut)
#   make list            # list available testbenches
#   make help            # show help
#   make clean

SHELL    := /bin/bash

IVERILOG ?= iverilog
VVP      ?= vvp
IVFLAGS  ?= -g2012 -Wall

BUILD_DIR := build
WAVE_DIR  := waveforms
LOG_DIR   := logs

# ---- Tests (explicit list to keep per-TB deps simple) ----
TESTS := pe_mux pe_core

# ---- Outputs ----
PE_MUX_VVP  := $(BUILD_DIR)/pe_mux.vvp
PE_CORE_VVP := $(BUILD_DIR)/pe_core.vvp

# ---- Sources ----
DESIGN_SRCS := src/pe_mux.sv src/pe_core.sv src/pe_relu.sv

# Per-testbench source groupings (kept as in your original)
SRCS_pe_mux  := test/tb_pe_mux.sv src/pe_mux.sv
SRCS_pe_core := test/tb_pe_core.sv $(DESIGN_SRCS)

.PHONY: all build run clean dirs help list run-% build-%

all: build run

dirs:
	@mkdir -p $(BUILD_DIR) $(WAVE_DIR) $(LOG_DIR)

# ---------- Build (all or single via TB=<name>) ----------
# Examples:
#   make build
#   make build TB=pe_mux
ifeq ($(strip $(TB)),)
build: $(PE_MUX_VVP) $(PE_CORE_VVP)
else
build: $(BUILD_DIR)/$(TB).vvp
endif

# Explicit .vvp rules with logging
$(PE_MUX_VVP): $(SRCS_pe_mux) | dirs
	@echo "Compiling pe_mux..." | tee $(LOG_DIR)/pe_mux_build.log
	@$(IVERILOG) $(IVFLAGS) -o $@ $^ 2>&1 | tee -a $(LOG_DIR)/pe_mux_build.log

$(PE_CORE_VVP): $(SRCS_pe_core) | dirs
	@echo "Compiling pe_core..." | tee $(LOG_DIR)/pe_core_build.log
	@$(IVERILOG) $(IVFLAGS) -o $@ $^ 2>&1 | tee -a $(LOG_DIR)/pe_core_build.log


# Shortcuts: build-<name>
build-%: | dirs
	@$(MAKE) $(BUILD_DIR)/$*.vvp

# ---------- Run (all or single via TB=<name>) ----------
# Examples:
#   make run
#   make run TB=pe_core
ifeq ($(strip $(TB)),)
run: $(addprefix run-,$(TESTS))
else
run: run-$(TB)
endif

# Generic runner with logging
run-%: $(BUILD_DIR)/%.vvp | dirs
	@echo "Running $*..." | tee $(LOG_DIR)/$*_run.log
	@$(VVP) $< 2>&1 | tee -a $(LOG_DIR)/$*_run.log

# ---------- Utilities ----------
list:
	@echo "Available testbenches:"; \
	for t in $(TESTS); do echo "  $$t"; done

help:
	@echo "Makefile Help"
	@echo
	@echo "Targets:"
	@echo "  make                 Build and run ALL testbenches"
	@echo "  make build           Compile ALL testbenches"
	@echo "  make run             Run ALL testbenches"
	@echo "  make build TB=<name> Compile a SINGLE testbench (e.g., TB=pe_mux)"
	@echo "  make run   TB=<name> Run a SINGLE testbench (e.g., TB=pe_core)"
	@echo "  make build-<name>    Shortcut to build a SINGLE testbench"
	@echo "  make run-<name>      Shortcut to run a SINGLE testbench"
	@echo "  make list            List available testbenches"
	@echo "  make clean           Remove build/, waveforms/, logs/"
	@echo
	@echo "Available testbenches:"
	@for t in $(TESTS); do echo "  $$t"; done
	@echo
	@echo "Logs:"
	@echo "  Compile logs: logs/<tb>_build.log"
	@echo "  Run logs:     logs/<tb>_run.log"

clean:
	@rm -rf $(BUILD_DIR) $(WAVE_DIR) $(LOG_DIR)
