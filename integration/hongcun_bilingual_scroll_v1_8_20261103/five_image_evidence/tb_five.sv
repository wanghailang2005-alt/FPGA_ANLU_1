`timescale 1ns/1ps
module tb_five;
reg clk=0; always #5 clk=~clk;
reg rst=1,start=0,load=0; wire ready,done,found,req,ld,err,pv,wr; wire [2:0] total; wire [31:0] addr,sector; wire [23:0] pixel;
reg [7:0] data=0; reg valid=0,last=0; integer n=0,pos=0,base=0,pixels=0,cycles=0; reg active=0,waitlow=0; reg test_pass=0;
reg [31:0] img_sector0=0,img_sector1=1,img_sector2=2,img_sector3=3,img_sector4=4;
function [2:0] next_index_limited;
 input [2:0] cur;
 input [2:0] count;
 begin
 if(count<=3'd1 || cur>=count-3'd1 || cur>=3'd4) next_index_limited=3'd0;
 else next_index_limited=cur+3'd1;
 end
endfunction
function [31:0] sector_lut;
 input [2:0] idx;
 begin
 case(idx)
 3'd0: sector_lut=img_sector0;
 3'd1: sector_lut=img_sector1;
 3'd2: sector_lut=img_sector2;
 3'd3: sector_lut=img_sector3;
 3'd4: sector_lut=img_sector4;
 default: sector_lut=img_sector0;
 endcase
 end
endfunction

bmp_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(start),.scan_start_sector(32'd0),.scan_max_sector(32'd100),.scan_target_count(3'd5),.scan_done(done),.scan_found_valid(found),.scan_found_sector(sector),.scan_found_signature(),.scan_found_total(total),.load_start(load),.load_sector(32'd4),.load_done(ld),.load_error(err),.load_error_code(),.load_error_retries(),.load_error_sector(),.load_error_signature(),.sd_init_done(1'b1),.state_code(),.bmp_width(16'd640),.bmp_height(16'd480),.write_req(wr),.write_req_ack(wr),.sd_sec_read(req),.sd_sec_read_addr(addr),.sd_sec_read_data(data),.sd_sec_read_data_valid(valid),.sd_sec_read_end(last),.bmp_data_wr_en(pv),.bmp_data(pixel),.src_w(),.src_h(),.src_accept(1'b1));
function [7:0] filebyte(input integer k,input integer image);
begin
filebyte=0;
case(k)
0:filebyte="B";1:filebyte="M";2:filebyte=70;10:filebyte=54;14:filebyte=40;18:filebyte=2;22:filebyte=2;26:filebyte=1;28:filebyte=24;
54,57,62,65:filebyte=image+1;
endcase
end endfunction
always @(posedge clk) begin
valid<=0;last<=0;cycles<=cycles+1;
if(cycles>30000) $fatal(1,"timeout");
if(rst) begin active<=0;waitlow<=0;end
else if(waitlow) begin if(!req) waitlow<=0;end
else if(!active) begin if(req) begin active<=1;pos<=0;base<=addr;end end
else if(pos==512) begin last<=1;active<=0;waitlow<=1;end
else begin data<=filebyte(pos,base);valid<=1;pos<=pos+1;end
if(found) begin if(sector!==n) $fatal(1,"scan sector mismatch");n=n+1;end
if(pv) begin if(pixel!==24'h000005) $fatal(1,"fifth image pixel mismatch %h",pixel);pixels=pixels+1;end
if(err) $fatal(1,"load error");
end
integer count,idx;
initial begin
for(count=0;count<=5;count=count+1) begin
for(idx=0;idx<5;idx=idx+1) begin
if(next_index_limited(idx,count)!==((count<=1 || idx>=count-1)?0:idx+1)) $fatal(1,"wrap mismatch");
end end
if(sector_lut(4)!==4) $fatal(1,"fifth lookup");
repeat(5) @(negedge clk);rst=0; wait(ready); @(negedge clk);start=1;@(negedge clk);start=0;
wait(done);repeat(3) @(negedge clk);if(total!=5 || n!=5) $fatal(1,"scan count");
wait(ready);@(negedge clk);load=1;@(negedge clk);load=0;
wait(ld);repeat(10) @(negedge clk);if(pixels!=4) $fatal(1,"pixel count %d",pixels);
test_pass=1;$display("PASS: five sectors, fifth BMP pixels, wrap counts 0..5");$finish;
end
endmodule

