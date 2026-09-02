module tb_naneye_controller_small_image;

    tb_naneye_controller_base #(
        .IMAGE_ROWS (8),
        .IMAGE_COLS (8),
        .MEM_FILE   ("data/test_image_8x8_grayscale_10bit.mem"),
        .TRACE_FILE ("tb_naneye_controller_small_image.fst")
    ) tb();

endmodule
