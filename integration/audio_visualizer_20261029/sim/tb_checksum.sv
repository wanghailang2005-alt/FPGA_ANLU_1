`timescale 1ns/1ps
module tb_checksum;
 reg sc=0,mc=0,rst=1;
 always #5 sc=~sc;
 always #4 mc=~mc;
 reg write_valid=0,return_valid=0,new_session=0;
 reg [20:0] column=0;
 reg [15:0] row_number=0;
 reg [31:0] data=0;
 wire [19:0] status;
 reg test_pass=0;
 integer r,c,n;
 zoom_source_cache dut(.rst(rst),.sd_clk(sc),.mem_clk(mc),.upload_req(1'b0),.src_w(16'd4),.src_h(16'd4),
  .upload_valid(1'b0),.upload_pixel(24'd0),.row_req(1'b0),.row_index(16'd0),.row_ready(1'b1),
  .legacy_busy(1'b0),.init_done(1'b0),.refresh_busy(1'b0),.sdr_busy(1'b0),.read_valid(1'b0),.read_data(data),.checksum_status(status));
 function automatic [31:0] word(input integer row,col);
  word=32'h12345600+row*32'h10000+col*32'h1700;
 endfunction
 task read_row(input integer row,corrupt);
  @(negedge mc);row_number=row;
  repeat(3) @(negedge mc);
  for(integer j=0;j<4;j=j+1) begin
   return_valid=1;column=j;data=word(row,j)^((corrupt && j==2) ? 32'h100:32'h0);
   @(negedge mc);
  end
  return_valid=0;repeat(3) @(negedge mc);
 endtask
 initial begin
  force dut.aux_write=write_valid;
  force dut.aux_data=data;
  force dut.return_to_row=return_valid;
  force dut.row_returned=column;
  force dut.width=16'd4;
  force dut.row_index_mem=row_number;
  force dut.req_sync=new_session;
  repeat(4) @(negedge mc);rst=0;
  for(r=0;r<4;r=r+1) for(c=0;c<4;c=c+1) begin
   @(negedge mc);write_valid=1;data=word(r,c);
  end
  @(negedge mc);write_valid=0;
  read_row(3,0);
  if(status!=={1'b1,1'b0,10'd0,8'd1}) $fatal(1,"clean row status %h",status);
  read_row(1,1);
  if(status!=={1'b1,1'b1,10'd1,8'd2}) $fatal(1,"first mismatch status %h",status);
  read_row(2,1);
  if(status!=={1'b1,1'b1,10'd1,8'd3}) $fatal(1,"sticky first bad row %h",status);
  for(n=0;n<260;n=n+1) read_row(3,0);
  if(status!=={1'b1,1'b1,10'd1,8'hff}) $fatal(1,"saturating count %h",status);
  // A new upload cancels a pending old row check.
  @(negedge mc);row_number=3;
  repeat(3) @(negedge mc);
  for(c=0;c<4;c=c+1) begin return_valid=1;column=c;data=word(3,c);@(negedge mc);end
  return_valid=0;new_session=1;
  @(negedge mc);new_session=0;repeat(3) @(negedge mc);
  if(status!==0) $fatal(1,"new-session cancellation %h",status);
  rst=1;@(negedge mc);if(status!==0) $fatal(1,"checksum reset");
  $display("RESULT PASS checksum clean mismatch first_bad_sticky count_saturation pending_cancel reset");
  test_pass=1;$finish;
 end
 initial begin #100000;$fatal(1,"checksum watchdog");end
endmodule
