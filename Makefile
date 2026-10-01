# Directories
IN_DIR  := images_in
PGM_DIR := build_pgm
OUT_DIR := images_out
SV_DIR := build_sv

.PHONY: all sobel process tb test clean

# Default target
all: sobel process

# Build sobel executable
sobel:
	verilator --cc rtl/sobel.sv --exe sim/main.cpp --build

# Process all images
process:
	mkdir -p "$(PGM_DIR)"
	mkdir -p "$(OUT_DIR)"
	@for file in "$(IN_DIR)"/*; do \
		if [ -f "$$file" ]; then \
			base=$$(basename "$$file"); \
			name=$${base%.*}; \
			safe_name=$$(echo "$$name" | tr ' ' '_'); \
			echo "Processing $$base"; \
			convert "$$file" -colorspace Gray -depth 8 -compress none \
			    -define pgm:format=ascii "$(PGM_DIR)/$$safe_name.pgm"; \
			./obj_dir/Vsobel "$(PGM_DIR)/$$safe_name.pgm" \
			    "$(PGM_DIR)/$${safe_name}_out.pgm"; \
			convert "$(PGM_DIR)/$${safe_name}_out.pgm" \
			    "$(OUT_DIR)/$${safe_name}_sobel.png"; \
		fi; \
	done
	@echo "Done."

clean:
	rm -rf obj_dir
	rm -rf "$(PGM_DIR)"
	rm -rf "$(OUT_DIR)"
	rm -rf build_sv

tb:
	mkdir -p $(SV_DIR)
	verilator --binary --timing --timescale 1ns/1ps -Wno-fatal --top-module sobel_tb \
	    rtl/sobel.sv tb/sobel_tb.sv -Mdir $(SV_DIR)/obj

test: tb
	./$(SV_DIR)/obj/Vsobel_tb
