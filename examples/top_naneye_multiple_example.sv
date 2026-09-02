module top_naneye_multiple_example (
    input  logic clk,
    input  logic rst_n,

    output logic naneye_sclk_1,
    inout  wire  naneye_sdat_1,
    output logic naneye_enable_1,

    output logic naneye_sclk_2,
    inout  wire  naneye_sdat_2,
    output logic naneye_enable_2,

    output logic [7:0] pixel_1,
    output logic       pixel_valid_1,
    output logic       frame_pulse_1,

    output logic [7:0] pixel_2,
    output logic       pixel_valid_2,
    output logic       frame_pulse_2
);

    logic [15:0] start_counter;
    logic        start;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            start_counter <= '0;
        end
        else if (!start) begin
            start_counter <= start_counter + 1'b1;
        end
    end

    assign start = (start_counter == 16'hFFFF);
    assign naneye_enable_1 = 1'b1;
    assign naneye_enable_2 = 1'b1;

    logic readout_sync_ready_1;
    logic readout_sync_ready_2;
    logic readout_sync_go;

    assign readout_sync_go = readout_sync_ready_1 && readout_sync_ready_2;

    naneye_ctl #(
        .OUTBITS    (8),
        .WAITCLKS   (1000),
        .RESET_ROWS (8'h60),
        .RAMP_GAIN  (2'b11),
        .RAMP_OFFS  (2'b11),
        .OUT_CURR   (2'b10),
        .ROWS_DELAY (5'h00),
        .BIAS_INCR  (1'b1),
        .CDS_GAIN   (1'b0),
        .CDS_VREF   (2'b10),
        .MCLK_MODE  (2'b01),
        .MCLK_HSPD  (1'b0)
    ) controller_1 (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (start),
        .readout_sync_go    (readout_sync_go), 
        .readout_sync_ready (readout_sync_ready_1),
        .naneye_sclk        (naneye_sclk_1),
        .naneye_sdat        (naneye_sdat_1),
        .pixel              (pixel_1),
        .valid              (pixel_valid_1),
        .frame_pulse        (frame_pulse_1)
    );

    naneye_ctl #(
        .OUTBITS    (8),
        .WAITCLKS   (1000),
        .RESET_ROWS (8'h60),
        .RAMP_GAIN  (2'b11),
        .RAMP_OFFS  (2'b11),
        .OUT_CURR   (2'b10),
        .ROWS_DELAY (5'h00),
        .BIAS_INCR  (1'b1),
        .CDS_GAIN   (1'b0),
        .CDS_VREF   (2'b10),
        .MCLK_MODE  (2'b01),
        .MCLK_HSPD  (1'b0)
    ) controller_2 (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (start),
        .readout_sync_go    (readout_sync_go), 
        .readout_sync_ready (readout_sync_ready_2),
        .naneye_sclk        (naneye_sclk_2),
        .naneye_sdat        (naneye_sdat_2),
        .pixel              (pixel_2),
        .valid              (pixel_valid_2),
        .frame_pulse        (frame_pulse_2)
    );

endmodule
