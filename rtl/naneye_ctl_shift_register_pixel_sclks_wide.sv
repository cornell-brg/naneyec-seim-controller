// ================================================================
//
// Date  : 9 June, 2026
// Author: Kaan Akan
//
// Shift register for pixel value handling
//
// ================================================================

`ifndef _NANEYE_CTL_SHIFT_REGISTER_PIXEL_SCLKS_WIDE_
`define _NANEYE_CTL_SHIFT_REGISTER_PIXEL_SCLKS_WIDE_

module naneye_ctl_shift_register_pixel_sclks_wide #
(
    parameter PIXEL_SCLKS = 12
)(
    input  logic               clk,
    input  logic               rst_n,

    input  logic               data,
    input  logic               enable,

    output logic [PIXEL_SCLKS-1:0] pixel_word
);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pixel_word <= '0;
        end
        else if (enable) begin
            pixel_word <= {pixel_word[PIXEL_SCLKS-2:0], data};
        end
    end

endmodule

`endif // _NANEYE_CTL_SHIFT_REGISTER_PIXEL_SCLKS_WIDE_
