// Candidate-only insertion before the existing RGB-to-AXIS instance.
wire [23:0] osd_pos_rgb;
wire osd_pos_de, osd_pos_hs, osd_pos_vs, osd_position_valid, osd_frame_tick;
wire [9:0] osd_pos_x;
wire [8:0] osd_pos_y;
wire [23:0] osd_video_rgb;
wire osd_video_de, osd_video_hs, osd_video_vs;
wire [9:0] osd_video_x;
wire [8:0] osd_video_y;
reg osd_display_meta, osd_display_sync, osd_enable_frame;

// Only the OSD enable consumes this synchronized status. The original
// display_valid black-screen gate and TF/SDRAM path remain unchanged.
always @(posedge video_clk or posedge rst_all) begin
    if (rst_all) begin
        osd_display_meta <= 1'b0;
        osd_display_sync <= 1'b0;
        osd_enable_frame <= 1'b0;
    end else begin
        osd_display_meta <= display_valid;
        osd_display_sync <= osd_display_meta;
        if (osd_frame_tick)
            osd_enable_frame <= osd_display_sync;
    end
end

osd_video_position #(.VS_ACTIVE(1'b0)) u_osd_video_position (
    .clk(video_clk), .rst(rst_all),
    .in_rgb(vout_data), .in_de(de), .in_hs(hs), .in_vs(vs),
    .out_rgb(osd_pos_rgb), .out_de(osd_pos_de),
    .out_hs(osd_pos_hs), .out_vs(osd_pos_vs),
    .out_x(osd_pos_x), .out_y(osd_pos_y),
    .position_valid(osd_position_valid), .frame_tick(osd_frame_tick)
);
osd_overlay u_osd_overlay (
    .clk(video_clk), .rst(rst_all),
    .enable(osd_enable_frame && osd_position_valid),
    .in_rgb(osd_pos_rgb), .in_de(osd_pos_de),
    .in_hs(osd_pos_hs), .in_vs(osd_pos_vs),
    .in_x(osd_pos_x), .in_y(osd_pos_y),
    .out_rgb(osd_video_rgb), .out_de(osd_video_de),
    .out_hs(osd_video_hs), .out_vs(osd_video_vs),
    .out_x(osd_video_x), .out_y(osd_video_y)
);
