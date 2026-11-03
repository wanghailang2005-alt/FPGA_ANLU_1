`timescale 1ns/1ps
// Restore 640x480 active coordinates from DE and VS in the pixel clock domain.
// Preserve video during acquisition; position_valid qualifies coordinates only.
module osd_video_position #(
    parameter VS_ACTIVE = 1'b0
) (
    input wire clk,
    input wire rst,
    input wire [23:0] in_rgb,
    input wire in_de, in_hs, in_vs,
    output reg [23:0] out_rgb,
    output reg out_de, out_hs, out_vs,
    output reg [9:0] out_x,
    output reg [8:0] out_y,
    output reg position_valid,
    output reg frame_tick
);
    reg de_prev;
    reg vs_prev;
    reg saw_inactive;
    reg saw_active;
    reg synced;
    reg [9:0] x_count;
    reg [8:0] y_count;
    wire sync_end = saw_active && (vs_prev == VS_ACTIVE) &&
                    (in_vs != VS_ACTIVE) && !in_de;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            de_prev <= 1'b0;
            vs_prev <= VS_ACTIVE;
            saw_inactive <= 1'b0;
            saw_active <= 1'b0;
            synced <= 1'b0;
            x_count <= 10'd0;
            y_count <= 9'd0;
            out_rgb <= 24'd0;
            out_de <= 1'b0;
            out_hs <= 1'b0;
            out_vs <= 1'b0;
            out_x <= 10'd0;
            out_y <= 9'd0;
            position_valid <= 1'b0;
            frame_tick <= 1'b0;
        end else begin
            de_prev <= in_de;
            vs_prev <= in_vs;
            out_rgb <= in_rgb;
            out_de <= in_de;
            out_hs <= in_hs;
            out_vs <= in_vs;
            out_x <= 10'd0;
            out_y <= 9'd0;
            position_valid <= 1'b0;
            frame_tick <= sync_end;

            // Require inactive -> active -> inactive after reset; an initial
            // reset-level VS alone is not accepted as a complete sync pulse.
            if (in_vs != VS_ACTIVE)
                saw_inactive <= 1'b1;
            if (saw_inactive && in_vs == VS_ACTIVE && !in_de)
                saw_active <= 1'b1;

            if (sync_end) begin
                saw_active <= 1'b0;
                synced <= 1'b1;
                x_count <= 10'd0;
                y_count <= 9'd0;
            end else if (synced) begin
                if (in_de) begin
                    if (x_count < 10'd640 && y_count < 9'd480) begin
                        out_x <= x_count;
                        out_y <= y_count;
                        position_valid <= 1'b1;
                    end
                    // Saturate at an invalid sentinel; never wrap coordinates.
                    if (x_count < 10'd640)
                        x_count <= x_count + 10'd1;
                end else begin
                    x_count <= 10'd0;
                    if (de_prev && y_count < 9'd480)
                        y_count <= y_count + 9'd1;
                end
            end
        end
    end
endmodule
