VERILATOR ?= verilator

RTL_TOP          := naneye_ctl
SMALL_SIM_TOP    := tb_naneye_controller_small_image
LARGE_SIM_TOP    := tb_naneye_controller_large_image
MULTIPLE_SIM_TOP := tb_naneye_controller_multiple

BUILD_DIR      := build
SMALL_BUILD    := $(BUILD_DIR)/small
LARGE_BUILD    := $(BUILD_DIR)/large
MULTIPLE_BUILD := $(BUILD_DIR)/multiple

SMALL_BINARY    := $(SMALL_BUILD)/V$(SMALL_SIM_TOP)
LARGE_BINARY    := $(LARGE_BUILD)/V$(LARGE_SIM_TOP)
MULTIPLE_BINARY := $(MULTIPLE_BUILD)/V$(MULTIPLE_SIM_TOP)

RTL_SOURCES := \
	rtl/naneye_ctl_state_pkg.sv \
	rtl/naneye_ctl.sv \
	rtl/naneye_ctl_eof_valid_detector.sv \
	rtl/naneye_ctl_frame_aligner.sv \
	rtl/naneye_ctl_fsm.sv \
	rtl/naneye_ctl_phase_counter.sv \
	rtl/naneye_ctl_sclk_generator.sv \
	rtl/naneye_ctl_serial_io.sv \
	rtl/naneye_ctl_shift_register_pixel_sclks_wide.sv

TB_COMMON := \
	tb/naneye_emul.sv \
	tb/naneye_scene_rom.sv \
	tb/tb_naneye_controller_base.sv

VERILATOR_FLAGS := \
	--timing \
	--assert \
	-Wall \
	-Irtl \
	-Itb

.PHONY: all lint test test-small test-large test-multiple clean

all: lint test

lint:
	$(VERILATOR) --lint-only \
		$(VERILATOR_FLAGS) \
		$(RTL_SOURCES) \
		--top-module $(RTL_TOP)
	$(VERILATOR) --lint-only \
		$(VERILATOR_FLAGS) \
		$(RTL_SOURCES) \
		examples/top_naneye_single_example.sv \
		--top-module top_naneye_single_example
	$(VERILATOR) --lint-only \
		$(VERILATOR_FLAGS) \
		$(RTL_SOURCES) \
		examples/top_naneye_multiple_example.sv \
		--top-module top_naneye_multiple_example

$(SMALL_BINARY): $(RTL_SOURCES) $(TB_COMMON) \
		tb/$(SMALL_SIM_TOP).sv \
		tb/tb_naneye_controller_tests.svh \
		tb/data/test_image_8x8_grayscale_10bit.mem
	mkdir -p $(SMALL_BUILD)
	$(VERILATOR) --binary \
		$(VERILATOR_FLAGS) \
		--Mdir $(SMALL_BUILD) \
		$(RTL_SOURCES) \
		$(TB_COMMON) \
		tb/$(SMALL_SIM_TOP).sv \
		--top-module $(SMALL_SIM_TOP)

$(LARGE_BINARY): $(RTL_SOURCES) $(TB_COMMON) \
		tb/$(LARGE_SIM_TOP).sv \
		tb/tb_naneye_controller_tests.svh \
		tb/data/test_image_320x320_grayscale_10bit.mem
	mkdir -p $(LARGE_BUILD)
	$(VERILATOR) --binary \
		$(VERILATOR_FLAGS) \
		--Mdir $(LARGE_BUILD) \
		$(RTL_SOURCES) \
		$(TB_COMMON) \
		tb/$(LARGE_SIM_TOP).sv \
		--top-module $(LARGE_SIM_TOP)

$(MULTIPLE_BINARY): $(RTL_SOURCES) \
		tb/naneye_emul.sv \
		tb/naneye_scene_rom.sv \
		tb/$(MULTIPLE_SIM_TOP).sv \
		tb/data/test_image_8x8_grayscale_10bit.mem
	mkdir -p $(MULTIPLE_BUILD)
	$(VERILATOR) --binary \
		$(VERILATOR_FLAGS) \
		--Mdir $(MULTIPLE_BUILD) \
		$(RTL_SOURCES) \
		tb/naneye_emul.sv \
		tb/naneye_scene_rom.sv \
		tb/$(MULTIPLE_SIM_TOP).sv \
		--top-module $(MULTIPLE_SIM_TOP)

test: test-small test-large test-multiple

test-small: $(SMALL_BINARY)
	cd tb && ../$(SMALL_BINARY)

test-large: $(LARGE_BINARY)
	cd tb && ../$(LARGE_BINARY)

test-multiple: $(MULTIPLE_BINARY)
	cd tb && ../$(MULTIPLE_BINARY)

clean:
	rm -rf $(BUILD_DIR)
