`timescale 1ns/1ps
// Real BMP/scaler/load controller; models only SD-sector and SDRAM/transition boundaries.
module tb_card;
reg clk=0; always #5 clk=~clk;
reg rst=1,key_next=1,key_auto=1;
reg [1:0] scale_mode=0;
reg diagnostic_gray=0,frame_gray=0;
reg [8:0] usedw=0;
wire req,write_en,commit,transition_req,display_valid;
wire [31:0] write_data;
wire [1:0] bank,display_bank;
reg ack=0,finish_toggle=0,dark=0,transition_done=0;
reg last_req=0,last_commit=0;
integer commits=0,transactions=0,count=0,tick=0,ack_count=0;
integer iw=321,ih=241,im,ww,hh,ox,oy,x,y,fx,fy,sx,sy;
reg [31:0] expected;
reg test_pass=0;
localparam STRIDE=964, FILE_LEN=54+STRIDE*241, SECTORS=(FILE_LEN+511)/512;
sd_card_bmp #(.CLK_FREQ_HZ(1000),.SCAN_MAX_SECTOR(100000)) dut(
 .clk(clk),.rst(rst),.key_next(key_next),.key_auto(key_auto),
 .scale_mode(scale_mode),.write_fifo_usedw(usedw),.diagnostic_gray_requested(diagnostic_gray),.diagnostic_source(),
 .transition_dark_toggle(dark),.transition_done_toggle(transition_done),
 .transition_req_toggle(transition_req),.transition_commit_toggle(commit),
 .state_code(),.pixel_count_debug(),.bmp_width(16'd640),.bmp_height(16'd480),
 .display_valid(display_valid),.osd_status(),.storage_diag_sd(80'd0),.storage_diag_write(3'd0),
 .write_finish_toggle(finish_toggle),.write_buf_idx(bank),.disp_buf_idx(display_bank),
 .write_req(req),.write_req_ack(ack),.write_en(write_en),.write_data(write_data),
 .SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1));
function automatic [23:0] colour(input integer xx,yy);
 colour={8'(xx),8'(yy),8'(xx+yy)};
endfunction
function automatic [7:0] file_byte(input integer address);
 integer addr,k,row,col,v;
 begin
 addr=address%(SECTORS*512); file_byte=0;
 if(address>=4*SECTORS*512) file_byte=0;
 else if(addr==0) file_byte="B";
 else if(addr==1) file_byte="M";
 else if(addr>=2 && addr<=5) file_byte=(FILE_LEN>>((addr-2)*8))&255;
 else if(addr==10) file_byte=54;
 else if(addr==14) file_byte=40;
 else if(addr>=18 && addr<=21) file_byte=(iw>>((addr-18)*8))&255;
 else if(addr>=22 && addr<=25) file_byte=(ih>>((addr-22)*8))&255;
 else if(addr==26) file_byte=1;
 else if(addr==28) file_byte=24;
 else if(addr>=54 && addr<FILE_LEN) begin
   k=addr-54; row=ih-1-k/STRIDE; col=(k%STRIDE)/3;
   v=colour(col,row); file_byte=k%STRIDE>=iw*3 ? 8'ha5 : (v>>(8*((k%STRIDE)%3)))&255;
 end
 end
endfunction
always @(posedge clk) begin
 tick<=tick+1;
 usedw<=tick%997<111 ? 400 : 0;
 if(rst) begin ack<=0; ack_count<=0; last_req<=0; last_commit<=0; dark<=0; transition_done<=0; end
 else begin
  if(req && !ack) begin if(ack_count==500) ack<=1; else ack_count<=ack_count+1; end
  if(!req) begin ack<=0; ack_count<=0; end
  if(tick%127==0) begin dark<=transition_req; transition_done<=commit; end
  last_req<=req; last_commit<=commit;
  if(req && !last_req) begin
    if(transactions!=0 && count!=307200) $fatal(1,"previous transaction incomplete");
    count=0; transactions=transactions+1; im=dut.load_scale_mode;frame_gray=diagnostic_gray;
    if(dut.load_sector!=dut.load_idx*SECTORS) $fatal(1,"wrong source sector for selected image");
    ww=iw; hh=ih;
    if(im!=0) begin
      if((iw*480<=ih*640 && im==1) || (iw*480>ih*640 && im==2)) begin hh=480; ww=iw*480/ih; end
      else begin ww=640; hh=ih*640/iw; end
    end
    ox=(640-ww)>>>1; oy=(480-hh)>>>1;
  end
  if(write_en) begin
    if(req || ack || count>=307200) $fatal(1,"write during clear or extra pixels");
    x=count%640; y=479-count/640; fx=x-ox; fy=y-oy; expected=0;
    if(fx>=0 && fy>=0 && fx<ww && fy<hh) begin sx=fx*iw/ww; sy=fy*ih/hh; expected={colour(sx,sy),8'd0}; end
    if(frame_gray) expected=32'hc0c0c000;
    if(write_data!==expected) $fatal(1,"card pipeline pixel mismatch mode=%0d idx=%0d",im,count);
    count=count+1;
    if(count==307200) finish_toggle<=~finish_toggle;
  end
  if(commit!=last_commit) begin
    if(count!=307200 || !display_valid) $fatal(1,"premature display commit");
    commits=commits+1;
    $display("PASS card commit=%0d image=%0d mode=%0d count=%0d",commits,dut.img_idx,im,count);
  end
 end
end
task automatic wait_commit(input integer target,index,md);
 integer cycles;
 begin
 cycles=0;
 while(commits<target && cycles<3000000) begin @(negedge clk); cycles=cycles+1; end
 if(commits!=target || dut.img_idx!=index || im!=md) $fatal(1,"commit target=%0d actual=%0d image=%0d mode=%0d",target,commits,dut.img_idx,im);
 end
endtask
task automatic press_next;
 begin key_next=0; repeat(40) @(negedge clk); key_next=1; repeat(40) @(negedge clk); end
endtask
task automatic press_auto;
 begin key_auto=0; repeat(40) @(negedge clk); key_auto=1; repeat(40) @(negedge clk); end
endtask
initial begin
 repeat(5) @(negedge clk); rst=0;
 wait_commit(1,0,0);
 scale_mode=1; wait_commit(2,0,1);
 scale_mode=2;
 wait(dut.load_busy); repeat(3000) @(negedge clk);
 scale_mode=0; // Mid-load update must not change the current transaction.
 wait_commit(3,0,2); wait_commit(4,0,0);
 repeat(300) @(negedge clk); press_next(); wait_commit(5,1,0);
 repeat(300) @(negedge clk); press_auto(); wait_commit(6,2,0); press_auto();
 repeat(3000) @(negedge clk);
 if(dut.load_busy || dut.auto_play_en || transactions!=6) $fatal(1,"unexpected reload after completion");
 diagnostic_gray=1;press_next();wait_commit(7,3,0);
 if(dut.diagnostic_source[60:50]!=321 || dut.diagnostic_source[49:39]!=241 ||
    dut.diagnostic_source[18:0]!=307200) $fatal(1,"diagnostic source snapshot mismatch");
 test_pass=1; $display("RESULT PASS card transactions=7 checked_pixels=%0d diagnostic_gray=PASS",7*307200); $finish;
end
endmodule

module sd_card_top #(parameter SPI_LOW_SPEED_DIV=248,SPI_HIGH_SPEED_DIV=0)(
 input wire clk,rst,SD_MISO,sd_sec_read,sd_sec_write,
 input wire [31:0] sd_sec_read_addr,sd_sec_write_addr,
 input wire [7:0] sd_sec_write_data,
 output wire SD_nCS,SD_DCLK,SD_MOSI,sd_init_done,sd_sec_write_data_req,sd_sec_write_end,
 output reg [7:0] sd_sec_read_data,
 output reg sd_sec_read_data_valid,sd_sec_read_end
);
assign SD_nCS=1; assign SD_DCLK=0; assign SD_MOSI=0;
assign sd_init_done=!rst; assign sd_sec_write_data_req=0; assign sd_sec_write_end=0;
integer pos=0,base=0,tick=0;
reg active=0,wait_low=0;
always @(posedge clk) begin
 tick<=tick+1; sd_sec_read_data_valid<=0; sd_sec_read_end<=0;
 if(rst) begin active<=0; wait_low<=0; pos<=0; sd_sec_read_data<=0; end
 else if(wait_low) begin if(!sd_sec_read) wait_low<=0; end
 else if(!active) begin if(sd_sec_read) begin active<=1; pos<=0; base<=sd_sec_read_addr*512; end end
 else if(pos==512) begin sd_sec_read_end<=1; active<=0; wait_low<=1; end
 else if(tick%7!=0) begin
    sd_sec_read_data<=tb_card.file_byte(base+pos); sd_sec_read_data_valid<=1; pos<=pos+1;
 end
end
endmodule

