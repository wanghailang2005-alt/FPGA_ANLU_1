`timescale 1ns/1ps
module tb_osd_overlay;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, enable = 0;
    reg [23:0] in_rgb = 0;
    reg in_de = 0, in_hs = 0, in_vs = 0;
    reg [9:0] in_x = 0;
    reg [8:0] in_y = 0;
    wire [23:0] out_rgb;
    wire out_de, out_hs, out_vs;
    wire [9:0] out_x;
    wire [8:0] out_y;
    reg test_passed = 0;
    reg [45:0] q0 = 0, q1 = 0, expected;
    integer checks = 0, active_pixels = 0, black_pixels = 0;
    integer frame_i, h, v, drain_i;
    integer ppm_file;
    reg [7:0] bg_r, bg_g, bg_b;
    reg capture = 0;
    osd_overlay dut (
        .clk(clk), .rst(rst), .enable(enable),
        .in_rgb(in_rgb), .in_de(in_de), .in_hs(in_hs), .in_vs(in_vs),
        .in_x(in_x), .in_y(in_y), .out_rgb(out_rgb),
        .out_de(out_de), .out_hs(out_hs), .out_vs(out_vs),
        .out_x(out_x), .out_y(out_y)
    );

    // Independent artwork fixtures for the eight letters in HELLO FPGA.
    function [63:0] bitmap;
        input [7:0] code;
        begin
            case (code)
                "H": bitmap = 64'h6666667e66666600;
                "E": bitmap = 64'h7e60607860607e00;
                "L": bitmap = 64'h6060606060607e00;
                "O": bitmap = 64'h3c66666666663c00;
                "F": bitmap = 64'h7e60607860606000;
                "P": bitmap = 64'h7c66667c60606000;
                "G": bitmap = 64'h3c66606e66663c00;
                "A": bitmap = 64'h183c667e66666600;
                default: bitmap = 0;
            endcase
        end
    endfunction

    function [23:0] reference_rgb;
        input en, de;
        input [9:0] x;
        input [8:0] y;
        input [23:0] background;
        reg [79:0] message;
        reg [63:0] whole;
        integer index, local_col, local_row;
        reg foreground;
        begin
            message = "HELLO FPGA";
            reference_rgb = de ? background : 24'd0;
            if (en && de && x >= 16 && x < 96 && y >= 16 && y < 32) begin
                index = (x - 16) / 8;
                local_col = (x - 16) % 8;
                local_row = (y - 16) / 2;
                whole = bitmap((message >> ((9-index)*8)) & 255);
                foreground = (whole >> (63 - local_row*8 - local_col)) & 1;
                if (foreground) reference_rgb = 24'h000000;
            end
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            q0 = 0;
            q1 = 0;
            #1;
            checks = checks + 1;
            if ({out_de,out_hs,out_vs,out_x,out_y,out_rgb} !== 46'd0)
                $fatal(1, "FAIL reset t=%0t", $time);
        end else begin
            // Three registers: a request sampled at N appears after N+2.
            expected = q1;
            q1 = q0;
            q0 = {in_de,in_hs,in_vs,in_x,in_y,
                  reference_rgb(enable,in_de,in_x,in_y,in_rgb)};
            #1;
            checks = checks + 1;
            if ({out_de,out_hs,out_vs,out_x,out_y,out_rgb} !== expected)
                $fatal(1, "FAIL t=%0t x=%0d y=%0d got=%012h expected=%012h",
                       $time, expected[42:33], expected[32:24],
                       {out_de,out_hs,out_vs,out_x,out_y,out_rgb}, expected);
            if (out_de) begin
                active_pixels = active_pixels + 1;
                if (out_rgb == 24'h000000) black_pixels = black_pixels + 1;
                if (capture && out_x >= 8 && out_x < 104 &&
                    out_y >= 8 && out_y < 40)
                    $fdisplay(ppm_file, "%0d %0d %0d",
                              out_rgb[23:16], out_rgb[15:8], out_rgb[7:0]);
            end
        end
    end

    initial begin
        #15000000;
        $fatal(1, "FAIL timeout");
    end

    initial begin
        #2;
        if ($test$plusargs("FORCE_FAIL"))
            $fatal(1, "FAIL intentional harness check");
        repeat (2) @(negedge clk);
        rst = 0;
        // Fill in-flight stages, then reset in the middle of an active glyph.
        @(negedge clk);
        enable = 1; in_de = 1; in_x = 18; in_y = 16; in_rgb = 24'h123456;
        repeat (2) @(negedge clk);
        #2 rst = 1;
        #2;
        if ({out_de,out_hs,out_vs,out_x,out_y,out_rgb} !== 46'd0)
            $fatal(1, "FAIL asynchronous pipeline reset");
        @(negedge clk);
        in_de = 0; in_hs = 0; in_vs = 0; in_x = 0; in_y = 0; in_rgb = 0;
        rst = 0;
        repeat (4) @(negedge clk);
        active_pixels = 0;
        black_pixels = 0;

        ppm_file = $fopen("../evidence/hello_fpga_crop.ppm", "w");
        if (!ppm_file) $fatal(1, "FAIL preview open");
        $fdisplay(ppm_file, "P3");
        $fdisplay(ppm_file, "96 32");
        $fdisplay(ppm_file, "255");
        // Three complete 800x525 timings: enabled, bypass, enabled again.
        // The 100 MHz simulation clock is a test clock, not a board pixel clock.
        for (frame_i = 0; frame_i < 3; frame_i = frame_i + 1) begin
            for (v = 0; v < 525; v = v + 1) begin
                for (h = 0; h < 800; h = h + 1) begin
                    @(negedge clk);
                    enable = (frame_i != 1);
                    capture = (frame_i == 0);
                    in_de = (h < 640 && v < 480);
                    in_hs = !(h >= 656 && h < 752);
                    in_vs = !(v >= 490 && v < 492);
                    in_x = in_de ? h : 0;
                    in_y = in_de ? v : 0;
                    bg_r = (h*3 + v + frame_i*31) % 240;
                    bg_g = (h + v*5 + frame_i*17) % 240;
                    bg_b = (h*7 + v*3 + frame_i*11) % 240;
                    in_rgb = {bg_r,bg_g,bg_b}; // Nonzero blanking tests black output.
                end
            end
        end
        @(negedge clk);
        in_de = 0; in_hs = 0; in_vs = 0;
        in_x = 0; in_y = 0; in_rgb = 0; capture = 0;
        repeat (4) @(negedge clk);
        $fclose(ppm_file);
        if (active_pixels != 3*640*480)
            $fatal(1, "FAIL active pixel count=%0d", active_pixels);
        if (black_pixels == 0) $fatal(1, "FAIL no foreground pixels");
        test_passed = 1;
        $display("SIM PASS: overlay checks=%0d active_pixels=%0d foreground_pixels=%0d; 3 full frames, enabled/bypass/enabled, reset, 3 stages.",
                 checks, active_pixels, black_pixels);
        $finish;
    end
endmodule
