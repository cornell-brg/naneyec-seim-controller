module naneye_scene_rom #(
    parameter int ROWS = 320,
    parameter int COLS = 320,
    parameter int PIXELBITS = 10,
    parameter string MEM_FILE = "data/test_image_320x320_grayscale_10bit.mem"
)(
    input  logic                          clk,
    input  logic [$clog2(ROWS*COLS)-1:0]  addr,
    output logic [PIXELBITS-1:0]          pixel
);

    localparam int DEPTH = ROWS * COLS;

    logic [PIXELBITS-1:0] mem [0:DEPTH-1];

    initial begin
        $readmemb(MEM_FILE, mem);
    end

    always_ff @(posedge clk) begin
        pixel <= mem[addr];
    end

endmodule
