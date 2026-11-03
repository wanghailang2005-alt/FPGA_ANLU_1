// Derived glyphs: Copyright (c) 2007 Danial Chitnis, MIT License.
// See ../THIRD_PARTY_NOTICES.md and ../LICENSE.FPGA-text-overlay.
// ASCII adapter, punctuation additions and row-doubled 8x16 interface.
`timescale 1ns/1ps
module osd_font_rom (
    input wire clk,
    input wire rst,
    input wire in_valid,
    input wire [7:0] char_code,
    input wire [3:0] glyph_y,
    output reg out_valid,
    output reg [7:0] row_bits
);
    // One registered stage; rows 2*n and 2*n+1 use the same 8x8 row.
    function [7:0] lookup_row;
        input [7:0] code;
        input [2:0] row;
        reg [63:0] bitmap;
        begin
            case (code)
            8'h20: bitmap = 64'h0000000000000000; // SPACE
            8'h2b: bitmap = 64'h0018187e18180000; // +
            8'h2c: bitmap = 64'h0000000000181830; // ,
            8'h2d: bitmap = 64'h0000007e00000000; // -
            8'h2e: bitmap = 64'h0000000000181800; // .
            8'h2f: bitmap = 64'h0003060c18306000; // /
            8'h30: bitmap = 64'h3c666e7666663c00; // 0
            8'h31: bitmap = 64'h1818381818187e00; // 1
            8'h32: bitmap = 64'h3c66060c30607e00; // 2
            8'h33: bitmap = 64'h3c66061c06663c00; // 3
            8'h34: bitmap = 64'h060e1e667f060600; // 4
            8'h35: bitmap = 64'h7e607c0606663c00; // 5
            8'h36: bitmap = 64'h3c66607c66663c00; // 6
            8'h37: bitmap = 64'h7e660c1818181800; // 7
            8'h38: bitmap = 64'h3c66663c66663c00; // 8
            8'h39: bitmap = 64'h3c66663e06663c00; // 9
            8'h3a: bitmap = 64'h0018180018180000; // :
            8'h3b: bitmap = 64'h0018180018183000; // ;
            8'h3d: bitmap = 64'h00003c003c000000; // =
            8'h41: bitmap = 64'h183c667e66666600; // A
            8'h42: bitmap = 64'h7c66667c66667c00; // B
            8'h43: bitmap = 64'h3c66606060663c00; // C
            8'h44: bitmap = 64'h786c6666666c7800; // D
            8'h45: bitmap = 64'h7e60607860607e00; // E
            8'h46: bitmap = 64'h7e60607860606000; // F
            8'h47: bitmap = 64'h3c66606e66663c00; // G
            8'h48: bitmap = 64'h6666667e66666600; // H
            8'h49: bitmap = 64'h3c18181818183c00; // I
            8'h4a: bitmap = 64'h1e0c0c0c0c6c3800; // J
            8'h4b: bitmap = 64'h666c7870786c6600; // K
            8'h4c: bitmap = 64'h6060606060607e00; // L
            8'h4d: bitmap = 64'h63777f6b63636300; // M
            8'h4e: bitmap = 64'h66767e7e6e666600; // N
            8'h4f: bitmap = 64'h3c66666666663c00; // O
            8'h50: bitmap = 64'h7c66667c60606000; // P
            8'h51: bitmap = 64'h3c666666663c0e00; // Q
            8'h52: bitmap = 64'h7c66667c786c6600; // R
            8'h53: bitmap = 64'h3c66603c06663c00; // S
            8'h54: bitmap = 64'h7e18181818181800; // T
            8'h55: bitmap = 64'h6666666666663c00; // U
            8'h56: bitmap = 64'h66666666663c1800; // V
            8'h57: bitmap = 64'h6363636b7f776300; // W
            8'h58: bitmap = 64'h66663c183c666600; // X
            8'h59: bitmap = 64'h6666663c18181800; // Y
            8'h5a: bitmap = 64'h7e060c1830607e00; // Z
                default: bitmap = 64'h0000000000000000;
            endcase
            lookup_row = bitmap[63 - {row, 3'b000} -: 8];
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_valid <= 1'b0;
            row_bits <= 8'h00;
        end else begin
            out_valid <= in_valid;
            if (in_valid)
                row_bits <= lookup_row(char_code, glyph_y[3:1]);
            else
                row_bits <= 8'h00;
        end
    end
endmodule
