`timescale 1ns/1ps
module tb_reset;
reg clk=0; always #5 clk=~clk;
reg rst=1,start=0,pv=0,sdone=0;
reg [15:0] w=1,h=1;
wire accept,ov,busy,err,done;
wire [31:0] pixel;
reg [8:0] usedw=0;
reg test_pass=0;
integer count=0,phase=0,t=0;
scale_on_load dut(.clk(clk),.rst(rst),.load_start(start),.mode(2'd2),
 .src_w(w),.src_h(h),.src_px_valid(pv),.src_px(24'h123456),
 .src_accept(accept),.source_done(sdone),.fifo_usedw(usedw),
 .tgt_px_valid(ov),.tgt_px(pixel),.busy(busy),.cfg_error(err),.frame_done(done));
always @(posedge clk) if(ov && !rst) begin
 if(phase==2 && pixel!==32'h12345600) $fatal(1,"bad pixel after reset");
 count=count+1;
end
task automatic begin_one_pixel;
 begin
 start=1; @(negedge clk); start=0; pv=1;
 while(!accept) @(negedge clk);
 @(negedge clk); pv=0; sdone=1;
 @(negedge clk); sdone=0;
 end
endtask
initial begin
 repeat(5) @(negedge clk); rst=0; phase=1;
 begin_one_pixel();
 while(count<1000) @(negedge clk);
 rst=1; repeat(5) @(negedge clk);
 if(ov || busy || done) $fatal(1,"reset failed to quiesce outputs");
 phase=2; count=0; rst=0; begin_one_pixel();
 while(!done && t<1000000) begin @(negedge clk); t=t+1; end
 if(!done || count!=307200) $fatal(1,"restart did not complete exactly one frame");
 repeat(100) @(negedge clk);
 if(ov || busy || done || count!=307200) $fatal(1,"extra completion/output");
 w=0; start=1; @(negedge clk); start=0; repeat(10) @(negedge clk);
 if(!err || busy || ov) $fatal(1,"zero width did not reject");
 test_pass=1; $display("RESULT PASS reset_mid_frame restart zero_dimension"); $finish;
end
initial begin #20000000; $fatal(1,"reset test timeout"); end
endmodule
