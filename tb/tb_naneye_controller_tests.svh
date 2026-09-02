// ================================================================
//
// NanEyeC controller test tasks
//
// This file is included inside tb_naneye_controller_base
//
// ================================================================

localparam logic [15:0] EXPECTED_REG0 = {
    RESET_ROWS,
    PIXEL_VRST,
    RAMP_GAIN,
    RAMP_OFFS,
    OUT_CURR
};

localparam logic [15:0] EXPECTED_REG1 = {
    ROWS_DELAY,
    BIAS_INCR,
    CDS_GAIN,
    OUT_MODE,
    MCLK_MODE,
    CDS_VREF,
    CVC_CURR,
    IDLE_MODE,
    MCLK_HSPD
};

localparam int ONE_FRAME_APPROX_CLK_CYCLES =
    24 * (
        656 +
        (IMAGE_COLS + 8) * (IMAGE_ROWS + 6 + (16 * int'(ROWS_DELAY)))
    );
localparam int REGISTER_TEST_CYCLES        = 2000;
localparam int CYCLE_LIMIT                 = ONE_FRAME_APPROX_CLK_CYCLES * 10;
localparam int FRAME_PIXELS                = IMAGE_ROWS * IMAGE_COLS;

// Assertions

property property_valid_only_in_row_data;
    @(posedge clk) disable iff (!rst_n)
    valid |-> (dut.current_state == ST_ROW_DATA);
endproperty

assert_valid_only_in_row_data: assert property (property_valid_only_in_row_data)
    else $error("valid outside ROW_DATA state=%0d", dut.current_state);

property property_frame_pulse_only_in_row_data;
    @(posedge clk) disable iff (!rst_n)
    frame_pulse |-> (dut.current_state == ST_ROW_DATA);
endproperty

assert_frame_pulse_only_in_row_data: assert property (property_frame_pulse_only_in_row_data)
    else $error("frame_pulse outside ROW_DATA state=%0d", dut.current_state);

property property_frame_pulse_only_when_valid;
    @(posedge clk) disable iff (!rst_n)
    frame_pulse |-> valid;
endproperty

assert_frame_pulse_only_when_valid: assert property (property_frame_pulse_only_when_valid)
    else $error("frame_pulse without valid");


task automatic init_testbench();
    clk                           = 1'b0;
    rst_n                         = 1'b0;
    naneye_emul_rst_n             = 1'b0;
    start                         = 1'b0;
    corrupt_rows_delay            = 1'b0;
    corrupt_rows_delay_value      = '0;
    pixel_choice                  = CONSTANT_PIXEL;
    reset_scoreboard();
    coverage_reset();
endtask

task automatic reset_testbench();
    rst_n                         = 1'b0;
    naneye_emul_rst_n             = 1'b0;
    start                         = 1'b0;
    corrupt_rows_delay            = 1'b0;
    corrupt_rows_delay_value      = '0;
    reset_scoreboard();

    repeat (4) @(posedge clk);
    rst_n             = 1'b1;
    naneye_emul_rst_n = 1'b1;

    repeat (4) @(posedge clk);
endtask

task automatic reset_scoreboard();
    scoreboard_valid_seen          = 1'b0;
    scoreboard_mismatch_seen       = 1'b0;
    scoreboard_expected_addr       = '0;
    scoreboard_expected_pixel      = '0;
    scoreboard_mismatch_pixel      = '0;
    scoreboard_mismatch_expected   = '0;
    scoreboard_mismatch_addr       = '0;
    scoreboard_correct_pixel_count = '0;
endtask

// Scoreboard signals declared
logic       scoreboard_valid_seen;
logic       scoreboard_mismatch_seen;

logic [7:0] scoreboard_mismatch_pixel;
logic [7:0] scoreboard_mismatch_expected;
logic [7:0] scoreboard_expected_pixel;
int         scoreboard_correct_pixel_count;
logic [$clog2(IMAGE_ROWS*IMAGE_COLS)-1:0] scoreboard_expected_addr;
logic [$clog2(IMAGE_ROWS*IMAGE_COLS)-1:0] scoreboard_mismatch_addr;

task automatic scoreboard_check_pixel();

    if (scoreboard_mismatch_seen) begin
        return;
    end

    case (pixel_choice)
        CONSTANT_PIXEL: begin
            scoreboard_expected_pixel = CONSTANT_SENSOR_PIXEL[9:2];
        end
        MEMORY_PIXEL: begin
            scoreboard_expected_pixel = scene_rom.mem[scoreboard_expected_addr][9:2];
        end
        default: begin
            scoreboard_expected_pixel = '0;
        end

    endcase

    scoreboard_valid_seen = 1'b1;
    if (pixel !== scoreboard_expected_pixel) begin
        scoreboard_mismatch_seen     = 1'b1;
        scoreboard_mismatch_pixel    = pixel;
        scoreboard_mismatch_expected = scoreboard_expected_pixel;
        scoreboard_mismatch_addr     = scoreboard_expected_addr;
    end
    else begin
        scoreboard_correct_pixel_count++;
    end

    if (scoreboard_expected_addr ==
        $bits(scoreboard_expected_addr)'(FRAME_PIXELS - 1)) begin
            scoreboard_expected_addr = '0;
        end
    else begin
        scoreboard_expected_addr++;
    end
endtask

task automatic scoreboard_report(input string test_name);
    if (!scoreboard_valid_seen) begin
         $fatal(1, "%s FAIL no valid pixels seen", test_name);
    end
    else if (scoreboard_mismatch_seen) begin
        $fatal(1,
            "%s FAIL correct_pixels=%0d addr=%0d received=%02h expected=%02h",
            test_name,
            scoreboard_correct_pixel_count,
            scoreboard_mismatch_addr,
            scoreboard_mismatch_pixel,
            scoreboard_mismatch_expected
        );
    end
    else begin
        $display("%s PASS correct_pixels=%0d", test_name, scoreboard_correct_pixel_count);
    end

endtask

// Functional coverage
// Keep manual coverage state observable across Verilator task optimization.
int coverage_valid_pixel_count /*verilator public_flat_rw*/;
int coverage_frame_count /*verilator public_flat_rw*/;

logic coverage_constant_pixel_seen /*verilator public_flat_rw*/;
logic coverage_memory_pixel_seen /*verilator public_flat_rw*/;
logic coverage_delay_corruption_seen /*verilator public_flat_rw*/;

logic coverage_delay_0_seen /*verilator public_flat_rw*/;
logic coverage_delay_4_seen /*verilator public_flat_rw*/;
logic coverage_delay_8_seen /*verilator public_flat_rw*/;
logic coverage_delay_16_seen /*verilator public_flat_rw*/;

logic coverage_idle_seen /*verilator public_flat_rw*/;
logic coverage_activate_seen /*verilator public_flat_rw*/;
logic coverage_reg0_cfg_seen /*verilator public_flat_rw*/;
logic coverage_reg1_cfg_seen /*verilator public_flat_rw*/;
logic coverage_wait_seen /*verilator public_flat_rw*/;
logic coverage_row_train_seen /*verilator public_flat_rw*/;
logic coverage_row_data_seen /*verilator public_flat_rw*/;
logic coverage_eof_seen /*verilator public_flat_rw*/;
logic coverage_find_readout_seen /*verilator public_flat_rw*/;
logic coverage_readout_sync_seen /*verilator public_flat_rw*/;
logic coverage_interface_seen /*verilator public_flat_rw*/;

int coverage_idle_count /*verilator public_flat_rw*/;
int coverage_activate_count /*verilator public_flat_rw*/;
int coverage_reg0_cfg_count /*verilator public_flat_rw*/;
int coverage_reg1_cfg_count /*verilator public_flat_rw*/;
int coverage_wait_count /*verilator public_flat_rw*/;
int coverage_row_train_count /*verilator public_flat_rw*/;
int coverage_row_data_count /*verilator public_flat_rw*/;
int coverage_eof_count /*verilator public_flat_rw*/;
int coverage_find_readout_count /*verilator public_flat_rw*/;
int coverage_readout_sync_count /*verilator public_flat_rw*/;
int coverage_interface_count /*verilator public_flat_rw*/;

task automatic coverage_reset();
    coverage_valid_pixel_count     = '0;
    coverage_frame_count           = '0;
    coverage_constant_pixel_seen   = '0;
    coverage_memory_pixel_seen     = '0;
    coverage_delay_corruption_seen = '0;
    coverage_delay_0_seen          = '0;
    coverage_delay_4_seen          = '0;
    coverage_delay_8_seen          = '0;
    coverage_delay_16_seen         = '0;

    coverage_idle_seen             = '0;
    coverage_activate_seen         = '0;
    coverage_reg0_cfg_seen         = '0;
    coverage_reg1_cfg_seen         = '0;
    coverage_wait_seen             = '0;
    coverage_row_train_seen        = '0;
    coverage_row_data_seen         = '0;
    coverage_eof_seen              = '0;
    coverage_find_readout_seen     = '0;
    coverage_readout_sync_seen     = '0;
    coverage_interface_seen        = '0;

    coverage_idle_count            = '0;
    coverage_activate_count        = '0;
    coverage_reg0_cfg_count        = '0;
    coverage_reg1_cfg_count        = '0;
    coverage_wait_count            = '0;
    coverage_row_train_count       = '0;
    coverage_row_data_count        = '0;
    coverage_eof_count             = '0;
    coverage_find_readout_count    = '0;
    coverage_readout_sync_count    = '0;
    coverage_interface_count       = '0;
endtask

task automatic coverage_sample();
    #1;
    if (valid) begin
        coverage_valid_pixel_count++;
    end

    if (frame_pulse) begin
        coverage_frame_count++;
    end

    case (pixel_choice)
        CONSTANT_PIXEL: begin
            coverage_constant_pixel_seen = 1'b1;
        end
        MEMORY_PIXEL: begin
            coverage_memory_pixel_seen = 1'b1;
        end
        default: begin end
    endcase

    case (dut.current_state)
        ST_IDLE: begin
            coverage_idle_seen = 1'b1;
            coverage_idle_count++;
        end

        ST_ACTIVATE: begin
            coverage_activate_seen = 1'b1;
            coverage_activate_count++;
        end

        ST_REG0_CFG: begin
            coverage_reg0_cfg_seen = 1'b1;
            coverage_reg0_cfg_count++;
        end

        ST_REG1_CFG: begin
            coverage_reg1_cfg_seen = 1'b1;
            coverage_reg1_cfg_count++;
        end

        ST_WAIT: begin
            coverage_wait_seen = 1'b1;
            coverage_wait_count++;
        end

        ST_ROW_TRAIN: begin
            coverage_row_train_seen = 1'b1;
            coverage_row_train_count++;
        end

        ST_ROW_DATA: begin
            coverage_row_data_seen = 1'b1;
            coverage_row_data_count++;
        end

        ST_EOF: begin
            coverage_eof_seen = 1'b1;
            coverage_eof_count++;
        end

        ST_FIND_READOUT: begin
            coverage_find_readout_seen = 1'b1;
            coverage_find_readout_count++;
        end

        ST_READOUT_SYNC_BETWEEN_SENSORS: begin
            coverage_readout_sync_seen = 1'b1;
            coverage_readout_sync_count++;
        end

        ST_INTERFACE: begin
            coverage_interface_seen = 1'b1;
            coverage_interface_count++;
        end

        default: begin end
    endcase

endtask

task automatic coverage_sample_delay_corruption(input logic [4:0] rows_delay);
    coverage_delay_corruption_seen = 1'b1;
    case (rows_delay)
        5'h00: coverage_delay_0_seen  = 1'b1;
        5'h04: coverage_delay_4_seen  = 1'b1;
        5'h08: coverage_delay_8_seen  = 1'b1;
        5'h10: coverage_delay_16_seen = 1'b1;
        default: begin end
    endcase
endtask

// Injects incorrect value to rows delay register to test for
// signal integrity issues during register writes
task automatic corrupt_naneye_rows_delay(input logic[4:0] rows_delay);

    corrupt_rows_delay_value = rows_delay;
    corrupt_rows_delay       = 1'b1;

    @(posedge naneye_sclk);
    #1;
    corrupt_rows_delay = 1'b0;

    coverage_sample_delay_corruption(rows_delay);
    if ($test$plusargs("events")) begin
        $display("  event rows_delay_corrupted=%0d", rows_delay);
    end

endtask

// NanEye register configuration test case
task automatic run_reg_config_test();

    logic config_carried_out;
    config_carried_out = 1'b0;

    reset_testbench();

    @(negedge clk);
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;

    for(int cycle = 0; cycle < REGISTER_TEST_CYCLES; cycle++) begin
        @(posedge clk);

        if ((naneye.reg0 === EXPECTED_REG0) &&
             (naneye.reg1 === EXPECTED_REG1)) begin
            config_carried_out = 1'b1;

            $display("TEST 1 reg_config PASS reg0=%04h reg1=%04h",
                     naneye.reg0, naneye.reg1);
            break;
        end
    end

    if (!config_carried_out) begin
        $fatal(1,
            "TEST 1 reg_config FAIL got reg0=%04h reg1=%04h expected reg0=%04h reg1=%04h",
            naneye.reg0, naneye.reg1, EXPECTED_REG0, EXPECTED_REG1
        );
    end

endtask

// Enables displaying progress because tests take long to complete
task automatic print_loop_progress(
    input string test_name,
    input int cycle,
    input int cycle_limit
);
    int progress_step;

    if (!$test$plusargs("progress")) begin
        return;
    end

    // Ternary to prevent division by 0 when cycle_limit less than 100
    progress_step = (cycle_limit >= 100) ? (cycle_limit / 100) : 1;

    if ((cycle % progress_step) == 0) begin
        $write("\r%s Progress: %0d%%", test_name, ((cycle * 100) / cycle_limit) + 1);
        $fflush();
    end
endtask

// NanEye readout test case with constant pixel value
task automatic run_constant_pixel_value_readout_test();

    reset_testbench();
    pixel_choice = CONSTANT_PIXEL;

    coverage_sample();
    @(negedge clk);
    start = 1'b1;

    coverage_sample();
    @(negedge clk);
    start = 1'b0;

    for(int cycle = 0; cycle < CYCLE_LIMIT; cycle++) begin
        @(posedge clk);

        coverage_sample();

        print_loop_progress("TEST CASE 2", cycle, CYCLE_LIMIT);

        if ((valid)) begin
            scoreboard_check_pixel();
            if(scoreboard_mismatch_seen) begin
                break;
            end
        end
    end

    if ($test$plusargs("progress")) begin
        $write("\n");
    end

    scoreboard_report("TEST 2 constant_pixel_readout");


endtask

// NanEye readout with register delay value changing during readout
// with constant pixel value to test for frame alignment
task automatic run_corrupted_sensor_delay_relock_with_constant_pixel_test();

    logic [3:0] rows_delay_case_counter;

    reset_testbench();

    pixel_choice = CONSTANT_PIXEL;
    rows_delay_case_counter    = 4'b0;

    coverage_sample();
    @(negedge clk);
    start = 1'b1;

    coverage_sample();
    @(negedge clk);
    start = 1'b0;

    for(int cycle = 0; cycle < CYCLE_LIMIT; cycle++) begin
        @(posedge clk);

        coverage_sample();

        print_loop_progress("TEST CASE 3", cycle, CYCLE_LIMIT);

        if (valid) begin
            scoreboard_check_pixel();
            if (scoreboard_mismatch_seen) begin
                break;
            end
        end

        // Score the final pixel before this task waits for the next SCLK edge.
        if (frame_pulse) begin
            case (rows_delay_case_counter % 4)
                0: corrupt_naneye_rows_delay(5'h00);
                1: corrupt_naneye_rows_delay(5'h04);
                2: corrupt_naneye_rows_delay(5'h08);
                3: corrupt_naneye_rows_delay(5'h10);
            endcase
            rows_delay_case_counter = rows_delay_case_counter + 1;
        end
    end

    if ($test$plusargs("progress")) begin
        $write("\n");
    end

    scoreboard_report("TEST 3 constant_delay_corruption");

endtask

// NanEye readout test case with memory loaded image
task automatic run_memory_loaded_image_readout_test();

    reset_testbench();

    pixel_choice = MEMORY_PIXEL;

    coverage_sample();
    @(negedge clk);
    start = 1'b1;

    coverage_sample();
    @(negedge clk);
    start = 1'b0;

    for(int cycle = 0; cycle < CYCLE_LIMIT; cycle++) begin
        @(posedge clk);

        coverage_sample();

        print_loop_progress("TEST CASE 4", cycle, CYCLE_LIMIT);

        if ((valid)) begin
            scoreboard_check_pixel();
            if(scoreboard_mismatch_seen) begin
                break;
            end

        end
    end

    if ($test$plusargs("progress")) begin
        $write("\n");
    end

    scoreboard_report("TEST 4 memory_readout");

endtask

// NanEye readout test case with memory loaded image and delay register corruption
task automatic run_memory_loaded_image_readout_with_delay_corruption_test();

    logic [3:0] rows_delay_case_counter;

    reset_testbench();

    pixel_choice            = MEMORY_PIXEL;
    rows_delay_case_counter = 4'b0;

    coverage_sample();
    @(negedge clk);
    start = 1'b1;

    coverage_sample();
    @(negedge clk);
    start = 1'b0;

    for(int cycle = 0; cycle < CYCLE_LIMIT; cycle++) begin
        @(posedge clk);

        coverage_sample();

        print_loop_progress("TEST CASE 5", cycle, CYCLE_LIMIT);

        if (valid) begin
            scoreboard_check_pixel();
            if (scoreboard_mismatch_seen) begin
                break;
            end
        end

        // Score the final pixel before this task waits for the next SCLK edge.
        if (frame_pulse) begin
            case (rows_delay_case_counter % 4)
                0: corrupt_naneye_rows_delay(5'h00);
                1: corrupt_naneye_rows_delay(5'h04);
                2: corrupt_naneye_rows_delay(5'h08);
                3: corrupt_naneye_rows_delay(5'h10);
            endcase
            rows_delay_case_counter = rows_delay_case_counter + 1;
        end
    end

    if ($test$plusargs("progress")) begin
        $write("\n");
    end

    scoreboard_report("TEST 5 memory_delay_corruption");

endtask

task automatic run_sdat_find_readout_noise_recovery_test();

    int   frame_count;
    int   total_flip_count;
    int   noisy_frame_flip_count;
    int   correctly_synced_frame_count;

    logic check_frame;
    logic checked_frame_failed;
    logic should_flip;
    logic forced_sdat;

    reset_testbench();

    pixel_choice                 = MEMORY_PIXEL;
    frame_count                  = 0;
    total_flip_count             = 0;
    noisy_frame_flip_count       = 0;
    checked_frame_failed         = 1'b0;
    correctly_synced_frame_count = 0;

    coverage_sample();
    @(negedge clk);
    start = 1'b1;

    coverage_sample();
    @(negedge clk);
    start = 1'b0;

    for (int cycle = 0; cycle < CYCLE_LIMIT; cycle++) begin

        @(negedge clk);

        // Check in odd frames and inject noisy (inverted) bits in even frames
        check_frame = frame_count[0];

        should_flip =
            !check_frame &&
            (noisy_frame_flip_count < 8) &&
            (dut.current_state == ST_FIND_READOUT) &&
            naneye_sclk &&
            ($urandom_range(0, IMAGE_COLS / 4) == 0);

        if (should_flip) begin
            forced_sdat = (naneye_sdat === 1'b1) ? 1'b0 : 1'b1;
            force naneye_sdat = forced_sdat;
            noisy_frame_flip_count++;
            total_flip_count++;
        end

        @(posedge clk);

        if (should_flip) begin
            #1; // wait 1 ns to ensure controller samples unreleased
            release naneye_sdat;
        end

        coverage_sample();

        print_loop_progress("TEST CASE 6", cycle, CYCLE_LIMIT);

        check_frame = frame_count[0];

        if (check_frame && valid) begin
            scoreboard_check_pixel();

            if (scoreboard_mismatch_seen) begin
                checked_frame_failed = 1'b1;
                break;
            end
        end

        if (frame_pulse) begin
            if (check_frame) begin
                if (scoreboard_mismatch_seen ||
                    (scoreboard_correct_pixel_count != FRAME_PIXELS)) begin
                    checked_frame_failed = 1'b1;
                    break;
                end

                correctly_synced_frame_count++;

            end

            frame_count++;
            noisy_frame_flip_count = 0;
            reset_scoreboard();
        end
    end

    if ($test$plusargs("progress")) begin
        $write("\n");
    end

    if (checked_frame_failed) begin
        $fatal(1,
            "TEST 6 sdat_find_readout_noise_recovery FAIL correct_pixels=%0d addr=%0d received=%02h expected=%02h",
            scoreboard_correct_pixel_count,
            scoreboard_mismatch_addr,
            scoreboard_mismatch_pixel,
            scoreboard_mismatch_expected
        );
    end
    else if (total_flip_count == 0) begin
        $fatal(1, "TEST 6 sdat_find_readout_noise_recovery FAIL no SDAT flips injected");
    end
    else if (correctly_synced_frame_count == 0) begin
        $fatal(1, "TEST 6 sdat_find_readout_noise_recovery FAIL no clean checked frames completed");
    end
    else begin
        $display("TEST 6 sdat_find_readout_noise_recovery PASS checked_frames=%0d sdat_flips=%0d",
                correctly_synced_frame_count, total_flip_count);
    end


endtask
