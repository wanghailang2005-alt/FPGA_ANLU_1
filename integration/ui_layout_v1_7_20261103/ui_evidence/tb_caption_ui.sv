`timescale 1ns/1ps
module tb_caption_ui;
 reg clk=0,rst=1,vs=1,de=0;always #20 clk=~clk;
 reg [9:0] x=0;reg [8:0] y=0;reg [1:0] image=0,lang=3;reg dir=0;
 wire [23:0] rgb;wire ode,hs,ovs;wire [9:0] ox;wire [8:0] oy;
 integer p,m,xx,yy,n,zc,ec;integer signature,sig0,sig1;reg test_pass=0;
 osd_overlay dut(.clk(clk),.rst(rst),.enable(1'b1),.compact_layout(1'b1),
 .scale_mode(2'd1),.interpolation(1'b1),.transition_mode(3'd0),.image_valid(1'b1),
 .image_index(image),.auto_play(1'b0),.sw_code(4'd12),.setting_value(4'd3),
 .brightness(4'd5),.contrast(4'd5),.sub_mode(lang),.text_mode(2'd0),
 .scroll_speed(2'd0),.scroll_dir(dir),.in_rgb(24'hff00ff),.in_de(de),.in_hs(1'b1),
 .in_vs(vs),.in_x(x),.in_y(y),.out_rgb(rgb),.out_de(ode),.out_hs(hs),.out_vs(ovs),.out_x(ox),.out_y(oy));
 task tick(input integer count);begin
 de=0;for(n=0;n<count;n=n+1)begin
 @(negedge clk);vs=1;repeat(4)@(negedge clk);vs=0;repeat(4)@(negedge clk);
 end end endtask
 task render;begin
 zc=0;ec=0;signature=0;
 for(yy=416;yy<480;yy=yy+1)begin
 for(xx=0;xx<640;xx=xx+1)begin
 @(negedge clk);de=1;x=xx;y=yy;
 end
 @(negedge clk);de=0;repeat(4)@(negedge clk);
 end
 end endtask
 always @(posedge clk)begin #1;
 if(ode && oy>=416)begin
 if(rgb==24'hf2f4f6)begin
 if(oy<432 || oy>=448 || ox<16 || ox>=624)$fatal(1,"Chinese spill");
 zc=zc+1;signature=signature+ox+oy*640;end
 else if(rgb==24'ha8b3c0)begin
 if(oy<456 || oy>=472 || ox<16 || ox>=272)$fatal(1,"English spill");ec=ec+1;end
 else if(rgb!==24'h000000)$fatal(1,"nonopaque subtitle background");
 end end
 initial begin
 for(p=0;p<4;p=p+1)for(m=0;m<4;m=m+1)begin
 rst=1;de=0;image=p;lang=m;repeat(5)@(negedge clk);rst=0;tick(2);render();
 if((m==1 || m==3) ? zc<100:zc!=0)$fatal(1,"Chinese language gating");
 if((m==2 || m==3) ? ec<100:ec!=0)$fatal(1,"English language gating");
 end
 image=1;lang=3;tick(2);render();sig0=signature;tick(10);render();
 $display("pause sig0=%d sig1=%d pos=%d pause=%d",sig0,signature,dut.zh_pos,dut.zh_pause); if(signature!=sig0)$fatal(1,"long caption moved during initial pause");
 tick(70);render();if(signature==sig0)$fatal(1,"long caption did not scroll");
 dir=1;tick(5);render();sig1=signature;tick(5);render();
 if(signature==sig1)$fatal(1,"right-scroll caption did not move");
 image=0;tick(2);render();sig0=signature;tick(120);render();
 if(signature!=sig0)$fatal(1,"short caption should remain still");
 test_pass=1;$display("RESULT PASS captions 4 images x 4 languages, opaque background, pause, left/right scrolling, short stationary");$finish;
 end
endmodule
