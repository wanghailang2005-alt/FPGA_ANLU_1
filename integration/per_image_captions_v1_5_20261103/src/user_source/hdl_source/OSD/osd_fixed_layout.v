`timescale 1ns/1ps
// Combinational request layout: 10 characters, 8x16 each, transparent outside.
module osd_fixed_layout (
    input wire enable,
    input wire in_de,
    input wire [9:0] in_x,
    input wire [8:0] in_y,
    output reg text_valid,
    output reg [7:0] char_code,
    output reg [2:0] glyph_x,
    output reg [3:0] glyph_y
);
    reg [9:0] local_x;
    reg [8:0] local_y;
    always @* begin
        text_valid = 1'b0;
        char_code = 8'h20;
        glyph_x = 3'd0;
        glyph_y = 4'd0;
        local_x = 10'd0;
        local_y = 9'd0;
        // x=16..95, y=16..31, including both endpoints.
        if (enable && in_de &&
            in_x >= 10'd16 && in_x < 10'd96 &&
            in_y >= 9'd16 && in_y < 9'd32) begin
            local_x = in_x - 10'd16;
            local_y = in_y - 9'd16;
            text_valid = 1'b1;
            glyph_x = local_x[2:0];
            glyph_y = local_y[3:0];
            case (local_x[9:3])
                7'd0: char_code = "H";
                7'd1: char_code = "E";
                7'd2: char_code = "L";
                7'd3: char_code = "L";
                7'd4: char_code = "O";
                7'd5: char_code = " ";
                7'd6: char_code = "F";
                7'd7: char_code = "P";
                7'd8: char_code = "G";
                7'd9: char_code = "A";
                default: char_code = 8'h20;
            endcase
        end
    end
endmodule
