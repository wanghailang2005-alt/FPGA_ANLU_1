`timescale 1ns/1ps
module tb_transition_ui;
 reg clk=0,rst=1,vs=0,de=0,req=0,commit=0;always #20 clk=~clk;
 reg [2:0] mode=0;wire dark,done;wire [23:0] rgb;
 reg test_pass=0;integer m,n,x,y,seen;
 image_transition #(.VIEW_WIDTH(480),.VIEW_HEIGHT(360)) dut(
 .video_clk(clk),.rst(rst),.vs(vs),.de(de),.rgb_in(24'h8090a0),
 .transition_mode(mode),.duration_sel(2'd0),.slide_dir(1'b0),
 .brightness(4'd5),.contrast(4'd5),.transition_req_toggle(req),
 .transition_commit_toggle(commit),.dark_ack_toggle(dark),.done_toggle(done),.rgb_out(rgb));
 task frame;begin
 @(negedge clk);de=0;vs=0;repeat(5)@(negedge clk);
 vs=1;repeat(5)@(negedge clk);vs=0;repeat(5)@(negedge clk);
 end endtask
 task check_visible;begin
 seen=0;
 for(y=0;y<480;y=y+1)begin
 for(x=0;x<640;x=x+1)begin
 @(negedge clk);de=1;#1;
 if(x<480 && y<360)begin
 if(rgb!==24'h8090a0)$fatal(1,"visible endpoint mode=%0d xy=%0d,%0d rgb=%h",mode,x,y,rgb);
 seen=seen+1;end
 end
 @(negedge clk);de=0;repeat(3)@(negedge clk);
 end
 if(seen!=480*360)$fatal(1,"image viewport count");
 end endtask
 initial begin
 for(m=0;m<8;m=m+1)begin
 rst=1;req=0;commit=0;mode=m;repeat(5)@(negedge clk);rst=0;
 repeat(10)@(negedge clk);req=1;
 for(n=0;n<18;n=n+1)frame();
 if(dark!==1)$fatal(1,"dark acknowledgment missing mode=%0d",m);
 commit=1;for(n=0;n<18;n=n+1)frame();
 if(done!==1)$fatal(1,"commit acknowledgment missing mode=%0d",m);
 frame();check_visible();
 $display("PASS transition mode=%0d complete 480x360 visible",m);
 end
 test_pass=1;$display("RESULT PASS transitions=8 viewport=480x360");$finish;
 end
endmodule
