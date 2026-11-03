`timescale 1ns/1ps
// Combinational substitution adds zero pixel latency; controls are untouched.
module zoom_diagnostics(
 input wire clk,rst,select_pattern,de,hs,vs,position_valid,
 input wire [9:0] x,
 input wire [8:0] y,
 input wire [23:0] rgb,
 input wire [1:0] read_health,
 output wire [23:0] rgb_out,
 output wire [7:0] health
);
reg prev_hs,prev_vs,seen_hs,seen_vs,seen_de,seen_position;
always @(posedge clk or posedge rst) begin
 if(rst) begin
  prev_hs<=0;prev_vs<=0;seen_hs<=0;seen_vs<=0;seen_de<=0;seen_position<=0;
 end else begin
  prev_hs<=hs;prev_vs<=vs;
  if(prev_hs!=hs) seen_hs<=1;
  if(prev_vs!=vs) seen_vs<=1;
  if(de) seen_de<=1;
  if(position_valid) seen_position<=1;
 end
end
assign health={2'd0,read_health,seen_hs,seen_vs,seen_de,seen_position};
assign rgb_out=select_pattern ? ((x[5]^y[5]) ? 24'he0e0a0 : 24'hffffff) : rgb;
endmodule
