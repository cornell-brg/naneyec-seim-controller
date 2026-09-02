// ================================================================
//
// Date  : June 8, 2026
// Author: Kaan Akan
//
// NanEyeC interface controller. Sets NanEye registers, reads out pixel
// values, syncs as appropriate using EOF pattern.
//
// ================================================================

`ifndef _NANEYE_CTL_SV_
`define _NANEYE_CTL_SV_

`include "naneye_ctl_state_pkg.sv"

module naneye_ctl #(
    parameter OUTBITS    = 8,                 // number of data bits in pixel word
    parameter WAITCLKS   = 1000,              // wait cycles before sync after interface
    // NanEye config register 0 fields
    parameter logic [7:0] RESET_ROWS = 8'h60, // sets 194 rows for reset
    parameter logic [1:0] PIXEL_VRST = 2'b10, // recommended: pixel reset voltage of 2.6V
    parameter logic [1:0] RAMP_GAIN  = 2'b01, // default: ramp gain of 1
    parameter logic [1:0] RAMP_OFFS  = 2'b11, // recommended: ramp offset voltage of 2.2V
    parameter logic [1:0] OUT_CURR   = 2'b01, // default: sets LVDS/SEIM output current
    // NanEye config register 1 fields
    parameter logic [4:0] ROWS_DELAY = 5'h00, // default: sets 2 rows period for delay duration
    parameter logic       BIAS_INCR  = 1'b1,  // non-default: sets 2x bias current for high speed
    parameter logic       CDS_GAIN   = 1'b0,  // recommended: CDS gain of 1.3
    parameter logic       OUT_MODE   = 1'b0,  // non-default: output set to SEIM (single-wire) instead of LVDS (differential signaling)
    parameter logic [1:0] MCLK_MODE  = 2'b00, // non-default: NanEye clock set to (main clock x 2)
    parameter logic [1:0] CDS_VREF   = 2'b10, // recommended: sets CDS voltage reference to 2.1V
    parameter logic [1:0] CVC_CURR   = 2'b01, // recommended
    parameter logic       IDLE_MODE  = 1'b0,  // non-default: idle mode disabled
    parameter logic       MCLK_HSPD  = 1'b0,   //default

    // NanEyeC is actually 320x320. These parameters allow testbenches
    // to use a short synthetic frame.
    parameter IMAGE_ROWS = 320,
    parameter IMAGE_COLS = 320
    )(
    input  logic clk,
    input  logic rst_n,
    input  logic start,           // allows delay after power up for booting
    input  logic readout_sync_go, // optional signal to synchronize multiple sensors

    inout  wire  naneye_sdat, // driven in config, tristated in readout
    output logic naneye_sclk, // clock driving naneye internals

    output logic [OUTBITS-1:0] pixel,             // streamed pixel data
    output logic               valid,             // based on bit counter only
    output logic               frame_pulse,       // pulses after frame complete
    output logic               readout_sync_ready // sends sync ready signal when readout is found
    );
    import naneye_ctl_state_pkg::*;

    localparam PIXEL_SCLKS = 12;

    // pixel_word is the full captured pixel word in the format
    // { start=1, pixel[9:0], stop=0 }

    /* verilator lint_off UNUSEDSIGNAL */
    logic [PIXEL_SCLKS-1:0] pixel_word;
    /* verilator lint_on UNUSEDSIGNAL */

    // High when bit counter is done and start, stop bits match format:
    // { start, pixel[9:0], stop }
    logic pixel_word_ok;

    // pixel_word_received is used to compensate for the last
    // pixel bit that isn't shifted into the register during the last cycle
    logic [PIXEL_SCLKS-1:0] pixel_word_received;

    // Phase counter, used for pixel or row counting inside state
    logic [23:0] phase_count;
    logic        phase_count_done;
    logic        clear_count;

    // Pulses when the first pixel start bit is found after a long
    // alternating training pattern.
    logic row_start_found;

    // Clears phase counter in state transitions except for the transition
    // from ST_READOUT_SYNC_BETWEEN_SENSORS to ST_ROW_DATA because data should sit
    // and bit counter should be preserved while waiting
    assign clear_count = (current_state != next_state) &&
                       !((current_state == ST_READOUT_SYNC_BETWEEN_SENSORS) &&
                         (next_state    == ST_ROW_DATA));

    // Parameters and concatenations for register writes
    localparam logic [3:0] UPCODE = 4'b1001;
    localparam logic [2:0] REG0   = 3'b000;
    localparam logic [2:0] REG1   = 3'b001;
    localparam logic       RSTBIT = 1'b0;

    localparam logic [23:0] REG0_CFG = {
        UPCODE,
        REG0,
        RESET_ROWS,
        PIXEL_VRST,
        RAMP_GAIN,
        RAMP_OFFS,
        OUT_CURR,
        RSTBIT
    };

    localparam logic [23:0] REG1_CFG = {
        UPCODE,
        REG1,
        ROWS_DELAY,
        BIAS_INCR,
        CDS_GAIN,
        OUT_MODE,
        MCLK_MODE,
        CDS_VREF,
        CVC_CURR,
        IDLE_MODE,
        MCLK_HSPD,
        RSTBIT
    };

    naneye_ctl_state_t current_state;
    naneye_ctl_state_t next_state;

    localparam ROW_COUNT_WIDTH = $clog2(IMAGE_ROWS);
    logic [ROW_COUNT_WIDTH-1:0] row_count;

    assign frame_pulse = (current_state == ST_ROW_DATA) &&
                         (phase_count_done) &&
                         (row_count == ROW_COUNT_WIDTH'(IMAGE_ROWS - 1));

    logic [23:0] state_defined_phase_limit;
    logic        sclk_enable;
    logic        sclk_fall;
    /* verilator lint_off UNUSEDSIGNAL */
    logic        sclk_rise;
    /* verilator lint_on UNUSEDSIGNAL */

    // The ternary operator is necessary because sclk_fall doesn't go high
    // in ST_WAIT, as sclk_generator has sclk_enable low in ST_WAIT
    logic  phase_counter_enable;

    // Also, enabling phase counter only when sclk fall is high prevents
    // from counting every clk (which would give 2x of the sclk) and the
    // proper sclk change amount instead. Could use rise also, but better
    // to use fall as sdat is changed in rising sclk by NanEye
    assign phase_counter_enable = (current_state == ST_WAIT) ? 1'b1 : sclk_fall;

    naneye_ctl_phase_counter #(
        .WIDTH (24)
    ) phase_counter
    (
        .clk         (clk),
        .rst_n       (rst_n),
        .clear       (clear_count),
        .enable      (phase_counter_enable),
        .phase_limit (state_defined_phase_limit),
        .count       (phase_count),
        .done        (phase_count_done),
        // Enables starting phase counter from 1 when start of row bit
        // had already been sampled in eof search state
        .load       (row_start_found),
        .load_value (24'd1)
    );

    // RTL readout row counter
    always_ff @(posedge clk) begin : readout_row_counter
        // Reset row counter at end of ST_FIND_READOUT mode, just before readout
        if (!rst_n || row_start_found) begin
            row_count <= '0;
        end

        // Increment row count when one st_row_data finishes
        else if (phase_count_done && (current_state == ST_ROW_DATA)) begin
            row_count <= row_count + 1'b1;
        end

    end

    // Serial data output and output enable logic to control when
    // naneye_sdat is being written to configure and tristated to be read
    logic naneye_sdat_out;
    logic naneye_sdat_out_en;
    logic naneye_sdat_in;

    naneye_ctl_serial_io serial_io (
        .clk          (clk),
        .rst_n        (rst_n),
        .sclk_enable  (sclk_enable),
        .write_enable (naneye_sdat_out_en),
        .write_bit    (naneye_sdat_out),
        .read_bit     (naneye_sdat_in),
        .sclk_rise    (sclk_rise),
        .sclk_fall    (sclk_fall),
        .naneye_sclk  (naneye_sclk),
        .naneye_sdat  (naneye_sdat)
    );

    // Shift register to store pixel value, samples every clk
    // but is enabled only when in RD_ROW_DATA and in sclk_fall cycle
    naneye_ctl_shift_register_pixel_sclks_wide #(
        .PIXEL_SCLKS (PIXEL_SCLKS)
    ) shift_register
    (
        .clk        (clk),
        .rst_n      (rst_n),
        .data       (naneye_sdat_in),
        // Also enabled in ST_FIND_READOUT to better handle EOF search
        // to readout transition
        .enable     (sclk_fall && ((current_state == ST_ROW_DATA) ||
                                   (current_state == ST_FIND_READOUT))),
        .pixel_word (pixel_word)
    );

    // Take 10th to 3rd bit or more generally PIXEL_SCLKS-2 to PIXEL_SCLKS-2-OUTBITS+1
    // if pixel_word_ok high (so matches start,stop bit) and 0 if it doesn't

    assign pixel_word_received = {pixel_word[PIXEL_SCLKS-2:0],naneye_sdat_in};
    assign pixel = pixel_word_ok ?
                   pixel_word_received[PIXEL_SCLKS-2:PIXEL_SCLKS-2-OUTBITS+1] :
                   '0;

    // EOF valid detector
    logic  eof_valid;
    logic  eof_valid_detector_enable;
    assign eof_valid_detector_enable = sclk_fall && (current_state == ST_EOF);

    naneye_ctl_eof_valid_detector naneye_ctl_eof_valid_detector
    (
        .clk               (clk),
        .rst_n             (rst_n),
        // resets bad_bit_detected at state transitions
        .clear             (clear_count),
        .enable            (eof_valid_detector_enable),
        .sdat              (naneye_sdat_in),
        .eof_valid         (eof_valid)
    );

    naneye_ctl_frame_aligner #(
        .MIN_ALTERNATING_BITS ((IMAGE_COLS + 8) * PIXEL_SCLKS)
    )frame_aligner
    (
        .clk             (clk),
        .rst_n           (rst_n),
        .clear           (clear_count),
        .enable          (sclk_fall && current_state == ST_FIND_READOUT),
        .sdat            (naneye_sdat_in),
        .row_start_found (row_start_found)
    );

    // Invalid pixel counter to enable frame alignment when necessary
    // even when EOF frame pattern seems to work
    logic [3:0] invalid_pixel_count;

    always_ff @(posedge clk) begin : invalid_pixel_counter
        if (!rst_n || row_start_found) begin
            invalid_pixel_count <= '0;
        end
        else if (valid && !pixel_word_ok) begin
            // Threshold for invalid pixel count is 10
            if (invalid_pixel_count < 4'd11)
                invalid_pixel_count <= invalid_pixel_count + 1'b1;
        end
    end

    // RTL pixel bit counter
    logic [$clog2(PIXEL_SCLKS)-1:0] pixel_bit_count;

    always_ff @(posedge clk) begin : pixel_bit_counter
        if (!rst_n) begin
            pixel_bit_count <= '0;
        end
        else if (row_start_found) begin
            // Pixel start bit captured on same edge when transitioning
            // from sync to readout
            pixel_bit_count <= 4'd1;
        end

        // Reset pixel bit counter at ST_FIND_READOUT mode, which is before readout
        else if (current_state == ST_FIND_READOUT) begin
            pixel_bit_count <= '0;
        end

        else if ((current_state == ST_ROW_DATA) && sclk_fall) begin

            // Reset pixel bit count when it reaches PIXEL_SCLKS
            if (pixel_bit_count == PIXEL_SCLKS - 1) begin
                pixel_bit_count <= '0;
            end

            // Increment pixel bit count when in readout mode
            else begin
                pixel_bit_count <= pixel_bit_count + 1'b1;
            end
        end
    end

    // State sequencing and state-dependent controller outputs
    naneye_ctl_fsm #(
        .WAITCLKS       (WAITCLKS),
        .IMAGE_ROWS     (IMAGE_ROWS),
        .IMAGE_COLS     (IMAGE_COLS),
        .REG0_CFG       (REG0_CFG),
        .REG1_CFG       (REG1_CFG),
        .ROW_COUNT_WIDTH(ROW_COUNT_WIDTH)
    ) fsm (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .start                    (start),
        .readout_sync_go          (readout_sync_go),
        .phase_count_done         (phase_count_done),
        .row_start_found          (row_start_found),
        .eof_valid                (eof_valid),
        .row_count                (row_count),
        .invalid_pixel_count      (invalid_pixel_count),
        .phase_count              (phase_count),
        .pixel_bit_count          (pixel_bit_count),
        .sclk_fall                (sclk_fall),
        .pixel_word_received      (pixel_word_received),
        .current_state            (current_state),
        .next_state               (next_state),
        .state_defined_phase_limit(state_defined_phase_limit),
        .sclk_enable              (sclk_enable),
        .naneye_sdat_out_en       (naneye_sdat_out_en),
        .naneye_sdat_out          (naneye_sdat_out),
        .valid                    (valid),
        .pixel_word_ok            (pixel_word_ok),
        .readout_sync_ready       (readout_sync_ready)
    );

endmodule

`endif // _NANEYE_CTL_SV_
