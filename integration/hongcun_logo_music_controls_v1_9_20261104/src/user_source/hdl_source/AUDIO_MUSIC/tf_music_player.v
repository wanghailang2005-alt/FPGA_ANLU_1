// 48kHz signed PCM16 mono, little endian, mirrored to HDMI L/R.
// Two 30s tracks at fixed raw-card LBAs; no FAT or compressed decoder.
module tf_music_player #(
 parameter [31:0] TRACK0_LBA=32'd131072,
 parameter [31:0] TRACK1_LBA=32'd136697,
 parameter integer TRACK_SECTORS=5625,
 parameter integer START_SAMPLES=1024
)(
 input sd_clk,audio_clk,rst,input [1:0] control,input sd_ready,
 output read_req,output [31:0] read_addr,input read_grant,
 input read_valid,read_end,input [7:0] read_data,
 output reg bclk,lrck,dout,output [2:0] health,
 input [4:0] playback_controls
);
 wire [4:0] playback_audio;
 osd_status_cdc #(.WIDTH(5)) u_playback_cdc(
  .src_clk(sd_clk),.dst_clk(audio_clk),.rst(rst),
  .src_data(playback_controls),.dst_data(playback_audio));
 wire paused=playback_audio[4];
 // Signed Q8 gain with a balanced shift/add tree; no multiplier or DSP.
 function [15:0] scale_sample;
 input signed [15:0] sample;input [3:0] volume;
 reg [8:0] gain;reg signed [24:0] x,a,b,c,d,total;
 begin
  case(volume)
   1:gain=26;2:gain=51;3:gain=77;4:gain=102;5:gain=128;
   6:gain=154;7:gain=179;8:gain=205;9:gain=230;10:gain=256;
   default:gain=128;
  endcase
  x={{9{sample[15]}},sample};
  a=(gain[0]?x:25'sd0)+(gain[1]?(x<<<1):25'sd0);
  b=(gain[2]?(x<<<2):25'sd0)+(gain[3]?(x<<<3):25'sd0);
  c=(gain[4]?(x<<<4):25'sd0)+(gain[5]?(x<<<5):25'sd0);
  d=(gain[6]?(x<<<6):25'sd0)+(gain[7]?(x<<<7):25'sd0);
  total=(a+b)+(c+d)+(gain[8]?(x<<<8):25'sd0);
  scale_sample=total>>>8;
 end endfunction
 reg [15:0] samples[0:2047];
 reg [11:0] wr_bin,rd_bin;
 (* keep="true" *) reg [11:0] wr_gray,rd_gray;
 (* ASYNC_REG="TRUE",keep="true" *) reg [11:0] rg1,rg2,wg1,wg2;
 (* ASYNC_REG="TRUE",keep="true" *) reg run_a1,run_a2,ack1,ack2;
 reg run_sd,run_ack,playing,underflow,short_sector;
 reg [1:0] selected;
 reg [1:0] state;
 reg in_flight,space_ok;
 reg [12:0] sector_index;
 reg [9:0] byte_count;
 reg [7:0] low_byte;
 localparam STOP=0,WAIT_ACK=1,PLAY=2;
 function [11:0] ungray;
 input [11:0] g;integer i;
 begin ungray[11]=g[11];for(i=10;i>=0;i=i-1) ungray[i]=ungray[i+1]^g[i];end
 endfunction
 wire [11:0] used_sd=wr_bin-ungray(rg2);
 wire [11:0] used_audio=ungray(wg2)-rd_bin;
 wire accept_byte=state==PLAY && selected==control && read_valid;
 wire [11:0] wr_next=wr_bin+1'b1;
 wire [11:0] rd_next=rd_bin+1'b1;
 // Registered watermark breaks Gray-decode/subtract/compare out of SD arbitration.
 // Leave an extra sector of headroom for the one-cycle watermark latency.
 assign read_req=state==PLAY && control==selected && sd_ready && !in_flight && space_ok;
 assign read_addr=(selected[0] ? TRACK1_LBA:TRACK0_LBA)+{19'd0,sector_index};
 assign health={short_sector,underflow,playing};
 always @(posedge sd_clk) begin
  if(accept_byte && byte_count[0]) samples[wr_bin[10:0]]<={read_data,low_byte};
 end
 always @(posedge sd_clk or posedge rst) begin
  if(rst) begin
   wr_bin<=0;wr_gray<=0;rg1<=0;rg2<=0;ack1<=0;ack2<=0;
   run_sd<=0;selected<=0;state<=STOP;in_flight<=0;space_ok<=0;
   sector_index<=0;byte_count<=0;low_byte<=0;short_sector<=0;
  end else begin
   rg1<=rd_gray;rg2<=rg1;ack1<=run_ack;ack2<=ack1;
   space_ok<=used_sd<=12'd1536;
   if(read_grant) begin in_flight<=1;byte_count<=0;end
   if(read_end) begin
    in_flight<=0;
    if(state==PLAY && selected==control) begin
     if(byte_count!=512) short_sector<=1;
     if(sector_index==TRACK_SECTORS-1) sector_index<=0;
     else sector_index<=sector_index+1'b1;
    end
   end
   if(accept_byte) begin
    byte_count<=byte_count+1'b1;
    if(!byte_count[0]) low_byte<=read_data;
    else begin wr_bin<=wr_next;wr_gray<=(wr_next>>1)^wr_next;end
   end
   case(state)
    STOP: begin
     run_sd<=0;
     // Finish any sector already owned before resetting queue pointers.
     if(!in_flight && !read_grant && !ack2) begin
      wr_bin<=0;wr_gray<=0;sector_index<=0;selected<=control;
      state<=WAIT_ACK;short_sector<=0;
     end
    end
    WAIT_ACK: begin
     if(selected!=control) state<=STOP;
     else if(control[1] && sd_ready) begin run_sd<=1;state<=PLAY;end
    end
    PLAY: if(selected!=control || !sd_ready) begin run_sd<=0;state<=STOP;end
    default: state<=STOP;
   endcase
  end
 end
 reg [15:0] sample_q;
 wire [15:0] scaled_sample=scale_sample(sample_q,playback_audio[3:0]);
 reg [23:0] frame_sample;
 reg [63:0] shift_word;
 reg [5:0] bit_count;
 always @(posedge audio_clk) sample_q<=samples[rd_bin[10:0]];
 always @(posedge audio_clk or posedge rst) begin
  if(rst) begin
   wg1<=0;wg2<=0;run_a1<=0;run_a2<=0;run_ack<=0;
   rd_bin<=0;rd_gray<=0;playing<=0;underflow<=0;
   bclk<=0;lrck<=0;dout<=0;bit_count<=0;shift_word<=0;frame_sample<=0;
  end else begin
   wg1<=wr_gray;wg2<=wg1;run_a1<=run_sd;run_a2<=run_a1;run_ack<=run_a2;
   // Clocks continue even while muted, preserving HDMI sample cadence.
   bclk<=~bclk;
   if(!run_a2) begin rd_bin<=0;rd_gray<=0;playing<=0;underflow<=0;end
   else if(!playing && used_audio>=START_SAMPLES) playing<=1;
   if(bclk) begin
    dout<=shift_word[63];shift_word<={shift_word[62:0],1'b0};
    if(bit_count==63) begin
     bit_count<=0;lrck<=~lrck;
     if(!lrck) shift_word<={frame_sample,40'd0};
     else if(paused) begin frame_sample<=0;shift_word<=0;end
     else if(run_a2 && playing && used_audio!=0) begin
      frame_sample<={scaled_sample,8'd0};shift_word<={scaled_sample,48'd0};
      rd_bin<=rd_next;rd_gray<=(rd_next>>1)^rd_next;
     end else begin
      frame_sample<=0;shift_word<=0;
      if(run_a2 && playing && used_audio==0) begin underflow<=1;playing<=0;end
     end
    end else bit_count<=bit_count+1'b1;
   end
  end
 end
endmodule
