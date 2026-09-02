module tb_naneye_controller_large_image;

    tb_naneye_controller_base #(
        .IMAGE_ROWS (320),
        .IMAGE_COLS (320),
        .MEM_FILE   ("data/test_image_320x320_grayscale_10bit.mem"),
        .TRACE_FILE ("tb_naneye_controller_large_image.fst")
    ) tb();

endmodule
