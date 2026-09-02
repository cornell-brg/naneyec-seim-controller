// ================================================================
//
// Date  : 20 June, 2026
// Author: Kaan Akan
//
// A serial input/output bit controller to abstract the read and
// write on the bidirectional sdat pin
//
// ================================================================

`ifndef _NANEYE_CTL_SERIAL_IO_SV_
`define _NANEYE_CTL_SERIAL_IO_SV_

module naneye_ctl_serial_io
(
    input  logic clk,
    input  logic rst_n,

    input  logic sclk_enable,

    input  logic write_enable,
    input  logic write_bit,

    output logic read_bit,

    output logic sclk_rise,
    output logic sclk_fall,
    output logic naneye_sclk,

    inout  wire  naneye_sdat
);

    naneye_ctl_sclk_generator sclk_generator (
        .clk         (clk),
        .rst_n       (rst_n),
        .sclk_enable (sclk_enable),
        .sclk_rise   (sclk_rise),
        .sclk_fall   (sclk_fall),
        .naneye_sclk (naneye_sclk)
    );

    assign naneye_sdat = write_enable ? write_bit : 1'bz;
    assign read_bit    = naneye_sdat;
endmodule

`endif // _NANEYE_CTL_SERIAL_IO_SV_
