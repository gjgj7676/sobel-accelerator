# Directories
IN_DIR  := images_in
PGM_DIR := build_pgm
OUT_DIR := images_out
SV_DIR  := build_sv

.PHONY: all sobel process tb test img_tb process_sv clean

# Default target
all: sobel process

# ---------------------------------------------------------------
# C++ testbench flow
# ---------------------------------------------------------------

# Build sobel executable
sobel:
	verilator --cc rtl/sobel.sv --exe sim/main.cpp --build

# Process all RGB images
process:
	mkdir -p "$(PGM_DIR)"
	mkdir -p "$(OUT_DIR)"
	@for file in "$(IN_DIR)"/*; do \
		if [ -f "$$file" ]; then \
			base=$$(basename "$$file"); \
			name=$${base%.*}; \
			safe_name=$$(echo "$$name" | tr ' ' '_'); \
			echo "Processing $$base"; \
			convert "$$file" -strip -depth 8 -compress none \
			    -define ppm:format=ascii "$(PGM_DIR)/$$safe_name.ppm"; \
			./obj_dir/Vsobel "$(PGM_DIR)/$$safe_name.ppm" \
			    "$(PGM_DIR)/$${safe_name}_out.pgm"; \
			convert "$(PGM_DIR)/$${safe_name}_out.pgm" \
			    "$(OUT_DIR)/$${safe_name}_sobel.png"; \
		fi; \
	done
	@echo "Done."


# Pure SystemVerilog testbench flow (needs Verilator 5 or newer)

VERILATOR_SV := verilator --binary --timing --timescale 1ns/1ps -Wno-fatal

# Self-checking regression: generated patterns vs a software Sobel model
tb:
	mkdir -p $(SV_DIR)
	$(VERILATOR_SV) --top-module sobel_tb \
	    rtl/sobel.sv tb/sobel_tb.sv -Mdir $(SV_DIR)/obj

test: tb
	./$(SV_DIR)/obj/Vsobel_tb

# Image pipeline testbench: RGB PPM in, Sobel, grayscale PGM out
img_tb:
	mkdir -p $(SV_DIR)
	$(VERILATOR_SV) --top-module sobel_image_tb \
	    rtl/sobel.sv tb/sobel_image_tb.sv -Mdir $(SV_DIR)/img


# RGB image -> P3 PPM -> SystemVerilog RGB simulation -> P2 PGM -> PNG
process_sv: img_tb
	mkdir -p "$(SV_DIR)"
	mkdir -p "$(OUT_DIR)"

	@for file in "$(IN_DIR)"/*; do \
		if [ -f "$$file" ]; then \
			base=$$(basename "$$file"); \
			name=$${base%.*}; \
			safe_name=$$(echo "$$name" | tr ' ' '_'); \
			echo "Processing RGB $$base"; \
			convert "$$file" -strip -depth 8 -compress none \
			    -define ppm:format=ascii "$(SV_DIR)/$$safe_name.ppm"; \
			./$(SV_DIR)/img/Vsobel_image_tb \
			    +in="$(SV_DIR)/$$safe_name.ppm" \
			    +out="$(SV_DIR)/$${safe_name}_out.pgm"; \
			convert "$(SV_DIR)/$${safe_name}_out.pgm" \
			    "$(OUT_DIR)/$${safe_name}_sobel_sv.png"; \
		fi; \
	done

	@echo "Done."

clean:
	rm -rf obj_dir
	rm -rf "$(PGM_DIR)"
	rm -rf "$(OUT_DIR)"
	rm -rf "$(SV_DIR)"
