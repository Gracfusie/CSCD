# Simple Icarus Verilog build & run
# Usage:
#   make            # build and run both sims, generate VCDs
#   make build      # only compile .vvp
#   make run        # run sims (assumes build done)
#   make clean

IVERILOG ?= iverilog
VVP      ?= vvp
IVFLAGS  ?= -g2012 -Wall

BUILD_DIR     := build
WAVE_DIR      := waveforms

PE_MUX_VVP    := $(BUILD_DIR)/pe_mux.vvp
PE_CORE_VVP   := $(BUILD_DIR)/pe_core.vvp

DESIGN_SRCS   := src/pe_mux.sv src/pe_core.sv src/pe_relu.sv

.PHONY: all build run clean dirs

all: build run

dirs:
	@mkdir -p $(BUILD_DIR) $(WAVE_DIR)

build: $(PE_MUX_VVP) $(PE_CORE_VVP)

$(PE_MUX_VVP): test/tb_pe_mux.sv src/pe_mux.sv | dirs
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(PE_CORE_VVP): test/tb_pe_core.sv $(DESIGN_SRCS) | dirs
	$(IVERILOG) $(IVFLAGS) -o $@ $^

run: | dirs
	$(VVP) $(PE_MUX_VVP)
	$(VVP) $(PE_CORE_VVP)

clean:
	@rm -rf $(BUILD_DIR) $(WAVE_DIR)