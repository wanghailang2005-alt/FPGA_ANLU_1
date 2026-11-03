// SD controller has a level request, byte VALID, then a one-cycle END.
// Insert a release cycle so a client cannot accidentally launch its old LBA.
module sd_music_arbiter(
 input clk,rst,input image_req,input [31:0] image_addr,
 output image_valid,image_end,
 input audio_req,input [31:0] audio_addr,
 output audio_grant,audio_valid,audio_end,
 output phy_req,output reg [31:0] phy_addr,input phy_valid,phy_end
);
 reg [1:0] owner;
 localparam IDLE=0,IMAGE=1,AUDIO=2,GAP=3;
 assign phy_req=(owner==IMAGE || owner==AUDIO) && !phy_end;
 assign image_valid=owner==IMAGE && phy_valid;
 assign image_end=owner==IMAGE && phy_end;
 assign audio_valid=owner==AUDIO && phy_valid;
 assign audio_end=owner==AUDIO && phy_end;
 assign audio_grant=owner==IDLE && audio_req;
 always @(posedge clk or posedge rst) begin
  if(rst) begin owner<=IDLE;phy_addr<=0;end
  else case(owner)
   IDLE: if(audio_req) begin owner<=AUDIO;phy_addr<=audio_addr;end
         else if(image_req) begin owner<=IMAGE;phy_addr<=image_addr;end
   IMAGE,AUDIO: if(phy_end) owner<=GAP;
   default: owner<=IDLE;
  endcase
 end
endmodule
