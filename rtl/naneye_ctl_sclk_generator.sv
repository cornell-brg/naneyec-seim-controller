// ================================================================
//
// Date  : 9 June, 2026
// Author: Kaan Akan
//
// Creates a naneye_sclk with the frequency of clk / 2 that only
// toggles when sclk_enable is high
//
// ================================================================

`ifndef _NANEYE_CTL_SCLK_GENERATOR_SV_
`define _NANEYE_CTL_SCLK_GENERATOR_SV_

module naneye_ctl_sclk_generator
(
    input  logic clk,
    input  logic rst_n,
    input  logic sclk_enable,

    output logic sclk_rise,
    output logic sclk_fall,
    output logic naneye_sclk
);

    // Hold naneye_sclk low when reset and sclk disabled
    // Otherwise, invert at each clk to get a naneye_sclk = clk / 2
    always_ff @(posedge clk) begin
        if ((!rst_n) || (!sclk_enable)) begin
            naneye_sclk <= 1'b0;
        end
        else if (sclk_enable) begin
            naneye_sclk <= ~naneye_sclk;
        end
    end

    // Signifies if the coming edge is a rising or falling edge
    assign sclk_rise = sclk_enable && !naneye_sclk;
    assign sclk_fall = sclk_enable && naneye_sclk;

endmodule

`endif // _NANEYE_CTL_SCLK_GENERATOR_SV_
