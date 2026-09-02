// ================================================================
//
// Simple NanEyeC SEIM sensor model for controller simulation
//
// The state names and phase lengths intentionally mirror naneye_ctl.
// The model advances on rising SCLK edges, where NanEyeC transmits a new
// downstream bit or captures one upstream configuration bit.
//
// ================================================================

`ifndef _NANEYE_EMUL_SV_
`define _NANEYE_EMUL_SV_

module naneye_emul #(
    parameter int         IMAGE_ROWS = 320,
    parameter int         IMAGE_COLS = 320
)(
    input  logic       sclk,
    input  logic [9:0] scene_pixel,
    input  logic       rst_n,

    // Register corruption testing
    input logic       corrupt_rows_delay,
    input logic [4:0] corrupt_rows_delay_value,

    inout  wire  sdat,

    output logic [$clog2(IMAGE_ROWS*IMAGE_COLS)-1:0] scene_addr
);

    localparam logic PIXEL_START   = 1'b1;
    localparam logic PIXEL_STOP    = 1'b0;
    localparam int PIXEL_SCLKS     = 12;
    localparam int PRESYNC_SCLKS   = 10 + ((IMAGE_COLS + 9) * PIXEL_SCLKS);
    localparam int SYNC_SCLKS      = 2 * (IMAGE_COLS + 8) * PIXEL_SCLKS;
    localparam int ROW_TRAIN_SCLKS = 8 * PIXEL_SCLKS;
    localparam int ROW_DATA_SCLKS  = IMAGE_COLS * PIXEL_SCLKS;
    localparam int EOF_SCLKS       = 8 * PIXEL_SCLKS;
    localparam int INTERFACE_SCLKS = 648 * PIXEL_SCLKS;

    localparam logic [3:0]  UPDATE_CODE = 4'b1001;
    localparam logic [2:0]  REG0_ADDR   = 3'b000;
    localparam logic [2:0]  REG1_ADDR   = 3'b001;
    localparam logic [15:0] REG0_RESET  = 16'h0000;
    localparam logic [15:0] REG1_RESET  = 16'h035A;

    localparam int SCENE_ADDR_WIDTH = $clog2(IMAGE_ROWS * IMAGE_COLS);
    localparam int ROW_COUNT_WIDTH =
        (IMAGE_ROWS > 1) ? $clog2(IMAGE_ROWS) : 1;

    localparam int COL_COUNT_WIDTH =
        (IMAGE_COLS > 1) ? $clog2(IMAGE_COLS) : 1;

    typedef enum logic [3:0] {
        ST_ACTIVATE,
        ST_INITIAL_INTERFACE,
        ST_INITIAL_WAIT,
        ST_PRESYNC,
        ST_SYNC,
        ST_DELAY,
        ST_ROW_TRAIN,
        ST_ROW_DATA,
        ST_EOF,
        ST_READOUT_SYNC_BETWEEN_SENSORS,
        ST_INTERFACE
    } state_t;

    state_t current_state;
    state_t next_state;

    logic [23:0] phase_count;
    logic [23:0] phase_limit;
    logic        phase_count_done;

    logic [ROW_COUNT_WIDTH-1:0] row_count;
    logic [COL_COUNT_WIDTH-1:0] col_count;

    logic [15:0] reg0;
    logic [15:0] reg1;

    logic [22:0] config_shift;
    logic [23:0] config_word;
    logic        config_capture;
    logic        config_word_valid;
    logic        reg0_write;
    logic        reg1_write;

    logic [11:0] pixel_word;
    logic [3:0]  pixel_bit_count;
    logic        sdat_out;
    logic        sdat_out_delayed;
    logic        sdat_out_en;
    int unsigned sdat_delay_ns;

    logic [8:0] delay_rows;

    assign delay_rows = (9'(reg1[15:11]) << 4) + 9'd2;
    assign pixel_bit_count = 4'(phase_count % 24'(PIXEL_SCLKS));

    assign config_word = {config_shift, (sdat === 1'b1) ? 1'b1 : 1'b0};
    assign config_word_valid = (config_word[23:20] == UPDATE_CODE) && !config_word[0];
    assign reg0_write = config_capture && config_word_valid &&
                        (config_word[19:17] == REG0_ADDR);
    assign reg1_write = config_capture && config_word_valid &&
                        (config_word[19:17] == REG1_ADDR);

    // The first interface bit is sampled on the edge entering ST_INTERFACE
    // so requires (current_state == ST_EOF) && phase_count_done) as well as
    // initial interface
    assign config_capture = (current_state == ST_INITIAL_INTERFACE) ||
                            ((current_state == ST_EOF) && phase_count_done) ||
                            ((current_state == ST_INTERFACE) && !phase_count_done);

    assign phase_count_done =
        (phase_limit != 24'd0) && (phase_count == phase_limit - 1'b1);

    assign scene_addr = SCENE_ADDR_WIDTH'(int'(col_count) + row_count * int'(IMAGE_COLS));
    assign pixel_word = {PIXEL_START, scene_pixel, PIXEL_STOP};

    assign sdat = sdat_out_en
            ? ((sdat_delay_ns == 0) ? sdat_out : sdat_out_delayed)
            : 1'bz;

    initial begin
        sdat_out_delayed = 1'b0;
        sdat_delay_ns    = 0;

        if ($value$plusargs("sdat_delay_ns=%d", sdat_delay_ns) &&
            $test$plusargs("events")) begin
            $display("  event sdat_delay_ns=%0d", sdat_delay_ns);
        end
    end

    always @(sdat_out) begin
        if (sdat_delay_ns != 0) begin
            /* verilator lint_off ZERODLY */
            sdat_out_delayed <= #(sdat_delay_ns) sdat_out;
            /* verilator lint_on ZERODLY */
        end
    end

    always_ff @(posedge sclk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= ST_ACTIVATE;
            phase_count   <= '0;
            row_count     <= '0;
            col_count     <= '0;
            config_shift  <= '0;
            reg0          <= REG0_RESET;
            reg1          <= REG1_RESET;
        end
        else begin
            current_state <= next_state;

            // Phase counter
            if (current_state != next_state)
                phase_count <= '0;
            else if (phase_count_done)
                phase_count <= '0;
            else
                phase_count <= phase_count + 1'b1;

            if (config_capture) begin
                if (reg0_write || reg1_write)
                    config_shift <= '0;
                else
                    config_shift <= config_word[22:0];
            end
            else begin
                config_shift <= '0;
            end

            if (reg0_write)
                reg0 <= config_word[16:1];
            if (reg1_write)
                reg1 <= config_word[16:1];

            if (corrupt_rows_delay)
                reg1[15:11] <= corrupt_rows_delay_value;

            if (phase_count_done && (current_state == ST_DELAY)) begin
                row_count <= '0;
                col_count <= '0;
            end
            else begin
                if (current_state == ST_ROW_TRAIN) begin
                    col_count <= '0;
                end
                else if ((current_state == ST_ROW_DATA) &&
                         ((int'(phase_count) % PIXEL_SCLKS) == (PIXEL_SCLKS - 1))) begin
                    if (col_count == COL_COUNT_WIDTH'(IMAGE_COLS - 1))
                        col_count <= '0;
                    else
                        col_count <= col_count + 1'b1;
                end

                if (phase_count_done && (current_state == ST_ROW_DATA)) begin
                    if (row_count == ROW_COUNT_WIDTH'(IMAGE_ROWS - 1))
                        row_count <= '0;
                    else
                        row_count <= row_count + 1'b1;
                end
            end
        end
    end

    always_comb begin : next_state_logic
        next_state = current_state;

        case (current_state)
            ST_ACTIVATE: begin
                if (phase_count_done)
                    next_state = ST_INITIAL_INTERFACE;
            end

            ST_INITIAL_INTERFACE: begin
                if (reg1_write && !config_word[2])
                    next_state = ST_INITIAL_WAIT;
            end

            // SCLK is stopped by the controller during its wait period.
            // The first edge after that pause starts INITIAL PRE-SYNC.
            ST_INITIAL_WAIT: begin
                if (phase_count_done)
                    next_state = ST_PRESYNC;
            end

            ST_PRESYNC: begin
                if (phase_count_done)
                    next_state = ST_SYNC;
            end

            ST_SYNC: begin
                if (phase_count_done)
                    next_state = ST_DELAY;
            end

            ST_DELAY: begin
                if (phase_count_done)
                    next_state = ST_ROW_TRAIN;
            end

            ST_ROW_TRAIN: begin
                if (phase_count_done)
                    next_state = ST_ROW_DATA;
            end

            ST_ROW_DATA: begin
                if (phase_count_done) begin
                    if (row_count == ROW_COUNT_WIDTH'(IMAGE_ROWS - 1))
                        next_state = ST_EOF;
                    else
                        next_state = ST_ROW_TRAIN;
                end
            end

            ST_EOF: begin
                if (phase_count_done)
                    next_state = ST_INTERFACE;
            end

            ST_INTERFACE: begin
                if (phase_count_done)
                    next_state = ST_SYNC;
            end

            default: next_state = ST_ACTIVATE;
        endcase
    end

    always_comb begin : output_logic
        phase_limit = 24'd1;
        sdat_out_en = 1'b0;
        sdat_out    = 1'b0;

        case (current_state)
            ST_ACTIVATE,
            ST_INITIAL_INTERFACE,
            ST_INITIAL_WAIT: begin
                phase_limit = 24'd1;
            end
            ST_INTERFACE: begin
                phase_limit = 24'(INTERFACE_SCLKS);
            end

            ST_PRESYNC: begin
                phase_limit = 24'(PRESYNC_SCLKS);
                sdat_out_en = 1'b1;
                // Easy way to send alternating bits for the AAA training pattern
                sdat_out    = ~phase_count[0];
            end

            ST_SYNC: begin
                phase_limit = 24'(SYNC_SCLKS);
                sdat_out_en = 1'b1;
                // Easy way to send alternating bits for the 555 training pattern
                sdat_out    = phase_count[0];
            end

            ST_DELAY: begin
                phase_limit = 24'(delay_rows * (IMAGE_COLS + 8) * PIXEL_SCLKS);
                sdat_out_en = 1'b1;
                sdat_out    = phase_count[0];
            end

            ST_ROW_TRAIN: begin
                phase_limit = 24'(ROW_TRAIN_SCLKS);
                sdat_out_en = 1'b1;
                sdat_out    = phase_count[0];
            end

            ST_ROW_DATA: begin
                phase_limit = 24'(ROW_DATA_SCLKS);
                sdat_out_en = 1'b1;
                sdat_out = pixel_word[4'(PIXEL_SCLKS - 1) - pixel_bit_count];
            end

            ST_EOF: begin
                phase_limit = 24'(EOF_SCLKS);
                sdat_out_en = 1'b1;
                sdat_out    = 1'b0;
            end

            default: begin
            end
        endcase
    end

endmodule

`endif // _NANEYE_EMUL_SV_
