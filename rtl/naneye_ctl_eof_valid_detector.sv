// ================================================================
//
// Date  : 12 June, 2026
// Author: Kaan Akan
//
// Uses the EOF pattern, 8PP of zeros, to identify if EOF is correctly
// synced between controller and the sensor.
//
//
// ================================================================

`ifndef _NANEYE_CTL_EOF_VALID_DETECTOR_SV_
`define _NANEYE_CTL_EOF_VALID_DETECTOR_SV_

module naneye_ctl_eof_valid_detector
(
    input  logic             clk,
    input  logic             rst_n,

    input  logic             clear,
    // Enable when in ST_EOF and sclk_fall high
    input  logic             enable,
    input  logic             sdat,

    output logic             eof_valid
);

    logic [6:0] zero_count;

    // In the last cycle, last cycle's bad_bit_detected hasn't been sampled yet
    // so we can use the combinational sdat to take the last sdat into consideration
    // Limit is 95 because EOF is 8 PIXEL_SCLKS so 8 * 12 - 1 = 95
    assign eof_valid = enable && !sdat && (zero_count == 7'd95);

    always_ff @(posedge clk) begin
        if (!rst_n || clear) begin
            zero_count <= '0;
        end
        else if (enable) begin
            if (sdat) begin
                zero_count <= '0;
            end
            else if (zero_count != 7'd95) begin
                zero_count <= zero_count + 1'b1;
            end
        end
    end

endmodule

`endif // _NANEYE_CTL_EOF_VALID_DETECTOR_SV_
