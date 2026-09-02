// ================================================================
//
// Date  : 14 June, 2026
// Author: Kaan Akan
//
// Uses the long alternating sync pattern 0x555 (0101 0101 0101) and
// the start bit being 1 to find the first consecutive 1s after a long
// stream of alternating bits to sync the controller and the sensor states
//
// ================================================================

`ifndef _NANEYE_CTL_STATE_FRAME_ALIGNER_SV_
`define _NANEYE_CTL_STATE_FRAME_ALIGNER_SV_

module naneye_ctl_frame_aligner #(
    parameter MIN_ALTERNATING_BITS = 3936
)(
    input  logic clk,
    input  logic rst_n,

    input  logic clear,
    // Enable when in ST_FIND_READOUT and sclk_fall high
    input  logic enable,
    input  logic sdat,

    output logic row_start_found
);

    // Require at least 3936 (328 * 12) cycles of alternating bits
    // to arm for setting row_start_found after sampling two consecutive ones

    logic [23:0] alternating_bit_cycles;
    logic        previous_bit;

    assign row_start_found = (alternating_bit_cycles >= 24'(MIN_ALTERNATING_BITS)) &&
                              sdat && previous_bit && enable;

    always_ff @(posedge clk) begin
        if (!rst_n || clear) begin
            alternating_bit_cycles <= '0;
            previous_bit           <= '0;

        end
        else if (enable) begin
            previous_bit <= sdat;

            // XOR of previous_bit and current bit
            if (previous_bit ^ sdat) begin
                alternating_bit_cycles <= alternating_bit_cycles + 1'b1;
            end
            else begin
                alternating_bit_cycles <= '0;
            end
        end
    end

endmodule

`endif // _NANEYE_CTL_STATE_FRAME_ALIGNER_SV_
