`timescale 1ns/1ps
// Two 8x16 lines. Inputs must remain constant throughout active video.
module osd_status_layout (
    input wire enable, in_de,
    input wire [9:0] in_x,
    input wire [8:0] in_y,
    input wire image_valid,
    input wire [1:0] image_index,
    input wire auto_play,
    output reg text_valid,
    output reg [7:0] char_code,
    output reg [2:0] glyph_x,
    output reg [3:0] glyph_y
);
    reg [9:0] dx;
    always @* begin
        text_valid=0; char_code=" "; glyph_x=0; glyph_y=0; dx=0;
        if (enable && in_de && in_x>=16 && in_x<80 &&
            ((in_y>=16 && in_y<32) || (in_y>=40 && in_y<56))) begin
            dx=in_x-10'd16;
            glyph_x=dx[2:0];
            text_valid=1;
            if (in_y<32) begin
                glyph_y=in_y-9'd16;
                case (dx[9:3])
                    0: char_code="I";
                    1: char_code="M";
                    2: char_code="G";
                    3: char_code=":";
                    4: char_code=image_valid ? (8'h31+{6'd0,image_index}) : "-";
                    default: char_code=" ";
                endcase
            end else begin
                glyph_y=in_y-9'd40;
                case (dx[9:3])
                    0: char_code="A";
                    1: char_code="U";
                    2: char_code="T";
                    3: char_code="O";
                    4: char_code=":";
                    5: char_code="O";
                    6: char_code=auto_play ? "N" : "F";
                    7: char_code=auto_play ? " " : "F";
                    default: char_code=" ";
                endcase
            end
        end
    end
endmodule
