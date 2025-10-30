# Simple Icarus Verilog build & run (per-testbench friendly)
# Usage:
#   make                # build and run all testbenches
#   make build          # build all .vvp
#   make run            # run all (assumes build done)
#   make clean
#
# Per-testbench:
#   make pe_mux         # build & run tb_pe_mux.sv
#   make pe_core        # build & run tb_pe_core.sv
#   make build-pe_mux   # only build
#   make run-pe_mux     # only run

IVERILOG ?= iverilog
VVP      ?= vvp
IVFLAGS  ?= -g2012 -Wall

SRC_DIR   := src
TB_DIR    := test
BUILD_DIR := build
WAVE_DIR  := waveforms

# Stems must match tb_<stem>.sv in $(TB_DIR)
TESTS       := pe_mux pe_core
VVP_FILES   := $(TESTS:%=$(BUILD_DIR)/%.vvp)

DESIGN_SRCS := $(SRC_DIR)/pe_mux.sv $(SRC_DIR)/pe_core.sv $(SRC_DIR)/pe_relu.sv

.PHONY: all build run clean dirs help FORCE \
        $(TESTS) $(TESTS:%=build-%) $(TESTS:%=run-%)

all: build run

help:
	@echo "Targets:"
	@echo "  make / make all     - build and run all testbenches"
	@echo "  make build          - build all .vvp"
	@echo "  make run            - run all (assumes build done)"
	@echo "  make clean          - remove build and waveform directories"
	@echo ""
	@echo "Per-testbench:"
	@echo "  make <name>         - build & run tb_<name>.sv"
	@echo "  make build-<name>   - only build <name>"
	@echo "  make run-<name>     - only run <name>"
	@echo ""
	@echo "Defined testbenches: $(TESTS)"

dirs:
	@mkdir -p $(BUILD_DIR) $(WAVE_DIR)

# Build all
build: $(VVP_FILES)

# Run all (chains through run-<name> targets)
run: $(TESTS:%=run-%)

# Compile a single testbench
$(BUILD_DIR)/%.vvp: $(TB_DIR)/tb_%.sv $(DESIGN_SRCS) | dirs
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# Always run, even if the .vvp timestamp hasn't changed
FORCE:

run-%: $(BUILD_DIR)/%.vvp FORCE | dirs
	$(VVP) $<

build-%: $(BUILD_DIR)/%.vvp

# IMPORTANT: Make these aliases real recipes so 'make pe_mux' never says "Nothing to be done"
$(TESTS): %:
	@$(MAKE) run-$@
	
clean:
	@rm -rf $(BUILD_DIR) $(WAVE_DIR)
