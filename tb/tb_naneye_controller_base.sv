// ================================================================
//
// Date  : June 16, 2026
// Author: Kaan Akan
//
// NanEyeC controller testbench harness
//
// This file owns the controller (DUT), sensor emulator, shared wires
// Test-specific tasks live in the included .svh file, and 
// can be called in this file, for instance: init_testbench()
//
// ================================================================

module tb_naneye_controller_base #(
    parameter int    IMAGE_ROWS = 8,
    parameter int    IMAGE_COLS = 8,
    parameter string MEM_FILE   = "data/test_image_8x8_grayscale_10bit.mem",
    parameter string TRACE_FILE = "tb_naneye_controller.fst"
);
    import naneye_ctl_state_pkg::*;

    localparam int PIXELBITS  = 8;

    localparam logic [7:0] RESET_ROWS = 8'h12;
    localparam logic [1:0] PIXEL_VRST = 2'b10;
    localparam logic [1:0] RAMP_GAIN  = 2'b11;
    localparam logic [1:0] RAMP_OFFS  = 2'b01;
    localparam logic [1:0] OUT_CURR   = 2'b10;

    localparam logic [4:0] ROWS_DELAY = 5'h08;
    localparam logic       BIAS_INCR  = 1'b1;
    localparam logic       CDS_GAIN   = 1'b0;
    localparam logic       OUT_MODE   = 1'b0;
    localparam logic [1:0] MCLK_MODE  = 2'b00;
    localparam logic [1:0] CDS_VREF   = 2'b10;
    localparam logic [1:0] CVC_CURR   = 2'b01;
    localparam logic       IDLE_MODE  = 1'b0;
    localparam logic       MCLK_HSPD  = 1'b0;

    localparam logic [9:0] CONSTANT_SENSOR_PIXEL = 10'h2D3;

    localparam int SENSOR_PIXELBITS = 10;
    localparam int SCENE_ADDR_WIDTH = $clog2(IMAGE_ROWS * IMAGE_COLS);

    logic [SCENE_ADDR_WIDTH-1:0] scene_addr;
    logic [SENSOR_PIXELBITS-1:0] scene_memory_pixel;

    typedef enum logic [1:0]{
        CONSTANT_PIXEL,
        MEMORY_PIXEL
    } pixel_choice_t;

    pixel_choice_t pixel_choice;
    logic clk;
    logic rst_n;
    logic start;

    logic naneye_sclk;
    wire  naneye_sdat;
    logic naneye_emul_rst_n;

    /* verilator lint_off UNUSEDSIGNAL */
    logic readout_sync_ready;
    /* verilator lint_on UNUSEDSIGNAL */

    logic [PIXELBITS-1:0] pixel;
    logic                 valid;
    logic                 frame_pulse;

    logic [SENSOR_PIXELBITS-1:0] passed_pixel;

    always_comb begin
        case (pixel_choice)
            CONSTANT_PIXEL: passed_pixel = CONSTANT_SENSOR_PIXEL;
            MEMORY_PIXEL:   passed_pixel = scene_memory_pixel;
            default:        passed_pixel = CONSTANT_SENSOR_PIXEL;
        endcase
    end

    logic       corrupt_rows_delay;
    logic [4:0] corrupt_rows_delay_value;

    naneye_emul #(
        .IMAGE_ROWS (IMAGE_ROWS),
        .IMAGE_COLS (IMAGE_COLS)
    ) naneye (
        .rst_n                    (naneye_emul_rst_n),
        .scene_pixel              (passed_pixel),
        .sclk                     (naneye_sclk),
        .corrupt_rows_delay       (corrupt_rows_delay),
        .corrupt_rows_delay_value (corrupt_rows_delay_value),
        .sdat                     (naneye_sdat),
        .scene_addr               (scene_addr)
    );

    naneye_ctl #(
        .OUTBITS    (PIXELBITS),
        .WAITCLKS   (4),
        .RESET_ROWS (RESET_ROWS),
        .PIXEL_VRST (PIXEL_VRST),
        .RAMP_GAIN  (RAMP_GAIN),
        .RAMP_OFFS  (RAMP_OFFS),
        .OUT_CURR   (OUT_CURR),
        .ROWS_DELAY (ROWS_DELAY),
        .BIAS_INCR  (BIAS_INCR),
        .CDS_GAIN   (CDS_GAIN),
        .OUT_MODE   (OUT_MODE),
        .MCLK_MODE  (MCLK_MODE),
        .CDS_VREF   (CDS_VREF),
        .CVC_CURR   (CVC_CURR),
        .IDLE_MODE  (IDLE_MODE),
        .MCLK_HSPD  (MCLK_HSPD),
        .IMAGE_ROWS (IMAGE_ROWS),
        .IMAGE_COLS (IMAGE_COLS)
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (start),
        .naneye_sdat        (naneye_sdat),
        .naneye_sclk        (naneye_sclk),
        .pixel              (pixel),
        .valid              (valid),
        .readout_sync_go    (1'b1),
        .readout_sync_ready (readout_sync_ready),
        .frame_pulse        (frame_pulse)
    );

    naneye_scene_rom #(
        .ROWS      (IMAGE_ROWS),
        .COLS      (IMAGE_COLS),
        .PIXELBITS (SENSOR_PIXELBITS),
        .MEM_FILE  (MEM_FILE)
    ) scene_rom
    (
        .clk   (clk),
        .addr  (scene_addr),
        .pixel (scene_memory_pixel)
    );

    always #10 clk <= ~clk;

    `include "tb_naneye_controller_tests.svh"

    initial begin
        string selected_test;
        logic  test_ran;

        if ($test$plusargs("trace")) begin
            $dumpfile(TRACE_FILE);
            $dumpvars(0);
        end

        init_testbench();

        if (!$value$plusargs("test=%s", selected_test)) begin
            selected_test = "all";
        end

        test_ran = 1'b0;

        if ((selected_test == "all") || (selected_test == "reg_config")) begin
            run_reg_config_test();
            test_ran = 1'b1;
        end

        if ((selected_test == "all") || (selected_test == "constant")) begin
            run_constant_pixel_value_readout_test();
            test_ran = 1'b1;
        end

        if ((selected_test == "all") || (selected_test == "constant_delay")) begin
            run_corrupted_sensor_delay_relock_with_constant_pixel_test();
            test_ran = 1'b1;
        end

        if ((selected_test == "all") || (selected_test == "memory")) begin
            run_memory_loaded_image_readout_test();
            test_ran = 1'b1;
        end

        if ((selected_test == "all") || (selected_test == "memory_delay")) begin
            run_memory_loaded_image_readout_with_delay_corruption_test();
            test_ran = 1'b1;
        end

        if ((selected_test == "all") || (selected_test == "sdat_noise")) begin
            run_sdat_find_readout_noise_recovery_test();
            test_ran = 1'b1;
        end

        if (!test_ran) begin
            $fatal(1, "Unknown +test=%s", selected_test);
        end

        $display("COVERAGE SUMMARY:");
        $display("  valid_pixel_count       = %0d", coverage_valid_pixel_count);
        $display("  frame_count             = %0d", coverage_frame_count);
        $display("  constant_pixel_seen     = %0d", coverage_constant_pixel_seen);
        $display("  memory_pixel_seen       = %0d", coverage_memory_pixel_seen);
        $display("  delay_corruption_seen   = %0d", coverage_delay_corruption_seen);
        $display("  delay_0_seen            = %0d", coverage_delay_0_seen);
        $display("  delay_4_seen            = %0d", coverage_delay_4_seen);
        $display("  delay_8_seen            = %0d", coverage_delay_8_seen);
        $display("  delay_16_seen           = %0d", coverage_delay_16_seen);
        $display("  state_idle          seen=%0d clk_count=%0d", coverage_idle_seen, coverage_idle_count);
        $display("  state_activate      seen=%0d clk_count=%0d", coverage_activate_seen, coverage_activate_count);
        $display("  state_reg0_cfg      seen=%0d clk_count=%0d", coverage_reg0_cfg_seen, coverage_reg0_cfg_count);
        $display("  state_reg1_cfg      seen=%0d clk_count=%0d", coverage_reg1_cfg_seen, coverage_reg1_cfg_count);
        $display("  state_wait          seen=%0d clk_count=%0d", coverage_wait_seen, coverage_wait_count);
        $display("  state_row_train     seen=%0d clk_count=%0d", coverage_row_train_seen, coverage_row_train_count);
        $display("  state_row_data      seen=%0d clk_count=%0d", coverage_row_data_seen, coverage_row_data_count);
        $display("  state_eof           seen=%0d clk_count=%0d", coverage_eof_seen, coverage_eof_count);
        $display("  state_find_readout  seen=%0d clk_count=%0d", coverage_find_readout_seen, coverage_find_readout_count);
        $display("  state_readout_sync  seen=%0d clk_count=%0d", coverage_readout_sync_seen, coverage_readout_sync_count);
        $display("  state_interface     seen=%0d clk_count=%0d", coverage_interface_seen, coverage_interface_count);
        $finish;
    end

endmodule
