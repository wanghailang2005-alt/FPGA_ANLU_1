"""Apply the user-approved SW1001 K2/K4/K3 controls, retaining TF layout."""
from pathlib import Path
import shutil,re,json
R=Path(__file__).resolve().parents[1];H=R/'src/user_source/hdl_source'
E=R/'audio_controls_evidence';B=E/'before';B.mkdir(parents=True,exist_ok=True)
def save(name,s):
 p=H/name;dst=B/name;dst.parent.mkdir(parents=True,exist_ok=True)
 if not dst.exists():shutil.copy2(p,dst)
 p.write_text(s,encoding='utf-8')
def read(name):return (H/name).read_text(encoding='utf-8')
assert 'module music_controls' not in read('user_control.v'),'Integration already applied'
s=read('user_control.v')
s+='''
// K2/B2 and K4/C1. Filter continuously; execute presses only in stable SW1001.
module music_controls #(parameter CLK_FREQ_HZ=50000000,FILTER_MS=20)(
 input clk,rst,enable,input key_pause_n,key_volume_n,
 output reg paused,output reg [3:0] volume);
 localparam LIMIT=(CLK_FREQ_HZ/1000)*FILTER_MS;
 (* ASYNC_REG="TRUE",keep="true" *) reg [1:0] meta,sync_key;
 reg [1:0] stable,pulse;
 reg [20:0] count[0:1];integer k;
 always @(posedge clk or posedge rst) begin
  if(rst)begin meta<=3;sync_key<=3;stable<=3;pulse<=0;count[0]<=0;count[1]<=0;end
  else begin
   meta<={key_volume_n,key_pause_n};sync_key<=meta;pulse<=0;
   for(k=0;k<2;k=k+1)begin
    if(sync_key[k]==stable[k]) count[k]<=0;
    else if(count[k]>=LIMIT-1)begin
     stable[k]<=sync_key[k];count[k]<=0;
     if(!sync_key[k])pulse[k]<=1;
    end else count[k]<=count[k]+1'b1;
   end
  end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin paused<=0;volume<=5;end
  else if(enable)begin
   if(pulse[0])paused<=~paused;
   if(pulse[1])volume<=volume==10 ? 4'd1:volume+1'b1;
  end
 end
endmodule
'''
save('user_control.v',s)
s=read('top_tf_hdmi_audio.v')
s=s.replace('wire [1:0] music_control_sd;','wire [6:0] music_control_sd;\nwire music_paused;wire [3:0] music_volume;\nwire music_mode_sys=diagnostic_sw_stable==4\'h9;\nmusic_controls u_music_controls(.clk(clk),.rst(rst_all),\n .enable(music_mode_sys && sw==4\'h9),.key_pause_n(key1),.key_volume_n(key2),\n .paused(music_paused),.volume(music_volume));')
s=s.replace('osd_status_cdc #(.WIDTH(2)) u_music_control_cdc','osd_status_cdc #(.WIDTH(7)) u_music_control_cdc')
s=s.replace('.src_data({1\'b1,music_track})','.src_data({music_paused,music_volume,1\'b1,music_track})')
s=s.replace('.music_control(music_control_sd),','.music_control(music_control_sd[1:0]),.playback_controls(music_control_sd[6:2]),')
s=s.replace('.key_next          (key1),','.key_next          (music_mode_sys ? 1\'b1:key1),')
s=s.replace('.key_auto          (key2),','.key_auto          (music_mode_sys ? 1\'b1:key2),')
s=s.replace('wire [28:0] ui_state_video;reg [28:0] ui_state_frame;','wire [34:0] ui_state_video;reg [34:0] ui_state_frame;')
s=s.replace('osd_status_cdc #(.WIDTH(29)) u_osd_cfg_video','osd_status_cdc #(.WIDTH(35)) u_osd_cfg_video')
s=s.replace('.src_data({diagnostic_sw_stable,transition_mode,interpolation,scale_mode,osd_cfg_sys})',
 '.src_data({music_track,music_paused,music_volume,diagnostic_sw_stable,transition_mode,interpolation,scale_mode,osd_cfg_sys})')
s=s.replace("ui_state_frame<=29'd0","ui_state_frame<=35'd0")
s=s.replace('osd_overlay #(.STATUS_MODE(OSD_STATUS_MODE)) u_osd_overlay (',
 'osd_overlay #(.STATUS_MODE(OSD_STATUS_MODE)) u_osd_overlay (\n    .music_track(ui_state_frame[34]),.music_paused(ui_state_frame[33]),.music_volume(ui_state_frame[32:29]),')
save('top_tf_hdmi_audio.v',s)
s=read('SD/sd_card_bmp.v').replace('input [1:0] music_control,','input [1:0] music_control,\n    input [4:0] playback_controls,')
s=s.replace('.bclk(music_bclk),','.playback_controls(playback_controls),.bclk(music_bclk),')
save('SD/sd_card_bmp.v',s)
s=read('AUDIO_MUSIC/tf_music_player.v')
s=s.replace('output reg bclk,lrck,dout,output [2:0] health','output reg bclk,lrck,dout,output [2:0] health,\n input [4:0] playback_controls')
s=s.replace(' reg [15:0] samples[0:2047];',''' wire [4:0] playback_audio;
 osd_status_cdc #(.WIDTH(5)) u_playback_cdc(
  .src_clk(sd_clk),.dst_clk(audio_clk),.rst(rst),
  .src_data(playback_controls),.dst_data(playback_audio));
 wire paused=playback_audio[4];
 // Signed Q8 gain with a balanced shift/add tree; no multiplier or DSP.
 function [15:0] scale_sample;
 input signed [15:0] sample;input [3:0] volume;
 reg [8:0] gain;reg signed [24:0] x,a,b,c,d,total;
 begin
  case(volume)
   1:gain=26;2:gain=51;3:gain=77;4:gain=102;5:gain=128;
   6:gain=154;7:gain=179;8:gain=205;9:gain=230;10:gain=256;
   default:gain=128;
  endcase
  x={{9{sample[15]}},sample};
  a=(gain[0]?x:25'sd0)+(gain[1]?(x<<<1):25'sd0);
  b=(gain[2]?(x<<<2):25'sd0)+(gain[3]?(x<<<3):25'sd0);
  c=(gain[4]?(x<<<4):25'sd0)+(gain[5]?(x<<<5):25'sd0);
  d=(gain[6]?(x<<<6):25'sd0)+(gain[7]?(x<<<7):25'sd0);
  total=(a+b)+(c+d)+(gain[8]?(x<<<8):25'sd0);
  scale_sample=total>>>8;
 end endfunction
 reg [15:0] samples[0:2047];''')
s=s.replace(' reg [23:0] frame_sample;', ' wire [15:0] scaled_sample=scale_sample(sample_q,playback_audio[3:0]);\n reg [23:0] frame_sample;')
s=s.replace('else if(run_a2 && playing && used_audio!=0)', 'else if(paused) begin frame_sample<=0;shift_word<=0;end\n     else if(run_a2 && playing && used_audio!=0)')
s=s.replace("frame_sample<={sample_q,8'd0};shift_word<={sample_q,48'd0};", "frame_sample<={scaled_sample,8'd0};shift_word<={scaled_sample,48'd0};")
save('AUDIO_MUSIC/tf_music_player.v',s)

glyph=json.loads((E/'new_ui_glyphs.json').read_text(encoding='utf-8-sig'))
chars=glyph['characters'];ids={c:chars.index(c) for c in '音量暂停播放频'}
s=read('OSD/osd_overlay.v')
s=s.replace('    input wire compact_layout,','    input wire compact_layout,\n    input wire music_track,music_paused,\n    input wire [3:0] music_volume,',1)
s=s.replace('ui_sidebar sidebar(.clk(clk)', 'ui_sidebar sidebar(.music_track(music_track),.music_paused(music_paused),.music_volume(music_volume),.clk(clk)',1)
s=s.replace("(sw_code==11 && ui_y>=272 && ui_y<288))", "(sw_code==11 && ui_y>=272 && ui_y<288) ||\n           (sw_code==9 && ui_y>=288 && ui_y<304))",1)
s=s.replace(' input wire clk,rst,frame_tick,enable,',' input wire clk,rst,frame_tick,enable,\n input wire music_track,music_paused,input wire [3:0] music_volume,',1)
start=s.index('function [15:0] font_init;');end=s.index('default:font_init=0;',start)
extra=[]
for g in glyph['added']:
 for row,value in enumerate(g['rows']):extra.append(f"11'd{g['id']*16+row}:font_init=16'h{value:04x};")
s=s[:end]+'\n'.join(extra)+'\n'+s[end:]
def seq(text):return "72'h"+''.join(f'{ids[c]:02x}' for c in text).ljust(18,'0')
music_lines=f'''18:begin
  if(sw_code==9) begin
   line={{8'd{ids['音']},8'd{ids['量']},8'd0,digit(music_volume==10 ? 1:0),digit(music_volume==10 ? 0:music_volume),8'd107,digit(1),digit(0),8'd0}};
   ink=24'h39b9c8;
  end else begin line=selected_value(sw_code,setting_value-4'd1);ink=24'ha8b3c0;end
 end
 19:if(sw_code==9)begin line=music_paused ? {seq('暂停')}:{seq('播放')};ink=music_paused ? 24'hf0b867:24'h39b9c8;end else active=0;
 20:if(sw_code==9)begin line={{8'd{ids['音']},8'd{ids['频']},8'd0,digit(0),digit(music_track ? 2:1),8'd107,digit(0),digit(2),8'd0}};end else active=0;'''
s=s.replace("18:begin line=selected_value(sw_code,setting_value-4'd1);ink=24'ha8b3c0;end",music_lines,1)
save('OSD/osd_overlay.v',s)
font_block=s[s.index('function [15:0] font_init;'):s.index('default:font_init=0;')]
rows=[0]*2048
for address,value in re.findall(r"11'd(\d+):font_init=16'h([0-9a-f]+);",font_block):rows[int(address)]=int(value,16)
(E/'sidebar_font.hex').write_text(''.join(f'{n:04x}\n' for n in rows),encoding='ascii')
(E/'sidebar_chars.txt').write_text(chars,encoding='utf-8')
(E/'glyph_ids.json').write_text(json.dumps(ids,ensure_ascii=False,indent=2),encoding='utf-8')

# Preserve old test/release records and extend existing music tests at unity gain.
for name in ['tb_music.sv','music.do','real_music.do']:
 p=R/'music_sim'/name;shutil.copy2(p,B/name)
 t=p.read_text(encoding='utf-8')
 if name=='tb_music.sv':t=t.replace('dout,health);',"dout,health,5'd10);")
 else:t=t.replace('vlog $h/AUDIO_MUSIC/', 'vlog $h/OSD/osd_status_cdc.v $h/AUDIO_MUSIC/')
 p.write_text(t,encoding='utf-8')
print('Audio controls integrated; sidebar glyph IDs:',ids)
