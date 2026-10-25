`timescale 1ns/1ps
module tb_ack_release;
reg clk=0,mem_clk=0,rst=1;
always #5 clk=~clk;
initial begin #3; forever #4 mem_clk=~mem_clk; end
reg [7:0] card_byte=0;reg card_valid=0,card_end=0;
wire req,we;wire [31:0] data;
reg raw_ack=0;reg [2:0] req_sync=0;integer hold=0,release_delay=17;
reg test_passed=0;integer i,c,frames=0,pixels=0;
reg handshake_started=0;
sd_card_bmp dut(.clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),
.state_code(),.pixel_count_debug(),.storage_diag_sd(80'd0),.storage_diag_write(3'd0),
.bmp_width(16'd1),.bmp_height(16'd1),.display_valid(),.osd_status(),
.write_finish_toggle(1'b0),.write_buf_idx(),.disp_buf_idx(),
.write_req(req),.write_req_ack(raw_ack),.write_en(we),.write_data(data),
.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1));
// Held-ACK/FIFO-clear protocol responder, not a memory or card implementation.
always @(posedge mem_clk or posedge rst) begin
 if(rst) begin raw_ack<=0;req_sync<=0;hold<=0;end
 else begin
  req_sync<={req_sync[1:0],req};
  if(req_sync[2]) begin raw_ack<=1;hold<=release_delay;end
  else if(raw_ack) begin
   if(hold!=0) hold<=hold-1;else raw_ack<=0;
  end
 end
end
always @(posedge clk) begin
 if(rst) pixels<=0;
 else begin
  if(we) begin
   if(raw_ack) $fatal(1,"pixel emitted during FIFO clear");
   if(data!==32'h11223300) $fatal(1,"first pixel corrupted %h",data);
   pixels<=pixels+1;
  end
  if(handshake_started && raw_ack && dut.sd_sec_read)
   $fatal(1,"sector requested before FIFO clear released");
 end
end
function [7:0] file_byte(input integer index);
 begin
 case(index)
  0:file_byte="B";1:file_byte="M";2:file_byte=57;
  10:file_byte=54;18:file_byte=1;22:file_byte=1;28:file_byte=24;
  54:file_byte=8'h33;55:file_byte=8'h22;56:file_byte=8'h11;
  default:file_byte=0;
 endcase
 end
endfunction
task send_bytes(input integer count);
 begin
 for(i=0;i<count;i=i+1) begin
  card_byte=file_byte(i);card_valid=1;@(negedge clk);
 end
 card_valid=0;card_end=1;@(negedge clk);card_end=0;
 end
endtask
task start_load;
 begin
 force dut.load_start_pulse=1;@(negedge clk);release dut.load_start_pulse;
 wait(dut.sd_sec_read);@(negedge clk);send_bytes(54);
 wait(req);handshake_started=1;
 end
endtask
initial begin
 force dut.sd_init_done=1;force dut.scan_kicked=1;force dut.scan_done=1;
 force dut.img_found_count=0;force dut.load_sector=0;
 force dut.sd_sec_read_data=card_byte;
 force dut.sd_sec_read_data_valid=card_valid;
 force dut.sd_sec_read_end=card_end;
 repeat(4) @(negedge clk);rst=0;
 // First transfer: delayed ACK deassertion exercises the original ordering gap.
 for(c=0;c<3;c=c+1) begin
  release_delay=17+c*3;
  start_load();wait(!req);
  repeat(3) @(negedge clk);
  if(!raw_ack || req || dut.sd_sec_read)
   $fatal(1,"must wait for held ACK to drop");
  wait(dut.sd_sec_read);@(negedge clk);send_bytes(57);
  wait(dut.bmp_ready);repeat(3) @(negedge clk);
  if(pixels!=c+1) $fatal(1,"wrong pixel count %0d",pixels);
  handshake_started=0;frames=frames+1;
 end
 // Reset in release-wait, then verify another complete request can recover.
 start_load();wait(!req);@(negedge clk);rst=1;
 handshake_started=0;repeat(4) @(negedge clk);
 if(req || we || raw_ack) $fatal(1,"reset did not clear handshake");
 rst=0;start_load();wait(dut.sd_sec_read);@(negedge clk);send_bytes(57);
 wait(dut.bmp_ready);repeat(3) @(negedge clk);
 if(pixels!=1) $fatal(1,"recovery pixel count");
 test_passed=1;$display("SIM PASS ACK release: three transfers, delayed clear, first pixel, reset/recovery");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
