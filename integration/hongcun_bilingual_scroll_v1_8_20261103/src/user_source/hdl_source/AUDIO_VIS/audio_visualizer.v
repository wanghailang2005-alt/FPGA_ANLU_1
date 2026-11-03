`timescale 1ns/1ps
// Pixel-domain audio analysis. Raw PCM is copied, never backpressured or altered
// on the HDMI audio path. Display state is committed only in vertical blanking.
module audio_visualizer (
 input wire clk,rst,frame_tick,
 input wire audio_valid,
 input wire [23:0] audio_left,audio_right,
 input wire [8:0] wave_address,
 input wire [4:0] band_address,
 output reg [7:0] wave_y,
 output reg [7:0] bar_height,peak_height,
 output reg [7:0] level_left,level_right,
 output wire overflow,
 output reg [15:0] fft_frames
);
 wire signed [16:0] stereo_sum=
  $signed({audio_left[23],audio_left[23:8]})+
  $signed({audio_right[23],audio_right[23:8]});
 wire signed [15:0] mono=stereo_sum >>> 1;
 reg signed [23:0] dc_q8;
 wire signed [24:0] dc_delta=($signed({{9{mono[15]}},mono}) <<< 8)-$signed(dc_q8);
 wire signed [16:0] centered=$signed({mono[15],mono})-$signed({dc_q8[23],dc_q8[23:8]});
 reg sample_valid;
 reg signed [15:0] sample_data;
 always @(posedge clk or posedge rst) begin
  if(rst) begin dc_q8<=0;sample_valid<=0;sample_data<=0;end
  else begin
   sample_valid<=audio_valid;
   if(audio_valid) begin
    dc_q8<=dc_q8+(dc_delta >>> 8);
    if(centered>17'sd32767) sample_data<=16'sh7fff;
    else if(centered < -17'sd32768) sample_data<=16'sh8000;
    else sample_data<=centered[15:0];
   end
  end
 end
 wire load_valid,bin_valid,fft_done;
 wire [8:0] load_index;
 wire signed [15:0] load_sample,bin_re,bin_im;
 wire [7:0] bin_index;
 audio_fft512 fft(
  .clk(clk),.rst(rst),.sample_valid(sample_valid),.sample_data(sample_data),
  .overflow(overflow),.load_valid(load_valid),.load_index(load_index),.load_sample(load_sample),
  .bin_valid(bin_valid),.bin_index(bin_index),.bin_re(bin_re),.bin_im(bin_im),.fft_done(fft_done));

 function [15:0] abs16;
  input signed [15:0] v;
  begin abs16=v[15] ? (~v+16'd1):v;end
 endfunction
 wire [15:0] re_abs=abs16(bin_re),im_abs=abs16(bin_im);
 wire [15:0] larger=re_abs>im_abs ? re_abs:im_abs;
 wire [15:0] smaller=re_abs>im_abs ? im_abs:re_abs;
 // A display magnitude approximation, not calibrated power or dB SPL.
 wire [16:0] magnitude={1'b0,larger}+{2'b0,smaller[15:1]};
 function [4:0] band_for_bin;
  input [7:0] b;
  begin
   if(b<=16) band_for_bin=b-1'b1;
   else if(b<18) band_for_bin=16;
   else if(b<20) band_for_bin=17;
   else if(b<23) band_for_bin=18;
   else if(b<27) band_for_bin=19;
   else if(b<32) band_for_bin=20;
   else if(b<38) band_for_bin=21;
   else if(b<45) band_for_bin=22;
   else if(b<54) band_for_bin=23;
   else if(b<64) band_for_bin=24;
   else if(b<76) band_for_bin=25;
   else if(b<90) band_for_bin=26;
   else if(b<107) band_for_bin=27;
   else if(b<128) band_for_bin=28;
   else if(b<152) band_for_bin=29;
   else if(b<181) band_for_bin=30;
   else band_for_bin=31;
  end
 endfunction
 function [7:0] log_height;
  input [16:0] value;
  integer k;
  reg [4:0] e,octaves;
  reg [8:0] h;
  reg [16:0] norm;
  begin
   e=0;h=0;norm=0;octaves=0;
   for(k=0;k<17;k=k+1) if(value[k]) e=k;
   if(value>=4) begin
    norm=e>=3 ? (value >> (e-3)):(value << (3-e));
    octaves=e-5'd2;
    // Explicit shifts avoid synthesizing a multiplier for display scaling.
    h=({4'd0,octaves}<<4)-({4'd0,octaves}<<1)+{5'd0,norm[2:0],1'b0};
   end
   log_height=h>160 ? 8'd160:h[7:0];
  end
 endfunction
 // Natural-order FFT bins allow one running maximum instead of 32 accumulators.
 // Two target banks make every published spectrum an indivisible FFT frame.
 reg [16:0] band_max;
 reg [4:0] accumulation_band;
 reg [7:0] target_mem[0:63];
 reg target_write_bank,target_published_bank,target_ready;
 // Two synchronous ports: renderer read, updater read/write. Runtime clear
 // permits BRAM inference without relying on global ERAM initialization.
 (* ram_style="bram" *) reg [19:0] display_mem[0:31];
 reg [19:0] display_q,render_q;
 reg display_ready;
 reg [2:0] display_state;
 reg [4:0] display_index;
 reg display_bank;
 reg [7:0] target_q;
 wire [4:0] band_index=band_for_bin(bin_index);
 wire [7:0] old_bar=display_q[7:0],old_peak=display_q[15:8];
 wire [3:0] old_hold=display_q[19:16];
 wire [7:0] next_bar=target_q>=old_bar ? target_q:(old_bar>3 ? old_bar-8'd3:8'd0);
 wire [7:0] next_peak=target_q>=old_peak ? target_q:
                              ((old_hold!=0 || old_peak==0) ? old_peak:old_peak-8'd1);
 wire [3:0] next_hold=target_q>=old_peak ? 4'd12:(old_hold!=0 ? old_hold-1'b1:4'd0);
 always @(posedge clk) begin
  render_q<=display_mem[band_address];
  display_q<=display_mem[display_index];
  if(display_state==4) display_mem[display_index]<=0;
  else if(display_state==3) display_mem[display_index]<={next_hold,next_peak,next_bar};
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin bar_height<=0;peak_height<=0;end
  else begin
   bar_height<=display_ready ? render_q[7:0]:8'd0;
   peak_height<=display_ready ? render_q[15:8]:8'd0;
  end
 end
 always @(posedge clk) begin
  target_q<=target_mem[{display_bank,display_index}];
  if(bin_valid && bin_index!=0 && band_index!=accumulation_band)
   target_mem[{target_write_bank,accumulation_band}]<=log_height(band_max);
  else if(fft_done) target_mem[{target_write_bank,accumulation_band}]<=log_height(band_max);
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   fft_frames<=0;band_max<=0;accumulation_band<=0;
   target_write_bank<=0;target_published_bank<=0;target_ready<=0;
   display_state<=4;display_index<=0;display_bank<=0;display_ready<=0;
  end else begin
   if(bin_valid && bin_index!=0) begin
    if(band_index!=accumulation_band) begin accumulation_band<=band_index;band_max<=magnitude;end
    else if(magnitude>band_max) band_max<=magnitude;
   end
   if(fft_done) begin
    fft_frames<=fft_frames+1'b1;
    target_published_bank<=target_write_bank;target_write_bank<=~target_write_bank;target_ready<=1;
    accumulation_band<=0;band_max<=0;
   end
   // One shared update circuit, 96 cycles in the vertical back porch.
   // At most one further FFT frame can complete in this short interval;
   // its writes go to the other target bank, leaving display_bank immutable.
   if(frame_tick && target_ready) begin
    display_index<=0;display_bank<=target_published_bank;display_state<=1;
   end else case(display_state)
    1:display_state<=2;
    2:display_state<=3;
    3:begin
     if(display_index==31) display_state<=0;
     else begin display_index<=display_index+1'b1;display_state<=1;end
    end
    4:begin
     if(display_index==31) begin display_ready<=1;display_state<=0;display_index<=0;end
     else display_index<=display_index+1'b1;
    end
    default:;
   endcase
  end
 end

 // Audio peak meters cover the raw signed 24-bit range via its upper 16 bits.
 reg [15:0] left_max,right_max;
 wire [15:0] left_abs=abs16($signed(audio_left[23:8]));
 wire [15:0] right_abs=abs16($signed(audio_right[23:8]));
 function [7:0] meter;
  input [15:0] v;
  begin meter=(v>>7)>160 ? 8'd160:(v>>7);end
 endfunction
 always @(posedge clk or posedge rst) begin
  if(rst) begin left_max<=0;right_max<=0;level_left<=0;level_right<=0;end
  else if(frame_tick) begin
   level_left<=meter(left_max)>=level_left ? meter(left_max):(level_left>3 ? level_left-8'd3:8'd0);
   level_right<=meter(right_max)>=level_right ? meter(right_max):(level_right>3 ? level_right-8'd3:8'd0);
   // Include a sample coincident with the frame boundary in the next interval.
   left_max<=audio_valid ? left_abs:16'd0;right_max<=audio_valid ? right_abs:16'd0;
  end else if(audio_valid) begin
   if(left_abs>left_max) left_max<=left_abs;
   if(right_abs>right_max) right_max<=right_abs;
  end
 end

 // Two waveform banks; a complete 512-sample capture is held until vblank.
 // The writer never touches the displayed bank or an unpublished snapshot.
 reg [7:0] wave_mem[0:1023];
 reg wave_bank,wave_pending,wave_capture,wave_ready;
 reg wave_q_valid;
 wire [9:0] wave_write_addr={~wave_bank,load_index};
 wire [9:0] wave_read_addr={wave_bank,wave_address};
 reg [7:0] wave_q;
 function [7:0] sample_to_y;
  input signed [15:0] v;
  reg signed [15:0] scaled;
  begin
   scaled=v >>> 8;
   if(scaled>40) sample_to_y=120;
   else if(scaled < -40) sample_to_y=200;
   else sample_to_y=16'sd160-scaled;
  end
 endfunction
 wire wave_start=load_valid && load_index==0 && !wave_pending;
 always @(posedge clk) begin
  wave_q<=wave_mem[wave_read_addr];
  if(load_valid && (wave_start || wave_capture)) wave_mem[wave_write_addr]<=sample_to_y(load_sample);
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   wave_bank<=0;wave_pending<=0;wave_capture<=0;wave_ready<=0;
   wave_y<=160;wave_q_valid<=0;
  end else begin
   // Match the single synchronous RAM read, with one output register here.
   wave_q_valid<=wave_ready;
   wave_y<=wave_q_valid ? wave_q:8'd160;
   if(wave_start) wave_capture<=1;
   if(load_valid && load_index==511 && wave_capture) begin wave_pending<=1;wave_capture<=0;end
   if(frame_tick && wave_pending) begin wave_bank<=~wave_bank;wave_pending<=0;wave_ready<=1;end
  end
 end
endmodule
