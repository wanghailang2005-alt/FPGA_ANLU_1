`timescale 1ns/1ps
// Compact, PCM-driven 32-band spectrum. enable is already frame-latched by
// the caller. RGB/DE/HS/VS/X/Y have exactly three registers in every mode.
module audio_spectrum_overlay (
    input wire clk, rst, frame_tick, enable,
    input wire audio_valid,
    input wire [23:0] audio_left, audio_right,
    input wire [23:0] in_rgb,
    input wire in_de, in_hs, in_vs,
    input wire [9:0] in_x,
    input wire [8:0] in_y,
    output reg [23:0] out_rgb,
    output reg out_de, out_hs, out_vs,
    output reg [9:0] out_x,
    output reg [8:0] out_y
);
    wire [9:0] band_x = in_x - 10'd112;
    wire [7:0] bar_height, peak_height;
    wire overflow;
    wire [15:0] fft_frames;
    audio_visualizer analysis (
        .clk(clk), .rst(rst), .frame_tick(frame_tick),
        .audio_valid(audio_valid), .audio_left(audio_left), .audio_right(audio_right),
        .wave_address(9'd0), .band_address(band_x[8:4]),
        .wave_y(), .bar_height(bar_height), .peak_height(peak_height),
        .level_left(), .level_right(), .overflow(overflow), .fft_frames(fft_frames)
    );

    // Reuse the licensed 8x16 font, including its two registered read stages.
    // The label identifies the existing internal test tone honestly.
    wire text_valid = enable && in_de && in_x >= 10'd16 && in_x < 10'd96 &&
                      in_y >= 9'd380 && in_y < 9'd396;
    wire [9:0] text_dx = in_x - 10'd16;
    wire [8:0] text_dy = in_y - 9'd380;
    reg [7:0] text_char;
    always @* begin
        case (text_dx[6:3])
            0: text_char = "A";
            1: text_char = "U";
            2: text_char = "D";
            3: text_char = "I";
            4: text_char = "O";
            5: text_char = " ";
            6: text_char = "T";
            7: text_char = "E";
            8: text_char = "S";
            9: text_char = "T";
            default: text_char = " ";
        endcase
    end
    wire glyph_valid, glyph_on;
    osd_glyph_pixel label_glyph (
        .clk(clk), .rst(rst), .in_valid(text_valid), .char_code(text_char),
        .glyph_x(text_dx[2:0]), .glyph_y(text_dy[3:0]),
        .out_valid(glyph_valid), .pixel_on(glyph_on)
    );

    // {enable,DE,HS,VS,X[9:0],Y[8:0],RGB[23:0]} = 47 bits.
    reg [46:0] video_s0, video_s1;
    wire [9:0] x = video_s1[42:33];
    wire [8:0] y = video_s1[32:24];
    wire [9:0] column_x = x - 10'd112;
    wire [8:0] depth = 9'd407 - y;
    wire [5:0] height = bar_height[7:2];
    wire [5:0] peak = peak_height[7:2];
    // A 40-pixel peak belongs to the highest row, depth=39. Subtracting one
    // also ensures a retained peak is the top pixel of its represented height.
    wire [5:0] peak_depth = peak == 0 ? 6'd0 : peak - 6'd1;
    reg [23:0] pixel;
    always @* begin
        pixel = video_s1[23:0];
        if (video_s1[46] && video_s1[45]) begin
            if (y >= 9'd360 && y < 9'd416)
                pixel = 24'h0b1729;
            if (x >= 10'd112 && x < 10'd624 && y >= 9'd368 && y <= 9'd407 &&
                column_x[3:0] >= 4'd2 && column_x[3:0] <= 4'd12) begin
                if (depth < {3'd0, height}) pixel = 24'h286474;
                if (peak != 0 && depth == {3'd0, peak_depth}) pixel = 24'h82c4c7;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            video_s0 <= 47'd0;
            video_s1 <= 47'd0;
            out_rgb <= 24'd0;
            out_de <= 1'b0;
            out_hs <= 1'b0;
            out_vs <= 1'b0;
            out_x <= 10'd0;
            out_y <= 9'd0;
        end else begin
            video_s0 <= {enable, in_de, in_hs, in_vs, in_x, in_y, in_rgb};
            video_s1 <= video_s0;
            {out_de, out_hs, out_vs, out_x, out_y} <= video_s1[45:24];
            if (!video_s1[45]) out_rgb <= 24'd0;
            else if (glyph_valid && glyph_on) out_rgb <= 24'h8391a1;
            else out_rgb <= pixel;
        end
    end
endmodule
