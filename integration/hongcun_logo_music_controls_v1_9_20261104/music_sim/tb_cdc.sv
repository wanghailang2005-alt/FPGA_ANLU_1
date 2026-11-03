`timescale 1ns/1ps
module tb_cdc;
 reg sc=0,dc=0,mc=0,vc=0,rst=1;
 always #10 sc=~sc;
 always #17 dc=~dc;
 initial begin #1;forever #4 mc=~mc;end
 always #20 vc=~vc;
 reg [31:0] source_data=0;wire [31:0] dest_data;
 osd_status_cdc #(.WIDTH(32)) mailbox(sc,dc,rst,source_data,dest_data);
 reg [31:0] expected[$];reg [31:0] previous=0,held_previous=0;
 integer transfers=0;reg busy_previous=0;
 always @(posedge sc) if(!rst) begin
  if(mailbox.request==mailbox.ack_sync && mailbox.held_data!=source_data)
   expected.push_back(source_data);
  if(busy_previous && mailbox.request!=mailbox.ack_sync && mailbox.held_data!==held_previous)
   $fatal(1,"mailbox payload changed before ACK");
  held_previous=mailbox.held_data;
  busy_previous=mailbox.request!=mailbox.ack_sync;
 end
 always @(negedge dc) if(!rst && dest_data!=previous) begin
  if(expected.size()==0)$fatal(1,"unrequested mailbox transfer");
  if(dest_data!==expected.pop_front())$fatal(1,"torn/out-of-order mailbox transfer");
  previous=dest_data;transfers=transfers+1;
 end
 wire request,ack,hs,vs,de,rd,finish,clear,rd_busy;wire [20:0] addr;wire [5:0] status;
 video_timing_data video(.video_clk(vc),.rst(rst),.read_req(request),.read_req_ack(ack),.hs(hs),.vs(vs),.de(de));
 defparam video.color_bar_m0.H_ACTIVE=8,video.color_bar_m0.H_FP=2,
          video.color_bar_m0.H_SYNC=2,video.color_bar_m0.H_BP=2,
          video.color_bar_m0.V_ACTIVE=4,video.color_bar_m0.V_FP=1,
          video.color_bar_m0.V_SYNC=1,video.color_bar_m0.V_BP=1;
 frame_fifo_read #(.BURST_SIZE(4),.FIFO_DEPTH(32)) reader(
 .rst(rst),.mem_clk(mc),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
 .Sdr_rd_en(rd),.App_wr_busy(1'b0),.O_rd_busy(rd_busy),.App_rd_en(rd),.App_rd_addr(addr),
 .read_req(request),.read_req_ack(ack),.read_finish(finish),
 .read_addr_0(21'd0),.read_addr_1(21'd100),.read_addr_2(21'd200),.read_addr_3(21'd300),
 .read_status(11'd0),.read_frame_status(status),.read_addr_index(2'd0),.read_len(21'd16),
 .fifo_aclr(clear),.wrusedw(10'd0));
 integer frame_requests=0,frame_finishes=0,reads=0;reg prev_req=0;
 always @(negedge vc) if(!rst)begin
  if(request && !prev_req)frame_requests=frame_requests+1;
  prev_req=request;
 end
 always @(negedge mc) if(!rst)begin
  if(rd)reads=reads+1;
  if(finish)begin
   if(reads!=16)$fatal(1,"frame DMA count %0d",reads);
   reads=0;frame_finishes=frame_finishes+1;
  end
 end
 integer i;reg mailbox_done=0;integer test_pass=0;
 initial begin
  #137;rst=0;
  for(i=1;i<=300;i=i+1)begin
   @(negedge sc);source_data={16'(i),16'(~i)};
   repeat(i%7+1)@(negedge sc);
  end
  repeat(200)@(negedge sc);
  if(dest_data!==source_data || expected.size()!=0 || transfers<20)$fatal(1,"mailbox convergence");
  mailbox_done=1;
 end
 initial begin
  wait(mailbox_done && frame_finishes>=20);
  if(frame_requests!=frame_finishes)$fatal(1,"duplicate/lost frame handshake");
  $display("PASS CDC: %0d coherent mailbox transfers, %0d complete frame request/ACK handshakes",transfers,frame_finishes);
  test_pass=1;$finish;
 end
 initial begin #1000000;$fatal(1,"watchdog");end
endmodule
