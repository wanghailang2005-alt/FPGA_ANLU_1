`timescale 1ns/1ps
module sdram_diag_top(input clk,rst_n,output [5:0] seg_sel,output [7:0] seg_data);
wire mem_clk,shift_clk,unused_sd_clk;
sys_pll sys_pll_m0(.refclk(clk),.reset(1'b0),.clk0_out(unused_sd_clk),
 .clk1_out(mem_clk),.clk2_out(shift_clk));
reg [17:0] startup=0;
always @(posedge mem_clk) if(!(&startup)) startup<=startup+1'b1;
wire async_rst=!rst_n || !(&startup);
(* ASYNC_REG="TRUE" *) reg [2:0] reset_sync=3'b111;
always @(posedge mem_clk or posedge async_rst)
 if(async_rst) reset_sync<=3'b111;else reset_sync<={reset_sync[1:0],1'b0};
wire rst=reset_sync[2];
wire init_done,ref_active,mem_busy,wr_en,rd_en,rd_valid;
wire [20:0] wr_addr,rd_addr;
wire [31:0] wr_data,rd_data;
wire [3:0] phase;
wire [19:0] errors;
wire [15:0] passes;
wire timed_out,first_valid;
wire [20:0] first_addr;
wire [31:0] first_expected,first_actual;
sdram u_mem(.Clk(mem_clk),.Clk_sft(shift_clk),.Rst(rst),
 .Sdr_init_done(init_done),.Sdr_init_ref_vld(ref_active),.Sdr_busy(mem_busy),
 .App_wr_en(wr_en),.App_wr_addr(wr_addr),.App_wr_dm(4'd0),.App_wr_din(wr_data),
 .App_rd_en(rd_en),.App_rd_addr(rd_addr),.Sdr_rd_en(rd_valid),.Sdr_rd_dout(rd_data));
sdram_diag_core u_test(.clk(mem_clk),.rst(rst),.init_done(init_done),
 .ref_active(ref_active),.mem_busy(mem_busy),.wr_en(wr_en),.rd_en(rd_en),
 .wr_addr(wr_addr),.rd_addr(rd_addr),.wr_data(wr_data),.rd_valid(rd_valid),.rd_data(rd_data),
 .phase(phase),.errors(errors),.passes(passes),.timed_out(timed_out),
 .first_valid(first_valid),.first_addr(first_addr),
 .first_expected(first_expected),.first_actual(first_actual));
// All display logic runs at mem_clk; there is no diagnostic bus CDC.
reg [26:0] page_timer;
reg [2:0] page;
reg [23:0] display;
always @(posedge mem_clk or posedge rst) begin
 if(rst) begin page_timer<=0;page<=0;display<=0;end
 else begin
  if(page_timer==125000000-1) begin page_timer<=0;page<=page==6 ? 0 : page+1'b1;end
  else page_timer<=page_timer+1'b1;
  case(page)
   0:display<={timed_out ? 4'hf : (errors!=0 ? 4'he : (passes!=0 ? 4'ha : phase)),errors};
   1:display<={4'hb,4'd0,passes};
   2:display<={3'b110,first_addr};
   3:display<={4'hd,first_expected[19:0]};
   4:display<={4'he,first_actual[19:0]};
   5:display<={4'h5,8'd0,first_expected[31:20]};
   default:display<={4'h6,8'd0,first_actual[31:20]};
  endcase
 end
end
wire [6:0] digit[0:5];
genvar i;
generate for(i=0;i<6;i=i+1) begin: decode
 seg_decoder u_dec(.bin_data(display[23-i*4 -: 4]),.seg_data(digit[i]));
end endgenerate
seg_scan #(.CLK_FREQ(125000000)) u_scan(.clk(mem_clk),.rst_n(!rst),
 .seg_sel(seg_sel),.seg_data(seg_data),
 .seg_data_0({1'b1,digit[0]}),.seg_data_1({1'b1,digit[1]}),
 .seg_data_2({1'b1,digit[2]}),.seg_data_3({1'b1,digit[3]}),
 .seg_data_4({1'b1,digit[4]}),.seg_data_5({1'b1,digit[5]}));
endmodule
