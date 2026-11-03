`timescale 1ns/1ps
// Three 8x16 lines. Inputs must remain constant throughout active video.
//   y=16..31  IMG:<n>   当前显示图片序号，无图显示 IMG:-
//   y=40..55  AUTO:ON   轮播状态
//   y=64..79  SW:1010 V=10  当前 SW 编码和该设置项的值（亮度/对比度为 0~10）
module osd_status_layout (
    input wire enable, in_de,
    input wire [9:0] in_x,
    input wire [8:0] in_y,
    input wire image_valid,
    input wire [2:0] image_index,
    input wire auto_play,
    input wire [3:0] sw_code,
    input wire [3:0] setting_value,
    output reg text_valid,
    output reg [7:0] char_code,
    output reg [2:0] glyph_x,
    output reg [3:0] glyph_y
);
    reg [9:0] dx;
    reg [7:0] value_tens;
    reg [7:0] value_ones;

    // 设置值用两位十进制显示：0~9 时十位留空，10 显示 "10"。
    always @* begin
        value_tens = " ";
        value_ones = 8'h30 + {4'd0, setting_value};
        if (setting_value >= 4'd10) begin
            value_tens = "1";
            value_ones = 8'h30 + {4'd0, setting_value} - 8'd10;
        end
    end

    always @* begin
        text_valid=0; char_code=" "; glyph_x=0; glyph_y=0; dx=0;
        if (enable && in_de && in_x>=16 && in_x<112 &&
            ((in_y>=16 && in_y<32) || (in_y>=40 && in_y<56) ||
             (in_y>=64 && in_y<80))) begin
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
                    4: char_code=image_valid ? (8'h31+{5'd0,image_index}) : "-";
                    default: char_code=" ";
                endcase
            end else if (in_y<56) begin
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
            end else begin
                glyph_y=in_y-9'd64;
                case (dx[9:3])
                    0: char_code="S";
                    1: char_code="W";
                    2: char_code=":";
                    3: char_code=sw_code[3] ? "1" : "0";
                    4: char_code=sw_code[2] ? "1" : "0";
                    5: char_code=sw_code[1] ? "1" : "0";
                    6: char_code=sw_code[0] ? "1" : "0";
                    7: char_code=" ";
                    8: char_code="V";
                    9: char_code="=";
                    10: char_code=value_tens;
                    11: char_code=value_ones;
                    default: char_code=" ";
                endcase
            end
        end
    end
endmodule
