
// ================================================================
//
// Date  : 30 Aug, 2026
// Author: Kaan Akan
//
// FSM output and next state logic for the naneye_ctl module.
//
// ================================================================

`ifndef _NANEYE_CTL_FSM_SV_
`define _NANEYE_CTL_FSM_SV_

`include "naneye_ctl_state_pkg.sv"

module naneye_ctl_fsm #(
    parameter int          WAITCLKS   = 1000,
    parameter int          IMAGE_ROWS = 320,
    parameter int          IMAGE_COLS = 320,
    parameter logic [23:0] REG0_CFG   = '0,
    parameter logic [23:0] REG1_CFG   = '0,
    parameter int          ROW_COUNT_WIDTH = $clog2(IMAGE_ROWS)
)(
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic                       start,
    input  logic                       readout_sync_go,
    input  logic                       phase_count_done,
    input  logic                       row_start_found,
    input  logic                       eof_valid,
    input  logic [ROW_COUNT_WIDTH-1:0] row_count,
    input  logic [3:0]                 invalid_pixel_count,
    input  logic [23:0]                phase_count,
    input  logic [3:0]                 pixel_bit_count,
    input  logic                       sclk_fall,
    input  logic [11:0]                pixel_word_received,

    output naneye_ctl_state_pkg::naneye_ctl_state_t current_state,
    output naneye_ctl_state_pkg::naneye_ctl_state_t next_state,
    output logic [23:0]                state_defined_phase_limit,
    output logic                       sclk_enable,
    output logic                       naneye_sdat_out_en,
    output logic                       naneye_sdat_out,
    output logic                       valid,
    output logic                       pixel_word_ok,
    output logic                       readout_sync_ready
);
    import naneye_ctl_state_pkg::*;

    localparam int PIXEL_SCLKS                   = 12;
    localparam int REGWR_SCLKS                   = 2 * PIXEL_SCLKS;
    localparam int ROW_TRAIN_SCLKS               = 8 * PIXEL_SCLKS;
    localparam int ROW_DATA_SCLKS                = IMAGE_COLS * PIXEL_SCLKS;
    localparam int EOF_SCLKS                     = 8 * PIXEL_SCLKS;
    localparam int INTERFACE_SCLKS               = 648 * PIXEL_SCLKS;
    localparam int ST_FIND_READOUT_TIMEOUT_SCLKS = 1000 * (IMAGE_COLS + 8) * PIXEL_SCLKS;

    // State register
    always_ff @(posedge clk) begin : state_register
        if (!rst_n) begin
            current_state <= ST_IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

    // Next-state logic
    always_comb begin : next_state_logic
        // Default for matching current_state whose condition wasn't met
        next_state = current_state;

        // Match current_state
        case (current_state)
            ST_IDLE: begin
                if (start) begin
                    next_state = ST_ACTIVATE;
                end
            end

            ST_ACTIVATE: begin
                if (phase_count_done) begin
                    next_state = ST_REG0_CFG;
                end
            end

            ST_REG0_CFG: begin
                if (phase_count_done) begin
                    next_state = ST_REG1_CFG;
                end
            end

            ST_REG1_CFG: begin
                if (phase_count_done) begin
                    next_state = ST_WAIT;
                end
            end

            ST_WAIT: begin
                if (phase_count_done) begin
                    next_state = ST_FIND_READOUT;
                end
            end

            ST_FIND_READOUT: begin
                if (row_start_found) begin
                    next_state = ST_READOUT_SYNC_BETWEEN_SENSORS;
                end
                // The phase_count_done condition is an extra safety measure
                // to recognize if there are no start of frames detected in a limit
                // and goes to ST_INTERFACE to configure the registers again
                else if (phase_count_done) begin
                    next_state = ST_INTERFACE;
                end
            end

            ST_READOUT_SYNC_BETWEEN_SENSORS : begin
                if (readout_sync_go) begin
                    next_state = ST_ROW_DATA;
                end
            end

            ST_ROW_TRAIN: begin
                if (phase_count_done) begin
                    next_state = ST_ROW_DATA;
                end
            end

            ST_ROW_DATA: begin
                if (phase_count_done) begin
                    // Each row corresponds to a phase count done which
                    // increments row count 0 to 319 <-> (0, IMGROWS-1)
                    if (row_count == ROW_COUNT_WIDTH'(IMAGE_ROWS - 1)) begin
                        next_state = ST_EOF;
                    end
                    else begin
                        next_state = ST_ROW_TRAIN;
                    end
                end
            end

            ST_EOF: begin
                if (phase_count_done) begin
                    next_state = eof_valid &&
                                 invalid_pixel_count < 4'd11 ?
                                 ST_INTERFACE : ST_FIND_READOUT;
                    end
            end

            ST_INTERFACE: begin
                if (phase_count_done) begin
                    next_state = ST_FIND_READOUT;
                end
            end

            // Default for non-matching current_state
            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end

    // Output logic
    always_comb begin : output_logic

        sclk_enable               = 1'b0;  // Controls NanEye sclk
        state_defined_phase_limit = 24'd1; // Phase limit defined by state or row
        naneye_sdat_out_en        = 1'b0;  // Control if naneye_sdat is read or written
        naneye_sdat_out           = 1'b0;  // Prevent an inferred latch; tristating is handled above
        valid                     = 1'b0;  // Sets valid high when bit counter reaches PIXEL_SCLKS
        pixel_word_ok             = 1'b0;  // Sets pixel_word_ok (start, stop bit match + bit_counter done)
        readout_sync_ready        = 1'b0;  // Sync the two NanEye readout streams

        case (current_state)

            ST_IDLE: begin
                sclk_enable               = 1'b0;
                state_defined_phase_limit = 24'd1;
                naneye_sdat_out_en        = 1'b0;
            end

            ST_ACTIVATE: begin
                sclk_enable               = 1'b1;
                state_defined_phase_limit = 24'd1;
                naneye_sdat_out_en        = 1'b0;
            end

            ST_REG0_CFG: begin
                sclk_enable               = 1'b1;
                state_defined_phase_limit = 24'(REGWR_SCLKS);
                naneye_sdat_out_en        = 1'b1;
                // Write config bit based on phase counter from MSB to LSB
                naneye_sdat_out = REG0_CFG[5'd23 - phase_count[4:0]];
            end

            ST_REG1_CFG: begin
                sclk_enable               = 1'b1;
                state_defined_phase_limit = 24'(REGWR_SCLKS);
                naneye_sdat_out_en        = 1'b1;
                naneye_sdat_out = REG1_CFG[5'd23 - phase_count[4:0]];
            end

            ST_WAIT: begin
                sclk_enable               = 1'b0;
                state_defined_phase_limit = 24'(WAITCLKS);
                naneye_sdat_out_en        = 1'b0;
            end

            ST_ROW_TRAIN: begin
                sclk_enable               = 1'b1;
                state_defined_phase_limit = 24'(ROW_TRAIN_SCLKS);
                naneye_sdat_out_en        = 1'b0;
            end

            ST_ROW_DATA: begin
                sclk_enable               = 1'b1;
                state_defined_phase_limit = 24'(ROW_DATA_SCLKS);
                naneye_sdat_out_en        = 1'b0;
                valid = (pixel_bit_count == 4'(PIXEL_SCLKS - 1)) && sclk_fall;
                pixel_word_ok = valid &&
                        pixel_word_received[PIXEL_SCLKS-1] &&
                        !pixel_word_received[0];
            end

            ST_EOF: begin
                sclk_enable               = 1'b1;
                state_defined_phase_limit = 24'(EOF_SCLKS);
                naneye_sdat_out_en        = 1'b0;
            end

            ST_FIND_READOUT: begin
                // The phase limit provides a timeout rather than the normal transition condition
                sclk_enable               = 1'b1;
                naneye_sdat_out_en        = 1'b0;
                state_defined_phase_limit = 24'(ST_FIND_READOUT_TIMEOUT_SCLKS);
            end

            ST_READOUT_SYNC_BETWEEN_SENSORS : begin
                sclk_enable        = 1'b0; // Stop sclk while waiting for sync
                naneye_sdat_out_en = 1'b0;
                readout_sync_ready = 1'b1;
            end

            // Rewrite the configuration registers in each interface state
            ST_INTERFACE: begin
                sclk_enable               = 1'b1;
                state_defined_phase_limit = 24'(INTERFACE_SCLKS);

                if (phase_count < 24'd24) begin
                    naneye_sdat_out_en = 1'b1;
                    naneye_sdat_out    = REG0_CFG[5'd23 - phase_count[4:0]];
                end
                else if (phase_count < 24'd48) begin
                    naneye_sdat_out_en = 1'b1;
                    naneye_sdat_out    = REG1_CFG[5'(6'd47 - phase_count[5:0])];
                end
                else begin
                    naneye_sdat_out_en = 1'b0;
                end
            end

            default: begin
                sclk_enable               = 1'b0;
                state_defined_phase_limit = 24'd1;
                naneye_sdat_out_en        = 1'b0;
                pixel_word_ok             = 1'b0;
                naneye_sdat_out           = 1'b0;
                readout_sync_ready        = 1'b0;
            end

        endcase
    end
endmodule

`endif // _NANEYE_CTL_FSM_SV_
