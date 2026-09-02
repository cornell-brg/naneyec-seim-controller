module top_naneye_single_example (
    input  logic clk,
    input  logic rst_n,

    output logic naneye_sclk,
    inout  wire  naneye_sdat,
    output logic naneye_enable,

    output logic [7:0] pixel,
    output logic       pixel_valid,
    output logic       frame_pulse
);

    logic [15:0] start_counter;
    logic        start;

    /* verilator lint_off UNUSEDSIGNAL */
    logic        readout_ready;
    /* verilator lint_on UNUSEDSIGNAL */

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            start_counter <= '0;
        end
        else if (!start) begin
            start_counter <= start_counter + 1'b1;
        end
    end

    assign start = (start_counter == 16'hFFFF);

    assign naneye_enable = 1'b1;

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
    ) controller (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (start),
        // single controller doesn't need to sync
        .readout_sync_go    (1'b1), 
        .readout_sync_ready (readout_ready),
        .naneye_sclk        (naneye_sclk),
        .naneye_sdat        (naneye_sdat),
        .pixel              (pixel),
        .valid              (pixel_valid),
        .frame_pulse        (frame_pulse)
    );

endmodule
