`timescale 1ns/1ps
// Fixed white HELLO FPGA, transparent background; three registered stages.
// enable must be stable for an active frame; frame-boundary control is upstream.
module osd_overlay (
    input wire clk,
    input wire rst,
    input wire enable,
    input wire [23:0] in_rgb,
    input wire in_de, in_hs, in_vs,
    input wire [9:0] in_x,
    input wire [8:0] in_y,
    output reg [23:0] out_rgb,
    output reg out_de, out_hs, out_vs,
    output reg [9:0] out_x,
    output reg [8:0] out_y
);
    wire text_valid, glyph_valid, pixel_on;
    wire [7:0] char_code;
    wire [2:0] glyph_x;
    wire [3:0] glyph_y;
    // {DE, HS, VS, X[9:0], Y[8:0], RGB[23:0]}, 46 bits.
    reg [45:0] video_d1, video_d2;
    osd_fixed_layout layout (
        .enable(enable), .in_de(in_de), .in_x(in_x), .in_y(in_y),
        .text_valid(text_valid), .char_code(char_code),
        .glyph_x(glyph_x), .glyph_y(glyph_y)
    );
    osd_glyph_pixel glyph (
        .clk(clk), .rst(rst), .in_valid(text_valid), .char_code(char_code),
        .glyph_x(glyph_x), .glyph_y(glyph_y),
        .out_valid(glyph_valid), .pixel_on(pixel_on)
    );
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            video_d1 <= 46'd0;
            video_d2 <= 46'd0;
            out_rgb <= 24'd0;
            out_de <= 1'b0;
            out_hs <= 1'b0;
            out_vs <= 1'b0;
            out_x <= 10'd0;
            out_y <= 9'd0;
        end else begin
            video_d1 <= {in_de, in_hs, in_vs, in_x, in_y, in_rgb};
            video_d2 <= video_d1;
            {out_de, out_hs, out_vs, out_x, out_y} <= video_d2[45:24];
            if (!video_d2[45])
                out_rgb <= 24'd0;
            else if (glyph_valid && pixel_on)
                out_rgb <= 24'hFFFFFF;
            else
                out_rgb <= video_d2[23:0];
        end
    end
endmodule
