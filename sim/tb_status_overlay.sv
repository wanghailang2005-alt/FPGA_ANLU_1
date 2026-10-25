`timescale 1ns/1ps
module tb_status_overlay;
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
    reg image_valid=0, auto_play=0;
    reg [1:0] image_index=0;
    osd_overlay #(.STATUS_MODE(1), .SCROLL_ENABLE(0)) dut (
        .image_valid(image_valid), .image_index(image_index), .auto_play(auto_play),
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
                8'h20: bitmap = 64'h0000000000000000;
                8'h2b: bitmap = 64'h0018187e18180000;
                8'h2d: bitmap = 64'h0000007e00000000;
                8'h2e: bitmap = 64'h0000000000181800;
                8'h2f: bitmap = 64'h0003060c18306000;
                8'h30: bitmap = 64'h3c666e7666663c00;
                8'h31: bitmap = 64'h1818381818187e00;
                8'h32: bitmap = 64'h3c66060c30607e00;
                8'h33: bitmap = 64'h3c66061c06663c00;
                8'h34: bitmap = 64'h060e1e667f060600;
                8'h35: bitmap = 64'h7e607c0606663c00;
                8'h36: bitmap = 64'h3c66607c66663c00;
                8'h37: bitmap = 64'h7e660c1818181800;
                8'h38: bitmap = 64'h3c66663c66663c00;
                8'h39: bitmap = 64'h3c66663e06663c00;
                8'h3a: bitmap = 64'h0018180018180000;
                8'h3b: bitmap = 64'h0018180018183000;
                8'h41: bitmap = 64'h183c667e66666600;
                8'h42: bitmap = 64'h7c66667c66667c00;
                8'h43: bitmap = 64'h3c66606060663c00;
                8'h44: bitmap = 64'h786c6666666c7800;
                8'h45: bitmap = 64'h7e60607860607e00;
                8'h46: bitmap = 64'h7e60607860606000;
                8'h47: bitmap = 64'h3c66606e66663c00;
                8'h48: bitmap = 64'h6666667e66666600;
                8'h49: bitmap = 64'h3c18181818183c00;
                8'h4a: bitmap = 64'h1e0c0c0c0c6c3800;
                8'h4b: bitmap = 64'h666c7870786c6600;
                8'h4c: bitmap = 64'h6060606060607e00;
                8'h4d: bitmap = 64'h63777f6b63636300;
                8'h4e: bitmap = 64'h66767e7e6e666600;
                8'h4f: bitmap = 64'h3c66666666663c00;
                8'h50: bitmap = 64'h7c66667c60606000;
                8'h51: bitmap = 64'h3c666666663c0e00;
                8'h52: bitmap = 64'h7c66667c786c6600;
                8'h53: bitmap = 64'h3c66603c06663c00;
                8'h54: bitmap = 64'h7e18181818181800;
                8'h55: bitmap = 64'h6666666666663c00;
                8'h56: bitmap = 64'h66666666663c1800;
                8'h57: bitmap = 64'h6363636b7f776300;
                8'h58: bitmap = 64'h66663c183c666600;
                8'h59: bitmap = 64'h6666663c18181800;
                8'h5a: bitmap = 64'h7e060c1830607e00;
                default: bitmap = 64'h0000000000000000;
            endcase
        end
    endfunction

    function [23:0] reference_rgb;
        input en, de;
        input [9:0] x;
        input [8:0] y;
        input [23:0] background;
        reg [63:0] message;
        reg [63:0] whole;
        integer index, local_col, local_row;
        reg foreground;
        begin
            reference_rgb = de ? background : 24'd0;
            if (en && de && x>=16 && x<80 &&
                ((y>=16 && y<32) || (y>=40 && y<56))) begin
                if(y<32) begin
                    message={"IMG:",(image_valid ? (8'h31+{6'd0,image_index}):8'h2d),"   "};
                    local_row=(y-16)/2;
                end else begin
                    message=auto_play ? "AUTO:ON " : "AUTO:OFF";
                    local_row=(y-40)/2;
                end
                index=(x-16)/8;
                local_col=(x-16)%8;
                whole=bitmap((message >> ((7-index)*8)) & 255);
                foreground=(whole >> (63-local_row*8-local_col)) & 1;
                if(foreground) reference_rgb=24'h000000;
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
                    out_y >= 8 && out_y < 72)
                    $fdisplay(ppm_file, "%0d %0d %0d",
                              out_rgb[23:16], out_rgb[15:8], out_rgb[7:0]);
            end
        end
    end

    initial begin
        #60000000;
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

        ppm_file = $fopen("../evidence/status_osd_crop.ppm", "w");
        if (!ppm_file) $fatal(1, "FAIL preview open");
        $fdisplay(ppm_file, "P3");
        $fdisplay(ppm_file, "96 64");
        $fdisplay(ppm_file, "255");
        // Three complete 800x525 timings: enabled, bypass, enabled again.
        // The 100 MHz simulation clock is a test clock, not a board pixel clock.
        for (frame_i = 0; frame_i < 11; frame_i = frame_i + 1) begin
            for (v = 0; v < 525; v = v + 1) begin
                for (h = 0; h < 800; h = h + 1) begin
                    @(negedge clk);
                    enable = (frame_i != 10);
                    image_valid=(frame_i>=2);
                    image_index=(frame_i-2)/2;
                    auto_play=frame_i%2;
                    capture = (frame_i == 7);
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
        if (active_pixels != 11*640*480)
            $fatal(1, "FAIL active pixel count=%0d", active_pixels);
        if (black_pixels == 0) $fatal(1, "FAIL no foreground pixels");
        test_passed = 1;
        $display("SIM PASS: status overlay checks=%0d active_pixels=%0d foreground_pixels=%0d; 11 full frames, all indices/invalid/AUTO/bypass, reset, 3 stages.",
                 checks, active_pixels, black_pixels);
        $finish;
    end
endmodule
