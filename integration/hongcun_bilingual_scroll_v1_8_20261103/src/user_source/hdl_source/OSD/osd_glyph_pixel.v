`timescale 1ns/1ps
// Stage 1: row query + matching horizontal coordinate.
// Stage 2: registered pixel selection. No video timing is generated here.
module osd_glyph_pixel (
    input wire clk,
    input wire rst,
    input wire in_valid,
    input wire [7:0] char_code,
    input wire [2:0] glyph_x,
    input wire [3:0] glyph_y,
    output reg out_valid,
    output reg pixel_on
);
    wire row_valid;
    wire [7:0] row_bits;
    reg [2:0] glyph_x_d1;

    osd_font_rom font_rom (
        .clk(clk), .rst(rst), .in_valid(in_valid),
        .char_code(char_code), .glyph_y(glyph_y),
        .out_valid(row_valid), .row_bits(row_bits)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            glyph_x_d1 <= 3'd0;
            out_valid <= 1'b0;
            pixel_on <= 1'b0;
        end else begin
            glyph_x_d1 <= in_valid ? glyph_x : 3'd0;
            out_valid <= row_valid;
            pixel_on <= row_valid ? row_bits[3'd7 - glyph_x_d1] : 1'b0;
        end
    end
endmodule
