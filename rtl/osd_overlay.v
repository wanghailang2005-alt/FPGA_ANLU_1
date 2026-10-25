`timescale 1ns/1ps
// Black fixed/status text plus optional bottom scrolling banner; three stages.
// enable must be stable for an active frame; frame-boundary control is upstream.
module osd_overlay #(parameter STATUS_MODE=0, parameter SCROLL_ENABLE=1) (
    input wire clk,
    input wire rst,
    input wire enable,
    input wire image_valid,
    input wire [1:0] image_index,
    input wire auto_play,
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
    wire layout_valid;
    wire [7:0] layout_char;
    wire [2:0] layout_x;
    wire [3:0] layout_y;
    wire [7:0] char_code;
    wire [2:0] glyph_x;
    wire [3:0] glyph_y;
    // 20 characters, 160 pixels. Offset is stable throughout active video.

    // Phase is (offset - 640) modulo 1024; reset is fully offscreen.
    reg [9:0] scroll_phase;
    reg frame_half, vs_prev;

    wire [9:0] scroll_local = in_x + scroll_phase;
    wire scroll_valid = SCROLL_ENABLE && enable && in_de &&
                        in_x < 640 && in_y >= 448 && in_y < 464 &&
                        scroll_local < 10'd160;
    reg [7:0] scroll_char;
    always @* begin
        scroll_char = " ";
        case (scroll_local[9:3])
            0: scroll_char="W";
            1: scroll_char="E";
            2: scroll_char="L";
            3: scroll_char="C";
            4: scroll_char="O";
            5: scroll_char="M";
            6: scroll_char="E";
            7: scroll_char=" ";
            8: scroll_char="T";
            9: scroll_char="O";
            10: scroll_char=" ";
            11: scroll_char="A";
            12: scroll_char="N";
            13: scroll_char="L";
            14: scroll_char="U";
            15: scroll_char=" ";
            16: scroll_char="F";
            17: scroll_char="P";
            18: scroll_char="G";
            19: scroll_char="A";
            default: scroll_char=" ";
        endcase
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scroll_phase <= 10'd384;
            frame_half <= 0;
            vs_prev <= 0;
        end else begin
            vs_prev <= in_vs;
            if (SCROLL_ENABLE && vs_prev && !in_vs && !in_de) begin
                frame_half <= ~frame_half;
                if (frame_half)
                    scroll_phase <= (scroll_phase == 10'd160) ? 10'd384 : scroll_phase + 10'd1;
            end
        end
    end
    assign text_valid = layout_valid || scroll_valid;
    assign char_code = scroll_valid ? scroll_char : layout_char;
    assign glyph_x = scroll_valid ? scroll_local[2:0] : layout_x;
    assign glyph_y = scroll_valid ? (in_y - 9'd448) : layout_y;
    // {DE, HS, VS, X[9:0], Y[8:0], RGB[23:0]}, 46 bits.
    reg [45:0] video_d1, video_d2;
    generate if (STATUS_MODE) begin : status_mode
    osd_status_layout layout (
        .enable(enable), .in_de(in_de), .in_x(in_x), .in_y(in_y),
        .image_valid(image_valid), .image_index(image_index), .auto_play(auto_play),
        .text_valid(layout_valid), .char_code(layout_char),
        .glyph_x(layout_x), .glyph_y(layout_y)
    );
    end else begin : fixed_mode
    osd_fixed_layout layout (
        .enable(enable), .in_de(in_de), .in_x(in_x), .in_y(in_y),
        .text_valid(layout_valid), .char_code(layout_char),
        .glyph_x(layout_x), .glyph_y(layout_y)
    );
    end endgenerate
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
                out_rgb <= 24'h000000;
            else
                out_rgb <= video_d2[23:0];
        end
    end
endmodule
