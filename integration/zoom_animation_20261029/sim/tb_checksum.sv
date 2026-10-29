`timescale 1ns/1ps
module tb_checksum;
reg sc=0,mc=0,rst=1,upload_req=0,uv=0,rr=0,rready=0;
always #5 sc=~sc;always #4 mc=~mc;
reg [15:0] w=1024,h=1024,ri=0;
reg [23:0] up=0;
wire ready,valid,rack,rv,hold,active,ren,wen,error;
wire [23:0] rp;
wire [20:0] addr;
wire [31:0] data;
reg [31:0] returns[0:5];
reg [5:0] rvalid=0;
integer tick=0,sd_tick=0,legacy_count=0,accepted=0,written=0,got=0,pattern=0,loads=0,rows=0,j,cycles;
reg took=0,row_took=0,test_pass=0;
reg inject=0; wire [19:0] check_status;
reg [12:0] packet_page;
reg [23:0] captured;
zoom_source_cache dut(.rst(rst),.sd_clk(sc),.mem_clk(mc),.upload_req(upload_req),.src_w(w),.src_h(h),
 .upload_valid(uv),.upload_pixel(up),.upload_ready(ready),.cache_valid(valid),.row_req(rr),.row_index(ri),
 .row_ack(rack),.row_valid(rv),.row_pixel(rp),.row_ready(rready),.legacy_hold(hold),.legacy_busy(legacy_count!=0),
 .aux_active(active),.aux_read(ren),.aux_write(wen),.aux_addr(addr),.aux_data(data),
 .init_done(!rst),.refresh_busy(tick%1024<8),.sdr_busy(tick%1024<8),
 .read_valid(rvalid[5]),.read_data(returns[5]),.cache_error(error),.checksum_status(check_status));
function automatic [23:0] colour(input integer index);
 colour={8'(index%w+pattern*19),8'(h-1-index/w+pattern*23),8'(index%w+index/w+pattern*31)};
endfunction
always @(posedge mc) begin
 tick<=tick+1;
 if(rst) begin rvalid<=0;legacy_count<=0;end
 else begin
  if(legacy_count!=0) legacy_count<=legacy_count-1;
  else if(!hold && tick%257==0) legacy_count<=128;
  rvalid<={rvalid[4:0],ren};
  if(ren) begin
   if(addr<614400 || addr>=614400+w*h) $fatal(1,"source read out of range");
   returns[0]<={colour(addr-614400),8'd0} ^ ((inject && (addr-614400)%w==7) ? 32'h00000100 : 32'd0);
  end
  for(j=1;j<6;j=j+1) returns[j]<=returns[j-1];
  if((wen || ren) && legacy_count!=0) $fatal(1,"cache command overlaps legacy owner");
  if(ren || wen) begin
   if(dut.issued==0) packet_page=addr[20:8];
   else if(packet_page!=addr[20:8]) $fatal(1,"auxiliary packet crossed SDRAM column boundary");
   if(dut.block_len>8) $fatal(1,"auxiliary packet exceeds eight words");
  end
  if(wen) begin
   if(dut.issued==0 && dut.block_len!=(w*h-written>=8 ? 8:w*h-written)) $fatal(1,"upload packet not coalesced");
   if(addr!==614400+written || data!=={colour(written),8'd0}) $fatal(1,"upload address/data mismatch count=%0d addr=%0d data=%h",written,addr,data);
   written=written+1;
  end
  if(error) $fatal(1,"cache FIFO overflow/underflow");
 end
end
always @(posedge sc) begin
 took<=uv && ready;row_took<=rv && rready;captured<=rp;
end
task automatic upload(input integer width,height,pat);
 begin
 @(negedge sc);w=width;h=height;pattern=pat;accepted=0;written=0;upload_req=1;uv=0;
 repeat(12) @(negedge sc);upload_req=0;
 up=colour(0);uv=1;cycles=0;
 while(accepted<w*h && cycles<40000000) begin
  @(negedge sc);cycles=cycles+1;
  if(took) begin accepted=accepted+1;if(accepted<w*h) up=colour(accepted);end
 end
 uv=0;
 while(!valid && cycles<40000000) begin @(negedge sc);cycles=cycles+1;end
 if(!valid || written!=w*h || accepted!=w*h) $fatal(1,"cache upload timeout accepted=%0d written=%0d",accepted,written);
 loads=loads+1;$display("PASS cache upload=%0dx%0d words=%0d cycles=%0d",w,h,written,cycles);
 end
endtask
task automatic read_row(input integer row);
 begin
 @(negedge sc);ri=row;rr=1;got=0;cycles=0;rready=0;
 while(!rack && cycles<100000) begin @(negedge sc);cycles=cycles+1;end
 if(!rack) $fatal(1,"row request timeout");rr=0;
 while(got<w && cycles<100000) begin
  @(negedge sc);cycles=cycles+1;
  if(row_took) begin
   if(!inject && captured!==colour(row*w+got)) $fatal(1,"row pixel mismatch row=%0d x=%0d got=%h expected=%h",row,got,captured,colour(row*w+got));
   got=got+1;
  end
  rready=cycles%17>4;
 end
 rready=0;
 while(rack && cycles<100000) begin @(negedge sc);cycles=cycles+1;end
 if(got!=w || rack) $fatal(1,"row stream did not finish");
 rows=rows+1;$display("PASS cache row=%0d pixels=%0d",row,got);
 end
endtask
initial begin
 repeat(12) @(negedge sc);rst=0;
 upload(241,4,1);read_row(0);read_row(1);
 repeat(10) @(negedge sc);
 if(check_status[19:18]!==2'b10 || check_status[7:0]!=2) $fatal(1,"clean rows status=%h",check_status);
 inject=1;read_row(2);inject=0;repeat(10) @(negedge sc);
 if(check_status[19:18]!==2'b11 || check_status[17:8]!=2 || check_status[7:0]!=3) $fatal(1,"corruption missed status=%h",check_status);
 read_row(3);repeat(10) @(negedge sc);
 if(check_status[17:8]!=2 || check_status[7:0]!=4 || !check_status[18]) $fatal(1,"sticky status lost %h",check_status);
 upload(240,3,2);read_row(1);repeat(10) @(negedge sc);
 if(check_status[19:18]!==2'b10 || check_status[7:0]!=1) $fatal(1,"session reset failed %h",check_status);
 $display("RESULT PASS checksum clean=PASS injected_bit=DETECTED first_row=2 sticky=PASS reload=PASS odd_even_width=PASS");
 test_pass=1;$finish;
end
endmodule
