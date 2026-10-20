`timescale 1ns/1ps
module tb_osd_glyph_pixel;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg in_valid = 0;
    reg [7:0] char_code = 0;
    reg [2:0] glyph_x = 0;
    reg [3:0] glyph_y = 0;
    wire out_valid, pixel_on;
    reg test_passed = 0;
    reg pending_valid = 0, pending_pixel = 0;
    reg expected_valid = 0, expected_pixel = 0;
    integer pending_code = 0, pending_x = 0, pending_y = 0;
    integer expected_code, expected_x, expected_y;
    integer requests = 0, checks = 0;
    integer code_i, x_i, y_i, i;
    integer preview_file, pbm_file;
    reg [63:0] bitmap;

    osd_glyph_pixel dut (
        .clk(clk), .rst(rst), .in_valid(in_valid),
        .char_code(char_code), .glyph_x(glyph_x), .glyph_y(glyph_y),
        .out_valid(out_valid), .pixel_on(pixel_on)
    );

    function [63:0] golden_bitmap;
        input [7:0] code;
        begin
            case (code)
                8'h20: golden_bitmap = 64'h0000000000000000;
                8'h2b: golden_bitmap = 64'h0018187e18180000;
                8'h2d: golden_bitmap = 64'h0000007e00000000;
                8'h2e: golden_bitmap = 64'h0000000000181800;
                8'h2f: golden_bitmap = 64'h0003060c18306000;
                8'h30: golden_bitmap = 64'h3c666e7666663c00;
                8'h31: golden_bitmap = 64'h1818381818187e00;
                8'h32: golden_bitmap = 64'h3c66060c30607e00;
                8'h33: golden_bitmap = 64'h3c66061c06663c00;
                8'h34: golden_bitmap = 64'h060e1e667f060600;
                8'h35: golden_bitmap = 64'h7e607c0606663c00;
                8'h36: golden_bitmap = 64'h3c66607c66663c00;
                8'h37: golden_bitmap = 64'h7e660c1818181800;
                8'h38: golden_bitmap = 64'h3c66663c66663c00;
                8'h39: golden_bitmap = 64'h3c66663e06663c00;
                8'h3a: golden_bitmap = 64'h0018180018180000;
                8'h3b: golden_bitmap = 64'h0018180018183000;
                8'h41: golden_bitmap = 64'h183c667e66666600;
                8'h42: golden_bitmap = 64'h7c66667c66667c00;
                8'h43: golden_bitmap = 64'h3c66606060663c00;
                8'h44: golden_bitmap = 64'h786c6666666c7800;
                8'h45: golden_bitmap = 64'h7e60607860607e00;
                8'h46: golden_bitmap = 64'h7e60607860606000;
                8'h47: golden_bitmap = 64'h3c66606e66663c00;
                8'h48: golden_bitmap = 64'h6666667e66666600;
                8'h49: golden_bitmap = 64'h3c18181818183c00;
                8'h4a: golden_bitmap = 64'h1e0c0c0c0c6c3800;
                8'h4b: golden_bitmap = 64'h666c7870786c6600;
                8'h4c: golden_bitmap = 64'h6060606060607e00;
                8'h4d: golden_bitmap = 64'h63777f6b63636300;
                8'h4e: golden_bitmap = 64'h66767e7e6e666600;
                8'h4f: golden_bitmap = 64'h3c66666666663c00;
                8'h50: golden_bitmap = 64'h7c66667c60606000;
                8'h51: golden_bitmap = 64'h3c666666663c0e00;
                8'h52: golden_bitmap = 64'h7c66667c786c6600;
                8'h53: golden_bitmap = 64'h3c66603c06663c00;
                8'h54: golden_bitmap = 64'h7e18181818181800;
                8'h55: golden_bitmap = 64'h6666666666663c00;
                8'h56: golden_bitmap = 64'h66666666663c1800;
                8'h57: golden_bitmap = 64'h6363636b7f776300;
                8'h58: golden_bitmap = 64'h66663c183c666600;
                8'h59: golden_bitmap = 64'h6666663c18181800;
                8'h5a: golden_bitmap = 64'h7e060c1830607e00;
                default: golden_bitmap = 64'h0000000000000000;
            endcase
        end
    endfunction

    // A full-glyph reference: choose a linear bit, not a DUT row signal.
    function reference_pixel;
        input [7:0] code;
        input [2:0] x;
        input [3:0] y;
        reg [63:0] whole;
        begin
            whole = golden_bitmap(code);
            reference_pixel = (whole >> (63 - ((y / 2) * 8 + x))) & 1;
        end
    endfunction

    // At each edge the second register must return the PREVIOUS edge's request.
    // Clearing this queue on asynchronous reset discards all in-flight requests.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pending_valid = 0;
            pending_pixel = 0;
            #1;
            checks = checks + 1;
            if (out_valid !== 0 || pixel_on !== 0)
                $fatal(1, "FAIL asynchronous reset t=%0t", $time);
        end else begin
            expected_valid = pending_valid;
            expected_pixel = pending_pixel;
            expected_code = pending_code;
            expected_x = pending_x;
            expected_y = pending_y;
            pending_valid = in_valid;
            pending_pixel = in_valid ? reference_pixel(char_code, glyph_x, glyph_y) : 0;
            pending_code = char_code;
            pending_x = glyph_x;
            pending_y = glyph_y;
            #1;
            checks = checks + 1;
            if (out_valid !== expected_valid || pixel_on !== expected_pixel)
                $fatal(1, "FAIL t=%0t code=%02h x=%0d y=%0d valid=%b/%b pixel=%b/%b",
                       $time, expected_code, expected_x, expected_y,
                       out_valid, expected_valid, pixel_on, expected_pixel);
        end
    end

    task send_pixel;
        input valid;
        input [7:0] code;
        input [2:0] x;
        input [3:0] y;
        reg old_valid, old_pixel;
        begin
            @(negedge clk);
            old_valid = out_valid;
            old_pixel = pixel_on;
            in_valid = valid;
            char_code = code;
            glyph_x = x;
            glyph_y = y;
            #1;
            checks = checks + 1;
            if (out_valid !== old_valid || pixel_on !== old_pixel)
                $fatal(1, "FAIL combinational output change");
            @(posedge clk);
            #2;
            requests = requests + 1;
        end
    endtask

    initial begin
        #1000000;
        $fatal(1, "FAIL timeout");
    end

    initial begin
        #2;
        if ($test$plusargs("FORCE_FAIL"))
            $fatal(1, "FAIL intentional harness check");
        repeat (2) @(negedge clk);
        rst = 0;
        // Drain/prime explicitly after reset, then test all 32768 pixels.
        send_pixel(0, 0, 0, 0);
        for (code_i = 0; code_i < 256; code_i = code_i + 1)
            for (y_i = 0; y_i < 16; y_i = y_i + 1)
                for (x_i = 0; x_i < 8; x_i = x_i + 1)
                    send_pixel(1, code_i[7:0], x_i[2:0], y_i[3:0]);
        // Rapid x/y/character changes with bubbles catch stale-coordinate mixing.
        for (i = 0; i < 256; i = i + 1)
            send_pixel((i % 3) != 0,
                       (i % 2) ? 8'h46 : 8'h50, (7-i) & 7, (15-i) & 15);
        send_pixel(1, "A", 3, 0);

        // Reset between clock edges while a valid request is pending.
        @(negedge clk);
        in_valid = 1;
        char_code = "G";
        glyph_x = 6;
        glyph_y = 7;
        #2 rst = 1;
        #2;
        if (out_valid !== 0 || pixel_on !== 0)
            $fatal(1, "FAIL reset did not clear immediately");
        @(negedge clk);
        rst = 0;
        in_valid = 0;
        send_pixel(1, "A", 3, 0);
        send_pixel(1, "F", 7, 0);
        send_pixel(0, 0, 0, 0);
        send_pixel(0, 0, 0, 0);

        preview_file = $fopen("../evidence/glyph_pixel_A.txt", "w");
        pbm_file = $fopen("../evidence/glyph_pixel_A.pbm", "w");
        if (!preview_file || !pbm_file) $fatal(1, "FAIL preview open");
        $fdisplay(preview_file, "ASCII A, 8x16, actual DUT pixel_on");
        $fdisplay(pbm_file, "P1");
        $fdisplay(pbm_file, "8 16");
        for (y_i = 0; y_i < 16; y_i = y_i + 1) begin
            for (x_i = 0; x_i < 8; x_i = x_i + 1) begin
                send_pixel(1, "A", x_i[2:0], y_i[3:0]);
                send_pixel(0, 0, 0, 0); // Advance matching pixel to output stage.
                if (out_valid !== 1) $fatal(1, "FAIL preview missing valid");
                $fwrite(preview_file, "%s", pixel_on ? "#" : ".");
                $fwrite(pbm_file, "%0d ", pixel_on);
            end
            $fwrite(preview_file, "\n");
            $fwrite(pbm_file, "\n");
        end
        $fclose(preview_file);
        $fclose(pbm_file);
        send_pixel(0, 0, 0, 0);
        send_pixel(0, 0, 0, 0);
        test_passed = 1;
        $display("SIM PASS: glyph pixels requests=%0d checks=%0d; 256 codes x 16 rows x 8 columns, two stages, bubbles, reset.",
                 requests, checks);
        $finish;
    end
endmodule
