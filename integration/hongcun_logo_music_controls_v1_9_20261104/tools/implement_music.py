"""Register the approved TF music datapath, retaining image and clock interfaces."""
from pathlib import Path
import shutil, re
R=Path(__file__).resolve().parents[1]
if 'u_music_control_cdc' in (R/'src/user_source/hdl_source/top_tf_hdmi_audio.v').read_text(encoding='utf-8'):
    print('Music integration already present; no changes made.')
    raise SystemExit(0)
H=R/'src/user_source/hdl_source'
B=R/'music_evidence/before'
files=['top_tf_hdmi_audio.v','user_control.v','SD/sd_card_bmp.v']
for name in files:
    src=H/name; dst=B/name
    dst.parent.mkdir(parents=True,exist_ok=True)
    if not dst.exists(): shutil.copy2(src,dst)

p=H/'user_control.v'; s=p.read_text(encoding='utf-8')
s=s.replace('output reg  [3:0] setting_value','output reg music_track,\n    output reg  [3:0] setting_value')
s=s.replace("scale_mode      <= 2'd0;","music_track <= 1'b0;\n            scale_mode      <= 2'd0;",1)
s=s.replace('case (sw_stable)\n',"case (sw_stable)\n                4'b1001: music_track <= ~music_track;\n",1)
s=s.replace("4'b1000: setting_value", "4'b1001: setting_value = {3'd0,music_track} + 4'd1;\n            4'b1000: setting_value")
p.write_text(s,encoding='utf-8')

p=H/'SD/sd_card_bmp.v'; s=p.read_text(encoding='utf-8')
s=s.replace('input                       key_next,','input [1:0] music_control,\n    input audio_mclk,\n    output music_bclk,music_lrck,music_dout,\n    output [2:0] music_health,\n    input                       key_next,',1)
marker='// Use a conservative ~3.125 MHz read clock'
insert='''// Sector ownership is held through END; no image bytes see audio responses.
wire phy_req,phy_valid,phy_end,a_req,a_grant,a_valid,a_end;
wire [31:0] phy_addr,a_addr;
wire [7:0] phy_data;
sd_music_arbiter u_music_arbiter(
 .clk(clk),.rst(rst),.image_req(sd_sec_read),.image_addr(sd_sec_read_addr),
 .image_valid(sd_sec_read_data_valid),.image_end(sd_sec_read_end),
 .audio_req(a_req),.audio_addr(a_addr),.audio_grant(a_grant),.audio_valid(a_valid),.audio_end(a_end),
 .phy_req(phy_req),.phy_addr(phy_addr),.phy_valid(phy_valid),.phy_end(phy_end));
assign sd_sec_read_data=phy_data;
tf_music_player u_music_player(
 .sd_clk(clk),.audio_clk(audio_mclk),.rst(rst),.control(music_control),.sd_ready(sd_init_done),
 .read_req(a_req),.read_addr(a_addr),.read_grant(a_grant),
 .read_valid(a_valid),.read_end(a_end),.read_data(phy_data),
 .bclk(music_bclk),.lrck(music_lrck),.dout(music_dout),.health(music_health));

'''
s=s.replace(marker,insert+marker,1)
pos=s.index(') sd_card_top_m0(')
s=s[:pos]+s[pos:].replace('(sd_sec_read)', '(phy_req)').replace('(sd_sec_read_addr)', '(phy_addr)').replace('(sd_sec_read_data)', '(phy_data)').replace('(sd_sec_read_data_valid)', '(phy_valid)').replace('(sd_sec_read_end)', '(phy_end)')
p.write_text(s,encoding='utf-8')

p=H/'top_tf_hdmi_audio.v'; s=p.read_text(encoding='utf-8')
s=s.replace('user_control u_transition_control (','wire music_track;\nwire [1:0] music_control_sd;\nwire [2:0] music_health;\nosd_status_cdc #(.WIDTH(2)) u_music_control_cdc(\n .src_clk(clk),.dst_clk(sd_card_clk),.rst(rst_all),\n .src_data({1\'b1,music_track}),.dst_data(music_control_sd));\nuser_control u_transition_control (',1)
s=s.replace('.text_mode(text_mode),','.music_track(music_track), .text_mode(text_mode),',1)
s=s.replace('.key_next          (key1),','.music_control(music_control_sd),.audio_mclk(audio_mclk),\n    .music_bclk(audio_i2s_bclk),.music_lrck(audio_i2s_lrck),.music_dout(audio_i2s_dout),\n    .music_health(music_health),\n    .key_next          (key1),',1)
start=s.index('// ===================== 音频：内部 I2S 测试音')
end=s.index('I2S_receiver u_I2S_receiver(',start)
s=s[:start]+'// TF PCM is serialized with the existing 64-bit/channel transport.\n'+s[end:]
p.write_text(s,encoding='utf-8')

project=R/'src/td_project/HDMI1.4b_Transmitter_v1.0.al'
dst=B/'HDMI1.4b_Transmitter_v1.0.al'
if not dst.exists(): shutil.copy2(project,dst)
s=project.read_text(encoding='utf-8')
for name in ['tf_music_player.v','sd_music_arbiter.v']:
    rel='../user_source/hdl_source/AUDIO_MUSIC/'+name
    if rel not in s:
        s=s.replace('<Verilog>',f'<Verilog>\n<File Path="{rel}"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="0"/></FileInfo></File>',1)
order=iter(range(1000))
s=re.sub(r'(<Attr Name="CompileOrder" Val=")\d+',lambda m:m[1]+str(next(order)),s)
project.write_text(s,encoding='utf-8')
batch=s.split('    <Runs>')[0]+'</Project>\n'
batch=re.sub(r'(<File Path=")([^"]+)',lambda m:m[1]+('../../al_ip/'+m[2][6:] if m[2].startswith('al_ip/') else '../../'+m[2]),batch)
for stage in ['syn_1','phy_1']:
    (project.parent/f'HDMI1.4b_Transmitter_v1.0_Runs/{stage}/HDMI1.4b_Transmitter_v1.0.prj').write_text(batch,encoding='utf-8')
print('Music sources registered; original modified HDL saved in music_evidence/before')
