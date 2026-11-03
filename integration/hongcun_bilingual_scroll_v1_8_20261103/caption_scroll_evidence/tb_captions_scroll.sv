`timescale 1ns/1ps
module tb_captions_scroll;
 reg clk=0;always #20 clk=~clk;
 reg rst=1,vs=1,de=0,dir=0;reg [1:0] lang=3,speed=0;reg [2:0] image=0;
 reg [9:0] x=0;reg [8:0] y=416;
 wire [23:0] rgb;wire ode,oh,ov;wire [9:0] ox;wire [8:0] oy;
 osd_overlay dut(.clk(clk),.rst(rst),.enable(1'b1),.compact_layout(1'b1),
 .scale_mode(2'd1),.interpolation(1'b1),.transition_mode(3'd0),.image_valid(1'b1),
 .image_index(image),.auto_play(1'b0),.sw_code(4'd12),.setting_value(4'd3),
 .brightness(4'd5),.contrast(4'd5),.sub_mode(lang),.text_mode(2'd0),
 .scroll_speed(speed),.scroll_dir(dir),.in_rgb(24'hff00ff),.in_de(de),.in_hs(1'b1),
 .in_vs(vs),.in_x(x),.in_y(y),.out_rgb(rgb),.out_de(ode),.out_hs(oh),.out_vs(ov),.out_x(ox),.out_y(oy));
 integer zstart[0:4],zlen[0:4],estart[0:4],elen[0:4];
 reg [255:0] zbits[0:255];reg [7:0] eletters[0:1023];reg [63:0] ebits[0:255];
 integer rz=0,re=0,pause_left=60,step,zwidth,ewidth,ztotal,etotal;
 integer k,p,m,xx,yy,loopcount,zc,ec,checks=0,rendered=0;
 reg [23:0] expected[0:2];reg [9:0] ex[0:2];reg [8:0] ey[0:2];reg [2:0] ede=0;
 reg [2:0] evs=7;reg test_pass=0;integer ci,idx,local_x;reg [23:0] sample;
 function [23:0] reference_pixel;
 input integer px,py;
 integer loc,idx,bitno;begin
 reference_pixel=24'h000000;
 if(px>=16 && px<624)begin
 loc=px-16+16*zlen[image]-rz;
 if((lang==1 || lang==3) && py>=432 && py<448 && loc>=0 && loc<16*zlen[image])begin
 idx=zstart[image]+loc/16;bitno=255-((py-432)*16+loc%16);
 if(zbits[idx][bitno])reference_pixel=24'hf2f4f6;
 end
 loc=px-16+8*elen[image]-re;
 if((lang==2 || lang==3) && py>=456 && py<472 && loc>=0 && loc<8*elen[image])begin
 idx=estart[image]+loc/8;bitno=63-(((py-456)/2)*8+loc%8);
 if(ebits[eletters[idx]][bitno])reference_pixel=24'ha8b3c0;
 end end end endfunction
 always @(posedge clk)begin
 if(rst)begin ede=0;evs=0;for(k=0;k<3;k=k+1)begin expected[k]=0;ex[k]=0;ey[k]=0;end end
 else begin
 expected[2]=expected[1];expected[1]=expected[0];expected[0]=de?reference_pixel(x,y):0;
 ex[2]=ex[1];ex[1]=ex[0];ex[0]=x;ey[2]=ey[1];ey[1]=ey[0];ey[0]=y;
 ede={ede[1:0],de};evs={evs[1:0],vs};
 #1;
 if(ode!==ede[2] || ov!==evs[2])$fatal(1,"DE/VS latency mismatch");
 if(ode)begin
 if(ox!==ex[2] || oy!==ey[2] || oh!==1'b1)$fatal(1,"coordinate/HS latency mismatch");
 if(rgb!==expected[2])$fatal(1,"pixel image=%0d lang=%0d x=%0d y=%0d got=%h expected=%h rz=%0d re=%0d",image,lang,ox,oy,rgb,expected[2],rz,re);
 checks=checks+1;if(rgb==24'hf2f4f6)zc=zc+1;if(rgb==24'ha8b3c0)ec=ec+1;
 end end end
 task select_image(input integer which);begin
 @(negedge clk);de=0;vs=1;image=which;rz=zlen[which]*16;re=elen[which]*8;pause_left=60;
 repeat(5)@(negedge clk);
 if(dut.zh_pos!==rz || dut.en_pos!==re)$fatal(1,"image change did not reset both captions");
 end endtask
 task frames(input integer count);integer f;begin
 for(f=0;f<count;f=f+1)begin
 @(negedge clk);de=0;vs=1;repeat(3)@(negedge clk);vs=0;
 if(pause_left>0)pause_left=pause_left-1;
 else begin
 step=1<<speed;ztotal=zlen[image]*16+608;etotal=elen[image]*8+608;
 if(dir)begin rz=(rz+step>=ztotal)?0:rz+step;re=(re+step>=etotal)?0:re+step;end
 else begin rz=(rz<step)?ztotal:rz-step;re=(re<step)?etotal:re-step;end
 end
 repeat(4)@(negedge clk);
 if(dut.zh_pos!==rz || dut.en_pos!==re || dut.zh_pause!==pause_left)$fatal(1,"scroll model mismatch image=%0d speed=%0d dir=%0d rz=%0d/%0d re=%0d/%0d pause=%0d",image,speed,dir,rz,dut.zh_pos,re,dut.en_pos,pause_left);
 end end endtask
 task render;begin
 zc=0;ec=0;
 for(yy=416;yy<480;yy=yy+1)begin
 for(xx=0;xx<640;xx=xx+1)begin @(negedge clk);de=1;x=xx;y=yy;end
 @(negedge clk);de=0;repeat(4)@(negedge clk);
 end
 rendered=rendered+1;
 end endtask
 initial begin
 for(ci=0;ci<256;ci=ci+1)ebits[ci]=0;
 `include "golden.svh"
 zc=0;ec=0;repeat(5)@(negedge clk);rst=0;rz=zlen[0]*16;re=elen[0]*8;
 repeat(5)@(negedge clk);
 // Exhaustive text-table check, including every final character.
 for(p=0;p<5;p=p+1)begin
 if(dut.cap_len(p)!=zlen[p] || dut.en_len(p)!=elen[p])$fatal(1,"caption length mismatch");
 for(ci=0;ci<elen[p];ci=ci+1)if(dut.en_char(dut.en_start(p)+ci)!==eletters[estart[p]+ci])$fatal(1,"English text mismatch");
 for(ci=0;ci<zlen[p];ci=ci+1)begin
 for(idx=0;idx<16;idx=idx+1)
 if(dut.zh_glyph_row(dut.cap_char(dut.cap_start(p)+ci),idx)!==zbits[zstart[p]+ci][255-16*idx-:16])$fatal(1,"Chinese text/glyph mismatch");
 end end
 for(p=0;p<5;p=p+1)begin
 select_image(p);
 for(m=0;m<4;m=m+1)begin lang=m;render();
 if((m==1 || m==3)?zc<100:zc!=0)$fatal(1,"Chinese mode gating");
 if((m==2 || m==3)?ec<100:ec!=0)$fatal(1,"English mode gating");
 end
 lang=3;frames(60);render();frames(73);render();
 // Tail and wrap positions exercise the full English string, not just its prefix.
 frames(elen[p]*8-73);render();frames(610);render();
 end
 // Short Chinese must also move; all speed/direction settings and reverse in flight.
 select_image(3);lang=3;frames(60);
 for(m=0;m<3;m=m+1)begin speed=m;dir=0;frames(19);render();dir=1;frames(23);render();end
 // Five-to-one commit resets both positions at their full-text start.
 select_image(4);frames(90);select_image(0);render();
 // Reset while English is partially visible.
 @(negedge clk);rst=1;repeat(4)@(negedge clk);rst=0;rz=zlen[0]*16;re=elen[0]*8;pause_left=60;
 repeat(5)@(negedge clk);render();
 test_pass=1;$display("RESULT PASS full bilingual captions five images four modes; all characters, pause, speeds, directions, tail/wrap, reset, 5-to-1; renders=%0d pixels=%0d; RGB/DE/HS/VS/XY latency=3",rendered,checks);$finish;
 end
 initial begin #1000000000;$fatal(1,"timeout");end
endmodule
