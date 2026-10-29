`timescale 1ns/1ps
// Three matched video registers, in both enabled and bypass modes.
// Analysis and rendering share video_clk; controls commit at frame_tick.
module audio_visualizer_overlay (
 input wire clk,rst,frame_tick,enable_request,
 input wire audio_valid,
 input wire [23:0] audio_left,audio_right,
 input wire [23:0] in_rgb,
 input wire in_de,in_hs,in_vs,
 input wire [9:0] in_x,
 input wire [8:0] in_y,
 output reg [23:0] out_rgb,
 output reg out_de,out_hs,out_vs,
 output reg [9:0] out_x,
 output reg [8:0] out_y
);
 reg enabled;
 always @(posedge clk or posedge rst) begin
  if(rst) enabled<=0;
  else if(frame_tick) enabled<=enable_request;
 end
 wire [7:0] left_level,right_level,wave_y,height,peak;
 wire overflow;
 wire [15:0] fft_frames;
 wire [8:0] wave_address=(in_x>=32 && in_x<544) ? in_x-10'd32:9'd0;
 wire [9:0] band_x=in_x-10'd32;
 audio_visualizer analysis(
  .clk(clk),.rst(rst),.frame_tick(frame_tick),.audio_valid(audio_valid),
  .audio_left(audio_left),.audio_right(audio_right),.wave_address(wave_address),
  .band_address(band_x[8:4]),.wave_y(wave_y),.bar_height(height),.peak_height(peak),
  .level_left(left_level),.level_right(right_level),.overflow(overflow),.fft_frames(fft_frames));

 // Reuse the existing licensed bitmap font. Labels are compile-time constants.
 reg text_valid;
 reg [7:0] text_char;
 reg [2:0] glyph_x;
 reg [3:0] glyph_y;
 reg [9:0] text_dx;
 reg [8*40-1:0] text_line;
 always @* begin
  text_valid=0;text_char=" ";glyph_x=0;glyph_y=0;text_dx=0;text_line=0;
  if(enabled && in_de) begin
   if(in_x>=32 && in_x<352 && in_y>=64 && in_y<80) begin
    text_valid=1;text_dx=in_x-32;glyph_y=in_y-64;
    text_line={"AUDIO VISUALIZER 48K FFT512 TEST",64'd0};
   end else if(in_x>=32 && in_x<96 && in_y>=88 && in_y<104) begin
    text_valid=1;text_dx=in_x-32;glyph_y=in_y-88;
    text_line="WAVEFORM                                ";
   end else if(in_x>=32 && in_x<96 && in_y>=232 && in_y<248) begin
    text_valid=1;text_dx=in_x-32;glyph_y=in_y-232;
    text_line="SPECTRUM                                ";
   end else if(in_x>=568 && in_x<624 && in_y>=232 && in_y<248) begin
    text_valid=1;text_dx=in_x-568;glyph_y=in_y-232;
    text_line="L    R                                  ";
   end else if(in_x>=32 && in_x<72 && in_y>=432 && in_y<448) begin
    text_valid=1;text_dx=in_x-32;glyph_y=in_y-432;
    text_line="94HZ                                    ";
   end else if(in_x>=288 && in_x<344 && in_y>=432 && in_y<448) begin
    text_valid=1;text_dx=in_x-288;glyph_y=in_y-432;
    text_line="1.5KHZ                                  ";
   end else if(in_x>=496 && in_x<544 && in_y>=432 && in_y<448) begin
    text_valid=1;text_dx=in_x-496;glyph_y=in_y-432;
    text_line="24KHZ                                   ";
   end
   glyph_x=text_dx[2:0];
   text_char=text_line[(39-text_dx[8:3])*8+:8];
  end
 end
 wire glyph_valid,glyph_on;
 osd_glyph_pixel label_glyph(
  .clk(clk),.rst(rst),.in_valid(text_valid),.char_code(text_char),
  .glyph_x(glyph_x),.glyph_y(glyph_y),.out_valid(glyph_valid),.pixel_on(glyph_on));

 // {enabled,DE,HS,VS,X[9:0],Y[8:0],RGB[23:0]} = 47 bits.
 reg [46:0] video_s0,video_s1;
 wire act=video_s1[46] && video_s1[45];
 wire [9:0] x=video_s1[42:33];
 wire [8:0] y=video_s1[32:24];
 wire [9:0] spectrum_x=x-10'd32;
 wire [8:0] from_bottom=9'd423-y;
 reg [7:0] previous_wave;
 wire [7:0] wave_prev=x==32 ? wave_y:previous_wave;
 wire [7:0] wave_lo=wave_y<wave_prev ? wave_y:wave_prev;
 wire [7:0] wave_hi=wave_y>wave_prev ? wave_y:wave_prev;
 reg [23:0] pixel,bar_color;
 always @* begin
  pixel=video_s1[23:0];bar_color=24'h26e65a;
  if(y<304) bar_color=24'hff533d;
  else if(y<352) bar_color=24'hffd43b;
  if(act) begin
   // Darken panels using bit shifts, no alpha multipliers or frame writes.
   if((x>=24 && x<552 && y>=84 && y<216) ||
      (x>=24 && x<632 && y>=228 && y<448) ||
      (x>=24 && x<552 && y>=60 && y<80))
    pixel={2'b0,pixel[23:18],2'b0,pixel[15:10],2'b0,pixel[7:2]};
   if(x>=32 && x<544 && y>=112 && y<=208) begin
    if(x[5:0]==0 || y==112 || y==160 || y==208) pixel=24'h244253;
    if(y>=wave_lo && y<=wave_hi) pixel=24'h38e8ff;
   end
   if(x>=32 && x<544 && y>=256 && y<=423) begin
    if(y==263 || y==303 || y==343 || y==383 || y==423 || spectrum_x[3:0]==0) pixel=24'h203747;
    if(spectrum_x[3:0]>=2 && spectrum_x[3:0]<=13) begin
     if(from_bottom<height && y[2:0]!=7) pixel=bar_color;
     if(peak!=0 && from_bottom=={1'b0,peak}) pixel=24'hf0ffff;
    end
   end
   if(((x>=568 && x<584) || (x>=608 && x<624)) && y>=256 && y<=423) begin
    pixel=24'h172a3b;
    if(from_bottom < (x<600 ? left_level:right_level) && y[2:0]!=7) pixel=bar_color;
   end
   // Red = sample FIFO overflow, green = FFT has completed, gray = acquisition.
   if(x>=608 && x<624 && y>=64 && y<80)
    pixel=overflow ? 24'hff3040:(fft_frames!=0 ? 24'h26e65a:24'h607080);
  end
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   video_s0<=0;video_s1<=0;previous_wave<=160;
   out_rgb<=0;out_de<=0;out_hs<=0;out_vs<=0;out_x<=0;out_y<=0;
  end else begin
   video_s0<={enabled,in_de,in_hs,in_vs,in_x,in_y,in_rgb};
   video_s1<=video_s0;
   previous_wave<=wave_y;
   {out_de,out_hs,out_vs,out_x,out_y}<=video_s1[45:24];
   if(!video_s1[45]) out_rgb<=0;
   else if(glyph_valid && glyph_on) out_rgb<=24'hf0f6ff;
   else out_rgb<=pixel;
  end
 end
endmodule
