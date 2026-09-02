// ================================================================
//
// Date  : 8 June, 2026
// Author: Kaan Akan
//
// Outputs the current count and count done signals for naneye_ctl
// in-state phase counting
//
// ================================================================

`ifndef _NANEYE_CTL_PHASE_COUNTER_SV_
`define _NANEYE_CTL_PHASE_COUNTER_SV_

module naneye_ctl_phase_counter #(
    parameter int WIDTH = 24
    )(
    input  logic             clk,
    input  logic             rst_n,

    input  logic             clear,
    input  logic             enable,
    input  logic [WIDTH-1:0] phase_limit,

    input  logic             load,
    input  logic [WIDTH-1:0] load_value,

    output logic [WIDTH-1:0] count,
    output logic             done
);

    assign done = enable &&
                  (phase_limit != '0) &&
                  (count == (phase_limit - 1'b1));

    always_ff @(posedge clk) begin
        if ((!rst_n)) begin
            count <= '0;
        end
        else if (load) begin
            count <= load_value;
        end
        // Load needs priority over clear because the state transition would also
        // caue clear from eof_search to readout
        else if (clear) begin
            count <= '0;
        end
        else if (enable) begin
            count <= done ? '0 : count + 1'b1;
        end
    end

endmodule

`endif // _NANEYE_CTL_PHASE_COUNTER_SV_
