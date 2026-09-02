// ================================================================
//
// Date  : Sep 1, 2026
// Author: Kaan Akan
//
// NanEyeC controller testbench harness for multiple sensor sync
//
// ================================================================

module tb_naneye_controller_multiple ();

    import naneye_ctl_state_pkg::*;

    localparam int PIXELBITS  = 8;

    localparam logic [7:0] RESET_ROWS = 8'h12;
    localparam logic [1:0] PIXEL_VRST = 2'b10;
    localparam logic [1:0] RAMP_GAIN  = 2'b11;
    localparam logic [1:0] RAMP_OFFS  = 2'b01;
    localparam logic [1:0] OUT_CURR   = 2'b10;

    // Give different rows delay to sensors
    localparam logic [4:0] ROWS_DELAY_1 = 5'h08;
    localparam logic [4:0] ROWS_DELAY_2 = 5'h04;

    localparam logic       BIAS_INCR  = 1'b1;
    localparam logic       CDS_GAIN   = 1'b0;
    localparam logic       OUT_MODE   = 1'b0;
    localparam logic [1:0] MCLK_MODE  = 2'b00;
    localparam logic [1:0] CDS_VREF   = 2'b10;
    localparam logic [1:0] CVC_CURR   = 2'b01;
    localparam logic       IDLE_MODE  = 1'b0;
    localparam logic       MCLK_HSPD  = 1'b0;

    localparam int IMAGE_ROWS = 8;
    localparam int IMAGE_COLS = 8;

    localparam int SENSOR_PIXELBITS = 10;
    localparam int SCENE_ADDR_WIDTH = $clog2(IMAGE_ROWS * IMAGE_COLS);

    localparam string MEM_FILE   = "data/test_image_8x8_grayscale_10bit.mem";

    logic [SCENE_ADDR_WIDTH-1:0] scene_addr_1, scene_addr_2;
    logic [SENSOR_PIXELBITS-1:0] scene_memory_pixel_1, 
                                 scene_memory_pixel_2;

    logic clk;
    logic rst_n;
    logic start;

    logic naneye_sclk_1, naneye_sclk_2;
    wire  naneye_sdat_1, naneye_sdat_2;
    logic naneye_emul_rst_n;

    logic readout_sync_ready_1, readout_sync_ready_2;
    logic readout_sync_go;

    assign readout_sync_go = readout_sync_ready_1 && readout_sync_ready_2;

    logic [PIXELBITS-1:0] pixel_1,       pixel_2;
    logic                 valid_1,       valid_2;
    logic                 frame_pulse_1, frame_pulse_2;

    naneye_emul #(
        .IMAGE_ROWS (IMAGE_ROWS),
        .IMAGE_COLS (IMAGE_COLS)
    ) naneye_1 (
        .rst_n                    (naneye_emul_rst_n),
        .scene_pixel              (scene_memory_pixel_1),
        .sclk                     (naneye_sclk_1),
        .corrupt_rows_delay       (1'b0),
        .corrupt_rows_delay_value (5'd0),
        .sdat                     (naneye_sdat_1),
        .scene_addr               (scene_addr_1)
    );

    naneye_ctl #(
        .OUTBITS    (PIXELBITS),
        .WAITCLKS   (4),
        .RESET_ROWS (RESET_ROWS),
        .PIXEL_VRST (PIXEL_VRST),
        .RAMP_GAIN  (RAMP_GAIN),
        .RAMP_OFFS  (RAMP_OFFS),
        .OUT_CURR   (OUT_CURR),
        .ROWS_DELAY (ROWS_DELAY_1),
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
    ) dut_1 (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (start),
        .naneye_sdat        (naneye_sdat_1),
        .naneye_sclk        (naneye_sclk_1),
        .pixel              (pixel_1),
        .valid              (valid_1),
        .readout_sync_go    (readout_sync_go),
        .readout_sync_ready (readout_sync_ready_1),
        .frame_pulse        (frame_pulse_1)
    );

    naneye_scene_rom #(
        .ROWS      (IMAGE_ROWS),
        .COLS      (IMAGE_COLS),
        .PIXELBITS (SENSOR_PIXELBITS),
        .MEM_FILE  (MEM_FILE)
    ) scene_rom_1
    (
        .clk   (clk),
        .addr  (scene_addr_1),
        .pixel (scene_memory_pixel_1)
    );

    naneye_emul #(
        .IMAGE_ROWS (IMAGE_ROWS),
        .IMAGE_COLS (IMAGE_COLS)
    ) naneye_2 (
        .rst_n                    (naneye_emul_rst_n),
        .scene_pixel              (scene_memory_pixel_2),
        .sclk                     (naneye_sclk_2),
        .corrupt_rows_delay       (1'b0),
        .corrupt_rows_delay_value (5'd0),
        .sdat                     (naneye_sdat_2),
        .scene_addr               (scene_addr_2)
    );

    naneye_ctl #(
        .OUTBITS    (PIXELBITS),
        .WAITCLKS   (4),
        .RESET_ROWS (RESET_ROWS),
        .PIXEL_VRST (PIXEL_VRST),
        .RAMP_GAIN  (RAMP_GAIN),
        .RAMP_OFFS  (RAMP_OFFS),
        .OUT_CURR   (OUT_CURR),
        .ROWS_DELAY (ROWS_DELAY_2),
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
    ) dut_2 (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (start),
        .naneye_sdat        (naneye_sdat_2),
        .naneye_sclk        (naneye_sclk_2),
        .pixel              (pixel_2),
        .valid              (valid_2),
        .readout_sync_go    (readout_sync_go),
        .readout_sync_ready (readout_sync_ready_2),
        .frame_pulse        (frame_pulse_2)
    );

    naneye_scene_rom #(
        .ROWS      (IMAGE_ROWS),
        .COLS      (IMAGE_COLS),
        .PIXELBITS (SENSOR_PIXELBITS),
        .MEM_FILE  (MEM_FILE)
    ) scene_rom_2
    (
        .clk   (clk),
        .addr  (scene_addr_2),
        .pixel (scene_memory_pixel_2)
    );

    logic [31:0] valid_pixel_count;
    always_ff @(posedge clk) begin : valid_pixel_counter
        if (!rst_n) begin
            valid_pixel_count <= '0;
        end
        else if (valid_1 && valid_2) begin
            valid_pixel_count <= valid_pixel_count + 1'b1;
        end
    end

    always_ff @(posedge clk) begin : assert_valid_signals_match
        if (rst_n) begin
            assert ((valid_1 == valid_2));
            else $fatal(1, "Sensor pixel-valid signals aren't synchronized");

            assert (frame_pulse_1 == frame_pulse_2);
            else $fatal(1, "Sensor frame pulses aren't synchronized");

            if (valid_1 || valid_2) begin
                assert(pixel_1 == pixel_2);
                else $fatal(1, "Sensor pixels aren't same for same scene");
            end
        end
    end

    always #10 clk <= ~clk;

    initial begin

        clk                           = 1'b0;
        rst_n                         = 1'b0;
        naneye_emul_rst_n             = 1'b0;
        start                         = 1'b0;

        @(posedge clk);
        @(posedge clk);

        rst_n             = 1'b1;
        naneye_emul_rst_n = 1'b1;

        @(posedge clk);
        @(posedge clk);

        @(negedge clk);
        start = 1'b1;

        @(posedge clk);

        wait (valid_pixel_count == (IMAGE_ROWS * IMAGE_COLS) * 10);
        $display("MULTIPLE SENSOR SYNC PASS");

        $finish;
    end

endmodule
