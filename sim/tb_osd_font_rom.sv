`timescale 1ns/1ps
module tb_osd_font_rom;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg in_valid = 0;
    reg [7:0] char_code = 0;
    reg [3:0] glyph_y = 0;
    wire out_valid;
    wire [7:0] row_bits;
    integer checks = 0;
    integer requests = 0;
    reg test_passed = 0;
    integer code_i, row_i, i;
    integer preview_file;
    reg [7:0] expected_row;
    reg [63:0] golden;
    reg [7:0] preview_code;
    osd_font_rom dut (
        .clk(clk), .rst(rst), .in_valid(in_valid),
        .char_code(char_code), .glyph_y(glyph_y),
        .out_valid(out_valid), .row_bits(row_bits)
    );

    // Independent whole-glyph fixture; not obtained from DUT hierarchy.
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

    task check_outputs;
        input expected_valid;
        input [7:0] expected_data;
        begin
            checks = checks + 1;
            if (out_valid !== expected_valid || row_bits !== expected_data)
                $fatal(1, "FAIL t=%0t code=%02h y=%0d valid=%b/%b row=%02h/%02h",
                       $time, char_code, glyph_y, out_valid, expected_valid,
                       row_bits, expected_data);
        end
    endtask

    task request_row;
        input valid;
        input [7:0] code;
        input [3:0] y;
        reg old_valid;
        reg [7:0] old_row;
        reg [63:0] whole_glyph;
        reg [63:0] shifted;
        reg [7:0] want;
        begin
            @(negedge clk);
            old_valid = out_valid;
            old_row = row_bits;
            in_valid = valid;
            char_code = code;
            glyph_y = y;
            whole_glyph = golden_bitmap(code);
            // Reference uses shift + modulo rather than DUT's indexed slice.
            shifted = whole_glyph >> (8 * (7 - y / 2));
            want = valid ? (shifted % 256) : 8'h00;
            #1;
            check_outputs(old_valid, old_row); // No combinational output change.
            @(posedge clk);
            #1;
            check_outputs(valid, want);
            requests = requests + 1;
        end
    endtask

    initial begin
        #200000;
        $fatal(1, "FAIL timeout");
    end

    initial begin
        #1;
        if ($test$plusargs("FORCE_FAIL"))
            $fatal(1, "FAIL: intentional harness exit-code check");
        check_outputs(0, 0);
        repeat (2) @(negedge clk);
        rst = 0;
        request_row(1, 8'h41, 0); // First request after reset.
        request_row(1, 8'h46, 1);
        request_row(0, 8'h50, 2);

        // 4096 valid requests, including every unsupported encoding.
        for (code_i = 0; code_i < 256; code_i = code_i + 1)
            for (row_i = 0; row_i < 16; row_i = row_i + 1)
                request_row(1, code_i[7:0], row_i[3:0]);

        // Alternating characters/rows and bubbles exercise request alignment.
        for (i = 0; i < 256; i = i + 1)
            request_row((i % 3) != 0,
                        (i % 2) ? 8'h41 : 8'h5A, (15-i) & 15);

        // A request is interrupted before its sampling edge by asynchronous reset.
        @(negedge clk);
        in_valid = 1;
        char_code = 8'h41;
        glyph_y = 6;
        #2 rst = 1;
        #1 check_outputs(0, 0);
        @(posedge clk);
        #1 check_outputs(0, 0);
        @(negedge clk);
        in_valid = 0;
        rst = 0;
        request_row(0, 8'h41, 6);
        request_row(1, 8'h41, 6);
        request_row(1, 8'h39, 15);
        request_row(0, 8'hFF, 15);

        // Export DUT-produced pixels for visual review (P/G are asymmetric).
        preview_file = $fopen("../evidence/glyph_preview.txt", "w");
        if (preview_file == 0) $fatal(1, "FAIL cannot open preview");
        for (code_i = 0; code_i < 7; code_i = code_i + 1) begin
            case (code_i)
                0: preview_code = "A";
                1: preview_code = "F";
                2: preview_code = "P";
                3: preview_code = "G";
                4: preview_code = "0";
                5: preview_code = "1";
                6: preview_code = ":";
            endcase
            $fdisplay(preview_file, "ASCII %02h (%c)", preview_code, preview_code);
            for (row_i = 0; row_i < 16; row_i = row_i + 1) begin
                request_row(1, preview_code, row_i[3:0]);
                for (i = 7; i >= 0; i = i - 1)
                    if (row_bits[i]) $fwrite(preview_file, "#");
                    else $fwrite(preview_file, ".");
                $fwrite(preview_file, "\n");
            end
            $fwrite(preview_file, "\n");
        end
        $fclose(preview_file);
        $display("SIM PASS: requests=%0d checks=%0d; all 256 codes x 16 rows, bubbles, reset, latency.",
                 requests, checks);
        test_passed = 1;
        $finish;
    end
endmodule
