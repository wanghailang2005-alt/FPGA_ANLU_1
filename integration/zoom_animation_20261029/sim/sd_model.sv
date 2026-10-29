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
 else if(!active) begin if(sd_sec_read) begin tb_system.sd_requests=tb_system.sd_requests+1;active<=1; pos<=0; base<=sd_sec_read_addr*512; end end
 else if(pos==512) begin sd_sec_read_end<=1; active<=0; wait_low<=1; end
 else if(tick%7!=0) begin
    sd_sec_read_data<=tb_system.file_byte(base+pos); sd_sec_read_data_valid<=1; pos<=pos+1;
 end
end
endmodule

