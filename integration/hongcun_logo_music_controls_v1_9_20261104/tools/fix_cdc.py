"""2026-11-03 user-approved CDC boundary preservation and bounded path constraints."""
from pathlib import Path
import shutil
R=Path(__file__).resolve().parents[1];H=R/'src/user_source/hdl_source';B=R/'music_evidence/before_cdc'
def edit(name,changes):
 p=H/name;dst=B/name;dst.parent.mkdir(parents=True,exist_ok=True)
 if not dst.exists():shutil.copy2(p,dst)
 s=p.read_text(encoding='utf-8')
 for old,new in changes:
  if new in s:continue
  assert old in s,(name,old)
  s=s.replace(old,new)
 p.write_text(s,encoding='utf-8')
edit('OSD/osd_status_cdc.v',[
 ('output reg [WIDTH-1:0] dst_data','(* keep="true" *) output reg [WIDTH-1:0] dst_data'),
 ('reg [WIDTH-1:0] held_data;','(* keep="true" *) reg [WIDTH-1:0] held_data;'),
 ('reg request, acknowledge;','(* keep="true" *) reg request, acknowledge;'),
 ('(* ASYNC_REG="TRUE" *)','(* ASYNC_REG="TRUE",keep="true" *)')])
edit('top_tf_hdmi_audio.v',[
 ('(* ASYNC_REG="TRUE" *)','(* ASYNC_REG="TRUE",keep="true" *)'),
 ('reg osd_display_meta, osd_display_sync, osd_enable_frame;',
  '(* ASYNC_REG="TRUE",keep="true" *) reg osd_display_meta, osd_display_sync;\nreg osd_enable_frame;')])
edit('SD/sd_card_bmp.v',[
 ('(* ASYNC_REG="TRUE" *)','(* ASYNC_REG="TRUE",keep="true" *)'),
 ('reg [2:0] dark_sync, done_sync;','(* ASYNC_REG="TRUE",keep="true" *) reg [2:0] dark_sync, done_sync;'),
 ('reg [2:0]        wrfin_tgl_sync;','(* ASYNC_REG="TRUE",keep="true" *) reg [2:0]        wrfin_tgl_sync;')])
edit('SD/image_transition.v',[
 ('reg [2:0] req_sync;','(* ASYNC_REG="TRUE",keep="true" *) reg [2:0] req_sync;'),
 ('reg [2:0] commit_sync;','(* ASYNC_REG="TRUE",keep="true" *) reg [2:0] commit_sync;'),
 ('reg [2:0] mode_meta, mode_sync;','(* ASYNC_REG="TRUE",keep="true" *) reg [2:0] mode_meta, mode_sync;'),
 ('reg [1:0] duration_meta, duration_sync;','(* ASYNC_REG="TRUE",keep="true" *) reg [1:0] duration_meta, duration_sync;'),
 ('reg dir_meta, dir_sync;','(* ASYNC_REG="TRUE",keep="true" *) reg dir_meta, dir_sync;')])
for name,prefix in [('SD/frame_fifo_read.v','read'),('SD/frame_fifo_write.v','write')]:
 changes=[]
 for i in range(3):
  import re
  s=(H/name).read_text(encoding='utf-8')
  old=re.search(r'\breg\s+'+prefix+r'_req_d'+str(i)+r';',s,re.M)[0]
  changes.append((old,'(* ASYNC_REG="TRUE",keep="true" *) '+old))
 edit(name,changes)
edit('SD/video_timing_data.v',[
 ('reg                    video_hs_d0;', '''// The memory-domain ACK is held until the synchronized request drops.
(* ASYNC_REG="TRUE",keep="true" *) reg ack_meta,ack_sync;
always @(posedge video_clk or posedge rst) begin
 if(rst) begin ack_meta<=0;ack_sync<=0;end
 else begin ack_meta<=read_req_ack;ack_sync<=ack_meta;end
end
reg                    video_hs_d0;'''),
 ('else if(read_req_ack)','else if(ack_sync)')])
edit('SD/zoom_source_cache.v',[
 ('(* ASYNC_REG="TRUE" *)','(* ASYNC_REG="TRUE",keep="true" *)')])

p=R/'src/user_source/constraints_source/timing.sdc'
dst=B/'timing.sdc';dst.parent.mkdir(parents=True,exist_ok=True)
if not dst.exists():shutil.copy2(p,dst)
s=p.read_text(encoding='utf-8').split('# BEGIN APPROVED BOUNDED CDC')[0]
lines=['# BEGIN APPROVED BOUNDED CDC -- 2026-11-03',
 '# TD SWUG200 3.11: -datapath_only bounds routing and automatically removes',
 '# the meaningless inter-clock hold check. No synchronous pipeline is cut.',
 '# Mailbox request/ACK uses two retained synchronizer registers. Payload is',
 '# held from request until ACK returns; capture follows two destination edges.',
 '# 8ns is at most one period of the fastest destination (125MHz).']
mailboxes=['u_checksum_cdc','u_memory_probe_cdc','u_scale_mode_cdc','u_music_control_cdc',
 'u_diag_sw_video','u_osd_cfg_video','u_diag_source_sys','u_diag_health_sys',
 'u_storage_probe_mem_sd','u_status_sd_mem','u_status_mem_pixel','u_diag_legacy_sys']
for m in mailboxes:
 for a,b in [('request','req_meta'),('acknowledge','ack_meta'),('held_data[*]','dst_data[*]')]:
  lines.append(f'set_max_delay -from [get_regs -nowarn {{{m}/{a}}}] -to [get_regs -nowarn {{{m}/{b}}}] -datapath_only 8.000')
lines+=['# Held frame request and return ACK, each synchronized before use.',
 'set_max_delay -from [get_clocks {video_clk}] -to [get_regs -nowarn {frame_read_write_m0/frame_fifo_read_m0/read_req_d0}] -datapath_only 8.000',
 'set_max_delay -from [get_clocks {ext_mem_clk}] -to [get_regs -nowarn {video_timing_data_m0/ack_meta}] -datapath_only 8.000',
 '# Persistent generation toggles. Only the first synchronizer stage is bounded.',
 'set_max_delay -from [get_clocks {video_clk}] -to [get_regs -nowarn {sd_card_bmp_m0/dark_sync[0] sd_card_bmp_m0/done_sync[0]}] -datapath_only 8.000',
 'set_max_delay -from [get_clocks {sd_card_clk}] -to [get_regs -nowarn {u_image_transition/req_sync[0] u_image_transition/commit_sync[0]}] -datapath_only 8.000',
 '# END APPROVED BOUNDED CDC']
p.write_text(s+'\n'+'\n'.join(lines)+'\n',encoding='utf-8')
print('Approved CDC preservation and bounded constraints applied.')
