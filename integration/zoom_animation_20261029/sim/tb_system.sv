`timescale 1ns/1ps
module tb_system;
reg sc=0,mc=0,pc=0,rst=1;
always #5 sc=~sc;always #4 mc=~mc;always #20 pc=~pc;
reg key_next=1,key_auto=1;
reg [1:0] scale_mode=0;
reg interpolation=0;
wire req,we,wa,wf,display_valid,commit,treq,tdark,tdone,anim;
wire [31:0] wd,rd;
wire [1:0] wb,db;
wire [8:0] used,sd_status,mem_status;
wire [4:0] read_status,pixel_status;
wire cache_valid,upload_ready,upload_req,upload_valid,row_req,row_ack,row_valid,row_ready,cache_error;
wire [23:0] upload_pixel,row_pixel;
wire [15:0] cw,ch,row_index;
wire hold,legacy_busy,aux_active,aux_read,aux_write;
wire [20:0] aux_addr;
wire [31:0] aux_data;
wire fr,fw;
wire [20:0] fra,fwa;
wire [31:0] fwd;
wire ar=aux_active ? aux_read:fr,aw=aux_active ? aux_write:fw;
wire [20:0] ra=aux_active ? aux_addr:fra,wa_mem=aux_active ? aux_addr:fwa;
wire [31:0] wdata=aux_active ? aux_data:fwd;
reg [31:0] memory[0:1662975];
reg [5:0] ret_valid=0,ret_owner=0;
reg [31:0] ret_data[0:5];
reg finish_toggle=0;
wire video_req,video_ack,read_en,hs,vs,de;
wire [23:0] vrgb,out_rgb;
wire vhs,vvs,vde;
wire [1:0] read_diag;
wire [79:0] storage_diag;
wire [2:0] write_diag;
integer iw=240,ih=320;
localparam STRIDE=720,FILE_LEN=54+STRIDE*320,SECTORS=(FILE_LEN+511)/512;
integer memtick=0,sdtick=0,j,count=0,transactions=0,commits=0,sd_requests=0,upload_words=0;
integer ww,hh,ox,oy,x,y,fx,fy,sx,sy,im=0,active_image=0;
integer anim_commits=0,last_step_tick=0,max_step_cycles=0,last_req_tick=0;
reg frame_interp=0,req_last=0,commit_last=0,test_pass=0;
reg [31:0] expected;
reg [2:0] anim_sync=0;
reg video_started=0,read_en_last=0;
integer vindex=0,video_pixels=0,read_bank=0;
reg [31:0] video_expected;
reg [1:0] selected_read_bank=0;
integer bw[0:1],bh[0:1],selected_w,selected_h,visible_w,visible_h,visible_ox,visible_oy;
reg bi[0:1],selected_interp,visible_interp;
reg dma_req=0;
reg [1:0] dma_bank=0;
integer physical_write_count=0,vx,vy,vfx,vfy,vsx,vsy;
always @(posedge sc or posedge rst) begin
 if(rst) begin dma_req<=0;dma_bank<=0;end
 else begin dma_req<=req;dma_bank<=wb;end
end
integer ew,eh,gw0,gh0,gw1,gh1;
wire refresh=(memtick%4096<12);
sd_card_bmp #(.CLK_FREQ_HZ(1000000),.SCAN_MAX_SECTOR(100000)) dut(
 .clk(sc),.rst(rst),.key_next(key_next),.key_auto(key_auto),.scale_mode(scale_mode),.interpolation(interpolation),
 .diagnostic_gray_requested(1'b0),.diagnostic_source(),.cache_valid(cache_valid),.cache_upload_ready(upload_ready),
 .cache_upload_req(upload_req),.cache_upload_valid(upload_valid),.cache_upload_pixel(upload_pixel),.cache_source_w(cw),.cache_source_h(ch),
 .animation_active(anim),.cache_row_req(row_req),.cache_row_index(row_index),.cache_row_ack(row_ack),.cache_row_valid(row_valid),
 .cache_row_pixel(row_pixel),.cache_row_ready(row_ready),.write_fifo_usedw(used),.transition_dark_toggle(tdark),.transition_done_toggle(tdone),
 .transition_req_toggle(treq),.transition_commit_toggle(commit),.display_valid(display_valid),.osd_status(sd_status),
 .storage_diag_sd(storage_diag),.storage_diag_write(write_diag),.write_finish_toggle(finish_toggle),.write_buf_idx(wb),.disp_buf_idx(db),
 .write_req(req),.write_req_ack(wa),.write_en(we),.write_data(wd),.bmp_width(16'd640),.bmp_height(16'd480),
 .SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),.state_code(),.pixel_count_debug());
zoom_source_cache cache(
 .rst(rst),.sd_clk(sc),.mem_clk(mc),.upload_req(upload_req),.src_w(cw),.src_h(ch),.upload_valid(upload_valid),.upload_pixel(upload_pixel),
 .upload_ready(upload_ready),.cache_valid(cache_valid),.row_req(row_req),.row_index(row_index),.row_ack(row_ack),.row_valid(row_valid),
 .row_pixel(row_pixel),.row_ready(row_ready),.legacy_hold(hold),.legacy_busy(legacy_busy),.aux_active(aux_active),
 .aux_read(aux_read),.aux_write(aux_write),.aux_addr(aux_addr),.aux_data(aux_data),.init_done(!rst),.refresh_busy(refresh),
 .sdr_busy(refresh),.read_valid(ret_valid[5]),.read_data(ret_data[5]),.cache_error(cache_error));
frame_read_write frames(
 .auxiliary_hold(hold),.legacy_busy(legacy_busy),.rst(rst),.mem_clk(mc),.Sdr_init_done(!rst),.Sdr_init_ref_vld(refresh),.Sdr_busy(refresh),
 .App_rd_en(fr),.App_rd_addr(fra),.Sdr_rd_en(ret_valid[5] && !aux_active),.Sdr_rd_dout(ret_data[5]),
 .read_clk(pc),.read_req(video_req),.read_req_ack(video_ack),.read_finish(),
 .read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd0),.read_addr_3(21'd0),
 .read_status(mem_status),.read_frame_status(read_status),.read_addr_index(mem_status[5:4]),.read_len(21'd307200),
 .read_en(read_en),.read_data(rd),.App_wr_en(fw),.App_wr_addr(fwa),.App_wr_din(fwd),.App_wr_dm(),
 .write_clk(sc),.write_req(dma_req),.write_req_ack(wa),.write_finish(wf),
 .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd0),.write_addr_3(21'd0),
 .write_addr_index(dma_bank),.write_len(21'd307200),.write_en(we),.write_data(wd),.write_usedw(used),
 .storage_diag_mem(storage_diag),.storage_diag_write(write_diag),.diagnostic_read(read_diag));
osd_status_cdc #(.WIDTH(9)) cm(.src_clk(sc),.dst_clk(mc),.rst(rst),.src_data(sd_status),.dst_data(mem_status));
osd_status_cdc #(.WIDTH(5)) cp(.src_clk(mc),.dst_clk(pc),.rst(rst),.src_data(read_status),.dst_data(pixel_status));
video_timing_data vt(.video_clk(pc),.rst(rst),.read_req(video_req),.read_req_ack(video_ack),.hs(hs),.vs(vs),.de(de));
video_delay vd(.video_clk(pc),.rst(rst),.read_en(read_en),.read_data(rd[31:8]),.hs(hs),.vs(vs),.de(de),.hs_r(vhs),.vs_r(vvs),.de_r(vde),.vout_data(vrgb));
always @(posedge pc or posedge rst) if(rst) anim_sync<=0;else anim_sync<={anim_sync[1:0],anim};
image_transition tr(.video_clk(pc),.rst(rst),.vs(vvs),.de(vde),.rgb_in(pixel_status[2] ? vrgb:24'd0),
 .transition_mode(2'd0),.duration_sel(2'd1),.transition_req_toggle(treq),.transition_commit_toggle(pixel_status[4]),
 .dark_ack_toggle(tdark),.done_toggle(tdone),.rgb_out(out_rgb));
function automatic [23:0] colour(input integer xx,yy);
 colour={8'(xx),8'(yy),8'(xx+yy)};
endfunction
function automatic [23:0] reference(input integer xx,yy,rx,ry,denx,deny);
 integer x1,y1,ax,ay,c,a,b,d,e,v;reg [23:0] z;
 begin
 x1=xx+1<iw ? xx+1:xx;y1=yy+1<ih ? yy+1:yy;ax=rx*256/denx;ay=ry*256/deny;z=0;
 for(c=0;c<3;c=c+1) begin
 a=(colour(xx,yy)>>(8*c))&255;b=(colour(x1,yy)>>(8*c))&255;d=(colour(xx,y1)>>(8*c))&255;e=(colour(x1,y1)>>(8*c))&255;
 v=(a*(256-ax)*(256-ay)+b*ax*(256-ay)+d*(256-ax)*ay+e*ax*ay+32768)/65536;z=z|(v<<(8*c));end
 reference=z;end
endfunction
function automatic [7:0] file_byte(input integer address);
 integer a,k,col,row,v;
 begin
 a=address%(SECTORS*512);file_byte=0;
 if(address<4*SECTORS*512) begin
 if(a==0) file_byte="B";else if(a==1) file_byte="M";
 else if(a>=2 && a<=5) file_byte=(FILE_LEN>>((a-2)*8))&255;
 else if(a==10) file_byte=54;else if(a==14) file_byte=40;
 else if(a>=18 && a<=21) file_byte=(iw>>((a-18)*8))&255;
 else if(a>=22 && a<=25) file_byte=(ih>>((a-22)*8))&255;
 else if(a==26) file_byte=1;else if(a==28) file_byte=24;
 else if(a>=54 && a<FILE_LEN) begin k=a-54;col=(k%STRIDE)/3;row=ih-1-k/STRIDE;v=colour(col,row);file_byte=(v>>(8*((k%STRIDE)%3)))&255;end
 end
 end
endfunction
always @(posedge mc) begin
 memtick<=memtick+1;
 if(rst) selected_read_bank<=0;
 else if(frames.frame_fifo_read_m0.state==1) begin
 selected_read_bank<=frames.frame_fifo_read_m0.read_addr_index_d1;
 selected_w<=bw[frames.frame_fifo_read_m0.read_addr_index_d1];selected_h<=bh[frames.frame_fifo_read_m0.read_addr_index_d1];
 selected_interp<=bi[frames.frame_fifo_read_m0.read_addr_index_d1];
 end
 if(rst || frames.frame_fifo_write_m0.state==1) physical_write_count=0;
 if(rst) begin ret_valid<=0;ret_owner<=0;finish_toggle<=0;end
 else begin
  ret_valid<={ret_valid[4:0],ar};ret_owner<={ret_owner[4:0],aux_active};
  if(ar) begin
   if(ra>=1662976) $fatal(1,"out of range read");
   ret_data[0]<=memory[ra];
  end
  for(j=1;j<6;j=j+1) ret_data[j]<=ret_data[j-1];
  if(ret_valid[5] && ret_owner[5]!=aux_active) $fatal(1,"read return routed to wrong owner");
  if(ar && aw) $fatal(1,"read/write collision");
  if(aux_active && (fr || fw)) $fatal(1,"auxiliary grant overlaps legacy command");
  if(aw) begin
   if(wa_mem>=1662976) $fatal(1,"out of range write");
   memory[wa_mem]<=wdata;
   if(aux_active) begin
    if(wa_mem<614400) $fatal(1,"cache overwrote display buffer");
    sx=(wa_mem-614400)%iw;sy=ih-1-(wa_mem-614400)/iw;
    if(wdata!=={colour(sx,sy),8'd0}) $fatal(1,"source cache upload mismatch at %0d got=%h",wa_mem,wdata);
    upload_words=upload_words+1;
   end else begin
    if(frames.diag_fifo_empty) $fatal(1,"target write FIFO underflow");
    if(pixel_status[2] && wa_mem/307200==selected_read_bank) $fatal(1,"writing the bank selected by the memory reader");
    if(wa_mem !== dma_bank*307200+(479-physical_write_count/640)*640+physical_write_count%640) $fatal(1,"target write address/order mismatch");
    physical_write_count=physical_write_count+1;
   end
  end
  if(wf) finish_toggle<=~finish_toggle;
  if(cache_error) $fatal(1,"cache FIFO error");
 end
end
always @(posedge sc) begin
 sdtick<=sdtick+1;
 if(sdtick%2000000==0) $display("PROGRESS cycle=%0d sdstate=%0d bmp=%0d scale=%0d source=%0d,%0d bridge=%0d uploaded=%0d legacy=%0d/%0d pixels=%0d hold=%b busy=%b/%b used=%h dataready=%b req=%b ack=%b len=%h cnt=%h portcount=%h",sdtick,dut.state_code_i,dut.bmp_read_m0.state,dut.u_scale.state,dut.u_scale.src_x,dut.u_scale.src_row,cache.state,cache.uploaded,frames.frame_fifo_write_m0.state,frames.frame_fifo_read_m0.state,count,hold,frames.O_wr_busy,frames.O_rd_busy,frames.wrusedw,frames.frame_fifo_write_m0.fifo_data_ready,req,wa,frames.frame_fifo_write_m0.write_len_latch,frames.frame_fifo_write_m0.write_cnt,frames.frame_fifo_write_m0.rdusedw);
 if(rst) begin req_last<=0;commit_last<=0;count=0;end
 else begin
  req_last<=req;commit_last<=commit;
  if(req && !req_last) begin
   if(transactions!=0 && count!=307200) $fatal(1,"incomplete previous frame");
   transactions=transactions+1;count=0;last_req_tick=sdtick;
   frame_interp=anim || dut.load_interpolation;im=dut.load_scale_mode;
   if(anim) begin
    ww=dut.u_animation.current_w;hh=dut.u_animation.current_h;
    gw0=iw;gh0=ih;gw1=iw;gh1=ih;
    case(dut.applied_scale_mode)
     1:begin gh0=480;gw0=iw*480/ih;end
     2:begin gw0=640;gh0=ih*640/iw;end
    endcase
    case(dut.anim_target)
     1:begin gh1=480;gw1=iw*480/ih;end
     2:begin gw1=640;gh1=ih*640/iw;end
    endcase
    ew=gw1>=gw0 ? gw0+(gw1-gw0)*dut.anim_step/24:gw0-(gw0-gw1)*dut.anim_step/24;
    eh=gh1>=gh0 ? gh0+(gh1-gh0)*dut.anim_step/24:gh0-(gh0-gh1)*dut.anim_step/24;
    if(ww!=ew || hh!=eh) $fatal(1,"animation geometry DDA mismatch step=%0d got=%0dx%0d expected=%0dx%0d",dut.anim_step,ww,hh,ew,eh);
   end
   else begin
    ww=iw;hh=ih;
    if(im!=0) begin
     if((iw*480<=ih*640 && im==1) || (iw*480>ih*640 && im==2)) begin hh=480;ww=iw*480/ih;end
     else begin ww=640;hh=ih*640/iw;end
    end
   end
   ox=(640-ww)>>>1;oy=(480-hh)>>>1;bw[wb]=ww;bh[wb]=hh;bi[wb]=frame_interp;
  end
  if(we) begin
   if(req || wa || count>=307200) $fatal(1,"write during FIFO clear or extra pixel");
   x=count%640;y=479-count/640;fx=x-ox;fy=y-oy;expected=0;
   if(fx>=0 && fy>=0 && fx<ww && fy<hh) begin
    sx=fx*iw/ww;sy=fy*ih/hh;
    expected={colour(sx,sy),8'd0};
    if(frame_interp) expected={reference(sx,sy,(fx*iw)%ww,(fy*ih)%hh,ww,hh),8'd0};
   end
   if(wd!==expected) $fatal(1,"system pixel mismatch frame=%0d step=%0d src=%0dx%0d scale=%0dx%0d xy=%0d,%0d got=%h expected=%h",transactions,dut.anim_step,iw,ih,ww,hh,x,y,wd,expected);
   count=count+1;
  end
  if(commit!=commit_last) begin
   if(count!=307200) $fatal(1,"premature frame commit");
   commits=commits+1;
   if(anim) begin anim_commits=anim_commits+1;if(sdtick-last_req_tick>max_step_cycles) max_step_cycles=sdtick-last_req_tick;end
   $display("PASS system commit=%0d anim=%0d step=%0d scale=%0dx%0d cycles=%0d",commits,anim,dut.anim_step,ww,hh,sdtick-last_req_tick);
  end
 end
end
// Check the real read FIFO at the pixel clock, including active-display starvation.
always @(posedge pc) begin
 read_en_last<=read_en;
 if(rst) begin vindex=0;video_started=0;end
 else begin
  if(video_req) begin vindex=0;video_started=0;end
  if(read_en && pixel_status[2]) begin
   if(!video_started) begin read_bank=selected_read_bank;visible_w=selected_w;visible_h=selected_h;visible_interp=selected_interp;
   visible_ox=(640-visible_w)>>>1;visible_oy=(480-visible_h)>>>1;video_started=1;end
   if(frames.diagnostic_read_empty) $fatal(1,"video FIFO underrun while animation/cache active");
   vx=vindex%640;vy=vindex/640;vfx=vx-visible_ox;vfy=vy-visible_oy;video_expected=0;
   if(vfx>=0 && vfy>=0 && vfx<visible_w && vfy<visible_h) begin
    vsx=vfx*iw/visible_w;vsy=vfy*ih/visible_h;video_expected={colour(vsx,vsy),8'd0};
    if(visible_interp) video_expected={reference(vsx,vsy,(vfx*iw)%visible_w,(vfy*ih)%visible_h,visible_w,visible_h),8'd0};
   end
   vindex=vindex+1;video_pixels=video_pixels+1;
   #1;if(rd!==video_expected) $fatal(1,"video readback mismatch bank=%0d idx=%0d got=%h expected=%h",read_bank,vindex-1,rd,video_expected);
  end
 end
end
task automatic wait_idle;
 integer n;
 begin n=0;while((dut.load_busy || dut.transition_active || !display_valid) && n<200000000) begin @(negedge sc);n=n+1;end
 if(n==200000000) $fatal(1,"system timeout cache=%0d engine=%0d renderer=%0d bridge=%0d upload=%0d",cache_valid,dut.u_animation.state,dut.u_animation.u_render.state,cache.state,cache.uploaded);
 repeat(100) @(negedge sc);
 end
endtask
integer before_reads,before_upload,before_commits;
initial begin
 repeat(20) @(negedge sc);rst=0;wait_idle();wait(cache_valid);
 if(commits!=1 || upload_words!=iw*ih) $fatal(1,"initial image/cache did not complete");
 before_reads=sd_requests;before_upload=upload_words;
 interpolation=1;scale_mode=1;wait(dut.load_busy);wait_idle();
 if(commits!=25 || anim_commits!=24 || sd_requests!=before_reads || upload_words!=before_upload) $fatal(1,"animation reread SD or wrong frame count");
 if($test$plusargs("FULL")) begin
 scale_mode=2;wait(dut.load_busy);wait_idle();
 if(commits!=49 || dut.applied_scale_mode!=2) $fatal(1,"fill animation failed");
 scale_mode=0;wait(dut.load_busy);wait_idle();
 if(commits!=73 || dut.applied_scale_mode!=0 || sd_requests!=before_reads) $fatal(1,"reverse animation failed");
 end
 before_commits=commits;
 // Switching back to nearest uses the original static path and reloads the source.
 interpolation=0;scale_mode=1;wait(dut.load_busy);wait_idle();wait(cache_valid);
 if(commits!=before_commits+1 || sd_requests==before_reads) $fatal(1,"nearest fallback failed");
 // Manual next still uses real BMP loading after all animation operations.
 key_next=0;repeat(30000) @(negedge sc);key_next=1;wait_idle();
 if(dut.img_idx!=1 || commits!=before_commits+2) $fatal(1,"manual image change failed");
 $display("RESULT PASS system frames=%0d pixels=%0d animated=%0d video_pixels=%0d max_render_cycles=%0d no_SD_reread=PASS",commits,commits*307200,anim_commits,video_pixels,max_step_cycles);
 test_pass=1;$finish;
end
endmodule
