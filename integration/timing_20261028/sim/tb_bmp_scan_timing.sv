`timescale 1ns/1ps
module tb_bmp_scan_timing;
reg clk=0, rst=1, scan_start=0, valid=0, sec_end=0;
reg [7:0] data=0;
reg [31:0] max_sector=32'hffffffff;
wire [31:0] addr;
wire done, found;
reg test_passed=0;
integer cases=0;
always #5 clk=~clk;
bmp_read dut(.clk(clk),.rst(rst),.scan_start(scan_start),
 .scan_start_sector(32'd100),.scan_max_sector(max_sector),.scan_target_count(3'd4),
 .scan_done(done),.scan_found_valid(found),.load_start(1'b0),.load_sector(32'd0),
 .sd_init_done(1'b1),.bmp_width(16'd640),.bmp_height(16'd480),
 .write_req_ack(1'b0),.sd_sec_read_addr(addr),.sd_sec_read_data(data),
 .sd_sec_read_data_valid(valid),.sd_sec_read_end(sec_end));
function automatic [7:0] header_byte(input integer i,input [31:0] len,input bit good);
 begin
  case(i)
   0:header_byte=good ? 8'h42 : 8'h00;
   1:header_byte=8'h4d;
   2,3,4,5:header_byte=(len >> ((i-2)*8));
   10:header_byte=54;
   18:header_byte=8'h80;
   19:header_byte=8'h02;
   22:header_byte=8'he0;
   23:header_byte=8'h01;
   28:header_byte=24;
   default:header_byte=0;
  endcase
 end
endfunction
task automatic scan_case(input [31:0] len,input bit good,input bit limited,input bit stalls);
 reg [31:0] rounded, expected;
 integer i;
 begin
  @(negedge clk);rst=1;valid=0;sec_end=0;scan_start=0;
  repeat(2) @(negedge clk);
  rst=0;max_sector=limited ? 32'd100 : 32'hffffffff;
  scan_start=1;
  @(negedge clk);scan_start=0;
  for(i=0;i<512;i=i+1) begin
   valid=1;data=header_byte(i,len,good);
   @(negedge clk);
   if(stalls && i%7==0) begin valid=0;repeat(2) @(negedge clk);end
  end
  valid=0;sec_end=1;
  @(negedge clk);sec_end=0;
  rounded=len+32'd511;
  expected=good ? (100+((len==0) ? 32'd1 : (rounded>>9))) : (limited ? 100 : 101);
  if(addr!==expected || found!==good || done!==(limited && (!good || expected>100)))
   $fatal(1,"scan len=%h good=%b limit=%b addr=%h expected=%h done=%b found=%b",len,good,limited,addr,expected,done,found);
  cases=cases+1;
 end
endtask
initial begin
 scan_case(0,1,0,0);scan_case(1,1,0,1);
 scan_case(511,1,0,0);scan_case(512,1,0,1);scan_case(513,1,0,0);
 scan_case(921654,1,0,1);scan_case(921654,1,1,0);
 scan_case(32'hfffffe00,1,0,0);scan_case(32'hfffffe01,1,0,0);
 scan_case(32'hffffffff,1,0,1);
 scan_case(512,0,0,0);scan_case(512,0,1,1);
 test_passed=1;$display("SIM PASS BMP scan timing: %0d boundary/overflow/stall/end cases",cases);$finish;
end
initial begin #200000;$fatal(1,"timeout");end
endmodule
