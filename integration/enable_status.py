"""Enable status OSD in an existing isolated candidate; originals saved once.

Run: python integration/enable_status.py --candidate ../lab_ex5_i2s_osd
Does not modify the original lab_ex5_i2s or encrypted/vendor IP.
"""
from pathlib import Path
import argparse
import shutil

PROJECT='HDMI1.4b_Transmitter_v1.0'
REPO=Path(__file__).resolve().parents[1]

def replace_once(s, old, new):
    if s.count(old)!=1:
        raise ValueError(f'Expected one anchor: {old[:80]!r}, got {s.count(old)}')
    return s.replace(old,new,1)

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--candidate',required=True)
    c=Path(ap.parse_args().candidate).resolve()
    h=c/'src/user_source/hdl_source'
    top=h/'top_tf_hdmi_audio.v'
    if 'u_status_sd_mem' in top.read_text(encoding='utf-8-sig'):
        raise ValueError('Status integration already present; refusing to overwrite')
    backup=c/'fixed_osd_backup'
    if backup.exists(): raise ValueError('Backup already exists')
    paths=[top,h/'SD/sd_card_bmp.v',h/'SD/frame_read_write.v',h/'SD/frame_fifo_read.v',h/'OSD/osd_overlay.v']
    project=c/'src/td_project'/f'{PROJECT}.al'
    projects=[project]+[c/'src/td_project'/f'{PROJECT}_Runs'/stage/f'{PROJECT}.prj' for stage in ('syn_1','phy_1')]
    for p in paths+projects:
        dst=backup/p.relative_to(c); dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,dst)
    bit=c/'src/td_project'/f'{PROJECT}_Runs/phy_1/{PROJECT}.bit'
    if bit.exists(): shutil.copy2(bit,backup/'fixed_osd.bit')

    p=h/'SD/sd_card_bmp.v'; s=p.read_text(encoding='utf-8-sig')
    s=replace_once(s,'    output reg                  display_valid,','''    output reg                  display_valid,
    // SD-domain coherent metadata: {auto,valid,selected bank,tag1,tag0}.
    output wire [7:0]           osd_status,''')
    anchor='reg              next_req_pending;'
    s=replace_once(s,anchor,'''reg [1:0] osd_tag0, osd_tag1;
assign osd_status = {auto_play_en, display_valid, disp_buf_idx, osd_tag1, osd_tag0};
// Tags change only when a complete image is committed, never at load start.
always @(posedge clk or posedge rst) begin
    if (rst) begin osd_tag0<=0; osd_tag1<=0; end
    else if (!sd_init_done) begin osd_tag0<=0; osd_tag1<=0; end
    else if (load_busy && source_done_seen && (write_done_seen || write_finish_pulse)) begin
        if (pending_buf_idx==0) osd_tag0<=load_idx;
        else if (pending_buf_idx==1) osd_tag1<=load_idx;
    end
end
'''+anchor)
    a=s.index('// Tags change only'); b=s.index('reg              next_req_pending;',a)
    block=s[a:b]; s=s[:a]+s[b:]
    at=s.index('assign write_en'); s=s[:at]+block+'\n'+s[at:]
    p.write_text(s,encoding='utf-8')

    for name in ('frame_read_write.v','frame_fifo_read.v'):
        p=h/'SD'/name; s=p.read_text(encoding='utf-8-sig')
        s=replace_once(s,'\tinput[1:0]                       read_addr_index,','''    input [7:0] read_status, // coherent metadata already in mem_clk domain
    output '''+('reg ' if name=='frame_fifo_read.v' else 'wire ')+'''[3:0] read_frame_status,
\tinput[1:0]                       read_addr_index,''')
        if name=='frame_read_write.v':
            s=replace_once(s,'frame_fifo_read_m0\n(','''frame_fifo_read_m0
(
    .read_status(read_status), .read_frame_status(read_frame_status),''')
        else:
            s=replace_once(s,'reg [ADDR_BITS - 1:0]\t App_rd_addr_r;', '''reg [7:0] status_d0, status_d1;
// Same two registers as read_addr_index_d0/d1; use the same bank on the
// final S_ACK edge that initializes App_rd_addr_r.
always @(posedge mem_clk or posedge rst) begin
    if (rst) begin status_d0<=0; status_d1<=0; read_frame_status<=0; end
    else begin
        status_d0<=read_status; status_d1<=status_d0;
        if (state==S_ACK)
            read_frame_status <= {status_d1[7:6],
                (read_addr_index_d1==0 ? status_d1[1:0] : status_d1[3:2])};
    end
end
reg [ADDR_BITS - 1:0]\t App_rd_addr_r;''')
        p.write_text(s,encoding='utf-8')

    s=top.read_text(encoding='utf-8-sig')
    s=replace_once(s,'wire        display_valid;', '''wire        display_valid;
wire [7:0] osd_sd_status, osd_mem_status;
wire [3:0] osd_read_status, osd_pixel_status;
osd_status_cdc #(.WIDTH(8)) u_status_sd_mem (
    .src_clk(sd_card_clk), .dst_clk(ext_mem_clk), .rst(rst_all),
    .src_data(osd_sd_status), .dst_data(osd_mem_status));
osd_status_cdc #(.WIDTH(4)) u_status_mem_pixel (
    .src_clk(ext_mem_clk), .dst_clk(video_clk), .rst(rst_all),
    .src_data(osd_read_status), .dst_data(osd_pixel_status));''')
    s=replace_once(s,'    .display_valid     (display_valid),','    .display_valid     (display_valid),\n    .osd_status(osd_sd_status),')
    # This connection occurs only in frame_read_write. Address selection and
    # tags consume one mailbox snapshot instead of separate asynchronous buses.
    import re
    s,n=re.subn(r'(\.read_addr_index\s*\()disp_buf_idx(\s*\))',r'\1osd_mem_status[5:4]\2',s)
    if n!=1: raise ValueError('Unexpected read_addr_index connection')
    anchor='    .read_addr_0'
    at=s.index(anchor)
    s=s[:at]+'''    .read_status(osd_mem_status), .read_frame_status(osd_read_status),
'''+s[at:]
    s=replace_once(s,'osd_overlay u_osd_overlay (','''// Latch after the memory frame request, at active-video entry. Metadata
// has the entire vertical back porch to cross; first text pixel is x=16.
reg osd_pos_de_prev;
reg [3:0] osd_status_frame;
always @(posedge video_clk or posedge rst_all) begin
    if (rst_all) begin osd_pos_de_prev<=0; osd_status_frame<=0; end
    else begin
        osd_pos_de_prev<=osd_pos_de;
        if (osd_pos_de && !osd_pos_de_prev && osd_pos_y==0)
            osd_status_frame<=osd_pixel_status;
    end
end
osd_overlay #(.STATUS_MODE(1)) u_osd_overlay (
    .image_valid(osd_status_frame[2]), .image_index(osd_status_frame[1:0]),
    .auto_play(osd_status_frame[3]),''')
    s=replace_once(s,'.enable(osd_enable_frame && osd_position_valid)', '.enable(osd_position_valid)')
    s=s.replace('wire rst_all;\n','')
    s=s.replace('wire [7:0] osd_sd_status','wire rst_all;\nwire [7:0] osd_sd_status',1)
    top.write_text(s,encoding='utf-8')
    for name in ('osd_overlay.v','osd_status_layout.v','osd_status_cdc.v'):
        shutil.copy2(REPO/'rtl'/name,h/'OSD'/name)
    for p in projects:
        s=p.read_text(encoding='utf-8-sig')
        prefix='../user_source/hdl_source/OSD/' if p==project else '../../../user_source/hdl_source/OSD/'
        extra=''
        for i,name in enumerate(('osd_status_layout.v','osd_status_cdc.v'),49):
            extra+=f'''            <File Path="{prefix}{name}">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="{i}"/>
                </FileInfo>
            </File>
'''
        s=replace_once(s,'        </Verilog>',extra+'        </Verilog>')
        p.write_text(s,encoding='utf-8')
    print(f'Status enabled: {project}; fixed baseline: {backup}')

if __name__=='__main__': main()
